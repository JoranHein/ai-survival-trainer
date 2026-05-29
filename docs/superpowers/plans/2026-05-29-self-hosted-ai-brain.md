# Self-Hosted AI Brain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional, free, self-hosted remote AI brain for Ari that can call a local model running on a Hetzner server while preserving the current offline planner as the authoritative fallback.

**Architecture:** Keep the simulation in `IdleSurvivalWorld` authoritative. The game builds compact legal action plans locally, optionally sends a sanitized world snapshot plus legal actions to a private remote model endpoint, validates the model's JSON decision, and falls back to `LocalBrainModel` on any invalid output, timeout, or disabled config. The server runs either `llama.cpp` `llama-server` or Ollama behind a private tunnel or authenticated reverse proxy.

**Tech Stack:** Python standard library HTTP (`urllib.request`), Pygame, pytest, optional llama.cpp or Ollama on Linux/systemd, optional Nginx/Tailscale/WireGuard for secure access.

---

## Current Project Evidence

- `alife/brain.py` contains `BrainDecision` and `LocalBrainModel.choose(scores, rng, temperature)`.
- `alife/survival.py` constructs day plans in `IdleSurvivalWorld.day_action_plans()`, picks actions in `choose_day_action()`, and picks combat weapons in `choose_weapon()`.
- `ui/survival_ui.py` already displays `world.last_brain_thought` in the HUD.
- `requirements.txt` currently only needs `pygame` and `pytest`.
- The folder is not a git repository, so implementation should not include commit steps unless the user later initializes git.

## Primary Source Notes

- Ollama's official API docs say the local API is served by default at `http://localhost:11434/api`, and `/api/chat` accepts chat messages.
- Ollama's FAQ documents `keep_alive`, including `-1` to keep a model loaded and `0` to unload it.
- llama.cpp's server docs describe `llama-server` as an OpenAI-compatible HTTP API server with `/v1/chat/completions` and embeddings endpoints.
- The Ollama Gemma 3 model page lists small text model options including `gemma3:270m`, `gemma3:1b`, and `gemma3:4b`.

## Server Choice

Recommended first path: **llama.cpp with `llama-server`**.

Why:
- It exposes an OpenAI-compatible endpoint, which is easy to isolate behind one generic client.
- It can be bound to `127.0.0.1` on the Hetzner server and accessed through SSH/Tailscale/WireGuard.
- It supports constrained output approaches better than a loose chat endpoint, which matters because Ari needs structured JSON actions.

Practical alternate path: **Ollama**.

Why:
- It is easier to install and manage models.
- It has a simple `/api/chat` endpoint and can keep a model loaded with `keep_alive`.
- It is good for early experiments if strict JSON reliability is handled in the game client.

CPU model recommendation:
- Tiny server / first smoke test: Gemma 3 1B quantized or similar 1B-class instruct model.
- Better quality if CPU/RAM allow it: Gemma 3 4B quantized.
- Avoid 12B+ models for the first Hetzner CPU prototype unless the server has enough RAM and slow responses are acceptable.

## API Contract

The game sends one compact JSON payload per decision point:

```json
{
  "schema": "ari.remote_brain.v1",
  "decision_kind": "day_action",
  "legal_actions": ["eat", "train_defense", "study_book", "rest_in_bed", "explore"],
  "local_top_options": [
    {"action": "eat", "score": 18.4, "reasons": ["hunger 92 needs food", "fruit is ready now"]},
    {"action": "train_defense", "score": 7.2, "reasons": ["night is getting close"]}
  ],
  "ari": {
    "hp": 45,
    "max_hp": 45,
    "hunger": 92,
    "rest": 81,
    "fear": 15,
    "traits": {"aggression": 0.35, "curiosity": 0.55, "charisma": 0.55, "perseverance": 0.5},
    "learned": {"attack": 1.2, "defense": 0.7, "bow": 0.0, "literacy": 1.4},
    "current_action": "thinking",
    "committed_action": null
  },
  "world": {
    "phase": "day",
    "day": 1,
    "wave": 1,
    "seconds_left": 83,
    "fruit_ready": true,
    "fruit_ready_in_seconds": 0,
    "tree_travel_ticks": 21,
    "dummy_travel_ticks": 42,
    "bed_travel_ticks": 30
  },
  "sign": {
    "text": "eat before night",
    "known_words": ["eat", "before", "night"],
    "unknown_words": [],
    "interpreted": "eat fruit"
  }
}
```

