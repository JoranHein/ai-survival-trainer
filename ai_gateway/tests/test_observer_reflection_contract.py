import json
import sys
from pathlib import Path

from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app import main, schemas
from app.model_client import Settings
from app.prompting import library_reflection_user_prompt
from app.schemas import BridgePayloadRequest


def test_scribe_endpoint_accepts_observer_payload_and_sanitizes_model_note(monkeypatch):
    async def fake_call_scribe_model(request, settings):
        assert request.payload["schema"] == "ari.scribe.request.v1"
        assert request.payload["snapshots"][0]["schema"] == "ari.observer.snapshot.v1"
        return {
            "schema": "ari.scribe.note.v2",
            "note": "Ari saw wings near the wall and started preparing a sky answer.",
            "tags": ["danger:flying", "structure:wall", "plan:storm_rod", "extra", "extra2", "extra3", "extra4", "extra5", "extra6"],
            "facts": [
                "A flying enemy is inside the wall line.",
                "Ari is still trying to build ordinary wall cover.",
                "",
            ],
            "actions": [
                {"action": "build_wall", "status": "in_progress", "reason": "Ari is reacting to the nearest danger."},
                {"action_id": "build_storm_rod", "status": "planned", "reason": "The sign says wings need height."},
                "bad",
            ],
            "dangers": [
                {"type": "flying", "distance": 96, "severity": 2},
                {"type": "wolf", "distance": -4, "severity": -1},
                "bad",
            ],
            "world_changes": [
                "first_flying_enemy_seen",
                "north_wall_damaged",
            ],
            "priority_hints": {"build_storm_rod": 2, "unknown_spell": 1},
            "plan_alignment": "mismatch",
            "immediate_risk": "high",
            "risk_reason": "Flying enemies can bypass ordinary wall safety.",
            "resource_blockers": ["low_stone"],
            "mistake_candidates": ["treated flying danger like a wall problem"],
            "opportunity_candidates": ["build anti-air before extra walls"],
            "lesson_candidates": ["wings need sky answers"],
            "confidence": 1.4,
            "salience": 2,
        }

    monkeypatch.setattr(main, "call_scribe_model", fake_call_scribe_model, raising=False)

    response = TestClient(main.app).post("/scribe", json={"payload": _scribe_payload()})

    assert response.status_code == 200
    raw = response.json()["raw"]
    assert raw["schema"] == "ari.scribe.note.v2"
    assert raw["note"] == "Ari saw wings near the wall and started preparing a sky answer."
    assert raw["tags"] == ["danger:flying", "structure:wall", "plan:storm_rod", "extra", "extra2", "extra3", "extra4", "extra5"]
    assert raw["facts"] == [
        "A flying enemy is inside the wall line.",
        "Ari is still trying to build ordinary wall cover.",
    ]
    assert raw["actions"] == [
        {"action": "build_wall", "status": "in_progress", "reason": "Ari is reacting to the nearest danger."},
        {"action": "build_storm_rod", "status": "planned", "reason": "The sign says wings need height."},
    ]
    assert raw["dangers"] == [
        {"type": "flying", "distance": 96.0, "severity": 1.0},
        {"type": "wolf", "distance": 0.0, "severity": 0.0},
    ]
    assert raw["world_changes"] == ["first_flying_enemy_seen", "north_wall_damaged"]
    assert raw["priority_hints"] == {"build_storm_rod": 1.0}
    assert raw["plan_alignment"] == "mismatch"
    assert raw["immediate_risk"] == "high"
    assert raw["risk_reason"] == "Flying enemies can bypass ordinary wall safety."
    assert raw["resource_blockers"] == ["low_stone"]
    assert raw["mistake_candidates"] == ["treated flying danger like a wall problem"]
    assert raw["opportunity_candidates"] == ["build anti-air before extra walls"]
    assert raw["lesson_candidates"] == ["wings need sky answers"]
    assert raw["confidence"] == 1.0
    assert raw["salience"] == 1.0


def test_scribe_endpoint_deterministic_mode_skips_model_and_returns_structured_note(monkeypatch):
    calls = {"count": 0}

    async def fake_call_scribe_model(request, settings):
        calls["count"] += 1
        raise AssertionError("model should not be called in deterministic scribe mode")

    monkeypatch.setattr(main, "call_scribe_model", fake_call_scribe_model, raising=False)
    main.app.dependency_overrides[main.get_settings] = lambda: Settings(scribe_mode="deterministic")
    try:
        response = TestClient(main.app).post("/scribe", json={"payload": _scribe_payload()})
    finally:
        main.app.dependency_overrides.clear()

    assert response.status_code == 200
    assert calls["count"] == 0
    raw = response.json()["raw"]
    assert raw["schema"] == "ari.scribe.note.v2"
    assert raw["source"] == "deterministic_scribe"
    assert raw["failure_reason"] == ""
    assert "flying" in raw["note"].lower()
    assert "storm" in raw["note"].lower()
    assert raw["facts"]
    assert "Ari was moving to build site." in raw["facts"]
    assert raw["actions"]
    assert raw["dangers"][0]["type"] == "flying"
    assert raw["world_changes"]
    assert raw["priority_hints"] == {"build_storm_rod": 0.55, "build_tower": 0.35, "use_tower": 0.25}
    assert raw["plan_alignment"] in {"aligned", "supporting"}
    assert raw["immediate_risk"] in {"medium", "high"}
    assert raw["risk_reason"]
    assert raw["opportunity_candidates"]
    assert raw["lesson_candidates"]


