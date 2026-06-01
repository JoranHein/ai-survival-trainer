extends SceneTree

const AIBridgeScript = preload("res://scripts/autoload/AIBridge.gd")
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
	_test_no_wall_builds_cover_first()
	_test_aura_lure_execution()
	_test_dawn_survival_avoids_fight()
	_test_combat_investment_execution()
	_test_flying_storm_execution()
	_test_corner_bow_execution()
	_test_hunger_food_execution()
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
	_assert(decision.get("job", "") == "use_cover", "local fallback for stand behind the wall should use existing cover when a wall exists")
	_assert(str(decision.get("reason", "")).to_lower().contains("wall"), "cover decision should explain the existing wall")
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
	ari_mind.free()


func _test_flying_storm_execution() -> void:
	var ari_mind = AriMindScript.new()
	var decision := ari_mind.choose_daytime_job(_base_mind_context({
		"wall_count": 2,
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
