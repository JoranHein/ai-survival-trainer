extends SceneTree

const AIBridgeScript = preload("res://scripts/autoload/AIBridge.gd")
const AriDoctrineScript = preload("res://scripts/ari/AriDoctrine.gd")
const AriMemoryScript = preload("res://scripts/ari/AriMemory.gd")
const AriMindScript = preload("res://scripts/ari/AriMind.gd")
const AriPerceptionScript = preload("res://scripts/ari/AriPerception.gd")
const AriRulebookScript = preload("res://scripts/ari/AriRulebook.gd")
const SignMindScript = preload("res://scripts/ari/SignMind.gd")
const WorldScript = preload("res://scripts/world/World.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_rulebook_mentions_enemy_counters()
	await _test_perception_reports_lure_gap_and_enemy_counters()
	_test_local_fallback_cover_uses_existing_wall()
	_test_wall_cover_adds_backup_layer_after_shell()
	_test_no_wall_builds_cover_first()
	_test_aura_lure_execution()
	_test_aura_circle_maintains_the_killing_circle()
	_test_dawn_survival_avoids_fight()
	_test_combat_investment_execution()
	_test_flying_storm_execution()
	_test_corner_bow_execution()
	_test_combo_wall_light_tower_builds_wall_floor()
	_test_hunger_food_execution()
	_test_thorn_tank_holds_thorn_ground_at_night()
	_test_no_touch_floor_fight_avoids_melee()
	_test_no_wall_light_sign_builds_light_first()
	_test_weapon_anxiety_adds_fear_light_to_ranged_plan()
	_test_warm_fear_light_uses_existing_lantern_at_night()
	_test_moon_cowards_stages_before_first_contact()
	_test_false_me_uses_existing_decoy_at_night()
	_test_reflection_waits_for_basic_survival()
	_test_wall_failure_lesson_drives_repair_support()
	_test_ground_grab_sign_prefers_tar_pit()
	_test_repair_tools_sign_builds_bench_before_damage()
	_test_plain_anti_air_instead_of_walls_avoids_wall_habit()
	_test_stay_near_safest_defense_holds_existing_anchor()
	_test_agent_grounded_plan_drives_day_job()
	_test_agent_build_tower_plan_can_add_redundancy()
	_test_agent_aura_plan_can_add_redundancy()
	_test_agent_mine_stone_plan_drives_resource_work()
	_test_negative_lesson_bias_changes_real_job()
	await _test_world_doctrine_changes_real_behavior()
	await _test_world_learning_disabled_ablation_blocks_doctrine_behavior()
	await _test_world_allows_redundant_tower_slots()
	await _test_world_allows_redundant_aura_slots()
	_test_impossible_grounded_plan_falls_through()
	_test_bridge_validation_keeps_failure_safe()

	if failures.is_empty():
		print("Ari intelligence scenario tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _test_rulebook_mentions_enemy_counters() -> void:
	var rulebook = AriRulebookScript.new()
	var data: Dictionary = rulebook.call("get_rulebook")
	var text := JSON.stringify(data).to_lower()
	_assert(text.contains("runner"), "rulebook should explain runners as a distinct counter pressure")
	_assert(text.contains("brute"), "rulebook should explain brutes as wall-breaking pressure")
	_assert(text.contains("dawn"), "rulebook should explain dawn clearing/stalling")
	_assert(text.find("origin_year") < 0, "rulebook should not reintroduce origin-year")
	_assert(text.find("stubbornness") < 0, "rulebook should not reintroduce stubbornness")


func _test_perception_reports_lure_gap_and_enemy_counters() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for perception intelligence tests")
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
		resource_system.call("add_stone", 60)
	var arena: Rect2 = world.call("get_arena_rect")
	var center := arena.get_center()
	var build_grid = world.get("build_grid")
	if build_grid != null:
		world.call("_place_aura_orb_at_cell", build_grid.call("world_to_cell", center + Vector2(-90.0, 0.0)))
		world.call("_place_wall_at_cell", build_grid.call("world_to_cell", center + Vector2(20.0, 0.0)))
	world.call("_spawn_enemy", center + Vector2(210.0, 0.0), "zombie")
	world.call("_spawn_enemy", center + Vector2(238.0, 34.0), "runner")
	world.call("_spawn_enemy", center + Vector2(260.0, -36.0), "brute")
	await process_frame

	var perception = AriPerceptionScript.new()
	var report: Dictionary = perception.call("build_report", world)
	var facts: Array = report.get("tactical_facts", [])
	_assert(_array_text_contains(facts, "outside") and _array_text_contains(facts, "Aura"), "perception should say when enemies are outside the Aura Orb and luring matters")
	_assert(_array_text_contains(facts, "Runner"), "perception should surface runner pressure as a tactical fact")
	_assert(_array_text_contains(facts, "Brute"), "perception should surface brute wall-breaking pressure as a tactical fact")
	_assert(_array_text_contains(report.get("available_safe_moves", []), "lure_to_aura"), "perception should expose lure_to_aura as a safe move when aura exists")

	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_local_fallback_cover_uses_existing_wall() -> void:
	var sign_mind = SignMindScript.new()
	var ari_mind = AriMindScript.new()
	var hints: Dictionary = sign_mind.interpret_sign("stand behind the wall").get("priority_hints", {})
	var decision: Dictionary = ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"stone": 20,
		"priority_hints": hints,
	}))
	_assert(decision.get("job", "") == "build_wall", "daytime wall-cover signs should reinforce thin cover before treating it as solved")
	var active_decision: Dictionary = ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"stone": 20,
		"priority_hints": hints,
		"enemy_type_counts": {"zombie": 1},
	}))
	_assert(active_decision.get("job", "") == "use_cover", "active enemies should still make Ari use the existing wall immediately")
	_assert(str(active_decision.get("reason", "")).to_lower().contains("wall"), "cover decision should explain the existing wall")
	sign_mind.free()
	ari_mind.free()


func _test_wall_cover_adds_backup_layer_after_shell() -> void:
	var sign_mind = SignMindScript.new()
	var ari_mind = AriMindScript.new()
	var builder_wall_build := {"points": {"mining": 4, "building": 5, "warding": 3}}
	var hints: Dictionary = sign_mind.interpret_sign("stand behind the wall and make teeth wait", builder_wall_build).get("priority_hints", {})
	var backup_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 4,
		"aura_orb_count": 0,
		"stone": 20,
		"priority_hints": hints,
		"run_build": builder_wall_build,
	}))
	_assert(backup_decision.get("job", "") == "place_aura_orb", "wall-cover plans with a ready shell should add backup light before treating cover as solved; got %s because %s" % [str(backup_decision.get("job", "")), str(backup_decision.get("reason", ""))])
	var pressure_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 4,
		"aura_orb_count": 0,
		"stone": 20,
		"enemy_type_counts": {"zombie": 1},
		"priority_hints": hints,
		"run_build": builder_wall_build,
	}))
	_assert(pressure_decision.get("job", "") == "use_cover", "active enemies should still make wall-cover Ari use the wall immediately")
	sign_mind.free()
	ari_mind.free()


func _test_no_wall_builds_cover_first() -> void:
	var ari_mind = AriMindScript.new()
	var decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 0,
		"stone": 20,
		"grounded_plan": [{
			"affordance_id": "use_existing_wall",
			"priority": 0.95,
			"reason": "The sign wants cover.",
		}, {
			"affordance_id": "build_wall",
			"priority": 0.9,
			"reason": "No wall exists yet.",
		}],
	}))
	_assert(decision.get("job", "") == "build_wall", "no-wall cover plans should build cover first when stone exists")
	ari_mind.free()


func _test_aura_lure_execution() -> void:
	var ari_mind = AriMindScript.new()
	var decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"aura_orb_count": 1,
		"enemy_type_counts": {"zombie": 2},
		"grounded_plan": [{
			"affordance_id": "lure_to_aura",
			"priority": 0.95,
			"reason": "The circle should eat the dead.",
		}],
	}))
	_assert(decision.get("job", "") == "lure_to_aura", "aura plans should make Ari lure enemies through existing light")
	ari_mind.free()


