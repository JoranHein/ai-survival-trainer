# Real Smart Ari Design

Date: 2026-06-03

## Objective

Make Ari a genuinely goal-directed survival agent, not only a deterministic NPC colored by LLM text. "Real Smart Ari" means Ari observes the world, wants to survive the next night, forms plans, chooses legal actions, notices failures, updates beliefs, and lets those beliefs change future play. The Godot simulation still owns movement, combat, damage, building, collision, pathfinding, farming, mining, monsters, and all direct state mutation.

This document is a design brief and implementation roadmap only. It does not approve gameplay implementation.

## Project Constraints

- Real game code is Godot 4 and GDScript under `godot_game/`.
- The Python/Pygame prototype is reference only.
- The sign remains fully freeform. Do not add command slots or fixed sign fields.
- The LLM is Ari's mind, not his body.
- LLM output must be validated JSON with deterministic fallback.
- Godot must stay runnable after every implementation milestone.
- Work must proceed one mechanic or one integration point at a time.

## Current AI Audit

The current project already has a real, safe influence path from AI output to behavior:

- `World._build_ai_deep_interpretation_payload()` sends the sign, rulebook, perception, Ari state, world state, current affordances, recent thoughts, latest library note, and local fallback to the gateway.
- `AIBridge` validates remote deep interpretation into `interpretation`, `thought`, `survival_theory`, `emotion`, `grounded_plan`, `priority_hints`, `sign_strength`, and `resonance`.
- `World._on_ai_deep_interpretation_response()` merges validated `grounded_plan` and `priority_hints` into the live sign state.
- `World._get_ari_mind_context()` passes `priority_hints`, `grounded_plan`, and `lesson_priority_bias` into `AriMind`.
- `AriMind.choose_daytime_job()` and `AriMind.choose_night_tactic()` convert those hints and grounded plan items into concrete jobs such as `build_wall`, `use_cover`, `lure_to_aura`, `build_bow_tower`, `use_tower`, `build_storm_rod`, `mine_ore`, `smith_sword`, `farm_food`, `rest`, `reflect_library`, `hide_until_dawn`, and `flee`.
- Existing tests prove this path for cover, aura luring, dawn survival, smithing, anti-flying storm rod decisions, impossible plan fallthrough, and safe fallback.

What is genuinely behavior-influencing today:

- Sign interpretation can change Ari's job.
- Remote LLM output can become a grounded plan.
- Grounded plans are mapped through known affordances instead of direct world mutation.
- Ari can skip impossible plan items and fall through to feasible ones.
- Library notes can bias later priorities through `AriMemory.get_note_priority_bias()`.

What is still mostly illusion:

- Ari does not run an explicit agent loop of observe, plan, act, evaluate, learn.
- The LLM is mostly a sign interpreter, not a survival planner.
- `priority_hints` are flat weights, so learned notes cannot express conditional tactical knowledge like "if flying enemies exist, downweight walls and build storm rod".
- Library, sleep, life summaries, and permanent insights are not compiled into an active planner input with triggers, preconditions, confidence, and decay.
- There is no persistent current goal with success criteria, plan step state, failure reason, or replanning trigger.
- The gateway currently exposes deep interpretation and fast thought endpoints, while Godot has local stub plumbing for other reflection endpoints.

## Architecture Options

### Option A: Keep Deterministic AriMind, Add Better LLM Hints

This is the smallest extension. The LLM would keep returning `priority_hints` and `grounded_plan`, with richer prompt context.

Pros:
- Low implementation risk.
- Reuses current gateway and tests.
- Safe and cheap.

Cons:
- Still feels like weighted deterministic behavior.
- Cannot express conditional learned tactics well.
- Complex library instructions collapse into shallow numbers.

Verdict: useful as a fallback, not enough for Real Smart Ari.

### Option B: Behavior Tree or Utility AI With LLM Parameters

The deterministic planner stays in control, but the LLM adjusts tree conditions, utility weights, and flavor thoughts.

Pros:
- Predictable and testable.
- Works well for moment-to-moment execution.
- Fits Godot gameplay loops.

Cons:
- Ari is still primarily hand-authored.
- The LLM cannot own goal formation.
- Intelligence is limited by prewritten branches.

Verdict: good executor, not the main mind.

### Option C: GOAP or Utility Planner With LLM-Authored Goals and Doctrine

Godot defines legal actions, preconditions, costs, and effects. The LLM chooses goals and updates doctrine. A deterministic planner finds action sequences.

Pros:
- Strong safety.
- Good emergent recombination from known actions.
- Makes memory actionable through conditions and effects.

