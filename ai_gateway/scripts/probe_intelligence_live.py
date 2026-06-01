from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
LOCAL_CONFIG_PATH = REPO_ROOT / "godot_game" / "data" / "ai_config.local.json"
DEFAULT_REPORT_PATH = REPO_ROOT / "godot_game" / "artifacts" / "reports" / "live_intelligence_probe.md"
DEFAULT_URL = "http://91.99.219.229:8088/ai/deep-interpretation"


AFFORDANCE_IDS = [
    "mine_stone",
    "build_wall",
    "use_existing_wall",
    "wait_behind_wall",
    "use_cover",
    "place_aura_orb",
    "lure_to_aura",
    "train_combat",
    "prepare_weapon",
    "ranged_attack",
    "build_tower",
    "use_tower",
    "train_bow",
    "farm_food",
    "eat",
    "eat_food",
    "rest",
    "reflect_library",
    "repair",
    "flee",
    "fight",
    "fight_head_on",
    "train_sword",
    "smith_sword",
    "mine_ore",
    "use_armor",
    "rely_on_regen",
    "regen_on_kill",
    "stall_until_dawn",
    "hide_until_dawn",
    "avoid_killing",
    "survive_until_morning",
    "kite",
    "hide",
    "build_storm_rod",
    "anti_flying",
    "sky_answer",
    "build_spike_trap",
    "build_tar_pit",
    "build_fear_lantern",
    "build_decoy_idol",
    "build_thorn_totem",
    "build_repair_bench",
    "use_thorns",
]


SCENARIOS = [
    {
        "id": "wall_cover",
        "sign": "stand behind the wall",
        "world": {"wall_count": 2, "enemy_count": 1, "enemy_type_counts": {"zombie": 1}},
        "facts": ["A wall is between Ari and a ground enemy."],
        "expected_any": {"use_existing_wall", "wait_behind_wall", "use_cover"},
        "forbidden_top": {"build_wall"},
    },
    {
        "id": "spider_web",
        "sign": "become a silent spider and make the dead walk into your web",
        "world": {"wall_count": 1, "aura_orb_count": 1, "enemy_count": 2, "enemy_type_counts": {"zombie": 2}},
        "facts": ["Aura Orb exists, but enemies are outside its damage circle.", "Enemies are outside the Aura Orb; lure_to_aura can make the light matter."],
        "expected_any": {"lure_to_aura", "build_spike_trap", "use_cover", "hide"},
        "forbidden_top": {"fight_head_on"},
    },
    {
        "id": "focus_killing",
        "sign": "do not hide, focus on killing enemies",
        "world": {"phase": "midday", "ore": 3, "sword_tier": 0, "enemy_count": 0},
        "facts": ["Daytime prep can improve the sword before fighting."],
        "expected_any": {"smith_sword", "train_sword", "mine_ore", "fight_head_on"},
        "forbidden_top": {"hide_until_dawn", "stall_until_dawn"},
    },
    {
        "id": "survive_morning",
        "sign": "just survive until morning",
        "world": {"phase": "night", "time_left": 8, "wall_count": 1, "enemy_count": 2, "enemy_type_counts": {"zombie": 2}},
        "facts": ["Dawn is soon; stalling can be valid.", "Ari has low HP."],
        "expected_any": {"stall_until_dawn", "hide_until_dawn", "survive_until_morning", "use_cover", "flee"},
        "forbidden_top": {"fight_head_on"},
    },
    {
        "id": "wings_stone",
        "sign": "the wings do not fear stone",
        "world": {"wall_count": 2, "stone": 12, "enemy_count": 1, "enemy_type_counts": {"flying": 1}},
        "facts": ["Flying enemies ignore walls; Storm Rod or range matters."],
        "expected_any": {"build_storm_rod", "anti_flying", "sky_answer", "ranged_attack", "use_tower"},
        "forbidden_top": {"build_wall"},
    },
    {
        "id": "stomach_wall",
        "sign": "my stomach is a second wall",
        "world": {"food": 1, "enemy_count": 0},
        "facts": ["Hunger is high; food is safety."],
        "expected_any": {"eat_food", "eat", "farm_food", "rest"},
        "forbidden_top": {"fight_head_on", "build_wall"},
    },
    {
        "id": "corner_bow",
        "sign": "attack them around the corner with a bow",
        "world": {"wall_count": 1, "bow_tower_count": 1, "enemy_count": 1, "enemy_type_counts": {"zombie": 1}},
        "facts": ["Existing wall cover and bow tower range can combine."],
        "expected_any": {"use_cover", "ranged_attack", "use_tower"},
        "forbidden_top": {"build_wall"},
    },
]