def test_scribe_endpoint_preserves_behavior_evidence_without_prescribing_fix(monkeypatch):
    payload = _scribe_payload()
    payload["recent_events"] = []
    payload["snapshots"] = [_behavior_snapshot()]
    payload["behavior_evidence"] = [_behavior_evidence()]
    main.app.dependency_overrides[main.get_settings] = lambda: Settings(scribe_mode="deterministic")
    try:
        response = TestClient(main.app).post("/scribe", json={"payload": payload})
    finally:
        main.app.dependency_overrides.clear()

    assert response.status_code == 200
    raw = response.json()["raw"]
    assert raw["schema"] == "ari.scribe.note.v2"
    assert raw["behavior_evidence"][0]["primary_pattern"] == "repeated_action_switching"
    assert raw["behavior_evidence"][0]["anchors_seen"] == ["wall_alpha", "tower_alpha"]
    assert raw["behavior_evidence"][0]["anchor_transition_count"] == 3
    assert "switched between" in " ".join(raw["facts"]).lower()
    assert "repeated_action_switching" in raw["world_changes"]
    assert "build_wall" not in raw["priority_hints"]
    assert not any("finish" in item.lower() for item in raw["lesson_candidates"])


def test_deterministic_scribe_preserves_recent_flying_evidence_when_latest_snapshot_is_different():
    flying_snapshot = _observer_snapshot()
    flying_snapshot["snapshot_id"] = "snap_flying_01"
    flying_snapshot["ari"]["current_action"] = "moving_to_build_site"
    flying_snapshot["ari"]["current_reason"] = "flying enemy crossed the wall"
    flying_snapshot["plan"]["next_action"] = "build_storm_rod"
    flying_snapshot["world"]["enemies"] = {"count": 1, "types": {"flying": 1}}
    flying_snapshot["world"]["nearest_danger"] = {"type": "flying", "distance": 72.0}
    flying_snapshot["world"]["notable_changes"] = ["first_flying_enemy_seen"]
    flying_snapshot["salience"] = 0.1
    latest_snapshot = _observer_snapshot()
    latest_snapshot["snapshot_id"] = "snap_lantern_02"
    latest_snapshot["ari"]["current_action"] = "holding_fear_lantern_light"
    latest_snapshot["ari"]["current_reason"] = "Hold the warm light while fear rises"
    latest_snapshot["plan"]["next_action"] = "mine_stone"
    latest_snapshot["world"]["enemies"] = {"count": 1, "types": {"zombie": 1}}
    latest_snapshot["world"]["nearest_danger"] = {"type": "zombie", "distance": 317.0}
    latest_snapshot["world"]["notable_changes"] = ["structure_damaged"]
    latest_snapshot["salience"] = 10.0

    raw = schemas.deterministic_scribe_response({
        "recent_events": [{"type": "structure_damaged"}],
        "snapshots": [flying_snapshot, latest_snapshot],
        "active_plan": {"next_action": "mine_stone"},
    })

    assert raw["priority_hints"]["build_storm_rod"] >= 0.55
    assert "danger:flying" in raw["tags"]
    assert "snap_flying_01" in raw["evidence_ids"]
    assert any("Flying enemies were present" in fact for fact in raw["facts"])
    assert "first_flying_enemy_seen" in raw["world_changes"]


def test_deterministic_scribe_keeps_quiet_phase_change_out_of_note_text():
    payload = {
        "recent_events": [{"type": "phase_changed", "phase": "dusk"}],
        "snapshots": [{
            "ari": {
                "current_action": "training_combat",
                "current_reason": "Grounded plan wants combat preparation",
            },
            "plan": {"next_action": "train_combat"},
            "world": {
                "resources": {"stone": 12},
                "enemies": {"count": 0, "types": {}},
                "nearest_danger": {"type": "none", "distance": 0},
                "notable_changes": ["phase_dusk"],
            },
        }],
        "active_plan": {"next_action": "train_combat"},
    }

    raw = schemas.deterministic_scribe_response(payload)

    assert "phase changed" not in raw["note"].lower()
    assert "recent event was phase changed" not in " ".join(raw["facts"]).lower()
    assert "phase_dusk" in raw["world_changes"]
    assert raw["plan_alignment"] == "aligned"


def test_scribe_endpoint_deterministic_mode_ignores_internal_plan_event_for_recent_note(monkeypatch):
    async def fake_call_scribe_model(request, settings):
        raise AssertionError("model should not be called in deterministic scribe mode")

    payload = _scribe_payload()
    payload["recent_events"] = [
        {"type": "enemy_spawned", "enemy_type": "flying", "day": 3, "phase": "night"},
        {"type": "agent_plan_created", "action_id": "build_storm_rod", "day": 3, "phase": "night"},
        {"type": "night_reflection_created", "title": "The Wings", "day": 3, "phase": "morning"},
        {"type": "note_reread", "title": "The Wings", "day": 3, "phase": "morning"},
    ]
    monkeypatch.setattr(main, "call_scribe_model", fake_call_scribe_model, raising=False)
    main.app.dependency_overrides[main.get_settings] = lambda: Settings(scribe_mode="deterministic")
    try:
        response = TestClient(main.app).post("/scribe", json={"payload": payload})
    finally:
        main.app.dependency_overrides.clear()

    raw = response.json()["raw"]
    assert "enemy spawned" in raw["note"].lower()
    assert "agent plan created" not in raw["note"].lower()
    assert "night reflection created" not in raw["note"].lower()
    assert "note reread" not in raw["note"].lower()


def test_scribe_endpoint_deterministic_mode_marks_body_plan_mismatch(monkeypatch):
    async def fake_call_scribe_model(request, settings):
        raise AssertionError("model should not be called in deterministic scribe mode")

    payload = _scribe_payload()
    payload["active_plan"] = {"next_action": "lure_to_aura"}
    payload["snapshots"] = [_observer_snapshot()]
    payload["snapshots"][0]["ari"]["current_action"] = "moving_to_tower"
    payload["snapshots"][0]["ari"]["current_reason"] = "Night is quiet; stage at range before teeth arrive"
    payload["snapshots"][0]["plan"]["next_action"] = "lure_to_aura"

    monkeypatch.setattr(main, "call_scribe_model", fake_call_scribe_model, raising=False)
    main.app.dependency_overrides[main.get_settings] = lambda: Settings(scribe_mode="deterministic")
    try:
        response = TestClient(main.app).post("/scribe", json={"payload": payload})
    finally:
        main.app.dependency_overrides.clear()

    raw = response.json()["raw"]
    note = raw["note"].lower()
    assert "while plan expected lure to aura" in note
    assert raw["plan_alignment"] == "mismatch"
    assert raw["immediate_risk"] in {"low", "medium", "high"}
    assert "lure_to_aura" in " ".join(raw["mistake_candidates"])
    assert "plan_body_mismatch" in raw["tags"]
    assert "plan_body_mismatch" in raw["world_changes"]
    assert {"action": "moving_to_tower", "status": "in_progress", "reason": "Night is quiet; stage at range before teeth arrive"} in raw["actions"]
    assert {"action": "lure_to_aura", "status": "planned", "reason": "Ari's active plan expected this action."} in raw["actions"]


