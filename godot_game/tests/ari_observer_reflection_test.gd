extends SceneTree

const AIBridgeScript = preload("res://scripts/autoload/AIBridge.gd")
const WorldScene = preload("res://scenes/world/World.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_observer_snapshot_builder_includes_structured_world_facts()
	await _test_observer_timer_records_snapshots_and_rate_limits_scribe()
	await _test_damage_event_records_high_salience_snapshot()
	await _test_local_stub_scribe_mentions_specific_danger_and_plan()
	await _test_local_stub_scribe_ignores_internal_plan_event_for_recent_note()
	await _test_local_stub_scribe_keeps_quiet_phase_change_out_of_note_text()
	await _test_local_stub_scribe_marks_body_plan_mismatch()
	await _test_local_stub_scribe_marks_plan_support_without_mismatch()
	await _test_local_stub_scribe_marks_defensive_hold_as_plan_support()
	await _test_local_stub_scribe_marks_recovery_as_plan_support()
	await _test_local_library_reflection_fallback_learns_from_flying_scribe()
	await _test_day_summary_and_strategy_packet_feed_ai_pipeline()
	await _test_provenance_and_learning_trace_link_ai_pipeline()
	await _test_rolling_tactical_summary_feeds_fast_prediction_and_background()
	await _test_background_ai_jobs_discard_stale_results()
	await _test_fast_prediction_packets_feed_strategy_evidence()
	await _test_high_salience_snapshot_primes_fast_prediction()
	await _test_night_reflection_payload_caps_and_valid_note_learning()
	await _test_night_started_reflection_does_not_spend_smart_endpoint()

	if failures.is_empty():
		print("Ari observer reflection tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_observer_snapshot_builder_includes_structured_world_facts() -> void:
	var world: World = await _make_world()
	world.call("commit_sign", "build high when wings come")
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("add_stone", 30)
		resource_system.call("add_food", 2)
	var arena: Rect2 = world.call("get_arena_rect")
	world.call("_spawn_enemy", arena.get_center() + Vector2(180.0, -60.0), "flying")
	await process_frame

	_assert(world.has_method("_build_observer_snapshot"), "World should expose a deterministic observer snapshot builder")
	if world.has_method("_build_observer_snapshot"):
		var snapshot: Dictionary = world.call("_build_observer_snapshot", "timer", 0.2, ["manual_test"])
		_assert(snapshot.get("schema", "") == "ari.observer.snapshot.v1", "observer snapshot should carry schema")
		_assert(snapshot.get("trigger", "") == "timer", "observer snapshot should keep trigger")
		_assert(snapshot.get("day", 0) >= 1, "observer snapshot should include day")
		_assert(str(snapshot.get("phase", "")).length() > 0, "observer snapshot should include phase")
		_assert(snapshot.has("time_left"), "observer snapshot should include time left")
		var ari: Dictionary = snapshot.get("ari", {})
		_assert(ari.has("hp") and ari.has("max_hp"), "observer snapshot should include Ari HP")
		_assert(ari.has("fear") and ari.has("hunger") and ari.has("stamina"), "observer snapshot should include Ari needs")
		_assert(str(ari.get("current_job", "")).length() > 0, "observer snapshot should include current job")
		_assert(str(ari.get("current_action", "")).length() > 0, "observer snapshot should include current action")
		var sign: Dictionary = snapshot.get("sign", {})
		_assert(sign.get("text", "") == "build high when wings come", "observer snapshot should preserve freeform sign text")
		_assert(str(sign.get("interpretation", "")).length() > 0, "observer snapshot should include current interpretation")
		var plan: Dictionary = snapshot.get("plan", {})
		_assert(plan.has("recent_outcomes"), "observer snapshot should include recent agent outcomes")
		var world_state: Dictionary = snapshot.get("world", {})
		_assert(world_state.get("resources", {}).get("stone", -1) >= 30, "observer snapshot should include resources")
		_assert(world_state.get("enemies", {}).get("types", {}).get("flying", 0) == 1, "observer snapshot should include enemy type counts")
		_assert(world_state.get("nearest_danger", {}).get("type", "") == "flying", "observer snapshot should include nearest danger")
		_assert(world_state.get("notable_changes", []).has("manual_test"), "observer snapshot should preserve notable changes")
		_assert(float(snapshot.get("salience", 0.0)) == 0.2, "observer snapshot should keep salience")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_observer_timer_records_snapshots_and_rate_limits_scribe() -> void:
	var world: World = await _make_world()
	var memory = world.get("ari_memory")
	_assert(world.has_method("advance_observer_memory"), "World should expose deterministic observer memory stepping")
	if world.has_method("advance_observer_memory"):
		world.call("advance_observer_memory", 4.9)
		_assert(memory.get_recent_snapshots(20).is_empty(), "observer timer should not record before five seconds")
		world.call("advance_observer_memory", 0.2)
		_assert(memory.get_recent_snapshots(20).size() == 1, "observer timer should record after five seconds")
		var latest: Dictionary = memory.get_recent_snapshots(1)[0]
		_assert(latest.get("trigger", "") == "timer", "timer snapshot should use timer trigger")
		var chronicle = world.get("chronicle")
		_assert(chronicle != null, "World should own a Chronicle for moment notes")
		if chronicle != null:
			_assert(chronicle.get_today_scribe_notes().is_empty(), "scribe should not run before its slower cooldown")
			world.call("advance_observer_memory", 25.0)
			await process_frame
			_assert(chronicle.get_today_scribe_notes().size() <= 1, "scribe should create at most one note after cooldown")
			world.call("advance_observer_memory", 1.0)
			await process_frame
			_assert(chronicle.get_today_scribe_notes().size() <= 1, "scribe should skip while inside cooldown")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_damage_event_records_high_salience_snapshot() -> void:
	var world: World = await _make_world()
	var memory = world.get("ari_memory")
	world.call("_on_ari_damaged", 50.0)
	var snapshots: Array = memory.get_recent_snapshots(5)
	_assert(not snapshots.is_empty(), "damage should immediately record a high-salience observer snapshot")
	if not snapshots.is_empty():
		var latest: Dictionary = snapshots[snapshots.size() - 1]
		_assert(latest.get("trigger", "") == "damage", "damage snapshot should use damage trigger")
		_assert(float(latest.get("salience", 0.0)) >= 0.8, "damage snapshot should be high salience")
		_assert(float(latest.get("world", {}).get("recent_damage", 0.0)) > 0.0, "damage snapshot should include recent damage")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_local_stub_scribe_mentions_specific_danger_and_plan() -> void:
	var bridge: AIBridge = AIBridgeScript.new()
	var note: Dictionary = bridge.call("_local_stub_scribe", {
		"recent_events": [{"type": "enemy_spawned", "enemy_type": "flying"}],
		"snapshots": [{
			"ari": {
				"current_action": "moving_to_build_site",
				"current_reason": "flying enemy near crops",
				"fear": 42.0,
			},
			"plan": {"next_action": "build_storm_rod"},
			"world": {
				"enemies": {"count": 1, "types": {"flying": 1}},
				"nearest_danger": {"type": "flying", "distance": 96.0},
				"notable_changes": ["first_flying_enemy_seen"],
			},
		}],
	})
	var note_text := str(note.get("note", "")).to_lower()
	_assert(note_text.contains("flying"), "local scribe fallback note should mention the specific danger")
	_assert(note_text.contains("storm"), "local scribe fallback note should mention the active storm response")
	_assert(note_text.contains("moving to build site"), "local scribe fallback note should humanize Ari's current action")
	_assert(note.get("facts", []).has("Ari was moving to build site."), "local scribe fallback facts should humanize Ari's current action")
	var hints: Dictionary = note.get("priority_hints", {})
	_assert(float(hints.get("build_storm_rod", 0.0)) >= 0.55, "local scribe fallback should preserve anti-flying storm priority")
	_assert(float(hints.get("build_tower", 0.0)) >= 0.35, "local scribe fallback should preserve anti-flying tower support")
	_assert(float(hints.get("use_tower", 0.0)) >= 0.25, "local scribe fallback should preserve anti-flying tower-use support")
	bridge.free()


func _test_local_stub_scribe_ignores_internal_plan_event_for_recent_note() -> void:
	var bridge: AIBridge = AIBridgeScript.new()
	var note: Dictionary = bridge.call("_local_stub_scribe", {
		"recent_events": [
			{"type": "enemy_spawned", "enemy_type": "flying"},
			{"type": "agent_plan_created", "action_id": "build_storm_rod"},
			{"type": "night_reflection_created", "title": "The Wings"},
			{"type": "note_reread", "title": "The Wings"},
			{"type": "learning_trace_created", "doctrine_id": "flying_requires_anti_air"},
		],
		"snapshots": [{
			"ari": {"current_action": "moving_to_build_site", "current_reason": "flying enemy near crops"},
			"plan": {"next_action": "build_storm_rod"},
			"world": {
				"enemies": {"count": 1, "types": {"flying": 1}},
				"nearest_danger": {"type": "flying", "distance": 96.0},
			},
		}],
	})
	var note_text := str(note.get("note", "")).to_lower()
	_assert(note_text.contains("enemy spawned"), "local scribe fallback should use the latest gameplay event")
	_assert(not note_text.contains("agent plan created"), "local scribe fallback should not let internal planner telemetry crowd out gameplay")
	_assert(not note_text.contains("night reflection created"), "local scribe fallback should not let internal reflection telemetry crowd out gameplay")
	_assert(not note_text.contains("note reread"), "local scribe fallback should not let rest-memory telemetry crowd out gameplay")
	_assert(not note_text.contains("learning trace created"), "local scribe fallback should not let learning-trace telemetry crowd out gameplay")
	bridge.free()


func _test_local_stub_scribe_keeps_quiet_phase_change_out_of_note_text() -> void:
	var bridge: AIBridge = AIBridgeScript.new()
	var note: Dictionary = bridge.call("_local_stub_scribe", {
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
				"nearest_danger": {"type": "none", "distance": 0.0},
				"notable_changes": ["phase_dusk"],
			},
		}],
		"active_plan": {"next_action": "train_combat"},
	})
	var note_text := str(note.get("note", "")).to_lower()
	var facts_text := " ".join(PackedStringArray(note.get("facts", []))).to_lower()
	_assert(not note_text.contains("phase changed"), "quiet phase changes should not dominate local scribe note text")
	_assert(not facts_text.contains("recent event was phase changed"), "quiet phase changes should not dominate local scribe facts")
	_assert(note.get("world_changes", []).has("phase_dusk"), "quiet phase should remain compact context")
	_assert(note.get("plan_alignment", "") == "aligned", "quiet phase scribe should preserve plan alignment")
	bridge.free()


