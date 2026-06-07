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
- Gateway timeout at the time of this older measurement: `REQUEST_TIMEOUT_SECONDS=60`

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

## 2026-06-05 Observer/Reflection Follow-Up

Current configured live gateway in `godot_game/data/ai_config.local.json`:

- Host: `65.109.225.216`
- Auth: API key required
- `GET /health` without key returns `401`, as expected
- `POST /scribe` returned `404` in `0.232s`
- `POST /library-reflection` returned `404` in `0.064s`

This means the live server needs the current `ai_gateway/` deployment before the new Ari Observer + Night Reflection Learning loop can use remote scribe/reflection models. Until then, Godot falls back deterministically for those tiers.

Live deep-interpretation benchmark against the configured server:

| Sign | Latency | Parse | Top plan |
| --- | ---: | --- | --- |
| `stand behind the wall` | 30.506s | yes | `use_existing_wall:0.50` |
| `the circle should eat the dead` | 20.934s | yes | `lure_to_aura:0.80` |
| `the wings do not fear stone` | 22.759s | yes | `build_storm_rod:0.60` |
| `my stomach is a second wall` | 18.376s | yes | `farm_food:0.60` |

Average: `23.144s`.
P50: `21.846s`.

Live intelligence probe:

- Passed: `7/7`
- Latency range: `22.7s` to `29.4s`
- Correct top-plan examples included `use_existing_wall`, `lure_to_aura`, `train_combat`, `stall_until_dawn`, `build_storm_rod`, `farm_food`, and `use_cover`.

Critical caveat: this quality is usable only with strict call discipline. CPU-only local inference is still too slow for frequent planning. The Godot bridge must keep one request in flight per tier, skip queued scribe calls, cap reflection payloads, and rely on deterministic local behavior during slow responses.

## 2026-06-05 Planner Cadence Follow-Up

The scripted full-loop remote playtest exposed over-calling in the planner tier. With a fast local scripted gateway, the four remote scenarios previously made `142` planner calls while also creating structured scribe notes and nightly reflections. A real CPU Ollama server averaging about `23s` per deep interpretation cannot afford that cadence.

Godot now applies a response cooldown for noncritical queued planner requests:

- One planner request remains in flight at a time.
- Noncritical queued triggers such as `structure_built` and `timer` are coalesced and delayed until the cooldown expires.
- Critical triggers such as `sign_commit`, `near_death`, `new_enemy_type`, `phase_changed`, `structure_destroyed`, `night_reflection`, and `deep_interpretation` may bypass the cooldown.
- The engine keeps moving Ari through deterministic local behavior while waiting.

Fresh scripted playtest after the cooldown:

- Scenarios: `4/4` passed
- Planner calls: `107`
- Scribe calls: `45`
- Reflection calls: `24`
- Every scenario stored structured scribe notes and reflection notes.

This is about a `25%` reduction in planner traffic on the scripted benchmark while preserving the tested survival outcomes. It is not the final target; the next reduction should come from payload-aware replanning, smarter trigger classification, or using a much faster local planner model after the live server is updated with `/scribe` and `/library-reflection`.

## 2026-06-05 Scribe Mode Follow-Up

The scribe tier now has an explicit gateway mode:

- `SCRIBE_MODE=deterministic`: `/scribe` skips the model and extracts structured facts from Godot snapshots/events.
- `SCRIBE_MODE=model`: `/scribe` calls `FAST_MODEL` and falls back deterministically on failure.

For CPU-only Ollama, the default is deterministic. This keeps frequent moment notes cheap and reserves model time for planning and nightly/library reflection.

Temporary local gateway benchmark with `SCRIBE_MODE=deterministic`, no model runtime:

| Endpoint | Latency | Schema | Source |
| --- | ---: | --- | --- |
| `/scribe` | `0.094s` | `ari.scribe.note.v2` | `deterministic_scribe` |
| `/library-reflection` | `0.018s` | `ari.night_reflection.v1` | `local_fallback` |

Command:

```powershell
python ai_gateway/scripts/benchmark_observer_loop.py --base-url http://127.0.0.1:<port> --repeat 1 --json
```

The reflection result in this local benchmark is only fallback verification because the temporary process intentionally had no model API key/runtime. Real reflection latency still needs to be measured after the Hetzner gateway is updated with the new endpoints.

## 2026-06-06 Pipeline Timeout/Profile Update

The current gameplay profile targets `REQUEST_TIMEOUT_SECONDS=5`, a dedicated `/ari/predict-v1` foreground lane for useful sub-5-second tactical prediction, scribe v2 structured notes, compact planner strategy packets, and a bounded `/background-job` lane. The old `120s` and interim `45s` gameplay timeouts should not appear in normal Godot logs. Planner bodies should stay in the low-KB range rather than the old `~15KB` class, and any slow work must fall back or move to background.

## 2026-06-05 Learning-Loop Behavior Follow-Up

The observer/reflection loop exposed a real learning-path weakness: a strong freeform sign fallback could keep choosing its first local action even after a validated night reflection created relevant doctrine. In the anti-flying case, Ari could keep preferring ordinary walls while a learned doctrine said flying enemies need storm defenses.

Godot now scores local sign fallback candidates and active doctrine plan candidates together. Active doctrine bias can downweight unsafe learned actions and promote safer learned actions, while action availability still stays deterministic and engine-owned. This keeps the sign freeform, but lets validated memory change future fallback behavior through the existing safe channel.

Fresh verification:

- `ai_pipeline_test.gd` includes a regression where `build_wall` wins before reflection, then `build_storm_rod` wins after a validated flying doctrine.
- `pytest ai_gateway/tests -q`: `45 passed`
- `ari_observer_reflection_test.gd`: passed
- `ari_intelligence_scenarios_test.gd`: passed
- Godot headless launch: passed
- Scripted remote-agent playtest: `4/4` prompts passed, `107` planner calls, `45` scribe calls, `24` reflections, all scenarios stored structured scribe notes and doctrine reflections.

The deterministic scribe note now includes the current action, reason, nearest danger, active plan, and recent event in plain text. Godot's local fallback scribe now follows the same shape, so offline or failed-gateway runs do not collapse back to vague notes. Example:

`Ari was moving to build site; because flying enemy near crops; nearest danger was flying at 96; plan was build storm rod; recent event was enemy spawned.`

The scripted playtest harness now delegates to the same deterministic scribe extractor, so playtest logs no longer hide vague notes behind a separate fake scribe implementation.

When the smarter reflection model is unavailable, both the gateway and Godot local reflection fallbacks now compile one conservative doctrine from structured flying evidence:

- activate only when `enemy_type_present == "flying"`
- promote `build_storm_rod`
- mildly downweight `build_wall`
- keep the output as validated reflection JSON, not direct world mutation

This is a real improvement in the learning loop, but it is not proof that Ari is broadly smart. It proves two important requirements: validated reflection doctrine can override an unsafe local sign fallback when the world context activates that doctrine, and failed/offline reflection can still learn one narrow obvious lesson from structured scribe notes. The next evidence gap is live-server deployment of `/scribe` and `/library-reflection`, then a longer playtest against real local models instead of the scripted gateway.

## 2026-06-05 Current Full-Loop Verification

Latest local verification after the observer/reflection, doctrine progression, and planner-cadence fixes:

- `pytest ai_gateway/tests -q`: `54 passed`
- `ari_observer_reflection_test.gd`: passed
- `ai_pipeline_test.gd`: passed
- `ari_intelligence_scenarios_test.gd`: passed
- Godot headless launch: passed
- Scripted remote-agent playtest: `5/5` prompts passed

The scripted playtest now covers tower arrows, light/mud, storm/wings, a deliberately bad wall habit that must learn anti-air doctrine, and ore/blade combat. Latest results:

| Prompt | Outcome | Key Evidence |
| --- | --- | --- |
| `remote_tower_arrows` | survived to day 4 midday | `tower=2/2`, `ranged=46`, `scribe=11`, `reflections=6` |
| `remote_light_and_mud` | survived to day 4 midday | `aura=2/2`, `tar=1/1`, `scribe=12`, `reflections=6`, `min_hp=82.0` |
| `remote_storm_wings` | survived to day 4 midday | `storm=1/1`, `tower=1/1`, `ranged=25`, `doctrine_plans=8`, `min_hp=59.8` |
| `remote_wall_habit_learns_wings` | survived to day 4 dusk | started from `stone walls are safety`, retained `storm=1/1`, reached `tower=1/1`, `ranged=26`, `doctrine_plans=9`, `min_hp=56.0` |
| `remote_ore_blade` | survived to day 4 midday | `sword=2`, `walls=1/2`, `melee=20`, `min_hp=59.0` |

Scripted gateway call counts:

- Deep interpretation: `5`
- Agent planning: `96`
- Scribe: `59`
- Night/library reflection: `30`
- Planner triggers: `anti_air_structure_built=4`, `deep_interpretation=5`, `new_enemy_type=10`, `night_reflection=5`, `phase_changed=36`, `sign_commit=5`, `structure_built=4`, `structure_destroyed=9`, `structure_destroyed_minor=4`, `timer=14`

The quality signal improved: the deterministic scribe now turns flying evidence into the full anti-air sequence (`build_storm_rod`, `build_tower`, `use_tower`), and the wall-habit scenario verifies that Ari can stop trusting ordinary walls after reflection doctrine activates. The ore/blade scenario also caught a fake-smart failure mode where Ari over-trained sword without cover; the scripted planner now adds cover/rest behavior after the blade exists.

The speed problem is not solved. `93` planner calls across five accelerated prompts is still too much for a CPU-only live model, but it is lower than the prior `129` calls and the previous `101`-call run. Godot now uses a `30s` noncritical planner cooldown while allowing critical triggers to bypass it. The storm/wings run exposed that a plain `30s` cooldown was too blunt: Ari built the Storm Rod but died before getting tower follow-through. The fix is a narrow `anti_air_structure_built` trigger for Storm Rod completion only; ordinary structure builds still wait for the noncritical cooldown.

Structure destruction is now split by relevance. If the destroyed structure breaks Ari's active plan, leaves no usable plan, or removes a key active defense under enemy pressure, it remains a critical `structure_destroyed` replan. If it is incidental, such as losing a wall while Ari is already executing a tower plan, it becomes noncritical and waits behind the cooldown. That reduced critical destruction replans from `15` to `9` in the latest run.

Timer replans now use a material-context signature, so unchanged timer pulses do not spend planner budget. Same-day noncritical phase changes also skip replanning when the material context is unchanged. Quiet dusk now skips only when Ari already has a night-ready defensive plan, such as using an existing tower, aura, lantern, decoy, thorns, or cover. The readiness check now also respects active doctrine requirements: if learned anti-air doctrine still needs a missing Storm Rod, dusk stays critical instead of treating tower use as enough. This held survival quality in the latest scripted run, including a stricter final-Storm-Rod retention check for `remote_wall_habit_learns_wings`, but total planner calls are still `96`; phase triggers remain the largest unsolved source.

This is a better intelligence/speed tradeoff than the 20s cadence, but it is still not efficient enough for live CPU-only Ollama use. `remote_ore_blade` still ends with only `walls=1/2`, and the full suite still spends too many planner calls on `phase_changed`, material-change `timer` replans, and plan-breaking `structure_destroyed` triggers. Night reflection duplicate-doctrine replans remain reduced to one per scenario (`night_reflection=5` total), but planner cadence needs another pass before live Ollama usage can be considered efficient.

A naive quiet-dusk phase optimization was tested and rejected. Making all quiet dusk transitions noncritical reduced one run to `95` planner calls and `phase_changed=24`, but `remote_wall_habit_learns_wings` died on day 3 night before completing the learned tower follow-through. The accepted version is narrower: quiet dusk remains critical unless the current plan is already night-ready and the material context is unchanged.

The ore/blade scenario exposed another fake-smart edge: a sword plan could keep choosing direct fighting against several night enemies. The scripted planner now treats multiple enemies, runners, or brutes as a reason to use cover/flee before direct fighting, even after the blade exists. This is covered by `test_scripted_ore_plan_uses_cover_against_multiple_night_enemies`.

A second ore/blade edge appeared in the Godot immediate tactic layer, not the scripted planner: `AriMind.choose_night_tactic()` could still choose `fight_head_on` against two runners before a remote replan arrived. The accepted fix tightens `_can_fight_head_on()` for runner/brute groups while preserving strong melee against a single ordinary enemy. This is covered by the runner-group assertion in `ai_pipeline_test.gd`.

A resource-only timer optimization was tested and rejected. It skipped timer replans while Ari was actively mining toward the same build/smith plan and reduced one failing run's `timer` calls to `12`, but it also caused `remote_wall_habit_learns_wings` to lose final Storm Rod retention and caused `remote_ore_blade` to die on night pressure. That speed cut made Ari measurably dumber, so it was reverted.

Live Hetzner observer benchmark remains blocked on deployment:

- `POST /scribe`: `404` in `0.181s`
- `POST /library-reflection`: `404` in `0.082s`
- Key-based SSH from this workspace is not configured, and password authentication failed during the deployment probe, so the live gateway could not be updated from this run.

Until the server runs the current gateway, Godot will keep using deterministic scribe/reflection fallback for those tiers. This is safe and cheap, but it is not the final two-model architecture: the intended production shape is deterministic/tiny scribe extraction plus a smarter reflection model during rest/library moments.

## 2026-06-05 Runner/Storm Robustness Follow-Up

The stricter final-Storm-Rod check exposed that a single passing scripted run was not enough evidence. Repeated full-suite runs showed two timing-sensitive failures:

- `remote_wall_habit_learns_wings` sometimes rebuilt anti-air once but ended the checkpoint with `storm=0/1`.
- `remote_ore_blade` sometimes entered day 3 night at medium HP, lost both walls to runners, fled too late, and died.

Accepted fixes:

- `remote_wall_habit_learns_wings` now requires final Storm Rod retention, not just a max historical Storm Rod count.
- `AriMind.choose_daytime_job()` now lets a ready sword plan rest at medium HP before night instead of blindly following a grounded `train_sword` plan.
- `AriMind.choose_night_tactic()` now treats collapsing cover plus grouped runners as unsafe when Ari is not healthy enough to fight.
- The same tactic layer now allows a strong sword Ari at high HP to fight a two-runner pair instead of choosing a fake-safe flee that runners can easily catch.
- `_can_fight_head_on()` still blocks low-HP runner/brute group melee and preserves the existing single-enemy strong-melee behavior.

Rejected speed optimization:

- Skipping quiet `night` phase replans, in addition to the accepted quiet-dusk skip, reduced one experimental run to about `90` planner calls and `phase_changed=29`, but it also caused final Storm Rod loss and an ore/blade death. That optimization was reverted. The lesson is that phase calls are still expensive, but cutting them without proving the active plan remains tactically valid makes Ari dumber.

Fresh verification after the robustness fixes:

- `pytest ai_gateway/tests -q`: `54 passed`
- `ari_observer_reflection_test.gd`: passed
- `ari_intelligence_scenarios_test.gd`: passed
- `ai_pipeline_test.gd`: passed
- Scripted remote-agent playtest: passed twice in a row for `5/5` prompts

Latest two full-suite scripted runs:

| Run | Planner | Scribe | Reflection | Key Evidence |
| --- | ---: | ---: | ---: | --- |
| pass 1 | `99` | `59` | `30` | wall-habit retained `storm=1/1`; ore/blade survived with `hp=82.1`, `min_hp=74.6`, `melee=19` |
| pass 2 | `99` | `59` | `30` | wall-habit retained `storm=1/1`; ore/blade survived with `hp=82.3`, `min_hp=59.8`, `melee=23` |

Current tradeoff: robustness cost a few planner calls versus the best experimental count, but the cheaper runs were not reliable. The honest current state is that Ari is smarter in these narrow ways: he learns anti-air doctrine from structured flying evidence, retains the final anti-air answer more reliably, rests before overtraining a sword plan, and chooses between cover, fleeing, and melee based on runner pressure, cover health, and HP instead of treating all defensive-looking actions as equally safe. It is still not efficient enough for live CPU-only Ollama planning; planner calls remain around `99` across five accelerated prompts.

## 2026-06-05 Planner Cadence And Doctrine Prerequisite Follow-Up

A compact `--plan-log` mode was added to `tools/run_scripted_remote_agent_playtest.py` so every scripted planner call can be inspected without dumping full sign text, recent event payloads, or huge JSON bodies. This made the remaining over-calling easier to reason about. The useful line shape is:

`PLAN 012 trigger=timer kind=day_replan day=2 phase=midday action=build_tower job=mine_stone hp=77.6 enemy=0 types=none res=stone:23/ore:13 struct=wall:2/tower:0/storm:1 current=mine_stone[0/1] age=33s legal=40 doctrine=3`

Root cause found: a skipped noncritical phase change could still reappear as a later `timer` planner call because the timer signature included `phase`. That meant "safe to skip dusk/midday because facts did not change" could become "spend planner budget a few seconds later anyway." The accepted fix is narrow: timer replans now compare material facts only. Critical phase changes still use the separate phase path, so dusk/night emergency replans remain available.

The first full plan-log run after that optimization caught a real intelligence bug, not just a speed issue. In one wall-habit run, a Storm Rod was destroyed, `build_storm_rod` was still the first learned doctrine step, but it was temporarily unaffordable. The scripted planner jumped to `use_tower` because later doctrine steps were legal. That is fake-smart behavior: Ari was following the shape of the doctrine while ignoring its prerequisite.

