from __future__ import annotations

import argparse
import json
import os
import socket
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from ai_gateway.app.schemas import (
    BackgroundJobRequest,
    PredictionRequest,
    deterministic_scribe_response,
    fallback_background_job_response,
    fallback_prediction_response,
    sanitize_background_job_response,
    sanitize_prediction_response,
)


def main() -> int:
    args = _parse_args(sys.argv[1:])
    repo_root = Path(__file__).resolve().parents[1]
    host = "127.0.0.1"
    port = _free_port(host)
    ScriptedGatewayHandler.reset_metrics()
    ScriptedGatewayHandler.plan_log_enabled = bool(args.plan_log or _truthy(os.environ.get("ARI_PLAN_LOG", "")))
    server = ThreadingHTTPServer((host, port), ScriptedGatewayHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    env = os.environ.copy()
    env["ARI_TEST_GATEWAY_URL"] = f"http://{host}:{port}"
    command = [
        "powershell",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(repo_root / "tools" / "run_godot.ps1"),
        "--headless",
        "--script",
        "res://tests/remote_smart_agent_playtest.gd",
    ]
    try:
        _apply_filter_env(env, args)
        completed = subprocess.run(command, cwd=repo_root, env=env, check=False)
        _print_gateway_summary()
        return int(completed.returncode)
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2.0)


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run Godot remote smart-agent playtests against a scripted local gateway.")
    parser.add_argument("--scenario", default="", help="Run one scenario id from remote_smart_agent_playtest.gd.")
    parser.add_argument("--trace", action="store_true", help="Print periodic Godot trace lines for the selected scenario.")
    parser.add_argument("--plan-log", action="store_true", help="Print one compact line for each planner request.")
    parser.add_argument("--scribe-log", action="store_true", help="Print compact structured SCRIBE JSON lines from Godot.")
    return parser.parse_args(argv)


def _apply_filter_env(env: dict[str, str], args: argparse.Namespace) -> None:
    scenario = str(getattr(args, "scenario", "") or "").strip()
    if scenario:
        env["ARI_REMOTE_SCENARIO"] = scenario
    if bool(getattr(args, "trace", False)):
        env["ARI_TRACE_REMOTE"] = "1"
        if scenario:
            env["ARI_TRACE_SCENARIO"] = scenario
    if bool(getattr(args, "plan_log", False)):
        env["ARI_PLAN_LOG"] = "1"
    if bool(getattr(args, "scribe_log", False)):
        env["ARI_SCRIBE_LOG"] = "1"


def _print_gateway_summary() -> None:
    counts = ScriptedGatewayHandler.call_counts
    latencies = ScriptedGatewayHandler.latencies_ms
    print(
        "Scripted gateway calls: deep=%d plan=%d prediction=%d scribe=%d reflection=%d background=%d plan_triggers=%s avg_ms=%s"
        % (
            counts.get("deep", 0),
            counts.get("plan", 0),
            counts.get("prediction", 0),
            counts.get("scribe", 0),
            counts.get("library_reflection", 0),
            counts.get("background_job", 0),
            json.dumps(dict(sorted(ScriptedGatewayHandler.plan_triggers.items())), sort_keys=True),
            json.dumps({key: _avg(values) for key, values in latencies.items() if values}, sort_keys=True),
        )
    )


def _avg(values: list[int]) -> int:
    return int(sum(values) / len(values)) if values else 0


