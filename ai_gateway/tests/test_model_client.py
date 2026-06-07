import asyncio
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import model_client
from app.model_client import Settings, settings_from_env
from app.schemas import BridgePayloadRequest


def test_settings_from_env_reads_current_openai_environment(monkeypatch):
    monkeypatch.setenv("MODEL_BACKEND", "openai")
    monkeypatch.setenv("MODEL_BASE_URL", "https://api.openai.com/v1")
    monkeypatch.setenv("MODEL_API_KEY", "sk-test")
    monkeypatch.setenv("FAST_MODEL", "gpt-5.4-nano")
    monkeypatch.setenv("DEEP_MODEL", "gpt-5.4-mini")

    settings = settings_from_env()

    assert settings.model_backend == "openai"
    assert settings.model_base_url == "https://api.openai.com/v1"
    assert settings.model_api_key == "sk-test"
    assert settings.fast_model == "gpt-5.4-nano"
    assert settings.deep_model == "gpt-5.4-mini"


def test_settings_from_env_uses_validated_ollama_defaults(monkeypatch):
    monkeypatch.setenv("MODEL_BACKEND", "ollama")
    monkeypatch.delenv("MODEL_NAME", raising=False)
    monkeypatch.delenv("MODEL_BASE_URL", raising=False)
    monkeypatch.delenv("FAST_MODEL", raising=False)
    monkeypatch.delenv("DEEP_MODEL", raising=False)
    monkeypatch.delenv("PLANNER_MODEL", raising=False)
    monkeypatch.delenv("DEEP_MAX_TOKENS", raising=False)
    monkeypatch.delenv("PLANNER_MAX_TOKENS", raising=False)
    monkeypatch.delenv("PREDICTION_MAX_TOKENS", raising=False)
    monkeypatch.delenv("OLLAMA_NUM_THREAD", raising=False)
    monkeypatch.delenv("OLLAMA_NUM_CTX", raising=False)
    monkeypatch.delenv("PREDICTION_NUM_CTX", raising=False)
    monkeypatch.delenv("SCRIBE_MODE", raising=False)

    settings = settings_from_env()

    assert settings.model_backend == "ollama"
    assert settings.model_base_url == "http://127.0.0.1:11434"
    assert settings.fast_model == "qwen3:0.6b"
    assert settings.deep_model == "hf.co/Qwen/Qwen3-1.7B-GGUF:Q8_0"
    assert settings.planner_model == "qwen3:0.6b"
    assert settings.prediction_model == "smollm2:135m"
    assert settings.deep_mode == "deterministic"
    assert settings.scribe_mode == "deterministic"
    assert settings.deep_max_tokens == 360
    assert settings.planner_max_tokens == 180
    assert settings.reflection_max_tokens == 140
    assert settings.prediction_max_tokens == 96
    assert settings.ollama_num_thread == 0
    assert settings.ollama_num_ctx == 0
    assert settings.planner_num_ctx == 1024
    assert settings.reflection_num_ctx == 1024
    assert settings.prediction_num_ctx == 512
    assert settings.deep_request_timeout_seconds == 5.0
    assert settings.planner_request_timeout_seconds == 5.0
    assert settings.reflection_request_timeout_seconds == 12.0
    assert settings.background_request_timeout_seconds == 4.0
    assert settings.prediction_request_timeout_seconds == 5.0
    assert settings.enable_startup_warmup is True


