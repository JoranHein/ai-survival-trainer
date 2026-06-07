import asyncio
import sys
from pathlib import Path

from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import main
from app.model_client import Settings
from app.prompting import background_job_user_prompt
from app.schemas import BackgroundJobRequest


def setup_function():
    main._BACKGROUND_JOB_CACHE.clear()
    main._BACKGROUND_JOB_CACHE_ORDER.clear()


def test_background_job_endpoint_validates_and_sanitizes_model_result(monkeypatch):
    async def fake_call_background_job_model(request, settings):
        assert request.kind == "strategy_candidate"
        assert request.context_hash == "ctx-current"
        return {
            "schema": "ari.background_result.v1",
            "job_id": request.job_id,
            "kind": request.kind,
            "context_hash": request.context_hash,
            "status": "ok",
            "priority_hints": {"build_storm_rod": 2, "unknown_magic": 1},
            "notes": ["Use the sky answer before wall repair."],
            "strategy_packet": {
                "schema": "ari.strategy_packet.v1",
                "main_risks": ["flying"],
                "try_next": ["build_storm_rod"],
                "confidence": 1.5,
            },
            "confidence": 1.4,
            "extra": "drop me",
        }

    monkeypatch.setattr(main, "call_background_job_model", fake_call_background_job_model, raising=False)

    response = TestClient(main.app).post("/background-job", json=_background_job_payload())

    assert response.status_code == 200
    raw = response.json()["raw"]
    assert raw["schema"] == "ari.background_result.v1"
    assert raw["job_id"] == "job-1"
    assert raw["kind"] == "strategy_candidate"
    assert raw["context_hash"] == "ctx-current"
    assert raw["status"] == "ok"
    assert raw["priority_hints"] == {"build_storm_rod": 1.0}
    assert raw["strategy_packet"]["schema"] == "ari.strategy_packet.v1"
    assert raw["strategy_packet"]["confidence"] == 1.0
    assert "extra" not in raw


def test_background_job_endpoint_accepts_compact_model_result(monkeypatch):
    async def fake_call_background_job_model(request, settings):
        return {
            "s": "ok",
            "n": ["Wings are active; keep the sky answer first."],
            "h": {"build_storm_rod": 0.82},
            "try": ["build_storm_rod"],
            "avoid": ["ordinary walls before sky answer"],
            "c": 0.66,
        }

    monkeypatch.setattr(main, "call_background_job_model", fake_call_background_job_model, raising=False)

    response = TestClient(main.app).post("/background-job", json=_background_job_payload())

    assert response.status_code == 200
    raw = response.json()["raw"]
    assert raw["schema"] == "ari.background_result.v1"
    assert raw["status"] == "ok"
    assert raw["notes"] == ["Wings are active; keep the sky answer first."]
    assert raw["priority_hints"]["build_storm_rod"] == 0.82
    assert raw["strategy_packet"]["try_next"] == ["build_storm_rod"]
    assert raw["strategy_packet"]["avoid_repeating"] == ["ordinary walls before sky answer"]
    assert raw["confidence"] == 0.66


def test_background_job_endpoint_marks_stale_without_model_call(monkeypatch):
    calls = {"count": 0}

    async def fake_call_background_job_model(request, settings):
        calls["count"] += 1
        raise AssertionError("stale jobs should not call the model")

    payload = _background_job_payload()
    payload["expires_at_game_time"] = 10.0
    payload["current_game_time"] = 12.0
    monkeypatch.setattr(main, "call_background_job_model", fake_call_background_job_model, raising=False)

    response = TestClient(main.app).post("/background-job", json=payload)

    assert response.status_code == 200
    raw = response.json()["raw"]
    assert calls["count"] == 0
    assert raw["status"] == "stale"
    assert raw["failure_reason"] == "expired"


def test_background_job_endpoint_falls_back_on_model_failure(monkeypatch):
    async def fake_call_background_job_model(request, settings):
        raise RuntimeError("model down")

    monkeypatch.setattr(main, "call_background_job_model", fake_call_background_job_model, raising=False)

    response = TestClient(main.app).post("/background-job", json=_background_job_payload())

    assert response.status_code == 200
    raw = response.json()["raw"]
    assert raw["status"] == "fallback"
    assert raw["failure_reason"] == "model_failed"
    assert raw["strategy_packet"]["schema"] == "ari.strategy_packet.v1"


def test_background_job_endpoint_caches_same_context(monkeypatch):
    calls = {"count": 0}

    async def fake_call_background_job_model(request, settings):
        calls["count"] += 1
        return {
            "schema": "ari.background_result.v1",
            "job_id": request.job_id,
            "kind": request.kind,
            "context_hash": request.context_hash,
            "status": "ok",
            "notes": ["cached strategy"],
            "strategy_packet": {"schema": "ari.strategy_packet.v1", "try_next": ["build_storm_rod"]},
            "confidence": 0.7,
        }

    monkeypatch.setattr(main, "call_background_job_model", fake_call_background_job_model, raising=False)
    client = TestClient(main.app)

    first = client.post("/background-job", json=_background_job_payload())
    second = client.post("/background-job", json=_background_job_payload())

    assert first.status_code == 200
    assert second.status_code == 200
    assert calls["count"] == 1
    assert second.json()["raw"]["source"] == "cache"


