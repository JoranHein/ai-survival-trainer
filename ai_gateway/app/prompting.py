from __future__ import annotations

import json

from .schemas import (
    AgentPlanRequest,
    BackgroundJobRequest,
    BridgePayloadRequest,
    DeepInterpretationRequest,
    FastThoughtRequest,
    PredictionRequest,
)


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


AGENT_PLAN_SYSTEM_PROMPT = """Output exactly one minified JSON object with only keys g,theory,plan,next,fb,why,belief,thought,c,after.
plan is 1-3 legal action ids. next and fb are one legal action id each. belief is a short object of belief_key:number.
No wrapper. No prose. Do not invent actions, coordinates, movement paths, or game-state mutations."""


SCRIBE_SYSTEM_PROMPT = """You are Ari's lightweight observer-scribe.
Read compact structured game snapshots and recent events. Write one short moment note about what Ari noticed or misunderstood.
Return minified JSON only. Schema exactly: {"schema":"ari.scribe.note.v2","note":string,"facts":[string],"actions":[{"action":string,"status":string,"reason":string}],"dangers":[{"type":string,"distance":number,"severity":number}],"world_changes":[string],"tags":[string],"priority_hints":object,"plan_alignment":"aligned|supporting|mismatch|unknown","immediate_risk":"none|low|medium|high|lethal","risk_reason":string,"resource_blockers":[string],"mistake_candidates":[string],"opportunity_candidates":[string],"lesson_candidates":[string],"behavior_evidence":[object],"confidence":number,"salience":number}.
facts/actions/dangers/world_changes must come from snapshots or events only. priority_hints may only bias future planning.
Behavior evidence is factual; describe it plainly but do not prescribe the lesson or fix.
Do not mutate game state. Do not invent actions. Keep note under 35 words and each list short."""


LIBRARY_REFLECTION_SYSTEM_PROMPT = """Output exactly one minified JSON object with only keys t,m,changed,worked,wrong,mis,lesson,h,bias,belief,doctrine,thought,c.
No wrapper. No prose. Use supplied facts only. h/bias/doctrine plan actions must be real Ari affordance ids.
If behavior evidence is supplied, decide whether it was useful adaptation, prerequisite progress, safety substitution, indecision, repeated blocked action, wasted time, bad plan, or missing resources. Do not assume the fix.
Doctrine may include a control object with preferred_anchor_kind, min_hold_seconds, avoid_action_ids, and allowed_break_reasons; this is advice only.
The engine owns movement, combat, building, resources, damage, and state mutation."""


BACKGROUND_JOB_SYSTEM_PROMPT = """You are Ari's bounded background intelligence worker.
Use compact summaries and strategy packets to improve Ari's future thinking without controlling his body.
Return minified JSON only. Schema exactly: {"schema":"ari.background_result.v1","job_id":string,"kind":string,"context_hash":string,"status":"ok|fallback|stale","notes":[string],"priority_hints":object,"strategy_packet":{"schema":"ari.strategy_packet.v1","main_risks":[string],"current_lessons":[string],"active_doctrines":[object],"priority_hints":object,"avoid_repeating":[string],"try_next":[string],"evidence":[string],"confidence":number},"confidence":number}.
Only use supplied facts. Priority hints may only name concrete survival affordance ids. Do not mutate game state."""