class ScriptedGatewayHandler(BaseHTTPRequestHandler):
    call_counts: dict[str, int] = {
        "deep": 0,
        "plan": 0,
        "prediction": 0,
        "scribe": 0,
        "library_reflection": 0,
        "background_job": 0,
    }
    latencies_ms: dict[str, list[int]] = {
        "deep": [],
        "plan": [],
        "prediction": [],
        "scribe": [],
        "library_reflection": [],
        "background_job": [],
    }
    plan_triggers: dict[str, int] = {}
    plan_log_enabled = False
    plan_call_index = 0

    @classmethod
    def reset_metrics(cls) -> None:
        cls.call_counts = {
            "deep": 0,
            "plan": 0,
            "prediction": 0,
            "scribe": 0,
            "library_reflection": 0,
            "background_job": 0,
        }
        cls.latencies_ms = {
            "deep": [],
            "plan": [],
            "prediction": [],
            "scribe": [],
            "library_reflection": [],
            "background_job": [],
        }
        cls.plan_triggers = {}
        cls.plan_call_index = 0
        cls.plan_log_enabled = False

    def log_message(self, _format: str, *_args: Any) -> None:
        return

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send_json({"ok": True, "source": "scripted_gateway"})
            return
        self._send_json({"error": "not found"}, status=404)

    def do_POST(self) -> None:
        started = time.perf_counter()
        payload = self._read_json()
        if self.path == "/ai/deep-interpretation":
            self._record_call("deep", started)
            self._send_json(_deep_response(payload))
            return
        if self.path == "/ari/plan-v1":
            _record_plan_trigger(payload)
            self._record_call("plan", started)
            response = _plan_response(payload)
            if self.plan_log_enabled:
                type(self).plan_call_index += 1
                print(_plan_log_line(type(self).plan_call_index, payload, response), flush=True)
            self._send_json(response)
            return
        if self.path == "/ari/predict-v1":
            self._record_call("prediction", started)
            self._send_json(_prediction_response(payload))
            return
        if self.path == "/scribe":
            self._record_call("scribe", started)
            self._send_json({"raw": _scribe_response(payload.get("payload", payload))})
            return
        if self.path == "/library-reflection":
            self._record_call("library_reflection", started)
            self._send_json({"raw": _library_reflection_response(payload.get("payload", payload))})
            return
        if self.path == "/background-job":
            self._record_call("background_job", started)
            self._send_json({"raw": _background_job_response(payload.get("payload", payload))})
            return
        self._send_json({"error": "not found"}, status=404)

    def _record_call(self, name: str, started: float) -> None:
        self.call_counts[name] = self.call_counts.get(name, 0) + 1
        self.latencies_ms.setdefault(name, []).append(int((time.perf_counter() - started) * 1000))

    def _read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("Content-Length", "0") or "0")
        body = self.rfile.read(length)
        if not body:
            return {}
        parsed = json.loads(body.decode("utf-8"))
        return parsed if isinstance(parsed, dict) else {}

    def _send_json(self, data: dict[str, Any], status: int = 200) -> None:
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def _record_plan_trigger(payload: dict[str, Any]) -> None:
    trigger = _plan_trigger_key(payload)
    ScriptedGatewayHandler.plan_triggers[trigger] = ScriptedGatewayHandler.plan_triggers.get(trigger, 0) + 1


def _plan_trigger_key(payload: dict[str, Any]) -> str:
    trigger = str(payload.get("trigger", "") if isinstance(payload, dict) else "").strip()
    return trigger or "unknown"


def _plan_log_line(call_index: int, payload: dict[str, Any], response: dict[str, Any]) -> str:
    world = payload.get("world", {})
    world = world if isinstance(world, dict) else {}
    ari = payload.get("ari", {})
    ari = ari if isinstance(ari, dict) else {}
    current_plan = payload.get("current_plan", {})
    current_plan = current_plan if isinstance(current_plan, dict) else {}
    active_doctrine_plan = payload.get("active_doctrine_plan", [])
    if not isinstance(active_doctrine_plan, list):
        active_doctrine_plan = []
    return (
        "PLAN %03d trigger=%s kind=%s day=%s phase=%s action=%s job=%s hp=%s enemy=%s types=%s "
        "res=stone:%s/ore:%s struct=wall:%s/tower:%s/storm:%s damaged=%d current=%s age=%ss src=%s legal=%d doctrine=%d"
        % (
            call_index,
            _plan_trigger_key(payload),
            _field(payload, "decision_kind", "unknown"),
            _field(world, "day", "?"),
            _field(world, "phase", "?"),
            _action_choice_id(response.get("next_action", {})),
            _field(ari, "current_job", "?"),
            _compact_number(ari.get("hp", "?")),
            _field(world, "enemy_count", 0),
            _format_enemy_types(world.get("enemy_type_counts", {})),
            _field(world, "stone", 0),
            _field(world, "ore", 0),
            _field(world, "wall_count", 0),
            _field(world, "bow_tower_count", 0),
            _field(world, "storm_rod_count", 0),
            _damaged_structure_count(world),
            _format_current_plan(current_plan),
            _compact_number(current_plan.get("age_seconds", 0.0)),
            _field(current_plan, "source", "unknown"),
            len(_legal_actions(payload)),
            len(active_doctrine_plan),
        )
    )