def test_settings_from_env_reads_endpoint_specific_timeouts(monkeypatch):
    monkeypatch.setenv("MODEL_BACKEND", "ollama")
    monkeypatch.setenv("REQUEST_TIMEOUT_SECONDS", "5")
    monkeypatch.setenv("DEEP_REQUEST_TIMEOUT_SECONDS", "6")
    monkeypatch.setenv("PLANNER_REQUEST_TIMEOUT_SECONDS", "7")
    monkeypatch.setenv("REFLECTION_REQUEST_TIMEOUT_SECONDS", "13")
    monkeypatch.setenv("BACKGROUND_REQUEST_TIMEOUT_SECONDS", "3.5")
    monkeypatch.setenv("PREDICTION_REQUEST_TIMEOUT_SECONDS", "4.8")
    monkeypatch.setenv("PLANNER_NUM_CTX", "640")
    monkeypatch.setenv("REFLECTION_NUM_CTX", "768")
    monkeypatch.setenv("DEEP_MODE", "model")

    settings = settings_from_env()

    assert settings.request_timeout_seconds == 5.0
    assert settings.deep_request_timeout_seconds == 6.0
    assert settings.planner_request_timeout_seconds == 7.0
    assert settings.reflection_request_timeout_seconds == 13.0
    assert settings.background_request_timeout_seconds == 3.5
    assert settings.prediction_request_timeout_seconds == 4.8
    assert settings.planner_num_ctx == 640
    assert settings.reflection_num_ctx == 768
    assert settings.deep_mode == "model"


def test_settings_from_env_reads_explicit_scribe_mode(monkeypatch):
    monkeypatch.setenv("MODEL_BACKEND", "ollama")
    monkeypatch.setenv("SCRIBE_MODE", "model")

    settings = settings_from_env()

    assert settings.scribe_mode == "model"


def test_settings_from_env_reads_tier_specific_models(monkeypatch):
    monkeypatch.setenv("MODEL_BACKEND", "ollama")
    monkeypatch.setenv("FAST_MODEL", "tiny-fast")
    monkeypatch.setenv("DEEP_MODEL", "semantic-deep")
    monkeypatch.setenv("PLANNER_MODEL", "survival-planner")
    monkeypatch.setenv("SCRIBE_MODEL", "tiny-scribe")
    monkeypatch.setenv("REFLECTION_MODEL", "night-reflector")

    settings = settings_from_env()

    assert settings.fast_model == "tiny-fast"
    assert settings.deep_model == "semantic-deep"
    assert settings.planner_model == "survival-planner"
    assert settings.scribe_model == "tiny-scribe"
    assert settings.reflection_model == "night-reflector"


def test_model_calls_use_tier_specific_scribe_and_reflection_models(monkeypatch):
    captured_models = []

    async def fake_chat_json(**kwargs):
        captured_models.append(kwargs["model"])
        return {"schema": "ok"}

    monkeypatch.setattr(model_client, "_chat_json", fake_chat_json)
    settings = Settings(
        scribe_model="tiny-scribe",
        reflection_model="night-reflector",
        fast_model="tiny-fast",
        planner_model="survival-planner",
    )

    asyncio.run(model_client.call_scribe_model(BridgePayloadRequest(payload={"schema": "ari.scribe.request.v1"}), settings))
    asyncio.run(
        model_client.call_library_reflection_model(
            BridgePayloadRequest(payload={"schema": "ari.night_reflection.request.v1"}),
            settings,
        )
    )

    assert captured_models == ["tiny-scribe", "night-reflector"]


def test_prediction_model_uses_small_context_window(monkeypatch):
    captured = {}

    async def fake_chat_json(**kwargs):
        captured.update(kwargs)
        return {"r": "low", "a": "mine_stone", "why": "short", "c": 0.5}

    monkeypatch.setattr(model_client, "_chat_json", fake_chat_json)
    settings = Settings(prediction_model="tiny-predict", prediction_num_ctx=384, prediction_max_tokens=42)

    asyncio.run(
        model_client.call_prediction_model(
            model_client.PredictionRequest(
                context_hash="ctx",
                legal_actions=[{"id": "mine_stone", "available": True}],
            ),
            settings,
        )
    )

    assert captured["model"] == "tiny-predict"
    assert captured["max_tokens"] == 42
    assert captured["num_ctx"] == 384
    assert captured["response_schema"]["required"] == ["r", "a", "u", "h", "c"]
    assert "why" not in captured["response_schema"]["properties"]
    assert "avoid" not in captured["response_schema"]["properties"]


