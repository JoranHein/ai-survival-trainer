import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.schemas import (
    ALLOWED_PRIORITY_KEYS,
    DeepInterpretationRequest,
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
}


def test_allowed_priority_keys_cover_current_action_vocabulary():
    assert CURRENT_ACTION_KEYS.issubset(ALLOWED_PRIORITY_KEYS)


def test_gateway_request_contract_has_no_random_trait_state():
    from pydantic import ValidationError

    from app.schemas import AriState

    removed_key = "person" + "ality"
    former_fear_key = "fear" + "fulness"
    former_combat_key = "ag" + "gression"
    assert removed_key not in AriState.model_fields
    with pytest.raises(ValidationError):
        AriState(**{removed_key: {former_fear_key: 0.7}})

    prompt = deep_user_prompt(_deep_request("stand behind the wall"))
    assert removed_key not in prompt.lower()
    assert former_fear_key not in prompt.lower()
    assert former_combat_key not in prompt.lower()


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
                "fight_head_on": 1.3,
                "train_sword": 0.7,
                "smith_sword": 0.6,
                "mine_ore": 0.5,
                "regen_on_kill": 0.8,
                "survive_until_morning": 0.4,
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
    assert response["priority_hints"]["fight_head_on"] == 1.0
    assert response["priority_hints"]["train_sword"] == 0.7
    assert response["priority_hints"]["smith_sword"] == 0.6
    assert response["priority_hints"]["mine_ore"] == 0.5
    assert response["priority_hints"]["regen_on_kill"] == 0.8
    assert response["priority_hints"]["survive_until_morning"] == 0.4
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


def test_deep_interpretation_accepts_modern_godot_payload_with_extra_request_fields(monkeypatch):
    import app.main as gateway_main

    payload = _modern_godot_payload()

    request = DeepInterpretationRequest(**payload)
    assert request.world.food == 2
    assert request.world.ore == 3
    assert request.world.bow_tower_count == 1
    assert request.world.storm_rod_count == 1
    assert request.world.sword_tier == 2
    assert not hasattr(request.world, "benign_future_world_field")
    assert not hasattr(request.ari, "benign_future_ari_field")

    async def fake_call_deep_model(_request, _settings):
        return {
            "interpretation": "Ari reads the wall and tower as cover while watching the sky.",
            "thought": "The wall helps, but I should notice the sky too.",
            "survival_theory": "cover_and_sky",
            "emotion": "careful",
            "grounded_plan": [
                {
                    "affordance_id": "use_existing_wall",
                    "priority": 0.8,
                    "reason": "The existing wall is valid cover.",
                },
                {
                    "affordance_id": "build_storm_rod",
                    "priority": 0.7,
                    "reason": "Flying enemies need a sky answer.",
                },
            ],
            "priority_hints": {
                "use_existing_wall": 0.8,
                "build_storm_rod": 0.7,
                "unknown_model_key": 1.0,
            },
            "sign_strength": 0.9,
            "resonance": 0.85,
            "extra_response_field": "must not pass response schema",
        }

    monkeypatch.setattr(gateway_main, "call_deep_model", fake_call_deep_model)

    client = TestClient(gateway_main.app)
    response = client.post("/ai/deep-interpretation", json=payload)

    assert response.status_code == 200
    assert "extra_forbidden" not in response.text
    validated = DeepInterpretationResponse(**response.json())
    assert validated.grounded_plan[0]["affordance_id"] == "use_existing_wall"
    assert validated.priority_hints["build_storm_rod"] == 0.7
    assert "unknown_model_key" not in validated.priority_hints
    assert set(response.json()) == {
        "interpretation",
        "thought",
        "survival_theory",
        "emotion",
        "grounded_plan",
        "priority_hints",
        "sign_strength",
        "resonance",
    }


def test_deep_interpretation_deterministic_mode_skips_model(monkeypatch):
    import app.main as gateway_main
    from app.model_client import Settings

    payload = _modern_godot_payload()

    async def fake_call_deep_model(_request, _settings):
        raise AssertionError("deterministic deep mode must not call the model")

    monkeypatch.setattr(gateway_main, "call_deep_model", fake_call_deep_model)
    gateway_main.app.dependency_overrides[gateway_main.get_settings] = lambda: Settings(deep_mode="deterministic")
    try:
        response = TestClient(gateway_main.app).post("/ai/deep-interpretation", json=payload)
    finally:
        gateway_main.app.dependency_overrides.clear()

    assert response.status_code == 200
    data = response.json()
    assert data["interpretation"] == payload["local_fallback"]["interpretation"]
    assert data["survival_theory"] == "local_fallback"