def _field(data: dict[str, Any], key: str, fallback: Any) -> str:
    value = data.get(key, fallback)
    text = str(value).strip()
    return text if text else str(fallback)


def _format_enemy_types(value: Any) -> str:
    if not isinstance(value, dict) or not value:
        return "none"
    parts: list[str] = []
    for key in sorted(value.keys()):
        count = value.get(key, 0)
        try:
            clean_count = int(count or 0)
        except (TypeError, ValueError):
            clean_count = 0
        if clean_count > 0:
            parts.append("%s:%d" % (str(key).strip(), clean_count))
    return ",".join(parts) if parts else "none"


def _format_current_plan(value: dict[str, Any]) -> str:
    action = str(value.get("current_action", "") or "").strip() or "none"
    try:
        step_index = int(value.get("step_index", 0) or 0)
    except (TypeError, ValueError):
        step_index = 0
    try:
        step_count = int(value.get("step_count", 0) or 0)
    except (TypeError, ValueError):
        step_count = 0
    return "%s[%d/%d]" % (action, step_index, step_count)


def _damaged_structure_count(world: dict[str, Any]) -> int:
    raw_count = world.get("damaged_structure_count")
    if raw_count is not None:
        try:
            return max(0, int(raw_count or 0))
        except (TypeError, ValueError):
            return 0
    structures = world.get("structures", [])
    if not isinstance(structures, list):
        return 0
    damaged = 0
    for item in structures:
        if not isinstance(item, dict):
            continue
        status = str(item.get("status", "")).strip().lower()
        if status in {"damaged", "broken", "destroyed"}:
            damaged += 1
    return damaged


def _compact_number(value: Any) -> str:
    try:
        numeric = float(value)
    except (TypeError, ValueError):
        return str(value)
    if numeric.is_integer():
        return str(int(numeric))
    return ("%.1f" % numeric).rstrip("0").rstrip(".")


def _action_choice_id(value: Any) -> str:
    if not isinstance(value, dict):
        return ""
    return str(value.get("action_id") or value.get("id") or "").strip()


def _truthy(value: str) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def _deep_response(payload: dict[str, Any]) -> dict[str, Any]:
    sign = str(payload.get("sign_text", "")).lower()
    hints: dict[str, float] = {}
    plan: list[dict[str, Any]] = []
    if _has_any(sign, ["wing", "wings", "sky", "flying", "storm"]):
        hints["build_storm_rod"] = 0.95
        plan.append(_grounded("build_storm_rod", 0.95, "Wings ignore walls; answer the sky."))
    elif _has_any(sign, ["arrow", "arrows", "bow", "mountain", "tower"]):
        hints["build_tower"] = 0.95
        hints["range"] = 0.85
        plan.append(_grounded("build_tower", 0.95, "Height keeps teeth below Ari."))
    elif _has_any(sign, ["light", "circle", "mud", "slow"]):
        hints["aura_orb"] = 0.9
        hints["build_tar_pit"] = 0.88
        plan.append(_grounded("aura_orb", 0.9, "Light damages them before Ari has to."))
        plan.append(_grounded("build_tar_pit", 0.82, "Slow ground buys time."))
    elif _has_any(sign, ["ore", "blade", "sword", "metal"]):
        hints["smith_sword"] = 0.92
        hints["mine_ore"] = 0.82
        hints["train_sword"] = 0.55
        plan.append(_grounded("smith_sword", 0.92, "A better blade makes contact less desperate."))
    else:
        hints["build_wall"] = 0.7
        plan.append(_grounded("build_wall", 0.7, "Default to cover before night."))
    return {
        "interpretation": "The scripted remote mind reads the sign as a survival plan.",
        "thought": "I can turn the sign into steps I can actually do.",
        "survival_theory": "remote_scripted_survival",
        "emotion": "focused",
        "grounded_plan": plan[:4],
        "priority_hints": hints,
        "sign_strength": 0.9,
        "resonance": 0.85,
    }


