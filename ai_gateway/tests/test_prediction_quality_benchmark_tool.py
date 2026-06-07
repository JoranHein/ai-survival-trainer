import importlib.util
import io
from pathlib import Path
import urllib.error


def _load_tool():
    path = Path(__file__).resolve().parents[1] / "scripts" / "benchmark_prediction_quality.py"
    spec = importlib.util.spec_from_file_location("benchmark_prediction_quality", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_prediction_benchmark_cases_use_concrete_available_actions():
    tool = _load_tool()

    non_executable = {"anti_flying", "sky_answer", "wall", "range", "mining"}

    for case in tool.CASES:
        payload = tool.build_payload(case)
        legal_ids = {item["id"] for item in payload["legal_actions"] if item.get("available", True)}
        assert legal_ids
        assert not legal_ids.intersection(non_executable)
        assert payload["schema"] == "ari.prediction.request.v1"
        assert set(case["expected_any"]).issubset(legal_ids)


def test_prediction_benchmark_rejects_fallback_even_with_expected_action():
    tool = _load_tool()
    case = {"id": "wings", "expected_any": {"build_storm_rod"}, "forbidden": {"build_wall"}}

    row = tool.evaluate_response(
        case,
        tool.build_payload({**tool.CASES[0], "id": "wings"}),
        {
            "schema": "ari.prediction.v1",
            "source": "local_fallback",
            "failure_reason": "model_failed",
            "next_action_bias": {"action_id": "build_storm_rod"},
        },
        1.0,
        5.0,
    )

    assert row["ok"] is False
    assert row["fallback_or_failed"] is True
    assert row["error"] == "fallback_or_failed"


def test_prediction_benchmark_rejects_illegal_action():
    tool = _load_tool()
    case = {"id": "wings", "expected_any": {"build_storm_rod"}, "forbidden": {"build_wall"}}
    payload = tool.build_payload({**tool.CASES[0], "id": "wings"})

    row = tool.evaluate_response(
        case,
        payload,
        {
            "schema": "ari.prediction.v1",
            "source": "remote_server",
            "failure_reason": "",
            "next_action_bias": {"action_id": "summon_dragon"},
        },
        1.0,
        5.0,
    )

    assert row["ok"] is False
    assert row["error"] == "illegal action"


def test_prediction_benchmark_summary_reports_p95_and_fallbacks():
    tool = _load_tool()

    summary = tool.summary([
        {"ok": True, "latency_seconds": 0.5, "fallback_or_failed": False, "legal_action": True},
        {"ok": False, "latency_seconds": 5.2, "fallback_or_failed": True, "legal_action": True},
        {"ok": False, "latency_seconds": 1.2, "fallback_or_failed": False, "legal_action": False},
    ])

    assert summary == {
        "count": 3,
        "passed": 1,
        "failed": 2,
        "fallback_or_failed": 1,
        "illegal_actions": 1,
        "useful_under_target": 1,
        "avg_latency_seconds": 2.3,
        "p50_latency_seconds": 1.2,
        "p95_latency_seconds": 5.2,
        "max_latency_seconds": 5.2,
    }


def test_prediction_benchmark_reports_http_error_without_crashing(monkeypatch):
    tool = _load_tool()

    def fail_urlopen(_request, timeout):
        raise urllib.error.HTTPError(
            url="http://example.test/ari/predict-v1",
            code=404,
            msg="Not Found",
            hdrs={},
            fp=io.BytesIO(b"not found"),
        )

    monkeypatch.setattr(tool.urllib.request, "urlopen", fail_urlopen)

    row = tool.run_case("http://example.test", "", tool.CASES[0], 1.0, 5.0)

    assert row["ok"] is False
    assert row["error"] == "HTTPError"
    assert row["http_status"] == 404
