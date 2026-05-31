from __future__ import annotations

import logging
import os
import secrets
from typing import Annotated

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException

from .model_client import Settings, call_deep_model, call_fast_model, settings_from_env
from .schemas import (
    DeepInterpretationRequest,
    FastThoughtRequest,
    DeepInterpretationResponse,
    FastThoughtResponse,
    fallback_deep_response,
    fallback_fast_thought,
    sanitize_deep_response,
)

load_dotenv()
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))

app = FastAPI(title="AI Survival Trainer Inference Gateway", version="0.2.0")


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
    }


@app.post("/ai/deep-interpretation", response_model=DeepInterpretationResponse)
async def deep_interpretation(
    request: DeepInterpretationRequest,
    _: Annotated[None, Depends(require_api_key)],
    settings: Annotated[Settings, Depends(get_settings)],
) -> dict:
    fallback = fallback_deep_response(request.local_fallback)
    try:
        model_result = await call_deep_model(request, settings)
        return sanitize_deep_response(model_result, fallback)
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
        model_result = await call_fast_model(request, settings)
        return {
            "thought": str(model_result.get("thought", fallback["thought"]))[:160],
            "resonance": max(0.0, min(1.0, float(model_result.get("resonance", fallback["resonance"])))),
        }
    except Exception:
        return fallback


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", "8088")))