def _plan_response(payload: dict[str, Any]) -> dict[str, Any]:
    legal = _legal_actions(payload)
    sign_data = payload.get("sign", {})
    sign = str(sign_data.get("text", "") if isinstance(sign_data, dict) else "").lower()
    world = payload.get("world", {})
    world = world if isinstance(world, dict) else {}
    ari = payload.get("ari", {})
    ari = ari if isinstance(ari, dict) else {}
    doctrine_action = _active_doctrine_action(payload, legal)
    action = doctrine_action or _choose_action(sign, world, legal, ari)
    fallback = _first_legal(legal, ["use_cover", "hide", "flee", "mine_stone"])
    plan = [_step(action, _reason_for(action))] if action else []
    reason = _reason_for(action)
    if doctrine_action:
        reason = "Active doctrine selected %s before the sign habit." % action
    return {
        "schema": "ari.agent.plan.v1",
        "goal": "survive_next_night",
        "survival_theory": "Use only legal actions, replan when resources change, and keep Ari alive.",
        "plan": plan,
        "next_action": {"action_id": action, "urgency": 0.95, "reason": reason} if action else {},
        "fallback_action": {"action_id": fallback, "urgency": 0.35, "reason": "Fallback remains legal if the plan stalls."} if fallback else {},
        "belief_updates": [{"key": "remote_plan_pressure", "delta": 0.25, "reason": "The sign became a legal survival step."}],
        "thought": _thought_for(action),
        "confidence": 0.88,
        "replan_after_seconds": 3.0,
    }


def _scribe_response(payload: dict[str, Any]) -> dict[str, Any]:
    raw = deterministic_scribe_response(payload)
    raw["source"] = "scripted_gateway"
    return raw


def _prediction_response(payload: dict[str, Any]) -> dict[str, Any]:
    request = PredictionRequest(**payload)
    fallback = fallback_prediction_response(request)
    raw = dict(fallback)
    raw["source"] = "scripted_gateway"
    raw["failure_reason"] = ""
    risks = payload.get("risks", [])
    risk_text = json.dumps(risks).lower() if isinstance(risks, list) else ""
    rolling_summary = payload.get("rolling_summary", {})
    rolling_text = json.dumps(rolling_summary).lower() if isinstance(rolling_summary, dict) else ""
    if "flying" in risk_text or "flying" in rolling_text or "wing" in rolling_text:
        raw["prediction"] = "Flying or wing danger is present, so Ari should answer the sky before ordinary walls."
        raw["priority_hints"] = _merge_hint_dicts(raw.get("priority_hints", {}), {"build_storm_rod": 0.8, "build_tower": 0.35})
    elif "runner" in risk_text or "runner" in rolling_text:
        raw["prediction"] = "Fast ground danger is close, so Ari should bias toward cover, distance, or tower safety."
        raw["priority_hints"] = _merge_hint_dicts(raw.get("priority_hints", {}), {"use_cover": 0.45, "flee": 0.3})
    return sanitize_prediction_response(raw, fallback, request)


