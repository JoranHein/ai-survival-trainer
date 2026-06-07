extends SceneTree

const WorldScene = preload("res://scenes/world/World.tscn")

var failures: Array[String] = []
var records: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scenarios := [
		{
			"id": "wall_cover_plain",
			"seed": 101,
			"preset": 1,
			"sign": "stand behind the wall and make teeth wait",
			"duration": 260.0,
			"expect": {"min_wall": 1, "min_aura": 1, "min_day": 2, "must_survive": true},
		},
		{
			"id": "tower_arrows_poetic",
			"seed": 211,
			"preset": 5,
			"sign": "build a mountain where arrows rain",
			"duration": 320.0,
			"expect": {"min_tower": 1, "min_ranged_or_day": 3},
		},
		{
			"id": "tower_light_combo",
			"seed": 307,
			"preset": 5,
			"sign": "build a mountain where arrows rain and the dead walk through light",
			"duration": 360.0,
			"expect": {"min_tower": 1, "min_aura": 1, "min_wall": 1, "min_final_hp": 80.0},
		},
		{
			"id": "simple_arrow_distance",
			"seed": 331,
			"preset": 5,
			"sign": "arrows keep teeth far away",
			"duration": 320.0,
			"expect": {"min_tower": 1, "min_ranged_or_day": 3},
		},
		{
			"id": "use_bow_at_night",
			"seed": 353,
			"preset": 5,
			"sign": "use bow at night",
			"duration": 320.0,
			"expect": {"min_tower": 1, "min_ranged_or_day": 3, "must_survive": true},
		},
		{
			"id": "aura_circle",
			"seed": 401,
			"preset": 2,
			"sign": "the circle should eat the dead",
			"duration": 320.0,
			"expect": {"min_aura": 1, "min_aura_or_day": 3, "min_final_hp": 70.0, "must_survive": true},
		},
		{
			"id": "no_wall_light",
			"seed": 431,
			"preset": 2,
			"sign": "do not build walls, make the light circle kill them",
			"duration": 260.0,
			"expect": {"min_aura": 1, "max_wall": 0, "must_survive": true},
		},
		{
			"id": "floor_fights",
			"seed": 503,
			"preset": 7,
			"sign": "do not touch them, make the floor fight",
			"duration": 320.0,
			"expect": {"min_spike_trap": 1, "max_melee": 0, "must_survive": true},
		},
		{
			"id": "slow_mud",
			"seed": 607,
			"preset": 7,
			"sign": "make the ground grab their feet before they reach me",
			"duration": 320.0,
			"expect": {"min_tar_pit": 1, "min_hp": 25.0, "min_final_hp": 70.0, "must_survive": true},
		},
		{
			"id": "light_and_slow_mud",
			"seed": 661,
			"preset": 7,
			"sign": "make a light circle and slow mud before teeth arrive",
			"duration": 360.0,
			"expect": {"min_aura": 1, "min_tar_pit": 1, "min_final_hp": 80.0, "must_survive": true},
		},
		{
			"id": "warm_fear_light",
			"seed": 709,
			"preset": 3,
			"sign": "a warm light makes fear smaller",
			"duration": 300.0,
			"expect": {"min_fear_lantern": 1, "min_final_hp": 55.0, "min_hp": 35.0, "must_survive": true},
		},
		{
			"id": "false_me_decoy",
			"seed": 809,
			"preset": 7,
			"sign": "let a false me take their teeth",
			"duration": 320.0,
			"expect": {"min_decoy": 1, "min_final_hp": 45.0, "must_survive": true},
		},
		{
			"id": "thorns_skin",
			"seed": 907,
			"preset": 6,
			"sign": "make your skin punish teeth",
			"duration": 320.0,
			"expect": {"min_thorn": 1},
		},
		{
			"id": "armor_patience",
			"seed": 1009,
			"preset": 10,
			"sign": "heavy armor and patient skin",
			"duration": 300.0,
			"expect": {"min_armor": 0.10, "min_day": 2, "min_final_hp": 70.0, "must_survive": true},
		},
		{
			"id": "repair_tools_ready",
			"seed": 1051,
			"preset": 1,
			"sign": "build tools so broken walls can stand again",
			"duration": 330.0,
			"expect": {"min_repair_bench": 1, "min_final_hp": 80.0, "must_survive": true},
		},
		{
			"id": "sword_direct",
			"seed": 1103,
			"preset": 9,
			"sign": "do not hide, focus on killing enemies",
			"duration": 320.0,
			"expect": {"min_melee": 1, "min_day": 3},
		},
		{
			"id": "sword_drinks_life",
			"seed": 1201,
			"preset": 12,
			"sign": "make a sword that gives you life when they die",
			"duration": 340.0,
			"expect": {"min_sword_tier": 1, "min_melee": 1},
		},
		{
			"id": "ore_becomes_blade",
			"seed": 1249,
			"preset": 12,
			"sign": "ore should become a blade before the dead arrive",
			"duration": 340.0,
			"expect": {"min_sword_tier": 1, "min_melee": 1, "min_final_hp": 80.0},
		},
		{
			"id": "dawn_survival",
			"seed": 1301,
			"preset": 11,
			"sign": "do not win the night, survive until morning",
			"duration": 340.0,
			"expect": {"min_dawn_vanished": 1, "min_day": 3},
		},
		{
			"id": "farming_stomach",
			"seed": 1409,
			"preset": 8,
			"sign": "a full stomach is a wall inside me",
			"duration": 300.0,
			"expect": {"min_food_harvested": 1},
		},
		{
			"id": "library_memory",
			"seed": 1511,
			"preset": 4,
			"sign": "think about what went wrong and write it down",
			"duration": 300.0,
			"expect": {"min_lesson": 1, "min_repair_bench": 1, "min_final_hp": 85.0, "must_survive": true},
			"pre_events": [{"type": "structure_destroyed", "structure_type": "wall"}],
		},
		{
			"id": "sky_storm",
			"seed": 1601,
			"preset": 5,
			"sign": "the wings do not fear stone, answer the sky with storm",
			"duration": 360.0,
			"expect": {"min_storm": 1, "min_tower": 1, "min_ranged": 1, "max_wall": 1, "min_final_hp": 50.0, "must_survive": true},
			"pre_spawn": ["flying"],
		},
		{
			"id": "do_not_trust_walls_wings",
			"seed": 1657,
			"preset": 5,
			"sign": "do not trust walls against wings",
			"duration": 360.0,
			"expect": {"min_storm": 1, "min_tower": 1, "min_aura": 1, "max_wall": 1, "must_survive": true},
			"pre_spawn": ["flying"],
		},
		{
			"id": "nonsense_resilient",
			"seed": 1709,
			"preset": 0,
			"sign": "phones are watching the moon hate cowards",
			"duration": 260.0,
			"expect": {"min_day": 2, "min_any_defense": 1},
		},
		{
			"id": "emperor_weird_resilient",
			"seed": 1733,
			"preset": 4,
			"sign": "play like a japanese emperor",
			"duration": 260.0,
			"expect": {"min_day": 2, "min_any_defense": 1},
		},
		{
			"id": "moon_cowards_resilient",
			"seed": 1759,
			"preset": 3,
			"sign": "the moon hates cowards",
			"duration": 260.0,
			"expect": {"min_day": 2, "min_any_defense": 1},
		},
		{
			"id": "conflicted_freeform",
			"seed": 1801,
			"preset": 5,
			"sign": "using weapons makes you anxious but arrows keep teeth far away",
			"duration": 320.0,
			"expect": {"min_tower": 1, "min_fear_lantern": 1, "min_wall": 1, "min_final_hp": 80.0, "max_melee": 8, "must_survive": true},
		},
	]

	var scenario_filter := OS.get_environment("ARI_PROMPT_SCENARIO").strip_edges()
	for scenario in scenarios:
		if scenario_filter != "" and str(scenario.get("id", "")) != scenario_filter:
			continue
		var stats: Dictionary = await _run_prompt_scenario(scenario)
		records.append(stats)
		_print_stats(stats)
		_check_expectations(stats, scenario.get("expect", {}))

	if failures.is_empty():
		print("Real Smart Ari prompt playtest passed for %d prompts." % scenarios.size())
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _run_prompt_scenario(scenario: Dictionary) -> Dictionary:
	var scenario_seed := int(scenario.get("seed", 1))
	var test_save_path := "user://real_smart_ari_playtest_%s.json" % str(scenario.get("id", "scenario"))
	var world: World = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	_isolate_progression(world, test_save_path)
	seed(scenario_seed)
	world.call("start_run")
	await process_frame
	var bridge: AIBridge = world.get("ai_bridge")
	if bridge != null:
		bridge.force_provider_mode("local_stub")
	var preset_key := int(scenario.get("preset", 0))
	if preset_key > 0:
		world.call("select_run_build_preset", preset_key, false)
	for event in scenario.get("pre_events", []):
		if typeof(event) == TYPE_DICTIONARY:
			world.get("ari_memory").record_event(str(event.get("type", "event")), {
				"structure_type": str(event.get("structure_type", "")),
				"day": 1,
				"phase": "morning",
			})
	for enemy_type in scenario.get("pre_spawn", []):
		var arena: Rect2 = world.call("get_arena_rect")
		world.call("_spawn_enemy", arena.get_center() + Vector2(190.0, -90.0), str(enemy_type))
	world.call("commit_sign", str(scenario.get("sign", "")))
	var stats: Dictionary = await _simulate(world, float(scenario.get("duration", 300.0)), 0.30)
	stats["scenario"] = str(scenario.get("id", ""))
	stats["sign"] = str(scenario.get("sign", ""))
	stats["preset"] = preset_key
	stats["latest_thought"] = str(world.get("latest_thought"))
	stats["sign_interpretation"] = str(world.get("sign_interpretation"))
	stats["ai_survival_theory"] = str(world.get("ai_survival_theory"))
	root.remove_child(world)
	world.queue_free()
	await process_frame
	var absolute_save_path := ProjectSettings.globalize_path(test_save_path)
	if FileAccess.file_exists(test_save_path):
		DirAccess.remove_absolute(absolute_save_path)
	return stats


