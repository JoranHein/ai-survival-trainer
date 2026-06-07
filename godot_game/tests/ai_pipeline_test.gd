extends SceneTree

const AIBridgeScript = preload("res://scripts/autoload/AIBridge.gd")
const AriDoctrineScript = preload("res://scripts/ari/AriDoctrine.gd")
const AriMemoryScript = preload("res://scripts/ari/AriMemory.gd")
const ChronicleScript = preload("res://scripts/ari/Chronicle.gd")
const ScribeSystemScript = preload("res://scripts/ari/ScribeSystem.gd")
const ReflectionSystemScript = preload("res://scripts/ari/ReflectionSystem.gd")
const LessonBookScript = preload("res://scripts/ari/LessonBook.gd")
const SleepConsolidationScript = preload("res://scripts/ari/SleepConsolidation.gd")
const LifeArchiveScript = preload("res://scripts/ari/LifeArchive.gd")
const PermanentInsightBookScript = preload("res://scripts/ari/PermanentInsightBook.gd")
const WisdomSynthesizerScript = preload("res://scripts/ari/WisdomSynthesizer.gd")
const AriControllerScript = preload("res://scripts/ari/AriController.gd")
const AriMindScript = preload("res://scripts/ari/AriMind.gd")
const AriPerceptionScript = preload("res://scripts/ari/AriPerception.gd")
const AriRulebookScript = preload("res://scripts/ari/AriRulebook.gd")
const SignMindScript = preload("res://scripts/ari/SignMind.gd")
const RunBuildScript = preload("res://scripts/ari/RunBuild.gd")
const EnemyControllerScript = preload("res://scripts/enemies/EnemyController.gd")
const DayNightCycleScript = preload("res://scripts/world/DayNightCycle.gd")
const WaveDirectorScript = preload("res://scripts/world/WaveDirector.gd")
const ResourceSystemScript = preload("res://scripts/world/ResourceSystem.gd")
const MineNodeScript = preload("res://scripts/stations/MineNode.gd")
const WorldScript = preload("res://scripts/world/World.gd")
const SignPanelScene = preload("res://scenes/ui/SignPanel.tscn")
const HUDScene = preload("res://scenes/ui/HUD.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var bridge: AIBridge = AIBridgeScript.new()
	root.add_child(bridge)
	bridge.force_provider_mode("local_stub")

	await _test_bridge_health_and_raw_validation(bridge)
	_test_ai_bridge_endpoint_specific_timeouts(bridge)
	_test_deep_interpretation_contract(bridge)
	_test_agent_plan_contract(bridge)
	_test_agent_plan_doctrine_prerequisite_guard(bridge)
	_test_ari_doctrine_conditional_bias()
	_test_ari_doctrine_deduplicates_repeated_lessons()
	_test_ari_doctrine_outcome_feedback()
	_test_doctrine_fields_preserved_in_memory_pipeline()
	await _test_no_random_trait_runtime_contract()
	await _test_rulebook_perception_payload_contract()
	await _test_night_affordances_exclude_day_only_jobs()
	await _test_agent_planner_legal_actions_exclude_abstract_hints()
	await _test_action_control_panel_explains_legal_actions()
	await _test_prediction_legal_actions_explain_blocked_actions()
	await _test_fast_prediction_payload_stays_live_sized()
	await _test_fast_prediction_waits_for_due_agent_plan()
	await _test_observer_snapshot_uses_concrete_fallback_plan_action()
	await _test_night_agent_eat_food_plan_executes()
	await _test_agent_planner_withholds_eat_food_during_active_danger()
	await _test_world_agent_plan_state_contract()
	await _test_agent_plan_outcomes_feed_next_observation()
	await _test_agent_plan_out_of_order_completion_does_not_skip_prerequisite()
	await _test_reflection_doctrine_overrides_unsafe_local_sign_fallback()
	await _test_reflection_doctrine_advances_after_storm_exists()
	await _test_plain_night_reflection_does_not_force_agent_plan()
	await _test_doctrine_night_reflection_requests_agent_plan()
	await _test_gateway_fallback_reflection_doctrine_is_not_discarded()
	await _test_repeated_doctrine_reflection_does_not_force_agent_plan()
	await _test_agent_plan_abandons_contradicted_step()
	await _test_sign_commit_defers_agent_plan_while_deep_interpretation_runs()
	await _test_deep_interpretation_requests_do_not_overlap()
	await _test_agent_plan_replan_timer_skips_unchanged_context()
	await _test_agent_plan_replan_timer_requests_new_plan()
	await _test_agent_plan_requests_do_not_overlap()
	await _test_noncritical_agent_plan_waits_while_fast_prediction_in_flight()
	await _test_agent_plan_noncritical_queued_triggers_wait_for_cooldown()
	await _test_agent_plan_same_day_midday_phase_skips_unchanged_context()
	await _test_agent_plan_safe_phase_skip_does_not_resurface_as_timer()
	await _test_agent_plan_safe_daytime_hold_phase_skips_day_rollover()
	await _test_agent_plan_safe_daytime_hold_phase_respects_material_change()
	await _test_agent_plan_ready_dusk_phase_skips_unchanged_context()
	await _test_agent_plan_unready_dusk_phase_stays_critical()
	await _test_agent_plan_dusk_requires_unsatisfied_doctrine_defense()
	await _test_agent_plan_ready_night_hold_skips_unchanged_context()
	await _test_agent_plan_ready_night_hold_ignores_resource_only_drift()
	await _test_agent_plan_ready_night_cover_hold_skips_quiet_phase()
	await _test_agent_plan_unready_night_phase_stays_critical()
	await _test_agent_plan_safe_phase_changes_wait_for_cooldown()
	await _test_agent_plan_night_phase_change_bypasses_cooldown()
	await _test_agent_plan_critical_queued_triggers_bypass_cooldown()
	await _test_agent_plan_anti_air_structure_built_bypasses_cooldown()
	await _test_agent_plan_minor_structure_destroyed_waits_for_cooldown()
	_test_ai_latency_cache_v1_contract(bridge)
	await _test_world_ai_latency_commit_contract()
	await _test_sign_panel_ai_status_line()
	await _test_hud_enemy_counter_is_readable()
	_test_local_combat_signs()
	_test_local_tower_range_signs()
	_test_local_flying_storm_signs()
	_test_farming_hunger_rest_behavior()
	_test_library_reflection_v1_contract()
	_test_permanent_upgrades_v1_contract()
	_test_enemy_variety_stats()
	_test_wave_director_escalates_with_flying()
	_test_day_night_balance_v1_targets()
	await _test_day_night_balance_v1_multiday_simulation()
	await _test_combat_survival_balance_v1_scenarios()
	await _test_survival_strategy_expansion_v1_contract(bridge)
	_test_ai_tactical_priority_jobs()
	_test_memory_records_events()
	_test_chronicle_validates_scribe_notes()
	await _test_scribe_pipeline(bridge)
	_test_local_scribe_keeps_recent_salient_flying_snapshot(bridge)
	_test_local_scribe_preserves_recent_flying_hints_when_latest_snapshot_differs(bridge)
	await _test_reflection_and_sleep_pipeline(bridge)
	await _test_life_and_wisdom_pipeline(bridge)

	if failures.is_empty():
		print("AI pipeline tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _array_has_dictionary_value(items, key: String, expected: String) -> bool:
	if typeof(items) != TYPE_ARRAY:
		return false
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and str(item.get(key, "")) == expected:
			return true
	return false


func _find_dictionary_by_value(items, key: String, expected: String) -> Dictionary:
	if typeof(items) != TYPE_ARRAY:
		return {}
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and str(item.get(key, "")) == expected:
			return item
	return {}


func _http_request_child_count(node: Node) -> int:
	if node == null:
		return 0
	var count := 0
	for child in node.get_children():
		if child is HTTPRequest:
			count += 1
	return count


func _test_ai_bridge_endpoint_specific_timeouts(bridge: AIBridge) -> void:
	_assert(bridge.has_method("_timeout_for_kind"), "AIBridge should expose endpoint-specific timeout lookup for tests")
	if not bridge.has_method("_timeout_for_kind"):
		return
	var config: Dictionary = bridge.get("config")
	config["timeout_seconds"] = 5.0
	config["fast_prediction_timeout_seconds"] = 4.8
	config["background_timeout_seconds"] = 4.0
	config["library_reflection_timeout_seconds"] = 12.0
	config["agent_plan_timeout_seconds"] = 5.0
	bridge.set("config", config)
	_assert(absf(float(bridge.call("_timeout_for_kind", "fast_prediction")) - 4.8) < 0.01, "fast prediction should keep a live sub-5s timeout")
	_assert(absf(float(bridge.call("_timeout_for_kind", "background_job")) - 4.0) < 0.01, "background jobs should use a short stale-safe timeout")
	_assert(absf(float(bridge.call("_timeout_for_kind", "library_reflection")) - 12.0) < 0.01, "library reflection should get a slower async timeout")
	_assert(absf(float(bridge.call("_timeout_for_kind", "agent_plan")) - 5.0) < 0.01, "agent planning should keep the gameplay timeout")


func _array_text_contains(items, fragment: String) -> bool:
	if typeof(items) != TYPE_ARRAY:
		return false
	var needle := fragment.to_lower()
	for item in items:
		if str(item).to_lower().contains(needle):
			return true
	return false


func _test_night_affordances_exclude_day_only_jobs() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for night affordance checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var day_night = world.get("day_night")
	if day_night != null:
		day_night.set("phase", "night")
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("add_stone", 60)
		resource_system.call("add_ore", 60)
	var affordances: Array = world.call("_current_affordances")
	for action_id in ["mine_stone", "mine_ore", "build_wall", "build_tower", "build_storm_rod", "train_sword", "train_combat", "farm_food", "rest", "repair"]:
		_assert(not _affordance_available(affordances, action_id), "night affordances should mark %s unavailable because Ari's body cannot perform day jobs at night" % action_id)
	_assert(_affordance_available(affordances, "flee"), "night affordances should keep flee legal")
	_assert(_affordance_available(affordances, "stall_until_dawn"), "night affordances should keep survival-until-dawn legal")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _affordance_available(items: Array, action_id: String) -> bool:
	for item in items:
		if typeof(item) == TYPE_DICTIONARY and str(item.get("id", "")) == action_id:
			return bool(item.get("available", false))
	return false


func _test_agent_planner_legal_actions_exclude_abstract_hints() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for agent planner legal action checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("add_stone", 60)
	var affordances: Array = world.call("_current_affordances")
	_assert(_array_has_dictionary_value(affordances, "id", "anti_flying"), "current affordances should keep anti_flying as interpretation vocabulary")
	_assert(_array_has_dictionary_value(affordances, "id", "sky_answer"), "current affordances should keep sky_answer as interpretation vocabulary")
	var payload: Dictionary = world.call("_build_agent_plan_payload", "sign_commit")
	var legal_actions: Array = payload.get("legal_actions", [])
	_assert(_array_has_dictionary_value(legal_actions, "id", "build_storm_rod"), "agent planner legal actions should keep concrete Storm Rod work when available")
	for abstract_action_id in [
		"anti_flying",
		"sky_answer",
		"use_armor",
		"rely_on_regen",
		"regen_on_kill",
		"use_existing_wall",
		"wait_behind_wall",
		"hide",
		"kite",
		"fight",
		"prepare_weapon",
		"train_bow",
		"ranged_attack",
		"eat",
		"avoid_killing",
		"survive_until_morning",
		"repair",
	]:
		_assert(not _array_has_dictionary_value(legal_actions, "id", abstract_action_id), "agent planner legal actions should not expose abstract/passive %s as an executable step" % abstract_action_id)
	for concrete_action_id in [
		"use_cover",
		"flee",
		"fight_head_on",
		"train_combat",
		"build_tower",
		"eat_food",
		"stall_until_dawn",
		"hide_until_dawn",
		"repair_structure",
	]:
		_assert(_array_has_dictionary_value(legal_actions, "id", concrete_action_id), "agent planner legal actions should keep concrete %s" % concrete_action_id)
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_action_control_panel_explains_legal_actions() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for action control panel checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("add_stone", 60)
	var build_grid = world.get("build_grid")
	if build_grid != null:
		var anchor: Vector2 = world.call("get_arena_rect").get_center()
		world.call("_place_bow_tower_at_cell", build_grid.call("world_to_cell", anchor + Vector2(144.0, -112.0)))
	world.set("sign_priority_hints", {"use_tower": 1.0, "ranged_attack": 0.8})
	var panel: Dictionary = world.call("_build_action_control_panel")
	_assert(panel.get("schema", "") == "ari.action_control_panel.v1", "action control panel should carry a stable schema")
	_assert(panel.has("objective"), "action control panel should explain the control objective")
	_assert(panel.get("engine_owns", []).has("movement"), "action control panel should state that Godot owns movement")
	_assert(panel.get("engine_owns", []).has("resources"), "action control panel should state that Godot owns resources")
	var actions: Array = panel.get("actions", [])
	var storm: Dictionary = _find_dictionary_by_value(actions, "id", "build_storm_rod")
	_assert(not storm.is_empty(), "action control panel should include concrete storm rod action")
	_assert(bool(storm.get("available", false)), "storm rod should be available after adding enough stone")
	_assert(str(storm.get("description", "")).to_lower().contains("flying"), "storm rod panel entry should explain anti-flying purpose")
	_assert(str(storm.get("category", "")) == "build", "storm rod panel entry should expose action category")
	_assert(storm.get("counters", []).has("flying"), "storm rod panel entry should expose what it counters")
	_assert(storm.get("preconditions", []).has("daytime_building"), "storm rod panel entry should expose deterministic build preconditions")
	_assert(storm.get("good_when", []).has("flying_enemy_seen"), "storm rod panel entry should expose when the action is strategically useful")
	var tower: Dictionary = _find_dictionary_by_value(actions, "id", "use_tower")
	_assert(not tower.is_empty(), "action control panel should include concrete tower-use action")
	_assert(tower.get("preconditions", []).has("living_bow_tower"), "tower-use panel entry should expose that the body needs an existing tower")
	_assert(tower.get("failure_modes", []).has("brute_or_runner_can_destroy_support"), "tower-use panel entry should warn that tower plans need support against structure pressure")
	var tar: Dictionary = _find_dictionary_by_value(actions, "id", "build_tar_pit")
	_assert(not tar.is_empty(), "action control panel should include concrete tar pit action")
	_assert(tar.get("good_when", []).has("brute_or_runner_pressure"), "tar pit panel entry should expose slow-ground tactical value")
	_assert(tar.get("enables", []).has("lure_to_tar_pit"), "tar pit panel entry should expose the follow-up action it enables")
	var payload: Dictionary = world.call("_build_agent_plan_payload", "sign_commit")
	_assert(payload.has("action_control_panel"), "agent planner payload should include action control panel")
	var prediction_payload: Dictionary = world.call("_build_fast_prediction_payload")
	_assert(prediction_payload.has("action_control_panel"), "fast prediction payload should include action control panel")
	var prediction_panel: Dictionary = prediction_payload.get("action_control_panel", {})
	_assert(prediction_panel.get("actions", []).size() <= 14, "fast prediction action control panel should stay compact")
	var compact_tower: Dictionary = _find_dictionary_by_value(prediction_panel.get("actions", []), "id", "use_tower")
	_assert(compact_tower.get("failure_modes", []).has("brute_or_runner_can_destroy_support"), "fast prediction compact panel should keep tower failure-mode facts")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_prediction_legal_actions_explain_blocked_actions() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for blocked prediction action checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.set("stone", 0)
	var legal_actions: Array = world.call("_current_agent_legal_actions_prediction_compact", 50)
	var storm: Dictionary = _find_dictionary_by_value(legal_actions, "id", "build_storm_rod")
	_assert(not storm.is_empty(), "prediction legal actions should include blocked storm rod as an option the model can reason about")
	_assert(not bool(storm.get("available", true)), "storm rod should be blocked without enough stone")
	_assert(str(storm.get("reason_unavailable", "")).contains("stone"), "blocked storm rod prediction action should carry the blocker reason")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_fast_prediction_payload_stays_live_sized() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for fast prediction payload checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("add_stone", 80)
	var chronicle = world.get("chronicle")
	if chronicle != null:
		for index in range(8):
			chronicle.call("add_scribe_note", {
				"note": "Ari noticed flying pressure, damaged cover, and a plan mismatch near the tower.",
				"facts": ["Flying enemies were present; ordinary walls may not solve them.", "The tower plan needed repair support."],
				"actions": [{"action": "build_wall", "status": "mismatch", "reason": "ordinary cover did not answer wings"}],
				"dangers": [{"type": "flying", "distance": 96.0 - float(index), "severity": 0.9}],
				"world_changes": ["first_flying_enemy_seen", "north_wall_damaged"],
				"priority_hints": {"build_storm_rod": 0.8, "use_tower": 0.5},
				"plan_alignment": "mismatch",
				"immediate_risk": "high",
				"risk_reason": "Flying enemies can bypass ordinary wall safety.",
				"resource_blockers": ["low stone before storm support"],
				"mistake_candidates": ["ordinary wall thinking did not answer wings"],
				"opportunity_candidates": ["build storm rod before ordinary wall work"],
				"lesson_candidates": ["when wings appear, answer the sky first"],
				"confidence": 0.8,
				"salience": 0.9,
			})
	var ari_memory = world.get("ari_memory")
	if ari_memory != null:
		for index in range(12):
			ari_memory.call("record_event", "structure_damaged", {
				"phase": "night",
				"structure_type": "bow_tower",
				"damage": 6 + index,
				"action_id": "repair_structure",
			})
			ari_memory.call("record_snapshot", {
				"schema": "ari.observer.snapshot.v1",
				"snapshot_id": "payload_size_%02d" % index,
				"trigger": "timer",
				"phase": "night",
				"ari": {"current_action": "build_wall", "current_reason": "flying pressure near tower"},
				"plan": {"next_action": "build_storm_rod"},
				"world": {
					"enemies": {"count": 1, "types": {"flying": 1}},
					"nearest_danger": {"type": "flying", "distance": 96.0},
					"notable_changes": ["first_flying_enemy_seen", "north_wall_damaged"],
				},
				"salience": 0.9,
			})
	world.set("agent_plan", {
		"goal": "survive_next_night",
		"survival_theory": "Use storm and tower support before trusting ordinary walls.",
		"next_action": {"action_id": "build_storm_rod", "reason": "Wings need a sky answer."},
		"plan": [
			{"step_id": "storm", "action_id": "build_storm_rod", "reason": "Build anti-air first.", "success": "storm_rod_built"},
			{"step_id": "tower", "action_id": "build_tower", "reason": "Add tower support.", "success": "tower_built"},
		],
		"failures": [
			{"action_id": "build_wall", "reason": "ordinary wall did not answer flying"},
			{"action_id": "repair_structure", "reason": "repair started too late"},
		],
		"outcomes": [
			{"action_id": "build_storm_rod", "outcome": "planned"},
			{"action_id": "use_tower", "outcome": "worked"},
		],
		"source": "remote_server",
	})
	var payload: Dictionary = world.call("_build_fast_prediction_payload")
	var payload_bytes := JSON.stringify(payload).length()
	_assert(payload_bytes <= 5000, "fast prediction payload should stay <=5KB for live tiny-model requests, got %d bytes" % payload_bytes)
	var plan_payload: Dictionary = world.call("_build_agent_plan_payload", "payload_size_test")
	var plan_payload_bytes := JSON.stringify(plan_payload).length()
	_assert(plan_payload_bytes <= 15000, "agent plan payload should stay <=15KB for planner requests, got %d bytes" % plan_payload_bytes)
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_fast_prediction_waits_for_due_agent_plan() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for fast prediction/planner fairness checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["fast_prediction_timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "build high when wings come")
	world.set("_agent_plan_clock", 29.9)
	world.set("_agent_plan_pending_trigger", "structure_built")
	world.set("_agent_plan_pending_at", 30.0)
	world.set("_fast_prediction_elapsed", 5.0)
	var prediction_id := int(world.get("_fast_prediction_request_id"))
	world.call("_advance_fast_prediction", 0.0)
	_assert(int(world.get("_fast_prediction_request_id")) == prediction_id, "fast prediction should not start when a queued planner request is due soon")
	world.set("_agent_plan_pending_trigger", "")
	world.set("_agent_plan_pending_at", 0.0)
	world.call("_advance_fast_prediction", 0.0)
	_assert(int(world.get("_fast_prediction_request_id")) == prediction_id + 1, "fast prediction should start normally when no due planner work is waiting")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_observer_snapshot_uses_concrete_fallback_plan_action() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for observer fallback plan checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("add_stone", 60)
	world.set("sign_grounded_plan", [{
		"affordance_id": "train_bow",
		"priority": 0.95,
		"reason": "The sign asks Ari to practice bow safety.",
	}])
	var snapshot: Dictionary = world.call("_build_observer_snapshot", "timer", 0.1, [])
	var plan: Dictionary = snapshot.get("plan", {})
	_assert(plan.get("next_action", "") == "build_tower", "observer fallback plan should translate train_bow into concrete build_tower when no tower exists")
	_assert(plan.get("next_action", "") != "train_bow", "observer fallback plan should not expose semantic train_bow as Ari's executable next action")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_night_agent_eat_food_plan_executes() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for night eat_food plan checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")
	var day_night = world.get("day_night")
	if day_night != null:
		day_night.set("phase", "night")
		day_night.set("_phase_index", 3)
		day_night.set("phase_elapsed", 0.0)
	var resource_system = world.get("resource_system")
	var food_before := 0
	if resource_system != null:
		food_before = int(resource_system.call("get_food"))
		if food_before <= 0:
			resource_system.call("add_food", 1)
			food_before = int(resource_system.call("get_food"))
	var ari = world.get("ari")
	if ari != null:
		ari.set("hunger", 80.0)
	world.set("agent_grounded_plan", [{
		"affordance_id": "eat_food",
		"priority": 0.95,
		"reason": "Night food keeps Ari alive.",
		"source": "agent",
	}])
	var decision: Dictionary = world.get("ari_mind").call("choose_night_tactic", world.call("_get_night_tactic_context"))
	_assert(decision.get("job", "") == "eat_food", "quiet-night agent eat_food plans should become Ari's night tactic when food exists")
	world.call("_advance_ari_night_tactic", 0.1)
	if resource_system != null:
		_assert(int(resource_system.call("get_food")) == food_before - 1, "night eat_food plans should spend stored food instead of idling")
	if ari != null:
		_assert(float(ari.get("hunger")) < 80.0, "night eat_food plans should reduce hunger pressure")
		_assert(str(ari.call("get_current_job")) == "eat_food", "night eat_food plans should expose the executed job for observer snapshots")
		_assert(str(ari.call("get_current_action")).to_lower().contains("eating"), "night eat_food plans should expose an eating action for scribe notes")
	var events: Array = world.get("ari_memory").get_recent_events(8)
	_assert(_array_has_dictionary_value(events, "type", "food_eaten"), "night eat_food plans should record a food_eaten memory event")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_planner_withholds_eat_food_during_active_danger() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for active-danger eat_food gating")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var day_night = world.get("day_night")
	if day_night != null:
		day_night.set("phase", "night")
		day_night.set("_phase_index", 3)
		day_night.set("phase_elapsed", 0.0)
	var resource_system = world.get("resource_system")
	if resource_system != null and int(resource_system.call("get_food")) <= 0:
		resource_system.call("add_food", 2)
	var quiet_payload: Dictionary = world.call("_build_agent_plan_payload", "night_quiet_test")
	_assert(_array_has_dictionary_value(quiet_payload.get("legal_actions", []), "id", "eat_food"), "planner should still see eat_food during quiet night when food exists")
	var arena: Rect2 = world.call("get_arena_rect")
	world.call("_spawn_enemy", arena.get_center() + Vector2(120.0, 0.0), "zombie")
	await process_frame
	var danger_payload: Dictionary = world.call("_build_agent_plan_payload", "night_danger_test")
	_assert(not _array_has_dictionary_value(danger_payload.get("legal_actions", []), "id", "eat_food"), "planner should not choose eat_food while active enemies need body-safe actions")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_bridge_health_and_raw_validation(bridge: AIBridge) -> void:
	var health_state := {"done": false}
	bridge.request_health(func(result: Dictionary) -> void:
		_assert(result.get("ok", false), "local_stub health should be available without a server")
		_assert(result.get("provider_mode", "") == "local_stub", "local_stub health should report local_stub")
		health_state["done"] = true
	)

	var valid_body := JSON.stringify({"raw": JSON.stringify({"note": "Remote note", "tags": ["remote"], "salience": 2.0})}).to_utf8_buffer()
	var parsed := bridge._parse_remote_response("scribe", {}, HTTPRequest.RESULT_SUCCESS, 200, valid_body)
	_assert(parsed.get("note", "") == "Remote note", "remote raw JSON should parse through the raw field")
	_assert(parsed.get("salience", 0.0) == 1.0, "remote scribe salience should be clamped")

	var invalid_body := JSON.stringify({"raw": "not json"}).to_utf8_buffer()
	var fallback := bridge._parse_remote_response("scribe", {"recent_events": [{"type": "enemy_spawned"}], "ari": {"fear": 90}}, HTTPRequest.RESULT_SUCCESS, 200, invalid_body)
	_assert(fallback.get("note", "").contains("enemy spawned"), "invalid remote raw JSON should fall back to readable local_stub note")
	_assert(fallback.get("tags", []).has("fear_high"), "fallback after invalid raw should still validate local_stub tags")

	await process_frame
	_assert(health_state["done"], "health callback should run in local_stub mode")


func _test_deep_interpretation_contract(bridge: AIBridge) -> void:
	var long_interpretation := ""
	var long_thought := ""
	for _i in range(300):
		long_interpretation += "x"
	for _j in range(220):
		long_thought += "y"

	var payload := {
		"local_fallback": {
			"interpretation": "Fallback wall reading",
			"priority_hints": {
				"wall": 0.4,
				"defensive_wait": 0.2,
			},
			"sign_strength": 0.3,
			"resonance": 0.2,
		},
	}
	var response := bridge._validate_deep_interpretation({
		"interpretation": long_interpretation,
		"thought": long_thought,
		"survival_theory": "cover",
		"emotion": "focused fear",
		"grounded_plan": [
			{
				"affordance_id": "use_existing_wall",
				"priority": 2.0,
				"reason": "The wall already exists, so cover matters more than building.",
			},
			{
				"affordance_id": "build_storm_rod",
				"priority": "0.8",
				"reason": "Wings need a sky answer.",
			},
			{
				"affordance_id": "unknown_spell",
				"priority": 1.0,
				"reason": "Unknown model affordances should be ignored.",
			},
		],
		"priority_hints": {
			"build_wall": 2.0,
			"wait_behind_wall": "0.7",
			"lure_to_aura": 0.8,
			"repair": 0.4,
			"kite": 1.5,
			"prepare_weapon": 0.5,
			"ranged_attack": 2.0,
			"use_tower": 0.9,
			"train_bow": "0.6",
			"eat": 0.3,
			"eat_food": 0.4,
			"build_storm_rod": 0.45,
			"anti_flying": 1.4,
			"sky_answer": 0.8,
			"unknown_key": 1.0,
		},
		"sign_strength": -5.0,
		"resonance": 2.0,
	}, payload, true, "remote_server")

	_assert(response.get("ok", false), "deep interpretation should report successful remote validation")
	_assert(str(response.get("interpretation", "")).length() == 240, "deep interpretation text should be capped")
	_assert(str(response.get("thought", "")).length() == 160, "deep thought text should be capped")
	_assert(response.get("emotion", "") == "focused fear", "deep response should preserve Ari emotion")
	var grounded_plan: Array = response.get("grounded_plan", [])
	_assert(grounded_plan.size() == 2, "deep grounded plan should keep known affordances and ignore unknown ones")
	if grounded_plan.size() >= 2:
		_assert(grounded_plan[0].get("affordance_id", "") == "use_existing_wall", "first grounded plan item should keep affordance id")
		_assert(grounded_plan[0].get("priority", 0.0) == 1.0, "grounded plan priority should be clamped")
		_assert(grounded_plan[1].get("affordance_id", "") == "build_storm_rod", "storm plan item should be preserved")
		_assert(grounded_plan[1].get("priority", 0.0) == 0.8, "grounded plan should accept numeric strings")
	var hints: Dictionary = response.get("priority_hints", {})
	_assert(hints.get("build_wall", 0.0) == 1.0, "deep build_wall hint should be clamped")
	_assert(hints.get("wait_behind_wall", 0.0) == 0.7, "deep wait_behind_wall hint should accept numeric strings")
	_assert(hints.get("lure_to_aura", 0.0) == 0.8, "deep lure_to_aura hint should be preserved")
	_assert(hints.get("repair", 0.0) == 0.4, "deep repair hint should be preserved")
	_assert(hints.get("kite", 0.0) == 1.0, "deep kite hint should be clamped")
	_assert(hints.get("prepare_weapon", 0.0) == 0.5, "deep prepare_weapon hint should be preserved")
	_assert(hints.get("ranged_attack", 0.0) == 1.0, "deep ranged_attack hint should be clamped")
	_assert(hints.get("use_tower", 0.0) == 0.9, "deep use_tower hint should be preserved")
	_assert(hints.get("train_bow", 0.0) == 0.6, "deep train_bow hint should accept numeric strings")
	_assert(hints.get("eat", 0.0) == 0.3, "deep eat hint should be preserved")
	_assert(hints.get("eat_food", 0.0) == 0.4, "deep eat_food hint should be preserved")
	_assert(hints.get("build_storm_rod", 0.0) == 0.8, "deep build_storm_rod hint should include grounded plan priority")
	_assert(hints.get("anti_flying", 0.0) == 1.0, "deep anti_flying hint should be clamped")
	_assert(hints.get("sky_answer", 0.0) == 0.8, "deep sky_answer hint should be preserved")
	_assert(not hints.has("unknown_key"), "deep priority hints should remove unknown keys")
	_assert(response.get("sign_strength", 1.0) == 0.0, "deep sign strength should clamp low values")
	_assert(response.get("resonance", 0.0) == 1.0, "deep resonance should clamp high values")

	var fallback := bridge._deep_fallback(payload, "disabled")
	var fallback_hints: Dictionary = fallback.get("priority_hints", {})
	var fallback_plan: Array = fallback.get("grounded_plan", [])
	_assert(not fallback.get("ok", true), "deep fallback should report unsuccessful remote use")
	_assert(fallback.get("source", "") == "disabled", "deep fallback should preserve source")
	_assert(fallback_hints.get("build_wall", 0.0) == 0.4, "deep fallback should translate local wall hint")
	_assert(fallback_hints.get("wait_or_idle", 0.0) == 0.2, "deep fallback should translate local defensive wait hint")
	_assert(fallback_plan.size() > 0 and fallback_plan[0].get("affordance_id", "") == "build_wall", "deep fallback should expose a grounded plan from local hints")


func _test_agent_plan_contract(bridge: AIBridge) -> void:
	var payload := {
		"legal_actions": [
			{"id": "build_tower", "available": true, "description": "Build tower."},
			{"id": "use_cover", "available": true, "description": "Use cover."},
			{"id": "flee", "available": true, "description": "Move away."},
		],
		"local_fallback": {
			"goal": "survive with local cover",
			"survival_theory": "The wall still buys time.",
			"plan": [{
				"step_id": "fallback_cover",
				"action_id": "use_cover",
				"reason": "A wall exists.",
				"success": "safe_distance",
			}],
			"next_action": {"action_id": "use_cover", "urgency": 0.5},
			"fallback_action": {"action_id": "flee", "urgency": 0.4, "reason": "Distance stays legal."},
			"thought": "I can still use the wall.",
			"confidence": 0.4,
		},
	}
	var valid: Dictionary = bridge.call("_validate_agent_plan", {
		"schema": "ari.agent.plan.v1",
		"goal": "survive with height",
		"survival_theory": "Height buys time.",
		"plan": [{
			"step_id": "build_height",
			"action_id": "build_tower",
			"reason": "The sign asks for arrows above teeth.",
			"success": "bow_tower_count > 0",
		}],
		"next_action": {"action_id": "build_tower", "urgency": 0.9, "reason": "Build the tower first."},
		"fallback_action": {"action_id": "use_cover", "urgency": 0.5, "reason": "Use the wall if tower work fails."},
		"belief_updates": [{"key": "height", "delta": 0.4, "reason": "The sign says arrows."}],
		"thought": "If death has to climb, I get time.",
		"confidence": 0.8,
		"replan_after_seconds": 9.0,
	}, payload, true, "remote_server")
	_assert(valid.get("ok", false), "valid agent plan should report successful validation")
	_assert(valid.get("next_action", {}).get("action_id", "") == "build_tower", "valid agent plan should preserve legal next action")
	_assert(valid.get("plan", [])[0].get("action_id", "") == "build_tower", "valid agent plan should preserve legal plan step")
	_assert(valid.get("belief_updates", [])[0].get("key", "") == "height", "valid agent plan should preserve belief updates")

	var failed: Dictionary = bridge.call("_validate_agent_plan", {
		"schema": "ari.agent.plan.v1",
		"goal": "cheat",
		"plan": [{"step_id": "bad", "action_id": "spawn_dragon", "reason": "illegal", "success": "dragon"}],
		"next_action": {"action_id": "spawn_dragon", "urgency": 1.0},
		"fallback_action": {"action_id": "teleport", "urgency": 1.0},
	}, payload, true, "remote_server")
	_assert(not failed.get("ok", true), "illegal agent plan should fall back")
	_assert(failed.get("next_action", {}).get("action_id", "") == "use_cover", "illegal agent plan should use local fallback next action")
	_assert(failed.get("fallback_action", {}).get("action_id", "") == "flee", "illegal agent plan should preserve legal fallback action")
	_assert(failed.get("failure_reason", "") == "invalid_action", "illegal agent plan should expose invalid action failure reason")

	var tower_payload := payload.duplicate(true)
	tower_payload["sign"] = {"text": "build a mountain where arrows rain", "interpretation": "height and range"}
	tower_payload["world"] = {
		"phase": "night",
		"enemy_count": 3,
		"enemy_type_counts": {"zombie": 2, "brute": 1},
		"bow_tower_count": 1,
	}
	tower_payload["legal_actions"] = [
		{"id": "fight_head_on", "available": true},
		{"id": "use_tower", "available": true},
		{"id": "use_cover", "available": true},
		{"id": "flee", "available": true},
	]
	var guarded_tower: Dictionary = bridge.call("_validate_agent_plan", {
		"schema": "ari.agent.plan.v1",
		"goal": "fight anyway",
		"survival_theory": "Bad remote plan should not override tower safety.",
		"plan": [{"step_id": "bad_melee", "action_id": "fight_head_on", "reason": "Fight directly.", "success": "survive"}],
		"next_action": {"action_id": "fight_head_on", "urgency": 0.8, "reason": "Fight directly."},
		"fallback_action": {"action_id": "flee", "urgency": 0.4},
	}, tower_payload, true, "remote_server")
	_assert(guarded_tower.get("next_action", {}).get("action_id", "") == "use_tower", "AIBridge should rewrite unsupported melee to tower use when the sign and panel support range")
	_assert(guarded_tower.get("plan", [])[0].get("action_id", "") == "use_tower", "AIBridge guarded tower plan should start with tower use")

	var flying_payload := payload.duplicate(true)
	flying_payload["sign"] = {"text": "do not trust walls against wings", "interpretation": "anti air"}
	flying_payload["world"] = {
		"phase": "night",
		"stone": 24,
		"enemy_count": 2,
		"enemy_type_counts": {"flying": 1, "zombie": 1},
		"storm_rod_count": 0,
	}
	flying_payload["legal_actions"] = [
		{"id": "use_cover", "available": true},
		{"id": "build_storm_rod", "available": true},
		{"id": "mine_stone", "available": true},
		{"id": "flee", "available": true},
	]
	var guarded_flying: Dictionary = bridge.call("_validate_agent_plan", {
		"schema": "ari.agent.plan.v1",
		"goal": "hide behind cover",
		"survival_theory": "Bad remote plan treats flying like ground danger.",
		"plan": [{"step_id": "bad_cover", "action_id": "use_cover", "reason": "Use cover.", "success": "survive"}],
		"next_action": {"action_id": "use_cover", "urgency": 0.8, "reason": "Use cover."},
		"fallback_action": {"action_id": "flee", "urgency": 0.4},
	}, flying_payload, true, "remote_server")
	_assert(guarded_flying.get("next_action", {}).get("action_id", "") == "build_storm_rod", "AIBridge should rewrite cover to Storm Rod when flying enemies are present")
	_assert(guarded_flying.get("plan", [])[0].get("action_id", "") == "build_storm_rod", "AIBridge guarded flying plan should start with Storm Rod")


func _test_agent_plan_doctrine_prerequisite_guard(bridge: AIBridge) -> void:
	var payload := {
		"local_fallback": {
			"next_action": {"action_id": "mine_stone", "urgency": 0.55, "reason": "Local fallback gathers stone for missing anti-air."},
			"fallback_action": {"action_id": "use_cover", "urgency": 0.4},
			"plan": [{
				"step_id": "fallback_mine_stone",
				"action_id": "mine_stone",
				"reason": "Gather stone for the missing Storm Rod.",
				"success": "stone_for_storm",
			}],
		},
		"world": {
			"stone": 4,
			"storm_rod_count": 0,
			"bow_tower_count": 1,
		},
		"active_doctrine_plan": [
			{"affordance_id": "build_storm_rod", "priority": 0.85, "reason": "Sky danger needs anti-air."},
			{"affordance_id": "build_tower", "priority": 0.58, "reason": "Add ranged support."},
			{"affordance_id": "use_tower", "priority": 0.48, "reason": "Use range after the sky answer exists."},
		],
		"legal_actions": [
			{"id": "mine_stone", "available": true},
			{"id": "build_storm_rod", "available": false, "reason": "not enough stone"},
			{"id": "use_tower", "available": true},
			{"id": "use_cover", "available": true},
		],
	}
	var guarded: Dictionary = bridge.call("_validate_agent_plan", {
		"schema": "ari.agent.plan.v1",
		"goal": "hold the sky doctrine",
		"survival_theory": "The tower can still fire.",
		"plan": [{
			"step_id": "skip_to_tower",
			"action_id": "use_tower",
			"reason": "Use the tower even though the Storm Rod is gone.",
			"success": "survive",
		}],
		"next_action": {"action_id": "use_tower", "urgency": 0.9, "reason": "Use tower."},
		"fallback_action": {"action_id": "use_cover", "urgency": 0.4},
		"belief_updates": [],
		"thought": "The tower is enough.",
		"confidence": 0.8,
		"replan_after_seconds": 8.0,
	}, payload, true, "remote_server")

	_assert(str(guarded.get("source", "")) == "remote_server", "doctrine prerequisite guard should sanitize remote plans without pretending the server failed")
	_assert(guarded.get("next_action", {}).get("action_id", "") == "mine_stone", "missing unaffordable doctrine structures should force prerequisite resource gathering")
	_assert(guarded.get("plan", [])[0].get("action_id", "") == "mine_stone", "guarded plan should start with the prerequisite resource action")
	_assert(str(guarded.get("next_action", {}).get("reason", "")).to_lower().contains("storm rod"), "guarded prerequisite reason should name the missing doctrine structure")


func _test_ari_doctrine_conditional_bias() -> void:
	var doctrine = AriDoctrineScript.new()
	doctrine.add_doctrine({
		"id": "wings_ignore_walls",
		"when": {"enemy_type_present": "flying"},
		"bias": {
			"build_storm_rod": 0.9,
			"build_wall": -0.7,
		},
		"plan": [{
			"affordance_id": "build_storm_rod",
			"priority": 0.9,
			"reason": "Wings need a sky answer.",
		}],
	})
	var inactive: Dictionary = doctrine.get_active_bias({"enemy_type_counts": {"zombie": 2}})
	_assert(inactive.is_empty(), "flying doctrine should stay inactive without flying enemies")
	var remembered: Dictionary = doctrine.get_active_bias({"enemy_type_counts": {}, "known_enemy_types": ["flying"]})
	_assert(float(remembered.get("build_storm_rod", 0.0)) > 0.0, "flying doctrine should activate after Ari has learned flying enemies exist")
	var active: Dictionary = doctrine.get_active_bias({"enemy_type_counts": {"flying": 1}})
	_assert(float(active.get("build_storm_rod", 0.0)) > 0.0, "flying doctrine should promote storm rod")
	_assert(float(active.get("build_wall", 0.0)) < 0.0, "flying doctrine should downweight walls")
	var plan: Array = doctrine.get_active_plan({"enemy_type_counts": {"flying": 1}})
	_assert(plan.size() > 0 and plan[0].get("affordance_id", "") == "build_storm_rod", "flying doctrine should expose an executable active plan")
	_assert(doctrine.has_method("get_active_doctrines"), "AriDoctrine should expose active doctrine records for planner context")
	if doctrine.has_method("get_active_doctrines"):
		_assert(doctrine.call("get_active_doctrines", {"enemy_type_counts": {"zombie": 2}}).is_empty(), "active doctrine records should stay inactive without matching conditions")
		_assert(doctrine.call("get_active_doctrines", {"enemy_type_counts": {"flying": 1}}).size() == 1, "active doctrine records should include matching learned doctrine")


func _test_ari_doctrine_deduplicates_repeated_lessons() -> void:
	var doctrine = AriDoctrineScript.new()
	var raw := {
		"id": "wings_ignore_walls",
		"when": {"enemy_type_present": "flying"},
		"bias": {"build_storm_rod": 0.45, "build_wall": -0.1},
		"plan": [{"affordance_id": "build_storm_rod", "priority": 0.85}],
		"confidence": 0.85,
	}
	var first := doctrine.add_doctrines([raw])
	var repeated := doctrine.add_doctrines([raw])
	_assert(first.size() == 1, "first doctrine lesson should be accepted")
	_assert(repeated.is_empty(), "repeated identical doctrine lessons should not be re-added")
	_assert(doctrine.get_all_doctrines().size() == 1, "doctrine book should keep one copy of an identical lesson")
	var active_bias := doctrine.get_active_bias({"enemy_type_counts": {"flying": 1}})
	_assert(float(active_bias.get("build_storm_rod", 0.0)) <= 0.45, "duplicate doctrine lessons should not compound priority bias")


func _test_ari_doctrine_outcome_feedback() -> void:
	var doctrine = AriDoctrineScript.new()
	doctrine.add_doctrine({
		"id": "walls_are_enough_for_wings",
		"when": {"enemy_type_present": "flying"},
		"bias": {"build_wall": 0.9},
		"plan": [{
			"affordance_id": "build_wall",
			"priority": 0.9,
			"reason": "A wall should be enough.",
		}],
		"confidence": 0.9,
	})
	var context := {"enemy_type_counts": {"flying": 1}}
	var before: Dictionary = doctrine.get_active_bias(context)
	_assert(float(before.get("build_wall", 0.0)) > 0.7, "fresh doctrine should strongly promote its action")
	_assert(doctrine.has_method("apply_outcome_feedback"), "AriDoctrine should update confidence from action outcomes")
	if doctrine.has_method("apply_outcome_feedback"):
		for _i in range(3):
			doctrine.call("apply_outcome_feedback", {
				"action_id": "build_wall",
				"outcome": "near_death",
				"reason": "Ari was nearly killed while trusting this plan.",
			})
		var after: Dictionary = doctrine.get_active_bias(context)
		_assert(float(after.get("build_wall", 0.0)) < 0.35, "repeated bad outcomes should weaken bad doctrine enough to change future decisions")
		var active: Array = doctrine.call("get_active_doctrines", context)
		_assert(active.size() == 1 and int(active[0].get("failure_count", 0)) >= 3, "weakened doctrine should keep failure evidence for the planner")


func _test_doctrine_fields_preserved_in_memory_pipeline() -> void:
	var doctrine := {
		"id": "wings_ignore_walls",
		"when": {"enemy_type_present": "flying"},
		"bias": {"build_storm_rod": 0.9, "build_wall": -0.7},
		"plan": [{"affordance_id": "build_storm_rod", "priority": 0.9, "reason": "Wings need a sky answer."}],
	}

	var memory = AriMemoryScript.new()
	memory.add_lifetime_note({"title": "Wings", "doctrines": [doctrine]})
	var memory_note: Dictionary = memory.get_latest_lifetime_note()
	var memory_doctrines: Array = memory_note.get("doctrines", [])
	_assert(memory_doctrines.size() == 1, "AriMemory should preserve validated doctrine arrays")
	if memory_doctrines.size() > 0:
		_assert(float(memory_doctrines[0].get("bias", {}).get("build_wall", 0.0)) < 0.0, "AriMemory should preserve negative doctrine bias")

	var lesson_book = LessonBookScript.new()
	lesson_book.add_note({"title": "Wings", "doctrines": [doctrine]})
	var lesson_note: Dictionary = lesson_book.get_latest_note()
	_assert(lesson_note.get("doctrines", []).size() == 1, "LessonBook should preserve validated doctrine arrays")

	var reflection = ReflectionSystemScript.new()
	var reflected: Dictionary = reflection.call("_validate_reflection", {"title": "Wings", "doctrines": [doctrine]})
	_assert(reflected.get("doctrines", []).size() == 1, "ReflectionSystem should preserve doctrine arrays from AI notes")

	var sleep = SleepConsolidationScript.new()
	var plan: Dictionary = sleep.call("_validate_sleep_plan", {"doctrines": [doctrine]})
	_assert(plan.get("doctrines", []).size() == 1, "SleepConsolidation should preserve doctrine arrays")


func _test_no_random_trait_runtime_contract() -> void:
	var removed_state_key := "person" + "ality"
	var removed_summary_key := removed_state_key + "_summary"
	var removed_script_path := "res://scripts/ari/" + "Person" + "ality.gd"
	var removed_node_name := "Person" + "ality"
	_assert(not ResourceLoader.exists(removed_script_path), "Ari random trait script should be removed from the active game")
	var sign_mind: SignMind = SignMindScript.new()
	var neutral := sign_mind.interpret_sign("stand behind the wall")
	var sign_faith_build := sign_mind.interpret_sign("stand behind the wall", {"points": {"sign_faith": 12}})
	_assert(float(sign_faith_build.get("sign_strength", 0.0)) > float(neutral.get("sign_strength", 0.0)), "SignMind should treat its second argument as run_build")
	sign_mind.free()

	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load without the removed trait resource")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	_assert(world.get_node_or_null(removed_node_name) == null, "World scene should not instantiate the removed trait node")
	var seen_state := {"state": {}}
	world.state_changed.connect(func(state: Dictionary) -> void:
		seen_state["state"] = state
	)
	world.call("_emit_state")
	await process_frame
	var state = seen_state.get("state", {})
	if typeof(state) == TYPE_DICTIONARY:
		_assert(not state.has(removed_state_key), "World state should not expose removed random traits")
		_assert(not state.has(removed_summary_key), "World state should not expose removed random trait summary")
	var payload: Dictionary = world.call("_build_ai_deep_interpretation_payload")
	var ari_payload = payload.get("ari", {})
	if typeof(ari_payload) == TYPE_DICTIONARY:
		_assert(not ari_payload.has(removed_state_key), "AIBridge deep payload should not send removed random traits")
	world.queue_free()


func _test_rulebook_perception_payload_contract() -> void:
	var rulebook = AriRulebookScript.new()
	var rules: Dictionary = rulebook.call("get_rulebook")
	_assert(not rules.is_empty(), "Ari rulebook should load a compact rule set")
	_assert(str(rules.get("version", "")).strip_edges() != "", "Ari rulebook should include a version")
	_assert(str(rules).find("origin_year") < 0, "Ari rulebook should not reintroduce origin-year")
	_assert(str(rules).find("stubbornness") < 0, "Ari rulebook should not reintroduce stubbornness")

	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for rulebook/perception payload checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")
	world.call("commit_sign", "attack them around the corner with a bow")
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("add_stone", 40)
	var arena: Rect2 = world.call("get_arena_rect")
	var anchor := arena.get_center()
	var build_grid = world.get("build_grid")
	if build_grid != null:
		world.call("_place_wall_at_cell", build_grid.call("world_to_cell", anchor + Vector2(48.0, 0.0)))
		world.call("_place_bow_tower_at_cell", build_grid.call("world_to_cell", anchor + Vector2(48.0, -72.0)))
		world.call("_place_storm_rod_at_cell", build_grid.call("world_to_cell", anchor + Vector2(112.0, -72.0)))
	world.call("_spawn_enemy", anchor + Vector2(180.0, 0.0), "zombie")
	world.call("_spawn_enemy", anchor + Vector2(150.0, -96.0), "flying")
	await process_frame

	var perception_builder = AriPerceptionScript.new()
	var direct_report: Dictionary = perception_builder.call("build_report", world)
	_assert(direct_report.has("nearby_enemies"), "Ari perception should list nearby enemies")
	_assert(direct_report.has("nearby_structures"), "Ari perception should list nearby structures")
	_assert(direct_report.has("tactical_facts"), "Ari perception should include tactical facts")
	_assert(direct_report.get("nearby_enemies", []).size() <= 5, "Ari perception should cap nearby enemies")
	_assert(direct_report.get("nearby_structures", []).size() <= 8, "Ari perception should cap nearby structures")
	_assert(_array_has_dictionary_value(direct_report.get("nearby_enemies", []), "type", "flying"), "Ari perception should notice flying enemies")
	_assert(_array_has_dictionary_value(direct_report.get("nearby_structures", []), "type", "wall"), "Ari perception should notice existing walls")
	_assert(_array_has_dictionary_value(direct_report.get("nearby_structures", []), "type", "bow_tower"), "Ari perception should notice existing bow towers")
	_assert(_array_text_contains(direct_report.get("tactical_facts", []), "Flying"), "Ari perception should explain flying enemy implications")

	var payload: Dictionary = world.call("_build_ai_deep_interpretation_payload")
	_assert(payload.has("rulebook"), "AI deep payload should include the compact rulebook")
	_assert(payload.has("perception"), "AI deep payload should include Ari's perception report")
	_assert(payload.has("run_build"), "AI deep payload should include run_build at top level")
	_assert(payload.has("ari") and payload.has("world"), "AI deep payload should keep compatibility ari/world fields")
	_assert(typeof(payload.get("rulebook", {})) == TYPE_DICTIONARY, "AI rulebook payload should be a dictionary")
	_assert(typeof(payload.get("perception", {})) == TYPE_DICTIONARY, "AI perception payload should be a dictionary")
	var perception: Dictionary = payload.get("perception", {})
	_assert(perception.get("available_safe_moves", []).size() > 0, "AI perception should expose available safe moves")
	_assert(_array_text_contains(perception.get("tactical_facts", []), "wall") or _array_text_contains(perception.get("tactical_facts", []), "tower"), "AI perception should include readable tactical facts")

	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_world_agent_plan_state_contract() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for agent plan state checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("add_stone", 40)
	_assert(world.has_method("_on_agent_plan_response"), "World should expose an agent plan response callback")
	if not world.has_method("_on_agent_plan_response"):
		root.remove_child(world)
		world.queue_free()
		await process_frame
		return
	var request_id := 0
	world.call("_on_agent_plan_response", request_id, {
		"ok": true,
		"schema": "ari.agent.plan.v1",
		"goal": "survive with height",
		"survival_theory": "Height buys time.",
		"plan": [{
			"step_id": "height_first",
			"action_id": "build_tower",
			"reason": "The plan wants height and arrows.",
			"success": "tower_exists",
		}],
		"next_action": {"action_id": "build_tower", "urgency": 0.9, "reason": "Build height first."},
		"fallback_action": {"action_id": "use_cover", "urgency": 0.5},
		"belief_updates": [],
		"thought": "If teeth have to climb, I get time.",
		"confidence": 0.8,
		"replan_after_seconds": 9.0,
	})
	var active_plan: Array = world.get("agent_grounded_plan")
	_assert(active_plan.size() > 0, "valid agent plan should become active grounded plan")
	if active_plan.size() > 0:
		_assert(active_plan[0].get("affordance_id", "") == "build_tower", "active agent grounded plan should map action ids to affordances")
	var context: Dictionary = world.call("_get_ari_mind_context")
	_assert(context.has("agent_grounded_plan"), "AriMind context should include active agent plan")
	_assert(context.get("agent_grounded_plan", []).size() > 0, "AriMind context should carry active agent plan items")
	var plan_events: Array = world.get("ari_memory").get_recent_events(8)
	_assert(_array_has_dictionary_value(plan_events, "type", "agent_plan_created"), "accepted agent plan should be recorded as memory telemetry")
	var plan_event := _find_dictionary_by_value(plan_events, "type", "agent_plan_created")
	_assert(str(plan_event.get("action_id", "")) == "build_tower", "agent plan telemetry should record chosen action")
	_assert(str(plan_event.get("reason", "")).contains("Build height"), "agent plan telemetry should record chosen reason")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_outcomes_feed_next_observation() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for agent plan outcome checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")
	world.set("sign_text", "build height then light")
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("add_stone", 80)
	world.call("_on_agent_plan_response", 0, {
		"ok": true,
		"source": "remote_server",
		"schema": "ari.agent.plan.v1",
		"goal": "survive with height and light",
		"survival_theory": "Build height, then make light hurt enemies before contact.",
		"plan": [{
			"step_id": "height_first",
			"action_id": "build_tower",
			"reason": "Height makes arrows real.",
			"success": "bow_tower_count > 0",
		}, {
			"step_id": "light_second",
			"action_id": "place_aura_orb",
			"reason": "Light hurts enemies before contact.",
			"success": "aura_orb_count > 0",
		}],
		"next_action": {"action_id": "build_tower", "urgency": 0.9, "reason": "Build height first."},
		"fallback_action": {"action_id": "use_cover", "urgency": 0.5},
		"belief_updates": [],
		"thought": "Height first, then light.",
		"confidence": 0.8,
		"replan_after_seconds": 9.0,
	})
	var first_plan: Array = world.get("agent_grounded_plan")
	_assert(first_plan.size() > 0 and first_plan[0].get("affordance_id", "") == "build_tower", "agent plan should start on the first step")
	var tower_slot: Dictionary = world.call("_get_next_build_slot", "bow_tower")
	_assert(tower_slot.has("cell"), "tower slot should exist for plan outcome test")
	if tower_slot.has("cell"):
		_assert(bool(world.call("_place_bow_tower_at_cell", tower_slot["cell"])), "plan outcome test should place a bow tower")
	var active_plan: Dictionary = world.get("agent_plan")
	_assert(int(active_plan.get("step_index", 0)) >= 1, "successful plan action should advance the active step index")
	var next_plan: Array = world.get("agent_grounded_plan")
	_assert(next_plan.size() > 0 and next_plan[0].get("affordance_id", "") == "place_aura_orb", "after building tower, active plan should advance to the aura step")
	var payload: Dictionary = world.call("_build_agent_plan_payload", "structure_built")
	_assert(payload.has("current_plan"), "agent planner payload should include current_plan")
	_assert(payload.has("recent_outcomes"), "agent planner payload should include recent_outcomes")
	_assert(payload.has("active_doctrines"), "agent planner payload should include active_doctrines")
	_assert(int(payload.get("current_plan", {}).get("step_index", 0)) >= 1, "current_plan payload should expose advanced step index")
	var outcomes: Array = payload.get("recent_outcomes", [])
	_assert(outcomes.size() > 0, "recent_outcomes should include completed plan action")
	if outcomes.size() > 0:
		_assert(str(outcomes[0].get("action_id", "")) == "build_tower", "completed plan outcome should name the action id")
		_assert(str(outcomes[0].get("outcome", "")) == "action_completed", "completed plan outcome should name action_completed")
	world.get("ari_doctrine").add_doctrine({
		"id": "height_always_saves",
		"when": {"phase": "midday"},
		"bias": {"build_tower": 0.9},
		"plan": [{"affordance_id": "build_tower", "priority": 0.9, "reason": "Height always saves Ari."}],
		"confidence": 0.9,
	})
	var doctrine_before: Dictionary = world.get("ari_doctrine").get_active_bias({"phase": "midday", "enemy_type_counts": {}})
	_assert(float(doctrine_before.get("build_tower", 0.0)) > 0.7, "world outcome test should start with a strong tower doctrine")
	for _i in range(3):
		world.call("_record_agent_plan_outcome", "build_tower", "near_death", "Ari was nearly killed while trusting height.", "near_death")
	var doctrine_after: Dictionary = world.get("ari_doctrine").get_active_bias({"phase": "midday", "enemy_type_counts": {}})
	_assert(float(doctrine_after.get("build_tower", 0.0)) < 0.35, "World should feed bad plan outcomes into doctrine confidence")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_out_of_order_completion_does_not_skip_prerequisite() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for out-of-order plan outcome checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var plan := {
		"ok": true,
		"source": "remote_server",
		"schema": "ari.agent.plan.v1",
		"goal": "restore sky defense before using range",
		"survival_theory": "The sky answer comes before ranged support.",
		"plan": [{
			"step_id": "restore_storm",
			"action_id": "build_storm_rod",
			"reason": "Rebuild the destroyed sky answer.",
			"success": "storm_rod_count > 0",
		}, {
			"step_id": "add_range",
			"action_id": "build_tower",
			"reason": "Add ranged support after storm exists.",
			"success": "bow_tower_count > 0",
		}, {
			"step_id": "use_range",
			"action_id": "use_tower",
			"reason": "Use range after both structures exist.",
			"success": "survive",
		}],
		"next_action": {"action_id": "build_storm_rod", "urgency": 0.9, "reason": "Storm first."},
		"fallback_action": {"action_id": "flee", "urgency": 0.5},
		"belief_updates": [],
		"thought": "Storm first, tower second.",
		"confidence": 0.85,
		"replan_after_seconds": 9.0,
		"step_index": 0,
		"created_at_seconds": 0.0,
		"outcomes": [],
		"failures": [],
		"abandoned": false,
	}
	world.set("agent_plan", plan.duplicate(true))
	world.set("agent_grounded_plan", world.call("_agent_plan_to_grounded_plan", plan))
	world.call("_record_agent_plan_outcome", "build_tower", "action_completed", "A later tower was built before the storm prerequisite.", "structure_built")
	var active_plan: Dictionary = world.get("agent_plan")
	_assert(int(active_plan.get("step_index", -1)) == 0, "out-of-order completed support steps should not advance past an unsatisfied Storm Rod prerequisite")
	_assert(str(world.call("_current_agent_step_action_id")) == "build_storm_rod", "current agent step should remain the missing Storm Rod prerequisite")
	var grounded: Array = world.get("agent_grounded_plan")
	_assert(grounded.size() > 0 and str(grounded[0].get("affordance_id", "")) == "build_storm_rod", "grounded plan should keep driving the missing Storm Rod prerequisite")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_reflection_doctrine_overrides_unsafe_local_sign_fallback() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for reflection doctrine planning checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("add_stone", 100)
	world.set("sign_text", "build walls until the sky stops")
	world.set("sign_grounded_plan", [{
		"affordance_id": "build_wall",
		"priority": 0.95,
		"reason": "The sign still speaks in walls.",
	}])
	var arena: Rect2 = world.call("get_arena_rect")
	world.call("_spawn_enemy", arena.get_center() + Vector2(190.0, -80.0), "flying")
	await process_frame
	var before_action := str(world.call("_local_fallback_agent_action_id"))
	_assert(before_action == "build_wall", "local fallback should start by following the sign before a learned reflection")
	world.call("_apply_night_reflection_note", {
		"schema": "ari.night_reflection.v1",
		"title": "Wings Over Stone",
		"markdown": "Ari learned that wings made ordinary wall thinking unsafe.",
		"hypothesis": "Flying enemies need anti-air before extra wall.",
		"priority_hints": {"build_storm_rod": 0.9},
		"priority_bias": {"build_storm_rod": 0.9, "build_wall": -0.35},
		"doctrines": [{
			"id": "wings_need_sky_before_wall",
			"summary": "When flying enemies are present, build the sky answer before more wall.",
			"when": {"enemy_type_present": "flying"},
			"bias": {"build_storm_rod": 0.9, "build_wall": -0.35},
			"plan": [{"affordance_id": "build_storm_rod", "priority": 0.95, "reason": "Wings need anti-air before ordinary cover."}],
			"confidence": 0.9,
		}],
		"thought": "Walls did not answer wings.",
		"confidence": 0.9,
	}, "dawn_survived")
	var after_action := str(world.call("_local_fallback_agent_action_id"))
	_assert(after_action == "build_storm_rod", "learned reflection doctrine should override an unsafe wall sign when flying danger is present")
	var payload: Dictionary = world.call("_build_agent_plan_payload", "night_reflection")
	var fallback_next: Dictionary = payload.get("local_fallback", {}).get("next_action", {})
	_assert(str(fallback_next.get("action_id", "")) == "build_storm_rod", "planner fallback payload should carry the learned doctrine action")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_reflection_doctrine_advances_after_storm_exists() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for anti-flying doctrine progression checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("add_stone", 100)
	world.set("sign_text", "stone walls are safety")
	world.set("sign_grounded_plan", [{
		"affordance_id": "build_wall",
		"priority": 0.95,
		"reason": "The sign still speaks in walls.",
	}])
	var arena: Rect2 = world.call("get_arena_rect")
	var anchor := arena.get_center()
	var build_grid = world.get("build_grid")
	if build_grid != null:
		world.call("_place_wall_at_cell", build_grid.call("world_to_cell", anchor + Vector2(48.0, 0.0)))
		world.call("_place_storm_rod_at_cell", build_grid.call("world_to_cell", anchor + Vector2(112.0, -72.0)))
	world.call("_spawn_enemy", anchor + Vector2(190.0, -80.0), "flying")
	world.get("ari_doctrine").add_doctrine({
		"id": "wings_need_sequence_after_storm",
		"summary": "When flying danger has a first sky answer, add ranged support instead of stacking walls.",
		"when": {"enemy_type_present": "flying"},
		"bias": {"build_storm_rod": 0.45, "build_tower": 0.24, "use_tower": 0.18, "build_wall": -0.1},
		"plan": [
			{"affordance_id": "build_storm_rod", "priority": 0.85, "reason": "Sky danger needs anti-air."},
			{"affordance_id": "build_tower", "priority": 0.58, "reason": "Ranged support keeps Ari away from wings."},
			{"affordance_id": "use_tower", "priority": 0.48, "reason": "Use the ranged perch once it exists."},
		],
		"confidence": 0.85,
	})
	await process_frame
	var action := str(world.call("_local_fallback_agent_action_id"))
	_assert(action == "build_tower", "learned anti-flying doctrine should advance to tower support once a Storm Rod already exists")
	var payload: Dictionary = world.call("_build_agent_plan_payload", "night_reflection")
	var fallback_next: Dictionary = payload.get("local_fallback", {}).get("next_action", {})
	_assert(str(fallback_next.get("action_id", "")) == "build_tower", "planner fallback payload should expose the next unsatisfied anti-flying doctrine step")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_plain_night_reflection_does_not_force_agent_plan() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for plain reflection planner checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "keep notes before night")
	var before_request_id := int(world.get("_agent_plan_request_id"))
	world.call("_apply_night_reflection_note", {
		"schema": "ari.night_reflection.v1",
		"title": "The Day's Useful Shape",
		"markdown": "Ari kept useful notes, but did not learn a new doctrine.",
		"hypothesis": "Structured notes help later reflection.",
		"priority_hints": {"use_cover": 0.2},
		"doctrines": [],
		"thought": "I can remember the shape of the day.",
		"confidence": 0.75,
	}, "dawn_survived")
	_assert(int(world.get("_agent_plan_request_id")) == before_request_id, "plain reflection notes should not force another planner call")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_doctrine_night_reflection_requests_agent_plan() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for doctrine reflection planner checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "stone walls are safety")
	var before_request_id := int(world.get("_agent_plan_request_id"))
	world.call("_apply_night_reflection_note", {
		"schema": "ari.night_reflection.v1",
		"title": "Wings Over Stone",
		"markdown": "Flying danger changed the plan.",
		"hypothesis": "Flying enemies need anti-air before wall stacking.",
		"priority_hints": {"build_storm_rod": 0.85},
		"doctrines": [{
			"id": "wings_need_sky_answer",
			"summary": "Flying threats should push Ari toward storm rods before more walls.",
			"when": {"enemy_type_present": "flying"},
			"bias": {"build_storm_rod": 0.45, "build_wall": -0.1},
			"plan": [{"affordance_id": "build_storm_rod", "priority": 0.85, "reason": "Sky danger needs anti-air."}],
			"confidence": 0.85,
		}],
		"thought": "Wings do not respect the same fear-lines as teeth.",
		"confidence": 0.85,
	}, "dawn_survived")
	_assert(int(world.get("_agent_plan_request_id")) == before_request_id + 1, "doctrine reflection notes should request a planner refresh")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_gateway_fallback_reflection_doctrine_is_not_discarded() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for gateway fallback reflection checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")
	world.set("sign_text", "do not trust walls against wings")
	_assert(world.has_method("_handle_night_reflection_response"), "World should handle validated gateway fallback reflection notes directly")
	if world.has_method("_handle_night_reflection_response"):
		world.call("_handle_night_reflection_response", {
			"schema": "ari.night_reflection.v1",
			"title": "Day 3 - Ari's rough local reflection",
			"markdown": "Ari learned that wings need a sky answer.",
			"hypothesis": "Wings need anti-air before ordinary walls.",
			"priority_hints": {"anti_air_defense": 0.65, "build_storm_rod": 0.55},
			"priority_bias": {"build_storm_rod": 0.45, "build_wall": -0.1},
			"doctrines": [{
				"id": "local_flying_requires_sky_answer",
				"summary": "When wings appear, Ari should answer the sky before stacking ordinary walls.",
				"when": {"enemy_type_present": "flying"},
				"bias": {"build_storm_rod": 0.45, "build_wall": -0.1},
				"plan": [{"affordance_id": "build_storm_rod", "priority": 0.75, "reason": "Wings need a sky defense."}],
				"confidence": 0.45,
			}],
			"thought": "Wings need an answer above the wall.",
			"confidence": 0.35,
			"source": "local_fallback",
			"failure_reason": "model_failed",
		}, "dawn_survived")
		var lesson_book = world.get("lesson_book")
		var latest_note: Dictionary = lesson_book.get_latest_note() if lesson_book != null and lesson_book.has_method("get_latest_note") else {}
		_assert(str(latest_note.get("title", "")) == "Day 3 - Ari's rough local reflection", "gateway fallback reflection title should be stored instead of replaced")
		_assert(latest_note.get("doctrines", []).size() == 1, "gateway fallback reflection doctrine should survive LessonBook validation")
		var doctrine = world.get("ari_doctrine")
		var stored_doctrines: Array = doctrine.get_all_doctrines() if doctrine != null and doctrine.has_method("get_all_doctrines") else []
		_assert(stored_doctrines.size() == 1, "gateway fallback reflection doctrine should be added to AriDoctrine")
		if not stored_doctrines.is_empty():
			_assert(str(stored_doctrines[0].get("id", "")) == "local_flying_requires_sky_answer", "stored doctrine should be the gateway fallback anti-air lesson")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_repeated_doctrine_reflection_does_not_force_agent_plan() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for repeated doctrine reflection planner checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")
	var note := {
		"schema": "ari.night_reflection.v1",
		"title": "Wings Over Stone",
		"markdown": "Ari learned that wings made ordinary wall thinking unsafe.",
		"hypothesis": "Flying enemies need anti-air before extra wall.",
		"priority_hints": {"build_storm_rod": 0.85},
		"doctrines": [{
			"id": "same_wings_need_sky_answer",
			"summary": "Flying threats need sky answers before ordinary walls.",
			"when": {"enemy_type_present": "flying"},
			"bias": {"build_storm_rod": 0.45, "build_wall": -0.1},
			"plan": [{"affordance_id": "build_storm_rod", "priority": 0.85, "reason": "Sky danger needs anti-air."}],
			"confidence": 0.85,
		}],
		"thought": "Wings do not respect walls.",
		"confidence": 0.85,
	}
	world.call("_apply_night_reflection_note", note, "dawn_survived")
	await process_frame
	var after_first_request_id := int(world.get("_agent_plan_request_id"))
	world.set("_agent_plan_request_in_flight", false)
	_assert(not bool(world.call("_night_reflection_should_request_agent_plan", note, "dawn_survived", [])), "unchanged doctrine reflections with strong hints should not force a planner call")
	world.call("_apply_night_reflection_note", note, "dawn_survived")
	await process_frame
	_assert(int(world.get("_agent_plan_request_id")) == after_first_request_id, "repeating an unchanged doctrine reflection should not force another planner call")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_abandons_contradicted_step() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for plan contradiction checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")
	world.set("sign_text", "height is always safe")
	world.call("_on_agent_plan_response", 0, {
		"ok": true,
		"source": "remote_server",
		"schema": "ari.agent.plan.v1",
		"goal": "survive by trusting height",
		"survival_theory": "Height should solve the danger.",
		"plan": [{
			"step_id": "trust_height",
			"action_id": "build_tower",
			"reason": "Ari should keep trying height.",
			"success": "bow_tower_count > 0",
		}],
		"next_action": {"action_id": "build_tower", "urgency": 0.9, "reason": "Build height."},
		"fallback_action": {"action_id": "flee", "urgency": 0.5},
		"belief_updates": [],
		"thought": "Height will save me.",
		"confidence": 0.8,
		"replan_after_seconds": 9.0,
	})
	_assert(world.get("agent_grounded_plan").size() > 0, "contradiction test should start with an active plan")
	world.call("_record_agent_plan_outcome", "build_tower", "near_death", "Ari was nearly killed while trusting height.", "near_death")
	var abandoned_plan: Dictionary = world.get("agent_plan")
	_assert(bool(abandoned_plan.get("abandoned", false)), "near-death on the active step should mark the plan abandoned")
	_assert(str(abandoned_plan.get("stale_reason", "")).contains("near_death"), "abandoned plan should preserve a stale reason")
	_assert(world.get("agent_grounded_plan").is_empty(), "abandoned plan should stop driving Ari's active grounded plan")
	var context: Dictionary = world.call("_get_ari_mind_context")
	_assert(context.get("agent_grounded_plan", []).is_empty(), "AriMind context should not keep executing an abandoned plan")
	var payload: Dictionary = world.call("_build_agent_plan_payload", "near_death")
	_assert(bool(payload.get("current_plan", {}).get("abandoned", false)), "planner payload should expose abandoned current plan")
	_assert(str(payload.get("current_plan", {}).get("stale_reason", "")).contains("near_death"), "planner payload should expose why the plan went stale")
	_assert(str(world.get("latest_thought")).to_lower().contains("change"), "Ari should visibly say that the contradicted plan changed")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_sign_commit_defers_agent_plan_while_deep_interpretation_runs() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for sign/deep planning checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	var first_plan_request_id := int(world.get("_agent_plan_request_id"))
	world.call("commit_sign", "build a mountain where arrows rain")
	_assert(world.get("_ai_deep_interpretation_in_flight") == true, "committing a sign should start deep interpretation before remote planning")
	_assert(int(world.get("_agent_plan_request_id")) == first_plan_request_id, "sign commit should defer agent planner while deep interpretation is in flight")
	_assert(str(world.get("agent_plan").get("source", "")) == "local_fallback", "deferred sign commit should seed an immediate local fallback plan")
	_assert(str(world.call("_current_agent_step_action_id")) == "build_tower", "defensive height sign should seed local tower building while deep interpretation runs")
	var sign_request_id := int(world.get("_ai_sign_request_id"))
	world.call("_on_ai_deep_interpretation_response", sign_request_id, {
		"ok": false,
		"source": "timeout",
		"failure_reason": "timeout",
	})
	_assert(world.get("_ai_deep_interpretation_in_flight") != true, "failed deep interpretation should clear the in-flight marker")
	_assert(int(world.get("_agent_plan_request_id")) == first_plan_request_id + 1, "failed deep interpretation should fall back to the sign-commit planner path")
	root.remove_child(world)
	world.queue_free()
	await process_frame

	var ore_world: World = world_scene.instantiate()
	root.add_child(ore_world)
	await process_frame
	var ore_bridge: AIBridge = ore_world.get("ai_bridge")
	if ore_bridge != null:
		ore_bridge.force_provider_mode("remote_server")
		var ore_config: Dictionary = ore_bridge.get("config")
		ore_config["server_base_url"] = "http://127.0.0.1:1"
		ore_config["timeout_seconds"] = 0.1
		ore_bridge.set("config", ore_config)
	var ore_first_plan_request_id := int(ore_world.get("_agent_plan_request_id"))
	ore_world.call("commit_sign", "ore should become a blade before the dead arrive")
	_assert(ore_world.get("_ai_deep_interpretation_in_flight") == true, "ore sign should still start deep interpretation")
	_assert(int(ore_world.get("_agent_plan_request_id")) == ore_first_plan_request_id + 1, "ore/blade signs should keep the remote sign-commit bootstrap planner call")
	root.remove_child(ore_world)
	ore_world.queue_free()
	await process_frame


func _test_deep_interpretation_requests_do_not_overlap() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for deep interpretation budget checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.5
		bridge.set("config", config)

	world.call("commit_sign", "build a mountain where arrows rain")
	var first_http_count := _http_request_child_count(bridge)
	var first_request_id := int(world.get("_ai_sign_request_id"))
	_assert(first_http_count == 1, "first sign commit should create exactly one deep interpretation HTTP request")

	world.call("_request_ai_deep_interpretation", false, false)
	world.call("_request_ai_deep_interpretation", false, false)
	_assert(_http_request_child_count(bridge) == first_http_count, "repeated deep interpretation asks for the same sign should coalesce instead of overlapping")
	_assert(int(world.get("_ai_sign_request_id")) == first_request_id, "coalesced deep requests should not invalidate the in-flight callback id")

	world.call("commit_sign", "use bow from safe height")
	_assert(_http_request_child_count(bridge) == first_http_count, "a newer sign while deep interpretation is busy should become pending instead of starting another HTTP request")
	_assert(int(world.get("_ai_sign_request_id")) == first_request_id, "pending newer signs should not invalidate the in-flight request before it returns")
	_assert(str(world.get("_ai_deep_interpretation_pending_sign_text")) == "use bow from safe height", "World should remember the latest pending sign text for the next deep interpretation")

	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_replan_timer_requests_new_plan() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for agent replan timer checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	var ari_doctrine = world.get("ari_doctrine")
	if ari_doctrine != null and ari_doctrine.has_method("clear"):
		ari_doctrine.call("clear")
	world.set("sign_text", "build a mountain where arrows rain")
	world.call("_on_agent_plan_response", 0, {
		"ok": true,
		"source": "remote_server",
		"schema": "ari.agent.plan.v1",
		"goal": "survive with height",
		"survival_theory": "Height buys time.",
		"plan": [{
			"step_id": "height_first",
			"action_id": "build_tower",
			"reason": "The plan wants height and arrows.",
			"success": "tower_exists",
		}],
		"next_action": {"action_id": "build_tower", "urgency": 0.9, "reason": "Build height first."},
		"fallback_action": {"action_id": "use_cover", "urgency": 0.5},
		"belief_updates": [],
		"thought": "If teeth have to climb, I get time.",
		"confidence": 0.8,
		"replan_after_seconds": 3.0,
	})
	var request_id := int(world.get("_agent_plan_request_id"))
	world.call("_process", 2.9)
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "agent replan timer should wait until simulated replan time is due")
	world.call("_process", 0.2)
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "due agent replan timer should still respect the planner request cooldown")
	var resource_system = world.get("resource_system")
	_assert(resource_system != null, "World should expose ResourceSystem for timer context checks")
	if resource_system != null:
		resource_system.call("add_stone", 1)
	world.call("_process", 26.8)
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "agent replan timer should wait until cooldown is nearly expired")
	world.call("_process", 0.2)
	_assert(int(world.get("_agent_plan_request_id")) > request_id, "due agent replan timer should request once when the planner cooldown expires")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_replan_timer_skips_unchanged_context() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for unchanged agent timer checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "build a mountain where arrows rain")
	world.call("_on_agent_plan_response", 0, _agent_plan_success_response(3.0))
	var request_id := int(world.get("_agent_plan_request_id"))
	world.set("_agent_plan_clock", 3.1)
	world.call("_advance_agent_replan")
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "unchanged due timer should still wait for cooldown")
	world.set("_agent_plan_clock", 30.1)
	world.call("_advance_agent_replan")
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "unchanged timer context should not spend a planner request when cooldown expires")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_requests_do_not_overlap() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for agent in-flight request checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "build a mountain where arrows rain")
	world.call("_request_agent_plan", "first")
	var first_request_id := int(world.get("_agent_plan_request_id"))
	world.call("_request_agent_plan", "second")
	world.call("_request_agent_plan", "third")
	_assert(int(world.get("_agent_plan_request_id")) == first_request_id, "agent planner should keep one in-flight request and queue later triggers")
	world.call("_on_agent_plan_response", first_request_id, {
		"ok": true,
		"source": "remote_server",
		"schema": "ari.agent.plan.v1",
		"goal": "survive with height",
		"survival_theory": "Height buys time.",
		"plan": [{
			"step_id": "height_first",
			"action_id": "build_tower",
			"reason": "The plan wants height and arrows.",
			"success": "tower_exists",
		}],
		"next_action": {"action_id": "build_tower", "urgency": 0.9, "reason": "Build height first."},
		"fallback_action": {"action_id": "use_cover", "urgency": 0.5},
		"belief_updates": [],
		"thought": "If teeth have to climb, I get time.",
		"confidence": 0.8,
		"replan_after_seconds": 8.0,
	})
	_assert(int(world.get("_agent_plan_request_id")) == first_request_id, "queued noncritical planner trigger should not immediately start a second request")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_noncritical_agent_plan_waits_while_fast_prediction_in_flight() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for prediction/planner contention checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "build high when wings come")
	world.set("_agent_plan_clock", 90.0)
	world.set("_agent_plan_next_allowed_at", 0.0)
	world.set("_fast_prediction_request_in_flight", true)
	var request_id := int(world.get("_agent_plan_request_id"))
	world.call("_request_agent_plan", "structure_built")
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "noncritical planner work should not start while fast prediction is in flight")
	_assert(str(world.get("_agent_plan_pending_trigger")) == "structure_built", "noncritical planner trigger should queue behind the fast prediction lane")
	world.call("_request_agent_plan", "near_death")
	_assert(int(world.get("_agent_plan_request_id")) == request_id + 1, "critical planner work should still bypass prediction-lane throttling")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_noncritical_queued_triggers_wait_for_cooldown() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for agent cooldown checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "build a mountain where arrows rain")
	world.call("_request_agent_plan", "sign_commit")
	var first_request_id := int(world.get("_agent_plan_request_id"))
	world.call("_request_agent_plan", "structure_built")
	world.call("_request_agent_plan", "timer")
	_assert(int(world.get("_agent_plan_request_id")) == first_request_id, "agent planner should still keep one in-flight request")
	world.call("_on_agent_plan_response", first_request_id, _agent_plan_success_response(8.0))
	_assert(int(world.get("_agent_plan_request_id")) == first_request_id, "noncritical queued planner trigger should not fire immediately after a response")
	world.call("_process", 29.9)
	_assert(int(world.get("_agent_plan_request_id")) == first_request_id, "noncritical queued planner trigger should wait for the request cooldown")
	world.call("_process", 0.2)
	_assert(int(world.get("_agent_plan_request_id")) == first_request_id + 1, "noncritical queued planner trigger should fire once when cooldown expires")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_safe_phase_changes_wait_for_cooldown() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for safe phase cooldown checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "build a mountain where arrows rain")
	var day_night = world.get("day_night")
	if day_night != null:
		day_night.set("phase", "midday")
	world.call("_request_agent_plan", "sign_commit")
	var first_request_id := int(world.get("_agent_plan_request_id"))
	world.call("_request_agent_plan", "phase_changed")
	world.call("_on_agent_plan_response", first_request_id, _agent_plan_success_response(8.0))
	_assert(int(world.get("_agent_plan_request_id")) == first_request_id, "safe phase changes should not bypass the planner cooldown")
	var resource_system = world.get("resource_system")
	_assert(resource_system != null, "World should expose ResourceSystem for safe phase context checks")
	if resource_system != null:
		resource_system.call("add_stone", 1)
	world.call("_process", 29.9)
	_assert(int(world.get("_agent_plan_request_id")) == first_request_id, "safe phase change replan should stay queued until cooldown expires")
	world.call("_process", 0.2)
	_assert(int(world.get("_agent_plan_request_id")) == first_request_id + 1, "safe phase change replan should eventually run after cooldown")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_same_day_midday_phase_skips_unchanged_context() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for same-day phase context checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "build a mountain where arrows rain")
	var day_night = world.get("day_night")
	if day_night != null:
		day_night.set("day", 1)
		day_night.set("phase", "midday")
	world.call("_on_agent_plan_response", 0, _agent_plan_success_response(8.0))
	var request_id := int(world.get("_agent_plan_request_id"))
	world.call("_request_agent_plan", "phase_changed")
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "same-day safe phase with unchanged context should not request immediately")
	world.set("_agent_plan_clock", 30.1)
	world.call("_advance_agent_replan")
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "same-day safe phase with unchanged context should not spend planner budget after cooldown")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_safe_phase_skip_does_not_resurface_as_timer() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for safe phase timer context checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "build a mountain where arrows rain")
	var day_night = world.get("day_night")
	if day_night != null:
		day_night.set("day", 1)
		day_night.set("phase", "morning")
	world.call("_on_agent_plan_response", 0, _agent_plan_success_response(8.0))
	var request_id := int(world.get("_agent_plan_request_id"))
	if day_night != null:
		day_night.set("phase", "midday")
	world.call("_request_agent_plan", "phase_changed")
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "safe midday phase with unchanged context should not request immediately")
	world.set("_agent_plan_clock", 30.1)
	world.call("_advance_agent_replan")
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "safe skipped phase should not resurface as a timer planner call when facts are unchanged")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_safe_daytime_hold_phase_skips_day_rollover() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for safe daytime hold phase checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "build a mountain where arrows rain")
	var build_grid = world.get("build_grid")
	if build_grid != null:
		var arena: Rect2 = world.call("get_arena_rect")
		_assert(bool(world.call("_place_bow_tower_at_cell", build_grid.call("world_to_cell", arena.get_center() + Vector2(48.0, -72.0)))), "safe daytime hold test should place a tower")
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("spend", {
			"stone": int(resource_system.call("get_stone")),
			"food": int(resource_system.call("get_food")),
			"ore": int(resource_system.call("get_ore")),
		})
	var day_night = world.get("day_night")
	if day_night != null:
		day_night.set("day", 3)
		day_night.set("phase", "morning")
	var hold_plan := _agent_plan_success_response(8.0)
	hold_plan["plan"] = [{
		"step_id": "hold_tower",
		"action_id": "use_tower",
		"reason": "Ari already has the ranged perch.",
		"success": "survived_pressure",
	}]
	hold_plan["next_action"] = {"action_id": "use_tower", "urgency": 0.9, "reason": "Keep using the tower."}
	world.call("_on_agent_plan_response", int(world.get("_agent_plan_request_id")), hold_plan)
	var request_id := int(world.get("_agent_plan_request_id"))
	var previous_signature := str(world.call("_agent_phase_context_signature"))
	world.set("_agent_plan_phase_signature", previous_signature)
	if day_night != null:
		day_night.set("day", 4)
		day_night.set("phase", "morning")
	_assert(day_night == null or str(day_night.get("phase")) == "morning", "safe daytime hold fixture should be in morning")
	_assert(world.get("enemies").is_empty(), "safe daytime hold fixture should have no enemies")
	_assert(int(world.call("_get_damaged_structure_count")) == 0, "safe daytime hold fixture should have no damaged structures")
	_assert(int(world.get("bow_towers").size()) > 0, "safe daytime hold fixture should still have a tower")
	_assert(str(world.call("_current_agent_step_action_id")) == "use_tower", "safe daytime hold fixture should have use_tower as current action")
	_assert(not bool(world.call("_agent_has_safe_daytime_upgrade_opportunity")), "safe daytime hold fixture should have no build upgrade available")
	_assert(bool(world.call("_agent_can_keep_safe_daytime_hold_plan")), "safe daytime hold fixture should be eligible to keep its plan")
	var previous_enemy_signature := previous_signature.replace("enemies:0", "enemies:1") + "|enemy_brute:1"
	world.set("_agent_plan_phase_signature", previous_enemy_signature)
	_assert(not bool(world.call("_agent_phase_replan_needed")), "safe daytime tower hold should ignore enemies already cleared by dawn")
	world.set("_agent_plan_timer_signature", previous_enemy_signature)
	_assert(not bool(world.call("_agent_timer_replan_needed")), "safe daytime tower hold timer should ignore enemies already cleared by dawn")
	world.set("_agent_plan_phase_signature", previous_signature)
	world.set("_agent_plan_timer_signature", previous_signature)
	_assert(not bool(world.call("_agent_phase_replan_needed")), "safe daytime tower hold should ignore harmless day rollover")
	world.call("_request_agent_plan", "phase_changed")
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "safe daytime tower hold should not replan just because the day rolled over")
	world.set("_agent_plan_clock", 30.1)
	world.call("_advance_agent_replan")
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "safe daytime tower hold should not spend queued planner budget after cooldown")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_safe_daytime_hold_phase_respects_material_change() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for safe daytime material checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var ari_doctrine = world.get("ari_doctrine")
	if ari_doctrine != null and ari_doctrine.has_method("clear"):
		ari_doctrine.call("clear")
	world.set("sign_text", "build a mountain where arrows rain")
	var build_grid = world.get("build_grid")
	if build_grid != null:
		var arena: Rect2 = world.call("get_arena_rect")
		world.call("_place_bow_tower_at_cell", build_grid.call("world_to_cell", arena.get_center() + Vector2(48.0, -72.0)))
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("spend", {
			"stone": int(resource_system.call("get_stone")),
			"food": int(resource_system.call("get_food")),
			"ore": int(resource_system.call("get_ore")),
		})
	var day_night = world.get("day_night")
	if day_night != null:
		day_night.set("day", 3)
		day_night.set("phase", "morning")
	var hold_plan := _agent_plan_success_response(8.0)
	hold_plan["plan"] = [{
		"step_id": "hold_tower",
		"action_id": "use_tower",
		"reason": "Ari already has the ranged perch.",
		"success": "survived_pressure",
	}]
	hold_plan["next_action"] = {"action_id": "use_tower", "urgency": 0.9, "reason": "Keep using the tower."}
	world.call("_on_agent_plan_response", int(world.get("_agent_plan_request_id")), hold_plan)
	world.set("_agent_plan_phase_signature", str(world.call("_agent_phase_context_signature")))
	if resource_system != null:
		resource_system.call("add_stone", 1)
	if day_night != null:
		day_night.set("day", 4)
		day_night.set("phase", "morning")
	_assert(bool(world.call("_agent_phase_replan_needed")), "safe daytime tower hold should still replan when materials changed")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_ready_dusk_phase_skips_unchanged_context() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for ready dusk phase context checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "build a mountain where arrows rain")
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("add_stone", 40)
	var build_grid = world.get("build_grid")
	if build_grid != null:
		var arena: Rect2 = world.call("get_arena_rect")
		world.call("_place_bow_tower_at_cell", build_grid.call("world_to_cell", arena.get_center() + Vector2(48.0, -72.0)))
	var day_night = world.get("day_night")
	if day_night != null:
		day_night.set("day", 1)
		day_night.set("phase", "dusk")
	var ready_plan := _agent_plan_success_response(8.0)
	ready_plan["plan"] = [{
		"step_id": "hold_tower",
		"action_id": "use_tower",
		"reason": "Ari already has the night perch.",
		"success": "survived_pressure",
	}]
	ready_plan["next_action"] = {"action_id": "use_tower", "urgency": 0.9, "reason": "Use the tower through dusk."}
	var built_request_id := int(world.get("_agent_plan_request_id"))
	world.call("_on_agent_plan_response", built_request_id, ready_plan)
	var request_id := int(world.get("_agent_plan_request_id"))
	world.call("_request_agent_plan", "phase_changed")
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "ready quiet dusk should not request immediately")
	world.set("_agent_plan_clock", 30.1)
	world.call("_advance_agent_replan")
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "ready quiet dusk with unchanged context should not spend planner budget after cooldown")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_unready_dusk_phase_stays_critical() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for unready dusk phase checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "build a mountain where arrows rain")
	var day_night = world.get("day_night")
	if day_night != null:
		day_night.set("day", 1)
		day_night.set("phase", "dusk")
	var unready_plan := _agent_plan_success_response(8.0)
	unready_plan["plan"] = [{
		"step_id": "still_building",
		"action_id": "build_tower",
		"reason": "Ari has not finished the night perch.",
		"success": "tower_exists",
	}]
	unready_plan["next_action"] = {"action_id": "build_tower", "urgency": 0.9, "reason": "The tower is still missing."}
	world.call("_request_agent_plan", "sign_commit")
	var first_request_id := int(world.get("_agent_plan_request_id"))
	world.call("_request_agent_plan", "phase_changed")
	world.call("_on_agent_plan_response", first_request_id, unready_plan)
	_assert(int(world.get("_agent_plan_request_id")) == first_request_id + 1, "unready dusk should stay critical and bypass cooldown")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_dusk_requires_unsatisfied_doctrine_defense() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for doctrine dusk readiness checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "stone walls are safety")
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("add_stone", 40)
	var build_grid = world.get("build_grid")
	if build_grid != null:
		var arena: Rect2 = world.call("get_arena_rect")
		world.call("_place_bow_tower_at_cell", build_grid.call("world_to_cell", arena.get_center() + Vector2(48.0, -72.0)))
	var day_night = world.get("day_night")
	if day_night != null:
		day_night.set("day", 3)
		day_night.set("phase", "dusk")
	world.set("_noticed_enemy_types", {"flying": true})
	var doctrine = world.get("ari_doctrine")
	if doctrine != null:
		doctrine.call("add_doctrine", {
			"id": "scripted_wings_need_sky_answer",
			"summary": "Flying threats need anti-air before more walls.",
			"when": {"enemy_type_present": "flying"},
			"bias": {"build_storm_rod": 0.45, "build_tower": 0.24, "use_tower": 0.18, "build_wall": -0.1},
			"plan": [
				{"affordance_id": "build_storm_rod", "priority": 0.85, "reason": "Sky danger needs anti-air."},
				{"affordance_id": "build_tower", "priority": 0.58, "reason": "Ranged support follows anti-air."},
				{"affordance_id": "use_tower", "priority": 0.48, "reason": "Use the ranged perch once it exists."},
			],
			"confidence": 0.85,
		})
	var ready_plan := _agent_plan_success_response(8.0)
	ready_plan["plan"] = [{
		"step_id": "hold_tower",
		"action_id": "use_tower",
		"reason": "Ari has a tower but has lost the sky answer.",
		"success": "survived_pressure",
	}]
	ready_plan["next_action"] = {"action_id": "use_tower", "urgency": 0.9, "reason": "Use the tower through dusk."}
	var built_request_id := int(world.get("_agent_plan_request_id"))
	world.call("_on_agent_plan_response", built_request_id, ready_plan)
	var request_id := int(world.get("_agent_plan_request_id"))
	world.call("_request_agent_plan", "phase_changed")
	_assert(int(world.get("_agent_plan_request_id")) == request_id + 1, "dusk should stay critical when active doctrine still needs a missing Storm Rod")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_ready_night_hold_skips_unchanged_context() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for ready night hold checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "build a mountain where arrows rain")
	var build_grid = world.get("build_grid")
	if build_grid != null:
		var arena: Rect2 = world.call("get_arena_rect")
		world.call("_place_bow_tower_at_cell", build_grid.call("world_to_cell", arena.get_center() + Vector2(48.0, -72.0)))
	var day_night = world.get("day_night")
	if day_night != null:
		day_night.set("day", 2)
		day_night.set("phase", "dusk")
	var ready_plan := _agent_plan_success_response(8.0)
	ready_plan["plan"] = [{
		"step_id": "hold_tower",
		"action_id": "use_tower",
		"reason": "Ari is already using the night perch.",
		"success": "survived_pressure",
	}]
	ready_plan["next_action"] = {"action_id": "use_tower", "urgency": 0.9, "reason": "Keep using the tower through quiet night."}
	world.call("_on_agent_plan_response", int(world.get("_agent_plan_request_id")), ready_plan)
	var request_id := int(world.get("_agent_plan_request_id"))
	if day_night != null:
		day_night.set("phase", "night")
	_assert(bool(world.call("_agent_can_keep_safe_night_hold_plan")), "ready night tower hold should be eligible to keep its plan")
	world.call("_request_agent_plan", "phase_changed")
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "ready quiet night hold should not request immediately")
	world.set("_agent_plan_clock", 30.1)
	world.call("_advance_agent_replan")
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "ready quiet night hold should not spend queued planner budget after cooldown")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_ready_night_hold_ignores_resource_only_drift() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for resource-only night hold checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "build a mountain where arrows rain")
	var build_grid = world.get("build_grid")
	if build_grid != null:
		var arena: Rect2 = world.call("get_arena_rect")
		world.call("_place_bow_tower_at_cell", build_grid.call("world_to_cell", arena.get_center() + Vector2(48.0, -72.0)))
	var day_night = world.get("day_night")
	if day_night != null:
		day_night.set("day", 2)
		day_night.set("phase", "dusk")
	var ready_plan := _agent_plan_success_response(8.0)
	ready_plan["plan"] = [{
		"step_id": "hold_tower",
		"action_id": "use_tower",
		"reason": "Ari already has the night perch.",
		"success": "survived_pressure",
	}]
	ready_plan["next_action"] = {"action_id": "use_tower", "urgency": 0.9, "reason": "Keep using the tower through quiet night."}
	world.call("_on_agent_plan_response", int(world.get("_agent_plan_request_id")), ready_plan)
	var request_id := int(world.get("_agent_plan_request_id"))
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("add_stone", 4)
		resource_system.call("add_food", 2)
		resource_system.call("add_ore", 1)
	if day_night != null:
		day_night.set("phase", "night")
	_assert(bool(world.call("_agent_can_keep_safe_night_hold_plan")), "ready night tower hold with resources changed should still be eligible to keep its plan")
	_assert(not bool(world.call("_agent_phase_replan_needed")), "safe quiet night hold should ignore stone/food/ore drift because Ari cannot use day resources at night")
	world.call("_request_agent_plan", "phase_changed")
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "resource-only drift should not spend a night planner call for an already safe hold")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_ready_night_cover_hold_skips_quiet_phase() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for quiet night cover hold checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "just survive until morning")
	var build_grid = world.get("build_grid")
	if build_grid != null:
		var arena: Rect2 = world.call("get_arena_rect")
		world.call("_place_wall_at_cell", build_grid.call("world_to_cell", arena.get_center() + Vector2(48.0, 0.0)))
	var day_night = world.get("day_night")
	if day_night != null:
		day_night.set("day", 2)
		day_night.set("phase", "dusk")
	var ready_plan := _agent_plan_success_response(8.0)
	ready_plan["plan"] = [{
		"step_id": "hold_cover",
		"action_id": "use_cover",
		"reason": "Ari already has wall cover for a quiet night.",
		"success": "survived_pressure",
	}]
	ready_plan["next_action"] = {"action_id": "use_cover", "urgency": 0.8, "reason": "Use cover until pressure arrives."}
	world.call("_on_agent_plan_response", int(world.get("_agent_plan_request_id")), ready_plan)
	var request_id := int(world.get("_agent_plan_request_id"))
	if day_night != null:
		day_night.set("phase", "night")
	_assert(bool(world.call("_agent_can_keep_safe_night_hold_plan")), "quiet night cover hold should be eligible to keep its plan")
	world.call("_request_agent_plan", "phase_changed")
	_assert(int(world.get("_agent_plan_request_id")) == request_id, "quiet night cover hold should not spend a planner call before enemies appear")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_unready_night_phase_stays_critical() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for unready night phase checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "ore should become a blade before the dead arrive")
	var day_night = world.get("day_night")
	if day_night != null:
		day_night.set("day", 2)
		day_night.set("phase", "dusk")
	var unready_plan := _agent_plan_success_response(8.0)
	unready_plan["plan"] = [{
		"step_id": "train_sword",
		"action_id": "train_sword",
		"reason": "Ari is still preparing a blade plan, not holding a night defense.",
		"success": "sword_training_done",
	}]
	unready_plan["next_action"] = {"action_id": "train_sword", "urgency": 0.8, "reason": "Keep preparing the sword."}
	world.call("_on_agent_plan_response", int(world.get("_agent_plan_request_id")), unready_plan)
	var request_id := int(world.get("_agent_plan_request_id"))
	if day_night != null:
		day_night.set("phase", "night")
	_assert(not bool(world.call("_agent_can_keep_safe_night_hold_plan")), "unready night sword plan should not be eligible for quiet-night skip")
	world.call("_request_agent_plan", "phase_changed")
	_assert(int(world.get("_agent_plan_request_id")) == request_id + 1, "unready quiet night should stay critical and request immediately")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_night_phase_change_bypasses_cooldown() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for night phase cooldown checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "build a mountain where arrows rain")
	var day_night = world.get("day_night")
	if day_night != null:
		day_night.set("phase", "night")
	var arena: Rect2 = world.call("get_arena_rect")
	world.call("_spawn_enemy", arena.get_center() + Vector2(190.0, 0.0), "zombie")
	world.call("_request_agent_plan", "sign_commit")
	var first_request_id := int(world.get("_agent_plan_request_id"))
	world.call("_request_agent_plan", "phase_changed")
	var night_ready_response := _agent_plan_success_response(8.0)
	night_ready_response["plan"] = [{
		"step_id": "use_existing_cover",
		"action_id": "use_cover",
		"reason": "Ari already has a night-safe cover plan.",
		"success": "survived_pressure",
	}]
	night_ready_response["next_action"] = {"action_id": "use_cover", "urgency": 0.8, "reason": "Use existing cover through the quiet night."}
	world.call("_on_agent_plan_response", first_request_id, night_ready_response)
	_assert(int(world.get("_agent_plan_request_id")) == first_request_id + 1, "night phase changes should bypass cooldown for immediate danger planning")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_critical_queued_triggers_bypass_cooldown() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for critical agent cooldown checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "build a mountain where arrows rain")
	world.call("_request_agent_plan", "sign_commit")
	var first_request_id := int(world.get("_agent_plan_request_id"))
	world.call("_request_agent_plan", "near_death")
	world.call("_on_agent_plan_response", first_request_id, _agent_plan_success_response(8.0))
	_assert(int(world.get("_agent_plan_request_id")) == first_request_id + 1, "critical queued planner trigger should bypass cooldown after in-flight response")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_anti_air_structure_built_bypasses_cooldown() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for anti-air build cooldown checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "do not trust walls against wings")
	world.call("_request_agent_plan", "sign_commit")
	var first_request_id := int(world.get("_agent_plan_request_id"))
	world.call("_request_agent_plan", "anti_air_structure_built")
	world.call("_on_agent_plan_response", first_request_id, _agent_plan_success_response(8.0))
	_assert(int(world.get("_agent_plan_request_id")) == first_request_id + 1, "anti-air structure builds should bypass cooldown for immediate follow-up planning")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_agent_plan_minor_structure_destroyed_waits_for_cooldown() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for structure destruction cooldown checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("remote_server")
		var config: Dictionary = bridge.get("config")
		config["server_base_url"] = "http://127.0.0.1:1"
		config["timeout_seconds"] = 0.1
		bridge.set("config", config)
	world.set("sign_text", "use the tower and keep distance")
	world.call("_request_agent_plan", "sign_commit")
	var first_request_id := int(world.get("_agent_plan_request_id"))
	var tower_plan := _agent_plan_success_response(8.0)
	tower_plan["plan"] = [{
		"step_id": "use_existing_tower",
		"action_id": "use_tower",
		"reason": "The tower is the safe active plan.",
		"success": "survived_pressure",
	}]
	tower_plan["next_action"] = {"action_id": "use_tower", "urgency": 0.8, "reason": "Use the tower that exists."}
	world.call("_on_agent_plan_response", first_request_id, tower_plan)
	var minor_trigger := str(world.call("_structure_destroyed_agent_plan_trigger", "build_wall"))
	_assert(minor_trigger == "structure_destroyed_minor", "destroying an irrelevant wall should be a noncritical planner trigger")
	world.call("_request_agent_plan", minor_trigger)
	_assert(int(world.get("_agent_plan_request_id")) == first_request_id, "minor structure destruction should not bypass cooldown")
	world.call("_process", 29.9)
	_assert(int(world.get("_agent_plan_request_id")) == first_request_id, "minor structure destruction should stay queued until cooldown expires")
	world.call("_process", 0.2)
	_assert(int(world.get("_agent_plan_request_id")) == first_request_id + 1, "minor structure destruction should eventually replan after cooldown")

	world.call("_on_agent_plan_response", first_request_id + 1, tower_plan)
	var critical_trigger := str(world.call("_structure_destroyed_agent_plan_trigger", "build_tower"))
	_assert(critical_trigger == "structure_destroyed", "destroying the structure Ari is using should stay critical")
	world.call("_request_agent_plan", critical_trigger)
	_assert(int(world.get("_agent_plan_request_id")) == first_request_id + 2, "plan-breaking structure destruction should bypass cooldown")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _agent_plan_success_response(replan_after_seconds: float) -> Dictionary:
	return {
		"ok": true,
		"source": "remote_server",
		"schema": "ari.agent.plan.v1",
		"goal": "survive with height",
		"survival_theory": "Height buys time.",
		"plan": [{
			"step_id": "height_first",
			"action_id": "build_tower",
			"reason": "The plan wants height and arrows.",
			"success": "tower_exists",
		}],
		"next_action": {"action_id": "build_tower", "urgency": 0.9, "reason": "Build height first."},
		"fallback_action": {"action_id": "use_cover", "urgency": 0.5},
		"belief_updates": [],
		"thought": "If teeth have to climb, I get time.",
		"confidence": 0.8,
		"replan_after_seconds": replan_after_seconds,
	}


