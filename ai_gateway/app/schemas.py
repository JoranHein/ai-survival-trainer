from __future__ import annotations

from typing import Any

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
    "build_fear_lantern",
    "build_decoy_idol",
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
    "mining",
    "wall",
    "aura_orb",
    "combat_training",
    "range",
    "defensive_wait",
}

MAX_GROUNDED_PLAN_ITEMS = 4

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


def clean_text(value: Any, max_chars: int) -> str:
    text = str(value if value is not None else "").replace("\n", " ").strip()
    if len(text) <= max_chars:
        return text
    return text[:max_chars].rstrip()


def clamp01(value: Any) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError):
        number = 0.0
    return max(0.0, min(1.0, number))