def test_model_calls_pass_endpoint_specific_timeouts(monkeypatch):
    captured: list[tuple[str, float | None]] = []

    async def fake_chat_json(**kwargs):
        captured.append((kwargs["model"], kwargs.get("timeout_seconds")))
        if kwargs["model"] == "tiny-predict":
            return {"r": "low", "a": "mine_stone", "u": 0.4, "why": "short", "h": {}, "avoid": [], "c": 0.5}
        return {"schema": "ok"}

    monkeypatch.setattr(model_client, "_chat_json", fake_chat_json)
    settings = Settings(
        model_backend="ollama",
        deep_model="deep",
        planner_model="planner",
        scribe_model="scribe",
        reflection_model="reflect",
        background_model="background",
        prediction_model="tiny-predict",
        deep_request_timeout_seconds=6.0,
        planner_request_timeout_seconds=7.0,
        scribe_request_timeout_seconds=3.0,
        reflection_request_timeout_seconds=12.0,
        background_request_timeout_seconds=4.0,
        prediction_request_timeout_seconds=5.0,
    )

    asyncio.run(
        model_client.call_deep_model(
            model_client.DeepInterpretationRequest(
                sign_text="x",
                ari={},
                world={},
                local_fallback={},
            ),
            settings,
        )
    )
    asyncio.run(model_client.call_plan_model(model_client.AgentPlanRequest(sign={"text": "x"}), settings))
    asyncio.run(model_client.call_scribe_model(BridgePayloadRequest(payload={"schema": "ari.scribe.request.v1"}), settings))
    asyncio.run(model_client.call_library_reflection_model(BridgePayloadRequest(payload={"schema": "ari.night_reflection.request.v1"}), settings))
    asyncio.run(
        model_client.call_background_job_model(
            model_client.BackgroundJobRequest(
                job_id="bg",
                kind="strategy_candidate",
                context_hash="ctx",
            ),
            settings,
        )
    )
    asyncio.run(
        model_client.call_prediction_model(
            model_client.PredictionRequest(context_hash="ctx", legal_actions=[{"id": "mine_stone", "available": True}]),
            settings,
        )
    )

    assert captured == [
        ("deep", 6.0),
        ("planner", 7.0),
        ("scribe", 3.0),
        ("reflect", 12.0),
        ("background", 4.0),
        ("tiny-predict", 5.0),
    ]


def test_background_job_model_uses_compact_response_schema(monkeypatch):
    captured = {}

    async def fake_chat_json(**kwargs):
        captured.update(kwargs)
        return {"s": "ok", "n": ["short"], "h": {}, "try": [], "avoid": [], "c": 0.5}

    monkeypatch.setattr(model_client, "_chat_json", fake_chat_json)
    settings = Settings(background_model="tiny-bg", background_max_tokens=88)

    asyncio.run(
        model_client.call_background_job_model(
            model_client.BackgroundJobRequest(
                job_id="bg",
                kind="strategy_candidate",
                context_hash="ctx",
            ),
            settings,
        )
    )

    assert captured["model"] == "tiny-bg"
    assert captured["max_tokens"] == 88
    assert captured["response_schema"]["required"] == ["s", "n", "h", "try", "avoid", "c"]


def test_agent_plan_model_uses_compact_response_schema_and_small_context(monkeypatch):
    captured = {}

    async def fake_chat_json(**kwargs):
        captured.update(kwargs)
        return {"g": "survive", "theory": "height", "plan": ["build_tower"], "next": "build_tower", "fb": "use_cover", "why": "height", "belief": {}, "thought": "Up.", "c": 0.6, "after": 8}

    monkeypatch.setattr(model_client, "_chat_json", fake_chat_json)
    settings = Settings(planner_model="tiny-plan", planner_max_tokens=120, planner_num_ctx=640)

    asyncio.run(
        model_client.call_plan_model(
            model_client.AgentPlanRequest(
                sign={"text": "build high"},
                legal_actions=[{"id": "build_tower", "available": True}, {"id": "use_cover", "available": True}],
            ),
            settings,
        )
    )

    assert captured["model"] == "tiny-plan"
    assert captured["max_tokens"] == 120
    assert captured["num_ctx"] == 640
    assert captured["response_schema"]["required"] == ["g", "theory", "plan", "next", "fb", "why", "belief", "thought", "c", "after"]