func _test_ai_latency_cache_v1_contract(bridge: AIBridge) -> void:
	_assert(bridge.has_method("clear_deep_interpretation_cache"), "AIBridge should expose a way to clear the in-memory deep interpretation cache")
	_assert(bridge.has_method("_deep_cache_key"), "AIBridge should build a stable deep interpretation cache key")
	_assert(bridge.has_method("_store_deep_interpretation_cache"), "AIBridge should store valid deep interpretations")
	_assert(bridge.has_method("_cached_deep_interpretation"), "AIBridge should return cached deep interpretations")
	if not bridge.has_method("clear_deep_interpretation_cache") or not bridge.has_method("_deep_cache_key") or not bridge.has_method("_store_deep_interpretation_cache") or not bridge.has_method("_cached_deep_interpretation"):
		return
	bridge.call("clear_deep_interpretation_cache")
	var payload := {
		"sign_text": "  Stand   behind the WALL  ",
		"world": {
			"phase": "midday",
			"wall_count": 1,
			"aura_orb_count": 0,
			"bow_tower_count": 0,
			"storm_rod_count": 0,
			"enemy_type_counts": {"flying": 1},
			"structures": [{"type": "wall", "status": "intact"}],
		},
		"current_affordances": [
			{"id": "use_existing_wall", "available": true},
			{"id": "build_storm_rod", "available": true},
		],
		"local_fallback": {
			"interpretation": "Ari locally reads the wall as cover.",
			"thought": "The wall may help.",
			"survival_theory": "local_cover",
			"priority_hints": {
				"use_existing_wall": 0.7,
			},
			"grounded_plan": [{
				"affordance_id": "use_existing_wall",
				"priority": 0.7,
				"reason": "The local sign reading points to the existing wall.",
			}],
			"sign_strength": 0.6,
			"resonance": 0.55,
		},
	}
	var similar_payload := payload.duplicate(true)
	similar_payload["sign_text"] = "stand behind the wall"
	var changed_context := payload.duplicate(true)
	changed_context["world"]["wall_count"] = 0

	_assert(bridge.call("_deep_cache_key", payload) == bridge.call("_deep_cache_key", similar_payload), "deep cache should treat whitespace/case-only sign edits as the same key")
	_assert(bridge.call("_deep_cache_key", payload) != bridge.call("_deep_cache_key", changed_context), "deep cache key should include compact world context")

	var remote_result := bridge._validate_deep_interpretation({
		"interpretation": "Remote says the wall is useful cover while wings need a sky answer.",
		"thought": "The sign is deeper than it looks, but I see the wall and the sky now.",
		"survival_theory": "cover_and_sky",
		"priority_hints": {
			"use_existing_wall": 0.8,
			"build_storm_rod": 0.7,
			"unknown_key": 1.0,
		},
		"grounded_plan": [{
			"affordance_id": "build_storm_rod",
			"priority": 0.7,
			"reason": "Flying enemies bypass walls, so storm support answers the sky.",
		}],
		"sign_strength": 0.9,
		"resonance": 0.85,
	}, payload, true, "remote_server")
	bridge.call("_store_deep_interpretation_cache", payload, remote_result)
	var cached: Dictionary = bridge.call("_cached_deep_interpretation", similar_payload)
	_assert(cached.get("ok", false), "deep cache should return a valid cached interpretation")
	_assert(cached.get("source", "") == "cache", "deep cache should mark cached results")
	_assert(bool(cached.get("cached", false)), "deep cache should expose cached status")
	_assert(cached.get("interpretation", "") == remote_result.get("interpretation", ""), "deep cache should preserve the remote interpretation")
	_assert(cached.get("priority_hints", {}).get("build_storm_rod", 0.0) == 0.7, "deep cache should preserve validated priority hints")

	bridge.force_provider_mode("remote_server")
	var cached_request_state := {"done": false, "result": {}}
	bridge.request_deep_interpretation(similar_payload, func(result: Dictionary) -> void:
		cached_request_state["done"] = true
		cached_request_state["result"] = result
	)
	_assert(cached_request_state["done"], "request_deep_interpretation should return cached results immediately")
	_assert(cached_request_state["result"].get("source", "") == "cache", "request_deep_interpretation should use cache before the network")
	bridge.force_provider_mode("local_stub")

	var failed := bridge._parse_deep_interpretation_response(payload, HTTPRequest.RESULT_TIMEOUT, 0, PackedByteArray())
	_assert(not failed.get("ok", true), "failed remote deep interpretation should report fallback")
	_assert(failed.get("source", "") == "timeout", "failed remote deep interpretation should preserve timeout source")
	_assert(failed.get("failure_reason", "") == "timeout", "failed remote deep interpretation should expose compact timeout reason")
	_assert(failed.get("interpretation", "") == "Ari locally reads the wall as cover.", "failed remote deep interpretation should keep local interpretation")

	var auth_failed := bridge._parse_deep_interpretation_response(payload, HTTPRequest.RESULT_SUCCESS, 401, PackedByteArray("{}".to_utf8_buffer()))
	_assert(auth_failed.get("failure_reason", "") == "auth", "HTTP 401 should expose auth failure reason")
	var schema_failed := bridge._parse_deep_interpretation_response(payload, HTTPRequest.RESULT_SUCCESS, 422, PackedByteArray("{}".to_utf8_buffer()))
	_assert(schema_failed.get("failure_reason", "") == "http_422", "HTTP 422 should expose schema-drift failure reason")
	var parse_failed := bridge._parse_deep_interpretation_response(payload, HTTPRequest.RESULT_SUCCESS, 200, PackedByteArray("not json".to_utf8_buffer()))
	_assert(parse_failed.get("failure_reason", "") == "parse", "invalid JSON should expose parse failure reason")

	var world: World = WorldScript.new()
	_assert(world.has_method("_begin_ai_waiting"), "World should begin visible remote-AI thinking state")
	_assert(world.has_method("_advance_ai_waiting"), "World should advance visible remote-AI thinking state")
	_assert(world.has_method("_finish_ai_waiting"), "World should finish visible remote-AI thinking state")
	if not world.has_method("_begin_ai_waiting") or not world.has_method("_advance_ai_waiting") or not world.has_method("_finish_ai_waiting"):
		world.free()
		return
	world.call("_begin_ai_waiting")
	_assert(str(world.get("ai_status")).begins_with("AI: thinking"), "world should expose an AI thinking status while remote interpretation is pending")
	_assert(str(world.get("latest_thought")) == "I understand part of it. I need to turn the rest over.", "world should show the requested initial waiting thought")
	world.call("_advance_ai_waiting", 10.1)
	_assert(str(world.get("latest_thought")) == "The sign is still unfolding.", "world should show the requested long-pending thought after ten seconds")
	world.set("latest_thought", "sentinel after long pending")
	world.call("_advance_ai_waiting", 10.0)
	_assert(str(world.get("latest_thought")) == "sentinel after long pending", "world should not repeat the long-pending thought after it fires once")
	_assert(str(world.get("ai_status")).contains("thinking"), "world should keep exposing thinking status for slow remote interpretation")
	world.call("_finish_ai_waiting")
	_assert(not bool(world.get("_ai_waiting_active")), "world should stop pending state when remote interpretation resolves")
	world.free()