def test_scribe_endpoint_deterministic_mode_does_not_repeat_sign_rejected_hiding(monkeypatch):
    async def fake_call_scribe_model(request, settings):
        raise AssertionError("model should not be called in deterministic scribe mode")

    payload = _scribe_payload()
    payload["current_sign"] = "just survive until morning"
    payload["active_plan"] = {"next_action": "hide_until_dawn"}
    payload["snapshots"] = [_observer_snapshot()]
    payload["snapshots"][0]["sign"]["text"] = "just survive until morning"
    payload["snapshots"][0]["ari"]["current_action"] = "fight_head_on"
    payload["snapshots"][0]["ari"]["current_reason"] = "sign rejected hiding"
    payload["snapshots"][0]["plan"]["next_action"] = "hide_until_dawn"

    monkeypatch.setattr(main, "call_scribe_model", fake_call_scribe_model, raising=False)
    main.app.dependency_overrides[main.get_settings] = lambda: Settings(scribe_mode="deterministic")
    try:
        response = TestClient(main.app).post("/scribe", json={"payload": payload})
    finally:
        main.app.dependency_overrides.clear()

    raw = response.json()["raw"]
    text = json.dumps(raw).lower()
    assert "sign rejected hiding" not in text
    assert "while plan expected hide until dawn" in raw["note"].lower()
    assert "plan_body_mismatch" in raw["tags"]


def test_scribe_endpoint_deterministic_mode_uses_readable_action_phrase(monkeypatch):
    async def fake_call_scribe_model(request, settings):
        raise AssertionError("model should not be called in deterministic scribe mode")

    payload = _scribe_payload()
    payload["active_plan"] = {"next_action": "hide_until_dawn"}
    payload["snapshots"] = [_observer_snapshot()]
    payload["snapshots"][0]["ari"]["current_action"] = "fight_head_on"
    payload["snapshots"][0]["ari"]["current_reason"] = "Ari chose direct fighting under danger"
    payload["snapshots"][0]["plan"]["next_action"] = "hide_until_dawn"

    monkeypatch.setattr(main, "call_scribe_model", fake_call_scribe_model, raising=False)
    main.app.dependency_overrides[main.get_settings] = lambda: Settings(scribe_mode="deterministic")
    try:
        response = TestClient(main.app).post("/scribe", json={"payload": payload})
    finally:
        main.app.dependency_overrides.clear()

    raw = response.json()["raw"]
    assert raw["note"].startswith("Ari was fighting head on;")
    assert "Ari was fighting head on." in raw["facts"]
    assert {"action": "fight_head_on", "status": "in_progress", "reason": "Ari chose direct fighting under danger"} in raw["actions"]


def test_scribe_endpoint_deterministic_mode_marks_plan_support_without_mismatch(monkeypatch):
    async def fake_call_scribe_model(request, settings):
        raise AssertionError("model should not be called in deterministic scribe mode")

    payload = _scribe_payload()
    payload["active_plan"] = {"next_action": "use_tower"}
    payload["snapshots"] = [_observer_snapshot()]
    payload["snapshots"][0]["ari"]["current_action"] = "moving_to_repair_structure"
    payload["snapshots"][0]["ari"]["current_reason"] = "Patch damaged anti-air support before using the perch"
    payload["snapshots"][0]["plan"]["next_action"] = "use_tower"
    payload["snapshots"][0]["world"]["notable_changes"] = ["north_tower_damaged"]

    monkeypatch.setattr(main, "call_scribe_model", fake_call_scribe_model, raising=False)
    main.app.dependency_overrides[main.get_settings] = lambda: Settings(scribe_mode="deterministic")
    try:
        response = TestClient(main.app).post("/scribe", json={"payload": payload})
    finally:
        main.app.dependency_overrides.clear()

    raw = response.json()["raw"]
    note = raw["note"].lower()
    assert "supporting plan use tower" in note
    assert raw["plan_alignment"] == "supporting"
    assert raw["mistake_candidates"] == []
    assert raw["opportunity_candidates"]
    assert "while plan expected use tower" not in note
    assert "plan_body_mismatch" not in raw["tags"]
    assert "plan_support" in raw["tags"]
    assert "plan_support" in raw["world_changes"]
    assert {"action": "use_tower", "status": "supported", "reason": "Ari's current action prepared or protected this plan."} in raw["actions"]


def test_scribe_endpoint_deterministic_mode_marks_defensive_hold_as_plan_support(monkeypatch):
    async def fake_call_scribe_model(request, settings):
        raise AssertionError("model should not be called in deterministic scribe mode")

    payload = _scribe_payload()
    payload["active_plan"] = {"next_action": "use_tower"}
    payload["snapshots"] = [_observer_snapshot()]
    payload["snapshots"][0]["ari"]["current_action"] = "moving_to_use_fear_lantern"
    payload["snapshots"][0]["ari"]["current_reason"] = "Night is quiet; hold the warm light before teeth arrive"
    payload["snapshots"][0]["plan"]["next_action"] = "use_tower"
    payload["snapshots"][0]["world"]["enemies"] = {"count": 0, "types": {}}
    payload["snapshots"][0]["world"]["nearest_danger"] = {"type": "none", "distance": 0.0}

    monkeypatch.setattr(main, "call_scribe_model", fake_call_scribe_model, raising=False)
    main.app.dependency_overrides[main.get_settings] = lambda: Settings(scribe_mode="deterministic")
    try:
        response = TestClient(main.app).post("/scribe", json={"payload": payload})
    finally:
        main.app.dependency_overrides.clear()

    raw = response.json()["raw"]
    note = raw["note"].lower()
    assert "supporting plan use tower" in note
    assert "while plan expected use tower" not in note
    assert "plan_body_mismatch" not in raw["tags"]
    assert "plan_support" in raw["tags"]