func _test_local_stub_scribe_marks_body_plan_mismatch() -> void:
	var bridge: AIBridge = AIBridgeScript.new()
	var note: Dictionary = bridge.call("_local_stub_scribe", {
		"recent_events": [{"type": "phase_changed", "phase": "night"}],
		"active_plan": {"next_action": "lure_to_aura"},
		"snapshots": [{
			"ari": {
				"current_action": "moving_to_tower",
				"current_reason": "Night is quiet; stage at range before teeth arrive",
			},
			"plan": {"next_action": "lure_to_aura"},
			"world": {
				"enemies": {"count": 0, "types": {}},
				"nearest_danger": {"type": "none", "distance": 0.0},
				"notable_changes": [],
			},
		}],
	})
	var note_text := str(note.get("note", "")).to_lower()
	_assert(note_text.contains("while plan expected lure to aura"), "local scribe should explicitly mark body/plan mismatch instead of blending contradictory facts")
	_assert(note.get("tags", []).has("plan_body_mismatch"), "local scribe should tag body/plan mismatch")
	_assert(note.get("world_changes", []).has("plan_body_mismatch"), "local scribe should expose mismatch as a reflection-relevant world change")
	var actions: Array = note.get("actions", [])
	_assert(actions.has({"action": "moving_to_tower", "status": "in_progress", "reason": "Night is quiet; stage at range before teeth arrive"}), "local scribe should keep Ari's actual body action")
	_assert(actions.has({"action": "lure_to_aura", "status": "planned", "reason": "Ari's active plan expected this action."}), "local scribe should keep the expected plan action separately")
	bridge.free()


