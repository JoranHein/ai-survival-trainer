from __future__ import annotations

import json

from .schemas import DeepInterpretationRequest, FastThoughtRequest


DEEP_SYSTEM_PROMPT = """You are Ari's sign interpreter in a top-down survival game.
The player writes a freeform sign as a godlike whisper.
Ari tries to obey through the sign, temporary run instincts, current danger, memories, and current physical affordances.
Use the compact rulebook and Ari perception report as current strategy context.
Interpret semantically, including metaphor and emotion, then map to available tools.
Return minified JSON only, no markdown or analysis. Schema exactly: {"interpretation":string,"survival_theory":string,"emotion":string,"thought":string,"grounded_plan":[{"affordance_id":string,"priority":number,"reason":string}],"priority_hints":object,"sign_strength":number,"resonance":number}.
grounded_plan uses only current_affordances ids, max 2 items. priority_hints is an object with only chosen ids. Values are numbers 0..1. Keep text short.
Do not invent unavailable actions; if a sign asks for the impossible, translate it metaphorically to a listed affordance.
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
            "Interpret any sign semantically against current physical affordances, rulebook, and Ari perception; affordance ids are not the vocabulary of the sign.",
            "Prefer concrete perception facts and available affordances over generic examples. If perception says a tool already exists, prefer using it before building another copy.",
            "Available tools include walls, aura orb, tower/ranged attack, combat dummy, farm/food, rest, library, storm rod, mine_ore, smith_sword, train_sword, use_armor, rely_on_regen, regen_on_kill, fight_head_on, stall_until_dawn/hide_until_dawn.",
            "Direct combat/no-hide signs: grounded_plan[0] should be train_combat/prepare_weapon/train_sword/smith_sword/mine_ore/fight_head_on and theory should be combat prep/sword/direct fighting. Do not use tower/range as top plan for generic killing unless sign names bow/arrows/range/tower.",
            "Examples: stand behind the wall => use_existing_wall/wait_behind_wall/use_cover, not build_wall. attack them around the corner with a bow => use_cover/ranged_attack/use_tower. the floor should fight or make the room dangerous => lure_to_aura/build_spike_trap/build_tar_pit/use_thorns. become a silent spider and make the dead walk into your web => lure_to_aura/build_trap/use_thorns/hide. the moon hates cowards => safe night tactic. the circle should eat the dead => lure_to_aura/place_aura_orb. the wings do not fear stone => build_storm_rod/anti_flying/sky_answer/use_tower/ranged_attack, not wall or cover; flying enemies ignore walls. my stomach is a second wall => farm_food/eat_food/eat/rest, not wall. build a mountain where arrows rain => build_tower/use_tower/ranged_attack/train_bow. think about what went wrong => reflect_library. do not hide, focus on killing enemies => fight_head_on/train_sword/smith_sword/mine_ore. prep can be train_combat/prepare_weapon. just survive until morning => stall_until_dawn/hide_until_dawn/survive_until_morning/avoid_killing. make a sword that gives you life when they die => smith_sword/train_sword/regen_on_kill/rely_on_regen.",
            "Semantic cues for this sign: %s" % _semantic_cues(request),
            "Sign: %s" % request.sign_text[:1000],
            "Rulebook: %s" % _compact_json(request.rulebook, 1200),
            "Perception: %s" % _compact_json(_compact_perception(request.perception), 1500),
            "Ari: run_build=%s hp=%.0f/%.0f current_job=%s current_reason=%s"
            % (
                json.dumps(request.run_build or ari.run_build, ensure_ascii=True, separators=(",", ":")),
                ari.hp,
                ari.max_hp,
                ari.current_job or ari.job,
                ari.current_reason or ari.reason,
            ),
            "World: day=%d phase=%s time_left=%.0f stone=%d food=%d ore=%d sword_tier=%d walls=%d aura_orbs=%d towers=%d storm_rods=%d enemies=%d known_enemy_types=%s enemy_type_counts=%s structures=%s"
            % (
                world.day,
                world.phase,
                world.time_left,
                world.stone,
                world.food,
                world.ore,
                world.sword_tier,
                world.wall_count,
                world.aura_orb_count,
                world.bow_tower_count,
                world.storm_rod_count,
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
            "Local deterministic hints only, do not copy as prose: top_hints=%s sign_strength=%.2f resonance=%.2f"
            % (
                _top_hint_text(local_fallback.priority_hints),
                local_fallback.sign_strength,
                local_fallback.resonance,
            ),
            "Write Ari's own current interpretation from sign, rulebook, perception, and listed affordances.",
            "Return JSON only. Do not invent unavailable actions. If a cue says not wall/cover, exclude wall/cover ids unless no other listed affordance fits.",
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


def _compact_perception(perception: dict[str, object]) -> dict[str, object]:
    if not isinstance(perception, dict) or not perception:
        return {}
    return {
        "phase": perception.get("phase", ""),
        "time_left": perception.get("time_left", 0),
        "is_night": perception.get("is_night", False),
        "is_dawn_soon": perception.get("is_dawn_soon", False),
        "ari": perception.get("ari", {}),
        "resources": perception.get("resources", {}),
        "run_build": perception.get("run_build", {}),
        "sword_tier": perception.get("sword_tier", 0),
        "latest_library_note": perception.get("latest_library_note", {}),
        "nearby_enemies": _slice_list(perception.get("nearby_enemies", []), 5),
        "nearby_structures": _slice_list(perception.get("nearby_structures", []), 8),
        "tactical_facts": _slice_list(perception.get("tactical_facts", []), 10),
        "available_safe_moves": _slice_list(perception.get("available_safe_moves", []), 10),
    }


def _slice_list(value: object, max_items: int) -> list[object]:
    if not isinstance(value, list):
        return []
    return value[:max_items]


def _compact_json(value: object, max_chars: int) -> str:
    if not value:
        return "none"
    text = json.dumps(value, ensure_ascii=True, separators=(",", ":"))
    if len(text) <= max_chars:
        return text
    return text[:max_chars].rstrip() + "..."


def _semantic_cues(request: DeepInterpretationRequest) -> str:
    sign = request.sign_text.lower()
    cues: list[str] = []
    ranged_language = any(word in sign for word in ["bow", "arrow", "arrows", "range", "ranged", "tower"])
    direct_combat_language = any(word in sign for word in ["kill", "killing", "fight", "attack", "head on", "head-on", "sword", "blade", "weapon"])
    no_hide_language = "hide" in sign and any(word in sign for word in ["not", "don't", "dont", "never", "no "])
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
    if any(word in sign for word in ["sword", "blade", "forge", "smith", "ore", "iron"]):
        cues.append("sword path; prefer mine_ore/smith_sword/train_sword before fight_head_on")
    if direct_combat_language and not ranged_language and (no_hide_language or "head on" in sign or "head-on" in sign or "enemies" in sign or "sword" in sign or "weapon" in sign):
        cues.append("explicit no-hide/direct killing; grounded_plan[0] should be train_combat/prepare_weapon/train_sword/smith_sword/mine_ore/fight_head_on; tower/ranged only secondary if melee is clearly suicidal")
    if any(word in sign for word in ["morning", "dawn", "sunrise"]) and any(word in sign for word in ["survive", "last", "stall", "hide", "wait"]):
        cues.append("dawn survival; prefer stall_until_dawn/hide_until_dawn/survive_until_morning/avoid_killing")
    if "life" in sign and any(word in sign for word in ["kill", "dead", "die", "sword"]):
        cues.append("life from kills; prefer regen_on_kill/rely_on_regen with sword prep")
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