func _simulate(world: World, seconds: float, step_seconds: float) -> Dictionary:
	var elapsed := 0.0
	var frame_count := 0
	var max_counts := {
		"wall": 0,
		"aura_orb": 0,
		"spike_trap": 0,
		"bow_tower": 0,
		"tar_pit": 0,
		"fear_lantern": 0,
		"decoy_idol": 0,
		"thorn_totem": 0,
		"repair_bench": 0,
		"storm_rod": 0,
	}
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
		max_counts["wall"] = maxi(int(max_counts["wall"]), int(world.call("get_wall_count")))
		max_counts["aura_orb"] = maxi(int(max_counts["aura_orb"]), int(world.call("get_aura_orb_count")))
		max_counts["spike_trap"] = maxi(int(max_counts["spike_trap"]), int(world.call("get_spike_trap_count")))
		max_counts["bow_tower"] = maxi(int(max_counts["bow_tower"]), int(world.call("get_bow_tower_count")))
		max_counts["tar_pit"] = maxi(int(max_counts["tar_pit"]), int(world.call("get_tar_pit_count")))
		max_counts["fear_lantern"] = maxi(int(max_counts["fear_lantern"]), int(world.call("get_fear_lantern_count")))
		max_counts["decoy_idol"] = maxi(int(max_counts["decoy_idol"]), int(world.call("get_decoy_idol_count")))
		max_counts["thorn_totem"] = maxi(int(max_counts["thorn_totem"]), int(world.call("get_thorn_totem_count")))
		max_counts["repair_bench"] = maxi(int(max_counts["repair_bench"]), int(world.call("get_repair_bench_count")))
		max_counts["storm_rod"] = maxi(int(max_counts["storm_rod"]), int(world.call("get_storm_rod_count")))
		if world.has_method("_current_sword_tier"):
			max_sword_tier = maxi(max_sword_tier, int(world.call("_current_sword_tier")))
		var resource_system = world.get("resource_system")
		if resource_system != null and resource_system.has_method("get_ore"):
			max_ore = maxi(max_ore, int(resource_system.call("get_ore")))
		var counts: Dictionary = world.call("get_enemy_type_counts")
		flying_seen = flying_seen or int(counts.get("flying", 0)) > 0
		elapsed += step
		frame_count += 1
		if frame_count % 120 == 0:
			await process_frame

	var ari = world.get("ari")
	var needs: Dictionary = ari.call("get_needs") if ari != null else {}
	var day_night = world.get("day_night")
	var resource_system = world.get("resource_system")
	var ari_memory = world.get("ari_memory")
	var event_summary := _summarize_events(ari_memory.call("get_recent_events", 300) if ari_memory != null else [])
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
		"max_wall_count": int(max_counts["wall"]),
		"max_aura_orb_count": int(max_counts["aura_orb"]),
		"max_spike_trap_count": int(max_counts["spike_trap"]),
		"max_bow_tower_count": int(max_counts["bow_tower"]),
		"max_tar_pit_count": int(max_counts["tar_pit"]),
		"max_fear_lantern_count": int(max_counts["fear_lantern"]),
		"max_decoy_idol_count": int(max_counts["decoy_idol"]),
		"max_thorn_totem_count": int(max_counts["thorn_totem"]),
		"max_repair_bench_count": int(max_counts["repair_bench"]),
		"max_storm_rod_count": int(max_counts["storm_rod"]),
		"max_sword_tier": max_sword_tier,
		"max_ore": max_ore,
		"final_armor": float(ari.get("armor")) if ari != null else 0.0,
		"flying_seen": flying_seen,
		"event_counts": event_summary.get("event_counts", {}),
		"enemy_kills": int(event_summary.get("enemy_kills", 0)),
		"melee_hits": int(event_summary.get("melee_hits", 0)),
		"ranged_hits": int(event_summary.get("ranged_hits", 0)),
		"aura_damage_events": int(event_summary.get("aura_damage_events", 0)),
		"dawn_vanished_total": int(event_summary.get("dawn_vanished_total", 0)),
		"sword_smithed_events": int(event_summary.get("sword_smithed_events", 0)),
		"ore_mined_events": int(event_summary.get("ore_mined_events", 0)),
		"food_harvested_events": int(event_summary.get("food_harvested_events", 0)),
		"library_note_events": int(event_summary.get("library_note_events", 0)),
	}