func _test_local_stub_scribe_marks_plan_support_without_mismatch() -> void:
	var bridge: AIBridge = AIBridgeScript.new()
	var note: Dictionary = bridge.call("_local_stub_scribe", {
		"recent_events": [{"type": "structure_damaged", "phase": "morning"}],
		"active_plan": {"next_action": "use_tower"},
		"snapshots": [{
			"ari": {
				"current_action": "moving_to_repair_structure",
				"current_reason": "Patch damaged anti-air support before using the perch",
			},
			"plan": {"next_action": "use_tower"},
			"world": {
				"enemies": {"count": 0, "types": {}},
				"nearest_danger": {"type": "none", "distance": 0.0},
				"notable_changes": ["north_tower_damaged"],
			},
		}],
	})
	var note_text := str(note.get("note", "")).to_lower()
	_assert(note_text.contains("supporting plan use tower"), "local scribe should mark prerequisite repair as support for the tower plan")
	_assert(not note_text.contains("while plan expected use tower"), "local scribe should not frame prerequisite repair as contradiction")
	_assert(not note.get("tags", []).has("plan_body_mismatch"), "local scribe should not tag clear plan support as mismatch")
	_assert(note.get("tags", []).has("plan_support"), "local scribe should tag clear plan support")
	_assert(note.get("world_changes", []).has("plan_support"), "local scribe should expose plan support as reflection-relevant context")
	var actions: Array = note.get("actions", [])
	_assert(actions.has({"action": "use_tower", "status": "supported", "reason": "Ari's current action prepared or protected this plan."}), "local scribe should keep the planned action as supported")
	bridge.free()


func _test_local_stub_scribe_marks_defensive_hold_as_plan_support() -> void:
	var bridge: AIBridge = AIBridgeScript.new()
	var note: Dictionary = bridge.call("_local_stub_scribe", {
		"recent_events": [{"type": "phase_changed", "phase": "night"}],
		"active_plan": {"next_action": "use_tower"},
		"snapshots": [{
			"ari": {
				"current_action": "moving_to_use_fear_lantern",
				"current_reason": "Night is quiet; hold the warm light before teeth arrive",
			},
			"plan": {"next_action": "use_tower"},
			"world": {
				"enemies": {"count": 0, "types": {}},
				"nearest_danger": {"type": "none", "distance": 0.0},
				"notable_changes": [],
			},
		}],
	})
	var note_text := str(note.get("note", "")).to_lower()
	_assert(note_text.contains("supporting plan use tower"), "local scribe should mark quiet defensive holds as support for a tower plan")
	_assert(not note_text.contains("while plan expected use tower"), "local scribe should not frame quiet defensive holds as contradiction")
	_assert(not note.get("tags", []).has("plan_body_mismatch"), "local scribe should not tag quiet defensive holds as mismatch")
	_assert(note.get("tags", []).has("plan_support"), "local scribe should tag quiet defensive holds as plan support")
	bridge.free()


func _test_local_stub_scribe_marks_recovery_as_plan_support() -> void:
	var bridge: AIBridge = AIBridgeScript.new()
	var note: Dictionary = bridge.call("_local_stub_scribe", {
		"recent_events": [{"type": "dawn_enemies_vanished", "phase": "morning"}],
		"active_plan": {"next_action": "use_cover"},
		"snapshots": [{
			"ari": {
				"current_action": "moving_to_bed",
				"current_reason": "Blade plan is ready enough; recover before night",
			},
			"plan": {"next_action": "use_cover"},
			"world": {
				"enemies": {"count": 0, "types": {}},
				"nearest_danger": {"type": "none", "distance": 0.0},
				"notable_changes": [],
			},
		}],
	})
	var note_text := str(note.get("note", "")).to_lower()
	_assert(note_text.contains("supporting plan use cover"), "local scribe should mark safe recovery as support for a cover plan")
	_assert(not note_text.contains("while plan expected use cover"), "local scribe should not frame safe recovery as contradiction")
	_assert(not note.get("tags", []).has("plan_body_mismatch"), "local scribe should not tag safe recovery as mismatch")
	_assert(note.get("tags", []).has("plan_support"), "local scribe should tag safe recovery as plan support")
	var actions: Array = note.get("actions", [])
	_assert(actions.has({"action": "moving_to_bed", "status": "in_progress", "reason": "Blade plan is ready enough; recover before night"}), "local scribe should keep Ari's actual rest movement")
	_assert(actions.has({"action": "use_cover", "status": "supported", "reason": "Ari's current action prepared or protected this plan."}), "local scribe should keep the cover action as supported")
	bridge.free()