def _background_job_response(payload: dict[str, Any]) -> dict[str, Any]:
    request = BackgroundJobRequest(**payload)
    fallback = fallback_background_job_response(request)
    raw = dict(fallback)
    raw["status"] = "ok"
    raw["source"] = "scripted_gateway"
    raw["failure_reason"] = ""
    raw["notes"] = _background_notes_from_payload(payload)
    strategy_packet = raw.get("strategy_packet", {})
    if isinstance(strategy_packet, dict):
        strategy_packet = dict(strategy_packet)
        hints = dict(strategy_packet.get("priority_hints", {}) if isinstance(strategy_packet.get("priority_hints", {}), dict) else {})
        summary = payload.get("payload", {}).get("rolling_summary", {}) if isinstance(payload.get("payload", {}), dict) else {}
        summary_text = json.dumps(summary).lower() if isinstance(summary, dict) else ""
        if "flying" in summary_text or "wing" in summary_text:
            hints["build_storm_rod"] = max(float(hints.get("build_storm_rod", 0.0) or 0.0), 0.72)
        strategy_packet["priority_hints"] = hints
        raw["strategy_packet"] = strategy_packet
        raw["priority_hints"] = hints
    raw["confidence"] = max(float(raw.get("confidence", 0.0) or 0.0), 0.45)
    return sanitize_background_job_response(raw, fallback, request)


def _background_notes_from_payload(payload: dict[str, Any]) -> list[str]:
    inner = payload.get("payload", {})
    inner = inner if isinstance(inner, dict) else {}
    summary = inner.get("rolling_summary", {})
    summary = summary if isinstance(summary, dict) else {}
    threats = summary.get("threats", [])
    mismatches = summary.get("plan_mismatches", [])
    notes: list[str] = []
    threat_text = ", ".join(str(item) for item in threats[:3]) if isinstance(threats, list) else ""
    mismatch_text = str(mismatches[0]) if isinstance(mismatches, list) and mismatches else ""
    if threat_text:
        notes.append("Background noticed current threat pressure: %s." % threat_text)
    if mismatch_text:
        notes.append("Background preserved plan mismatch evidence: %s" % mismatch_text)
    if not notes:
        notes.append("Background kept the latest strategy packet warm for planning.")
    return notes[:3]


def _merge_hint_dicts(base: Any, extra: dict[str, float]) -> dict[str, float]:
    merged: dict[str, float] = {}
    if isinstance(base, dict):
        for key, value in base.items():
            try:
                merged[str(key)] = float(value)
            except (TypeError, ValueError):
                continue
    for key, value in extra.items():
        merged[key] = max(float(merged.get(key, 0.0)), float(value))
    return merged


def _library_reflection_response(payload: dict[str, Any]) -> dict[str, Any]:
    notes = payload.get("scribe_notes", [])
    text = json.dumps(notes).lower() if isinstance(notes, list) else ""
    snapshots = payload.get("snapshots", [])
    snapshot_text = json.dumps(snapshots).lower() if isinstance(snapshots, list) else ""
    has_flying = "flying" in text or "flying" in snapshot_text
    if has_flying:
        return {
            "schema": "ari.night_reflection.v1",
            "title": "Wings Over Stone",
            "markdown": "Ari saw that wings changed the rules. Walls helped less, so the next plan should answer the sky first.",
            "hypothesis": "Flying enemies need anti-air priority before ordinary wall stacking.",
            "what_changed": ["flying enemies appeared"],
            "worked": ["structured scribe notes preserved the danger"],
            "went_wrong": ["ordinary wall thinking was not enough"],
            "misunderstood": ["Ari treated sky danger like ground danger"],
            "lesson": "When wings appear, build the sky answer before extra walls, then add ranged support.",
            "priority_hints": {"build_storm_rod": 0.85, "build_tower": 0.55, "use_tower": 0.45},
            "belief_updates": [{"key": "wings_ignore_walls", "delta": 0.35, "reason": "Scribe notes reported flying danger."}],
            "doctrines": [{
                "id": "scripted_wings_need_sky_answer",
                "summary": "Flying threats should push Ari toward storm rods or range before more walls.",
                "when": {"enemy_type_present": "flying"},
                "bias": {"build_storm_rod": 0.45, "build_tower": 0.24, "use_tower": 0.18, "build_wall": -0.1},
                "plan": [
                    {"affordance_id": "build_storm_rod", "priority": 0.85, "reason": "Sky danger needs anti-air."},
                    {"affordance_id": "build_tower", "priority": 0.58, "reason": "After the storm answer, ranged support keeps Ari away from wings."},
                    {"affordance_id": "use_tower", "priority": 0.48, "reason": "Use the ranged perch once it exists."},
                ],
                "confidence": 0.85,
            }],
            "thought": "Wings do not respect the same fear-lines as teeth.",
            "confidence": 0.85,
            "source": "scripted_gateway",
        }
    return {
        "schema": "ari.night_reflection.v1",
        "title": "The Day's Useful Shape",
        "markdown": "Ari kept compact notes about what he tried and what danger changed. The next plan should favor what the notes showed working.",
        "hypothesis": "Structured notes make future planning less vague.",
        "what_changed": ["Ari recorded actions and dangers"],
        "worked": ["facts survived into reflection"],
        "went_wrong": [],
        "misunderstood": [],
        "lesson": "Use the latest structured facts before generic habits.",
        "priority_hints": {"use_cover": 0.2},
        "belief_updates": [{"key": "structured_notes_help", "delta": 0.2, "reason": "Reflection received factual scribe notes."}],
        "doctrines": [],
        "thought": "I can remember the shape of the day.",
        "confidence": 0.75,
        "source": "scripted_gateway",
    }