PREDICTION_SYSTEM_PROMPT = """Output exactly one minified JSON object with only keys r,a,u,h,c.
No response key. No wrapper. No prose. Use one listed legal action id. flying=>build_storm_rod if legal."""


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
            "Tools: walls, aura orb, tower/ranged attack, dummy, farm/food, rest, reflect_library, storm rod, mine_ore, smith_sword, train_sword, use_armor, rely_on_regen, regen_on_kill, fight_head_on, stall_until_dawn/hide_until_dawn.",
            "Direct combat/no-hide signs: grounded_plan[0]=train_combat/prepare_weapon/train_sword/smith_sword/mine_ore/fight_head_on; theory should be combat prep/sword/direct fighting. Do not use tower/range as top plan for generic killing unless bow/range named.",
            "Examples: stand behind the wall => use_existing_wall/wait_behind_wall/use_cover, not build_wall. use bow => use_tower/ranged_attack/train_bow/build_tower. attack them around the corner with a bow => use_cover/ranged_attack. the floor should fight or make the room dangerous => lure_to_aura/build_spike_trap/build_tar_pit/lure_to_tar_pit. ground grabs feet=>build_tar_pit/lure_to_tar_pit. warm=>build_fear_lantern/use_fear_lantern. false me=>build_decoy_idol/use_decoy_idol. become a silent spider and make the dead walk into your web => lure_to_aura/build_trap/use_thorns/hide. the moon hates cowards. the circle should eat the dead => lure_to_aura/place_aura_orb. the wings do not fear stone => build_storm_rod/anti_flying/sky_answer/use_tower/ranged_attack, not wall or cover; flying enemies ignore walls. my stomach is a second wall => farm_food/eat_food/eat/rest, not wall. do not hide, focus on killing enemies => fight_head_on/train_sword/smith_sword/mine_ore. just survive until morning => stall_until_dawn/hide_until_dawn/survive_until_morning/avoid_killing. make a sword that gives you life when they die => smith_sword/train_sword/regen_on_kill/rely_on_regen.",
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
            "Write Ari's current interpretation from sign, rulebook, perception, and affordances.",
            "Return JSON only. Do not invent unavailable actions. If a cue says not wall/cover, exclude wall/cover ids unless no other listed affordance fits.",
        ]
    )


def fast_user_prompt(request: FastThoughtRequest) -> str:
    return json.dumps(request.model_dump(), ensure_ascii=True, separators=(",", ":"))


def agent_plan_user_prompt(request: AgentPlanRequest) -> str:
    available_actions, unavailable_actions = _compact_legal_actions(request)
    sign_text = request.sign.get("text", request.sign.get("interpretation", "")) if isinstance(request.sign, dict) else ""
    world = request.world if isinstance(request.world, dict) else {}
    ari = request.ari if isinstance(request.ari, dict) else {}
    strategy = request.strategy_packet if isinstance(request.strategy_packet, dict) else {}
    compact_world = {
        "day": world.get("day", ""),
        "phase": world.get("phase", ""),
        "time": world.get("time_left", ""),
        "stone": world.get("stone", ""),
        "food": world.get("food", ""),
        "ore": world.get("ore", ""),
        "enemies": world.get("enemy_type_counts", {}),
        "walls": world.get("wall_count", world.get("walls", "")),
        "towers": world.get("bow_tower_count", world.get("towers", "")),
        "storm": world.get("storm_rod_count", world.get("storm_rods", "")),
        "damaged": world.get("damaged_structure_count", ""),
    }
    compact_ari = {
        "hp": ari.get("hp_ratio", ari.get("hp", "")),
        "fear": ari.get("fear", ""),
        "hunger": ari.get("hunger", ""),
        "job": ari.get("current_job", ""),
    }
    return "\n".join(
        [
            "Pick Ari's next survival action from legal ids only. Return compact JSON keys g,theory,plan,next,fb,why,belief,thought,c,after.",
            "cues mountain/arrows=>build_tower; wings=>build_storm_rod; survive morning=>use_cover/flee/stall_until_dawn; no-hide combat=>train_sword/fight_head_on if safe.",
            "Rule: first plan id should equal next. doctrine prereq: if a learned plan needs an unbuilt structure, choose that build id or its resource action first.",
            "kind=%s sign=%s" % (request.decision_kind[:60], str(sign_text)[:260]),
            "ari=%s world=%s" % (_compact_json(compact_ari, 220), _compact_json(compact_world, 420)),
            "strategy=%s" % _compact_json({
                "risk": strategy.get("main_risks", []),
                "lessons": strategy.get("current_lessons", []),
                "hints": strategy.get("priority_hints", {}),
                "avoid": strategy.get("avoid_repeating", []),
                "try": strategy.get("try_next", []),
            }, 520),
            "understanding=%s" % _compact_json(_compact_understanding(strategy.get("understanding", {})), 420),
            "behavior=%s" % _compact_json(_compact_behavior_evidence(request.behavior_evidence or strategy.get("behavior_evidence", []), 2), 420),
            "panel=%s" % _compact_json(_compact_action_control_panel(request.action_control_panel, 12), 950),
            "doctrine_plan=%s doctrines=%s" % (_compact_json(request.active_doctrine_plan[:4], 360), _compact_json(request.active_doctrines[:3], 360)),
            "recent=%s current=%s" % (_compact_json(request.recent_outcomes[:4], 320), _compact_json(request.current_plan, 280)),
            "legal_ok=%s legal_blocked=%s" % (available_actions, unavailable_actions),
            "fallback=%s" % _compact_json(_compact_agent_fallback(request.local_fallback), 300),
            "JSON contract: g/theory/why/thought are short strings; plan is 1-3 ids from legal_ok; next is plan[0]; fb is one id from legal_ok; belief is key:number; c is 0..1; after is seconds.",
        ]
    )