Cons:
- Requires maintaining action preconditions and effects.
- Can feel mechanical if the LLM only selects a goal.
- Needs careful testing so doctrine truly changes decisions.

Verdict: a strong component, especially for plan repair and deterministic fallback.

### Option D: LLM Planner Plus Deterministic Executor

The LLM runs at meaningful decision points and owns Ari's survival reasoning. It returns a validated goal, plan, next action, fallback, thought, and belief updates. Godot validates the action against the legal action interface and executes it through deterministic movement/combat/building systems. Ari keeps the plan until it succeeds, fails, becomes stale, or danger forces replanning.

Pros:
- Ari's mind can be genuinely goal-directed.
- The LLM chooses what Ari is trying to do, not just text flavor.
- Still respects the engine-owned body boundary.
- API calls are event-triggered rather than per-frame.
- Current `grounded_plan` infrastructure can evolve into this instead of being discarded.

Cons:
- Needs a new contract, planner state, replanning triggers, and tests.
- Requires strict validation and fallback.
- Requires careful UI/thought presentation so the player understands Ari's reasoning.

Verdict: recommended.

### Option E: Pure LLM Frame-by-Frame Brain

Every frame or very frequent tick asks the model what Ari should do.

Pros:
- Maximum apparent agency.

Cons:
- Too slow and too expensive.
- Hard to test.
- Unsafe unless heavily constrained, at which point it becomes Option D with worse latency.
- Frame-level game control belongs in Godot, not the model.

Verdict: reject.

## Recommendation

Build Real Smart Ari as an event-triggered LLM planner with a deterministic executor, supported by conditional doctrine memory and a GOAP/utility fallback.

The target loop:

1. Godot builds a compact observation: Ari state, world facts, current sign, current plan, recent outcomes, active doctrines, relevant lifetime notes, and legal actions.
2. The Ari Agent Brain chooses a survival goal, plan, next legal action, fallback action, and belief updates.
3. Godot validates the response against schema and legal actions.
4. AriMind or a new executor carries out the selected action deterministically.
5. Godot records outcomes: action completed, blocked, damage taken, structure destroyed, enemy type seen, death, dawn survival.
6. Replanning occurs only on meaningful triggers.
7. Library, sleep, death, and life summary convert experience into conditional doctrine that can affect later planning.

This is the strongest practical version of "AI inside Ari's brain": the model owns intention and reasoning; Godot owns embodiment and safety.

## Core Components

### AriObservation

Builds the compact state sent to the model. This should evolve from `AriPerception` and `World._build_ai_deep_interpretation_payload()`.

Required fields:

- `schema`: contract version.
- `decision_kind`: `morning_plan`, `day_replan`, `dusk_plan`, `night_emergency`, `post_failure_review`, or `library_doctrine`.
- `objective`: always includes `survive_next_night`; may include secondary needs such as `stay_fed`, `learn_from_failure`, `respect_sign_when_safe`.
- `sign`: freeform text plus current local/remote interpretation, never fixed command slots.
- `ari`: hp, fear, hunger, stamina, current job, current reason, run build, permanent progression summary.
- `world`: phase, time left, resources, structures, enemy counts, known enemy types, damaged structures.
- `perception`: tactical facts and safe moves.
- `current_plan`: active plan, current step, age, failures, and stale reason.
- `active_doctrines`: conditionally relevant learned rules.
- `recent_outcomes`: short event log.
- `legal_actions`: action ids, availability, costs, preconditions, expected effects, and reason unavailable.

### AriAgentBrain

New conceptual owner of Ari's deliberation. It can be implemented as a Godot-facing service wrapper around the existing gateway.

Responsibilities:

- Decide whether to use local fallback, cache, or remote LLM.
- Request a plan only at event triggers.
- Track request ids and ignore stale responses.
- Validate model output.
- Store the active plan.
- Expose `next_action` to AriMind or a planner executor.

### AriPlanExecutor

Deterministic executor that converts the selected `action_id` into real jobs. This can initially reuse `AriMind._job_for_affordance()` and later become a cleaner action adapter.

Responsibilities:

- Execute only known legal action ids.
- Reject actions whose preconditions are no longer true.
- Advance plan steps when success criteria are met.
- Mark failures with reason codes.
- Fall back to deterministic AriMind when the plan is invalid, stale, or missing.
- Apply emergency overrides for low HP, immediate contact, invalid shelter, or night danger.

### AriDoctrine

Persistent tactical memory compiled from library reflection, sleep consolidation, death review, and wisdom synthesis.

Doctrine is not prose. It is validated conditional survival knowledge:

- `when`: allowed predicates over world state.
- `bias`: action weights from -1.0 to 1.0.
- `plan_template`: optional action sequence with preconditions.
- `avoid`: downweighted actions under the condition.
- `confidence`: 0.0 to 1.0.
- `evidence`: source note/life/event ids.
- `decay`: how strongly the rule fades within a life if unconfirmed.

Example:

```json
{
  "id": "wings_ignore_walls",
  "title": "Walls do not stop wings",
  "when": {
    "enemy_type_present": "flying"
  },
  "bias": {
    "build_storm_rod": 0.9,
    "use_tower": 0.45,
    "train_bow": 0.35,
    "build_wall": -0.7
  },
  "plan_template": [
    {"action_id": "build_storm_rod", "if": "storm_rod_count == 0"},
    {"action_id": "use_tower", "if": "bow_tower_count > 0"},
    {"action_id": "flee", "if": "enemy_distance < 48"}
  ],
  "confidence": 0.85,
  "evidence": ["life_3_night_2_death"]
}
```

## Planner Contract

Recommended endpoint: `/ari/plan-v1`

Request:

```json
{
  "schema": "ari.agent.plan.v1",
  "decision_kind": "dusk_plan",
  "objective": {
    "primary": "survive_next_night",
    "secondary": ["respect_sign_when_safe", "preserve_hp"]
  },
  "sign": {
    "text": "build a mountain where arrows rain and the dead walk through light",
    "interpretation": "height, range, and aura luring"
  },
  "ari": {
    "hp_ratio": 0.82,
    "fear": 34.0,
    "hunger": 22.0,
    "stamina": 78.0,
    "current_job": "mine_stone",
    "run_build": {"points": {"bow": 5, "warding": 4, "building": 3}}
  },
  "world": {
    "day": 3,
    "phase": "dusk",
    "time_left": 42.0,
    "stone": 11,
    "ore": 0,
    "enemy_type_counts": {"zombie": 2, "runner": 1},
    "wall_count": 1,
    "aura_orb_count": 0,
    "bow_tower_count": 0,
    "storm_rod_count": 0,
    "damaged_structure_count": 0
  },
  "perception": {
    "tactical_facts": [
      "Runners punish open layouts; distance, cover, slowing, or aura luring matters."
    ],
    "available_safe_moves": ["use_cover", "flee", "rest"]
  },
  "current_plan": {
    "id": "plan_12",
    "goal": "prepare height and light",
    "step_index": 0,
    "age_seconds": 18.0,
    "failures": []
  },
  "active_doctrines": [],
  "recent_outcomes": [
    {"event": "structure_destroyed", "type": "wall", "phase": "night"}
  ],
  "legal_actions": [
    {"id": "mine_stone", "available": true, "cost": {}, "effect": "gain_stone"},
    {"id": "build_tower", "available": true, "cost": {"stone": 8}, "effect": "tower_count+1"},
    {"id": "place_aura_orb", "available": true, "cost": {"stone": 5}, "effect": "aura_orb_count+1"},
    {"id": "use_tower", "available": false, "reason_unavailable": "no tower exists"},
    {"id": "lure_to_aura", "available": false, "reason_unavailable": "no aura exists"},
    {"id": "use_cover", "available": true, "cost": {}, "effect": "reduce_ground_contact"},
    {"id": "flee", "available": true, "cost": {"stamina": 1}, "effect": "increase_distance"}
  ]
}
```

Response:

```json
{
  "schema": "ari.agent.plan.v1",
  "goal": "survive tonight by combining height, range, and light",
  "survival_theory": "The sign means distance first, then a killing circle.",
  "plan": [
    {
      "step_id": "build_height",
      "action_id": "build_tower",
      "reason": "A tower makes arrows real.",
      "success": "bow_tower_count > 0"
    },
    {
      "step_id": "make_light",
      "action_id": "place_aura_orb",
      "reason": "The dead must walk through light before reaching Ari.",
      "success": "aura_orb_count > 0"
    },
    {
      "step_id": "night_tactic",
      "action_id": "use_tower",
      "reason": "Height keeps teeth away while the aura does work.",
      "success": "dawn or no_enemy_pressure"
    }
  ],
  "next_action": {
    "action_id": "build_tower",
    "urgency": 0.82
  },
  "fallback_action": {
    "action_id": "use_cover",
    "reason": "If height is blocked, use the wall that exists."
  },
  "belief_updates": [
    {
      "key": "height_plus_light",
      "delta": 0.4,
      "reason": "The sign repeats arrows and light."
    }
  ],
  "thought": "If death has to climb and cross the light, I have time.",
  "confidence": 0.74,
  "replan_after_seconds": 12.0
}
```

