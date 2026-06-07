extends SceneTree

const AIBridgeScript = preload("res://scripts/autoload/AIBridge.gd")
const WorldScene = preload("res://scenes/world/World.tscn")

var failures: Array[String] = []
var passes: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _pass_wing_low_stone_packet()
	await _pass_wing_low_stone_body_prerequisite()
	await _pass_wing_enough_stone_builds_storm_rod()
	await _pass_storm_then_tower_support()
	await _pass_true_body_plan_mismatch()
	await _pass_safety_substitution_under_danger()
	await _pass_empty_sign_fallback()
	await _pass_vague_sign_fallback()
	await _pass_direct_combat_safety_pressure()
	await _pass_flying_reflection_becomes_doctrine()
	await _pass_payload_builders_do_not_mutate_world()

	_assert(passes.size() >= 10, "repeated gameplay checks should record at least 10 passing scenario runs")
	if failures.is_empty():
		print("Ari understanding gameplay scenario tests passed: %d passes." % passes.size())
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _pass_wing_low_stone_packet() -> void:
	var before := failures.size()
	var world: World = await _make_world()
	await _commit_sign(world, "build high when wings come")
	_set_stone(world, 0)
	_spawn_flying(world)
	world.call("_refresh_ari_understanding", "scenario_low_stone")
	var packet: Dictionary = world.get("ari_understanding")
	_assert(packet.get("schema", "") == "ari.understanding.v1", "wing/low-stone packet should use understanding schema")
	_assert(str(packet.get("sign_thesis", "")).to_lower().contains("sky") or str(packet.get("sign_thesis", "")).to_lower().contains("wing"), "wing sign should produce sky/wing thesis")
	_assert(_array_has_dictionary_value(packet.get("legal_answers", []), "action_id", "build_storm_rod"), "wing packet should keep Storm Rod as a validated legal answer")
	_assert(_array_has_dictionary_value(packet.get("prerequisite_ladder", []), "action_id", "build_storm_rod"), "wing packet should include Storm Rod prerequisite ladder")
	_assert(_array_has_dictionary_value(packet.get("prerequisite_ladder", []), "action_id", "mine_stone"), "wing packet should include mine_stone when Storm Rod lacks stone")
	_assert_concrete_legal_answers(packet)
	var state := await _capture_state(world)
	_assert(state.get("ari_understanding", {}).get("schema", "") == "ari.understanding.v1", "state should expose compact understanding")
	_assert(str(state.get("ari_understanding_line", "")).strip_edges() != "", "state should expose understanding display line")
	_assert(world.call("_build_agent_plan_payload", "scenario").get("strategy_packet", {}).get("understanding", {}).get("schema", "") == "ari.understanding.v1", "planner payload should carry nested understanding")
	var prediction_payload: Dictionary = world.call("_build_fast_prediction_payload")
	_assert(prediction_payload.get("strategy_packet", {}).get("understanding", {}).get("schema", "") == "ari.understanding.v1", "prediction payload should carry nested understanding")
	_assert(JSON.stringify(prediction_payload).length() <= 5000, "fast prediction payload should remain within live size cap")
	_finish_pass("wing_low_stone_packet", before)
	await _free_world(world)


func _pass_wing_low_stone_body_prerequisite() -> void:
	var before := failures.size()
	var world: World = await _make_world()
	await _commit_sign(world, "build high when wings come")
	_set_stone(world, 0)
	await _inject_plan(world, ["build_storm_rod"], "A Storm Rod answers wings.")
	world.call("_advance_ari_daytime", 0.25)
	var alignment: Dictionary = world.get("_latest_body_alignment")
	_assert(alignment.get("relation", "") == "prerequisite_progress", "low stone should make Ari mining stone prerequisite progress")
	_assert(alignment.get("planned_action", "") == "build_storm_rod", "body alignment should preserve planned Storm Rod")
	_assert(alignment.get("body_action", "") == "mine_stone", "body alignment should preserve actual mining job")
	world.call("_refresh_ari_understanding", "scenario_body")
	_assert(world.get("ari_understanding").get("body_alignment", {}).get("relation", "") == "prerequisite_progress", "understanding should carry latest prerequisite trace")
	var snapshot: Dictionary = world.call("_build_observer_snapshot", "scenario", 0.7, ["first_flying_enemy_seen"])
	var bridge: AIBridge = world.get("ai_bridge")
	var note: Dictionary = bridge.call("_local_stub_scribe", {
		"active_plan": world.call("_agent_current_plan_payload"),
		"snapshots": [snapshot],
	})
	_assert(note.get("plan_alignment", "") == "supporting", "scribe should classify prerequisite mining as support")
	_assert(note.get("world_changes", []).has("prerequisite_progress"), "scribe should expose prerequisite progress")
	_finish_pass("wing_low_stone_body_prerequisite", before)
	await _free_world(world)


