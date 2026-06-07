from __future__ import annotations

import argparse
import asyncio
import json
import math
import os
import subprocess
import sys
import time
from dataclasses import replace
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
GATEWAY_ROOT = SCRIPT_DIR.parents[0]
REPO_ROOT = SCRIPT_DIR.parents[1]
for path in (str(GATEWAY_ROOT), str(SCRIPT_DIR)):
    if path not in sys.path:
        sys.path.insert(0, path)

import benchmark_prediction_quality as prediction_benchmark  # noqa: E402
from app.model_client import Settings, call_prediction_model, settings_from_env  # noqa: E402
from app.schemas import PredictionRequest, fallback_prediction_response, sanitize_prediction_response  # noqa: E402


DEFAULT_CANDIDATE_MODELS = ("qwen3:0.6b", "qwen3:1.7b", "llama3.2:1b")
DEFAULT_REPORT_PATH = REPO_ROOT / "godot_game" / "artifacts" / "reports" / "live_prediction_model_bakeoff.md"


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    models = parse_models(args.models)
    if not models:
        raise SystemExit("No models selected.")

    base_settings = settings_from_env()
    if args.model_base_url:
        base_settings = replace(base_settings, model_backend="ollama", model_base_url=args.model_base_url.rstrip("/"))
    if args.pull:
        for model in models:
            pull_model(model)

    rows = asyncio.run(run_models(models, base_settings, args.repeat, args.timeout, args.max_tokens, args.target_latency))
    grouped = summary_by_model(rows, args.target_latency)
    result = {"results": rows, "summary_by_model": grouped, "winner": choose_winner(grouped)}
    if args.report:
        write_report(Path(args.report), result, args.target_latency)
    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print_table(rows)
        print()
        print_summary(grouped, result["winner"])
    return exit_code_for_result(result)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Benchmark candidate tiny models for Ari fast prediction.")
    parser.add_argument("--models", default=",".join(DEFAULT_CANDIDATE_MODELS), help="Comma-separated Ollama model names.")
    parser.add_argument("--model-base-url", default=os.getenv("MODEL_BASE_URL", ""), help="Ollama base URL. Defaults to env/settings.")
    parser.add_argument("--repeat", type=int, default=1, help="Requests per model/case.")
    parser.add_argument("--timeout", type=float, default=5.0, help="Per-request model timeout seconds.")
    parser.add_argument("--target-latency", type=float, default=5.0, help="Useful prediction latency target.")
    parser.add_argument("--max-tokens", type=int, default=96, help="Prediction token budget for each candidate.")
    parser.add_argument("--pull", action="store_true", help="Run `ollama pull` for each candidate before benchmarking.")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--report", default=str(DEFAULT_REPORT_PATH), help="Markdown report path. Use empty string to skip.")
    return parser.parse_args(argv)


def parse_models(value: str) -> list[str]:
    return [item.strip() for item in str(value or "").split(",") if item.strip()]


def pull_model(model: str) -> None:
    subprocess.run(["ollama", "pull", model], check=False)