def test_background_job_skips_model_when_foreground_pending(monkeypatch):
    calls = {"count": 0}

    async def fake_call_background_job_model(request, settings):
        calls["count"] += 1
        raise AssertionError("background should not start while foreground is pending")

    monkeypatch.setattr(main, "call_background_job_model", fake_call_background_job_model, raising=False)
    monkeypatch.setattr(main, "_FOREGROUND_PENDING", 1, raising=False)

    response = TestClient(main.app).post("/background-job", json=_background_job_payload())

    assert response.status_code == 200
    raw = response.json()["raw"]
    assert calls["count"] == 0
    assert raw["status"] == "fallback"
    assert raw["failure_reason"] == "foreground_busy"
    monkeypatch.setattr(main, "_FOREGROUND_PENDING", 0, raising=False)


def test_startup_warmup_runs_prediction_planner_and_background(monkeypatch):
    calls = []

    async def fake_prediction(request, settings):
        calls.append(("prediction", request.context_hash))
        return {"r": "none", "a": "wait_or_idle", "u": 0.2, "why": "warm", "h": {}, "avoid": [], "c": 0.4}

    async def fake_plan(request, settings):
        calls.append(("planner", request.decision_kind, settings.planner_request_timeout_seconds))
        return {
            "g": "warm planner",
            "theory": "Warm the planner schema before gameplay.",
            "plan": ["use_cover"],
            "next": "use_cover",
            "fb": "flee",
            "why": "Planner warmup should pay cold-start cost.",
            "belief": {},
            "thought": "I warm the planning lane before danger.",
            "c": 0.4,
            "after": 8,
        }

    async def fake_background(request, settings):
        calls.append(("background", request.kind, settings.background_request_timeout_seconds))
        return {"s": "ok", "n": ["warm"], "h": {}, "try": [], "avoid": [], "c": 0.4}

    monkeypatch.setattr(main, "call_prediction_model", fake_prediction, raising=False)
    monkeypatch.setattr(main, "call_plan_model", fake_plan, raising=False)
    monkeypatch.setattr(main, "call_background_job_model", fake_background, raising=False)

    asyncio.run(main._warmup_prediction_model(Settings(model_backend="ollama")))

    assert calls == [
        ("prediction", "startup_warmup"),
        ("planner", "startup_planner_warmup", 8.0),
        ("background", "strategy_candidate", 8.0),
    ]


def test_startup_planner_warmup_does_not_abort_when_prediction_probe_is_pending(monkeypatch):
    calls = []

    async def fake_prediction(request, settings):
        calls.append(("prediction", request.context_hash))
        return {"r": "none", "a": "wait_or_idle", "u": 0.2, "why": "warm", "h": {}, "avoid": [], "c": 0.4}

    async def fake_plan(request, settings):
        calls.append(("planner", request.decision_kind))
        return {
            "g": "warm planner",
            "theory": "Warm the planner even if a health probe hit prediction.",
            "plan": ["use_cover"],
            "next": "use_cover",
            "fb": "flee",
            "why": "Startup warmup should not abort permanently.",
            "belief": {},
            "thought": "The planner can still warm after prediction.",
            "c": 0.4,
            "after": 8,
        }

    async def fake_background(request, settings):
        calls.append(("background", request.kind))
        return {"s": "ok", "n": ["warm"], "h": {}, "try": [], "avoid": [], "c": 0.4}

    monkeypatch.setattr(main, "call_prediction_model", fake_prediction, raising=False)
    monkeypatch.setattr(main, "call_plan_model", fake_plan, raising=False)
    monkeypatch.setattr(main, "call_background_job_model", fake_background, raising=False)
    monkeypatch.setattr(main, "_PREDICTION_PENDING", 1, raising=False)

    try:
        asyncio.run(main._warmup_prediction_model(Settings(model_backend="ollama")))
    finally:
        monkeypatch.setattr(main, "_PREDICTION_PENDING", 0, raising=False)

    assert ("planner", "startup_planner_warmup") in calls


def test_background_job_endpoint_rejects_unknown_kind():
    payload = _background_job_payload()
    payload["kind"] = "spawn_dragon"

    response = TestClient(main.app).post("/background-job", json=payload)

    assert response.status_code == 422


def test_background_job_prompt_includes_rolling_summary():
    payload = _background_job_payload()
    payload["payload"]["rolling_summary"] = {
        "schema": "ari.rolling_tactical_summary.v1",
        "risk_level": "high",
        "threats": ["flying"],
        "plan_mismatches": ["Ari kept mining while flying danger approached."],
        "resource_blockers": ["low_stone"],
        "priority_hints": {"build_storm_rod": 0.8},
    }

    prompt = background_job_user_prompt(BackgroundJobRequest(**payload))

    assert "Rolling summary:" in prompt
    assert "flying" in prompt
    assert "low_stone" in prompt
    assert "Ari kept mining" in prompt
    assert '"s"' in prompt
    assert '"h"' in prompt
    assert '"short"' not in prompt
    assert len(prompt) < 900


def _background_job_payload():
    return {
        "schema": "ari.background_job.v1",
        "job_id": "job-1",
        "kind": "strategy_candidate",
        "priority": "normal",
        "context_hash": "ctx-current",
        "expires_at_game_time": 40.0,
        "current_game_time": 22.0,
        "payload": {
            "strategy_packet": {
                "schema": "ari.strategy_packet.v1",
                "main_risks": ["flying"],
                "current_lessons": ["wings need sky answers"],
                "priority_hints": {"build_storm_rod": 0.7},
                "try_next": ["build_storm_rod"],
            },
            "day_summary": {
                "schema": "ari.day_summary.v1",
                "candidate_lessons": ["when wings appear, answer the sky first"],
            },
        },
    }