func _pass_wing_enough_stone_builds_storm_rod() -> void:
	var before := failures.size()
	var world: World = await _make_world()
	_set_stone(world, 120)
	_place_next(world, "wall")
	_place_next(world, "aura_orb")
	_set_stone(world, 120)
	await _commit_sign(world, "build high when wings come")
	await _inject_plan(world, ["build_storm_rod"], "Build anti-flying defense.")
	world.call("_advance_debug_daytime", 12.0)
	_assert(world.get("storm_rods").size() > 0, "enough stone wing plan should build a Storm Rod through Ari's body")
	_finish_pass("wing_enough_stone_builds_storm_rod", before)
	await _free_world(world)


func _pass_storm_then_tower_support() -> void:
	var before := failures.size()
	var world: World = await _make_world()
	_set_stone(world, 160)
	_place_next(world, "wall")
	_place_next(world, "aura_orb")
	_set_stone(world, 160)
	await _commit_sign(world, "build high when wings come")
	await _inject_plan(world, ["build_storm_rod", "build_tower", "use_tower"], "Storm first, then height.")
	world.call("_advance_debug_daytime", 32.0)
	_assert(world.get("storm_rods").size() > 0, "storm/tower plan should build Storm Rod first")
	_assert(world.get("bow_towers").size() > 0, "storm/tower plan should add tower support after Storm Rod")
	_finish_pass("storm_then_tower_support", before)
	await _free_world(world)


func _pass_true_body_plan_mismatch() -> void:
	var before := failures.size()
	var world: World = await _make_world()
	_set_stone(world, 120)
	_place_next(world, "aura_orb")
	_place_next(world, "bow_tower")
	await _commit_sign(world, "make the circle eat them")
	await _inject_plan(world, ["lure_to_aura"], "Use the light.")
	var trace: Dictionary = world.call("_build_body_alignment_trace", {"job": "use_tower", "reason": "Went to the perch instead."}, world.call("_get_ari_mind_context"))
	_assert(trace.get("relation", "") == "mismatch", "tower use should be true mismatch when plan expects aura lure and both are feasible")
	var memory = world.get("ari_memory")
	memory.call("record_snapshot", world.call("_build_observer_snapshot", "scenario_mismatch", 0.75, []))
	var summary: Dictionary = world.call("_build_day_summary", "scenario", "in_progress")
	_assert(summary.get("plan_mismatches", []).size() >= 1, "day summary should preserve true mismatches")
	_finish_pass("true_body_plan_mismatch", before)
	await _free_world(world)


func _pass_safety_substitution_under_danger() -> void:
	var before := failures.size()
	var world: World = await _make_world()
	await _commit_sign(world, "build high when wings come")
	_spawn_flying(world)
	await _inject_plan(world, ["build_storm_rod"], "Build anti-flying defense.")
	var trace: Dictionary = world.call("_build_body_alignment_trace", {"job": "flee", "reason": "Immediate danger is too close."}, world.call("_get_ari_mind_context"))
	_assert(trace.get("relation", "") == "safety_substitution", "fleeing under danger should be safety substitution, not mismatch")
	var memory = world.get("ari_memory")
	memory.call("record_snapshot", world.call("_build_observer_snapshot", "scenario_safety", 0.8, []))
	var summary: Dictionary = world.call("_build_day_summary", "scenario", "in_progress")
	_assert(summary.get("safety_substitutions", []).size() >= 1, "day summary should preserve safety substitutions separately")
	_finish_pass("safety_substitution_under_danger", before)
	await _free_world(world)


func _pass_empty_sign_fallback() -> void:
	var before := failures.size()
	var world: World = await _make_world()
	await _commit_sign(world, "")
	world.call("_refresh_ari_understanding", "empty")
	var packet: Dictionary = world.get("ari_understanding")
	_assert(packet.get("schema", "") == "ari.understanding.v1", "empty sign should still produce deterministic understanding packet")
	_assert(str(packet.get("sign_thesis", "")).to_lower().contains("no sign"), "empty sign thesis should explain fallback caution")
	_assert(not str(packet.get("sign_thesis", "")).to_lower().contains("wing"), "empty sign should not invent wing danger")
	_assert_concrete_legal_answers(packet)
	_finish_pass("empty_sign_fallback", before)
	await _free_world(world)