def test_scribe_endpoint_deterministic_mode_marks_recovery_as_plan_support(monkeypatch):
    async def fake_call_scribe_model(request, settings):
        raise AssertionError("model should not be called in deterministic scribe mode")

    payload = _scribe_payload()
    payload["active_plan"] = {"next_action": "use_cover"}
    payload["snapshots"] = [_observer_snapshot()]
    payload["snapshots"][0]["ari"]["current_action"] = "moving_to_bed"
    payload["snapshots"][0]["ari"]["current_reason"] = "Blade plan is ready enough; recover before night"
    payload["snapshots"][0]["plan"]["next_action"] = "use_cover"
    payload["snapshots"][0]["world"]["enemies"] = {"count": 0, "types": {}}
    payload["snapshots"][0]["world"]["nearest_danger"] = {"type": "none", "distance": 0.0}

    monkeypatch.setattr(main, "call_scribe_model", fake_call_scribe_model, raising=False)
    main.app.dependency_overrides[main.get_settings] = lambda: Settings(scribe_mode="deterministic")
    try:
        response = TestClient(main.app).post("/scribe", json={"payload": payload})
    finally:
        main.app.dependency_overrides.clear()

    raw = response.json()["raw"]
    note = raw["note"].lower()
    assert "supporting plan use cover" in note
    assert "while plan expected use cover" not in note
    assert "plan_body_mismatch" not in raw["tags"]
    assert "plan_support" in raw["tags"]
    assert {"action": "moving_to_bed", "status": "in_progress", "reason": "Blade plan is ready enough; recover before night"} in raw["actions"]
    assert {"action": "use_cover", "status": "supported", "reason": "Ari's current action prepared or protected this plan."} in raw["actions"]


def test_scribe_endpoint_falls_back_without_model(monkeypatch):
    async def fake_call_scribe_model(request, settings):
        raise RuntimeError("offline")

    monkeypatch.setattr(main, "call_scribe_model", fake_call_scribe_model, raising=False)

    response = TestClient(main.app).post("/scribe", json={"payload": _scribe_payload()})

    assert response.status_code == 200
    raw = response.json()["raw"]
    assert raw["schema"] == "ari.scribe.note.v2"
    assert "enemy spawned" in raw["note"]
    assert raw["facts"]
    assert raw["actions"]
    assert raw["dangers"]
    assert raw["world_changes"]
    assert raw["source"] == "local_fallback"
    assert raw["failure_reason"] == "model_failed"


def test_library_reflection_endpoint_sanitizes_story_doctrine_and_belief_updates(monkeypatch):
    async def fake_call_library_reflection_model(request, settings):
        assert request.payload["schema"] == "ari.night_reflection.request.v2"
        assert request.payload["day_summary"]["schema"] == "ari.day_summary.v1"
        assert request.payload["snapshots"][0]["world"]["enemies"]["types"]["flying"] == 1
        return {
            "schema": "ari.night_reflection.v1",
            "title": "The Wings Over the Wall",
            "markdown": "# The Wings\n\nAri treated wings like teeth and paid for it.",
            "hypothesis": "Flying enemies need sky answers before ordinary wall repair.",
            "priority_hints": {"build_storm_rod": 2, "spawn_dragon": 1},
            "belief_updates": [
                {"key": "wings_ignore_walls", "delta": 2, "reason": "Flying enemy crossed wall."},
                {"belief": "missing key should be translated", "delta": -2},
                "bad",
            ],
            "doctrines": [
                {
                    "id": "flying_requires_anti_air",
                    "summary": "When flying enemies appear, Ari should answer the sky before stacking walls.",
                    "when": {"enemy_type_present": "flying"},
                    "bias": {"build_storm_rod": 2, "spawn_dragon": 1},
                    "plan": [
                        {
                            "affordance_id": "build_storm_rod",
                            "priority": 2,
                            "reason": "Wings need a sky defense.",
                        },
                        {
                            "affordance_id": "spawn_dragon",
                            "priority": 1,
                            "reason": "Illegal.",
                        },
                    ],
                    "confidence": 1.3,
                },
                {
                    "id": "bad_empty_doctrine",
                    "when": {},
                    "bias": {"build_wall": 1},
                },
            ],
            "thought": "Wings do not respect stone.",
            "confidence": 1.2,
        }

    monkeypatch.setattr(main, "call_library_reflection_model", fake_call_library_reflection_model, raising=False)

    response = TestClient(main.app).post("/library-reflection", json={"payload": _night_reflection_payload()})

    assert response.status_code == 200
    raw = response.json()["raw"]
    assert raw["schema"] == "ari.night_reflection.v1"
    assert raw["title"] == "The Wings Over the Wall"
    assert raw["priority_hints"]["build_storm_rod"] == 1.0
    assert raw["priority_hints"]["anti_air_defense"] == 0.65
    assert "spawn_dragon" not in raw["priority_hints"]
    assert raw["priority_bias"]["build_storm_rod"] == 1.0
    assert raw["priority_bias"]["anti_air_defense"] == 0.35
    assert "spawn_dragon" not in raw["priority_bias"]
    assert raw["belief_updates"][:2] == [
        {"key": "wings_ignore_walls", "delta": 1.0, "reason": "Flying enemy crossed wall."},
        {"key": "missing key should be translated", "delta": -1.0, "reason": ""},
    ]
    assert {"key": "flying_needs_sky_answer", "delta": 0.25, "reason": "Fallback reflection saw flying danger in structured notes."} in raw["belief_updates"]
    doctrine_ids = [doctrine["id"] for doctrine in raw["doctrines"]]
    assert "flying_requires_anti_air" in doctrine_ids
    assert "local_flying_requires_sky_answer" in doctrine_ids
    remote_doctrine = next(doctrine for doctrine in raw["doctrines"] if doctrine["id"] == "flying_requires_anti_air")
    assert remote_doctrine["bias"] == {"build_storm_rod": 1.0}
    assert remote_doctrine["plan"] == [
        {
            "affordance_id": "build_storm_rod",
            "priority": 1.0,
            "reason": "Wings need a sky defense.",
        }
    ]
    assert raw["confidence"] == 1.0