The model must return only JSON:

```json
{
  "action": "eat",
  "confidence": 0.72,
  "reason": "Ari is hungry, fruit is ready, and there is still time before night.",
  "thought": "Belly first, then train."
}
```

Validation rules:
- `action` must be in `legal_actions`.
- `confidence` must be a number from `0.0` to `1.0`; default to `0.5` if missing.
- `reason` and `thought` must be strings and trimmed to safe HUD lengths.
- Unknown fields are ignored.
- Invalid JSON, invalid action, timeout, HTTP error, or empty response must return the local fallback decision.

---

### Task 1: Add Remote Brain Configuration

**Files:**
- Modify: `config.py`
- Test: `tests/test_remote_brain.py`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_remote_brain.py`:

```python
import importlib

import config


def test_remote_brain_is_disabled_by_default(monkeypatch):
    monkeypatch.delenv("ARI_REMOTE_BRAIN", raising=False)
    monkeypatch.delenv("ARI_REMOTE_BRAIN_URL", raising=False)

    importlib.reload(config)

    assert config.REMOTE_BRAIN_ENABLED is False
    assert config.REMOTE_BRAIN_URL == ""


def test_remote_brain_config_reads_environment(monkeypatch):
    monkeypatch.setenv("ARI_REMOTE_BRAIN", "1")
    monkeypatch.setenv("ARI_REMOTE_BRAIN_URL", "http://127.0.0.1:8080/v1/chat/completions")
    monkeypatch.setenv("ARI_REMOTE_BRAIN_BACKEND", "llamacpp")
    monkeypatch.setenv("ARI_REMOTE_BRAIN_MODEL", "gemma-3-1b")
    monkeypatch.setenv("ARI_REMOTE_BRAIN_TOKEN", "secret")
    monkeypatch.setenv("ARI_REMOTE_BRAIN_TIMEOUT", "1.5")

    importlib.reload(config)

    assert config.REMOTE_BRAIN_ENABLED is True
    assert config.REMOTE_BRAIN_URL == "http://127.0.0.1:8080/v1/chat/completions"
    assert config.REMOTE_BRAIN_BACKEND == "llamacpp"
    assert config.REMOTE_BRAIN_MODEL == "gemma-3-1b"
    assert config.REMOTE_BRAIN_TOKEN == "secret"
    assert config.REMOTE_BRAIN_TIMEOUT == 1.5
```

- [ ] **Step 2: Run the tests to verify RED**

Run:

```bash
python -m pytest tests/test_remote_brain.py -q
```

Expected: fails because `REMOTE_BRAIN_ENABLED` and related config values do not exist.

- [ ] **Step 3: Implement minimal config**

Add to `config.py`:

```python
import os


def _float_env(name: str, default: float) -> float:
    try:
        return float(os.getenv(name, str(default)))
    except ValueError:
        return default


REMOTE_BRAIN_ENABLED = os.getenv("ARI_REMOTE_BRAIN", "0").strip().lower() in {"1", "true", "yes", "on"}
REMOTE_BRAIN_BACKEND = os.getenv("ARI_REMOTE_BRAIN_BACKEND", "llamacpp").strip().lower()
REMOTE_BRAIN_URL = os.getenv("ARI_REMOTE_BRAIN_URL", "").strip()
REMOTE_BRAIN_MODEL = os.getenv("ARI_REMOTE_BRAIN_MODEL", "gemma-3-1b").strip()
REMOTE_BRAIN_TOKEN = os.getenv("ARI_REMOTE_BRAIN_TOKEN", "").strip()
REMOTE_BRAIN_TIMEOUT = _float_env("ARI_REMOTE_BRAIN_TIMEOUT", 1.8)
REMOTE_BRAIN_COOLDOWN_SECONDS = _float_env("ARI_REMOTE_BRAIN_COOLDOWN_SECONDS", 8.0)
```

- [ ] **Step 4: Run GREEN**

Run:

```bash
python -m pytest tests/test_remote_brain.py -q
```

Expected: passes.

---

### Task 2: Define Remote Brain Request and Response Parsing

**Files:**
- Create: `alife/remote_brain.py`
- Test: `tests/test_remote_brain.py`

- [ ] **Step 1: Write failing parser tests**

Append to `tests/test_remote_brain.py`:

```python
from alife.brain import BrainDecision
from alife.remote_brain import parse_remote_decision


