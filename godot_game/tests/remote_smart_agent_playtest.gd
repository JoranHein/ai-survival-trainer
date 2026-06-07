extends SceneTree

const WorldScene = preload("res://scenes/world/World.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var gateway_url := OS.get_environment("ARI_TEST_GATEWAY_URL").strip_edges()
	if gateway_url == "":
		push_error("ARI_TEST_GATEWAY_URL is required for remote smart agent playtest.")
		quit(2)
		return

	var scenarios := [
		{
			"id": "remote_tower_arrows",
			"seed": 2201,
			"preset": 5,
			"sign": "build a mountain where arrows rain",
			"duration": 340.0,
			"expect": {"min_tower": 1, "min_ranged_or_day": 3, "min_structured_scribe": 1, "min_reflection": 1, "must_survive": true},
		},
		{
			"id": "remote_light_and_mud",
			"seed": 2267,
			"preset": 7,
			"sign": "make a light circle and slow mud before teeth arrive",
			"duration": 360.0,
			"expect": {"min_aura": 1, "min_tar_pit": 1, "min_structured_scribe": 1, "min_reflection": 1, "must_survive": true},
		},
		{
			"id": "remote_storm_wings",
			"seed": 2309,
			"preset": 5,
			"sign": "do not trust walls against wings",
			"duration": 360.0,
			"expect": {"min_storm": 1, "min_structured_scribe": 1, "min_reflection": 1, "min_reflection_doctrine": 1, "must_survive": true},
			"pre_spawn": ["flying"],
		},
		{
			"id": "remote_wall_habit_learns_wings",
			"seed": 2347,
			"preset": 5,
			"sign": "stone walls are safety",
			"duration": 380.0,
			"expect": {"min_storm": 1, "min_final_storm": 1, "min_tower": 1, "min_ranged_or_day": 3, "min_structured_scribe": 1, "min_reflection": 1, "min_reflection_doctrine": 1, "min_doctrine_plan": 1, "must_survive": true},
			"pre_spawn": ["flying"],
		},
		{
			"id": "remote_ore_blade",
			"seed": 2381,
			"preset": 12,
			"sign": "ore should become a blade before the dead arrive",
			"duration": 360.0,
			"expect": {"min_sword_tier": 1, "min_melee": 1, "min_structured_scribe": 1, "min_reflection": 1, "must_survive": true},
		},
	]

	var scenario_filter := OS.get_environment("ARI_REMOTE_SCENARIO").strip_edges()
	var ran_count := 0
	for scenario in scenarios:
		if scenario_filter != "" and str(scenario.get("id", "")) != scenario_filter:
			continue
		ran_count += 1
		var stats: Dictionary = await _run_remote_scenario(scenario, gateway_url)
		_print_stats(stats)
		_check_expectations(stats, scenario.get("expect", {}))

	if failures.is_empty():
		print("Remote smart Ari agent playtest passed for %d prompts." % ran_count)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _run_remote_scenario(scenario: Dictionary, gateway_url: String) -> Dictionary:
	var scenario_seed := int(scenario.get("seed", 1))
	var test_save_path := "user://remote_smart_ari_%s.json" % str(scenario.get("id", "scenario"))
	var world: World = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	_isolate_progression(world, test_save_path)
	seed(scenario_seed)
	world.call("start_run")
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		_configure_remote_bridge(bridge, gateway_url)
	var preset_key := int(scenario.get("preset", 0))
	if preset_key > 0:
		world.call("select_run_build_preset", preset_key, false)
	for enemy_type in scenario.get("pre_spawn", []):
		var arena: Rect2 = world.call("get_arena_rect")
		world.call("_spawn_enemy", arena.get_center() + Vector2(190.0, -90.0), str(enemy_type))
	world.call("commit_sign", str(scenario.get("sign", "")))
	var stats: Dictionary = await _simulate(world, float(scenario.get("duration", 320.0)), 0.25, str(scenario.get("id", "")))
	stats["scenario"] = str(scenario.get("id", ""))
	stats["sign"] = str(scenario.get("sign", ""))
	stats["agent_source"] = str(world.get("agent_plan").get("source", ""))
	stats["ai_status"] = str(world.get("ai_status"))
	stats["agent_next_action"] = _agent_next_action(world.get("agent_plan"))
	root.remove_child(world)
	world.queue_free()
	await process_frame
	var absolute_save_path := ProjectSettings.globalize_path(test_save_path)
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(absolute_save_path)
	return stats


func _configure_remote_bridge(bridge: AIBridge, gateway_url: String) -> void:
	bridge.force_provider_mode("remote_server")
	var config: Dictionary = bridge.get("config")
	config["enabled"] = true
	config["provider_mode"] = "remote_server"
	config["server_base_url"] = gateway_url
	config["deep_interpretation_url"] = ""
	config["agent_plan_url"] = ""
	config["fast_thought_url"] = ""
	config["timeout_seconds"] = 5.0
	config["deep_interpretation_timeout_seconds"] = 5.0
	config["agent_plan_timeout_seconds"] = 5.0
	config["fast_prediction_timeout_seconds"] = 5.0
	config["background_timeout_seconds"] = 4.0
	config["scribe_timeout_seconds"] = 4.0
	config["library_reflection_timeout_seconds"] = 12.0
	config["enable_agent_plan"] = true
	config["enable_scribe"] = true
	config["enable_library_reflection"] = true
	config["enable_sleep_plan"] = false
	config["enable_life_summary"] = false
	config["enable_wisdom_synthesis"] = false
	bridge.set("config", config)


func _simulate(world: World, seconds: float, step_seconds: float, scenario_id := "") -> Dictionary:
	var elapsed := 0.0
	var frame_count := 0
	var trace_scenario := OS.get_environment("ARI_TRACE_SCENARIO").strip_edges()
	var trace := OS.get_environment("ARI_TRACE_REMOTE").strip_edges() == "1" and (trace_scenario == "" or trace_scenario == scenario_id)
	var next_trace_at := 0.0
	var max_counts := {
		"wall": 0,
		"aura_orb": 0,
		"bow_tower": 0,
		"tar_pit": 0,
		"storm_rod": 0,
	}
	var max_sword_tier := 0
	var min_hp := INF
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
		max_counts["wall"] = maxi(int(max_counts["wall"]), int(world.call("get_wall_count")))
		max_counts["aura_orb"] = maxi(int(max_counts["aura_orb"]), int(world.call("get_aura_orb_count")))
		max_counts["bow_tower"] = maxi(int(max_counts["bow_tower"]), int(world.call("get_bow_tower_count")))
		max_counts["tar_pit"] = maxi(int(max_counts["tar_pit"]), int(world.call("get_tar_pit_count")))
		max_counts["storm_rod"] = maxi(int(max_counts["storm_rod"]), int(world.call("get_storm_rod_count")))
		if world.has_method("_current_sword_tier"):
			max_sword_tier = maxi(max_sword_tier, int(world.call("_current_sword_tier")))
		if trace and elapsed >= next_trace_at:
			_print_trace(world, elapsed)
			next_trace_at += 8.0
		elapsed += step
		frame_count += 1
		if frame_count % 8 == 0:
			await process_frame
			await create_timer(0.01).timeout
			await _settle_remote_ai(world, 0.25)

	var ari = world.get("ari")
	var day_night = world.get("day_night")
	var resource_system = world.get("resource_system")
	var ari_memory = world.get("ari_memory")
	var chronicle = world.get("chronicle")
	var lesson_book = world.get("lesson_book")
	var combat_stats: Dictionary = ari.call("get_combat_stats") if ari != null and ari.has_method("get_combat_stats") else {}
	var event_summary := _summarize_events(ari_memory.call("get_recent_events", 300) if ari_memory != null else [])
	var scribe_notes: Array = chronicle.call("get_lifetime_scribe_notes") if chronicle != null and chronicle.has_method("get_lifetime_scribe_notes") else []
	var lesson_notes: Array = lesson_book.call("get_all_notes") if lesson_book != null and lesson_book.has_method("get_all_notes") else []
	return {
		"alive": ari != null and bool(ari.call("is_alive")),
		"hp": float(ari.get("hp")) if ari != null else 0.0,
		"min_hp": min_hp if min_hp < INF else 0.0,
		"day": int(day_night.get("day")) if day_night != null else 1,
		"phase": str(day_night.get("phase")) if day_night != null else "",
		"enemy_count": int(world.call("get_enemy_count")) if world.has_method("get_enemy_count") else 0,
		"wall_count": int(world.call("get_wall_count")),
		"aura_orb_count": int(world.call("get_aura_orb_count")),
		"bow_tower_count": int(world.call("get_bow_tower_count")),
		"tar_pit_count": int(world.call("get_tar_pit_count")),
		"storm_rod_count": int(world.call("get_storm_rod_count")),
		"stone": int(resource_system.call("get_stone")) if resource_system != null and resource_system.has_method("get_stone") else 0,
		"food": int(resource_system.call("get_food")) if resource_system != null and resource_system.has_method("get_food") else 0,
		"ore": int(resource_system.call("get_ore")) if resource_system != null and resource_system.has_method("get_ore") else 0,
		"combat_level": float(combat_stats.get("combat_level", 0.0)),
		"damage_bonus": float(combat_stats.get("damage_bonus", 0.0)),
		"defense_training": float(combat_stats.get("defense_training", 0.0)),
		"max_wall_count": int(max_counts["wall"]),
		"max_aura_orb_count": int(max_counts["aura_orb"]),
		"max_bow_tower_count": int(max_counts["bow_tower"]),
		"max_tar_pit_count": int(max_counts["tar_pit"]),
		"max_storm_rod_count": int(max_counts["storm_rod"]),
		"max_sword_tier": max_sword_tier,
		"enemy_kills": int(event_summary.get("enemy_kills", 0)),
		"ari_damage_events": int(event_summary.get("ari_damage_events", 0)),
		"structure_damage_events": int(event_summary.get("structure_damage_events", 0)),
		"structure_destroyed_events": int(event_summary.get("structure_destroyed_events", 0)),
		"night_reflection_events": int(event_summary.get("night_reflection_events", 0)),
		"doctrine_plan_events": int(event_summary.get("doctrine_plan_events", 0)),
		"melee_hits": int(event_summary.get("melee_hits", 0)),
		"ranged_hits": int(event_summary.get("ranged_hits", 0)),
		"scribe_notes": scribe_notes.size(),
		"structured_scribe_notes": _structured_scribe_count(scribe_notes),
		"reflection_notes": lesson_notes.size(),
		"reflection_doctrine_notes": _reflection_doctrine_count(lesson_notes),
	}


func _settle_remote_ai(world: World, max_seconds: float) -> void:
	var waited := 0.0
	while waited < max_seconds and _has_remote_ai_in_flight(world):
		await process_frame
		await create_timer(0.02).timeout
		waited += 0.02


func _has_remote_ai_in_flight(world: World) -> bool:
	return bool(world.get("_agent_plan_request_in_flight")) \
		or bool(world.get("_observer_scribe_request_in_flight")) \
		or bool(world.get("_night_reflection_request_in_flight"))


func _print_trace(world: World, elapsed: float) -> void:
	var ari = world.get("ari")
	var day_night = world.get("day_night")
	var resource_system = world.get("resource_system")
	var job := str(ari.call("get_current_job")) if ari != null and ari.has_method("get_current_job") else ""
	var reason := str(ari.call("get_job_reason")) if ari != null and ari.has_method("get_job_reason") else ""
	print("TRACE t=%.1f day=%d phase=%s hp=%.1f job=%s reason=%s enemies=%s stone=%d walls=%d towers=%d storm=%d structs=%s" % [
		elapsed,
		int(day_night.get("day")) if day_night != null else 1,
		str(day_night.get("phase")) if day_night != null else "",
		float(ari.get("hp")) if ari != null else 0.0,
		job,
		reason,
		str(world.call("get_enemy_type_counts") if world.has_method("get_enemy_type_counts") else {}),
		int(resource_system.call("get_stone")) if resource_system != null and resource_system.has_method("get_stone") else 0,
		int(world.call("get_wall_count")),
		int(world.call("get_bow_tower_count")),
		int(world.call("get_storm_rod_count")),
		_structure_hp_summary(world),
	])


func _structure_hp_summary(world: World) -> String:
	var parts: Array[String] = []
	for structure in world.call("get_structures"):
		if not is_instance_valid(structure):
			continue
		var type := str(structure.get("structure_type"))
		var hp := float(structure.get("hp"))
		var max_hp := float(structure.get("max_hp"))
		parts.append("%s:%.0f/%.0f" % [type, hp, max_hp])
	return ",".join(parts)


func _summarize_events(events: Array) -> Dictionary:
	var enemy_kills := 0
	var ari_damage_events := 0
	var structure_damage_events := 0
	var structure_destroyed_events := 0
	var night_reflection_events := 0
	var doctrine_plan_events := 0
	var melee_hits := 0
	var ranged_hits := 0
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		match str(event.get("type", "")):
			"enemy_killed":
				enemy_kills += 1
			"ari_damaged", "ari_near_death", "near_death":
				ari_damage_events += 1
			"structure_damaged":
				structure_damage_events += 1
			"structure_destroyed":
				structure_destroyed_events += 1
			"night_reflection_created":
				night_reflection_events += 1
			"agent_plan_created":
				if bool(event.get("doctrine_influenced", false)):
					doctrine_plan_events += 1
			"ari_melee_hit":
				melee_hits += 1
			"ari_ranged_hit":
				ranged_hits += 1
	return {
		"enemy_kills": enemy_kills,
		"ari_damage_events": ari_damage_events,
		"structure_damage_events": structure_damage_events,
		"structure_destroyed_events": structure_destroyed_events,
		"night_reflection_events": night_reflection_events,
		"doctrine_plan_events": doctrine_plan_events,
		"melee_hits": melee_hits,
		"ranged_hits": ranged_hits,
	}


func _structured_scribe_count(notes: Array) -> int:
	var count := 0
	for note in notes:
		if typeof(note) != TYPE_DICTIONARY:
			continue
		if not note.get("facts", []).is_empty() and not note.get("actions", []).is_empty():
			count += 1
	return count


func _reflection_doctrine_count(notes: Array) -> int:
	var count := 0
	for note in notes:
		if typeof(note) != TYPE_DICTIONARY:
			continue
		if not note.get("doctrines", []).is_empty():
			count += 1
	return count


func _check_expectations(stats: Dictionary, expect) -> void:
	var id := str(stats.get("scenario", "scenario"))
	_assert(bool(stats.get("agent_source", "") == "remote_server"), id, "expected active plan from remote_server")
	if typeof(expect) != TYPE_DICTIONARY:
		return
	if bool(expect.get("must_survive", false)):
		_assert(bool(stats.get("alive", false)), id, "expected Ari to survive this coherent remote plan")
	if expect.has("min_tower"):
		_assert(int(stats.get("max_bow_tower_count", 0)) >= int(expect["min_tower"]), id, "expected bow tower count >= %d" % int(expect["min_tower"]))
	if expect.has("min_aura"):
		_assert(int(stats.get("max_aura_orb_count", 0)) >= int(expect["min_aura"]), id, "expected aura orb count >= %d" % int(expect["min_aura"]))
	if expect.has("min_tar_pit"):
		_assert(int(stats.get("max_tar_pit_count", 0)) >= int(expect["min_tar_pit"]), id, "expected tar pit count >= %d" % int(expect["min_tar_pit"]))
	if expect.has("min_storm"):
		_assert(int(stats.get("max_storm_rod_count", 0)) >= int(expect["min_storm"]), id, "expected storm rod count >= %d" % int(expect["min_storm"]))
	if expect.has("min_final_storm"):
		_assert(int(stats.get("storm_rod_count", 0)) >= int(expect["min_final_storm"]), id, "expected final storm rod count >= %d" % int(expect["min_final_storm"]))
	if expect.has("min_sword_tier"):
		_assert(int(stats.get("max_sword_tier", 0)) >= int(expect["min_sword_tier"]), id, "expected sword tier >= %d" % int(expect["min_sword_tier"]))
	if expect.has("min_melee"):
		_assert(int(stats.get("melee_hits", 0)) >= int(expect["min_melee"]), id, "expected melee hits >= %d" % int(expect["min_melee"]))
	if expect.has("min_ranged_or_day"):
		_assert(int(stats.get("ranged_hits", 0)) > 0 or int(stats.get("day", 1)) >= int(expect["min_ranged_or_day"]), id, "expected ranged hits or day >= %d" % int(expect["min_ranged_or_day"]))
	if expect.has("min_structured_scribe"):
		_assert(int(stats.get("structured_scribe_notes", 0)) >= int(expect["min_structured_scribe"]), id, "expected structured scribe notes >= %d" % int(expect["min_structured_scribe"]))
	if expect.has("min_reflection"):
		_assert(int(stats.get("reflection_notes", 0)) >= int(expect["min_reflection"]), id, "expected reflection notes >= %d" % int(expect["min_reflection"]))
	if expect.has("min_reflection_doctrine"):
		_assert(int(stats.get("reflection_doctrine_notes", 0)) >= int(expect["min_reflection_doctrine"]), id, "expected doctrine reflection notes >= %d" % int(expect["min_reflection_doctrine"]))
	if expect.has("min_doctrine_plan"):
		_assert(int(stats.get("doctrine_plan_events", 0)) >= int(expect["min_doctrine_plan"]), id, "expected doctrine-influenced planner events >= %d" % int(expect["min_doctrine_plan"]))


func _assert(condition: bool, id: String, message: String) -> void:
	if not condition:
		failures.append("%s: %s" % [id, message])


func _agent_next_action(agent_plan) -> String:
	if typeof(agent_plan) != TYPE_DICTIONARY:
		return ""
	var next_action = agent_plan.get("next_action", {})
	if typeof(next_action) != TYPE_DICTIONARY:
		return ""
	return str(next_action.get("action_id", ""))


func _print_stats(stats: Dictionary) -> void:
	print("Remote prompt %s: source=%s next=%s status=%s day=%d phase=%s alive=%s hp=%.1f min_hp=%.1f enemies=%d stone=%d food=%d combat=%.2f dmg_bonus=%.2f def=%.2f walls=%d/%d aura=%d/%d tower=%d/%d tar=%d/%d storm=%d/%d sword=%d kills=%d damaged=%d struct_hit=%d struct_dead=%d melee=%d ranged=%d scribe=%d structured=%d reflections=%d doctrine_reflections=%d doctrine_plans=%d sign=\"%s\"" % [
		str(stats.get("scenario", "")),
		str(stats.get("agent_source", "")),
		str(stats.get("agent_next_action", "")),
		str(stats.get("ai_status", "")),
		int(stats.get("day", 1)),
		str(stats.get("phase", "")),
		str(stats.get("alive", false)),
		float(stats.get("hp", 0.0)),
		float(stats.get("min_hp", 0.0)),
		int(stats.get("enemy_count", 0)),
		int(stats.get("stone", 0)),
		int(stats.get("food", 0)),
		float(stats.get("combat_level", 0.0)),
		float(stats.get("damage_bonus", 0.0)),
		float(stats.get("defense_training", 0.0)),
		int(stats.get("wall_count", 0)),
		int(stats.get("max_wall_count", 0)),
		int(stats.get("aura_orb_count", 0)),
		int(stats.get("max_aura_orb_count", 0)),
		int(stats.get("bow_tower_count", 0)),
		int(stats.get("max_bow_tower_count", 0)),
		int(stats.get("tar_pit_count", 0)),
		int(stats.get("max_tar_pit_count", 0)),
		int(stats.get("storm_rod_count", 0)),
		int(stats.get("max_storm_rod_count", 0)),
		int(stats.get("max_sword_tier", 0)),
		int(stats.get("enemy_kills", 0)),
		int(stats.get("ari_damage_events", 0)),
		int(stats.get("structure_damage_events", 0)),
		int(stats.get("structure_destroyed_events", 0)),
		int(stats.get("melee_hits", 0)),
		int(stats.get("ranged_hits", 0)),
		int(stats.get("scribe_notes", 0)),
		int(stats.get("structured_scribe_notes", 0)),
		int(stats.get("reflection_notes", 0)),
		int(stats.get("reflection_doctrine_notes", 0)),
		int(stats.get("doctrine_plan_events", 0)),
		str(stats.get("sign", "")),
	])


func _isolate_progression(world: World, save_path: String) -> void:
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
