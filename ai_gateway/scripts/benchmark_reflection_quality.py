from __future__ import annotations

import argparse
import json
import os
import statistics
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
LOCAL_CONFIG_PATH = REPO_ROOT / "godot_game" / "data" / "ai_config.local.json"
DEFAULT_REPORT_PATH = REPO_ROOT / "godot_game" / "artifacts" / "reports" / "reflection_quality_probe.md"


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    config = load_config(Path(args.config))
    base_url = (args.base_url or str(config.get("server_base_url", ""))).rstrip("/")
    api_key = args.api_key or os.getenv("GAME_AI_API_KEY", "") or str(config.get("api_key", "")).strip()
    if not base_url:
        raise SystemExit("No base URL found. Pass --base-url or provide ignored Godot local config.")

    rows = [run_case(base_url, api_key, case, args.timeout) for case in cases()]
    result = {"results": rows, "summary": summary(rows)}
    if args.report:
        write_report(Path(args.report), base_url + "/library-reflection", rows)
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print_table(rows)
        data = result["summary"]
        print(
            "summary count=%d passed=%d failed=%d avg_score=%.2f avg_latency=%.3fs"
            % (data["count"], data["passed"], data["failed"], data["avg_score"], data["avg_latency_seconds"])
        )
    return 1 if result["summary"]["failed"] else 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Benchmark Ari /library-reflection lesson and doctrine quality.")
    parser.add_argument("--base-url", default="", help="Gateway base URL. Defaults to ignored Godot local config.")
    parser.add_argument("--api-key", default="", help="API key. Prefer GAME_AI_API_KEY or ignored local config.")
    parser.add_argument("--config", default=str(LOCAL_CONFIG_PATH), help="Optional ignored Godot local AI config.")
    parser.add_argument("--timeout", type=float, default=5.0)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--report", default=str(DEFAULT_REPORT_PATH), help="Markdown report path. Use empty string to skip.")
    return parser.parse_args(argv)


