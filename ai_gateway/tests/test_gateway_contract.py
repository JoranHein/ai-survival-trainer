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


CURRENT_ACTION_KEYS = {
    "mine_stone",
    "build_wall",
    "use_existing_wall",
    "wait_behind_wall",
    "use_cover",
    "place_aura_orb",
    "lure_to_aura",
    "train_combat",
    "prepare_weapon",
    "ranged_attack",
    "build_tower",
    "use_tower",
    "train_bow",
    "farm_food",
    "eat",
    "eat_food",
    "rest",
    "reflect_library",
    "repair",
    "flee",
    "fight",
    "kite",
    "hide",
    "build_storm_rod",
    "anti_flying",
    "sky_answer",
}


def test_allowed_priority_keys_cover_current_action_vocabulary():
    assert CURRENT_ACTION_KEYS.issubset(ALLOWED_PRIORITY_KEYS)


def test_sanitizes_deep_response_contract_without_confusion():
    response = sanitize_deep_response(
        {
            "interpretation": "x" * 300,
            "thought": "y" * 200,
            "survival_theory": "cover" * 30,
            "emotion": "focused fear",
            "grounded_plan": [
                {
                    "affordance_id": "use_existing_wall",
                    "priority": 2,
                    "reason": "The wall already exists, so cover matters more than building.",
                },
                {
                    "affordance_id": "build_storm_rod",
                    "priority": "0.8",
                    "reason": "Wings need a sky answer.",
                },
                {
                    "affordance_id": "unknown_spell",
                    "priority": 1,
                    "reason": "Unknown model invention should not pass through.",
                },
            ],
            "priority_hints": {
                "use_existing_wall": 2,
                "wait_behind_wall": "0.7",
                "prepare_weapon": 0.5,
                "ranged_attack": 2,
                "use_tower": 0.9,
                "train_bow": "0.6",
                "eat": 0.3,
                "eat_food": 0.4,
                "build_storm_rod": 0.45,
                "anti_flying": 1.5,
                "sky_answer": "0.8",
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
        "emotion",
        "grounded_plan",
        "priority_hints",
        "sign_strength",
        "resonance",
    }
    assert len(response["interpretation"]) <= 240
    assert len(response["thought"]) <= 160
    assert len(response["survival_theory"]) <= 64
    assert response["emotion"] == "focused fear"
    assert response["grounded_plan"] == [
        {
            "affordance_id": "use_existing_wall",
            "priority": 1.0,
            "reason": "The wall already exists, so cover matters more than building.",
        },
        {
            "affordance_id": "build_storm_rod",
            "priority": 0.8,
            "reason": "Wings need a sky answer.",
        },
    ]
    assert response["priority_hints"]["use_existing_wall"] == 1.0
    assert response["priority_hints"]["wait_behind_wall"] == 0.7
    assert response["priority_hints"]["prepare_weapon"] == 0.5
    assert response["priority_hints"]["ranged_attack"] == 1.0
    assert response["priority_hints"]["use_tower"] == 0.9
    assert response["priority_hints"]["train_bow"] == 0.6
    assert response["priority_hints"]["eat"] == 0.3
    assert response["priority_hints"]["eat_food"] == 0.4
    assert response["priority_hints"]["build_storm_rod"] == 0.8
    assert response["priority_hints"]["anti_flying"] == 1.0
    assert response["priority_hints"]["sky_answer"] == 0.8
    assert "unknown" not in response["priority_hints"]
    assert set(response["priority_hints"]) == ALLOWED_PRIORITY_KEYS
    assert response["sign_strength"] == 0.0
    assert response["resonance"] == 1.0


def test_fallback_deep_response_maps_legacy_local_hints_and_grounded_plan():
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
    assert response["emotion"] == "uncertain"
    assert response["priority_hints"]["build_wall"] == 0.9
    assert response["priority_hints"]["wait_or_idle"] == 0.6
    assert response["priority_hints"]["train_combat"] == 0.3
    assert response["grounded_plan"][0]["affordance_id"] == "build_wall"
    assert response["grounded_plan"][0]["priority"] == 0.9
    assert response["sign_strength"] == 0.8
    assert response["resonance"] == 0.5
    DeepInterpretationResponse(**response)


def _deep_request(sign_text: str) -> "DeepInterpretationRequest":
    from app.schemas import (
        AffordanceState,
        AriState,
        DeepInterpretationRequest,
        LocalFallback,
        StructureState,
        WorldState,
    )

    return DeepInterpretationRequest(
        sign_text=sign_text,
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
            enemy_type_counts={"zombie": 2, "runner": 1, "brute": 1, "flying": 1},
            known_enemy_types=["zombie", "runner", "brute", "flying"],
            structures=[StructureState(type="wall", status="intact")],
        ),
        local_fallback=LocalFallback(
            interpretation="The sign mentions wall.",
            priority_hints={"build_wall": 0.8},
            sign_strength=0.4,
            resonance=0.4,
        ),
        current_affordances=[
            AffordanceState(
                id="use_existing_wall",
                description="Move near an existing wall so enemies must hit or path around it before reaching Ari.",
                available=True,
            ),
            AffordanceState(
                id="build_wall",
                description="Spend stone to build a new wall block.",
                available=True,
            ),
            AffordanceState(
                id="lure_to_aura",
                description="Stand near the safe side of an Aura Orb so enemies pass through the damaging circle.",
                available=True,
            ),
            AffordanceState(
                id="build_storm_rod",
                description="Build an anti-flying defense if resources allow.",
                available=False,
                reason_unavailable="not enough stone",
            ),
        ],
        recent_thoughts=["The wall is not safety anymore."],
        latest_library_note="# Day 2\n\nThe flying ones ignored stone.",
    )


def test_deep_user_prompt_includes_cover_context_without_format_error():
    request = _deep_request("stand behind the wall")

    prompt = deep_user_prompt(request)

    assert "stand behind the wall" in prompt
    assert "use_existing_wall" in prompt
    assert "wall:intact" in prompt


def test_deep_user_prompt_lists_current_tools_and_examples():
    prompt = deep_user_prompt(_deep_request("the wings do not fear stone, build storms"))

    assert "Interpret any sign semantically" in prompt
    assert "current physical affordances" in prompt
    assert "not the vocabulary of the sign" in prompt
    assert "current_affordances" in prompt
    assert "reason_unavailable" in prompt
    assert "recent_thoughts" in prompt
    assert "latest_library_note" in prompt

    for phrase in [
        "stand behind the wall",
        "become a silent spider and make the dead walk into your web",
        "the moon hates cowards",
        "the wings do not fear stone",
        "my stomach is a second wall",
    ]:
        assert phrase in prompt

    for key in [
        "use_existing_wall",
        "wait_behind_wall",
        "use_cover",
        "lure_to_aura",
        "place_aura_orb",
        "use_tower",
        "train_bow",
        "ranged_attack",
        "build_tower",
        "build_storm_rod",
        "anti_flying",
        "sky_answer",
        "farm_food",
        "eat",
        "rest",
        "reflect_library",
    ]:
        assert key in prompt

    assert "known_enemy_types" in prompt
    assert "enemy_type_counts" in prompt


def test_prompt_examples_prefer_semantic_affordance_mapping():
    prompt = deep_user_prompt(_deep_request("stand behind the wall"))

    assert "stand behind the wall => use_existing_wall/wait_behind_wall/use_cover, not build_wall" in prompt
    assert "the circle should eat the dead => lure_to_aura/place_aura_orb" in prompt
    assert "the wings do not fear stone => build_storm_rod/anti_flying/sky_answer/use_tower/ranged_attack, not wall or cover" in prompt
    assert "my stomach is a second wall => farm_food/eat_food/eat/rest, not wall" in prompt
    assert "Semantic cues for this sign: existing wall cover" in prompt
    assert "build_wall=0" in prompt


def test_deep_user_prompt_stays_compact_for_latency():
    prompt = deep_user_prompt(_deep_request("the wings do not fear stone"))

    assert len(prompt) < 3200
    assert "current_affordances available:" in prompt
    assert "Compatibility priority_hints may use these executable affordance ids" not in prompt
    assert "sky threat; wall/cover fails" in prompt
