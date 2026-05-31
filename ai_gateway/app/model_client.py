from __future__ import annotations

import json
import logging
import os
import time
from dataclasses import dataclass
from typing import Any

import httpx

from .prompting import DEEP_SYSTEM_PROMPT, FAST_SYSTEM_PROMPT, deep_user_prompt, fast_user_prompt
from .schemas import DeepInterpretationRequest, FastThoughtRequest

logger = logging.getLogger("ari_ai_gateway")


@dataclass(frozen=True)
class Settings:
    game_api_key: str = os.getenv("GAME_AI_API_KEY", "")
    model_backend: str = os.getenv("MODEL_BACKEND", "ollama").lower()
    model_base_url: str = os.getenv("MODEL_BASE_URL", "http://127.0.0.1:11434").rstrip("/")
    fast_model: str = os.getenv("FAST_MODEL", os.getenv("MODEL_NAME", "qwen3:1.7b"))
    deep_model: str = os.getenv("DEEP_MODEL", os.getenv("MODEL_NAME", "qwen3:1.7b"))
    request_timeout_seconds: float = float(os.getenv("REQUEST_TIMEOUT_SECONDS", "6"))
    debug_log_signs: bool = os.getenv("DEBUG_LOG_SIGNS", "false").lower() == "true"


def settings_from_env() -> Settings:
    return Settings()


async def call_deep_model(request: DeepInterpretationRequest, settings: Settings) -> dict[str, Any]:
    start = time.perf_counter()
    try:
        raw = await _chat_json(
            settings=settings,
            model=settings.deep_model,
            system_prompt=DEEP_SYSTEM_PROMPT,
            user_prompt=deep_user_prompt(request),
            max_tokens=320,
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
        max_tokens=96,
    )
    logger.info("fast_thought model=success latency_ms=%d", int((time.perf_counter() - start) * 1000))
    return raw


async def _chat_json(settings: Settings, model: str, system_prompt: str, user_prompt: str, max_tokens: int) -> dict[str, Any]:
    if settings.model_backend == "ollama":
        content = await _ollama_chat(settings, model, system_prompt, user_prompt, max_tokens)
    elif settings.model_backend == "vllm":
        content = await _openai_chat(settings, model, system_prompt, user_prompt, max_tokens)
    else:
        raise ValueError(f"Unsupported MODEL_BACKEND={settings.model_backend}")
    return parse_strict_json_object(content)


async def _ollama_chat(settings: Settings, model: str, system_prompt: str, user_prompt: str, max_tokens: int) -> str:
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "stream": False,
        "think": False,
        "options": {"temperature": 0.2, "num_predict": max_tokens},
    }
    async with httpx.AsyncClient(timeout=settings.request_timeout_seconds) as client:
        response = await client.post(f"{settings.model_base_url}/api/chat", json=payload)
        response.raise_for_status()
        data = response.json()
    return data["message"]["content"]


async def _openai_chat(settings: Settings, model: str, system_prompt: str, user_prompt: str, max_tokens: int) -> str:
    headers = {"Content-Type": "application/json"}
    api_key = os.getenv("MODEL_API_KEY", "")
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "temperature": 0.2,
        "max_tokens": max_tokens,
    }
    async with httpx.AsyncClient(timeout=settings.request_timeout_seconds) as client:
        response = await client.post(f"{settings.model_base_url}/chat/completions", headers=headers, json=payload)
        response.raise_for_status()
        data = response.json()
    return data["choices"][0]["message"]["content"]


def parse_strict_json_object(text: str) -> dict[str, Any]:
    cleaned = text.strip()
    decoder = json.JSONDecoder()
    parsed, end = decoder.raw_decode(cleaned)
    if cleaned[end:].strip():
        raise ValueError("Model returned extra text after JSON.")
    if not isinstance(parsed, dict):
        raise ValueError("Model returned non-object JSON.")
    return parsed
