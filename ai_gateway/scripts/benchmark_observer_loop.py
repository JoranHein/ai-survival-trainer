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


def main() -> int:
    parser = argparse.ArgumentParser(description="Benchmark Ari observer scribe/reflection gateway latency.")
    parser.add_argument("--base-url", default="", help="Gateway base URL. Defaults to ignored Godot local config.")
    parser.add_argument("--api-key", default="", help="API key. Prefer GAME_AI_API_KEY or ignored local config.")
    parser.add_argument("--godot-config", default="godot_game/data/ai_config.local.json", help="Optional ignored Godot AI config.")
    parser.add_argument("--repeat", type=int, default=1, help="Requests per endpoint.")
    parser.add_argument("--timeout", type=float, default=5.0, help="HTTP timeout seconds.")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of a table.")
    args = parser.parse_args()

    config = _load_godot_config(Path(args.godot_config))
    base_url = (args.base_url or str(config.get("server_base_url", "")) or _base_from_deep_url(config)).rstrip("/")
    api_key = args.api_key or os.getenv("GAME_AI_API_KEY", "") or str(config.get("api_key", "")).strip()
    if not base_url:
        raise SystemExit("No base URL found. Pass --base-url or provide ignored Godot local config.")

    openapi_paths = _fetch_openapi_paths(base_url, api_key, args.timeout)
    rows: list[dict[str, Any]] = []
    for _index in range(max(1, args.repeat)):
        for case in _cases():
            rows.append(_run_case(base_url, api_key, case, args.timeout))

    output = {"results": rows, "summary": _summary(rows, openapi_paths)}
    if args.json:
        print(json.dumps(output, indent=2, sort_keys=True))
    else:
        _print_table(rows)
        summary = output["summary"]
        print()
        print(
            "summary count=%d ok=%d avg_latency=%.3fs p50_latency=%.3fs missing=%s"
            % (
                summary["count"],
                summary["ok"],
                summary["avg_latency_seconds"],
                summary["p50_latency_seconds"],
                ",".join(summary.get("missing_endpoints", [])),
            )
        )
    return 0 if output["summary"]["ok"] == output["summary"]["count"] else 1


