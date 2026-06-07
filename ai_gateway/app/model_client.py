from __future__ import annotations

import json
import logging
import os
import time
from dataclasses import dataclass
from typing import Any

import httpx

from .prompting import (
    AGENT_PLAN_SYSTEM_PROMPT,
    BACKGROUND_JOB_SYSTEM_PROMPT,
    DEEP_SYSTEM_PROMPT,
    FAST_SYSTEM_PROMPT,
    LIBRARY_REFLECTION_SYSTEM_PROMPT,
    PREDICTION_SYSTEM_PROMPT,
    SCRIBE_SYSTEM_PROMPT,
    agent_plan_user_prompt,
    background_job_user_prompt,
    deep_user_prompt,
    fast_user_prompt,
    library_reflection_user_prompt,
    prediction_user_prompt,
    scribe_user_prompt,
)
from .schemas import (
    AgentPlanRequest,
    AgentPlanResponse,
    BackgroundJobRequest,
    BridgePayloadRequest,
    DeepInterpretationRequest,
    DeepInterpretationResponse,
    FastThoughtRequest,
    FastThoughtResponse,
    PredictionRequest,
    PredictionResponse,
)

logger = logging.getLogger("ari_ai_gateway")

PREDICTION_COMPACT_RESPONSE_SCHEMA: dict[str, Any] = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "r": {"type": "string"},
        "a": {"type": "string"},
        "u": {"type": "number"},
        "h": {"type": "object"},
        "c": {"type": "number"},
    },
    "required": ["r", "a", "u", "h", "c"],
}

BACKGROUND_COMPACT_RESPONSE_SCHEMA: dict[str, Any] = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "s": {"type": "string"},
        "n": {"type": "array", "items": {"type": "string"}},
        "h": {"type": "object"},
        "try": {"type": "array", "items": {"type": "string"}},
        "avoid": {"type": "array", "items": {"type": "string"}},
        "c": {"type": "number"},
    },
    "required": ["s", "n", "h", "try", "avoid", "c"],
}

AGENT_PLAN_COMPACT_RESPONSE_SCHEMA: dict[str, Any] = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "g": {"type": "string"},
        "theory": {"type": "string"},
        "plan": {"type": "array", "items": {"type": "string"}},
        "next": {"type": "string"},
        "fb": {"type": "string"},
        "why": {"type": "string"},
        "belief": {"type": "object"},
        "thought": {"type": "string"},
        "c": {"type": "number"},
        "after": {"type": "number"},
    },
    "required": ["g", "theory", "plan", "next", "fb", "why", "belief", "thought", "c", "after"],
}

LIBRARY_REFLECTION_COMPACT_RESPONSE_SCHEMA: dict[str, Any] = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "t": {"type": "string"},
        "m": {"type": "string"},
        "chg": {"type": "array", "items": {"type": "string"}},
        "ok": {"type": "array", "items": {"type": "string"}},
        "bad": {"type": "array", "items": {"type": "string"}},
        "mis": {"type": "array", "items": {"type": "string"}},
        "lesson": {"type": "string"},
        "h": {"type": "object"},
        "bias": {"type": "object"},
        "belief": {"type": "object"},
        "plan": {"type": "array", "items": {"type": "string"}},
        "thought": {"type": "string"},
        "c": {"type": "number"},
    },
    "required": ["t", "m", "chg", "ok", "bad", "mis", "lesson", "h", "bias", "belief", "plan", "thought", "c"],
}


@dataclass(frozen=True)
class Settings:
    game_api_key: str = ""
    model_backend: str = "openai"
    model_base_url: str = "https://api.openai.com/v1"
    model_api_key: str = ""
    fast_model: str = "gpt-5.4-nano"
    deep_model: str = "gpt-5.4-mini"
    planner_model: str = "gpt-5.4-mini"
    scribe_model: str = "gpt-5.4-nano"
    reflection_model: str = "gpt-5.4-mini"
    background_model: str = "gpt-5.4-nano"
    prediction_model: str = "gpt-5.4-nano"
    request_timeout_seconds: float = 5.0
    deep_request_timeout_seconds: float = 5.0
    planner_request_timeout_seconds: float = 5.0
    scribe_request_timeout_seconds: float = 4.0
    reflection_request_timeout_seconds: float = 12.0
    background_request_timeout_seconds: float = 4.0
    prediction_request_timeout_seconds: float = 5.0
    model_temperature: float = 0.0
    deep_mode: str = "model"
    deep_max_tokens: int = 300
    fast_max_tokens: int = 80
    planner_max_tokens: int = 360
    scribe_max_tokens: int = 140
    reflection_max_tokens: int = 520
    background_max_tokens: int = 120
    prediction_max_tokens: int = 96
    scribe_mode: str = "model"
    ollama_json_format: bool = True
    openai_json_format: bool = True
    ollama_num_thread: int = 0
    ollama_num_ctx: int = 0
    planner_num_ctx: int = 1024
    reflection_num_ctx: int = 1024
    prediction_num_ctx: int = 512
    ollama_keep_alive: str = "30m"
    enable_startup_warmup: bool = True
    debug_log_signs: bool = False