def test_deep_request_accepts_rulebook_perception_and_prompt_uses_strategy_context():
    payload = _modern_godot_payload()
    payload["sign_text"] = "attack them around the corner with a bow"
    payload["rulebook"] = _compact_rulebook_payload()
    payload["perception"] = _compact_perception_payload()
    payload["run_build"] = {"preset": "Tower Archer", "points": {"bow": 5, "building": 3}}

    request = DeepInterpretationRequest(**payload)

    assert request.rulebook["rules"]["walls"] == "Walls block ground enemies but not flying enemies."
    assert request.perception["tactical_facts"][0] == "A wall is between Ari and the nearest zombie."
    assert request.run_build["preset"] == "Tower Archer"

    prompt = deep_user_prompt(request)

    assert "Rulebook:" in prompt
    assert "Perception:" in prompt
    assert "A wall is between Ari and the nearest zombie." in prompt
    assert "flying enemies ignore walls" in prompt
    assert "attack them around the corner with a bow" in prompt
    assert "use_cover/ranged_attack" in prompt
    assert "Do not invent unavailable actions" in prompt


INTELLIGENCE_CONTRACT_SCENARIOS = [
    {
        "sign": "stand behind the wall",
        "world": {"wall_count": 2, "enemy_count": 1, "enemy_type_counts": {"zombie": 1}},
        "facts": ["A wall is between Ari and a ground enemy."],
        "expected_plan": ["use_existing_wall", "use_cover", "wait_behind_wall"],
        "reject": ["build_wall"],
    },
    {
        "sign": "stand behind the wall",
        "world": {"wall_count": 0, "stone": 12, "enemy_count": 0},
        "facts": ["No wall exists; Ari must make cover before using it."],
        "expected_plan": ["build_wall"],
        "reject": ["use_existing_wall"],
    },
    {
        "sign": "become a silent spider and make the dead walk into your web",
        "world": {"aura_orb_count": 1, "enemy_count": 2, "enemy_type_counts": {"zombie": 2}},
        "facts": ["Aura Orb exists, but enemies are outside its damage circle."],
        "expected_plan": ["lure_to_aura", "use_cover"],
        "reject": ["fight_head_on"],
    },
    {
        "sign": "do not hide, focus on killing enemies",
        "world": {"ore": 3, "sword_tier": 0, "enemy_count": 0},
        "facts": ["Daytime prep can improve the sword before fighting."],
        "expected_plan": ["smith_sword", "train_sword", "fight_head_on", "mine_ore", "prepare_weapon", "train_combat"],
        "reject": ["hide_until_dawn", "stall_until_dawn", "use_tower", "ranged_attack", "build_tower", "train_bow"],
    },
    {
        "sign": "just survive until morning",
        "world": {"phase": "night", "time_left": 8, "wall_count": 1, "enemy_count": 2},
        "facts": ["Dawn is soon; stalling can be valid.", "Ari has low HP."],
        "expected_plan": ["stall_until_dawn", "hide_until_dawn", "use_cover", "flee"],
        "reject": ["fight_head_on"],
    },
    {
        "sign": "the wings do not fear stone",
        "world": {"wall_count": 2, "stone": 12, "enemy_count": 1, "enemy_type_counts": {"flying": 1}},
        "facts": ["Flying enemies ignore walls; Storm Rod or range matters."],
        "expected_plan": ["build_storm_rod", "anti_flying", "sky_answer", "ranged_attack"],
        "reject": ["build_wall"],
    },
    {
        "sign": "my stomach is a second wall",
        "world": {"food": 1, "enemy_count": 0},
        "facts": ["Hunger is high; food is safety."],
        "expected_plan": ["eat_food", "eat", "farm_food", "rest"],
        "reject": ["fight_head_on"],
    },
    {
        "sign": "attack them around the corner with a bow",
        "world": {"wall_count": 1, "bow_tower_count": 1, "enemy_count": 1},
        "facts": ["Existing wall cover and bow tower range can combine."],
        "expected_plan": ["use_cover", "ranged_attack", "use_tower"],
        "reject": ["build_wall"],
    },
    {
        "sign": "use bow",
        "world": {"wall_count": 1, "bow_tower_count": 1, "enemy_count": 1, "enemy_type_counts": {"zombie": 1}},
        "facts": ["A bow tower can support ranged attacks.", "A ground enemy is approaching."],
        "expected_plan": ["use_tower", "ranged_attack", "train_bow", "build_tower"],
        "reject": ["train_combat", "fight_head_on"],
    },
]


