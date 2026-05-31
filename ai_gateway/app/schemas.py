from __future__ import annotations

from typing import Any

from pydantic import BaseModel, ConfigDict, Field


ALLOWED_PRIORITY_KEYS = {
    "mine_stone",
    "build_wall",
    "wait_or_idle",
    "use_existing_wall",
    "wait_behind_wall",
    "place_aura_orb",
    "lure_to_aura",
    "train_combat",
    "farm_food",
    "build_trap",
    "build_tower",
    "rest",
    "reflect_library",
    "repair",
    "flee",
    "fight",
    "kite",
    "hide",
    "use_cover",
}


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class AriState(StrictModel):
    personality: dict[str, Any] = Field(default_factory=dict)
    run_build: dict[str, Any] = Field(default_factory=dict)
    hp: float = 100.0
    max_hp: float = 100.0
    current_job: str = ""
    current_reason: str = ""
    job: str = ""
    reason: str = ""


class StructureState(StrictModel):
    type: str = ""
    status: str = ""


class WorldState(StrictModel):
    day: int = 1
    phase: str = "morning"
    time_left: float = 0.0
    stone: int = 0
    wall_count: int = 0
    aura_orb_count: int = 0
    enemy_count: int = 0
    known_enemy_types: list[str] = Field(default_factory=list)
    structures: list[StructureState] = Field(default_factory=list)


class LocalFallback(StrictModel):
    interpretation: str = ""
    priority_hints: dict[str, Any] = Field(default_factory=dict)
    sign_strength: float = 0.0
    resonance: float = 0.0


class DeepInterpretationRequest(StrictModel):
    sign_text: str
    ari: AriState
    world: WorldState
    local_fallback: LocalFallback


class DeepInterpretationResponse(StrictModel):
    interpretation: str
    thought: str
    survival_theory: str
    priority_hints: dict[str, float]
    sign_strength: float
    resonance: float


class FastThoughtRequest(StrictModel):
    event: str = ""
    ari: dict[str, Any] = Field(default_factory=dict)
    world: dict[str, Any] = Field(default_factory=dict)
    local_fallback_thought: str = ""


class FastThoughtResponse(StrictModel):
    thought: str
    resonance: float


def sanitize_deep_response(raw: dict[str, Any], fallback: dict[str, Any]) -> dict[str, Any]:
    raw_hints = raw.get("priority_hints", {})
    if not isinstance(raw_hints, dict):
        raw_hints = {}
    return {
        "interpretation": clean_text(raw.get("interpretation", fallback.get("interpretation", "")), 240),
        "thought": clean_text(raw.get("thought", fallback.get("thought", "")), 160),
        "survival_theory": clean_text(raw.get("survival_theory", fallback.get("survival_theory", "fallback")), 64),
        "priority_hints": sanitize_priority_hints(raw_hints),
        "sign_strength": clamp01(raw.get("sign_strength", fallback.get("sign_strength", 0.0))),
        "resonance": clamp01(raw.get("resonance", fallback.get("resonance", 0.0))),
    }


def fallback_deep_response(local_fallback: LocalFallback | dict[str, Any]) -> dict[str, Any]:
    if isinstance(local_fallback, LocalFallback):
        data = local_fallback.model_dump()
    else:
        data = local_fallback
    interpretation = clean_text(data.get("interpretation") or "Ari falls back to his local reading.", 240)
    return {
        "interpretation": interpretation,
        "thought": "I only understand part of the sign. I will stay careful.",
        "survival_theory": "local_fallback",
        "priority_hints": fallback_priority_hints(data.get("priority_hints", {})),
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
    }
    translated: dict[str, Any] = {}
    for key, value in raw_hints.items():
        translated[mapping.get(str(key), str(key))] = value
    return sanitize_priority_hints(translated)


def sanitize_priority_hints(raw_hints: dict[str, Any]) -> dict[str, float]:
    return {key: clamp01(raw_hints.get(key, 0.0)) for key in sorted(ALLOWED_PRIORITY_KEYS)}


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