def settings_from_env() -> Settings:
    backend = os.getenv("MODEL_BACKEND", "openai").lower()
    model_name = os.getenv("MODEL_NAME", "")
    default_base_url = "http://127.0.0.1:11434" if backend == "ollama" else "https://api.openai.com/v1"
    default_ollama_model = "hf.co/Qwen/Qwen3-1.7B-GGUF:Q8_0"
    default_ollama_fast_model = "qwen3:0.6b"
    default_ollama_prediction_model = "smollm2:135m"
    default_fast_model = default_ollama_fast_model if backend == "ollama" else "gpt-5.4-nano"
    default_deep_model = default_ollama_model if backend == "ollama" else "gpt-5.4-mini"
    default_planner_model = default_ollama_fast_model if backend == "ollama" else "gpt-5.4-mini"
    default_deep_max_tokens = "360" if backend == "ollama" else "300"
    default_planner_max_tokens = "180" if backend == "ollama" else "360"
    default_reflection_max_tokens = "140" if backend == "ollama" else default_planner_max_tokens
    default_deep_mode = "deterministic" if backend == "ollama" else "model"
    default_scribe_mode = "deterministic" if backend == "ollama" else "model"
    fast_model = os.getenv("FAST_MODEL", model_name or default_fast_model)
    deep_model = os.getenv("DEEP_MODEL", model_name or default_deep_model)
    planner_model = os.getenv("PLANNER_MODEL", model_name or default_planner_model)
    reflection_model = os.getenv("REFLECTION_MODEL", planner_model)
    request_timeout_seconds = float(os.getenv("REQUEST_TIMEOUT_SECONDS", "5"))
    return Settings(
        game_api_key=os.getenv("GAME_AI_API_KEY", ""),
        model_backend=backend,
        model_base_url=os.getenv("MODEL_BASE_URL", default_base_url).rstrip("/"),
        model_api_key=os.getenv("MODEL_API_KEY", ""),
        fast_model=fast_model,
        deep_model=deep_model,
        planner_model=planner_model,
        scribe_model=os.getenv("SCRIBE_MODEL", fast_model),
        reflection_model=reflection_model,
        background_model=os.getenv("BACKGROUND_MODEL", fast_model),
        prediction_model=os.getenv("PREDICTION_MODEL", default_ollama_prediction_model if backend == "ollama" else fast_model),
        request_timeout_seconds=request_timeout_seconds,
        deep_request_timeout_seconds=float(os.getenv("DEEP_REQUEST_TIMEOUT_SECONDS", str(request_timeout_seconds))),
        planner_request_timeout_seconds=float(os.getenv("PLANNER_REQUEST_TIMEOUT_SECONDS", str(request_timeout_seconds))),
        scribe_request_timeout_seconds=float(os.getenv("SCRIBE_REQUEST_TIMEOUT_SECONDS", "4")),
        reflection_request_timeout_seconds=float(os.getenv("REFLECTION_REQUEST_TIMEOUT_SECONDS", "12")),
        background_request_timeout_seconds=float(os.getenv("BACKGROUND_REQUEST_TIMEOUT_SECONDS", "4")),
        prediction_request_timeout_seconds=float(os.getenv("PREDICTION_REQUEST_TIMEOUT_SECONDS", str(request_timeout_seconds))),
        model_temperature=float(os.getenv("MODEL_TEMPERATURE", "0.0")),
        deep_mode=_normalize_mode(os.getenv("DEEP_MODE", default_deep_mode), {"deterministic", "model"}),
        deep_max_tokens=int(os.getenv("DEEP_MAX_TOKENS", default_deep_max_tokens)),
        fast_max_tokens=int(os.getenv("FAST_MAX_TOKENS", "80")),
        planner_max_tokens=int(os.getenv("PLANNER_MAX_TOKENS", default_planner_max_tokens)),
        scribe_max_tokens=int(os.getenv("SCRIBE_MAX_TOKENS", "140")),
        reflection_max_tokens=int(os.getenv("REFLECTION_MAX_TOKENS", default_reflection_max_tokens)),
        background_max_tokens=int(os.getenv("BACKGROUND_MAX_TOKENS", "120")),
        prediction_max_tokens=int(os.getenv("PREDICTION_MAX_TOKENS", "96")),
        scribe_mode=_normalize_mode(os.getenv("SCRIBE_MODE", default_scribe_mode), {"deterministic", "model"}),
        ollama_json_format=os.getenv("OLLAMA_JSON_FORMAT", "true").lower() == "true",
        openai_json_format=os.getenv("OPENAI_JSON_FORMAT", "true").lower() == "true",
        ollama_num_thread=max(0, int(os.getenv("OLLAMA_NUM_THREAD", "0"))),
        ollama_num_ctx=max(0, int(os.getenv("OLLAMA_NUM_CTX", "0"))),
        planner_num_ctx=max(0, int(os.getenv("PLANNER_NUM_CTX", "1024"))),
        reflection_num_ctx=max(0, int(os.getenv("REFLECTION_NUM_CTX", "1024"))),
        prediction_num_ctx=max(0, int(os.getenv("PREDICTION_NUM_CTX", "512"))),
        ollama_keep_alive=os.getenv("OLLAMA_KEEP_ALIVE", "30m"),
        enable_startup_warmup=os.getenv("ENABLE_STARTUP_WARMUP", "true").lower() == "true",
        debug_log_signs=os.getenv("DEBUG_LOG_SIGNS", "false").lower() == "true",
    )