def test_parse_openai_compatible_response_accepts_legal_action():
    response = {
        "choices": [
            {
                "message": {
                    "content": '{"action":"eat","confidence":0.8,"reason":"hungry","thought":"Fruit now."}'
                }
            }
        ]
    }

    decision = parse_remote_decision(response, {"eat", "train_defense"}, {"eat": 18.0}, "local fallback")

    assert decision is not None
    assert decision.action == "eat"
    assert decision.thought.startswith("Remote AI:")


def test_parse_ollama_response_accepts_legal_action():
    response = {
        "message": {
            "content": '{"action":"rest_in_bed","confidence":0.6,"reason":"rest low","thought":"Bed first."}'
        }
    }

    decision = parse_remote_decision(response, {"rest_in_bed", "explore"}, {"rest_in_bed": 9.0}, "local fallback")

    assert decision is not None
    assert decision.action == "rest_in_bed"


def test_parse_remote_decision_rejects_illegal_action():
    response = {"message": {"content": '{"action":"teleport","reason":"fast"}'}}

    decision = parse_remote_decision(response, {"eat"}, {"eat": 10.0}, "local fallback")

    assert decision is None
```

- [ ] **Step 2: Run tests to verify RED**

Run:

```bash
python -m pytest tests/test_remote_brain.py -q
```

Expected: import fails because `alife.remote_brain` does not exist.

- [ ] **Step 3: Implement parsing**

Create `alife/remote_brain.py`:

```python
from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any

from alife.brain import BrainDecision
from alife.utils import clamp


@dataclass
class RemoteBrainResult:
    decision: BrainDecision | None
    error: str = ""


def _extract_content(response: dict[str, Any]) -> str:
    if "choices" in response:
        choices = response.get("choices") or []
        if choices:
            message = choices[0].get("message", {})
            return str(message.get("content", ""))
    message = response.get("message", {})
    if isinstance(message, dict):
        return str(message.get("content", ""))
    return ""


def _load_json_object(text: str) -> dict[str, Any] | None:
    text = text.strip()
    if not text:
        return None
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        start = text.find("{")
        end = text.rfind("}")
        if start < 0 or end <= start:
            return None
        try:
            parsed = json.loads(text[start : end + 1])
        except json.JSONDecodeError:
            return None
    return parsed if isinstance(parsed, dict) else None


def parse_remote_decision(
    response: dict[str, Any],
    legal_actions: set[str],
    scores: dict[str, float],
    fallback_thought: str,
) -> BrainDecision | None:
    content = _extract_content(response)
    payload = _load_json_object(content)
    if not payload:
        return None
    action = str(payload.get("action", "")).strip()
    if action not in legal_actions:
        return None
    confidence = clamp(float(payload.get("confidence", 0.5) or 0.5), 0.0, 1.0)
    reason = str(payload.get("reason", "")).strip()[:140]
    thought = str(payload.get("thought", "")).strip()[:100]
    explanation = reason or thought or fallback_thought
    return BrainDecision(
        action=action,
        scores=scores,
        probabilities={action: confidence},
        thought=f"Remote AI: {explanation}",
    )
```

- [ ] **Step 4: Run GREEN**

Run:

```bash
python -m pytest tests/test_remote_brain.py -q
```

Expected: parser tests pass.

---

### Task 3: Build Compact World State for Ari

**Files:**
- Modify: `alife/remote_brain.py`
- Test: `tests/test_remote_brain.py`

- [ ] **Step 1: Write failing state summary test**

Append:

```python
from alife.survival import IdleSurvivalWorld
from alife.remote_brain import build_remote_brain_payload