Validation rules:

- `schema` must match.
- `next_action.action_id`, `fallback_action.action_id`, and all plan `action_id` values must be in `legal_actions`.
- `next_action` must be available unless the action has an executable preparation mapping, such as `build_tower` leading to `mine_stone` when stone is low.
- Text fields must be length-limited.
- `confidence` and `urgency` clamp to 0.0..1.0.
- Unknown fields ignored.
- Invalid JSON, timeout, unavailable action, empty plan, or stale request falls back to deterministic AriMind.
- Negative action influence is allowed only in doctrine bias, not direct world mutation.

## Replanning Triggers

Do not call the model every frame. Replan on:

- Sign changed.
- Morning begins.
- Dusk begins.
- Night begins.
- New enemy type seen.
- Ari takes significant damage.
- HP or fear crosses danger threshold.
- Current plan step completes.
- Current plan step is blocked.
- Structure used by current plan is destroyed.
- New doctrine is created in library or sleep.
- Death or dawn survival review.
- Plan age exceeds `replan_after_seconds` during active danger.

Frame-to-frame behavior remains deterministic: Ari keeps executing the current action until a trigger occurs.

## Safety Boundaries

- The model never sends coordinates, spawned objects, HP changes, resource changes, or direct node mutations.
- The model chooses action ids from `legal_actions`.
- Godot owns target selection through named policies such as nearest cover, nearest aura, safest tower, closest resource, or current threat.
- Emergency guardrails can override the model:
  - low HP and close enemy -> flee or hide;
  - no valid tower -> cannot use tower;
  - no aura -> cannot lure to aura;
  - night phase -> cannot start long daytime build actions unless explicitly allowed;
  - impossible action -> use fallback or deterministic AriMind.
- The sign is evidence, not a command slot. Ari may respect, misunderstand, resist, or reinterpret it based on fear and survival evidence.
- API keys stay server-side in the gateway. Godot only uses the game gateway key.
- All remote outputs are logged as sanitized summaries for debugging, not as trusted state.

## Model Strategy

Recommended playtest path:

- Use OpenAI API through the existing gateway for the planner during development.
- Use `gpt-5.4-mini` for major planner calls and doctrine compilation.
- Use `gpt-5.4-nano` for cheap short thoughts, simple classification, and maybe high-frequency replan prechecks.
- Keep deterministic local fallback always available.
- Later benchmark local GPU/vLLM only if API costs or dependency are unacceptable.

Reasoning:

- The current CPU-only Ollama report showed optimized deep interpretation still around 14-21 seconds with `qwen3:1.7b`; that is too slow for agentic play unless calls are rare and hidden behind waiting states.
- OpenAI official model docs list `gpt-5.4-mini` as a fast mini model with structured outputs and `gpt-5.4-nano` as a fast cheap model for high-volume tasks.
- OpenAI structured outputs are a better fit than loose JSON mode for agent contracts because schema adherence matters.
- Output token count dominates latency, so planner responses should be compact and bounded.
- Prompt caching can lower input cost and latency when repeated static prefixes are kept identical.

Approximate API costs with current official per-1M token prices:

- `gpt-5.4-mini`: $0.75 input, $4.50 output.
- `gpt-5.4-nano`: $0.20 input, $1.25 output.
- A compact planner call around 1,000 input tokens and 250 output tokens costs about $0.0019 on mini or $0.0005 on nano.
- 1,000 compact planner calls cost about $1.90 on mini or $0.51 on nano.
- A playtest run with 5 to 20 planner calls is usually well below $0.05 on mini, assuming no long-context prompts or tool calls.

Server guidance:

- For API mode, a small CPU server is enough because inference is remote.
- Hetzner CPU cloud examples from the official price-adjustment page show CCX33 around $73.99/month in listed US pricing, but API mode does not need that much CPU unless hosting other services.
- A dedicated GPU server such as GEX44 is listed at about 212.30 EUR or $252.10/month after the 2026 price adjustment. That is only rational if local GPU inference is a product requirement, not just a playtest convenience.
- Avoid CPU-only local LLM as the main smart Ari path unless the planner only runs overnight or asynchronously.

## Testing Strategy

Contract tests:

- Gateway rejects missing or invalid `schema`.
- Gateway validates `next_action` and plan actions against legal actions.
- Unknown actions are dropped or cause fallback.
- Unavailable direct actions trigger fallback or preparation mappings.
- Invalid JSON returns deterministic fallback.
- Text fields are bounded.
- Negative doctrine bias is accepted only in doctrine contracts, not direct action plans.

