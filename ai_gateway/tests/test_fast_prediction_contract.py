import sys
from pathlib import Path

from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import main
from app.prompting import prediction_user_prompt
from app.schemas import PredictionRequest


def test_fast_prediction_endpoint_sanitizes_model_result(monkeypatch):
    async def fake_call_prediction_model(request, settings):
        assert request.context_hash == "ctx-fast"
        return {
            "schema": "ari.prediction.v1",
            "context_hash": request.context_hash,
            "risk_level": "catastrophic",
            "prediction": "Flying danger will bypass ordinary walls unless Ari builds a sky answer.",
            "next_action_bias": {"action_id": "build_storm_rod", "urgency": 2, "reason": "wings need sky answer"},
            "priority_hints": {"build_storm_rod": 1.4, "unknown_magic": 1},
            "avoid": ["extra walls before sky answer"],
            "confidence": 1.6,
            "extra": "drop me",
        }

    monkeypatch.setattr(main, "call_prediction_model", fake_call_prediction_model, raising=False)

    response = TestClient(main.app).post("/ari/predict-v1", json=_prediction_payload())

    assert response.status_code == 200
    raw = response.json()
    assert raw["schema"] == "ari.prediction.v1"
    assert raw["context_hash"] == "ctx-fast"
    assert raw["risk_level"] == "high"
    assert raw["next_action_bias"]["action_id"] == "build_storm_rod"
    assert raw["next_action_bias"]["urgency"] == 1.0
    assert raw["priority_hints"] == {"build_storm_rod": 1.0}
    assert raw["confidence"] == 1.0
    assert "extra" not in raw


def test_fast_prediction_endpoint_falls_back_on_model_failure(monkeypatch):
    async def fake_call_prediction_model(request, settings):
        raise RuntimeError("model too slow")

    monkeypatch.setattr(main, "call_prediction_model", fake_call_prediction_model, raising=False)

    response = TestClient(main.app).post("/ari/predict-v1", json=_prediction_payload())

    assert response.status_code == 200
    raw = response.json()
    assert raw["schema"] == "ari.prediction.v1"
    assert raw["source"] == "local_fallback"
    assert raw["failure_reason"] == "model_failed"
    assert raw["next_action_bias"]["action_id"] == "build_storm_rod"


def test_fast_prediction_endpoint_rejects_non_legal_action(monkeypatch):
    async def fake_call_prediction_model(request, settings):
        return {
            "schema": "ari.prediction.v1",
            "context_hash": request.context_hash,
            "risk_level": "medium",
            "prediction": "Invented action should be rejected.",
            "next_action_bias": {"action_id": "summon_dragon", "urgency": 0.9, "reason": "bad"},
            "priority_hints": {"summon_dragon": 1, "build_wall": 0.5},
            "confidence": 0.8,
        }

    monkeypatch.setattr(main, "call_prediction_model", fake_call_prediction_model, raising=False)

    response = TestClient(main.app).post("/ari/predict-v1", json=_prediction_payload())

    assert response.status_code == 200
    raw = response.json()
    assert raw["next_action_bias"]["action_id"] == "build_storm_rod"
    assert raw["priority_hints"] == {"build_wall": 0.5}


def test_fast_prediction_endpoint_accepts_compact_model_result(monkeypatch):
    async def fake_call_prediction_model(request, settings):
        return {
            "r": "high",
            "a": "build_storm_rod",
            "u": 0.86,
            "why": "Flying danger is close, so Ari should stop mining and answer the sky.",
            "h": {"build_storm_rod": 0.82},
            "avoid": ["mining during active night attack"],
            "c": 0.74,
        }

    monkeypatch.setattr(main, "call_prediction_model", fake_call_prediction_model, raising=False)

    response = TestClient(main.app).post("/ari/predict-v1", json=_prediction_payload())

    assert response.status_code == 200
    raw = response.json()
    assert raw["schema"] == "ari.prediction.v1"
    assert raw["risk_level"] == "high"
    assert raw["prediction"] == "Flying danger is close, so Ari should stop mining and answer the sky."
    assert raw["next_action_bias"]["action_id"] == "build_storm_rod"
    assert raw["next_action_bias"]["urgency"] == 0.86
    assert raw["priority_hints"] == {"build_storm_rod": 0.82}
    assert raw["confidence"] == 0.74