func _test_local_library_reflection_fallback_learns_from_flying_scribe() -> void:
	var bridge: AIBridge = AIBridgeScript.new()
	var note: Dictionary = bridge.call("_validated_fallback", "library_reflection", {
		"schema": "ari.night_reflection.request.v1",
		"trigger": "dawn_survived",
		"day": 3,
		"outcome": "survived",
		"snapshots": [{
			"world": {
				"enemies": {"count": 1, "types": {"flying": 1}},
				"nearest_danger": {"type": "flying", "distance": 96.0},
			},
		}],
		"recent_events": [{"type": "enemy_spawned", "enemy_type": "flying"}],
		"scribe_notes": [{
			"note": "Ari saw flying danger and ordinary walls were not enough.",
			"facts": ["Flying enemies were present; ordinary walls may not solve them."],
			"actions": [{"action": "build_wall", "status": "failed", "reason": "Wings crossed the wall."}],
			"dangers": [{"type": "flying", "distance": 96.0, "severity": 0.8}],
			"priority_hints": {"build_storm_rod": 0.7},
			"salience": 0.8,
		}],
	})
	var doctrines: Array = note.get("doctrines", [])
	_assert(float(note.get("priority_hints", {}).get("build_storm_rod", 0.0)) >= 0.55, "local reflection fallback should promote storm rods when flying evidence exists")
	_assert(not doctrines.is_empty(), "local reflection fallback should emit conservative doctrine from flying evidence")
	if not doctrines.is_empty():
		var doctrine: Dictionary = doctrines[0]
		_assert(str(doctrine.get("id", "")) == "local_flying_requires_sky_answer", "local reflection fallback should name the anti-flying doctrine")
		_assert(doctrine.get("when", {}).get("enemy_type_present", "") == "flying", "local reflection fallback doctrine should activate only for flying enemies")
		_assert(float(doctrine.get("bias", {}).get("build_storm_rod", 0.0)) > 0.0, "local reflection fallback doctrine should bias toward storm rods")
		_assert(float(doctrine.get("bias", {}).get("build_wall", 0.0)) < 0.0, "local reflection fallback doctrine should downweight wall-only thinking")
		var plan: Array = doctrine.get("plan", [])
		_assert(plan.size() >= 3, "local reflection fallback doctrine should include storm plus ranged follow-up")
		if plan.size() >= 3:
			_assert(plan[0].get("affordance_id", "") == "build_storm_rod", "local flying doctrine should start with Storm Rod")
			_assert(plan[1].get("affordance_id", "") == "build_tower", "local flying doctrine should add tower support after Storm Rod")
			_assert(plan[2].get("affordance_id", "") == "use_tower", "local flying doctrine should use tower support once built")
	bridge.free()


