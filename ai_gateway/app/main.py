from __future__ import annotations

import asyncio
import logging
import os
import secrets
from contextlib import asynccontextmanager
from dataclasses import replace
from typing import Annotated

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException

from .model_client import (
    Settings,
    call_background_job_model,
    call_deep_model,
    call_fast_model,
    call_library_reflection_model,
    call_plan_model,
    call_prediction_model,
    call_scribe_model,
    settings_from_env,
)
from .schemas import (
    AgentPlanRequest,
    AgentPlanResponse,
    BackgroundJobRequest,
    BridgePayloadRequest,
    BridgeRawResponse,
    DeepInterpretationRequest,
    FastThoughtRequest,
    PredictionRequest,
    PredictionResponse,
    fallback_agent_plan_response,
    fallback_background_job_response,
    deterministic_scribe_response,
    fallback_library_reflection_response,
    fallback_scribe_response,
    DeepInterpretationResponse,
    FastThoughtResponse,
    fallback_deep_response,
    fallback_fast_thought,
    fallback_prediction_response,
    sanitize_agent_plan_response,
    sanitize_background_job_response,
    sanitize_deep_response,
    sanitize_library_reflection_response,
    sanitize_prediction_response,
    sanitize_scribe_response,
)

load_dotenv()
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))
logger = logging.getLogger("ari_ai_gateway")

BACKGROUND_JOB_CACHE_MAX = 64
FOREGROUND_PRIORITY_DELAY_SECONDS = float(os.getenv("FOREGROUND_PRIORITY_DELAY_SECONDS", "0.18"))
_BACKGROUND_JOB_CACHE: dict[str, dict] = {}
_BACKGROUND_JOB_CACHE_ORDER: list[str] = []
_AI_GENERATION_LOCK: asyncio.Lock | None = None
_AI_GENERATION_LOCK_LOOP: asyncio.AbstractEventLoop | None = None
_PREDICTION_GENERATION_LOCK: asyncio.Lock | None = None
_PREDICTION_GENERATION_LOCK_LOOP: asyncio.AbstractEventLoop | None = None
_FOREGROUND_PENDING = 0
_PREDICTION_PENDING = 0


@asynccontextmanager
async def lifespan(_: FastAPI):
    settings = get_settings()
    if settings.model_backend == "ollama" and settings.enable_startup_warmup:
        asyncio.create_task(_warmup_prediction_model(settings))
    yield


app = FastAPI(title="AI Survival Trainer Inference Gateway", version="0.2.0", lifespan=lifespan)