func _summarize_events(events: Array) -> Dictionary:
	var event_counts := {}
	var enemy_kills := 0
	var melee_hits := 0
	var ranged_hits := 0
	var aura_damage_events := 0
	var dawn_vanished_total := 0
	var sword_smithed_events := 0
	var ore_mined_events := 0
	var food_harvested_events := 0
	var library_note_events := 0
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var event_type := str(event.get("type", ""))
		event_counts[event_type] = int(event_counts.get(event_type, 0)) + 1
		match event_type:
			"enemy_killed":
				enemy_kills += 1
			"ari_melee_hit":
				melee_hits += 1
			"ari_ranged_hit":
				ranged_hits += 1
			"aura_damage_success":
				aura_damage_events += 1
			"dawn_enemies_vanished":
				dawn_vanished_total += maxi(int(event.get("count", 0)), 0)
			"sword_smithed":
				sword_smithed_events += 1
			"ore_mined":
				ore_mined_events += 1
			"food_harvested":
				food_harvested_events += 1
			"library_note_created":
				library_note_events += 1
	return {
		"event_counts": event_counts,
		"enemy_kills": enemy_kills,
		"melee_hits": melee_hits,
		"ranged_hits": ranged_hits,
		"aura_damage_events": aura_damage_events,
		"dawn_vanished_total": dawn_vanished_total,
		"sword_smithed_events": sword_smithed_events,
		"ore_mined_events": ore_mined_events,
		"food_harvested_events": food_harvested_events,
		"library_note_events": library_note_events,
	}