def test_build_remote_payload_includes_compact_legal_context():
    world = IdleSurvivalWorld(seed=50, ticks_per_second=10, day_ticks=100, night_ticks=20)
    world.survivor.hunger = 90
    world.fruit_tree.remaining_ticks = 0
    plans = world.day_action_plans()

    payload = build_remote_brain_payload(world, "day_action", plans)

    assert payload["schema"] == "ari.remote_brain.v1"
    assert payload["decision_kind"] == "day_action"
    assert "eat" in payload["legal_actions"]
    assert payload["ari"]["hunger"] == 90
    assert "aggression" in payload["ari"]["traits"]
    assert payload["world"]["phase"] == "day"
    assert payload["local_top_options"][0]["action"] in payload["legal_actions"]
```

- [ ] **Step 2: Run RED**

Run:

```bash
python -m pytest tests/test_remote_brain.py::test_build_remote_payload_includes_compact_legal_context -q
```

Expected: fails because `build_remote_brain_payload` does not exist.

- [ ] **Step 3: Implement summary builder**

Add to `alife/remote_brain.py`:

```python
def _rounded_stats(data: dict[str, float]) -> dict[str, float]:
    return {key: round(float(value), 2) for key, value in data.items()}


def build_remote_brain_payload(world, decision_kind: str, plans: dict) -> dict[str, Any]:
    survivor = world.survivor
    legal_actions = list(plans.keys())
    top_options = sorted(plans.values(), key=lambda plan: plan.score, reverse=True)[:5]
    total_ticks = world.day_ticks if world.phase == "day" else world.night_ticks
    seconds_left = max(0, round((total_ticks - world.phase_tick) / world.ticks_per_second))
    return {
        "schema": "ari.remote_brain.v1",
        "decision_kind": decision_kind,
        "legal_actions": legal_actions,
        "local_top_options": [
            {
                "action": plan.action,
                "score": round(plan.score, 2),
                "reasons": plan.reasons[:3],
            }
            for plan in top_options
        ],
        "ari": {
            "hp": round(survivor.hp, 1),
            "max_hp": round(survivor.max_hp(world.permanent), 1),
            "hunger": round(survivor.hunger, 1),
            "rest": round(survivor.energy, 1),
            "fear": round(survivor.fear, 1),
            "confidence": round(survivor.confidence, 1),
            "traits": _rounded_stats(survivor.personality_summary()),
            "learned": _rounded_stats(survivor.learned.to_dict()),
            "current_action": survivor.current_action,
            "committed_action": survivor.committed_action,
        },
        "world": {
            "phase": world.phase,
            "day": world.day,
            "wave": world.wave,
            "seconds_left": seconds_left,
            "fruit_ready": world.fruit_tree.ready(),
            "fruit_ready_in_seconds": max(0, round(world.fruit_tree.remaining_ticks / world.ticks_per_second)),
            "tree_travel_ticks": world.travel_ticks_to(world.fruit_tree.x, world.fruit_tree.y),
            "dummy_travel_ticks": world.travel_ticks_to(world.dummy.x, world.dummy.y),
            "bed_travel_ticks": world.travel_ticks_to(world.bed.x, world.bed.y),
            "enemy_count": len(world.enemies),
        },
        "sign": {
            "text": world.sign.text[:80],
            "known_words": [word for word in world.sign_words() if world.word_known(word)],
            "unknown_words": world.unknown_sign_words(),
            "interpreted": survivor.last_interpretation[:120],
        },
    }
```

- [ ] **Step 4: Run GREEN**

Run:

```bash
python -m pytest tests/test_remote_brain.py::test_build_remote_payload_includes_compact_legal_context -q
```

Expected: passes.

---

### Task 4: Implement HTTP RemoteBrainModel With Fallback

**Files:**
- Modify: `alife/remote_brain.py`
- Test: `tests/test_remote_brain.py`

- [ ] **Step 1: Write failing HTTP fallback tests**

Append:

```python
import json
import socket
from io import BytesIO

from alife.remote_brain import RemoteBrainConfig, RemoteBrainModel


class FakeHTTPResponse:
    def __init__(self, data):
        self.data = json.dumps(data).encode("utf-8")

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def read(self):
        return self.data


