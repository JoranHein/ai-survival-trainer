# Real Smart Ari Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable Real Smart Ari vertical slice where Ari receives a validated agent plan, persists it across decisions, executes only legal Godot-owned actions, and uses conditional doctrine memory to change real behavior.

**Architecture:** Extend the existing gateway and Godot AI bridge instead of replacing them. The gateway adds `ari.agent.plan.v1` request/response validation and fallback. Godot adds active plan state, a small deterministic executor adapter over existing AriMind affordance jobs, and `AriDoctrine` rules that compile learned notes into conditional action bias.

**Tech Stack:** Godot 4 GDScript, FastAPI/Pydantic Python gateway, pytest, existing Godot SceneTree tests.

---

## File Map

- Create `ai_gateway/tests/test_agent_plan_contract.py`: Python contract tests for `/ari/plan-v1`, schema validation, legal action filtering, fallback, and OpenAI model call shape.
- Modify `ai_gateway/app/schemas.py`: Pydantic models and sanitizers for `AgentPlanRequest`, `AgentPlanResponse`, and fallback plan responses.
- Modify `ai_gateway/app/prompting.py`: compact agent planner system/user prompts.
- Modify `ai_gateway/app/model_client.py`: `call_plan_model()` that reuses the deep model unless `PLANNER_MODEL` is configured.
- Modify `ai_gateway/app/main.py`: FastAPI endpoint `/ari/plan-v1`.
- Create `godot_game/scripts/ari/AriDoctrine.gd`: validated conditional doctrine rules and active bias/plan extraction.
- Modify `godot_game/scripts/autoload/AIBridge.gd`: endpoint name, local stub response, response validation, and `request_agent_plan()`.
- Modify `godot_game/scripts/ari/AriMemory.gd`, `LessonBook.gd`, `ReflectionSystem.gd`, and `SleepConsolidation.gd`: preserve validated doctrine fields from notes and sleep plans.
- Modify `godot_game/scripts/ari/AriMind.gd`: accept `agent_grounded_plan` ahead of sign plan and allow negative lesson bias to downweight actions.
- Modify `godot_game/scripts/world/World.gd`: active plan state, plan request triggers, doctrine activation, planner context, and local/offline fallback.
- Modify `godot_game/tests/ari_intelligence_scenarios_test.gd` and `godot_game/tests/ai_pipeline_test.gd`: Godot tests for plan execution, fallback, and anti-flying doctrine.

## Task 1: Gateway Agent Plan Contract

**Files:**
- Create: `ai_gateway/tests/test_agent_plan_contract.py`
- Modify: `ai_gateway/app/schemas.py`
- Modify: `ai_gateway/app/prompting.py`
- Modify: `ai_gateway/app/model_client.py`
- Modify: `ai_gateway/app/main.py`

- [ ] **Step 1: Write failing pytest contract tests**

Cover these behaviors:

```python
def test_agent_plan_endpoint_accepts_legal_plan(client, monkeypatch):
    # model returns build_tower/use_cover; endpoint returns schema, goal, plan, next_action, fallback_action.
```

```python
def test_agent_plan_endpoint_falls_back_on_unknown_action(client, monkeypatch):
    # model returns spawn_dragon; endpoint returns deterministic fallback legal action.
```

```python
def test_agent_plan_endpoint_preserves_failure_safe_fallback(client, monkeypatch):
    # model call raises; endpoint returns local_fallback and no illegal actions.
```

- [ ] **Step 2: Run failing tests**

Run:

```powershell
python -m pytest ai_gateway/tests/test_agent_plan_contract.py -q
```

Expected: failures because `/ari/plan-v1` and agent plan schema do not exist.

- [ ] **Step 3: Implement minimal Python contract**

Add schema classes, `sanitize_agent_plan_response()`, `fallback_agent_plan_response()`, prompts, `call_plan_model()`, and `/ari/plan-v1`.

- [ ] **Step 4: Run Python tests**

Run:

```powershell
python -m pytest ai_gateway/tests/test_agent_plan_contract.py ai_gateway/tests/test_model_client.py ai_gateway/tests/test_gateway_contract.py -q
```

Expected: all selected Python tests pass.

## Task 2: Godot Bridge Validation and Local Stub