def _normalize_mode(value: str, allowed: set[str]) -> str:
    normalized = str(value or "").strip().lower().replace("-", "_")
    return normalized if normalized in allowed else sorted(allowed)[0]


async def call_deep_model(request: DeepInterpretationRequest, settings: Settings) -> dict[str, Any]:
    start = time.perf_counter()
    try:
        raw = await _chat_json(
            settings=settings,
            model=settings.deep_model,
            system_prompt=DEEP_SYSTEM_PROMPT,
            user_prompt=deep_user_prompt(request),
            max_tokens=settings.deep_max_tokens,
            response_schema=DeepInterpretationResponse.model_json_schema(),
            timeout_seconds=settings.deep_request_timeout_seconds,
        )
        logger.info("deep_interpretation model=success latency_ms=%d", int((time.perf_counter() - start) * 1000))
        return raw
    except Exception:
        logger.exception("deep_interpretation model=failed latency_ms=%d", int((time.perf_counter() - start) * 1000))
        raise


async def call_fast_model(request: FastThoughtRequest, settings: Settings) -> dict[str, Any]:
    start = time.perf_counter()
    raw = await _chat_json(
        settings=settings,
        model=settings.fast_model,
        system_prompt=FAST_SYSTEM_PROMPT,
        user_prompt=fast_user_prompt(request),
        max_tokens=settings.fast_max_tokens,
        response_schema=FastThoughtResponse.model_json_schema(),
        timeout_seconds=settings.scribe_request_timeout_seconds,
    )
    logger.info("fast_thought model=success latency_ms=%d", int((time.perf_counter() - start) * 1000))
    return raw


async def call_plan_model(request: AgentPlanRequest, settings: Settings) -> dict[str, Any]:
    start = time.perf_counter()
    try:
        raw = await _chat_json(
            settings=settings,
            model=settings.planner_model,
            system_prompt=AGENT_PLAN_SYSTEM_PROMPT,
            user_prompt=agent_plan_user_prompt(request),
            max_tokens=settings.planner_max_tokens,
            response_schema=AGENT_PLAN_COMPACT_RESPONSE_SCHEMA,
            num_ctx=settings.planner_num_ctx,
            timeout_seconds=settings.planner_request_timeout_seconds,
        )
        logger.info("agent_plan model=success latency_ms=%d", int((time.perf_counter() - start) * 1000))
        return raw
    except Exception:
        logger.exception("agent_plan model=failed latency_ms=%d", int((time.perf_counter() - start) * 1000))
        raise


async def call_scribe_model(request: BridgePayloadRequest, settings: Settings) -> dict[str, Any]:
    start = time.perf_counter()
    try:
        raw = await _chat_json(
            settings=settings,
            model=settings.scribe_model,
            system_prompt=SCRIBE_SYSTEM_PROMPT,
            user_prompt=scribe_user_prompt(request),
            max_tokens=settings.scribe_max_tokens,
            response_schema=None,
            timeout_seconds=settings.scribe_request_timeout_seconds,
        )
        logger.info("scribe model=success latency_ms=%d", int((time.perf_counter() - start) * 1000))
        return raw
    except Exception:
        logger.exception("scribe model=failed latency_ms=%d", int((time.perf_counter() - start) * 1000))
        raise


