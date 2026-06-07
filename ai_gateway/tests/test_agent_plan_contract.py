import sys
from pathlib import Path

from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import main
from app.prompting import agent_plan_user_prompt
from app.schemas import AgentPlanRequest, fallback_agent_plan_response, sanitize_agent_plan_response


def test_agent_plan_endpoint_accepts_legal_plan(monkeypatch):
    async def fake_call_plan_model(request, settings):
        return {
            "schema": "ari.agent.plan.v1",
            "goal": "survive with height",
            "survival_theory": "Height buys Ari time.",
            "plan": [
                {
                    "step_id": "build_height",
                    "action_id": "build_tower",
                    "reason": "The sign asks for arrows above teeth.",
                    "success": "bow_tower_count > 0",
                }
            ],
            "next_action": {"action_id": "build_tower", "urgency": 0.9},
            "fallback_action": {"action_id": "use_cover", "reason": "Use the wall if tower work fails."},
            "belief_updates": [{"key": "height", "delta": 0.4, "reason": "The sign names arrows."}],
            "thought": "If death has to climb, I get time.",
            "confidence": 0.8,
            "replan_after_seconds": 9,
        }

    monkeypatch.setattr(main, "call_plan_model", fake_call_plan_model, raising=False)
    response = TestClient(main.app).post("/ari/plan-v1", json=_plan_payload())

    assert response.status_code == 200
    data = response.json()
    assert data["schema"] == "ari.agent.plan.v1"
    assert data["goal"] == "survive with height"
    assert data["next_action"]["action_id"] == "build_tower"
    assert data["fallback_action"]["action_id"] == "use_cover"
    assert data["plan"][0]["action_id"] == "build_tower"
    assert data["belief_updates"][0]["key"] == "height"
    assert data["confidence"] == 0.8


def test_agent_plan_endpoint_accepts_compact_model_result(monkeypatch):
    async def fake_call_plan_model(request, settings):
        return {
            "g": "survive with height",
            "theory": "Height buys Ari time against teeth.",
            "plan": ["build_tower", "use_tower"],
            "next": "build_tower",
            "fb": "use_cover",
            "why": "Build height before night.",
            "belief": {"height_buys_time": 0.4},
            "thought": "If death has to climb, I get time.",
            "c": 0.8,
            "after": 9,
        }

    monkeypatch.setattr(main, "call_plan_model", fake_call_plan_model, raising=False)
    response = TestClient(main.app).post("/ari/plan-v1", json=_plan_payload())

    assert response.status_code == 200
    data = response.json()
    assert data["schema"] == "ari.agent.plan.v1"
    assert data["source"] == "remote_server"
    assert data["goal"] == "survive with height"
    assert data["survival_theory"] == "Height buys Ari time against teeth."
    assert data["plan"][0]["action_id"] == "build_tower"
    assert data["next_action"]["action_id"] == "build_tower"
    assert data["fallback_action"]["action_id"] == "use_cover"
    assert data["belief_updates"] == [{"key": "height_buys_time", "delta": 0.4, "reason": "Height buys Ari time against teeth."}]
    assert data["confidence"] == 0.8
    assert data["replan_after_seconds"] == 9


def test_agent_plan_endpoint_falls_back_on_unknown_action(monkeypatch):
    async def fake_call_plan_model(request, settings):
        return {
            "schema": "ari.agent.plan.v1",
            "goal": "cheat",
            "survival_theory": "Invented actions should be rejected.",
            "plan": [{"step_id": "bad", "action_id": "spawn_dragon", "reason": "illegal", "success": "dragon"}],
            "next_action": {"action_id": "spawn_dragon", "urgency": 1.0},
            "fallback_action": {"action_id": "teleport", "reason": "also illegal"},
            "belief_updates": [],
            "thought": "I should not be allowed to do this.",
            "confidence": 1.0,
            "replan_after_seconds": 1,
        }

    monkeypatch.setattr(main, "call_plan_model", fake_call_plan_model, raising=False)
    response = TestClient(main.app).post("/ari/plan-v1", json=_plan_payload())

    assert response.status_code == 200
    data = response.json()
    assert data["source"] == "local_fallback"
    assert data["next_action"]["action_id"] == "use_cover"
    assert data["fallback_action"]["action_id"] == "flee"
    assert data["plan"][0]["action_id"] == "use_cover"
    assert data["failure_reason"] == "invalid_action"


def test_agent_plan_endpoint_preserves_failure_safe_fallback(monkeypatch):
    async def fake_call_plan_model(request, settings):
        raise RuntimeError("model unavailable")

    monkeypatch.setattr(main, "call_plan_model", fake_call_plan_model, raising=False)
    response = TestClient(main.app).post("/ari/plan-v1", json=_plan_payload())

    assert response.status_code == 200
    data = response.json()
    assert data["source"] == "local_fallback"
    assert data["next_action"]["action_id"] == "use_cover"
    assert data["fallback_action"]["action_id"] == "flee"
    assert data["failure_reason"] == "model_failed"