func _test_world_ai_latency_commit_contract() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should be loadable for AI latency integration checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")

	world.commit_sign("stand behind the wall")
	var local_interpretation := str(world.get("sign_interpretation"))
	var local_hints: Dictionary = world.get("sign_priority_hints")
	_assert(local_interpretation != "" and local_interpretation != "No sign yet.", "committing a sign should apply local SignMind interpretation immediately")
	_assert(float(local_hints.get("use_existing_wall", 0.0)) > 0.0 or float(local_hints.get("defensive_wait", 0.0)) > 0.0 or float(local_hints.get("wall", 0.0)) > 0.0, "local fallback should immediately provide executable cover/wall priority")
	_assert(str(world.get("ai_status")) == "AI disabled", "AI-disabled commits should keep gameplay on local fallback")

	world.call("_begin_ai_waiting")
	var request_id := int(world.get("_ai_sign_request_id"))
	world.call("_on_ai_deep_interpretation_response", request_id, {
		"ok": true,
		"source": "remote_server",
		"interpretation": "Remote reads the wall as cover and gives Ari a calmer plan.",
		"thought": "The wall is not the whole answer, but it buys me time.",
		"survival_theory": "remote_cover",
		"emotion": "careful focus",
		"grounded_plan": [{
			"affordance_id": "use_existing_wall",
			"priority": 0.9,
			"reason": "The sign says to stand behind the existing wall.",
		}],
		"priority_hints": {
			"use_existing_wall": 0.9,
			"use_cover": 0.8,
		},
		"sign_strength": 0.82,
		"resonance": 0.76,
	})
	_assert(str(world.get("sign_interpretation")).begins_with("Remote reads"), "valid remote response should replace the displayed interpretation")
	_assert(float(world.get("sign_priority_hints").get("use_existing_wall", 0.0)) >= 0.9, "valid remote response should enhance priorities")
	_assert(str(world.get("ai_status")) == "AI: active", "valid remote response should leave AI active")
	_assert(str(world.get("latest_thought")).contains("buys me time"), "valid remote response should show Ari's AI thought")

	world.call("_begin_ai_waiting")
	world.call("_on_ai_deep_interpretation_response", request_id, {
		"ok": true,
		"source": "remote_server",
		"interpretation": "Remote sees the wall again.",
		"survival_theory": "remote_cover",
		"grounded_plan": [{
			"affordance_id": "use_existing_wall",
			"priority": 0.7,
			"reason": "The sign says to stand behind the existing wall.",
		}],
		"priority_hints": {
			"use_existing_wall": 0.7,
		},
		"sign_strength": 0.7,
		"resonance": 0.7,
	})
	_assert(str(world.get("latest_thought")) == "Now I see it.", "valid remote response without a thought should show the fallback understood moment")

	world.call("_begin_ai_waiting")
	world.call("_on_ai_deep_interpretation_response", request_id, {
		"ok": true,
		"cached": true,
		"source": "cache",
		"interpretation": "Cached remote reads the wall as cover.",
		"thought": "Cached thought should not override the remembered sign line.",
		"survival_theory": "cached_cover",
		"grounded_plan": [{
			"affordance_id": "use_existing_wall",
			"priority": 0.8,
			"reason": "The cached sign still points to existing cover.",
		}],
		"priority_hints": {
			"use_existing_wall": 0.8,
		},
		"sign_strength": 0.8,
		"resonance": 0.8,
	})
	_assert(str(world.get("ai_status")) == "AI: cached", "cached remote response should expose cached status")
	_assert(str(world.get("latest_thought")) == "I remember this sign.", "cached remote response should show the requested memory thought")

	var remote_interpretation := str(world.get("sign_interpretation"))
	world.call("_begin_ai_waiting")
	world.call("_on_ai_deep_interpretation_response", request_id, {
		"ok": false,
		"source": "timeout",
		"failure_reason": "timeout",
	})
	_assert(str(world.get("sign_interpretation")) == remote_interpretation, "failed remote response should not erase the current interpretation")
	_assert(str(world.get("ai_status")) == "AI: failed/fallback (timeout)", "failed remote response should expose fallback status with reason")
	_assert(str(world.get("latest_thought")) == "I cannot hear more from the sign. I will use what I understood.", "failed remote response should show the requested fallback thought")

	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_sign_panel_ai_status_line() -> void:
	var panel = SignPanelScene.instantiate()
	root.add_child(panel)
	await process_frame
	panel.call("update_state", {
		"ai_status": "AI: thinking 12s...",
		"ai_top_hint": "build_tower",
		"sign_text": "stand behind the wall",
		"sign_interpretation": "Ari reads the wall as cover.",
	})
	var status_label = panel.get_node_or_null("DisplayPanel/DisplayVBox/AiHeaderRow/AiStatusLabel")
	_assert(status_label != null, "SignPanel should expose a compact AI status line in the AI section")
	if status_label != null:
		_assert(str(status_label.get("text")) == "AI: thinking 12s...", "SignPanel should show the current AI status")
	var sign_header = panel.get_node_or_null("DisplayPanel/DisplayVBox/SignHeaderLabel")
	var ai_header = panel.get_node_or_null("DisplayPanel/DisplayVBox/AiHeaderRow/AIHeaderLabel")
	_assert(sign_header != null and str(sign_header.get("text")) == "SIGN", "SignPanel should group the current sign under a Sign header")
	_assert(ai_header != null and str(ai_header.get("text")) == "AI", "SignPanel should group interpretation under an AI header")
	var plan_label = panel.get_node_or_null("DisplayPanel/DisplayVBox/PlanLabel")
	_assert(plan_label != null, "SignPanel should expose a readable plan label")
	if plan_label != null:
		_assert(str(plan_label.get("text")).contains("tower range"), "SignPanel should fall back to the local top hint when no grounded AI plan exists")
	panel.call("update_state", {
		"ai_status": "AI: failed/fallback (http_422)",
		"ai_top_grounded_plan": "use tower: bow range",
		"sign_text": "use bow",
		"sign_interpretation": "Ari reads this as a ranged-fighting sign.",
	})
	if status_label != null:
		_assert(str(status_label.get("text")) == "AI: failed/fallback (http_422)", "SignPanel should show compact non-secret AI failure reason")
	root.remove_child(panel)
	panel.queue_free()
	await process_frame


