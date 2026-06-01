# Gateway Contract Notes

Godot owns gameplay state and may add request context fields as the prototype evolves. The gateway request schema should therefore be tolerant of extra `ari`, `world`, structure, affordance, and fallback fields. Unknown request fields are ignored unless they are explicitly banned legacy or unsafe concepts such as `personality`, `era`, `origin_year`, `stubbornness`, `perseverance`, or `confusion`.

Modern deep-interpretation requests may also include top-level `rulebook`, `perception`, and `run_build` context. The rulebook is compact game knowledge; perception is Ari's current tactical report. The gateway may use these fields in prompting, but they are still advisory request context and must not mutate gameplay directly.

The response contract is different: model output must remain strict, sanitized, and clamped before Godot consumes it. Responses should continue to use only:

- `interpretation`
- `thought`
- `survival_theory`
- `emotion`
- `grounded_plan`
- `priority_hints`
- `sign_strength`
- `resonance`

This prevents future Godot payload expansion from causing HTTP 422 drift while keeping LLM output bounded and deterministic.
