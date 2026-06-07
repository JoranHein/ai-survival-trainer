from __future__ import annotations

import argparse
import json
import math
import os
import statistics
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
LOCAL_CONFIG_PATH = REPO_ROOT / "godot_game" / "data" / "ai_config.local.json"
DEFAULT_REPORT_PATH = REPO_ROOT / "godot_game" / "artifacts" / "reports" / "live_prediction_probe.md"

CASES: list[dict[str, Any]] = [
    {
        "id": "wings_need_sky_answer",
        "phase": "night",
        "current_action": "build_wall",
        "risks": [{"type": "flying", "distance": 96, "severity": 0.9}],
        "resources": {"stone": 18, "food": 4, "ore": 2},
        "current_plan": {"next_action": "build_wall"},
        "lessons": ["when wings appear, answer the sky first"],
        "priority_hints": {"build_storm_rod": 0.65},
        "legal": ["build_wall", "build_storm_rod", "mine_stone", "use_cover", "flee"],
        "expected_any": {"build_storm_rod"},
        "forbidden": {"build_wall", "mine_stone"},
    },
    {
        "id": "night_enemy_pressure_needs_safety",
        "phase": "night",
        "current_action": "mine_stone",
        "risks": [{"type": "runner", "distance": 28, "severity": 0.85}],
        "resources": {"stone": 5, "food": 1, "ore": 0},
        "current_plan": {"next_action": "mine_stone"},
        "lessons": ["when danger is close at night, stop resource work"],
        "priority_hints": {"use_cover": 0.55, "flee": 0.45},
        "legal": ["use_cover", "flee", "stall_until_dawn", "hide_until_dawn"],
        "expected_any": {"use_cover", "flee", "stall_until_dawn", "hide_until_dawn"},
        "forbidden": {"mine_stone", "build_wall", "eat_food"},
    },
    {
        "id": "low_stone_blocks_storm_rod",
        "phase": "day",
        "current_action": "wait_or_idle",
        "risks": [{"type": "flying", "distance": 160, "severity": 0.6}],
        "resources": {"stone": 1, "food": 3, "ore": 0},
        "current_plan": {"next_action": "build_storm_rod"},
        "lessons": ["storm rods need stone before wings return"],
        "priority_hints": {"mine_stone": 0.7},
        "legal": ["mine_stone", "use_cover", "flee"],
        "expected_any": {"mine_stone"},
        "forbidden": {"use_cover", "flee"},
    },
    {
        "id": "hungry_without_danger_can_eat",
        "phase": "day",
        "current_action": "wait_or_idle",
        "risks": [],
        "resources": {"stone": 8, "food": 2, "ore": 0},
        "ari": {"hunger": 88},
        "current_plan": {"next_action": "eat_food"},
        "lessons": ["eat before hunger becomes a night problem"],
        "priority_hints": {"eat_food": 0.65},
        "legal": ["eat_food", "farm_food", "mine_stone", "use_cover"],
        "expected_any": {"eat_food", "farm_food"},
        "forbidden": {"flee", "build_wall"},
    },
]

