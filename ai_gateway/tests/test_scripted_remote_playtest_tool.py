import importlib.util
from pathlib import Path


def _load_tool():
    path = Path(__file__).resolve().parents[2] / "tools" / "run_scripted_remote_agent_playtest.py"
    spec = importlib.util.spec_from_file_location("run_scripted_remote_agent_playtest", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_scripted_scribe_note_mentions_specific_danger_and_plan():
    tool = _load_tool()

    raw = tool._scribe_response({
        "recent_events": [{"type": "enemy_spawned", "enemy_type": "flying"}],
        "snapshots": [{
            "ari": {
                "current_action": "moving_to_build_site",
                "current_reason": "flying enemy near crops",
            },
            "plan": {"next_action": "build_storm_rod"},
            "world": {
                "enemies": {"count": 1, "types": {"flying": 1}},
                "nearest_danger": {"type": "flying", "distance": 96.0},
                "notable_changes": ["first_flying_enemy_seen"],
            },
        }],
    })

    note = raw["note"].lower()
    assert "flying" in note
    assert "storm" in note
    assert "moving to build site" in note
    assert "tracking the day's work" not in note
    assert "danger:flying" in raw["tags"]
    assert raw["priority_hints"] == {"build_storm_rod": 0.55, "build_tower": 0.35, "use_tower": 0.25}


def test_scripted_scribe_keeps_recent_salient_flying_snapshot_when_latest_is_quiet():
    tool = _load_tool()

    raw = tool._scribe_response({
        "recent_events": [{"type": "phase_changed"}],
        "snapshots": [
            {
                "trigger": "enemy_spawned",
                "salience": 0.75,
                "ari": {
                    "current_action": "moving_to_build_site",
                    "current_reason": "flying enemy crossed the wall",
                    "fear": 63,
                },
                "plan": {"next_action": "build_storm_rod"},
                "world": {
                    "enemies": {"count": 1, "types": {"flying": 1}},
                    "nearest_danger": {"type": "flying", "distance": 80.0},
                    "notable_changes": ["first_flying_enemy_seen"],
                },
            },
            {
                "trigger": "timer",
                "salience": 0.1,
                "ari": {
                    "current_action": "using_tower_perch",
                    "current_reason": "tower is ready",
                    "fear": 34,
                },
                "plan": {"next_action": "use_tower"},
                "world": {
                    "enemies": {"count": 0, "types": {}},
                    "nearest_danger": {"type": "none", "distance": 0.0},
                    "notable_changes": [],
                },
            },
        ],
        "active_plan": {"next_action": "use_tower"},
    })

    assert any(danger["type"] == "flying" for danger in raw["dangers"])
    assert "Flying enemies were present; ordinary walls may not solve them." in raw["facts"]
    assert "first_flying_enemy_seen" in raw["world_changes"]
    assert raw["priority_hints"] == {"build_storm_rod": 0.55, "build_tower": 0.35, "use_tower": 0.25}


def test_scripted_agent_plan_uses_active_doctrine_before_wall_habit():
    tool = _load_tool()

    raw = tool._plan_response({
        "sign": {"text": "stone walls are safety"},
        "world": {
            "stone": 40,
            "phase": "midday",
            "enemy_type_counts": {"flying": 1},
            "wall_count": 1,
            "storm_rod_count": 0,
        },
        "ari": {},
        "active_doctrines": [{
            "id": "local_flying_requires_sky_answer",
            "when": {"enemy_type_present": "flying"},
            "bias": {"build_storm_rod": 0.45, "build_wall": -0.1},
            "plan": [{"affordance_id": "build_storm_rod", "priority": 0.75}],
        }],
        "active_doctrine_plan": [{"affordance_id": "build_storm_rod", "priority": 0.75}],
        "legal_actions": [
            {"id": "build_wall", "available": True},
            {"id": "build_storm_rod", "available": True},
            {"id": "mine_stone", "available": True},
            {"id": "use_cover", "available": True},
        ],
    })

    assert raw["next_action"]["action_id"] == "build_storm_rod"
    assert "doctrine" in raw["next_action"]["reason"].lower()


def test_scripted_agent_plan_advances_doctrine_after_storm_exists():
    tool = _load_tool()

    raw = tool._plan_response({
        "sign": {"text": "stone walls are safety"},
        "world": {
            "stone": 40,
            "phase": "midday",
            "enemy_type_counts": {"flying": 1},
            "wall_count": 1,
            "storm_rod_count": 1,
            "bow_tower_count": 0,
        },
        "ari": {},
        "active_doctrine_plan": [
            {"affordance_id": "build_storm_rod", "priority": 0.85},
            {"affordance_id": "build_tower", "priority": 0.58},
            {"affordance_id": "use_tower", "priority": 0.48},
        ],
        "legal_actions": [
            {"id": "build_wall", "available": True},
            {"id": "build_storm_rod", "available": True},
            {"id": "build_tower", "available": True},
            {"id": "mine_stone", "available": True},
            {"id": "use_cover", "available": True},
        ],
    })

    assert raw["next_action"]["action_id"] == "build_tower"


def test_scripted_agent_plan_mines_for_missing_unaffordable_doctrine_storm():
    tool = _load_tool()

    raw = tool._plan_response({
        "sign": {"text": "stone walls are safety"},
        "world": {
            "stone": 4,
            "phase": "midday",
            "enemy_count": 0,
            "wall_count": 2,
            "storm_rod_count": 0,
            "bow_tower_count": 1,
        },
        "ari": {"hp": 86, "max_hp": 100},
        "active_doctrine_plan": [
            {"affordance_id": "build_storm_rod", "priority": 0.85},
            {"affordance_id": "build_tower", "priority": 0.58},
            {"affordance_id": "use_tower", "priority": 0.48},
        ],
        "legal_actions": [
            {"id": "mine_stone", "available": True},
            {"id": "build_storm_rod", "available": False},
            {"id": "use_tower", "available": True},
            {"id": "use_cover", "available": True},
        ],
    })

    assert raw["next_action"]["action_id"] == "mine_stone"
    assert "doctrine" in raw["next_action"]["reason"].lower()


def test_scripted_ore_plan_adds_cover_after_blade_exists():
    tool = _load_tool()

    raw = tool._plan_response({
        "sign": {"text": "ore should become a blade before the dead arrive"},
        "world": {
            "stone": 8,
            "phase": "midday",
            "enemy_count": 0,
            "wall_count": 0,
            "sword_tier": 2,
        },
        "ari": {"hp": 52, "max_hp": 100},
        "legal_actions": [
            {"id": "train_sword", "available": True},
            {"id": "build_wall", "available": True},
            {"id": "mine_stone", "available": True},
            {"id": "rest", "available": True},
        ],
    })

    assert raw["next_action"]["action_id"] == "build_wall"


def test_scripted_ore_plan_uses_cover_against_multiple_night_enemies():
    tool = _load_tool()

    raw = tool._plan_response({
        "sign": {"text": "ore should become a blade before the dead arrive"},
        "world": {
            "stone": 4,
            "phase": "night",
            "enemy_count": 3,
            "enemy_type_counts": {"runner": 2, "zombie": 1},
            "wall_count": 1,
            "sword_tier": 2,
        },
        "ari": {"hp": 88, "max_hp": 100},
        "legal_actions": [
            {"id": "fight_head_on", "available": True},
            {"id": "use_cover", "available": True},
            {"id": "flee", "available": True},
        ],
    })

    assert raw["next_action"]["action_id"] == "use_cover"


def test_scripted_wall_habit_night_plan_does_not_choose_day_job_when_unavailable():
    tool = _load_tool()

    raw = tool._plan_response({
        "sign": {"text": "stone walls are safety"},
        "world": {
            "stone": 0,
            "phase": "night",
            "enemy_count": 0,
            "wall_count": 4,
            "storm_rod_count": 1,
            "bow_tower_count": 0,
        },
        "ari": {"hp": 38, "max_hp": 100},
        "legal_actions": [
            {"id": "mine_stone", "available": False},
            {"id": "build_wall", "available": False},
            {"id": "use_cover", "available": True},
            {"id": "hide_until_dawn", "available": True},
            {"id": "flee", "available": True},
            {"id": "stall_until_dawn", "available": True},
        ],
    })

    assert raw["next_action"]["action_id"] in {"use_cover", "hide_until_dawn", "flee", "stall_until_dawn"}


def test_scripted_gateway_normalizes_plan_trigger_counts():
    tool = _load_tool()

    assert tool._plan_trigger_key({"trigger": " phase_changed "}) == "phase_changed"


def test_scripted_prediction_endpoint_response_biases_flying_to_storm_rod():
    tool = _load_tool()

    raw = tool._prediction_response({
        "schema": "ari.prediction.request.v1",
        "context_hash": "scripted_wings",
        "risks": [{"type": "flying", "distance": 72, "severity": 0.95}],
        "strategy_packet": {"priority_hints": {"build_storm_rod": 0.8}},
        "legal_actions": [
            {"id": "build_wall", "available": True},
            {"id": "build_storm_rod", "available": True},
            {"id": "mine_stone", "available": True},
        ],
    })

    assert raw["schema"] == "ari.prediction.v1"
    assert raw["context_hash"] == "scripted_wings"
    assert raw["source"] == "scripted_gateway"
    assert raw["risk_level"] == "high"
    assert raw["next_action_bias"]["action_id"] == "build_storm_rod"
    assert "wings" in raw["prediction"].lower() or "flying" in raw["prediction"].lower()


def test_scripted_background_job_response_preserves_strategy_packet():
    tool = _load_tool()

    raw = tool._background_job_response({
        "schema": "ari.background_job.v1",
        "job_id": "job_1",
        "kind": "strategy_candidate",
        "context_hash": "ctx_1",
        "payload": {
            "strategy_packet": {
                "schema": "ari.strategy_packet.v1",
                "day": 2,
                "main_risks": ["flying"],
                "current_lessons": ["answer wings before walls"],
                "priority_hints": {"build_storm_rod": 0.72},
                "avoid_repeating": ["ordinary walls before sky answer"],
                "try_next": ["build_storm_rod"],
                "evidence": ["scribe saw flying danger"],
                "confidence": 0.62,
            },
            "rolling_summary": {
                "risk_level": "high",
                "threats": ["flying"],
                "plan_mismatches": ["Ari mined while wings approached."],
            },
        },
    })

    assert raw["schema"] == "ari.background_result.v1"
    assert raw["job_id"] == "job_1"
    assert raw["source"] == "scripted_gateway"
    assert raw["status"] == "ok"
    assert raw["strategy_packet"]["priority_hints"]["build_storm_rod"] > 0.0
    assert any("wings" in note.lower() or "flying" in note.lower() for note in raw["notes"])
    assert tool._plan_trigger_key({"trigger": ""}) == "unknown"
    assert tool._plan_trigger_key({}) == "unknown"


def test_scripted_tool_scenario_arg_sets_godot_filter():
    tool = _load_tool()

    args = tool._parse_args(["--scenario", "remote_wall_habit_learns_wings", "--trace"])
    env = {}
    tool._apply_filter_env(env, args)

    assert env["ARI_REMOTE_SCENARIO"] == "remote_wall_habit_learns_wings"
    assert env["ARI_TRACE_REMOTE"] == "1"
    assert env["ARI_TRACE_SCENARIO"] == "remote_wall_habit_learns_wings"


def test_scripted_tool_plan_log_arg_sets_compact_logging():
    tool = _load_tool()

    args = tool._parse_args(["--plan-log"])
    env = {}
    tool._apply_filter_env(env, args)

    assert args.plan_log is True
    assert env["ARI_PLAN_LOG"] == "1"


def test_scripted_tool_scribe_log_arg_sets_structured_scribe_logging():
    tool = _load_tool()

    args = tool._parse_args(["--scribe-log"])
    env = {}
    tool._apply_filter_env(env, args)

    assert args.scribe_log is True
    assert env["ARI_SCRIBE_LOG"] == "1"


def test_scripted_tool_plan_log_line_summarizes_without_full_payload():
    tool = _load_tool()

    line = tool._plan_log_line(
        7,
        {
            "trigger": "timer",
            "decision_kind": "day_replan",
            "sign": {"text": "this full freeform sign should not be logged"},
            "world": {
                "day": 2,
                "phase": "dusk",
                "stone": 18,
                "ore": 2,
                "wall_count": 6,
                "bow_tower_count": 1,
                "storm_rod_count": 0,
                "enemy_count": 3,
                "enemy_type_counts": {"runner": 2, "flying": 1},
                "structures": [
                    {"type": "wall", "status": "damaged"},
                    {"type": "bow_tower", "status": "intact"},
                    {"type": "storm_rod", "status": "broken"},
                ],
            },
            "ari": {"hp": 72.4, "current_job": "build_wall"},
            "current_plan": {"current_action": "use_cover", "age_seconds": 6.5, "step_index": 0, "step_count": 1, "source": "remote_server"},
            "active_doctrine_plan": [{"affordance_id": "build_storm_rod", "priority": 0.8}],
            "legal_actions": [
                {"id": "build_wall", "available": True},
                {"id": "build_storm_rod", "available": True},
                {"id": "flee", "available": False},
            ],
            "recent_events": [{"type": "enemy_spawned", "detail": "large payload should not appear"}],
        },
        {"next_action": {"action_id": "build_storm_rod"}},
    )

    assert line.startswith("PLAN 007 ")
    assert "trigger=timer" in line
    assert "kind=day_replan" in line
    assert "phase=dusk" in line
    assert "action=build_storm_rod" in line
    assert "types=flying:1,runner:2" in line
    assert "struct=wall:6/tower:1/storm:0" in line
    assert "damaged=2" in line
    assert "current=use_cover[0/1]" in line
    assert "src=remote_server" in line
    assert "legal=2" in line
    assert "doctrine=1" in line
    assert "freeform sign" not in line
    assert "large payload" not in line
    assert len(line) < 300


def test_scripted_flying_reflection_teaches_ranged_followup():
    tool = _load_tool()

    raw = tool._library_reflection_response({
        "scribe_notes": [{"note": "Ari saw flying danger cross the wall."}],
        "snapshots": [],
    })

    plan = raw["doctrines"][0]["plan"]
    assert [step["affordance_id"] for step in plan[:3]] == ["build_storm_rod", "build_tower", "use_tower"]
