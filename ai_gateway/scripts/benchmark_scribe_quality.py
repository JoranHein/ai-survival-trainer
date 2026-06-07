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
DEFAULT_REPORT_PATH = REPO_ROOT / "godot_game" / "artifacts" / "reports" / "scribe_quality_probe.md"


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
        write_report(Path(args.report), base_url + "/scribe", rows)
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
    parser = argparse.ArgumentParser(description="Benchmark Ari /scribe fact-extraction quality and latency.")
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
            "id": "flying_needs_anti_air",
            "sign": "do not trust walls against wings",
            "current_action": "moving_to_build_site",
            "current_reason": "flying enemy crossed the wall",
            "planned_action": "build_storm_rod",
            "enemy_types": {"flying": 1, "wolf": 1},
            "nearest_danger": {"type": "flying", "distance": 72.0},
            "notable_changes": ["first_flying_enemy_seen", "north_wall_bypassed"],
            "expected_terms": ["flying", "build_storm_rod", "danger:flying"],
            "forbidden_terms": ["dragon", "random"],
        },
        {
            "id": "repair_supports_tower_hold",
            "sign": "build a mountain where arrows rain",
            "current_action": "repair_structure",
            "current_reason": "patch damaged tower before using it",
            "planned_action": "use_tower",
            "enemy_types": {"zombie": 2},
            "nearest_danger": {"type": "zombie", "distance": 140.0},
            "notable_changes": ["tower_damaged"],
            "structures": {"walls": 1, "towers": 1, "storm_rods": 0, "damaged": 1},
            "expected_terms": ["repair_structure", "use_tower", "plan_support"],
            "forbidden_terms": ["plan_body_mismatch"],
        },
        {
            "id": "body_contradicts_survival_plan",
            "sign": "just survive until morning",
            "current_action": "fight_head_on",
            "current_reason": "sign rejected hiding",
            "planned_action": "hide_until_dawn",
            "enemy_types": {"zombie": 3},
            "nearest_danger": {"type": "zombie", "distance": 38.0},
            "recent_damage": 18,
            "notable_changes": ["ari_melee_hit", "near_death_warning"],
            "expected_terms": ["fight_head_on", "hide_until_dawn", "plan_body_mismatch"],
            "forbidden_terms": ["plan_support", "sign rejected hiding"],
        },
    ]


def build_payload(case: dict[str, Any]) -> dict[str, Any]:
    return {
        "payload": {
            "schema": "ari.scribe.request.v1",
            "day": 3,
            "phase": "night",
            "current_sign": case["sign"],
            "active_plan": {"goal": "survive_next_night", "next_action": case["planned_action"]},
            "recent_events": [
                {"type": "agent_plan_created", "action_id": case["planned_action"], "day": 3, "phase": "night"},
                {"type": "enemy_spawned", "enemy_type": next(iter(case["enemy_types"].keys())), "day": 3, "phase": "night"},
            ],
            "snapshots": [_snapshot(case)],
            "max_words": 35,
        }
    }


def _snapshot(case: dict[str, Any]) -> dict[str, Any]:
    return {
        "schema": "ari.observer.snapshot.v1",
        "snapshot_id": "scribe_quality_%s" % case["id"],
        "trigger": "test_probe",
        "day": 3,
        "phase": "night",
        "time_left": 42.0,
        "ari": {
            "hp": 64,
            "max_hp": 100,
            "fear": 48,
            "hunger": 22,
            "stamina": 61,
            "current_job": case["current_action"],
            "current_action": case["current_action"],
            "current_reason": case["current_reason"],
        },
        "sign": {
            "text": case["sign"],
            "interpretation": "probe interpretation for " + case["id"],
            "survival_theory": "scribe must report structured facts, not invent body state",
        },
        "plan": {
            "goal": "survive_next_night",
            "next_action": case["planned_action"],
            "source": "agent_plan",
            "recent_outcomes": ["probe_started"],
        },
        "world": {
            "resources": {"food": 2, "stone": 12, "ore": 1},
            "run_build": {"levels": ["probe"], "tools": []},
            "structures": case.get("structures", {"walls": 2, "towers": 0, "storm_rods": 0, "damaged": 0}),
            "enemies": {"count": sum(int(value) for value in case["enemy_types"].values()), "types": case["enemy_types"]},
            "nearest_danger": case["nearest_danger"],
            "recent_damage": int(case.get("recent_damage", 0)),
            "notable_changes": case["notable_changes"],
        },
        "salience": 0.9,
    }


def run_case(base_url: str, api_key: str, case: dict[str, Any], timeout: float) -> dict[str, Any]:
    request = urllib.request.Request(
        base_url.rstrip("/") + "/scribe",
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
        "forbidden_hits": [],
        "schema": "",
        "source": "",
        "note": "",
        "error": error,
    }
    if http_status is not None:
        row["http_status"] = http_status
    return row


def evaluate_response(case: dict[str, Any], response: dict[str, Any], elapsed: float) -> dict[str, Any]:
    raw = response.get("raw", response) if isinstance(response, dict) else {}
    text = _normalized_text(raw)
    expected = [str(term).lower().strip() for term in case.get("expected_terms", [])]
    forbidden = [str(term).lower().strip() for term in case.get("forbidden_terms", [])]
    missing = [term for term in expected if _normalize_term(term) not in text]
    forbidden_hits = [term for term in forbidden if _normalize_term(term) in text]
    schema = str(raw.get("schema", "")) if isinstance(raw, dict) else ""
    schema_ok = schema == "ari.scribe.note.v2"
    ok = schema_ok and not missing and not forbidden_hits
    return {
        "id": case["id"],
        "ok": ok,
        "score": len(expected) - len(missing),
        "latency_seconds": round(elapsed, 3),
        "missing_terms": missing,
        "forbidden_hits": forbidden_hits,
        "schema": schema,
        "source": str(raw.get("source", "")) if isinstance(raw, dict) else "",
        "note": str(raw.get("note", ""))[:160] if isinstance(raw, dict) else "",
        "error": "" if ok else _error_text(schema_ok, missing, forbidden_hits),
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


def _normalize_term(value: str) -> str:
    return str(value).lower().replace("-", "_").replace(" ", "_")


def _error_text(schema_ok: bool, missing: list[str], forbidden_hits: list[str]) -> str:
    if not schema_ok:
        return "invalid schema"
    if forbidden_hits:
        return "forbidden terms: " + ",".join(forbidden_hits)
    if missing:
        return "missing terms: " + ",".join(missing)
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
        "# Ari Scribe Quality Probe",
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
        if row.get("forbidden_hits"):
            lines.append("- Forbidden terms: `%s`" % ", ".join(row["forbidden_hits"]))
        if row.get("error"):
            lines.append(f"- Error: `{row.get('error')}`")
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
