from __future__ import annotations

import json

from .schemas import ALLOWED_PRIORITY_KEYS, DeepInterpretationRequest, FastThoughtRequest


DEEP_SYSTEM_PROMPT = """You are Ari's sign interpreter in a top-down survival game.
The player writes a freeform sign as a godlike whisper.
Ari is afraid of death and tries to obey through personality, current build, danger, and available tools.
Infer relationships and intent; do not merely keyword-match.
Return minified JSON only. Schema exactly: {"interpretation":string,"thought":string,"survival_theory":string,"priority_hints":object,"sign_strength":number,"resonance":number}.
priority_hints is an object whose values are numbers 0..1.
Do not directly command movement or mutate game state."""


FAST_SYSTEM_PROMPT = """Write one short Ari thought for a survival game.
Return only valid JSON: {"thought":"string max 160 chars","resonance":0.0}.
Do not mutate game state."""


def deep_user_prompt(request: DeepInterpretationRequest) -> str:
    ari = request.ari
    world = request.world
    structures = ", ".join("%s:%s" % (item.type, item.status) for item in world.structures[:8]) or "none"
    return "\n".join(
        [
            "Example sign: stand behind the wall",
            'Example JSON: {"interpretation":"Ari thinks the sign means to use an existing wall as cover, not build more walls.","thought":"The wall is already there. I should keep it between me and their teeth.","survival_theory":"use_cover","priority_hints":{"build_wall":0.2,"use_existing_wall":0.9,"wait_behind_wall":0.8,"use_cover":0.9},"sign_strength":0.75,"resonance":0.8}',
            "Other meanings: circle/light/orb can mean lure_to_aura; floor fights can mean build_trap; hurt/teeth/fight can mean train_combat or fight; tired/safe can mean rest or hide.",
            "Now interpret this game state.",
            "Sign: %s" % request.sign_text[:1000],
            "Ari: personality=%s run_build=%s hp=%.0f/%.0f current_job=%s current_reason=%s"
            % (
                json.dumps(ari.personality, ensure_ascii=True, separators=(",", ":")),
                json.dumps(ari.run_build, ensure_ascii=True, separators=(",", ":")),
                ari.hp,
                ari.max_hp,
                ari.current_job or ari.job,
                ari.current_reason or ari.reason,
            ),
            "World: day=%d phase=%s time_left=%.0f stone=%d walls=%d aura_orbs=%d enemies=%d structures=%s"
            % (
                world.day,
                world.phase,
                world.time_left,
                world.stone,
                world.wall_count,
                world.aura_orb_count,
                world.enemy_count,
                structures,
            ),
            "Local fallback: %s"
            % json.dumps(request.local_fallback.model_dump(), ensure_ascii=True, separators=(",", ":")),
            "Allowed priority keys: %s" % ", ".join(sorted(ALLOWED_PRIORITY_KEYS)),
            "Return JSON only.",
        ]
    )


def fast_user_prompt(request: FastThoughtRequest) -> str:
    return json.dumps(request.model_dump(), ensure_ascii=True, separators=(",", ":"))