def test_agent_plan_endpoint_guards_doctrine_prerequisite_skip(monkeypatch):
    async def fake_call_plan_model(request, settings):
        return {
            "schema": "ari.agent.plan.v1",
            "goal": "skip prerequisite",
            "survival_theory": "The tower can still fire.",
            "plan": [{
                "step_id": "skip_to_tower",
                "action_id": "use_tower",
                "reason": "Use the tower even though the Storm Rod is gone.",
                "success": "survive",
            }],
            "next_action": {"action_id": "use_tower", "urgency": 0.9, "reason": "Use tower."},
            "fallback_action": {"action_id": "use_cover", "urgency": 0.4},
            "belief_updates": [],
            "thought": "The tower is enough.",
            "confidence": 0.8,
            "replan_after_seconds": 8,
        }

    payload = _plan_payload()
    payload["world"] = {
        **payload["world"],
        "stone": 4,
        "storm_rod_count": 0,
        "bow_tower_count": 1,
        "enemy_count": 0,
    }
    payload["active_doctrine_plan"] = [
        {"affordance_id": "build_storm_rod", "priority": 0.85},
        {"affordance_id": "build_tower", "priority": 0.58},
        {"affordance_id": "use_tower", "priority": 0.48},
    ]
    payload["legal_actions"] = [
        {"id": "mine_stone", "available": True, "description": "Mine stone."},
        {"id": "build_storm_rod", "available": False, "description": "Build Storm Rod.", "reason_unavailable": "not enough stone"},
        {"id": "use_tower", "available": True, "description": "Use tower."},
        {"id": "use_cover", "available": True, "description": "Use cover."},
    ]

    monkeypatch.setattr(main, "call_plan_model", fake_call_plan_model, raising=False)
    response = TestClient(main.app).post("/ari/plan-v1", json=payload)

    assert response.status_code == 200
    data = response.json()
    assert data["source"] == "remote_server"
    assert data["next_action"]["action_id"] == "mine_stone"
    assert data["plan"][0]["action_id"] == "mine_stone"
    assert "Storm Rod" in data["next_action"]["reason"]


def test_agent_plan_prompt_includes_compact_semantic_action_examples():
    prompt = agent_plan_user_prompt(AgentPlanRequest(**_plan_payload()))

    assert "mountain/arrows=>build_tower" in prompt
    assert "wings=>build_storm_rod" in prompt
    assert "survive morning=>use_cover/flee/stall_until_dawn" in prompt
    assert "first plan id should equal next" in prompt
    assert "doctrine prereq" in prompt
    assert "doctrine_plan=" in prompt
    assert "survive with height" not in prompt
    assert len(prompt) < 2600


def test_agent_plan_prompt_includes_compact_action_control_panel():
    payload = _plan_payload()
    payload["action_control_panel"] = {
        "schema": "ari.action_control_panel.v1",
        "actions": [
            {
                "id": "build_storm_rod",
                "available": True,
                "category": "build",
                "description": "Build a Storm Rod as an anti-flying sky defense.",
                "counters": ["flying"],
                "cost": {"stone": 15},
            },
            {
                "id": "mine_stone",
                "available": True,
                "category": "resource",
                "description": "Mine stone for structures.",
                "enables": ["build_storm_rod"],
            },
        ],
    }

    prompt = agent_plan_user_prompt(AgentPlanRequest(**payload))

    assert "panel=" in prompt
    assert "build_storm_rod" in prompt
    assert "anti-flying" in prompt
    assert "mine_stone" in prompt
    assert "enables" in prompt


def test_agent_plan_prompt_compacts_local_fallback_without_thought_prose():
    payload = _plan_payload()
    payload["local_fallback"]["thought"] = "I can still choose a legal fallback."

    prompt = agent_plan_user_prompt(AgentPlanRequest(**payload))
    fallback_line = next(line for line in prompt.splitlines() if line.startswith("fallback="))

    assert "I can still choose a legal fallback" not in prompt
    assert "next_action" in fallback_line
    assert "fallback_action" in fallback_line
    assert len(fallback_line) < 360