def scribe_user_prompt(request: BridgePayloadRequest) -> str:
    payload = request.payload
    return "\n".join(
        [
            "Write one compact moment note from structured facts only.",
            "Current sign: %s" % str(payload.get("current_sign", payload.get("sign", "")))[:400],
            "Phase/day: day=%s phase=%s" % (payload.get("day", ""), payload.get("phase", "")),
            "Active plan: %s" % _compact_json(payload.get("active_plan", {}), 600),
            "Behavior evidence: %s" % _compact_json(_compact_behavior_evidence(payload.get("behavior_evidence", []), 3), 620),
            "Recent events: %s" % _compact_json(_slice_list(payload.get("recent_events", []), 12), 1200),
            "Recent snapshots: %s" % _compact_json(_slice_list(payload.get("snapshots", payload.get("recent_snapshots", [])), 6), 1600),
            "Return JSON only with schema ari.scribe.note.v2. Extract facts/actions/dangers/world_changes from supplied facts only. Include plan_alignment, immediate_risk, blockers, mistake/opportunity/lesson candidates. priority_hints may contain only concrete survival affordance ids.",
        ]
    )


def library_reflection_user_prompt(request: BridgePayloadRequest) -> str:
    payload = request.payload
    day_summary = payload.get("day_summary", {})
    compact_summary = _compact_day_summary(day_summary)
    compact_notes = _compact_scribe_notes(payload.get("scribe_notes", []), 4)
    compact_events = _compact_reflection_events(payload.get("recent_events", []), 8)
    compact_outcomes = _compact_reflection_outcomes(payload.get("agent_plan_outcomes", []), 5)
    compact_behavior = _compact_behavior_evidence(payload.get("behavior_evidence", day_summary.get("behavior_evidence", [])), 3)
    return "\n".join(
        [
            "Ari nightly reflection. Use Day summary first; details only support it.",
            "If behavior evidence appears, decide whether behavior evidence was useful adaptation, prerequisite progress, safety substitution, indecision, repeated blocked action, wasted time, a bad plan, or missing resources.",
            "meta trigger=%s day=%s outcome=%s" % (payload.get("trigger", ""), payload.get("day", ""), payload.get("outcome", "")),
            "Sign: %s" % _compact_json(payload.get("sign", {}), 280),
            "Day summary: %s" % _compact_json(compact_summary, 620),
            "Behavior evidence: %s" % _compact_json(compact_behavior, 520),
            "Recent events: %s" % _compact_json(compact_events, 360),
            "Scribe notes: %s" % _compact_json(compact_notes, 420),
            "Agent outcomes: %s" % _compact_json(compact_outcomes, 280),
            "Active doctrines: %s" % _compact_json(_compact_reflection_doctrines(payload.get("active_doctrines", []), 3), 300),
            'Return JSON like {"t":"Wings Over Stone","m":"Ari saw wings cross the wall.","chg":["flying enemies appeared"],"ok":["storm rod plan helped"],"bad":["walls stayed first too long"],"mis":["treated flying like ground danger"],"lesson":"Build storm rod before extra walls when wings appear.","h":{"build_storm_rod":0.8},"bias":{"build_storm_rod":0.4,"build_wall":-0.1},"belief":{"wings_ignore_walls":0.25},"plan":["build_storm_rod"],"thought":"Stone is not sky.","c":0.7}.',
        ]
    )


def background_job_user_prompt(request: BackgroundJobRequest) -> str:
    payload = request.payload if isinstance(request.payload, dict) else {}
    return "\n".join(
        [
            "Bounded background job. Use only current facts and matching context_hash.",
            "Job id=%s kind=%s pri=%s ctx=%s exp=%.1f now=%.1f"
            % (
                request.job_id[:120],
                request.kind,
                request.priority,
                request.context_hash[:160],
                request.expires_at_game_time,
                request.current_game_time,
            ),
            "Sign: %s" % str(payload.get("current_sign", ""))[:220],
            "Rolling summary: %s" % _compact_json(_compact_rolling_summary(payload.get("rolling_summary", {})), 1000),
            "Day summary: %s" % _compact_json(payload.get("day_summary", {}), 1600),
            "Strategy packet: %s" % _compact_json(payload.get("strategy_packet", {}), 1400),
            "Recent scribe notes: %s" % _compact_json(_slice_list(payload.get("recent_scribe_notes", []), 3), 600),
            "Active plan: %s" % _compact_json(payload.get("active_plan", {}), 500),
            'JSON only, no placeholders: {"s":"ok","n":["wings make mining unsafe"],"h":{"build_storm_rod":0.6},"try":["build_storm_rod"],"avoid":["mine_stone"],"c":0.5}.',
        ]
    )