async def call_library_reflection_model(request: BridgePayloadRequest, settings: Settings) -> dict[str, Any]:
    start = time.perf_counter()
    try:
        raw = await _chat_json(
            settings=settings,
            model=settings.reflection_model,
            system_prompt=LIBRARY_REFLECTION_SYSTEM_PROMPT,
            user_prompt=library_reflection_user_prompt(request),
            max_tokens=settings.reflection_max_tokens,
            response_schema=LIBRARY_REFLECTION_COMPACT_RESPONSE_SCHEMA,
            num_ctx=settings.reflection_num_ctx,
            timeout_seconds=settings.reflection_request_timeout_seconds,
        )
        logger.info("library_reflection model=success latency_ms=%d", int((time.perf_counter() - start) * 1000))
        return raw
    except Exception:
        logger.exception("library_reflection model=failed latency_ms=%d", int((time.perf_counter() - start) * 1000))
        raise


async def call_background_job_model(request: BackgroundJobRequest, settings: Settings) -> dict[str, Any]:
    start = time.perf_counter()
    try:
        raw = await _chat_json(
            settings=settings,
            model=settings.background_model,
            system_prompt=BACKGROUND_JOB_SYSTEM_PROMPT,
            user_prompt=background_job_user_prompt(request),
            max_tokens=settings.background_max_tokens,
            response_schema=BACKGROUND_COMPACT_RESPONSE_SCHEMA,
            timeout_seconds=settings.background_request_timeout_seconds,
        )
        logger.info(
            "background_job kind=%s model=success latency_ms=%d",
            request.kind,
            int((time.perf_counter() - start) * 1000),
        )
        return raw
    except Exception:
        logger.exception(
            "background_job kind=%s model=failed latency_ms=%d",
            request.kind,
            int((time.perf_counter() - start) * 1000),
        )
        raise


async def call_prediction_model(request: PredictionRequest, settings: Settings) -> dict[str, Any]:
    start = time.perf_counter()
    try:
        raw = await _chat_json(
            settings=settings,
            model=settings.prediction_model,
            system_prompt=PREDICTION_SYSTEM_PROMPT,
            user_prompt=prediction_user_prompt(request),
            max_tokens=settings.prediction_max_tokens,
            response_schema=PREDICTION_COMPACT_RESPONSE_SCHEMA,
            num_ctx=settings.prediction_num_ctx,
            timeout_seconds=settings.prediction_request_timeout_seconds,
        )
        logger.info("prediction model=success latency_ms=%d", int((time.perf_counter() - start) * 1000))
        return raw
    except Exception:
        logger.exception("prediction model=failed latency_ms=%d", int((time.perf_counter() - start) * 1000))
        raise


async def _chat_json(
    settings: Settings,
    model: str,
    system_prompt: str,
    user_prompt: str,
    max_tokens: int,
    response_schema: dict[str, Any] | None = None,
    num_ctx: int | None = None,
    timeout_seconds: float | None = None,
) -> dict[str, Any]:
    if settings.model_backend == "ollama":
        content = await _ollama_chat(settings, model, system_prompt, user_prompt, max_tokens, response_schema, num_ctx, timeout_seconds)
    elif settings.model_backend == "openai":
        content = await _openai_chat(settings, model, system_prompt, user_prompt, max_tokens, timeout_seconds)
    elif settings.model_backend == "vllm":
        content = await _openai_compatible_chat(settings, model, system_prompt, user_prompt, max_tokens, timeout_seconds)
    else:
        raise ValueError(f"Unsupported MODEL_BACKEND={settings.model_backend}")
    return parse_strict_json_object(content)