func _test_aura_circle_maintains_the_killing_circle() -> void:
	var sign_mind = SignMindScript.new()
	var ari_mind = AriMindScript.new()
	var aura_build := {"points": {"warding": 7, "building": 3, "fear_control": 2}}
	var hints: Dictionary = sign_mind.interpret_sign("the circle should eat the dead", aura_build).get("priority_hints", {})
	_assert(float(hints.get("aura_orb", 0.0)) >= 0.70, "circle-eats-dead signs should strongly mean aura/light")
	_assert(float(hints.get("lure_to_aura", 0.0)) >= 0.50, "circle-eats-dead signs should create an aura-lure tactic")
	_assert(float(hints.get("farm_food", 0.0)) < 0.20, "circle-eats-dead signs should not become a food plan just because they contain 'eat'")
	var first_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 0,
		"aura_orb_count": 0,
		"stone": 10,
		"food": 2,
		"priority_hints": hints,
		"run_build": aura_build,
	}))
	_assert(first_decision.get("job", "") != "farm_food", "aura-circle plans should start survival prep before optional food")
	var buildup_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"aura_orb_count": 1,
		"stone": 10,
		"food": 2,
		"priority_hints": hints,
		"run_build": aura_build,
	}))
	_assert(buildup_decision.get("job", "") == "place_aura_orb", "aura-circle plans should build a redundant light circle before using it in empty daylight")
	var repair_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"aura_orb_count": 2,
		"stone": 0,
		"damaged_structure_count": 3,
		"lowest_structure_hp_ratio": 0.59,
		"priority_hints": hints,
		"run_build": aura_build,
	}))
	_assert(repair_decision.get("job", "") == "repair_structure", "aura-circle plans should repair a damaged killing circle before idling")
	sign_mind.free()
	ari_mind.free()


func _test_dawn_survival_avoids_fight() -> void:
	var ari_mind = AriMindScript.new()
	var decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"time_left": 8.0,
		"enemy_count": 2,
		"nearest_enemy_distance": 96.0,
		"ari_hp_ratio": 0.30,
		"wall_count": 1,
		"has_valid_cover": true,
		"grounded_plan": [{
			"affordance_id": "survive_until_morning",
			"priority": 0.95,
			"reason": "Dawn is close.",
		}],
	}))
	_assert(decision.get("job", "") != "fight_head_on", "survive-until-morning should not pull low-HP Ari into direct fighting")
	_assert(["flee", "hide_until_dawn", "stall_until_dawn", "use_cover"].has(str(decision.get("job", ""))), "survive-until-morning should become a safe night tactic")
	ari_mind.free()


func _test_combat_investment_execution() -> void:
	var ari_mind = AriMindScript.new()
	var smith_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"ore": 3,
		"sword_tier": 0,
		"sword_next_ore_cost": 2,
		"grounded_plan": [{
			"affordance_id": "smith_sword",
			"priority": 0.95,
			"reason": "Do not hide; prepare to kill.",
		}],
	}))
	_assert(smith_decision.get("job", "") == "smith_sword", "combat-killing plans with ore should smith before fighting")
	var mine_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"ore": 0,
		"sword_tier": 0,
		"sword_next_ore_cost": 2,
		"grounded_plan": [{
			"affordance_id": "smith_sword",
			"priority": 0.95,
			"reason": "The blade comes first.",
		}],
	}))
	_assert(mine_decision.get("job", "") == "mine_ore", "smith plans without ore should mine ore first")
	var wounded_night_decision := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 90.0,
		"ari_hp_ratio": 0.54,
		"wall_count": 2,
		"aura_orb_count": 1,
		"has_valid_cover": true,
		"has_valid_aura": true,
		"sword_tier": 2,
		"combat_stats": {"combat_level": 1.04, "sword_skill": 1.0, "attack_damage": 25.8, "armor": 0.09, "sword_tier": 2},
		"priority_hints": {"smith_sword": 0.9, "train_sword": 0.7, "fight_head_on": 0.72},
		"needs": {"hunger": 51.0, "stamina": 87.0, "fear": 84.0},
	}))
	_assert(wounded_night_decision.get("job", "") == "lure_to_aura", "wounded sword plans should rotate to existing aura instead of forcing melee")
	ari_mind.free()