func _test_hud_enemy_counter_is_readable() -> void:
	var hud = HUDScene.instantiate()
	root.add_child(hud)
	await process_frame
	hud.call("update_state", {
		"day": 2,
		"phase": "night",
		"time_left": 12.0,
		"ari_hp": 80.0,
		"ari_max_hp": 100.0,
		"enemy_count": 4,
		"enemy_type_counts": {
			"zombie": 1,
			"runner": 1,
			"brute": 1,
			"flying": 1,
		},
		"stone": 12,
		"food": 2,
		"ari_action": "use_cover",
		"ari_job_reason": "Use existing wall.",
		"selected_build_name": "Tower",
		"selected_build_type": "bow_tower",
		"run_build_name": "Balanced",
		"ai_survival_theory": "Remote theory should stay out of the HUD.",
		"ai_top_grounded_plan": "Remote plan should stay out of the HUD.",
		"ai_top_hint": "build_tower",
		"ai_status": "AI: active",
	})
	var status_label = hud.get_node_or_null("StatusPanel/Content/StatusLabel")
	var mind_label = hud.get_node_or_null("StatusPanel/Content/MindLabel")
	var build_label = hud.get_node_or_null("StatusPanel/Content/BuildLabel")
	_assert(status_label != null, "HUD should expose its status label")
	if status_label != null:
		var text := str(status_label.get("text"))
		_assert(text.contains("SURVIVAL"), "HUD should group phase, HP, and enemies under Survival")
		_assert(text.contains("NIGHT"), "HUD should make night phase obvious")
		_assert(text.contains("Enemies 4"), "HUD should label the enemy counter with a readable word")
		_assert(text.contains("Z1 R1 B1 F1"), "HUD should preserve per-enemy-type counters")
	_assert(mind_label != null, "HUD should expose Ari state")
	if mind_label != null:
		var text := str(mind_label.get("text"))
		_assert(text.contains("ARI"), "HUD should group current behavior under Ari")
		_assert(not text.contains("AI theory"), "HUD should not duplicate AI theory from the SignPanel")
		_assert(not text.contains("AI plan"), "HUD should not duplicate AI plan from the SignPanel")
		_assert(not text.contains("Top hint"), "HUD should not duplicate sign hint text from the SignPanel")
		_assert(not text.contains("AI:"), "HUD should leave AI status to the SignPanel")
	_assert(build_label != null, "HUD should expose resources and build preset")
	if build_label != null:
		var text := str(build_label.get("text"))
		_assert(text.contains("RESOURCES"), "HUD should group stone, food, and TP under Resources")
		_assert(text.contains("Stone 12"), "HUD should keep stone readable")
		_assert(text.contains("Food 2"), "HUD should keep food readable")
		_assert(text.contains("Build: Tower"), "HUD should keep the current build preset readable")
		_assert(text.contains("Keys:"), "HUD should preserve compact keyboard hints")
	root.remove_child(hud)
	hud.queue_free()
	await process_frame