func _pass_vague_sign_fallback() -> void:
	var before := failures.size()
	var world: World = await _make_world()
	await _commit_sign(world, "the room remembers my fear")
	world.call("_refresh_ari_understanding", "vague")
	var packet: Dictionary = world.get("ari_understanding")
	_assert(packet.get("schema", "") == "ari.understanding.v1", "vague sign should produce deterministic understanding packet")
	_assert(not str(packet.get("sign_thesis", "")).to_lower().contains("wing"), "vague non-wing sign should not become sky danger")
	_assert(world.call("_build_agent_plan_payload", "vague").get("strategy_packet", {}).get("understanding", {}).get("schema", "") == "ari.understanding.v1", "vague sign planner payload should still carry understanding")
	_assert_concrete_legal_answers(packet)
	_finish_pass("vague_sign_fallback", before)
	await _free_world(world)


func _pass_direct_combat_safety_pressure() -> void:
	var before := failures.size()
	var world: World = await _make_world()
	_set_stone(world, 80)
	_place_next(world, "wall")
	await _commit_sign(world, "do not hide, kill them")
	_spawn_enemy(world, "runner")
	var ari = world.get("ari")
	if ari != null:
		ari.set("hp", 20.0)
	await _inject_plan(world, ["fight_head_on"], "The sign wants direct combat.")
	world.call("_advance_ari_daytime", 0.25)
	var alignment: Dictionary = world.get("_latest_body_alignment")
	_assert(alignment.get("relation", "") == "safety_substitution", "low HP direct-combat sign should allow safety substitution")
	_assert(["use_cover", "flee", "stall_until_dawn", "hide_until_dawn", "rest"].has(str(alignment.get("body_action", ""))), "direct-combat safety substitution should be a defensive body action")
	_finish_pass("direct_combat_safety_pressure", before)
	await _free_world(world)


func _pass_flying_reflection_becomes_doctrine() -> void:
	var before := failures.size()
	var world: World = await _make_world()
	await _commit_sign(world, "build high when wings come")
	_spawn_flying(world)
	var memory = world.get("ari_memory")
	var chronicle = world.get("chronicle")
	memory.call("record_snapshot", {
		"schema": "ari.observer.snapshot.v1",
		"snapshot_id": "scenario_flying_reflection",
		"day": 2,
		"phase": "night",
		"trigger": "enemy_spawned",
		"ari": {"current_action": "repair_structure", "current_reason": "patched ground cover"},
		"plan": {"next_action": "build_storm_rod"},
		"world": {
			"resources": {"stone": 1},
			"enemies": {"count": 1, "types": {"flying": 1}},
			"nearest_danger": {"type": "flying", "distance": 44.0},
			"notable_changes": ["first_flying_enemy_seen"],
		},
		"salience": 0.9,
	})
	chronicle.call("add_scribe_note", {
		"note": "Ari saw flying danger and ordinary walls were not enough.",
		"tags": ["danger:flying", "plan_body_mismatch"],
		"facts": ["Flying enemies were present; ordinary walls may not solve them."],
		"actions": [{"action": "repair_structure", "status": "in_progress", "reason": "Ari patched ground cover."}],
		"dangers": [{"type": "flying", "distance": 44.0, "severity": 0.9}],
		"world_changes": ["first_flying_enemy_seen", "plan_body_mismatch"],
		"priority_hints": {"build_storm_rod": 0.8},
		"plan_alignment": "mismatch",
		"lesson_candidates": ["when wings appear, answer the sky first"],
		"salience": 0.9,
	})
	var payload: Dictionary = world.call("_build_night_reflection_payload", "dawn_survived", "survived")
	var bridge: AIBridge = world.get("ai_bridge")
	var reflection: Dictionary = bridge.call("_validated_fallback", "library_reflection", payload)
	world.call("_handle_night_reflection_response", reflection, "dawn_survived")
	var doctrines: Array = world.get("ari_doctrine").call("get_all_doctrines")
	_assert(_array_has_dictionary_value(doctrines, "id", "local_flying_requires_sky_answer"), "flying reflection should install sky-answer doctrine")
	var planner_payload: Dictionary = world.call("_build_agent_plan_payload", "night_reflection")
	_assert(str(planner_payload).contains("build_storm_rod"), "future planner payload should preserve storm-rod doctrine bias")
	_finish_pass("flying_reflection_becomes_doctrine", before)
	await _free_world(world)