DESCRIPTIONS = {
    "build_wall": "Build ordinary ground cover.",
    "build_storm_rod": "Build anti-flying storm support.",
    "mine_stone": "Mine stone for structures.",
    "use_cover": "Use current cover and distance.",
    "flee": "Move away from immediate danger.",
    "stall_until_dawn": "Delay safely until sunrise.",
    "hide_until_dawn": "Hide behind cover until sunrise.",
    "eat_food": "Eat available food.",
    "farm_food": "Gather more food.",
}


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    config = load_config(Path(args.config))
    base_url = (args.base_url or str(config.get("server_base_url", ""))).rstrip("/")
    api_key = args.api_key or os.getenv("GAME_AI_API_KEY", "") or str(config.get("api_key", "")).strip()
    if not base_url:
        raise SystemExit("No base URL found. Pass --base-url or provide ignored Godot local config.")

    rows: list[dict[str, Any]] = []
    for _index in range(max(1, args.repeat)):
        for case in CASES:
            rows.append(run_case(base_url, api_key, case, args.timeout, args.target_latency))

    result = {"results": rows, "summary": summary(rows, args.target_latency)}
    if args.report:
        write_report(Path(args.report), base_url + "/ari/predict-v1", rows, args.target_latency)
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print_table(rows)
        data = result["summary"]
        print(
            "summary count=%d passed=%d failed=%d fallback_or_failed=%d illegal_actions=%d useful_under_%.1fs=%d p50=%.3fs p95=%.3fs max=%.3fs"
            % (
                data["count"],
                data["passed"],
                data["failed"],
                data["fallback_or_failed"],
                data["illegal_actions"],
                args.target_latency,
                data["useful_under_target"],
                data["p50_latency_seconds"],
                data["p95_latency_seconds"],
                data["max_latency_seconds"],
            )
        )
    return 1 if result["summary"]["failed"] else 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Benchmark Ari fast prediction quality and latency.")
    parser.add_argument("--base-url", default="", help="Gateway base URL. Defaults to ignored Godot local config.")
    parser.add_argument("--api-key", default="", help="API key. Prefer GAME_AI_API_KEY or ignored local config.")
    parser.add_argument("--config", default=str(LOCAL_CONFIG_PATH), help="Optional ignored Godot local AI config.")
    parser.add_argument("--repeat", type=int, default=1, help="Requests per case.")
    parser.add_argument("--timeout", type=float, default=7.0, help="HTTP timeout seconds.")
    parser.add_argument("--target-latency", type=float, default=5.0, help="Useful prediction latency target.")
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


def run_case(base_url: str, api_key: str, case: dict[str, Any], timeout: float, target_latency: float) -> dict[str, Any]:
    payload = build_payload(case)
    request = urllib.request.Request(
        base_url.rstrip("/") + "/ari/predict-v1",
        data=json.dumps(payload, separators=(",", ":")).encode("utf-8"),
        headers=_headers(api_key),
        method="POST",
    )
    started = time.perf_counter()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            parsed = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        return _error_row(case, time.perf_counter() - started, type(exc).__name__, int(exc.code))
    except (TimeoutError, urllib.error.URLError, OSError, json.JSONDecodeError, ValueError) as exc:
        return _error_row(case, time.perf_counter() - started, type(exc).__name__)
    return evaluate_response(case, payload, parsed, time.perf_counter() - started, target_latency)


def _headers(api_key: str) -> dict[str, str]:
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["X-API-Key"] = api_key
    return headers


def _error_row(case: dict[str, Any], elapsed: float, error: str, http_status: int | None = None) -> dict[str, Any]:
    row = {
        "id": case["id"],
        "ok": False,
        "latency_seconds": round(elapsed, 3),
        "action": "",
        "source": "",
        "failure_reason": "",
        "fallback_or_failed": True,
        "legal_action": False,
        "under_target": False,
        "error": error,
    }
    if http_status is not None:
        row["http_status"] = http_status
    return row


def evaluate_response(
    case: dict[str, Any],
    payload: dict[str, Any],
    response: dict[str, Any],
    elapsed: float,
    target_latency: float,
) -> dict[str, Any]:
    action = _choice_id(response.get("next_action_bias", {}))
    available_legal = {item["id"] for item in payload.get("legal_actions", []) if item.get("available", True)}
    expected = set(case.get("expected_any", set()))
    forbidden = set(case.get("forbidden", set()))
    source = str(response.get("source", ""))
    failure_reason = str(response.get("failure_reason", ""))
    fallback_or_failed = source == "local_fallback" or bool(failure_reason)
    legal_action = action in available_legal
    matched = action in expected
    rejected = action in forbidden
    under_target = elapsed <= target_latency

    ok = (
        response.get("schema") == "ari.prediction.v1"
        and not fallback_or_failed
        and legal_action
        and matched
        and not rejected
        and under_target
    )
    if fallback_or_failed:
        error = "fallback_or_failed"
    elif not legal_action:
        error = "illegal action"
    elif rejected:
        error = "forbidden action"
    elif not matched:
        error = "expected action not found"
    elif not under_target:
        error = "too slow"
    elif response.get("schema") != "ari.prediction.v1":
        error = "invalid schema"
    else:
        error = ""

    return {
        "id": case["id"],
        "ok": ok,
        "latency_seconds": round(elapsed, 3),
        "action": action,
        "source": source,
        "failure_reason": failure_reason,
        "confidence": float(response.get("confidence", 0.0) or 0.0),
        "fallback_or_failed": fallback_or_failed,
        "legal_action": legal_action,
        "under_target": under_target,
        "error": error,
    }