func _test_ai_tactical_priority_jobs() -> void:
	var ari_mind: AriMind = AriMindScript.new()

	var cover_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"aura_orb_count": 0,
		"priority_hints": {
			"use_existing_wall": 0.9,
			"wait_behind_wall": 0.8,
			"use_cover": 0.9,
			"build_wall": 0.1,
		},
	}))
	_assert(cover_decision.get("job", "") == "build_wall", "daytime cover hints should reinforce thin cover before treating it as solved")
	_assert(str(cover_decision.get("reason", "")).to_lower().contains("wall"), "cover job should explain the wall tactic")

	var grounded_cover_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"bow_tower_count": 0,
		"grounded_plan": [
			{
				"affordance_id": "ranged_attack",
				"priority": 0.95,
				"reason": "The sign wants arrows around cover.",
			},
			{
				"affordance_id": "use_existing_wall",
				"priority": 0.9,
				"reason": "The existing wall is the feasible corner.",
			},
		],
		"priority_hints": {},
	}))
	_assert(grounded_cover_decision.get("job", "") == "use_cover", "Ari should skip an unavailable grounded plan item and use the next feasible one")
	_assert(str(grounded_cover_decision.get("reason", "")).to_lower().contains("plan") or str(grounded_cover_decision.get("reason", "")).to_lower().contains("wall"), "grounded plan fallback should explain the feasible wall choice")

	var grounded_smith_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"ore": 0,
		"sword_tier": 0,
		"sword_next_ore_cost": 2,
		"grounded_plan": [{
			"affordance_id": "smith_sword",
			"priority": 0.95,
			"reason": "The sign wants the forge path.",
		}],
		"priority_hints": {},
	}))
	_assert(grounded_smith_decision.get("job", "") == "mine_ore", "A grounded smith_sword plan should mine ore first when Ari lacks ore")

	var aura_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"aura_orb_count": 1,
		"priority_hints": {
			"lure_to_aura": 0.95,
			"place_aura_orb": 0.2,
		},
	}))
	_assert(aura_decision.get("job", "") == "lure_to_aura", "lure_to_aura should make Ari use an existing Aura Orb instead of building")
	_assert(str(aura_decision.get("reason", "")).to_lower().contains("light"), "aura lure job should explain the light tactic")

	var aura_monk_reinforce_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"aura_orb_count": 1,
		"stone": 10,
		"run_build": {"points": {"warding": 7, "building": 3, "fear_control": 2}},
		"priority_hints": {
			"aura_orb": 0.92,
		},
	}))
	_assert(aura_monk_reinforce_decision.get("job", "") == "place_aura_orb", "a strong aura sign with Aura Monk instincts should reinforce one orb instead of treating the circle as done")
	_assert(str(aura_monk_reinforce_decision.get("reason", "")).to_lower().contains("light") or str(aura_monk_reinforce_decision.get("reason", "")).to_lower().contains("circle"), "reinforcing aura reason should explain the light/circle tactic")

	var repair_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"damaged_structure_count": 0,
		"priority_hints": {
			"repair": 0.9,
		},
	}))
	_assert(repair_decision.get("job", "") == "wait_or_idle", "repair hint without damaged structures should not invent a new repair system")
	_assert(str(repair_decision.get("reason", "")).to_lower().contains("repair"), "unavailable repair should still be reported as Ari's reason")

	var repair_bench_needs_walls_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"repair_bench_count": 0,
		"stone": 10,
		"priority_hints": {
			"build_repair_bench": 0.9,
			"repair_structure": 0.7,
			"wall": 0.45,
		},
	}))
	_assert(repair_bench_needs_walls_decision.get("job", "") == "build_wall", "repair tools should not outrank adding enough walls to repair")
	_assert(str(repair_bench_needs_walls_decision.get("reason", "")).to_lower().contains("wall"), "repair-wall sequencing should explain that walls come first")

	var repair_bench_ready_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"repair_bench_count": 0,
		"stone": 10,
		"priority_hints": {
			"build_repair_bench": 0.9,
			"repair_structure": 0.7,
			"wall": 0.45,
		},
	}))
	_assert(repair_bench_ready_decision.get("job", "") == "build_repair_bench", "repair tools should be built after enough walls exist")

	var repair_bench_wait_needs_wall_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"repair_bench_count": 1,
		"damaged_structure_count": 0,
		"stone": 10,
		"priority_hints": {
			"repair_structure": 0.9,
			"wall": 0.45,
		},
	}))
	_assert(repair_bench_wait_needs_wall_decision.get("job", "") == "build_wall", "repair sign should add walls instead of waiting when the bench exists but shelter is thin")

	var repair_bench_ready_keeps_prepping_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"repair_bench_count": 1,
		"damaged_structure_count": 0,
		"stone": 10,
		"priority_hints": {
			"build_repair_bench": 0.9,
			"repair_structure": 0.9,
			"wall": 0.45,
		},
	}))
	_assert(repair_bench_ready_keeps_prepping_decision.get("job", "") == "build_wall", "repair-tool plans should keep adding repairable shelter instead of waiting for damage")

	for training_case in [
		{"key": "train_combat", "label": "train_combat"},
		{"key": "fight", "label": "fight"},
		{"key": "prepare_weapon", "label": "prepare_weapon"},
	]:
		var training_decision := ari_mind.choose_daytime_job(_base_mind_context({
			"wall_count": 2,
			"aura_orb_count": 1,
			"priority_hints": {
				str(training_case.get("key", "")): 0.9,
			},
		}))
		_assert(training_decision.get("job", "") == "train_combat", "%s hint should make Ari train after basic defenses exist" % str(training_case.get("label", "")))
		_assert(str(training_decision.get("reason", "")).to_lower().contains("prepare") or str(training_decision.get("reason", "")).to_lower().contains("combat"), "%s training reason should explain combat preparation" % str(training_case.get("label", "")))

	var unsupported_tower_day_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 0,
		"bow_tower_count": 1,
		"stone": 14,
		"priority_hints": {
			"use_tower": 0.9,
			"ranged_attack": 0.8,
		},
	}))
	_assert(unsupported_tower_day_decision.get("job", "") == "build_wall", "safe daytime tower plans should add a support wall before perching all day")
	_assert(str(unsupported_tower_day_decision.get("reason", "")).to_lower().contains("tower") or str(unsupported_tower_day_decision.get("reason", "")).to_lower().contains("cover"), "tower support reason should explain why the wall matters")

	var thin_tower_low_stone_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"bow_tower_count": 1,
		"stone": 2,
		"priority_hints": {
			"use_tower": 0.9,
			"ranged_attack": 0.8,
		},
	}))
	_assert(thin_tower_low_stone_decision.get("job", "") == "mine_stone", "safe daytime tower plans should mine when cover is thin and Ari lacks wall stone")
	_assert(str(thin_tower_low_stone_decision.get("reason", "")).to_lower().contains("tower") or str(thin_tower_low_stone_decision.get("reason", "")).to_lower().contains("cover"), "tower mining reason should explain support for the ranged plan")

	var light_mud_missing_wall_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 0,
		"aura_orb_count": 1,
		"tar_pit_count": 1,
		"stone": 80,
		"grounded_plan": [{
			"affordance_id": "mine_stone",
			"priority": 0.8,
			"reason": "Generic planner says gather stone for later defenses.",
		}],
		"priority_hints": {
			"aura_orb": 0.9,
			"lure_to_aura": 0.85,
			"build_tar_pit": 0.8,
		},
	}))
	_assert(light_mud_missing_wall_decision.get("job", "") == "build_wall", "light/mud plans should rebuild missing support walls before generic mining")
	_assert(str(light_mud_missing_wall_decision.get("reason", "")).to_lower().contains("light") or str(light_mud_missing_wall_decision.get("reason", "")).to_lower().contains("mud") or str(light_mud_missing_wall_decision.get("reason", "")).to_lower().contains("cover"), "light/mud support reason should explain why the wall matters")

	var light_mud_destroyed_core_wall_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 0,
		"aura_orb_count": 0,
		"tar_pit_count": 1,
		"stone": 80,
		"grounded_plan": [{
			"affordance_id": "mine_stone",
			"priority": 0.8,
			"reason": "Generic planner says gather stone for later defenses.",
		}],
		"priority_hints": {
			"aura_orb": 0.9,
			"lure_to_aura": 0.85,
			"build_tar_pit": 0.8,
		},
	}))
	_assert(light_mud_destroyed_core_wall_decision.get("job", "") == "build_wall", "partial light/mud plans should rebuild cover before generic mining when the light is gone")
	_assert(str(light_mud_destroyed_core_wall_decision.get("reason", "")).to_lower().contains("light") or str(light_mud_destroyed_core_wall_decision.get("reason", "")).to_lower().contains("mud") or str(light_mud_destroyed_core_wall_decision.get("reason", "")).to_lower().contains("cover"), "partial light/mud cover reason should explain recovery")

	var light_mud_destroyed_core_aura_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"aura_orb_count": 0,
		"tar_pit_count": 1,
		"stone": 80,
		"grounded_plan": [{
			"affordance_id": "mine_stone",
			"priority": 0.8,
			"reason": "Generic planner says gather stone for later defenses.",
		}],
		"priority_hints": {
			"aura_orb": 0.9,
			"lure_to_aura": 0.85,
			"build_tar_pit": 0.8,
		},
	}))
	_assert(light_mud_destroyed_core_aura_decision.get("job", "") == "place_aura_orb", "partial light/mud plans should rebuild the light before generic mining once cover exists")
	_assert(str(light_mud_destroyed_core_aura_decision.get("reason", "")).to_lower().contains("light") or str(light_mud_destroyed_core_aura_decision.get("reason", "")).to_lower().contains("mud"), "partial light/mud aura reason should explain recovery")

	var light_mud_thin_cover_reinforce_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"aura_orb_count": 1,
		"tar_pit_count": 1,
		"stone": 80,
		"grounded_plan": [{
			"affordance_id": "mine_stone",
			"priority": 0.8,
			"reason": "Generic planner says gather stone for later defenses.",
		}],
		"priority_hints": {
			"aura_orb": 0.9,
			"lure_to_aura": 0.85,
			"build_tar_pit": 0.8,
		},
	}))
	_assert(light_mud_thin_cover_reinforce_decision.get("job", "") == "build_wall", "complete light/mud plans should add a second cover wall before generic mining")
	_assert(str(light_mud_thin_cover_reinforce_decision.get("reason", "")).to_lower().contains("light") or str(light_mud_thin_cover_reinforce_decision.get("reason", "")).to_lower().contains("mud") or str(light_mud_thin_cover_reinforce_decision.get("reason", "")).to_lower().contains("cover"), "light/mud second wall reason should explain cover for the kill zone")

	for ranged_case in [
		{"key": "use_tower", "label": "use_tower"},
		{"key": "train_bow", "label": "train_bow"},
		{"key": "ranged_attack", "label": "ranged_attack"},
	]:
		var tower_decision := ari_mind.choose_daytime_job(_base_mind_context({
			"wall_count": 2,
			"bow_tower_count": 1,
			"priority_hints": {
				str(ranged_case.get("key", "")): 0.9,
			},
		}))
		_assert(tower_decision.get("job", "") == "use_tower", "%s hint should make Ari use an existing tower" % str(ranged_case.get("label", "")))
		_assert(str(tower_decision.get("reason", "")).to_lower().contains("tower") or str(tower_decision.get("reason", "")).to_lower().contains("range"), "%s tower reason should explain the ranged tactic" % str(ranged_case.get("label", "")))

	var tower_reserve_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "midday",
		"time_left": 32.0,
		"wall_count": 2,
		"bow_tower_count": 1,
		"stone": 2,
		"priority_hints": {
			"use_tower": 0.9,
			"ranged_attack": 0.8,
		},
	}))
	_assert(tower_reserve_decision.get("job", "") == "mine_stone", "safe daytime tower plans should keep a repair-stone reserve before perching through the next night")
	_assert(str(tower_reserve_decision.get("reason", "")).to_lower().contains("repair") or str(tower_reserve_decision.get("reason", "")).to_lower().contains("tower") or str(tower_reserve_decision.get("reason", "")).to_lower().contains("reserve"), "tower reserve reason should explain repair readiness for the ranged plan")

	var tower_slow_ground_budget_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "midday",
		"time_left": 34.0,
		"wall_count": 2,
		"bow_tower_count": 1,
		"tar_pit_count": 0,
		"stone": 8,
		"run_build": {"points": {"building": 3, "bow": 5, "attack_range": 4}},
		"priority_hints": {
			"use_tower": 0.9,
			"ranged_attack": 0.8,
		},
	}))
	_assert(tower_slow_ground_budget_decision.get("job", "") == "mine_stone", "tower archer builds should mine beyond the repair reserve before adding slow ground support")
	_assert(str(tower_slow_ground_budget_decision.get("reason", "")).to_lower().contains("slow") or str(tower_slow_ground_budget_decision.get("reason", "")).to_lower().contains("arrow") or str(tower_slow_ground_budget_decision.get("reason", "")).to_lower().contains("tower"), "tower slow-ground budget reason should explain ranged support")

	var tower_slow_ground_build_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "midday",
		"time_left": 34.0,
		"wall_count": 2,
		"bow_tower_count": 1,
		"tar_pit_count": 0,
		"stone": 12,
		"run_build": {"points": {"building": 3, "bow": 5, "attack_range": 4}},
		"priority_hints": {
			"use_tower": 0.9,
			"ranged_attack": 0.8,
		},
	}))
	_assert(tower_slow_ground_build_decision.get("job", "") == "build_tar_pit", "tower archer builds should add slow ground once tower, cover, and reserve stone are ready")
	_assert(str(tower_slow_ground_build_decision.get("reason", "")).to_lower().contains("slow") or str(tower_slow_ground_build_decision.get("reason", "")).to_lower().contains("arrow") or str(tower_slow_ground_build_decision.get("reason", "")).to_lower().contains("tower"), "tower slow-ground build reason should explain why slow ground helps arrows")

	var build_tower_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"bow_tower_count": 0,
		"priority_hints": {
			"build_tower": 0.9,
		},
	}))
	_assert(build_tower_decision.get("job", "") == "build_bow_tower", "build_tower hint should make Ari build a tower when defenses exist")

	var destroyed_tower_rebuild_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "midday",
		"time_left": 42.0,
		"wall_count": 2,
		"bow_tower_count": 0,
		"stone": 14,
		"grounded_plan": [{
			"affordance_id": "use_cover",
			"priority": 0.8,
			"reason": "Generic planner says the existing wall is available.",
		}],
		"priority_hints": {
			"use_tower": 0.9,
			"ranged_attack": 0.8,
		},
	}))
	_assert(destroyed_tower_rebuild_decision.get("job", "") == "build_bow_tower", "safe daytime ranged plans should rebuild a destroyed tower before generic wall cover")
	_assert(str(destroyed_tower_rebuild_decision.get("reason", "")).to_lower().contains("tower") or str(destroyed_tower_rebuild_decision.get("reason", "")).to_lower().contains("range") or str(destroyed_tower_rebuild_decision.get("reason", "")).to_lower().contains("arrows"), "destroyed tower recovery reason should explain the ranged plan")

	var damaged_tower_support_repair_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "midday",
		"time_left": 38.0,
		"wall_count": 2,
		"bow_tower_count": 1,
		"stone": 6,
		"damaged_structure_count": 1,
		"lowest_structure_hp_ratio": 0.88,
		"meaningful_event_count": 1,
		"grounded_plan": [{
			"affordance_id": "use_cover",
			"priority": 0.8,
			"reason": "Generic planner says the existing wall is available.",
		}],
		"priority_hints": {
			"use_tower": 0.9,
			"ranged_attack": 0.8,
		},
	}))
	_assert(damaged_tower_support_repair_decision.get("job", "") == "repair_structure", "safe daytime ranged plans should repair damaged tower support before using cover")
	_assert(str(damaged_tower_support_repair_decision.get("reason", "")).to_lower().contains("tower") or str(damaged_tower_support_repair_decision.get("reason", "")).to_lower().contains("range") or str(damaged_tower_support_repair_decision.get("reason", "")).to_lower().contains("support"), "damaged tower support repair reason should explain the ranged setup")

	var runner_pressure_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"aura_orb_count": 1,
		"bow_tower_count": 1,
		"enemy_type_counts": {
			"runner": 2,
		},
	}))
	_assert(["use_tower", "lure_to_aura", "use_cover"].has(str(runner_pressure_decision.get("job", ""))), "runner pressure should push Ari toward active defensive positioning")

	var brute_pressure_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"aura_orb_count": 1,
		"bow_tower_count": 1,
		"enemy_type_counts": {
			"brute": 1,
		},
	}))
	_assert(brute_pressure_decision.get("job", "") == "use_tower" or brute_pressure_decision.get("job", "") == "lure_to_aura", "brute pressure should prefer damage over adding weak walls")

	for sky_case in [
		{"key": "build_storm_rod", "label": "build_storm_rod"},
		{"key": "anti_flying", "label": "anti_flying"},
		{"key": "sky_answer", "label": "sky_answer"},
	]:
		var storm_decision := ari_mind.choose_daytime_job(_base_mind_context({
			"wall_count": 2,
			"aura_orb_count": 1,
			"storm_rod_count": 0,
			"priority_hints": {
				str(sky_case.get("key", "")): 0.9,
			},
		}))
		_assert(storm_decision.get("job", "") == "build_storm_rod", "%s hint should make Ari build a Storm Rod after basic defenses exist" % str(sky_case.get("label", "")))
		_assert(str(storm_decision.get("reason", "")).to_lower().contains("sky") or str(storm_decision.get("reason", "")).to_lower().contains("anti-air"), "%s storm reason should explain the sky threat" % str(sky_case.get("label", "")))

	var flying_pressure_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"aura_orb_count": 1,
		"bow_tower_count": 1,
		"storm_rod_count": 0,
		"enemy_type_counts": {
			"flying": 1,
		},
	}))
	_assert(flying_pressure_decision.get("job", "") == "build_storm_rod", "seen flying enemies should push Ari toward Storm Rod support")

	var wounded_sky_plan_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "midday",
		"time_left": 38.0,
		"ari_hp_ratio": 0.40,
		"hunger": 34.0,
		"wall_count": 1,
		"bow_tower_count": 1,
		"storm_rod_count": 1,
		"priority_hints": {
			"build_storm_rod": 0.9,
			"use_tower": 0.8,
		},
	}))
	_assert(wounded_sky_plan_decision.get("job", "") == "rest", "wounded sky/tower plans should recover during safe daytime instead of perching all day")
	_assert(str(wounded_sky_plan_decision.get("reason", "")).to_lower().contains("recover") or str(wounded_sky_plan_decision.get("reason", "")).to_lower().contains("rest"), "wounded sky rest reason should explain recovery")

	var ready_sky_thin_cover_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "midday",
		"time_left": 42.0,
		"wall_count": 1,
		"aura_orb_count": 1,
		"bow_tower_count": 1,
		"storm_rod_count": 1,
		"stone": 80,
		"grounded_plan": [{
			"affordance_id": "mine_stone",
			"priority": 0.8,
			"reason": "Generic planner says gather stone for later defenses.",
		}],
		"priority_hints": {
			"build_storm_rod": 0.9,
			"anti_flying": 0.8,
		},
	}))
	_assert(ready_sky_thin_cover_decision.get("job", "") == "build_wall", "ready sky plans should add a second cover wall before generic mining")
	_assert(str(ready_sky_thin_cover_decision.get("reason", "")).to_lower().contains("sky") or str(ready_sky_thin_cover_decision.get("reason", "")).to_lower().contains("cover") or str(ready_sky_thin_cover_decision.get("reason", "")).to_lower().contains("storm"), "ready sky cover reason should explain support for the anti-air plan")

	var soft_wall_distrust_sky_cover_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "midday",
		"time_left": 42.0,
		"wall_count": 1,
		"aura_orb_count": 1,
		"bow_tower_count": 1,
		"storm_rod_count": 1,
		"stone": 80,
		"grounded_plan": [{
			"affordance_id": "mine_stone",
			"priority": 0.8,
			"reason": "Generic planner says gather stone for later defenses.",
		}],
		"priority_hints": {
			"build_storm_rod": 0.9,
			"anti_flying": 0.8,
			"avoid_wall": 0.4,
		},
	}))
	_assert(soft_wall_distrust_sky_cover_decision.get("job", "") == "build_wall", "soft wall distrust should still allow the second support wall for a ready sky plan")
	_assert(str(soft_wall_distrust_sky_cover_decision.get("reason", "")).to_lower().contains("sky") or str(soft_wall_distrust_sky_cover_decision.get("reason", "")).to_lower().contains("cover") or str(soft_wall_distrust_sky_cover_decision.get("reason", "")).to_lower().contains("storm"), "soft wall distrust sky cover reason should explain support, not wall worship")

	var sky_plan_missing_tower_day_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "midday",
		"time_left": 34.0,
		"ari_hp_ratio": 0.58,
		"wall_count": 1,
		"bow_tower_count": 0,
		"storm_rod_count": 1,
		"stone": 30,
		"grounded_plan": [{
			"affordance_id": "use_existing_wall",
			"priority": 0.8,
			"reason": "Generic cover plan stays first.",
		}],
		"priority_hints": {
			"build_storm_rod": 0.9,
			"use_tower": 0.8,
		},
	}))
	_assert(sky_plan_missing_tower_day_decision.get("job", "") == "build_bow_tower", "sky plans should rebuild a missing tower before generic wall cover")
	_assert(str(sky_plan_missing_tower_day_decision.get("reason", "")).to_lower().contains("storm") or str(sky_plan_missing_tower_day_decision.get("reason", "")).to_lower().contains("tower") or str(sky_plan_missing_tower_day_decision.get("reason", "")).to_lower().contains("sky"), "missing tower recovery reason should explain the sky plan")

	_assert(ari_mind.has_method("choose_night_tactic"), "AriMind should choose tactical night behavior")
	if not ari_mind.has_method("choose_night_tactic"):
		ari_mind.free()
		return

	var night_cover_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"nearest_enemy_distance": 118.0,
		"ari_hp_ratio": 0.82,
		"wall_count": 1,
		"has_valid_cover": true,
		"priority_hints": {
			"use_existing_wall": 0.8,
			"wait_behind_wall": 0.9,
			"use_cover": 0.9,
		},
	}))
	_assert(night_cover_decision.get("job", "") == "use_cover", "night cover hints should keep Ari using wall cover")

	var night_aura_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"nearest_enemy_distance": 112.0,
		"ari_hp_ratio": 0.9,
		"wall_count": 1,
		"aura_orb_count": 1,
		"has_valid_aura": true,
		"priority_hints": {
			"lure_to_aura": 0.95,
		},
	}))
	_assert(night_aura_decision.get("job", "") == "lure_to_aura", "night aura hint should keep Ari luring through an existing orb")

	var night_tower_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"nearest_enemy_distance": 112.0,
		"ari_hp_ratio": 0.9,
		"wall_count": 1,
		"bow_tower_count": 1,
		"has_valid_tower": true,
		"priority_hints": {
			"use_tower": 0.9,
			"ranged_attack": 0.9,
		},
	}))
	_assert(night_tower_decision.get("job", "") == "use_tower", "night tower hints should keep Ari using a tower perch")

	var night_sky_tower_over_cover_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"nearest_enemy_distance": 112.0,
		"ari_hp_ratio": 0.67,
		"wall_count": 1,
		"bow_tower_count": 1,
		"storm_rod_count": 1,
		"has_valid_cover": true,
		"has_valid_tower": true,
		"grounded_plan": [
			{"affordance_id": "use_existing_wall", "priority": 0.8, "reason": "Generic cover appears first."},
			{"affordance_id": "use_tower", "priority": 0.7, "reason": "Use the ranged perch after storm is ready."},
		],
		"priority_hints": {
			"build_storm_rod": 0.9,
			"use_tower": 0.8,
		},
	}))
	_assert(night_sky_tower_over_cover_decision.get("job", "") == "use_tower", "ready sky/tower plans should use tower range before generic wall cover")
	_assert(str(night_sky_tower_over_cover_decision.get("reason", "")).to_lower().contains("storm") or str(night_sky_tower_over_cover_decision.get("reason", "")).to_lower().contains("tower") or str(night_sky_tower_over_cover_decision.get("reason", "")).to_lower().contains("range"), "sky tower reason should explain the ranged storm tactic")

	var close_enemy_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 28.0,
		"ari_hp_ratio": 0.7,
		"wall_count": 1,
		"has_valid_cover": true,
		"priority_hints": {
			"use_cover": 0.9,
		},
	}))
	_assert(close_enemy_decision.get("job", "") == "flee", "Ari should flee when enemies are too close for the tactic")
	_assert(str(close_enemy_decision.get("reason", "")).to_lower().contains("close"), "flee reason should explain close danger")

	var close_fight_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 32.0,
		"ari_hp_ratio": 0.9,
		"combat_stats": {"combat_level": 1.0, "sword_skill": 1.2, "attack_damage": 18.0, "armor": 0.18},
		"priority_hints": {
			"fight_head_on": 0.95,
		},
	}))
	_assert(close_fight_decision.get("job", "") == "fight_head_on", "strong melee intent should attack inside normal flee distance when Ari is ready")

	var broken_cover_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 90.0,
		"ari_hp_ratio": 0.8,
		"wall_count": 0,
		"has_valid_cover": false,
		"priority_hints": {
			"use_cover": 0.9,
		},
	}))
	_assert(broken_cover_decision.get("job", "") == "flee", "Ari should reposition when sign cover fails at night")
	_assert(str(broken_cover_decision.get("reason", "")).to_lower().contains("wall"), "failed cover reason should mention the wall")

	var grounded_dawn_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"time_left": 9.0,
		"enemy_count": 2,
		"nearest_enemy_distance": 120.0,
		"ari_hp_ratio": 0.32,
		"wall_count": 1,
		"has_valid_cover": true,
		"grounded_plan": [{
			"affordance_id": "survive_until_morning",
			"priority": 0.95,
			"reason": "Dawn is close; survival matters more than kills.",
		}],
		"priority_hints": {},
	}))
	_assert(grounded_dawn_decision.get("job", "") != "fight_head_on", "dawn survival grounded plans should not pull low-HP Ari into combat")
	_assert(["flee", "stall_until_dawn", "hide_until_dawn", "use_cover"].has(str(grounded_dawn_decision.get("job", ""))), "dawn survival grounded plans should preserve survival behavior")
	ari_mind.free()


