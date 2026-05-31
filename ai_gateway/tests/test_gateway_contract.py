import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.schemas import (
    ALLOWED_PRIORITY_KEYS,
    DeepInterpretationResponse,
    fallback_deep_response,
    sanitize_deep_response,
)
from app.prompting import deep_user_prompt


def test_sanitizes_deep_response_contract_without_confusion():
    response = sanitize_deep_response(
        {
            "interpretation": "x" * 300,
            "thought": "y" * 200,
            "survival_theory": "cover" * 30,
            "priority_hints": {
                "use_existing_wall": 2,
                "wait_behind_wall": "0.7",
                "unknown": 1,
            },
            "sign_strength": -5,
            "resonance": 2,
            "confusion": 1,
        },
        fallback_deep_response(
            {
                "interpretation": "fallback",
                "priority_hints": {"build_wall": 0.4},
                "sign_strength": 0.3,
                "resonance": 0.2,
            }
        ),
    )

    assert set(response.keys()) == {
        "interpretation",
        "thought",
        "survival_theory",
        "priority_hints",
        "sign_strength",
        "resonance",
    }
    assert len(response["interpretation"]) <= 240
    assert len(response["thought"]) <= 160
    assert len(response["survival_theory"]) <= 64
    assert response["priority_hints"]["use_existing_wall"] == 1.0
    assert response["priority_hints"]["wait_behind_wall"] == 0.7
    assert "unknown" not in response["priority_hints"]
    assert set(response["priority_hints"]) == ALLOWED_PRIORITY_KEYS
    assert response["sign_strength"] == 0.0
    assert response["resonance"] == 1.0


def test_fallback_deep_response_maps_legacy_local_hints():
    response = fallback_deep_response(
        {
            "interpretation": "The sign mentions a wall.",
            "priority_hints": {
                "wall": 0.9,
                "defensive_wait": 0.6,
                "combat_training": 0.3,
            },
            "sign_strength": 0.8,
            "resonance": 0.5,
        }
    )

    assert response["interpretation"] == "The sign mentions a wall."
    assert response["priority_hints"]["build_wall"] == 0.9
    assert response["priority_hints"]["wait_or_idle"] == 0.6
    assert response["priority_hints"]["train_combat"] == 0.3
    assert response["sign_strength"] == 0.8
    assert response["resonance"] == 0.5
    DeepInterpretationResponse(**response)


def test_deep_user_prompt_includes_cover_context_without_format_error():
    from app.schemas import AriState, DeepInterpretationRequest, LocalFallback, StructureState, WorldState

    request = DeepInterpretationRequest(
        sign_text="stand behind the wall",
        ari=AriState(
            personality={"fearfulness": 0.7},
            run_build={"preset": "Builder"},
            hp=80,
            max_hp=100,
            current_job="build_wall",
            current_reason="No aura orb yet",
        ),
        world=WorldState(
            day=1,
            phase="midday",
            time_left=25,
            stone=10,
            wall_count=2,
            aura_orb_count=1,
            structures=[StructureState(type="wall", status="intact")],
        ),
        local_fallback=LocalFallback(
            interpretation="The sign mentions wall.",
            priority_hints={"build_wall": 0.8},
            sign_strength=0.4,
            resonance=0.4,
        ),
    )

    prompt = deep_user_prompt(request)

    assert "stand behind the wall" in prompt
    assert "use_existing_wall" in prompt
    assert "wall:intact" in prompt
