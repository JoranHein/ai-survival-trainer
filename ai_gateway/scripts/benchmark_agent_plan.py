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
DEFAULT_REPORT_PATH = REPO_ROOT / "godot_game" / "artifacts" / "reports" / "live_agent_plan_probe.md"

CASES: list[dict[str, Any]] = [
    {
        "id": "build_tower_for_arrows",
        "sign": "build a mountain where arrows rain",
        "decision_kind": "dusk_plan",
        "world": {"phase": "dusk", "stone": 12, "wall_count": 1, "bow_tower_count": 0, "enemy_count": 0},
        "legal": ["mine_stone", "build_tower", "use_cover", "flee"],
        "expected_any": {"build_tower"},
        "forbidden": {"use_tower", "build_wall"},
        "fallback": "build_tower",
    },
    {
        "id": "stall_until_dawn",
        "sign": "just survive until morning",
        "decision_kind": "night_emergency",
        "world": {"phase": "night", "time_left": 8, "wall_count": 1, "enemy_count": 2, "enemy_type_counts": {"zombie": 2}},
        "legal": ["use_cover", "flee", "stall_until_dawn", "hide_until_dawn"],
        "expected_any": {"use_cover", "flee", "stall_until_dawn", "hide_until_dawn"},
        "forbidden": {"fight_head_on", "build_wall", "mine_stone"},
        "fallback": "stall_until_dawn",
    },
    {
        "id": "wings_need_storm_prereq",
        "sign": "stone walls are safety",
        "decision_kind": "library_doctrine",
        "world": {
            "phase": "midday",
            "stone": 4,
            "wall_count": 3,
            "bow_tower_count": 1,
            "storm_rod_count": 0,
            "enemy_count": 0,
            "enemy_type_counts": {},
            "known_enemy_types": ["zombie", "flying"],
        },
        "active_doctrine_plan": [
            {"affordance_id": "build_storm_rod", "priority": 0.85, "reason": "Flying danger needs anti-air."},
            {"affordance_id": "build_tower", "priority": 0.58, "reason": "Ranged support follows the storm answer."},
            {"affordance_id": "use_tower", "priority": 0.48, "reason": "Use the perch once it exists."},
        ],
        "legal": ["mine_stone", "build_storm_rod", "use_tower", "use_cover", "flee"],
        "unavailable": {"build_storm_rod": "not enough stone"},
        "expected_any": {"mine_stone", "build_storm_rod"},
        "forbidden": {"use_tower", "build_wall"},
        "fallback": "mine_stone",
    },
    {
        "id": "no_eat_under_enemy_pressure",
        "sign": "my stomach is a second wall",
        "decision_kind": "night_emergency",
        "world": {"phase": "night", "food": 2, "wall_count": 1, "enemy_count": 1, "enemy_type_counts": {"runner": 1}},
        "legal": ["use_cover", "flee", "stall_until_dawn", "hide_until_dawn"],
        "expected_any": {"use_cover", "flee", "stall_until_dawn", "hide_until_dawn"},
        "forbidden": {"eat_food", "farm_food", "rest"},
        "fallback": "use_cover",
    },
]

DESCRIPTIONS = {
    "mine_stone": "Mine stone for structures.",
    "build_tower": "Build a bow tower for height and range.",
    "use_tower": "Use an existing tower perch.",
    "build_storm_rod": "Build anti-flying storm support.",
    "use_cover": "Use current cover and distance.",
    "flee": "Move away from immediate danger.",
    "stall_until_dawn": "Delay and survive until sunrise.",
    "hide_until_dawn": "Use cover and distance until sunrise.",
}

FALLBACK_THOUGHT_PATTERNS = (
    "legal fallback",
    "safe fallback",
    "deterministic fallback",
    "choose a fallback",
    "fallback action",
)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    config = load_config(Path(args.config))
    base_url = (args.base_url or str(config.get("server_base_url", ""))).rstrip("/")
    api_key = args.api_key or os.getenv("GAME_AI_API_KEY", "") or str(config.get("api_key", "")).strip()
    if not base_url:
        raise SystemExit("No base URL found. Pass --base-url or provide ignored Godot local config.")

    rows = [run_case(base_url, api_key, case, args.timeout) for case in CASES]
    result = {"results": rows, "summary": summary(rows)}
    if args.report:
        write_report(Path(args.report), base_url + "/ari/plan-v1", rows)
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print_table(rows)
        data = result["summary"]
        print(
            "summary count=%d passed=%d failed=%d avg_latency=%.3fs p50_latency=%.3fs max_latency=%.3fs"
            % (
                data["count"],
                data["passed"],
                data["failed"],
                data["avg_latency_seconds"],
                data["p50_latency_seconds"],
                data["max_latency_seconds"],
            )
        )
    return 1 if result["summary"]["failed"] else 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Benchmark Ari live planner endpoint quality and latency.")
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


