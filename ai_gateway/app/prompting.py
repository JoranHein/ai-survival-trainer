from __future__ import annotations

import json

from .schemas import DeepInterpretationRequest, FastThoughtRequest


DEEP_SYSTEM_PROMPT = """You are Ari's sign interpreter in a top-down survival game.
The player writes a freeform sign as a godlike whisper.
Ari tries to obey through personality, current danger, memories, and current physical affordances.
Interpret semantically, including metaphor and emotion, then map to available tools.
Return minified JSON only, no markdown or analysis. Schema exactly: {"interpretation":string,"survival_theory":string,"emotion":string,"thought":string,"grounded_plan":[{"affordance_id":string,"priority":number,"reason":string}],"priority_hints":object,"sign_strength":number,"resonance":number}.
grounded_plan uses only current_affordances ids, max 2 items. priority_hints is an object with only chosen ids. Values are numbers 0..1. Keep text short.
Do not directly command movement or mutate game state."""


FAST_SYSTEM_PROMPT = """Write one short Ari thought for a survival game.
Return only valid JSON: {"thought":"string max 160 chars","resonance":0.0}.
Do not mutate game state."""


def deep_user_prompt(request: DeepInterpretationRequest) -> str:
    ari = request.ari
    world = request.world
    structures = ", ".join("%s:%s" % (item.type, item.status) for item in world.structures[:8]) or "none"
    available_affordances, unavailable_affordances = _compact_affordances(request)
    recent_thoughts = [str(item)[:120] for item in request.recent_thoughts[:3]]
    local_fallback = request.local_fallback
    return "\n".join(
        [
            "Interpret any sign semantically against current physical affordances; affordance ids are not the vocabulary of the sign.",
            "Examples: stand behind the wall => use_existing_wall/wait_behind_wall/use_cover, not build_wall. become a silent spider and make the dead walk into your web => lure_to_aura/build_trap/use_thorns/hide if listed. the moon hates cowards => emotional night fear, choose safe tactic. the circle should eat the dead => lure_to_aura/place_aura_orb. the wings do not fear stone => build_storm_rod/anti_flying/sky_answer/use_tower/ranged_attack, not wall or cover. my stomach is a second wall => farm_food/eat_food/eat/rest, not wall. build a mountain where arrows rain => build_tower/use_tower/ranged_attack/train_bow. think about what went wrong => reflect_library.",
            "Semantic cues for this sign: %s" % _semantic_cues(request),
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
            "current_affordances available: %s" % available_affordances,
            "current_affordances reason_unavailable: %s" % unavailable_affordances,
            "recent_thoughts: %s"
            % json.dumps(recent_thoughts, ensure_ascii=True, separators=(",", ":")),
            "latest_library_note: %s" % request.latest_library_note[:360],
            "Local fallback may be wrong: interpretation=%s top_hints=%s sign_strength=%.2f resonance=%.2f"
            % (
                str(local_fallback.interpretation)[:160],
                _top_hint_text(local_fallback.priority_hints),
                local_fallback.sign_strength,
                local_fallback.resonance,
            ),
            "Return JSON only. If a cue says not wall/cover, exclude build_wall/use_existing_wall/wait_behind_wall/use_cover unless no other listed affordance fits.",
        ]
    )


def fast_user_prompt(request: FastThoughtRequest) -> str:
    return json.dumps(request.model_dump(), ensure_ascii=True, separators=(",", ":"))


def _compact_affordances(request: DeepInterpretationRequest) -> tuple[str, str]:
    available: list[str] = []
    unavailable: list[str] = []
    for item in request.current_affordances:
        if item.available:
            available.append(item.id)
        else:
            reason = item.reason_unavailable.strip() or "unavailable"
            unavailable.append("%s(%s)" % (item.id, reason[:48]))
    return ",".join(available) or "none", ",".join(unavailable) or "none"


def _semantic_cues(request: DeepInterpretationRequest) -> str:
    sign = request.sign_text.lower()
    cues: list[str] = []
    if ("behind" in sign or "cover" in sign) and "wall" in sign and request.world.wall_count > 0:
        cues.append("existing wall cover; prefer use_existing_wall/wait_behind_wall/use_cover; build_wall=0")
    if "circle" in sign and ("dead" in sign or "eat" in sign or "teeth" in sign):
        cues.append("aura circle lure; prefer lure_to_aura/place_aura_orb")
    if any(word in sign for word in ["spider", "web"]):
        cues.append("web means lure/trap/patient avoidance; prefer lure_to_aura/build_trap/use_thorns/hide if listed")
    if any(word in sign for word in ["wing", "wings", "flying", "sky", "air"]):
        cues.append("sky threat; wall/cover fails; prefer build_storm_rod/anti_flying/sky_answer/use_tower/ranged_attack")
    if "arrow" in sign or "arrows" in sign or "mountain" in sign:
        cues.append("height and arrows; prefer build_tower/use_tower/ranged_attack/train_bow")
    if any(word in sign for word in ["stomach", "hunger", "hungry", "food"]):
        cues.append("body safety through food; prefer farm_food/eat_food/eat/rest; wall ids=0")
    if "time for myself" in sign or "quiet" in sign or "rest" in sign:
        cues.append("recovery; prefer rest")
    if "went wrong" in sign or "what went wrong" in sign or "think about" in sign:
        cues.append("reflection; prefer reflect_library")
    if "moon" in sign and "coward" in sign:
        cues.append("night fear metaphor; choose a safe fear-aware tactic from listed affordances")
    return "; ".join(cues) if cues else "none"


def _top_hint_text(priority_hints: dict[str, object]) -> str:
    candidates: list[tuple[str, float]] = []
    for key, value in priority_hints.items():
        try:
            number = float(value)
        except (TypeError, ValueError):
            continue
        if number > 0.0:
            candidates.append((str(key), max(0.0, min(1.0, number))))
    candidates.sort(key=lambda item: item[1], reverse=True)
    return ",".join("%s:%.2f" % item for item in candidates[:5]) or "none"