def test_remote_brain_uses_valid_http_decision(monkeypatch):
    config = RemoteBrainConfig(
        enabled=True,
        backend="ollama",
        url="http://brain.local/api/chat",
        model="gemma3:1b",
        token="",
        timeout=0.2,
        cooldown_seconds=0.0,
    )
    model = RemoteBrainModel(config)

    def fake_urlopen(request, timeout):
        return FakeHTTPResponse({"message": {"content": '{"action":"eat","reason":"hungry"}'}})

    monkeypatch.setattr("urllib.request.urlopen", fake_urlopen)

    fallback = BrainDecision("explore", {"eat": 10.0, "explore": 5.0}, {"explore": 1.0}, "local")
    decision = model.choose({"legal_actions": ["eat", "explore"]}, {"eat": 10.0, "explore": 5.0}, fallback)

    assert decision.action == "eat"
    assert model.last_status == "remote"


def test_remote_brain_timeout_falls_back_to_local(monkeypatch):
    config = RemoteBrainConfig(
        enabled=True,
        backend="ollama",
        url="http://brain.local/api/chat",
        model="gemma3:1b",
        token="",
        timeout=0.01,
        cooldown_seconds=0.0,
    )
    model = RemoteBrainModel(config)

    def fake_urlopen(request, timeout):
        raise socket.timeout("slow")

    monkeypatch.setattr("urllib.request.urlopen", fake_urlopen)

    fallback = BrainDecision("explore", {"eat": 10.0, "explore": 5.0}, {"explore": 1.0}, "local")
    decision = model.choose({"legal_actions": ["eat", "explore"]}, {"eat": 10.0, "explore": 5.0}, fallback)

    assert decision.action == "explore"
    assert model.last_status.startswith("fallback")
```

- [ ] **Step 2: Run RED**

Run:

```bash
python -m pytest tests/test_remote_brain.py::test_remote_brain_uses_valid_http_decision tests/test_remote_brain.py::test_remote_brain_timeout_falls_back_to_local -q
```

Expected: fails because `RemoteBrainConfig` and `RemoteBrainModel` do not exist.

- [ ] **Step 3: Implement the HTTP client**

Add to `alife/remote_brain.py`:

```python
import time
import urllib.error
import urllib.request


@dataclass
class RemoteBrainConfig:
    enabled: bool
    backend: str
    url: str
    model: str
    token: str
    timeout: float = 1.8
    cooldown_seconds: float = 8.0


class RemoteBrainModel:
    def __init__(self, config: RemoteBrainConfig):
        self.config = config
        self.last_status = "disabled"
        self.disabled_until = 0.0

    def available(self) -> bool:
        return self.config.enabled and bool(self.config.url) and time.monotonic() >= self.disabled_until

    def choose(self, payload: dict[str, Any], scores: dict[str, float], fallback: BrainDecision) -> BrainDecision:
        if not self.available():
            self.last_status = "disabled" if not self.config.enabled else "fallback: cooldown"
            return fallback
        try:
            response = self._post(payload)
            decision = parse_remote_decision(response, set(payload["legal_actions"]), scores, fallback.thought)
        except (OSError, TimeoutError, urllib.error.URLError, json.JSONDecodeError) as exc:
            self.disabled_until = time.monotonic() + self.config.cooldown_seconds
            self.last_status = f"fallback: {type(exc).__name__}"
            return fallback
        if decision is None:
            self.disabled_until = time.monotonic() + self.config.cooldown_seconds
            self.last_status = "fallback: invalid response"
            return fallback
        self.last_status = "remote"
        return decision

    def _post(self, payload: dict[str, Any]) -> dict[str, Any]:
        body = self._request_body(payload)
        headers = {"Content-Type": "application/json"}
        if self.config.token:
            headers["Authorization"] = f"Bearer {self.config.token}"
        request = urllib.request.Request(
            self.config.url,
            data=json.dumps(body).encode("utf-8"),
            headers=headers,
            method="POST",
        )
        with urllib.request.urlopen(request, timeout=self.config.timeout) as response:
            return json.loads(response.read().decode("utf-8"))

    def _request_body(self, payload: dict[str, Any]) -> dict[str, Any]:
        system_prompt = (
            "You are Ari's private survival planner. Return only JSON. "
            "Choose exactly one action from legal_actions. "
            "Never invent actions. The simulation rules are final."
        )
        user_prompt = json.dumps(payload, separators=(",", ":"))
        if self.config.backend == "ollama":
            return {
                "model": self.config.model,
                "stream": False,
                "keep_alive": "-1",
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt},
                ],
            }
        return {
            "model": self.config.model,
            "temperature": 0.4,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
        }