func _test_flying_storm_execution() -> void:
	var sign_mind = SignMindScript.new()
	var ari_mind = AriMindScript.new()
	var decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 3,
		"aura_orb_count": 1,
		"storm_rod_count": 0,
		"enemy_type_counts": {"flying": 1},
		"grounded_plan": [{
			"affordance_id": "anti_flying",
			"priority": 0.95,
			"reason": "The wall does not reach the sky.",
		}],
	}))
	_assert(decision.get("job", "") == "build_storm_rod", "anti-flying plans should build Storm Rod when flying is visible and stone exists")

	var no_wall_hints: Dictionary = sign_mind.interpret_sign("do not trust walls against wings", {"points": {"bow": 5, "attack_range": 4, "building": 3}}).get("priority_hints", {})
	_assert(float(no_wall_hints.get("avoid_build_wall", 0.0)) < 0.50, "do-not-trust-walls wing signs should not become a total wall-building ban")
	_assert(float(no_wall_hints.get("avoid_build_wall", 0.0)) > 0.25, "do-not-trust-walls wing signs should still make Ari distrust extra wall layers")
	var sky_hints: Dictionary = sign_mind.interpret_sign("the wings do not fear stone, answer the sky with storm", {"points": {"bow": 5, "attack_range": 4, "building": 3}}).get("priority_hints", {})
	_assert(float(sky_hints.get("build_storm_rod", 0.0)) >= 0.70, "sky-storm signs should still strongly prefer Storm Rod")
	_assert(float(sky_hints.get("use_tower", 0.0)) >= 0.55, "sky-storm signs should also carry ranged support into night tactics")
	_assert(float(sky_hints.get("avoid_build_wall", 0.0)) < 0.50, "sky-storm stone distrust should not become a total wall-building ban")
	_assert(float(sky_hints.get("avoid_build_wall", 0.0)) > 0.25, "sky-storm signs should teach Ari that stone is not the main answer to wings")
	var no_wall_storm_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 0,
		"aura_orb_count": 0,
		"stone": 20,
		"enemy_type_counts": {"flying": 1},
		"priority_hints": no_wall_hints,
		"run_build": {"points": {"bow": 5, "attack_range": 4, "building": 3}},
	}))
	_assert(no_wall_storm_decision.get("job", "") == "build_storm_rod", "anti-flying signs should build Storm Rod without waiting for wall cover when wings are already present")

	var distrust_ready_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "midday",
		"night_close": false,
		"wall_count": 1,
		"aura_orb_count": 1,
		"bow_tower_count": 1,
		"storm_rod_count": 1,
		"stone": 20,
		"priority_hints": no_wall_hints,
		"run_build": {"points": {"bow": 5, "attack_range": 4, "building": 3}},
	}))
	_assert(distrust_ready_decision.get("job", "") == "train_combat", "wall-distrust wing plans should train ranged readiness instead of adding extra wall layers once one cover layer and light exist")

	var sky_ready_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "midday",
		"night_close": false,
		"wall_count": 1,
		"aura_orb_count": 1,
		"bow_tower_count": 1,
		"storm_rod_count": 1,
		"stone": 20,
		"priority_hints": sky_hints,
		"run_build": {"points": {"bow": 5, "attack_range": 4, "building": 3}},
	}))
	_assert(sky_ready_decision.get("job", "") == "train_combat", "sky-storm signs should train ranged readiness instead of stacking stone walls once storm, light, and one cover layer exist")

	var support_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"aura_orb_count": 0,
		"bow_tower_count": 0,
		"storm_rod_count": 1,
		"stone": 20,
		"enemy_type_counts": {"flying": 1},
		"grounded_plan": [{
			"affordance_id": "anti_flying",
			"priority": 0.95,
			"reason": "The storm rod exists, but Ari still needs ranged sky support.",
		}],
		"priority_hints": {
			"anti_flying": 0.95,
			"sky_answer": 0.9,
			"build_tower": 0.72,
		},
	}))
	_assert(support_decision.get("job", "") == "build_bow_tower", "after the first storm rod, anti-flying plans should add ranged support instead of hiding behind walls")

	var dusk_staging_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "dusk",
		"night_close": true,
		"wall_count": 2,
		"aura_orb_count": 1,
		"bow_tower_count": 1,
		"storm_rod_count": 1,
		"stone": 8,
		"priority_hints": {
			"anti_flying": 0.95,
			"sky_answer": 0.9,
			"use_tower": 0.62,
		},
	}))
	_assert(dusk_staging_decision.get("job", "") == "use_tower", "complete sky plans should stage Ari at the tower perch before night instead of idling near generic defenses")

	var midday_sky_backup_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "midday",
		"night_close": false,
		"wall_count": 3,
		"aura_orb_count": 0,
		"bow_tower_count": 1,
		"storm_rod_count": 1,
		"stone": 20,
		"priority_hints": sky_hints,
		"run_build": {"points": {"bow": 5, "attack_range": 4, "building": 3}},
	}))
	_assert(midday_sky_backup_decision.get("job", "") == "place_aura_orb", "sky support should not make Ari idle at the tower before basic backup light exists; got %s because %s" % [str(midday_sky_backup_decision.get("job", "")), str(midday_sky_backup_decision.get("reason", ""))])

	var degraded_sky_mine_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "midday",
		"night_close": false,
		"wall_count": 2,
		"aura_orb_count": 0,
		"bow_tower_count": 1,
		"storm_rod_count": 0,
		"stone": 0,
		"priority_hints": sky_hints,
		"run_build": {"points": {"bow": 5, "attack_range": 4, "building": 3}},
	}))
	_assert(degraded_sky_mine_decision.get("job", "") == "mine_stone", "degraded sky plans should mine for the missing Storm Rod before idling at the tower")

	var degraded_sky_rebuild_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "midday",
		"night_close": false,
		"wall_count": 2,
		"aura_orb_count": 0,
		"bow_tower_count": 1,
		"storm_rod_count": 0,
		"stone": 20,
		"priority_hints": sky_hints,
		"run_build": {"points": {"bow": 5, "attack_range": 4, "building": 3}},
	}))
	_assert(degraded_sky_rebuild_decision.get("job", "") == "build_storm_rod", "degraded sky plans should rebuild the missing Storm Rod before idling at the tower")

	var hurt_sky_recovery_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"phase": "dusk",
		"night_close": false,
		"wall_count": 3,
		"aura_orb_count": 1,
		"bow_tower_count": 1,
		"storm_rod_count": 1,
		"ari_hp_ratio": 0.67,
		"priority_hints": sky_hints,
		"run_build": {"points": {"bow": 5, "attack_range": 4, "building": 3}},
	}))
	_assert(hurt_sky_recovery_decision.get("job", "") == "rest", "hurt sky plans should recover once storm, range, and backup defenses are ready before night")

	var ground_night_sky_decision := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 3,
		"enemy_type_counts": {"zombie": 2, "runner": 1},
		"nearest_enemy_distance": 88.0,
		"ari_hp_ratio": 0.70,
		"bow_tower_count": 1,
		"storm_rod_count": 1,
		"fear_lantern_count": 1,
		"has_valid_tower": true,
		"has_valid_fear_lantern": true,
		"priority_hints": sky_hints,
		"needs": {"fear": 72.0, "hunger": 24.0, "stamina": 70.0},
	}))
	_assert(ground_night_sky_decision.get("job", "") == "use_tower", "sky-storm night tactics should keep using ranged support against ground pressure after the initial flying enemy dies")

	var tower_gone_sky_decision := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"enemy_type_counts": {"zombie": 2},
		"nearest_enemy_distance": 82.0,
		"ari_hp_ratio": 0.40,
		"wall_count": 2,
		"aura_orb_count": 1,
		"bow_tower_count": 0,
		"storm_rod_count": 1,
		"has_valid_cover": true,
		"has_valid_aura": true,
		"has_valid_tower": false,
		"priority_hints": sky_hints,
		"needs": {"fear": 58.0, "hunger": 24.0, "stamina": 68.0},
	}))
	_assert(tower_gone_sky_decision.get("job", "") == "lure_to_aura", "sky-storm plans should rotate to existing light when the tower is gone at night")

	var repair_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"bow_tower_count": 1,
		"storm_rod_count": 1,
		"damaged_structure_count": 2,
		"lowest_structure_hp_ratio": 0.28,
		"enemy_type_counts": {},
		"grounded_plan": [{
			"affordance_id": "anti_flying",
			"priority": 0.95,
			"reason": "The sky plan exists, but the support is badly damaged.",
		}],
		"priority_hints": {
			"anti_flying": 0.95,
			"sky_answer": 0.9,
		},
	}))
	_assert(repair_decision.get("job", "") == "repair_structure", "smart anti-air execution should repair damaged support before returning to the perch")

	var tower_recovery_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"bow_tower_count": 1,
		"storm_rod_count": 1,
		"stone": 0,
		"damaged_structure_count": 2,
		"lowest_structure_hp_ratio": 0.58,
		"enemy_type_counts": {},
		"agent_grounded_plan": [{
			"affordance_id": "use_tower",
			"priority": 0.95,
			"reason": "The remote plan wants tower range against wings.",
		}, {
			"affordance_id": "build_tower",
			"priority": 0.80,
			"reason": "More height helps when the sky comes back.",
		}],
		"priority_hints": {
			"anti_flying": 0.95,
			"sky_answer": 0.9,
			"use_tower": 0.9,
		},
	}))
	_assert(tower_recovery_decision.get("job", "") == "repair_structure", "daytime tower-use plans should repair damaged anti-air support before idling at the perch")

	var underbuilt_sky_mine_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"bow_tower_count": 2,
		"storm_rod_count": 1,
		"stone": 0,
		"agent_grounded_plan": [{
			"affordance_id": "use_tower",
			"priority": 0.95,
			"reason": "Use height against the sky.",
		}],
		"priority_hints": {
			"anti_flying": 0.95,
			"sky_answer": 0.9,
			"use_tower": 0.9,
		},
	}))
	_assert(underbuilt_sky_mine_decision.get("job", "") == "mine_stone", "underbuilt sky-tower plans should mine stone for missing cover before idling at the perch")

	var underbuilt_sky_wall_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"bow_tower_count": 2,
		"storm_rod_count": 1,
		"stone": 4,
		"agent_grounded_plan": [{
			"affordance_id": "use_tower",
			"priority": 0.95,
			"reason": "Use height against the sky.",
		}],
		"priority_hints": {
			"anti_flying": 0.95,
			"sky_answer": 0.9,
			"use_tower": 0.9,
		},
	}))
	_assert(underbuilt_sky_wall_decision.get("job", "") == "build_wall", "underbuilt sky-tower plans should add basic cover before idling at the perch")

	var wounded_sky_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"bow_tower_count": 0,
		"storm_rod_count": 0,
		"stone": 20,
		"ari_hp_ratio": 0.10,
		"agent_grounded_plan": [{
			"affordance_id": "build_storm_rod",
			"priority": 0.95,
			"reason": "Rebuild the sky answer.",
		}, {
			"affordance_id": "build_tower",
			"priority": 0.85,
			"reason": "Add ranged support.",
		}],
		"priority_hints": {
			"anti_flying": 0.95,
			"sky_answer": 0.9,
		},
	}))
	_assert(wounded_sky_decision.get("job", "") == "rest", "critically wounded Ari should recover before executing remote sky-plan construction")

	var recovering_sky_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"bow_tower_count": 0,
		"storm_rod_count": 0,
		"stone": 20,
		"ari_hp_ratio": 0.26,
		"agent_grounded_plan": [{
			"affordance_id": "build_storm_rod",
			"priority": 0.95,
			"reason": "Rebuild the sky answer after the defenses collapsed.",
		}, {
			"affordance_id": "build_tower",
			"priority": 0.85,
			"reason": "Add ranged support before night.",
		}],
		"priority_hints": {
			"anti_flying": 0.95,
			"sky_answer": 0.9,
		},
	}))
	_assert(recovering_sky_decision.get("job", "") == "rest", "near-death sky rebuild plans should keep Ari resting above the critical HP threshold before construction")
	sign_mind.free()
	ari_mind.free()


func _test_corner_bow_execution() -> void:
	var ari_mind = AriMindScript.new()
	var decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"bow_tower_count": 1,
		"enemy_type_counts": {"zombie": 1},
		"grounded_plan": [{
			"affordance_id": "use_cover",
			"priority": 0.92,
			"reason": "Use the wall as the corner.",
		}, {
			"affordance_id": "ranged_attack",
			"priority": 0.90,
			"reason": "Use bow range from cover.",
		}],
	}))
	_assert(["use_cover", "use_tower"].has(str(decision.get("job", ""))), "corner bow should execute as cover plus range, not a new tactic")
	_assert(decision.get("job", "") != "build_wall", "corner bow should not collapse into build-wall-only when cover exists")
	ari_mind.free()