Godot unit tests:

- A valid `ari.agent.plan.v1` response with `build_tower` makes Ari build a tower.
- If the same plan has no stone, Ari mines stone first only if the executor supports that preparation.
- A plan for `use_tower` falls back when no tower exists.
- A flying-enemy doctrine downweights wall building and promotes storm rod only when flying enemies are present.
- The same flying doctrine stays inactive when only zombies are present.
- Low HP near enemy overrides an aggressive model plan.
- Plan step completion advances to the next step.
- Structure destruction marks the current plan stale and triggers replanning.
- Library doctrine created after a failure changes the next day's selected action.
- Remote timeout preserves current local behavior.

Scenario tests:

- "Build a mountain where arrows rain and the dead walk through light" should produce tower/aura/range behavior over multiple decisions.
- "The wings do not fear stone" after a flying death should produce storm/range preparation and avoid wall-only preparation.
- "Do not hide, make the sword drink life" should mine ore, smith sword, train, and only fight when readiness/HP thresholds permit.
- "Just survive until morning" should prioritize cover, fleeing, stalling, and dawn survival over unnecessary kills.

Live playtest metrics:

- Planner call count per run.
- Average and p95 planner latency.
- Fallback rate.
- Invalid action rate.
- Plan completion rate.
- Replan trigger distribution.
- Survival nights by sign and doctrine.
- Cases where Ari's action changed because of active doctrine.

## Milestone Roadmap

### Milestone 1: Plan Contract Only

Add a new planner contract and validation tests without changing live gameplay. Use local stub responses first.

Deliverable:

- `ari.agent.plan.v1` request/response schema.
- Gateway/Godot validation for legal actions.
- Deterministic fallback on bad responses.
- Tests prove invalid output cannot mutate behavior.

### Milestone 2: Planner State Adapter

Store an active Ari plan in Godot and expose it to the existing AriMind path, but only for one or two existing actions.

Deliverable:

- Active plan with step index, age, failure reasons, and current action.
- Replan triggers for sign change and phase change.
- Tests prove a model plan changes the job.

### Milestone 3: Doctrine Memory v1

Add conditional doctrine validation and activation. Start with flying vs wall/storm behavior.

Deliverable:

- `AriDoctrine` data structure.
- Allowed predicate vocabulary.
- Active doctrine bias feeds into `lesson_priority_bias` or the new planner context.
- Tests prove doctrine is conditional and changes action choice.

### Milestone 4: Library and Sleep Compile Doctrine

Library reflection and sleep consolidation produce both prose notes and validated doctrine updates.

Deliverable:

- Reflection note remains human-readable.
- Doctrine update is machine-readable and safe.
- Rest/sleep can strengthen, weaken, or carry forward doctrine.
- Tests prove overnight learning changes next-day choices.

### Milestone 5: Event-Triggered Remote Planner

Call the remote smart model at meaningful triggers. Keep current deterministic behavior during waiting or failure.

Deliverable:

- Planner endpoint in gateway.
- OpenAI structured output or strict schema mode.
- Request ids and stale response handling.
- Latency/fallback logging.
- Playtest config for mini/nano model split.

### Milestone 6: Plan Repair and Outcome Learning

Ari reviews action outcomes and updates beliefs after blocked plans, damage, structure destruction, dawn survival, and death.

Deliverable:

- Outcome records tied to plan steps.
- Failure review prompt.
- Doctrine confidence updates.
- Tests prove repeated failure weakens bad doctrine or adds counters.

### Milestone 7: Player-Facing Mind Readability

Expose Ari's current goal, plan thought, and doctrine influence through thought bubbles and existing panels without turning the sign into command fields.

Deliverable:

- Short thought when Ari commits to a plan.
- Short thought when Ari abandons a plan.
- Debug-visible reason for active doctrine influence.
- No in-app fixed sign fields.

## Definition of Real Smart Ari

The architecture is successful when these are true:

- Ari can choose a plan that was not hardcoded for the exact sign text.
- Ari's plan is constrained to legal actions but selected by an AI survival mind.
- Ari persists with a plan across frames without per-frame LLM calls.
- Ari abandons or repairs a plan when live evidence contradicts it.
- A library or sleep lesson can change future behavior conditionally, not just as a flat weight.
- Repeated survival and failure change Ari's future decisions.
- The game remains playable when the model is offline, slow, wrong, or expensive.

## Implementation Stop Gate

Do not start implementation until the user explicitly approves a first milestone. The recommended first implementation is Milestone 1: Plan Contract Only.

