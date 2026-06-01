# AI Survival Trainer Agent Instructions

These rules are permanent project guidance for future Codex sessions.

## Project Shape

- The Python/Pygame prototype is reference only. Do not delete, rewrite, refactor, or "modernize" Python prototype files unless the user explicitly asks for prototype work.
- The real game is Godot 4 with GDScript under `godot_game/`.
- Do not use C# for game code.
- Keep `godot_game/` runnable after every change.
- Prefer simple placeholder art first: circles, rectangles, labels, and readable debug text.

## Design Authority

- Read `docs/GAME_VISION.md` before making design decisions.
- Use `docs/VISUAL_REVIEW_CHECKLIST.md` when reviewing screenshots or visual changes.
- Use `docs/CODEX_WORKFLOW.md` for development process and milestone discipline.

## Core Identity

- AI Survival Trainer is an AI psychology survival game.
- The player is a godlike whisperer who writes freeform text onto a sign.
- Ari interprets the sign through fear, danger, run instincts, memories, lifetime notes, library reflections, and rest integration.
- The objective is to understand this Ari well enough to write a sign that unlocks his best emergent survival behavior.

## Freeform Sign Rule

- Never turn the sign into command slots.
- Never create fixed fields such as DAY GOAL, NIGHT RULE, or SURVIVAL RULE.
- Never restrict sign syntax.
- The player must be able to write anything.
- Ari may misunderstand anything.

## Development Rules

- Work one milestone at a time.
- Implement one mechanic at a time.
- Do not build future systems early.
- Do not do large unrelated refactors.
- Prefer readable small scripts.
- Use data files later for balance.
- Every task should include manual test steps.
- Keep changes commit-worthy.
- Never try to build the entire game in one prompt.

## AI/LLM Boundary

- The LLM is Ari's mind, not his body.
- The game engine owns movement, combat, building, collision, pathfinding, damage, farming, mining, monsters, and direct game state mutation.
- LLM output may propose interpretation, belief deltas, priorities, emotional lines, and survival theories.
- Never let LLM output directly mutate game state.
- Always validate JSON.
- Always keep a deterministic fallback.