func _test_day_summary_and_strategy_packet_feed_ai_pipeline() -> void:
	var world: World = await _make_world()
	var memory = world.get("ari_memory")
	var chronicle = world.get("chronicle")
	world.call("commit_sign", "build high when wings come")
	memory.record_event("enemy_spawned", {"day": 2, "phase": "night", "enemy_type": "flying"})
	memory.record_event("structure_damaged", {"day": 2, "phase": "night", "structure_type": "wall"})
	memory.record_snapshot({
		"schema": "ari.observer.snapshot.v1",
		"snapshot_id": "day2_0010_flying",
		"day": 2,
		"phase": "night",
		"trigger": "enemy_spawned",
		"salience": 0.9,
		"ari": {
			"current_action": "moving_to_repair_structure",
			"current_reason": "Ari repaired ground cover while wings approached",
		},
		"sign": {
			"text": "build high when wings come",
			"interpretation": "prepare anti-flying defense",
		},
		"plan": {
			"next_action": "build_storm_rod",
			"recent_outcomes": ["failed_repair_low_stone"],
		},
		"world": {
			"resources": {"stone": 2, "food": 1, "ore": 0},
			"structures": {"walls": 2, "towers": 0, "storm_rods": 0, "damaged": 1},
			"enemies": {"count": 1, "types": {"flying": 1}},
			"nearest_danger": {"type": "flying", "distance": 42.0},
			"recent_damage": 12,
			"notable_changes": ["first_flying_enemy_seen", "north_wall_damaged"],
		},
	})
	chronicle.add_scribe_note({
		"schema": "ari.scribe.note.v2",
		"note": "Ari repaired ground cover while the plan expected a sky answer.",
		"tags": ["danger:flying", "plan_body_mismatch"],
		"facts": ["Flying enemies were present; ordinary walls may not solve them."],
		"actions": [
			{"action": "repair_structure", "status": "in_progress", "reason": "Ari patched ground cover."},
			{"action": "build_storm_rod", "status": "planned", "reason": "Ari's active plan expected this action."},
		],
		"dangers": [{"type": "flying", "distance": 42.0, "severity": 0.9}],
		"world_changes": ["first_flying_enemy_seen", "plan_body_mismatch"],
		"priority_hints": {"build_storm_rod": 0.8, "anti_air_defense": 0.7},
		"plan_alignment": "mismatch",
		"immediate_risk": "high",
		"risk_reason": "Flying enemies ignore ordinary walls.",
		"resource_blockers": ["low_stone"],
		"mistake_candidates": ["repaired ordinary wall before anti-air"],
		"opportunity_candidates": ["build storm rod before extra wall work"],
		"lesson_candidates": ["when wings appear, answer the sky first"],
		"confidence": 0.8,
		"salience": 0.9,
	})

	_assert(world.has_method("_build_day_summary"), "World should build a deterministic day summary before reflection")
	var summary: Dictionary = world.call("_build_day_summary", "dawn_survived", "survived") if world.has_method("_build_day_summary") else {}
	_assert(summary.get("schema", "") == "ari.day_summary.v1", "day summary should carry schema")
	_assert(summary.get("threats", []).has("flying"), "day summary should preserve major threats")
	_assert(summary.get("plan_mismatches", []).size() >= 1, "day summary should preserve body/plan mismatches")
	_assert(summary.get("resource_blockers", []).has("low_stone"), "day summary should preserve resource blockers")
	_assert(_array_text_contains(summary.get("candidate_lessons", []), "sky"), "day summary should preserve supported lesson candidates")
	_assert(world.has_method("_day_summary_log_line"), "World should expose a compact day-summary log line for evidence analysis")
	var summary_log_line := str(world.call("_day_summary_log_line", summary)) if world.has_method("_day_summary_log_line") else ""
	_assert(summary_log_line.begins_with("DAY_SUMMARY "), "day summary log line should use analyzer prefix")
	var parsed_summary = JSON.parse_string(summary_log_line.trim_prefix("DAY_SUMMARY "))
	_assert(typeof(parsed_summary) == TYPE_DICTIONARY, "day summary log line should contain JSON")
	if typeof(parsed_summary) == TYPE_DICTIONARY:
		_assert(parsed_summary.get("schema", "") == "ari.day_summary.v1", "day summary log JSON should preserve schema")
		_assert(not parsed_summary.get("evidence_snapshot_ids", []).is_empty(), "day summary log JSON should preserve evidence ids")
		_assert(not parsed_summary.get("candidate_lessons", []).is_empty(), "day summary log JSON should preserve lessons")

	_assert(world.has_method("_build_strategy_packet"), "World should build a compact strategy packet for planning")
	var strategy: Dictionary = world.call("_build_strategy_packet", "dawn_survived") if world.has_method("_build_strategy_packet") else {}
	_assert(strategy.get("schema", "") == "ari.strategy_packet.v1", "strategy packet should carry schema")
	_assert(strategy.get("main_risks", []).has("flying"), "strategy packet should expose current risks")
	_assert(strategy.get("priority_hints", {}).has("build_storm_rod"), "strategy packet should expose validated priority hints")
	_assert(_array_text_contains(strategy.get("avoid_repeating", []), "wall"), "strategy packet should expose avoid-repeating lessons")

	var reflection_payload: Dictionary = world.call("_build_night_reflection_payload", "dawn_survived", "survived")
	_assert(reflection_payload.get("schema", "") == "ari.night_reflection.request.v2", "reflection payload should use summary-first v2 contract")
	_assert(reflection_payload.get("day_summary", {}).get("schema", "") == "ari.day_summary.v1", "reflection payload should include the day summary")

	var planner_payload: Dictionary = world.call("_build_agent_plan_payload", "night_reflection")
	_assert(planner_payload.get("strategy_packet", {}).get("schema", "") == "ari.strategy_packet.v1", "planner payload should include compact strategy packet")

	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_provenance_and_learning_trace_link_ai_pipeline() -> void:
	var world: World = await _make_world()
	var memory = world.get("ari_memory")
	var chronicle = world.get("chronicle")
	world.call("commit_sign", "build high when wings come")
	memory.record_snapshot({
		"schema": "ari.observer.snapshot.v1",
		"snapshot_id": "trace_snap_flying_01",
		"day": 3,
		"phase": "night",
		"trigger": "enemy_spawned",
		"source": "godot",
		"origin": "observer_snapshot",
		"ari": {"current_action": "repair_structure", "current_reason": "wall cracked"},
		"plan": {"next_action": "build_storm_rod"},
		"world": {
			"resources": {"stone": 2, "food": 1, "ore": 0},
			"enemies": {"count": 1, "types": {"flying": 1}},
			"nearest_danger": {"type": "flying", "distance": 40.0},
			"recent_damage": 6,
			"notable_changes": ["first_flying_enemy_seen"],
		},
		"salience": 0.9,
	})
	chronicle.add_scribe_note({
		"schema": "ari.scribe.note.v2",
		"note_id": "trace_scribe_01",
		"note": "Ari repaired the wall while flying danger required a sky answer.",
		"facts": ["Flying enemy was present."],
		"actions": [{"action": "repair_structure", "status": "in_progress", "reason": "Ari patched ordinary cover."}],
		"dangers": [{"type": "flying", "distance": 40.0, "severity": 0.9}],
		"world_changes": ["first_flying_enemy_seen"],
		"priority_hints": {"build_storm_rod": 0.8},
		"plan_alignment": "mismatch",
		"immediate_risk": "high",
		"risk_reason": "Wings bypass ordinary wall thinking.",
		"mistake_candidates": ["treated flying danger like ground danger"],
		"lesson_candidates": ["answer flying danger with sky defense first"],
		"source": "remote_server",
		"failure_reason": "",
		"origin": "scribe_model",
		"evidence_ids": ["trace_snap_flying_01"],
		"confidence": 0.8,
		"salience": 0.9,
	})
	var stored_scribe: Dictionary = chronicle.get_today_scribe_notes()[0]
	_assert(stored_scribe.get("note_id", "") == "trace_scribe_01", "scribe notes should retain stable note ids for learning traces")
	_assert(stored_scribe.get("origin", "") == "scribe_model", "scribe notes should retain origin")
	_assert(stored_scribe.get("evidence_ids", []).has("trace_snap_flying_01"), "scribe notes should retain evidence ids")

	var summary: Dictionary = world.call("_build_day_summary", "dawn_survived", "survived")
	_assert(str(summary.get("summary_id", "")).length() > 0, "day summary should have a stable summary id")
	_assert(summary.get("source", "") == "deterministic", "day summary should declare deterministic source")
	_assert(summary.get("origin", "") == "day_summary", "day summary should declare origin")
	_assert(summary.get("evidence_ids", []).has("trace_snap_flying_01"), "day summary should preserve evidence ids")

	var reflection := {
		"schema": "ari.night_reflection.v1",
		"title": "Sky Before Stone",
		"markdown": "# Sky Before Stone\n\nAri saw wings and learned the wall was the wrong first answer.",
		"hypothesis": "Flying danger needs anti-air before ordinary repair.",
		"priority_hints": {"build_storm_rod": 0.9},
		"doctrines": [{
			"id": "trace_flying_requires_sky",
			"summary": "When flying enemies appear, build the sky answer first.",
			"when": {"enemy_type_present": "flying"},
			"bias": {"build_storm_rod": 0.9},
			"plan": [{"affordance_id": "build_storm_rod", "priority": 0.9, "reason": "Doctrine says wings need a sky answer."}],
			"confidence": 0.85,
		}],
		"source": "remote_server",
		"failure_reason": "",
		"origin": "library_reflection_model",
		"evidence_ids": ["trace_snap_flying_01"],
		"summary_id": summary.get("summary_id", ""),
		"confidence": 0.85,
	}
	var stored_reflection: Dictionary = world.call("_apply_night_reflection_note", reflection, "dawn_survived")
	var reflection_id := str(stored_reflection.get("reflection_id", ""))
	_assert(reflection_id != "", "reflection notes should receive a stable reflection id")
	_assert(stored_reflection.get("source", "") == "remote_server", "reflection lifetime memory should retain source")
	_assert(stored_reflection.get("origin", "") == "library_reflection_model", "reflection lifetime memory should retain origin")
	_assert(stored_reflection.get("evidence_ids", []).has("trace_snap_flying_01"), "reflection lifetime memory should retain evidence ids")
	var latest_lesson: Dictionary = world.get("lesson_book").get_latest_note()
	_assert(latest_lesson.get("reflection_id", "") == reflection_id, "lesson book notes should keep reflection id")
	_assert(latest_lesson.get("evidence_ids", []).has("trace_snap_flying_01"), "lesson book notes should keep evidence ids")
	var doctrines: Array = world.get("ari_doctrine").get_all_doctrines()
	var learned_doctrine := _find_dictionary(doctrines, "id", "trace_flying_requires_sky")
	_assert(not learned_doctrine.is_empty(), "reflection doctrine should be stored")
	_assert(learned_doctrine.get("reflection_id", "") == reflection_id, "doctrines should keep their reflection id")
	_assert(learned_doctrine.get("evidence_ids", []).has("trace_snap_flying_01"), "doctrines should keep evidence ids")

	var plan_result := {
		"schema": "ari.agent.plan.v1",
		"source": "remote_server",
		"origin": "planner_model",
		"goal": "answer wings",
		"confidence": 0.8,
		"next_action": {"action_id": "build_storm_rod", "reason": "Doctrine says wings need a sky answer."},
		"plan": [{"step_id": "trace_step_01", "action_id": "build_storm_rod", "reason": "Doctrine says wings need a sky answer."}],
		"created_at_seconds": 1.0,
		"step_index": 0,
	}
	world.set("agent_plan", plan_result.duplicate(true))
	world.call("_record_agent_plan_created", "night_reflection", plan_result)
	world.call("_record_agent_plan_outcome", "build_storm_rod", "action_completed", "Storm rod built from learned sky doctrine.", "structure_built")
	var trace_event := _find_event_by_type(memory.get_recent_events(40), "learning_trace_created")
	_assert(not trace_event.is_empty(), "doctrine-influenced later plans should create a learning trace event after outcome")
	if not trace_event.is_empty():
		var trace: Dictionary = trace_event.get("trace", {})
		_assert(trace.get("schema", "") == "ari.learning_trace.v1", "learning trace should carry schema")
		_assert(trace.get("doctrine_id", "") == "trace_flying_requires_sky", "learning trace should link doctrine id")
		_assert(trace.get("reflection_id", "") == reflection_id, "learning trace should link reflection id")
		_assert(trace.get("later_plan_id", "") != "", "learning trace should link later plan id")
		_assert(trace.get("outcome", "") == "action_completed", "learning trace should keep later outcome")
		_assert(trace.get("evidence_ids", []).has("trace_snap_flying_01"), "learning trace should link original evidence ids")
		_assert(str(trace.get("improvement_claim", "")).length() > 0, "learning trace should include a cautious improvement claim")

	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_rolling_tactical_summary_feeds_fast_prediction_and_background() -> void:
	var world: World = await _make_world()
	var memory = world.get("ari_memory")
	var chronicle = world.get("chronicle")
	world.call("commit_sign", "build high when wings come")
	memory.record_snapshot({
		"schema": "ari.observer.snapshot.v1",
		"snapshot_id": "roll_001",
		"day": 2,
		"phase": "night",
		"trigger": "timer",
		"ari": {"current_action": "mine_stone", "current_reason": "need stone"},
		"plan": {"next_action": "mine_stone"},
		"world": {
			"resources": {"stone": 2, "food": 1, "ore": 0},
			"enemies": {"count": 1, "types": {"flying": 1}},
			"nearest_danger": {"type": "flying", "distance": 64.0},
			"recent_damage": 0,
			"notable_changes": ["first_flying_enemy_seen"],
		},
		"salience": 0.8,
	})
	chronicle.add_scribe_note({
		"schema": "ari.scribe.note.v2",
		"note": "Ari kept mining while flying danger approached.",
		"facts": ["Flying enemies were present."],
		"actions": [{"action": "mine_stone", "status": "in_progress", "reason": "Ari wanted stone."}],
		"dangers": [{"type": "flying", "distance": 64.0, "severity": 0.9}],
		"world_changes": ["first_flying_enemy_seen"],
		"priority_hints": {"build_storm_rod": 0.8},
		"plan_alignment": "mismatch",
		"immediate_risk": "high",
		"risk_reason": "Flying enemy is close while Ari mines.",
		"resource_blockers": ["low_stone"],
		"mistake_candidates": ["mining during active flying danger"],
		"lesson_candidates": ["answer flying danger before ordinary mining"],
		"confidence": 0.8,
		"salience": 0.9,
	})

	_assert(world.has_method("_build_rolling_tactical_summary"), "World should build a rolling tactical summary")
	var rolling: Dictionary = world.call("_build_rolling_tactical_summary", "fast_prediction") if world.has_method("_build_rolling_tactical_summary") else {}
	_assert(rolling.get("schema", "") == "ari.rolling_tactical_summary.v1", "rolling tactical summary should carry schema")
	_assert(rolling.get("threats", []).has("flying"), "rolling tactical summary should preserve immediate threat")
	_assert(rolling.get("resource_blockers", []).has("low_stone"), "rolling tactical summary should preserve blockers")
	_assert(_array_text_contains(rolling.get("plan_mismatches", []), "mining"), "rolling tactical summary should preserve tactical mismatch")
	_assert(rolling.get("priority_hints", {}).has("build_storm_rod"), "rolling tactical summary should preserve action priority")

	var prediction_payload: Dictionary = world.call("_build_fast_prediction_payload")
	_assert(prediction_payload.get("rolling_summary", {}).get("schema", "") == "ari.rolling_tactical_summary.v1", "fast prediction payload should include rolling summary")
	var background_job: Dictionary = world.call("_build_background_ai_job", "strategy_candidate", "normal")
	_assert(background_job.get("payload", {}).get("rolling_summary", {}).get("schema", "") == "ari.rolling_tactical_summary.v1", "background jobs should include rolling summary")
	var strategy: Dictionary = world.call("_build_strategy_packet", "fast_prediction")
	_assert(strategy.get("rolling_summary", {}).get("schema", "") == "ari.rolling_tactical_summary.v1", "strategy packet should include rolling summary")

	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_background_ai_jobs_discard_stale_results() -> void:
	var world: World = await _make_world()
	world.call("commit_sign", "build high when wings come")
	_assert(world.has_method("_build_background_ai_job"), "World should build bounded background AI jobs")
	_assert(world.has_method("_on_background_ai_result"), "World should validate background AI results before storing them")
	var job: Dictionary = world.call("_build_background_ai_job", "strategy_candidate", "normal") if world.has_method("_build_background_ai_job") else {}
	_assert(job.get("schema", "") == "ari.background_job.v1", "background job should carry schema")
	_assert(job.get("kind", "") == "strategy_candidate", "background job should preserve job kind")
	_assert(str(job.get("context_hash", "")) != "", "background job should carry a context hash")
	_assert(float(job.get("expires_at_game_time", 0.0)) > float(world.get("_agent_plan_clock")), "background job should expire in game time")

	var stale_result := {
		"schema": "ari.background_result.v1",
		"job_id": job.get("job_id", "job"),
		"kind": "strategy_candidate",
		"context_hash": "old_context",
		"status": "ok",
		"strategy_packet": {"schema": "ari.strategy_packet.v1", "try_next": ["build_storm_rod"]},
		"notes": ["stale result should be ignored"],
		"confidence": 0.8,
	}
	world.call("_on_background_ai_result", stale_result)
	_assert(world.get("_background_ai_results").is_empty(), "stale background result should not be stored")

	var current_result := stale_result.duplicate(true)
	current_result["context_hash"] = job.get("context_hash", "")
	current_result["notes"] = ["current result can help the next plan"]
	world.call("_on_background_ai_result", current_result)
	_assert(world.get("_background_ai_results").size() == 1, "current background result should be stored")
	_assert(world.get("_background_ai_results")[0].get("notes", []).has("current result can help the next plan"), "stored background result should preserve useful notes")

	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_fast_prediction_packets_feed_strategy_evidence() -> void:
	var world: World = await _make_world()
	world.call("commit_sign", "build high when wings come")
	_assert(world.has_method("_build_fast_prediction_payload"), "World should build a tiny 5-second prediction payload")
	_assert(world.has_method("_on_fast_prediction_response"), "World should validate fast prediction responses before storing them")
	var payload: Dictionary = world.call("_build_fast_prediction_payload") if world.has_method("_build_fast_prediction_payload") else {}
	_assert(payload.get("schema", "") == "ari.prediction.request.v1", "fast prediction payload should carry schema")
	_assert(str(payload.get("context_hash", "")) != "", "fast prediction payload should carry context hash")
	_assert(payload.get("legal_actions", []).size() > 0, "fast prediction payload should include legal actions")

	var stale_prediction := {
		"schema": "ari.prediction.v1",
		"context_hash": "old_context",
		"risk_level": "high",
		"prediction": "stale prediction should be ignored",
		"next_action_bias": {"action_id": "build_storm_rod", "urgency": 0.9, "reason": "sky"},
		"priority_hints": {"build_storm_rod": 0.9},
		"avoid": ["ordinary walls before sky answer"],
		"confidence": 0.8,
	}
	world.call("_on_fast_prediction_response", stale_prediction)
	_assert(world.get("_background_ai_results").is_empty(), "stale fast prediction should not be stored")

	var fallback_prediction := stale_prediction.duplicate(true)
	fallback_prediction["context_hash"] = payload.get("context_hash", "")
	fallback_prediction["source"] = "local_fallback"
	fallback_prediction["failure_reason"] = "timeout"
	world.call("_on_fast_prediction_response", fallback_prediction)
	_assert(world.get("_background_ai_results").is_empty(), "fallback fast prediction should not become durable strategy evidence")

	var current_prediction := stale_prediction.duplicate(true)
	current_prediction["context_hash"] = payload.get("context_hash", "")
	current_prediction["prediction"] = "Flying danger needs a sky answer now."
	current_prediction["source"] = "remote_server"
	world.call("_on_fast_prediction_response", current_prediction)
	_assert(world.get("_background_ai_results").size() == 1, "current fast prediction should become strategy evidence")
	var strategy: Dictionary = world.call("_build_strategy_packet", "fast_prediction")
	_assert(strategy.get("priority_hints", {}).has("build_storm_rod"), "fast prediction should feed future priority hints")
	_assert(_array_text_contains(strategy.get("evidence", []), "sky answer"), "fast prediction should feed strategy evidence text")

	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_high_salience_snapshot_primes_fast_prediction() -> void:
	var world: World = await _make_world()
	world.call("commit_sign", "build high when wings come")
	world.set("_fast_prediction_elapsed", 0.0)
	world.call("_record_observer_snapshot", "timer", 0.1, [])
	_assert(float(world.get("_fast_prediction_elapsed")) < 1.0, "ordinary timer snapshots should not force immediate prediction")
	world.call("_record_observer_snapshot", "enemy_spawned", 0.75, ["enemy_spawned", "zombie"])
	_assert(float(world.get("_fast_prediction_elapsed")) < 1.0, "enemy labels without current tactical danger should not wake prediction")
	var arena: Rect2 = world.call("get_arena_rect")
	world.call("_spawn_enemy", arena.get_center() + Vector2(90.0, -30.0), "flying")
	world.set("_fast_prediction_elapsed", 0.0)
	world.call("_record_observer_snapshot", "enemy_spawned", 0.75, ["enemy_spawned", "flying"])
	_assert(float(world.get("_fast_prediction_elapsed")) >= 5.0, "high-salience enemy snapshots should prime a sub-5s prediction request")
	world.set("_fast_prediction_elapsed", 0.0)
	world.set("_fast_prediction_request_in_flight", true)
	world.call("_record_observer_snapshot", "damage", 0.85, ["ari_damaged"])
	_assert(float(world.get("_fast_prediction_elapsed")) < 1.0, "high-salience snapshots should not pile up while prediction is already in flight")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_night_reflection_payload_caps_and_valid_note_learning() -> void:
	var world: World = await _make_world()
	var memory = world.get("ari_memory")
	for i in range(90):
		memory.record_event("ari_damaged", {"day": 2, "phase": "night", "hp": 90 - i})
	for i in range(50):
		memory.record_snapshot({"schema": "ari.observer.snapshot.v1", "snapshot_id": "snap_%d" % i, "salience": 0.9 if i % 10 == 0 else 0.1})
	var chronicle = world.get("chronicle")
	_assert(chronicle != null, "World should own Chronicle before building reflection payloads")
	if chronicle != null:
		for i in range(12):
			chronicle.add_scribe_note({
				"note": "note %d" % i,
				"tags": ["test"],
				"facts": ["fact %d" % i],
				"actions": [{"action": "build_wall", "status": "failed" if i == 11 else "in_progress", "reason": "test"}],
				"dangers": [{"type": "flying", "distance": 96.0, "severity": 0.8}],
				"world_changes": ["change %d" % i],
				"priority_hints": {"build_storm_rod": 0.7},
				"confidence": 0.75,
				"salience": 0.5,
			})

	_assert(world.has_method("_build_night_reflection_payload"), "World should build capped night reflection payloads")
	if world.has_method("_build_night_reflection_payload"):
		var payload: Dictionary = world.call("_build_night_reflection_payload", "dawn_survived", "survived")
		_assert(payload.get("schema", "") == "ari.night_reflection.request.v2", "reflection payload should carry schema")
		_assert(payload.get("day_summary", {}).get("schema", "") == "ari.day_summary.v1", "reflection payload should carry deterministic day summary")
		_assert(payload.get("snapshots", []).size() <= 40, "reflection payload should cap snapshots")
		_assert(payload.get("recent_events", []).size() <= 80, "reflection payload should cap events")
		_assert(payload.get("scribe_notes", []).size() <= 10, "reflection payload should cap scribe notes")
		var payload_notes: Array = payload.get("scribe_notes", [])
		_assert(not payload_notes.is_empty() and payload_notes[payload_notes.size() - 1].get("facts", []).has("fact 11"), "reflection payload should carry structured scribe facts")
		_assert(payload_notes[payload_notes.size() - 1].get("actions", [])[0].get("status", "") == "failed", "reflection payload should carry structured scribe action outcomes")
		_assert(payload_notes[payload_notes.size() - 1].get("dangers", [])[0].get("type", "") == "flying", "reflection payload should carry structured scribe dangers")
		_assert(payload_notes[payload_notes.size() - 1].get("priority_hints", {}).has("build_storm_rod"), "reflection payload should carry scribe priority hints")
		_assert(payload.has("agent_plan_outcomes"), "reflection payload should include agent plan outcomes")
		_assert(payload.has("active_doctrines"), "reflection payload should include active doctrines")

	_assert(world.has_method("_apply_night_reflection_note"), "World should apply validated reflection through memory/doctrine channels")
	if world.has_method("_apply_night_reflection_note"):
		var note := {
			"schema": "ari.night_reflection.v1",
			"title": "The Wings Over the Wall",
			"markdown": "# The Wings\n\nAri learned that wings need sky answers.",
			"hypothesis": "Flying enemies need anti-air before extra wall.",
			"priority_hints": {"build_storm_rod": 0.9},
			"priority_bias": {"build_storm_rod": 0.9},
			"doctrines": [{
				"id": "flying_requires_anti_air",
				"summary": "When flying enemies appear, build the sky answer first.",
				"when": {"enemy_type_present": "flying"},
				"bias": {"build_storm_rod": 0.9},
				"plan": [{"affordance_id": "build_storm_rod", "priority": 0.9, "reason": "Wings need a sky defense."}],
				"confidence": 0.9,
			}],
			"thought": "Wings do not respect stone.",
			"confidence": 0.9,
		}
		var lessons_before: int = world.get("lesson_book").get_all_notes().size()
		world.call("_apply_night_reflection_note", note, "dawn_survived")
		_assert(world.get("lesson_book").get_all_notes().size() == lessons_before + 1, "reflection should add a lesson book note")
		_assert(memory.get_latest_lifetime_note().get("title", "") == "The Wings Over the Wall", "reflection should add Ari lifetime memory")
		var active_plan: Array = world.get("ari_doctrine").get_active_plan({"enemy_type_counts": {"flying": 1}})
		_assert(not active_plan.is_empty() and active_plan[0].get("affordance_id", "") == "build_storm_rod", "reflection doctrine should affect future planning")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_night_started_reflection_does_not_spend_smart_endpoint() -> void:
	var world: World = await _make_world()
	var bridge: AIBridge = world.get("ai_bridge")
	_assert(bridge != null, "World should own an AI bridge for reflection cadence checks")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	var before_requests := _http_request_child_count(bridge)
	world.call("_request_night_reflection", "night_started", "in_progress")
	_assert(_http_request_child_count(bridge) == before_requests, "night-start reflection should not spend the smarter endpoint before the outcome is known")
	_assert(not bool(world.get("_night_reflection_request_in_flight")), "night-start reflection skip should not leave an in-flight marker")
	var requested: Dictionary = world.get("_night_reflection_requested")
	_assert(not requested.has("%d:night_started" % int(world.get("day_night").get("day"))), "night-start reflection skip should not consume the per-day reflection key")
	world.call("_request_night_reflection", "dawn_survived", "survived")
	_assert(_http_request_child_count(bridge) > before_requests or bool(world.get("_night_reflection_request_in_flight")), "dawn reflection should still spend the smarter endpoint after an outcome exists")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _make_world() -> World:
	var world: World = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")
	return world


func _http_request_child_count(node: Node) -> int:
	if node == null:
		return 0
	var count := 0
	for child in node.get_children():
		if child is HTTPRequest:
			count += 1
	return count


func _array_text_contains(items, fragment: String) -> bool:
	if typeof(items) != TYPE_ARRAY:
		return false
	var needle := fragment.to_lower()
	for item in items:
		if str(item).to_lower().contains(needle):
			return true
	return false


func _find_dictionary(items: Array, key: String, value: String) -> Dictionary:
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and str(item.get(key, "")) == value:
			return item.duplicate(true)
	return {}


func _find_event_by_type(items: Array, event_type: String) -> Dictionary:
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and str(item.get("type", "")) == event_type:
			return item.duplicate(true)
	return {}


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
