import asyncio
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import main
from app.model_client import Settings
from app.schemas import AgentPlanRequest, PredictionRequest


def test_live_prediction_preempts_planner_that_arrived_first(monkeypatch):
    async def fake_call_plan_model(_request, _settings):
        await asyncio.sleep(0.20)
        return {
            "g": "slow plan",
            "theory": "Slow planning should not block live prediction.",
            "plan": ["build_tower"],
            "next": "build_tower",
            "fb": "use_cover",
            "why": "The planner arrived first.",
            "c": 0.7,
            "after": 8,
        }

    async def fake_call_prediction_model(request, _settings):
        await asyncio.sleep(0.08)
        return {
            "r": "high",
            "a": "build_storm_rod",
            "u": 0.9,
            "why": "Live flying danger needs a sky answer now.",
            "h": {"build_storm_rod": 0.9},
            "c": 0.8,
            "ctx": request.context_hash,
        }

    _reset_scheduler_state()
    monkeypatch.setattr(main, "FOREGROUND_PRIORITY_DELAY_SECONDS", 0.05, raising=False)
    monkeypatch.setattr(main, "call_plan_model", fake_call_plan_model, raising=False)
    monkeypatch.setattr(main, "call_prediction_model", fake_call_prediction_model, raising=False)

    async def run_probe():
        settings = Settings()
        plan_task = asyncio.create_task(main.agent_plan(AgentPlanRequest(**_plan_payload()), None, settings))
        await asyncio.sleep(0.01)
        start = time.perf_counter()
        prediction = await main.fast_prediction(PredictionRequest(**_prediction_payload()), None, settings)
        elapsed = time.perf_counter() - start
        plan = await plan_task
        return prediction, elapsed, plan

    try:
        prediction, elapsed, plan = asyncio.run(run_probe())
    finally:
        _reset_scheduler_state()

    assert elapsed < 0.15
    assert prediction["source"] == "remote_server"
    assert prediction["next_action_bias"]["action_id"] == "build_storm_rod"
    assert plan["source"] == "local_fallback"
    assert plan["failure_reason"] == "prediction_pending"


def test_live_prediction_does_not_wait_for_background_already_running(monkeypatch):
    async def fake_call_background_job_model(_request, _settings):
        await asyncio.sleep(0.20)
        return {"s": "ok", "n": ["background finished late"], "h": {}, "try": [], "avoid": [], "c": 0.4}

    async def fake_call_prediction_model(request, _settings):
        await asyncio.sleep(0.02)
        return {
            "r": "high",
            "a": "build_storm_rod",
            "u": 0.9,
            "h": {"build_storm_rod": 0.9},
            "c": 0.8,
            "ctx": request.context_hash,
        }

    _reset_scheduler_state()
    monkeypatch.setattr(main, "call_background_job_model", fake_call_background_job_model, raising=False)
    monkeypatch.setattr(main, "call_prediction_model", fake_call_prediction_model, raising=False)

    async def run_probe():
        settings = Settings()
        background_task = asyncio.create_task(main.background_job(main.BackgroundJobRequest(**_background_payload()), None, settings))
        await asyncio.sleep(0.01)
        start = time.perf_counter()
        prediction = await main.fast_prediction(PredictionRequest(**_prediction_payload()), None, settings)
        elapsed = time.perf_counter() - start
        background = await background_task
        return prediction, elapsed, background

    try:
        prediction, elapsed, background = asyncio.run(run_probe())
    finally:
        _reset_scheduler_state()

    assert elapsed < 0.08
    assert prediction["source"] == "remote_server"
    assert prediction["next_action_bias"]["action_id"] == "build_storm_rod"
    assert background["raw"]["status"] == "ok"


def test_live_prediction_does_not_wait_for_planner_already_running(monkeypatch):
    async def fake_call_plan_model(_request, _settings):
        await asyncio.sleep(0.20)
        return {
            "g": "slow plan",
            "theory": "Slow planning should not block live prediction.",
            "plan": ["build_tower"],
            "next": "build_tower",
            "fb": "use_cover",
            "why": "The planner was already running.",
            "belief": {},
            "thought": "I will think later.",
            "c": 0.7,
            "after": 8,
        }

    async def fake_call_prediction_model(request, _settings):
        await asyncio.sleep(0.02)
        return {
            "r": "high",
            "a": "build_storm_rod",
            "u": 0.9,
            "h": {"build_storm_rod": 0.9},
            "c": 0.8,
            "ctx": request.context_hash,
        }

    _reset_scheduler_state()
    monkeypatch.setattr(main, "FOREGROUND_PRIORITY_DELAY_SECONDS", 0.0, raising=False)
    monkeypatch.setattr(main, "call_plan_model", fake_call_plan_model, raising=False)
    monkeypatch.setattr(main, "call_prediction_model", fake_call_prediction_model, raising=False)

    async def run_probe():
        settings = Settings()
        plan_task = asyncio.create_task(main.agent_plan(AgentPlanRequest(**_plan_payload()), None, settings))
        await asyncio.sleep(0.01)
        start = time.perf_counter()
        prediction = await main.fast_prediction(PredictionRequest(**_prediction_payload()), None, settings)
        elapsed = time.perf_counter() - start
        plan = await plan_task
        return prediction, elapsed, plan

    try:
        prediction, elapsed, plan = asyncio.run(run_probe())
    finally:
        _reset_scheduler_state()

    assert elapsed < 0.08
    assert prediction["source"] == "remote_server"
    assert prediction["next_action_bias"]["action_id"] == "build_storm_rod"
    assert plan["source"] == "remote_server"


