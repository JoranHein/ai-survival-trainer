import importlib.util
from pathlib import Path


def _load_tool():
    path = Path(__file__).resolve().parents[1] / "scripts" / "benchmark_prediction_models.py"
    spec = importlib.util.spec_from_file_location("benchmark_prediction_models", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_model_bakeoff_defaults_include_required_candidates():
    tool = _load_tool()

    assert "qwen3:0.6b" in tool.DEFAULT_CANDIDATE_MODELS
    assert "qwen3:1.7b" in tool.DEFAULT_CANDIDATE_MODELS
    assert "llama3.2:1b" in tool.DEFAULT_CANDIDATE_MODELS


def test_model_bakeoff_evaluates_compact_raw_prediction_through_gate():
    tool = _load_tool()
    case = tool.prediction_benchmark.CASES[0]
    payload = tool.prediction_benchmark.build_payload(case)

    row = tool.evaluate_model_result(
        "qwen3:0.6b",
        case,
        payload,
        {
            "r": "high",
            "a": "build_storm_rod",
            "u": 0.8,
            "h": {"build_storm_rod": 0.8},
            "c": 0.6,
        },
        1.2,
        5.0,
        json_valid=True,
    )

    assert row["ok"] is True
    assert row["model"] == "qwen3:0.6b"
    assert row["json_valid"] is True
    assert row["action"] == "build_storm_rod"
    assert row["source"] == "remote_server"


def test_model_bakeoff_failed_generation_counts_invalid_json_and_fallback():
    tool = _load_tool()
    case = tool.prediction_benchmark.CASES[0]
    payload = tool.prediction_benchmark.build_payload(case)

    row = tool.evaluate_model_exception("qwen3:0.6b", case, payload, RuntimeError("truncated"), 3.1, 5.0)

    assert row["ok"] is False
    assert row["model"] == "qwen3:0.6b"
    assert row["json_valid"] is False
    assert row["fallback_or_failed"] is True
    assert row["error"] == "fallback_or_failed"
    assert row["model_error"] == "RuntimeError"


def test_model_bakeoff_summary_groups_quality_latency_and_validity():
    tool = _load_tool()

    summary = tool.summary_by_model([
        {"model": "a", "ok": True, "json_valid": True, "fallback_or_failed": False, "legal_action": True, "latency_seconds": 0.8},
        {"model": "a", "ok": False, "json_valid": False, "fallback_or_failed": True, "legal_action": True, "latency_seconds": 5.2},
        {"model": "b", "ok": True, "json_valid": True, "fallback_or_failed": False, "legal_action": True, "latency_seconds": 1.4},
    ])

    assert summary["a"] == {
        "count": 2,
        "passed": 1,
        "failed": 1,
        "json_valid_rate": 0.5,
        "fallback_rate": 0.5,
        "legal_action_rate": 1.0,
        "useful_under_target": 1,
        "avg_latency_seconds": 3.0,
        "p50_latency_seconds": 3.0,
        "p95_latency_seconds": 5.2,
        "max_latency_seconds": 5.2,
    }
    assert summary["b"]["json_valid_rate"] == 1.0
    assert summary["b"]["p95_latency_seconds"] == 1.4


def test_model_bakeoff_selects_highest_pass_rate_then_lowest_p95():
    tool = _load_tool()

    winner = tool.choose_winner({
        "slow": {"count": 4, "passed": 4, "fallback_rate": 0.0, "p95_latency_seconds": 4.0},
        "fast": {"count": 4, "passed": 4, "fallback_rate": 0.0, "p95_latency_seconds": 1.2},
        "partial": {"count": 4, "passed": 3, "fallback_rate": 0.0, "p95_latency_seconds": 0.9},
    })

    assert winner == "fast"


def test_model_bakeoff_exit_succeeds_when_any_candidate_passes():
    tool = _load_tool()

    assert tool.exit_code_for_result({
        "summary_by_model": {
            "winner": {"count": 4, "passed": 4},
            "loser": {"count": 4, "passed": 0},
        }
    }) == 0
    assert tool.exit_code_for_result({
        "summary_by_model": {
            "loser": {"count": 4, "passed": 0},
        }
    }) == 1