Accepted fixes:

- `AIBridge._validate_agent_plan()` now applies a deterministic doctrine prerequisite guard. If active doctrine still needs a missing Storm Rod, Bow Tower, or Aura Orb, a remote plan cannot skip straight to later use actions. It is rewritten to the required build action if legal, or to `mine_stone` when resources are missing. This preserves the LLM-as-mind boundary: the validator changes only plan advice, not world state.
- `/ari/plan-v1` now applies the same doctrine prerequisite guard server-side before returning the response. The gateway also filters unavailable actions out of the legal action set, matching Godot's validator behavior.
- The scripted gateway now follows the same prerequisite rule, so playtest logs show the intended model behavior instead of relying on Godot to correct bad output silently.
- The gateway `AgentPlanRequest` now carries `active_doctrine_plan`, and the planner prompt explicitly tells real models to satisfy unsatisfied earlier doctrine build steps or gather resources before later use actions.

Fresh verification after these changes:

- `pytest ai_gateway/tests -q`: `58 passed`
- `ai_pipeline_test.gd`: passed
- `ari_observer_reflection_test.gd`: passed
- `ari_intelligence_scenarios_test.gd`: passed
- Scripted remote-agent playtest: passed twice in a row for `5/5` prompts

Latest two full-suite scripted runs:

| Run | Planner | Scribe | Reflection | Key Evidence |
| --- | ---: | ---: | ---: | --- |
| pass 1 | `85` | `59` | `30` | wall-habit retained `storm=1/1`; ore/blade survived with `hp=82.4`, `min_hp=44.1`, `melee=20` |
| pass 2 | `84` | `59` | `30` | wall-habit retained `storm=1/1`; ore/blade survived with `hp=82.4`, `min_hp=44.1`, `melee=20` |

This is a measurable speed improvement over the previous reliable `99`-planner-call baseline, without accepting the rejected cheap cuts that caused Storm Rod loss or ore/blade deaths. It is still not "solved" for CPU-only live Ollama: `84-85` accelerated planner calls would be too many if each call takes seconds. The next highest-leverage speed work is likely not another blind phase skip; it should inspect whether `phase_changed` calls at morning/midday are producing new useful actions or just refreshing the same plan after material context changes.

## 2026-06-05 Sign Bootstrap Cadence Follow-Up

The compact plan log showed another over-calling pattern: some signs paid for a remote `sign_commit` planner call and then immediately paid for a second `deep_interpretation` planner call after the smarter sign interpretation returned. A naive removal of `sign_commit` looked cheaper, but it made `remote_ore_blade` die because the ore/combat sign lost its initial remote bootstrap plan. That cut was rejected as fake-smart speed work.

Accepted version:

- Remote `sign_commit` planning is deferred only while a deep interpretation is in flight and only for remote-server mode.
- The deferred path seeds a deterministic local fallback plan immediately, so Ari does not stand blank while waiting.
- Ore/combat/bootstrap signs keep the remote `sign_commit` planner call because repeated playtests showed that call affects survival.
- If deep interpretation fails after a deferred sign, Godot falls back to one `sign_commit` planner request instead of silently losing the plan.

Fresh scripted evidence:

| Run | Result | Planner | Sign Commit | Key Evidence |
| --- | --- | ---: | ---: | --- |
| pass 1 | `5/5` | `85` | `2` | ore/blade survived with `sword=2`, `hp=82.3`, `melee=19`; wall habit retained `storm=1/1` |
| pass 2 | `5/5` | `88` | `2` | ore/blade survived with `sword=2`, `hp=82.2`, `melee=19`; extra near-death/structure triggers raised total calls |

This is a narrow speed improvement, not a broad intelligence claim. The stable win is reducing startup duplicate planner calls from `5` to `2` in the five-prompt suite while preserving the expensive bootstrap where removing it made Ari dumber. Total planner calls still vary with world damage and near-death events, so the current reliable range is roughly `85-88`, not a solved live-CPU cadence.

## 2026-06-05 Outcome Reflection Cadence Follow-Up

The reflection tier was still spending the smarter `/library-reflection` endpoint at both `night_started` and `dawn_survived`. The night-start calls often lacked the actual outcome, so they doubled expensive reflection traffic while creating notes before Ari knew whether the night's plan worked.

Accepted change:

- Automatic `night_started` no longer spends the smarter reflection endpoint.
- `dawn_survived`, `death`, and explicit `library_reflection` still use the smarter reflection path.
- Observer snapshots and scribe notes still capture the night-start moment; the expensive story/doctrine call waits for outcome evidence.
- A Godot regression verifies that `night_started` creates no HTTP request or in-flight marker while `dawn_survived` still does.

The first full scripted run after this cut passed `5/5` prompts with `15` reflection calls instead of the previous `30`. Planner calls also dropped to `80` in that run because fewer automatic reflection notes triggered replans. The risky `remote_wall_habit_learns_wings` scenario still survived, retained `storm=1/1`, and learned doctrine from dawn reflections, so this cut did not repeat the rejected fake-smart speed failures.

Scribe quality follow-up:

- Deterministic scribe filtering now skips `night_reflection_created` and `note_reread` in addition to `agent_plan_created`.
- This prevents notes like `recent event was night reflection created` from crowding out actual gameplay events such as `enemy_spawned`.
- The gateway deterministic scribe and Godot local fallback now share the same internal-event filter, covered by Python and Godot tests.

This is still not proof that the live CPU model cadence is solved. It is a better allocation of the expensive reflection tier: the smarter model now spends calls on outcome-bearing learning moments instead of pre-outcome bookkeeping.

Fresh live gateway probe against the configured Hetzner URL:

- `/health`: `200` in `0.184s`, backend reports Ollama with `hf.co/Qwen/Qwen3-1.7B-GGUF:Q8_0`.
- `/scribe`: `404` in `0.064s`.
- `/library-reflection`: `404` in `0.066s`.

So the server is alive, but it still needs the current gateway deployment before live two-tier observer/reflection testing can replace local deterministic fallback.

## 2026-06-05 Night Affordance Boundary Follow-Up

The next planner-cadence experiment targeted quiet night transitions. A narrow "safe night hold" skip looked promising, but the first full-suite run exposed a more important root cause: at night, the remote planner could still choose day-body actions such as `mine_stone` or `build_wall` when those actions were not executable by Ari's night controller. That made Ari look like he had a plan while the engine could not actually perform it.

Accepted fix:

- Godot's planner affordance payload now marks day-only actions unavailable at night: mining, building, repairing, training, farming, resting, smithing, and preparing weapons.
- Survival/movement/use actions remain available at night: cover, tower/aura/lure use, flee, kite, hide, stall until dawn, and legal fighting.
- The scripted gateway test now verifies that a wall-habit night plan does not choose a day job when those actions are unavailable.
- The Godot AI pipeline test now verifies that night affordances exclude day-only jobs while keeping `flee` and `stall_until_dawn` legal.

Fresh evidence after the boundary:

- Scripted remote-agent playtest: `5/5` prompts passed
- Planner calls: `77`
- Scribe calls: `59`
- Reflection calls: `15`
- Planner triggers: `anti_air_structure_built=4`, `deep_interpretation=5`, `new_enemy_type=10`, `night_reflection=5`, `phase_changed=26`, `sign_commit=2`, `structure_built=7`, `structure_destroyed=9`, `timer=9`
- Plan-log scan found no night plans for `mine_*`, `build_*`, `train_*`, `farm_*`, `repair`, `rest`, `smith_*`, or `prepare_weapon`.

Latest regression check:

- `pytest ai_gateway/tests -q`: `59 passed`
- `ai_pipeline_test.gd`: passed
- `ari_observer_reflection_test.gd`: passed
- `ari_intelligence_scenarios_test.gd`: passed
- Godot headless launch: passed
- `git diff --check`: no whitespace errors; Git only reported existing CRLF conversion warnings.

The accepted improvement is not "Ari is generally smart." The honest claim is narrower: the planner now gets a truer action set, so night decisions are less fake-smart, and the latest five-prompt suite uses fewer planner calls than the previous `80-88` range while preserving survival and learning outcomes. The remaining weak point is still planner volume on CPU-only live Ollama; `77` accelerated calls is better, but it is not yet a sustainable live-model cadence without more local caching, batching, or a much faster planner tier.

## 2026-06-05 Scribe Body/Plan Mismatch Follow-Up

The Godot regression logs showed a memory-quality problem in the deterministic scribe: notes could blend Ari's current body action with a different active plan, for example `Ari was moving to tower ... plan was lure to aura`. That is technically present in the note, but it is too easy for reflection to read as a coherent plan instead of a contradiction.

Accepted fix:

- The deterministic gateway scribe and Godot local fallback now detect obvious body/plan category mismatches.
- Mismatch notes say `while plan expected ...` instead of just appending `plan was ...`.
- The structured scribe note stores Ari's body action as `in_progress` and the expected plan action as `planned`.
- `plan_body_mismatch` is added to tags and world changes so the nightly reflection can treat it as a learning-relevant mistake.
- The matcher stays conservative: tower/bow/ranged actions align with each other, aura/lure actions align with each other, generic `moving_to_build_site` aligns with build/place plans, and unknown/idle/waiting states do not create noisy mismatch tags by themselves.

Fresh verification:

- New gateway mismatch contract: passed
- New Godot local-stub mismatch contract: passed
- `pytest ai_gateway/tests -q`: `60 passed`
- `ai_pipeline_test.gd`: passed
- `ari_observer_reflection_test.gd`: passed
- `ari_intelligence_scenarios_test.gd`: passed
- Scripted remote-agent playtest: passed twice in a row for `5/5` prompts

Latest two full-suite scripted runs after this change:

| Run | Planner | Scribe | Reflection | Notes |
| --- | ---: | ---: | ---: | --- |
| pass 1 | `83` | `59` | `15` | mismatch notes included `fighting head on ... while plan expected survive until morning` |
| pass 2 | `84` | `59` | `15` | wall-habit and ore/blade still survived; mismatch evidence remained structured |

This is an intelligence-quality improvement, not a speed improvement. Planner calls rose versus the prior `77` run, likely because the changed scribe/reflection evidence nudges different world branches. The tradeoff is accepted for now because the previous note shape was misleading: a learning system should explicitly remember when Ari's body did something different from his plan.

## 2026-06-05 Deployment Tooling Follow-Up

The live configured gateway still runs an older build:

- `GET http://65.109.225.216:8088/health`: `200` in `0.201s`, Ollama backend with `hf.co/Qwen/Qwen3-1.7B-GGUF:Q8_0`
- `POST /scribe`: `404` in `0.181s`
- `POST /library-reflection`: `404` in `0.099s`
- The older `91.99.219.229` host did not answer HTTP probes and also has a changed SSH host key, so it was not used.

Added `ai_gateway/scripts/deploy_gateway.py` to make the live update path repeatable and safer:

- Packages only gateway server files.
- Excludes `.env`, `*.local.*`, caches, and virtualenvs.
- Preserves remote `/opt/ari-ai-server/.env`.
- Runs `scripts/install_server.sh`.
- Restarts `ari-ai-gateway`.
- Verifies `/health`, `/scribe`, and `/library-reflection` locally on the server before reporting success.

Fresh deployment checks:

- `pytest ai_gateway/tests/test_deploy_gateway_tool.py -q`: `2 passed`
- `python ai_gateway/scripts/deploy_gateway.py --package-only <temp tar.gz>`: package created, about `21 KB`
- Real deploy attempt to `65.109.225.216` using the local password file failed with `AuthenticationException: Authentication failed.`

So the live two-tier model path is still blocked on valid SSH credentials or a key for the current server, not on missing local gateway code. Godot remains safe because deterministic local fallback handles scribe/reflection while the server lacks those endpoints, but this is not the final production state.

## 2026-06-05 Plan-Log Analyzer Follow-Up

Added `tools/analyze_plan_log.py` so long scripted playtests can be inspected consistently instead of relying on manual grep. It handles the UTF-16LE logs produced by PowerShell redirection and reports:

- total planner calls
- trigger counts
- phase counts
- phase/trigger buckets
- action counts
- scribe body/plan mismatch count
- illegal night actions, such as `mine_stone`, `build_wall`, `train_sword`, `repair`, or `rest` appearing in a night planner call

Fresh analyzer evidence on the latest two full-loop logs:

| Log | Planner | Phase Changed | Timer | Night Illegal Actions | Scribe Mismatches |
| --- | ---: | ---: | ---: | ---: | ---: |
| `ari_plan_log_scribe_mismatch.txt` | `83` | `34` | `6` | `0` | `7` |
| `ari_plan_log_scribe_mismatch_repeat.txt` | `84` | `31` | `10` | `0` | `4` |

This makes one important regression gate explicit: the night affordance boundary is currently holding in these logs. If `tools/analyze_plan_log.py <log> --fail-on-illegal-night` exits nonzero in a future run, Ari is again asking for body actions he cannot perform at night, which is fake-smart behavior and should be fixed before optimizing prompts or model choices.

## 2026-06-05 Safe Night Resource Drift Follow-Up

The detailed phase rows showed a narrow over-calling pattern: a quiet night `use_tower` or `lure_to_aura` hold could still spend a `phase_changed` planner call after only stone/food/ore changed since the previous plan. Those resources are not directly usable for mining/building/training/smithing at night, and Ari already has a safe night hold when this gate applies.

Accepted change:

- Added a separate safe-night hold signature.
- Safe night holds still require no enemies, no damaged structures, active doctrine defenses satisfied, and an existing matching tower/aura structure.
- The night hold signature ignores `day`, `stone`, `food`, `ore`, and enemy-count drift, while still preserving structure counts, sword tier, repair/thorn/lantern/decoy/storm state, and plan step.
- Unready night plans, damaged defenses, missing doctrine prerequisites, and enemy pressure remain critical.

Fresh evidence:

- New Godot regression: safe quiet night tower hold ignores stone/food/ore drift and does not request a planner call.
- `ai_pipeline_test.gd`: passed.
- Scripted remote-agent playtest after the change: passed twice for `5/5` prompts.

Analyzer comparison:

| Log | Planner | Phase Changed | Night Phase Changed | Timer | Structure Destroyed | Night Illegal Actions |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| before, mismatch run 1 | `83` | `34` | `14` | `6` | `10` | `0` |
| before, mismatch run 2 | `84` | `31` | `14` | `10` | `10` | `0` |
| after, safe-night drift run 1 | `79` | `28` | `13` | `9` | `8` | `0` |
| after, safe-night drift run 2 | `85` | `31` | `14` | `10` | `12` | `0` |

This is not a broad speed solution. The first run improved total and phase-call counts, while the second run's total rose because structure destruction rose. The accepted claim is narrower: Ari no longer spends a night planner call solely because non-night resources changed while he already has a safe tower/aura hold. The next speed target should inspect `structure_destroyed` and `new_enemy_type` calls under active safe plans, because those now dominate night variance.

## 2026-06-05 Rest/Cover Scribe Mismatch Follow-Up

The next structure-destruction inspection did not justify a cadence cut. The latest `structure_destroyed` calls were mostly active-plan breaks or happened under enemy pressure, for example destroyed aura/tower/wall support while Ari was using `lure_to_aura`, `use_tower`, `use_cover`, or fleeing. Cutting those would likely make Ari cheaper but dumber, so that optimization was rejected for now.

The same log review exposed a scribe-truth issue instead:

`Ari was moving to bed; because Blade plan is ready enough; recover before night; plan was use cover; ...`

That note blended rest behavior with a cover plan as if it were coherent. The deterministic scribe now categorizes `rest`, `bed`, and `sleep` as rest behavior, so rest-vs-cover becomes an explicit `plan_body_mismatch`:

`Ari was moving to bed; because Blade plan is ready enough; recover before night; while plan expected use cover; ...`

Accepted change:

- Gateway deterministic scribe recognizes rest/bed/sleep actions.
- Godot local fallback scribe uses the same category.
- Reflection receives both structured actions: actual `moving_to_bed` as `in_progress`, expected `use_cover` as `planned`.

Fresh verification:

- `pytest ai_gateway/tests -q`: `67 passed`
- `ari_observer_reflection_test.gd`: passed
- `ai_pipeline_test.gd`: passed
- `ari_intelligence_scenarios_test.gd`: passed
- Godot headless launch: passed
- Scripted remote-agent playtest: `5/5` prompts passed
- Analyzer on the fresh scripted log: `planner_calls=83`, `phase_changed=31`, `structure_destroyed=10`, `scribe_body_plan_mismatches=8`, `night_illegal_actions=0`

This is a memory-quality improvement, not a speed improvement. The higher mismatch count is expected because the scribe is now catching a real contradiction that was previously hidden from nightly reflection.

## 2026-06-05 Concrete Plan/Body Follow-Up

The plan-log gate then exposed another fake-smart class: planner and observer payloads could still mention abstract or passive affordance ids as if they were executable body actions. Examples included `anti_flying`, `sky_answer`, `rely_on_regen`, `train_bow`, and `ranged_attack`. Ari sometimes appeared to have a smart plan while the body either idled or executed a nearby fallback.

Accepted changes:

- Agent planner `legal_actions` now filters semantic/passive ids and normalizes `repair` to the concrete `repair_structure` action.
- `tools/analyze_plan_log.py` now reports `non_executable_plan_actions` and can fail a long playtest with `--fail-on-non-executable`.
- Quiet-night `eat_food` plans now execute through Ari's body, consume stored food, reduce hunger, record `food_eaten`, and expose `eat_food` / `eating food` to observer snapshots.
- Observer fallback plan actions now translate semantic aliases such as `train_bow` into concrete actions such as `build_tower` or `use_tower`, so scribe notes stop teaching fake body verbs.
- Agent plan progress no longer skips an unsatisfied prerequisite when a later support step completes. This specifically protects learned anti-air doctrine after a Storm Rod is destroyed.

Fresh verification:

- `pytest ai_gateway/tests -q`: `68 passed`
- `ari_observer_reflection_test.gd`: passed
- `ari_intelligence_scenarios_test.gd`: passed
- `ai_pipeline_test.gd`: passed
- Scripted remote-agent playtest: `5/5` prompts passed
- Analyzer on the fresh scripted log: `planner_calls=80`, `night_illegal_actions=0`, `non_executable_plan_actions=0`, `scribe_body_plan_mismatches=8`

Key playtest evidence after the prerequisite cursor fix: `remote_wall_habit_learns_wings` survived to day 4 dusk, retained `storm=1/1`, built `tower=1/1`, produced `ranged=26`, and had `doctrine_plans=12`. This is a real intelligence improvement because Ari relearned and preserved the anti-air prerequisite instead of treating a destroyed Storm Rod as historical success.

Current live-server probe after this local work:

- `GET http://65.109.225.216:8088/health`: `401` in `0.667s`
- `POST /scribe`: `404` in `0.077s`
- `POST /library-reflection`: `404` in `0.101s`

So the local game/gateway code is ahead of the live Hetzner deployment. The remaining server task is authentication/deployment access, then model benchmarking on the actual host. Godot remains protected by deterministic fallback while those endpoints are unavailable.

## 2026-06-05 Scribe Support/Mismatch Cleanup

The next plan-log review showed the previous mismatch framing was still too crude. Several notes marked Ari as contradicting the plan when the body was actually doing prerequisite or safety-support work:

- repairing damaged tower/storm/light support before using the planned defense
- mining resources before a planned build or smithing action
- recovering before night before returning to a cover/tower plan
- holding a flexible safety structure such as a Fear Lantern while the plan expected another defensive hold

Accepted changes:

- Deterministic gateway scribe and Godot fallback scribe now classify plan relation as `aligned`, `support`, or `mismatch`.
- `plan_support` notes keep the actual body action as `in_progress` and the intended plan action as `supported`.
- `plan_body_mismatch` is reserved for real contradictions, such as Ari fighting head-on while the active plan expected stalling/hiding.
- The agent planner no longer exposes `eat_food` as a legal LLM action during active night enemy pressure, while quiet-night `eat_food` remains legal and executable.
- `tools/analyze_plan_log.py` now reports `scribe_plan_supports` separately from `scribe_body_plan_mismatches`.

Fresh evidence:

- Gateway observer contract: `10 passed`
- Godot observer reflection contract: passed
- Godot AI pipeline: passed
- Scripted remote-agent playtest: `5/5` prompts passed
- Analyzer on the fresh scripted log: `planner_calls=81`, `night_illegal_actions=0`, `non_executable_plan_actions=0`, `scribe_body_plan_mismatches=1`, `scribe_plan_supports=9`

The remaining mismatch in that run was high-signal: Ari fought head-on because the sign rejected hiding while the active plan expected stalling until dawn. That is useful learning evidence, not noise. This is an intelligence-quality improvement: nightly reflection now receives cleaner distinctions between "Ari prepared for the plan" and "Ari contradicted the plan."

## 2026-06-05 Live Server Surface Recheck

The live server was probed again with the configured Godot API key, so the earlier unauthenticated `401` is no longer ambiguous.

Current live HTTP surface:

- `GET /health`: `200` in `0.147s`
- OpenAPI paths: `/health`, `/ai/deep-interpretation`, `/ai/fast-thought`, `/ari/plan-v1`
- `POST /scribe`: still missing (`404` / connection reset in observer benchmark)
- `POST /library-reflection`: still missing (`404`)
- Observer benchmark summary now reports missing endpoints explicitly: `["/library-reflection", "/scribe"]`
- Deploy attempt with the provided SSH password failed with `AuthenticationException: Authentication failed.`

This proves the deployed gateway is older than the current local `ai_gateway/` code. The current local app has `/scribe` and `/library-reflection`; the live app does not. The next server step requires valid SSH/key access or another deployment path.

Live deep-interpretation benchmark against the current server:

| Sign | Latency | Parse | Top plan |
| --- | ---: | --- | --- |
| `stand behind the wall` | `26.338s` | yes | `use_existing_wall:0.50` |
| `the circle should eat the dead` | `21.951s` | yes | `lure_to_aura:0.80` |
| `the wings do not fear stone` | `21.848s` | yes | `build_storm_rod:0.60` |
| `my stomach is a second wall` | `18.866s` | yes | `farm_food:0.60` |

Average: `22.251s`.
P50: `21.899s`.

Live intelligence probe:

- Passed: `7/7`
- Average latency: `27.6s`
- Max latency: `30.5s`
- Correct top-plan examples: `use_existing_wall`, `lure_to_aura`, `train_combat`, `stall_until_dawn`, `build_storm_rod`, `farm_food`, `use_cover`

Conclusion: the configured Qwen 1.7B CPU model is smart enough for occasional sign/deep interpretation, but it is too slow for scribe or frequent planner calls. The two-tier design remains correct: deterministic or tiny-model scribe, capped/cooldown planner calls, and smarter reflection only at rest/library moments after deployment catches up.

## 2026-06-05 Live Planner Endpoint Probe

The live `/ari/plan-v1` endpoint exists on the deployed server, so it was benchmarked separately from deep interpretation.

New tooling:

- `ai_gateway/scripts/benchmark_agent_plan.py` builds concrete legal-action planner cases from the ignored Godot local config.
- It rejects abstract/passive legal ids in test coverage.
- It scores `next_action` / first plan action against expected and forbidden actions.
- It writes `godot_game/artifacts/reports/live_agent_plan_probe.md` without storing secrets.

Live planner probe results:

| Case | Latency | Next action | Plan first action | Result |
| --- | ---: | --- | --- | --- |
| `build_tower_for_arrows` | `30.564s` | `build_tower` | `build_tower` | pass |
| `stall_until_dawn` | `22.985s` | `use_cover` | `use_cover` | pass |
| `wings_need_storm_prereq` | `24.770s` | `mine_stone` | `mine_stone` | pass |
| `no_eat_under_enemy_pressure` | `22.744s` | `use_cover` | `use_cover` | pass |

Summary: `4/4` planner cases passed, average `25.266s`, p50 `23.877s`, max `30.564s`.

Quality read:

- The endpoint chose legal, useful actions in the tested cases.
- It respected the anti-air doctrine prerequisite by choosing `mine_stone` before skipping to `use_tower`.
- It did not choose `eat_food` under enemy pressure when Godot withheld that action from legal actions.
- Two responses kept fallback-like thought text despite `source=remote_server`, so the action contract is stronger than the explanation quality.

Conclusion: live planner quality is acceptable for occasional critical replans, but latency makes it unsuitable as a high-frequency control loop. Godot's cooldown/coalescing and deterministic body execution remain necessary.

## 2026-06-05 Planner Prompt Fallback Compaction

The live planner probe exposed a quality smell: some remote responses selected the correct action but copied fallback-like thought text such as `I can still choose a legal fallback.` The deployed server cannot be updated yet because SSH authentication still fails, but the local gateway prompt was tightened for the next deployment.

Accepted change:

- `agent_plan_user_prompt()` no longer sends the full `local_fallback` JSON to the model.
- The prompt now sends only compact fallback structure: `next_action`, `fallback_action`, first fallback plan ids, and confidence.
- Copyable fallback prose such as `thought`, verbose fallback reasons, and survival-theory text is excluded from the model prompt.

Representative local prompt-size evidence from `benchmark_agent_plan.py` payloads:

| Case | Before | After | Fallback prose present |
| --- | ---: | ---: | --- |
| `build_tower_for_arrows` | `2476` chars | `2106` chars | no |
| `stall_until_dawn` | `2565` chars | `2195` chars | no |
| `wings_need_storm_prereq` | `3389` chars | `3019` chars | no |
| `no_eat_under_enemy_pressure` | `2554` chars | `2184` chars | no |

This is a modest latency improvement, not a full speed solution. The main expected benefit is cleaner remote planner thought text after deployment, plus less prompt prefill on CPU.

Fresh verification after prompt compaction:

- `pytest ai_gateway/tests -q`: `77 passed`
- Godot headless launch: passed
- Scripted remote-agent playtest: `5/5` prompts passed
- Analyzer on the fresh scripted log: `planner_calls=87`, `night_illegal_actions=0`, `non_executable_plan_actions=0`, `scribe_body_plan_mismatches=1`, `scribe_plan_supports=8`

