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


SIGNS = [
    "stand behind the wall",
    "the circle should eat the dead",
    "the wings do not fear stone",
    "my stomach is a second wall",
]


def main() -> int:
    parser = argparse.ArgumentParser(description="Benchmark Ari AI gateway deep interpretation latency.")
    parser.add_argument("--base-url", default="http://91.99.219.229:8088", help="Gateway base URL.")
    parser.add_argument("--api-key", default="", help="API key. Prefer GAME_AI_API_KEY or local config instead.")
    parser.add_argument("--godot-config", default="godot_game/data/ai_config.local.json", help="Optional ignored Godot AI config.")
    parser.add_argument("--repeat", type=int, default=1, help="Requests per sign.")
    parser.add_argument("--timeout", type=float, default=90.0, help="HTTP timeout seconds.")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of a table.")
    args = parser.parse_args()

    api_key = args.api_key or os.getenv("GAME_AI_API_KEY", "") or _api_key_from_godot_config(Path(args.godot_config))
    if not api_key:
        raise SystemExit("No API key found. Set GAME_AI_API_KEY or provide an ignored Godot local config.")

    rows: list[dict[str, Any]] = []
    for sign in SIGNS:
        for index in range(max(1, args.repeat)):
            rows.append(_run_case(args.base_url.rstrip("/"), api_key, sign, index + 1, args.timeout))

    if args.json:
        print(json.dumps({"results": rows, "summary": _summary(rows)}, indent=2, sort_keys=True))
    else:
        _print_table(rows)
        summary = _summary(rows)
        print()
        print("summary count=%d ok=%d avg_latency=%.2fs p50_latency=%.2fs" % (
            summary["count"],
            summary["ok"],
            summary["avg_latency_seconds"],
            summary["p50_latency_seconds"],
        ))
    return 0


def _api_key_from_godot_config(path: Path) -> str:
    if not path.exists():
        return ""
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    return str(data.get("api_key", "")).strip()


def _run_case(base_url: str, api_key: str, sign: str, repeat_index: int, timeout: float) -> dict[str, Any]:
    payload = _payload_for_sign(sign)
    request = urllib.request.Request(
        base_url + "/ai/deep-interpretation",
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", "X-API-Key": api_key},
        method="POST",
    )
    start = time.perf_counter()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body = response.read()
        elapsed = time.perf_counter() - start
        parsed = json.loads(body)
        plan = parsed.get("grounded_plan") if isinstance(parsed, dict) else []
        top_plan = ""
        if isinstance(plan, list) and plan and isinstance(plan[0], dict):
            top_plan = "%s:%.2f" % (plan[0].get("affordance_id", ""), float(plan[0].get("priority", 0.0)))
        return {
            "sign": sign,
            "repeat": repeat_index,
            "latency_seconds": round(elapsed, 3),
            "parse_success": isinstance(parsed, dict),
            "top_plan": top_plan,
            "survival_theory": str(parsed.get("survival_theory", ""))[:80] if isinstance(parsed, dict) else "",
        }
    except (TimeoutError, urllib.error.URLError, json.JSONDecodeError, ValueError) as exc:
        return {
            "sign": sign,
            "repeat": repeat_index,
            "latency_seconds": round(time.perf_counter() - start, 3),
            "parse_success": False,
            "top_plan": "",
            "error": type(exc).__name__,
        }


def _payload_for_sign(sign: str) -> dict[str, Any]:
    flying = 1 if "wing" in sign else 0
    local_hints: dict[str, float] = {"build_wall": 0.5}
    local_interpretation = "Local fallback reading."
    if "circle" in sign:
        local_hints = {"place_aura_orb": 0.5}
        local_interpretation = "Local reads circle and light."
    elif "wing" in sign:
        local_hints = {"build_storm_rod": 0.6, "anti_flying": 0.6}
        local_interpretation = "Local reads sky danger."
    elif "stomach" in sign:
        local_hints = {"farm_food": 0.6, "build_wall": 0.5}
        local_interpretation = "Local reads food and wall."

    affordances = [
        ("use_existing_wall", "Use an existing wall as cover."),
        ("wait_behind_wall", "Wait behind an existing wall."),
        ("use_cover", "Use cover and distance."),
        ("build_wall", "Build a new wall."),
        ("place_aura_orb", "Build a damaging aura circle."),
        ("lure_to_aura", "Lure enemies into an aura circle."),
        ("build_tower", "Build a bow tower."),
        ("use_tower", "Use an existing tower."),
        ("ranged_attack", "Shoot from range."),
        ("train_bow", "Train bow skill."),
        ("build_storm_rod", "Build anti-flying storm support."),
        ("anti_flying", "Prioritize flying counters."),
        ("sky_answer", "Answer sky threats."),
        ("farm_food", "Grow food."),
        ("eat_food", "Eat stored food."),
        ("eat", "Eat."),
        ("rest", "Rest and recover."),
        ("reflect_library", "Reflect in the library."),
    ]
    return {
        "sign_text": sign,
        "ari": {
            "run_build": {"preset": "Balanced"},
            "hp": 100,
            "max_hp": 100,
            "current_job": "build_wall",
            "current_reason": "Local fallback wants walls",
        },
        "world": {
            "day": 1,
            "phase": "midday",
            "time_left": 24,
            "stone": 25,
            "wall_count": 2,
            "aura_orb_count": 1,
            "enemy_count": 1,
            "enemy_type_counts": {"zombie": 1, "runner": 0, "brute": 0, "flying": flying},
            "known_enemy_types": ["zombie", "flying"] if flying else ["zombie"],
            "structures": [{"type": "wall", "status": "intact"}, {"type": "aura_orb", "status": "intact"}],
        },
        "current_affordances": [
            {"id": affordance_id, "description": description, "available": True}
            for affordance_id, description in affordances
        ],
        "recent_thoughts": ["The wall is not safety anymore."],
        "latest_library_note": "# Day 2\n\nThe flying ones ignored stone." if flying else "",
        "local_fallback": {
            "interpretation": local_interpretation,
            "priority_hints": local_hints,
            "sign_strength": 0.5,
            "resonance": 0.5,
        },
    }


def _summary(rows: list[dict[str, Any]]) -> dict[str, Any]:
    latencies = [float(row["latency_seconds"]) for row in rows if row.get("parse_success")]
    return {
        "count": len(rows),
        "ok": sum(1 for row in rows if row.get("parse_success")),
        "avg_latency_seconds": round(statistics.fmean(latencies), 3) if latencies else 0.0,
        "p50_latency_seconds": round(statistics.median(latencies), 3) if latencies else 0.0,
    }


def _print_table(rows: list[dict[str, Any]]) -> None:
    print("sign | repeat | latency_s | parse_success | top_plan")
    print("--- | ---: | ---: | --- | ---")
    for row in rows:
        print("%s | %d | %.3f | %s | %s" % (
            row["sign"],
            row["repeat"],
            float(row["latency_seconds"]),
            row["parse_success"],
            row.get("top_plan", ""),
        ))


if __name__ == "__main__":
    raise SystemExit(main())
