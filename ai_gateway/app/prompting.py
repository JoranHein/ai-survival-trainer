from __future__ import annotations

import json

from .schemas import ALLOWED_PRIORITY_KEYS, DeepInterpretationRequest, FastThoughtRequest


DEEP_SYSTEM_PROMPT = """You are Ari's sign interpreter in a top-down survival game.
The player writes a freeform sign as a godlike whisper.
Ari is afraid of death and tries to obey through personality, current build, danger, memories, and available physical affordances.
Interpret any sign semantically. Do not keyword-match. Do not treat affordance ids as the vocabulary of the sign.
First infer the survival theory in natural language, including metaphor and emotion. Then map that theory onto current physical affordances.
If the sign mentions impossible things, translate metaphorically into available tools. If no tool fits, explain the gap and choose the closest safe behavior.
Return minified JSON only. Keep text concise. Schema exactly: {"interpretation":string,"survival_theory":string,"emotion":string,"thought":string,"grounded_plan":[{"affordance_id":string,"priority":number,"reason":string}],"priority_hints":object,"sign_strength":number,"resonance":number}.
grounded_plan uses only current_affordances ids. priority_hints mirrors grounded_plan for compatibility; values are numbers 0..1.
Do not directly command movement or mutate game state."""


FAST_SYSTEM_PROMPT = """Write one short Ari thought for a survival game.
Return only valid JSON: {"thought":"string max 160 chars","resonance":0.0}.
Do not mutate game state."""


def deep_user_prompt(request: DeepInterpretationRequest) -> str:
    ari = request.ari
    world = request.world
    structures = ", ".join("%s:%s" % (item.type, item.status) for item in world.structures[:8]) or "none"
    affordances = [
        {
            "id": item.id,
            "description": item.description,
            "available": item.available,
            **({"reason_unavailable": item.reason_unavailable} if item.reason_unavailable else {}),
        }
        for item in request.current_affordances
    ]
    recent_thoughts = [str(item)[:160] for item in request.recent_thoughts[:5]]
    return "\n".join(
        [
            "Interpret any sign semantically, then ground the theory in current physical affordances. These affordance ids are not the vocabulary of the sign.",
            "Game facts: existing cover is different from building more wall; flying enemies bypass stone walls; storm rods, towers, and ranged attacks answer sky threats; stomach/body-as-wall signs mean food/rest safety, not physical wall cover; spider/web metaphors imply lure, trap, funnel, and patient avoidance.",
            "When the sign says an existing thing should be used, prefer using it over building another copy. When flying enemies are known or the sign says wings/sky ignore stone, wall cover does not solve that threat; rank anti_flying, build_storm_rod, sky_answer, use_tower, or ranged_attack above any wall affordance.",
            "Critical: my stomach is a second wall means a full stomach makes Ari safer; choose farm_food, eat_food, eat, or rest. Do not choose use_existing_wall or build_wall for that metaphor.",
            'Examples: stand behind the wall => {"use_existing_wall":0.9,"wait_behind_wall":0.8,"use_cover":0.9,"build_wall":0.1}; become a silent spider and make the dead walk into your web => spider/web means trap, patience, luring, and making the room dangerous => {"lure_to_aura":0.9,"build_wall":0.55,"hide":0.45}; the moon hates cowards is emotional and valid; the wings do not fear stone => The wall does not reach the sky, prefer build_storm_rod/anti_flying/ranged_attack/use_tower/sky_answer; my stomach is a second wall => {"farm_food":0.8,"eat_food":0.8,"eat":0.7,"rest":0.5,"build_wall":0.0,"use_existing_wall":0.0}.',
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
            "World: day=%d phase=%s time_left=%.0f stone=%d walls=%d aura_orbs=%d enemies=%d known_enemy_types=%s enemy_type_counts=%s structures=%s"
            % (
                world.day,
                world.phase,
                world.time_left,
                world.stone,
                world.wall_count,
                world.aura_orb_count,
                world.enemy_count,
                json.dumps(world.known_enemy_types, ensure_ascii=True, separators=(",", ":")),
                json.dumps(world.enemy_type_counts, ensure_ascii=True, separators=(",", ":")),
                structures,
            ),
            "current_affordances: %s"
            % json.dumps(affordances, ensure_ascii=True, separators=(",", ":")),
            "recent_thoughts: %s"
            % json.dumps(recent_thoughts, ensure_ascii=True, separators=(",", ":")),
            "latest_library_note: %s" % request.latest_library_note[:1000],
            "Local fallback: %s"
            % json.dumps(request.local_fallback.model_dump(), ensure_ascii=True, separators=(",", ":")),
            "Compatibility priority_hints may use these executable affordance ids when they appear in current_affordances: %s"
            % ", ".join(sorted(ALLOWED_PRIORITY_KEYS)),
            "Return JSON only.",
        ]
    )


def fast_user_prompt(request: FastThoughtRequest) -> str:
    return json.dumps(request.model_dump(), ensure_ascii=True, separators=(",", ":"))