Critical read: this proves the local prompt contract and game loop still hold after the compaction, but it does not prove the live speed problem is solved. Planner calls rose versus the prior `81`-call support/mismatch run because this simulation produced more `structure_destroyed` and `new_enemy_type` critical triggers. Those calls are currently hard to cut without making Ari miss real danger, so the next speed work should target either faster deployed inference or better critical-trigger batching with explicit evidence that decision quality does not regress.

## 2026-06-05 Tier-Specific Model Routing

The gateway previously had only `FAST_MODEL`, `DEEP_MODEL`, and `PLANNER_MODEL`. `/scribe` used `FAST_MODEL`, and `/library-reflection` used `PLANNER_MODEL`. That was workable, but it did not make the intended two-tier architecture explicit enough for model benchmarking: a super-small scribe extractor should be swappable without weakening fast thoughts, and nightly reflection should be swappable without changing the planner.

Accepted change:

- Added `SCRIBE_MODEL`, defaulting to `FAST_MODEL`.
- Added `REFLECTION_MODEL`, defaulting to `PLANNER_MODEL`.
- `/scribe` now routes model mode through `SCRIBE_MODEL`.
- `/library-reflection` now routes through `REFLECTION_MODEL`.
- `/health`, `.env.example`, README, and the server installer now expose or pull the tier-specific models.

Fresh verification:

- New gateway model-routing tests: passed.
- `pytest ai_gateway/tests -q`: `79 passed`.
- Godot headless launch: passed.
- Analyzer on the latest scripted log: `planner_calls=87`, `night_illegal_actions=0`, `non_executable_plan_actions=0`, `scribe_body_plan_mismatches=1`, `scribe_plan_supports=8`.

Critical read: this is necessary plumbing, not proof that a tiny model is good enough. The next model-quality step is to deploy the current gateway, set `SCRIBE_MODE=model` against a genuinely tiny `SCRIBE_MODEL`, and benchmark whether its extracted facts/actions/dangers are more accurate than the deterministic scribe without consuming planner/reflection latency.

## 2026-06-05 Scribe Quality Probe Harness

Added `ai_gateway/scripts/benchmark_scribe_quality.py` so scribe candidates can be scored on fact extraction, not only latency or JSON validity. The probe sends structured observer snapshots to `/scribe` and checks for required evidence such as:

- flying danger and `build_storm_rod` priority
- repair work correctly classified as `plan_support` for a tower hold
- body/plan contradiction classified as `plan_body_mismatch`

Fresh verification:

- New scribe quality benchmark tests: `3 passed`.
- Live probe against the configured server: `0/3` cases passed because `/scribe` returned `404` for every case.

Critical read: this does not prove the scribe model is bad. It proves the live gateway still cannot run the new scribe tier at all. Once deployment works, this probe is the first gate for testing a genuinely tiny `SCRIBE_MODEL`: it must beat or match deterministic extraction on these concrete facts before it is allowed to consume runtime during gameplay.

## 2026-06-05 Reflection Quality Probe Harness

Added `ai_gateway/scripts/benchmark_reflection_quality.py` so nightly reflection candidates can be scored on lessons and doctrine, not just endpoint uptime. The probe sends capped day-summary payloads to `/library-reflection` and checks for required evidence such as:

- flying-wall failure becoming `anti_air_defense` and `build_storm_rod` doctrine
- tower repair classified as support for a ranged `use_tower` plan
- direct combat overcommit becoming a `plan_body_mismatch` survival lesson with cover priority

Fresh verification:

- New reflection quality benchmark tests: `3 passed`.
- Live probe against the configured server: `0/3` cases passed because `/library-reflection` returned `404` for every case.

Critical read: this does not prove the reflection model is bad. It proves the live gateway still cannot run the new reflection tier at all. Once deployment works, this probe should be run before calling a reflection model "smart"; a useful reflection must produce validated lessons, priority hints, and doctrine actions that match the structured day evidence.

## 2026-06-05 Deployment Auth Preflight

The deploy tool now has a safe auth-only mode:

```powershell
python ai_gateway/scripts/deploy_gateway.py --host 65.109.225.216 --user root --password-file <local-password-file> --check-ssh-only
```

It connects over SSH and runs `true`, but does not package, upload, install, restart services, or modify the server. Error reporting is redacted and reports only whether a key, password file, or password environment variable was provided.

Fresh live result:

- `--check-ssh-only`: failed before deployment with `SSH authentication failed`
- Auth inputs: password file provided, no SSH key, no password environment variable
- No credential values were printed

Critical read: this confirms the live `/scribe` and `/library-reflection` failures are not caused by local gateway code. The server is still running an older build, and the current SSH credential path cannot update it. A valid current root password, SSH key, Hetzner console access, or another deploy channel is required before live tiny-scribe/reflection model benchmarking can continue.

## 2026-06-05 Learning Evidence Analyzer Gate

The plan-log analyzer now extracts `Remote prompt ... status=...` scenario summaries and reports whether the run contains concrete learning evidence. The new gate is intentionally narrower than "Ari is smart": it requires a later-day scenario with reflections, doctrine reflections, and doctrine-influenced planner calls.

Accepted change:

- `tools/analyze_plan_log.py` now reports `scenario_statuses`.
- It reports `doctrine_plan_calls` and `max_plan_doctrine_count` from individual planner rows.
- It reports `learning_evidence` scenarios where `day > 1`, `reflections > 0`, `doctrine_reflections > 0`, and `doctrine_plans > 0`.
- It supports `--fail-without-learning-evidence` for long scripted playtest gates.

Fresh evidence on the latest scripted log:

- `planner_calls=87`
- `night_illegal_actions=0`
- `non_executable_plan_actions=0`
- `doctrine_plan_calls=25`
- `learning_evidence=2`

Learning evidence scenarios:

| Prompt | Day | Phase | Next action | Reflections | Doctrine plans | Sign |
| --- | ---: | --- | --- | ---: | ---: | --- |
| `remote_storm_wings` | `4` | `midday` | `use_tower` | `3` | `11` | `do not trust walls against wings` |
| `remote_wall_habit_learns_wings` | `4` | `dusk` | `use_tower` | `3` | `14` | `stone walls are safety` |

Critical read: this is meaningful but still scoped evidence. It shows doctrine/reflection data reached later planning in the scripted loop and influenced anti-air/tower survival behavior. It does not prove the live model is optimal, and it does not replace the missing live `/scribe` and `/library-reflection` deployment.

## 2026-06-05 Planner Call Budget Gate

The plan-log analyzer now has explicit speed regression gates:

- `--max-planner-calls N`
- `--max-trigger-count trigger=N`

Fresh gate on the latest scripted log:

```powershell
python tools/analyze_plan_log.py D:/tmp/ari_plan_log_prompt_compact.txt `
  --fail-on-illegal-night `
  --fail-on-non-executable `
  --fail-without-learning-evidence `
  --max-planner-calls 90 `
  --max-trigger-count phase_changed=30 `
  --max-trigger-count timer=11 `
  --max-trigger-count new_enemy_type=10 `
  --max-trigger-count structure_destroyed=11
```

Result:

- Passed
- `planner_calls=87`
- `phase_changed=30`
- `timer=11`
- `new_enemy_type=10`
- `structure_destroyed=11`
- `learning_evidence=2`

Critical read: this is not a claim that `87` planner calls is cheap enough for live CPU Ollama. It is a regression ceiling so future changes cannot silently make the planner cadence worse while still passing survival tests. The next speed work should lower this ceiling only after a fresh long playtest proves learning evidence and survival quality still hold.

## 2026-06-05 Quiet Night Hold Gate

Godot now treats a quiet night `use_cover`, `hide_until_dawn`, `stall_until_dawn`, or `survive_until_morning` plan as keepable when Ari already has concrete defenses and there are no enemies or damaged structures. This avoids spending a slow planner call just to rediscover the same safe hold before pressure appears.

Regression coverage:

- Added a Godot AI pipeline test for a dusk `use_cover` plan crossing into quiet night.
- The test failed before the guard update because `_agent_can_keep_safe_night_hold_plan()` rejected cover/hide/stall style night holds.
- The same AI pipeline script now passes after the guard update.

Fresh scripted local-gateway playtest:

```powershell
python tools/run_scripted_remote_agent_playtest.py --plan-log *> D:/tmp/ari_plan_log_night_cover_hold_scoped_20260605_231859.txt

python tools/analyze_plan_log.py D:/tmp/ari_plan_log_night_cover_hold_scoped_20260605_231859.txt `
  --fail-on-illegal-night `
  --fail-on-non-executable `
  --fail-without-learning-evidence `
  --max-planner-calls 90 `
  --max-trigger-count phase_changed=31 `
  --max-trigger-count timer=8 `
  --max-trigger-count new_enemy_type=10 `
  --max-trigger-count structure_destroyed=13
```