func _test_survival_strategy_expansion_v1_contract(bridge: AIBridge) -> void:
	for key in [
		"fight_head_on",
		"train_sword",
		"smith_sword",
		"mine_ore",
		"build_forge",
		"use_armor",
		"rely_on_regen",
		"regen_on_kill",
		"stall_until_dawn",
		"hide_until_dawn",
		"avoid_killing",
		"survive_until_morning",
		"lure_to_tar_pit",
		"use_fear_lantern",
		"use_decoy_idol",
	]:
		_assert(bridge.DEEP_PRIORITY_KEYS.has(key), "AIBridge should pass through %s priority hints" % key)

	var bridge_response := bridge._validate_deep_interpretation({
		"interpretation": "Ari reads the sign as a direct sword plan.",
		"thought": "If I must kill them, I need a blade first.",
		"survival_theory": "sword_killer",
		"grounded_plan": [
			{"affordance_id": "fight_head_on", "priority": 1.4, "reason": "The sign rejects hiding."},
			{"affordance_id": "smith_sword", "priority": 0.8, "reason": "A better blade makes contact less desperate."},
			{"affordance_id": "unknown_berserk", "priority": 1.0, "reason": "Unknown keys should not pass."},
		],
		"priority_hints": {
			"fight_head_on": 1.2,
			"train_sword": 0.7,
			"smith_sword": 0.8,
			"mine_ore": 0.5,
			"regen_on_kill": 0.9,
			"hide_until_dawn": -1.0,
			"unknown_berserk": 1.0,
		},
		"sign_strength": 0.9,
		"resonance": 0.8,
	}, {"local_fallback": {}}, true, "remote_server")
	var bridge_hints: Dictionary = bridge_response.get("priority_hints", {})
	_assert(bridge_hints.get("fight_head_on", 0.0) == 1.0, "fight_head_on hint should clamp and pass through")
	_assert(bridge_hints.get("smith_sword", 0.0) == 0.8, "smith_sword hint should pass through")
	_assert(bridge_hints.get("regen_on_kill", 0.0) == 0.9, "regen_on_kill hint should pass through")
	_assert(bridge_hints.get("hide_until_dawn", 1.0) == 0.0, "hide_until_dawn hint should clamp low values")
	_assert(not bridge_hints.has("unknown_berserk"), "unknown sword hints should be ignored")

	var resource_system: ResourceSystem = ResourceSystemScript.new()
	resource_system.call("_ready")
	_assert(resource_system.has_method("add_ore"), "ResourceSystem should track ore for smithing")
	_assert(resource_system.has_method("get_ore"), "ResourceSystem should expose ore count")
	if resource_system.has_method("add_ore") and resource_system.has_method("get_ore"):
		resource_system.call("add_ore", 3)
		_assert(int(resource_system.call("get_ore")) >= 3, "ore should be added to run resources")
		_assert(bool(resource_system.call("can_afford", {"ore": 2})), "ore should participate in affordability checks")
		_assert(bool(resource_system.call("spend", {"ore": 2})), "ore should be spendable")
		_assert(int(resource_system.call("get_state").get("ore", 0)) >= 1, "resource state should include ore")
	resource_system.free()

	var mine_node: MineNode = MineNodeScript.new()
	_assert(mine_node.has_method("mine_ore"), "MineNode should support an ore-focused mining job")
	mine_node.free()

	_assert(ResourceLoader.exists("res://data/weapons.json"), "weapons.json should define sword tiers")
	var weapons := _load_json_file("res://data/weapons.json")
	var sword_tiers: Dictionary = weapons.get("sword_tiers", {})
	_assert(sword_tiers.has("crude_sword"), "weapons.json should include a crude sword tier")
	_assert(sword_tiers.has("iron_sword"), "weapons.json should include an iron sword tier")

	var run_build: RunBuild = RunBuildScript.new()
	root.add_child(run_build)
	await process_frame
	_assert(bool(run_build.call("apply_preset_key", 9)), "run build key 9 should select Sword Killer")
	_assert(str(run_build.call("get_preset_name")) == "Sword Killer", "Sword Killer preset should be named clearly")
	var sword_effects: Dictionary = run_build.call("get_effects")
	_assert(float(sword_effects.get("sword_strength", 0.0)) > 0.0, "Sword Killer should grant sword strength")
	_assert(float(sword_effects.get("attack_damage_bonus", 0.0)) > 0.0, "Sword Killer should improve melee damage")
	_assert(float(sword_effects.get("attack_speed_multiplier", 1.0)) > 1.0, "Sword Killer should improve melee attack speed")
	root.remove_child(run_build)
	run_build.queue_free()

	var ari: AriController = AriControllerScript.new()
	ari.call("apply_run_build_effects", {
		"sword_strength": 0.8,
		"attack_damage_bonus": 0.35,
		"attack_speed_multiplier": 1.25,
		"armor_bonus": 0.18,
		"passive_regen_per_second": 0.2,
		"regen_on_kill": 6.0,
	})
	var combat_stats: Dictionary = ari.call("get_combat_stats")
	for stat_key in ["sword_skill", "attack_damage", "attack_speed", "armor", "passive_regen", "regen_on_kill", "sword_tier"]:
		_assert(combat_stats.has(stat_key), "Ari combat stats should include %s" % stat_key)
	_assert(ari.has_method("advance_sword_training_job"), "Ari should have a sword training job")
	_assert(ari.has_method("restore_from_kill"), "Ari should be able to apply regen-on-kill")
	ari.free()

	var sign_mind: SignMind = SignMindScript.new()
	var aggressive := sign_mind.interpret_sign("do not hide, focus on killing enemies")
	var aggressive_hints: Dictionary = aggressive.get("priority_hints", {})
	_assert(float(aggressive_hints.get("fight_head_on", 0.0)) >= 0.7, "aggressive signs should push fight_head_on")
	_assert(float(aggressive_hints.get("train_sword", 0.0)) > 0.0, "aggressive signs should push sword training")
	_assert(float(aggressive_hints.get("hide_until_dawn", 0.0)) <= 0.2, "do-not-hide signs should not push hiding")
	var light_dead := sign_mind.interpret_sign("make the dead walk through light")
	var light_dead_hints: Dictionary = light_dead.get("priority_hints", {})
	_assert(float(light_dead_hints.get("aura_orb", 0.0)) > float(light_dead_hints.get("fight_head_on", 0.0)), "dead-through-light signs should stay aura-oriented instead of becoming melee intent")
	var dawn_sign := sign_mind.interpret_sign("just survive until morning")
	var dawn_hints: Dictionary = dawn_sign.get("priority_hints", {})
	_assert(float(dawn_hints.get("stall_until_dawn", 0.0)) >= 0.7, "morning survival signs should push stall_until_dawn")
	_assert(float(dawn_hints.get("survive_until_morning", 0.0)) >= 0.7, "morning survival signs should push survive_until_morning")
	_assert(float(dawn_hints.get("avoid_killing", 0.0)) > 0.0, "morning survival signs should allow avoiding kills")
	var sword_sign := sign_mind.interpret_sign("make a sword that gives you life when they die")
	var sword_hints: Dictionary = sword_sign.get("priority_hints", {})
	_assert(float(sword_hints.get("smith_sword", 0.0)) > 0.0, "sword crafting signs should push smith_sword")
	_assert(float(sword_hints.get("regen_on_kill", 0.0)) > 0.0, "life-on-kill signs should push regen_on_kill")
	sign_mind.free()

	var ari_mind: AriMind = AriMindScript.new()
	var mine_ore_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"ore": 0,
		"sword_tier": 0,
		"sword_next_ore_cost": 2,
		"priority_hints": {"smith_sword": 0.9, "mine_ore": 0.8},
		"run_build": {"points": {"sword": 5, "smithing": 4, "defense": 3}},
	}))
	_assert(mine_ore_decision.get("job", "") == "mine_ore", "smithing plans should mine ore before a sword upgrade")
	var smith_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"ore": 3,
		"sword_tier": 0,
		"sword_next_ore_cost": 2,
		"priority_hints": {"smith_sword": 0.9},
		"run_build": {"points": {"sword": 5, "smithing": 4, "defense": 3}},
	}))
	_assert(smith_decision.get("job", "") == "smith_sword", "enough ore should let Ari smith a better sword")
	var train_sword_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"ore": 3,
		"sword_tier": 1,
		"combat_stats": {"combat_level": 0.2, "sword_skill": 0.0},
		"priority_hints": {"train_sword": 0.9},
		"run_build": {"points": {"sword": 5, "defense": 3}},
	}))
	_assert(train_sword_decision.get("job", "") == "train_sword", "sword training hint should use the dummy for sword skill")
	var wounded_sword_day_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "midday",
		"time_left": 30.0,
		"ari_hp_ratio": 0.75,
		"hunger": 36.0,
		"wall_count": 2,
		"sword_tier": 2,
		"combat_stats": {"combat_level": 5.0, "sword_skill": 1.2, "attack_damage": 30.0, "armor": 0.18},
		"priority_hints": {"fight_head_on": 0.95, "train_sword": 0.9},
		"agent_grounded_plan": [{"affordance_id": "train_sword", "priority": 0.95, "reason": "Practice the blade before night."}],
		"run_build": {"points": {"sword": 5, "defense": 3}},
	}))
	_assert(wounded_sword_day_decision.get("job", "") == "rest", "ready sword plans should recover at medium HP instead of overtraining before night")

	var ready_sword_thin_cover_day_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "midday",
		"time_left": 26.0,
		"ari_hp_ratio": 0.86,
		"hunger": 34.0,
		"wall_count": 1,
		"stone": 44,
		"sword_tier": 2,
		"combat_stats": {"combat_level": 3.0, "sword_skill": 1.2, "attack_damage": 30.0, "armor": 0.12},
		"priority_hints": {"fight_head_on": 0.75, "train_sword": 0.7, "smith_sword": 0.55},
		"agent_grounded_plan": [{"affordance_id": "mine_stone", "priority": 0.8, "reason": "Generic planner keeps gathering stone."}],
		"run_build": {"points": {"sword": 5, "defense": 3}},
	}))
	_assert(ready_sword_thin_cover_day_decision.get("job", "") == "build_wall", "ready sword plans should add a second wall before generic mining")
	_assert(str(ready_sword_thin_cover_day_decision.get("reason", "")).to_lower().contains("blade") or str(ready_sword_thin_cover_day_decision.get("reason", "")).to_lower().contains("cover") or str(ready_sword_thin_cover_day_decision.get("reason", "")).to_lower().contains("wall"), "ready sword cover reason should explain the safety support")

	var ready_sword_missing_killzone_day_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "midday",
		"time_left": 22.0,
		"ari_hp_ratio": 0.86,
		"hunger": 34.0,
		"wall_count": 2,
		"aura_orb_count": 0,
		"stone": 44,
		"sword_tier": 2,
		"combat_stats": {"combat_level": 3.0, "sword_skill": 1.2, "attack_damage": 30.0, "armor": 0.12},
		"priority_hints": {"fight_head_on": 0.75, "train_sword": 0.7, "smith_sword": 0.55},
		"agent_grounded_plan": [{"affordance_id": "mine_stone", "priority": 0.8, "reason": "Generic planner keeps gathering stone."}],
		"run_build": {"points": {"sword": 5, "defense": 3}},
	}))
	_assert(ready_sword_missing_killzone_day_decision.get("job", "") == "place_aura_orb", "ready sword plans should add a light kill zone before generic mining")
	_assert(str(ready_sword_missing_killzone_day_decision.get("reason", "")).to_lower().contains("blade") or str(ready_sword_missing_killzone_day_decision.get("reason", "")).to_lower().contains("light") or str(ready_sword_missing_killzone_day_decision.get("reason", "")).to_lower().contains("kill"), "ready sword kill-zone reason should explain the support")

	var night_fight_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 96.0,
		"ari_hp_ratio": 0.9,
		"combat_stats": {"combat_level": 1.0, "sword_skill": 1.2, "attack_damage": 18.0, "armor": 0.18},
		"priority_hints": {"fight_head_on": 0.95},
	}))
	_assert(night_fight_decision.get("job", "") == "fight_head_on", "strong melee intent should allow head-on fighting at night")
	var night_wounded_sword_cover_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 96.0,
		"ari_hp_ratio": 0.69,
		"wall_count": 1,
		"has_valid_cover": true,
		"combat_stats": {"combat_level": 3.0, "sword_skill": 1.2, "attack_damage": 30.0, "armor": 0.12},
		"priority_hints": {"fight_head_on": 0.75, "train_sword": 0.7, "smith_sword": 0.55},
	}))
	_assert(night_wounded_sword_cover_decision.get("job", "") == "use_cover", "wounded sword plans should use existing cover before HP is critical")
	_assert(str(night_wounded_sword_cover_decision.get("reason", "")).to_lower().contains("wounded") or str(night_wounded_sword_cover_decision.get("reason", "")).to_lower().contains("wall") or str(night_wounded_sword_cover_decision.get("reason", "")).to_lower().contains("cover"), "wounded sword cover reason should explain the safety pivot")

	var night_runner_group_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"enemy_type_counts": {"runner": 2},
		"nearest_enemy_distance": 96.0,
		"ari_hp_ratio": 0.71,
		"wall_count": 1,
		"has_valid_cover": true,
		"combat_stats": {"combat_level": 5.0, "sword_skill": 1.2, "attack_damage": 30.0, "armor": 0.18},
		"priority_hints": {"fight_head_on": 0.95, "use_cover": 0.3},
	}))
	_assert(night_runner_group_decision.get("job", "") == "use_cover", "runner groups should make sword Ari use cover instead of taking open melee")
	var night_weak_cover_runner_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"enemy_type_counts": {"runner": 2},
		"nearest_enemy_distance": 96.0,
		"ari_hp_ratio": 0.72,
		"wall_count": 2,
		"has_valid_cover": true,
		"damaged_structure_count": 1,
		"lowest_structure_hp_ratio": 0.26,
		"combat_stats": {"combat_level": 5.0, "sword_skill": 1.2, "attack_damage": 30.0, "armor": 0.18},
		"priority_hints": {"fight_head_on": 0.95, "use_cover": 0.3},
	}))
	_assert(night_weak_cover_runner_decision.get("job", "") == "flee", "runner groups should make Ari leave cover that is already close to collapse")
	var night_ready_sword_runner_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"enemy_type_counts": {"runner": 2},
		"nearest_enemy_distance": 32.0,
		"ari_hp_ratio": 0.82,
		"wall_count": 2,
		"has_valid_cover": true,
		"damaged_structure_count": 1,
		"lowest_structure_hp_ratio": 0.26,
		"combat_stats": {"combat_level": 5.0, "sword_skill": 1.2, "attack_damage": 30.0, "armor": 0.18},
		"priority_hints": {"fight_head_on": 0.95, "use_cover": 0.3},
	}))
	_assert(night_ready_sword_runner_decision.get("job", "") == "fight_head_on", "ready sword Ari should fight a runner pair when fleeing would only expose him")
	var night_lifesteal_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 36.0,
		"ari_hp_ratio": 0.86,
		"combat_stats": {"combat_level": 0.6, "sword_skill": 0.8, "attack_damage": 20.0, "armor": 0.12},
		"priority_hints": {"smith_sword": 0.85, "train_sword": 0.55, "regen_on_kill": 0.9},
	}))
	_assert(night_lifesteal_decision.get("job", "") == "fight_head_on", "sword plus life-on-kill intent should become visible melee when Ari is ready")
	_assert(not str(night_lifesteal_decision.get("reason", "")).to_lower().contains("sign rejects hiding"), "lifesteal sword combat should not invent a do-not-hide sign reason")
	_assert(str(night_lifesteal_decision.get("reason", "")).to_lower().contains("sword") or str(night_lifesteal_decision.get("reason", "")).to_lower().contains("blade") or str(night_lifesteal_decision.get("reason", "")).to_lower().contains("life"), "lifesteal sword combat reason should describe the real sword/life-on-kill cause")
	var stall_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"nearest_enemy_distance": 130.0,
		"ari_hp_ratio": 0.8,
		"wall_count": 1,
		"has_valid_cover": true,
		"priority_hints": {"survive_until_morning": 0.95, "stall_until_dawn": 0.9, "avoid_killing": 0.8},
	}))
	_assert(["stall_until_dawn", "hide_until_dawn"].has(str(stall_decision.get("job", ""))), "morning survival intent should become an explicit stall/hide night tactic")
	ari_mind.free()

	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for survival strategy expansion checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	_assert(world.get("forge_station") != null, "World should expose a forge station")
	_assert(world.has_method("_advance_ari_melee_job"), "World should advance a melee combat job")
	_assert(world.has_method("_advance_ari_smithing_job"), "World should advance a smithing job")
	_assert(world.has_method("_clear_enemies_for_dawn"), "World should clear enemies at dawn")
	world.call("spawn_enemy_at_edge", "zombie")
	await process_frame
	_assert(int(world.call("get_enemy_count")) > 0, "World should spawn a test enemy before dawn")
	world.call("_on_phase_changed", 2, "morning")
	_assert(int(world.call("get_enemy_count")) == 0, "Dawn should despawn remaining night enemies")
	_assert(str(world.get("status_message")).contains("Dawn") or str(world.get("latest_thought")).contains("Morning"), "Dawn despawn should be visible in status or thought")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_local_combat_signs() -> void:
	var sign_mind: SignMind = SignMindScript.new()
	for sign_text in [
		"train before night",
		"make your hands hurt them",
		"teeth are coming",
		"fight the dead",
		"be ready to hit",
	]:
		var interpretation := sign_mind.interpret_sign(sign_text)
		var hints: Dictionary = interpretation.get("priority_hints", {})
		_assert(float(hints.get("combat_training", 0.0)) > 0.0, "local SignMind should read '%s' as combat training" % sign_text)
	sign_mind.free()