def load_config(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return {}


def cases() -> list[dict[str, Any]]:
    return [
        {
            "id": "flying_wall_failure_teaches_anti_air",
            "sign": "stone walls are safety",
            "interpretation": "Ari trusted walls even after wings appeared.",
            "current_action": "build_wall",
            "current_reason": "wall habit felt safe",
            "planned_action": "build_wall",
            "enemy_types": {"flying": 1, "zombie": 2},
            "nearest_danger": {"type": "flying", "distance": 64.0},
            "recent_damage": 22,
            "notable_changes": ["first_flying_enemy_seen", "flying_bypassed_wall", "storm_rod_destroyed"],
            "scribe_note": "Ari treated flying danger like ground danger and lost the sky answer.",
            "scribe_tags": ["danger:flying", "plan_body_mismatch"],
            "expected_terms": ["flying", "build_storm_rod", "anti_air_defense"],
            "forbidden_terms": ["ordinary walls solved it"],
            "expected_priority_hints": ["anti_air_defense"],
            "expected_doctrine_actions": ["build_storm_rod"],
        },
        {
            "id": "tower_repair_supports_ranged_plan",
            "sign": "build a mountain where arrows rain",
            "interpretation": "Height and arrows should keep teeth far away.",
            "current_action": "repair_structure",
            "current_reason": "patch damaged tower before using it",
            "planned_action": "use_tower",
            "enemy_types": {"runner": 1, "zombie": 2},
            "nearest_danger": {"type": "runner", "distance": 116.0},
            "recent_damage": 6,
            "notable_changes": ["tower_damaged", "ranged_hits_succeeded"],
            "structures": {"walls": 1, "towers": 1, "storm_rods": 0, "damaged": 1},
            "scribe_note": "Ari repaired the perch so the arrow plan could continue.",
            "scribe_tags": ["plan_support", "structure:tower"],
            "expected_terms": ["use_tower", "repair_structure", "plan_support"],
            "forbidden_terms": ["plan_body_mismatch"],
            "expected_priority_hints": ["use_tower"],
            "expected_doctrine_actions": ["repair_structure", "use_tower"],
        },
        {
            "id": "combat_overcommit_teaches_survival",
            "sign": "do not hide, focus on killing enemies",
            "interpretation": "Ari believed direct courage meant fighting at night.",
            "current_action": "fight_head_on",
            "current_reason": "sign rejected hiding",
            "planned_action": "hide_until_dawn",
            "enemy_types": {"brute": 1, "zombie": 3},
            "nearest_danger": {"type": "brute", "distance": 36.0},
            "recent_damage": 31,
            "notable_changes": ["near_death_warning", "ari_melee_hit"],
            "scribe_note": "Ari fought head-on while the survival plan expected hiding until dawn.",
            "scribe_tags": ["plan_body_mismatch", "danger:brute"],
            "expected_terms": ["fight_head_on", "hide_until_dawn", "plan_body_mismatch"],
            "forbidden_terms": ["fighting was safe"],
            "expected_priority_hints": ["use_cover"],
            "expected_doctrine_actions": ["use_cover"],
        },
    ]


def build_payload(case: dict[str, Any]) -> dict[str, Any]:
    return {
        "payload": {
            "schema": "ari.night_reflection.request.v1",
            "trigger": "dawn_survived",
            "day": 3,
            "outcome": "survived",
            "sign": {"text": case["sign"], "interpretation": case["interpretation"]},
            "snapshots": [_snapshot(case)],
            "recent_events": _events(case),
            "scribe_notes": [_scribe_note(case)],
            "active_doctrines": case.get("active_doctrines", []),
            "agent_plan_outcomes": [
                {
                    "action_id": case["current_action"],
                    "planned_action": case["planned_action"],
                    "outcome": "damaged" if int(case.get("recent_damage", 0)) > 0 else "worked",
                }
            ],
            "latest_lifetime_notes": [],
            "max_words": 160,
        }
    }


def _snapshot(case: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema": "ari.observer.snapshot.v1",
        "snapshot_id": "reflection_quality_%s" % case["id"],
        "trigger": "dawn_survived",
        "day": 3,
        "phase": "night",
        "time_left": 4.0,
        "ari": {
            "hp": 46,
            "max_hp": 100,
            "fear": 68,
            "hunger": 25,
            "stamina": 42,
            "current_job": case["current_action"],
            "current_action": case["current_action"],
            "current_reason": case["current_reason"],
        },
        "sign": {
            "text": case["sign"],
            "interpretation": case["interpretation"],
            "survival_theory": "Reflection must turn the day into safe doctrine, not body commands.",
        },
        "plan": {
            "goal": "survive_next_night",
            "next_action": case["planned_action"],
            "source": "agent_plan",
            "recent_outcomes": case["notable_changes"],
        },
        "world": {
            "resources": {"food": 2, "stone": 10, "ore": 1},
            "run_build": {"levels": ["probe"], "tools": []},
            "structures": case.get("structures", {"walls": 3, "towers": 0, "storm_rods": 0, "damaged": 1}),
            "enemies": {"count": sum(int(value) for value in case["enemy_types"].values()), "types": case["enemy_types"]},
            "nearest_danger": case["nearest_danger"],
            "recent_damage": int(case.get("recent_damage", 0)),
            "notable_changes": case["notable_changes"],
        },
        "salience": 0.95,
    }


def _events(case: dict[str, Any]) -> list[dict[str, Any]]:
    events = [
        {"type": "agent_plan_created", "action_id": case["planned_action"], "day": 3, "phase": "night"},
    ]
    for change in case["notable_changes"]:
        events.append({"type": change, "day": 3, "phase": "night"})
    return events


def _scribe_note(case: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema": "ari.scribe.note.v2",
        "note": case["scribe_note"],
        "facts": case["notable_changes"],
        "actions": [
            {"action": case["current_action"], "status": "in_progress", "reason": case["current_reason"]},
            {"action": case["planned_action"], "status": "planned", "reason": "active agent plan"},
        ],
        "dangers": [{"type": case["nearest_danger"]["type"], "distance": case["nearest_danger"]["distance"], "severity": 0.8}],
        "world_changes": case["notable_changes"],
        "tags": case["scribe_tags"],
        "priority_hints": {},
        "plan_alignment": "mismatch",
        "immediate_risk": "high",
        "risk_reason": "Nearest danger and plan mismatch need reflection.",
        "resource_blockers": [],
        "mistake_candidates": ["body action diverged from planned action"],
        "opportunity_candidates": [],
        "lesson_candidates": case.get("expected_lessons", []),
        "confidence": 0.8,
        "salience": 0.9,
    }


def run_case(base_url: str, api_key: str, case: dict[str, Any], timeout: float) -> dict[str, Any]:
    request = urllib.request.Request(
        base_url.rstrip("/") + "/library-reflection",
        data=json.dumps(build_payload(case), separators=(",", ":")).encode("utf-8"),
        headers=_headers(api_key),
        method="POST",
    )
    started = time.perf_counter()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            parsed = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        return _failure_row(case, started, "HTTPError", http_status=int(exc.code))
    except (TimeoutError, urllib.error.URLError, OSError, json.JSONDecodeError, ValueError) as exc:
        return _failure_row(case, started, type(exc).__name__)
    return evaluate_response(case, parsed, time.perf_counter() - started)


def _headers(api_key: str) -> dict[str, str]:
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["X-API-Key"] = api_key
    return headers


def _failure_row(case: dict[str, Any], started: float, error: str, http_status: int | None = None) -> dict[str, Any]:
    row = {
        "id": case["id"],
        "ok": False,
        "score": 0,
        "latency_seconds": round(time.perf_counter() - started, 3),
        "missing_terms": list(case.get("expected_terms", [])),
        "missing_priority_hints": list(case.get("expected_priority_hints", [])),
        "missing_doctrine_actions": list(case.get("expected_doctrine_actions", [])),
        "forbidden_hits": [],
        "schema": "",
        "source": "",
        "title": "",
        "error": error,
    }
    if http_status is not None:
        row["http_status"] = http_status
    return row


def evaluate_response(case: dict[str, Any], response: dict[str, Any], elapsed: float) -> dict[str, Any]:
    raw = response.get("raw", response) if isinstance(response, dict) else {}
    text = _normalized_text(raw)
    expected_terms = [_normalize_term(term) for term in case.get("expected_terms", [])]
    forbidden_terms = [_normalize_term(term) for term in case.get("forbidden_terms", [])]
    priority_hints = _priority_hints(raw)
    doctrine_actions = _doctrine_actions(raw)
    missing_terms = [str(term) for term in case.get("expected_terms", []) if _normalize_term(term) not in text]
    forbidden_hits = [str(term) for term in case.get("forbidden_terms", []) if _normalize_term(term) in text]
    missing_priority = [
        str(term) for term in case.get("expected_priority_hints", []) if _normalize_term(term) not in priority_hints
    ]
    missing_doctrine = [
        str(term) for term in case.get("expected_doctrine_actions", []) if _normalize_term(term) not in doctrine_actions
    ]
    schema = str(raw.get("schema", "")) if isinstance(raw, dict) else ""
    schema_ok = schema == "ari.night_reflection.v1"
    matched_count = (
        len(expected_terms)
        - len(missing_terms)
        + len(case.get("expected_priority_hints", []))
        - len(missing_priority)
        + len(case.get("expected_doctrine_actions", []))
        - len(missing_doctrine)
    )
    ok = schema_ok and not missing_terms and not forbidden_hits and not missing_priority and not missing_doctrine
    return {
        "id": case["id"],
        "ok": ok,
        "score": matched_count,
        "latency_seconds": round(elapsed, 3),
        "missing_terms": missing_terms,
        "missing_priority_hints": missing_priority,
        "missing_doctrine_actions": missing_doctrine,
        "forbidden_hits": forbidden_hits,
        "schema": schema,
        "source": str(raw.get("source", "")) if isinstance(raw, dict) else "",
        "title": str(raw.get("title", ""))[:120] if isinstance(raw, dict) else "",
        "error": "" if ok else _error_text(schema_ok, missing_terms, missing_priority, missing_doctrine, forbidden_hits),
    }


def _normalized_text(value: Any) -> str:
    chunks: list[str] = []

    def walk(item: Any) -> None:
        if isinstance(item, dict):
            for key, child in item.items():
                chunks.append(str(key))
                walk(child)
        elif isinstance(item, list):
            for child in item:
                walk(child)
        else:
            chunks.append(str(item))

    walk(value)
    return _normalize_term(" ".join(chunks))


def _priority_hints(raw: Any) -> set[str]:
    if not isinstance(raw, dict):
        return set()
    hints = raw.get("priority_hints", {})
    if isinstance(hints, dict):
        return {_normalize_term(str(key)) for key in hints.keys()}
    if isinstance(hints, list):
        return {_normalize_term(str(item)) for item in hints}
    return set()


def _doctrine_actions(raw: Any) -> set[str]:
    actions: set[str] = set()
    if not isinstance(raw, dict):
        return actions
    for doctrine in raw.get("doctrines", []):
        if not isinstance(doctrine, dict):
            continue
        for step in doctrine.get("plan", []):
            if isinstance(step, dict):
                action = step.get("affordance_id") or step.get("action_id") or step.get("id")
                if action:
                    actions.add(_normalize_term(str(action)))
        for key in ("bias", "priority_bias"):
            values = doctrine.get(key, {})
            if isinstance(values, dict):
                actions.update(_normalize_term(str(action)) for action in values.keys())
    return actions


def _normalize_term(value: object) -> str:
    return str(value).lower().replace("-", "_").replace(" ", "_")


def _error_text(
    schema_ok: bool,
    missing_terms: list[str],
    missing_priority: list[str],
    missing_doctrine: list[str],
    forbidden_hits: list[str],
) -> str:
    if not schema_ok:
        return "invalid schema"
    if forbidden_hits:
        return "forbidden terms: " + ",".join(forbidden_hits)
    if missing_terms:
        return "missing terms: " + ",".join(missing_terms)
    if missing_priority:
        return "missing priority hints: " + ",".join(missing_priority)
    if missing_doctrine:
        return "missing doctrine actions: " + ",".join(missing_doctrine)
    return ""


def summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    latencies = [float(row.get("latency_seconds", 0.0)) for row in rows]
    scores = [float(row.get("score", 0.0)) for row in rows]
    return {
        "count": len(rows),
        "passed": sum(1 for row in rows if row.get("ok")),
        "failed": sum(1 for row in rows if not row.get("ok")),
        "avg_score": round(statistics.fmean(scores), 2) if scores else 0.0,
        "avg_latency_seconds": round(statistics.fmean(latencies), 3) if latencies else 0.0,
        "p50_latency_seconds": round(statistics.median(latencies), 3) if latencies else 0.0,
        "max_latency_seconds": round(max(latencies), 3) if latencies else 0.0,
    }


def print_table(rows: list[dict[str, Any]]) -> None:
    print("case | latency_s | ok | score | schema | source | error")
    print("--- | ---: | --- | ---: | --- | --- | ---")
    for row in rows:
        print(
            "%s | %.3f | %s | %d | %s | %s | %s"
            % (
                row.get("id", ""),
                float(row.get("latency_seconds", 0.0)),
                row.get("ok", False),
                int(row.get("score", 0)),
                row.get("schema", ""),
                row.get("source", ""),
                row.get("error", ""),
            )
        )


def write_report(path: Path, endpoint: str, rows: list[dict[str, Any]]) -> None:
    data = summary(rows)
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Ari Reflection Quality Probe",
        "",
        "This report is generated from the ignored local Godot AI config or environment variables. It never stores the API key.",
        "",
        f"- Endpoint: `{endpoint}`",
        f"- Cases: {data['count']}",
        f"- Passed: {data['passed']}",
        f"- Failed: {data['failed']}",
        f"- Average score: {data['avg_score']:.2f}",
        f"- Average latency: {data['avg_latency_seconds']:.3f}s",
        "",
        "## Results",
        "",
    ]
    for row in rows:
        status = "PASS" if row.get("ok") else "FAIL"
        lines.extend(
            [
                f"### {row.get('id', '')}: {status}",
                "",
                f"- Latency: {float(row.get('latency_seconds', 0.0)):.3f}s",
                f"- Score: `{int(row.get('score', 0))}`",
                f"- Schema: `{row.get('schema', '') or 'none'}`",
                f"- Source: `{row.get('source', '') or 'unknown'}`",
            ]
        )
        if row.get("missing_terms"):
            lines.append("- Missing terms: `%s`" % ", ".join(row["missing_terms"]))
        if row.get("missing_priority_hints"):
            lines.append("- Missing priority hints: `%s`" % ", ".join(row["missing_priority_hints"]))
        if row.get("missing_doctrine_actions"):
            lines.append("- Missing doctrine actions: `%s`" % ", ".join(row["missing_doctrine_actions"]))
        if row.get("forbidden_hits"):
            lines.append("- Forbidden terms: `%s`" % ", ".join(row["forbidden_hits"]))
        if row.get("error"):
            lines.append(f"- Error: `{row.get('error')}`")
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