def test_agent_plan_returns_fallback_before_model_budget_expires(monkeypatch):
    async def fake_call_plan_model(_request, _settings):
        await asyncio.sleep(0.20)
        return {
            "g": "late plan",
            "theory": "This should arrive too late for live gameplay.",
            "plan": ["build_tower"],
            "next": "build_tower",
            "fb": "use_cover",
            "why": "Late planner.",
            "belief": {},
            "thought": "Too late.",
            "c": 0.7,
            "after": 8,
        }

    _reset_scheduler_state()
    monkeypatch.setattr(main, "FOREGROUND_PRIORITY_DELAY_SECONDS", 0.0, raising=False)
    monkeypatch.setattr(main, "call_plan_model", fake_call_plan_model, raising=False)

    async def run_probe():
        start = time.perf_counter()
        plan = await main.agent_plan(
            AgentPlanRequest(**_plan_payload()),
            None,
            Settings(planner_request_timeout_seconds=0.08),
        )
        return plan, time.perf_counter() - start

    try:
        plan, elapsed = asyncio.run(run_probe())
    finally:
        _reset_scheduler_state()

    assert elapsed < 0.16
    assert plan["source"] == "local_fallback"
    assert plan["failure_reason"] == "model_timeout"


def _reset_scheduler_state():
    main._AI_GENERATION_LOCK = None
    main._AI_GENERATION_LOCK_LOOP = None
    if hasattr(main, "_PREDICTION_GENERATION_LOCK"):
        main._PREDICTION_GENERATION_LOCK = None
    if hasattr(main, "_PREDICTION_GENERATION_LOCK_LOOP"):
        main._PREDICTION_GENERATION_LOCK_LOOP = None
    main._FOREGROUND_PENDING = 0
    if hasattr(main, "_PREDICTION_PENDING"):
        main._PREDICTION_PENDING = 0


def _plan_payload():
    return {
        "schema": "ari.agent.plan.v1",
        "decision_kind": "dusk_plan",
        "objective": {"primary": "survive_next_night"},
        "sign": {"text": "build a mountain where arrows rain"},
        "ari": {"hp_ratio": 0.8, "current_job": "wait_or_idle"},
        "world": {"day": 2, "phase": "dusk", "stone": 12, "bow_tower_count": 0},
        "legal_actions": [
            {"id": "build_tower", "available": True, "description": "Build tower."},
            {"id": "use_cover", "available": True, "description": "Use cover."},
        ],
        "local_fallback": {
            "goal": "local survival",
            "survival_theory": "Fallback should keep Ari moving.",
            "plan": [{"step_id": "fallback_cover", "action_id": "use_cover", "reason": "Use cover.", "success": "safe"}],
            "next_action": {"action_id": "use_cover", "urgency": 0.5},
            "fallback_action": {"action_id": "use_cover", "urgency": 0.4},
            "confidence": 0.4,
        },
    }


def _prediction_payload():
    return {
        "schema": "ari.prediction.request.v1",
        "context_hash": "ctx-live-first",
        "day": 2,
        "phase": "night",
        "time_left": 30,
        "ari": {"hp": 70, "current_action": "build_wall"},
        "risks": [{"type": "flying", "distance": 80, "severity": 0.9}],
        "resources": {"stone": 18},
        "current_plan": {"next_action": "build_wall"},
        "strategy_packet": {"schema": "ari.strategy_packet.v1", "priority_hints": {"build_storm_rod": 0.6}},
        "legal_actions": [
            {"id": "build_wall", "available": True},
            {"id": "build_storm_rod", "available": True},
            {"id": "use_cover", "available": True},
        ],
    }


def _background_payload():
    return {
        "schema": "ari.background_job.v1",
        "job_id": "bg-running",
        "kind": "strategy_candidate",
        "priority": "low",
        "context_hash": "ctx-bg-running",
        "payload": {
            "rolling_summary": {
                "risk_level": "high",
                "threats": ["flying"],
                "priority_hints": {"build_storm_rod": 0.7},
            },
            "strategy_packet": {
                "schema": "ari.strategy_packet.v1",
                "main_risks": ["flying"],
                "priority_hints": {"build_storm_rod": 0.7},
                "try_next": ["build_storm_rod"],
                "confidence": 0.4,
            },
        },
    }