@pytest.mark.parametrize("scenario", INTELLIGENCE_CONTRACT_SCENARIOS, ids=lambda item: item["sign"])
def test_deep_interpretation_intelligence_scenario_contracts(monkeypatch, scenario):
    import app.main as gateway_main

    payload = _intelligence_payload(scenario)
    expected_plan = scenario["expected_plan"]
    reject = set(scenario["reject"])

    async def fake_call_deep_model(_request, _settings):
        return {
            "interpretation": "Ari maps the sign to current world-aware tools.",
            "thought": "The sign is strange, but the world makes it practical.",
            "survival_theory": "world_aware_strategy",
            "emotion": "focused",
            "grounded_plan": [
                {
                    "affordance_id": expected_plan[0],
                    "priority": 0.92,
                    "reason": "The sign and perception make this the best executable step.",
                },
                {
                    "affordance_id": expected_plan[-1],
                    "priority": 0.66,
                    "reason": "This is the next fallback if the first step fails.",
                },
                {
                    "affordance_id": "unknown_magic",
                    "priority": 1.0,
                    "reason": "Must be removed.",
                },
            ],
            "priority_hints": {
                expected_plan[0]: 1.2,
                "unknown_magic": 1.0,
                **{key: 0.99 for key in reject},
            },
            "sign_strength": 1.4,
            "resonance": -2,
        }

    monkeypatch.setattr(gateway_main, "call_deep_model", fake_call_deep_model)

    client = TestClient(gateway_main.app)
    response = client.post("/ai/deep-interpretation", json=payload)

    assert response.status_code == 200
    data = response.json()
    validated = DeepInterpretationResponse(**data)
    assert validated.grounded_plan[0]["affordance_id"] in expected_plan
    assert validated.priority_hints[expected_plan[0]] == 1.0
    assert "unknown_magic" not in validated.priority_hints
    assert validated.sign_strength == 1.0
    assert validated.resonance == 0.0


def test_prompt_prioritizes_world_perception_over_generic_examples():
    payload = _intelligence_payload(
        {
            "sign": "the wall is already enough, do not build more",
            "world": {"wall_count": 2, "enemy_count": 1, "enemy_type_counts": {"zombie": 1}},
            "facts": ["A wall is between Ari and a ground enemy.", "Existing cover is already enough."],
            "expected_plan": ["use_existing_wall", "use_cover"],
            "reject": ["build_wall"],
        }
    )

    prompt = deep_user_prompt(DeepInterpretationRequest(**payload))

    assert "Prefer concrete perception facts and available affordances over generic examples" in prompt
    assert "If perception says a tool already exists, prefer using it before building another copy" in prompt
    assert "the floor should fight" in prompt
    assert "make the room dangerous" in prompt


def test_prompt_direct_combat_rejects_default_tower_top_plan():
    payload = _intelligence_payload(
        {
            "sign": "do not hide, focus on killing enemies",
            "world": {"ore": 3, "sword_tier": 0, "enemy_count": 0, "bow_tower_count": 0},
            "facts": ["Daytime prep can improve the sword before fighting."],
            "expected_plan": ["smith_sword", "train_sword", "fight_head_on"],
            "reject": ["use_tower"],
        }
    )

    prompt = deep_user_prompt(DeepInterpretationRequest(**payload))

    assert "Direct combat/no-hide signs" in prompt
    assert "grounded_plan[0]" in prompt
    assert "train_combat/prepare_weapon/train_sword/smith_sword/mine_ore/fight_head_on" in prompt
    assert "theory should be combat prep/sword/direct fighting" in prompt
    assert "Do not use tower/range as top plan for generic killing" in prompt
    assert "explicit no-hide/direct killing" in prompt


def test_prompt_use_bow_has_ranged_semantic_cue():
    payload = _intelligence_payload(
        {
            "sign": "use bow",
            "world": {"wall_count": 1, "bow_tower_count": 1, "enemy_count": 1, "enemy_type_counts": {"zombie": 1}},
            "facts": ["A bow tower can support ranged attacks."],
            "expected_plan": ["use_tower", "ranged_attack"],
            "reject": ["train_combat"],
        }
    )

    prompt = deep_user_prompt(DeepInterpretationRequest(**payload))

    assert "use bow" in prompt
    assert "bow/ranged intent" in prompt
    assert "use_tower/ranged_attack/train_bow/build_tower" in prompt


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