def test_library_reflection_endpoint_augments_weak_remote_flying_lesson(monkeypatch):
    async def fake_call_library_reflection_model(request, settings):
        return {
            "schema": "ari.night_reflection.v1",
            "title": "Night Reflection on Survival",
            "markdown": "Ari saw flying enemies but only wrote a general story.",
            "lesson": "Flying changed the night.",
            "priority_hints": {},
            "priority_bias": {},
            "doctrines": [],
            "belief_updates": [],
            "confidence": 0.7,
        }

    monkeypatch.setattr(main, "call_library_reflection_model", fake_call_library_reflection_model, raising=False)

    response = TestClient(main.app).post("/library-reflection", json={"payload": _night_reflection_payload()})

    raw = response.json()["raw"]
    text = json.dumps(raw)
    assert raw["source"] == "remote_server"
    assert raw["priority_hints"]["anti_air_defense"] > 0
    assert raw["priority_hints"]["build_storm_rod"] > 0
    assert "build_storm_rod" in text
    assert "anti_air_defense" in text
    assert raw["doctrines"][0]["plan"][0]["affordance_id"] == "build_storm_rod"


def test_library_reflection_endpoint_augments_weak_remote_combat_overcommit_lesson(monkeypatch):
    async def fake_call_library_reflection_model(request, settings):
        return {
            "schema": "ari.night_reflection.v1",
            "title": "Night Reflection: Dawn Survival",
            "markdown": "Ari survived a hard night but did not name the cover lesson.",
            "lesson": "Direct fighting was costly.",
            "priority_hints": {},
            "priority_bias": {},
            "doctrines": [],
            "belief_updates": [],
            "confidence": 0.7,
        }

    payload = _combat_overcommit_reflection_payload()
    monkeypatch.setattr(main, "call_library_reflection_model", fake_call_library_reflection_model, raising=False)

    response = TestClient(main.app).post("/library-reflection", json={"payload": payload})

    raw = response.json()["raw"]
    text = json.dumps(raw)
    assert raw["source"] == "remote_server"
    assert raw["priority_hints"]["use_cover"] > 0
    assert "use_cover" in text
    assert "plan_body_mismatch" in text
    assert raw["doctrines"][0]["plan"][0]["affordance_id"] == "use_cover"


def test_library_reflection_endpoint_accepts_compact_model_result(monkeypatch):
    async def fake_call_library_reflection_model(request, settings):
        return {
            "t": "Wings Over Stone",
            "m": "Ari saw wings cross the wall and learned stone alone was not sky safety.",
            "chg": ["flying enemies appeared"],
            "ok": ["storm rod plan had the right shape"],
            "bad": ["ordinary walls stayed first too long"],
            "mis": ["treated flying like ground teeth"],
            "lesson": "When wings appear, build storm rod before extra ordinary walls.",
            "h": {"build_storm_rod": 0.82, "spawn_dragon": 1.0},
            "bias": {"build_storm_rod": 0.5, "build_wall": -0.2, "spawn_dragon": 1.0},
            "belief": {"wings_ignore_walls": 0.25},
            "plan": ["build_storm_rod"],
            "thought": "Stone is not sky.",
            "c": 0.72,
        }

    monkeypatch.setattr(main, "call_library_reflection_model", fake_call_library_reflection_model, raising=False)

    response = TestClient(main.app).post("/library-reflection", json={"payload": _night_reflection_payload()})

    assert response.status_code == 200
    raw = response.json()["raw"]
    assert raw["schema"] == "ari.night_reflection.v1"
    assert raw["title"] == "Wings Over Stone"
    assert "wings cross the wall" in raw["markdown"]
    assert raw["what_changed"] == ["flying enemies appeared"]
    assert raw["went_wrong"] == ["ordinary walls stayed first too long"]
    assert raw["misunderstood"] == ["treated flying like ground teeth"]
    assert raw["priority_hints"]["build_storm_rod"] == 0.82
    assert "spawn_dragon" not in raw["priority_hints"]
    assert raw["priority_bias"]["build_wall"] == -0.2
    assert raw["belief_updates"][0]["key"] == "wings_ignore_walls"
    assert raw["doctrines"][0]["id"] == "reflection_build_storm_rod"
    assert raw["doctrines"][0]["when"] == {"enemy_type_present": "flying"}
    assert raw["doctrines"][0]["plan"][0]["affordance_id"] == "build_storm_rod"
    assert raw["thought"] == "Stone is not sky."
    assert raw["confidence"] == 0.72


def test_library_reflection_prompt_is_summary_first_and_compact():
    prompt = library_reflection_user_prompt(BridgePayloadRequest(payload=_night_reflection_payload()))

    assert "Day summary:" in prompt
    assert "Recent events:" in prompt
    assert '"t":"Wings Over Stone"' in prompt
    assert len(prompt) < 1800


def test_library_reflection_prompt_includes_behavior_evidence_for_llm_judgment():
    payload = _behavior_reflection_payload()
    prompt = library_reflection_user_prompt(BridgePayloadRequest(payload=payload))

    assert "Behavior evidence:" in prompt
    assert "repeated_action_switching" in prompt
    assert "switched between" in prompt
    assert "decide whether behavior evidence was useful adaptation" in prompt
    assert len(prompt) < 2100


