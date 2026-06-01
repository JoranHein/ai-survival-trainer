# AI Gateway Latency Report

Date: 2026-06-01

## Server Runtime

- Host: Hetzner `91.99.219.229`
- CPU: 4 vCPU, AMD EPYC-Milan Processor
- RAM: 15 GiB total, about 12 GiB available during inspection
- GPU: none detected; `nvidia-smi` is not installed
- Ollama: `0.24.0`
- Ollama processor: `100% CPU`
- Gateway service: `ari-ai-gateway`, active under systemd
- Gateway backend: `MODEL_BACKEND=ollama`
- Gateway model env: `DEEP_MODEL=qwen3:1.7b`, `FAST_MODEL=qwen3:1.7b`
- Gateway timeout: `REQUEST_TIMEOUT_SECONDS=60`

No API key or secret value was printed during inspection.

## Root Cause

The 40s live latency was caused by CPU-only Ollama inference on the full deep-interpretation prompt, not by gateway HTTP overhead or API authentication.

Evidence:

- Direct Ollama tiny JSON prompt: `0.764s`
- Direct Ollama short JSON prompt: `2.885s`
- Direct Ollama full old deep prompt for `stand behind the wall`: `26.257s`
  - Prompt tokens: `1177`
  - Prompt eval time: `12.423s`
  - Output tokens: `247`
  - Output eval time: `13.636s`
- Gateway old representative benchmark: `31.60s` to `41.62s`
- Gateway logs showed deep requests hitting `httpx.ReadTimeout` at 60s in some cases.
- Gateway code performs one model call and one strict JSON parse; there is no JSON repair retry loop.

The old prompt spent roughly half its direct time evaluating the prompt and half generating an overly long response.

## Benchmarks Before Optimization

Representative gateway calls with the old prompt/runtime:

| Sign | Latency | Parse | Top plan |
| --- | ---: | --- | --- |
| `stand behind the wall` | 41.62s | yes | `use_existing_wall:0.5` |
| `the circle should eat the dead` | 31.60s | yes | `farm_food:0.8` |
| `the wings do not fear stone` | 38.40s | fallback | `build_wall:0.5` |
| `my stomach is a second wall` | 34.23s | yes | `farm_food:0.8` |

Average: about `36.46s`.

## Optimizations Applied

Gateway-only changes:

- Compacted the deep interpretation prompt.
- Removed the full allowed-key list from every prompt.
- Replaced full affordance JSON dumps with compact available/unavailable id lists.
- Replaced full local fallback JSON with compact top hints.
- Added concise semantic cue lines for known current sign metaphors.
- Kept the response schema unchanged.
- Kept Godot API contract unchanged.
- Set Ollama JSON mode by default: `format=json`.
- Set default model temperature to `0.0`.
- Reduced default deep output budget from `360` to `300` tokens.
- Reduced default fast thought budget from `96` to `80` tokens.
- Added env controls:
  - `MODEL_TEMPERATURE`
  - `DEEP_MAX_TOKENS`
  - `FAST_MAX_TOKENS`
  - `OLLAMA_JSON_FORMAT`

The optimized direct prompt for `stand behind the wall`:

- Prompt chars: `1958` user + `805` system
- Prompt tokens: `720`
- Prompt eval time: `7.294s`
- Output tokens: `119`
- Output eval time: `6.161s`
- Direct latency: `13.677s`
- Top plan: `use_existing_wall`

## Benchmarks After Optimization

Command:

```powershell
python ai_gateway/scripts/benchmark_latency.py --repeat 1 --timeout 90 --json
```

Results:

| Sign | Latency | Parse | Top plan |
| --- | ---: | --- | --- |
| `stand behind the wall` | 20.894s | yes | `use_existing_wall:0.50` |
| `the circle should eat the dead` | 14.173s | yes | `lure_to_aura:0.50` |
| `the wings do not fear stone` | 17.105s | yes | `build_storm_rod:0.60` |
| `my stomach is a second wall` | 14.648s | yes | `farm_food:0.60` |

Average: `16.705s`.
P50: `15.877s`.

This is about a 54% reduction from the old representative average.

## Smaller Model Candidate

Tested `qwen3:0.6b` after pulling it into Ollama.

With the old full prompt it was faster than `qwen3:1.7b` on some calls, but quality was not acceptable:

- `stand behind the wall`: `22.134s`, top `use_existing_wall`
- `the circle should eat the dead`: `18.616s`, top `farm_food` instead of aura/lure
- `the wings do not fear stone`: `16.631s`, top `lure_to_aura` instead of anti-flying/storm
- `my stomach is a second wall`: `20.429s`, top `farm_food`

Recommendation: do not switch the live gateway to `qwen3:0.6b`.

## Final Recommendation

Keep `qwen3:1.7b` with the compact prompt/runtime settings for now.

The optimized gateway is still not instant on CPU-only hardware. The local fallback and interpretation cache remain necessary for playability. For further reductions, the next best steps are:

1. Validate whether a GPU-backed runtime or vLLM deployment is available.
2. Try another small instruct model only if it beats `qwen3:1.7b` on the four representative signs.
3. Consider a separate fast semantic router only for obvious high-confidence examples if live latency still feels too high, while preserving the LLM contract for ambiguous signs.

No Godot gameplay changes were made for this latency pass.