```

- [ ] **Step 4: Run GREEN**

Run:

```bash
python -m pytest tests/test_remote_brain.py -q
```

Expected: all remote brain tests pass.

---

### Task 5: Wire Remote Brain Into Day Action Choice

**Files:**
- Modify: `alife/survival.py`
- Modify: `alife/remote_brain.py`
- Test: `tests/test_survival_idle.py`

- [ ] **Step 1: Write failing integration tests**

Append to `tests/test_survival_idle.py`:

```python
from alife.brain import BrainDecision


class StubRemoteBrain:
    def __init__(self, action):
        self.action = action
        self.last_status = "remote"
        self.payloads = []

    def choose(self, payload, scores, fallback):
        self.payloads.append(payload)
        if self.action not in payload["legal_actions"]:
            return fallback
        return BrainDecision(self.action, scores, {self.action: 0.9}, "Remote AI: test choice")


def test_remote_brain_can_choose_legal_day_action():
    world = IdleSurvivalWorld(seed=60)
    world.sign.text = ""
    world.remote_brain = StubRemoteBrain("rest_in_bed")

    action = world.choose_day_action()

    assert action == "rest_in_bed"
    assert world.last_brain_thought.startswith("Remote AI:")
    assert world.last_brain_source == "remote"


def test_remote_brain_cannot_override_unknown_sign_word_research():
    world = IdleSurvivalWorld(seed=61)
    world.survivor.vocabulary = []
    world.write_sign("use bow")
    world.remote_brain = StubRemoteBrain("train_bow")

    action = world.choose_day_action()

    assert action == "research_word"
    assert world.last_brain_source == "local"
```

- [ ] **Step 2: Run RED**

Run:

```bash
python -m pytest tests/test_survival_idle.py::test_remote_brain_can_choose_legal_day_action tests/test_survival_idle.py::test_remote_brain_cannot_override_unknown_sign_word_research -q
```

Expected: fails because `remote_brain` and `last_brain_source` are not wired.

- [ ] **Step 3: Implement wiring**

In `alife/remote_brain.py`, add:

```python
def remote_brain_from_config() -> RemoteBrainModel:
    from config import (
        REMOTE_BRAIN_BACKEND,
        REMOTE_BRAIN_COOLDOWN_SECONDS,
        REMOTE_BRAIN_ENABLED,
        REMOTE_BRAIN_MODEL,
        REMOTE_BRAIN_TIMEOUT,
        REMOTE_BRAIN_TOKEN,
        REMOTE_BRAIN_URL,
    )

    return RemoteBrainModel(
        RemoteBrainConfig(
            enabled=REMOTE_BRAIN_ENABLED,
            backend=REMOTE_BRAIN_BACKEND,
            url=REMOTE_BRAIN_URL,
            model=REMOTE_BRAIN_MODEL,
            token=REMOTE_BRAIN_TOKEN,
            timeout=REMOTE_BRAIN_TIMEOUT,
            cooldown_seconds=REMOTE_BRAIN_COOLDOWN_SECONDS,
        )
    )
```

In `alife/survival.py`, import:

```python
from alife.remote_brain import build_remote_brain_payload, remote_brain_from_config
```

Add fields to `IdleSurvivalWorld`:

```python
last_brain_source: str = "local"
```

In `__post_init__`:

```python
self.remote_brain = remote_brain_from_config()
```

Change `choose_day_action()` after `plans` and local `decision` are created:

```python
local_thought = self.format_brain_decision(decision, plans)
decision.thought = local_thought
payload = build_remote_brain_payload(self, "day_action", plans)
decision = self.remote_brain.choose(payload, scores, decision)
self.last_brain_source = "remote" if getattr(self.remote_brain, "last_status", "") == "remote" else "local"
self.last_brain_thought = decision.thought
return decision.action
```

For unknown sign word and sign-plan hard gates, set:

```python
self.last_brain_source = "local"
```

- [ ] **Step 4: Run GREEN**

Run:

```bash
python -m pytest tests/test_survival_idle.py::test_remote_brain_can_choose_legal_day_action tests/test_survival_idle.py::test_remote_brain_cannot_override_unknown_sign_word_research -q
```

Expected: passes.

---

### Task 6: Wire Remote Brain Into Combat Choice

**Files:**
- Modify: `alife/survival.py`
- Test: `tests/test_survival_idle.py`

- [ ] **Step 1: Write failing combat tests**

Append:

```python
def test_remote_brain_can_choose_legal_combat_action():
    world = IdleSurvivalWorld(seed=62)
    world.sign.text = ""
    world.remote_brain = StubRemoteBrain("hide")

    weapon = world.choose_weapon(enemy_distance=40)

    assert weapon == "hide"
    assert world.last_brain_source == "remote"