def test_agent_plan_sanitizer_promotes_first_plan_step_to_next_action():
    raw = {
        "schema": "ari.agent.plan.v1",
        "goal": "survive with height",
        "survival_theory": "Height buys Ari time.",
        "plan": [
            {
                "step_id": "build_height",
                "action_id": "build_tower",
                "reason": "The sign asks for arrows above teeth.",
                "success": "bow_tower_count > 0",
            }
        ],
        "next_action": {"action_id": "use_cover", "urgency": 0.5, "reason": "Generic safe fallback."},
        "fallback_action": {"action_id": "flee", "urgency": 0.4, "reason": "Distance is safe."},
        "belief_updates": [],
        "thought": "A tower is the plan.",
        "confidence": 0.8,
        "replan_after_seconds": 9,
    }

    data = sanitize_agent_plan_response(raw, _plan_payload()["local_fallback"], _plan_payload()["legal_actions"])

    assert data["plan"][0]["action_id"] == "build_tower"
    assert data["next_action"]["action_id"] == "build_tower"
    assert "The sign asks for arrows" in data["next_action"]["reason"]


def test_agent_plan_sanitizer_replaces_remote_fallback_like_thought():
    raw = {
        "schema": "ari.agent.plan.v1",
        "goal": "survive with height",
        "survival_theory": "Build height because the sign asks for arrows above teeth.",
        "plan": [
            {
                "step_id": "build_height",
                "action_id": "build_tower",
                "reason": "The sign asks for arrows above teeth.",
                "success": "bow_tower_count > 0",
            }
        ],
        "next_action": {"action_id": "build_tower", "urgency": 0.9, "reason": "Build height before night."},
        "fallback_action": {"action_id": "use_cover", "urgency": 0.4, "reason": "Use cover if building fails."},
        "belief_updates": [],
        "thought": "I can still choose a legal fallback.",
        "confidence": 0.8,
        "replan_after_seconds": 9,
    }

    data = sanitize_agent_plan_response(raw, _plan_payload()["local_fallback"], _plan_payload()["legal_actions"])

    assert data["source"] == "remote_server"
    assert "fallback" not in data["thought"].lower()
    assert "Build height before night" in data["thought"]


def test_agent_plan_sanitizer_blocks_suicidal_melee_when_tower_answer_exists():
    payload = _plan_payload()
    payload["sign"] = {"text": "build a mountain where arrows rain", "interpretation": "height and range"}
    payload["world"] = {
        **payload["world"],
        "phase": "night",
        "enemy_count": 3,
        "enemy_type_counts": {"zombie": 2, "brute": 1},
        "bow_tower_count": 1,
    }
    payload["legal_actions"] = [
        {"id": "fight_head_on", "available": True, "description": "Fight in melee."},
        {"id": "use_tower", "available": True, "description": "Use existing tower range."},
        {"id": "use_cover", "available": True, "description": "Use cover."},
        {"id": "flee", "available": True, "description": "Move away."},
    ]
    raw = {
        "g": "fight anyway",
        "theory": "Bad remote plan should not override the tower control panel.",
        "plan": ["fight_head_on"],
        "next": "fight_head_on",
        "fb": "flee",
        "why": "Fight directly.",
        "c": 0.8,
    }

    data = sanitize_agent_plan_response(raw, payload["local_fallback"], payload["legal_actions"], AgentPlanRequest(**payload))

    assert data["source"] == "remote_server"
    assert data["next_action"]["action_id"] == "use_tower"
    assert data["plan"][0]["action_id"] == "use_tower"
    assert "tower" in data["next_action"]["reason"].lower()


def test_agent_plan_sanitizer_prioritizes_storm_rod_over_cover_against_flying():
    payload = _plan_payload()
    payload["sign"] = {"text": "do not trust walls against wings", "interpretation": "anti air"}
    payload["world"] = {
        **payload["world"],
        "phase": "night",
        "stone": 24,
        "enemy_count": 2,
        "enemy_type_counts": {"flying": 1, "zombie": 1},
        "storm_rod_count": 0,
    }
    payload["legal_actions"] = [
        {"id": "use_cover", "available": True, "description": "Use cover."},
        {"id": "build_storm_rod", "available": True, "description": "Build anti-air defense."},
        {"id": "mine_stone", "available": True, "description": "Mine stone."},
        {"id": "flee", "available": True, "description": "Move away."},
    ]
    raw = {
        "g": "hide behind cover",
        "theory": "Bad remote plan treats flying like ground danger.",
        "plan": ["use_cover"],
        "next": "use_cover",
        "fb": "flee",
        "why": "Use cover.",
        "c": 0.8,
    }

    data = sanitize_agent_plan_response(raw, payload["local_fallback"], payload["legal_actions"], AgentPlanRequest(**payload))

    assert data["source"] == "remote_server"
    assert data["next_action"]["action_id"] == "build_storm_rod"
    assert data["plan"][0]["action_id"] == "build_storm_rod"
    assert "flying" in data["next_action"]["reason"].lower()