async def _warmup_prediction_model(settings: Settings) -> None:
    try:
        request = PredictionRequest(
            context_hash="startup_warmup",
            phase="night",
            time_left=10.0,
            ari={"hp": 100, "current_action": "wait_or_idle"},
            risks=[],
            legal_actions=[
                {"id": "wait_or_idle", "available": True},
                {"id": "flee", "available": True},
            ],
            action_control_panel={
                "schema": "ari.action_control_panel.v1",
                "actions": [
                    {"id": "wait_or_idle", "available": True, "category": "survival", "description": "Keep Ari safe while no urgent action is needed."},
                    {"id": "flee", "available": True, "category": "movement", "description": "Move away from immediate danger."},
                ],
            },
        )
        await _run_prediction_generation(lambda: call_prediction_model(request, settings))
        logger.info("prediction warmup=success model=%s", settings.prediction_model)
    except Exception:
        logger.exception("prediction warmup=failed")
    try:
        request = AgentPlanRequest(
            decision_kind="startup_planner_warmup",
            objective={"primary": "warm_planner_lane"},
            sign={"text": "survive with cover until the plan is clear", "interpretation": "safe startup planning"},
            ari={"hp_ratio": 1.0, "fear": 0.1, "hunger": 0.1, "stamina": 1.0, "current_job": "wait_or_idle"},
            world={"day": 1, "phase": "day", "time_left": 30.0, "stone": 0, "food": 1, "enemy_count": 0},
            strategy_packet={
                "schema": "ari.strategy_packet.v1",
                "main_risks": [],
                "current_lessons": [],
                "priority_hints": {},
                "avoid_repeating": [],
                "try_next": ["use_cover"],
                "evidence": ["startup warmup"],
                "confidence": 0.25,
            },
            action_control_panel={
                "schema": "ari.action_control_panel.v1",
                "actions": [
                    {"id": "use_cover", "available": True, "category": "survival", "description": "Use current cover and distance."},
                    {"id": "flee", "available": True, "category": "movement", "description": "Move away from danger."},
                ],
            },
            legal_actions=[
                {"id": "use_cover", "available": True, "description": "Use current cover and distance."},
                {"id": "flee", "available": True, "description": "Move away from danger."},
            ],
            local_fallback={
                "goal": "warm planner lane",
                "survival_theory": "Use the safest startup action if the model is cold.",
                "plan": [{"step_id": "warm_cover", "action_id": "use_cover", "reason": "Warmup cover is legal.", "success": "warm"}],
                "next_action": {"action_id": "use_cover", "urgency": 0.3, "reason": "Warmup cover is legal."},
                "fallback_action": {"action_id": "flee", "urgency": 0.2, "reason": "Fallback movement is legal."},
                "thought": "Warm the planning lane before danger.",
                "confidence": 0.3,
            },
        )
        warm_settings = replace(
            settings,
            planner_request_timeout_seconds=max(8.0, settings.planner_request_timeout_seconds),
        )
        await _run_foreground_generation(lambda: call_plan_model(request, warm_settings))
        logger.info("planner warmup=success model=%s", settings.planner_model)
    except Exception:
        logger.exception("planner warmup=failed")
    try:
        job = BackgroundJobRequest(
            job_id="startup_background_warmup",
            kind="strategy_candidate",
            priority="low",
            context_hash="startup_background_warmup",
            payload={
                "rolling_summary": {
                    "risk_level": "none",
                    "threats": [],
                    "plan_mismatches": [],
                    "resource_blockers": [],
                    "priority_hints": {},
                },
                "strategy_packet": {
                    "schema": "ari.strategy_packet.v1",
                    "day": 0,
                    "main_risks": [],
                    "current_lessons": [],
                    "priority_hints": {},
                    "avoid_repeating": [],
                    "try_next": ["wait_or_idle"],
                    "evidence": ["startup warmup"],
                    "confidence": 0.25,
                },
            },
        )
        warm_settings = replace(
            settings,
            background_request_timeout_seconds=max(8.0, settings.background_request_timeout_seconds),
        )
        await _run_background_generation(lambda: call_background_job_model(job, warm_settings))
        logger.info("background warmup=success model=%s", settings.background_model)
    except Exception:
        logger.exception("background warmup=failed")


def _generation_lock() -> asyncio.Lock:
    global _AI_GENERATION_LOCK, _AI_GENERATION_LOCK_LOOP
    loop = asyncio.get_running_loop()
    if _AI_GENERATION_LOCK is None or _AI_GENERATION_LOCK_LOOP is not loop:
        _AI_GENERATION_LOCK = asyncio.Lock()
        _AI_GENERATION_LOCK_LOOP = loop
    return _AI_GENERATION_LOCK


def _prediction_generation_lock() -> asyncio.Lock:
    global _PREDICTION_GENERATION_LOCK, _PREDICTION_GENERATION_LOCK_LOOP
    loop = asyncio.get_running_loop()
    if _PREDICTION_GENERATION_LOCK is None or _PREDICTION_GENERATION_LOCK_LOOP is not loop:
        _PREDICTION_GENERATION_LOCK = asyncio.Lock()
        _PREDICTION_GENERATION_LOCK_LOOP = loop
    return _PREDICTION_GENERATION_LOCK


async def _run_foreground_generation(call):
    global _FOREGROUND_PENDING
    _FOREGROUND_PENDING += 1
    try:
        async with _generation_lock():
            return await call()
    finally:
        _FOREGROUND_PENDING = max(0, _FOREGROUND_PENDING - 1)


async def _run_prediction_generation(call):
    global _PREDICTION_PENDING
    foreground_lock = _generation_lock()
    if _FOREGROUND_PENDING > 0 or foreground_lock.locked():
        raise RuntimeError("foreground_busy")
    _PREDICTION_PENDING += 1
    try:
        if _FOREGROUND_PENDING > 0 or foreground_lock.locked():
            raise RuntimeError("foreground_busy")
        async with _prediction_generation_lock():
            if _FOREGROUND_PENDING > 0 or foreground_lock.locked():
                raise RuntimeError("foreground_busy")
            return await call()
    finally:
        _PREDICTION_PENDING = max(0, _PREDICTION_PENDING - 1)