def prediction_user_prompt(request: PredictionRequest) -> str:
    legal_available = [item.id for item in request.legal_actions if item.available]
    risks = [
        {"t": risk.type[:24], "d": round(risk.distance, 1), "s": round(risk.severity, 2)}
        for risk in request.risks[:4]
    ]
    strategy = request.strategy_packet if isinstance(request.strategy_packet, dict) else {}
    hints = strategy.get("priority_hints", {}) if isinstance(strategy, dict) else {}
    lessons = strategy.get("current_lessons", []) if isinstance(strategy, dict) else []
    understanding = _compact_understanding(strategy.get("understanding", {})) if isinstance(strategy, dict) else {}
    rolling = _compact_rolling_summary(request.rolling_summary)
    lines = [
        "ctx=%s phase=%s t=%.0f hp=%s action=%s"
        % (
            request.context_hash[:80],
            request.phase[:16],
            request.time_left,
            str(request.ari.get("hp", ""))[:12] if isinstance(request.ari, dict) else "",
            str(request.ari.get("current_action", ""))[:60] if isinstance(request.ari, dict) else "",
        ),
        "risk=%s threats=%s blockers=%s mismatch=%s"
        % (
            str(rolling.get("risk", ""))[:40],
            ",".join(rolling.get("threats", [])) if isinstance(rolling.get("threats", []), list) else "",
            ",".join(rolling.get("blockers", [])) if isinstance(rolling.get("blockers", []), list) else "",
            ";".join(rolling.get("mismatch", []))[:180] if isinstance(rolling.get("mismatch", []), list) else "",
        ),
        "risks=%s res=%s plan=%s" % (_compact_json(risks, 180), _compact_json(request.resources, 120), _compact_json(request.current_plan, 140)),
        "hints=%s lessons=%s" % (_compact_json(hints, 160), _compact_json(_slice_list(lessons, 2), 160)),
        "panel=%s" % _prediction_action_panel_text(request.action_control_panel, 8),
        "legal=%s" % (",".join(legal_available[:16]) or "none"),
        'example={"r":"high","a":"build_storm_rod","u":0.8,"h":{"build_storm_rod":0.8},"c":0.6}',
    ]
    if understanding:
        lines.insert(4, "understanding=%s" % _compact_json(understanding, 260))
    return "\n".join(lines)


def _compact_day_summary(summary: object) -> dict[str, object]:
    if not isinstance(summary, dict):
        return {}
    compact: dict[str, object] = {
        "timeline": [str(value)[:90] for value in _slice_list(summary.get("timeline", []), 3)],
        "changed": [str(value)[:70] for value in _slice_list(summary.get("what_changed", []), 4)],
        "worked": [str(value)[:70] for value in _slice_list(summary.get("worked", []), 3)],
        "wrong": [str(value)[:80] for value in _slice_list(summary.get("went_wrong", []), 4)],
        "mis": [str(value)[:80] for value in _slice_list(summary.get("misunderstood", []), 3)],
        "mismatch": [str(value)[:90] for value in _slice_list(summary.get("plan_mismatches", []), 3)],
        "blockers": [str(value)[:70] for value in _slice_list(summary.get("resource_blockers", []), 3)],
        "threats": [str(value)[:40] for value in _slice_list(summary.get("threats", []), 4)],
        "lessons": [str(value)[:100] for value in _slice_list(summary.get("candidate_lessons", []), 4)],
        "hints": [str(value)[:50] for value in _slice_list(summary.get("recommended_priority_hints", []), 4)],
        "evidence": [str(value)[:60] for value in _slice_list(summary.get("evidence_snapshot_ids", []), 4)],
        "behavior_patterns": [str(value)[:60] for value in _slice_list(summary.get("behavior_patterns", []), 3)],
    }
    return {key: value for key, value in compact.items() if value not in ("", [], {})}