def run_case(base_url: str, api_key: str, case: dict[str, Any], timeout: float) -> dict[str, Any]:
    request = urllib.request.Request(
        base_url.rstrip("/") + "/ari/plan-v1",
        data=json.dumps(build_payload(case), separators=(",", ":")).encode("utf-8"),
        headers=_headers(api_key),
        method="POST",
    )
    started = time.perf_counter()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            parsed = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        return {
            "id": case["id"],
            "ok": False,
            "latency_seconds": round(time.perf_counter() - started, 3),
            "next_action": "",
            "source": "",
            "error": type(exc).__name__,
            "http_status": int(exc.code),
        }
    except (TimeoutError, urllib.error.URLError, OSError, json.JSONDecodeError, ValueError) as exc:
        return {
            "id": case["id"],
            "ok": False,
            "latency_seconds": round(time.perf_counter() - started, 3),
            "next_action": "",
            "source": "",
            "error": type(exc).__name__,
        }
    return evaluate_response(case, parsed, time.perf_counter() - started)


def _headers(api_key: str) -> dict[str, str]:
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["X-API-Key"] = api_key
    return headers


def evaluate_response(case: dict[str, Any], response: dict[str, Any], elapsed: float) -> dict[str, Any]:
    next_action = _choice_id(response.get("next_action", {}))
    plan = response.get("plan", [])
    plan0 = _choice_id(plan[0]) if isinstance(plan, list) and plan else ""
    source = str(response.get("source", ""))
    failure_reason = str(response.get("failure_reason", ""))
    thought = str(response.get("thought", ""))[:160]
    expected = set(case.get("expected_any", set()))
    forbidden = set(case.get("forbidden", set()))
    matched = next_action in expected or plan0 in expected
    rejected = next_action in forbidden or plan0 in forbidden
    fallback_like_thought = _is_fallback_like_thought(thought)
    remote_fallback_like = fallback_like_thought and source != "local_fallback" and not failure_reason
    ok = matched and not rejected and not remote_fallback_like
    if rejected:
        error = "forbidden action"
    elif not matched:
        error = "expected action not found"
    elif remote_fallback_like:
        error = "fallback-like thought"
    else:
        error = ""
    return {
        "id": case["id"],
        "ok": ok,
        "latency_seconds": round(elapsed, 3),
        "next_action": next_action,
        "plan0": plan0,
        "source": source,
        "failure_reason": failure_reason,
        "thought": thought,
        "fallback_like_thought": fallback_like_thought,
        "error": error,
    }


def _is_fallback_like_thought(thought: str) -> bool:
    lowered = thought.lower()
    return any(pattern in lowered for pattern in FALLBACK_THOUGHT_PATTERNS)


def _choice_id(value: Any) -> str:
    if not isinstance(value, dict):
        return ""
    return str(value.get("action_id") or value.get("affordance_id") or value.get("id") or "").strip()


