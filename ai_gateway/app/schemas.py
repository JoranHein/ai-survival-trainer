from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator


ALLOWED_PRIORITY_KEYS = {
    "mine_stone",
    "build_wall",
    "wait_or_idle",
    "use_existing_wall",
    "wait_behind_wall",
    "use_cover",
    "place_aura_orb",
    "lure_to_aura",
    "train_combat",
    "prepare_weapon",
    "ranged_attack",
    "use_tower",
    "train_bow",
    "farm_food",
    "eat",
    "eat_food",
    "build_trap",
    "build_spike_trap",
    "build_tower",
    "build_tar_pit",
    "lure_to_tar_pit",
    "build_fear_lantern",
    "use_fear_lantern",
    "build_decoy_idol",
    "use_decoy_idol",
    "build_thorn_totem",
    "build_repair_bench",
    "use_thorns",
    "rest",
    "reflect_library",
    "repair",
    "repair_structure",
    "flee",
    "fight",
    "fight_head_on",
    "train_sword",
    "smith_sword",
    "mine_ore",
    "build_forge",
    "use_armor",
    "rely_on_regen",
    "regen_on_kill",
    "stall_until_dawn",
    "hide_until_dawn",
    "avoid_killing",
    "survive_until_morning",
    "kite",
    "hide",
    "build_storm_rod",
    "anti_flying",
    "sky_answer",
    "anti_air_defense",
    "mining",
    "wall",
    "aura_orb",
    "combat_training",
    "range",
    "hold_best_defense",
    "defensive_wait",
}

MAX_GROUNDED_PLAN_ITEMS = 4
AGENT_PLAN_SCHEMA = "ari.agent.plan.v1"
SCRIBE_NOTE_SCHEMA = "ari.scribe.note.v2"
BEHAVIOR_EVIDENCE_SCHEMA = "ari.behavior_evidence.v1"
PREDICTION_SCHEMA = "ari.prediction.v1"
MAX_AGENT_PLAN_STEPS = 4
MAX_BELIEF_UPDATES = 6
MAX_SCRIBE_TAGS = 8
MAX_SCRIBE_FACTS = 8
MAX_SCRIBE_ACTIONS = 4
MAX_SCRIBE_DANGERS = 4
MAX_SCRIBE_WORLD_CHANGES = 6
MAX_SCRIBE_DECISION_ITEMS = 5
MAX_BEHAVIOR_EVIDENCE_ITEMS = 4
MAX_REFLECTION_DOCTRINES = 5
MAX_REFLECTION_LIST_ITEMS = 8
MAX_DOCTRINE_CONTROL_ACTIONS = 6
MAX_DOCTRINE_CONTROL_BREAK_REASONS = 6
ALLOWED_DOCTRINE_ANCHOR_KINDS = {
    "safest_defense",
    "current_anchor",
    "tower",
    "aura",
    "cover",
    "wall",
    "storm_rod",
    "fear_lantern",
    "decoy_idol",
    "thorn_totem",
    "repair_target",
}
ALLOWED_DOCTRINE_BREAK_REASONS = {
    "danger_changed",
    "anchor_destroyed",
    "low_hp",
    "enemy_too_close",
    "anchor_invalid",
    "plan_completed",
    "resource_blocked",
    "required_resource_missing",
}
INTERNAL_SCRIBE_EVENT_TYPES = {
    "agent_plan_created",
    "learning_trace_created",
    "night_reflection_created",
    "note_reread",
    "phase_changed",
}
SCRIBE_PLAN_ALIGNMENTS = {"aligned", "supporting", "mismatch", "unknown"}
SCRIBE_RISK_LEVELS = {"none", "low", "medium", "high", "lethal"}
PREDICTION_RISK_LEVELS = ("none", "low", "medium", "high", "lethal")
BACKGROUND_JOB_KINDS = (
    "scribe_enrich",
    "summary_review",
    "reflection_draft",
    "strategy_candidate",
    "doctrine_review",
    "playtest_analysis",
)
BACKGROUND_JOB_PRIORITIES = ("low", "normal", "high")
BACKGROUND_RESULT_STATUSES = {"ok", "fallback", "stale"}
MAX_STRATEGY_LIST_ITEMS = 8
MAX_STRATEGY_EVIDENCE_ITEMS = 14

FORBIDDEN_REQUEST_KEYS = {
    "personality",
    "personality_summary",
    "era",
    "origin_year",
    "stubbornness",
    "perseverance",
    "confusion",
}


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class TolerantRequestModel(BaseModel):
    model_config = ConfigDict(extra="ignore")

    @model_validator(mode="before")
    @classmethod
    def reject_forbidden_request_keys(cls, data: Any) -> Any:
        if isinstance(data, dict):
            forbidden = sorted(FORBIDDEN_REQUEST_KEYS.intersection(str(key) for key in data.keys()))
            if forbidden:
                raise ValueError(f"Forbidden request field(s): {', '.join(forbidden)}")
        return data


class AriState(TolerantRequestModel):
    run_build: dict[str, Any] = Field(default_factory=dict)
    hp: float = 100.0
    max_hp: float = 100.0
    current_job: str = ""
    current_reason: str = ""
    job: str = ""
    reason: str = ""


class StructureState(TolerantRequestModel):
    type: str = ""
    status: str = ""


class WorldState(TolerantRequestModel):
    day: int = 1
    phase: str = "morning"
    time_left: float = 0.0
    stone: int = 0
    food: int = 0
    ore: int = 0
    wall_count: int = 0
    aura_orb_count: int = 0
    bow_tower_count: int = 0
    storm_rod_count: int = 0
    sword_tier: int = 0
    enemy_count: int = 0
    enemy_type_counts: dict[str, int] = Field(default_factory=dict)
    known_enemy_types: list[str] = Field(default_factory=list)
    structures: list[StructureState] = Field(default_factory=list)


class AffordanceState(TolerantRequestModel):
    id: str
    description: str = ""
    available: bool = True
    reason_unavailable: str = ""


class LocalFallback(TolerantRequestModel):
    interpretation: str = ""
    priority_hints: dict[str, Any] = Field(default_factory=dict)
    emotion: str = ""
    grounded_plan: list[dict[str, Any]] = Field(default_factory=list)
    sign_strength: float = 0.0
    resonance: float = 0.0


class DeepInterpretationRequest(TolerantRequestModel):
    sign_text: str
    rulebook: dict[str, Any] = Field(default_factory=dict)
    perception: dict[str, Any] = Field(default_factory=dict)
    run_build: dict[str, Any] = Field(default_factory=dict)
    ari: AriState
    world: WorldState
    local_fallback: LocalFallback
    current_affordances: list[AffordanceState] = Field(default_factory=list)
    recent_thoughts: list[str] = Field(default_factory=list)
    latest_library_note: str = ""


class DeepInterpretationResponse(StrictModel):
    interpretation: str
    thought: str
    survival_theory: str
    emotion: str
    grounded_plan: list[dict[str, Any]]
    priority_hints: dict[str, float]
    sign_strength: float
    resonance: float


class FastThoughtRequest(TolerantRequestModel):
    event: str = ""
    ari: dict[str, Any] = Field(default_factory=dict)
    world: dict[str, Any] = Field(default_factory=dict)
    local_fallback_thought: str = ""


class FastThoughtResponse(StrictModel):
    thought: str
    resonance: float


class AgentPlanAction(TolerantRequestModel):
    id: str
    description: str = ""
    available: bool = True
    reason_unavailable: str = ""


class AgentPlanRequest(TolerantRequestModel):
    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    schema_: str = Field(default=AGENT_PLAN_SCHEMA, alias="schema")
    decision_kind: str = "day_replan"
    objective: dict[str, Any] = Field(default_factory=dict)
    sign: dict[str, Any] = Field(default_factory=dict)
    ari: dict[str, Any] = Field(default_factory=dict)
    world: dict[str, Any] = Field(default_factory=dict)
    perception: dict[str, Any] = Field(default_factory=dict)
    current_plan: dict[str, Any] = Field(default_factory=dict)
    strategy_packet: dict[str, Any] = Field(default_factory=dict)
    behavior_evidence: list[dict[str, Any]] = Field(default_factory=list)
    action_control_panel: dict[str, Any] = Field(default_factory=dict)
    active_doctrines: list[dict[str, Any]] = Field(default_factory=list)
    active_doctrine_plan: list[dict[str, Any]] = Field(default_factory=list)
    recent_outcomes: list[dict[str, Any]] = Field(default_factory=list)
    legal_actions: list[AgentPlanAction] = Field(default_factory=list)
    local_fallback: dict[str, Any] = Field(default_factory=dict)


class AgentPlanStep(StrictModel):
    step_id: str
    action_id: str
    reason: str
    success: str


class AgentPlanActionChoice(StrictModel):
    action_id: str
    urgency: float = 0.5
    reason: str = ""


class AgentPlanBeliefUpdate(StrictModel):
    key: str
    delta: float
    reason: str