def _choose_action(sign: str, world: dict[str, Any], legal: set[str], ari: dict[str, Any]) -> str:
    stone = int(world.get("stone", 0) or 0)
    wall_count = int(world.get("wall_count", 0) or 0)
    aura_count = int(world.get("aura_orb_count", 0) or 0)
    tower_count = int(world.get("bow_tower_count", 0) or 0)
    storm_count = int(world.get("storm_rod_count", 0) or 0)
    sword_tier = int(world.get("sword_tier", 0) or 0)
    enemy_count = int(world.get("enemy_count", 0) or 0)
    enemy_type_counts = world.get("enemy_type_counts", {})
    enemy_type_counts = enemy_type_counts if isinstance(enemy_type_counts, dict) else {}
    runner_count = int(enemy_type_counts.get("runner", 0) or 0)
    brute_count = int(enemy_type_counts.get("brute", 0) or 0)
    phase = str(world.get("phase", "")).lower()
    hp = float(ari.get("hp", 100.0) or 0.0)
    max_hp = max(float(ari.get("max_hp", 100.0) or 100.0), 1.0)
    hp_ratio = hp / max_hp
    combat_stats = ari.get("combat_stats", {})
    combat_stats = combat_stats if isinstance(combat_stats, dict) else {}
    combat_level = float(combat_stats.get("combat_level", 0.0) or 0.0)
    if _has_any(sign, ["wing", "wings", "sky", "flying", "storm"]):
        if storm_count < 1:
            return _first_legal(legal, ["build_storm_rod", "mine_stone", "build_tower", "flee", "use_cover"])
        if tower_count < 1 and phase != "night":
            return _first_legal(legal, ["build_tower", "mine_stone", "flee", "use_cover"])
        if tower_count > 0:
            return _first_legal(legal, ["use_tower", "ranged_attack", "flee", "use_cover"])
        return _first_legal(legal, ["flee", "hide_until_dawn", "use_cover"])
    if _has_any(sign, ["light", "circle", "mud", "slow"]):
        if enemy_count > 0 or phase == "night":
            if aura_count > 0:
                return _first_legal(legal, ["lure_to_aura", "use_cover", "flee", "hide_until_dawn"])
            if wall_count > 0:
                return _first_legal(legal, ["use_cover", "hide_until_dawn", "flee", "kite"])
            return _first_legal(legal, ["flee", "kite", "use_cover"])
        if aura_count < 1:
            return _first_legal(legal, ["place_aura_orb", "mine_stone", "build_wall", "flee"])
        if not _has_structure(world, "tar_pit"):
            return _first_legal(legal, ["build_tar_pit", "mine_stone", "lure_to_aura", "use_cover"])
        if aura_count < 2:
            return _first_legal(legal, ["place_aura_orb", "mine_stone", "lure_to_aura", "use_cover"])
        return _first_legal(legal, ["lure_to_aura", "use_cover", "flee"])
    if _has_any(sign, ["ore", "blade", "sword", "metal"]):
        if sword_tier < 1:
            return _first_legal(legal, ["smith_sword", "mine_ore", "train_sword", "build_wall", "flee"])
        dangerous_group = enemy_count >= 2 or runner_count > 0 or brute_count > 0
        if enemy_count > 0 and (hp_ratio < 0.55 or dangerous_group):
            return _first_legal(legal, ["use_cover", "flee", "fight_head_on"])
        if enemy_count > 0:
            return _first_legal(legal, ["fight_head_on", "use_cover", "flee"])
        if phase != "night" and wall_count < 1:
            return _first_legal(legal, ["build_wall", "mine_stone", "rest", "train_sword"])
        if phase != "night" and hp_ratio < 0.65:
            return _first_legal(legal, ["rest", "eat_food", "use_cover", "train_sword"])
        return _first_legal(legal, ["train_sword", "mine_ore", "build_wall"])
    if _has_any(sign, ["arrow", "arrows", "bow", "mountain", "tower"]):
        if enemy_count > 0:
            if tower_count > 0:
                return _first_legal(legal, ["use_tower", "use_cover", "flee", "hide_until_dawn"])
            return _first_legal(legal, ["use_cover", "hide_until_dawn", "flee", "kite"])
        if phase == "night":
            if tower_count > 0:
                return _first_legal(legal, ["use_tower", "use_cover", "hide_until_dawn", "flee"])
            return _first_legal(legal, ["use_cover", "hide_until_dawn", "flee", "kite"])
        if tower_count < 1:
            return _first_legal(legal, ["build_tower", "mine_stone", "build_wall", "flee"])
        if combat_level < 1.1:
            return _first_legal(legal, ["train_combat", "use_tower", "use_cover"])
        if tower_count < 2:
            return _first_legal(legal, ["build_tower", "mine_stone", "use_tower", "use_cover"])
        if wall_count < 1:
            return _first_legal(legal, ["build_wall", "mine_stone", "use_tower", "use_cover"])
        return _first_legal(legal, ["use_tower", "train_combat", "use_cover"])
    if stone < 4:
        return _first_legal(legal, ["mine_stone", "flee"])
    return _first_legal(legal, ["build_wall", "use_cover", "mine_stone", "flee"])