func _test_local_tower_range_signs() -> void:
	var sign_mind: SignMind = SignMindScript.new()
	for sign_text in [
		"use bow",
		"arrows keep teeth far away",
		"build a mountain where arrows rain",
		"shoot from above",
		"height keeps teeth below",
	]:
		var interpretation := sign_mind.interpret_sign(sign_text)
		var hints: Dictionary = interpretation.get("priority_hints", {})
		_assert(float(hints.get("range", 0.0)) > 0.0 or float(hints.get("build_tower", 0.0)) > 0.0, "local SignMind should read '%s' as range or tower intent" % sign_text)
		if sign_text == "use bow":
			_assert(str(interpretation.get("interpretation_text", "")).to_lower().contains("ranged") or str(interpretation.get("interpretation_text", "")).to_lower().contains("bow"), "use bow should produce a ranged/bow local interpretation")
			_assert(float(hints.get("range", 0.0)) >= float(hints.get("combat_training", 0.0)), "use bow should not collapse to generic dummy practice")
	sign_mind.free()

	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should be loadable for local use-bow plan checks")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("add_stone", 40)
	var arena: Rect2 = world.call("get_arena_rect")
	var anchor := arena.get_center()
	var build_grid = world.get("build_grid")
	if build_grid != null:
		world.call("_place_bow_tower_at_cell", build_grid.call("world_to_cell", anchor + Vector2(48.0, -72.0)))
	world.call("_spawn_enemy", anchor + Vector2(180.0, 0.0), "zombie")
	await process_frame
	world.call("commit_sign", "use bow")
	var local_plan: Array = world.get("sign_grounded_plan")
	_assert(local_plan.size() > 0, "use bow local fallback should create a grounded ranged plan when tower context exists")
	if local_plan.size() > 0:
		_assert(["use_tower", "ranged_attack"].has(str(local_plan[0].get("affordance_id", ""))), "use bow with tower should top-plan tower/ranged behavior")
	_assert(str(world.get("sign_interpretation")).to_lower().contains("ranged") or str(world.get("sign_interpretation")).to_lower().contains("bow"), "use bow local fallback should read as ranged/bow")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_local_flying_storm_signs() -> void:
	var sign_mind: SignMind = SignMindScript.new()
	for sign_text in [
		"the wings come from above",
		"build a storm rod for the sky",
		"lightning should answer flying teeth",
		"air danger needs thunder",
		"the wings do not fear stone",
	]:
		var interpretation := sign_mind.interpret_sign(sign_text)
		var hints: Dictionary = interpretation.get("priority_hints", {})
		_assert(float(hints.get("build_storm_rod", 0.0)) > 0.0, "local SignMind should read '%s' as Storm Rod intent" % sign_text)
		if sign_text == "the wings do not fear stone":
			_assert(float(hints.get("build_storm_rod", 0.0)) > float(hints.get("build_fear_lantern", 0.0)), "wings should beat the fear keyword in local anti-flying signs")
			_assert(str(interpretation.get("interpretation_text", "")).to_lower().contains("sky"), "wings/stone sign should produce a sky interpretation")
	sign_mind.free()


func _test_farming_hunger_rest_behavior() -> void:
	var ari: AriController = AriControllerScript.new()
	ari.reset_run()
	var starting_hunger := float(ari.get("hunger"))
	ari.advance_survival_needs(10.0, "morning")
	_assert(float(ari.get("hunger")) > starting_hunger, "Ari hunger should rise over time")

	ari.set("hunger", 82.0)
	ari.restore_from_food(30.0)
	_assert(float(ari.get("hunger")) < 82.0, "eating should reduce hunger pressure")

	ari.set("hp", 52.0)
	ari.set("fear", 74.0)
	ari.set("stamina", 26.0)
	ari.set("hunger", 66.0)
	ari.restore_from_rest(2.0)
	_assert(float(ari.get("hp")) > 52.0, "rest should recover HP")
	_assert(float(ari.get("fear")) < 74.0, "rest should lower fear")
	_assert(float(ari.get("stamina")) > 26.0, "rest should recover stamina")
	_assert(float(ari.get("hunger")) <= 66.0, "rest should not increase hunger pressure")
	ari.free()

	var sign_mind: SignMind = SignMindScript.new()
	var food_sign := sign_mind.interpret_sign("full stomach, quiet heart, long life")
	var food_hints: Dictionary = food_sign.get("priority_hints", {})
	_assert(float(food_hints.get("farm_food", 0.0)) > 0.0, "SignMind should read full stomach as food intent")
	_assert(float(food_hints.get("rest", 0.0)) > 0.0, "SignMind should read quiet heart as rest intent")

	var rest_sign := sign_mind.interpret_sign("I really need some time for myself to breathe")
	var rest_hints: Dictionary = rest_sign.get("priority_hints", {})
	_assert(float(rest_hints.get("rest", 0.0)) > 0.0, "SignMind should read time for myself and breathe as rest intent")
	sign_mind.free()

	var ari_mind: AriMind = AriMindScript.new()
	var eat_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"food": 1,
		"needs": {"hunger": 82.0, "stamina": 92.0, "fear": 18.0},
	}))
	_assert(eat_decision.get("job", "") == "eat_food", "high hunger with food should make Ari eat")

	var night_agent_eat_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 0,
		"food": 1,
		"needs": {"hunger": 80.0, "stamina": 72.0, "fear": 36.0},
		"agent_grounded_plan": [{
			"affordance_id": "eat_food",
			"priority": 0.95,
			"reason": "Night food keeps Ari alive.",
		}],
	}))
	_assert(night_agent_eat_decision.get("job", "") == "eat_food", "quiet-night grounded eat_food plans should make Ari eat before idling")

	var farm_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"food": 0,
		"needs": {"hunger": 76.0, "stamina": 92.0, "fear": 18.0},
	}))
	_assert(farm_decision.get("job", "") == "farm_food", "high hunger without food should make Ari farm")

	var rest_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"ari_hp_ratio": 0.34,
		"needs": {"hunger": 22.0, "stamina": 88.0, "fear": 20.0},
	}))
	_assert(rest_decision.get("job", "") == "rest", "low HP with defenses should make Ari rest")

	var rest_sign_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"priority_hints": {"rest": 0.9},
		"needs": {"hunger": 22.0, "stamina": 88.0, "fear": 20.0},
	}))
	_assert(rest_sign_decision.get("job", "") == "rest", "rest sign should make Ari rest when defenses exist")

	var raw_eat_hint_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"food": 0,
		"priority_hints": {"eat": 0.9},
		"needs": {"hunger": 30.0, "stamina": 90.0, "fear": 18.0},
	}))
	_assert(raw_eat_hint_decision.get("job", "") == "farm_food", "raw eat AI hint should make Ari prepare food")
	ari_mind.free()


func _test_library_reflection_v1_contract() -> void:
	_assert(ResourceLoader.exists("res://scenes/stations/Library.tscn"), "Library v1 should expose a Library.tscn station resource")

	var sign_mind: SignMind = SignMindScript.new()
	var why_sign := sign_mind.interpret_sign("why did the wall fail")
	var why_hints: Dictionary = why_sign.get("priority_hints", {})
	_assert(float(why_hints.get("reflect_library", 0.0)) > 0.0, "SignMind should read why/mistake language as library reflection")
	sign_mind.free()

	var memory = AriMemoryScript.new()
	_assert(memory.has_method("create_lifetime_note_from_recent_events"), "AriMemory should create lifetime notes from recent events")
	_assert(memory.has_method("get_lifetime_notes"), "AriMemory should expose lifetime notes")
	_assert(memory.has_method("get_note_priority_bias"), "AriMemory should expose newest-note priority bias")
	if not memory.has_method("create_lifetime_note_from_recent_events"):
		return

	memory.record_event("structure_destroyed", {"structure_type": "wall", "day": 2, "phase": "night"})
	var note: Dictionary = memory.call("create_lifetime_note_from_recent_events", 2)
	_assert(str(note.get("title", "")).to_lower().contains("wall"), "library note should title the wall failure")
	_assert(str(note.get("markdown_text", "")).begins_with("#"), "library note should have markdown-like text")
	_assert(note.get("tags", []).has("structure_destroyed"), "library note should tag the source event")
	var note_hints: Dictionary = note.get("priority_hints", {})
	_assert(float(note_hints.get("build_wall", 0.0)) > 0.0 or float(note_hints.get("place_aura_orb", 0.0)) > 0.0, "library note should carry soft priority hints")
	_assert(int(note.get("created_day", 0)) == 2, "library note should store created day")
	_assert(memory.call("get_lifetime_notes").size() == 1, "memory should store the created lifetime note")

	var duplicate_note: Dictionary = memory.call("create_lifetime_note_from_recent_events", 2)
	_assert(duplicate_note.is_empty(), "reflection should not spam duplicate notes for the same event")

	memory.record_event("enemy_killed", {"enemy_type": "runner", "day": 2, "phase": "night"})
	var second_note: Dictionary = memory.call("create_lifetime_note_from_recent_events", 2)
	_assert(not second_note.is_empty(), "a new meaningful event should allow a new lifetime note")
	var bias: Dictionary = memory.call("get_note_priority_bias")
	_assert(float(bias.get("place_aura_orb", 0.0)) > 0.0 or float(bias.get("train_combat", 0.0)) > 0.0, "newest note should softly bias future priorities")

	var reflection = ReflectionSystemScript.new()
	var safe_note: Dictionary = reflection._validate_reflection({
		"title": "Day 2 - The tower saved me",
		"markdown_text": "# Day 2\n\nThe tower helped.",
		"tags": ["tower_ranged_success"],
		"priority_hints": {"build_tower": 0.4},
		"created_day": 2,
	})
	_assert(safe_note.has("markdown_text"), "ReflectionSystem should preserve markdown_text")
	_assert(safe_note.has("tags"), "ReflectionSystem should preserve note tags")
	_assert(safe_note.has("priority_hints"), "ReflectionSystem should preserve priority_hints")

	var bridge: AIBridge = AIBridgeScript.new()
	var flying_reflection: Dictionary = bridge.call("_local_stub_library_reflection", {
		"scribe_notes": [{"note": "Ari saw flying danger cross the wall.", "tags": ["danger:flying"]}],
		"snapshots": [],
	})
	_assert(flying_reflection.get("priority_hints", {}).has("anti_air_defense"), "local reflection should preserve anti_air_defense as a memory hint")
	_assert(str(flying_reflection.get("markdown", "")).contains("anti_air_defense"), "local flying reflection should name the anti-air lesson")
	var flying_plan: Array = flying_reflection.get("doctrines", [])[0].get("plan", [])
	_assert(str(flying_plan[0].get("affordance_id", "")) == "build_storm_rod", "anti-air reflection doctrine should still use concrete storm rod action")

	var tower_reflection: Dictionary = bridge.call("_local_stub_library_reflection", {
		"scribe_notes": [{
			"note": "Ari repaired the perch so the arrow plan could continue.",
			"tags": ["plan_support", "structure:tower"],
			"actions": [
				{"action": "repair_structure", "status": "in_progress"},
				{"action": "use_tower", "status": "supported"},
			],
		}],
		"snapshots": [],
	})
	var tower_actions: Array = tower_reflection.get("doctrines", [])[0].get("plan", [])
	_assert(tower_reflection.get("priority_hints", {}).has("use_tower"), "tower support reflection should bias use_tower")
	_assert(_array_has_dictionary_value(tower_actions, "affordance_id", "repair_structure"), "tower support reflection should teach repair_structure")
	_assert(_array_has_dictionary_value(tower_actions, "affordance_id", "use_tower"), "tower support reflection should teach use_tower")

	var cover_reflection: Dictionary = bridge.call("_local_stub_library_reflection", {
		"scribe_notes": [{
			"note": "Ari fought head-on while the survival plan expected hiding until dawn.",
			"tags": ["plan_body_mismatch", "danger:brute"],
			"actions": [
				{"action": "fight_head_on", "status": "in_progress"},
				{"action": "hide_until_dawn", "status": "planned"},
			],
		}],
		"snapshots": [],
	})
	var cover_actions: Array = cover_reflection.get("doctrines", [])[0].get("plan", [])
	_assert(cover_reflection.get("priority_hints", {}).has("use_cover"), "combat mismatch reflection should bias use_cover")
	_assert(_array_has_dictionary_value(cover_actions, "affordance_id", "use_cover"), "combat mismatch reflection should teach cover before direct contact")

	var ari_mind: AriMind = AriMindScript.new()
	var research_reflect_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"aura_orb_count": 1,
		"meaningful_event_count": 1,
		"run_build": {"points": {"curiosity": 7}},
		"needs": {"hunger": 24.0, "stamina": 90.0, "fear": 18.0},
	}))
	_assert(research_reflect_decision.get("job", "") == "reflect_library", "research build should reflect after a meaningful event when needs are stable")
	ari_mind.free()


func _test_permanent_upgrades_v1_contract() -> void:
	_assert(ResourceLoader.exists("res://scripts/progression/PermanentUpgrades.gd"), "Permanent Upgrades v1 should expose scripts/progression/PermanentUpgrades.gd")
	_assert(ResourceLoader.exists("res://data/permanent_upgrades.json"), "Permanent Upgrades v1 should use data/permanent_upgrades.json")
	var script = load("res://scripts/progression/PermanentUpgrades.gd")
	if script == null:
		return
	var save_path := "user://permanent_upgrades_test.json"
	var absolute_save_path := ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(absolute_save_path)
	var progression = script.new()
	progression.set("save_path", save_path)
	_assert(progression.has_method("get_state"), "PermanentUpgrades should expose progression state")
	_assert(progression.has_method("advance_survival"), "PermanentUpgrades should award Time Points while Ari lives")
	_assert(progression.has_method("reset_run"), "PermanentUpgrades should support run reset without wiping progression")
	_assert(progression.has_method("buy_upgrade"), "PermanentUpgrades should let the player buy upgrades")
	_assert(progression.has_method("grant_time_points"), "PermanentUpgrades should support controlled Time Point grants")
	_assert(progression.has_method("save_now") and progression.has_method("load_now"), "PermanentUpgrades should save/load user JSON")
	if not progression.has_method("get_state") or not progression.has_method("buy_upgrade"):
		return

	var state: Dictionary = progression.call("get_state")
	var rows: Array = state.get("upgrade_rows", [])
	var ids := []
	for row in rows:
		if typeof(row) == TYPE_DICTIONARY:
			ids.append(str(row.get("id", "")))
	for required_id in [
		"max_hp",
		"base_damage",
		"defense",
		"mining_efficiency",
		"building_efficiency",
		"farming_yield",
		"warding_power",
		"regeneration",
		"movement_speed_small",
		"sign_understanding",
	]:
		_assert(ids.has(required_id), "PermanentUpgrades should define %s" % required_id)

	progression.set("seconds_per_time_point", 1.0)
	progression.call("advance_survival", 3.0, false, true)
	var earned_points := int(progression.call("get_state").get("time_points", 0))
	_assert(earned_points >= 1, "Time Points should increase while Ari is alive")
	progression.call("advance_survival", 3.0, false, true)
	var longer_survival_points := int(progression.call("get_state").get("time_points", 0))
	_assert(longer_survival_points > earned_points, "surviving longer should give more Time Points")
	progression.call("advance_survival", 5.0, false, false)
	_assert(int(progression.call("get_state").get("time_points", 0)) == longer_survival_points, "Time Points should not increase after Ari dies")
	progression.call("reset_run")
	_assert(int(progression.call("get_state").get("time_points", 0)) == longer_survival_points, "run reset should keep Time Points")

	progression.call("grant_time_points", 200)
	for upgrade_id in ids:
		progression.call("buy_upgrade", upgrade_id)
	var effects: Dictionary = progression.call("get_effects")
	_assert(float(effects.get("max_hp_bonus", 0.0)) > 0.0, "max_hp should increase Ari max HP")
	_assert(float(effects.get("base_damage_multiplier", 1.0)) > 1.0, "base_damage should improve damage")
	_assert(float(effects.get("damage_taken_multiplier", 1.0)) < 1.0, "defense should reduce incoming damage")
	_assert(float(effects.get("mining_speed_multiplier", 1.0)) > 1.0, "mining_efficiency should improve mining")
	_assert(float(effects.get("stone_cost_multiplier", 1.0)) < 1.0, "building_efficiency should reduce build costs")
	_assert(float(effects.get("farming_yield_multiplier", 1.0)) > 1.0 or float(effects.get("farming_speed_multiplier", 1.0)) > 1.0, "farming_yield should improve food production")
	_assert(float(effects.get("aura_damage_multiplier", 1.0)) > 1.0, "warding_power should improve aura damage")
	_assert(float(effects.get("rest_recovery_multiplier", 1.0)) > 1.0, "regeneration should improve rest recovery")
	_assert(float(effects.get("movement_speed_multiplier", 1.0)) > 1.0, "movement_speed_small should improve movement")
	_assert(float(effects.get("movement_speed_multiplier", 1.0)) <= 1.12, "movement_speed_small should stay capped")
	_assert(float(effects.get("sign_strength_bonus", 0.0)) > 0.0, "sign_understanding should improve local sign reading")

	progression.call("save_now")
	var loaded = script.new()
	loaded.set("save_path", save_path)
	loaded.call("load_now")
	var loaded_state: Dictionary = loaded.call("get_state")
	_assert(int(loaded_state.get("time_points", 0)) == int(progression.call("get_state").get("time_points", 0)), "saved Time Points should load")
	var loaded_upgrades: Dictionary = loaded_state.get("upgrades", {})
	_assert(int(loaded_upgrades.get("max_hp", 0)) >= 1, "saved upgrade levels should load")
	progression.free()
	loaded.free()
	DirAccess.remove_absolute(absolute_save_path)


func _test_enemy_variety_stats() -> void:
	var zombie: EnemyController = EnemyControllerScript.new()
	zombie.configure_type("zombie")
	var runner: EnemyController = EnemyControllerScript.new()
	runner.configure_type("runner")
	var brute: EnemyController = EnemyControllerScript.new()
	brute.configure_type("brute")
	var flying: EnemyController = EnemyControllerScript.new()
	flying.configure_type("flying")

	_assert(float(runner.get("speed")) > float(zombie.get("speed")), "runner should be faster than zombie")
	_assert(float(runner.get("max_hp")) < float(zombie.get("max_hp")), "runner should have lower HP than zombie")
	_assert(float(runner.get("structure_attack_damage")) < float(zombie.get("structure_attack_damage")), "runner should have lower wall damage than zombie")
	_assert(float(brute.get("speed")) < float(zombie.get("speed")), "brute should be slower than zombie")
	_assert(float(brute.get("max_hp")) > float(zombie.get("max_hp")), "brute should have higher HP than zombie")
	_assert(float(brute.get("structure_attack_damage")) > float(zombie.get("structure_attack_damage")), "brute should have higher wall damage than zombie")
	_assert(str(flying.get("enemy_type")) == "flying", "flying beast should keep the flying enemy type")
	_assert(flying.get("ignores_walls") == true, "flying beast should ignore walls and ground blockers")
	_assert(float(flying.get("max_hp")) < float(brute.get("max_hp")), "flying beast should have lower HP than brute")
	_assert(float(flying.get("structure_attack_damage")) <= float(runner.get("structure_attack_damage")), "flying beast should not be a primary wall attacker")
	_assert(ResourceLoader.exists("res://scenes/enemies/FlyingBeast.tscn"), "Flying Beast should have a readable scene resource")

	zombie.free()
	runner.free()
	brute.free()
	flying.free()


func _test_wave_director_escalates_with_flying() -> void:
	var director: WaveDirector = WaveDirectorScript.new()
	_assert(director.has_method("choose_enemy_type_for_day"), "WaveDirector should expose deterministic enemy type choice")
	if not director.has_method("choose_enemy_type_for_day"):
		director.free()
		return
	_assert(director.call("choose_enemy_type_for_day", 1, 0.01) == "zombie", "day 1 should only spawn baseline zombies")
	_assert(director.call("choose_enemy_type_for_day", 2, 0.10) == "runner", "day 2 should begin adding runners")
	_assert(director.call("choose_enemy_type_for_day", 3, 0.05) == "brute", "day 3 should begin adding brutes")
	_assert(director.call("choose_enemy_type_for_day", 5, 0.01) != "flying", "flying enemies should wait until Ari has seen several ground nights")
	_assert(director.call("choose_enemy_type_for_day", 6, 0.01) == "flying", "later nights should begin adding flying enemies")
	director.free()


func _test_day_night_balance_v1_targets() -> void:
	var cycle: DayNightCycle = DayNightCycleScript.new()
	var prep_seconds := float(cycle.get("morning_seconds")) + float(cycle.get("midday_seconds")) + float(cycle.get("dusk_seconds"))
	_assert(prep_seconds >= 76.0, "day preparation should be long enough for several meaningful tasks")
	_assert(float(cycle.get("night_seconds")) >= 28.0, "night should last long enough to read whether defenses worked")
	cycle.free()

	var director: WaveDirector = WaveDirectorScript.new()
	_assert(float(director.get("spawn_interval_seconds")) >= 3.5, "night spawns should be paced for readability")
	_assert(int(director.get("max_enemies")) <= 7, "night enemy cap should keep early fights readable")
	director.free()

	var materials := _load_json_file("res://data/materials.json")
	var stone_material: Dictionary = materials.get("materials", {}).get("crumbly_stone", {})
	_assert(float(stone_material.get("wall_hp", 0.0)) >= 46.0, "basic walls should buy time without solving the night alone")

	var structures := _load_json_file("res://data/structures.json")
	var structure_defs: Dictionary = structures.get("structures", {})
	var aura: Dictionary = structure_defs.get("aura_orb", {})
	var tower: Dictionary = structure_defs.get("bow_tower", {})
	_assert(float(aura.get("damage_per_second", 0.0)) <= 6.8, "aura should help without becoming an automatic kill field")
	_assert(float(tower.get("damage", 0.0)) <= 9.0, "tower damage should be strong but not erase every ground enemy immediately")

	var upgrades := _load_json_file("res://data/permanent_upgrades.json")
	var upgrade_defs: Dictionary = upgrades.get("upgrades", {})
	_assert(int(upgrade_defs.get("mining_efficiency", {}).get("base_cost", 0)) >= 3, "cheap permanent upgrades should still require a real survival run")
	_assert(int(upgrade_defs.get("max_hp", {}).get("base_cost", 0)) >= 4, "core permanent upgrades should help without replacing sign understanding")

	var ari: AriController = AriControllerScript.new()
	var start_hunger := float(ari.get("hunger"))
	ari.call("advance_survival_needs", 76.0, "midday")
	_assert(float(ari.get("hunger")) - start_hunger <= 8.0, "one longer prep window should not make hunger dominate the loop")
	ari.set("hp", 60.0)
	ari.call("restore_from_rest", 5.0)
	_assert(float(ari.get("hp")) >= 69.0, "short rest should be visibly useful after damage")
	ari.free()


func _test_day_night_balance_v1_multiday_simulation() -> void:
	seed(55)
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for day/night balance simulation")
	if world_scene == null:
		return
	var test_save_path := "user://permanent_upgrades_balance_test.json"
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	_isolate_balance_progression(world, test_save_path)
	world.call("start_run")
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")
	world.call("select_run_build_preset", 5, false)
	world.call("commit_sign", "build walls, let arrows rain from a mountain, and make the dead walk through light")
	var stats: Dictionary = await _simulate_balance_seconds(world, 420.0, 0.25)
	print("Balance sim: day=%d phase=%s hp=%.1f hunger=%.1f food=%d stone=%d structures=%d enemies=%d max_wall=%d max_aura=%d max_tower=%d flying_seen=%s max_night_enemies=%d" % [
		int(stats.get("day", 1)),
		str(stats.get("phase", "")),
		float(stats.get("hp", 0.0)),
		float(stats.get("hunger", 0.0)),
		int(stats.get("food", 0)),
		int(stats.get("stone", 0)),
		int(stats.get("structures", 0)),
		int(stats.get("enemies", 0)),
		int(stats.get("max_wall_count", 0)),
		int(stats.get("max_aura_orb_count", 0)),
		int(stats.get("max_bow_tower_count", 0)),
		str(stats.get("flying_seen", false)),
		int(stats.get("max_night_enemies", 0)),
	])
	_assert(bool(stats.get("alive", false)), "a coherent wall/light/tower sign should survive a four-day balance simulation")
	_assert(int(stats.get("day", 1)) >= 5, "four-day simulation should reach the next morning")
	_assert(int(stats.get("max_wall_count", 0)) >= 2, "Ari should build enough basic wall cover during a defensive run")
	_assert(int(stats.get("max_aura_orb_count", 0)) >= 1, "Ari should make aura/light matter when the sign asks for it")
	_assert(int(stats.get("max_bow_tower_count", 0)) >= 1, "Ari should make tower/ranged prep matter when the sign asks for it")
	_assert(float(stats.get("hunger", 100.0)) < 85.0, "hunger should matter without dominating a competent four-day run")
	_assert(not bool(stats.get("flying_seen", false)), "flying should not appear during the first four nights")
	_assert(int(stats.get("max_night_enemies", 99)) <= 7, "night simulation should respect the readable enemy cap")
	root.remove_child(world)
	world.queue_free()
	await process_frame
	var absolute_save_path := ProjectSettings.globalize_path(test_save_path)
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(absolute_save_path)