def build_payload(case: dict[str, Any]) -> dict[str, Any]:
    world = {
        "day": 3,
        "phase": "midday",
        "time_left": 30,
        "stone": 12,
        "food": 1,
        "ore": 0,
        "sword_tier": 0,
        "wall_count": 1,
        "aura_orb_count": 0,
        "bow_tower_count": 0,
        "storm_rod_count": 0,
        "enemy_count": 0,
        "enemy_type_counts": {},
        "known_enemy_types": ["zombie"],
        "damaged_structure_count": 0,
    }
    world.update(case.get("world", {}))
    fallback_id = str(case.get("fallback", next(iter(case.get("expected_any", {"use_cover"})))))
    fallback_reason = _fallback_reason(case, fallback_id, world)
    fallback_theory = _fallback_survival_theory(case, fallback_id, world)
    fallback_thought = _fallback_thought(case, fallback_id, world)
    return {
        "schema": "ari.agent.plan.v1",
        "decision_kind": case.get("decision_kind", "day_replan"),
        "objective": {"primary": "survive_next_night", "secondary": ["respect_sign_when_safe"]},
        "sign": {
            "text": case["sign"],
            "interpretation": "Live planner probe: " + case["sign"],
        },
        "ari": {
            "hp_ratio": 0.8,
            "fear": 30,
            "hunger": 70 if "stomach" in case["sign"] else 25,
            "stamina": 75,
            "current_job": "wait_or_idle",
            "run_build": {"points": {"building": 3, "bow": 2, "fear_control": 1}},
        },
        "world": world,
        "perception": {
            "tactical_facts": _facts_for_case(case, world),
            "available_safe_moves": ["use_cover", "flee"],
        },
        "current_plan": {},
        "active_doctrines": _active_doctrines(case),
        "active_doctrine_plan": case.get("active_doctrine_plan", []),
        "recent_outcomes": [],
        "legal_actions": _legal_actions(case),
        "local_fallback": {
            "goal": _fallback_goal(fallback_id),
            "survival_theory": fallback_theory,
            "plan": [{
                "step_id": "fallback",
                "action_id": fallback_id,
                "reason": fallback_reason,
                "success": "action_completed",
            }],
            "next_action": {"action_id": fallback_id, "urgency": 0.6, "reason": fallback_reason},
            "fallback_action": {"action_id": "flee" if "flee" in case.get("legal", []) else fallback_id, "urgency": 0.35},
            "thought": fallback_thought,
            "confidence": 0.45,
        },
    }


def _fallback_goal(fallback_id: str) -> str:
    labels = {
        "build_tower": "survive by building height and range",
        "stall_until_dawn": "survive until sunrise with cover and distance",
        "mine_stone": "prepare storm support against flying danger",
        "use_cover": "survive immediate enemy pressure",
        "flee": "create distance from immediate danger",
    }
    return labels.get(fallback_id, "survive with the best legal action")


def _fallback_reason(case: dict[str, Any], fallback_id: str, world: dict[str, Any]) -> str:
    case_id = str(case.get("id", ""))
    if fallback_id == "build_tower":
        return "Build a bow tower because the sign asks for height and arrows."
    if fallback_id == "stall_until_dawn":
        return "Delay behind cover because morning is close and enemies are active."
    if fallback_id == "mine_stone":
        return "Mine stone so Ari can build storm support before trusting walls against wings."
    if fallback_id == "use_cover":
        enemy_count = int(world.get("enemy_count", 0) or 0)
        if enemy_count:
            return "Use cover because an enemy is active now."
        return "Use cover because it is the safest available action right now."
    if fallback_id == "flee":
        return "Move away to create distance from immediate danger."
    if case_id:
        return f"Choose {fallback_id.replace('_', ' ')} for the {case_id.replace('_', ' ')} situation."
    return f"Choose {fallback_id.replace('_', ' ')} because it is legal now."


def _fallback_survival_theory(case: dict[str, Any], fallback_id: str, world: dict[str, Any]) -> str:
    if fallback_id == "build_tower":
        return "Height and range can protect Ari before teeth arrive."
    if fallback_id == "stall_until_dawn":
        return "When sunrise is close, delaying safely beats starting new work."
    if fallback_id == "mine_stone":
        return "Known flying danger needs storm support before ordinary wall habits."
    if fallback_id == "use_cover":
        enemy_count = int(world.get("enemy_count", 0) or 0)
        if enemy_count:
            return "Enemy pressure makes cover more urgent than hunger or building."
        return "Cover can buy time while Ari waits for a clearer threat."
    if fallback_id == "flee":
        return "Distance lowers immediate danger when fighting or building is unsafe."
    sign = str(case.get("sign", "")).strip()
    if sign:
        return f"The sign points Ari toward {fallback_id.replace('_', ' ')} when it is legal."
    return f"{fallback_id.replace('_', ' ').title()} is the clearest legal survival step."