def _compact_scribe_notes(notes: object, max_notes: int) -> list[dict[str, object]]:
    compact: list[dict[str, object]] = []
    for raw in _slice_list(notes, max_notes):
        if not isinstance(raw, dict):
            continue
        item: dict[str, object] = {
            "note": str(raw.get("note", ""))[:120],
            "risk": str(raw.get("immediate_risk", ""))[:24],
            "align": str(raw.get("plan_alignment", ""))[:24],
            "tags": [str(value)[:40] for value in _slice_list(raw.get("tags", []), 4)],
            "mistakes": [str(value)[:70] for value in _slice_list(raw.get("mistake_candidates", []), 2)],
            "lessons": [str(value)[:80] for value in _slice_list(raw.get("lesson_candidates", []), 2)],
        }
        compact.append({key: value for key, value in item.items() if value not in ("", [], {})})
    return compact


def _compact_reflection_events(events: object, max_events: int) -> list[dict[str, object]]:
    compact: list[dict[str, object]] = []
    for raw in _slice_list(events, max_events):
        if not isinstance(raw, dict):
            continue
        event_type = str(raw.get("type", raw.get("event", "")))[:50]
        item: dict[str, object] = {"type": event_type}
        for key in ("enemy_type", "action_id", "outcome", "phase"):
            value = str(raw.get(key, ""))[:50]
            if value:
                item[key] = value
        compact.append(item)
    return compact


def _compact_reflection_outcomes(outcomes: object, max_outcomes: int) -> list[dict[str, object]]:
    compact: list[dict[str, object]] = []
    for raw in _slice_list(outcomes, max_outcomes):
        if not isinstance(raw, dict):
            continue
        item = {
            "action": str(raw.get("action_id", raw.get("action", "")))[:70],
            "outcome": str(raw.get("outcome", raw.get("status", "")))[:70],
        }
        compact.append({key: value for key, value in item.items() if value})
    return compact


def _compact_reflection_doctrines(doctrines: object, max_doctrines: int) -> list[dict[str, object]]:
    compact: list[dict[str, object]] = []
    for raw in _slice_list(doctrines, max_doctrines):
        if not isinstance(raw, dict):
            continue
        item: dict[str, object] = {
            "id": str(raw.get("id", ""))[:70],
            "summary": str(raw.get("summary", raw.get("title", "")))[:100],
            "bias": raw.get("bias", raw.get("priority_bias", {})),
            "plan": _slice_list(raw.get("plan", []), 2),
            "control": raw.get("control", {}),
        }
        compact.append({key: value for key, value in item.items() if value not in ("", [], {})})
    return compact


def _compact_behavior_evidence(value: object, max_items: int) -> list[dict[str, object]]:
    if isinstance(value, dict):
        rows = [value]
    elif isinstance(value, list):
        rows = value
    else:
        return []
    compact: list[dict[str, object]] = []
    for raw in rows[:max_items]:
        if not isinstance(raw, dict):
            continue
        pattern = str(raw.get("primary_pattern", ""))[:80]
        if not pattern:
            continue
        progress = raw.get("progress_delta", {})
        if not isinstance(progress, dict):
            progress = {}
        context = raw.get("context", {})
        if not isinstance(context, dict):
            context = {}
        item: dict[str, object] = {
            "p": pattern,
            "a": [str(action)[:60] for action in _slice_list(raw.get("actions_seen", []), 5)],
            "sw": raw.get("transition_count", 0),
            "done": raw.get("completion_count", 0),
            "blocked": raw.get("blocked_count", 0),
            "abandoned": raw.get("abandoned_count", 0),
            "anchors": [str(anchor)[:60] for anchor in _slice_list(raw.get("anchors_seen", []), 4)],
            "anchor_sw": raw.get("anchor_transition_count", 0),
            "delta": {
                str(key)[:32]: progress[key]
                for key in ("structures", "stone", "repairs", "kills", "hp")
                if key in progress
            },
            "ctx": {
                str(key)[:36]: context[key]
                for key in (
                    "phase",
                    "enemy_count_before",
                    "enemy_count_after",
                    "nearest_danger_changed",
                    "active_plan_changed",
                )
                if key in context
            },
            "s": str(raw.get("neutral_summary", ""))[:180],
        }
        compact.append({key: item_value for key, item_value in item.items() if item_value not in ("", [], {})})
    return compact


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


