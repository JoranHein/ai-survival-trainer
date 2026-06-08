extends SceneTree

const AIBridgeScript = preload("res://scripts/autoload/AIBridge.gd")
const ScribeSystemScript = preload("res://scripts/ari/ScribeSystem.gd")
const WorldScene = preload("res://scenes/world/World.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_behavior_evidence_collection_and_neutral_scribe()
	_test_scribe_system_validation_preserves_behavior_evidence()
	await _test_anchor_switching_evidence_is_distinct_from_action_switching()
	await _test_llm_reflection_doctrine_from_behavior_evidence_changes_later_planning()
	await _test_negative_doctrine_bias_not_inverted_into_strategy_priority()

	if failures.is_empty():
		print("Ari behavior evidence reflection tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_anchor_switching_evidence_is_distinct_from_action_switching() -> void:
	var world: World = await _make_world()
	world.set("_agent_plan_clock", 36.0)
	world.set("_behavior_action_history", [
		_behavior_sample("day1_anchor_001", 0.0, "use_cover", "in_progress", "wall_alpha"),
		_behavior_sample("day1_anchor_002", 6.0, "use_cover", "in_progress", "tower_alpha"),
		_behavior_sample("day1_anchor_003", 12.0, "use_cover", "in_progress", "aura_alpha"),
		_behavior_sample("day1_anchor_004", 18.0, "use_cover", "in_progress", "wall_alpha"),
		_behavior_sample("day1_anchor_005", 24.0, "use_cover", "in_progress", "tower_alpha"),
		_behavior_sample("day1_anchor_006", 30.0, "use_cover", "in_progress", "aura_alpha"),
		_behavior_sample("day1_anchor_007", 36.0, "use_cover", "in_progress", "wall_alpha"),
	])
	world.set("_latest_behavior_evidence", {})
	var evidence_items: Array = world.call("_behavior_evidence_array", 4)
	var anchor_evidence := _find_pattern(evidence_items, "repeated_anchor_switching")
	_assert(not anchor_evidence.is_empty(), "behavior evidence should detect repeated anchor switching even when the action id stays stable")
	if not anchor_evidence.is_empty():
		_assert(int(anchor_evidence.get("anchor_transition_count", 0)) >= 4, "anchor switching evidence should count target-anchor transitions")
		_assert(anchor_evidence.get("anchors_seen", []).has("wall_alpha"), "anchor evidence should preserve observed wall anchor")
		_assert(anchor_evidence.get("anchors_seen", []).has("tower_alpha"), "anchor evidence should preserve observed tower anchor")
		_assert(not str(anchor_evidence.get("neutral_summary", "")).to_lower().contains("should"), "anchor switching summary should stay observational")
	await _free_world(world)


func _test_scribe_system_validation_preserves_behavior_evidence() -> void:
	var scribe = ScribeSystemScript.new()
	var evidence := _sample_behavior_evidence()
	var note: Dictionary = scribe.call("_validate_scribe_note", {
		"schema": "ari.scribe.note.v2",
		"note": "Ari switched between defenses without progress.",
		"facts": [evidence.get("neutral_summary", "")],
		"world_changes": ["repeated_action_switching"],
		"behavior_evidence": [evidence],
		"source": "remote_server",
	})
	var behavior_evidence = note.get("behavior_evidence", [])
	_assert(typeof(behavior_evidence) == TYPE_ARRAY and not behavior_evidence.is_empty(), "ScribeSystem validation should preserve structured behavior evidence before Chronicle storage")
	if typeof(behavior_evidence) == TYPE_ARRAY and not behavior_evidence.is_empty():
		_assert(behavior_evidence[0].get("primary_pattern", "") == "repeated_action_switching", "ScribeSystem validation should preserve behavior evidence pattern")


func _sample_behavior_evidence() -> Dictionary:
	return {
		"schema": "ari.behavior_evidence.v1",
		"window_seconds": 45.0,
		"primary_pattern": "repeated_action_switching",
		"actions_seen": ["build_wall", "repair_structure", "use_cover"],
		"transition_count": 6,
		"completion_count": 0,
		"blocked_count": 1,
		"abandoned_count": 4,
		"progress_delta": {"structures": 0, "stone": -2, "repairs": 0, "kills": 0, "hp": 0},
		"context": {
			"phase": "midday",
			"enemy_count_before": 0,
			"enemy_count_after": 0,
			"nearest_danger_changed": false,
			"active_plan_changed": false,
		},
		"evidence_ids": ["day2_0421_action_switch", "day2_0430_action_switch"],
		"neutral_summary": "Ari switched between build_wall, repair_structure, and use_cover 6 times in 45 seconds; no build or repair completed.",
	}


func _test_behavior_evidence_collection_and_neutral_scribe() -> void:
	var world: World = await _make_world()
	if not _assert_behavior_methods(world):
		await _free_world(world)
		return
	_seed_repeated_switching(world)
	var evidence: Dictionary = world.call("_current_behavior_evidence")
	_assert(evidence.get("schema", "") == "ari.behavior_evidence.v1", "behavior evidence should use v1 schema")
	_assert(evidence.get("primary_pattern", "") == "repeated_action_switching", "repeated defensive switching should be detected as a general pattern")
	_assert(int(evidence.get("transition_count", 0)) >= 5, "behavior evidence should count repeated action transitions")
	_assert(int(evidence.get("completion_count", -1)) == 0, "behavior evidence should show no completed work")
	_assert(evidence.get("actions_seen", []).has("build_wall"), "behavior evidence should preserve build_wall as observed action")
	_assert(evidence.get("actions_seen", []).has("repair_structure"), "behavior evidence should preserve repair_structure as observed action")
	_assert(evidence.get("actions_seen", []).has("use_cover"), "behavior evidence should preserve use_cover as observed action")
	_assert(str(evidence.get("neutral_summary", "")).contains("switched between"), "behavior evidence should include a neutral switching summary")
	_assert(not str(evidence.get("neutral_summary", "")).to_lower().contains("should"), "behavior evidence summary should not prescribe the fix")
	var snapshot: Dictionary = world.call("_build_observer_snapshot", "timer", 0.2, ["manual_behavior_check"])
	_assert(snapshot.get("behavior_evidence", {}).get("primary_pattern", "") == "repeated_action_switching", "observer snapshots should carry latest behavior evidence")

	var bridge: AIBridge = world.get("ai_bridge")
	var note: Dictionary = bridge.call("_local_stub_scribe", {
		"schema": "ari.scribe.request.v1",
		"day": 1,
		"phase": "morning",
		"active_plan": {"next_action": "build_wall"},
		"snapshots": [snapshot],
		"behavior_evidence": [evidence],
	})
	_assert(_array_text_contains(note.get("facts", []), "switched between"), "scribe should state repeated switching as a fact")
	_assert(note.get("world_changes", []).has("repeated_action_switching"), "scribe should expose repeated switching as a world change")
	_assert(not note.get("priority_hints", {}).has("build_wall"), "scribe should not turn neutral behavior evidence into an action fix")
	_assert(not _array_text_contains(note.get("lesson_candidates", []), "finish"), "scribe lesson candidates should not prewrite the anti-switching doctrine")
	_assert(note.get("behavior_evidence", [])[0].get("primary_pattern", "") == "repeated_action_switching", "scribe note should preserve structured behavior evidence")

	var fallback_reflection: Dictionary = bridge.call("_validated_fallback", "library_reflection", {
		"schema": "ari.night_reflection.request.v2",
		"day": 1,
		"trigger": "dawn_survived",
		"outcome": "survived",
		"recent_events": [],
		"scribe_notes": [note],
		"behavior_evidence": [evidence],
		"day_summary": {"behavior_evidence": [evidence], "behavior_patterns": ["repeated_action_switching"]},
		"active_doctrines": [],
	})
	_assert(not _array_id_contains_text(fallback_reflection.get("doctrines", []), "switch"), "deterministic fallback reflection must not invent a specific anti-switching doctrine")
	_assert(not _array_id_contains_text(fallback_reflection.get("doctrines", []), "oscillat"), "deterministic fallback reflection must not invent an oscillation doctrine")

	await _free_world(world)


func _test_llm_reflection_doctrine_from_behavior_evidence_changes_later_planning() -> void:
	var world: World = await _make_world()
	if not _assert_behavior_methods(world):
		await _free_world(world)
		return
	_set_stone(world, 80)
	_seed_repeated_switching(world)
	var evidence: Dictionary = world.call("_current_behavior_evidence")
	var chronicle = world.get("chronicle")
	chronicle.add_scribe_note({
		"schema": "ari.scribe.note.v2",
		"note_id": "behavior_scribe_01",
		"note": "Ari switched between build_wall, repair_structure, and use_cover 6 times; no build or repair completed.",
		"facts": [evidence.get("neutral_summary", "")],
		"actions": [
			{"action": "build_wall", "status": "in_progress", "reason": "Ari started wall work."},
			{"action": "repair_structure", "status": "abandoned", "reason": "Ari left repair work."},
			{"action": "use_cover", "status": "in_progress", "reason": "Ari moved back to cover."},
		],
		"world_changes": ["repeated_action_switching"],
		"mistake_candidates": ["repeated switching happened without progress"],
		"lesson_candidates": ["review whether repeated switching helped survival"],
		"behavior_evidence": [evidence],
		"evidence_ids": evidence.get("evidence_ids", []),
		"source": "remote_server",
		"origin": "scribe_model",
		"confidence": 0.8,
		"salience": 0.85,
	})
	var stored_scribe_notes: Array = chronicle.get_today_scribe_notes()
	_assert(stored_scribe_notes[0].get("behavior_evidence", [])[0].get("primary_pattern", "") == "repeated_action_switching", "stored scribe notes should preserve structured behavior evidence")

	var reflection_payload: Dictionary = world.call("_build_night_reflection_payload", "dawn_survived", "survived")
	_assert(reflection_payload.get("behavior_evidence", [])[0].get("primary_pattern", "") == "repeated_action_switching", "reflection payload should include behavior evidence")
	_assert(reflection_payload.get("day_summary", {}).get("behavior_evidence", [])[0].get("primary_pattern", "") == "repeated_action_switching", "day summary should include behavior evidence")

	var reflection := {
		"schema": "ari.night_reflection.v1",
		"title": "Hold One Thread",
		"markdown": "# Hold One Thread\n\nAri noticed repeated defensive switching without progress.",
		"hypothesis": "When danger and resources are stable, repeated defensive switching can waste preparation time.",
		"what_changed": ["repeated_action_switching"],
		"worked": [],
		"went_wrong": ["switched defensive tasks without progress"],
		"misunderstood": ["treated stable conditions like a reason to restart the task"],
		"lesson": "When the pattern is repeated_action_switching and danger did not change, keep one legal defensive step long enough to complete it.",
		"priority_hints": {},
		"priority_bias": {"build_wall": 0.22, "repair_structure": -0.06, "use_cover": -0.04},
		"doctrines": [{
			"id": "reflection_finish_defense_before_switching",
			"summary": "When repeated defensive switching happens without changed danger, keep one legal defensive step long enough to complete it.",
			"when": {"behavior_pattern": "repeated_action_switching", "danger_changed": false},
			"bias": {"build_wall": 0.22, "repair_structure": -0.06, "use_cover": -0.04},
			"plan": [{"affordance_id": "build_wall", "priority": 0.62, "reason": "LLM reflection chose this legal defense step from behavior evidence."}],
			"control": {
				"preferred_anchor_kind": "safest_defense",
				"min_hold_seconds": 14.0,
				"avoid_action_ids": ["train_combat", "spawn_dragon"],
				"allowed_break_reasons": ["danger_changed", "anchor_destroyed", "model_said_so"],
			},
			"confidence": 0.42,
		}],
		"source": "remote_server",
		"origin": "library_reflection_model",
		"evidence_ids": evidence.get("evidence_ids", []),
		"behavior_evidence": [evidence],
		"summary_id": reflection_payload.get("day_summary", {}).get("summary_id", ""),
		"confidence": 0.55,
	}
	var stored_reflection: Dictionary = world.call("_handle_night_reflection_response", reflection, "dawn_survived")
	_assert(stored_reflection.get("behavior_evidence", [])[0].get("primary_pattern", "") == "repeated_action_switching", "stored reflection note should preserve structured behavior evidence")
	_assert(world.get("lesson_book").get_latest_note().get("behavior_evidence", [])[0].get("primary_pattern", "") == "repeated_action_switching", "lesson book notes should preserve structured behavior evidence")
	var doctrines: Array = world.get("ari_doctrine").get_all_doctrines()
	var learned := _find_dictionary(doctrines, "id", "reflection_finish_defense_before_switching")
	_assert(not learned.is_empty(), "LLM behavior doctrine should be stored")
	_assert(learned.get("when", {}).get("behavior_pattern", "") == "repeated_action_switching", "stored doctrine should preserve behavior pattern condition")
	_assert(learned.get("evidence_ids", []).has(str(evidence.get("evidence_ids", [""])[0])), "stored doctrine should link behavior evidence ids")
	var learned_control: Dictionary = learned.get("control", {})
	_assert(learned_control.get("preferred_anchor_kind", "") == "safest_defense", "stored doctrine should preserve validated control anchor kind")
	_assert(float(learned_control.get("min_hold_seconds", 0.0)) == 14.0, "stored doctrine should preserve validated hold duration")
	_assert(learned_control.get("avoid_action_ids", []).has("train_combat"), "stored doctrine should preserve known avoided action ids")
	_assert(not learned_control.get("avoid_action_ids", []).has("spawn_dragon"), "stored doctrine should reject unknown avoided action ids")
	_assert(not learned_control.get("allowed_break_reasons", []).has("model_said_so"), "stored doctrine should reject unsafe break reasons")
	var active_bias: Dictionary = world.get("ari_doctrine").get_active_bias({
		"behavior_patterns": ["repeated_action_switching"],
		"behavior_evidence": [evidence],
		"danger_changed": false,
	})
	_assert(float(active_bias.get("hold_best_defense", 0.0)) > 0.0, "active doctrine control should bias Ari toward holding one safe defense")
	_assert(float(active_bias.get("train_combat", 0.0)) < 0.0, "active doctrine control should bias away from validated avoided actions")

	var planner_payload: Dictionary = world.call("_build_agent_plan_payload", "night_reflection")
	_assert(planner_payload.get("behavior_evidence", [])[0].get("primary_pattern", "") == "repeated_action_switching", "planner payload should include latest behavior evidence")
	_assert(_array_has_dictionary_value(planner_payload.get("active_doctrines", []), "id", "reflection_finish_defense_before_switching"), "planner payload should include active behavior doctrine")
	var compact_control := {}
	var active_doctrines = planner_payload.get("active_doctrines", [])
	if typeof(active_doctrines) == TYPE_ARRAY and not active_doctrines.is_empty() and typeof(active_doctrines[0]) == TYPE_DICTIONARY:
		compact_control = active_doctrines[0].get("control", {})
	_assert(compact_control.get("avoid_action_ids", []).has("train_combat"), "planner payload should expose active doctrine control")
	_assert(_array_has_dictionary_value(planner_payload.get("active_doctrine_plan", []), "affordance_id", "build_wall"), "active doctrine plan should expose LLM-chosen legal action")

	var bridge: AIBridge = world.get("ai_bridge")
	var remote_plan := {
		"schema": "ari.agent.plan.v1",
		"goal": "steady defense",
		"survival_theory": "The learned reflection says repeated switching wasted time.",
		"plan": [{"step_id": "behavior_doctrine_wall", "action_id": "build_wall", "reason": "Doctrine from behavior evidence says to keep one legal defense step long enough.", "success": "action_completed"}],
		"next_action": {"action_id": "build_wall", "urgency": 0.72, "reason": "Doctrine from behavior evidence says to keep one legal defense step long enough."},
		"fallback_action": {"action_id": "flee", "urgency": 0.3, "reason": "Create distance if the build becomes unsafe."},
		"belief_updates": [],
		"thought": "I keep one thread in my hands.",
		"confidence": 0.74,
		"replan_after_seconds": 10.0,
	}
	var validated_plan: Dictionary = bridge.call("_validate_agent_plan", remote_plan, planner_payload, true, "remote_server")
	_assert(validated_plan.get("source", "") == "remote_server", "mocked LLM planner response should remain remote when actions are legal")
	_assert(validated_plan.get("next_action", {}).get("action_id", "") == "build_wall", "mocked planner should be allowed to choose the doctrine's legal action")
	world.call("_on_agent_plan_response", int(world.get("_agent_plan_request_id")), validated_plan)
	world.call("_record_agent_plan_outcome", "build_wall", "action_completed", "Wall completed after behavior-evidence doctrine.", "structure_built")
	var trace_event := _find_event_by_type(world.get("ari_memory").get_recent_events(40), "learning_trace_created")
	_assert(not trace_event.is_empty(), "doctrine-influenced behavior plan should create a learning trace")
	if not trace_event.is_empty():
		var trace: Dictionary = trace_event.get("trace", {})
		_assert(trace.get("doctrine_id", "") == "reflection_finish_defense_before_switching", "learning trace should link behavior doctrine id")
		_assert(trace.get("outcome", "") == "action_completed", "learning trace should record later outcome")
		_assert(str(trace.get("improvement_claim", "")).contains("switch"), "learning trace improvement claim should mention switching evidence when available")

	await _free_world(world)


func _test_negative_doctrine_bias_not_inverted_into_strategy_priority() -> void:
	var world: World = await _make_world()
	var doctrine = world.get("ari_doctrine")
	if doctrine == null:
		_assert(false, "World should own AriDoctrine")
		await _free_world(world)
		return
	doctrine.add_doctrine({
		"id": "avoid_wall_when_wings_are_known",
		"summary": "Avoid wall bias should remain negative in strategy hints.",
		"when": {"min_day": 1},
		"bias": {"build_wall": -0.8, "build_storm_rod": 0.5},
		"confidence": 1.0,
	})
	var strategy: Dictionary = world.call("_build_strategy_packet", "bias_test")
	var hints: Dictionary = strategy.get("priority_hints", {})
	_assert(float(hints.get("build_wall", 0.0)) <= 0.0, "negative doctrine bias must not be inverted into positive build_wall priority")
	_assert(float(hints.get("build_storm_rod", 0.0)) > 0.0, "positive doctrine bias should still enter strategy priority")
	await _free_world(world)


func _seed_repeated_switching(world: World) -> void:
	world.call("commit_sign", "make the walls ready before night")
	world.set("_agent_plan_clock", 0.0)
	world.call("_record_behavior_action_sample", "build_wall", "in_progress", "Ari started wall work.", "timer")
	world.set("_agent_plan_clock", 8.0)
	world.call("_record_behavior_action_sample", "repair_structure", "abandoned", "Ari left the wall to repair.", "timer")
	world.set("_agent_plan_clock", 15.0)
	world.call("_record_behavior_action_sample", "use_cover", "in_progress", "Ari moved back to cover.", "timer")
	world.set("_agent_plan_clock", 22.0)
	world.call("_record_behavior_action_sample", "build_wall", "abandoned", "Ari returned to wall work.", "timer")
	world.set("_agent_plan_clock", 29.0)
	world.call("_record_behavior_action_sample", "repair_structure", "abandoned", "Ari changed back to repair.", "timer")
	world.set("_agent_plan_clock", 36.0)
	world.call("_record_behavior_action_sample", "use_cover", "in_progress", "Ari moved to cover again.", "timer")


func _behavior_sample(sample_id: String, time: float, action_id: String, status: String, anchor_id: String) -> Dictionary:
	return {
		"sample_id": sample_id,
		"day": 1,
		"phase": "night",
		"time": time,
		"action_id": action_id,
		"status": status,
		"reason": "Ari moved to another defense.",
		"trigger": "test",
		"plan_action": "use_cover",
		"stone": 10,
		"food": 2,
		"ore": 0,
		"hp": 90.0,
		"structures": 3,
		"damaged_structures": 0,
		"enemy_count": 1,
		"enemy_type_counts": {"zombie": 1},
		"nearest_danger": {"type": "zombie", "distance": 120.0},
		"anchor_id": anchor_id,
	}


func _assert_behavior_methods(world: World) -> bool:
	var ok := true
	if not world.has_method("_record_behavior_action_sample"):
		_assert(false, "World should expose internal behavior action samples for evidence tests")
		ok = false
	if not world.has_method("_current_behavior_evidence"):
		_assert(false, "World should expose current behavior evidence")
		ok = false
	return ok


func _make_world() -> World:
	var world: World = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")
	return world


func _free_world(world: World) -> void:
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _set_stone(world: World, amount: int) -> void:
	var resource_system = world.get("resource_system")
	if resource_system == null:
		return
	var current := int(resource_system.call("get_stone"))
	if current > 0:
		resource_system.call("spend", {"stone": current})
	if amount > 0:
		resource_system.call("add_stone", amount)


func _array_text_contains(items, text: String) -> bool:
	if typeof(items) != TYPE_ARRAY:
		return false
	var needle := text.to_lower()
	for item in items:
		if str(item).to_lower().contains(needle):
			return true
	return false


func _array_id_contains_text(items, text: String) -> bool:
	if typeof(items) != TYPE_ARRAY:
		return false
	var needle := text.to_lower()
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and str(item.get("id", "")).to_lower().contains(needle):
			return true
	return false


func _array_has_dictionary_value(items, key: String, expected: String) -> bool:
	if typeof(items) != TYPE_ARRAY:
		return false
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and str(item.get(key, "")) == expected:
			return true
	return false


func _find_dictionary(items, key: String, expected: String) -> Dictionary:
	if typeof(items) != TYPE_ARRAY:
		return {}
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and str(item.get(key, "")) == expected:
			return item
	return {}


func _find_pattern(items: Array, pattern: String) -> Dictionary:
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and str(item.get("primary_pattern", "")) == pattern:
			return item
	return {}


func _find_event_by_type(events: Array, event_type: String) -> Dictionary:
	for event in events:
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == event_type:
			return event
	return {}


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