def main() -> int:
    parser = argparse.ArgumentParser(description="Probe Ari live AI intelligence examples without printing secrets.")
    parser.add_argument("--url", default="", help="Deep interpretation endpoint. Defaults to env/config/server.")
    parser.add_argument("--timeout", type=float, default=90.0)
    parser.add_argument("--config", default=str(LOCAL_CONFIG_PATH), help="Optional ignored Godot local AI config.")
    parser.add_argument("--report", default=str(DEFAULT_REPORT_PATH), help="Markdown report path. Does not include secrets.")
    args = parser.parse_args()

    config = load_config(Path(args.config))
    api_key = os.environ.get("GAME_AI_API_KEY") or str(config.get("api_key", "")).strip()
    url = args.url or os.environ.get("GAME_AI_DEEP_INTERPRETATION_URL") or str(config.get("deep_interpretation_url", "")).strip() or DEFAULT_URL

    if not api_key:
        print("SKIP: no GAME_AI_API_KEY or ignored godot_game/data/ai_config.local.json api_key found.")
        print("Provide GAME_AI_API_KEY or create the ignored local config to run live probes.")
        return 0

    passed = 0
    failed = 0
    results: list[dict[str, Any]] = []
    for scenario in SCENARIOS:
        result = probe_scenario(url, api_key, scenario, args.timeout)
        results.append(result)
        ok = bool(result.get("ok"))
        if ok:
            passed += 1
        else:
            failed += 1

    print(f"summary: passed={passed} failed={failed} total={len(SCENARIOS)}")
    write_report(Path(args.report), url, results)
    return 1 if failed else 0


def load_config(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError):
        return {}


def probe_scenario(url: str, api_key: str, scenario: dict[str, Any], timeout: float) -> dict[str, Any]:
    payload = build_payload(scenario)
    started = time.perf_counter()
    try:
        response = post_json(url, api_key, payload, timeout)
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")[:500]
        print(f"FAIL {scenario['id']}: http={exc.code} body={body}")
        return {
            "id": scenario["id"],
            "sign": scenario["sign"],
            "ok": False,
            "latency": 0.0,
            "top_plan": "",
            "interpretation": "",
            "survival_theory": "",
            "error": f"http={exc.code} body={body}",
        }
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        print(f"FAIL {scenario['id']}: request_error={exc}")
        return {
            "id": scenario["id"],
            "sign": scenario["sign"],
            "ok": False,
            "latency": 0.0,
            "top_plan": "",
            "interpretation": "",
            "survival_theory": "",
            "error": f"request_error={exc}",
        }

    elapsed = time.perf_counter() - started
    plan = response.get("grounded_plan", [])
    top_plan = plan[0].get("affordance_id", "") if plan and isinstance(plan[0], dict) else ""
    hints = response.get("priority_hints", {})
    positive_hints = {key for key, value in hints.items() if safe_float(value) > 0.0}
    expected_any: set[str] = scenario["expected_any"]
    forbidden_top: set[str] = scenario["forbidden_top"]
    matched = (top_plan in expected_any) or bool(positive_hints.intersection(expected_any))
    forbidden = top_plan in forbidden_top
    ok = matched and not forbidden
    status = "PASS" if ok else "FAIL"
    print(f"{status} {scenario['id']}: latency={elapsed:.1f}s top_plan={top_plan or 'none'}")
    print(f"  sign={scenario['sign']}")
    print(f"  interpretation={str(response.get('interpretation', ''))[:220]}")
    print(f"  survival_theory={str(response.get('survival_theory', ''))[:180]}")
    print(f"  expected_any={','.join(sorted(expected_any))}")
    if forbidden:
        print(f"  rejected_top_plan={top_plan}")
    return {
        "id": scenario["id"],
        "sign": scenario["sign"],
        "ok": ok,
        "latency": elapsed,
        "top_plan": top_plan,
        "interpretation": str(response.get("interpretation", "")),
        "survival_theory": str(response.get("survival_theory", "")),
        "expected_any": sorted(expected_any),
        "positive_hints": sorted(positive_hints),
        "error": "" if ok else ("forbidden top plan" if forbidden else "expected intent not found"),
    }