def _compact_legal_actions(request: AgentPlanRequest) -> tuple[str, str]:
    available: list[str] = []
    unavailable: list[str] = []
    for item in request.legal_actions:
        if item.available:
            available.append(item.id)
        else:
            reason = item.reason_unavailable.strip() or "unavailable"
            unavailable.append("%s(%s)" % (item.id, reason[:48]))
    return ",".join(available) or "none", ",".join(unavailable) or "none"


def _compact_action_control_panel(panel: object, max_actions: int) -> dict[str, object]:
    if not isinstance(panel, dict):
        return {}
    raw_actions = panel.get("actions", [])
    if not isinstance(raw_actions, list):
        raw_actions = []
    actions: list[dict[str, object]] = []
    for raw in raw_actions[:max_actions]:
        if not isinstance(raw, dict):
            continue
        item: dict[str, object] = {
            "id": str(raw.get("id", ""))[:80],
            "ok": bool(raw.get("available", True)),
            "cat": str(raw.get("category", ""))[:40],
            "why": str(raw.get("description", ""))[:90],
        }
        reason = str(raw.get("reason_unavailable", ""))[:80]
        if reason:
            item["blocked"] = reason
        counters = _slice_list(raw.get("counters", []), 4)
        if counters:
            item["counters"] = [str(value)[:40] for value in counters]
        enables = _slice_list(raw.get("enables", []), 4)
        if enables:
            item["enables"] = [str(value)[:40] for value in enables]
        preconditions = _slice_list(raw.get("preconditions", []), 4)
        if preconditions:
            item["needs"] = [str(value)[:40] for value in preconditions]
        good_when = _slice_list(raw.get("good_when", []), 4)
        if good_when:
            item["good"] = [str(value)[:40] for value in good_when]
        failure_modes = _slice_list(raw.get("failure_modes", []), 3)
        if failure_modes:
            item["fails"] = [str(value)[:48] for value in failure_modes]
        cost = raw.get("cost", {})
        if isinstance(cost, dict) and cost:
            item["cost"] = {str(key)[:40]: cost[key] for key in list(cost.keys())[:3]}
        actions.append(item)
    if not actions:
        return {}
    return {
        "schema": str(panel.get("schema", "ari.action_control_panel.v1"))[:80],
        "actions": actions,
    }


def _prediction_action_panel_text(panel: object, max_actions: int) -> str:
    if not isinstance(panel, dict):
        return "none"
    raw_actions = panel.get("actions", [])
    if not isinstance(raw_actions, list):
        return "none"
    parts: list[str] = []
    for raw in raw_actions[:max_actions]:
        if not isinstance(raw, dict):
            continue
        action_id = str(raw.get("id", ""))[:80]
        if not action_id:
            continue
        status = "ok" if bool(raw.get("available", True)) else "blocked:%s" % str(raw.get("reason_unavailable", ""))[:36]
        details: list[str] = [status]
        category = str(raw.get("category", ""))[:24]
        if category:
            details.append(category)
        counters = [str(value)[:24] for value in _slice_list(raw.get("counters", []), 3)]
        if counters:
            details.append("counters:%s" % ",".join(counters))
        enables = [str(value)[:24] for value in _slice_list(raw.get("enables", []), 3)]
        if enables:
            details.append("enables:%s" % ",".join(enables))
        preconditions = [str(value)[:28] for value in _slice_list(raw.get("preconditions", []), 3)]
        if preconditions:
            details.append("needs:%s" % ",".join(preconditions))
        good_when = [str(value)[:28] for value in _slice_list(raw.get("good_when", []), 3)]
        if good_when:
            details.append("good:%s" % ",".join(good_when))
        failure_modes = [str(value)[:32] for value in _slice_list(raw.get("failure_modes", []), 2)]
        if failure_modes:
            details.append("fails:%s" % ",".join(failure_modes))
        cost = raw.get("cost", {})
        if isinstance(cost, dict) and cost:
            details.append("cost:%s" % ",".join("%s%s" % (str(key)[:12], str(cost[key])[:8]) for key in list(cost.keys())[:2]))
        why = str(raw.get("description", ""))[:70]
        if why:
            details.append(why)
        parts.append("%s(%s)" % (action_id, ",".join(details)))
    return ";".join(parts)[:650] or "none"


