# LLM Self-Learning Reflection Design

## Objective

Make Ari's learning loop capable of noticing and correcting recurring bad behavior through reflection, without prewriting a special-case fix for each behavior.

The motivating example is Ari repeatedly running between building, wall use, and building again without meaningful progress. The implementation should not hardcode "if Ari oscillates, stop oscillating." Instead, the game should expose clear, neutral evidence that the behavior happened. The LLM reflection should decide what the pattern means, write a lesson or doctrine, and future planning should change because of that learned doctrine.

## Core Constraint

The LLM is Ari's mind, not Ari's body.

The engine may observe, summarize, validate, and constrain. The engine may not let LLM output directly mutate the world or bypass legal action validation. The engine may also not pre-author the actual lesson for this kind of behavior. Deterministic code can say:

- Ari switched between `build_wall` and `repair_structure` 6 times.
- No new structure was completed during that window.
- Time to night decreased by 38 seconds.
- The active plan did not advance.
- Danger did or did not materially change.

Deterministic code should not say:

- Therefore Ari must stop oscillating.
- Therefore Ari should finish a wall first.
- Therefore the correct doctrine is commit_to_one_build.

That conclusion belongs to the LLM reflection.

## Non-Goals

- Do not directly patch Ari's movement or job selection to suppress this specific wall/building loop.
- Do not add command slots or restrict freeform sign syntax.
- Do not let reflection output execute jobs, spend resources, place structures, heal Ari, or mutate state directly.
- Do not make deterministic fallback the main learning brain.
- Do not create a one-off "wall oscillation" feature that cannot generalize to other repeated bad patterns.

## Current System Fit

The existing pipeline already has most of the required structure:

1. World and Ari body produce actions, jobs, resources, danger, damage, structures, and events.
2. Observer snapshots capture compact state.
3. Scribe turns recent snapshots into factual notes.
4. Day summary collects worked, went_wrong, misunderstood, candidate lessons, and evidence ids.
5. Library reflection creates lifetime notes and doctrines.
6. Doctrines are validated and added to AriDoctrine.
7. Planner payloads include active doctrines and recent outcomes.
8. Body still executes only validated legal actions.
9. Outcome feedback can strengthen or weaken doctrines.

The missing piece is a general evidence layer for behavioral patterns across time, especially repeated action switching with low progress.

## Proposed Design

Add a neutral "behavior evidence" layer that detects patterns in recent action history and passes them through scribe, day summary, and reflection.

The system should track enough action history to describe:

- action transitions
- repeated switching
- abandoned jobs
- completed jobs
- blocked jobs
- resource deltas
- structure count and repair deltas
- danger changes
- time spent
- active plan changes
- whether progress happened after the switches

This evidence is not a doctrine. It is a factual input to reflection.

## Behavior Evidence Contract

Introduce a compact evidence object, embedded in observer snapshots and scribe/reflection payloads:

```json
{
  "schema": "ari.behavior_evidence.v1",
  "window_seconds": 45.0,
  "primary_pattern": "repeated_action_switching",
  "actions_seen": ["build_wall", "repair_structure", "use_cover"],
  "transition_count": 6,
  "completion_count": 0,
  "blocked_count": 1,
  "abandoned_count": 4,
  "progress_delta": {
    "structures": 0,
    "stone": -2,
    "repairs": 0,
    "kills": 0,
    "hp": 0
  },
  "context": {
    "phase": "midday",
    "enemy_count_before": 0,
    "enemy_count_after": 0,
    "nearest_danger_changed": false,
    "active_plan_changed": false
  },
  "evidence_ids": ["day2_0421_action_switch", "day2_0430_action_switch"],
  "neutral_summary": "Ari switched between build_wall, repair_structure, and use_cover 6 times in 45 seconds; no build or repair completed."
}
```

Allowed `primary_pattern` values should stay general:

- `repeated_action_switching`
- `repeated_blocked_action`
- `abandoned_before_progress`
- `resource_spend_without_progress`
- `danger_ignored`
- `panic_safety_loop`
- `plan_changed_without_world_change`

These names describe the shape of evidence, not the fix.

## Scribe Behavior

Scribe should include behavior evidence as clear facts. It should not explain the lesson for the LLM.

Example scribe note:

> Ari switched between building wall, repairing structure, and using cover 6 times in 45 seconds. The active plan stayed on defense, enemies did not change, and no build or repair completed.

Structured fields:

- `facts`: include the neutral summary.
- `actions`: include the repeated actions and statuses.
- `world_changes`: include `repeated_action_switching` and any concrete deltas.
- `mistake_candidates`: may say `repeated switching happened without progress`.
- `lesson_candidates`: should stay open-ended, for example `review whether repeated switching helped survival`.
- `priority_hints`: should not bias the exact fix.