def test_remote_brain_cannot_choose_illegal_combat_action():
    world = IdleSurvivalWorld(seed=63)
    world.sign.text = ""
    world.remote_brain = StubRemoteBrain("magic")

    weapon = world.choose_weapon(enemy_distance=40)

    assert weapon in {"bow", "sword", "hide"}
    assert world.last_brain_source == "local"
```

- [ ] **Step 2: Run RED**

Run:

```bash
python -m pytest tests/test_survival_idle.py::test_remote_brain_can_choose_legal_combat_action tests/test_survival_idle.py::test_remote_brain_cannot_choose_illegal_combat_action -q
```

Expected: remote brain is not used by `choose_weapon()` yet.

- [ ] **Step 3: Implement combat payload and call**

In `choose_weapon()`, preserve current hard gates for unknown sign words and direct sign orders. After the local `decision` is created, call remote with a compact combat payload:

```python
payload = build_remote_brain_payload(self, "combat_weapon", {})
payload["legal_actions"] = ["bow", "sword", "hide"]
payload["combat"] = {
    "enemy_distance": round(enemy_distance, 1),
    "bow_score": round(bow_score, 2),
    "sword_score": round(sword_score, 2),
    "hide_score": round(hide_score, 2),
}
decision = self.remote_brain.choose(payload, scores, decision)
self.last_brain_source = "remote" if getattr(self.remote_brain, "last_status", "") == "remote" else "local"
self.last_brain_thought = decision.thought if self.last_brain_source == "remote" else "Combat: " + decision.thought
return decision.action
```

If `build_remote_brain_payload()` expects plan objects, allow an empty plan dict and then explicitly set `legal_actions` and combat data as above.

- [ ] **Step 4: Run GREEN**

Run:

```bash
python -m pytest tests/test_survival_idle.py::test_remote_brain_can_choose_legal_combat_action tests/test_survival_idle.py::test_remote_brain_cannot_choose_illegal_combat_action -q
```

Expected: passes.

---

### Task 7: Show Brain Source and Fallback Status in the HUD

**Files:**
- Modify: `ui/survival_ui.py`
- Test: optional manual smoke; no Pygame rendering unit test required unless a render helper is extracted.

- [ ] **Step 1: Add visible state**

Update the existing brain HUD line in `draw_panel()`:

```python
source = getattr(world, "last_brain_source", "local")
remote_status = getattr(getattr(world, "remote_brain", None), "last_status", "")
if world.last_brain_thought:
    label = f"Brain [{source}]"
    if source == "local" and remote_status.startswith("fallback"):
        label += f" ({remote_status})"
    y = draw_wrapped(surface, small_font, label + ": " + world.last_brain_thought, x, y + 2, 295, (190, 210, 245))
```

- [ ] **Step 2: Manual visual check**

Run:

```bash
python main.py
```

Expected: HUD still fits and shows `Brain [local]: ...` by default.

---

### Task 8: Document Hetzner Server Setup and Security

**Files:**
- Modify: `README.md`
- Create: `docs/hetzner-ai-brain.md`

- [ ] **Step 1: Add dedicated server guide**

Create `docs/hetzner-ai-brain.md` with these sections:

````markdown
# Hetzner Self-Hosted AI Brain

## Safe Default

Do not expose the model server publicly. Bind it to `127.0.0.1` on the Hetzner box and connect from the game through SSH forwarding, Tailscale, or WireGuard.

## Option A: llama.cpp

```bash
sudo useradd --system --home /opt/ari-brain --shell /usr/sbin/nologin ari-brain
sudo mkdir -p /opt/ari-brain
sudo chown ari-brain:ari-brain /opt/ari-brain
```

Install or build llama.cpp using its official instructions, then create `/etc/systemd/system/ari-llama-brain.service`:

```ini
[Unit]
Description=Ari llama.cpp Brain
After=network-online.target
Wants=network-online.target