func _test_combo_wall_light_tower_builds_wall_floor() -> void:
	var ari_mind = AriMindScript.new()
	var mine_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 0,
		"aura_orb_count": 1,
		"bow_tower_count": 1,
		"stone": 0,
		"priority_hints": {
			"wall": 0.85,
			"use_tower": 0.85,
			"lure_to_aura": 0.80,
		},
		"grounded_plan": [{
			"affordance_id": "use_tower",
			"priority": 0.90,
			"reason": "Use height.",
		}, {
			"affordance_id": "lure_to_aura",
			"priority": 0.85,
			"reason": "Use light.",
		}],
	}))
	_assert(mine_decision.get("job", "") == "mine_stone", "wall/light/tower combo signs should mine for missing basic walls before passive tower use")

	var wall_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 0,
		"aura_orb_count": 1,
		"bow_tower_count": 1,
		"stone": 4,
		"priority_hints": {
			"wall": 0.85,
			"use_tower": 0.85,
			"lure_to_aura": 0.80,
		},
		"grounded_plan": [{
			"affordance_id": "use_tower",
			"priority": 0.90,
			"reason": "Use height.",
		}, {
			"affordance_id": "lure_to_aura",
			"priority": 0.85,
			"reason": "Use light.",
		}],
	}))
	_assert(wall_decision.get("job", "") == "build_wall", "wall/light/tower combo signs should build basic walls before passive tower use")
	var implied_cover_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 0,
		"aura_orb_count": 1,
		"bow_tower_count": 1,
		"stone": 4,
		"priority_hints": {
			"build_tower": 0.90,
			"use_tower": 0.85,
			"aura_orb": 0.82,
			"lure_to_aura": 0.78,
		},
		"grounded_plan": [{
			"affordance_id": "use_tower",
			"priority": 0.90,
			"reason": "Use height.",
		}, {
			"affordance_id": "lure_to_aura",
			"priority": 0.85,
			"reason": "Use light.",
		}],
	}))
	_assert(implied_cover_decision.get("job", "") == "build_wall", "tower-plus-light plans should add one basic cover layer before passive staging even when the sign did not say wall")
	ari_mind.free()


func _test_hunger_food_execution() -> void:
	var ari_mind = AriMindScript.new()
	var decision := ari_mind.choose_daytime_job(_base_mind_context({
		"food": 1,
		"needs": {"hunger": 78.0, "stamina": 70.0, "fear": 20.0},
		"grounded_plan": [{
			"affordance_id": "eat_food",
			"priority": 0.95,
			"reason": "A full stomach is a wall inside me.",
		}],
	}))
	_assert(decision.get("job", "") == "eat_food", "stomach-as-wall signs should become eating when food exists and hunger is high")
	ari_mind.free()


func _test_thorn_tank_holds_thorn_ground_at_night() -> void:
	var sign_mind = SignMindScript.new()
	var ari_mind = AriMindScript.new()
	var interpretation: Dictionary = sign_mind.interpret_sign("heavy armor and patient skin", {"points": {"armor": 5, "thorns": 5, "defense": 4}})
	var hints: Dictionary = interpretation.get("priority_hints", {})
	_assert(float(hints.get("use_thorns", 0.0)) > 0.40, "armor/skin signs should create a thorn-use hint")
	var decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 76.0,
		"ari_hp_ratio": 0.82,
		"thorn_totem_count": 1,
		"has_valid_thorn_totem": true,
		"combat_stats": {"combat_level": 0.2, "sword_skill": 0.0, "attack_damage": 7.0, "armor": 0.18},
		"priority_hints": hints,
		"run_build": {"points": {"armor": 5, "defense": 4, "regeneration": 3}},
	}))
	_assert(decision.get("job", "") == "use_thorns", "armor/thorns night tactics should hold real thorn radius instead of just waiting")
	_assert(str(decision.get("reason", "")).to_lower().contains("thorn"), "thorn-tank night reason should explain the thorn ground")
	var close_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 28.0,
		"ari_hp_ratio": 0.82,
		"thorn_totem_count": 1,
		"has_valid_thorn_totem": true,
		"combat_stats": {"combat_level": 0.2, "sword_skill": 0.0, "attack_damage": 7.0, "armor": 0.18},
		"priority_hints": hints,
		"run_build": {"points": {"armor": 5, "defense": 4, "regeneration": 3}},
	}))
	_assert(close_decision.get("job", "") == "use_thorns", "armor/thorn builds should keep holding thorn ground inside normal contact range")
	sign_mind.free()
	ari_mind.free()


func _test_no_touch_floor_fight_avoids_melee() -> void:
	var sign_mind = SignMindScript.new()
	var ari_mind = AriMindScript.new()
	var interpretation: Dictionary = sign_mind.interpret_sign("do not touch them, make the floor fight", {"points": {"trapcraft": 6, "building": 3, "warding": 3}})
	var hints: Dictionary = interpretation.get("priority_hints", {})
	_assert(float(hints.get("build_trap", 0.0)) >= 0.70, "no-touch floor signs should still strongly prefer traps")
	_assert(float(hints.get("fight_head_on", 0.0)) <= 0.20, "no-touch floor signs should suppress direct melee interpretation")
	_assert(float(hints.get("avoid_killing", 0.0)) >= 0.45, "no-touch floor signs should tell Ari to avoid personal contact")
	var night_decision: Dictionary = ari_mind.call("choose_night_tactic", _base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 84.0,
		"ari_hp_ratio": 0.9,
		"spike_trap_count": 2,
		"combat_stats": {"combat_level": 2.0, "sword_skill": 1.5, "attack_damage": 18.0, "armor": 0.1},
		"priority_hints": hints,
	}))
	_assert(night_decision.get("job", "") != "fight_head_on", "no-touch trap signs should not become melee even when Ari is strong enough")
	sign_mind.free()
	ari_mind.free()


func _test_no_wall_light_sign_builds_light_first() -> void:
	var sign_mind = SignMindScript.new()
	var ari_mind = AriMindScript.new()
	var interpretation: Dictionary = sign_mind.interpret_sign("do not build walls, make the light circle kill them")
	var hints: Dictionary = interpretation.get("priority_hints", {})
	_assert(float(hints.get("wall", 0.0)) <= 0.10, "no-wall light signs should suppress new wall construction hints")
	_assert(float(hints.get("avoid_build_wall", 0.0)) >= 0.70, "no-wall light signs should create an explicit avoid-wall planner hint")
	_assert(float(hints.get("aura_orb", 0.0)) >= 0.70, "no-wall light signs should keep the light-circle alternative strong")
	var decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 0,
		"aura_orb_count": 0,
		"stone": 20,
		"priority_hints": hints,
		"run_build": {"points": {"warding": 7, "building": 3, "fear_control": 2}},
	}))
	_assert(decision.get("job", "") == "place_aura_orb", "explicit no-wall light signs should make Ari build light before new walls")
	var light_ready_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 0,
		"aura_orb_count": 2,
		"stone": 20,
		"priority_hints": hints,
		"run_build": {"points": {"warding": 7, "building": 3, "fear_control": 2}},
	}))
	_assert(light_ready_decision.get("job", "") != "build_wall", "explicit no-wall light signs should not drift back into baseline wall building after light exists")
	sign_mind.free()
	ari_mind.free()


func _test_weapon_anxiety_adds_fear_light_to_ranged_plan() -> void:
	var sign_mind = SignMindScript.new()
	var ari_mind = AriMindScript.new()
	var interpretation: Dictionary = sign_mind.interpret_sign("using weapons makes you anxious but arrows keep teeth far away", {"points": {"bow": 5, "attack_range": 4, "building": 3}})
	var hints: Dictionary = interpretation.get("priority_hints", {})
	_assert(float(hints.get("range", 0.0)) >= 0.70, "weapon-anxiety arrow signs should still keep the ranged plan")
	_assert(float(hints.get("build_fear_lantern", 0.0)) >= 0.35, "weapon-anxiety signs should add a fear-management structure")
	var tower_ready_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 0,
		"bow_tower_count": 1,
		"fear_lantern_count": 0,
		"stone": 20,
		"priority_hints": hints,
		"run_build": {"points": {"bow": 5, "attack_range": 4, "building": 3}},
	}))
	_assert(tower_ready_decision.get("job", "") == "build_fear_lantern", "ranged weapon-anxiety plans should calm fear after the tower exists")
	var support_wall_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 0,
		"bow_tower_count": 1,
		"fear_lantern_count": 1,
		"stone": 4,
		"priority_hints": hints,
		"run_build": {"points": {"bow": 5, "attack_range": 4, "building": 3}},
	}))
	_assert(support_wall_decision.get("job", "") == "build_wall", "ranged weapon-anxiety plans should add one basic cover layer after tower and lantern exist")
	sign_mind.free()
	ari_mind.free()