class AgentPlanResponse(StrictModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    schema_: str = Field(alias="schema")
    goal: str
    survival_theory: str
    plan: list[AgentPlanStep]
    next_action: AgentPlanActionChoice
    fallback_action: AgentPlanActionChoice
    belief_updates: list[AgentPlanBeliefUpdate]
    thought: str
    confidence: float
    replan_after_seconds: float
    source: str = "remote_server"
    failure_reason: str = ""


class PredictionRisk(TolerantRequestModel):
    type: str = ""
    distance: float = 0.0
    severity: float = 0.0


class PredictionRequest(TolerantRequestModel):
    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    schema_: str = Field(default="ari.prediction.request.v1", alias="schema")
    context_hash: str = ""
    day: int = 1
    phase: str = ""
    time_left: float = 0.0
    ari: dict[str, Any] = Field(default_factory=dict)
    risks: list[PredictionRisk] = Field(default_factory=list)
    resources: dict[str, Any] = Field(default_factory=dict)
    structures: dict[str, Any] = Field(default_factory=dict)
    current_plan: dict[str, Any] = Field(default_factory=dict)
    rolling_summary: dict[str, Any] = Field(default_factory=dict)
    strategy_packet: dict[str, Any] = Field(default_factory=dict)
    action_control_panel: dict[str, Any] = Field(default_factory=dict)
    legal_actions: list[AgentPlanAction] = Field(default_factory=list)
    max_words: int = 28


class PredictionActionBias(StrictModel):
    action_id: str
    urgency: float = 0.5
    reason: str = ""


class PredictionResponse(StrictModel):
    model_config = ConfigDict(extra="forbid", populate_by_name=True)

    schema_: str = Field(alias="schema")
    context_hash: str
    risk_level: str
    prediction: str
    next_action_bias: PredictionActionBias
    priority_hints: dict[str, float]
    avoid: list[str]
    confidence: float
    stale_after_seconds: float = 5.0
    source: str = "remote_server"
    failure_reason: str = ""


class BridgePayloadRequest(TolerantRequestModel):
    payload: dict[str, Any] = Field(default_factory=dict)


class BridgeRawResponse(StrictModel):
    raw: dict[str, Any]


class BackgroundJobRequest(TolerantRequestModel):
    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    schema_: str = Field(default="ari.background_job.v1", alias="schema")
    job_id: str = ""
    kind: Literal[
        "scribe_enrich",
        "summary_review",
        "reflection_draft",
        "strategy_candidate",
        "doctrine_review",
        "playtest_analysis",
    ] = "strategy_candidate"
    priority: Literal["low", "normal", "high"] = "normal"
    context_hash: str = ""
    expires_at_game_time: float = 0.0
    current_game_time: float = 0.0
    payload: dict[str, Any] = Field(default_factory=dict)


def sanitize_deep_response(
    raw: dict[str, Any],
    fallback: dict[str, Any],
    allowed_affordance_ids: set[str] | None = None,
) -> dict[str, Any]:
    raw_hints = raw.get("priority_hints", {})
    if not isinstance(raw_hints, dict):
        raw_hints = {}
    priority_hints = sanitize_priority_hints(raw_hints)
    grounded_plan = sanitize_grounded_plan(raw.get("grounded_plan", fallback.get("grounded_plan", [])), allowed_affordance_ids)
    for item in grounded_plan:
        affordance_id = item["affordance_id"]
        priority_hints[affordance_id] = max(priority_hints.get(affordance_id, 0.0), item["priority"])
    return {
        "interpretation": clean_text(raw.get("interpretation", fallback.get("interpretation", "")), 240),
        "thought": clean_text(raw.get("thought", fallback.get("thought", "")), 160),
        "survival_theory": clean_text(raw.get("survival_theory", fallback.get("survival_theory", "fallback")), 64),
        "emotion": clean_text(raw.get("emotion", fallback.get("emotion", "uncertain")), 64),
        "grounded_plan": grounded_plan,
        "priority_hints": priority_hints,
        "sign_strength": clamp01(raw.get("sign_strength", fallback.get("sign_strength", 0.0))),
        "resonance": clamp01(raw.get("resonance", fallback.get("resonance", 0.0))),
    }


def fallback_deep_response(
    local_fallback: LocalFallback | dict[str, Any],
    current_affordances: list[AffordanceState] | list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    if isinstance(local_fallback, LocalFallback):
        data = local_fallback.model_dump()
    else:
        data = local_fallback
    interpretation = clean_text(data.get("interpretation") or "Ari falls back to his local reading.", 240)
    priority_hints = fallback_priority_hints(data.get("priority_hints", {}))
    allowed_ids = affordance_ids(current_affordances)
    return {
        "interpretation": interpretation,
        "thought": "I only understand part of the sign. I will stay careful.",
        "survival_theory": "local_fallback",
        "emotion": clean_text(data.get("emotion", "uncertain"), 64),
        "grounded_plan": sanitize_grounded_plan(
            data.get("grounded_plan") or grounded_plan_from_hints(priority_hints, allowed_ids),
            allowed_ids,
        ),
        "priority_hints": priority_hints,
        "sign_strength": clamp01(data.get("sign_strength", 0.0)),
        "resonance": clamp01(data.get("resonance", 0.0)),
    }


def fallback_fast_thought(request: FastThoughtRequest | dict[str, Any]) -> dict[str, Any]:
    if isinstance(request, FastThoughtRequest):
        data = request.model_dump()
    else:
        data = request
    return {
        "thought": clean_text(data.get("local_fallback_thought") or "I need to stay alive.", 160),
        "resonance": clamp01(data.get("resonance", 0.0)),
    }


def sanitize_agent_plan_response(
    raw: dict[str, Any],
    fallback: dict[str, Any],
    legal_actions: list[AgentPlanAction] | list[dict[str, Any]] | None = None,
    request_context: AgentPlanRequest | dict[str, Any] | None = None,
) -> dict[str, Any]:
    raw = normalize_agent_plan_model_result(raw)
    legal_ids = action_ids(legal_actions)
    if raw.get("schema", AGENT_PLAN_SCHEMA) != AGENT_PLAN_SCHEMA:
        return fallback_agent_plan_response(fallback, legal_actions, "invalid_schema")

    repaired_invalid_action = False
    next_action = sanitize_agent_action_choice(raw.get("next_action", {}), legal_ids)
    plan = sanitize_agent_plan_steps(raw.get("plan", []), legal_ids)
    if not next_action and plan:
        next_action = {
            "action_id": plan[0]["action_id"],
            "urgency": max(clamp01(raw.get("confidence", 0.5)), 0.6),
            "reason": clean_text(plan[0].get("reason", "") or raw.get("survival_theory", ""), 180),
        }
        repaired_invalid_action = True
    if not next_action:
        repair_choice = agent_plan_doctrine_prerequisite_choice(request_context, legal_ids, "")
        if not repair_choice:
            repair_choice = agent_plan_safety_choice(request_context, legal_ids, "")
        if repair_choice:
            next_action = repair_choice
            plan = [agent_plan_step_from_choice(repair_choice, "validated_repair")]
            repaired_invalid_action = True
    if not next_action:
        return fallback_agent_plan_response(fallback, legal_actions, "invalid_action")

    fallback_action = sanitize_agent_action_choice(raw.get("fallback_action", {}), legal_ids)
    if not fallback_action:
        fallback_action = sanitize_agent_action_choice(fallback.get("fallback_action", {}), legal_ids)
    if not fallback_action:
        fallback_action = _first_legal_action_choice(legal_actions, next_action["action_id"])

    if not plan:
        plan = [
            {
                "step_id": "next_action",
                "action_id": next_action["action_id"],
                "reason": clean_text(next_action.get("reason", "") or raw.get("survival_theory", ""), 180),
                "success": "action_completed",
            }
        ]
    elif plan[0]["action_id"] != next_action["action_id"]:
        next_action = {
            "action_id": plan[0]["action_id"],
            "urgency": max(clamp01(next_action.get("urgency", 0.5)), 0.6),
            "reason": clean_text(plan[0].get("reason", "") or next_action.get("reason", ""), 180),
        }
    doctrine_prerequisite = agent_plan_doctrine_prerequisite_choice(
        request_context,
        legal_ids,
        next_action.get("action_id", ""),
    )
    if doctrine_prerequisite:
        next_action = doctrine_prerequisite
        plan = [agent_plan_step_from_choice(doctrine_prerequisite, "doctrine_prerequisite")]
    safety_choice = agent_plan_safety_choice(
        request_context,
        legal_ids,
        next_action.get("action_id", ""),
    )
    if safety_choice:
        next_action = safety_choice
        plan = [agent_plan_step_from_choice(safety_choice, "safety_guard")]
    thought = clean_text(raw.get("thought", fallback.get("thought", "I need a plan that keeps me alive.")), 180)
    if _is_agent_plan_fallback_like_thought(thought):
        thought = _agent_plan_concrete_thought([
            next_action.get("reason", ""),
            plan[0].get("reason", "") if plan else "",
            raw.get("survival_theory", ""),
        ])

    return {
        "schema": AGENT_PLAN_SCHEMA,
        "goal": clean_text(raw.get("goal", fallback.get("goal", "survive_next_night")), 160),
        "survival_theory": clean_text(raw.get("survival_theory", fallback.get("survival_theory", "")), 240),
        "plan": plan,
        "next_action": next_action,
        "fallback_action": fallback_action,
        "belief_updates": sanitize_belief_updates(raw.get("belief_updates", [])),
        "thought": thought,
        "confidence": clamp01(raw.get("confidence", fallback.get("confidence", 0.35))),
        "replan_after_seconds": clamp_seconds(raw.get("replan_after_seconds", fallback.get("replan_after_seconds", 10.0))),
        "source": "validated_guardrail" if repaired_invalid_action else "remote_server",
        "failure_reason": "repaired_invalid_action" if repaired_invalid_action else "",
    }


def normalize_agent_plan_model_result(raw: dict[str, Any]) -> dict[str, Any]:
    data = raw.copy() if isinstance(raw, dict) else {}
    if any(key in data for key in ("schema", "goal", "next_action", "fallback_action")):
        return data
    if not any(key in data for key in ("g", "theory", "plan", "next", "fb")):
        return data
    next_action = clean_text(data.get("next", ""), 80)
    fallback_action = clean_text(data.get("fb", ""), 80)
    why = clean_text(data.get("why", data.get("theory", "")), 180)
    compact_plan = data.get("plan", [])
    plan_steps: list[dict[str, str]] = []
    if isinstance(compact_plan, list):
        for index, raw_action in enumerate(compact_plan):
            action_id = clean_text(raw_action.get("action_id", raw_action.get("id", "")), 80) if isinstance(raw_action, dict) else clean_text(raw_action, 80)
            if not action_id:
                continue
            plan_steps.append(
                {
                    "step_id": "step_%d" % (index + 1),
                    "action_id": action_id,
                    "reason": why,
                    "success": "action_completed",
                }
            )
            if len(plan_steps) >= MAX_AGENT_PLAN_STEPS:
                break
    if not plan_steps and next_action:
        plan_steps = [{"step_id": "step_1", "action_id": next_action, "reason": why, "success": "action_completed"}]
    return {
        "schema": AGENT_PLAN_SCHEMA,
        "goal": clean_text(data.get("g", "survive_next_night"), 160),
        "survival_theory": clean_text(data.get("theory", why), 240),
        "plan": plan_steps,
        "next_action": {"action_id": next_action, "urgency": data.get("c", 0.6), "reason": why},
        "fallback_action": {"action_id": fallback_action, "urgency": 0.35, "reason": "Fallback if the compact plan is blocked."},
        "belief_updates": _compact_agent_plan_belief_updates(data.get("belief", {}), data.get("theory", why)),
        "thought": clean_text(data.get("thought", why), 180),
        "confidence": data.get("c", 0.5),
        "replan_after_seconds": data.get("after", 8),
        "source": "remote_server",
        "failure_reason": "",
    }


def _compact_agent_plan_belief_updates(raw_belief: Any, reason: Any) -> list[dict[str, Any]]:
    if isinstance(raw_belief, list):
        return raw_belief
    if not isinstance(raw_belief, dict):
        return []
    result: list[dict[str, Any]] = []
    reason_text = clean_text(reason, 180)
    for raw_key, raw_delta in raw_belief.items():
        key = clean_text(raw_key, 80)
        if not key:
            continue
        result.append({"key": key, "delta": _float_value(raw_delta), "reason": reason_text})
        if len(result) >= MAX_BELIEF_UPDATES:
            break
    return result


def _is_agent_plan_fallback_like_thought(thought: str) -> bool:
    lowered = thought.lower()
    return any(
        pattern in lowered
        for pattern in (
            "legal fallback",
            "safe fallback",
            "deterministic fallback",
            "choose a fallback",
            "fallback action",
        )
    )


def _agent_plan_concrete_thought(candidates: list[Any]) -> str:
    for candidate in candidates:
        text = clean_text(candidate, 180)
        if text and not _is_agent_plan_fallback_like_thought(text):
            return text
    return "I know the next concrete survival step."


def fallback_agent_plan_response(
    local_fallback: dict[str, Any],
    legal_actions: list[AgentPlanAction] | list[dict[str, Any]] | None = None,
    failure_reason: str = "local_fallback",
) -> dict[str, Any]:
    fallback = local_fallback if isinstance(local_fallback, dict) else {}
    legal_ids = action_ids(legal_actions)
    next_action = sanitize_agent_action_choice(fallback.get("next_action", {}), legal_ids)
    if not next_action:
        next_action = _first_legal_action_choice(legal_actions, "wait_or_idle")
    fallback_action = sanitize_agent_action_choice(fallback.get("fallback_action", {}), legal_ids)
    if not fallback_action:
        fallback_action = _first_legal_action_choice(legal_actions, next_action["action_id"])
    plan = sanitize_agent_plan_steps(fallback.get("plan", []), legal_ids)
    if not plan:
        plan = [
            {
                "step_id": "fallback",
                "action_id": next_action["action_id"],
                "reason": clean_text(next_action.get("reason", "Local fallback keeps Ari safe."), 180),
                "success": "action_completed",
            }
        ]
    thought = clean_text(fallback.get("thought", "I need to stay alive with what I know."), 180)
    if _is_agent_plan_fallback_like_thought(thought):
        thought = _agent_plan_concrete_thought([
            next_action.get("reason", ""),
            plan[0].get("reason", "") if plan else "",
            fallback.get("survival_theory", ""),
        ])
    return {
        "schema": AGENT_PLAN_SCHEMA,
        "goal": clean_text(fallback.get("goal", "survive_next_night"), 160),
        "survival_theory": clean_text(fallback.get("survival_theory", "Use the safest local behavior."), 240),
        "plan": plan,
        "next_action": next_action,
        "fallback_action": fallback_action,
        "belief_updates": sanitize_belief_updates(fallback.get("belief_updates", [])),
        "thought": thought,
        "confidence": clamp01(fallback.get("confidence", 0.35)),
        "replan_after_seconds": clamp_seconds(fallback.get("replan_after_seconds", 10.0)),
        "source": "local_fallback",
        "failure_reason": clean_text(failure_reason, 64),
    }


def sanitize_prediction_response(raw: dict[str, Any], fallback: dict[str, Any], request: PredictionRequest) -> dict[str, Any]:
    data = normalize_prediction_model_result(raw if isinstance(raw, dict) else {})
    if data.get("schema", PREDICTION_SCHEMA) != PREDICTION_SCHEMA:
        return fallback_prediction_response(request, "invalid_schema")
    legal_ids = action_ids(request.legal_actions)
    next_action = sanitize_prediction_action_bias(data.get("next_action_bias", {}), legal_ids)
    if not next_action:
        next_action = sanitize_prediction_action_bias(fallback.get("next_action_bias", {}), legal_ids)
    if not next_action:
        next_action = _first_legal_prediction_choice(request.legal_actions)
    risk_level = sanitize_prediction_risk_level(data.get("risk_level", fallback.get("risk_level", "none")), request)
    if not clean_text(next_action.get("reason", ""), 160):
        next_action["reason"] = _prediction_reason(request, next_action.get("action_id", ""), risk_level)
    priority_hints = sanitize_compact_priority_hints(data.get("priority_hints", fallback.get("priority_hints", {})))
    return {
        "schema": PREDICTION_SCHEMA,
        "context_hash": clean_text(request.context_hash, 160),
        "risk_level": risk_level,
        "prediction": clean_text(
            data.get("prediction", fallback.get("prediction", "Ari should follow the safest known next action.")),
            max(80, min(220, int(_float_value(request.max_words)) * 10)),
        ),
        "next_action_bias": next_action,
        "priority_hints": priority_hints,
        "avoid": sanitize_string_list(data.get("avoid", fallback.get("avoid", [])), 5, 120),
        "confidence": clamp01(data.get("confidence", fallback.get("confidence", 0.35))),
        "stale_after_seconds": max(1.0, min(5.0, _float_value(data.get("stale_after_seconds", 5.0)))),
        "source": clean_text(data.get("source", "remote_server"), 64) or "remote_server",
        "failure_reason": clean_text(data.get("failure_reason", ""), 64),
    }


def normalize_prediction_model_result(raw: dict[str, Any]) -> dict[str, Any]:
    data = raw if isinstance(raw, dict) else {}
    if any(key in data for key in ("risk_level", "prediction", "next_action_bias", "priority_hints")):
        return data
    action_id = clean_text(data.get("a", data.get("action", "")), 80)
    reason = clean_text(data.get("why", data.get("reason", "")), 180)
    priority_hints = data.get("h", data.get("hints", {}))
    return {
        "schema": PREDICTION_SCHEMA,
        "risk_level": data.get("r", data.get("risk", "none")),
        "prediction": reason or "Ari should follow the strongest current survival cue.",
        "next_action_bias": {
            "action_id": action_id,
            "urgency": data.get("u", data.get("urgency", 0.5)),
            "reason": reason,
        },
        "priority_hints": priority_hints,
        "avoid": data.get("avoid", data.get("av", [])),
        "confidence": data.get("c", data.get("confidence", 0.5)),
        "stale_after_seconds": data.get("stale_after_seconds", data.get("stale", 5.0)),
        "source": data.get("source", "remote_server"),
        "failure_reason": data.get("failure_reason", ""),
    }


def fallback_prediction_response(request: PredictionRequest, failure_reason: str = "local_fallback") -> dict[str, Any]:
    legal_ids = action_ids(request.legal_actions)
    strategy = request.strategy_packet if isinstance(request.strategy_packet, dict) else {}
    priority_hints = sanitize_compact_priority_hints(strategy.get("priority_hints", {}))
    risk_level = sanitize_prediction_risk_level("", request)
    action_id = _prediction_fallback_action(request, legal_ids, priority_hints)
    if action_id:
        priority_hints[action_id] = max(priority_hints.get(action_id, 0.0), 0.65 if risk_level in {"high", "lethal"} else 0.45)
    reason = _prediction_reason(request, action_id, risk_level)
    raw = {
        "schema": PREDICTION_SCHEMA,
        "context_hash": request.context_hash,
        "risk_level": risk_level,
        "prediction": reason,
        "next_action_bias": {"action_id": action_id, "urgency": _prediction_urgency(risk_level), "reason": reason},
        "priority_hints": priority_hints,
        "avoid": _prediction_avoid_list(request),
        "confidence": 0.35,
        "stale_after_seconds": 5.0,
        "source": "local_fallback",
        "failure_reason": clean_text(failure_reason, 64),
    }
    return sanitize_prediction_response(raw, raw, request)


def sanitize_prediction_risk_level(value: Any, request: PredictionRequest | None = None) -> str:
    text = clean_text(value, 40).lower().replace("-", "_").replace(" ", "_")
    if text in PREDICTION_RISK_LEVELS:
        return text
    if request is not None:
        max_severity = 0.0
        for risk in request.risks:
            max_severity = max(max_severity, clamp01(risk.severity))
        if max_severity >= 0.9:
            return "high"
        if max_severity >= 0.65:
            return "medium"
        if max_severity > 0.0:
            return "low"
    return "none"


def sanitize_prediction_action_bias(raw_action: Any, legal_ids: set[str] | None) -> dict[str, Any]:
    if not isinstance(raw_action, dict):
        return {}
    action_id = clean_text(raw_action.get("action_id", raw_action.get("id", "")), 80)
    if not action_id:
        return {}
    if legal_ids is not None and action_id not in legal_ids:
        return {}
    return {
        "action_id": action_id,
        "urgency": clamp01(raw_action.get("urgency", 0.5)),
        "reason": clean_text(raw_action.get("reason", ""), 140),
    }


def _first_legal_prediction_choice(legal_actions: list[AgentPlanAction] | list[dict[str, Any]] | None) -> dict[str, Any]:
    choice = _first_legal_action_choice(legal_actions, "wait_or_idle")
    return {
        "action_id": choice.get("action_id", "wait_or_idle"),
        "urgency": clamp01(choice.get("urgency", 0.25)),
        "reason": clean_text(choice.get("reason", "Use the first legal safe action."), 140),
    }


def _prediction_fallback_action(request: PredictionRequest, legal_ids: set[str] | None, priority_hints: dict[str, float]) -> str:
    legal_ids = legal_ids or set()
    risk_types = {clean_text(risk.type, 80).lower() for risk in request.risks}
    if "flying" in risk_types and "build_storm_rod" in legal_ids:
        return "build_storm_rod"
    hp_ratio = _ari_hp_ratio(request.ari)
    if hp_ratio <= 0.35:
        for action_id in ("use_cover", "flee", "rest"):
            if action_id in legal_ids:
                return action_id
    if priority_hints:
        for action_id, _value in sorted(priority_hints.items(), key=lambda item: item[1], reverse=True):
            if action_id in legal_ids:
                return action_id
    current_plan = request.current_plan if isinstance(request.current_plan, dict) else {}
    raw_next = current_plan.get("next_action", "")
    next_id = clean_text(raw_next.get("action_id", "") if isinstance(raw_next, dict) else raw_next, 80)
    if next_id in legal_ids:
        return next_id
    for action_id in ("use_cover", "flee", "mine_stone", "build_wall", "wait_or_idle"):
        if action_id in legal_ids:
            return action_id
    return next(iter(legal_ids), "wait_or_idle")


def _prediction_reason(request: PredictionRequest, action_id: str, risk_level: str) -> str:
    risk_types = [clean_text(risk.type, 60) for risk in request.risks if clean_text(risk.type, 60)]
    if "flying" in {item.lower() for item in risk_types} and action_id == "build_storm_rod":
        return "Flying danger is present, so Ari should answer the sky before ordinary walls."
    if risk_level in {"high", "lethal"} and action_id in {"use_cover", "flee"}:
        return "Immediate danger is high, so Ari should create distance before slower work."
    if action_id == "mine_stone":
        return "Ari needs resources before the stronger defensive action is possible."
    if action_id:
        return "Ari should bias toward %s for the next few seconds." % action_id.replace("_", " ")
    return "Ari should keep the safest deterministic action until a clearer prediction arrives."


def _prediction_urgency(risk_level: str) -> float:
    return {"lethal": 1.0, "high": 0.85, "medium": 0.65, "low": 0.45, "none": 0.3}.get(risk_level, 0.35)


def _prediction_avoid_list(request: PredictionRequest) -> list[str]:
    strategy = request.strategy_packet if isinstance(request.strategy_packet, dict) else {}
    avoid = sanitize_string_list(strategy.get("avoid_repeating", []), 4, 120)
    risk_types = {clean_text(risk.type, 60).lower() for risk in request.risks}
    if "flying" in risk_types and "ordinary walls before sky answer" not in avoid:
        avoid.append("ordinary walls before sky answer")
    return avoid[:5]


def _ari_hp_ratio(ari: dict[str, Any]) -> float:
    if not isinstance(ari, dict):
        return 1.0
    hp = _float_value(ari.get("hp", 100.0))
    max_hp = max(1.0, _float_value(ari.get("max_hp", 100.0)))
    return hp / max_hp


def sanitize_scribe_response(raw: dict[str, Any], fallback: dict[str, Any]) -> dict[str, Any]:
    data = raw if isinstance(raw, dict) else {}
    note = clean_text(data.get("note", fallback.get("note", "")), 300)
    if not note:
        note = fallback.get("note", "Ari noticed recent events.")
    plan_alignment = sanitize_scribe_plan_alignment(
        data.get("plan_alignment", fallback.get("plan_alignment", "unknown"))
    )
    immediate_risk = sanitize_scribe_risk_level(data.get("immediate_risk", fallback.get("immediate_risk", "none")))
    return {
        "schema": SCRIBE_NOTE_SCHEMA,
        "t_start": max(0.0, _float_value(data.get("t_start", fallback.get("t_start", 0.0)))),
        "t_end": max(0.0, _float_value(data.get("t_end", fallback.get("t_end", 0.0)))),
        "note": note,
        "tags": sanitize_string_list(data.get("tags", fallback.get("tags", [])), MAX_SCRIBE_TAGS, 40),
        "facts": sanitize_string_list(data.get("facts", fallback.get("facts", [])), MAX_SCRIBE_FACTS, 120),
        "actions": sanitize_scribe_actions(data.get("actions", fallback.get("actions", []))),
        "dangers": sanitize_scribe_dangers(data.get("dangers", fallback.get("dangers", []))),
        "world_changes": sanitize_string_list(
            data.get("world_changes", fallback.get("world_changes", data.get("notable_changes", []))),
            MAX_SCRIBE_WORLD_CHANGES,
            80,
        ),
        "priority_hints": sanitize_compact_priority_hints(data.get("priority_hints", fallback.get("priority_hints", {}))),
        "plan_alignment": plan_alignment,
        "immediate_risk": immediate_risk,
        "risk_reason": clean_text(data.get("risk_reason", fallback.get("risk_reason", "")), 180),
        "resource_blockers": sanitize_string_list(
            data.get("resource_blockers", fallback.get("resource_blockers", [])),
            MAX_SCRIBE_DECISION_ITEMS,
            80,
        ),
        "mistake_candidates": sanitize_string_list(
            data.get("mistake_candidates", fallback.get("mistake_candidates", [])),
            MAX_SCRIBE_DECISION_ITEMS,
            140,
        ),
        "opportunity_candidates": sanitize_string_list(
            data.get("opportunity_candidates", fallback.get("opportunity_candidates", [])),
            MAX_SCRIBE_DECISION_ITEMS,
            140,
        ),
        "lesson_candidates": sanitize_string_list(
            data.get("lesson_candidates", fallback.get("lesson_candidates", [])),
            MAX_SCRIBE_DECISION_ITEMS,
            140,
        ),
        "confidence": clamp01(data.get("confidence", fallback.get("confidence", 0.35))),
        "salience": clamp01(data.get("salience", fallback.get("salience", 0.3))),
        "source": clean_text(data.get("source", "remote_server"), 64) or "remote_server",
        "failure_reason": clean_text(data.get("failure_reason", ""), 64),
        "origin": clean_text(data.get("origin", fallback.get("origin", "")), 80),
        "evidence_ids": sanitize_string_list(
            data.get("evidence_ids", fallback.get("evidence_ids", data.get("evidence_snapshot_ids", []))),
            12,
            120,
        ),
        "behavior_evidence": sanitize_behavior_evidence_list(
            data.get("behavior_evidence", fallback.get("behavior_evidence", [])),
            3,
        ),
    }


def sanitize_behavior_evidence_list(raw_items: Any, max_count: int = MAX_BEHAVIOR_EVIDENCE_ITEMS) -> list[dict[str, Any]]:
    if isinstance(raw_items, dict):
        raw_items = [raw_items]
    if not isinstance(raw_items, list):
        return []
    result: list[dict[str, Any]] = []
    for item in raw_items:
        if not isinstance(item, dict):
            continue
        pattern = clean_text(item.get("primary_pattern", ""), 80)
        if not pattern:
            continue
        context = item.get("context", {})
        safe_context: dict[str, Any] = {}
        if isinstance(context, dict):
            safe_context = {
                "phase": clean_text(context.get("phase", ""), 40),
                "enemy_count_before": max(0, int(_float_value(context.get("enemy_count_before", 0)))),
                "enemy_count_after": max(0, int(_float_value(context.get("enemy_count_after", 0)))),
                "nearest_danger_changed": bool(context.get("nearest_danger_changed", False)),
                "active_plan_changed": bool(context.get("active_plan_changed", False)),
            }
        progress = item.get("progress_delta", {})
        safe_progress: dict[str, int] = {}
        if isinstance(progress, dict):
            safe_progress = {
                "structures": int(_float_value(progress.get("structures", 0))),
                "stone": int(_float_value(progress.get("stone", 0))),
                "repairs": int(_float_value(progress.get("repairs", 0))),
                "kills": int(_float_value(progress.get("kills", 0))),
                "hp": int(_float_value(progress.get("hp", 0))),
            }
        result.append(
            {
                "schema": BEHAVIOR_EVIDENCE_SCHEMA,
                "window_seconds": max(0.0, min(_float_value(item.get("window_seconds", 0.0)), 120.0)),
                "primary_pattern": pattern,
                "actions_seen": sanitize_string_list(item.get("actions_seen", []), 8, 80),
                "transition_count": max(0, int(_float_value(item.get("transition_count", 0)))),
                "completion_count": max(0, int(_float_value(item.get("completion_count", 0)))),
                "blocked_count": max(0, int(_float_value(item.get("blocked_count", 0)))),
                "abandoned_count": max(0, int(_float_value(item.get("abandoned_count", 0)))),
                "anchors_seen": sanitize_string_list(item.get("anchors_seen", []), 8, 80),
                "anchor_transition_count": max(0, int(_float_value(item.get("anchor_transition_count", 0)))),
                "progress_delta": safe_progress,
                "context": safe_context,
                "evidence_ids": sanitize_string_list(item.get("evidence_ids", []), 12, 120),
                "neutral_summary": clean_text(item.get("neutral_summary", ""), 220),
            }
        )
        if len(result) >= max_count:
            break
    return result


def sanitize_scribe_plan_alignment(value: Any) -> str:
    text = clean_text(value, 40).lower().replace("-", "_").replace(" ", "_")
    if text == "support":
        text = "supporting"
    return text if text in SCRIBE_PLAN_ALIGNMENTS else "unknown"


def sanitize_scribe_risk_level(value: Any) -> str:
    text = clean_text(value, 40).lower().replace("-", "_").replace(" ", "_")
    return text if text in SCRIBE_RISK_LEVELS else "none"


def fallback_scribe_response(payload: dict[str, Any], failure_reason: str = "local_fallback") -> dict[str, Any]:
    last_event_type = "none"
    events = payload.get("recent_events", [])
    if isinstance(events, list):
        for item in reversed(events):
            if isinstance(item, dict):
                candidate = clean_text(item.get("type", "event"), 80) or "event"
                if candidate not in INTERNAL_SCRIBE_EVENT_TYPES:
                    last_event_type = candidate
                    break
    snapshots = payload.get("snapshots", payload.get("recent_snapshots", []))
    current_action = clean_text(payload.get("current_action", "unknown"), 80)
    current_reason = clean_text(payload.get("current_reason", ""), 120)
    fear = _float_value(payload.get("fear", 0.0))
    facts: list[str] = []
    actions: list[dict[str, Any]] = []
    dangers: list[dict[str, Any]] = []
    world_changes: list[str] = []
    priority_hints: dict[str, float] = {}
    resource_blockers: list[str] = []
    nearest_danger_type = ""
    nearest_danger_distance = 0.0
    recent_damage = 0.0
    planned_action = ""
    evidence_ids: list[str] = []
    active_plan = payload.get("active_plan", {})
    if isinstance(active_plan, dict):
        raw_next_action = active_plan.get("next_action", "")
        if isinstance(raw_next_action, dict):
            planned_action = clean_text(raw_next_action.get("action_id", raw_next_action.get("id", "")), 80)
        else:
            planned_action = clean_text(raw_next_action, 80)
    snapshot_rows = [item for item in snapshots if isinstance(item, dict)] if isinstance(snapshots, list) else []
    behavior_evidence = sanitize_behavior_evidence_list(payload.get("behavior_evidence", []), 3)
    if snapshot_rows:
        latest = snapshot_rows[-1]
        if isinstance(latest, dict):
            ari = latest.get("ari", {})
            if isinstance(ari, dict):
                current_action = clean_text(ari.get("current_action", ari.get("current_job", current_action)), 80)
                current_reason = clean_text(ari.get("current_reason", current_reason), 120)
                fear = _float_value(ari.get("fear", fear))
            plan = latest.get("plan", {})
            if isinstance(plan, dict) and not planned_action:
                planned_action = clean_text(plan.get("next_action", ""), 80)
        evidence = _select_scribe_evidence_snapshot(snapshot_rows)
        evidence_id = clean_text(evidence.get("snapshot_id", ""), 120) if isinstance(evidence, dict) else ""
        if evidence_id:
            evidence_ids.append(evidence_id)
        world = evidence.get("world", {}) if isinstance(evidence, dict) else {}
        if isinstance(world, dict):
            nearest_danger = world.get("nearest_danger", {})
            if isinstance(nearest_danger, dict):
                danger_type = clean_text(nearest_danger.get("type", ""), 60)
                distance = max(0.0, _float_value(nearest_danger.get("distance", 0.0)))
                if danger_type and danger_type != "none":
                    nearest_danger_type = danger_type
                    nearest_danger_distance = distance
                    dangers.append({"type": danger_type, "distance": distance, "severity": 0.7})
                    facts.append("Nearest danger was %s at %.0f distance." % (danger_type, distance))
                    if danger_type == "flying":
                        _apply_flying_scribe_priority_hints(priority_hints, 0.45)
            enemies = world.get("enemies", {})
            if isinstance(enemies, dict):
                enemy_count = int(_float_value(enemies.get("count", 0)))
                if enemy_count > 0:
                    facts.append("Ari saw %d enemy threat(s)." % enemy_count)
                enemy_types = enemies.get("types", {})
                if isinstance(enemy_types, dict) and _float_value(enemy_types.get("flying", 0)) > 0:
                    flying_fact = "Flying enemies were present; ordinary walls may not solve them."
                    if flying_fact not in facts:
                        facts.append(flying_fact)
                    _apply_flying_scribe_priority_hints(priority_hints, 0.55)
            resources = world.get("resources", {})
            if isinstance(resources, dict) and _float_value(resources.get("stone", 99)) <= 3:
                resource_blockers.append("low_stone")
            recent_damage = max(recent_damage, _float_value(world.get("recent_damage", 0.0)))
            world_changes = sanitize_string_list(world.get("notable_changes", []), MAX_SCRIBE_WORLD_CHANGES, 80)
        for snapshot in snapshot_rows:
            behavior_evidence.extend(sanitize_behavior_evidence_list(snapshot.get("behavior_evidence", []), 3))
            behavior_evidence = behavior_evidence[:3]
        _preserve_recent_flying_scribe_evidence(snapshot_rows, facts, world_changes, priority_hints, evidence_ids)
    plan_relation = _scribe_plan_relation(current_action, current_reason, planned_action)
    plan_body_mismatch = plan_relation == "mismatch"
    plan_support = plan_relation == "support"
    current_reason = _sanitize_scribe_current_reason(current_reason, current_action)
    if current_action and current_action != "unknown":
        actions.append({"action": current_action, "status": "in_progress", "reason": current_reason})
        facts.insert(0, "Ari was %s." % _scribe_action_phrase(current_action))
    if plan_body_mismatch:
        actions.append({"action": planned_action, "status": "planned", "reason": "Ari's active plan expected this action."})
        facts.append("Ari's body action did not match the active plan: planned %s." % _humanize_key(planned_action))
    elif plan_support:
        actions.append({"action": planned_action, "status": "supported", "reason": "Ari's current action prepared or protected this plan."})
        facts.append("Ari's body action supported the active plan: planned %s." % _humanize_key(planned_action))
    if last_event_type != "none":
        facts.append("Recent event was %s." % _humanize_key(last_event_type))
    if not world_changes and last_event_type != "none":
        world_changes.append(last_event_type)
    tags = ["local_fallback"]
    if last_event_type != "none":
        tags.append(last_event_type)
    if nearest_danger_type:
        tags.append("danger:%s" % nearest_danger_type)
    if priority_hints.get("build_storm_rod", 0.0) > 0 and "danger:flying" not in tags:
        tags.append("danger:flying")
    if fear >= 70.0:
        tags.append("fear_high")
    if plan_body_mismatch:
        tags.append("plan_body_mismatch")
        if "plan_body_mismatch" not in world_changes:
            world_changes.append("plan_body_mismatch")
    elif plan_support:
        tags.append("plan_support")
        if "plan_support" not in world_changes:
            world_changes.append("plan_support")
    plan_alignment = "mismatch" if plan_body_mismatch else "supporting" if plan_support else "aligned" if planned_action else "unknown"
    immediate_risk = _scribe_immediate_risk(nearest_danger_type, nearest_danger_distance, recent_damage, plan_alignment)
    risk_reason = _scribe_risk_reason(nearest_danger_type, nearest_danger_distance, recent_damage, plan_alignment)
    mistake_candidates: list[str] = []
    opportunity_candidates: list[str] = []
    lesson_candidates: list[str] = []
    for evidence in behavior_evidence:
        pattern = clean_text(evidence.get("primary_pattern", ""), 80)
        neutral = clean_text(evidence.get("neutral_summary", ""), 220)
        if neutral and neutral not in facts:
            facts.append(neutral)
        if pattern:
            if pattern not in world_changes:
                world_changes.append(pattern)
            if pattern == "repeated_action_switching" and "repeated switching happened without progress" not in mistake_candidates:
                mistake_candidates.append("repeated switching happened without progress")
            review_lesson = "review whether %s helped survival" % pattern
            if review_lesson not in lesson_candidates:
                lesson_candidates.append(review_lesson)
        for evidence_id in sanitize_string_list(evidence.get("evidence_ids", []), 12, 120):
            if evidence_id not in evidence_ids:
                evidence_ids.append(evidence_id)
    if plan_body_mismatch:
        mistake_candidates.append(
            "body action %s diverged from planned %s" % (
                _normalize_action_key(current_action),
                _normalize_action_key(planned_action),
            )
        )
        lesson_candidates.append("compare Ari's body action with the active plan before trusting the moment")
    if nearest_danger_type == "flying" or priority_hints.get("build_storm_rod", 0.0) > 0:
        opportunity_candidates.append("build storm rod before ordinary wall work")
        lesson_candidates.append("when wings appear, answer the sky first")
    elif plan_support and planned_action:
        opportunity_candidates.append("continue support toward %s" % _normalize_action_key(planned_action))
    elif nearest_danger_type:
        opportunity_candidates.append("respond to nearest danger before routine chores")
    note_parts = ["Ari was %s" % _scribe_action_phrase(current_action or "acting")]
    if current_reason:
        note_parts.append("because %s" % current_reason)
    if nearest_danger_type:
        note_parts.append("nearest danger was %s at %.0f" % (_humanize_key(nearest_danger_type), nearest_danger_distance))
    if plan_body_mismatch:
        note_parts.append("while plan expected %s" % _humanize_key(planned_action))
    elif plan_support:
        note_parts.append("supporting plan %s" % _humanize_key(planned_action))
    elif planned_action:
        note_parts.append("plan was %s" % _humanize_key(planned_action))
    if last_event_type != "none":
        note_parts.append("recent event was %s" % _humanize_key(last_event_type))
    raw = {
        "schema": SCRIBE_NOTE_SCHEMA,
        "note": clean_text("; ".join(note_parts) + ".", 300),
        "tags": tags,
        "facts": facts,
        "actions": actions,
        "dangers": dangers,
        "world_changes": world_changes,
        "priority_hints": priority_hints,
        "plan_alignment": plan_alignment,
        "immediate_risk": immediate_risk,
        "risk_reason": risk_reason,
        "resource_blockers": resource_blockers,
        "mistake_candidates": mistake_candidates,
        "opportunity_candidates": opportunity_candidates,
        "lesson_candidates": lesson_candidates,
        "confidence": 0.25,
        "salience": 0.45 if last_event_type != "none" else 0.25,
        "source": "local_fallback",
        "failure_reason": clean_text(failure_reason, 64),
        "origin": "deterministic_scribe" if failure_reason == "deterministic_scribe" else "fallback_scribe",
        "evidence_ids": evidence_ids,
        "behavior_evidence": behavior_evidence,
    }
    return sanitize_scribe_response(raw, raw)


def _scribe_immediate_risk(danger_type: str, distance: float, recent_damage: float, plan_alignment: str) -> str:
    if recent_damage >= 40.0:
        return "lethal"
    if danger_type == "flying":
        return "high"
    if danger_type:
        if distance <= 32.0 or recent_damage >= 20.0:
            return "high"
        if distance <= 150.0 or plan_alignment == "mismatch":
            return "medium"
        return "low"
    if plan_alignment == "mismatch":
        return "medium"
    return "none"


def _scribe_risk_reason(danger_type: str, distance: float, recent_damage: float, plan_alignment: str) -> str:
    if danger_type == "flying":
        return "Flying enemies can bypass ordinary wall safety."
    if danger_type:
        return "Nearest danger was %s at %.0f distance." % (_humanize_key(danger_type), distance)
    if recent_damage > 0.0:
        return "Ari recently took %.0f damage." % recent_damage
    if plan_alignment == "mismatch":
        return "Ari's body action diverged from the active plan."
    return ""


def _preserve_recent_flying_scribe_evidence(
    snapshots: list[dict[str, Any]],
    facts: list[str],
    world_changes: list[str],
    priority_hints: dict[str, float],
    evidence_ids: list[str],
) -> bool:
    saw_flying = False
    for snapshot in snapshots:
        if not _snapshot_has_flying_scribe_evidence(snapshot):
            continue
        saw_flying = True
        snapshot_id = clean_text(snapshot.get("snapshot_id", ""), 120)
        if snapshot_id and snapshot_id not in evidence_ids:
            evidence_ids.append(snapshot_id)
        world = snapshot.get("world", {})
        if isinstance(world, dict):
            for change in sanitize_string_list(world.get("notable_changes", []), MAX_SCRIBE_WORLD_CHANGES, 80):
                if change not in world_changes and (
                    "flying" in change.lower() or "wing" in change.lower() or change == "first_flying_enemy_seen"
                ):
                    world_changes.append(change)
                    if len(world_changes) >= MAX_SCRIBE_WORLD_CHANGES:
                        break
    if not saw_flying:
        return False
    flying_fact = "Flying enemies were present; ordinary walls may not solve them."
    if flying_fact not in facts:
        facts.append(flying_fact)
    _apply_flying_scribe_priority_hints(priority_hints, 0.55)
    return True


def _snapshot_has_flying_scribe_evidence(snapshot: dict[str, Any]) -> bool:
    world = snapshot.get("world", {}) if isinstance(snapshot, dict) else {}
    if not isinstance(world, dict):
        return False
    nearest_danger = world.get("nearest_danger", {})
    if isinstance(nearest_danger, dict) and clean_text(nearest_danger.get("type", ""), 60).lower() == "flying":
        return True
    enemies = world.get("enemies", {})
    if isinstance(enemies, dict):
        enemy_types = enemies.get("types", {})
        if isinstance(enemy_types, dict) and _float_value(enemy_types.get("flying", 0)) > 0:
            return True
    notable_changes = world.get("notable_changes", [])
    if isinstance(notable_changes, list):
        return any("flying" in str(change).lower() or "wing" in str(change).lower() for change in notable_changes)
    return False


def _sanitize_scribe_current_reason(reason: str, current_action: str) -> str:
    text = clean_text(reason, 120)
    if not _scribe_reason_overstates_sign_hiding(text):
        return text
    categories = _scribe_action_categories(_normalize_action_key(current_action))
    if "combat" in categories:
        return "Ari chose direct fighting under danger"
    if "cover" in categories:
        return "Ari chose cover under danger"
    return "Ari chose this action under pressure"


def _scribe_action_phrase(action_id: str) -> str:
    action = _normalize_action_key(action_id)
    phrases = {
        "acting": "acting",
        "build_storm_rod": "building storm rod",
        "build_tower": "building tower",
        "fight_head_on": "fighting head on",
        "hide_until_dawn": "hiding until dawn",
        "mine_ore": "mining ore",
        "mine_stone": "mining stone",
        "repair_structure": "repairing structure",
        "stall_until_dawn": "stalling until dawn",
        "use_cover": "using cover",
        "use_tower": "using tower perch",
    }
    if action in phrases:
        return phrases[action]
    if action.startswith("moving_to_"):
        return "moving to %s" % _humanize_key(action.removeprefix("moving_to_"))
    if action.startswith("build_"):
        return "building %s" % _humanize_key(action.removeprefix("build_"))
    if action.startswith("use_"):
        return "using %s" % _humanize_key(action.removeprefix("use_"))
    if action.startswith("train_"):
        return "training %s" % _humanize_key(action.removeprefix("train_"))
    return _humanize_key(action_id)


def _scribe_reason_overstates_sign_hiding(reason: str) -> bool:
    text = clean_text(reason, 160).lower().replace("-", " ")
    return any(
        pattern in text
        for pattern in (
            "sign rejected hiding",
            "sign rejects hiding",
            "sign says not to hide",
            "sign said not to hide",
            "sign told ari not to hide",
            "do not hide",
            "don't hide",
        )
    )


def _select_scribe_evidence_snapshot(snapshots: list[dict[str, Any]]) -> dict[str, Any]:
    best: dict[str, Any] = snapshots[-1] if snapshots else {}
    best_score = -1.0
    for index, snapshot in enumerate(snapshots):
        score = _float_value(snapshot.get("salience", 0.0)) + index * 0.001
        world = snapshot.get("world", {})
        if isinstance(world, dict):
            nearest_danger = world.get("nearest_danger", {})
            if isinstance(nearest_danger, dict):
                danger_type = clean_text(nearest_danger.get("type", ""), 60)
                if danger_type and danger_type != "none":
                    score += 0.4
                    if danger_type == "flying":
                        score += 1.2
            enemies = world.get("enemies", {})
            if isinstance(enemies, dict):
                enemy_types = enemies.get("types", {})
                if isinstance(enemy_types, dict) and _float_value(enemy_types.get("flying", 0)) > 0:
                    score += 1.2
            notable_changes = world.get("notable_changes", [])
            if isinstance(notable_changes, list) and notable_changes:
                score += 0.2
                if any("flying" in str(change).lower() or "wing" in str(change).lower() for change in notable_changes):
                    score += 0.8
        if score > best_score:
            best_score = score
            best = snapshot
    return best


def _apply_flying_scribe_priority_hints(priority_hints: dict[str, float], storm_priority: float = 0.55) -> None:
    priority_hints["build_storm_rod"] = max(priority_hints.get("build_storm_rod", 0.0), storm_priority)
    priority_hints["build_tower"] = max(priority_hints.get("build_tower", 0.0), 0.35)
    priority_hints["use_tower"] = max(priority_hints.get("use_tower", 0.0), 0.25)


def deterministic_scribe_response(payload: dict[str, Any]) -> dict[str, Any]:
    raw = fallback_scribe_response(payload, "deterministic_scribe")
    raw["source"] = "deterministic_scribe"
    raw["failure_reason"] = ""
    return sanitize_scribe_response(raw, raw)


def _scribe_plan_relation(current_action: str, current_reason: str, planned_action: str) -> str:
    if not planned_action or _scribe_actions_aligned(current_action, planned_action):
        return "aligned"
    if _scribe_action_supports_plan(current_action, current_reason, planned_action):
        return "support"
    return "mismatch"


def _scribe_actions_aligned(current_action: str, planned_action: str) -> bool:
    current = _normalize_action_key(current_action)
    planned = _normalize_action_key(planned_action)
    if not current or not planned or current in {"unknown", "idle", "acting", "waiting_near_defenses"}:
        return True
    if current == planned or current in planned or planned in current:
        return True
    if current == "moving_to_build_site" and planned.startswith(("build_", "place_")):
        return True
    if current in {"moving_to_mine", "mining", "mining_ore"} and planned.startswith("mine_"):
        return True
    current_categories = _scribe_action_categories(current)
    planned_categories = _scribe_action_categories(planned)
    if current_categories and planned_categories:
        return bool(current_categories & planned_categories)
    return True


def _scribe_action_supports_plan(current_action: str, current_reason: str, planned_action: str) -> bool:
    current = _normalize_action_key(current_action)
    planned = _normalize_action_key(planned_action)
    reason = _normalize_action_key(current_reason)
    current_categories = _scribe_action_categories(current)
    planned_categories = _scribe_action_categories(planned)
    if not current or not planned:
        return False
    if "repair" in current_categories and (
        planned.startswith("use_")
        or planned_categories & {"tower", "storm", "cover", "aura", "thorn", "lantern", "decoy"}
    ):
        return True
    if "mine" in current_categories and (
        planned.startswith(("build_", "place_"))
        or planned in {"smith_sword", "repair_structure"}
        or planned_categories & {"tower", "storm", "cover", "aura", "thorn", "lantern", "decoy"}
    ):
        return True
    if "rest" in current_categories and "recover" in reason and planned_categories & {"tower", "storm", "combat", "cover"}:
        return True
    if "food" in current_categories and planned_categories & {"combat", "tower", "storm", "cover"}:
        return True
    defensive_hold_categories = {"tower", "storm", "cover", "aura", "thorn", "lantern", "decoy"}
    flexible_defensive_support_categories = {"cover", "thorn", "lantern", "decoy"}
    if (
        current_categories & flexible_defensive_support_categories
        and planned_categories & defensive_hold_categories
        and any(token in reason for token in ("night_is_quiet", "before", "hold", "stage", "safe"))
    ):
        return True
    return False


def _normalize_action_key(value: str) -> str:
    return clean_text(value, 80).lower().replace("-", "_").replace(" ", "_")


def _scribe_action_categories(action_id: str) -> set[str]:
    categories: set[str] = set()
    if any(token in action_id for token in ("tower", "bow", "ranged")):
        categories.add("tower")
    if "aura" in action_id or "lure" in action_id or "light" in action_id:
        categories.add("aura")
    if "storm" in action_id or "anti_air" in action_id:
        categories.add("storm")
    if any(token in action_id for token in ("wall", "cover", "hide", "stall", "survive")):
        categories.add("cover")
    if "repair" in action_id:
        categories.add("repair")
    if "mine" in action_id or "mining" in action_id:
        categories.add("mine")
    if "farm" in action_id or "food" in action_id:
        categories.add("food")
    if "rest" in action_id or "bed" in action_id or "sleep" in action_id:
        categories.add("rest")
    if any(token in action_id for token in ("sword", "combat", "fight", "weapon")):
        categories.add("combat")
    if "thorn" in action_id:
        categories.add("thorn")
    if "lantern" in action_id:
        categories.add("lantern")
    if "decoy" in action_id:
        categories.add("decoy")
    return categories


def sanitize_library_reflection_response(raw: dict[str, Any], fallback: dict[str, Any]) -> dict[str, Any]:
    data = normalize_library_reflection_model_result(raw)
    raw_hint_source = data.get(
        "priority_hints",
        data.get("priority_bias", fallback.get("priority_hints", fallback.get("priority_bias", {}))),
    )
    priority_hints = merge_priority_maps(
        sanitize_compact_priority_hints(raw_hint_source),
        sanitize_compact_priority_hints(fallback.get("priority_hints", fallback.get("priority_bias", {}))),
    )
    priority_bias = merge_priority_maps(
        sanitize_compact_priority_hints(data.get("priority_bias", raw_hint_source), signed=True),
        sanitize_compact_priority_hints(fallback.get("priority_bias", fallback.get("priority_hints", {})), signed=True),
    )
    belief_updates = merge_belief_updates(
        sanitize_reflection_belief_updates(data.get("belief_updates", [])),
        sanitize_reflection_belief_updates(fallback.get("belief_updates", [])),
    )
    doctrines = merge_doctrines(
        sanitize_doctrines(data.get("doctrines", [])),
        sanitize_doctrines(fallback.get("doctrines", [])),
    )
    markdown = clean_markdown(data.get("markdown_text", data.get("markdown", fallback.get("markdown", ""))), 2000)
    if not markdown:
        markdown = fallback.get("markdown", "# Ari's rough local reflection\n\nPreparation before night improves survival.")
    return {
        "schema": "ari.night_reflection.v1",
        "title": clean_text(data.get("title", fallback.get("title", "Ari's rough local reflection")), 120),
        "markdown": markdown,
        "markdown_text": markdown,
        "hypothesis": clean_text(data.get("hypothesis", data.get("lesson", fallback.get("hypothesis", ""))), 300),
        "what_changed": sanitize_string_list(data.get("what_changed", []), MAX_REFLECTION_LIST_ITEMS, 120),
        "worked": sanitize_string_list(data.get("worked", []), MAX_REFLECTION_LIST_ITEMS, 120),
        "went_wrong": sanitize_string_list(data.get("went_wrong", []), MAX_REFLECTION_LIST_ITEMS, 120),
        "misunderstood": sanitize_string_list(data.get("misunderstood", data.get("misread_sign", [])), MAX_REFLECTION_LIST_ITEMS, 120),
        "lesson": clean_text(data.get("lesson", data.get("hypothesis", fallback.get("hypothesis", ""))), 300),
        "tags": sanitize_string_list(data.get("tags", fallback.get("tags", [])), 8, 40),
        "plan": sanitize_string_dict(data.get("plan", fallback.get("plan", {})), 12, 80),
        "priority_hints": priority_hints,
        "priority_bias": priority_bias,
        "belief_updates": belief_updates,
        "doctrines": doctrines,
        "confidence": clamp01(data.get("confidence", fallback.get("confidence", 0.35))),
        "thought": clean_text(data.get("thought", fallback.get("thought", "I should prepare before the night gets close.")), 300),
        "source": clean_text(data.get("source", "remote_server"), 64) or "remote_server",
        "failure_reason": clean_text(data.get("failure_reason", ""), 64),
    }


def normalize_library_reflection_model_result(raw: dict[str, Any]) -> dict[str, Any]:
    data = raw.copy() if isinstance(raw, dict) else {}
    if any(key in data for key in ("schema", "title", "markdown", "priority_hints", "doctrines")):
        return data
    if not any(key in data for key in ("t", "m", "changed", "chg", "wrong", "bad", "mis", "h", "belief", "doctrine", "plan")):
        return data
    title = clean_text(data.get("t", data.get("title", "")), 120)
    markdown = clean_markdown(data.get("m", data.get("markdown", "")), 2000)
    lesson = clean_text(data.get("lesson", ""), 300)
    if markdown and title and not markdown.lstrip().startswith("#"):
        markdown = "# %s\n\n%s" % (title, markdown)
    belief_updates = _compact_reflection_belief_updates(data.get("belief", []), lesson)
    compact_plan = data.get("plan", [])
    doctrines = data.get("doctrine", data.get("doctrines", []))
    if not doctrines:
        doctrines = _compact_reflection_doctrine(data, lesson, compact_plan)
    return {
        "schema": "ari.night_reflection.v1",
        "title": title,
        "markdown": markdown,
        "markdown_text": markdown,
        "hypothesis": lesson,
        "what_changed": data.get("changed", data.get("chg", [])),
        "worked": data.get("worked", data.get("ok", [])),
        "went_wrong": data.get("wrong", data.get("bad", [])),
        "misunderstood": data.get("mis", []),
        "lesson": lesson,
        "priority_hints": data.get("h", {}),
        "priority_bias": data.get("bias", data.get("h", {})),
        "belief_updates": belief_updates,
        "doctrines": doctrines,
        "thought": data.get("thought", ""),
        "confidence": data.get("c", data.get("confidence", 0.35)),
        "source": data.get("source", "remote_server"),
        "failure_reason": data.get("failure_reason", ""),
    }


def _compact_reflection_belief_updates(raw_belief: Any, lesson: str) -> list[dict[str, Any]]:
    if isinstance(raw_belief, list):
        return raw_belief
    if not isinstance(raw_belief, dict):
        return []
    updates: list[dict[str, Any]] = []
    for raw_key, raw_delta in raw_belief.items():
        key = clean_text(raw_key, 80)
        if not key:
            continue
        updates.append(
            {
                "key": key,
                "delta": _float_value(raw_delta),
                "reason": lesson[:140],
            }
        )
        if len(updates) >= MAX_BELIEF_UPDATES:
            break
    return updates


def _compact_reflection_doctrine(data: dict[str, Any], lesson: str, raw_plan: Any) -> list[dict[str, Any]]:
    plan = _compact_reflection_doctrine_plan(raw_plan, data.get("h", {}), data.get("bias", {}), lesson)
    bias = sanitize_compact_priority_hints(data.get("bias", data.get("h", {})), signed=True)
    if not plan and not bias:
        return []
    first_action = plan[0]["affordance_id"] if plan else next(iter(bias.keys()), "survival")
    doctrine = {
        "id": "reflection_%s" % normalize_key(first_action),
        "summary": lesson or clean_text(data.get("m", "Ari formed a reflection lesson."), 220),
        "when": _compact_reflection_doctrine_when(data, first_action),
        "bias": bias,
        "plan": plan,
        "confidence": data.get("c", data.get("confidence", 0.5)),
    }
    return [doctrine]


def _compact_reflection_doctrine_plan(raw_plan: Any, hints: Any, bias: Any, lesson: str) -> list[dict[str, Any]]:
    if not isinstance(raw_plan, list):
        return []
    hint_map = sanitize_compact_priority_hints(hints)
    bias_map = sanitize_compact_priority_hints(bias, signed=True)
    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    for raw_item in raw_plan:
        if isinstance(raw_item, dict):
            action_id = clean_text(raw_item.get("affordance_id", raw_item.get("action_id", raw_item.get("id", ""))), 80)
        else:
            action_id = clean_text(raw_item, 80)
        if action_id not in ALLOWED_PRIORITY_KEYS or action_id in seen:
            continue
        priority = hint_map.get(action_id, abs(bias_map.get(action_id, 0.0)) or 0.6)
        result.append(
            {
                "affordance_id": action_id,
                "priority": clamp01(priority),
                "reason": lesson[:180],
            }
        )
        seen.add(action_id)
        if len(result) >= MAX_AGENT_PLAN_STEPS:
            break
    return result


def _compact_reflection_doctrine_when(data: dict[str, Any], first_action: str) -> dict[str, Any]:
    text = " ".join(
        [
            str(data.get("m", "")),
            str(data.get("lesson", "")),
            " ".join(str(value) for value in data.get("chg", data.get("changed", [])) if isinstance(data.get("chg", data.get("changed", [])), list)),
            first_action,
        ]
    ).lower()
    if "flying" in text or "wing" in text or first_action in {"build_storm_rod", "anti_air_defense", "anti_flying", "sky_answer"}:
        return {"enemy_type_present": "flying"}
    if "hurt" in text or "bleed" in text or first_action in {"use_cover", "flee"}:
        return {"max_hp_ratio": 0.65}
    return {"min_day": 1}


def fallback_library_reflection_response(payload: dict[str, Any], failure_reason: str = "local_fallback") -> dict[str, Any]:
    day = int(_float_value(payload.get("day", 0)))
    events = payload.get("recent_events", [])
    last_event_type = "recent events"
    if isinstance(events, list):
        for item in reversed(events):
            if isinstance(item, dict):
                last_event_type = clean_text(item.get("type", "event"), 80) or "event"
                break
    title = "Day %d - Ari's rough local reflection" % day if day > 0 else "Ari's rough local reflection"
    if _payload_mentions_text(payload, "plan_support") and (
        _payload_mentions_text(payload, "repair_structure") or _payload_mentions_text(payload, "use_tower")
    ):
        markdown = "# %s\n\nAri saw a plan_support moment: repair_structure kept the use_tower plan alive instead of contradicting it. Damaged ranged defenses should be patched before Ari trusts the perch again." % title
        raw = {
            "schema": "ari.night_reflection.v1",
            "title": title,
            "markdown": markdown,
            "hypothesis": "Repairing a damaged tower can support the ranged plan instead of delaying it.",
            "what_changed": ["tower_damaged", "ranged_hits_succeeded"],
            "worked": ["repair_structure supported use_tower"],
            "went_wrong": ["damaged tower support reduced the ranged plan's safety"],
            "misunderstood": [],
            "lesson": "When the tower plan is working but damaged, repair_structure before continuing use_tower.",
            "tags": ["local_fallback", "plan_support", "structure:tower"],
            "priority_hints": {"use_tower": 0.45, "repair_structure": 0.35, "build_tower": 0.2},
            "priority_bias": {"use_tower": 0.28, "repair_structure": 0.24, "build_tower": 0.12},
            "belief_updates": [
                {"key": "repair_can_support_ranged_plan", "delta": 0.2, "reason": "Structured notes showed repair_structure supporting use_tower."}
            ],
            "doctrines": [
                {
                    "id": "local_tower_repair_supports_ranged_plan",
                    "summary": "If the ranged tower plan is active and the tower is damaged, repair it before relying on it.",
                    "when": {"min_day": 1},
                    "bias": {"repair_structure": 0.24, "use_tower": 0.22, "build_tower": 0.1},
                    "plan": [
                        {
                            "affordance_id": "repair_structure",
                            "priority": 0.62,
                            "reason": "Patch the damaged tower so the ranged plan stays safe.",
                        },
                        {
                            "affordance_id": "use_tower",
                            "priority": 0.52,
                            "reason": "Use the perch after repair restores the ranged advantage.",
                        },
                    ],
                    "confidence": 0.42,
                }
            ],
            "confidence": 0.35,
            "thought": "Repair was not hesitation; it kept the arrow plan alive.",
            "source": "local_fallback",
            "failure_reason": clean_text(failure_reason, 64),
        }
        return sanitize_library_reflection_response(raw, raw)
    if _payload_mentions_text(payload, "plan_body_mismatch") and _payload_mentions_text(payload, "fight_head_on"):
        markdown = "# %s\n\nAri remembers a plan_body_mismatch: his body chose fight_head_on while the safer plan expected hide_until_dawn. Direct courage still needs cover when damage spikes." % title
        raw = {
            "schema": "ari.night_reflection.v1",
            "title": title,
            "markdown": markdown,
            "hypothesis": "When direct fighting causes a mismatch with survival, cover should come before more contact.",
            "what_changed": ["near_death_warning", "ari_melee_hit"],
            "worked": [],
            "went_wrong": ["fight_head_on contradicted hide_until_dawn"],
            "misunderstood": ["Ari treated direct fighting as safe even when the survival plan disagreed"],
            "lesson": "If fight_head_on creates a plan_body_mismatch under danger, use_cover or flee before taking more hits.",
            "tags": ["local_fallback", "plan_body_mismatch", "danger:brute"],
            "priority_hints": {"use_cover": 0.5, "flee": 0.25, "hide_until_dawn": 0.2},
            "priority_bias": {"use_cover": 0.34, "flee": 0.18, "fight_head_on": -0.18},
            "belief_updates": [
                {"key": "open_melee_needs_cover_when_hurt", "delta": 0.2, "reason": "Structured notes showed fight_head_on diverging from hide_until_dawn."}
            ],
            "doctrines": [
                {
                    "id": "local_overcommit_requires_cover",
                    "summary": "When direct combat causes near-death or plan mismatch, Ari should use cover before more contact.",
                    "when": {"max_hp_ratio": 0.65},
                    "bias": {"use_cover": 0.34, "flee": 0.16, "fight_head_on": -0.18},
                    "plan": [
                        {
                            "affordance_id": "use_cover",
                            "priority": 0.68,
                            "reason": "Break direct contact before continuing a risky combat plan.",
                        },
                        {
                            "affordance_id": "flee",
                            "priority": 0.42,
                            "reason": "Create distance if cover is not immediately safe.",
                        },
                    ],
                    "confidence": 0.4,
                }
            ],
            "confidence": 0.35,
            "thought": "A brave body still needs a place to stop bleeding.",
            "source": "local_fallback",
            "failure_reason": clean_text(failure_reason, 64),
        }
        return sanitize_library_reflection_response(raw, raw)
    if _payload_mentions_any_text(payload, ("flying", "wings", "winged")):
        markdown = "# %s\n\nAri remembers %s and flying danger. Ordinary walls were not enough by themselves, so the local anti_air_defense lesson is to answer the sky before stacking more wall." % (
            title,
            last_event_type,
        )
        raw = {
            "schema": "ari.night_reflection.v1",
            "title": title,
            "markdown": markdown,
            "hypothesis": "Flying enemies need a sky answer before ordinary wall stacking.",
            "what_changed": ["flying enemies appeared"],
            "worked": ["structured scribe notes preserved the flying danger"],
            "went_wrong": ["ordinary wall thinking was not enough"],
            "misunderstood": ["Ari treated flying danger like ground danger"],
            "lesson": "When flying enemies appear, prioritize anti_air_defense: storm rods or other sky answers before extra walls.",
            "tags": ["local_fallback", "flying", "anti_air_defense"],
            "priority_hints": {"anti_air_defense": 0.65, "build_storm_rod": 0.55, "build_tower": 0.35, "use_tower": 0.25},
            "priority_bias": {"anti_air_defense": 0.35, "build_storm_rod": 0.45, "build_tower": 0.22, "use_tower": 0.18, "build_wall": -0.1},
            "belief_updates": [
                {"key": "flying_needs_sky_answer", "delta": 0.25, "reason": "Fallback reflection saw flying danger in structured notes."}
            ],
            "doctrines": [
                {
                    "id": "local_flying_requires_sky_answer",
                    "summary": "When flying enemies appear, Ari should answer the sky before stacking ordinary walls.",
                    "when": {"enemy_type_present": "flying"},
                    "bias": {"build_storm_rod": 0.45, "build_tower": 0.22, "use_tower": 0.18, "build_wall": -0.1},
                    "plan": [
                        {
                            "affordance_id": "build_storm_rod",
                            "priority": 0.75,
                            "reason": "Flying danger needs a sky defense.",
                        },
                        {
                            "affordance_id": "build_tower",
                            "priority": 0.55,
                            "reason": "After the storm answer, ranged support keeps Ari away from wings.",
                        },
                        {
                            "affordance_id": "use_tower",
                            "priority": 0.45,
                            "reason": "Use the ranged perch once it exists.",
                        },
                    ],
                    "confidence": 0.45,
                }
            ],
            "confidence": 0.35,
            "thought": "Wings need an answer above the wall.",
            "source": "local_fallback",
            "failure_reason": clean_text(failure_reason, 64),
        }
        return sanitize_library_reflection_response(raw, raw)
    markdown = "# %s\n\nAri remembers %s. The deeper reflection model was unavailable, so he keeps the local lesson: preparation before night improves survival." % (
        title,
        last_event_type,
    )
    raw = {
        "schema": "ari.night_reflection.v1",
        "title": title,
        "markdown": markdown,
        "hypothesis": "Preparation before night improves survival.",
        "tags": ["local_fallback", last_event_type],
        "priority_hints": {"build_wall": 0.08, "place_aura_orb": 0.08},
        "priority_bias": {"build_wall": 0.08, "place_aura_orb": 0.08},
        "belief_updates": [],
        "doctrines": [],
        "confidence": 0.25,
        "thought": "I remember enough to prepare earlier.",
        "source": "local_fallback",
        "failure_reason": clean_text(failure_reason, 64),
    }
    return sanitize_library_reflection_response(raw, raw)


def sanitize_background_job_response(
    raw: dict[str, Any],
    fallback: dict[str, Any],
    request: BackgroundJobRequest,
) -> dict[str, Any]:
    data = normalize_background_job_model_result(raw, request)
    if data.get("schema", "ari.background_result.v1") != "ari.background_result.v1":
        return fallback_background_job_response(request, "invalid_schema")
    status = clean_text(data.get("status", "ok"), 32).lower()
    if status not in BACKGROUND_RESULT_STATUSES:
        status = "fallback"
    strategy_packet = sanitize_strategy_packet(
        data.get("strategy_packet", fallback.get("strategy_packet", {})),
        fallback.get("strategy_packet", {}),
    )
    priority_hints = merge_priority_maps(
        sanitize_compact_priority_hints(data.get("priority_hints", strategy_packet.get("priority_hints", {}))),
        sanitize_compact_priority_hints(strategy_packet.get("priority_hints", {})),
    )
    return {
        "schema": "ari.background_result.v1",
        "job_id": clean_text(request.job_id, 120),
        "kind": request.kind,
        "context_hash": clean_text(request.context_hash, 160),
        "status": status,
        "notes": sanitize_string_list(data.get("notes", fallback.get("notes", [])), 6, 180),
        "priority_hints": priority_hints,
        "strategy_packet": strategy_packet,
        "confidence": clamp01(data.get("confidence", strategy_packet.get("confidence", fallback.get("confidence", 0.35)))),
        "source": clean_text(data.get("source", "remote_server"), 64) or "remote_server",
        "failure_reason": clean_text(data.get("failure_reason", ""), 64),
    }


def normalize_background_job_model_result(raw: dict[str, Any], request: BackgroundJobRequest) -> dict[str, Any]:
    data = raw if isinstance(raw, dict) else {}
    if any(key in data for key in ("schema", "status", "notes", "priority_hints", "strategy_packet")):
        return data
    hints = data.get("h", data.get("hints", {}))
    payload = request.payload if isinstance(request.payload, dict) else {}
    source_strategy = payload.get("strategy_packet", {}) if isinstance(payload, dict) else {}
    source_strategy = source_strategy if isinstance(source_strategy, dict) else {}
    strategy_packet = {
        "schema": "ari.strategy_packet.v1",
        "day": source_strategy.get("day", 0),
        "main_risks": source_strategy.get("main_risks", []),
        "current_lessons": source_strategy.get("current_lessons", []),
        "active_doctrines": source_strategy.get("active_doctrines", []),
        "priority_hints": hints,
        "avoid_repeating": data.get("avoid", data.get("av", source_strategy.get("avoid_repeating", []))),
        "try_next": data.get("try", data.get("next", source_strategy.get("try_next", []))),
        "evidence": data.get("e", data.get("evidence", source_strategy.get("evidence", []))),
        "behavior_evidence": data.get("behavior_evidence", source_strategy.get("behavior_evidence", [])),
        "confidence": data.get("c", data.get("confidence", source_strategy.get("confidence", 0.45))),
    }
    return {
        "schema": "ari.background_result.v1",
        "job_id": request.job_id,
        "kind": request.kind,
        "context_hash": request.context_hash,
        "status": data.get("s", data.get("status", "ok")),
        "notes": data.get("n", data.get("notes", [])),
        "priority_hints": hints,
        "strategy_packet": strategy_packet,
        "confidence": data.get("c", data.get("confidence", 0.45)),
        "source": data.get("source", "remote_server"),
        "failure_reason": data.get("failure_reason", ""),
    }


def fallback_background_job_response(
    request: BackgroundJobRequest,
    failure_reason: str = "local_fallback",
    status: str = "fallback",
) -> dict[str, Any]:
    payload = request.payload if isinstance(request.payload, dict) else {}
    strategy_source = payload.get("strategy_packet", {})
    day_summary = payload.get("day_summary", {})
    strategy_packet = sanitize_strategy_packet(strategy_source if isinstance(strategy_source, dict) else {})
    notes = ["Background AI fallback kept deterministic strategy evidence available."]
    if isinstance(day_summary, dict):
        lessons = sanitize_string_list(day_summary.get("candidate_lessons", []), 2, 140)
        if lessons:
            notes = ["Fallback preserved lesson candidate: %s" % lessons[0]]
    return {
        "schema": "ari.background_result.v1",
        "job_id": clean_text(request.job_id, 120),
        "kind": request.kind,
        "context_hash": clean_text(request.context_hash, 160),
        "status": clean_text(status, 32) if status in BACKGROUND_RESULT_STATUSES else "fallback",
        "notes": notes,
        "priority_hints": sanitize_compact_priority_hints(strategy_packet.get("priority_hints", {})),
        "strategy_packet": strategy_packet,
        "confidence": clamp01(strategy_packet.get("confidence", 0.25)),
        "source": "local_fallback",
        "failure_reason": clean_text(failure_reason, 64),
    }


def sanitize_strategy_packet(raw: Any, fallback: dict[str, Any] | None = None) -> dict[str, Any]:
    data = raw if isinstance(raw, dict) else {}
    fallback = fallback if isinstance(fallback, dict) else {}
    priority_hints = merge_priority_maps(
        sanitize_compact_priority_hints(data.get("priority_hints", {})),
        sanitize_compact_priority_hints(fallback.get("priority_hints", {})),
    )
    return {
        "schema": "ari.strategy_packet.v1",
        "day": max(0, int(_float_value(data.get("day", fallback.get("day", 0))))),
        "main_risks": sanitize_string_list(data.get("main_risks", fallback.get("main_risks", [])), MAX_STRATEGY_LIST_ITEMS, 80),
        "current_lessons": sanitize_string_list(
            data.get("current_lessons", fallback.get("current_lessons", [])),
            MAX_STRATEGY_LIST_ITEMS,
            140,
        ),
        "active_doctrines": sanitize_strategy_doctrines(
            data.get("active_doctrines", fallback.get("active_doctrines", []))
        ),
        "priority_hints": priority_hints,
        "avoid_repeating": sanitize_string_list(
            data.get("avoid_repeating", fallback.get("avoid_repeating", [])),
            MAX_STRATEGY_LIST_ITEMS,
            140,
        ),
        "try_next": sanitize_string_list(data.get("try_next", fallback.get("try_next", [])), MAX_STRATEGY_LIST_ITEMS, 100),
        "evidence": sanitize_string_list(
            data.get("evidence", fallback.get("evidence", [])),
            MAX_STRATEGY_EVIDENCE_ITEMS,
            180,
        ),
        "behavior_evidence": sanitize_behavior_evidence_list(
            data.get("behavior_evidence", fallback.get("behavior_evidence", [])),
            3,
        ),
        "confidence": clamp01(data.get("confidence", fallback.get("confidence", 0.35))),
    }


def sanitize_strategy_doctrines(raw_items: Any) -> list[dict[str, Any]]:
    if not isinstance(raw_items, list):
        return []
    result: list[dict[str, Any]] = []
    for item in raw_items:
        if isinstance(item, dict):
            doctrine_id = clean_text(item.get("id", ""), 120)
            summary = clean_text(item.get("summary", item.get("title", "")), 180)
            confidence = clamp01(item.get("confidence", 0.35))
        else:
            doctrine_id = clean_text(item, 120)
            summary = doctrine_id
            confidence = 0.35
        if not doctrine_id and not summary:
            continue
        result.append({"id": doctrine_id or summary, "summary": summary or doctrine_id, "confidence": confidence})
        if len(result) >= 5:
            break
    return result


def fallback_priority_hints(raw_hints: dict[str, Any]) -> dict[str, float]:
    if not isinstance(raw_hints, dict):
        raw_hints = {}
    mapping = {
        "mining": "mine_stone",
        "wall": "build_wall",
        "aura_orb": "place_aura_orb",
        "defensive_wait": "wait_or_idle",
        "combat_training": "train_combat",
        "repair_structure": "repair",
        "build_spike_trap": "build_trap",
    }
    translated: dict[str, Any] = {}
    for key, value in raw_hints.items():
        translated[mapping.get(str(key), str(key))] = value
    return sanitize_priority_hints(translated)


def sanitize_priority_hints(raw_hints: dict[str, Any]) -> dict[str, float]:
    return {key: clamp01(raw_hints.get(key, 0.0)) for key in sorted(ALLOWED_PRIORITY_KEYS)}


def sanitize_compact_priority_hints(raw_hints: Any, signed: bool = False) -> dict[str, float]:
    if not isinstance(raw_hints, dict):
        return {}
    result: dict[str, float] = {}
    for raw_key, raw_value in raw_hints.items():
        key = clean_text(raw_key, 80)
        if key not in ALLOWED_PRIORITY_KEYS:
            continue
        value = _float_value(raw_value)
        if signed:
            value = max(-1.0, min(1.0, value))
            if value == 0.0:
                continue
        else:
            value = clamp01(value)
            if value <= 0.0:
                continue
        result[key] = value
        if len(result) >= 16:
            break
    return result


def merge_priority_maps(primary: dict[str, float], fallback: dict[str, float], max_count: int = 16) -> dict[str, float]:
    result: dict[str, float] = {}
    for source in (primary, fallback):
        for key, value in source.items():
            if key in result or key not in ALLOWED_PRIORITY_KEYS:
                continue
            result[key] = value
            if len(result) >= max_count:
                return result
    return result


def merge_belief_updates(primary: list[dict[str, Any]], fallback: list[dict[str, Any]]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    for source in (primary, fallback):
        for item in source:
            key = clean_text(item.get("key", ""), 80)
            if not key or key in seen:
                continue
            result.append(item)
            seen.add(key)
            if len(result) >= MAX_BELIEF_UPDATES:
                return result
    return result


def merge_doctrines(primary: list[dict[str, Any]], fallback: list[dict[str, Any]]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    for source in (primary, fallback):
        for item in source:
            doctrine_id = clean_text(item.get("id", ""), 80)
            if not doctrine_id or doctrine_id in seen:
                continue
            result.append(item)
            seen.add(doctrine_id)
            if len(result) >= MAX_REFLECTION_DOCTRINES:
                return result
    return result


def sanitize_scribe_actions(raw_actions: Any) -> list[dict[str, str]]:
    if not isinstance(raw_actions, list):
        return []
    result: list[dict[str, str]] = []
    for raw_item in raw_actions:
        if not isinstance(raw_item, dict):
            continue
        action = clean_text(raw_item.get("action", raw_item.get("action_id", raw_item.get("id", ""))), 80)
        if not action:
            continue
        result.append(
            {
                "action": action,
                "status": clean_text(raw_item.get("status", raw_item.get("outcome", "observed")), 40) or "observed",
                "reason": clean_text(raw_item.get("reason", ""), 160),
            }
        )
        if len(result) >= MAX_SCRIBE_ACTIONS:
            break
    return result


def sanitize_scribe_dangers(raw_dangers: Any) -> list[dict[str, Any]]:
    if not isinstance(raw_dangers, list):
        return []
    result: list[dict[str, Any]] = []
    for raw_item in raw_dangers:
        if not isinstance(raw_item, dict):
            continue
        danger_type = clean_text(raw_item.get("type", raw_item.get("enemy_type", "")), 60)
        if not danger_type:
            continue
        result.append(
            {
                "type": danger_type,
                "distance": max(0.0, _float_value(raw_item.get("distance", 0.0))),
                "severity": clamp01(raw_item.get("severity", raw_item.get("salience", 0.0))),
            }
        )
        if len(result) >= MAX_SCRIBE_DANGERS:
            break
    return result


def sanitize_grounded_plan(raw_plan: Any, allowed_affordance_ids: set[str] | None = None) -> list[dict[str, Any]]:
    if not isinstance(raw_plan, list):
        return []
    allowed_ids = allowed_affordance_ids or ALLOWED_PRIORITY_KEYS
    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    for raw_item in raw_plan:
        if not isinstance(raw_item, dict):
            continue
        affordance_id = clean_text(raw_item.get("affordance_id", raw_item.get("id", "")), 80)
        if affordance_id not in allowed_ids or affordance_id in seen:
            continue
        priority = clamp01(raw_item.get("priority", 0.0))
        if priority <= 0.0:
            continue
        result.append(
            {
                "affordance_id": affordance_id,
                "priority": priority,
                "reason": clean_text(raw_item.get("reason", ""), 180),
            }
        )
        seen.add(affordance_id)
        if len(result) >= MAX_GROUNDED_PLAN_ITEMS:
            break
    return result


def sanitize_agent_plan_steps(raw_plan: Any, legal_ids: set[str] | None) -> list[dict[str, str]]:
    if not isinstance(raw_plan, list):
        return []
    result: list[dict[str, str]] = []
    seen: set[str] = set()
    for index, raw_item in enumerate(raw_plan):
        if not isinstance(raw_item, dict):
            continue
        action_id = clean_text(raw_item.get("action_id", raw_item.get("affordance_id", raw_item.get("id", ""))), 80)
        if legal_ids is not None and action_id not in legal_ids:
            continue
        if action_id in seen:
            continue
        result.append(
            {
                "step_id": clean_text(raw_item.get("step_id", f"step_{index + 1}"), 80) or f"step_{index + 1}",
                "action_id": action_id,
                "reason": clean_text(raw_item.get("reason", ""), 180),
                "success": clean_text(raw_item.get("success", "action_completed"), 120) or "action_completed",
            }
        )
        seen.add(action_id)
        if len(result) >= MAX_AGENT_PLAN_STEPS:
            break
    return result


def sanitize_agent_action_choice(raw_action: Any, legal_ids: set[str] | None) -> dict[str, Any]:
    if not isinstance(raw_action, dict):
        return {}
    action_id = clean_text(raw_action.get("action_id", raw_action.get("id", "")), 80)
    if not action_id:
        return {}
    if legal_ids is not None and action_id not in legal_ids:
        return {}
    return {
        "action_id": action_id,
        "urgency": clamp01(raw_action.get("urgency", 0.5)),
        "reason": clean_text(raw_action.get("reason", ""), 180),
    }


def agent_plan_doctrine_prerequisite_choice(
    request_context: AgentPlanRequest | dict[str, Any] | None,
    legal_ids: set[str] | None,
    current_action: str,
) -> dict[str, Any]:
    if legal_ids is None or request_context is None:
        return {}
    context = request_context.model_dump() if isinstance(request_context, AgentPlanRequest) else request_context
    if not isinstance(context, dict):
        return {}
    active_plan = context.get("active_doctrine_plan", [])
    world = context.get("world", {})
    if not isinstance(active_plan, list) or not isinstance(world, dict):
        return {}
    plan_ids = {
        clean_text(item.get("affordance_id", item.get("action_id", item.get("id", ""))), 80)
        for item in active_plan
        if isinstance(item, dict)
    }
    if "build_storm_rod" in plan_ids and _agent_world_count(world, ("storm_rod_count", "storm_rods")) <= 0:
        return _agent_doctrine_prerequisite_action(
            "build_storm_rod", "mine_stone", "Storm Rod", current_action, legal_ids, world
        )
    if (
        "build_tower" in plan_ids
        and plan_ids.intersection({"use_tower", "ranged_attack", "train_bow"})
        and _agent_world_count(world, ("bow_tower_count", "tower_count", "towers")) <= 0
    ):
        return _agent_doctrine_prerequisite_action("build_tower", "mine_stone", "Bow Tower", current_action, legal_ids, world)
    if (
        "place_aura_orb" in plan_ids
        and "lure_to_aura" in plan_ids
        and _agent_world_count(world, ("aura_orb_count", "aura_orbs")) <= 0
    ):
        return _agent_doctrine_prerequisite_action(
            "place_aura_orb", "mine_stone", "Aura Orb", current_action, legal_ids, world
        )
    return {}


def agent_plan_safety_choice(
    request_context: AgentPlanRequest | dict[str, Any] | None,
    legal_ids: set[str] | None,
    current_action: str,
) -> dict[str, Any]:
    if legal_ids is None or request_context is None:
        return {}
    context = request_context.model_dump() if isinstance(request_context, AgentPlanRequest) else request_context
    if not isinstance(context, dict):
        return {}
    world = context.get("world", {})
    if not isinstance(world, dict):
        world = {}
    sign = context.get("sign", {})
    sign_text = ""
    if isinstance(sign, dict):
        sign_text = " ".join([str(sign.get("text", "")), str(sign.get("interpretation", ""))]).lower()
    enemy_count = int(_float_value(world.get("enemy_count", 0)))
    enemy_types = world.get("enemy_type_counts", {})
    has_flying = isinstance(enemy_types, dict) and _float_value(enemy_types.get("flying", 0)) > 0
    has_flying = has_flying or any(token in sign_text for token in ("wing", "flying", "sky"))

    if has_flying and _agent_world_count(world, ("storm_rod_count", "storm_rods")) <= 0:
        if current_action not in {"build_storm_rod", "mine_stone"}:
            if "build_storm_rod" in legal_ids:
                return {
                    "action_id": "build_storm_rod",
                    "urgency": 0.92,
                    "reason": "Flying danger bypasses ordinary cover; build the Storm Rod first.",
                }
            if "mine_stone" in legal_ids:
                return {
                    "action_id": "mine_stone",
                    "urgency": 0.82,
                    "reason": "Flying danger needs a Storm Rod; gather stone before ordinary cover.",
                }

    if current_action == "fight_head_on" and not _agent_plan_allows_direct_melee(context, world):
        wants_range = any(token in sign_text for token in ("tower", "mountain", "arrow", "arrows", "bow", "range", "high", "height"))
        if wants_range and _agent_world_count(world, ("bow_tower_count", "tower_count", "towers")) > 0 and "use_tower" in legal_ids:
            return {
                "action_id": "use_tower",
                "urgency": 0.9,
                "reason": "The sign and built tower point to ranged survival, not direct melee.",
            }
        if _agent_world_count(world, ("aura_orb_count", "aura_orbs")) > 0 and "lure_to_aura" in legal_ids:
            return {
                "action_id": "lure_to_aura",
                "urgency": 0.86,
                "reason": "Existing aura damage is safer than direct melee.",
            }
        if enemy_count > 0 and "use_cover" in legal_ids:
            return {
                "action_id": "use_cover",
                "urgency": 0.82,
                "reason": "Active enemies make unsupported direct melee unsafe; use cover.",
            }
        if enemy_count > 0 and "flee" in legal_ids:
            return {
                "action_id": "flee",
                "urgency": 0.78,
                "reason": "Active enemies make unsupported direct melee unsafe; create distance.",
            }
    return {}


def _agent_plan_allows_direct_melee(context: dict[str, Any], world: dict[str, Any]) -> bool:
    sign = context.get("sign", {})
    sign_text = ""
    if isinstance(sign, dict):
        sign_text = " ".join([str(sign.get("text", "")), str(sign.get("interpretation", ""))]).lower()
    direct_tokens = ("sword", "blade", "ore", "kill", "fight", "melee", "life when they die", "life-on-kill")
    if not any(token in sign_text for token in direct_tokens):
        return False
    sword_tier = _agent_world_count(world, ("sword_tier",))
    combat_level = _float_value(world.get("combat_level", world.get("combat", 0)))
    return sword_tier > 0 or combat_level >= 1.0


def _agent_doctrine_prerequisite_action(
    target_action: str,
    resource_action: str,
    label: str,
    current_action: str,
    legal_ids: set[str],
    world: dict[str, Any],
) -> dict[str, Any]:
    if current_action in {target_action, resource_action}:
        return {}
    if current_action in {"flee", "use_cover", "hide_until_dawn", "stall_until_dawn", "survive_until_morning"} and int(
        _float_value(world.get("enemy_count", 0))
    ) > 0:
        return {}
    if target_action in legal_ids:
        return {
            "action_id": target_action,
            "urgency": 0.9,
            "reason": f"Active doctrine still needs {label} before later steps.",
        }
    if resource_action in legal_ids:
        return {
            "action_id": resource_action,
            "urgency": 0.82,
            "reason": f"Active doctrine still needs {label}; gather resources before later steps.",
        }
    return {}


def _agent_world_count(world: dict[str, Any], keys: tuple[str, ...]) -> int:
    for key in keys:
        if key in world:
            return max(0, int(_float_value(world.get(key, 0))))
    structures = world.get("structures", {})
    if isinstance(structures, dict):
        for key in keys:
            if key in structures:
                return max(0, int(_float_value(structures.get(key, 0))))
    return 0


def agent_plan_step_from_choice(choice: dict[str, Any], step_id: str) -> dict[str, str]:
    return {
        "step_id": clean_text(step_id, 80),
        "action_id": clean_text(choice.get("action_id", ""), 80),
        "reason": clean_text(choice.get("reason", ""), 180),
        "success": "action_completed",
    }


def sanitize_belief_updates(raw_updates: Any) -> list[dict[str, Any]]:
    if not isinstance(raw_updates, list):
        return []
    result: list[dict[str, Any]] = []
    for item in raw_updates:
        if not isinstance(item, dict):
            continue
        key = clean_text(item.get("key", ""), 80)
        if not key:
            continue
        result.append(
            {
                "key": key,
                "delta": max(-1.0, min(1.0, _float_value(item.get("delta", 0.0)))),
                "reason": clean_text(item.get("reason", ""), 180),
            }
        )
        if len(result) >= MAX_BELIEF_UPDATES:
            break
    return result


def sanitize_reflection_belief_updates(raw_updates: Any) -> list[dict[str, Any]]:
    if not isinstance(raw_updates, list):
        return []
    result: list[dict[str, Any]] = []
    for item in raw_updates:
        if not isinstance(item, dict):
            continue
        key = clean_text(item.get("key", item.get("belief", "")), 80)
        if not key:
            continue
        result.append(
            {
                "key": key,
                "delta": max(-1.0, min(1.0, _float_value(item.get("delta", 0.0)))),
                "reason": clean_text(item.get("reason", ""), 180),
            }
        )
        if len(result) >= MAX_BELIEF_UPDATES:
            break
    return result


def sanitize_doctrines(raw_doctrines: Any) -> list[dict[str, Any]]:
    if not isinstance(raw_doctrines, list):
        return []
    result: list[dict[str, Any]] = []
    for item in raw_doctrines:
        if not isinstance(item, dict):
            continue
        doctrine = sanitize_doctrine(item)
        if doctrine:
            result.append(doctrine)
        if len(result) >= MAX_REFLECTION_DOCTRINES:
            break
    return result


def sanitize_doctrine(raw_doctrine: dict[str, Any]) -> dict[str, Any]:
    when = sanitize_doctrine_when(raw_doctrine.get("when", {}))
    if not when:
        return {}
    bias = sanitize_compact_priority_hints(raw_doctrine.get("bias", raw_doctrine.get("priority_bias", {})), signed=True)
    plan = sanitize_doctrine_plan(raw_doctrine.get("plan", []))
    control = sanitize_doctrine_control(raw_doctrine.get("control", {}))
    if not bias and not plan and not control:
        return {}
    raw_id = raw_doctrine.get("id", raw_doctrine.get("title", "doctrine"))
    doctrine_id = clean_text(normalize_key(str(raw_id)), 80)
    if not doctrine_id:
        return {}
    result = {
        "id": doctrine_id,
        "summary": clean_text(raw_doctrine.get("summary", raw_doctrine.get("hypothesis", raw_id)), 240),
        "when": when,
        "bias": bias,
        "plan": plan,
        "confidence": clamp01(raw_doctrine.get("confidence", 1.0)),
    }
    if control:
        result["control"] = control
    return result


def sanitize_doctrine_when(raw_when: Any) -> dict[str, Any]:
    if not isinstance(raw_when, dict):
        return {}
    result: dict[str, Any] = {}
    if "enemy_type_present" in raw_when:
        enemy_type = clean_text(raw_when.get("enemy_type_present", ""), 60)
        if enemy_type:
            result["enemy_type_present"] = enemy_type
    if "phase" in raw_when:
        phase = raw_when.get("phase")
        if isinstance(phase, list):
            phases = sanitize_string_list(phase, 4, 40)
            if phases:
                result["phase"] = phases
        else:
            phase_text = clean_text(phase, 40)
            if phase_text:
                result["phase"] = phase_text
    if "min_day" in raw_when:
        result["min_day"] = max(1, int(_float_value(raw_when.get("min_day", 1))))
    if "max_hp_ratio" in raw_when:
        result["max_hp_ratio"] = clamp01(raw_when.get("max_hp_ratio", 1.0))
    if "structure_destroyed" in raw_when:
        destroyed = raw_when.get("structure_destroyed")
        if isinstance(destroyed, bool):
            result["structure_destroyed"] = destroyed
        else:
            destroyed_text = clean_text(destroyed, 60)
            if destroyed_text:
                result["structure_destroyed"] = destroyed_text
    behavior_pattern = clean_text(raw_when.get("behavior_pattern", raw_when.get("pattern", "")), 80)
    if behavior_pattern:
        result["behavior_pattern"] = behavior_pattern
    if "danger_changed" in raw_when:
        result["danger_changed"] = bool(raw_when.get("danger_changed", False))
    return result


def sanitize_doctrine_plan(raw_plan: Any) -> list[dict[str, Any]]:
    if not isinstance(raw_plan, list):
        return []
    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    for item in raw_plan:
        if not isinstance(item, dict):
            continue
        affordance_id = clean_text(item.get("affordance_id", item.get("action_id", item.get("id", ""))), 80)
        if affordance_id not in ALLOWED_PRIORITY_KEYS or affordance_id in seen:
            continue
        priority = clamp01(item.get("priority", item.get("urgency", 0.0)))
        if priority <= 0.0:
            continue
        result.append(
            {
                "affordance_id": affordance_id,
                "priority": priority,
                "reason": clean_text(item.get("reason", ""), 180),
            }
        )
        seen.add(affordance_id)
        if len(result) >= MAX_AGENT_PLAN_STEPS:
            break
    return result


def sanitize_doctrine_control(raw_control: Any) -> dict[str, Any]:
    if not isinstance(raw_control, dict):
        return {}
    result: dict[str, Any] = {}
    anchor = clean_text(
        normalize_key(
            str(
                raw_control.get(
                    "preferred_anchor_kind",
                    raw_control.get("anchor_kind", raw_control.get("preferred_anchor", "")),
                )
            )
        ),
        80,
    )
    if anchor in ALLOWED_DOCTRINE_ANCHOR_KINDS:
        result["preferred_anchor_kind"] = anchor
    if "min_hold_seconds" in raw_control:
        result["min_hold_seconds"] = max(3.0, min(45.0, _float_value(raw_control.get("min_hold_seconds", 0.0))))
    avoid_actions: list[str] = []
    raw_avoid_actions = raw_control.get("avoid_action_ids", raw_control.get("avoid_actions", []))
    if isinstance(raw_avoid_actions, list):
        for item in raw_avoid_actions:
            action_id = clean_text(normalize_key(str(item)), 80)
            if action_id not in ALLOWED_PRIORITY_KEYS or action_id in avoid_actions:
                continue
            avoid_actions.append(action_id)
            if len(avoid_actions) >= MAX_DOCTRINE_CONTROL_ACTIONS:
                break
    if avoid_actions:
        result["avoid_action_ids"] = avoid_actions
    break_reasons: list[str] = []
    raw_break_reasons = raw_control.get("allowed_break_reasons", raw_control.get("break_reasons", []))
    if isinstance(raw_break_reasons, list):
        for item in raw_break_reasons:
            reason_id = clean_text(normalize_key(str(item)), 80)
            if reason_id not in ALLOWED_DOCTRINE_BREAK_REASONS or reason_id in break_reasons:
                continue
            break_reasons.append(reason_id)
            if len(break_reasons) >= MAX_DOCTRINE_CONTROL_BREAK_REASONS:
                break
    if break_reasons:
        result["allowed_break_reasons"] = break_reasons
    return result


def action_ids(actions: list[AgentPlanAction] | list[dict[str, Any]] | None) -> set[str] | None:
    if not actions:
        return None
    ids: set[str] = set()
    for item in actions:
        if isinstance(item, AgentPlanAction):
            if item.available:
                ids.add(item.id)
        elif isinstance(item, dict) and bool(item.get("available", True)):
            ids.add(str(item.get("id", "")))
    return {item for item in ids if item} or None


def grounded_plan_from_hints(priority_hints: dict[str, float], allowed_affordance_ids: set[str] | None = None) -> list[dict[str, Any]]:
    allowed_ids = allowed_affordance_ids or ALLOWED_PRIORITY_KEYS
    items = [
        (key, clamp01(value))
        for key, value in priority_hints.items()
        if key in allowed_ids and clamp01(value) > 0.0
    ]
    items.sort(key=lambda item: item[1], reverse=True)
    return [
        {
            "affordance_id": key,
            "priority": value,
            "reason": "Local fallback made this the closest executable behavior.",
        }
        for key, value in items[:MAX_GROUNDED_PLAN_ITEMS]
    ]


def affordance_ids(current_affordances: list[AffordanceState] | list[dict[str, Any]] | None) -> set[str] | None:
    if not current_affordances:
        return None
    ids: set[str] = set()
    for item in current_affordances:
        if isinstance(item, AffordanceState):
            ids.add(item.id)
        elif isinstance(item, dict):
            ids.add(str(item.get("id", "")))
    return ids or None


def _first_legal_action_choice(actions: list[AgentPlanAction] | list[dict[str, Any]] | None, fallback_id: str) -> dict[str, Any]:
    if actions:
        for item in actions:
            if isinstance(item, AgentPlanAction):
                if item.available:
                    return {"action_id": item.id, "urgency": 0.35, "reason": item.description[:180]}
            elif isinstance(item, dict) and bool(item.get("available", True)):
                return {
                    "action_id": str(item.get("id", fallback_id)),
                    "urgency": 0.35,
                    "reason": clean_text(item.get("description", ""), 180),
                }
    return {"action_id": fallback_id, "urgency": 0.35, "reason": "Local fallback action."}


def clean_text(value: Any, max_chars: int) -> str:
    text = str(value if value is not None else "").replace("\n", " ").strip()
    if len(text) <= max_chars:
        return text
    return text[:max_chars].rstrip()


def clean_markdown(value: Any, max_chars: int) -> str:
    text = str(value if value is not None else "").replace("\r\n", "\n").replace("\r", "\n").strip()
    if len(text) <= max_chars:
        return text
    return text[:max_chars].rstrip()


def sanitize_string_list(raw_items: Any, max_items: int, max_chars: int) -> list[str]:
    if not isinstance(raw_items, list):
        return []
    result: list[str] = []
    for item in raw_items:
        text = clean_text(item, max_chars)
        if text and text not in result:
            result.append(text)
        if len(result) >= max_items:
            break
    return result


def sanitize_string_dict(raw_value: Any, max_items: int, max_chars: int) -> dict[str, str]:
    if not isinstance(raw_value, dict):
        return {}
    result: dict[str, str] = {}
    for key, value in raw_value.items():
        clean_key = clean_text(key, max_chars)
        if not clean_key:
            continue
        result[clean_key] = clean_text(value, max_chars)
        if len(result) >= max_items:
            break
    return result


def clamp01(value: Any) -> float:
    return max(0.0, min(1.0, _float_value(value)))


def clamp_seconds(value: Any) -> float:
    return max(1.0, min(60.0, _float_value(value)))


def _float_value(value: Any) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def normalize_key(text: str) -> str:
    normalized = text.lower().strip().replace(" ", "_").replace("-", "_")
    return "".join(char for char in normalized if char.isalnum() or char == "_")


def _humanize_key(value: Any) -> str:
    return clean_text(str(value if value is not None else "").replace("_", " ").strip(), 80)


def _payload_mentions_text(value: Any, needle: str) -> bool:
    target = needle.lower()
    if isinstance(value, dict):
        return any(_payload_mentions_text(key, target) or _payload_mentions_text(item, target) for key, item in value.items())
    if isinstance(value, list):
        return any(_payload_mentions_text(item, target) for item in value)
    return target in str(value if value is not None else "").lower()


def _payload_mentions_any_text(value: Any, needles: tuple[str, ...]) -> bool:
    return any(_payload_mentions_text(value, needle) for needle in needles)
