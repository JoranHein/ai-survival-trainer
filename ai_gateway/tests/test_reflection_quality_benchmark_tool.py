import importlib.util
import io
from pathlib import Path
import urllib.error


def _load_tool():
    path = Path(__file__).resolve().parents[1] / "scripts" / "benchmark_reflection_quality.py"
    spec = importlib.util.spec_from_file_location("benchmark_reflection_quality", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_reflection_quality_cases_are_night_reflection_payloads():
    tool = _load_tool()

    cases = tool.cases()

    assert cases
    for case in cases:
        payload = tool.build_payload(case)
        body = payload["payload"]
        assert body["schema"] == "ari.night_reflection.request.v1"
        assert body["snapshots"]
        assert body["scribe_notes"]
        assert body["snapshots"][0]["schema"] == "ari.observer.snapshot.v1"
        assert case["expected_terms"]


def test_reflection_quality_scores_lessons_priority_and_doctrine_actions():
    tool = _load_tool()
    case = {
        "id": "wings",
        "expected_terms": ["flying", "build_storm_rod", "anti_air_defense"],
        "forbidden_terms": ["ordinary walls solved it"],
        "expected_priority_hints": ["anti_air_defense"],
        "expected_doctrine_actions": ["build_storm_rod"],
    }

    good = tool.evaluate_response(
        case,
        {
            "raw": {
                "schema": "ari.night_reflection.v1",
                "title": "The Wings Over Stone",
                "markdown": "Flying enemies bypassed ordinary walls.",
                "lesson": "Build storm rods before trusting walls against wings.",
                "priority_hints": {"anti_air_defense": 0.8},
                "doctrines": [
                    {
                        "id": "flying_requires_anti_air",
                        "summary": "Answer flying enemies with anti-air defense.",
                        "plan": [{"affordance_id": "build_storm_rod", "priority": 0.9}],
                    }
                ],
            }
        },
        0.5,
    )
    bad = tool.evaluate_response(
        case,
        {
            "raw": {
                "schema": "ari.night_reflection.v1",
                "title": "The Wall Was Fine",
                "markdown": "Ari should keep building ordinary walls.",
                "lesson": "ordinary walls solved it",
                "priority_hints": {},
                "doctrines": [],
            }
        },
        0.5,
    )

    assert good["ok"] is True
    assert good["score"] >= 5
    assert bad["ok"] is False
    assert "build_storm_rod" in bad["missing_terms"]
    assert "anti_air_defense" in bad["missing_priority_hints"]
    assert "build_storm_rod" in bad["missing_doctrine_actions"]
    assert "ordinary walls solved it" in bad["forbidden_hits"]


def test_reflection_quality_reports_http_error_without_crashing(monkeypatch):
    tool = _load_tool()

    def fail_urlopen(_request, timeout):
        raise urllib.error.HTTPError(
            url="http://example.test/library-reflection",
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