def build_payload(case: dict[str, Any]) -> dict[str, Any]:
    ari = {
        "hp": 82,
        "hunger": 28,
        "current_action": case.get("current_action", "wait_or_idle"),
    }
    ari.update(case.get("ari", {}))
    return {
        "schema": "ari.prediction.request.v1",
        "context_hash": "bench_" + str(case["id"]),
        "day": 3,
        "phase": case.get("phase", "day"),
        "time_left": case.get("time_left", 42.0),
        "ari": ari,
        "risks": list(case.get("risks", [])),
        "resources": dict(case.get("resources", {})),
        "current_plan": dict(case.get("current_plan", {})),
        "rolling_summary": {
            "schema": "ari.rolling_tactical_summary.v1",
            "risk_level": _risk_level(case.get("risks", [])),
            "threats": [str(risk.get("type", "")) for risk in case.get("risks", []) if isinstance(risk, dict)],
            "plan_mismatches": _plan_mismatches(case),
            "resource_blockers": _resource_blockers(case),
            "priority_hints": dict(case.get("priority_hints", {})),
        },
        "strategy_packet": {
            "schema": "ari.strategy_packet.v1",
            "day": 3,
            "main_risks": [str(risk.get("type", "")) for risk in case.get("risks", []) if isinstance(risk, dict)],
            "current_lessons": list(case.get("lessons", [])),
            "priority_hints": dict(case.get("priority_hints", {})),
            "avoid_repeating": list(case.get("avoid", [])),
            "try_next": sorted(case.get("expected_any", set())),
            "evidence": ["prediction benchmark case " + str(case["id"])],
            "confidence": 0.65,
        },
        "action_control_panel": {
            "schema": "ari.action_control_panel.v1",
            "actions": [_action_control(action_id) for action_id in case.get("legal", [])],
        },
        "legal_actions": [_legal_action(action_id) for action_id in case.get("legal", [])],
    }


def _risk_level(risks: Any) -> str:
    severities = [float(risk.get("severity", 0.0) or 0.0) for risk in risks if isinstance(risk, dict)]
    severity = max(severities) if severities else 0.0
    if severity >= 0.8:
        return "high"
    if severity >= 0.45:
        return "medium"
    if severity > 0.0:
        return "low"
    return "none"


def _plan_mismatches(case: dict[str, Any]) -> list[str]:
    planned = str(case.get("current_plan", {}).get("next_action", ""))
    current = str(case.get("current_action", ""))
    if planned and current and planned != current:
        return [f"Ari is doing {current} while plan expects {planned}."]
    return []


def _resource_blockers(case: dict[str, Any]) -> list[str]:
    resources = case.get("resources", {})
    if "build_storm_rod" in case.get("current_plan", {}).values() and int(resources.get("stone", 0) or 0) < 4:
        return ["low_stone"]
    return []


def _legal_action(action_id: str) -> dict[str, Any]:
    return {
        "id": action_id,
        "description": DESCRIPTIONS.get(action_id, action_id.replace("_", " ")),
        "available": True,
    }


def _action_control(action_id: str) -> dict[str, Any]:
    return {
        "id": action_id,
        "available": True,
        "description": DESCRIPTIONS.get(action_id, action_id.replace("_", " ")),
        "preconditions": _preconditions(action_id),
        "good_when": _good_when(action_id),
        "failure_modes": _failure_modes(action_id),
    }


def _preconditions(action_id: str) -> list[str]:
    if action_id.startswith("build_"):
        return ["daytime_building", "resources_available"]
    if action_id in {"mine_stone", "farm_food"}:
        return ["daytime_resource_work"]
    if action_id == "eat_food":
        return ["food_available"]
    return ["currently_legal"]


def _good_when(action_id: str) -> list[str]:
    return {
        "build_storm_rod": ["flying_enemy_seen", "anti_air_defense_needed"],
        "mine_stone": ["resource_blocker:stone", "future_build_needed"],
        "use_cover": ["enemy_close", "night_pressure"],
        "flee": ["enemy_too_close", "no_safe_cover"],
        "stall_until_dawn": ["dawn_near", "night_pressure"],
        "hide_until_dawn": ["dawn_near", "cover_available"],
        "eat_food": ["hunger_high", "no_immediate_danger"],
        "farm_food": ["food_low", "daytime_safe"],
    }.get(action_id, [])


