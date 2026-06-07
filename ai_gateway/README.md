# AI Survival Trainer Ari AI Gateway

FastAPI gateway for Ari sign interpretation. It exposes only game-facing endpoints and calls a configured model provider. The default playtest profile is local Ollama with a small open-source model on the same server. OpenAI API and OpenAI-compatible runtimes remain supported.

## Endpoints

- `GET /health`
- `POST /ai/deep-interpretation`
- `POST /ai/fast-thought`
- `POST /ari/plan-v1`
- `POST /ari/predict-v1`
- `POST /scribe`
- `POST /library-reflection`
- `POST /background-job`

All endpoints require `X-API-Key` when `GAME_AI_API_KEY` is set.

## Environment

Copy `.env.example` to `.env` on the server and fill values:

```bash
GAME_AI_API_KEY=replace-with-a-strong-random-key
MODEL_BACKEND=ollama
MODEL_BASE_URL=http://127.0.0.1:11434
FAST_MODEL=qwen3:0.6b
DEEP_MODEL=hf.co/Qwen/Qwen3-1.7B-GGUF:Q8_0
PLANNER_MODEL=qwen3:0.6b
SCRIBE_MODEL=qwen3:0.6b
REFLECTION_MODEL=qwen3:1.7b
BACKGROUND_MODEL=qwen3:0.6b
PREDICTION_MODEL=smollm2:135m
PORT=8088
REQUEST_TIMEOUT_SECONDS=5
DEEP_REQUEST_TIMEOUT_SECONDS=5
PLANNER_REQUEST_TIMEOUT_SECONDS=5
SCRIBE_REQUEST_TIMEOUT_SECONDS=4
REFLECTION_REQUEST_TIMEOUT_SECONDS=12
BACKGROUND_REQUEST_TIMEOUT_SECONDS=4
PREDICTION_REQUEST_TIMEOUT_SECONDS=5
FOREGROUND_PRIORITY_DELAY_SECONDS=0.18
MODEL_TEMPERATURE=0.0
DEEP_MODE=deterministic
DEEP_MAX_TOKENS=360
FAST_MAX_TOKENS=80
PLANNER_MAX_TOKENS=180
SCRIBE_MODE=deterministic
SCRIBE_MAX_TOKENS=140
REFLECTION_MAX_TOKENS=140
BACKGROUND_MAX_TOKENS=120
PREDICTION_MAX_TOKENS=96
PLANNER_NUM_CTX=1024
REFLECTION_NUM_CTX=1024
PREDICTION_NUM_CTX=512
OLLAMA_NUM_THREAD=4
OLLAMA_NUM_CTX=4096
OLLAMA_KEEP_ALIVE=30m
OLLAMA_JSON_FORMAT=true
ENABLE_STARTUP_WARMUP=true
DEBUG_LOG_SIGNS=false
```

For OpenAI mode, set `MODEL_BACKEND=openai`, `MODEL_BASE_URL=https://api.openai.com/v1`, `MODEL_API_KEY`, `FAST_MODEL`, `DEEP_MODEL`, `PLANNER_MODEL`, `SCRIBE_MODEL`, `REFLECTION_MODEL`, `BACKGROUND_MODEL`, and `PREDICTION_MODEL`. `MODEL_API_KEY` is an OpenAI Platform API key, not a ChatGPT web session or subscription token. ChatGPT subscription usage and API billing are separate.

Do not log or store player sign text. `DEBUG_LOG_SIGNS` should remain `false` outside short local debugging.

## Local Run

```bash
cd ai_gateway
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8088
```

## Server Install

The intended server path is:

```bash
/opt/ari-ai-server
```

After copying files there:

```bash
cd /opt/ari-ai-server
cp .env.example .env
# edit .env and set GAME_AI_API_KEY
bash scripts/install_server.sh
```

The installer installs Ollama and pulls `DEEP_MODEL`, `FAST_MODEL`, `PLANNER_MODEL`, `SCRIBE_MODEL`, `REFLECTION_MODEL`, `BACKGROUND_MODEL`, and `PREDICTION_MODEL` when `MODEL_BACKEND=ollama`.

From this workspace, the safer repeatable deployment path is:

```powershell
python ai_gateway/scripts/deploy_gateway.py `
  --host YOUR_SERVER_IP `
  --user root `
  --password-file "$HOME\.ssh\ari_ubuntu_16gb_hel1_1_root_password.txt"
```

To verify SSH credentials without uploading or changing the server:

```powershell
python ai_gateway/scripts/deploy_gateway.py `
  --host YOUR_SERVER_IP `
  --user root `
  --password-file "$HOME\.ssh\ari_ubuntu_16gb_hel1_1_root_password.txt" `
  --check-ssh-only