def _load_godot_config(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8-sig"))


def _base_from_deep_url(config: dict[str, Any]) -> str:
    deep_url = str(config.get("deep_interpretation_url", "")).strip()
    return deep_url.removesuffix("/ai/deep-interpretation")


def _cases() -> list[dict[str, Any]]:
    return [
        {
            "name": "scribe",
            "endpoint": "/scribe",
            "body": {"payload": _scribe_payload()},
        },
        {
            "name": "library_reflection",
            "endpoint": "/library-reflection",
            "body": {"payload": _reflection_payload()},
        },
    ]


def _run_case(base_url: str, api_key: str, case: dict[str, Any], timeout: float) -> dict[str, Any]:
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["X-API-Key"] = api_key
    request = urllib.request.Request(
        base_url + case["endpoint"],
        data=json.dumps(case["body"]).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    start = time.perf_counter()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read()
        elapsed = time.perf_counter() - start
        parsed = json.loads(body)
        raw = parsed.get("raw", {}) if isinstance(parsed, dict) else {}
        ok = isinstance(raw, dict) and str(raw.get("schema", "")).startswith("ari.")
        return {
            "endpoint": case["endpoint"],
            "latency_seconds": round(elapsed, 3),
            "ok": ok,
            "schema": str(raw.get("schema", "")) if isinstance(raw, dict) else "",
            "source": str(raw.get("source", "")) if isinstance(raw, dict) else "",
            "title": str(raw.get("title", raw.get("note", "")))[:80] if isinstance(raw, dict) else "",
        }
    except urllib.error.HTTPError as exc:
        return {
            "endpoint": case["endpoint"],
            "latency_seconds": round(time.perf_counter() - start, 3),
            "ok": False,
            "schema": "",
            "source": "",
            "title": "",
            "error": type(exc).__name__,
            "http_status": int(exc.code),
        }
    except (TimeoutError, urllib.error.URLError, OSError, json.JSONDecodeError, ValueError) as exc:
        return {
            "endpoint": case["endpoint"],
            "latency_seconds": round(time.perf_counter() - start, 3),
            "ok": False,
            "schema": "",
            "source": "",
            "title": "",
            "error": type(exc).__name__,
        }


def _fetch_openapi_paths(base_url: str, api_key: str, timeout: float) -> set[str]:
    headers = {}
    if api_key:
        headers["X-API-Key"] = api_key
    request = urllib.request.Request(base_url + "/openapi.json", headers=headers, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=min(max(timeout, 1.0), 15.0)) as response:
            parsed = json.loads(response.read())
    except (TimeoutError, urllib.error.HTTPError, urllib.error.URLError, OSError, json.JSONDecodeError, ValueError):
        return set()
    paths = parsed.get("paths", {}) if isinstance(parsed, dict) else {}
    if not isinstance(paths, dict):
        return set()
    return {str(path) for path in paths.keys()}


def _summary(rows: list[dict[str, Any]], openapi_paths: set[str] | None = None) -> dict[str, Any]:
    latencies = [float(row["latency_seconds"]) for row in rows if row.get("ok")]
    summary = {
        "count": len(rows),
        "ok": sum(1 for row in rows if row.get("ok")),
        "avg_latency_seconds": round(statistics.fmean(latencies), 3) if latencies else 0.0,
        "p50_latency_seconds": round(statistics.median(latencies), 3) if latencies else 0.0,
        "missing_endpoints": [],
    }
    if openapi_paths:
        required = {str(row.get("endpoint", "")) for row in rows if str(row.get("endpoint", "")).strip()}
        summary["missing_endpoints"] = sorted(required - openapi_paths)
    return summary


def _print_table(rows: list[dict[str, Any]]) -> None:
    print("endpoint | latency_s | ok | http | schema | source | title")
    print("--- | ---: | --- | ---: | --- | --- | ---")
    for row in rows:
        print(
            "%s | %.3f | %s | %s | %s | %s | %s"
            % (
                row["endpoint"],
                float(row["latency_seconds"]),
                row["ok"],
                row.get("http_status", ""),
                row.get("schema", ""),
                row.get("source", ""),
                row.get("title", ""),
            )
        )


def _scribe_payload() -> dict[str, Any]:
    return {
        "schema": "ari.scribe.request.v1",
        "day": 3,
        "phase": "night",
        "current_sign": "do not trust walls against wings",
        "active_plan": {"goal": "survive_next_night", "next_action": "build_storm_rod"},
        "recent_events": [{"type": "enemy_spawned", "enemy_type": "flying", "day": 3, "phase": "night"}],
        "snapshots": [_observer_snapshot()],
        "max_words": 35,
    }


def _reflection_payload() -> dict[str, Any]:
    return {
        "schema": "ari.night_reflection.request.v1",
        "trigger": "dawn_survived",
        "day": 3,
        "outcome": "survived",
        "sign": {
            "text": "do not trust walls against wings",
            "interpretation": "answer flying danger before ordinary walls",
        },
        "snapshots": [_observer_snapshot()],
        "recent_events": [{"type": "enemy_spawned", "enemy_type": "flying", "day": 3, "phase": "night"}],
        "scribe_notes": [
            {
                "schema": "ari.scribe.note.v2",
                "note": "Ari saw wings near weak walls.",
                "facts": ["Flying enemies were present; ordinary walls may not solve them."],
                "actions": [{"action": "build_wall", "status": "failed", "reason": "ordinary cover did not answer wings"}],
                "dangers": [{"type": "flying", "distance": 96.0, "severity": 0.9}],
                "world_changes": ["first_flying_enemy_seen"],
                "priority_hints": {"build_storm_rod": 0.7},
                "plan_alignment": "mismatch",
                "immediate_risk": "high",
                "risk_reason": "Flying enemies can bypass ordinary wall safety.",
                "resource_blockers": [],
                "mistake_candidates": ["ordinary wall thinking did not answer wings"],
                "opportunity_candidates": ["build storm rod before ordinary wall work"],
                "lesson_candidates": ["when wings appear, answer the sky first"],
                "confidence": 0.8,
                "salience": 0.9,
            }
        ],
        "active_doctrines": [],
        "agent_plan_outcomes": [{"action_id": "build_wall", "outcome": "near_death"}],
        "latest_lifetime_notes": [],
        "max_words": 160,
    }


def _observer_snapshot() -> dict[str, Any]:
    return {
        "schema": "ari.observer.snapshot.v1",
        "snapshot_id": "day3_0125_enemy_spawned",
        "trigger": "enemy_spawned",
        "day": 3,
        "phase": "night",
        "time_left": 84.5,
        "ari": {
            "hp": 72,
            "max_hp": 100,
            "fear": 42,
            "hunger": 31,
            "stamina": 77,
            "current_job": "build_wall",
            "current_action": "moving_to_build_site",
            "current_reason": "flying enemy near crops",
        },
        "sign": {
            "text": "do not trust walls against wings",
            "interpretation": "prepare anti-flying defense",
            "survival_theory": "height and storm matter against flying threats",
        },
        "plan": {
            "goal": "survive_next_night",
            "next_action": "build_storm_rod",
            "source": "agent_plan",
            "recent_outcomes": ["built_wall"],
        },
        "world": {
            "resources": {"food": 4, "stone": 18, "ore": 2},
            "run_build": {"levels": ["tower_1"], "tools": ["bow"]},
            "structures": {"walls": 6, "towers": 1, "storm_rods": 0, "damaged": 2},
            "enemies": {"count": 3, "types": {"wolf": 2, "flying": 1}},
            "nearest_danger": {"type": "flying", "distance": 96.0},
            "recent_damage": 8,
            "notable_changes": ["first_flying_enemy_seen", "north_wall_damaged"],
        },
        "salience": 0.9,
    }


if __name__ == "__main__":
    raise SystemExit(main())