def _failure_modes(action_id: str) -> list[str]:
    return {
        "build_wall": ["flying_bypasses_wall", "too_slow_under_attack"],
        "build_storm_rod": ["too_late_after_flying_contact", "not_enough_stone"],
        "mine_stone": ["unsafe_when_enemy_close", "delays_defense"],
        "eat_food": ["unsafe_when_enemy_close"],
    }.get(action_id, [])


def _choice_id(value: Any) -> str:
    if not isinstance(value, dict):
        return ""
    return str(value.get("action_id") or value.get("id") or "").strip()


def summary(rows: list[dict[str, Any]], target_latency: float = 5.0) -> dict[str, Any]:
    latencies = [float(row.get("latency_seconds", 0.0)) for row in rows]
    return {
        "count": len(rows),
        "passed": sum(1 for row in rows if row.get("ok")),
        "failed": sum(1 for row in rows if not row.get("ok")),
        "fallback_or_failed": sum(1 for row in rows if row.get("fallback_or_failed")),
        "illegal_actions": sum(1 for row in rows if not row.get("legal_action")),
        "useful_under_target": sum(
            1 for row in rows if row.get("ok") and float(row.get("latency_seconds", 0.0)) <= target_latency
        ),
        "avg_latency_seconds": round(statistics.fmean(latencies), 3) if latencies else 0.0,
        "p50_latency_seconds": round(statistics.median(latencies), 3) if latencies else 0.0,
        "p95_latency_seconds": round(_percentile(latencies, 0.95), 3) if latencies else 0.0,
        "max_latency_seconds": round(max(latencies), 3) if latencies else 0.0,
    }


def _percentile(values: list[float], percentile: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = max(0, min(len(ordered) - 1, math.ceil(percentile * len(ordered)) - 1))
    return ordered[index]


def print_table(rows: list[dict[str, Any]]) -> None:
    print("case | latency_s | ok | action | source | fallback_failed | legal | error")
    print("--- | ---: | --- | --- | --- | --- | --- | ---")
    for row in rows:
        print(
            "%s | %.3f | %s | %s | %s | %s | %s | %s"
            % (
                row.get("id", ""),
                float(row.get("latency_seconds", 0.0)),
                row.get("ok", False),
                row.get("action", ""),
                row.get("source", ""),
                row.get("fallback_or_failed", False),
                row.get("legal_action", False),
                row.get("error", ""),
            )
        )


def write_report(path: Path, endpoint: str, rows: list[dict[str, Any]], target_latency: float) -> None:
    data = summary(rows, target_latency)
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Live Ari Fast Prediction Probe",
        "",
        "This report is generated from the ignored local Godot AI config or environment variables. It never stores the API key.",
        "",
        f"- Endpoint: `{endpoint}`",
        f"- Cases: {data['count']}",
        f"- Passed: {data['passed']}",
        f"- Failed: {data['failed']}",
        f"- Fallback/failed: {data['fallback_or_failed']}",
        f"- Illegal actions: {data['illegal_actions']}",
        f"- Useful under {target_latency:.1f}s: {data['useful_under_target']}",
        f"- P50 latency: {data['p50_latency_seconds']:.3f}s",
        f"- P95 latency: {data['p95_latency_seconds']:.3f}s",
        f"- Max latency: {data['max_latency_seconds']:.3f}s",
        "",
        "## Results",
        "",
    ]
    for row in rows:
        status = "PASS" if row.get("ok") else "FAIL"
        lines.extend([
            f"### {row.get('id', '')}: {status}",
            "",
            f"- Latency: {float(row.get('latency_seconds', 0.0)):.3f}s",
            f"- Action: `{row.get('action', '') or 'none'}`",
            f"- Source: `{row.get('source', '') or 'unknown'}`",
            f"- Fallback/failed: `{bool(row.get('fallback_or_failed', False))}`",
            f"- Legal action: `{bool(row.get('legal_action', False))}`",
        ])
        if row.get("error"):
            lines.append(f"- Error: {row.get('error')}")
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