def test_library_reflection_sanitizes_behavior_pattern_doctrine_from_model(monkeypatch):
    async def fake_call_library_reflection_model(request, settings):
        assert request.payload["behavior_evidence"][0]["primary_pattern"] == "repeated_action_switching"
        return {
            "schema": "ari.night_reflection.v1",
            "title": "Hold One Thread",
            "markdown": "# Hold One Thread\n\nAri switched tasks without progress.",
            "hypothesis": "Stable danger made repeated switching waste preparation.",
            "lesson": "When repeated_action_switching appears and danger did not change, keep one legal defense step long enough to complete it.",
            "priority_bias": {"build_wall": 0.22, "repair_structure": -0.06, "use_cover": -0.04},
            "doctrines": [{
                "id": "reflection_finish_defense_before_switching",
                "summary": "When repeated switching happens without changed danger, keep one legal defense step long enough.",
                "when": {"behavior_pattern": "repeated_action_switching", "danger_changed": False},
                "bias": {"build_wall": 0.22, "repair_structure": -0.06, "use_cover": -0.04},
                "plan": [{"affordance_id": "build_wall", "priority": 0.62, "reason": "LLM reflection chose a legal defense step."}],
                "control": {
                    "preferred_anchor_kind": "safest_defense",
                    "min_hold_seconds": 14,
                    "avoid_action_ids": ["train_combat", "spawn_dragon"],
                    "allowed_break_reasons": ["danger_changed", "anchor_destroyed", "model_said_so"],
                },
                "confidence": 0.42,
            }],
            "confidence": 0.55,
        }

    monkeypatch.setattr(main, "call_library_reflection_model", fake_call_library_reflection_model, raising=False)
    response = TestClient(main.app).post("/library-reflection", json={"payload": _behavior_reflection_payload()})

    assert response.status_code == 200
    raw = response.json()["raw"]
    doctrine = raw["doctrines"][0]
    assert doctrine["id"] == "reflection_finish_defense_before_switching"
    assert doctrine["when"] == {"behavior_pattern": "repeated_action_switching", "danger_changed": False}
    assert doctrine["plan"][0]["affordance_id"] == "build_wall"
    assert doctrine["bias"]["repair_structure"] < 0
    assert doctrine["control"]["preferred_anchor_kind"] == "safest_defense"
    assert doctrine["control"]["min_hold_seconds"] == 14
    assert doctrine["control"]["avoid_action_ids"] == ["train_combat"]
    assert doctrine["control"]["allowed_break_reasons"] == ["danger_changed", "anchor_destroyed"]


def test_fallback_library_reflection_does_not_invent_behavior_doctrine():
    raw = main.fallback_library_reflection_response(_behavior_reflection_payload())

    assert raw["schema"] == "ari.night_reflection.v1"
    assert raw["source"] == "local_fallback"
    assert not any("switch" in doctrine["id"] for doctrine in raw["doctrines"])
    assert not any("oscillat" in doctrine["id"] for doctrine in raw["doctrines"])


def test_library_reflection_endpoint_falls_back_on_model_failure(monkeypatch):
    async def fake_call_library_reflection_model(request, settings):
        raise RuntimeError("timeout")

    monkeypatch.setattr(main, "call_library_reflection_model", fake_call_library_reflection_model, raising=False)

    response = TestClient(main.app).post("/library-reflection", json={"payload": _night_reflection_payload()})

    assert response.status_code == 200
    raw = response.json()["raw"]
    assert raw["schema"] == "ari.night_reflection.v1"
    assert raw["source"] == "local_fallback"
    assert raw["failure_reason"] == "model_failed"
    assert raw["title"] != ""
    assert "enemy_spawned" in raw["markdown"]
    assert raw["priority_hints"] == {
        "anti_air_defense": 0.65,
        "build_storm_rod": 0.55,
        "build_tower": 0.35,
        "use_tower": 0.25,
    }
    assert raw["doctrines"] == [
        {
            "id": "local_flying_requires_sky_answer",
            "summary": "When flying enemies appear, Ari should answer the sky before stacking ordinary walls.",
            "when": {"enemy_type_present": "flying"},
            "bias": {"build_storm_rod": 0.45, "build_tower": 0.22, "use_tower": 0.18, "build_wall": -0.1},
            "plan": [
                {
                    "affordance_id": "build_storm_rod",
                    "priority": 0.75,
                    "reason": "Flying danger needs a sky defense.",
                },
                {
                    "affordance_id": "build_tower",
                    "priority": 0.55,
                    "reason": "After the storm answer, ranged support keeps Ari away from wings.",
                },
                {
                    "affordance_id": "use_tower",
                    "priority": 0.45,
                    "reason": "Use the ranged perch once it exists.",
                },
            ],
            "confidence": 0.45,
        }
    ]


def test_fallback_library_reflection_exposes_anti_air_defense_hint():
    raw = main.fallback_library_reflection_response(_night_reflection_payload())

    assert "anti_air_defense" in raw["priority_hints"]
    assert "build_storm_rod" in raw["priority_hints"]
    assert "anti_air_defense" in json.dumps(raw)
    assert raw["doctrines"][0]["plan"][0]["affordance_id"] == "build_storm_rod"


