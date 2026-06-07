import importlib.util
import io
from pathlib import Path
import urllib.error


def _load_tool():
    path = Path(__file__).resolve().parents[1] / "scripts" / "benchmark_observer_loop.py"
    spec = importlib.util.spec_from_file_location("benchmark_observer_loop", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_observer_benchmark_tool_builds_scribe_and_reflection_cases():
    tool = _load_tool()

    cases = tool._cases()

    assert [case["endpoint"] for case in cases] == ["/scribe", "/library-reflection"]
    assert cases[0]["body"]["payload"]["schema"] == "ari.scribe.request.v1"
    assert cases[1]["body"]["payload"]["schema"] == "ari.night_reflection.request.v1"


def test_observer_benchmark_summary_counts_successful_contract_responses():
    tool = _load_tool()

    rows = [
        {"endpoint": "/scribe", "ok": True, "latency_seconds": 0.01},
        {"endpoint": "/library-reflection", "ok": False, "latency_seconds": 2.0},
    ]

    assert tool._summary(rows) == {
        "count": 2,
        "ok": 1,
        "avg_latency_seconds": 0.01,
        "p50_latency_seconds": 0.01,
        "missing_endpoints": [],
    }


def test_observer_benchmark_summary_reports_missing_openapi_endpoints():
    tool = _load_tool()

    summary = tool._summary(
        [{"endpoint": "/scribe", "ok": False, "latency_seconds": 0.01}],
        openapi_paths={"/health", "/ai/deep-interpretation"},
    )

    assert summary["missing_endpoints"] == ["/scribe"]


def test_observer_benchmark_reports_http_status_for_failed_endpoint(monkeypatch):
    tool = _load_tool()

    def fail_urlopen(_request, timeout):
        raise urllib.error.HTTPError(
            url="http://example.test/scribe",
            code=404,
            msg="Not Found",
            hdrs={},
            fp=io.BytesIO(b"not found"),
        )

    monkeypatch.setattr(tool.urllib.request, "urlopen", fail_urlopen)

    row = tool._run_case(
        "http://example.test",
        "",
        {"endpoint": "/scribe", "body": {"payload": {"schema": "ari.scribe.request.v1"}}},
        1.0,
    )

    assert row["ok"] is False
    assert row["error"] == "HTTPError"
    assert row["http_status"] == 404


def test_observer_benchmark_reports_connection_reset_without_crashing(monkeypatch):
    tool = _load_tool()

    def fail_urlopen(_request, timeout):
        raise ConnectionResetError(10054, "remote host closed the connection")

    monkeypatch.setattr(tool.urllib.request, "urlopen", fail_urlopen)

    row = tool._run_case(
        "http://example.test",
        "",
        {"endpoint": "/library-reflection", "body": {"payload": {"schema": "ari.night_reflection.request.v1"}}},
        1.0,
    )

    assert row["ok"] is False
    assert row["error"] == "ConnectionResetError"
    assert row["endpoint"] == "/library-reflection"