def test_library_reflection_model_uses_compact_response_schema(monkeypatch):
    captured = {}

    async def fake_chat_json(**kwargs):
        captured.update(kwargs)
        return {
            "t": "Wings Over Stone",
            "m": "Ari learned that wings need sky defense.",
            "chg": ["flying"],
            "ok": [],
            "bad": ["walls first"],
            "mis": ["treated flying like ground danger"],
            "lesson": "Build storm rods before extra walls when wings appear.",
            "h": {"build_storm_rod": 0.7},
            "bias": {"build_storm_rod": 0.45},
            "belief": {"wings_ignore_walls": 0.25},
            "plan": ["build_storm_rod"],
            "thought": "Stone is not sky.",
            "c": 0.6,
        }

    monkeypatch.setattr(model_client, "_chat_json", fake_chat_json)
    settings = Settings(reflection_model="reflector", reflection_max_tokens=120, reflection_num_ctx=768)

    asyncio.run(
        model_client.call_library_reflection_model(
            BridgePayloadRequest(payload={"schema": "ari.night_reflection.request.v1"}),
            settings,
        )
    )

    assert captured["model"] == "reflector"
    assert captured["max_tokens"] == 120
    assert captured["num_ctx"] == 768
    assert captured["response_schema"]["required"] == [
        "t",
        "m",
        "chg",
        "ok",
        "bad",
        "mis",
        "lesson",
        "h",
        "bias",
        "belief",
        "plan",
        "thought",
        "c",
    ]


def test_openai_backend_uses_chat_completions_auth_and_json_contract(monkeypatch):
    captured = {}

    class FakeResponse:
        def raise_for_status(self):
            pass

        def json(self):
            return {"choices": [{"message": {"content": '{"thought":"I will stay careful."}'}}]}

    class FakeAsyncClient:
        def __init__(self, timeout):
            captured["timeout"] = timeout

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return None

        async def post(self, url, headers, json):
            captured["url"] = url
            captured["headers"] = headers
            captured["json"] = json
            return FakeResponse()

    monkeypatch.setattr(model_client.httpx, "AsyncClient", FakeAsyncClient)

    result = asyncio.run(
        model_client._chat_json(
            settings=Settings(
                model_backend="openai",
                model_base_url="https://api.openai.com/v1",
                model_api_key="sk-test",
                model_temperature=0.0,
                request_timeout_seconds=12,
            ),
            model="gpt-5.4-nano",
            system_prompt="Return JSON.",
            user_prompt="Write a thought.",
            max_tokens=80,
        )
    )

    assert result == {"thought": "I will stay careful."}
    assert captured["timeout"] == 12
    assert captured["url"] == "https://api.openai.com/v1/chat/completions"
    assert captured["headers"]["Authorization"] == "Bearer sk-test"
    assert captured["json"]["model"] == "gpt-5.4-nano"
    assert captured["json"]["messages"] == [
        {"role": "system", "content": "Return JSON."},
        {"role": "user", "content": "Write a thought."},
    ]
    assert captured["json"]["max_completion_tokens"] == 80
    assert "max_tokens" not in captured["json"]
    assert captured["json"]["response_format"] == {"type": "json_object"}


def test_openai_backend_requires_model_api_key():
    with pytest.raises(ValueError, match="MODEL_API_KEY"):
        asyncio.run(
            model_client._chat_json(
                settings=Settings(model_backend="openai", model_api_key=""),
                model="gpt-5.4-nano",
                system_prompt="Return JSON.",
                user_prompt="Write a thought.",
                max_tokens=80,
            )
        )