func _pass_payload_builders_do_not_mutate_world() -> void:
	var before := failures.size()
	var world: World = await _make_world()
	_set_stone(world, 40)
	await _commit_sign(world, "build high when wings come")
	_spawn_flying(world)
	var state_before := _mutation_state(world)
	world.call("_refresh_ari_understanding", "mutation_check")
	world.call("_build_agent_plan_payload", "mutation_check")
	world.call("_build_fast_prediction_payload")
	world.call("_build_ai_deep_interpretation_payload")
	var state_after := _mutation_state(world)
	_assert(state_after == state_before, "understanding/payload builders should not mutate resources, structures, or enemies")
	_finish_pass("payload_builders_do_not_mutate_world", before)
	await _free_world(world)


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


func _commit_sign(world: World, sign_text: String) -> void:
	world.call("commit_sign", sign_text)
	await process_frame
	if world.has_method("_refresh_ari_understanding"):
		world.call("_refresh_ari_understanding", "scenario")


func _inject_plan(world: World, actions: Array, theory: String) -> void:
	var plan := []
	for index in range(actions.size()):
		var action_id := str(actions[index])
		plan.append({
			"step_id": "scenario_%d_%s" % [index, action_id],
			"action_id": action_id,
			"reason": theory,
			"success": "action_completed",
		})
	var next_action := str(actions[0]) if not actions.is_empty() else "use_cover"
	world.call("_on_agent_plan_response", int(world.get("_agent_plan_request_id")), {
		"ok": true,
		"schema": "ari.agent.plan.v1",
		"goal": "scenario survival",
		"survival_theory": theory,
		"plan": plan,
		"next_action": {"action_id": next_action, "urgency": 0.95, "reason": theory},
		"fallback_action": {"action_id": "use_cover", "urgency": 0.4, "reason": "Use safety if blocked."},
		"belief_updates": [],
		"thought": "Scenario plan.",
		"confidence": 0.85,
		"replan_after_seconds": 30.0,
	})
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


func _place_next(world: World, build_type: String) -> void:
	var slot: Dictionary = world.call("_get_next_build_slot", build_type)
	_assert(slot.has("cell"), "scenario should find build slot for %s" % build_type)
	if slot.has("cell"):
		_assert(bool(world.call("_place_structure_at_cell", build_type, slot["cell"])), "scenario should place %s" % build_type)


func _spawn_flying(world: World) -> void:
	_spawn_enemy(world, "flying")


func _spawn_enemy(world: World, enemy_type: String) -> void:
	var arena: Rect2 = world.call("get_arena_rect")
	world.call("_spawn_enemy", arena.get_center() + Vector2(180.0, -60.0), enemy_type)


func _capture_state(world: World) -> Dictionary:
	var seen := {"state": {}}
	world.state_changed.connect(func(state: Dictionary) -> void:
		seen["state"] = state
	, CONNECT_ONE_SHOT)
	world.call("_emit_state")
	await process_frame
	return seen.get("state", {}) if typeof(seen.get("state", {})) == TYPE_DICTIONARY else {}


func _mutation_state(world: World) -> Dictionary:
	return {
		"stone": int(world.call("_stone_count")),
		"food": int(world.call("_food_count")),
		"ore": int(world.call("_ore_count")),
		"structures": world.get("structures").size(),
		"storm_rods": world.get("storm_rods").size(),
		"towers": world.get("bow_towers").size(),
		"enemies": world.get("enemies").size(),
	}


func _assert_concrete_legal_answers(packet: Dictionary) -> void:
	var forbidden := {
		"anti_flying": true,
		"anti_air_defense": true,
		"sky_answer": true,
		"survive_until_morning": true,
		"fight": true,
	}
	var legal_answers = packet.get("legal_answers", [])
	_assert(typeof(legal_answers) == TYPE_ARRAY and not legal_answers.is_empty(), "understanding packet should expose legal answers")
	for answer in legal_answers:
		if typeof(answer) != TYPE_DICTIONARY:
			_assert(false, "legal answer entries should be dictionaries")
			continue
		var action_id := str(answer.get("action_id", "")).strip_edges()
		_assert(action_id != "", "legal answer should name an action id")
		_assert(not forbidden.has(action_id), "legal answer should not expose abstract/non-executable action id %s" % action_id)


func _finish_pass(name: String, failure_count_before: int) -> void:
	if failures.size() == failure_count_before:
		passes.append(name)
		print("ARI_UNDERSTANDING_GAMEPLAY_PASS %02d %s" % [passes.size(), name])


func _array_has_dictionary_value(items, key: String, expected: String) -> bool:
	if typeof(items) != TYPE_ARRAY:
		return false
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and str(item.get(key, "")) == expected:
			return true
	return false


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