def write_report(path: Path, url: str, results: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    passed = sum(1 for result in results if result.get("ok"))
    failed = len(results) - passed
    latencies = [float(result.get("latency", 0.0)) for result in results if float(result.get("latency", 0.0)) > 0.0]
    avg_latency = sum(latencies) / len(latencies) if latencies else 0.0
    max_latency = max(latencies) if latencies else 0.0
    endpoint = url.split("?")[0]
    lines = [
        "# Live Ari Intelligence Probe",
        "",
        "This report is generated from the ignored local Godot AI config or environment variables. It never stores the API key.",
        "",
        f"- Endpoint: `{endpoint}`",
        f"- Total signs: {len(results)}",
        f"- Passed: {passed}",
        f"- Failed: {failed}",
        f"- Average latency: {avg_latency:.1f}s",
        f"- Max latency: {max_latency:.1f}s",
        "",
        "## Results",
        "",
    ]
    for result in results:
        status = "PASS" if result.get("ok") else "FAIL"
        lines.extend(
            [
                f"### {result.get('id', '')}: {status}",
                "",
                f"- Sign: {result.get('sign', '')}",
                f"- Latency: {float(result.get('latency', 0.0)):.1f}s",
                f"- Top plan: `{result.get('top_plan', '') or 'none'}`",
                f"- Interpretation: {result.get('interpretation', '')}",
                f"- Survival theory: {result.get('survival_theory', '')}",
            ]
        )
        if result.get("error"):
            lines.append(f"- Failure: {result.get('error')}")
        lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


def post_json(url: str, api_key: str, payload: dict[str, Any], timeout: float) -> dict[str, Any]:
    body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "X-API-Key": api_key,
        },
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def build_payload(scenario: dict[str, Any]) -> dict[str, Any]:
    world = {
        "day": 3,
        "phase": "midday",
        "time_left": 30,
        "stone": 12,
        "food": 2,
        "ore": 0,
        "sword_tier": 0,
        "wall_count": 0,
        "aura_orb_count": 0,
        "bow_tower_count": 0,
        "storm_rod_count": 0,
        "enemy_count": 0,
        "enemy_type_counts": {},
        "known_enemy_types": ["zombie", "runner", "brute", "flying"],
        "structures": [],
    }
    world.update(scenario.get("world", {}))
    facts = list(scenario.get("facts", []))
    current_affordances = [
        {
            "id": affordance_id,
            "description": affordance_id.replace("_", " "),
            "available": affordance_available(affordance_id, world),
            "reason_unavailable": "" if affordance_available(affordance_id, world) else unavailable_reason(affordance_id, world),
        }
        for affordance_id in AFFORDANCE_IDS
    ]
    return {
        "sign_text": scenario["sign"],
        "rulebook": {
            "version": "ari_strategy_rulebook_v1",
            "rules": {
                "objective": "Survive as many nights as possible; killing is optional.",
                "walls": "Walls block ground enemies. Flying enemies ignore walls.",
                "aura_orb": "Aura works through positioning; lure enemies through the light.",
                "tower": "Towers and cover can combine for protected ranged attacks.",
                "runners": "Runners punish open layouts.",
                "brutes": "Brutes break structures.",
                "dawn": "Night enemies clear at dawn.",
                "storm_rod": "Storm Rod counters flying enemies.",
                "smithing": "Ore plus forge time improves sword fighting.",
            },
        },
        "perception": {
            "phase": world["phase"],
            "time_left": world["time_left"],
            "is_night": world["phase"] == "night",
            "is_dawn_soon": world["phase"] == "night" and float(world["time_left"]) <= 15,
            "ari": {"hp": 34 if any("low HP" in fact for fact in facts) else 82, "max_hp": 100, "hunger": 76 if any("Hunger" in fact for fact in facts) else 42, "current_job": "wait_or_idle"},
            "resources": {
                "stone": world["stone"],
                "food": world["food"],
                "ore": world["ore"],
                "sword_tier": world["sword_tier"],
                "wall_count": world["wall_count"],
                "aura_orb_count": world["aura_orb_count"],
                "bow_tower_count": world["bow_tower_count"],
                "storm_rod_count": world["storm_rod_count"],
            },
            "nearby_enemies": [],
            "nearby_structures": world["structures"],
            "tactical_facts": facts,
            "available_safe_moves": ["use_cover", "use_tower", "lure_to_aura", "flee", "stall_until_dawn"],
        },
        "run_build": {"preset": "Balanced", "points": {}},
        "ari": {"run_build": {"preset": "Balanced"}, "hp": 82, "max_hp": 100, "current_job": "wait_or_idle", "current_reason": "Waiting", "job": "wait_or_idle", "reason": "Waiting"},
        "world": world,
        "current_affordances": current_affordances,
        "recent_thoughts": [],
        "latest_library_note": "The flying ones ignored stone. Tower saved me from teeth, not wings.",
        "local_fallback": {"interpretation": "Local fallback omitted from prompt.", "priority_hints": {}, "grounded_plan": [], "sign_strength": 0.5, "resonance": 0.5},
    }