async def _run_yielding_foreground_generation(call):
    global _FOREGROUND_PENDING
    _FOREGROUND_PENDING += 1
    try:
        if FOREGROUND_PRIORITY_DELAY_SECONDS > 0.0:
            await asyncio.sleep(FOREGROUND_PRIORITY_DELAY_SECONDS)
        async with _generation_lock():
            return await call()
    finally:
        _FOREGROUND_PENDING = max(0, _FOREGROUND_PENDING - 1)


async def _run_background_generation(call):
    lock = _generation_lock()
    if _FOREGROUND_PENDING > 0 or lock.locked():
        raise RuntimeError("foreground_busy")
    async with lock:
        if _FOREGROUND_PENDING > 0:
            raise RuntimeError("foreground_busy")
        return await call()


def get_settings() -> Settings:
    return settings_from_env()


def require_api_key(
    settings: Annotated[Settings, Depends(get_settings)],
    x_api_key: Annotated[str | None, Header(alias="X-API-Key")] = None,
) -> None:
    if not settings.game_api_key:
        return
    if not x_api_key or not secrets.compare_digest(x_api_key, settings.game_api_key):
        raise HTTPException(status_code=401, detail="Invalid API key.")


@app.get("/health")
async def health(_: Annotated[None, Depends(require_api_key)], settings: Annotated[Settings, Depends(get_settings)]) -> dict[str, str]:
    return {
        "status": "ok",
        "model_backend": settings.model_backend,
        "fast_model": settings.fast_model,
        "deep_model": settings.deep_model,
        "planner_model": settings.planner_model,
        "scribe_model": settings.scribe_model,
        "reflection_model": settings.reflection_model,
        "background_model": settings.background_model,
        "prediction_model": settings.prediction_model,
        "request_timeout_seconds": str(settings.request_timeout_seconds),
        "deep_request_timeout_seconds": str(settings.deep_request_timeout_seconds),
        "planner_request_timeout_seconds": str(settings.planner_request_timeout_seconds),
        "scribe_request_timeout_seconds": str(settings.scribe_request_timeout_seconds),
        "reflection_request_timeout_seconds": str(settings.reflection_request_timeout_seconds),
        "background_request_timeout_seconds": str(settings.background_request_timeout_seconds),
        "prediction_request_timeout_seconds": str(settings.prediction_request_timeout_seconds),
        "deep_mode": settings.deep_mode,
        "scribe_mode": settings.scribe_mode,
    }


