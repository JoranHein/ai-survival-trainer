import importlib.util
import io
from pathlib import Path
import urllib.error


def _load_tool():
    path = Path(__file__).resolve().parents[1] / "scripts" / "benchmark_scribe_quality.py"
    spec = importlib.util.spec_from_file_location("benchmark_scribe_quality", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_scribe_quality_cases_are_structured_observer_payloads():
    tool = _load_tool()

    cases = tool.cases()

    assert cases
    for case in cases:
        payload = tool.build_payload(case)
        body = payload["payload"]
        assert body["schema"] == "ari.scribe.request.v1"
        assert body["snapshots"]
        assert body["snapshots"][0]["schema"] == "ari.observer.snapshot.v1"
        assert case["expected_terms"]


def test_scribe_quality_cases_forbid_freeform_sign_overreach():
    tool = _load_tool()

    body_mismatch = next(case for case in tool.cases() if case["id"] == "body_contradicts_survival_plan")

    assert "sign rejected hiding" in body_mismatch["forbidden_terms"]


def test_scribe_quality_scores_expected_terms_and_forbidden_terms():
    tool = _load_tool()
    case = {
        "id": "wings",
        "expected_terms": ["flying", "build_storm_rod", "plan_support"],
        "forbidden_terms": ["random invented dragon"],
    }

    good = tool.evaluate_response(
        case,
        {
            "raw": {
                "schema": "ari.scribe.note.v2",
                "note": "Ari saw flying danger and repaired support before build storm rod.",
                "facts": ["flying enemy present"],
                "actions": [{"action": "repair_structure", "status": "plan_support"}],
                "tags": ["danger:flying", "plan_support"],
                "priority_hints": {"build_storm_rod": 0.6},
                "plan_alignment": "supporting",
                "immediate_risk": "high",
                "risk_reason": "Flying danger needs a sky answer.",
                "lesson_candidates": ["when wings appear, answer the sky first"],
            }
        },
        0.25,
    )
    bad = tool.evaluate_response(
        case,
        {"raw": {"schema": "ari.scribe.note.v2", "note": "Ari saw nothing."}},
        0.25,
    )

    assert good["ok"] is True
    assert good["score"] == 3
    assert bad["ok"] is False
    assert "flying" in bad["missing_terms"]


def test_scribe_quality_reports_http_error_without_crashing(monkeypatch):
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

    row = tool.run_case("http://example.test", "", tool.cases()[0], 1.0)

    assert row["ok"] is False
    assert row["error"] == "HTTPError"
    assert row["http_status"] == 404