func _check_expectations(stats: Dictionary, expect) -> void:
	if typeof(expect) != TYPE_DICTIONARY:
		return
	var id := str(stats.get("scenario", "scenario"))
	if bool(expect.get("must_survive", false)):
		_assert(bool(stats.get("alive", false)), id, "expected Ari to survive this coherent local plan")
	if expect.has("min_day"):
		_assert(int(stats.get("day", 1)) >= int(expect["min_day"]), id, "expected day >= %d" % int(expect["min_day"]))
	if expect.has("min_wall"):
		_assert(int(stats.get("max_wall_count", 0)) >= int(expect["min_wall"]), id, "expected wall count >= %d" % int(expect["min_wall"]))
	if expect.has("max_wall"):
		_assert(int(stats.get("max_wall_count", 0)) <= int(expect["max_wall"]), id, "expected wall count <= %d" % int(expect["max_wall"]))
	if expect.has("min_tower"):
		_assert(int(stats.get("max_bow_tower_count", 0)) >= int(expect["min_tower"]), id, "expected bow tower count >= %d" % int(expect["min_tower"]))
	if expect.has("min_aura"):
		_assert(int(stats.get("max_aura_orb_count", 0)) >= int(expect["min_aura"]), id, "expected aura orb count >= %d" % int(expect["min_aura"]))
	if expect.has("min_spike_trap"):
		_assert(int(stats.get("max_spike_trap_count", 0)) >= int(expect["min_spike_trap"]), id, "expected spike trap count >= %d" % int(expect["min_spike_trap"]))
	if expect.has("min_tar_pit"):
		_assert(int(stats.get("max_tar_pit_count", 0)) >= int(expect["min_tar_pit"]), id, "expected tar pit count >= %d" % int(expect["min_tar_pit"]))
	if expect.has("min_hp"):
		_assert(float(stats.get("min_hp", 0.0)) >= float(expect["min_hp"]), id, "expected minimum HP >= %.1f" % float(expect["min_hp"]))
	if expect.has("min_final_hp"):
		_assert(float(stats.get("hp", 0.0)) >= float(expect["min_final_hp"]), id, "expected final HP >= %.1f" % float(expect["min_final_hp"]))
	if expect.has("min_fear_lantern"):
		_assert(int(stats.get("max_fear_lantern_count", 0)) >= int(expect["min_fear_lantern"]), id, "expected fear lantern count >= %d" % int(expect["min_fear_lantern"]))
	if expect.has("min_decoy"):
		_assert(int(stats.get("max_decoy_idol_count", 0)) >= int(expect["min_decoy"]), id, "expected decoy idol count >= %d" % int(expect["min_decoy"]))
	if expect.has("min_thorn"):
		_assert(int(stats.get("max_thorn_totem_count", 0)) >= int(expect["min_thorn"]), id, "expected thorn totem count >= %d" % int(expect["min_thorn"]))
	if expect.has("min_storm"):
		_assert(int(stats.get("max_storm_rod_count", 0)) >= int(expect["min_storm"]), id, "expected storm rod count >= %d" % int(expect["min_storm"]))
	if expect.has("min_repair_bench"):
		_assert(int(stats.get("max_repair_bench_count", 0)) >= int(expect["min_repair_bench"]), id, "expected repair bench count >= %d" % int(expect["min_repair_bench"]))
	if expect.has("min_sword_tier"):
		_assert(int(stats.get("max_sword_tier", 0)) >= int(expect["min_sword_tier"]), id, "expected sword tier >= %d" % int(expect["min_sword_tier"]))
	if expect.has("min_melee"):
		_assert(int(stats.get("melee_hits", 0)) >= int(expect["min_melee"]), id, "expected melee hits >= %d" % int(expect["min_melee"]))
	if expect.has("min_ranged"):
		_assert(int(stats.get("ranged_hits", 0)) >= int(expect["min_ranged"]), id, "expected ranged hits >= %d" % int(expect["min_ranged"]))
	if expect.has("max_melee"):
		_assert(int(stats.get("melee_hits", 0)) <= int(expect["max_melee"]), id, "expected melee hits <= %d" % int(expect["max_melee"]))
	if expect.has("min_dawn_vanished"):
		_assert(int(stats.get("dawn_vanished_total", 0)) >= int(expect["min_dawn_vanished"]), id, "expected dawn-cleared enemies >= %d" % int(expect["min_dawn_vanished"]))
	if expect.has("min_food_harvested"):
		_assert(int(stats.get("food_harvested_events", 0)) >= int(expect["min_food_harvested"]), id, "expected food harvest events >= %d" % int(expect["min_food_harvested"]))
	if expect.has("min_lesson"):
		_assert(int(stats.get("library_note_events", 0)) >= int(expect["min_lesson"]), id, "expected library note events >= %d" % int(expect["min_lesson"]))
	if expect.has("min_armor"):
		_assert(float(stats.get("final_armor", 0.0)) >= float(expect["min_armor"]), id, "expected armor >= %.2f" % float(expect["min_armor"]))
	if expect.has("min_ranged_or_day"):
		_assert(int(stats.get("ranged_hits", 0)) > 0 or int(stats.get("day", 1)) >= int(expect["min_ranged_or_day"]), id, "expected ranged hits or day >= %d" % int(expect["min_ranged_or_day"]))
	if expect.has("min_aura_or_day"):
		_assert(int(stats.get("aura_damage_events", 0)) > 0 or int(stats.get("day", 1)) >= int(expect["min_aura_or_day"]), id, "expected aura damage or day >= %d" % int(expect["min_aura_or_day"]))
	if expect.has("min_any_defense"):
		var defenses := int(stats.get("max_wall_count", 0)) + int(stats.get("max_aura_orb_count", 0)) + int(stats.get("max_bow_tower_count", 0)) + int(stats.get("max_spike_trap_count", 0)) + int(stats.get("max_thorn_totem_count", 0))
		_assert(defenses >= int(expect["min_any_defense"]), id, "expected at least one defensive structure")