func _test_combat_survival_balance_v1_scenarios() -> void:
	var scenarios := [
		{
			"id": "survive_until_morning",
			"seed": 191,
			"preset_key": 11,
			"sign": "just survive until morning",
		},
		{
			"id": "sword_killer",
			"seed": 271,
			"preset_key": 9,
			"sign": "do not hide, focus on killing enemies",
		},
		{
			"id": "lifesteal_smith",
			"seed": 353,
			"preset_key": 12,
			"sign": "make a sword that gives you life when they die",
		},
		{
			"id": "heavy_armor_thorns",
			"seed": 419,
			"preset_key": 10,
			"sign": "heavy armor and thorns",
		},
		{
			"id": "tower_arrows",
			"seed": 557,
			"preset_key": 5,
			"sign": "build a mountain where arrows rain",
		},
		{
			"id": "aura_circle",
			"seed": 631,
			"preset_key": 2,
			"sign": "the circle should eat the dead",
		},
	]
	var results := {}
	for scenario in scenarios:
		var stats: Dictionary = await _run_combat_survival_scenario(
			str(scenario.get("id", "")),
			int(scenario.get("seed", 1)),
			int(scenario.get("preset_key", 0)),
			str(scenario.get("sign", ""))
		)
		results[str(scenario.get("id", ""))] = stats
		_print_combat_survival_stats(stats)

	var survival: Dictionary = results.get("survive_until_morning", {})
	_assert(int(survival.get("day", 1)) >= 3, "survival-until-morning sign should last beyond the first night")
	_assert(int(survival.get("dawn_vanished_total", 0)) > 0, "survival-until-morning sign should benefit from dawn clearing enemies")

	var killer: Dictionary = results.get("sword_killer", {})
	_assert(int(killer.get("day", 1)) >= 3, "direct-killing build should remain viable past the first night")
	_assert(int(killer.get("melee_hits", 0)) > 0, "direct-killing build should visibly engage enemies in melee")

	var lifesteal: Dictionary = results.get("lifesteal_smith", {})
	_assert(int(lifesteal.get("ore_mined_events", 0)) > 0, "life-from-sword sign should pursue ore")
	_assert(int(lifesteal.get("max_sword_tier", 0)) >= 1, "life-from-sword sign should reach at least a crude sword")
	_assert(int(lifesteal.get("melee_hits", 0)) > 0, "life-from-sword sign should eventually risk melee to use the blade")
	_assert(float(lifesteal.get("max_regen_healed", 0.0)) <= 6.0, "regen-on-kill should reward aggression without erasing damage")

	var armor: Dictionary = results.get("heavy_armor_thorns", {})
	_assert(bool(armor.get("alive", false)), "heavy armor/thorns sign should survive the balance scenario instead of dying after building the themed defense")
	_assert(int(armor.get("day", 1)) >= 3, "heavy armor/thorns sign should remain viable past the first night")
	_assert(float(armor.get("final_armor", 0.0)) >= 0.10, "heavy armor build should expose meaningful armor")
	_assert(int(armor.get("max_thorn_totem_count", 0)) >= 1 or int(armor.get("ari_damaged_events", 0)) <= 6, "armor/thorns build should either prepare thorns or visibly reduce punishment")

	var tower: Dictionary = results.get("tower_arrows", {})
	_assert(int(tower.get("max_bow_tower_count", 0)) >= 1, "tower sign should build a tower")
	_assert(int(tower.get("ranged_hits", 0)) > 0 or int(tower.get("day", 1)) >= 3, "tower sign should either fire shots or buy survival time")

	var aura: Dictionary = results.get("aura_circle", {})
	_assert(int(aura.get("max_aura_orb_count", 0)) >= 1, "aura sign should place an aura orb")
	_assert(int(aura.get("aura_damage_events", 0)) > 0 or int(aura.get("day", 1)) >= 3, "aura sign should either damage enemies or buy survival time")


func _run_combat_survival_scenario(id: String, scenario_seed: int, preset_key: int, sign: String) -> Dictionary:
	seed(scenario_seed)
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for combat/survival scenario %s" % id)
	if world_scene == null:
		return {}
	var test_save_path := "user://combat_survival_balance_%s.json" % id
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	_isolate_balance_progression(world, test_save_path)
	world.call("start_run")
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")
	world.call("select_run_build_preset", preset_key, false)
	world.call("commit_sign", sign)
	var stats: Dictionary = await _simulate_balance_seconds(world, 312.0, 0.30)
	stats["scenario"] = id
	stats["sign"] = sign
	stats["preset_key"] = preset_key
	stats["current_job"] = str(world.get("current_job"))
	stats["latest_thought"] = str(world.get("latest_thought"))
	root.remove_child(world)
	world.queue_free()
	await process_frame
	var absolute_save_path := ProjectSettings.globalize_path(test_save_path)
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(absolute_save_path)
	return stats


func _print_combat_survival_stats(stats: Dictionary) -> void:
	print("Combat/survival sim %s: day=%d phase=%s alive=%s hp=%.1f hunger=%.1f food=%d stone=%d ore=%d sword=%d armor=%.2f kills=%d melee=%d ranged=%d aura=%d dawn_vanished=%d smithed=%d walls=%d aura_orbs=%d towers=%d thorns=%d" % [
		str(stats.get("scenario", "")),
		int(stats.get("day", 1)),
		str(stats.get("phase", "")),
		str(stats.get("alive", false)),
		float(stats.get("hp", 0.0)),
		float(stats.get("hunger", 0.0)),
		int(stats.get("food", 0)),
		int(stats.get("stone", 0)),
		int(stats.get("ore", 0)),
		int(stats.get("max_sword_tier", 0)),
		float(stats.get("final_armor", 0.0)),
		int(stats.get("enemy_kills", 0)),
		int(stats.get("melee_hits", 0)),
		int(stats.get("ranged_hits", 0)),
		int(stats.get("aura_damage_events", 0)),
		int(stats.get("dawn_vanished_total", 0)),
		int(stats.get("sword_smithed_events", 0)),
		int(stats.get("max_wall_count", 0)),
		int(stats.get("max_aura_orb_count", 0)),
		int(stats.get("max_bow_tower_count", 0)),
		int(stats.get("max_thorn_totem_count", 0)),
	])


func _base_mind_context(overrides: Dictionary) -> Dictionary:
	var context := {
		"is_night": false,
		"phase": "midday",
		"time_left": 25.0,
		"night_close": false,
		"stone": 20,
		"wall_cost": 4,
		"aura_orb_cost": 5,
		"spike_trap_cost": 5,
		"bow_tower_cost": 6,
		"tar_pit_cost": 4,
		"fear_lantern_cost": 5,
		"decoy_idol_cost": 4,
		"thorn_totem_cost": 5,
		"repair_bench_cost": 6,
		"storm_rod_cost": 7,
		"wall_count": 0,
		"aura_orb_count": 0,
		"spike_trap_count": 0,
		"bow_tower_count": 0,
		"tar_pit_count": 0,
		"fear_lantern_count": 0,
		"decoy_idol_count": 0,
		"thorn_totem_count": 0,
		"repair_bench_count": 0,
		"storm_rod_count": 0,
		"damaged_structure_count": 0,
		"lowest_structure_hp_ratio": 1.0,
		"combat_stats": {"combat_level": 0.0},
		"needs": {"hunger": 28.0, "stamina": 92.0, "fear": 18.0},
		"food": 2,
		"lesson_count": 0,
		"lesson_priority_bias": {},
		"priority_hints": {},
		"run_build": {"points": {}},
		"current_job": "wait_or_idle",
	}
	for key in overrides.keys():
		context[key] = overrides[key]
	return context


func _load_json_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}


func _isolate_balance_progression(world: World, save_path: String) -> void:
	var progression = world.get("permanent_progression")
	if progression == null:
		return
	progression.set("save_path", save_path)
	var zero_upgrades := {}
	var state: Dictionary = progression.call("get_state")
	for row in state.get("upgrade_rows", []):
		if typeof(row) == TYPE_DICTIONARY:
			zero_upgrades[str(row.get("id", ""))] = 0
	progression.set("time_points", 0)
	progression.set("deaths", 0)
	progression.set("best_day", 1)
	progression.set("upgrades", zero_upgrades)


func _simulate_balance_seconds(world: World, seconds: float, step_seconds: float) -> Dictionary:
	var elapsed := 0.0
	var frame_count := 0
	var trace_balance := OS.get_environment("ARI_TRACE_BALANCE").strip_edges() == "1"
	var trace_interval_frames := maxi(1, int(round(8.0 / maxf(step_seconds, 0.001))))
	var max_night_enemies := 0
	var max_wall_count := 0
	var max_aura_orb_count := 0
	var max_bow_tower_count := 0
	var max_thorn_totem_count := 0
	var max_storm_rod_count := 0
	var max_sword_tier := 0
	var max_ore := 0
	var min_hp := INF
	var flying_seen := false
	while elapsed < seconds:
		var ari = world.get("ari")
		if ari == null or not bool(ari.call("is_alive")):
			break
		min_hp = minf(min_hp, float(ari.get("hp")))
		var step := minf(step_seconds, seconds - elapsed)
		world.call("_process", step)
		for structure in world.call("get_structures"):
			if is_instance_valid(structure) and structure.has_method("_process"):
				structure.call("_process", step)
		for enemy in world.call("get_enemies"):
			if is_instance_valid(enemy) and enemy.has_method("_process"):
				enemy.call("_process", step)
		var day_night = world.get("day_night")
		if day_night != null and bool(day_night.call("is_night")):
			max_night_enemies = maxi(max_night_enemies, int(world.call("get_enemy_count")))
		max_wall_count = maxi(max_wall_count, int(world.call("get_wall_count")))
		max_aura_orb_count = maxi(max_aura_orb_count, int(world.call("get_aura_orb_count")))
		max_bow_tower_count = maxi(max_bow_tower_count, int(world.call("get_bow_tower_count")))
		max_thorn_totem_count = maxi(max_thorn_totem_count, int(world.call("get_thorn_totem_count")))
		max_storm_rod_count = maxi(max_storm_rod_count, int(world.call("get_storm_rod_count")))
		if world.has_method("_current_sword_tier"):
			max_sword_tier = maxi(max_sword_tier, int(world.call("_current_sword_tier")))
		var resource_system = world.get("resource_system")
		if resource_system != null and resource_system.has_method("get_ore"):
			max_ore = maxi(max_ore, int(resource_system.call("get_ore")))
		var counts: Dictionary = world.call("get_enemy_type_counts")
		flying_seen = flying_seen or int(counts.get("flying", 0)) > 0
		if trace_balance and frame_count % trace_interval_frames == 0:
			_trace_balance_step(world, elapsed, counts)
		elapsed += step
		frame_count += 1
		if frame_count % 120 == 0:
			await process_frame
	var ari = world.get("ari")
	var needs: Dictionary = ari.call("get_needs") if ari != null else {}
	var resource_system = world.get("resource_system")
	var day_night = world.get("day_night")
	var ari_memory = world.get("ari_memory")
	var event_summary := _summarize_balance_events(ari_memory.call("get_recent_events", 300) if ari_memory != null else [])
	return {
		"alive": ari != null and bool(ari.call("is_alive")),
		"hp": float(ari.get("hp")) if ari != null else 0.0,
		"min_hp": min_hp if min_hp < INF else 0.0,
		"hunger": float(needs.get("hunger", 100.0)),
		"day": int(day_night.get("day")) if day_night != null else 1,
		"phase": str(day_night.get("phase")) if day_night != null else "",
		"food": int(resource_system.call("get_food")) if resource_system != null else 0,
		"stone": int(resource_system.call("get_stone")) if resource_system != null else 0,
		"ore": int(resource_system.call("get_ore")) if resource_system != null and resource_system.has_method("get_ore") else 0,
		"structures": int(world.call("get_structures").size()),
		"wall_count": int(world.call("get_wall_count")),
		"aura_orb_count": int(world.call("get_aura_orb_count")),
		"bow_tower_count": int(world.call("get_bow_tower_count")),
		"max_wall_count": max_wall_count,
		"max_aura_orb_count": max_aura_orb_count,
		"max_bow_tower_count": max_bow_tower_count,
		"max_thorn_totem_count": max_thorn_totem_count,
		"max_storm_rod_count": max_storm_rod_count,
		"max_sword_tier": max_sword_tier,
		"max_ore": max_ore,
		"final_armor": float(ari.get("armor")) if ari != null else 0.0,
		"enemies": int(world.call("get_enemy_count")),
		"flying_seen": flying_seen,
		"max_night_enemies": max_night_enemies,
		"event_counts": event_summary.get("event_counts", {}),
		"enemy_kills": int(event_summary.get("enemy_kills", 0)),
		"melee_hits": int(event_summary.get("melee_hits", 0)),
		"ranged_hits": int(event_summary.get("ranged_hits", 0)),
		"aura_damage_events": int(event_summary.get("aura_damage_events", 0)),
		"dawn_clear_events": int(event_summary.get("dawn_clear_events", 0)),
		"dawn_vanished_total": int(event_summary.get("dawn_vanished_total", 0)),
		"sword_smithed_events": int(event_summary.get("sword_smithed_events", 0)),
		"ore_mined_events": int(event_summary.get("ore_mined_events", 0)),
		"ari_damaged_events": int(event_summary.get("ari_damaged_events", 0)),
		"max_regen_healed": float(event_summary.get("max_regen_healed", 0.0)),
		"total_regen_healed": float(event_summary.get("total_regen_healed", 0.0)),
	}


func _trace_balance_step(world: World, elapsed: float, counts: Dictionary) -> void:
	var ari = world.get("ari")
	var resource_system = world.get("resource_system")
	var day_night = world.get("day_night")
	var structures := []
	for structure in world.call("get_structures"):
		if not is_instance_valid(structure):
			continue
		var structure_type := str(structure.get("structure_type"))
		var hp := int(round(float(structure.get("hp"))))
		var max_hp := int(round(float(structure.get("max_hp"))))
		structures.append("%s:%d/%d" % [structure_type, hp, max_hp])
	print("BALANCE t=%.1f day=%d phase=%s hp=%.1f job=%s reason=%s enemies=%s stone=%d food=%d walls=%d aura=%d tower=%d structs=%s" % [
		elapsed,
		int(day_night.get("day")) if day_night != null else 1,
		str(day_night.get("phase")) if day_night != null else "",
		float(ari.get("hp")) if ari != null else 0.0,
		str(ari.call("get_current_job")) if ari != null else "",
		str(ari.call("get_job_reason")) if ari != null else "",
		JSON.stringify(counts),
		int(resource_system.call("get_stone")) if resource_system != null else 0,
		int(resource_system.call("get_food")) if resource_system != null else 0,
		int(world.call("get_wall_count")),
		int(world.call("get_aura_orb_count")),
		int(world.call("get_bow_tower_count")),
		",".join(structures),
	])


func _summarize_balance_events(events: Array) -> Dictionary:
	var event_counts := {}
	var enemy_kills := 0
	var melee_hits := 0
	var ranged_hits := 0
	var aura_damage_events := 0
	var dawn_clear_events := 0
	var dawn_vanished_total := 0
	var sword_smithed_events := 0
	var ore_mined_events := 0
	var ari_damaged_events := 0
	var max_regen_healed := 0.0
	var total_regen_healed := 0.0
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var event_type := str(event.get("type", ""))
		event_counts[event_type] = int(event_counts.get(event_type, 0)) + 1
		match event_type:
			"enemy_killed":
				enemy_kills += 1
				var healed := maxf(float(event.get("regen_healed", 0.0)), 0.0)
				total_regen_healed += healed
				max_regen_healed = maxf(max_regen_healed, healed)
			"ari_melee_hit":
				melee_hits += 1
			"ari_ranged_hit":
				ranged_hits += 1
			"aura_damage_success":
				aura_damage_events += 1
			"dawn_enemies_vanished":
				dawn_clear_events += 1
				dawn_vanished_total += maxi(int(event.get("count", 0)), 0)
			"sword_smithed":
				sword_smithed_events += 1
			"ore_mined":
				ore_mined_events += 1
			"ari_damaged":
				ari_damaged_events += 1
	return {
		"event_counts": event_counts,
		"enemy_kills": enemy_kills,
		"melee_hits": melee_hits,
		"ranged_hits": ranged_hits,
		"aura_damage_events": aura_damage_events,
		"dawn_clear_events": dawn_clear_events,
		"dawn_vanished_total": dawn_vanished_total,
		"sword_smithed_events": sword_smithed_events,
		"ore_mined_events": ore_mined_events,
		"ari_damaged_events": ari_damaged_events,
		"max_regen_healed": max_regen_healed,
		"total_regen_healed": total_regen_healed,
	}


func _test_memory_records_events() -> void:
	var memory = AriMemoryScript.new()
	memory.record_event("ari_damaged", {"day": 2, "phase": "night", "hp": 40})
	memory.record_snapshot({"ari": {"fear": 72}, "phase": "night"})

	var events = memory.get_recent_events()
	var snapshots = memory.get_recent_snapshots()
	_assert(events.size() == 1, "memory should store one event")
	_assert(events[0].get("type", "") == "ari_damaged", "event should keep its type")
	_assert(events[0].get("phase", "") == "night", "event should preserve provided phase")
	_assert(snapshots.size() == 1, "memory should store one snapshot")


func _test_chronicle_validates_scribe_notes() -> void:
	var chronicle = ChronicleScript.new()
	chronicle.add_scribe_note({
		"t_start": 1,
		"t_end": 2,
		"note": "Ari noticed the wall cracking.",
		"tags": ["wall", "danger", "extra", "extra2", "extra3", "extra4", "extra5", "extra6", "extra7"],
		"facts": ["A wall is cracked.", "Flying enemy crossed cover.", "extra", "extra2", "extra3", "extra4", "extra5", "extra6", "extra7"],
		"actions": [
			{"action": "build_wall", "status": "in_progress", "reason": "Ari tried ordinary cover."},
			{"action_id": "build_storm_rod", "status": "planned", "reason": "Wings need a sky answer."},
			"bad",
		],
		"dangers": [
			{"type": "flying", "distance": 96.0, "severity": 2.0},
			{"type": "wolf", "distance": -20.0, "severity": -1.0},
			"bad",
		],
		"world_changes": ["first_flying_enemy_seen", "north_wall_damaged", "extra", "extra2", "extra3", "extra4", "extra5"],
		"priority_hints": {"build_storm_rod": 0.8, "spawn_dragon": 0.9},
		"confidence": 2.0,
		"source": "remote_server",
		"failure_reason": "too long but harmless",
		"salience": 2.0,
	})

	var note = chronicle.get_today_scribe_notes()[0]
	_assert(note["tags"].size() == 8, "chronicle should cap scribe note tags")
	_assert(note["facts"].size() == 8, "chronicle should cap scribe facts")
	_assert(note["actions"].size() == 2, "chronicle should keep structured scribe actions and drop malformed entries")
	_assert(note["actions"][0].get("action", "") == "build_wall", "chronicle should normalize action keys")
	_assert(note["dangers"].size() == 2, "chronicle should keep structured scribe dangers and drop malformed entries")
	_assert(float(note["dangers"][0].get("severity", 0.0)) == 1.0, "chronicle should clamp danger severity")
	_assert(float(note["dangers"][1].get("distance", -1.0)) == 0.0, "chronicle should clamp danger distance")
	_assert(note["world_changes"].size() == 6, "chronicle should cap world changes")
	_assert(note["priority_hints"].has("build_storm_rod"), "chronicle should preserve validated priority hints for reflection")
	_assert(float(note["confidence"]) == 1.0, "chronicle should clamp scribe confidence")
	_assert(note["source"] == "remote_server", "chronicle should preserve scribe source")
	_assert(note["salience"] == 1.0, "chronicle should clamp salience")


func _test_scribe_pipeline(bridge: AIBridge) -> void:
	var memory = AriMemoryScript.new()
	var chronicle = ChronicleScript.new()
	var scribe = ScribeSystemScript.new()
	scribe.ai_bridge = bridge

	memory.record_event("wall_destroyed", {"phase": "night"})
	memory.record_snapshot({"ari": {"fear": 83, "current_action": "hiding"}, "phase": "night"})

	var state := {"done": false}
	scribe.create_scribe_note_from_recent_memory(memory, chronicle, {"phase": "night", "ari": {"fear": 83, "current_action": "hiding"}}, func(note: Dictionary) -> void:
		_assert(note.get("note", "").contains("wall destroyed"), "local scribe should mention the last event in readable form")
		_assert(note.get("tags", []).has("fear_high"), "local scribe should tag high fear")
		_assert(chronicle.get_today_scribe_notes().size() == 1, "scribe should add note to chronicle")
		state["done"] = true
	)
	await process_frame
	_assert(state["done"], "scribe callback should run in local_stub mode")


func _test_local_scribe_keeps_recent_salient_flying_snapshot(bridge: AIBridge) -> void:
	var note: Dictionary = bridge.call("_local_stub_scribe", {
		"recent_events": [{"type": "phase_changed"}],
		"snapshots": [
			{
				"trigger": "enemy_spawned",
				"salience": 0.75,
				"ari": {
					"current_action": "moving_to_build_site",
					"current_reason": "flying enemy crossed the wall",
					"fear": 63.0,
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
					"fear": 34.0,
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
	_assert(_array_has_dictionary_value(note.get("dangers", []), "type", "flying"), "local scribe should keep recent flying danger even if latest snapshot is quiet")
	_assert(note.get("tags", []).has("danger:flying"), "local scribe should tag recent flying danger")
	_assert(note.get("facts", []).has("Flying enemies were present; ordinary walls may not solve them."), "local scribe should preserve recent flying fact")
	_assert(note.get("world_changes", []).has("first_flying_enemy_seen"), "local scribe should preserve salient flying world change")
	_assert(note.get("priority_hints", {}).has("build_storm_rod"), "local scribe should emit anti-air priority hints from recent salient flying evidence")


func _test_local_scribe_preserves_recent_flying_hints_when_latest_snapshot_differs(bridge: AIBridge) -> void:
	var note: Dictionary = bridge.call("_local_stub_scribe", {
		"recent_events": [{"type": "structure_damaged"}],
		"snapshots": [
			{
				"snapshot_id": "snap_flying_01",
				"trigger": "enemy_spawned",
				"salience": 0.1,
				"ari": {
					"current_action": "moving_to_build_site",
					"current_reason": "flying enemy crossed the wall",
					"fear": 63.0,
				},
				"plan": {"next_action": "build_storm_rod"},
				"world": {
					"enemies": {"count": 1, "types": {"flying": 1}},
					"nearest_danger": {"type": "flying", "distance": 72.0},
					"notable_changes": ["first_flying_enemy_seen"],
				},
			},
			{
				"snapshot_id": "snap_lantern_02",
				"trigger": "structure_damaged",
				"salience": 10.0,
				"ari": {
					"current_action": "holding_fear_lantern_light",
					"current_reason": "Hold the warm light while fear rises",
					"fear": 71.0,
				},
				"plan": {"next_action": "mine_stone"},
				"world": {
					"enemies": {"count": 1, "types": {"zombie": 1}},
					"nearest_danger": {"type": "zombie", "distance": 317.0},
					"notable_changes": ["structure_damaged"],
				},
			},
		],
		"active_plan": {"next_action": "mine_stone"},
	})
	_assert(float(note.get("priority_hints", {}).get("build_storm_rod", 0.0)) >= 0.55, "local scribe should preserve anti-air priority from recent flying evidence even when latest snapshot differs")
	_assert(note.get("tags", []).has("danger:flying"), "local scribe should tag preserved flying evidence")
	_assert(note.get("facts", []).has("Flying enemies were present; ordinary walls may not solve them."), "local scribe should keep the flying fact from recent evidence")
	_assert(note.get("world_changes", []).has("first_flying_enemy_seen"), "local scribe should preserve flying world change from recent evidence")
	_assert(note.get("evidence_ids", []).has("snap_flying_01"), "local scribe should retain the evidence id that supports anti-air hints")


func _test_reflection_and_sleep_pipeline(bridge: AIBridge) -> void:
	var chronicle = ChronicleScript.new()
	var lesson_book = LessonBookScript.new()
	var reflection = ReflectionSystemScript.new()
	var sleep = SleepConsolidationScript.new()
	reflection.ai_bridge = bridge
	sleep.ai_bridge = bridge

	chronicle.add_scribe_note({"note": "Ari survived by preparing early.", "tags": ["prepare"], "salience": 0.8})

	var reflection_state := {"done": false}
	reflection.request_library_reflection({"day": 1, "current_sign": "prepare before night"}, chronicle, lesson_book, func(note: Dictionary) -> void:
		_assert(note.get("title", "") != "", "reflection should create a titled note")
		_assert(lesson_book.get_all_notes().size() == 1, "reflection should add note to lesson book")
		reflection_state["done"] = true
	)
	await process_frame
	_assert(reflection_state["done"], "reflection callback should run in local_stub mode")

	var sleep_state := {"done": false}
	sleep.request_sleep_plan({"day": 1}, lesson_book, func(plan: Dictionary) -> void:
		_assert(plan.get("tomorrow_focus", []).has("prepare"), "sleep plan should include prepare focus")
		_assert(plan.get("wake_thought", "") != "", "sleep plan should provide wake thought")
		sleep_state["done"] = true
	)
	await process_frame
	_assert(sleep_state["done"], "sleep callback should run in local_stub mode")


func _test_life_and_wisdom_pipeline(bridge: AIBridge) -> void:
	var archive = LifeArchiveScript.new()
	var insights = PermanentInsightBookScript.new()
	var wisdom = WisdomSynthesizerScript.new()
	wisdom.ai_bridge = bridge

	var summary_state := {"summary": {}, "done": false}
	bridge.request_life_summary({"life_id": "test-life", "result": "died", "survived_days": 1}, func(result: Dictionary) -> void:
		summary_state["summary"] = result
		summary_state["done"] = true
	)
	await process_frame
	_assert(summary_state["done"], "life summary callback should run in local_stub mode")
	var life_summary: Dictionary = summary_state["summary"]
	var long_summary := ""
	for i in range(800):
		long_summary += "x"
	archive.add_life_summary({
		"life_id": "test-life",
		"result": "died",
		"survived_days": 1,
		"life_summary_markdown": life_summary.get("life_summary_markdown", ""),
		"candidate_insights": [{
			"title": "Prepare Before Night",
			"summary": long_summary,
			"conditions": ["dusk", "night", "extra", "extra2", "extra3", "extra4", "extra5", "extra6", "extra7", "extra8", "extra9", "extra10", "extra11"],
			"suggested_actions": ["prepare"],
			"confidence": 2.0,
		}],
		"next_life_hint": life_summary.get("next_life_hint", ""),
	})
	insights.add_or_merge_insight(life_summary.get("candidate_insights", [])[0])
	insights.add_or_merge_insight(life_summary.get("candidate_insights", [])[0])
	_assert(not insights.update_matching_insight({"title": "Unknown New Advice", "summary": "Should not be added."}), "updated insights should not create unmatched permanent insights")

	_assert(archive.get_all_life_summaries().size() == 1, "life archive should store summary")
	_assert(archive.get_all_life_summaries()[0].get("candidate_insights", [])[0].get("summary", "").length() == 500, "life archive should cap candidate insight summary length")
	_assert(archive.get_all_life_summaries()[0].get("candidate_insights", [])[0].get("confidence", 0.0) == 1.0, "life archive should clamp candidate insight confidence")
	_assert(insights.get_all_insights().size() == 1, "insight book should merge duplicate titles")
	_assert(insights.get_all_insights()[0].get("times_confirmed", 0) == 2, "insight merge should increase confirmation count")

	var wisdom_state := {"done": false}
	wisdom.request_background_synthesis(archive, insights, func(result: Dictionary) -> void:
		_assert(result.has("new_insights"), "wisdom synthesis should return a validated result")
		wisdom_state["done"] = true
	)
	await process_frame
	_assert(wisdom_state["done"], "wisdom callback should run in local_stub mode")