func _test_warm_fear_light_uses_existing_lantern_at_night() -> void:
	var sign_mind = SignMindScript.new()
	var ari_mind = AriMindScript.new()
	var interpretation: Dictionary = sign_mind.interpret_sign("a warm light makes fear smaller", {"points": {"fear_control": 6, "warding": 3}})
	var hints: Dictionary = interpretation.get("priority_hints", {})
	_assert(float(hints.get("build_fear_lantern", 0.0)) >= 0.60, "warm-fear signs should build a fear lantern")
	_assert(float(hints.get("use_fear_lantern", 0.0)) > 0.55, "warm-fear signs should create a night use-lantern hint")
	var no_stone_buildup := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"aura_orb_count": 1,
		"fear_lantern_count": 1,
		"stone": 0,
		"priority_hints": hints,
		"run_build": {"points": {"movement": 7, "fear_control": 3, "building": 2}},
	}))
	_assert(no_stone_buildup.get("job", "") == "mine_stone", "warm-fear plans should mine toward stronger cover after the first warm-light core exists")
	var cover_buildup := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"aura_orb_count": 1,
		"fear_lantern_count": 1,
		"stone": 20,
		"priority_hints": hints,
		"run_build": {"points": {"movement": 7, "fear_control": 3, "building": 2}},
	}))
	_assert(cover_buildup.get("job", "") == "build_wall", "warm-fear plans should reinforce thin cover before rehearsing aura tactics in empty daylight")
	var night_decision := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 102.0,
		"ari_hp_ratio": 0.78,
		"wall_count": 1,
		"aura_orb_count": 1,
		"fear_lantern_count": 1,
		"has_valid_cover": true,
		"has_valid_aura": true,
		"has_valid_fear_lantern": true,
		"priority_hints": hints,
		"needs": {"fear": 72.0, "hunger": 30.0, "stamina": 70.0},
	}))
	_assert(night_decision.get("job", "") == "use_fear_lantern", "warm-fear signs should make Ari hold an existing lantern at night")
	var wounded_lantern_decision := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"nearest_enemy_distance": 82.0,
		"ari_hp_ratio": 0.29,
		"wall_count": 1,
		"aura_orb_count": 1,
		"fear_lantern_count": 1,
		"has_valid_cover": true,
		"has_valid_aura": true,
		"has_valid_fear_lantern": true,
		"priority_hints": hints,
		"needs": {"fear": 68.0, "hunger": 30.0, "stamina": 58.0},
	}))
	_assert(wounded_lantern_decision.get("job", "") == "use_fear_lantern", "wounded warm-fear plans should hold a valid lantern instead of fleeing through danger")
	var close_decision := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 28.0,
		"ari_hp_ratio": 0.78,
		"fear_lantern_count": 1,
		"has_valid_fear_lantern": true,
		"priority_hints": hints,
		"needs": {"fear": 72.0, "hunger": 30.0, "stamina": 70.0},
	}))
	_assert(close_decision.get("job", "") == "flee", "lantern-use signs should still flee when enemies are already too close")
	sign_mind.free()
	ari_mind.free()


func _test_moon_cowards_stages_before_first_contact() -> void:
	var sign_mind = SignMindScript.new()
	var ari_mind = AriMindScript.new()
	var interpretation: Dictionary = sign_mind.interpret_sign("the moon hates cowards", {"points": {"fear_control": 5, "movement": 3, "warding": 2}})
	var hints: Dictionary = interpretation.get("priority_hints", {})
	_assert(float(hints.get("survive_until_morning", 0.0)) >= 0.45, "moon/coward signs should become a night survival cue")
	_assert(float(hints.get("build_fear_lantern", 0.0)) >= 0.40, "moon/coward signs should make Ari prepare fear control")
	var stage_decision := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 0,
		"nearest_enemy_distance": INF,
		"ari_hp_ratio": 1.0,
		"wall_count": 2,
		"aura_orb_count": 1,
		"fear_lantern_count": 0,
		"has_valid_cover": true,
		"has_valid_aura": true,
		"has_valid_fear_lantern": false,
		"priority_hints": hints,
		"needs": {"fear": 42.0, "hunger": 30.0, "stamina": 82.0},
	}))
	_assert(stage_decision.get("job", "") == "lure_to_aura", "moon/coward night plans should stage at existing aura before the first enemy touches Ari")
	var lantern_stage_decision := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 0,
		"nearest_enemy_distance": INF,
		"ari_hp_ratio": 0.82,
		"wall_count": 2,
		"aura_orb_count": 1,
		"fear_lantern_count": 1,
		"has_valid_cover": true,
		"has_valid_aura": true,
		"has_valid_fear_lantern": true,
		"priority_hints": hints,
		"needs": {"fear": 58.0, "hunger": 30.0, "stamina": 82.0},
	}))
	_assert(lantern_stage_decision.get("job", "") == "use_fear_lantern", "moon/coward night plans should hold a valid lantern before enemies arrive")
	sign_mind.free()
	ari_mind.free()


func _test_false_me_uses_existing_decoy_at_night() -> void:
	var sign_mind = SignMindScript.new()
	var ari_mind = AriMindScript.new()
	var interpretation: Dictionary = sign_mind.interpret_sign("let a false me take their teeth", {"points": {"trapcraft": 6, "defense": 4}})
	var hints: Dictionary = interpretation.get("priority_hints", {})
	_assert(float(hints.get("build_decoy_idol", 0.0)) >= 0.55, "false-me signs should build a decoy")
	_assert(float(hints.get("use_decoy_idol", 0.0)) > 0.45, "false-me signs should create a night use-decoy hint")
	var night_decision := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 108.0,
		"ari_hp_ratio": 0.74,
		"wall_count": 1,
		"aura_orb_count": 1,
		"decoy_idol_count": 1,
		"has_valid_cover": true,
		"has_valid_aura": true,
		"has_valid_decoy_idol": true,
		"priority_hints": hints,
	}))
	_assert(night_decision.get("job", "") == "use_decoy_idol", "false-me signs should make Ari use an existing decoy at night")
	var breaking_decoy_decision := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"nearest_enemy_distance": 82.0,
		"ari_hp_ratio": 0.74,
		"wall_count": 1,
		"aura_orb_count": 1,
		"decoy_idol_count": 1,
		"has_valid_cover": true,
		"has_valid_aura": true,
		"has_valid_decoy_idol": true,
		"decoy_idol_hp_ratio": 0.30,
		"priority_hints": hints,
	}))
	_assert(breaking_decoy_decision.get("job", "") == "lure_to_aura", "false-me plans should rotate to existing light when the decoy is almost broken")
	var gone_decoy_decision := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"nearest_enemy_distance": 82.0,
		"ari_hp_ratio": 0.62,
		"wall_count": 1,
		"aura_orb_count": 1,
		"decoy_idol_count": 0,
		"has_valid_cover": true,
		"has_valid_aura": true,
		"has_valid_decoy_idol": false,
		"priority_hints": hints,
	}))
	_assert(gone_decoy_decision.get("job", "") == "lure_to_aura", "false-me plans should keep using existing light after the decoy collapses")
	var close_decision := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 28.0,
		"ari_hp_ratio": 0.74,
		"decoy_idol_count": 1,
		"has_valid_decoy_idol": true,
		"priority_hints": hints,
	}))
	_assert(close_decision.get("job", "") == "flee", "decoy-use signs should still flee when enemies are already too close")
	sign_mind.free()
	ari_mind.free()