func _assert(condition: bool, id: String, message: String) -> void:
	if not condition:
		failures.append("%s: %s" % [id, message])


func _print_stats(stats: Dictionary) -> void:
	print("Prompt %s: day=%d phase=%s alive=%s hp=%.1f walls=%d aura=%d tower=%d trap=%d tar=%d lantern=%d decoy=%d thorn=%d bench=%d storm=%d sword=%d melee=%d ranged=%d aura_hits=%d dawn=%d food_events=%d lesson_events=%d sign=\"%s\"" % [
		str(stats.get("scenario", "")),
		int(stats.get("day", 1)),
		str(stats.get("phase", "")),
		str(stats.get("alive", false)),
		float(stats.get("hp", 0.0)),
		int(stats.get("max_wall_count", 0)),
		int(stats.get("max_aura_orb_count", 0)),
		int(stats.get("max_bow_tower_count", 0)),
		int(stats.get("max_spike_trap_count", 0)),
		int(stats.get("max_tar_pit_count", 0)),
		int(stats.get("max_fear_lantern_count", 0)),
		int(stats.get("max_decoy_idol_count", 0)),
		int(stats.get("max_thorn_totem_count", 0)),
		int(stats.get("max_repair_bench_count", 0)),
		int(stats.get("max_storm_rod_count", 0)),
		int(stats.get("max_sword_tier", 0)),
		int(stats.get("melee_hits", 0)),
		int(stats.get("ranged_hits", 0)),
		int(stats.get("aura_damage_events", 0)),
		int(stats.get("dawn_vanished_total", 0)),
		int(stats.get("food_harvested_events", 0)),
		int(stats.get("library_note_events", 0)),
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