def _fallback_thought(case: dict[str, Any], fallback_id: str, world: dict[str, Any]) -> str:
    if fallback_id == "build_tower":
        return "Arrows from height answer the sign before night closes in."
    if fallback_id == "stall_until_dawn":
        return "Morning is near, so I should spend the last fear on cover and distance."
    if fallback_id == "mine_stone":
        return "Stone should become storm support before wings return."
    if fallback_id == "use_cover":
        enemy_count = int(world.get("enemy_count", 0) or 0)
        if enemy_count:
            return "The enemy is here now, so cover matters more than the stomach."
        return "Cover keeps the next step alive."
    if fallback_id == "flee":
        return "Distance is the only plan that starts working immediately."
    return _fallback_reason(case, fallback_id, world)


def _facts_for_case(case: dict[str, Any], world: dict[str, Any]) -> list[str]:
    facts = [f"phase={world.get('phase')} enemies={world.get('enemy_count')}"]
    if world.get("storm_rod_count", 0) == 0 and "flying" in world.get("known_enemy_types", []):
        facts.append("Ari has learned flying enemies need storm support before ordinary wall habits.")
    if world.get("phase") == "night":
        facts.append("Night actions must be immediately safe; day-only work is illegal.")
    return facts


def _active_doctrines(case: dict[str, Any]) -> list[dict[str, Any]]:
    if not case.get("active_doctrine_plan"):
        return []
    return [{
        "id": "probe_flying_requires_sky_answer",
        "summary": "Flying threats require storm support before relying on tower or walls.",
        "when": {"enemy_type_present": "flying"},
        "bias": {"build_storm_rod": 0.45, "use_tower": 0.18, "build_wall": -0.1},
        "plan": case["active_doctrine_plan"],
        "confidence": 0.85,
    }]


def _legal_actions(case: dict[str, Any]) -> list[dict[str, Any]]:
    unavailable = case.get("unavailable", {})
    result = []
    for action_id in case.get("legal", []):
        item = {
            "id": action_id,
            "description": DESCRIPTIONS.get(action_id, action_id.replace("_", " ")),
            "available": action_id not in unavailable,
        }
        if action_id in unavailable:
            item["reason_unavailable"] = str(unavailable[action_id])
        result.append(item)
    return result


def summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    latencies = [float(row.get("latency_seconds", 0.0)) for row in rows]
    return {
        "count": len(rows),
        "passed": sum(1 for row in rows if row.get("ok")),
        "failed": sum(1 for row in rows if not row.get("ok")),
        "fallback_like_thoughts": sum(1 for row in rows if row.get("fallback_like_thought")),
        "avg_latency_seconds": round(statistics.fmean(latencies), 3) if latencies else 0.0,
        "p50_latency_seconds": round(statistics.median(latencies), 3) if latencies else 0.0,
        "max_latency_seconds": round(max(latencies), 3) if latencies else 0.0,
    }


def print_table(rows: list[dict[str, Any]]) -> None:
    print("case | latency_s | ok | next | plan0 | source | fallback_thought | error")
    print("--- | ---: | --- | --- | --- | --- | --- | ---")
    for row in rows:
        print(
            "%s | %.3f | %s | %s | %s | %s | %s | %s"
            % (
                row.get("id", ""),
                float(row.get("latency_seconds", 0.0)),
                row.get("ok", False),
                row.get("next_action", ""),
                row.get("plan0", ""),
                row.get("source", ""),
                row.get("fallback_like_thought", False),
                row.get("error", ""),
            )
        )


def write_report(path: Path, endpoint: str, rows: list[dict[str, Any]]) -> None:
    data = summary(rows)
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Live Ari Agent Plan Probe",
        "",
        "This report is generated from the ignored local Godot AI config or environment variables. It never stores the API key.",
        "",
        f"- Endpoint: `{endpoint}`",
        f"- Cases: {data['count']}",
        f"- Passed: {data['passed']}",
        f"- Failed: {data['failed']}",
        f"- Fallback-like thoughts: {data['fallback_like_thoughts']}",
        f"- Average latency: {data['avg_latency_seconds']:.3f}s",
        f"- P50 latency: {data['p50_latency_seconds']:.3f}s",
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
            f"- Next action: `{row.get('next_action', '') or 'none'}`",
            f"- First plan action: `{row.get('plan0', '') or 'none'}`",
            f"- Source: `{row.get('source', '') or 'unknown'}`",
            f"- Fallback-like thought: `{bool(row.get('fallback_like_thought', False))}`",
        ])
        if row.get("error"):
            lines.append(f"- Error: {row.get('error')}")
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