def _modern_godot_payload() -> dict:
    return {
        "sign_text": "stand behind the wall while the sky watches",
        "ari": {
            "run_build": {"preset": "Tower Archer", "points": {"bow": 5, "building": 3}},
            "hp": 86,
            "max_hp": 108,
            "current_job": "use_cover",
            "current_reason": "Use the existing wall while enemies approach",
            "job": "use_cover",
            "reason": "Use the existing wall while enemies approach",
            "hunger": 42.0,
            "stamina": 76.0,
            "fear": 31.0,
            "benign_future_ari_field": {"ignored": True},
        },
        "world": {
            "day": 3,
            "phase": "night",
            "time_left": 18,
            "stone": 12,
            "food": 2,
            "ore": 3,
            "wall_count": 2,
            "aura_orb_count": 1,
            "bow_tower_count": 1,
            "storm_rod_count": 1,
            "sword_tier": 2,
            "enemy_count": 4,
            "enemy_type_counts": {"zombie": 1, "runner": 1, "brute": 1, "flying": 1},
            "known_enemy_types": ["zombie", "runner", "brute", "flying"],
            "structures": [
                {"type": "wall", "status": "damaged", "hp_ratio": 0.52},
                {"type": "bow_tower", "status": "intact", "shots_fired": 3},
                {"type": "storm_rod", "status": "intact", "charge": 0.4},
            ],
            "benign_future_world_field": {"ignored": True},
        },
        "current_affordances": [
            {
                "id": "use_existing_wall",
                "description": "Move near an existing wall so enemies must hit or go around it before reaching Ari.",
                "available": True,
                "reason_unavailable": "",
                "debug_score": 0.8,
            },
            {
                "id": "use_tower",
                "description": "Use an existing tower perch to keep distance from ground enemies.",
                "available": True,
                "reason_unavailable": "",
            },
            {
                "id": "build_storm_rod",
                "description": "Build a Storm Rod as an anti-flying sky defense.",
                "available": True,
                "reason_unavailable": "",
            },
            {
                "id": "mine_ore",
                "description": "Mine low-tier ore for sword upgrades at the forge.",
                "available": True,
                "reason_unavailable": "",
            },
        ],
        "recent_thoughts": [
            "The wall buys time.",
            "The flying ones do not care about stone.",
        ],
        "latest_library_note": "# Day 2\n\nTower saved me from teeth, not wings.",
        "local_fallback": {
            "interpretation": "Ari locally reads the sign as wall cover with sky danger.",
            "priority_hints": {
                "use_existing_wall": 0.8,
                "use_cover": 0.7,
                "build_storm_rod": 0.6,
            },
            "emotion": "careful",
            "grounded_plan": [
                {
                    "affordance_id": "use_existing_wall",
                    "priority": 0.8,
                    "reason": "The wall already exists.",
                    "future_reason_detail": "ignored",
                }
            ],
            "sign_strength": 0.75,
            "resonance": 0.7,
            "future_fallback_note": "ignored",
        },
        "benign_future_top_level": "ignored",
    }


def _intelligence_payload(scenario: dict) -> dict:
    payload = _modern_godot_payload()
    payload["sign_text"] = scenario["sign"]
    payload["rulebook"] = {
        "version": "ari_strategy_rulebook_v1",
        "rules": {
            "objective": "Survive as many nights as possible; killing is optional.",
            "walls": "Walls block ground enemies but flying enemies ignore walls.",
            "aura_orb": "Aura Orb works through positioning and luring.",
            "tower": "Tower and cover can combine for protected range.",
            "runners": "Runners punish open layouts and require distance, cover, or slowing.",
            "brutes": "Brutes break structures, so weak wall-only plans are risky.",
            "dawn": "Night enemies clear at dawn, so stalling can be correct.",
            "smithing": "Ore and forge time improve direct fighting but consume day time.",
        },
    }
    world = payload["world"]
    world.update(scenario.get("world", {}))
    payload["perception"] = {
        "phase": world.get("phase", "midday"),
        "time_left": world.get("time_left", 25),
        "is_night": world.get("phase") == "night",
        "is_dawn_soon": world.get("phase") == "night" and float(world.get("time_left", 0)) <= 15,
        "ari": {"hp": 34 if "low HP" in " ".join(scenario.get("facts", [])) else 82, "hunger": 75 if "Hunger" in " ".join(scenario.get("facts", [])) else 42},
        "resources": {
            "stone": world.get("stone", 0),
            "food": world.get("food", 0),
            "ore": world.get("ore", 0),
            "wall_count": world.get("wall_count", 0),
            "aura_orb_count": world.get("aura_orb_count", 0),
            "bow_tower_count": world.get("bow_tower_count", 0),
            "storm_rod_count": world.get("storm_rod_count", 0),
        },
        "nearby_enemies": [],
        "nearby_structures": world.get("structures", []),
        "tactical_facts": scenario.get("facts", []),
        "available_safe_moves": ["use_cover", "use_tower", "lure_to_aura", "flee", "stall_until_dawn"],
    }
    payload["current_affordances"] = [
        {"id": key, "description": key.replace("_", " "), "available": True}
        for key in sorted(ALLOWED_PRIORITY_KEYS)
        if key not in {"mining", "wall", "aura_orb", "combat_training", "range", "defensive_wait"}
    ]
    payload["local_fallback"] = {
        "interpretation": "Local fallback should not be copied.",
        "priority_hints": {},
        "grounded_plan": [],
        "sign_strength": 0.5,
        "resonance": 0.5,
    }
    return payload