def test_agent_plan_sanitizer_repairs_invalid_remote_action_with_doctrine_prerequisite():
    payload = _plan_payload()
    payload["sign"] = {"text": "stone walls are safety", "interpretation": "walls are not enough against wings"}
    payload["world"] = {
        **payload["world"],
        "phase": "midday",
        "stone": 4,
        "enemy_count": 0,
        "enemy_type_counts": {},
        "known_enemy_types": ["zombie", "flying"],
        "storm_rod_count": 0,
        "bow_tower_count": 1,
    }
    payload["active_doctrine_plan"] = [
        {"affordance_id": "build_storm_rod", "priority": 0.85, "reason": "Flying danger needs anti-air."},
        {"affordance_id": "use_tower", "priority": 0.48, "reason": "Use range after the sky answer exists."},
    ]
    payload["legal_actions"] = [
        {"id": "mine_stone", "available": True, "description": "Mine stone."},
        {"id": "build_storm_rod", "available": False, "description": "Build Storm Rod.", "reason_unavailable": "not enough stone"},
        {"id": "use_tower", "available": True, "description": "Use tower."},
        {"id": "use_cover", "available": True, "description": "Use cover."},
    ]
    raw = {
        "g": "repair stone habit",
        "theory": "The learned anti-air doctrine needs a Storm Rod first.",
        "plan": ["build_wall"],
        "next": "build_wall",
        "fb": "use_cover",
        "why": "The old wall habit is illegal in this control panel.",
        "thought": "Stone must become sky-defense resources.",
        "c": 0.72,
        "after": 7,
    }

    data = sanitize_agent_plan_response(raw, payload["local_fallback"], payload["legal_actions"], AgentPlanRequest(**payload))

    assert data["source"] == "validated_guardrail"
    assert data["failure_reason"] == "repaired_invalid_action"
    assert data["next_action"]["action_id"] == "mine_stone"
    assert data["plan"][0]["action_id"] == "mine_stone"
    assert "Storm Rod" in data["next_action"]["reason"]


def test_agent_plan_local_fallback_replaces_fallback_like_thought_with_concrete_reason():
    payload = _plan_payload()
    payload["local_fallback"] = {
        **payload["local_fallback"],
        "plan": [{
            "step_id": "fallback_tower",
            "action_id": "build_tower",
            "reason": "Build the tower because the sign asks for height and arrows.",
            "success": "bow_tower_count > 0",
        }],
        "next_action": {
            "action_id": "build_tower",
            "urgency": 0.7,
            "reason": "Build height before night.",
        },
        "thought": "I can still choose a legal fallback.",
    }

    data = fallback_agent_plan_response(payload["local_fallback"], payload["legal_actions"], "model_failed")

    assert data["source"] == "local_fallback"
    assert data["next_action"]["action_id"] == "build_tower"
    assert "fallback" not in data["thought"].lower()
    assert "Build height before night" in data["thought"]


def _plan_payload():
    return {
        "schema": "ari.agent.plan.v1",
        "decision_kind": "dusk_plan",
        "objective": {"primary": "survive_next_night", "secondary": ["respect_sign_when_safe"]},
        "sign": {
            "text": "build a mountain where arrows rain",
            "interpretation": "height and range",
        },
        "ari": {
            "hp_ratio": 0.8,
            "fear": 22,
            "hunger": 18,
            "stamina": 76,
            "current_job": "wait_or_idle",
            "run_build": {"points": {"bow": 4, "building": 3}},
        },
        "world": {
            "day": 2,
            "phase": "dusk",
            "time_left": 30,
            "stone": 12,
            "ore": 0,
            "enemy_type_counts": {"zombie": 1},
            "wall_count": 1,
            "aura_orb_count": 0,
            "bow_tower_count": 0,
            "storm_rod_count": 0,
            "damaged_structure_count": 0,
        },
        "perception": {
            "tactical_facts": ["A bow tower can support ranged attacks."],
            "available_safe_moves": ["use_cover", "flee"],
        },
        "current_plan": {},
        "active_doctrines": [],
        "active_doctrine_plan": [],
        "recent_outcomes": [],
        "legal_actions": [
            {"id": "mine_stone", "available": True, "description": "Mine stone."},
            {"id": "build_tower", "available": True, "description": "Build tower."},
            {"id": "use_cover", "available": True, "description": "Use cover."},
            {"id": "flee", "available": True, "description": "Move away."},
        ],
        "local_fallback": {
            "goal": "survive using existing cover",
            "survival_theory": "Cover buys time if the model is unavailable.",
            "plan": [
                {
                    "step_id": "fallback_cover",
                    "action_id": "use_cover",
                    "reason": "A wall already exists.",
                    "success": "safe_distance",
                }
            ],
            "next_action": {"action_id": "use_cover", "urgency": 0.6},
            "fallback_action": {"action_id": "flee", "reason": "Distance is always legal."},
            "thought": "I can still use the wall.",
            "confidence": 0.45,
        },
    }