@app.post("/ai/deep-interpretation", response_model=DeepInterpretationResponse)
async def deep_interpretation(
    request: DeepInterpretationRequest,
    _: Annotated[None, Depends(require_api_key)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict:
    fallback = fallback_deep_response(request.local_fallback, request.current_affordances)
    if settings.deep_mode == "deterministic":
        return fallback
    try:
        model_result = await _run_yielding_foreground_generation(lambda: call_deep_model(request, settings))
        allowed_ids = {item.id for item in request.current_affordances} or None
        return sanitize_deep_response(model_result, fallback, allowed_ids)
    except Exception:
        return fallback


@app.post("/ai/fast-thought", response_model=FastThoughtResponse)
async def fast_thought(
    request: FastThoughtRequest,
    _: Annotated[None, Depends(require_api_key)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict:
    fallback = fallback_fast_thought(request)
    try:
        model_result = await _run_yielding_foreground_generation(lambda: call_fast_model(request, settings))
        return {
            "thought": str(model_result.get("thought", fallback["thought"]))[:160],
            "resonance": max(0.0, min(1.0, float(model_result.get("resonance", fallback["resonance"])))),
        }
    except Exception:
        return fallback


@app.post("/ari/plan-v1", response_model=AgentPlanResponse)
async def agent_plan(
    request: AgentPlanRequest,
    _: Annotated[None, Depends(require_api_key)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict:
    fallback = fallback_agent_plan_response(request.local_fallback, request.legal_actions)
    try:
        route_timeout = max(0.05, settings.planner_request_timeout_seconds - 0.35)
        model_result = await asyncio.wait_for(
            _run_yielding_foreground_generation(lambda: call_plan_model(request, settings)),
            timeout=route_timeout,
        )
        return sanitize_agent_plan_response(model_result, fallback, request.legal_actions, request)
    except asyncio.TimeoutError:
        return fallback_agent_plan_response(request.local_fallback, request.legal_actions, "model_timeout")
    except Exception as exc:
        failure_reason = "prediction_pending" if str(exc) == "prediction_pending" else "model_failed"
        return fallback_agent_plan_response(request.local_fallback, request.legal_actions, failure_reason)


@app.post("/ari/predict-v1", response_model=PredictionResponse)
async def fast_prediction(
    request: PredictionRequest,
    _: Annotated[None, Depends(require_api_key)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict:
    fallback = fallback_prediction_response(request)
    try:
        model_result = await _run_prediction_generation(lambda: call_prediction_model(request, settings))
        return sanitize_prediction_response(model_result, fallback, request)
    except Exception as exc:
        failure_reason = "foreground_busy" if str(exc) == "foreground_busy" else "model_failed"
        return fallback_prediction_response(request, failure_reason)


@app.post("/scribe", response_model=BridgeRawResponse)
async def scribe(
    request: BridgePayloadRequest,
    _: Annotated[None, Depends(require_api_key)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict:
    fallback = fallback_scribe_response(request.payload)
    if settings.scribe_mode == "deterministic":
        return {"raw": deterministic_scribe_response(request.payload)}
    try:
        model_result = await _run_background_generation(lambda: call_scribe_model(request, settings))
        return {"raw": sanitize_scribe_response(model_result, fallback)}
    except Exception:
        return {"raw": fallback_scribe_response(request.payload, "model_failed")}


@app.post("/library-reflection", response_model=BridgeRawResponse)
async def library_reflection(
    request: BridgePayloadRequest,
    _: Annotated[None, Depends(require_api_key)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict:
    fallback = fallback_library_reflection_response(request.payload)
    try:
        model_result = await _run_yielding_foreground_generation(lambda: call_library_reflection_model(request, settings))
        return {"raw": sanitize_library_reflection_response(model_result, fallback)}
    except Exception:
        return {"raw": fallback_library_reflection_response(request.payload, "model_failed")}


@app.post("/background-job", response_model=BridgeRawResponse)
async def background_job(
    request: BackgroundJobRequest,
    _: Annotated[None, Depends(require_api_key)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict:
    if request.expires_at_game_time > 0.0 and request.current_game_time > request.expires_at_game_time:
        return {"raw": fallback_background_job_response(request, "expired", "stale")}
    fallback = fallback_background_job_response(request)
    cached = _background_job_cache_get(request)
    if cached is not None:
        raw = sanitize_background_job_response(cached, fallback, request)
        raw["source"] = "cache"
        return {"raw": raw}
    try:
        model_result = await _run_background_generation(lambda: call_background_job_model(request, settings))
        raw = sanitize_background_job_response(model_result, fallback, request)
        if raw.get("status") == "ok":
            _background_job_cache_put(request, raw)
        return {"raw": raw}
    except Exception as exc:
        if str(exc) == "foreground_busy":
            return {"raw": fallback_background_job_response(request, "foreground_busy")}
        return {"raw": fallback_background_job_response(request, "model_failed")}


def _background_job_cache_key(request: BackgroundJobRequest) -> str:
    if not request.context_hash:
        return ""
    return f"{request.kind}:{request.context_hash}"


def _background_job_cache_get(request: BackgroundJobRequest) -> dict | None:
    key = _background_job_cache_key(request)
    if not key or key not in _BACKGROUND_JOB_CACHE:
        return None
    return dict(_BACKGROUND_JOB_CACHE[key])


def _background_job_cache_put(request: BackgroundJobRequest, raw: dict) -> None:
    key = _background_job_cache_key(request)
    if not key:
        return
    if key not in _BACKGROUND_JOB_CACHE_ORDER:
        _BACKGROUND_JOB_CACHE_ORDER.append(key)
    _BACKGROUND_JOB_CACHE[key] = dict(raw)
    while len(_BACKGROUND_JOB_CACHE_ORDER) > BACKGROUND_JOB_CACHE_MAX:
        oldest = _BACKGROUND_JOB_CACHE_ORDER.pop(0)
        _BACKGROUND_JOB_CACHE.pop(oldest, None)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", "8088")))
