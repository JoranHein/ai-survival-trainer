import importlib.util
import json
from pathlib import Path


def _load_tool():
    path = Path(__file__).resolve().parents[2] / "tools" / "analyze_plan_log.py"
    spec = importlib.util.spec_from_file_location("analyze_plan_log", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_plan_log_analyzer_counts_triggers_and_scribe_mismatches():
    tool = _load_tool()
    text = "\n".join(
        [
            "PLAN 001 trigger=phase_changed kind=night_emergency day=1 phase=night action=use_tower job=wait_or_idle hp=100 enemy=0 types=none res=stone:0/ore:0 struct=wall:1/tower:1/storm:0 damaged=0 current=use_tower[0/1] age=10s src=remote_server legal=16 doctrine=0",
            "PLAN 002 trigger=timer kind=day_replan day=2 phase=morning action=build_wall job=mine_stone hp=90 enemy=0 types=none res=stone:8/ore:0 struct=wall:1/tower:1/storm:0 damaged=0 current=mine_stone[0/1] age=30s src=remote_server legal=30 doctrine=0",
            "Scribe note created: Ari was moving to tower; while plan expected lure to aura; recent event was phase changed.",
        ]
    )

    summary = tool.analyze_text(text)

    assert summary["planner_calls"] == 2
    assert summary["trigger_counts"] == {"phase_changed": 1, "timer": 1}
    assert summary["phase_counts"] == {"night": 1, "morning": 1}
    assert summary["scribe_body_plan_mismatches"] == 1
    assert summary["night_illegal_actions"] == []


def test_plan_log_analyzer_counts_plan_support_separately_from_mismatch():
    tool = _load_tool()
    text = "\n".join(
        [
            "PLAN 001 trigger=timer kind=day_replan day=2 phase=midday action=use_tower job=repair_structure hp=90 enemy=0 types=none res=stone:8/ore:0 struct=wall:1/tower:1/storm:0 damaged=1 current=use_tower[0/1] age=30s src=remote_server legal=30 doctrine=0",
            "Scribe note created: Ari was moving to repair structure; supporting plan use tower; recent event was structure damaged.",
        ]
    )

    summary = tool.analyze_text(text)

    assert summary["scribe_plan_supports"] == 1
    assert summary["scribe_body_plan_mismatches"] == 0


def test_plan_log_analyzer_does_not_double_count_structured_scribe_echoes():
    tool = _load_tool()
    text = "\n".join(
        [
            "Scribe note created: Ari was fighting head on; while plan expected hide until dawn; recent event was structure damaged.",
            'SCRIBE {"schema":"ari.scribe.log.v1","note":"Ari was fighting head on; while plan expected hide until dawn; recent event was structure damaged.","tags":["plan_body_mismatch"],"facts":["Ari was fighting head on."],"actions":[{"action":"fight_head_on","status":"in_progress"},{"action":"hide_until_dawn","status":"planned"}],"dangers":[{"type":"zombie","distance":38.0}],"world_changes":["plan_body_mismatch"],"priority_hints":{},"source":"local_fallback","confidence":0.25}',
            "Scribe note created: Ari was repairing structure; supporting plan use tower; recent event was structure damaged.",
            'SCRIBE {"schema":"ari.scribe.log.v1","note":"Ari was repairing structure; supporting plan use tower; recent event was structure damaged.","tags":["plan_support"],"facts":["Ari was repairing structure."],"actions":[{"action":"repair_structure","status":"in_progress"},{"action":"use_tower","status":"supported"}],"dangers":[],"world_changes":["plan_support"],"priority_hints":{},"source":"local_fallback","confidence":0.25}',
        ]
    )

    summary = tool.analyze_text(text)

    assert summary["scribe_body_plan_mismatches"] == 1
    assert summary["scribe_plan_supports"] == 1
    assert summary["structured_scribe_plan_mismatch_tags"] == 1
    assert summary["structured_scribe_plan_support_tags"] == 1


def test_plan_log_analyzer_parses_structured_scribe_json_lines():
    tool = _load_tool()
    text = "\n".join(
        [
            'SCRIBE {"schema":"ari.scribe.log.v1","note":"Ari saw wings.","tags":["danger:flying","plan_body_mismatch"],"facts":["Flying enemy crossed the wall."],"actions":[{"action":"build_storm_rod","status":"planned"}],"dangers":[{"type":"flying","distance":96.0}],"world_changes":["first_flying_enemy_seen"],"priority_hints":{"build_storm_rod":0.55},"source":"deterministic_scribe","confidence":0.8}',
            'SCRIBE {"schema":"ari.scribe.log.v1","note":"Ari repaired tower support.","tags":["plan_support"],"facts":[],"actions":[{"action":"repair_structure","status":"in_progress"}],"dangers":[],"world_changes":[],"priority_hints":{},"source":"local_fallback","confidence":0.25}',
            'SCRIBE not-json',
        ]
    )

    summary = tool.analyze_text(text)

    assert summary["structured_scribe_logs"] == 2
    assert summary["malformed_scribe_logs"] == 1
    assert summary["structured_scribe_with_facts"] == 1
    assert summary["structured_scribe_with_actions"] == 2
    assert summary["structured_scribe_with_dangers"] == 1
    assert summary["structured_scribe_with_priority_hints"] == 1
    assert summary["structured_scribe_plan_mismatch_tags"] == 1
    assert summary["structured_scribe_plan_support_tags"] == 1
    assert summary["structured_scribe_sources"] == {"deterministic_scribe": 1, "local_fallback": 1}


def test_plan_log_analyzer_does_not_count_structured_phase_echo_as_phase_dominated():
    tool = _load_tool()
    note = "Ari was mining; because Keep repair stone ready; recent event was phase changed."
    text = "\n".join(
        [
            f"Scribe note created: {note}",
            'SCRIBE {"schema":"ari.scribe.log.v1","note":"%s","tags":["phase_changed"],"facts":["Ari was mining."],"actions":[{"action":"mining","status":"in_progress"}],"dangers":[],"world_changes":["phase_midday"],"priority_hints":{},"resource_blockers":["low_stone"],"source":"scripted_gateway","confidence":0.25}' % note,
            "Scribe note created: Ari was idle; recent event was phase changed.",
        ]
    )

    summary = tool.analyze_text(text)

    assert summary["structured_scribe_logs"] == 1
    assert summary["scribe_phase_dominated_notes"] == 1


def test_plan_log_analyzer_cli_can_fail_without_structured_scribe_logs(tmp_path):
    tool = _load_tool()
    log = tmp_path / "plan.log"
    log.write_text(
        "Scribe note created: Ari was using tower perch; plan was use tower.\n",
        encoding="utf-8",
    )

    exit_code = tool.main([str(log), "--fail-without-structured-scribe"])

    assert exit_code == 7


def test_plan_log_analyzer_flags_day_only_night_actions(tmp_path):
    tool = _load_tool()
    log = tmp_path / "plan.log"
    log.write_text(
        "PLAN 003 trigger=phase_changed kind=night_emergency day=1 phase=night action=mine_stone job=build_wall hp=80 enemy=0 types=none res=stone:0/ore:0 struct=wall:0/tower:0/storm:0 damaged=0 current=mine_stone[0/1] age=5s src=remote_server legal=16 doctrine=0\n",
        encoding="utf-8",
    )

    summary = tool.analyze_file(log)

    assert summary["planner_calls"] == 1
    assert summary["night_illegal_actions"] == [
        {
            "plan_number": 3,
            "phase": "night",
            "action": "mine_stone",
            "job": "build_wall",
            "trigger": "phase_changed",
        }
    ]


def test_plan_log_analyzer_flags_non_executable_plan_actions(tmp_path):
    tool = _load_tool()
    log = tmp_path / "plan.log"
    log.write_text(
        "PLAN 004 trigger=structure_destroyed kind=day_replan day=3 phase=night action=rely_on_regen job=use_tower hp=36 enemy=2 types=zombie:1,brute:1 res=stone:7/ore:10 struct=wall:2/tower:1/storm:0 damaged=0 current=use_tower[0/1] age=5s src=remote_server legal=19 doctrine=3\n",
        encoding="utf-8",
    )

    summary = tool.analyze_file(log)

    assert summary["non_executable_plan_actions"] == [
        {
            "plan_number": 4,
            "phase": "night",
            "action": "rely_on_regen",
            "job": "use_tower",
            "trigger": "structure_destroyed",
        }
    ]


def test_plan_log_analyzer_reads_powershell_utf16_logs(tmp_path):
    tool = _load_tool()
    log = tmp_path / "plan-utf16.log"
    log.write_text(
        "PLAN 004 trigger=phase_changed kind=night_emergency day=2 phase=night action=use_tower job=wait_or_idle hp=100 enemy=0 types=none res=stone:0/ore:0 struct=wall:1/tower:1/storm:0 damaged=0 current=use_tower[0/1] age=30s src=remote_server legal=20 doctrine=0\n",
        encoding="utf-16",
    )

    summary = tool.analyze_file(log)

    assert summary["planner_calls"] == 1
    assert summary["phase_counts"] == {"night": 1}


def test_plan_log_analyzer_cli_outputs_json(tmp_path, capsys):
    tool = _load_tool()
    log = tmp_path / "plan.log"
    log.write_text(
        "PLAN 004 trigger=timer kind=day_replan day=2 phase=midday action=use_tower job=use_tower hp=100 enemy=0 types=none res=stone:0/ore:0 struct=wall:1/tower:1/storm:0 damaged=0 current=use_tower[0/1] age=30s src=remote_server legal=31 doctrine=0\n",
        encoding="utf-8",
    )

    exit_code = tool.main([str(log), "--json"])

    assert exit_code == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["planner_calls"] == 1
    assert payload["trigger_counts"] == {"timer": 1}


def test_plan_log_analyzer_extracts_learning_evidence_from_remote_prompt_status():
    tool = _load_tool()
    text = "\n".join(
        [
            "PLAN 041 trigger=night_reflection kind=library_doctrine day=2 phase=morning action=mine_stone job=repair_structure hp=59.7 enemy=0 types=none res=stone:5/ore:4 struct=wall:1/tower:0/storm:1 damaged=0 current=flee[0/1] age=8.1s src=remote_server legal=20 doctrine=3",
            "PLAN 074 trigger=anti_air_structure_built kind=day_replan day=4 phase=dusk action=use_tower job=build_storm_rod hp=35.4 enemy=0 types=none res=stone:11/ore:14 struct=wall:3/tower:1/storm:1 damaged=0 current=none[1/1] age=6.1s src=remote_server legal=24 doctrine=3",
            'Remote prompt remote_wall_habit_learns_wings: source=remote_server next=use_tower status=AI: planner active day=4 phase=dusk alive=true hp=35.4 min_hp=26.9 enemies=0 stone=11 food=0 combat=0.00 dmg_bonus=0.00 def=0.00 walls=3/4 aura=0/0 tower=1/1 tar=0/0 storm=1/1 sword=0 kills=9 damaged=12 struct_hit=32 struct_dead=5 melee=0 ranged=26 scribe=12 structured=12 reflections=3 doctrine_reflections=3 doctrine_plans=14 sign="stone walls are safety"',
        ]
    )

    summary = tool.analyze_text(text)

    assert summary["doctrine_plan_calls"] == 2
    assert summary["max_plan_doctrine_count"] == 3
    assert summary["scenario_statuses"] == [
        {
            "prompt": "remote_wall_habit_learns_wings",
            "source": "remote_server",
            "next_action": "use_tower",
            "day": 4,
            "phase": "dusk",
            "alive": True,
            "hp": 35.4,
            "min_hp": 26.9,
            "walls": "3/4",
            "tower": "1/1",
            "storm": "1/1",
            "scribe": 12,
            "structured": 12,
            "reflections": 3,
            "doctrine_reflections": 3,
            "doctrine_plans": 14,
            "sign": "stone walls are safety",
        }
    ]
    assert summary["learning_evidence"] == [
        {
            "prompt": "remote_wall_habit_learns_wings",
            "day": 4,
            "phase": "dusk",
            "next_action": "use_tower",
            "reflections": 3,
            "doctrine_reflections": 3,
            "doctrine_plans": 14,
            "sign": "stone walls are safety",
        }
    ]


def test_plan_log_analyzer_cli_can_fail_without_learning_evidence(tmp_path):
    tool = _load_tool()
    log = tmp_path / "plan.log"
    log.write_text(
        'Remote prompt remote_no_learning: source=remote_server next=use_cover status=AI: planner active day=1 phase=midday alive=true hp=100.0 min_hp=100.0 enemies=0 stone=10 food=0 combat=0.00 dmg_bonus=0.00 def=0.00 walls=0/0 aura=0/0 tower=0/0 tar=0/0 storm=0/0 sword=0 kills=0 damaged=0 struct_hit=0 struct_dead=0 melee=0 ranged=0 scribe=0 structured=0 reflections=0 doctrine_reflections=0 doctrine_plans=0 sign="just survive"\n',
        encoding="utf-8",
    )

    exit_code = tool.main([str(log), "--fail-without-learning-evidence"])

    assert exit_code == 4


def test_plan_log_analyzer_parses_ai_request_metrics_and_prediction_statuses():
    tool = _load_tool()
    text = "\n".join(
        [
            "AI prediction request start endpoint=http://65.109.225.216:8088/ari/predict-v1 timeout=5.0s bytes=4252",
            "AI prediction request done endpoint=http://65.109.225.216:8088/ari/predict-v1 result=0 http=200 latency_ms=834 status=ok",
            "AI prediction request start endpoint=http://65.109.225.216:8088/ari/predict-v1 timeout=5.0s bytes=4300",
            "AI prediction request done endpoint=http://65.109.225.216:8088/ari/predict-v1 result=13 http=0 latency_ms=5003 status=local_fallback",
            "AI agent plan request start endpoint=http://65.109.225.216:8088/ari/plan-v1 timeout=5.0s bytes=15546",
            "AI agent plan request done endpoint=http://65.109.225.216:8088/ari/plan-v1 result=0 http=200 latency_ms=382 status=ok",
            "AI deep request start endpoint=http://65.109.225.216:8088/ai/deep-interpretation timeout=120.0s bytes=14053",
            "AI deep request done endpoint=http://65.109.225.216:8088/ai/deep-interpretation result=13 http=0 latency_ms=120001 status=timeout",
        ]
    )

    summary = tool.analyze_text(text)

    assert summary["ai_request_counts"] == {"agent_plan": 1, "deep_interpretation": 1, "prediction": 2}
    assert summary["ai_request_done_counts"] == {"agent_plan": 1, "deep_interpretation": 1, "prediction": 2}
    assert summary["ai_request_status_counts"]["prediction"] == {"local_fallback": 1, "ok": 1}
    assert summary["prediction_calls"] == 2
    assert summary["prediction_ok_under_5s"] == 1
    assert summary["prediction_fallback_or_failed"] == 1
    assert summary["prediction_slow_or_failed"] == 1
    assert summary["max_agent_plan_payload_bytes"] == 15546
    assert summary["old_timeout_request_starts"] == 1
    assert summary["max_timeout_seconds"] == 120.0


def test_plan_log_analyzer_extracts_smart_loop_evidence_from_real_log_shapes():
    tool = _load_tool()
    text = "\n".join(
        [
            'SCRIBE {"schema":"ari.scribe.log.v1","note":"Ari saw wings crossing the wall.","tags":["danger:flying","plan_body_mismatch"],"facts":["Flying enemy crossed the wall."],"actions":[{"action":"build_wall","status":"in_progress"},{"action":"build_storm_rod","status":"planned"}],"dangers":[{"type":"flying","distance":80.0}],"world_changes":["first_flying_enemy_seen"],"priority_hints":{"build_storm_rod":0.8},"source":"remote_server","confidence":0.8}',
            "AI prediction request start endpoint=http://65.109.225.216:8088/ari/predict-v1 timeout=5.0s bytes=4200",
            "AI prediction request done endpoint=http://65.109.225.216:8088/ari/predict-v1 result=0 http=200 latency_ms=812 status=ok",
            'DAY_SUMMARY {"schema":"ari.day_summary.v1","day":2,"outcome":"survived","candidate_lessons":["flying enemies need storm rods before extra walls"],"evidence_snapshot_ids":["snap_flying_1"]}',
            "PLAN 041 trigger=night_reflection kind=library_doctrine day=2 phase=morning action=build_storm_rod job=build_storm_rod hp=80 enemy=0 types=none res=stone:12/ore:0 struct=wall:2/tower:0/storm:0 damaged=0 current=build_storm_rod[0/1] age=8.1s src=remote_server legal=20 doctrine=2",
            'Remote prompt remote_wall_habit_learns_wings: source=remote_server next=build_storm_rod status=AI: planner active day=3 phase=dusk alive=true hp=70.0 min_hp=42.0 enemies=0 stone=11 food=0 combat=0.00 dmg_bonus=0.00 def=0.00 walls=2/3 aura=0/0 tower=0/0 tar=0/0 storm=1/1 sword=0 kills=4 damaged=2 struct_hit=5 struct_dead=1 melee=0 ranged=2 scribe=6 structured=6 reflections=2 doctrine_reflections=1 doctrine_plans=1 sign="stone walls are safety"',
        ]
    )

    summary = tool.analyze_text(text)

    assert summary["scribe_decision_grade_notes"] == 1
    assert summary["smart_loop_evidence"]["passed"] is True
    assert summary["smart_loop_evidence"]["prediction_ok_under_5s"] == 1
    assert summary["smart_loop_evidence"]["noticed_facts"] is True
    assert summary["smart_loop_evidence"]["formed_lesson"] is True
    assert summary["smart_loop_evidence"]["changed_strategy"] is True
    assert summary["smart_loop_evidence"]["improved_or_plausible_survival"] is True


def test_plan_log_analyzer_smart_loop_evidence_rejects_fallback_prediction():
    tool = _load_tool()
    text = "\n".join(
        [
            'SCRIBE {"schema":"ari.scribe.log.v1","note":"Ari saw wings.","tags":["danger:flying"],"facts":["Flying enemy crossed the wall."],"actions":[{"action":"build_wall","status":"in_progress"}],"dangers":[{"type":"flying","distance":80.0}],"world_changes":["first_flying_enemy_seen"],"priority_hints":{"build_storm_rod":0.8},"source":"local_fallback","confidence":0.25}',
            "AI prediction request start endpoint=http://65.109.225.216:8088/ari/predict-v1 timeout=5.0s bytes=4200",
            "AI prediction request done endpoint=http://65.109.225.216:8088/ari/predict-v1 result=13 http=0 latency_ms=5004 status=local_fallback",
            'Remote prompt remote_wall_habit_learns_wings: source=remote_server next=build_storm_rod status=AI: planner active day=3 phase=dusk alive=true hp=70.0 min_hp=42.0 enemies=0 stone=11 food=0 combat=0.00 dmg_bonus=0.00 def=0.00 walls=2/3 aura=0/0 tower=0/0 tar=0/0 storm=1/1 sword=0 kills=4 damaged=2 struct_hit=5 struct_dead=1 melee=0 ranged=2 scribe=6 structured=6 reflections=2 doctrine_reflections=1 doctrine_plans=1 sign="stone walls are safety"',
        ]
    )

    summary = tool.analyze_text(text)

    assert summary["prediction_ok_under_5s"] == 0
    assert summary["smart_loop_evidence"]["passed"] is False
    assert "fast_prediction" in summary["smart_loop_evidence"]["missing"]


def test_plan_log_analyzer_smart_loop_evidence_rejects_scripted_gateway():
    tool = _load_tool()
    text = "\n".join(
        [
            'SCRIBE {"schema":"ari.scribe.log.v1","note":"Ari saw wings crossing the wall.","tags":["danger:flying","plan_body_mismatch"],"facts":["Flying enemy crossed the wall."],"actions":[{"action":"build_wall","status":"in_progress"},{"action":"build_storm_rod","status":"planned"}],"dangers":[{"type":"flying","distance":80.0}],"world_changes":["first_flying_enemy_seen"],"priority_hints":{"build_storm_rod":0.8},"source":"scripted_gateway","confidence":0.8}',
            'AI_METRIC {"schema":"ari.ai_request_metric.v1","kind":"prediction","endpoint":"/ari/predict-v1","request_id":"p1","context_hash":"ctx1","source":"scripted_gateway","status":"ok","latency_ms":180,"timeout_s":5.0,"bytes":2100,"model":"scripted","fallback_reason":""}',
            'DAY_SUMMARY {"schema":"ari.day_summary.v1","day":2,"outcome":"survived","candidate_lessons":["flying enemies need storm rods before extra walls"],"evidence_snapshot_ids":["snap_flying_1"],"source":"scripted_gateway"}',
            "PLAN 041 trigger=night_reflection kind=library_doctrine day=2 phase=morning action=build_storm_rod job=build_storm_rod hp=80 enemy=0 types=none res=stone:12/ore:0 struct=wall:2/tower:0/storm:0 damaged=0 current=build_storm_rod[0/1] age=8.1s src=scripted_gateway legal=20 doctrine=2",
            'Remote prompt remote_wall_habit_learns_wings: source=scripted_gateway next=build_storm_rod status=AI: planner active day=3 phase=dusk alive=true hp=70.0 min_hp=42.0 enemies=0 stone=11 food=0 combat=0.00 dmg_bonus=0.00 def=0.00 walls=2/3 aura=0/0 tower=0/0 tar=0/0 storm=1/1 sword=0 kills=4 damaged=2 struct_hit=5 struct_dead=1 melee=0 ranged=2 scribe=6 structured=6 reflections=2 doctrine_reflections=1 doctrine_plans=1 sign="stone walls are safety"',
        ]
    )

    summary = tool.analyze_text(text)

    assert summary["prediction_ok_under_5s"] == 1
    assert summary["real_model_prediction_ok_under_5s"] == 0
    assert summary["source_class_counts"]["prediction"] == {"scripted": 1}
    assert summary["smart_loop_evidence"]["passed"] is False
    assert "real_model_prediction" in summary["smart_loop_evidence"]["missing"]
    assert "real_model_learning_source" in summary["smart_loop_evidence"]["missing"]


def test_plan_log_analyzer_cli_can_fail_without_real_model_smart_loop(tmp_path):
    tool = _load_tool()
    log = tmp_path / "plan.log"
    log.write_text(
        "\n".join(
            [
                'SCRIBE {"schema":"ari.scribe.log.v1","note":"Ari saw wings crossing the wall.","tags":["danger:flying","plan_body_mismatch"],"facts":["Flying enemy crossed the wall."],"actions":[{"action":"build_wall","status":"in_progress"},{"action":"build_storm_rod","status":"planned"}],"dangers":[{"type":"flying","distance":80.0}],"world_changes":["first_flying_enemy_seen"],"priority_hints":{"build_storm_rod":0.8},"source":"scripted_gateway","confidence":0.8}',
                'AI_METRIC {"schema":"ari.ai_request_metric.v1","kind":"prediction","endpoint":"/ari/predict-v1","request_id":"p1","context_hash":"ctx1","source":"scripted_gateway","status":"ok","latency_ms":180,"timeout_s":5.0,"bytes":2100,"model":"scripted","fallback_reason":""}',
                'DAY_SUMMARY {"schema":"ari.day_summary.v1","day":2,"outcome":"survived","candidate_lessons":["flying enemies need storm rods before extra walls"],"evidence_snapshot_ids":["snap_flying_1"],"source":"scripted_gateway"}',
                "PLAN 041 trigger=night_reflection kind=library_doctrine day=2 phase=morning action=build_storm_rod job=build_storm_rod hp=80 enemy=0 types=none res=stone:12/ore:0 struct=wall:2/tower:0/storm:0 damaged=0 current=build_storm_rod[0/1] age=8.1s src=scripted_gateway legal=20 doctrine=2",
                'Remote prompt remote_wall_habit_learns_wings: source=scripted_gateway next=build_storm_rod status=AI: planner active day=3 phase=dusk alive=true hp=70.0 min_hp=42.0 enemies=0 stone=11 food=0 combat=0.00 dmg_bonus=0.00 def=0.00 walls=2/3 aura=0/0 tower=0/0 tar=0/0 storm=1/1 sword=0 kills=4 damaged=2 struct_hit=5 struct_dead=1 melee=0 ranged=2 scribe=6 structured=6 reflections=2 doctrine_reflections=1 doctrine_plans=1 sign="stone walls are safety"',
            ]
        ),
        encoding="utf-8",
    )

    exit_code = tool.main([str(log), "--fail-without-real-model-smart-loop"])

    assert exit_code == 11


def test_plan_log_analyzer_real_model_smart_loop_passes_with_remote_metrics():
    tool = _load_tool()
    text = "\n".join(
        [
            'SCRIBE {"schema":"ari.scribe.log.v1","note":"Ari saw wings crossing the wall.","tags":["danger:flying","plan_body_mismatch"],"facts":["Flying enemy crossed the wall."],"actions":[{"action":"build_wall","status":"in_progress"},{"action":"build_storm_rod","status":"planned"}],"dangers":[{"type":"flying","distance":80.0}],"world_changes":["first_flying_enemy_seen"],"priority_hints":{"build_storm_rod":0.8},"source":"remote_server","confidence":0.8}',
            'AI_METRIC {"schema":"ari.ai_request_metric.v1","kind":"prediction","endpoint":"/ari/predict-v1","request_id":"p1","context_hash":"ctx1","source":"remote_server","status":"ok","latency_ms":820,"timeout_s":5.0,"bytes":2100,"model":"smollm2:135m","fallback_reason":""}',
            'AI_METRIC {"schema":"ari.ai_request_metric.v1","kind":"agent_plan","endpoint":"/ari/plan-v1","request_id":"a1","context_hash":"ctx1","source":"remote_server","status":"ok","latency_ms":3100,"timeout_s":5.0,"bytes":8500,"model":"qwen3:0.6b","fallback_reason":""}',
            'DAY_SUMMARY {"schema":"ari.day_summary.v1","day":2,"outcome":"survived","candidate_lessons":["flying enemies need storm rods before extra walls"],"evidence_snapshot_ids":["snap_flying_1"],"source":"deterministic"}',
            'LEARNING_TRACE {"schema":"ari.learning_trace.v1","evidence_ids":["snap_flying_1"],"scribe_note_ids":["scribe1"],"summary_id":"summary1","reflection_id":"reflection1","doctrine_id":"doctrine1","later_plan_id":"plan1","outcome":"survived","improvement_claim":"storm rod was built before extra walls","source":"remote_server"}',
            "PLAN 041 trigger=night_reflection kind=library_doctrine day=2 phase=morning action=build_storm_rod job=build_storm_rod hp=80 enemy=0 types=none res=stone:12/ore:0 struct=wall:2/tower:0/storm:0 damaged=0 current=build_storm_rod[0/1] age=8.1s src=remote_server legal=20 doctrine=2",
            'Remote prompt remote_wall_habit_learns_wings: source=remote_server next=build_storm_rod status=AI: planner active day=3 phase=dusk alive=true hp=70.0 min_hp=42.0 enemies=0 stone=11 food=0 combat=0.00 dmg_bonus=0.00 def=0.00 walls=2/3 aura=0/0 tower=0/0 tar=0/0 storm=1/1 sword=0 kills=4 damaged=2 struct_hit=5 struct_dead=1 melee=0 ranged=2 scribe=6 structured=6 reflections=2 doctrine_reflections=1 doctrine_plans=1 sign="stone walls are safety"',
        ]
    )

    summary = tool.analyze_text(text)

    assert summary["real_model_prediction_ok_under_5s"] == 1
    assert summary["real_model_ai_ratio"] == 1.0
    assert summary["source_class_counts"]["ai_request"] == {"real_model": 2}
    assert summary["real_model_smart_loop_evidence"]["passed"] is True


def test_plan_log_analyzer_rejects_smart_loop_when_later_outcome_is_death():
    tool = _load_tool()
    text = "\n".join(
        [
            'SCRIBE {"schema":"ari.scribe.log.v1","note":"Ari saw wings crossing the wall.","tags":["danger:flying","plan_body_mismatch"],"facts":["Flying enemy crossed the wall."],"actions":[{"action":"build_wall","status":"in_progress"},{"action":"build_storm_rod","status":"planned"}],"dangers":[{"type":"flying","distance":80.0}],"world_changes":["first_flying_enemy_seen"],"priority_hints":{"build_storm_rod":0.8},"source":"deterministic_scribe","confidence":0.8}',
            'AI_METRIC {"schema":"ari.ai_request_metric.v1","kind":"prediction","endpoint":"/ari/predict-v1","source":"remote_server","status":"ok","latency_ms":820,"timeout_s":5.0,"bytes":2100,"model":"smollm2:135m","fallback_reason":""}',
            'DAY_SUMMARY {"schema":"ari.day_summary.v1","day":2,"outcome":"died","candidate_lessons":["flying enemies need storm rods before extra walls"],"evidence_snapshot_ids":["snap_flying_1"],"source":"deterministic"}',
            'LEARNING_TRACE {"schema":"ari.learning_trace.v1","evidence_ids":["snap_flying_1"],"scribe_note_ids":["scribe1"],"summary_id":"summary1","reflection_id":"reflection1","doctrine_id":"doctrine1","later_plan_id":"plan1","outcome":"ari_died","improvement_claim":"Doctrine-influenced plan chose flee but produced ari_died; treat this as feedback, not a success claim.","source":"godot"}',
            "PLAN 041 trigger=night_reflection kind=library_doctrine day=2 phase=night action=flee job=flee hp=0 enemy=5 types=zombie:3,flying:1,runner:1 res=stone:49/ore:0 struct=wall:0/tower:0/storm:0 damaged=15 current=flee[0/1] age=8.1s src=remote_server legal=20 doctrine=2",
            'Remote prompt remote_wall_habit_learns_wings: source=remote_server next=flee status=AI: planner active day=2 phase=night alive=false hp=0.0 min_hp=1.3 enemies=5 stone=49 food=1 combat=0.00 dmg_bonus=0.00 def=0.00 walls=0/2 aura=0/0 tower=0/0 tar=0/0 storm=0/1 sword=0 kills=1 damaged=15 struct_hit=39 struct_dead=6 melee=0 ranged=0 scribe=6 structured=6 reflections=1 doctrine_reflections=1 doctrine_plans=4 sign="stone walls are safety"',
        ]
    )

    summary = tool.analyze_text(text)

    assert summary["complete_learning_traces"] == 1
    assert summary["successful_learning_traces"] == 0
    assert summary["learning_evidence"] == []
    assert summary["smart_loop_evidence"]["passed"] is False
    assert "improved_or_plausible_survival" in summary["smart_loop_evidence"]["missing"]


def test_plan_log_analyzer_reports_real_model_ratios():
    tool = _load_tool()
    text = "\n".join(
        [
            'AI_METRIC {"schema":"ari.ai_request_metric.v1","kind":"prediction","endpoint":"/ari/predict-v1","source":"remote_server","status":"ok","latency_ms":800,"timeout_s":5.0,"bytes":2000,"model":"smollm2:135m","fallback_reason":""}',
            'AI_METRIC {"schema":"ari.ai_request_metric.v1","kind":"prediction","endpoint":"/ari/predict-v1","source":"scripted_gateway","status":"ok","latency_ms":150,"timeout_s":5.0,"bytes":2000,"model":"scripted","fallback_reason":""}',
            'AI_METRIC {"schema":"ari.ai_request_metric.v1","kind":"agent_plan","endpoint":"/ari/plan-v1","source":"local_fallback","status":"local_fallback","latency_ms":20,"timeout_s":5.0,"bytes":2000,"model":"","fallback_reason":"model_timeout"}',
        ]
    )

    summary = tool.analyze_text(text)

    assert summary["real_model_ai_ratio"] == 0.333
    assert summary["real_model_prediction_ratio"] == 0.5
    assert summary["scripted_evidence_count"] == 1


def test_plan_log_analyzer_cli_can_fail_on_low_real_model_prediction_ratio(tmp_path):
    tool = _load_tool()
    log = tmp_path / "plan.log"
    log.write_text(
        "\n".join(
            [
                'AI_METRIC {"schema":"ari.ai_request_metric.v1","kind":"prediction","endpoint":"/ari/predict-v1","source":"remote_server","status":"ok","latency_ms":800,"timeout_s":5.0,"bytes":2000,"model":"smollm2:135m","fallback_reason":""}',
                'AI_METRIC {"schema":"ari.ai_request_metric.v1","kind":"prediction","endpoint":"/ari/predict-v1","source":"scripted_gateway","status":"ok","latency_ms":150,"timeout_s":5.0,"bytes":2000,"model":"scripted","fallback_reason":""}',
            ]
        ),
        encoding="utf-8",
    )

    exit_code = tool.main([str(log), "--min-real-model-prediction-ratio", "0.75"])

    assert exit_code == 12


def test_plan_log_analyzer_cli_can_fail_on_low_real_model_ai_ratio(tmp_path):
    tool = _load_tool()
    log = tmp_path / "plan.log"
    log.write_text(
        "\n".join(
            [
                'AI_METRIC {"schema":"ari.ai_request_metric.v1","kind":"prediction","endpoint":"/ari/predict-v1","source":"remote_server","status":"ok","latency_ms":800,"timeout_s":5.0,"bytes":2000,"model":"smollm2:135m","fallback_reason":""}',
                'AI_METRIC {"schema":"ari.ai_request_metric.v1","kind":"agent_plan","endpoint":"/ari/plan-v1","source":"local_fallback","status":"local_fallback","latency_ms":20,"timeout_s":5.0,"bytes":2000,"model":"","fallback_reason":"model_timeout"}',
            ]
        ),
        encoding="utf-8",
    )

    exit_code = tool.main([str(log), "--min-real-model-ai-ratio", "0.75"])

    assert exit_code == 13


def test_plan_log_analyzer_cli_can_fail_on_scripted_evidence(tmp_path):
    tool = _load_tool()
    log = tmp_path / "plan.log"
    log.write_text(
        'SCRIBE {"schema":"ari.scribe.log.v1","note":"scripted note","tags":[],"facts":["fact"],"actions":[{"action":"use_cover"}],"dangers":[],"world_changes":[],"priority_hints":{},"source":"scripted_gateway","confidence":0.8}\n',
        encoding="utf-8",
    )

    exit_code = tool.main([str(log), "--fail-on-scripted-evidence"])

    assert exit_code == 14


def test_plan_log_analyzer_accepts_json_metrics_and_learning_traces():
    tool = _load_tool()
    text = "\n".join(
        [
            'AI_METRIC {"schema":"ari.ai_request_metric.v1","kind":"prediction","endpoint":"/ari/predict-v1","request_id":"p1","context_hash":"ctx1","source":"remote_server","status":"ok","latency_ms":411,"timeout_s":5.0,"bytes":2100,"model":"qwen3:0.6b","fallback_reason":""}',
            'DAY_SUMMARY {"schema":"ari.day_summary.v1","day":2,"outcome":"survived","candidate_lessons":["storm rod was built before extra walls"],"evidence_snapshot_ids":["snap1"]}',
            'LEARNING_TRACE {"schema":"ari.learning_trace.v1","evidence_ids":["snap1"],"scribe_note_ids":["scribe1"],"summary_id":"summary1","reflection_id":"reflection1","doctrine_id":"doctrine1","later_plan_id":"plan1","outcome":"survived","improvement_claim":"storm rod was built before extra walls"}',
        ]
    )

    summary = tool.analyze_text(text)

    assert summary["ai_request_counts"] == {"prediction": 1}
    assert summary["prediction_ok_under_5s"] == 1
    assert summary["learning_trace_logs"] == 1
    assert summary["complete_learning_traces"] == 1
    assert summary["smart_loop_evidence"]["passed"] is True


def test_plan_log_analyzer_smart_loop_rejects_trace_without_day_summary_log():
    tool = _load_tool()
    text = "\n".join(
        [
            'AI_METRIC {"schema":"ari.ai_request_metric.v1","kind":"prediction","endpoint":"/ari/predict-v1","request_id":"p1","context_hash":"ctx1","source":"remote_server","status":"ok","latency_ms":411,"timeout_s":5.0,"bytes":2100,"model":"qwen3:0.6b","fallback_reason":""}',
            'LEARNING_TRACE {"schema":"ari.learning_trace.v1","evidence_ids":["snap1"],"scribe_note_ids":["scribe1"],"summary_id":"summary1","reflection_id":"reflection1","doctrine_id":"doctrine1","later_plan_id":"plan1","outcome":"survived","improvement_claim":"storm rod was built before extra walls"}',
        ]
    )

    summary = tool.analyze_text(text)

    assert summary["complete_learning_traces"] == 1
    assert summary["day_summaries_with_evidence"] == 0
    assert summary["smart_loop_evidence"]["passed"] is False
    assert "summarized_mattered" in summary["smart_loop_evidence"]["missing"]


def test_plan_log_analyzer_cli_can_fail_without_smart_loop_evidence(tmp_path):
    tool = _load_tool()
    log = tmp_path / "plan.log"
    log.write_text(
        "\n".join(
            [
                "AI prediction request start endpoint=http://65.109.225.216:8088/ari/predict-v1 timeout=5.0s bytes=4200",
                "AI prediction request done endpoint=http://65.109.225.216:8088/ari/predict-v1 result=13 http=0 latency_ms=5004 status=local_fallback",
                'Remote prompt remote_wall_habit_learns_wings: source=remote_server next=build_storm_rod status=AI: planner active day=3 phase=dusk alive=true hp=70.0 min_hp=42.0 enemies=0 stone=11 food=0 combat=0.00 dmg_bonus=0.00 def=0.00 walls=2/3 aura=0/0 tower=0/0 tar=0/0 storm=1/1 sword=0 kills=4 damaged=2 struct_hit=5 struct_dead=1 melee=0 ranged=2 scribe=6 structured=6 reflections=2 doctrine_reflections=1 doctrine_plans=1 sign="stone walls are safety"',
            ]
        ),
        encoding="utf-8",
    )

    exit_code = tool.main([str(log), "--fail-without-smart-loop-evidence"])

    assert exit_code == 9


def test_plan_log_analyzer_cli_can_fail_when_planner_budget_is_exceeded(tmp_path):
    tool = _load_tool()
    log = tmp_path / "plan.log"
    log.write_text(
        "\n".join(
            [
                "PLAN 001 trigger=timer kind=day_replan day=1 phase=midday action=use_cover job=use_cover hp=100 enemy=0 types=none res=stone:0/ore:0 struct=wall:1/tower:0/storm:0 damaged=0 current=use_cover[0/1] age=30s src=remote_server legal=20 doctrine=0",
                "PLAN 002 trigger=timer kind=day_replan day=1 phase=midday action=use_cover job=use_cover hp=100 enemy=0 types=none res=stone:0/ore:0 struct=wall:1/tower:0/storm:0 damaged=0 current=use_cover[0/1] age=60s src=remote_server legal=20 doctrine=0",
            ]
        ),
        encoding="utf-8",
    )

    exit_code = tool.main([str(log), "--max-planner-calls", "1"])

    assert exit_code == 5


def test_plan_log_analyzer_cli_can_fail_when_trigger_budget_is_exceeded(tmp_path):
    tool = _load_tool()
    log = tmp_path / "plan.log"
    log.write_text(
        "\n".join(
            [
                "PLAN 001 trigger=phase_changed kind=night_emergency day=1 phase=night action=use_cover job=use_cover hp=100 enemy=0 types=none res=stone:0/ore:0 struct=wall:1/tower:0/storm:0 damaged=0 current=use_cover[0/1] age=30s src=remote_server legal=20 doctrine=0",
                "PLAN 002 trigger=phase_changed kind=night_emergency day=1 phase=night action=use_cover job=use_cover hp=100 enemy=0 types=none res=stone:0/ore:0 struct=wall:1/tower:0/storm:0 damaged=0 current=use_cover[0/1] age=60s src=remote_server legal=20 doctrine=0",
            ]
        ),
        encoding="utf-8",
    )

    exit_code = tool.main([str(log), "--max-trigger-count", "phase_changed=1"])

    assert exit_code == 6


def test_plan_log_analyzer_cli_can_fail_when_agent_plan_payload_budget_is_exceeded(tmp_path):
    tool = _load_tool()
    log = tmp_path / "plan.log"
    log.write_text(
        "AI agent plan request start endpoint=http://65.109.225.216:8088/ari/plan-v1 timeout=5.0s bytes=25055\n",
        encoding="utf-8",
    )

    exit_code = tool.main([str(log), "--max-agent-plan-payload-bytes", "15000"])

    assert exit_code == 10


def test_plan_log_analyzer_cli_can_fail_on_forbidden_phrase(tmp_path):
    tool = _load_tool()
    log = tmp_path / "plan.log"
    log.write_text(
        "Scribe note created: Ari was fight head on; because sign rejected hiding; while plan expected hide until dawn.\n",
        encoding="utf-8",
    )

    exit_code = tool.main([str(log), "--forbid-phrase", "sign rejected hiding"])

    assert exit_code == 8


def test_plan_log_analyzer_cli_accepts_budget_when_counts_are_within_limits(tmp_path):
    tool = _load_tool()
    log = tmp_path / "plan.log"
    log.write_text(
        "PLAN 001 trigger=timer kind=day_replan day=1 phase=midday action=use_cover job=use_cover hp=100 enemy=0 types=none res=stone:0/ore:0 struct=wall:1/tower:0/storm:0 damaged=0 current=use_cover[0/1] age=30s src=remote_server legal=20 doctrine=0\n",
        encoding="utf-8",
    )

    exit_code = tool.main([str(log), "--max-planner-calls", "1", "--max-trigger-count", "timer=1"])

    assert exit_code == 0