**Files:**
- Modify: `godot_game/scripts/autoload/AIBridge.gd`
- Test: `godot_game/tests/ai_pipeline_test.gd`

- [ ] **Step 1: Write failing Godot bridge tests**

Add tests that call private validation helpers directly:

```gdscript
var result: Dictionary = bridge.call("_validate_agent_plan", valid_data, payload, true, "remote_server")
_assert(result.get("next_action", {}).get("action_id", "") == "build_tower", "valid agent plan should preserve legal next action")
```

```gdscript
var failed: Dictionary = bridge.call("_validate_agent_plan", {"next_action": {"action_id": "spawn_dragon"}}, payload, true, "remote_server")
_assert(failed.get("next_action", {}).get("action_id", "") == "use_cover", "illegal plan action should fall back")
```

- [ ] **Step 2: Run failing Godot test**

Run the available Godot test command for `ai_pipeline_test.gd`.

Expected: failure because `_validate_agent_plan` and `request_agent_plan` do not exist.

- [ ] **Step 3: Implement bridge contract**

Add `agent_plan` endpoint, local stub, validation, legal action filtering, and callback request method.

- [ ] **Step 4: Re-run bridge tests**

Expected: new bridge tests pass.

## Task 3: AriDoctrine Conditional Memory

**Files:**
- Create: `godot_game/scripts/ari/AriDoctrine.gd`
- Modify: `godot_game/scripts/ari/AriMemory.gd`
- Modify: `godot_game/scripts/ari/LessonBook.gd`
- Modify: `godot_game/scripts/ari/ReflectionSystem.gd`
- Modify: `godot_game/scripts/ari/SleepConsolidation.gd`
- Test: `godot_game/tests/ai_pipeline_test.gd`

- [ ] **Step 1: Write failing doctrine tests**

Test that flying doctrine activates only with flying enemies:

```gdscript
var doctrine = AriDoctrineScript.new()
doctrine.add_doctrine({"id": "wings_ignore_walls", "when": {"enemy_type_present": "flying"}, "bias": {"build_storm_rod": 0.9, "build_wall": -0.7}})
var active: Dictionary = doctrine.get_active_bias({"enemy_type_counts": {"flying": 1}})
_assert(float(active.get("build_storm_rod", 0.0)) > 0.0, "flying doctrine should promote storm rod")
_assert(float(active.get("build_wall", 0.0)) < 0.0, "flying doctrine should downweight walls")
```

- [ ] **Step 2: Run failing doctrine tests**

Expected: failure because `AriDoctrine.gd` does not exist.

- [ ] **Step 3: Implement doctrine validation**

Add `add_doctrine()`, `add_doctrines()`, `get_active_bias(context)`, and `get_active_plan(context)`. Support predicates `enemy_type_present`, `phase`, `min_day`, `max_hp_ratio`, and `structure_destroyed`.

- [ ] **Step 4: Preserve doctrine in notes**

Store `doctrines` arrays in Ari memory, lesson book, reflection, and sleep validation. Clamp text and numbers. Unknown predicate keys are ignored.

- [ ] **Step 5: Re-run doctrine tests**

Expected: doctrine tests pass.

## Task 4: Active Plan Execution in AriMind

**Files:**
- Modify: `godot_game/scripts/ari/AriMind.gd`
- Test: `godot_game/tests/ari_intelligence_scenarios_test.gd`

- [ ] **Step 1: Write failing active plan tests**

Add tests proving:

```gdscript
var decision := ari_mind.choose_daytime_job(_base_mind_context({"agent_grounded_plan": [{"affordance_id": "build_tower", "priority": 0.95, "reason": "Agent plan wants height."}]}))
_assert(decision.get("job", "") == "build_bow_tower", "active agent plan should drive real tower building")
```

```gdscript
var decision := ari_mind.choose_daytime_job(_base_mind_context({"lesson_priority_bias": {"build_wall": -0.8, "build_storm_rod": 0.9}, "enemy_type_counts": {"flying": 1}}))
_assert(decision.get("job", "") == "build_storm_rod", "negative wall doctrine and positive storm doctrine should change real behavior")
```

- [ ] **Step 2: Run failing active plan tests**

Expected: failure because `agent_grounded_plan` is ignored and negative bias is clamped away.

- [ ] **Step 3: Implement AriMind support**