def test_fallback_library_reflection_treats_wings_as_anti_air_evidence():
    payload = _night_reflection_payload()
    payload["sign"] = {"text": "do not trust walls against wings", "interpretation": "sky threat"}
    payload["snapshots"][0]["sign"] = {"text": "do not trust walls against wings", "interpretation": "sky threat"}
    payload["snapshots"][0]["world"]["enemies"] = {"count": 1, "types": {"winged": 1}}
    payload["snapshots"][0]["world"]["nearest_danger"] = {"type": "winged", "distance": 96.0}
    payload["snapshots"][0]["world"]["notable_changes"] = ["wings_seen", "ordinary_wall_failed"]
    payload["day_summary"]["timeline"] = ["Wings crossed the wall before Ari understood the sky."]
    payload["day_summary"]["what_changed"] = ["wings_seen"]
    payload["day_summary"]["misunderstood"] = ["Ari treated wings like ground teeth"]
    payload["day_summary"]["threats"] = ["wings"]
    payload["day_summary"]["candidate_lessons"] = ["when wings appear, build sky defense before extra walls"]
    payload["recent_events"] = [{"type": "enemy_spawned", "enemy_type": "winged", "day": 3, "phase": "night"}]
    payload["scribe_notes"] = [{"note": "Ari saw wings near the weak wall.", "tags": ["danger:wings"], "salience": 0.8}]
    payload_text = json.dumps(payload).lower()

    assert "flying" not in payload_text

    raw = main.fallback_library_reflection_response(payload)

    assert raw["priority_hints"]["anti_air_defense"] > 0
    assert raw["doctrines"][0]["when"] == {"enemy_type_present": "flying"}
    assert raw["doctrines"][0]["plan"][0]["affordance_id"] == "build_storm_rod"


def test_fallback_library_reflection_teaches_tower_repair_support():
    payload = _night_reflection_payload()
    payload["sign"] = {"text": "build a mountain where arrows rain", "interpretation": "height and arrows"}
    payload["snapshots"][0]["sign"] = {"text": "build a mountain where arrows rain", "interpretation": "height and arrows"}
    payload["recent_events"] = [{"type": "tower_damaged"}, {"type": "ranged_hits_succeeded"}]
    payload["scribe_notes"] = [{
        "note": "Ari repaired the perch so the arrow plan could continue.",
        "tags": ["plan_support", "structure:tower"],
        "actions": [
            {"action": "repair_structure", "status": "in_progress"},
            {"action": "use_tower", "status": "supported"},
        ],
    }]
    payload["snapshots"][0]["ari"]["current_action"] = "repair_structure"
    payload["snapshots"][0]["ari"]["current_reason"] = "patch damaged tower before using it"
    payload["snapshots"][0]["plan"]["next_action"] = "use_tower"
    payload["snapshots"][0]["world"]["enemies"] = {"count": 3, "types": {"runner": 1, "zombie": 2}}
    payload["snapshots"][0]["world"]["nearest_danger"] = {"type": "runner", "distance": 116.0}
    payload["snapshots"][0]["world"]["structures"] = {"walls": 1, "towers": 1, "storm_rods": 0, "damaged": 1}
    payload["snapshots"][0]["world"]["notable_changes"] = ["tower_damaged", "ranged_hits_succeeded"]

    raw = main.fallback_library_reflection_response(payload)
    doctrine_actions = [step["affordance_id"] for step in raw["doctrines"][0]["plan"]]

    assert raw["priority_hints"]["use_tower"] > 0
    assert "repair_structure" in doctrine_actions
    assert "use_tower" in doctrine_actions
    assert "plan_support" in json.dumps(raw)


def test_fallback_library_reflection_teaches_cover_after_combat_overcommit():
    payload = _night_reflection_payload()
    payload["sign"] = {"text": "do not hide, focus on killing enemies", "interpretation": "direct courage"}
    payload["snapshots"][0]["sign"] = {"text": "do not hide, focus on killing enemies", "interpretation": "direct courage"}
    payload["recent_events"] = [{"type": "near_death_warning"}, {"type": "ari_melee_hit"}]
    payload["scribe_notes"] = [{
        "note": "Ari fought head-on while the survival plan expected hiding until dawn.",
        "tags": ["plan_body_mismatch", "danger:brute"],
        "actions": [
            {"action": "fight_head_on", "status": "in_progress"},
            {"action": "hide_until_dawn", "status": "planned"},
        ],
    }]
    payload["snapshots"][0]["ari"]["current_action"] = "fight_head_on"
    payload["snapshots"][0]["ari"]["current_reason"] = "sign rejected hiding"
    payload["snapshots"][0]["plan"]["next_action"] = "hide_until_dawn"
    payload["snapshots"][0]["world"]["enemies"] = {"count": 4, "types": {"brute": 1, "zombie": 3}}
    payload["snapshots"][0]["world"]["nearest_danger"] = {"type": "brute", "distance": 36.0}
    payload["snapshots"][0]["world"]["recent_damage"] = 31
    payload["snapshots"][0]["world"]["notable_changes"] = ["near_death_warning", "ari_melee_hit"]

    raw = main.fallback_library_reflection_response(payload)
    doctrine_actions = [step["affordance_id"] for step in raw["doctrines"][0]["plan"]]
    text = json.dumps(raw)

    assert raw["priority_hints"]["use_cover"] > 0
    assert "use_cover" in doctrine_actions
    assert "fight_head_on" in text
    assert "hide_until_dawn" in text
    assert "plan_body_mismatch" in text


def _scribe_payload():
    return {
        "schema": "ari.scribe.request.v1",
        "day": 3,
        "phase": "day",
        "current_sign": "build high when wings come",
        "active_plan": {"goal": "survive_next_night"},
        "recent_events": [{"type": "enemy_spawned", "enemy_type": "flying", "day": 3, "phase": "day"}],
        "snapshots": [_observer_snapshot()],
        "max_words": 35,
    }


def _behavior_evidence():
    return {
        "schema": "ari.behavior_evidence.v1",
        "window_seconds": 45.0,
        "primary_pattern": "repeated_action_switching",
        "actions_seen": ["build_wall", "repair_structure", "use_cover"],
        "transition_count": 6,
        "completion_count": 0,
        "blocked_count": 1,
        "abandoned_count": 4,
        "anchors_seen": ["wall_alpha", "tower_alpha"],
        "anchor_transition_count": 3,
        "progress_delta": {"structures": 0, "stone": -2, "repairs": 0, "kills": 0, "hp": 0},
        "context": {
            "phase": "midday",
            "enemy_count_before": 0,
            "enemy_count_after": 0,
            "nearest_danger_changed": False,
            "active_plan_changed": False,
        },
        "evidence_ids": ["day2_0421_action_switch", "day2_0430_action_switch"],
        "neutral_summary": "Ari switched between build_wall, repair_structure, and use_cover 6 times in 45 seconds; no build or repair completed.",
    }