def _compact_rolling_summary(summary: object) -> dict[str, object]:
    if not isinstance(summary, dict):
        return {}
    compact: dict[str, object] = {
        "schema": str(summary.get("schema", "ari.rolling_tactical_summary.v1"))[:80],
        "risk": str(summary.get("risk_level", "none"))[:40],
        "threats": [str(value)[:40] for value in _slice_list(summary.get("threats", []), 5)],
        "actions": [str(value)[:70] for value in _slice_list(summary.get("current_actions", []), 4)],
        "plan": [str(value)[:70] for value in _slice_list(summary.get("plan_actions", []), 4)],
        "mismatch": [str(value)[:120] for value in _slice_list(summary.get("plan_mismatches", []), 4)],
        "blockers": [str(value)[:60] for value in _slice_list(summary.get("resource_blockers", []), 4)],
        "changes": [str(value)[:70] for value in _slice_list(summary.get("world_changes", []), 4)],
        "lessons": [str(value)[:100] for value in _slice_list(summary.get("lesson_candidates", []), 4)],
    }
    hints = summary.get("priority_hints", {})
    if isinstance(hints, dict):
        compact["hints"] = {str(key)[:60]: hints[key] for key in list(hints.keys())[:5]}
    return {key: value for key, value in compact.items() if value not in ("", [], {})}


def _compact_understanding(value: object) -> dict[str, object]:
    if not isinstance(value, dict) or value.get("schema") != "ari.understanding.v1":
        return {}
    ladder: list[str] = []
    raw_ladder = value.get("prerequisite_ladder", [])
    if isinstance(raw_ladder, list):
        for raw in raw_ladder[:4]:
            if not isinstance(raw, dict):
                continue
            action_id = str(raw.get("action_id", raw.get("id", "")))[:60]
            status = str(raw.get("status", ""))[:32]
            if action_id:
                ladder.append("%s:%s" % (action_id, status) if status else action_id)
    body_alignment = value.get("body_alignment", {})
    align = ""
    if isinstance(body_alignment, dict):
        relation = str(body_alignment.get("relation", ""))[:40]
        body_job = str(body_alignment.get("body_job", body_alignment.get("body_action", "")))[:60]
        planned = str(body_alignment.get("planned_action", ""))[:60]
        if relation:
            align = "%s:%s>%s" % (relation, body_job, planned)
    compact: dict[str, object] = {
        "q": str(value.get("survival_question", ""))[:110],
        "thesis": str(value.get("sign_thesis", ""))[:110],
        "strategy": str(value.get("intended_strategy", ""))[:110],
        "ladder": ladder,
        "align": align,
    }
    return {key: item for key, item in compact.items() if item not in ("", [], {})}


def _compact_agent_fallback(value: object) -> dict[str, object]:
    if not isinstance(value, dict) or not value:
        return {}
    return {
        "next_action": _choice_id(value.get("next_action", {})),
        "fallback_action": _choice_id(value.get("fallback_action", {})),
        "plan": [_choice_id(item) for item in _slice_list(value.get("plan", []), 2) if _choice_id(item)],
        "confidence": value.get("confidence", 0.0),
    }


def _choice_id(value: object) -> str:
    if not isinstance(value, dict):
        return ""
    return str(value.get("action_id") or value.get("affordance_id") or value.get("id") or "").strip()


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
    if any(word in sign for word in ["mud", "tar", "sticky", "stuck", "sink", "mire", "ground grab", "feet"]):
        cues.append("slow ground means build_tar_pit first, then lure_to_tar_pit if a tar pit exists")
    if any(word in sign for word in ["warm", "warmth", "lantern", "lamp"]) and any(word in sign for word in ["fear", "afraid", "scared", "safe"]):
        cues.append("warm fear light means build_fear_lantern first, then use_fear_lantern if it exists")
    if any(word in sign for word in ["false", "decoy", "idol", "bait", "dummy"]) and any(word in sign for word in ["me", "self", "teeth", "take", "draw", "lure", "distract"]):
        cues.append("false self bait means build_decoy_idol first, then use_decoy_idol if it exists")
    if any(word in sign for word in ["wing", "wings", "flying", "sky", "air"]):
        cues.append("sky threat; wall/cover fails; prefer build_storm_rod/anti_flying/sky_answer/use_tower/ranged_attack; after storm exists, add tower/ranged support")
    if any(word in sign for word in ["bow", "arrow", "arrows", "shoot", "ranged", "range"]) or "mountain" in sign:
        cues.append("bow/ranged intent; prefer use_tower/ranged_attack/train_bow/build_tower")
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