Merge `agent_grounded_plan` before `grounded_plan`. Allow `_lesson_bias()` to return -1.0..1.0 and apply negative bias to preferences with clamp.

- [ ] **Step 4: Re-run scenario tests**

Expected: new tests pass and existing intelligence scenario tests still pass.

## Task 5: World Active Plan and Event Triggers

**Files:**
- Modify: `godot_game/scripts/world/World.gd`
- Test: `godot_game/tests/ai_pipeline_test.gd`

- [ ] **Step 1: Write failing World tests**

Add tests proving:

```gdscript
world.call("_on_agent_plan_response", request_id, valid_agent_plan)
_assert(world.get("agent_grounded_plan").size() > 0, "valid agent plan should become active grounded plan")
```

```gdscript
var context: Dictionary = world.call("_get_ari_mind_context")
_assert(context.has("agent_grounded_plan"), "AriMind context should include active agent plan")
```

- [ ] **Step 2: Run failing tests**

Expected: failure because active plan state and callbacks do not exist.

- [ ] **Step 3: Implement world planner state**

Add `agent_plan`, `agent_grounded_plan`, `_agent_plan_request_id`, `_request_agent_plan()`, `_build_agent_plan_payload()`, `_on_agent_plan_response()`, and `_clear_agent_plan()`.

- [ ] **Step 4: Wire safe triggers**

Call `_request_agent_plan()` on sign commit, phase change, AI deep interpretation completion, new enemy type, structure destruction, near death, library note creation, and restart if sign exists. If AI is disabled, use local stub through `AIBridge` or deterministic local plan generation.

- [ ] **Step 5: Re-run World tests**

Expected: active agent plan is included in context and changes real AriMind decisions.

## Task 6: Doctrine Into Real Play

**Files:**
- Modify: `godot_game/scripts/world/World.gd`
- Modify: `godot_game/scripts/ari/AriMemory.gd`
- Test: `godot_game/tests/ari_intelligence_scenarios_test.gd`

- [ ] **Step 1: Write failing scenario test**

Create a scenario where a learned flying doctrine changes the job:

```gdscript
world.ari_doctrine.add_doctrine({"id": "wings_ignore_walls", "when": {"enemy_type_present": "flying"}, "bias": {"build_storm_rod": 0.9, "build_wall": -0.7}})
var decision := world.get("ari_mind").choose_daytime_job(world.call("_get_ari_mind_context"))
_assert(decision.get("job", "") == "build_storm_rod", "learned flying doctrine should change Ari's real job")
```

- [ ] **Step 2: Run failing scenario test**

Expected: failure if doctrine is not integrated into `_get_lesson_priority_bias()` or mind context.

- [ ] **Step 3: Implement doctrine integration**

World owns `ari_doctrine := AriDoctrine.new()`. Add note/sleep doctrines to it. Merge active doctrine bias with memory note bias in `_get_lesson_priority_bias()`. Add active doctrine plan into `agent_grounded_plan` when relevant.

- [ ] **Step 4: Re-run scenario tests**

Expected: anti-flying doctrine affects real job choice only with flying enemies.

## Task 7: Verification and Manual Playtest Notes

**Files:**
- Modify: `docs/superpowers/specs/2026-06-03-real-smart-ari-design.md` only if implementation discoveries require a small clarification.

- [ ] **Step 1: Run Python tests**

Run:

```powershell
python -m pytest ai_gateway/tests -q
```

- [ ] **Step 2: Run Godot tests**

Run the available Godot test commands for:

```text
godot_game/tests/ai_pipeline_test.gd
godot_game/tests/ari_intelligence_scenarios_test.gd
```

- [ ] **Step 3: Run syntax/build checks**

Run:

```powershell
python -m compileall ai_gateway/app
git diff --check
```

- [ ] **Step 4: Document manual test steps in final report**

Manual playtest:

1. Open the Godot main scene.
2. Enable remote AI only if `godot_game/data/ai_config.local.json` and the gateway API key are configured.
3. Start a run and write `build a mountain where arrows rain and the dead walk through light`.
4. Observe Ari form a plan thought and build/use tower or light using legal actions.
5. Create or simulate a flying threat after a library lesson.
6. Observe learned doctrine promote storm/range and downweight wall-only behavior.
7. Disable the gateway or remove API key and verify local fallback remains playable.