func _test_reflection_waits_for_basic_survival() -> void:
	var ari_mind = AriMindScript.new()
	var reflection_plan := [{
		"affordance_id": "reflect_library",
		"priority": 0.95,
		"reason": "The sign asks Ari to think about what went wrong.",
	}]
	var unsafe_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 0,
		"aura_orb_count": 0,
		"priority_hints": {"reflect_library": 0.9},
		"grounded_plan": reflection_plan,
	}))
	_assert(unsafe_decision.get("job", "") == "build_wall", "reflection signs should build survival basics before reading")
	var thin_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"aura_orb_count": 0,
		"priority_hints": {"reflect_library": 0.9},
		"grounded_plan": reflection_plan,
	}))
	_assert(thin_decision.get("job", "") == "place_aura_orb", "reflection signs should add backup light before reading")
	var safe_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"aura_orb_count": 1,
		"priority_hints": {"reflect_library": 0.9},
		"grounded_plan": reflection_plan,
	}))
	_assert(safe_decision.get("job", "") == "reflect_library", "reflection signs should still read once basic survival is ready")
	var wounded_after_lesson_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"aura_orb_count": 1,
		"repair_bench_count": 1,
		"damaged_structure_count": 1,
		"lowest_structure_hp_ratio": 0.94,
		"lesson_count": 2,
		"meaningful_event_count": 2,
		"ari_hp_ratio": 0.62,
		"food": 3,
		"needs": {"hunger": 56.0, "stamina": 98.0, "fear": 62.0},
		"priority_hints": {"reflect_library": 0.9},
		"grounded_plan": reflection_plan,
	}))
	_assert(wounded_after_lesson_decision.get("job", "") == "rest", "reflection signs should recover after painful lessons before idling into the next night")
	var night_defense_decision := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"nearest_enemy_distance": 82.0,
		"ari_hp_ratio": 0.82,
		"wall_count": 2,
		"aura_orb_count": 1,
		"has_valid_cover": true,
		"has_valid_aura": true,
		"priority_hints": {"reflect_library": 0.9},
		"grounded_plan": reflection_plan,
	}))
	_assert(night_defense_decision.get("job", "") == "lure_to_aura", "reflection signs should still use existing light when enemies arrive at night")
	ari_mind.free()


func _test_wall_failure_lesson_drives_repair_support() -> void:
	var memory = AriMemoryScript.new()
	memory.record_event("structure_destroyed", {"structure_type": "wall", "day": 2, "phase": "night"})
	var note: Dictionary = memory.create_lifetime_note_from_recent_events(2)
	var doctrines: Array = note.get("doctrines", [])
	_assert(doctrines.size() > 0, "wall-failure reflections should compile into active repair doctrine")

	var doctrine = AriDoctrineScript.new()
	doctrine.add_doctrines(doctrines)
	var doctrine_context := {
		"phase": "midday",
		"enemy_type_counts": {},
		"ari_hp_ratio": 0.86,
		"recent_events": memory.get_recent_events(30),
	}
	var active_plan: Array = doctrine.get_active_plan(doctrine_context)
	var active_bias: Dictionary = doctrine.get_active_bias(doctrine_context)
	_assert(active_plan.size() > 0, "wall-failure doctrine should expose an executable repair-support plan")
	_assert(float(active_bias.get("build_repair_bench", 0.0)) > 0.20, "wall-failure doctrine should promote repair tools strongly enough to affect Ari")

	var ari_mind = AriMindScript.new()
	var reflection_plan := [{
		"affordance_id": "reflect_library",
		"priority": 0.95,
		"reason": "The sign asks Ari to think about what went wrong.",
	}]
	var decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"aura_orb_count": 1,
		"repair_bench_count": 0,
		"lesson_count": 1,
		"meaningful_event_count": 0,
		"priority_hints": {"reflect_library": 0.9},
		"grounded_plan": reflection_plan,
		"agent_grounded_plan": active_plan,
		"lesson_priority_bias": active_bias,
		"needs": {"hunger": 36.0, "stamina": 92.0, "fear": 24.0},
		"ari_hp_ratio": 0.86,
	}))
	_assert(decision.get("job", "") == "build_repair_bench", "after writing a wall-failure lesson, Ari should prepare repair tools before another library loop")
	ari_mind.free()


func _test_ground_grab_sign_prefers_tar_pit() -> void:
	var sign_mind = SignMindScript.new()
	var ari_mind = AriMindScript.new()
	var interpretation: Dictionary = sign_mind.interpret_sign("make the ground grab their feet before they reach me", {"points": {"trapcraft": 6, "building": 3, "warding": 3}})
	var hints: Dictionary = interpretation.get("priority_hints", {})
	_assert(float(hints.get("build_tar_pit", 0.0)) > float(hints.get("build_trap", 0.0)), "ground-grab signs should prefer slow tar pits over spike traps")
	_assert(float(hints.get("lure_to_tar_pit", 0.0)) > 0.70, "ground-grab signs should create a night lure-through-mud hint")
	_assert(float(hints.get("smith_sword", 0.0)) < 0.25, "generic make-language should not trigger smithing without sword words")
	var decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"aura_orb_count": 1,
		"priority_hints": hints,
		"run_build": {"points": {"trapcraft": 6, "building": 3, "warding": 3}},
	}))
	_assert(decision.get("job", "") == "build_tar_pit", "ground-grab signs should become tar-pit building when defenses exist")
	var combo_hints: Dictionary = sign_mind.interpret_sign("make a light circle and slow mud before teeth arrive", {"points": {"trapcraft": 6, "building": 3, "warding": 3}}).get("priority_hints", {})
	_assert(float(combo_hints.get("aura_orb", 0.0)) > 0.25, "light-and-mud signs should still read light circle intent")
	_assert(float(combo_hints.get("build_tar_pit", 0.0)) > 0.25, "light-and-mud signs should still read slow mud intent")
	var combo_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"aura_orb_count": 1,
		"tar_pit_count": 0,
		"stone": 20,
		"priority_hints": combo_hints,
		"run_build": {"points": {"trapcraft": 6, "building": 3, "warding": 3}},
	}))
	_assert(combo_decision.get("job", "") == "build_tar_pit", "light-and-mud signs should add the requested slow mud after the first light exists")
	var night_decision := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 104.0,
		"ari_hp_ratio": 0.86,
		"wall_count": 1,
		"aura_orb_count": 1,
		"tar_pit_count": 1,
		"has_valid_cover": true,
		"has_valid_aura": true,
		"has_valid_tar_pit": true,
		"priority_hints": hints,
	}))
	_assert(night_decision.get("job", "") == "lure_to_tar_pit", "ground-grab signs should make Ari use an existing tar pit at night")
	var combo_night_decision := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 104.0,
		"ari_hp_ratio": 0.86,
		"wall_count": 1,
		"aura_orb_count": 1,
		"tar_pit_count": 1,
		"has_valid_cover": true,
		"has_valid_aura": true,
		"has_valid_tar_pit": true,
		"priority_hints": combo_hints,
	}))
	_assert(combo_night_decision.get("job", "") == "lure_to_aura", "light-and-mud signs should use the light as the kill center once slow mud exists")
	var combo_upkeep_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"aura_orb_count": 1,
		"tar_pit_count": 1,
		"stone": 12,
		"damaged_structure_count": 1,
		"lowest_structure_hp_ratio": 0.90,
		"priority_hints": combo_hints,
		"run_build": {"points": {"trapcraft": 6, "building": 3, "warding": 3}},
	}))
	_assert(combo_upkeep_decision.get("job", "") == "repair_structure", "light-and-mud plans should top off a damaged kill-zone core before idling or farming")
	var combo_recovery_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"aura_orb_count": 1,
		"tar_pit_count": 1,
		"stone": 12,
		"damaged_structure_count": 0,
		"lowest_structure_hp_ratio": 1.0,
		"ari_hp_ratio": 0.73,
		"priority_hints": combo_hints,
		"run_build": {"points": {"trapcraft": 6, "building": 3, "warding": 3}},
		"needs": {"hunger": 38.0, "stamina": 84.0, "fear": 34.0},
	}))
	_assert(combo_recovery_decision.get("job", "") == "rest", "light-and-mud plans should recover Ari after a rough night once the kill-zone core is ready")
	var upkeep_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"aura_orb_count": 1,
		"spike_trap_count": 1,
		"tar_pit_count": 1,
		"stone": 4,
		"damaged_structure_count": 3,
		"lowest_structure_hp_ratio": 0.59,
		"priority_hints": hints,
		"run_build": {"points": {"trapcraft": 6, "building": 3, "warding": 3}},
	}))
	_assert(upkeep_decision.get("job", "") == "repair_structure", "ground-control plans should keep damaged mud/trap defenses repaired before idling")
	var broken_tar_fallback := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"nearest_enemy_distance": 70.0,
		"ari_hp_ratio": 0.80,
		"wall_count": 1,
		"aura_orb_count": 1,
		"tar_pit_count": 0,
		"has_valid_cover": true,
		"has_valid_aura": true,
		"has_valid_tar_pit": false,
		"priority_hints": hints,
	}))
	_assert(broken_tar_fallback.get("job", "") == "lure_to_aura", "ground-control plans should rotate to aura when the tar pit is gone")
	var close_decision := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 1,
		"nearest_enemy_distance": 28.0,
		"ari_hp_ratio": 0.86,
		"tar_pit_count": 1,
		"has_valid_tar_pit": true,
		"priority_hints": hints,
	}))
	_assert(close_decision.get("job", "") == "flee", "tar-lure signs should still flee when enemies are already too close")
	sign_mind.free()
	ari_mind.free()


