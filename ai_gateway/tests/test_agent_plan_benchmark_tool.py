import importlib.util
import io
from pathlib import Path
import urllib.error


def _load_tool():
    path = Path(__file__).resolve().parents[1] / "scripts" / "benchmark_agent_plan.py"
    spec = importlib.util.spec_from_file_location("benchmark_agent_plan", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_agent_plan_benchmark_cases_use_concrete_legal_actions():
    tool = _load_tool()

    non_executable = {"anti_flying", "sky_answer", "ranged_attack", "train_bow", "eat", "hide", "kite", "repair"}

    for case in tool.CASES:
        payload = tool.build_payload(case)
        legal_ids = {item["id"] for item in payload["legal_actions"]}
        assert legal_ids
        assert not legal_ids.intersection(non_executable)
        assert payload["schema"] == "ari.agent.plan.v1"
        assert payload["local_fallback"]["next_action"]["action_id"] in legal_ids


def test_agent_plan_benchmark_local_fallback_payloads_use_concrete_reasons():
    tool = _load_tool()

    for case in tool.CASES:
        fallback = tool.build_payload(case)["local_fallback"]
        texts = [
            fallback["survival_theory"],
            fallback["plan"][0]["reason"],
            fallback["next_action"]["reason"],
            fallback["thought"],
        ]

        assert all(text.strip() for text in texts)
        assert not any(tool._is_fallback_like_thought(text) for text in texts)


def test_agent_plan_benchmark_scores_expected_and_forbidden_actions():
    tool = _load_tool()
    case = {
        "id": "cover",
        "expected_any": {"use_cover", "flee"},
        "forbidden": {"eat_food"},
    }

    ok = tool.evaluate_response(case, {"next_action": {"action_id": "use_cover"}, "plan": []}, 1.2)
    bad = tool.evaluate_response(case, {"next_action": {"action_id": "eat_food"}, "plan": []}, 1.2)

    assert ok["ok"] is True
    assert ok["next_action"] == "use_cover"
    assert bad["ok"] is False
    assert bad["error"] == "forbidden action"


def test_agent_plan_benchmark_rejects_remote_fallback_like_thought():
    tool = _load_tool()
    case = {
        "id": "tower",
        "expected_any": {"build_tower"},
        "forbidden": {"build_wall"},
    }

    row = tool.evaluate_response(
        case,
        {
            "next_action": {"action_id": "build_tower"},
            "plan": [{"action_id": "build_tower"}],
            "source": "remote_server",
            "failure_reason": "",
            "thought": "I can still choose a legal fallback.",
        },
        1.2,
    )

    assert row["ok"] is False
    assert row["error"] == "fallback-like thought"
    assert row["fallback_like_thought"] is True


def test_agent_plan_benchmark_allows_explicit_local_fallback_thought():
    tool = _load_tool()
    case = {
        "id": "tower",
        "expected_any": {"build_tower"},
        "forbidden": {"build_wall"},
    }

    row = tool.evaluate_response(
        case,
        {
            "next_action": {"action_id": "build_tower"},
            "plan": [{"action_id": "build_tower"}],
            "source": "local_fallback",
            "failure_reason": "model_failed",
            "thought": "I can still choose a legal fallback.",
        },
        1.2,
    )

    assert row["ok"] is True
    assert row["fallback_like_thought"] is True


def test_agent_plan_benchmark_summary_counts_passed_cases():
    tool = _load_tool()

    summary = tool.summary([
        {"ok": True, "latency_seconds": 2.0, "fallback_like_thought": False},
        {"ok": False, "latency_seconds": 4.0, "fallback_like_thought": True},
    ])

    assert summary == {
        "count": 2,
        "passed": 1,
        "failed": 1,
        "fallback_like_thoughts": 1,
        "avg_latency_seconds": 3.0,
        "p50_latency_seconds": 3.0,
        "max_latency_seconds": 4.0,
    }


def test_agent_plan_benchmark_reports_http_error_without_crashing(monkeypatch):
    tool = _load_tool()

    def fail_urlopen(_request, timeout):
        raise urllib.error.HTTPError(
            url="http://example.test/ari/plan-v1",
            code=404,
            msg="Not Found",
            hdrs={},
            fp=io.BytesIO(b"not found"),
        )

    monkeypatch.setattr(tool.urllib.request, "urlopen", fail_urlopen)

    row = tool.run_case("http://example.test", "", tool.CASES[0], 1.0)

    assert row["ok"] is False
    assert row["error"] == "HTTPError"
    assert row["http_status"] == 404