def _active_doctrine_action(payload: dict[str, Any], legal: set[str]) -> str:
    plan = payload.get("active_doctrine_plan", [])
    if not isinstance(plan, list):
        plan = []
    world = payload.get("world", {})
    world = world if isinstance(world, dict) else {}
    plan_action_ids = [_plan_action_id(item) for item in plan if isinstance(item, dict)]
    prerequisite = _doctrine_prerequisite_action(world, legal, plan_action_ids)
    if prerequisite:
        return prerequisite
    candidates: list[tuple[float, str]] = []
    for item in plan:
        if not isinstance(item, dict):
            continue
        action_id = _plan_action_id(item)
        if action_id in legal and not _doctrine_step_satisfied(action_id, world, plan_action_ids):
            candidates.append((float(item.get("priority") or item.get("urgency") or 0.0), action_id))
    candidates.sort(reverse=True)
    return candidates[0][1] if candidates else ""


def _doctrine_prerequisite_action(world: dict[str, Any], legal: set[str], plan_action_ids: list[str]) -> str:
    if "build_storm_rod" in plan_action_ids and _world_count(world, "storm_rod_count", "storm_rods") <= 0:
        return _first_legal(legal, ["build_storm_rod", "mine_stone"])
    if (
        "build_tower" in plan_action_ids
        and ("use_tower" in plan_action_ids or "ranged_attack" in plan_action_ids)
        and _world_count(world, "bow_tower_count", "tower_count", "towers") <= 0
    ):
        return _first_legal(legal, ["build_tower", "mine_stone"])
    if "place_aura_orb" in plan_action_ids and "lure_to_aura" in plan_action_ids and _world_count(world, "aura_orb_count", "aura_orbs") <= 0:
        return _first_legal(legal, ["place_aura_orb", "mine_stone"])
    return ""