def test_fast_prediction_endpoint_accepts_ultra_compact_model_result_without_reason(monkeypatch):
    async def fake_call_prediction_model(request, settings):
        return {
            "r": "high",
            "a": "build_storm_rod",
            "u": 0.86,
            "h": {"build_storm_rod": 0.82},
            "c": 0.74,
        }

    monkeypatch.setattr(main, "call_prediction_model", fake_call_prediction_model, raising=False)

    response = TestClient(main.app).post("/ari/predict-v1", json=_prediction_payload())

    assert response.status_code == 200
    raw = response.json()
    assert raw["schema"] == "ari.prediction.v1"
    assert raw["risk_level"] == "high"
    assert raw["next_action_bias"]["action_id"] == "build_storm_rod"
    assert raw["next_action_bias"]["reason"] != ""
    assert raw["priority_hints"] == {"build_storm_rod": 0.82}
    assert raw["confidence"] == 0.74


def test_fast_prediction_prompt_includes_compact_action_control_panel():
    payload = _prediction_payload()
    payload["action_control_panel"] = {
        "schema": "ari.action_control_panel.v1",
        "actions": [
            {
                "id": "build_storm_rod",
                "available": True,
                "category": "build",
                "description": "Build a Storm Rod as an anti-flying sky defense.",
                "counters": ["flying"],
                "preconditions": ["daytime_building", "stone_available"],
                "good_when": ["flying_enemy_seen"],
                "failure_modes": ["too_late_after_flying_contact"],
            },
            {
                "id": "mine_stone",
                "available": True,
                "category": "resource",
                "description": "Mine stone for structures.",
                "enables": ["build_storm_rod"],
                "preconditions": ["daytime_resource_work"],
                "good_when": ["resource_blocker:stone"],
            },
        ],
    }

    prompt = prediction_user_prompt(PredictionRequest(**payload))

    assert "panel=" in prompt
    assert "build_storm_rod" in prompt
    assert "anti-flying" in prompt
    assert "needs:daytime_building" in prompt
    assert "good:flying_enemy_seen" in prompt
    assert "fails:too_late_after_flying_contact" in prompt
    assert "mine_stone" in prompt
    assert len(prompt) < 1200


def test_fast_prediction_prompt_includes_rolling_summary():
    payload = _prediction_payload()
    payload["rolling_summary"] = {
        "schema": "ari.rolling_tactical_summary.v1",
        "risk_level": "high",
        "threats": ["flying"],
        "plan_mismatches": ["Ari kept mining while flying danger approached."],
        "resource_blockers": ["low_stone"],
        "priority_hints": {"build_storm_rod": 0.8},
    }

    prompt = prediction_user_prompt(PredictionRequest(**payload))

    assert "risk=" in prompt
    assert "flying" in prompt
    assert "low_stone" in prompt
    assert "Ari kept mining" in prompt
    assert len(prompt) < 1200


def _prediction_payload():
    return {
        "schema": "ari.prediction.request.v1",
        "context_hash": "ctx-fast",
        "day": 3,
        "phase": "night",
        "time_left": 42.0,
        "ari": {"hp": 72, "current_action": "build_wall"},
        "risks": [{"type": "flying", "distance": 96, "severity": 0.9}],
        "resources": {"stone": 18, "food": 4, "ore": 2},
        "current_plan": {"next_action": "build_wall"},
        "strategy_packet": {
            "schema": "ari.strategy_packet.v1",
            "main_risks": ["flying"],
            "current_lessons": ["when wings appear, answer the sky first"],
            "priority_hints": {"build_storm_rod": 0.6},
        },
        "legal_actions": [
            {"id": "build_wall", "available": True},
            {"id": "build_storm_rod", "available": True},
            {"id": "mine_stone", "available": True},
            {"id": "use_cover", "available": True},
            {"id": "flee", "available": True},
        ],
    }