async def run_models(
    models: list[str],
    base_settings: Settings,
    repeat: int,
    timeout: float,
    max_tokens: int,
    target_latency: float,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for model in models:
        settings = build_settings_for_model(base_settings, model, timeout, max_tokens)
        for _index in range(max(1, repeat)):
            for case in prediction_benchmark.CASES:
                rows.append(await run_case_for_model(settings, model, case, target_latency))
    return rows


def build_settings_for_model(base_settings: Settings, model: str, timeout: float, max_tokens: int) -> Settings:
    return replace(
        base_settings,
        model_backend="ollama",
        prediction_model=model,
        prediction_request_timeout_seconds=timeout,
        prediction_max_tokens=max_tokens,
        ollama_json_format=True,
    )


async def run_case_for_model(settings: Settings, model: str, case: dict[str, Any], target_latency: float) -> dict[str, Any]:
    payload = prediction_benchmark.build_payload(case)
    request = PredictionRequest(**payload)
    started = time.perf_counter()
    try:
        raw = await call_prediction_model(request, settings)
    except Exception as exc:
        return evaluate_model_exception(model, case, payload, exc, time.perf_counter() - started, target_latency)
    return evaluate_model_result(model, case, payload, raw, time.perf_counter() - started, target_latency, json_valid=True)


def evaluate_model_result(
    model: str,
    case: dict[str, Any],
    payload: dict[str, Any],
    raw: dict[str, Any],
    elapsed: float,
    target_latency: float,
    *,
    json_valid: bool,
) -> dict[str, Any]:
    request = PredictionRequest(**payload)
    fallback = fallback_prediction_response(request)
    response = sanitize_prediction_response(raw, fallback, request)
    row = prediction_benchmark.evaluate_response(case, payload, response, elapsed, target_latency)
    row["model"] = model
    row["json_valid"] = bool(json_valid)
    return row


def evaluate_model_exception(
    model: str,
    case: dict[str, Any],
    payload: dict[str, Any],
    exc: Exception,
    elapsed: float,
    target_latency: float,
) -> dict[str, Any]:
    request = PredictionRequest(**payload)
    response = fallback_prediction_response(request, "model_failed")
    row = prediction_benchmark.evaluate_response(case, payload, response, elapsed, target_latency)
    row["model"] = model
    row["json_valid"] = False
    row["model_error"] = type(exc).__name__
    return row


def summary_by_model(rows: list[dict[str, Any]], target_latency: float = 5.0) -> dict[str, dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = {}
    for row in rows:
        grouped.setdefault(str(row.get("model", "")), []).append(row)
    return {model: _summary(rows_for_model, target_latency) for model, rows_for_model in sorted(grouped.items())}


def _summary(rows: list[dict[str, Any]], target_latency: float) -> dict[str, Any]:
    latencies = [float(row.get("latency_seconds", 0.0)) for row in rows]
    count = len(rows)
    return {
        "count": count,
        "passed": sum(1 for row in rows if row.get("ok")),
        "failed": sum(1 for row in rows if not row.get("ok")),
        "json_valid_rate": _rate(sum(1 for row in rows if row.get("json_valid")), count),
        "fallback_rate": _rate(sum(1 for row in rows if row.get("fallback_or_failed")), count),
        "legal_action_rate": _rate(sum(1 for row in rows if row.get("legal_action")), count),
        "useful_under_target": sum(
            1 for row in rows if row.get("ok") and float(row.get("latency_seconds", 0.0)) <= target_latency
        ),
        "avg_latency_seconds": round(sum(latencies) / count, 3) if latencies else 0.0,
        "p50_latency_seconds": round(_median(latencies), 3) if latencies else 0.0,
        "p95_latency_seconds": round(_percentile(latencies, 0.95), 3) if latencies else 0.0,
        "max_latency_seconds": round(max(latencies), 3) if latencies else 0.0,
    }


def _rate(value: int, count: int) -> float:
    if count <= 0:
        return 0.0
    return round(float(value) / float(count), 3)


def _median(values: list[float]) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    middle = len(ordered) // 2
    if len(ordered) % 2:
        return ordered[middle]
    return (ordered[middle - 1] + ordered[middle]) / 2.0


def _percentile(values: list[float], percentile: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = max(0, min(len(ordered) - 1, math.ceil(percentile * len(ordered)) - 1))
    return ordered[index]


def choose_winner(grouped: dict[str, dict[str, Any]]) -> str:
    if not grouped:
        return ""
    return sorted(
        grouped,
        key=lambda model: (
            -int(grouped[model].get("passed", 0)),
            float(grouped[model].get("fallback_rate", 1.0)),
            float(grouped[model].get("p95_latency_seconds", 999.0)),
            model,
        ),
    )[0]


def exit_code_for_result(result: dict[str, Any]) -> int:
    grouped = result.get("summary_by_model", {})
    if not isinstance(grouped, dict) or not grouped:
        return 1
    return 0 if any(int(data.get("passed", 0) or 0) > 0 for data in grouped.values() if isinstance(data, dict)) else 1


def print_table(rows: list[dict[str, Any]]) -> None:
    print("model | case | latency_s | ok | json | action | source | error")
    print("--- | --- | ---: | --- | --- | --- | --- | ---")
    for row in rows:
        print(
            "%s | %s | %.3f | %s | %s | %s | %s | %s"
            % (
                row.get("model", ""),
                row.get("id", ""),
                float(row.get("latency_seconds", 0.0)),
                row.get("ok", False),
                row.get("json_valid", False),
                row.get("action", ""),
                row.get("source", ""),
                row.get("error", row.get("model_error", "")),
            )
        )


def print_summary(grouped: dict[str, dict[str, Any]], winner: str) -> None:
    print("model | passed | fallback_rate | json_valid_rate | legal_action_rate | p50_s | p95_s | max_s")
    print("--- | ---: | ---: | ---: | ---: | ---: | ---: | ---:")
    for model, data in grouped.items():
        print(
            "%s | %d/%d | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f"
            % (
                model,
                int(data.get("passed", 0)),
                int(data.get("count", 0)),
                float(data.get("fallback_rate", 0.0)),
                float(data.get("json_valid_rate", 0.0)),
                float(data.get("legal_action_rate", 0.0)),
                float(data.get("p50_latency_seconds", 0.0)),
                float(data.get("p95_latency_seconds", 0.0)),
                float(data.get("max_latency_seconds", 0.0)),
            )
        )
    print(f"winner={winner or 'none'}")


def write_report(path: Path, result: dict[str, Any], target_latency: float) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Ari Prediction Model Bake-Off",
        "",
        "This report compares candidate Ollama models on the same fast-prediction cases used by the live gateway quality probe.",
        "",
        f"- Target latency: {target_latency:.1f}s",
        f"- Winner: `{result.get('winner', '') or 'none'}`",
        "",
        "## Summary",
        "",
        "| Model | Passed | Fallback Rate | JSON Valid Rate | Legal Action Rate | P50 | P95 | Max |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for model, data in result.get("summary_by_model", {}).items():
        lines.append(
            "| %s | %d/%d | %.3f | %.3f | %.3f | %.3fs | %.3fs | %.3fs |"
            % (
                model,
                int(data.get("passed", 0)),
                int(data.get("count", 0)),
                float(data.get("fallback_rate", 0.0)),
                float(data.get("json_valid_rate", 0.0)),
                float(data.get("legal_action_rate", 0.0)),
                float(data.get("p50_latency_seconds", 0.0)),
                float(data.get("p95_latency_seconds", 0.0)),
                float(data.get("max_latency_seconds", 0.0)),
            )
        )
    path.write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