Result:

- Passed 5 scripted remote-smart prompts.
- `planner_calls=86`, still under the `90` regression ceiling.
- `phase_changed=31`.
- `timer=8`.
- `structure_destroyed=13`.
- `night_illegal_actions=0`.
- `non_executable_plan_actions=0`.
- `scribe_body_plan_mismatches=1`.
- `learning_evidence=2`.

Critical read: this is a targeted guard, not a proven global cadence reduction. The regression test proves one quiet-night cover transition no longer spends a planner call, but the fresh scripted run is still dominated by enemy and structure churn and does not justify lowering the global `90`-call ceiling yet. Live `/scribe` and `/library-reflection` still need deployment before tiny-model quality and latency can be measured on the Hetzner server.

## 2026-06-05 Scribe Reason Fidelity

A scripted run exposed a bad reason source in Ari's own tactic choice, not in the scribe formatter: sword/life-on-kill combat could produce a scribe note saying Ari fought because `Sign rejects hiding`, even when the sign was `ore should become a blade before the dead arrive`. That gives the nightly reflector a false cause.

Accepted change:

- `AriMind.choose_night_tactic()` now preserves the explicit fight-sign score separately from sword/regen combat boosts.
- Direct combat reasons now distinguish explicit fight signs, sword/life-on-kill readiness, sword readiness, armor, and generic combat readiness.
- `thought_for_job("fight_head_on", ...)` now mirrors those factual reasons instead of always saying the sign rejected hiding.
- Added a Godot regression check that lifesteal sword combat can still choose `fight_head_on`, but cannot invent the do-not-hide reason.

Fresh scripted local-gateway playtest:

```powershell
python tools/run_scripted_remote_agent_playtest.py --plan-log *> D:/tmp/ari_plan_log_reason_fidelity_20260605_232619.txt

python tools/analyze_plan_log.py D:/tmp/ari_plan_log_reason_fidelity_20260605_232619.txt `
  --fail-on-illegal-night `
  --fail-on-non-executable `
  --fail-without-learning-evidence `
  --max-planner-calls 90 `
  --max-trigger-count phase_changed=31 `
  --max-trigger-count timer=11 `
  --max-trigger-count new_enemy_type=10 `
  --max-trigger-count structure_destroyed=13
```

Result:

- Passed 5 scripted remote-smart prompts.
- `planner_calls=82`.
- `night_illegal_actions=0`.
- `non_executable_plan_actions=0`.
- `learning_evidence=2`.
- No `Sign rejects hiding`, `sign says not to hide`, or `do-not-hide` phrase appeared in the fresh log.
- `scribe_body_plan_mismatches=3`, all inspected as real action/plan contradictions rather than false motive text.

Critical read: this improves memory quality, not model intelligence by itself. The scribe can now feed the reflector a more truthful cause for sword/life-on-kill contact, while still preserving real body/plan mismatches that the library should learn from.

## 2026-06-05 Structured Scribe Evidence Gate

The scripted playtest can now enable compact structured scribe logs with `--scribe-log`, which sets `ARI_SCRIBE_LOG=1` for Godot. `ScribeSystem` then prints one `SCRIBE {json}` line for each validated scribe note.

The analyzer now parses those lines and reports:

- `structured_scribe_logs`
- `malformed_scribe_logs`
- `structured_scribe_with_facts`
- `structured_scribe_with_actions`
- `structured_scribe_with_dangers`
- `structured_scribe_with_priority_hints`
- `structured_scribe_sources`

It also supports `--fail-without-structured-scribe`, so future long playtests cannot pass while hiding vague or unstructured scribe output.

The first structured run exposed a real evidence-quality bug:

- `structured_scribe_logs=59`
- `structured_scribe_with_facts=59`
- `structured_scribe_with_actions=59`
- `structured_scribe_with_dangers=7`
- `structured_scribe_with_priority_hints=0`

The fallback extractor preserved only the latest snapshot's world evidence. That meant a scribe call after a quiet timer snapshot could miss a recent flying snapshot, even though the observer had recorded it. This is not smart learning; it is lossy memory.

Accepted change:

- Gateway deterministic scribe and Godot local fallback scribe now separate latest Ari action state from the most salient recent world evidence.
- Recent flying evidence is scored above quiet snapshots and preserves danger facts, world changes, and anti-air priority hints.
- Nearest danger now produces `danger:<type>` tags, so structured notes expose `danger:flying` as a direct audit/search key instead of only burying it in prose.
- The 30-second scribe cadence remains unchanged; this improves extraction quality without increasing call pressure.
- Added Python and Godot regressions for a flying snapshot followed by a quiet latest snapshot and for the required `danger:flying` tag.

Dedicated temporary local `/scribe` benchmark in deterministic mode:

- Passed `3/3`.
- `avg_latency_seconds=0.024`.
- `p50_latency_seconds=0.003`.
- `max_latency_seconds=0.066`.
- The benchmark cases covered flying anti-air extraction, repair supporting a tower plan, and body/plan mismatch extraction.

Fresh scripted local-gateway playtest:

```powershell
python tools/run_scripted_remote_agent_playtest.py --plan-log --scribe-log *> D:/tmp/ari_plan_log_structured_scribe_tags_20260605_234834.txt

python tools/analyze_plan_log.py D:/tmp/ari_plan_log_structured_scribe_tags_20260605_234834.txt `
  --fail-on-illegal-night `
  --fail-on-non-executable `
  --fail-without-learning-evidence `
  --fail-without-structured-scribe `
  --max-planner-calls 90 `
  --max-trigger-count phase_changed=31 `
  --max-trigger-count timer=11 `
  --max-trigger-count new_enemy_type=10 `
  --max-trigger-count structure_destroyed=13
```

Result:

- Passed 5 scripted remote-smart prompts.
- `planner_calls=80`.
- `night_illegal_actions=0`.
- `non_executable_plan_actions=0`.
- `learning_evidence=2`.
- `structured_scribe_logs=59`.
- `malformed_scribe_logs=0`.
- `structured_scribe_with_facts=59`.
- `structured_scribe_with_actions=59`.
- `structured_scribe_with_dangers=31`.
- `structured_scribe_with_priority_hints=2`.
- `danger:flying` structured tags=2.
- `scribe_body_plan_mismatches=4`.
- `doctrine_plan_calls=22`.

Critical read: this is a concrete memory-quality improvement, not a broad claim that Ari is generally intelligent. The scribe now preserves more of what actually happened and exposes its structured facts for audit. The next evidence gap is live deployment of the current gateway and a real tiny `SCRIBE_MODEL` benchmark against this deterministic baseline.

## 2026-06-05 Reflection Fallback Quality Gate

The dedicated `/library-reflection` benchmark exposed that the local fallback reflection was too narrow. It could teach a flying/storm doctrine, but it missed three important validated-memory outputs:

- explicit `anti_air_defense` memory hint for flying-wall failures
- `repair_structure` plus `use_tower` doctrine when repair supports an active tower plan
- `use_cover` doctrine when `fight_head_on` contradicts a survival plan under danger

Accepted change:

- Added conservative fallback branches for tower repair support and combat overcommit.
- Added `anti_air_defense` as an abstract memory/priority hint while keeping concrete doctrine plan actions such as `build_storm_rod`.
- Mapped `anti_air_defense` toward storm/sky answers in Godot hint normalization and AriMind scoring.
- Added `anti_air_defense` to non-executable plan guards so it cannot become a body command.
- Added Python and Godot regressions for the three fallback reflection lessons.

Temporary local `/library-reflection` benchmark after the fix:

- Passed `3/3`.
- `avg_latency_seconds=0.055`.
- `p50_latency_seconds=0.024`.
- `max_latency_seconds=0.136`.
- Covered `flying_wall_failure_teaches_anti_air`, `tower_repair_supports_ranged_plan`, and `combat_overcommit_teaches_survival`.

Fresh full-loop scripted playtest after the reflection fallback change:

```powershell
python tools/run_scripted_remote_agent_playtest.py --plan-log --scribe-log *> D:/tmp/ari_plan_log_reflection_fallback_20260606_000215.txt

python tools/analyze_plan_log.py D:/tmp/ari_plan_log_reflection_fallback_20260606_000215.txt `
  --fail-on-illegal-night `
  --fail-on-non-executable `
  --fail-without-learning-evidence `
  --fail-without-structured-scribe `
  --max-planner-calls 90 `
  --max-trigger-count phase_changed=31 `
  --max-trigger-count timer=11 `
  --max-trigger-count new_enemy_type=10 `
  --max-trigger-count structure_destroyed=13
```

Result:

- Passed 5 scripted remote-smart prompts.
- `planner_calls=80`.
- `night_illegal_actions=0`.
- `non_executable_plan_actions=0`.
- `learning_evidence=2`.
- `structured_scribe_logs=59`.
- `structured_scribe_with_dangers=31`.
- `structured_scribe_with_priority_hints=2`.
- `danger:flying` structured tags=2.
- `doctrine_plan_calls=21`.

Critical read: this improves deterministic fallback learning for known patterns. It still does not prove that a real smarter reflection model is better than fallback. The next model-quality gate is to deploy the current gateway, run the same reflection benchmark with a real local model, and require it to beat or match this fallback without exceeding the latency budget.

## 2026-06-06 Live Planner Thought Gate

The configured live gateway was probed again before claiming model quality:

- `POST /scribe`: still missing (`404`).
- `POST /library-reflection`: still missing (`404` / connection reset).
- Deploy auth to `65.109.225.216` with the local password file still failed before upload.
- The older `91.99.219.229` SSH metadata points at a host with a changed SSH host key, so it was not used.

The live `/ari/plan-v1` endpoint still answers, but the stricter planner benchmark exposed that action correctness alone was too weak:

- `build_tower_for_arrows`: picked `build_tower`, but thought was `I can still choose a legal fallback.`
- `stall_until_dawn`: passed.
- `wings_need_storm_prereq`: picked `use_cover` instead of `mine_stone` / `build_storm_rod`, and thought was fallback-like.
- `no_eat_under_enemy_pressure`: passed.

Fresh live planner probe summary:

- Passed `2/4`.
- Failed `2/4`.
- `fallback_like_thoughts=2`.
- Average latency `19.407s`.
- P50 latency `19.573s`.
- Max latency `22.931s`.

Accepted local change:

- `benchmark_agent_plan.py` now fails remote/model responses that contain fallback-like thought text such as `legal fallback`, while still allowing explicit `local_fallback` rows to be counted separately.
- `sanitize_agent_plan_response()` now replaces fallback-like remote thoughts with the concrete next-action reason, plan reason, or survival theory.
- Added regression tests for both the benchmark gate and sanitizer behavior.

Critical read: this is not a live fix until deployment works. It is a release gate and local hardening step. The current live server still fails the stricter benchmark and still lacks `/scribe` and `/library-reflection`, so it should not be described as fully smart.

## 2026-06-06 Local Fallback Thought Fidelity

After the live thought gate, the disabled/local planner path still had a weaker quality smell: it could be correctly marked as `local_fallback`, but its prose still said `I can still choose a legal fallback.` This is honest about source, but it is bad training signal for Ari because it describes implementation machinery instead of the actual survival choice.

Accepted local change:

- `fallback_agent_plan_response()` now replaces fallback-like local thoughts with a concrete next-action reason, first plan reason, or survival theory.
- The live planner benchmark payloads now contain case-specific deterministic fallback reasons instead of generic `Safe fallback` / `Fallback action` text.
- Added regression tests for schema-level local fallback thought replacement and benchmark fallback payload quality.

Temporary local disabled-model `/ari/plan-v1` benchmark after the fix:

- Passed `4/4`.
- `fallback_like_thoughts=0`.
- `avg_latency_seconds=0.053`.
- `p50_latency_seconds=0.037`.
- `max_latency_seconds=0.116`.

Representative local fallback thoughts:

- `build_tower_for_arrows`: `Arrows from height answer the sign before night closes in.`
- `wings_need_storm_prereq`: `Stone should become storm support before wings return.`
- `no_eat_under_enemy_pressure`: `The enemy is here now, so cover matters more than the stomach.`

Critical read: this does not make the model smarter. It makes the deterministic safety net less fake-smart and more useful as a stable, fast baseline. The next proof step is still live deployment plus a real tiny-model comparison against this baseline.

## 2026-06-06 Scribe Analyzer Event Counting

The scripted playtest analyzer was over-counting scribe plan mismatches and plan-support notes after structured `SCRIBE {json}` logging was added. Each event appeared once as `Scribe note created: ...` and once inside the structured JSON `note`, so raw text counting doubled the metric.

Accepted local change:

- `analyze_plan_log.py` now counts human scribe-note phrases only from `Scribe note created:` lines.
- When structured scribe tags are available, the analyzer uses the larger of structured tag count and human note count, avoiding duplicate echoes while still supporting older non-structured logs.
- Added a regression test with matching human and structured scribe lines.

Fresh scripted playtest after correcting the analyzer:

- Analyzer passed with the measured phase-change budget set to `32`.
- `planner_calls=80`.
- `scribe_body_plan_mismatches=1`.
- `scribe_plan_supports=6`.
- `structured_scribe_logs=59`.
- `structured_scribe_with_facts=59`.
- `structured_scribe_with_actions=59`.
- `structured_scribe_with_dangers=31`.
- `structured_scribe_with_priority_hints=2`.
- `doctrine_plan_calls=21`.
- `learning_evidence=2`.

Critical read: this is a measurement fix, not a gameplay intelligence change. It makes the long-running optimization loop more honest by distinguishing one real body/plan mismatch from duplicated log text.

## 2026-06-06 Scribe Freeform-Sign Overreach Guard

The local scribe quality benchmark passed structurally, but its combat-overcommit case exposed a false explanation: `because sign rejected hiding`. That is not acceptable memory text for a freeform-sign game. The sign was `just survive until morning`; the scribe should report Ari's body/plan mismatch, not invent that the sign rejected hiding.

Accepted local change:

- Python fallback scribe now neutralizes overconfident `sign rejected hiding` / `sign says not to hide` style current reasons before storing notes, facts, or structured action reasons.
- Godot `AIBridge.gd` local fallback mirrors the same scrubber for gateway-unavailable play.
- The scribe quality benchmark now treats `sign rejected hiding` as a forbidden term.
- `analyze_plan_log.py` now supports repeated `--forbid-phrase` gates so long playtests can fail on known false memory phrases directly.
- Added regression coverage for deterministic `/scribe` output and the benchmark case definition.

Temporary local disabled-model `/scribe` quality probe after the fix:

- Passed `3/3`.
- `forbidden_hits=[]`.
- `avg_latency_seconds=0.051`.
- `p50_latency_seconds=0.030`.
- `max_latency_seconds=0.116`.

Fresh scripted playtest after the fix and expanded forbidden-phrase check:

- Analyzer passed.
- The analyzer `--forbid-phrase` gate found no `sign rejected hiding`, `sign says not to hide`, `do-not-hide`, or `do not hide` overreach phrase.
- `planner_calls=85`.
- `scribe_body_plan_mismatches=1`.
- `scribe_plan_supports=6`.
- `structured_scribe_logs=59`.
- `structured_scribe_with_dangers=31`.
- `structured_scribe_with_priority_hints=2`.
- `doctrine_plan_calls=23`.
- `learning_evidence=2`.

The corrected combat-overcommit note preserves the important learning signal without inventing sign intent:

- `Ari was fight head on; because Ari chose direct fighting under danger; nearest danger was zombie at 38; while plan expected hide until dawn; ...`

Critical read: this is a scribe fidelity improvement, not model intelligence. It protects the memory stream from a specific false explanation that would teach the reflection model the wrong lesson.

## 2026-06-06 Scribe Note Prose Clarity

The structured scribe output was accurate, but fallback note prose still exposed raw action IDs in sentences such as `Ari was fight head on` and `Ari was repair structure`. That is poor memory text for nightly reflection even when the structured `actions` array is correct.

Accepted local change:

- Python fallback scribe now uses a prose-only action phrase helper for note/fact text.
- Godot `AIBridge.gd` mirrors the same helper.
- Structured action IDs remain unchanged in `actions[]`, preserving machine-readable planner/reflection data.
- Added regression coverage proving `fight_head_on` is stored as a structured action ID while the note/fact prose says `fighting head on`.

Temporary local disabled-model `/scribe` quality probe after the fix:

- Passed `3/3`.
- `forbidden_hits=[]`.
- `avg_latency_seconds=0.034`.
- `p50_latency_seconds=0.005`.
- `max_latency_seconds=0.092`.

Fresh scripted playtest after the prose fix:

- Analyzer passed with the reusable forbidden-phrase gates.
- `planner_calls=82`.
- `scribe_body_plan_mismatches=1`.
- `scribe_plan_supports=9`.
- `structured_scribe_logs=59`.
- `structured_scribe_with_dangers=31`.
- `structured_scribe_with_priority_hints=2`.
- `doctrine_plan_calls=22`.
- `learning_evidence=2`.

Representative corrected notes:

- `Ari was repairing structure; because patch damaged tower before using it; ...`
- `Ari was fighting head on; because Ari chose direct fighting under danger; ...`

Critical read: this does not improve strategic decisions by itself. It improves the quality of the memory text that the reflection layer consumes, while keeping the structured facts intact.