func _test_repair_tools_sign_builds_bench_before_damage() -> void:
	var sign_mind = SignMindScript.new()
	var ari_mind = AriMindScript.new()
	var interpretation: Dictionary = sign_mind.interpret_sign("build repair tools and fix damaged defenses before fighting", {"points": {"building": 6, "defense": 4}})
	var hints: Dictionary = interpretation.get("priority_hints", {})
	_assert(float(hints.get("build_repair_bench", 0.0)) > 0.25, "repair-tools signs should create a repair bench hint")
	_assert(float(hints.get("repair_structure", 0.0)) > 0.25, "repair-tools signs should create a repair structure hint")
	var decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"stone": 20,
		"damaged_structure_count": 0,
		"repair_bench_count": 0,
		"priority_hints": hints,
		"run_build": {"points": {"building": 6, "defense": 4}},
	}))
	_assert(decision.get("job", "") == "build_repair_bench", "plain repair-tools signs should build repair support before adding unnecessary extra walls; got %s because %s" % [str(decision.get("job", "")), str(decision.get("reason", ""))])
	var bench_decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
		"stone": 20,
		"damaged_structure_count": 0,
		"repair_bench_count": 0,
		"priority_hints": hints,
		"run_build": {"points": {"building": 6, "defense": 4}},
	}))
	_assert(bench_decision.get("job", "") == "build_repair_bench", "repair-tools signs should build a repair bench after enough walls exist; got %s because %s" % [str(bench_decision.get("job", "")), str(bench_decision.get("reason", ""))])
	var close_runner_decision := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 3,
		"enemy_type_counts": {"runner": 2, "zombie": 1},
		"nearest_enemy_distance": 36.0,
		"wall_count": 3,
		"aura_orb_count": 0,
		"repair_bench_count": 1,
		"has_valid_cover": true,
		"has_valid_aura": false,
		"priority_hints": hints,
		"run_build": {"points": {"building": 6, "defense": 4}},
		"current_job": "use_cover",
	}))
	_assert(close_runner_decision.get("job", "") == "use_cover", "repair-tools Ari should hold prepared wall cover against close runners instead of fleeing into open ground")
	sign_mind.free()
	ari_mind.free()


func _test_plain_anti_air_instead_of_walls_avoids_wall_habit() -> void:
	var sign_mind = SignMindScript.new()
	var ari_mind = AriMindScript.new()
	var interpretation: Dictionary = sign_mind.interpret_sign("if enemies fly, build storm rods instead of walls", {"points": {"building": 5, "warding": 4}})
	var hints: Dictionary = interpretation.get("priority_hints", {})
	_assert(float(hints.get("build_storm_rod", 0.0)) >= 0.75, "plain anti-air signs should strongly prefer Storm Rod")
	_assert(float(hints.get("avoid_build_wall", 0.0)) >= 0.70, "instead-of-walls language should become a strong general wall avoidance preference")
	_assert(float(hints.get("wall", 0.0)) <= 0.15, "instead-of-walls language should not keep ordinary walls as the main plan")
	var decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 0,
		"stone": 20,
		"enemy_type_counts": {"flying": 1},
		"priority_hints": hints,
		"run_build": {"points": {"building": 5, "warding": 4}},
	}))
	_assert(decision.get("job", "") == "build_storm_rod", "anti-air instead-of-walls plans should build Storm Rod before ordinary wall cover when it is affordable")
	sign_mind.free()
	ari_mind.free()


func _test_stay_near_safest_defense_holds_existing_anchor() -> void:
	var sign_mind = SignMindScript.new()
	var ari_mind = AriMindScript.new()
	var interpretation: Dictionary = sign_mind.interpret_sign("choose the safest defense and stay near it, do not run back and forth", {"points": {"building": 4, "defense": 5}})
	var hints: Dictionary = interpretation.get("priority_hints", {})
	_assert(float(hints.get("hold_best_defense", 0.0)) >= 0.70, "stay-near-safest-defense language should create a general hold-best-defense hint")
	_assert(float(hints.get("defensive_wait", 0.0)) >= 0.70, "do-not-run-back-and-forth language should strengthen defensive waiting")
	var quiet_night := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 0,
		"wall_count": 1,
		"aura_orb_count": 1,
		"bow_tower_count": 1,
		"has_valid_cover": true,
		"has_valid_aura": true,
		"has_valid_tower": true,
		"priority_hints": hints,
		"current_job": "use_tower",
	}))
	_assert(quiet_night.get("job", "") == "use_tower", "safe-defense hold plans should keep the strongest existing anchor on quiet nights instead of idling")
	var pressured_night := ari_mind.choose_night_tactic(_base_mind_context({
		"is_night": true,
		"phase": "night",
		"enemy_count": 2,
		"enemy_type_counts": {"zombie": 2},
		"nearest_enemy_distance": 95.0,
		"wall_count": 1,
		"aura_orb_count": 1,
		"bow_tower_count": 1,
		"has_valid_cover": true,
		"has_valid_aura": true,
		"has_valid_tower": true,
		"priority_hints": hints,
		"current_job": "use_tower",
	}))
	_assert(pressured_night.get("job", "") == "use_tower", "safe-defense hold plans should keep the chosen tower anchor while danger is not close enough to force a safety override")
	sign_mind.free()
	ari_mind.free()


func _test_agent_grounded_plan_drives_day_job() -> void:
	var ari_mind = AriMindScript.new()
	var decision := ari_mind.choose_daytime_job(_base_mind_context({
		"agent_grounded_plan": [{
			"affordance_id": "build_tower",
			"priority": 0.95,
			"reason": "Agent plan wants height before night.",
		}],
	}))
	_assert(decision.get("job", "") == "build_bow_tower", "active agent plan should drive real tower building")
	ari_mind.free()


func _test_agent_build_tower_plan_can_add_redundancy() -> void:
	var ari_mind = AriMindScript.new()
	var decision := ari_mind.choose_daytime_job(_base_mind_context({
		"bow_tower_count": 1,
		"has_valid_tower": true,
		"agent_grounded_plan": [{
			"affordance_id": "build_tower",
			"priority": 0.95,
			"reason": "Agent plan wants a second tower before night.",
		}],
	}))
	_assert(decision.get("job", "") == "build_bow_tower", "build_tower agent plan should be able to add a redundant tower")
	ari_mind.free()


func _test_agent_aura_plan_can_add_redundancy() -> void:
	var ari_mind = AriMindScript.new()
	var decision := ari_mind.choose_daytime_job(_base_mind_context({
		"aura_orb_count": 1,
		"has_valid_aura": true,
		"agent_grounded_plan": [{
			"affordance_id": "place_aura_orb",
			"priority": 0.95,
			"reason": "Agent plan wants a second light circle before night.",
		}],
	}))
	_assert(decision.get("job", "") == "place_aura_orb", "place_aura_orb agent plan should be able to add a redundant aura")
	ari_mind.free()


func _test_agent_mine_stone_plan_drives_resource_work() -> void:
	var ari_mind = AriMindScript.new()
	var decision := ari_mind.choose_daytime_job(_base_mind_context({
		"agent_grounded_plan": [{
			"affordance_id": "mine_stone",
			"priority": 0.95,
			"reason": "Agent plan needs stone for the next defense.",
		}],
	}))
	_assert(decision.get("job", "") == "mine_stone", "mine_stone agent plan should drive real resource work")
	ari_mind.free()


func _test_negative_lesson_bias_changes_real_job() -> void:
	var ari_mind = AriMindScript.new()
	var decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"priority_hints": {"wall": 1.0},
		"lesson_priority_bias": {
			"build_wall": -1.0,
			"build_storm_rod": 0.4,
		},
	}))
	_assert(decision.get("job", "") == "build_storm_rod", "negative wall doctrine should let storm doctrine change real behavior")
	ari_mind.free()