[Service]
User=ari-brain
WorkingDirectory=/opt/ari-brain
ExecStart=/usr/local/bin/llama-server -hf ggml-org/gemma-3-1b-it-GGUF --host 127.0.0.1 --port 8080 -c 4096 -t 4
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Enable it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now ari-llama-brain
sudo systemctl status ari-llama-brain
```

From the gaming PC:

```bash
ssh -N -L 8080:127.0.0.1:8080 user@YOUR_HETZNER_IP
```

Game env:

```powershell
$env:ARI_REMOTE_BRAIN="1"
$env:ARI_REMOTE_BRAIN_BACKEND="llamacpp"
$env:ARI_REMOTE_BRAIN_URL="http://127.0.0.1:8080/v1/chat/completions"
$env:ARI_REMOTE_BRAIN_MODEL="gemma-3-1b"
python main.py
```

## Option B: Ollama

Install Ollama using its official install instructions, pull a small model:

```bash
ollama pull gemma3:1b
```

Use a systemd override to bind to localhost and keep models loaded:

```bash
sudo systemctl edit ollama
```

```ini
[Service]
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_KEEP_ALIVE=-1"
```

Restart:

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

Forward from the gaming PC:

```bash
ssh -N -L 11434:127.0.0.1:11434 user@YOUR_HETZNER_IP
```

Game env:

```powershell
$env:ARI_REMOTE_BRAIN="1"
$env:ARI_REMOTE_BRAIN_BACKEND="ollama"
$env:ARI_REMOTE_BRAIN_URL="http://127.0.0.1:11434/api/chat"
$env:ARI_REMOTE_BRAIN_MODEL="gemma3:1b"
python main.py
```

## Public HTTPS Option

Only use this if a VPN or SSH tunnel is inconvenient. Put Nginx in front with HTTPS and a bearer token, and keep the model server bound to `127.0.0.1`.

```nginx
location /ari-brain/ {
    if ($http_authorization != "Bearer CHANGE_ME_LONG_RANDOM_TOKEN") { return 401; }
    proxy_pass http://127.0.0.1:8080/;
    proxy_read_timeout 30s;
}
```

Then set:

```powershell
$env:ARI_REMOTE_BRAIN_TOKEN="CHANGE_ME_LONG_RANDOM_TOKEN"
```

## Expected Limits

CPU-only inference can be slow. Ari calls the remote brain only at decision points, and the game falls back to the local planner on timeouts.
````

- [ ] **Step 2: Link the guide from README**

Add a section to `README.md`:

```markdown
## Optional Self-Hosted AI Brain

Ari can optionally use a local model running on your own server. This is disabled by default and the built-in planner remains the fallback. See `docs/hetzner-ai-brain.md` for llama.cpp and Ollama setup, security notes, and environment variables.
```

---

### Task 9: Full Validation

**Files:**
- No new files.

- [ ] **Step 1: Run compile**

Run:

```bash
python -m compileall .
```

Expected: exits with code 0.

- [ ] **Step 2: Run all tests**

Run:

```bash
python -m pytest
```

Expected: all tests pass.

- [ ] **Step 3: Smoke the game**

Run:

```bash
python main.py
```

Expected:
- The game opens.
- Ari moves and makes decisions with `Brain [local]` when no remote env vars are set.
- With an SSH tunnel and remote env vars set, HUD can show `Brain [remote]`.
- If the remote server is stopped, the game continues with local fallback.

## Completion Checklist

- Remote brain disabled by default.
- No OpenAI API usage.
- No paid APIs.
- Local brain remains fully playable.
- Remote model called only at day/combat decision points.
- Remote output is validated JSON.
- Illegal remote actions are rejected.
- Timeout and network failures fall back locally.
- HUD shows local/remote/fallback source.
- Server setup guide includes systemd and security.
- Tests cover state summary, response parsing, invalid output, timeout fallback, and legal action filtering.
- `python -m compileall .` passes.
- `python -m pytest` passes.