def _compact_rulebook_payload() -> dict:
    return {
        "version": 1,
        "rules": {
            "walls": "Walls block ground enemies but not flying enemies.",
            "aura_orb": "Aura Orb damages enemies inside its circle; Ari should lure enemies through it.",
            "tower": "Bow towers create ranged attacks from height but need an existing tower.",
            "storm_rod": "Storm Rod is the dedicated answer to flying enemies.",
            "smithing": "Sword upgrades need ore and forge time before direct melee is wise.",
        },
        "affordance_notes": {
            "use_existing_wall": "Use a wall that already exists; do not build more wall unless no cover exists.",
            "ranged_attack": "Requires tower/range support.",
            "smith_sword": "Requires ore.",
        },
    }


def _compact_perception_payload() -> dict:
    return {
        "phase": "night",
        "time_left": 14,
        "is_night": True,
        "is_dawn_soon": True,
        "ari": {"hp": 74, "hunger": 48, "current_job": "use_cover"},
        "resources": {"stone": 12, "food": 2, "ore": 1},
        "run_build": {"preset": "Tower Archer"},
        "sword_tier": 1,
        "nearby_enemies": [
            {
                "type": "zombie",
                "distance": 96,
                "direction": "east",
                "danger": "medium",
                "is_flying": False,
                "tactical_note": "Ground enemy can be delayed by walls.",
            },
            {
                "type": "flying",
                "distance": 128,
                "direction": "north-east",
                "danger": "high",
                "is_flying": True,
                "tactical_note": "Flying enemies ignore walls.",
            },
        ],
        "nearby_structures": [
            {
                "type": "wall",
                "distance": 34,
                "direction": "east",
                "condition": "intact",
                "tactical_use": "existing cover",
            },
            {
                "type": "bow_tower",
                "distance": 70,
                "direction": "north",
                "condition": "intact",
                "tactical_use": "ranged attacks",
            },
        ],
        "tactical_facts": [
            "A wall is between Ari and the nearest zombie.",
            "Dawn is soon; stalling is valid.",
            "Flying enemies ignore walls.",
        ],
        "available_safe_moves": ["use_cover", "use_tower", "stall_until_dawn"],
    }


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
        "do not hide, focus on killing enemies",
        "just survive until morning",
        "make a sword that gives you life when they die",
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
        "fight_head_on",
        "train_sword",
        "smith_sword",
        "mine_ore",
        "use_armor",
        "rely_on_regen",
        "regen_on_kill",
        "stall_until_dawn",
        "hide_until_dawn",
        "avoid_killing",
        "survive_until_morning",
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
    assert "do not hide, focus on killing enemies => fight_head_on/train_sword/smith_sword/mine_ore" in prompt
    assert "just survive until morning => stall_until_dawn/hide_until_dawn/survive_until_morning/avoid_killing" in prompt
    assert "make a sword that gives you life when they die => smith_sword/train_sword/regen_on_kill/rely_on_regen" in prompt
    assert "Semantic cues for this sign: existing wall cover" in prompt
    assert "build_wall=0" in prompt


def test_deep_user_prompt_stays_compact_for_latency():
    prompt = deep_user_prompt(_deep_request("the wings do not fear stone"))

    assert len(prompt) < 3200
    assert "current_affordances available:" in prompt
    assert "Compatibility priority_hints may use these executable affordance ids" not in prompt
    assert "sky threat; wall/cover fails" in prompt
    assert "after storm exists, add tower/ranged support" in prompt