func _test_world_allows_redundant_tower_slots() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for redundant tower slot test")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("add_stone", 80)
	var first_slot: Dictionary = world.call("_get_next_build_slot", "bow_tower")
	_assert(first_slot.has("cell"), "first tower slot should exist")
	if first_slot.has("cell"):
		world.call("_place_bow_tower_at_cell", first_slot["cell"])
	var second_slot: Dictionary = world.call("_get_next_build_slot", "bow_tower")
	_assert(second_slot.has("cell"), "second tower slot should exist for redundant agent plans")
	if second_slot.has("cell"):
		world.call("_place_bow_tower_at_cell", second_slot["cell"])
	_assert(int(world.call("get_bow_tower_count")) >= 2, "world should allow at least two bow towers")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_world_allows_redundant_aura_slots() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for redundant aura slot test")
	if world_scene == null:
		return
	var world: World = world_scene.instantiate()
	root.add_child(world)
	await process_frame
	var resource_system = world.get("resource_system")
	if resource_system != null:
		resource_system.call("add_stone", 80)
	var first_slot: Dictionary = world.call("_get_next_build_slot", "aura_orb")
	_assert(first_slot.has("cell"), "first aura slot should exist")
	if first_slot.has("cell"):
		world.call("_place_aura_orb_at_cell", first_slot["cell"])
	var second_slot: Dictionary = world.call("_get_next_build_slot", "aura_orb")
	_assert(second_slot.has("cell"), "second aura slot should exist for redundant agent plans")
	if second_slot.has("cell"):
		world.call("_place_aura_orb_at_cell", second_slot["cell"])
	_assert(int(world.call("get_aura_orb_count")) >= 2, "world should allow at least two aura orbs")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_world_doctrine_changes_real_behavior() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for doctrine behavior checks")
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
	world.call("_spawn_enemy", arena.get_center() + Vector2(190.0, -90.0), "flying")
	await process_frame
	world.call("_clear_agent_plan")
	world.get("ari_doctrine").add_doctrine({
		"id": "wings_ignore_walls",
		"when": {"enemy_type_present": "flying"},
		"bias": {"build_storm_rod": 0.9, "build_wall": -0.7},
		"plan": [{
			"affordance_id": "build_storm_rod",
			"priority": 0.9,
			"reason": "Wings need a sky answer.",
		}],
	})
	var context: Dictionary = world.call("_get_ari_mind_context")
	var decision: Dictionary = world.get("ari_mind").choose_daytime_job(context)
	_assert(decision.get("job", "") == "build_storm_rod", "learned flying doctrine should change Ari's real job")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_world_learning_disabled_ablation_blocks_doctrine_behavior() -> void:
	var world_scene = load("res://scenes/world/World.tscn")
	_assert(world_scene != null, "World scene should load for learning ablation checks")
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
	var build_grid = world.get("build_grid")
	if build_grid != null:
		var first_wall: Dictionary = world.call("_get_next_build_slot", "wall")
		if first_wall.has("cell"):
			world.call("_place_wall_at_cell", first_wall["cell"])
		var second_wall: Dictionary = world.call("_get_next_build_slot", "wall")
		if second_wall.has("cell"):
			world.call("_place_wall_at_cell", second_wall["cell"])
	world.set("sign_text", "")
	world.set("sign_priority_hints", {})
	world.set("sign_grounded_plan", [])
	world.call("_clear_agent_plan")
	world.get("ari_doctrine").add_doctrine({
		"id": "ablation_repair_memory",
		"when": {"min_day": 1},
		"bias": {"build_repair_bench": 0.95, "build_wall": -0.95},
		"plan": [{
			"affordance_id": "build_repair_bench",
			"priority": 0.95,
			"reason": "Learned A/B memory says repair tools first.",
		}],
	})
	var enabled_context: Dictionary = world.call("_get_ari_mind_context")
	var enabled_decision: Dictionary = world.get("ari_mind").choose_daytime_job(enabled_context)
	_assert(enabled_decision.get("job", "") == "build_repair_bench", "learning-enabled A/B branch should let learned doctrine change the real job; got %s because %s" % [str(enabled_decision.get("job", "")), str(enabled_decision.get("reason", ""))])
	_assert(world.has_method("set_learning_enabled"), "World should expose a test-safe learning-enabled switch for A/B playtests")
	if world.has_method("set_learning_enabled"):
		world.call("set_learning_enabled", false)
		var disabled_context: Dictionary = world.call("_get_ari_mind_context")
		var disabled_decision: Dictionary = world.get("ari_mind").choose_daytime_job(disabled_context)
		_assert(disabled_decision.get("job", "") != "build_repair_bench", "learning-disabled A/B branch should remove learned doctrine from real job selection")
		_assert(disabled_context.get("grounded_plan", []).is_empty() or not _array_text_contains(disabled_context.get("grounded_plan", []), "build_repair_bench"), "learning-disabled context should not expose learned doctrine plan items")
	root.remove_child(world)
	world.queue_free()
	await process_frame


func _test_impossible_grounded_plan_falls_through() -> void:
	var ari_mind = AriMindScript.new()
	var decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 1,
		"bow_tower_count": 0,
		"grounded_plan": [{
			"affordance_id": "ranged_attack",
			"priority": 0.95,
			"reason": "No tower exists, so this is not feasible yet.",
		}, {
			"affordance_id": "use_existing_wall",
			"priority": 0.90,
			"reason": "Use the cover that exists.",
		}],
	}))
	_assert(decision.get("job", "") == "use_cover", "AriMind should skip impossible ranged attack and use the next feasible plan item")
	ari_mind.free()


func _test_bridge_validation_keeps_failure_safe() -> void:
	var bridge: AIBridge = AIBridgeScript.new()
	var payload := {
		"local_fallback": {
			"interpretation": "Fallback wall cover.",
			"priority_hints": {"use_cover": 0.7},
			"grounded_plan": [{
				"affordance_id": "use_cover",
				"priority": 0.7,
				"reason": "Fallback cover.",
			}],
			"sign_strength": 0.5,
			"resonance": 0.5,
		},
	}
	var failed: Dictionary = bridge.call("_parse_deep_interpretation_response", payload, HTTPRequest.RESULT_TIMEOUT, 0, PackedByteArray())
	_assert(not bool(failed.get("ok", true)), "failed remote interpretation should remain marked as fallback")
	_assert(failed.get("grounded_plan", []).size() > 0, "failed remote interpretation should keep local grounded plan")
	_assert(failed.get("priority_hints", {}).get("use_cover", 0.0) > 0.0, "failed remote interpretation should keep safe local priorities")
	bridge.free()


func _array_text_contains(items, fragment: String) -> bool:
	if typeof(items) != TYPE_ARRAY:
		return false
	var needle := fragment.to_lower()
	for item in items:
		if str(item).to_lower().contains(needle):
			return true
	return false


func _base_mind_context(overrides: Dictionary) -> Dictionary:
	var context := {
		"is_night": false,
		"phase": "midday",
		"time_left": 25.0,
		"night_close": false,
		"stone": 20,
		"ore": 0,
		"sword_tier": 0,
		"sword_next_ore_cost": 2,
		"sword_max_tier": 2,
		"wall_cost": 4,
		"aura_orb_cost": 5,
		"spike_trap_cost": 4,
		"bow_tower_cost": 8,
		"tar_pit_cost": 4,
		"fear_lantern_cost": 5,
		"decoy_idol_cost": 6,
		"thorn_totem_cost": 6,
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
		"enemy_type_counts": {},
		"enemy_count": 0,
		"nearest_enemy_distance": 120.0,
		"has_valid_cover": false,
		"has_valid_aura": false,
		"has_valid_tower": false,
		"damaged_structure_count": 0,
		"lowest_structure_hp_ratio": 1.0,
		"combat_stats": {"combat_level": 0.0, "sword_skill": 0.0, "attack_damage": 7.0, "armor": 0.0},
		"needs": {"hunger": 30.0, "stamina": 90.0, "fear": 20.0},
		"food": 2,
		"ari_hp_ratio": 0.9,
		"lesson_count": 0,
		"meaningful_event_count": 0,
		"lesson_priority_bias": {},
		"priority_hints": {},
		"grounded_plan": [],
		"run_build": {"points": {}},
		"current_job": "wait_or_idle",
	}
	for key in overrides.keys():
		context[key] = overrides[key]
	return context