async def _ollama_chat(
    settings: Settings,
    model: str,
    system_prompt: str,
    user_prompt: str,
    max_tokens: int,
    response_schema: dict[str, Any] | None = None,
    num_ctx: int | None = None,
    timeout_seconds: float | None = None,
) -> str:
    options = {"temperature": settings.model_temperature, "num_predict": max_tokens}
    effective_num_ctx = num_ctx if num_ctx is not None else settings.ollama_num_ctx
    if effective_num_ctx and effective_num_ctx > 0:
        options["num_ctx"] = effective_num_ctx
    if settings.ollama_num_thread > 0:
        options["num_thread"] = settings.ollama_num_thread
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "stream": False,
        "think": False,
        "options": options,
    }
    if settings.ollama_keep_alive:
        payload["keep_alive"] = settings.ollama_keep_alive
    if settings.ollama_json_format:
        payload["format"] = response_schema if response_schema else "json"
    async with httpx.AsyncClient(timeout=timeout_seconds or settings.request_timeout_seconds) as client:
        response = await client.post(f"{settings.model_base_url}/api/chat", json=payload)
        response.raise_for_status()
        data = response.json()
    return data["message"]["content"]


async def _openai_chat(
    settings: Settings,
    model: str,
    system_prompt: str,
    user_prompt: str,
    max_tokens: int,
    timeout_seconds: float | None = None,
) -> str:
    if not settings.model_api_key:
        raise ValueError("MODEL_API_KEY is required when MODEL_BACKEND=openai.")
    headers = {"Content-Type": "application/json", "Authorization": f"Bearer {settings.model_api_key}"}
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": settings.model_temperature,
        "max_completion_tokens": max_tokens,
    }
    if settings.openai_json_format:
        payload["response_format"] = {"type": "json_object"}
    async with httpx.AsyncClient(timeout=timeout_seconds or settings.request_timeout_seconds) as client:
        response = await client.post(f"{settings.model_base_url}/chat/completions", headers=headers, json=payload)
        response.raise_for_status()
        data = response.json()
    return data["choices"][0]["message"]["content"]


async def _openai_compatible_chat(
    settings: Settings,
    model: str,
    system_prompt: str,
    user_prompt: str,
    max_tokens: int,
    timeout_seconds: float | None = None,
) -> str:
    headers = {"Content-Type": "application/json"}
    if settings.model_api_key:
        headers["Authorization"] = f"Bearer {settings.model_api_key}"
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": settings.model_temperature,
        "max_tokens": max_tokens,
    }
    async with httpx.AsyncClient(timeout=timeout_seconds or settings.request_timeout_seconds) as client:
        response = await client.post(f"{settings.model_base_url}/chat/completions", headers=headers, json=payload)
        response.raise_for_status()
        data = response.json()
    return data["choices"][0]["message"]["content"]


def parse_strict_json_object(text: str) -> dict[str, Any]:
    cleaned = text.strip()
    try:
        return _parse_leading_json_object(cleaned)
    except json.JSONDecodeError:
        repaired = _repair_json_object_keys(cleaned)
        if repaired == cleaned:
            raise
        return _parse_leading_json_object(repaired)


def _parse_leading_json_object(cleaned: str) -> dict[str, Any]:
    decoder = json.JSONDecoder()
    parsed, end = decoder.raw_decode(cleaned)
    if not isinstance(parsed, dict):
        raise ValueError("Model returned non-object JSON.")
    if cleaned[end:].strip():
        logger.warning("Model returned trailing text after leading JSON object; ignoring trailing text.")
    return parsed


def _repair_json_object_keys(cleaned: str) -> str:
    if not cleaned.startswith("{"):
        return cleaned

    repaired: list[str] = []
    index = 0
    in_string = False
    escaped = False
    expecting_key = True

    while index < len(cleaned):
        char = cleaned[index]
        if in_string:
            repaired.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue

        if char == '"':
            repaired.append(char)
            in_string = True
            if expecting_key:
                expecting_key = False
            index += 1
            continue

        if char == "{":
            repaired.append(char)
            expecting_key = True
            index += 1
            continue

        if char == ",":
            next_non_space = _next_non_space(cleaned, index + 1)
            if next_non_space < len(cleaned) and cleaned[next_non_space] in "}":
                index += 1
                continue
            repaired.append(char)
            expecting_key = True
            index += 1
            continue

        if expecting_key and (char.isalpha() or char == "_"):
            end = index + 1
            while end < len(cleaned) and (cleaned[end].isalnum() or cleaned[end] == "_"):
                end += 1
            colon = _next_non_space(cleaned, end)
            if colon < len(cleaned) and cleaned[colon] == ":":
                repaired.append('"')
                repaired.append(cleaned[index:end])
                repaired.append('"')
                index = end
                expecting_key = False
                continue

        if char == ":":
            expecting_key = False
        elif char in "}]":
            expecting_key = False

        repaired.append(char)
        index += 1

    return "".join(repaired)


def _next_non_space(text: str, start: int) -> int:
    index = start
    while index < len(text) and text[index].isspace():
        index += 1
    return index