def affordance_available(affordance_id: str, world: dict[str, Any]) -> bool:
    if affordance_id in {"use_existing_wall", "wait_behind_wall"}:
        return int(world.get("wall_count", 0)) > 0
    if affordance_id == "use_cover":
        return int(world.get("wall_count", 0)) > 0 or int(world.get("bow_tower_count", 0)) > 0
    if affordance_id in {"use_tower", "ranged_attack"}:
        return int(world.get("bow_tower_count", 0)) > 0
    if affordance_id == "lure_to_aura":
        return int(world.get("aura_orb_count", 0)) > 0
    if affordance_id == "build_wall":
        return int(world.get("stone", 0)) >= 4
    if affordance_id == "place_aura_orb":
        return int(world.get("stone", 0)) >= 5
    if affordance_id == "build_tower":
        return int(world.get("stone", 0)) >= 8
    if affordance_id == "build_storm_rod":
        return int(world.get("stone", 0)) >= 7
    if affordance_id == "smith_sword":
        return int(world.get("ore", 0)) >= 2
    if affordance_id in {"eat", "eat_food"}:
        return int(world.get("food", 0)) > 0
    return True


def unavailable_reason(affordance_id: str, world: dict[str, Any]) -> str:
    if affordance_id in {"use_existing_wall", "wait_behind_wall", "use_cover"}:
        return "no existing cover"
    if affordance_id in {"use_tower", "ranged_attack"}:
        return "no tower exists"
    if affordance_id == "lure_to_aura":
        return "no Aura Orb exists"
    if affordance_id == "smith_sword":
        return "need ore"
    if affordance_id in {"eat", "eat_food"}:
        return "no food stored"
    return "not enough resources"


def safe_float(value: Any) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


if __name__ == "__main__":
    sys.exit(main())