The scribe is a witness, not the teacher.

## Reflection Behavior

The LLM reflection prompt should explicitly ask the model to inspect behavior evidence and decide whether it represents:

- useful adaptation to changing danger
- prerequisite progress
- safety substitution
- indecision or panic
- repeated blocked action
- wasted travel or time
- a bad plan
- a good plan interrupted by missing resources

The reflection response can then create a doctrine, but the doctrine must use existing validated affordance ids and remain advisory.

Example possible LLM-created doctrine:

```json
{
  "id": "reflection_finish_defense_before_switching",
  "summary": "When danger and resources are stable, Ari should finish the current defensive build step before switching to another defensive task.",
  "when": {
    "phase_not": "night",
    "danger_changed": false,
    "pattern": "repeated_action_switching"
  },
  "bias": {
    "build_wall": 0.18,
    "repair_structure": -0.08,
    "use_cover": -0.05
  },
  "plan": [
    {
      "affordance_id": "build_wall",
      "priority": 0.55,
      "reason": "Complete the current defense if no new danger changed the plan."
    }
  ],
  "confidence": 0.38
}
```

This is only an example of what the LLM might produce, not a hardcoded fallback doctrine.

## Planner Integration

Planner payloads should include active behavior-related doctrines and the latest behavior evidence. The planner prompt should ask:

- Does this doctrine apply to current conditions?
- Did the previous behavior evidence show low progress?
- Is there a stable reason to continue the current step?
- Has danger changed enough to justify switching?

The planner may bias toward continuing a step, choosing a prerequisite, or changing course. The engine still validates the action id against legal actions.

## Outcome Feedback

A doctrine only counts as real learning if later behavior and outcomes support it.

Track whether a doctrine-influenced plan:

- reduces repeated switching in the next comparable window
- completes the intended build/repair/use step
- preserves or improves survival state
- avoids increasing damage, missed deadlines, or resource waste

The learning trace should say what changed, for example:

> Doctrine-influenced plan completed build_wall after prior repeated switching. Switching count dropped from 6 to 1 in a comparable window.

If the doctrine leads to worse outcomes, confidence should fall.

## Deterministic Fallback Role

Deterministic fallback should support testing and resilience, but not replace LLM learning.

Allowed fallback behavior:

- validate schemas
- preserve behavior evidence
- create generic reflection if the LLM is unavailable
- avoid crashing when reflection fails
- optionally say "behavior evidence was observed but no remote reflection interpreted it"

Disallowed fallback behavior:

- generate a specific anti-oscillation doctrine
- decide the cause of the behavior
- bias future action choices as if a reflection lesson happened

## Testing Strategy

Add tests that prove the learning loop exists without hardcoding the lesson:

1. A Godot scenario where Ari alternates defensive tasks without progress.
2. Assert behavior evidence records repeated switching and low progress.
3. Assert scribe note states the pattern factually.
4. Assert reflection payload includes behavior evidence.
5. In a mocked LLM response, return a doctrine that discourages unproductive switching.
6. Assert doctrine validation stores it.
7. Assert planner payload includes the doctrine.
8. Assert later planner choice changes because of that doctrine.
9. Assert body still executes only legal actions.
10. Assert deterministic fallback does not invent the specific doctrine when the LLM is absent.

Manual testing should include watching Ari after the reflection: before learning, he may bounce between tasks; after the LLM-created doctrine enters planning, he should visibly commit longer to the learned better step unless danger or resources change.

## Success Criteria

The feature is working when:

- Scribe clearly describes repeated low-progress behavior without prescribing the answer.
- The LLM reflection can turn that evidence into a doctrine.
- The doctrine is validated, stored, and cited in later planner payloads.
- Ari's later behavior changes because the planner receives and follows the learned doctrine.
- A learning trace connects the evidence, reflection, doctrine, later action, and outcome.
- The same mechanism can represent other patterns, not only wall/building oscillation.

## Open Implementation Notes

Use small increments:

1. Add behavior evidence collection and compact schema.
2. Thread it into observer snapshots and scribe payloads.
3. Update scribe prompts/validation to preserve neutral evidence.
4. Update reflection prompt/schema to consider behavior evidence.
5. Update planner payload/prompt to use learned doctrines from reflection.
6. Add focused mocked-LLM tests for the end-to-end loop.
7. Add one manual playtest scenario for visible before/after learning.

The first implementation milestone should stop once the evidence reaches reflection and mocked LLM doctrine changes later planning. Real model prompt tuning can follow after that proof exists.
