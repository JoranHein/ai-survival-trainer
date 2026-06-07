#!/usr/bin/env python3
"""Summarize compact Ari planner logs from scripted playtests."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any


PLAN_RE = re.compile(
    r"PLAN\s+(?P<n>\d+)\s+"
    r"trigger=(?P<trigger>\S+)\s+"
    r"kind=(?P<kind>\S+)\s+"
    r"day=(?P<day>\d+)\s+"
    r"phase=(?P<phase>\S+)\s+"
    r"action=(?P<action>\S+)\s+"
    r"job=(?P<job>\S+).*?"
    r"enemy=(?P<enemy>\d+)\s+"
    r"types=(?P<types>\S+).*?"
    r"struct=wall:(?P<wall>\d+)/tower:(?P<tower>\d+)/storm:(?P<storm>\d+)\s+"
    r"damaged=(?P<damaged>\d+).*?"
    r"current=(?P<current>\S+).*?"
    r"(?:src=(?P<src>\S+)\s+)?"
    r"legal=(?P<legal>\d+)\s+"
    r"doctrine=(?P<doctrine>\d+)"
)

REMOTE_PROMPT_RE = re.compile(
    r"Remote prompt (?P<prompt>[^:]+):\s+"
    r"source=(?P<source>\S+)\s+"
    r"next=(?P<next_action>\S+)\s+"
    r"status=.*?\bday=(?P<day>\d+)\s+"
    r"phase=(?P<phase>\S+)\s+"
    r"alive=(?P<alive>true|false)\s+"
    r"hp=(?P<hp>-?\d+(?:\.\d+)?)\s+"
    r"min_hp=(?P<min_hp>-?\d+(?:\.\d+)?).*?"
    r"\bwalls=(?P<walls>\d+/\d+)\s+"
    r"aura=(?P<aura>\d+/\d+)\s+"
    r"tower=(?P<tower>\d+/\d+)\s+"
    r"tar=(?P<tar>\d+/\d+)\s+"
    r"storm=(?P<storm>\d+/\d+).*?"
    r"\bscribe=(?P<scribe>\d+)\s+"
    r"structured=(?P<structured>\d+)\s+"
    r"reflections=(?P<reflections>\d+)\s+"
    r"doctrine_reflections=(?P<doctrine_reflections>\d+)\s+"
    r"doctrine_plans=(?P<doctrine_plans>\d+)\s+"
    r"sign=\"(?P<sign>.*)\""
)

AI_TEXT_REQUEST_START_RE = re.compile(
    r"AI (?P<label>deep|prediction|background job|agent plan) request start "
    r"endpoint=(?P<endpoint>\S+)"
    r"(?: kind=(?P<job_kind>\S+))?\s+"
    r"timeout=(?P<timeout>\d+(?:\.\d+)?)s\s+"
    r"bytes=(?P<bytes>\d+)"
)

AI_TEXT_REQUEST_DONE_RE = re.compile(
    r"AI (?P<label>deep|prediction|background job|agent plan) request done "
    r"endpoint=(?P<endpoint>\S+)\s+"
    r"result=(?P<result>-?\d+)\s+"
    r"http=(?P<http>-?\d+)\s+"
    r"latency_ms=(?P<latency>\d+)\s+"
    r"status=(?P<status>\S+)"
)

AI_TEXT_REQUEST_START_FAILED_RE = re.compile(
    r"AI (?P<label>deep|agent plan) request start failed "
    r"endpoint=(?P<endpoint>\S+)\s+"
    r"error=(?P<error>-?\d+)"
)

SCRIBE_PREFIX = "SCRIBE "
AI_METRIC_PREFIX = "AI_METRIC "
DAY_SUMMARY_PREFIX = "DAY_SUMMARY "
LEARNING_TRACE_PREFIX = "LEARNING_TRACE "

DAY_ONLY_ACTIONS = {
    "mine_stone",
    "mine_ore",
    "build_wall",
    "place_aura_orb",
    "build_tower",
    "build_storm_rod",
    "build_spike_trap",
    "build_tar_pit",
    "build_fear_lantern",
    "build_decoy_idol",
    "build_thorn_totem",
    "build_repair_bench",
    "train_combat",
    "train_sword",
    "train_bow",
    "prepare_weapon",
    "smith_sword",
    "farm_food",
    "repair",
    "repair_structure",
    "rest",
    "reflect_library",
}

NON_EXECUTABLE_PLAN_ACTIONS = {
    "anti_flying",
    "anti_air_defense",
    "avoid_killing",
    "eat",
    "fight",
    "hide",
    "kite",
    "prepare_weapon",
    "ranged_attack",
    "regen_on_kill",
    "rely_on_regen",
    "repair",
    "sky_answer",
    "survive_until_morning",
    "train_bow",
    "use_armor",
    "use_existing_wall",
    "wait_behind_wall",
}


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    text = _read_log_text(Path(args.log_path))
    summary = analyze_text(text)
    forbidden_phrase_hits = _forbidden_phrase_hits(text, args.forbid_phrase)
    if args.forbid_phrase:
        summary["forbidden_phrase_hits"] = forbidden_phrase_hits
    if args.json:
        print(json.dumps(summary, indent=2, sort_keys=True))
    else:
        print_text_summary(summary)
    if args.fail_on_illegal_night and summary["night_illegal_actions"]:
        return 2
    if args.fail_on_non_executable and summary["non_executable_plan_actions"]:
        return 3
    if args.fail_without_learning_evidence and not summary["learning_evidence"]:
        return 4
    if args.fail_without_smart_loop_evidence and not summary["smart_loop_evidence"]["passed"]:
        return 9
    if args.fail_without_real_model_smart_loop and not summary["real_model_smart_loop_evidence"]["passed"]:
        return 11
    if args.min_real_model_prediction_ratio >= 0.0 and summary["real_model_prediction_ratio"] < args.min_real_model_prediction_ratio:
        return 12
    if args.min_real_model_ai_ratio >= 0.0 and summary["real_model_ai_ratio"] < args.min_real_model_ai_ratio:
        return 13
    if args.fail_on_scripted_evidence and summary["scripted_evidence_count"] > 0:
        return 14
    if args.max_planner_calls >= 0 and summary["planner_calls"] > args.max_planner_calls:
        return 5
    if _trigger_budget_exceeded(summary["trigger_counts"], args.max_trigger_count):
        return 6
    if args.fail_without_structured_scribe and summary["structured_scribe_logs"] <= 0:
        return 7
    if forbidden_phrase_hits:
        return 8
    if args.max_agent_plan_payload_bytes >= 0 and summary["max_agent_plan_payload_bytes"] > args.max_agent_plan_payload_bytes:
        return 10
    return 0


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Analyze tools/run_scripted_remote_agent_playtest.py --plan-log output.")
    parser.add_argument("log_path")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--fail-on-illegal-night", action="store_true")
    parser.add_argument("--fail-on-non-executable", action="store_true")
    parser.add_argument("--fail-without-learning-evidence", action="store_true")
    parser.add_argument("--fail-without-smart-loop-evidence", action="store_true")
    parser.add_argument("--fail-without-real-model-smart-loop", action="store_true")
    parser.add_argument("--fail-without-structured-scribe", action="store_true")
    parser.add_argument("--fail-on-scripted-evidence", action="store_true")
    parser.add_argument("--min-real-model-ai-ratio", type=float, default=-1.0)
    parser.add_argument("--min-real-model-prediction-ratio", type=float, default=-1.0)
    parser.add_argument("--max-planner-calls", type=int, default=-1)
    parser.add_argument("--max-agent-plan-payload-bytes", type=int, default=-1)
    parser.add_argument("--max-trigger-count", action="append", default=[], help="Trigger budget in trigger=count form.")
    parser.add_argument("--forbid-phrase", action="append", default=[], help="Fail if this case-insensitive phrase appears in the log.")
    return parser.parse_args(argv)


def _trigger_budget_exceeded(trigger_counts: dict[str, int], budgets: list[str]) -> bool:
    for budget in budgets:
        if "=" not in budget:
            return True
        trigger, raw_limit = budget.split("=", 1)
        trigger = trigger.strip()
        try:
            limit = int(raw_limit)
        except ValueError:
            return True
        if int(trigger_counts.get(trigger, 0)) > limit:
            return True
    return False


def analyze_file(path: Path) -> dict[str, Any]:
    return analyze_text(_read_log_text(path))


def _forbidden_phrase_hits(text: str, phrases: list[str]) -> list[str]:
    lowered = text.lower()
    hits: list[str] = []
    for phrase in phrases:
        normalized = str(phrase).strip().lower()
        if normalized and normalized in lowered and normalized not in hits:
            hits.append(normalized)
    return hits


def _read_log_text(path: Path) -> str:
    data = path.read_bytes()
    if data.startswith((b"\xff\xfe", b"\xfe\xff")):
        return data.decode("utf-16", errors="replace")
    if data.count(b"\x00") > max(8, len(data) // 20):
        return data.decode("utf-16", errors="replace")
    return data.decode("utf-8", errors="replace")


def analyze_text(text: str) -> dict[str, Any]:
    lines = text.splitlines()
    rows = [row for row in (_parse_plan_line(line) for line in lines) if row]
    scenario_statuses = [row for row in (_parse_remote_prompt_line(line) for line in lines) if row]
    scribe_logs, malformed_scribe_logs = _parse_scribe_log_lines(lines)
    ai_metrics, malformed_ai_metric_logs = _parse_ai_request_metric_lines(lines)
    day_summary_logs, malformed_day_summary_logs = _parse_day_summary_lines(lines)
    learning_trace_logs, malformed_learning_trace_logs = _parse_learning_trace_lines(lines)
    learning_evidence = _learning_evidence(scenario_statuses)
    trigger_counts = Counter(row["trigger"] for row in rows)
    phase_counts = Counter(row["phase"] for row in rows)
    phase_trigger_counts = Counter(f"{row['phase']}:{row['trigger']}" for row in rows)
    action_counts = Counter(row["action"] for row in rows)
    structured_mismatches = sum(1 for row in scribe_logs if "plan_body_mismatch" in row["tags"])
    structured_supports = sum(1 for row in scribe_logs if "plan_support" in row["tags"])
    human_mismatches = _count_human_scribe_notes(lines, "while plan expected")
    human_supports = _count_human_scribe_notes(lines, "supporting plan")
    scribe_decision_grade_notes = sum(1 for row in scribe_logs if _scribe_is_decision_grade(row))
    scribe_phase_dominated_notes = _count_phase_dominated_scribe_notes(lines, scribe_logs)
    ai_start_rows = [row for row in ai_metrics if row["event"] in {"start", "metric"}]
    ai_done_rows = [row for row in ai_metrics if row["event"] in {"done", "metric"}]
    prediction_rows = [row for row in ai_done_rows if row["kind"] == "prediction"]
    prediction_fallback_or_failed = sum(1 for row in prediction_rows if _is_prediction_fallback_or_failed(row))
    real_model_prediction_ok_under_5s = sum(1 for row in prediction_rows if _is_real_model_prediction_ok_under_5s(row))
    complete_learning_traces = sum(1 for row in learning_trace_logs if _is_complete_learning_trace(row))
    successful_learning_traces = sum(1 for row in learning_trace_logs if _is_successful_learning_trace(row))
    real_model_learning_traces = sum(1 for row in learning_trace_logs if _source_class(row.get("source", "")) == "real_model")
    source_class_counts = {
        "ai_request": _source_class_counter(ai_done_rows),
        "prediction": _source_class_counter(prediction_rows),
        "scribe": _source_class_counter(scribe_logs),
        "day_summary": _source_class_counter(day_summary_logs),
        "learning_trace": _source_class_counter(learning_trace_logs),
        "plan": _source_class_counter(rows),
        "scenario": _source_class_counter(scenario_statuses),
    }
    real_model_ai_done = int(source_class_counts["ai_request"].get("real_model", 0))
    real_model_ai_ratio = round(real_model_ai_done / len(ai_done_rows), 3) if ai_done_rows else 0.0
    real_model_prediction_ratio = round(real_model_prediction_ok_under_5s / len(prediction_rows), 3) if prediction_rows else 0.0
    scripted_evidence_count = sum(
        int(source_class_counts[key].get("scripted", 0))
        for key in ("ai_request", "scribe", "day_summary", "learning_trace", "plan", "scenario")
    )
    illegal_night = [
        {
            "plan_number": row["plan_number"],
            "phase": row["phase"],
            "action": row["action"],
            "job": row["job"],
            "trigger": row["trigger"],
        }
        for row in rows
        if row["phase"] == "night" and (row["action"] in DAY_ONLY_ACTIONS or row["job"] in DAY_ONLY_ACTIONS)
    ]
    non_executable = [
        {
            "plan_number": row["plan_number"],
            "phase": row["phase"],
            "action": row["action"],
            "job": row["job"],
            "trigger": row["trigger"],
        }
        for row in rows
        if row["action"] in NON_EXECUTABLE_PLAN_ACTIONS
    ]
    summary = {
        "planner_calls": len(rows),
        "trigger_counts": dict(sorted(trigger_counts.items())),
        "phase_counts": dict(sorted(phase_counts.items())),
        "phase_trigger_counts": dict(sorted(phase_trigger_counts.items())),
        "action_counts": dict(sorted(action_counts.items())),
        "scribe_body_plan_mismatches": max(structured_mismatches, human_mismatches),
        "scribe_plan_supports": max(structured_supports, human_supports),
        "structured_scribe_logs": len(scribe_logs),
        "malformed_scribe_logs": malformed_scribe_logs,
        "structured_scribe_with_facts": sum(1 for row in scribe_logs if row["facts"]),
        "structured_scribe_with_actions": sum(1 for row in scribe_logs if row["actions"]),
        "structured_scribe_with_dangers": sum(1 for row in scribe_logs if row["dangers"]),
        "structured_scribe_with_priority_hints": sum(1 for row in scribe_logs if row["priority_hints"]),
        "structured_scribe_plan_mismatch_tags": structured_mismatches,
        "structured_scribe_plan_support_tags": structured_supports,
        "structured_scribe_sources": dict(sorted(Counter(row["source"] for row in scribe_logs).items())),
        "scribe_decision_grade_notes": scribe_decision_grade_notes,
        "scribe_phase_dominated_notes": scribe_phase_dominated_notes,
        "ai_request_counts": dict(sorted(Counter(row["kind"] for row in ai_start_rows).items())),
        "ai_request_done_counts": dict(sorted(Counter(row["kind"] for row in ai_done_rows).items())),
        "ai_request_status_counts": _ai_status_counts(ai_done_rows),
        "ai_request_start_failures": sum(1 for row in ai_metrics if row["event"] == "start_failed"),
        "malformed_ai_metric_logs": malformed_ai_metric_logs,
        "prediction_calls": len(prediction_rows),
        "prediction_ok_under_5s": sum(1 for row in prediction_rows if _is_prediction_ok_under_5s(row)),
        "real_model_prediction_ok_under_5s": real_model_prediction_ok_under_5s,
        "prediction_fallback_or_failed": prediction_fallback_or_failed,
        "prediction_slow_or_failed": prediction_fallback_or_failed + sum(
            1 for row in prediction_rows if _is_prediction_ok(row) and int(row.get("latency_ms", 0)) > 5000
        ),
        "source_class_counts": source_class_counts,
        "real_model_ai_ratio": real_model_ai_ratio,
        "real_model_prediction_ratio": real_model_prediction_ratio,
        "scripted_evidence_count": scripted_evidence_count,
        "max_agent_plan_payload_bytes": max(
            (int(row.get("bytes", 0)) for row in ai_start_rows if row["kind"] == "agent_plan"),
            default=0,
        ),
        "old_timeout_request_starts": sum(1 for row in ai_start_rows if float(row.get("timeout_s", 0.0)) >= 45.0),
        "max_timeout_seconds": max((float(row.get("timeout_s", 0.0)) for row in ai_start_rows), default=0.0),
        "day_summary_logs": len(day_summary_logs),
        "malformed_day_summary_logs": malformed_day_summary_logs,
        "day_summaries_with_evidence": sum(1 for row in day_summary_logs if row["evidence_ids"]),
        "day_summaries_with_lessons": sum(1 for row in day_summary_logs if row["candidate_lessons"]),
        "learning_trace_logs": len(learning_trace_logs),
        "malformed_learning_trace_logs": malformed_learning_trace_logs,
        "complete_learning_traces": complete_learning_traces,
        "successful_learning_traces": successful_learning_traces,
        "real_model_learning_traces": real_model_learning_traces,
        "doctrine_plan_calls": sum(1 for row in rows if row["doctrine"] > 0),
        "max_plan_doctrine_count": max((row["doctrine"] for row in rows), default=0),
        "scenario_statuses": scenario_statuses,
        "learning_evidence": learning_evidence,
        "night_illegal_actions": illegal_night,
        "non_executable_plan_actions": non_executable,
    }
    summary["smart_loop_evidence"] = _smart_loop_evidence(summary, scenario_statuses)
    summary["real_model_smart_loop_evidence"] = summary["smart_loop_evidence"]
    return summary


def _count_human_scribe_notes(lines: list[str], phrase: str) -> int:
    return sum(1 for line in lines if line.startswith("Scribe note created:") and phrase in line)


def _parse_scribe_log_lines(lines: list[str]) -> tuple[list[dict[str, Any]], int]:
    parsed: list[dict[str, Any]] = []
    malformed = 0
    for line in lines:
        if not line.startswith(SCRIBE_PREFIX):
            continue
        raw_json = line[len(SCRIBE_PREFIX) :].strip()
        try:
            payload = json.loads(raw_json)
        except json.JSONDecodeError:
            malformed += 1
            continue
        if not isinstance(payload, dict):
            malformed += 1
            continue
        parsed.append(_normalize_scribe_log(payload))
    return parsed, malformed


def _normalize_scribe_log(payload: dict[str, Any]) -> dict[str, Any]:
    return {
        "note": str(payload.get("note", "")),
        "tags": _string_list(payload.get("tags", [])),
        "facts": _string_list(payload.get("facts", [])),
        "actions": _dict_list(payload.get("actions", [])),
        "dangers": _dict_list(payload.get("dangers", [])),
        "world_changes": _string_list(payload.get("world_changes", [])),
        "priority_hints": payload.get("priority_hints", {}) if isinstance(payload.get("priority_hints", {}), dict) else {},
        "plan_alignment": str(payload.get("plan_alignment", "unknown")),
        "immediate_risk": str(payload.get("immediate_risk", "none")),
        "resource_blockers": _string_list(payload.get("resource_blockers", [])),
        "mistake_candidates": _string_list(payload.get("mistake_candidates", [])),
        "opportunity_candidates": _string_list(payload.get("opportunity_candidates", [])),
        "lesson_candidates": _string_list(payload.get("lesson_candidates", [])),
        "source": str(payload.get("source", "unknown") or "unknown"),
        "model": str(payload.get("model", "")),
        "endpoint": str(payload.get("endpoint", "")),
        "failure_reason": str(payload.get("failure_reason", payload.get("fallback_reason", ""))),
        "confidence": _float_or_zero(payload.get("confidence", 0.0)),
    }


def _scribe_is_decision_grade(row: dict[str, Any]) -> bool:
    if not row["facts"] or not row["actions"]:
        return False
    if row["dangers"] or row["priority_hints"] or row["resource_blockers"]:
        return True
    if row["mistake_candidates"] or row["opportunity_candidates"] or row["lesson_candidates"]:
        return True
    return bool({"plan_body_mismatch", "plan_support"} & set(row["tags"]))


def _count_phase_dominated_scribe_notes(lines: list[str], structured_rows: list[dict[str, Any]]) -> int:
    count = 0
    structured_note_texts = {str(row.get("note", "")).strip().lower() for row in structured_rows if str(row.get("note", "")).strip()}
    for line in lines:
        if not line.startswith("Scribe note created:"):
            continue
        human_note = line[len("Scribe note created:") :].strip()
        if human_note.lower() in structured_note_texts:
            continue
        lowered = line.lower()
        if "recent event was phase changed" not in lowered:
            continue
        if any(marker in lowered for marker in ("nearest danger", "while plan expected", "supporting plan", "damaged", "low stone", "flying")):
            continue
        count += 1
    for row in structured_rows:
        text = " ".join([row["note"], *row["world_changes"]]).lower()
        if ("phase changed" in text or "phase_changed" in text) and not _scribe_is_decision_grade(row):
            count += 1
    return count


def _parse_ai_request_metric_lines(lines: list[str]) -> tuple[list[dict[str, Any]], int]:
    parsed: list[dict[str, Any]] = []
    malformed = 0
    for line in lines:
        if line.startswith(AI_METRIC_PREFIX):
            payload = _parse_json_payload(line, AI_METRIC_PREFIX)
            if not isinstance(payload, dict):
                malformed += 1
                continue
            parsed.append(_normalize_ai_metric_payload(payload))
            continue
        start = AI_TEXT_REQUEST_START_RE.search(line)
        if start:
            values = start.groupdict()
            parsed.append(
                {
                    "event": "start",
                    "kind": _normalize_ai_kind(values["label"]),
                    "endpoint": values["endpoint"],
                    "status": "",
                    "source": _source_from_endpoint(values["endpoint"]),
                    "fallback_reason": "",
                    "latency_ms": 0,
                    "timeout_s": _float_or_zero(values["timeout"]),
                    "bytes": int(values["bytes"]),
                    "http": 0,
                    "result": 0,
                    "model": "",
                    "context_hash": "",
                    "request_id": "",
                }
            )
            continue
        done = AI_TEXT_REQUEST_DONE_RE.search(line)
        if done:
            values = done.groupdict()
            parsed.append(
                {
                    "event": "done",
                    "kind": _normalize_ai_kind(values["label"]),
                    "endpoint": values["endpoint"],
                    "status": values["status"],
                    "source": _source_from_endpoint(values["endpoint"]),
                    "fallback_reason": "" if values["status"] == "ok" else values["status"],
                    "latency_ms": int(values["latency"]),
                    "timeout_s": 0.0,
                    "bytes": 0,
                    "http": int(values["http"]),
                    "result": int(values["result"]),
                    "model": "",
                    "context_hash": "",
                    "request_id": "",
                }
            )
            continue
        start_failed = AI_TEXT_REQUEST_START_FAILED_RE.search(line)
        if start_failed:
            values = start_failed.groupdict()
            parsed.append(
                {
                    "event": "start_failed",
                    "kind": _normalize_ai_kind(values["label"]),
                    "endpoint": values["endpoint"],
                    "status": "start_failed",
                    "source": _source_from_endpoint(values["endpoint"]),
                    "fallback_reason": "start_failed",
                    "latency_ms": 0,
                    "timeout_s": 0.0,
                    "bytes": 0,
                    "http": 0,
                    "result": int(values["error"]),
                    "model": "",
                    "context_hash": "",
                    "request_id": "",
                }
            )
    return parsed, malformed


def _parse_day_summary_lines(lines: list[str]) -> tuple[list[dict[str, Any]], int]:
    parsed: list[dict[str, Any]] = []
    malformed = 0
    for line in lines:
        if not line.startswith(DAY_SUMMARY_PREFIX):
            continue
        payload = _parse_json_payload(line, DAY_SUMMARY_PREFIX)
        if not isinstance(payload, dict):
            malformed += 1
            continue
        parsed.append(
            {
                "day": int(_float_or_zero(payload.get("day", 0))),
                "outcome": str(payload.get("outcome", "")),
                "candidate_lessons": _string_list(payload.get("candidate_lessons", [])),
                "evidence_ids": _string_list(payload.get("evidence_snapshot_ids", payload.get("evidence_ids", []))),
                "source": str(payload.get("source", "unknown") or "unknown"),
                "model": str(payload.get("model", "")),
                "endpoint": str(payload.get("endpoint", "")),
                "failure_reason": str(payload.get("failure_reason", payload.get("fallback_reason", ""))),
            }
        )
    return parsed, malformed


def _parse_learning_trace_lines(lines: list[str]) -> tuple[list[dict[str, Any]], int]:
    parsed: list[dict[str, Any]] = []
    malformed = 0
    for line in lines:
        if not line.startswith(LEARNING_TRACE_PREFIX):
            continue
        payload = _parse_json_payload(line, LEARNING_TRACE_PREFIX)
        if not isinstance(payload, dict):
            malformed += 1
            continue
        parsed.append(
            {
                "evidence_ids": _string_list(payload.get("evidence_ids", [])),
                "scribe_note_ids": _string_list(payload.get("scribe_note_ids", [])),
                "summary_id": str(payload.get("summary_id", "")),
                "reflection_id": str(payload.get("reflection_id", "")),
                "doctrine_id": str(payload.get("doctrine_id", "")),
                "later_plan_id": str(payload.get("later_plan_id", "")),
                "outcome": str(payload.get("outcome", "")),
                "improvement_claim": str(payload.get("improvement_claim", "")),
                "source": str(payload.get("source", "unknown") or "unknown"),
                "model": str(payload.get("model", "")),
                "endpoint": str(payload.get("endpoint", "")),
                "failure_reason": str(payload.get("failure_reason", payload.get("fallback_reason", ""))),
            }
        )
    return parsed, malformed


def _parse_json_payload(line: str, prefix: str) -> dict[str, Any] | None:
    try:
        payload = json.loads(line[len(prefix) :].strip())
    except json.JSONDecodeError:
        return None
    return payload if isinstance(payload, dict) else None


def _normalize_ai_metric_payload(payload: dict[str, Any]) -> dict[str, Any]:
    fallback_reason = str(payload.get("fallback_reason", payload.get("failure_reason", "")))
    status = str(payload.get("status", "ok" if not fallback_reason else fallback_reason))
    return {
        "event": "metric",
        "kind": _normalize_ai_kind(str(payload.get("kind", ""))),
        "endpoint": str(payload.get("endpoint", "")),
        "status": status,
        "source": str(payload.get("source", "")),
        "fallback_reason": fallback_reason,
        "latency_ms": int(_float_or_zero(payload.get("latency_ms", 0))),
        "timeout_s": _float_or_zero(payload.get("timeout_s", payload.get("timeout_seconds", 0.0))),
        "bytes": int(_float_or_zero(payload.get("bytes", payload.get("payload_bytes", 0)))),
        "http": int(_float_or_zero(payload.get("http", payload.get("http_status", 200 if status == "ok" else 0)))),
        "result": int(_float_or_zero(payload.get("result", 0))),
        "model": str(payload.get("model", "")),
        "context_hash": str(payload.get("context_hash", "")),
        "request_id": str(payload.get("request_id", "")),
    }


def _normalize_ai_kind(value: str) -> str:
    text = value.strip().lower().replace("-", "_").replace(" ", "_")
    aliases = {
        "deep": "deep_interpretation",
        "deep_interpretation": "deep_interpretation",
        "agent_plan": "agent_plan",
        "plan": "agent_plan",
        "prediction": "prediction",
        "fast_prediction": "prediction",
        "background_job": "background_job",
        "library_reflection": "library_reflection",
        "scribe": "scribe",
    }
    return aliases.get(text, text or "unknown")


def _source_from_endpoint(endpoint: str) -> str:
    text = endpoint.strip().lower()
    if not text:
        return "unknown"
    if "127.0.0.1" in text or "localhost" in text:
        return "local_endpoint"
    if text.startswith("http://") or text.startswith("https://"):
        return "remote_server"
    return "unknown"


def _source_class_counter(rows: list[dict[str, Any]]) -> dict[str, int]:
    counts = Counter(_source_class(row.get("source", ""), row.get("endpoint", ""), row.get("model", ""), row.get("failure_reason", row.get("fallback_reason", "")), row.get("status", "")) for row in rows)
    return dict(sorted(counts.items()))


def _source_class(
    source: Any,
    endpoint: Any = "",
    model: Any = "",
    failure_reason: Any = "",
    status: Any = "",
) -> str:
    source_text = str(source or "").strip().lower()
    endpoint_text = str(endpoint or "").strip().lower()
    model_text = str(model or "").strip().lower()
    failure_text = str(failure_reason or "").strip().lower()
    status_text = str(status or "").strip().lower()
    if failure_text or status_text in {"local_fallback", "fallback", "model_timeout", "model_failed", "request_error", "timeout", "start_failed"}:
        return "fallback"
    if "scripted" in source_text or model_text == "scripted":
        return "scripted"
    if source_text in {"local_fallback", "local_stub", "missing_server_base_url", "request_error"}:
        return "fallback"
    if source_text in {"deterministic", "deterministic_scribe"}:
        return "deterministic"
    if source_text == "validated_guardrail":
        return "guardrail"
    if source_text == "cache":
        return "cache"
    if source_text == "local_endpoint":
        return "local_endpoint"
    if source_text in {"remote_server", "model", "ollama", "openai", "vllm"}:
        return "real_model"
    if not source_text or source_text == "unknown":
        if endpoint_text.startswith("http://") or endpoint_text.startswith("https://"):
            if "127.0.0.1" in endpoint_text or "localhost" in endpoint_text:
                return "local_endpoint"
            return "real_model"
        return "unknown"
    return "other"


def _ai_status_counts(rows: list[dict[str, Any]]) -> dict[str, dict[str, int]]:
    grouped: dict[str, Counter] = {}
    for row in rows:
        kind = row["kind"]
        grouped.setdefault(kind, Counter())[str(row.get("status", "unknown") or "unknown")] += 1
    return {kind: dict(sorted(counts.items())) for kind, counts in sorted(grouped.items())}


def _is_prediction_ok(row: dict[str, Any]) -> bool:
    if str(row.get("status", "")) != "ok":
        return False
    if str(row.get("source", "")) == "local_fallback":
        return False
    if str(row.get("fallback_reason", "")):
        return False
    http = int(row.get("http", 0))
    return http == 0 or 200 <= http < 300


def _is_prediction_ok_under_5s(row: dict[str, Any]) -> bool:
    return _is_prediction_ok(row) and int(row.get("latency_ms", 0)) <= 5000


def _is_real_model_prediction_ok_under_5s(row: dict[str, Any]) -> bool:
    return _is_prediction_ok_under_5s(row) and _source_class(
        row.get("source", ""),
        row.get("endpoint", ""),
        row.get("model", ""),
        row.get("fallback_reason", ""),
        row.get("status", ""),
    ) == "real_model"


def _is_prediction_fallback_or_failed(row: dict[str, Any]) -> bool:
    return not _is_prediction_ok(row)


def _is_complete_learning_trace(row: dict[str, Any]) -> bool:
    return bool(
        row["evidence_ids"]
        and row["summary_id"]
        and row["reflection_id"]
        and row["doctrine_id"]
        and row["later_plan_id"]
        and row["outcome"]
    )


def _is_successful_learning_trace(row: dict[str, Any]) -> bool:
    if not _is_complete_learning_trace(row):
        return False
    outcome = str(row.get("outcome", "")).strip().lower()
    claim = str(row.get("improvement_claim", "")).strip().lower()
    if any(token in outcome for token in ("died", "death", "ari_died", "failed")):
        return False
    if "not a success" in claim or "produced ari_died" in claim:
        return False
    return outcome in {"survived", "success", "improved", "safe", "safer"} or bool(claim)


def _string_list(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item) for item in value if str(item)]


def _dict_list(value: Any) -> list[dict[str, Any]]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, dict)]


def _float_or_zero(value: Any) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return 0.0


def _parse_plan_line(line: str) -> dict[str, Any] | None:
    match = PLAN_RE.search(line)
    if not match:
        return None
    values = match.groupdict()
    return {
        "plan_number": int(values["n"]),
        "trigger": values["trigger"],
        "kind": values["kind"],
        "day": int(values["day"]),
        "phase": values["phase"],
        "action": values["action"],
        "job": values["job"],
        "enemy": int(values["enemy"]),
        "types": values["types"],
        "wall": int(values["wall"]),
        "tower": int(values["tower"]),
        "storm": int(values["storm"]),
        "damaged": int(values["damaged"]),
        "current": values["current"],
        "source": values.get("src") or "unknown",
        "endpoint": "",
        "model": "",
        "failure_reason": "",
        "legal": int(values["legal"]),
        "doctrine": int(values["doctrine"]),
    }


def _parse_remote_prompt_line(line: str) -> dict[str, Any] | None:
    match = REMOTE_PROMPT_RE.search(line)
    if not match:
        return None
    values = match.groupdict()
    return {
        "prompt": values["prompt"],
        "source": values["source"],
        "next_action": values["next_action"],
        "day": int(values["day"]),
        "phase": values["phase"],
        "alive": values["alive"] == "true",
        "hp": float(values["hp"]),
        "min_hp": float(values["min_hp"]),
        "walls": values["walls"],
        "tower": values["tower"],
        "storm": values["storm"],
        "scribe": int(values["scribe"]),
        "structured": int(values["structured"]),
        "reflections": int(values["reflections"]),
        "doctrine_reflections": int(values["doctrine_reflections"]),
        "doctrine_plans": int(values["doctrine_plans"]),
        "sign": values["sign"],
    }


def _learning_evidence(statuses: list[dict[str, Any]]) -> list[dict[str, Any]]:
    evidence: list[dict[str, Any]] = []
    for status in statuses:
        if (
            status["day"] > 1
            and status["alive"]
            and status["reflections"] > 0
            and status["doctrine_reflections"] > 0
            and status["doctrine_plans"] > 0
        ):
            evidence.append(
                {
                    "prompt": status["prompt"],
                    "day": status["day"],
                    "phase": status["phase"],
                    "next_action": status["next_action"],
                    "reflections": status["reflections"],
                    "doctrine_reflections": status["doctrine_reflections"],
                    "doctrine_plans": status["doctrine_plans"],
                    "sign": status["sign"],
                }
            )
    return evidence


def _smart_loop_evidence(summary: dict[str, Any], statuses: list[dict[str, Any]]) -> dict[str, Any]:
    has_complete_trace = int(summary["complete_learning_traces"]) > 0
    has_successful_trace = int(summary.get("successful_learning_traces", 0)) > 0
    has_day_summary_evidence = int(summary["day_summaries_with_evidence"]) > 0
    has_day_summary_lesson = int(summary["day_summaries_with_lessons"]) > 0
    source_counts = summary.get("source_class_counts", {})
    plan_source_counts = source_counts.get("plan", {}) if isinstance(source_counts, dict) else {}
    scenario_source_counts = source_counts.get("scenario", {}) if isinstance(source_counts, dict) else {}
    noticed_facts = int(summary["scribe_decision_grade_notes"]) > 0 or has_complete_trace
    summarized_mattered = has_day_summary_evidence
    formed_lesson = has_day_summary_lesson and (any(status["doctrine_reflections"] > 0 for status in statuses) or has_complete_trace)
    changed_strategy = (
        int(summary["doctrine_plan_calls"]) > 0
        or any(status["doctrine_plans"] > 0 for status in statuses)
        or has_complete_trace
    )
    improved_or_plausible_survival = (
        any(status["alive"] and status["day"] > 1 and status["min_hp"] > 0.0 for status in statuses)
        or has_successful_trace
    )
    fast_prediction = int(summary["prediction_ok_under_5s"]) > 0
    real_model_prediction = int(summary.get("real_model_prediction_ok_under_5s", 0)) > 0
    real_model_learning_source = (
        int(summary.get("real_model_learning_traces", 0)) > 0
        or (summary["learning_evidence"] and int(scenario_source_counts.get("real_model", 0)) > 0)
        or (int(summary["doctrine_plan_calls"]) > 0 and int(plan_source_counts.get("real_model", 0)) > 0)
        or (has_complete_trace and real_model_prediction)
    )
    checks = {
        "noticed_facts": noticed_facts,
        "summarized_mattered": summarized_mattered,
        "formed_lesson": formed_lesson,
        "changed_strategy": changed_strategy,
        "improved_or_plausible_survival": improved_or_plausible_survival,
        "fast_prediction": fast_prediction,
        "real_model_prediction": real_model_prediction,
        "real_model_learning_source": real_model_learning_source,
    }
    missing = [key for key, ok in checks.items() if not ok]
    return {
        **checks,
        "passed": not missing,
        "missing": missing,
        "prediction_ok_under_5s": int(summary["prediction_ok_under_5s"]),
        "real_model_prediction_ok_under_5s": int(summary.get("real_model_prediction_ok_under_5s", 0)),
        "prediction_fallback_or_failed": int(summary["prediction_fallback_or_failed"]),
        "decision_grade_scribe_notes": int(summary["scribe_decision_grade_notes"]),
        "day_summaries_with_evidence": int(summary["day_summaries_with_evidence"]),
        "complete_learning_traces": int(summary["complete_learning_traces"]),
        "successful_learning_traces": int(summary.get("successful_learning_traces", 0)),
        "real_model_learning_traces": int(summary.get("real_model_learning_traces", 0)),
        "real_model_ai_ratio": float(summary.get("real_model_ai_ratio", 0.0)),
    }


def print_text_summary(summary: dict[str, Any]) -> None:
    print(f"planner_calls={summary['planner_calls']}")
    print(f"scribe_body_plan_mismatches={summary['scribe_body_plan_mismatches']}")
    print(f"scribe_plan_supports={summary['scribe_plan_supports']}")
    print(f"structured_scribe_logs={summary['structured_scribe_logs']}")
    print(f"malformed_scribe_logs={summary['malformed_scribe_logs']}")
    print(f"structured_scribe_with_facts={summary['structured_scribe_with_facts']}")
    print(f"structured_scribe_with_actions={summary['structured_scribe_with_actions']}")
    print(f"structured_scribe_with_dangers={summary['structured_scribe_with_dangers']}")
    print(f"structured_scribe_with_priority_hints={summary['structured_scribe_with_priority_hints']}")
    print(f"scribe_decision_grade_notes={summary['scribe_decision_grade_notes']}")
    print(f"scribe_phase_dominated_notes={summary['scribe_phase_dominated_notes']}")
    print(f"prediction_ok_under_5s={summary['prediction_ok_under_5s']}")
    print(f"real_model_prediction_ok_under_5s={summary['real_model_prediction_ok_under_5s']}")
    print(f"prediction_fallback_or_failed={summary['prediction_fallback_or_failed']}")
    print(f"real_model_ai_ratio={summary['real_model_ai_ratio']}")
    print(f"real_model_prediction_ratio={summary['real_model_prediction_ratio']}")
    print(f"scripted_evidence_count={summary['scripted_evidence_count']}")
    print(f"old_timeout_request_starts={summary['old_timeout_request_starts']}")
    print(f"doctrine_plan_calls={summary['doctrine_plan_calls']}")
    print(f"learning_evidence={len(summary['learning_evidence'])}")
    print(f"smart_loop_evidence={summary['smart_loop_evidence']['passed']}")
    if summary["smart_loop_evidence"]["missing"]:
        print("smart_loop_missing=" + json.dumps(summary["smart_loop_evidence"]["missing"], sort_keys=True))
    print("ai_request_counts=" + json.dumps(summary["ai_request_counts"], sort_keys=True))
    print("source_class_counts=" + json.dumps(summary["source_class_counts"], sort_keys=True))
    print("trigger_counts=" + json.dumps(summary["trigger_counts"], sort_keys=True))
    print("phase_counts=" + json.dumps(summary["phase_counts"], sort_keys=True))
    if summary["night_illegal_actions"]:
        print("night_illegal_actions=" + json.dumps(summary["night_illegal_actions"], sort_keys=True))
    if summary["non_executable_plan_actions"]:
        print("non_executable_plan_actions=" + json.dumps(summary["non_executable_plan_actions"], sort_keys=True))
    if summary.get("forbidden_phrase_hits"):
        print("forbidden_phrase_hits=" + json.dumps(summary["forbidden_phrase_hits"], sort_keys=True))


if __name__ == "__main__":
    raise SystemExit(main())