def test_ollama_backend_uses_json_schema_format_when_provided(monkeypatch):
    captured = {}
    response_schema = {
        "type": "object",
        "properties": {"thought": {"type": "string"}},
        "required": ["thought"],
    }

    class FakeResponse:
        def raise_for_status(self):
            pass

        def json(self):
            return {"message": {"content": '{"thought":"I will stay careful."}'}}

    class FakeAsyncClient:
        def __init__(self, timeout):
            captured["timeout"] = timeout

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return None

        async def post(self, url, json):
            captured["url"] = url
            captured["json"] = json
            return FakeResponse()

    monkeypatch.setattr(model_client.httpx, "AsyncClient", FakeAsyncClient)

    result = asyncio.run(
        model_client._chat_json(
            settings=Settings(
                model_backend="ollama",
                model_base_url="http://127.0.0.1:11434",
                request_timeout_seconds=12,
                ollama_json_format=True,
            ),
            model="qwen",
            system_prompt="Return JSON.",
            user_prompt="Write a thought.",
            max_tokens=80,
            response_schema=response_schema,
        )
    )

    assert result == {"thought": "I will stay careful."}
    assert captured["timeout"] == 12
    assert captured["url"] == "http://127.0.0.1:11434/api/chat"
    assert captured["json"]["format"] == response_schema
    assert captured["json"]["stream"] is False


def test_ollama_backend_applies_thread_context_and_keep_alive(monkeypatch):
    captured = {}

    class FakeResponse:
        def raise_for_status(self):
            pass

        def json(self):
            return {"message": {"content": '{"thought":"I will stay careful."}'}}

    class FakeAsyncClient:
        def __init__(self, timeout):
            captured["timeout"] = timeout

        async def __aenter__(self):
            return self

        async def __aexit__(self, exc_type, exc, tb):
            return None

        async def post(self, url, json):
            captured["url"] = url
            captured["json"] = json
            return FakeResponse()

    monkeypatch.setattr(model_client.httpx, "AsyncClient", FakeAsyncClient)

    result = asyncio.run(
        model_client._chat_json(
            settings=Settings(
                model_backend="ollama",
                model_base_url="http://127.0.0.1:11434",
                request_timeout_seconds=12,
                ollama_num_thread=4,
                ollama_num_ctx=1024,
                ollama_keep_alive="45m",
            ),
            model="qwen",
            system_prompt="Return JSON.",
            user_prompt="Write a thought.",
            max_tokens=80,
            num_ctx=512,
        )
    )

    assert result == {"thought": "I will stay careful."}
    assert captured["json"]["keep_alive"] == "45m"
    assert captured["json"]["options"]["num_thread"] == 4
    assert captured["json"]["options"]["num_ctx"] == 512
    assert captured["json"]["options"]["num_predict"] == 80


def test_json_parser_accepts_leading_object_with_trailing_duplicate_block():
    raw = (
        '{"thought":"I will use the wall.","emotion":null}'
        "\n\n```json\n"
        '{"thought":"I will use the wall.","emotion":null}'
        "\n```"
    )

    assert model_client.parse_strict_json_object(raw) == {
        "thought": "I will use the wall.",
        "emotion": None,
    }


def test_json_parser_repairs_bare_keys_inside_leading_object():
    raw = """{
  "r": "high",
  "a": "build_storm_rod",
  "u": 0.85,
  h: {"build_storm_rod": 0.75},
  c: 0.42,
}"""

    assert model_client.parse_strict_json_object(raw) == {
        "r": "high",
        "a": "build_storm_rod",
        "u": 0.85,
        "h": {"build_storm_rod": 0.75},
        "c": 0.42,
    }


def test_json_parser_rejects_text_before_object():
    with pytest.raises(ValueError):
        model_client.parse_strict_json_object(
            'Here is the plan: {"thought":"I will use the wall."}'
        )