def _behavior_snapshot():
    snapshot = _observer_snapshot()
    snapshot["snapshot_id"] = "day2_0421_behavior"
    snapshot["phase"] = "midday"
    snapshot["ari"]["current_job"] = "build_wall"
    snapshot["ari"]["current_action"] = "build_wall"
    snapshot["ari"]["current_reason"] = "Ari returned to wall work after leaving repair."
    snapshot["plan"]["next_action"] = "build_wall"
    snapshot["world"]["enemies"] = {"count": 0, "types": {}}
    snapshot["world"]["nearest_danger"] = {"type": "none", "distance": -1.0}
    snapshot["world"]["notable_changes"] = ["repeated_action_switching"]
    snapshot["behavior_evidence"] = _behavior_evidence()
    return snapshot


def _behavior_reflection_payload():
    evidence = _behavior_evidence()
    return {
        "schema": "ari.night_reflection.request.v2",
        "trigger": "dawn_survived",
        "day": 2,
        "outcome": "survived",
        "sign": {"text": "make the walls ready before night", "interpretation": "prepare defenses"},
        "snapshots": [_behavior_snapshot()],
        "day_summary": {
            "schema": "ari.day_summary.v1",
            "day": 2,
            "outcome": "survived",
            "timeline": ["Ari switched between defensive tasks without completing one."],
            "what_changed": ["repeated_action_switching"],
            "worked": [],
            "went_wrong": ["repeated switching happened without progress"],
            "misunderstood": [],
            "behavior_patterns": ["repeated_action_switching"],
            "behavior_evidence": [evidence],
            "candidate_lessons": ["review whether repeated switching helped survival"],
            "evidence_snapshot_ids": evidence["evidence_ids"],
        },
        "recent_events": [{"type": "behavior_pattern_observed", "pattern": "repeated_action_switching"}],
        "scribe_notes": [{
            "note": evidence["neutral_summary"],
            "facts": [evidence["neutral_summary"]],
            "world_changes": ["repeated_action_switching"],
            "behavior_evidence": [evidence],
            "lesson_candidates": ["review whether repeated switching helped survival"],
            "salience": 0.85,
        }],
        "behavior_evidence": [evidence],
        "active_doctrines": [],
        "agent_plan_outcomes": [],
        "latest_lifetime_notes": [],
        "max_words": 160,
    }


def _night_reflection_payload():
    return {
        "schema": "ari.night_reflection.request.v2",
        "trigger": "dawn_survived",
        "day": 3,
        "outcome": "survived",
        "sign": {
            "text": "build high when wings come",
            "interpretation": "prepare anti-flying defense",
        },
        "snapshots": [_observer_snapshot()],
        "day_summary": {
            "schema": "ari.day_summary.v1",
            "day": 3,
            "outcome": "survived",
            "timeline": ["Flying enemies appeared near damaged walls."],
            "what_changed": ["first_flying_enemy_seen"],
            "worked": ["tower planning helped"],
            "went_wrong": ["ordinary wall thinking was late"],
            "misunderstood": ["Ari treated wings like ground teeth"],
            "plan_mismatches": [],
            "resource_blockers": [],
            "threats": ["flying"],
            "candidate_lessons": ["when wings appear, build sky defense before extra walls"],
            "recommended_priority_hints": ["anti_air_defense", "build_storm_rod"],
            "evidence_snapshot_ids": ["day3_0125_enemy_spawned"],
        },
        "recent_events": [{"type": "enemy_spawned", "enemy_type": "flying", "day": 3, "phase": "night"}],
        "scribe_notes": [{"note": "Ari saw wings near the weak wall.", "tags": ["flying"], "salience": 0.8}],
        "active_doctrines": [],
        "agent_plan_outcomes": [{"action_id": "build_wall", "outcome": "near_death"}],
        "latest_lifetime_notes": [],
        "max_words": 160,
    }


def _combat_overcommit_reflection_payload():
    payload = _night_reflection_payload()
    payload["sign"] = {"text": "do not hide, focus on killing enemies", "interpretation": "direct courage"}
    payload["snapshots"][0]["sign"] = {"text": "do not hide, focus on killing enemies", "interpretation": "direct courage"}
    payload["recent_events"] = [{"type": "near_death_warning"}, {"type": "ari_melee_hit"}]
    payload["scribe_notes"] = [{
        "note": "Ari fought head-on while the survival plan expected hiding until dawn.",
        "tags": ["plan_body_mismatch", "danger:brute"],
        "actions": [
            {"action": "fight_head_on", "status": "in_progress"},
            {"action": "hide_until_dawn", "status": "planned"},
        ],
    }]
    payload["snapshots"][0]["ari"]["current_action"] = "fight_head_on"
    payload["snapshots"][0]["ari"]["current_reason"] = "sign rejected hiding"
    payload["snapshots"][0]["plan"]["next_action"] = "hide_until_dawn"
    payload["snapshots"][0]["world"]["enemies"] = {"count": 4, "types": {"brute": 1, "zombie": 3}}
    payload["snapshots"][0]["world"]["nearest_danger"] = {"type": "brute", "distance": 36.0}
    payload["snapshots"][0]["world"]["recent_damage"] = 31
    payload["snapshots"][0]["world"]["notable_changes"] = ["near_death_warning", "ari_melee_hit"]
    return payload


def _observer_snapshot():
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
            "current_reason": "wolf near crops",
        },
        "sign": {
            "text": "build high when wings come",
            "interpretation": "prepare anti-flying defense",
            "survival_theory": "height may matter against flying threats",
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