```

The deploy script packages only gateway server files, excludes `.env` and `*.local.*` files, preserves the remote `/opt/ari-ai-server/.env`, restarts `ari-ai-gateway`, and verifies `/health`, `/ari/predict-v1`, `/scribe`, `/library-reflection`, and `/background-job` on the server before reporting success. Use `--package-only path.tar.gz` to inspect the upload package without connecting.

The currently validated 4 vCPU CPU-only gameplay profile is:

```bash
MODEL_BACKEND=ollama
MODEL_BASE_URL=http://127.0.0.1:11434
FAST_MODEL=qwen3:0.6b
DEEP_MODEL=hf.co/Qwen/Qwen3-1.7B-GGUF:Q8_0
PLANNER_MODEL=qwen3:0.6b
SCRIBE_MODEL=qwen3:0.6b
REFLECTION_MODEL=qwen3:1.7b
BACKGROUND_MODEL=qwen3:0.6b
PREDICTION_MODEL=smollm2:135m
REQUEST_TIMEOUT_SECONDS=5
DEEP_REQUEST_TIMEOUT_SECONDS=5
PLANNER_REQUEST_TIMEOUT_SECONDS=5
SCRIBE_REQUEST_TIMEOUT_SECONDS=4
REFLECTION_REQUEST_TIMEOUT_SECONDS=12
BACKGROUND_REQUEST_TIMEOUT_SECONDS=4
PREDICTION_REQUEST_TIMEOUT_SECONDS=5
FOREGROUND_PRIORITY_DELAY_SECONDS=0.18
DEEP_MODE=deterministic
PLANNER_MAX_TOKENS=180
REFLECTION_MAX_TOKENS=140
BACKGROUND_MAX_TOKENS=120
PREDICTION_MAX_TOKENS=96
PLANNER_NUM_CTX=1024
REFLECTION_NUM_CTX=1024
PREDICTION_NUM_CTX=512
OLLAMA_NUM_THREAD=4
OLLAMA_KEEP_ALIVE=30m
ENABLE_STARTUP_WARMUP=true
SCRIBE_MODE=deterministic
```

`qwen3:0.6b` is the current live prediction/planner/background model because it produced useful compact JSON in under 5 seconds on the 4 vCPU server. `FOREGROUND_PRIORITY_DELAY_SECONDS=0.18` gives live prediction a short window to preempt planner/reflection calls that arrived just before it. `DEEP_MODE=deterministic` keeps sign-reading from blocking live prediction on CPU; the LLM intelligence comes from prediction, background summaries, and reflection. `qwen3:1.7b` is the current reflection model with the compact reflection contract; the older Q8 1.7B profile is still useful for comparisons but is too slow for the live reflection timeout. `hf.co/ggml-org/SmolLM3-3B-GGUF:Q4_K_M` is small enough to keep installed as a comparison model, but it has not replaced the Qwen split in live probes.

`SCRIBE_MODE=deterministic` is recommended for CPU-only Ollama servers. It turns `/scribe` into a cheap structured extractor from Godot facts and reserves model time for prediction, planning, and nightly reflection. Set `SCRIBE_MODE=model` only when testing a tiny dedicated `SCRIBE_MODEL`; keep `REFLECTION_MODEL` on `qwen3:1.7b` or another benchmarked model that can finish the compact reflection contract before timeout.

If a CUDA-capable local runtime is available later, set `MODEL_BACKEND=vllm` and `MODEL_BASE_URL=http://127.0.0.1:8000/v1`.

## Curl Test

```bash
curl -fsS -H "X-API-Key: $GAME_AI_API_KEY" http://127.0.0.1:8088/health
```

```bash
curl -fsS -X POST http://127.0.0.1:8088/ai/deep-interpretation \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $GAME_AI_API_KEY" \
  -d '{
    "sign_text": "stand behind the wall",
    "ari": {
      "run_build": {"preset": "Builder", "building": 5, "warding": 3},
      "hp": 80,
      "max_hp": 100,
      "current_job": "build_wall",
      "current_reason": "No aura orb yet"
    },
    "world": {
      "day": 1,
      "phase": "midday",
      "time_left": 25,
      "stone": 10,
      "wall_count": 2,
      "aura_orb_count": 1,
      "enemy_count": 0,
      "known_enemy_types": ["zombie"],
      "structures": [{"type": "wall", "status": "intact"}]
    },
    "local_fallback": {
      "interpretation": "The sign mentions wall. Ari thinks about building walls.",
      "priority_hints": {"build_wall": 0.8},
      "sign_strength": 0.4,
      "resonance": 0.4
    }
  }'
```

The desired interpretation for `"stand behind the wall"` is cover behavior, not simply building more walls.

## Benchmarks

Deep interpretation:

```bash
python ai_gateway/scripts/benchmark_latency.py --base-url http://127.0.0.1:8088 --repeat 1
```

Observer loop endpoints:

```bash
python ai_gateway/scripts/benchmark_observer_loop.py --base-url http://127.0.0.1:8088 --repeat 1
```

Scribe quality:

```bash
python ai_gateway/scripts/benchmark_scribe_quality.py --base-url http://127.0.0.1:8088
```

Reflection quality:

```bash
python ai_gateway/scripts/benchmark_reflection_quality.py --base-url http://127.0.0.1:8088
```
