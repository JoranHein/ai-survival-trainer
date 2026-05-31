# Codex Workflow

This project should advance through small, runnable milestones.

## Default Process

1. Read `AGENTS.md`.
2. Read `docs/GAME_VISION.md` before design decisions.
3. Identify the current milestone.
4. Keep the scope to one mechanic or one integration point.
5. Preserve the Python prototype unless the user explicitly asks for prototype work.
6. Keep `godot_game/` runnable after every change.
7. Add or update focused tests when behavior changes.
8. Include manual test steps in the final report.
9. Commit only working, coherent milestones when asked to commit.

## Milestone Discipline

Good milestones are small and playable:

- Ari can move.
- Ari can read one freeform sign.
- One enemy type can threaten Ari.
- One structure can be built and damaged.
- One memory event is recorded and displayed.

Bad milestones try to build whole systems at once:

- all enemies
- all upgrades
- all AI
- all building
- all UI
- all progression

## Godot Rules

- Use Godot 4.
- Use GDScript.
- Do not use C#.
- Prefer small scripts with clear responsibility.
- Use placeholder visuals first.
- Keep scenes and scripts under `godot_game/`.
- Use data files later for balance values when the design stabilizes.

## AI Rules

- The LLM is Ari's mind, not his body.
- Never let LLM output directly mutate game state.
- Validate JSON before using model output.
- Always keep deterministic fallback.
- Keep local fallback behavior testable without a server.

## Visual Review

When visual changes matter, capture screenshots or screen recordings later in the workflow and review them with `docs/VISUAL_REVIEW_CHECKLIST.md`.

Do not judge a visual milestone only by code inspection. The screen must answer whether Ari is readable, the danger is readable, and the sign-god fantasy is visible.

## Manual Test Steps

Every gameplay milestone should report manual test steps such as:

1. Open the main scene in Godot.
2. Verify the scene starts without errors.
3. Interact with the new mechanic.
4. Observe Ari's behavior and HUD.
5. Confirm existing debug or memory behavior still works.

## Refactor Rules

- Do not do giant rewrites.
- Do not refactor unrelated Python prototype files.
- Refactor only when it directly supports the current milestone.
- Keep unrelated cleanup for separate tasks.

## Completion Standard

A milestone is complete only when:

- the requested behavior exists
- the game still runs
- relevant tests pass
- manual test steps are documented
- no unrelated systems were implemented
- no Python prototype files were changed without explicit permission