def _plan_action_id(item: dict[str, Any]) -> str:
    return str(item.get("affordance_id") or item.get("action_id") or item.get("id") or "").strip()


def _doctrine_step_satisfied(action_id: str, world: dict[str, Any], plan_action_ids: list[str]) -> bool:
    if action_id == "build_storm_rod":
        return _world_count(world, "storm_rod_count", "storm_rods") > 0
    if action_id == "build_tower":
        has_tower_followup = "use_tower" in plan_action_ids or "ranged_attack" in plan_action_ids
        return has_tower_followup and _world_count(world, "bow_tower_count", "tower_count", "towers") > 0
    return False


def _world_count(world: dict[str, Any], *keys: str) -> int:
    for key in keys:
        if key in world:
            try:
                return int(world.get(key) or 0)
            except (TypeError, ValueError):
                return 0
    structures = world.get("structures", {})
    if isinstance(structures, dict):
        for key in keys:
            if key in structures:
                try:
                    return int(structures.get(key) or 0)
                except (TypeError, ValueError):
                    return 0
    return 0


def _legal_actions(payload: dict[str, Any]) -> set[str]:
    result: set[str] = set()
    for action in payload.get("legal_actions", []):
        if not isinstance(action, dict):
            continue
        if action.get("available") is False:
            continue
        action_id = str(action.get("id") or action.get("action_id") or "").strip()
        if action_id:
            result.add(action_id)
    return result


def _has_structure(world: dict[str, Any], structure_type: str) -> bool:
    for item in world.get("structures", []):
        if isinstance(item, dict) and str(item.get("type", "")) == structure_type:
            return True
    return False


def _first_legal(legal: set[str], candidates: list[str]) -> str:
    for candidate in candidates:
        if candidate in legal:
            return candidate
    return next(iter(legal), "")


def _grounded(action: str, priority: float, reason: str) -> dict[str, Any]:
    return {"affordance_id": action, "priority": priority, "reason": reason}


def _step(action: str, reason: str) -> dict[str, Any]:
    return {"step_id": f"do_{action}", "action_id": action, "reason": reason, "success": "action_completed"}


def _reason_for(action: str) -> str:
    return {
        "mine_stone": "Stone is needed before the sign can become structure.",
        "build_tower": "Height and range answer the sign.",
        "use_tower": "The tower is ready; use the range.",
        "place_aura_orb": "Light should damage enemies before Ari touches them.",
        "build_tar_pit": "Slow ground buys Ari time.",
        "lure_to_aura": "Pull enemies through the light.",
        "build_storm_rod": "Flying enemies need a sky answer.",
        "mine_ore": "Ore comes before the blade.",
        "smith_sword": "Forge the blade before direct danger.",
        "fight_head_on": "Ari has the blade plan; use it when danger arrives.",
        "train_sword": "Practice the blade plan before night.",
        "build_wall": "Cover is the safest first layer.",
        "use_cover": "Use existing cover.",
        "flee": "Distance is the fallback.",
    }.get(action, "Choose the legal action that best preserves Ari.")


def _thought_for(action: str) -> str:
    return {
        "mine_stone": "I need stone before the sign can become real.",
        "build_tower": "If death has to climb, I get time.",
        "place_aura_orb": "The light can hurt them before I do.",
        "build_tar_pit": "The ground can slow their teeth.",
        "build_storm_rod": "The wings need an answer above the wall.",
        "mine_ore": "Stone is not enough for a blade.",
        "smith_sword": "A blade makes contact less desperate.",
        "fight_head_on": "I can risk contact now.",
    }.get(action, "I will follow the legal step I can do now.")


def _has_any(text: str, needles: list[str]) -> bool:
    return any(needle in text for needle in needles)


def _free_port(host: str) -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind((host, 0))
        return int(sock.getsockname()[1])


if __name__ == "__main__":
    raise SystemExit(main())
