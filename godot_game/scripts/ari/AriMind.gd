class_name AriMind
extends Node

@export var target_wall_count := 2
@export var target_aura_orb_count := 1
@export var night_close_seconds := 8.0
@export var night_flee_enemy_distance := 44.0
@export var night_low_hp_ratio := 0.35


func choose_daytime_job(context: Dictionary) -> Dictionary:
	if bool(context.get("is_night", false)):
		return _job("wait_or_idle", "Night has started")

	var wall_count := int(context.get("wall_count", 0))
	var aura_orb_count := int(context.get("aura_orb_count", 0))
	var spike_trap_count := int(context.get("spike_trap_count", 0))
	var bow_tower_count := int(context.get("bow_tower_count", 0))
	var tar_pit_count := int(context.get("tar_pit_count", 0))
	var fear_lantern_count := int(context.get("fear_lantern_count", 0))
	var decoy_idol_count := int(context.get("decoy_idol_count", 0))
	var thorn_totem_count := int(context.get("thorn_totem_count", 0))
	var repair_bench_count := int(context.get("repair_bench_count", 0))
	var storm_rod_count := int(context.get("storm_rod_count", 0))
	var damaged_structure_count := int(context.get("damaged_structure_count", 0))
	var lowest_structure_hp_ratio := float(context.get("lowest_structure_hp_ratio", 1.0))
	var combat_stats := _combat_stats(context)
	var combat_level := float(combat_stats.get("combat_level", 0.0))
	var sword_skill := float(combat_stats.get("sword_skill", 0.0))
	var attack_damage := float(combat_stats.get("attack_damage", 7.0))
	var armor := float(combat_stats.get("armor", 0.0))
	var needs := _needs(context)
	var hunger := float(needs.get("hunger", 100.0))
	var stamina := float(needs.get("stamina", 100.0))
	var fear := float(needs.get("fear", 0.0))
	var ari_hp_ratio := clampf(float(context.get("ari_hp_ratio", 1.0)), 0.0, 1.0)
	var stone := int(context.get("stone", 0))
	var ore := int(context.get("ore", 0))
	var sword_tier := int(context.get("sword_tier", int(combat_stats.get("sword_tier", 0))))
	var sword_next_ore_cost := int(context.get("sword_next_ore_cost", 0))
	var sword_max_tier := int(context.get("sword_max_tier", 2))
	var food := int(context.get("food", 0))
	var lesson_count := int(context.get("lesson_count", 0))
	var meaningful_event_count := int(context.get("meaningful_event_count", 0))
	var wall_cost := int(context.get("wall_cost", 0))
	var aura_orb_cost := int(context.get("aura_orb_cost", 0))
	var spike_trap_cost := int(context.get("spike_trap_cost", 0))
	var bow_tower_cost := int(context.get("bow_tower_cost", 0))
	var tar_pit_cost := int(context.get("tar_pit_cost", 0))
	var fear_lantern_cost := int(context.get("fear_lantern_cost", 0))
	var decoy_idol_cost := int(context.get("decoy_idol_cost", 0))
	var thorn_totem_cost := int(context.get("thorn_totem_cost", 0))
	var repair_bench_cost := int(context.get("repair_bench_cost", 0))
	var storm_rod_cost := int(context.get("storm_rod_cost", 0))
	var night_close := bool(context.get("night_close", false))
	var has_defenses := wall_count > 0 or aura_orb_count > 0
	var direct_priority_hints := _direct_priority_hints(context)
	var priority_hints := _priority_hints(context)
	var lesson_bias := _lesson_bias(context)
	var run_build := _run_build(context)
	var enemy_type_counts := _enemy_type_counts(context)
	var active_enemy_count := int(enemy_type_counts.get("zombie", 0)) + int(enemy_type_counts.get("runner", 0)) + int(enemy_type_counts.get("brute", 0)) + int(enemy_type_counts.get("flying", 0))
	var runner_pressure := clampf(float(int(enemy_type_counts.get("runner", 0))) / 2.0, 0.0, 1.0)
	var brute_pressure := clampf(float(int(enemy_type_counts.get("brute", 0))), 0.0, 1.0)
	var flying_pressure := clampf(float(int(enemy_type_counts.get("flying", 0))), 0.0, 1.0)
	var mining_points := _build_points(run_build, "mining")
	var building_points := _build_points(run_build, "building")
	var warding_points := _build_points(run_build, "warding")
	var mining_instinct := _build_strength(run_build, "mining")
	var building_instinct := _build_strength(run_build, "building")
	var warding_instinct := _build_strength(run_build, "warding")
	var trapcraft_instinct := _build_strength(run_build, "trapcraft")
	var defense_instinct := _build_strength(run_build, "defense")
	var fear_control_instinct := _build_strength(run_build, "fear_control")
	var thorns_instinct := _build_strength(run_build, "thorns")
	var sword_instinct := _build_strength(run_build, "sword")
	var smithing_instinct := _build_strength(run_build, "smithing")
	var attack_damage_instinct := _build_strength(run_build, "attack_damage")
	var attack_speed_instinct := _build_strength(run_build, "attack_speed")
	var armor_instinct := _build_strength(run_build, "armor")
	var regeneration_instinct := _build_strength(run_build, "regeneration")
	var sign_wall_preference := _hint(priority_hints, "wall")
	var avoid_wall_preference := maxf(_hint(priority_hints, "avoid_build_wall"), _hint(priority_hints, "avoid_wall"))
	var sign_aura_preference := _hint(priority_hints, "aura_orb")
	var sign_mining_preference := _hint(priority_hints, "mining")
	var sign_combat_preference := maxf(
		maxf(_hint(priority_hints, "combat_training"), _hint(priority_hints, "train_combat")),
		maxf(_hint(priority_hints, "fight"), _hint(priority_hints, "prepare_weapon"))
	)
	var sign_fight_head_on_preference := maxf(_hint(priority_hints, "fight_head_on"), _hint(priority_hints, "fight") * 0.65)
	var sign_train_sword_preference := _hint(priority_hints, "train_sword")
	var sign_smith_sword_preference := _hint(priority_hints, "smith_sword")
	var sign_mine_ore_preference := _hint(priority_hints, "mine_ore")
	var sign_armor_preference := _hint(priority_hints, "use_armor")
	var sign_regen_preference := maxf(_hint(priority_hints, "rely_on_regen"), _hint(priority_hints, "regen_on_kill"))
	var sign_dawn_survival_preference := maxf(
		maxf(_hint(priority_hints, "stall_until_dawn"), _hint(priority_hints, "hide_until_dawn")),
		maxf(_hint(priority_hints, "survive_until_morning"), _hint(priority_hints, "avoid_killing"))
	)
	var hold_best_defense_preference := _hint(priority_hints, "hold_best_defense")
	var sign_food_preference := maxf(
		_hint(priority_hints, "farm_food"),
		maxf(_hint(priority_hints, "eat"), _hint(priority_hints, "eat_food"))
	)
	var sign_trap_preference := _hint(priority_hints, "build_trap")
	var sign_tower_preference := maxf(_hint(priority_hints, "build_tower"), _hint(priority_hints, "use_tower"))
	var sign_ranged_preference := maxf(
		maxf(_hint(priority_hints, "range"), _hint(priority_hints, "train_bow")),
		_hint(priority_hints, "ranged_attack")
	)
	var sign_tar_pit_preference := _hint(priority_hints, "build_tar_pit")
	var sign_lantern_preference := _hint(priority_hints, "build_fear_lantern")
	var sign_decoy_preference := _hint(priority_hints, "build_decoy_idol")
	var sign_thorn_preference := _hint(priority_hints, "build_thorn_totem")
	var sign_repair_bench_preference := _hint(priority_hints, "build_repair_bench")
	var sign_repair_preference := maxf(_hint(priority_hints, "repair_structure"), _hint(priority_hints, "repair"))
	var sign_storm_preference := maxf(
		_hint(priority_hints, "build_storm_rod"),
		maxf(maxf(_hint(priority_hints, "anti_flying"), _hint(priority_hints, "sky_answer")), _hint(priority_hints, "anti_air_defense"))
	)
	var sign_rest_preference := _hint(priority_hints, "rest")
	var sign_reflect_preference := _hint(priority_hints, "reflect_library")
	var cover_preference := maxf(
		maxf(_hint(priority_hints, "use_existing_wall"), _hint(priority_hints, "wait_behind_wall")),
		maxf(_hint(priority_hints, "use_cover"), _hint(priority_hints, "hide"))
	)
	var direct_cover_preference := maxf(
		maxf(_hint(direct_priority_hints, "use_existing_wall"), _hint(direct_priority_hints, "wait_behind_wall")),
		maxf(_hint(direct_priority_hints, "use_cover"), _hint(direct_priority_hints, "hide"))
	)
	var aura_lure_preference := _hint(priority_hints, "lure_to_aura")
	var kite_preference := maxf(_hint(priority_hints, "kite"), _hint(priority_hints, "flee"))
	var wall_preference := sign_wall_preference
	var aura_preference := sign_aura_preference
	var mining_preference := sign_mining_preference
	var combat_preference := sign_combat_preference
	var food_preference := sign_food_preference
	var trap_preference := sign_trap_preference
	var range_preference := maxf(sign_ranged_preference, kite_preference)
	var tower_preference := maxf(sign_tower_preference, range_preference)
	var fight_head_on_preference := sign_fight_head_on_preference
	var train_sword_preference := sign_train_sword_preference
	var smith_sword_preference := sign_smith_sword_preference
	var mine_ore_preference := sign_mine_ore_preference
	var armor_preference := sign_armor_preference
	var regen_preference := sign_regen_preference
	var dawn_survival_preference := sign_dawn_survival_preference
	var tar_pit_preference := sign_tar_pit_preference
	var lantern_preference := sign_lantern_preference
	var decoy_preference := sign_decoy_preference
	var thorn_preference := sign_thorn_preference
	var repair_bench_preference := sign_repair_bench_preference
	var repair_preference := maxf(sign_repair_preference, sign_repair_bench_preference * 0.35)
	var storm_preference := sign_storm_preference
	var rest_preference := sign_rest_preference
	var reflect_preference := sign_reflect_preference
	var survival_needs_stable := hunger < 58.0 and stamina > 34.0 and fear < 70.0 and ari_hp_ratio > 0.45
	var defensive_wait_preference := maxf(maxf(_hint(priority_hints, "defensive_wait"), hold_best_defense_preference), maxf(cover_preference, _hint(priority_hints, "wait_or_idle")))
	if runner_pressure > 0.0:
		cover_preference = maxf(cover_preference, 0.34 + runner_pressure * 0.12)
		aura_lure_preference = maxf(aura_lure_preference, 0.34 + runner_pressure * 0.14)
		range_preference = clampf(range_preference + 0.18 + runner_pressure * 0.18, 0.0, 1.0)
		tower_preference = maxf(tower_preference, range_preference)
		defensive_wait_preference = maxf(defensive_wait_preference, 0.28 + runner_pressure * 0.10)
	if brute_pressure > 0.0:
		aura_lure_preference = maxf(aura_lure_preference, 0.42 + brute_pressure * 0.12)
		range_preference = clampf(range_preference + 0.18 + brute_pressure * 0.22, 0.0, 1.0)
		tower_preference = maxf(tower_preference, range_preference)
		wall_preference = clampf(wall_preference - brute_pressure * 0.18, 0.0, 1.0)
	if flying_pressure > 0.0:
		storm_preference = maxf(storm_preference, 0.50 + flying_pressure * 0.18)
		range_preference = clampf(range_preference + 0.16 + flying_pressure * 0.16, 0.0, 1.0)
		tower_preference = maxf(tower_preference, range_preference)
		aura_lure_preference = maxf(aura_lure_preference, 0.30 + flying_pressure * 0.10)
		wall_preference = clampf(wall_preference - flying_pressure * 0.22, 0.0, 1.0)
	wall_preference = clampf(wall_preference, 0.0, 1.0)
	aura_preference = clampf(aura_preference, 0.0, 1.0)
	mining_preference = clampf(mining_preference + (_build_strength(run_build, "curiosity") * 0.08 if mining_preference > 0.0 else 0.0), 0.0, 1.0)
	range_preference = clampf(range_preference, 0.0, 1.0)
	combat_preference = clampf(combat_preference, 0.0, 1.0)
	fight_head_on_preference = clampf(fight_head_on_preference + sword_instinct * 0.18 + attack_damage_instinct * 0.18 + armor_instinct * 0.08, 0.0, 1.0)
	train_sword_preference = clampf(train_sword_preference + sword_instinct * 0.22 + attack_speed_instinct * 0.10, 0.0, 1.0)
	smith_sword_preference = clampf(smith_sword_preference + smithing_instinct * 0.24 + sword_instinct * 0.08, 0.0, 1.0)
	mine_ore_preference = clampf(mine_ore_preference + smith_sword_preference * 0.35 + smithing_instinct * 0.12, 0.0, 1.0)
	armor_preference = clampf(armor_preference + armor_instinct * 0.24 + defense_instinct * 0.08, 0.0, 1.0)
	regen_preference = clampf(regen_preference + regeneration_instinct * 0.24, 0.0, 1.0)
	if regen_preference > 0.20 and (smith_sword_preference > 0.25 or train_sword_preference > 0.25):
		fight_head_on_preference = clampf(fight_head_on_preference + regen_preference * 0.20, 0.0, 1.0)
		combat_preference = clampf(combat_preference + regen_preference * 0.10, 0.0, 1.0)
	dawn_survival_preference = clampf(dawn_survival_preference + fear_control_instinct * 0.12 + _build_strength(run_build, "movement") * 0.10, 0.0, 1.0)
	food_preference = clampf(food_preference + (0.45 if hunger > 58.0 else 0.0) + _build_strength(run_build, "farming") * 0.22, 0.0, 1.0)
	trap_preference = clampf(trap_preference + trapcraft_instinct * 0.28, 0.0, 1.0)
	tower_preference = clampf(tower_preference + _build_strength(run_build, "bow") * 0.24 + _build_strength(run_build, "attack_range") * 0.22, 0.0, 1.0)
	tar_pit_preference = clampf(tar_pit_preference + trapcraft_instinct * 0.20, 0.0, 1.0)
	lantern_preference = clampf(lantern_preference + fear_control_instinct * 0.24 + warding_instinct * 0.08 + (0.16 if sign_lantern_preference > 0.0 or fear > 56.0 else 0.0), 0.0, 1.0)
	decoy_preference = clampf(decoy_preference + trapcraft_instinct * 0.14, 0.0, 1.0)
	thorn_preference = clampf(thorn_preference + thorns_instinct * 0.30 + defense_instinct * 0.08, 0.0, 1.0)
	repair_bench_preference = clampf(repair_bench_preference + building_instinct * 0.10 + defense_instinct * 0.10, 0.0, 1.0)
	repair_preference = clampf(repair_preference + building_instinct * 0.12 + defense_instinct * 0.16 + (0.40 if lowest_structure_hp_ratio < 0.55 else 0.0) + (0.20 if damaged_structure_count >= 2 else 0.0), 0.0, 1.0)
	storm_preference = clampf(storm_preference + _build_strength(run_build, "attack_range") * 0.18 + warding_instinct * 0.10 + (0.14 if sign_storm_preference > 0.0 or flying_pressure > 0.0 else 0.0), 0.0, 1.0)
	rest_preference = clampf(rest_preference + (fear / 100.0) * 0.20 + (0.34 if ari_hp_ratio <= 0.45 else 0.0) + (0.28 if stamina < 38.0 else 0.0) + _build_strength(run_build, "regeneration") * 0.18, 0.0, 1.0)
	reflect_preference = clampf(reflect_preference + _build_strength(run_build, "curiosity") * 0.18 + (0.36 if meaningful_event_count > 0 else 0.0), 0.0, 1.0)
	if sign_combat_preference > 0.0 and (range_preference > 0.0 or wall_preference > 0.0 or defensive_wait_preference > 0.0):
		combat_preference = clampf(combat_preference + 0.10, 0.0, 1.0)
	defensive_wait_preference = clampf(defensive_wait_preference + ((fear / 100.0) * 0.14 if defensive_wait_preference > 0.0 or fear > 62.0 else 0.0), 0.0, 1.0)
	wall_preference = clampf(wall_preference + building_instinct * 0.18, 0.0, 1.0)
	aura_preference = clampf(aura_preference + warding_instinct * 0.24, 0.0, 1.0)
	mining_preference = clampf(mining_preference + mining_instinct * 0.18, 0.0, 1.0)
	combat_preference = clampf(combat_preference + defense_instinct * 0.10 + fear_control_instinct * 0.08, 0.0, 1.0)
	combat_preference = clampf(combat_preference + fight_head_on_preference * 0.25 + train_sword_preference * 0.12, 0.0, 1.0)
	defensive_wait_preference = clampf(defensive_wait_preference + fear_control_instinct * 0.12 + defense_instinct * 0.08, 0.0, 1.0)
	wall_preference = clampf(wall_preference + _bias_hint(lesson_bias, "build_wall"), 0.0, 1.0)
	aura_preference = clampf(aura_preference + _bias_hint(lesson_bias, "place_aura_orb"), 0.0, 1.0)
	mining_preference = clampf(mining_preference + _bias_hint(lesson_bias, "mine_stone"), 0.0, 1.0)
	combat_preference = clampf(combat_preference + _bias_hint(lesson_bias, "train_combat"), 0.0, 1.0)
	fight_head_on_preference = clampf(fight_head_on_preference + _bias_hint(lesson_bias, "fight_head_on"), 0.0, 1.0)
	train_sword_preference = clampf(train_sword_preference + _bias_hint(lesson_bias, "train_sword"), 0.0, 1.0)
	smith_sword_preference = clampf(smith_sword_preference + _bias_hint(lesson_bias, "smith_sword"), 0.0, 1.0)
	mine_ore_preference = clampf(mine_ore_preference + _bias_hint(lesson_bias, "mine_ore"), 0.0, 1.0)
	food_preference = clampf(food_preference + _bias_hint(lesson_bias, "farm_food"), 0.0, 1.0)
	trap_preference = clampf(trap_preference + _bias_hint(lesson_bias, "build_trap"), 0.0, 1.0)
	tower_preference = clampf(tower_preference + _bias_hint(lesson_bias, "build_tower"), 0.0, 1.0)
	tar_pit_preference = clampf(tar_pit_preference + _bias_hint(lesson_bias, "build_tar_pit"), 0.0, 1.0)
	lantern_preference = clampf(lantern_preference + _bias_hint(lesson_bias, "build_fear_lantern"), 0.0, 1.0)
	decoy_preference = clampf(decoy_preference + _bias_hint(lesson_bias, "build_decoy_idol"), 0.0, 1.0)
	thorn_preference = clampf(thorn_preference + _bias_hint(lesson_bias, "build_thorn_totem"), 0.0, 1.0)
	repair_bench_preference = clampf(repair_bench_preference + _bias_hint(lesson_bias, "build_repair_bench"), 0.0, 1.0)
	repair_preference = clampf(repair_preference + _bias_hint(lesson_bias, "repair_structure"), 0.0, 1.0)
	storm_preference = clampf(storm_preference + _bias_hint(lesson_bias, "build_storm_rod"), 0.0, 1.0)
	rest_preference = clampf(rest_preference + _bias_hint(lesson_bias, "rest"), 0.0, 1.0)
	reflect_preference = clampf(reflect_preference + _bias_hint(lesson_bias, "reflect_library"), 0.0, 1.0)
	hold_best_defense_preference = clampf(hold_best_defense_preference + _bias_hint(lesson_bias, "hold_best_defense"), 0.0, 1.0)
	defensive_wait_preference = maxf(defensive_wait_preference, hold_best_defense_preference)
	if avoid_wall_preference > 0.55:
		wall_preference = 0.0
	var soft_sky_wall_distrust := avoid_wall_preference > 0.25 and avoid_wall_preference <= 0.55 and sign_storm_preference > 0.30
	var sky_wall_floor_distrust := _hint(priority_hints, "avoid_build_wall") > 0.25 and sign_storm_preference > 0.30
	var desired_wall_count := target_wall_count
	if building_points >= 4:
		desired_wall_count += 1
	if building_points >= 7:
		desired_wall_count += 1
	if wall_preference > 0.25:
		desired_wall_count += 1
	if wall_preference >= 0.85:
		desired_wall_count += 1
	if soft_sky_wall_distrust:
		desired_wall_count = mini(desired_wall_count, 1)
	var desired_aura_orb_count := target_aura_orb_count
	if sign_aura_preference > 0.35 and warding_points >= 5:
		desired_aura_orb_count += 1
	var reflection_survival_ready := wall_count >= mini(2, desired_wall_count) and aura_orb_count >= desired_aura_orb_count
	var repair_wall_floor := mini(desired_wall_count, 2)
	var repair_plan_needs_walls := (repair_bench_preference > 0.22 or sign_repair_preference > 0.25) and sign_wall_preference > 0.0
	var light_mud_control_plan := sign_aura_preference > 0.25 and sign_tar_pit_preference > 0.20 and aura_orb_count > 0 and tar_pit_count > 0
	var light_mud_recovery_plan := sign_aura_preference > 0.25 and sign_tar_pit_preference > 0.20 and (aura_orb_count > 0 or tar_pit_count > 0)

	var desired_stone_reserve := maxi(wall_cost, aura_orb_cost) + int(ceil(mining_preference * 4.0)) + int(ceil(float(mining_points) * 0.5))
	var desired_combat_level := 0.25 + combat_preference * 2.1 + defense_instinct * 0.30 + fear_control_instinct * 0.20
	var desired_sword_skill := 0.45 + train_sword_preference * 2.2 + sword_instinct * 0.45 + attack_speed_instinct * 0.22
	var wants_sword_upgrade := sword_next_ore_cost > 0 and sword_tier < sword_max_tier and smith_sword_preference > 0.25
	var tower_use_preference := maxf(sign_tower_preference, range_preference)
	var direct_tower_recovery_preference := maxf(
		maxf(_hint(direct_priority_hints, "build_tower"), _hint(direct_priority_hints, "use_tower")),
		maxf(maxf(_hint(direct_priority_hints, "range"), _hint(direct_priority_hints, "train_bow")), _hint(direct_priority_hints, "ranged_attack"))
	)
	var special_structure_preference := maxf(
		maxf(maxf(aura_preference, trap_preference), maxf(tar_pit_preference, lantern_preference)),
		maxf(maxf(decoy_preference, thorn_preference), maxf(repair_bench_preference, maxf(storm_preference, tower_preference)))
	)
	var no_wall_alternative_exists := aura_orb_count > 0 or bow_tower_count > 0 or spike_trap_count > 0 or tar_pit_count > 0 or fear_lantern_count > 0 or decoy_idol_count > 0 or thorn_totem_count > 0 or storm_rod_count > 0
	var explicit_no_wall_plan := avoid_wall_preference > 0.55 and (special_structure_preference > 0.20 or no_wall_alternative_exists)
	var ready_sky_perch_plan := storm_rod_count > 0 and bow_tower_count > 0 and storm_preference > 0.30
	var sky_support_tower_plan := ready_sky_perch_plan and sign_storm_preference > 0.30
	var sky_support_wall_floor := mini(desired_wall_count, 2)
	if ready_sky_perch_plan:
		sky_support_wall_floor = 1 if sky_wall_floor_distrust else 2
	var sky_survival_backup_ready := wall_count >= sky_support_wall_floor and aura_orb_count >= desired_aura_orb_count
	var sky_needs_aura_backup := sign_storm_preference > 0.30 and storm_rod_count > 0 and bow_tower_count > 0 and aura_orb_count < desired_aura_orb_count and wall_count > 0
	var agent_wants_build_tower := _plan_has_affordance(context.get("agent_grounded_plan", []), "build_tower")

	if night_close and ready_sky_perch_plan:
		return _job("use_tower", "Night is close; stage at the sky perch")
	if night_close and has_defenses:
		return _job("wait_or_idle", "Night is close; stay near defenses")

	if hunger > 64.0 and food > 0:
		return _job("eat_food", "Hunger is becoming dangerous")

	if active_enemy_count <= 0 and ready_sky_perch_plan and sky_survival_backup_ready and ari_hp_ratio < 0.76:
		return _job("rest", "Sky answer is ready; recover before night")

	if active_enemy_count <= 0 and not night_close and ready_sky_perch_plan and (wall_count > 0 or aura_orb_count > 0 or repair_bench_count > 0) and ari_hp_ratio <= 0.55 and hunger < 62.0:
		return _job("rest", "Sky answer is standing; recover before night")

	if flying_pressure > 0.0 and storm_rod_count < 1 and has_defenses:
		if stone < storm_rod_cost:
			return _job("mine_stone", "Need stone for storm rod")
		return _job("build_storm_rod", "Flying enemies need anti-air")

	if active_enemy_count > 0:
		var active_aura_lure_preference := maxf(aura_lure_preference, sign_aura_preference * 0.75)
		if fight_head_on_preference > 0.45 and _can_fight_head_on(combat_stats, ari_hp_ratio, enemy_type_counts, active_enemy_count):
			return _job("fight_head_on", _direct_fight_reason(sign_fight_head_on_preference, maxf(train_sword_preference, smith_sword_preference), regen_preference, armor_preference))
		if flying_pressure > 0.0 and storm_rod_count < 1 and storm_preference > 0.30 and (explicit_no_wall_plan or sign_storm_preference > 0.0):
			if stone < storm_rod_cost:
				return _job("mine_stone", "Need stone for storm rod")
			return _job("build_storm_rod", "Sign points to wings; answer the sky with storm")
		if flying_pressure > 0.0 and storm_rod_count > 0 and bow_tower_count < 1 and tower_preference > 0.20:
			if stone < bow_tower_cost:
				return _job("mine_stone", "Need stone for ranged sky support")
			return _job("build_bow_tower", "Storm answers wings; add ranged support")
		if tower_use_preference > 0.20 and bow_tower_count > 0:
			return _job("use_tower", "Enemies remain; use tower range")
		if active_aura_lure_preference > 0.20 and aura_orb_count > 0:
			return _job("lure_to_aura", "Enemies remain; pull them through light")
		if cover_preference > 0.20 and wall_count > 0:
			return _job("use_cover", "Enemies remain; keep the wall between us")
		if bow_tower_count > 0:
			return _job("use_tower", "Enemies remain; use tower range")
		if aura_orb_count > 0:
			return _job("lure_to_aura", "Enemies remain; pull them through light")
		if wall_count > 0:
			return _job("use_cover", "Enemies remain; keep cover between us")
		if stone < wall_cost:
			return _job("flee", "Enemies remain and there is no cover yet")

	if active_enemy_count <= 0 and damaged_structure_count > 0 and light_mud_control_plan and lowest_structure_hp_ratio < 0.98:
		return _job("repair_structure", "Top off the light and slow-mud kill zone before night")

	if active_enemy_count <= 0 and damaged_structure_count > 0 and direct_tower_recovery_preference > 0.30 and bow_tower_count > 0 and wall_count > 0 and lowest_structure_hp_ratio < 0.95 and not night_close:
		return _job("repair_structure", "Patch damaged tower support before using range")

	if active_enemy_count <= 0 and damaged_structure_count > 0 and repair_preference > 0.30:
		return _job("repair_structure", "Patch damaged defenses" if sign_repair_preference <= 0.0 else "Sign says repair what broke")

	if active_enemy_count <= 0 and damaged_structure_count > 0 and lowest_structure_hp_ratio < 0.85 and (tar_pit_count > 0 or spike_trap_count > 0) and maxf(maxf(sign_tar_pit_preference, tar_pit_preference), sign_trap_preference) > 0.20:
		return _job("repair_structure", "Patch the damaged slow-ground trap line")

	if active_enemy_count <= 0 and damaged_structure_count > 0 and lowest_structure_hp_ratio < 0.85 and sign_aura_preference > 0.35 and aura_orb_count > 0:
		return _job("repair_structure", "Patch the damaged light circle before night")

	if active_enemy_count <= 0 and damaged_structure_count > 0 and lowest_structure_hp_ratio < 0.85 and storm_preference > 0.30 and (storm_rod_count > 0 or bow_tower_count > 0):
		return _job("repair_structure", "Patch damaged anti-air support before using the perch")

	if active_enemy_count <= 0 and light_mud_control_plan and damaged_structure_count <= 0 and ari_hp_ratio < 0.84 and hunger < 62.0 and not night_close:
		return _job("rest", "Light and slow mud are ready; recover before the next night")

	if active_enemy_count <= 0 and repair_bench_preference > 0.22 and repair_bench_count < 1 and has_defenses and not night_close:
		if stone < repair_bench_cost:
			return _job("mine_stone", "Need stone for repair bench")
		return _job("build_repair_bench", "Sign asks for repair tools" if sign_repair_bench_preference > 0.0 else "Build favors repair")

	if active_enemy_count <= 0 and direct_cover_preference > 0.30 and wall_count > 0 and wall_count < desired_wall_count:
		if stone < wall_cost:
			return _job("mine_stone", "Need stone for stronger cover")
		return _job("build_wall", "Existing wall cover is too thin before night")

	if active_enemy_count <= 0 and not night_close and direct_cover_preference > 0.30 and defensive_wait_preference > 0.30 and wall_count >= desired_wall_count and aura_orb_count < desired_aura_orb_count and warding_points >= 3:
		if stone < aura_orb_cost:
			return _job("mine_stone", "Need stone for backup light behind cover")
		return _job("place_aura_orb", "Walls make teeth wait; light makes waiting matter")

	if active_enemy_count <= 0 and sign_lantern_preference > 0.35 and fear_lantern_count < 1 and (has_defenses or bow_tower_count > 0) and (bow_tower_count > 0 or tower_use_preference <= 0.30) and not sky_needs_aura_backup:
		if stone < fear_lantern_cost:
			return _job("mine_stone", "Need stone for lantern")
		return _job("build_fear_lantern", "Weapons make Ari anxious; add warm safety")

	if active_enemy_count <= 0 and ari_hp_ratio <= night_low_hp_ratio and has_defenses and not night_close:
		return _job("rest", "Ari is too hurt to spend the day building")

	if active_enemy_count <= 0 and sign_reflect_preference > 0.25 and lesson_count > 0 and ari_hp_ratio < 0.72 and has_defenses and not night_close and hunger < 62.0:
		return _job("rest", "Painful lessons need recovery before night")

	if active_enemy_count <= 0 and not explicit_no_wall_plan and storm_preference > 0.30 and bow_tower_count > 0 and wall_count < sky_support_wall_floor and not night_close:
		if stone < wall_cost:
			return _job("mine_stone", "Need stone for cover under the sky plan")
		return _job("build_wall", "Sky tower plan still needs basic cover")

	if active_enemy_count <= 0 and not night_close and sky_needs_aura_backup:
		if stone < aura_orb_cost:
			return _job("mine_stone", "Need stone for backup light under the sky plan")
		return _job("place_aura_orb", "Sky support still needs backup light before extra ground control")

	if active_enemy_count <= 0 and not explicit_no_wall_plan and tower_use_preference > 0.30 and aura_lure_preference > 0.30 and bow_tower_count > 0 and aura_orb_count > 0 and wall_count < 1 and not night_close:
		if stone < wall_cost:
			return _job("mine_stone", "Need stone for cover under the tower and light plan")
		return _job("build_wall", "Height and light still need basic cover")

	if active_enemy_count <= 0 and not explicit_no_wall_plan and tower_use_preference > 0.30 and sign_lantern_preference > 0.35 and bow_tower_count > 0 and fear_lantern_count > 0 and wall_count < 1 and not night_close:
		if stone < wall_cost:
			return _job("mine_stone", "Need stone for cover under the anxious ranged plan")
		return _job("build_wall", "Height and warm light still need basic cover")

	if active_enemy_count <= 0 and sign_storm_preference > 0.30 and bow_tower_count > 0 and storm_rod_count < 1 and not night_close:
		if stone < storm_rod_cost:
			return _job("mine_stone", "Need stone to restore the sky answer")
		return _job("build_storm_rod", "The sky answer broke; rebuild storm before perching")

	if active_enemy_count <= 0 and storm_rod_count > 0 and bow_tower_count < 1 and storm_preference > 0.30 and not night_close:
		if stone < bow_tower_cost:
			return _job("mine_stone", "Need stone to restore tower support for storm")
		return _job("build_bow_tower", "Storm answer needs the tower rebuilt")

	if active_enemy_count <= 0 and direct_tower_recovery_preference > 0.30 and bow_tower_count < 1 and wall_count > 0 and not night_close:
		if stone < bow_tower_cost:
			return _job("mine_stone", "Need stone to restore tower range")
		return _job("build_bow_tower", "Ranged plan needs the tower rebuilt")

	if active_enemy_count <= 0 and not explicit_no_wall_plan and sign_wall_preference > 0.0 and wall_preference > 0.0 and wall_count < mini(desired_wall_count, 2) and not night_close:
		if stone < wall_cost:
			return _job("mine_stone", "Need stone for wall")
		return _job("build_wall", "Sign wants basic walls before using other defenses")

	if active_enemy_count <= 0 and not night_close and not explicit_no_wall_plan and light_mud_recovery_plan:
		if wall_count < 1:
			if stone < wall_cost:
				return _job("mine_stone", "Need stone to restore cover for light and mud")
			return _job("build_wall", "Restore cover for the light and slow mud")
		if aura_orb_count < 1:
			if stone < aura_orb_cost:
				return _job("mine_stone", "Need stone to restore the light and mud plan")
			return _job("place_aura_orb", "Restore the light before mining more stone")
		if tar_pit_count < 1:
			if stone < tar_pit_cost:
				return _job("mine_stone", "Need stone to restore the slow mud")
			return _job("build_tar_pit", "Restore the slow mud before mining more stone")
		if wall_count < mini(desired_wall_count, 2):
			if stone < wall_cost:
				return _job("mine_stone", "Need stone for cover around light and mud")
			return _job("build_wall", "Add cover for the light and slow mud")

	var tower_support_wall_floor := mini(desired_wall_count, 2)
	if active_enemy_count <= 0 and not night_close and not explicit_no_wall_plan and tower_use_preference > 0.30 and bow_tower_count > 0 and wall_count < tower_support_wall_floor and not agent_wants_build_tower:
		if stone < wall_cost:
			return _job("mine_stone", "Need stone for cover under the tower plan")
		return _job("build_wall", "Tower plan needs cover below the perch")

	var tower_repair_stone_reserve := maxi(maxi(wall_cost * 2, bow_tower_cost), 6)
	if active_enemy_count <= 0 and not night_close and tower_use_preference > 0.30 and bow_tower_count > 0 and wall_count >= tower_support_wall_floor and stone < tower_repair_stone_reserve:
		return _job("mine_stone", "Keep repair stone ready for the tower plan")

	var tower_archer_support_plan := building_points >= 3 and tower_use_preference > 0.30 and bow_tower_count > 0 and wall_count >= tower_support_wall_floor
	if active_enemy_count <= 0 and not night_close and tower_archer_support_plan and tar_pit_count < 1 and tar_pit_cost > 0 and not sky_support_tower_plan and not agent_wants_build_tower:
		var tower_slow_ground_budget := tower_repair_stone_reserve + tar_pit_cost
		if stone < tower_slow_ground_budget:
			return _job("mine_stone", "Need stone so slow ground can hold enemies under the tower arrows")
		return _job("build_tar_pit", "Slow ground keeps enemies under the tower arrows")

	if active_enemy_count <= 0 and not night_close and not explicit_no_wall_plan and light_mud_control_plan and wall_count < 1:
		if stone < wall_cost:
			return _job("mine_stone", "Need stone to support the light and mud plan")
		return _job("build_wall", "Light and slow mud need cover before night")

	var sword_plan_ready_enough := sword_tier > 0 and (combat_level >= 2.0 or sword_skill >= 0.8)
	var sword_plan_wants_contact := fight_head_on_preference > 0.45 or train_sword_preference > 0.35 or smith_sword_preference > 0.35
	if active_enemy_count <= 0 and not night_close and has_defenses and sword_plan_ready_enough and sword_plan_wants_contact and ari_hp_ratio < 0.82 and hunger < 62.0:
		return _job("rest", "Blade plan is ready enough; recover before night")

	if active_enemy_count <= 0 and not night_close and not explicit_no_wall_plan and sword_plan_ready_enough and sword_plan_wants_contact and wall_count < mini(desired_wall_count, 2):
		if stone < wall_cost:
			return _job("mine_stone", "Need stone for cover around the blade plan")
		return _job("build_wall", "Blade plan needs cover before night")

	if active_enemy_count <= 0 and not night_close and sword_plan_ready_enough and sword_plan_wants_contact and wall_count >= mini(desired_wall_count, 2) and aura_orb_count < 1:
		if stone < aura_orb_cost:
			return _job("mine_stone", "Need stone for light around the blade plan")
		return _job("place_aura_orb", "Blade plan needs a light kill zone before night")

	var grounded_job := _job_from_grounded_plan(context, false)
	if not grounded_job.is_empty():
		return grounded_job

	if active_enemy_count <= 0 and (food_preference > 0.20 or hunger > 42.0) and food < 3:
		return _job("farm_food", "Need food before night" if sign_food_preference <= 0.0 else "Sign points to food")

	if active_enemy_count <= 0 and (rest_preference > 0.28 or fear > 64.0 or stamina < 34.0) and has_defenses:
		return _job("rest", "Need calm before night" if sign_rest_preference <= 0.0 else "Sign asks for quiet")

	if active_enemy_count <= 0 and sign_reflect_preference > 0.25 and lesson_count < 2 and not night_close and survival_needs_stable and reflection_survival_ready:
		return _job("reflect_library", "Sign wants a lesson")

	if active_enemy_count <= 0 and reflect_preference > 0.45 and lesson_count < 2 and meaningful_event_count > 0 and has_defenses and not night_close and survival_needs_stable and reflection_survival_ready:
		return _job("reflect_library", "Recent events need a lesson" if sign_reflect_preference <= 0.0 else "Sign wants a lesson")

	if active_enemy_count <= 0 and wants_sword_upgrade:
		if ore < sword_next_ore_cost:
			return _job("mine_ore", "Need ore for sword")
		return _job("smith_sword", "Sign wants a stronger sword")

	if active_enemy_count <= 0 and train_sword_preference > 0.30 and sword_skill < desired_sword_skill:
		return _job("train_sword", "Sign wants sword practice")

	if active_enemy_count <= 0 and mine_ore_preference > 0.35 and ore < maxi(sword_next_ore_cost, 2):
		return _job("mine_ore", "Sign points to ore")

	if active_enemy_count <= 0 and repair_plan_needs_walls and wall_count > 0 and wall_count < repair_wall_floor:
		if stone < wall_cost:
			return _job("mine_stone", "Need stone for repairable walls")
		return _job("build_wall", "Repair tools need walls to keep standing")

	if repair_bench_preference > 0.22 and repair_bench_count < 1 and has_defenses:
		if stone < repair_bench_cost:
			return _job("mine_stone", "Need stone for repair bench")
		return _job("build_repair_bench", "Sign asks for repair tools" if sign_repair_bench_preference > 0.0 else "Build favors repair")

	if sign_repair_preference > 0.25 and damaged_structure_count <= 0 and has_defenses and repair_bench_preference <= 0.22 and sign_wall_preference <= 0.0:
		return _job("wait_or_idle", "Sign wants repair, but nothing is broken yet")

	if active_enemy_count <= 0 and cover_preference > 0.30 and wall_count > 0:
		return _job("use_cover", "Sign says use the existing wall as cover")

	if active_enemy_count <= 0 and not explicit_no_wall_plan and wall_preference > 0.0 and wall_count < mini(desired_wall_count, 2) and (sign_wall_preference > 0.0 or special_structure_preference <= 0.20):
		if stone < wall_cost:
			return _job("mine_stone", "Need stone for wall")
		return _job("build_wall", "Sign wants stronger walls")

	if active_enemy_count <= 0 and sign_storm_preference > 0.30 and range_preference > 0.0 and bow_tower_count > 0 and combat_level < 1.1 and (not sky_support_tower_plan or sky_survival_backup_ready):
		return _job("train_combat", "Sign asks for ranged readiness")

	if tower_use_preference > 0.30 and bow_tower_count > 0 and tower_use_preference >= aura_lure_preference and tower_use_preference >= cover_preference and (not sky_support_tower_plan or sky_survival_backup_ready):
		return _job("use_tower", "Sign says use tower range")

	var aura_can_lead := wall_count > 0 or (sign_aura_preference > 0.0 and wall_preference <= 0.0) or warding_points >= 5
	if active_enemy_count <= 0 and not night_close and aura_preference > 0.0 and aura_orb_count < desired_aura_orb_count and aura_can_lead:
		if stone < aura_orb_cost:
			return _job("mine_stone", "Need stone for sign's light" if sign_aura_preference > 0.0 else "Need stone for Aura Orb")
		return _job("place_aura_orb", "Sign points to light" if sign_aura_preference > 0.0 else "Build favors Aura Orb")

	if active_enemy_count <= 0 and not night_close and sign_tar_pit_preference > 0.20 and tar_pit_count < 1 and has_defenses and (aura_orb_count > 0 or aura_preference <= 0.0):
		if stone < tar_pit_cost:
			return _job("mine_stone", "Need stone for slow mud")
		return _job("build_tar_pit", "Sign says slow the ground")

	if active_enemy_count <= 0 and not night_close and sign_lantern_preference > 0.35 and fear_lantern_count > 0 and wall_count > 0 and wall_count < 2 and tower_use_preference <= 0.30 and not explicit_no_wall_plan:
		if stone < wall_cost:
			return _job("mine_stone", "Need stone to make the warm light safer")
		return _job("build_wall", "Warm light needs stronger cover before night")

	if aura_lure_preference > 0.30 and aura_orb_count > 0 and aura_lure_preference >= cover_preference:
		return _job("lure_to_aura", "Sign says the light should hurt them")

	if tower_use_preference > 0.30 and bow_tower_count > 0 and (not sky_support_tower_plan or sky_survival_backup_ready):
		return _job("use_tower", "Sign says use tower range")

	if aura_lure_preference > 0.30 and aura_orb_count > 0:
		return _job("lure_to_aura", "Sign says the light should hurt them")

	if not explicit_no_wall_plan and wall_count < 1 and wall_preference > 0.0:
		if stone < wall_cost:
			return _job("mine_stone", "Need stone for wall")
		return _job("build_wall", "Sign wants first cover")

	if aura_preference > 0.0 and aura_orb_count < desired_aura_orb_count and aura_can_lead:
		if stone < aura_orb_cost:
			return _job("mine_stone", "Need stone for sign's light" if sign_aura_preference > 0.0 else "Need stone for Aura Orb")
		return _job("place_aura_orb", "Sign points to light" if sign_aura_preference > 0.0 else "Build favors Aura Orb")

	if tar_pit_preference > 0.20 and tar_pit_count < 1 and has_defenses and tar_pit_preference >= trap_preference:
		if stone < tar_pit_cost:
			return _job("mine_stone", "Need stone for tar pit")
		return _job("build_tar_pit", "Sign says slow the ground" if sign_tar_pit_preference > 0.0 else "Build favors slowing them")

	if trap_preference > 0.20 and spike_trap_count < 2 and has_defenses:
		if stone < spike_trap_cost:
			return _job("mine_stone", "Need stone for trap")
		return _job("build_spike_trap", "Sign says the floor can fight" if sign_trap_preference > 0.0 else "Build favors traps")

	if tar_pit_preference > 0.20 and tar_pit_count < 1 and has_defenses:
		if stone < tar_pit_cost:
			return _job("mine_stone", "Need stone for tar pit")
		return _job("build_tar_pit", "Sign says slow the ground" if sign_tar_pit_preference > 0.0 else "Build favors slowing them")

	if lantern_preference > 0.22 and fear_lantern_count < 1 and has_defenses and not sky_needs_aura_backup:
		if stone < fear_lantern_cost:
			return _job("mine_stone", "Need stone for lantern")
		return _job("build_fear_lantern", "Sign asks for warm safety" if sign_lantern_preference > 0.0 else "Fear needs a safe light")

	if decoy_preference > 0.22 and decoy_idol_count < 1 and has_defenses:
		if stone < decoy_idol_cost:
			return _job("mine_stone", "Need stone for decoy")
		return _job("build_decoy_idol", "Sign asks for bait" if sign_decoy_preference > 0.0 else "Build favors distraction")

	if thorn_preference > 0.22 and thorn_totem_count < 1 and has_defenses:
		if stone < thorn_totem_cost:
			return _job("mine_stone", "Need stone for thorns")
		return _job("build_thorn_totem", "Sign says touch should hurt" if sign_thorn_preference > 0.0 else "Build favors thorns")

	if storm_preference > 0.22 and storm_rod_count < 1 and (has_defenses or explicit_no_wall_plan):
		if stone < storm_rod_cost:
			return _job("mine_stone", "Need stone for storm rod")
		return _job("build_storm_rod", "Sign points to wings and sky" if sign_storm_preference > 0.0 else "Build favors anti-air")

	var tower_can_lead := wall_count > 0 or (aura_orb_count > 0 and wall_preference <= 0.0)
	if tower_preference > 0.22 and bow_tower_count < 1 and tower_can_lead:
		if stone < bow_tower_cost:
			return _job("mine_stone", "Need stone for tower")
		return _job("build_bow_tower", "Sign asks for height and arrows" if sign_tower_preference > 0.0 or range_preference > 0.0 else "Build favors tower")

	if mining_preference > 0.0 and stone < desired_stone_reserve:
		return _job("mine_stone", "Sign keeps pointing to stone" if sign_mining_preference > 0.0 else "Build favors mining")

	if not explicit_no_wall_plan and wall_count < desired_wall_count:
		if stone < wall_cost:
			return _job("mine_stone", "Need stone for wall")
		if sign_wall_preference > 0.0:
			return _job("build_wall", "Sign wants stronger walls")
		if building_points >= 4:
			return _job("build_wall", "Build favors walls")
		return _job("build_wall", "Too few walls")

	if wall_count > 0 and aura_orb_count < desired_aura_orb_count:
		if stone < aura_orb_cost:
			return _job("mine_stone", "Need stone for Aura Orb")
		return _job("place_aura_orb", "No aura orb yet")

	var basic_defenses_ready := wall_count >= mini(2, desired_wall_count) or (wall_count > 0 and aura_orb_count > 0)
	var stone_not_urgent := stone >= mini(wall_cost, aura_orb_cost) or wall_count >= desired_wall_count
	if combat_preference > 0.25 and basic_defenses_ready and stone_not_urgent and combat_level < desired_combat_level:
		if train_sword_preference > 0.25 and sword_skill < desired_sword_skill:
			return _job("train_sword", "Sign wants sword practice")
		if sign_combat_preference > 0.0:
			return _job("train_combat", "Sign says to prepare hands")
		return _job("train_combat", "Build favors combat readiness")

	if defensive_wait_preference > 0.25 and has_defenses:
		return _job("wait_or_idle", "Sign asks for safety")

	if range_preference > 0.0:
		return _job("wait_or_idle", "Sign asks for arrows; no bow yet")

	if defensive_wait_preference > 0.0 and has_defenses:
		return _job("wait_or_idle", "Sign asks for safety")

	return _job("wait_or_idle", "Basic defenses ready")


func choose_night_tactic(context: Dictionary) -> Dictionary:
	if not bool(context.get("is_night", false)):
		return _job("wait_or_idle", "Night tactic inactive")

	var priority_hints := _priority_hints(context)
	var lesson_bias := _lesson_bias(context)
	var enemy_type_counts := _enemy_type_counts(context)
	var runner_pressure := clampf(float(int(enemy_type_counts.get("runner", 0))) / 2.0, 0.0, 1.0)
	var brute_pressure := clampf(float(int(enemy_type_counts.get("brute", 0))), 0.0, 1.0)
	var flying_pressure := clampf(float(int(enemy_type_counts.get("flying", 0))), 0.0, 1.0)
	var cover_preference := maxf(
		maxf(_hint(priority_hints, "use_existing_wall"), _hint(priority_hints, "wait_behind_wall")),
		maxf(_hint(priority_hints, "use_cover"), _hint(priority_hints, "hide"))
	)
	var aura_lure_preference := maxf(_hint(priority_hints, "lure_to_aura"), _hint(priority_hints, "aura_orb") * 0.75)
	var tar_lure_preference := maxf(_hint(priority_hints, "lure_to_tar_pit"), _hint(priority_hints, "build_tar_pit") * 0.75)
	var lantern_use_preference := maxf(_hint(priority_hints, "use_fear_lantern"), _hint(priority_hints, "build_fear_lantern") * 0.78)
	var decoy_use_preference := maxf(_hint(priority_hints, "use_decoy_idol"), _hint(priority_hints, "build_decoy_idol") * 0.76)
	var tower_preference := maxf(
		maxf(_hint(priority_hints, "build_tower"), _hint(priority_hints, "use_tower")),
		maxf(maxf(_hint(priority_hints, "range"), _hint(priority_hints, "train_bow")), _hint(priority_hints, "ranged_attack"))
	)
	var sign_fight_head_on_preference := maxf(_hint(priority_hints, "fight_head_on"), _hint(priority_hints, "fight") * 0.65)
	var fight_head_on_preference := sign_fight_head_on_preference
	var sword_kill_preference := maxf(_hint(priority_hints, "train_sword"), _hint(priority_hints, "smith_sword"))
	var regen_kill_preference := maxf(_hint(priority_hints, "rely_on_regen"), _hint(priority_hints, "regen_on_kill"))
	if regen_kill_preference > 0.20 and sword_kill_preference > 0.25:
		fight_head_on_preference = maxf(fight_head_on_preference, 0.46 + regen_kill_preference * 0.22)
	var armor_preference := _hint(priority_hints, "use_armor")
	var thorn_preference := _hint(priority_hints, "build_thorn_totem")
	var thorn_use_preference := maxf(_hint(priority_hints, "use_thorns"), thorn_preference * 0.74)
	var repair_bench_preference := _hint(priority_hints, "build_repair_bench")
	var repair_preference := maxf(_hint(priority_hints, "repair_structure"), _hint(priority_hints, "repair"))
	var dawn_survival_preference := maxf(
		maxf(_hint(priority_hints, "stall_until_dawn"), _hint(priority_hints, "hide_until_dawn")),
		maxf(_hint(priority_hints, "survive_until_morning"), _hint(priority_hints, "avoid_killing"))
	)
	var hold_best_defense_preference := _hint(priority_hints, "hold_best_defense")
	hold_best_defense_preference = clampf(hold_best_defense_preference + _bias_hint(lesson_bias, "hold_best_defense"), 0.0, 1.0)
	var flee_preference := maxf(_hint(priority_hints, "flee"), _hint(priority_hints, "kite"))
	var has_valid_cover := bool(context.get("has_valid_cover", int(context.get("wall_count", 0)) > 0))
	var has_valid_aura := bool(context.get("has_valid_aura", int(context.get("aura_orb_count", 0)) > 0))
	var has_valid_tower := bool(context.get("has_valid_tower", int(context.get("bow_tower_count", 0)) > 0))
	var has_valid_tar_pit := bool(context.get("has_valid_tar_pit", int(context.get("tar_pit_count", 0)) > 0))
	var has_valid_fear_lantern := bool(context.get("has_valid_fear_lantern", int(context.get("fear_lantern_count", 0)) > 0))
	var has_valid_decoy_idol := bool(context.get("has_valid_decoy_idol", int(context.get("decoy_idol_count", 0)) > 0))
	var decoy_idol_hp_ratio := clampf(float(context.get("decoy_idol_hp_ratio", 1.0)), 0.0, 1.0)
	var has_valid_thorn_totem := bool(context.get("has_valid_thorn_totem", int(context.get("thorn_totem_count", 0)) > 0))
	var wall_count := int(context.get("wall_count", 0))
	var repair_bench_count := int(context.get("repair_bench_count", 0))
	var storm_rod_count := int(context.get("storm_rod_count", 0))
	var damaged_structure_count := int(context.get("damaged_structure_count", 0))
	var lowest_structure_hp_ratio := clampf(float(context.get("lowest_structure_hp_ratio", 1.0)), 0.0, 1.0)
	var nearest_enemy_distance := float(context.get("nearest_enemy_distance", INF))
	var ari_hp_ratio := clampf(float(context.get("ari_hp_ratio", 1.0)), 0.0, 1.0)
	var needs := _needs(context)
	var fear := float(needs.get("fear", 0.0))
	var combat_stats := _combat_stats(context)
	var armor := float(combat_stats.get("armor", 0.0))
	var thorn_totem_count := int(context.get("thorn_totem_count", 0))
	var active_enemy_count := int(context.get("enemy_count", 0))
	var wants_thorn_ground := thorn_totem_count > 0 and armor >= 0.10 and maxf(maxf(armor_preference, thorn_preference), thorn_use_preference) > 0.25
	if runner_pressure > 0.0:
		cover_preference = maxf(cover_preference, 0.34 + runner_pressure * 0.12)
		aura_lure_preference = maxf(aura_lure_preference, 0.34 + runner_pressure * 0.14)
		tar_lure_preference = maxf(tar_lure_preference, 0.36 + runner_pressure * 0.14)
		decoy_use_preference = maxf(decoy_use_preference, 0.35 + runner_pressure * 0.12)
		tower_preference = maxf(tower_preference, 0.32 + runner_pressure * 0.16)
		flee_preference = maxf(flee_preference, 0.20 + runner_pressure * 0.08)
	if brute_pressure > 0.0:
		aura_lure_preference = maxf(aura_lure_preference, 0.42 + brute_pressure * 0.12)
		tar_lure_preference = maxf(tar_lure_preference, 0.40 + brute_pressure * 0.10)
		decoy_use_preference = maxf(decoy_use_preference, 0.38 + brute_pressure * 0.10)
		tower_preference = maxf(tower_preference, 0.44 + brute_pressure * 0.14)
	if flying_pressure > 0.0:
		tower_preference = maxf(tower_preference, 0.42 + flying_pressure * 0.12)
		aura_lure_preference = maxf(aura_lure_preference, 0.34 + flying_pressure * 0.08)
		cover_preference = clampf(cover_preference - flying_pressure * 0.18, 0.0, 1.0)
		flee_preference = maxf(flee_preference, 0.22 + flying_pressure * 0.08)
	if fear > 62.0:
		lantern_use_preference = maxf(lantern_use_preference, 0.34 + (fear / 100.0) * 0.28)
	var wants_cover := cover_preference > 0.25
	var wants_aura_lure := aura_lure_preference > 0.25
	var wants_tar_lure := tar_lure_preference > 0.25
	var wants_lantern := lantern_use_preference > 0.25
	var wants_decoy := decoy_use_preference > 0.25
	var wants_thorns := thorn_use_preference > 0.25
	var wants_tower := tower_preference > 0.25
	var wants_best_defense_hold := hold_best_defense_preference > 0.30
	var ready_sky_tower_plan := storm_rod_count > 0 and has_valid_tower and maxf(tower_preference, _hint(priority_hints, "build_storm_rod")) > 0.25
	var wants_dawn_survival := dawn_survival_preference > 0.30
	var decoy_is_breaking := wants_decoy and has_valid_decoy_idol and decoy_idol_hp_ratio <= 0.45
	var repair_wall_line_plan := has_valid_cover and wall_count >= 2 and runner_pressure > 0.0 and (repair_bench_count > 0 or repair_bench_preference > 0.25 or repair_preference > 0.25)
	var cover_is_collapsing := has_valid_cover and damaged_structure_count > 0 and lowest_structure_hp_ratio <= 0.32
	var runner_group_breaks_cover := runner_pressure >= 0.9 and active_enemy_count >= 2 and cover_is_collapsing and not has_valid_aura and not has_valid_tower and not has_valid_tar_pit and not has_valid_fear_lantern and not has_valid_decoy_idol and not has_valid_thorn_totem

	if active_enemy_count <= 0:
		var quiet_food_job := _job_from_grounded_plan_actions(context, true, ["eat", "eat_food"])
		if not quiet_food_job.is_empty():
			return quiet_food_job
		if wants_best_defense_hold:
			var hold_job := _best_defense_hold_job(has_valid_tower, has_valid_aura, has_valid_cover, has_valid_fear_lantern, has_valid_decoy_idol, has_valid_thorn_totem)
			if not hold_job.is_empty():
				return hold_job
		if wants_lantern and has_valid_fear_lantern:
			return _job("use_fear_lantern", "Night is quiet; hold the warm light before teeth arrive")
		if wants_tower and has_valid_tower:
			return _job("use_tower", "Night is quiet; stage at range before teeth arrive")
		if wants_aura_lure and has_valid_aura:
			return _job("lure_to_aura", "Night is quiet; stand where the light can matter")
		if wants_dawn_survival and has_valid_aura:
			return _job("lure_to_aura", "Survive until morning; stage at the light")
		if wants_dawn_survival and has_valid_cover:
			return _job("use_cover", "Survive until morning; stage behind cover")
		if wants_cover and has_valid_cover:
			return _job("use_cover", "Night is quiet; keep cover ready")
		return _job("wait_or_idle", "Night has started")

	if ari_hp_ratio <= night_low_hp_ratio:
		if nearest_enemy_distance > night_flee_enemy_distance:
			if wants_lantern and has_valid_fear_lantern:
				return _job("use_fear_lantern", "HP is low; hold the warm light instead of running blind")
			if wants_tower and has_valid_tower:
				return _job("use_tower", "HP is low; use range instead of running blind")
			if wants_tower and not has_valid_tower and has_valid_aura:
				return _job("lure_to_aura", "The tower is gone; use the light")
			if wants_tower and not has_valid_tower and has_valid_cover:
				return _job("use_cover", "The tower is gone; use the wall")
			if wants_aura_lure and has_valid_aura:
				return _job("lure_to_aura", "HP is low; make the light take contact")
			if wants_cover and has_valid_cover:
				return _job("use_cover", "HP is low; keep a wall between Ari and teeth")
			if has_valid_aura:
				return _job("lure_to_aura", "HP is low; use the remaining light")
			if has_valid_cover:
				return _job("use_cover", "HP is low; use the remaining cover")
		return _job("flee", "HP is low; move away from danger")
	var wounded_melee_plan := fight_head_on_preference > 0.45 and (ari_hp_ratio < 0.76 or fear > 84.0) and (has_valid_aura or has_valid_cover or has_valid_tower)
	if wounded_melee_plan:
		if runner_group_breaks_cover:
			return _job("flee", "Runner pressure will break the weak cover; move before it collapses")
		if has_valid_aura:
			return _job("lure_to_aura", "Wounded sword plan uses the light before more contact")
		if has_valid_cover:
			return _job("use_cover", "Wounded sword plan keeps the wall between Ari and teeth")
		if has_valid_tower:
			return _job("use_tower", "Wounded sword plan uses range before more contact")
		if nearest_enemy_distance <= night_flee_enemy_distance:
			return _job("flee", "Wounded sword plan needs distance")
	if fight_head_on_preference > 0.45 and _can_fight_head_on(combat_stats, ari_hp_ratio, enemy_type_counts, active_enemy_count):
		return _job("fight_head_on", _direct_fight_reason(sign_fight_head_on_preference, sword_kill_preference, regen_kill_preference, armor_preference))
	if runner_group_breaks_cover:
		return _job("flee", "Runner pressure will break the weak cover; move before it collapses")
	if wants_thorn_ground and nearest_enemy_distance <= night_flee_enemy_distance:
		return _job("use_thorns", "Armor and thorns make this ground worth holding") if has_valid_thorn_totem else _job("wait_or_idle", "Armor and thorns make this ground worth holding")
	if nearest_enemy_distance <= night_flee_enemy_distance:
		if repair_wall_line_plan:
			return _job("use_cover", "Repair tools need the wall line, not open ground")
		return _job("flee", "Enemies are too close; move")
	if ready_sky_tower_plan:
		return _job("use_tower", "Storm Rod is ready; keep tower range")
	if wants_best_defense_hold:
		var pressure_hold_job := _best_defense_hold_job(has_valid_tower, has_valid_aura, has_valid_cover, has_valid_fear_lantern, has_valid_decoy_idol, has_valid_thorn_totem)
		if not pressure_hold_job.is_empty():
			return pressure_hold_job
	var grounded_job := _job_from_grounded_plan(context, true)
	if not grounded_job.is_empty():
		return grounded_job
	if wants_dawn_survival and (has_valid_cover or has_valid_aura or has_valid_tower):
		return _job("hide_until_dawn" if has_valid_cover else "stall_until_dawn", "Survive until morning; do not spend life chasing kills")
	if wants_tower and not has_valid_tower and not has_valid_aura and not has_valid_cover:
		return _job("flee", "The tower is gone; find another answer")
	if wants_cover and not has_valid_cover and not has_valid_aura and not has_valid_tower:
		return _job("flee", "The wall is gone; find another answer")
	if wants_aura_lure and not has_valid_aura and not has_valid_tower and not has_valid_cover:
		return _job("flee", "The light is gone; find another answer")
	if wants_tar_lure and not has_valid_tar_pit and not has_valid_tower and not has_valid_aura and not has_valid_cover:
		return _job("flee", "The slow ground is gone; find another answer")
	if wants_tar_lure and not has_valid_tar_pit and has_valid_aura:
		return _job("lure_to_aura", "The slow ground is gone; use the light")
	if wants_tar_lure and not has_valid_tar_pit and has_valid_cover:
		return _job("use_cover", "The slow ground is gone; use the wall")
	if wants_lantern and not has_valid_fear_lantern and not has_valid_tower and not has_valid_aura and not has_valid_cover:
		return _job("flee", "The warm light is gone; find another answer")
	if wants_decoy and not has_valid_decoy_idol and not has_valid_tower and not has_valid_aura and not has_valid_cover:
		return _job("flee", "The decoy is gone; find another answer")
	if wants_thorns and not has_valid_thorn_totem and not has_valid_tower and not has_valid_aura and not has_valid_cover:
		return _job("flee", "The thorn ground is gone; find another answer")
	if wants_tower and not has_valid_tower and has_valid_aura:
		return _job("lure_to_aura", "The tower is gone; use the light")
	if wants_tower and not has_valid_tower and has_valid_cover:
		return _job("use_cover", "The tower is gone; use the wall")
	if wants_lantern and not has_valid_fear_lantern and has_valid_aura:
		return _job("lure_to_aura", "The warm light is gone; use the aura")
	if wants_lantern and not has_valid_fear_lantern and has_valid_cover:
		return _job("use_cover", "The warm light is gone; use the wall")
	if wants_decoy and not has_valid_decoy_idol and has_valid_aura:
		return _job("lure_to_aura", "The false self is gone; use the light")
	if wants_decoy and not has_valid_decoy_idol and has_valid_cover:
		return _job("use_cover", "The false self is gone; use the wall")
	if decoy_is_breaking and has_valid_aura:
		return _job("lure_to_aura", "The false self is breaking; move through the light")
	if decoy_is_breaking and has_valid_cover:
		return _job("use_cover", "The false self is breaking; fall back to cover")
	if wants_tower and has_valid_tower and tower_preference >= aura_lure_preference and tower_preference >= cover_preference and tower_preference >= tar_lure_preference and tower_preference >= lantern_use_preference and tower_preference >= decoy_use_preference:
		return _job("use_tower", "Use height and range while enemies approach")
	if wants_tar_lure and has_valid_tar_pit and tar_lure_preference >= aura_lure_preference and tar_lure_preference >= cover_preference and tar_lure_preference >= tower_preference and tar_lure_preference >= lantern_use_preference and tar_lure_preference >= decoy_use_preference:
		return _job("lure_to_tar_pit", "Keep the dead crossing slow mud")
	if wants_decoy and has_valid_decoy_idol and decoy_use_preference >= aura_lure_preference and decoy_use_preference >= cover_preference and decoy_use_preference >= tower_preference:
		return _job("use_decoy_idol", "Let the false self take their teeth")
	if wants_thorns and has_valid_thorn_totem and armor >= 0.10 and thorn_use_preference >= aura_lure_preference and thorn_use_preference >= cover_preference and thorn_use_preference >= tower_preference:
		return _job("use_thorns", "Hold thorn ground and make contact cost them")
	if wants_lantern and has_valid_fear_lantern and lantern_use_preference >= aura_lure_preference and lantern_use_preference >= cover_preference and lantern_use_preference >= tower_preference and lantern_use_preference >= tar_lure_preference and lantern_use_preference >= decoy_use_preference:
		return _job("use_fear_lantern", "Hold the warm light while fear rises")
	if wants_aura_lure and has_valid_aura and aura_lure_preference >= cover_preference and aura_lure_preference >= tar_lure_preference and aura_lure_preference >= lantern_use_preference and aura_lure_preference >= decoy_use_preference:
		return _job("lure_to_aura", "Keep the dead crossing the light")
	if wants_cover and has_valid_cover:
		return _job("use_cover", "Keep the wall between Ari and teeth")
	if wants_tower and has_valid_tower:
		return _job("use_tower", "Use height and range while enemies approach")
	if wants_aura_lure and has_valid_aura:
		return _job("lure_to_aura", "Keep the dead crossing the light")
	if wants_tar_lure and has_valid_tar_pit:
		return _job("lure_to_tar_pit", "Keep the dead crossing slow mud")
	if wants_lantern and has_valid_fear_lantern:
		return _job("use_fear_lantern", "Hold the warm light while fear rises")
	if wants_decoy and has_valid_decoy_idol:
		return _job("use_decoy_idol", "Let the false self take their teeth")
	if wants_thorns and has_valid_thorn_totem and armor >= 0.10:
		return _job("use_thorns", "Hold thorn ground and make contact cost them")
	if flee_preference > 0.25:
		return _job("flee", "Sign asks for distance")
	if has_valid_tower:
		return _job("use_tower", "No clearer tactic; use the remaining tower")
	if has_valid_aura:
		return _job("lure_to_aura", "No clearer tactic; use the remaining light")
	if has_valid_cover:
		return _job("use_cover", "No clearer tactic; use the remaining cover")
	return _job("wait_or_idle", "No night tactic")


func _best_defense_hold_job(has_valid_tower: bool, has_valid_aura: bool, has_valid_cover: bool, has_valid_fear_lantern: bool, has_valid_decoy_idol: bool, has_valid_thorn_totem: bool) -> Dictionary:
	if has_valid_tower:
		return _job("use_tower", "Hold the safest known defense: tower range")
	if has_valid_aura:
		return _job("lure_to_aura", "Hold the safest known defense: the light")
	if has_valid_cover:
		return _job("use_cover", "Hold the safest known defense: cover")
	if has_valid_fear_lantern:
		return _job("use_fear_lantern", "Hold the safest known defense: warm light")
	if has_valid_decoy_idol:
		return _job("use_decoy_idol", "Hold the safest known defense: decoy ground")
	if has_valid_thorn_totem:
		return _job("use_thorns", "Hold the safest known defense: thorn ground")
	return {}


func _direct_fight_reason(explicit_fight_preference: float, sword_preference: float, regen_preference: float, armor_preference: float) -> String:
	if explicit_fight_preference > 0.45:
		return "Sign asks Ari to fight directly"
	if regen_preference > 0.20 and sword_preference > 0.25:
		return "Sword and life-on-kill plan can risk direct contact"
	if sword_preference > 0.25:
		return "Sword plan is ready enough for direct ground combat"
	if armor_preference > 0.25:
		return "Armor makes direct contact safer"
	return "Ari is combat-ready enough for direct ground combat"


func thought_for_job(job: String, reason: String, run_build := {}) -> String:
	var lower_reason := reason.to_lower()
	match job:
		"mine_stone":
			if lower_reason.find("build favors mining") >= 0:
				return "This build starts with stone. I should fill my hands."
			if lower_reason.find("sign keeps pointing") >= 0:
				return "The sign keeps saying stone. I should mine more."
			if lower_reason.find("aura") >= 0:
				return "I need stone before the light can protect me."
			if lower_reason.find("sign's light") >= 0:
				return "I need stone before the light can protect me."
			return "Stone first. Weak walls only pretend to protect me."
		"build_wall":
			if lower_reason.find("build favors walls") >= 0:
				return "This build wants shape and cover. I will make walls."
			if lower_reason.find("sign wants") >= 0:
				return "The sign wants walls. I can make the teeth wait outside."
			return "I need a wall before the night comes."
		"place_aura_orb":
			if lower_reason.find("build favors aura") >= 0:
				return "This build trusts the circle. Let it hurt them first."
			return "The light can hurt them before they reach me."
		"build_spike_trap":
			if lower_reason.find("floor") >= 0:
				return "The floor can fight before I have to."
			return "A trap can make contact cost them something."
		"build_bow_tower":
			if lower_reason.find("height") >= 0 or lower_reason.find("arrows") >= 0:
				return "If I stand high enough, maybe death has to climb."
			return "Distance can be a kind of wall."
		"use_tower":
			if lower_reason.find("range") >= 0 or lower_reason.find("height") >= 0:
				return "Up here, their hands cannot reach me."
			return "Arrows keep teeth far away."
		"build_tar_pit":
			if lower_reason.find("slow") >= 0:
				return "If the ground grabs them, I get more time."
			return "Mud can make their teeth arrive late."
		"build_fear_lantern":
			if lower_reason.find("warm") >= 0:
				return "A warm light might make my fear smaller."
			return "I need one place where the dark feels weaker."
		"build_decoy_idol":
			if lower_reason.find("bait") >= 0:
				return "Let the dead look at the idol instead of me."
			return "A false me can buy the real me time."
		"build_thorn_totem":
			if lower_reason.find("touch") >= 0:
				return "If they touch what protects me, they should bleed."
			return "Thorns can make every bite cost them."
		"build_repair_bench":
			if lower_reason.find("tools") >= 0:
				return "If the walls break, I need tools ready."
			return "A bench can help me keep the weak things standing."
		"repair_structure":
			if lower_reason.find("sign says") >= 0:
				return "The sign says repair. Broken safety is still worth saving."
			return "This is damaged. I can make it hold a little longer."
		"use_cover":
			return "The wall is already there. I should put it between me and their teeth."
		"lure_to_aura":
			return "If they cross the light, I do not have to touch them."
		"lure_to_tar_pit":
			return "If they cross the mud, their teeth arrive late."
		"use_fear_lantern":
			return "Warm light makes this spot less afraid."
		"use_decoy_idol":
			return "The false me should be closer to their teeth than I am."
		"use_thorns":
			return "If I hold the thorns, touching me hurts them too."
		"flee":
			if lower_reason.find("wall") >= 0:
				return "The wall is gone. I need another answer."
			if lower_reason.find("light") >= 0:
				return "The light is gone. I need to move before they reach me."
			if lower_reason.find("close") >= 0:
				return "They are too close. I have to move."
			if lower_reason.find("hp") >= 0 or lower_reason.find("low") >= 0:
				return "I am too hurt to trust this spot."
			return "This place is not safe. I have to move."
		"build_storm_rod":
			if lower_reason.find("wings") >= 0 or lower_reason.find("sky") >= 0:
				return "The wall did not reach the sky. The storm might."
			return "If the air brings teeth, I need lightning above me."
		"train_combat":
			if lower_reason.find("prepare hands") >= 0:
				return "The sign says teeth. I should prepare my hands."
			if lower_reason.find("ranged") >= 0:
				return "The sign wants distance. I should practice before night."
			return "The dummy does not bite. I can practice here."
		"train_sword":
			return "If I am going to use a sword, the dummy should suffer first."
		"mine_ore":
			return "A better blade starts under the stone."
		"smith_sword":
			return "Ore can become a sharper answer."
		"fight_head_on":
			if lower_reason.find("life-on-kill") >= 0 or lower_reason.find("sword") >= 0 or lower_reason.find("blade") >= 0:
				return "The blade plan is ready. Contact might pay back life."
			if lower_reason.find("sign asks") >= 0 or lower_reason.find("fight directly") >= 0:
				return "The sign asks me to fight. I will make the first strike matter."
			return "I am ready enough to make the first strike matter."
		"stall_until_dawn", "hide_until_dawn":
			return "I do not have to kill the night. I have to reach morning."
		"farm_food":
			if lower_reason.find("sign points") >= 0:
				return "The sign says food. A full stomach might keep fear quiet."
			return "If I am fed, the night feels smaller."
		"eat_food":
			return "A full stomach is a wall inside me."
		"rest":
			if lower_reason.find("quiet") >= 0:
				return "I need quiet. I cannot think with the dark touching me."
			return "I should rest before fear makes decisions."
		"reflect_library":
			if lower_reason.find("sign") >= 0:
				return "The sign wants memory. I should read what happened."
			return "Maybe the library can turn fear into a lesson."
		"wait_or_idle":
			if lower_reason.find("no bow yet") >= 0:
				return "The sign wants arrows, but I do not have arrows yet."
			if lower_reason.find("repair") >= 0:
				return "The sign wants repair, but my hands do not know that yet."
			if lower_reason.find("sign asks for safety") >= 0:
				return "The sign says safe. I will stay near what can protect me."
			if lower_reason.find("night has started") >= 0:
				return "The dark is here. I need to stop preparing."
			if lower_reason.find("defenses ready") >= 0 or lower_reason.find("stay near defenses") >= 0:
				return "I have done what I can. Now I wait."
	return ""


func thought_for_damage(hp: float, max_hp: float) -> String:
	if hp <= 0.0:
		return ""
	if max_hp > 0.0 and hp / max_hp <= 0.3:
		return "That hurt. I am too close to dying."
	return "That hurt. I do not want them near me."


func _job_from_grounded_plan(context: Dictionary, is_night: bool) -> Dictionary:
	var plan := _grounded_plan(context)
	for item in plan:
		var affordance_id := str(item.get("affordance_id", item.get("id", "")))
		var job := _job_for_affordance(affordance_id, context, is_night, item)
		if not job.is_empty():
			return job
	return {}


func _job_from_grounded_plan_actions(context: Dictionary, is_night: bool, action_ids: Array) -> Dictionary:
	var allowed := {}
	for action_id in action_ids:
		allowed[str(action_id)] = true
	var plan := _grounded_plan(context)
	for item in plan:
		var affordance_id := str(item.get("affordance_id", item.get("id", "")))
		if not bool(allowed.get(affordance_id, false)):
			continue
		var job := _job_for_affordance(affordance_id, context, is_night, item)
		if not job.is_empty():
			return job
	return {}


func _job_for_affordance(affordance_id: String, context: Dictionary, is_night: bool, plan_item := {}) -> Dictionary:
	var wall_count := int(context.get("wall_count", 0))
	var aura_orb_count := int(context.get("aura_orb_count", 0))
	var bow_tower_count := int(context.get("bow_tower_count", 0))
	var tar_pit_count := int(context.get("tar_pit_count", 0))
	var fear_lantern_count := int(context.get("fear_lantern_count", 0))
	var decoy_idol_count := int(context.get("decoy_idol_count", 0))
	var thorn_totem_count := int(context.get("thorn_totem_count", 0))
	var repair_bench_count := int(context.get("repair_bench_count", 0))
	var storm_rod_count := int(context.get("storm_rod_count", 0))
	var stone := int(context.get("stone", 0))
	var ore := int(context.get("ore", 0))
	var wall_cost := int(context.get("wall_cost", 0))
	var aura_orb_cost := int(context.get("aura_orb_cost", 0))
	var bow_tower_cost := int(context.get("bow_tower_cost", 0))
	var repair_bench_cost := int(context.get("repair_bench_cost", 0))
	var storm_rod_cost := int(context.get("storm_rod_cost", 0))
	var sword_next_ore_cost := int(context.get("sword_next_ore_cost", 0))
	var damaged_structure_count := int(context.get("damaged_structure_count", 0))
	var has_valid_cover := bool(context.get("has_valid_cover", wall_count > 0))
	var has_valid_aura := bool(context.get("has_valid_aura", aura_orb_count > 0))
	var has_valid_tower := bool(context.get("has_valid_tower", bow_tower_count > 0))
	var has_valid_tar_pit := bool(context.get("has_valid_tar_pit", tar_pit_count > 0))
	var has_valid_fear_lantern := bool(context.get("has_valid_fear_lantern", fear_lantern_count > 0))
	var has_valid_decoy_idol := bool(context.get("has_valid_decoy_idol", decoy_idol_count > 0))
	var has_valid_thorn_totem := bool(context.get("has_valid_thorn_totem", thorn_totem_count > 0))
	var enemy_count := int(context.get("enemy_count", 0))
	var enemy_type_counts := _enemy_type_counts(context)
	var ari_hp_ratio := clampf(float(context.get("ari_hp_ratio", 1.0)), 0.0, 1.0)
	var combat_stats := _combat_stats(context)

	match affordance_id:
		"use_existing_wall", "wait_behind_wall", "use_cover", "hide":
			if is_night:
				if has_valid_cover:
					return _job("use_cover", "Grounded plan uses the existing wall")
				if not has_valid_aura and not has_valid_tower:
					return _job("flee", "The wall is gone; try the next safe answer")
				return {}
			if wall_count > 0:
				return _job("use_cover", "Grounded plan uses the existing wall")
			return {}
		"lure_to_aura":
			if is_night:
				return _job("lure_to_aura", "Grounded plan lures danger through light") if has_valid_aura else {}
			return _job("lure_to_aura", "Grounded plan lures danger through light") if aura_orb_count > 0 else {}
		"lure_to_tar_pit":
			if is_night:
				return _job("lure_to_tar_pit", "Grounded plan lures danger through slow mud") if has_valid_tar_pit else {}
			return _job("lure_to_tar_pit", "Grounded plan lures danger through slow mud") if tar_pit_count > 0 else {}
		"use_fear_lantern":
			if is_night:
				return _job("use_fear_lantern", "Grounded plan holds the warm light") if has_valid_fear_lantern else {}
			return _job("use_fear_lantern", "Grounded plan holds the warm light") if fear_lantern_count > 0 else {}
		"use_decoy_idol":
			if is_night:
				return _job("use_decoy_idol", "Grounded plan hides behind the false self") if has_valid_decoy_idol else {}
			return _job("use_decoy_idol", "Grounded plan hides behind the false self") if decoy_idol_count > 0 else {}
		"use_thorns":
			if is_night:
				return _job("use_thorns", "Grounded plan holds thorn ground") if has_valid_thorn_totem else {}
			return _job("use_thorns", "Grounded plan holds thorn ground") if thorn_totem_count > 0 else {}
		"place_aura_orb":
			if is_night:
				return {}
			var source := str(plan_item.get("source", "")) if typeof(plan_item) == TYPE_DICTIONARY else ""
			if aura_orb_count > 0 and source != "agent":
				return _job("lure_to_aura", "Aura already exists; use the light")
			if stone < aura_orb_cost:
				return _job("mine_stone", "Grounded plan needs stone for Aura Orb")
			return _job("place_aura_orb", "Grounded plan wants the light circle")
		"use_tower", "ranged_attack", "train_bow":
			if is_night:
				return _job("use_tower", "Grounded plan uses tower range") if has_valid_tower else {}
			if bow_tower_count > 0:
				return _job("use_tower", "Grounded plan uses tower range")
			return {}
		"build_tower":
			if is_night:
				return {}
			var source := str(plan_item.get("source", "")) if typeof(plan_item) == TYPE_DICTIONARY else ""
			if bow_tower_count > 0 and source != "agent":
				return _job("use_tower", "Tower already exists; use range")
			if stone < bow_tower_cost:
				return _job("mine_stone", "Grounded plan needs stone for tower")
			return _job("build_bow_tower", "Grounded plan wants height and arrows")
		"build_wall":
			if is_night:
				return {}
			if stone < wall_cost:
				return _job("mine_stone", "Grounded plan needs stone for wall")
			return _job("build_wall", "Grounded plan wants new cover")
		"build_tar_pit":
			if is_night:
				return _job("lure_to_tar_pit", "Tar pit already exists; use the slow ground") if has_valid_tar_pit else {}
			if tar_pit_count > 0:
				return _job("lure_to_tar_pit", "Tar pit already exists; use the slow ground")
			var tar_pit_cost := int(context.get("tar_pit_cost", 0))
			if stone < tar_pit_cost:
				return _job("mine_stone", "Grounded plan needs stone for tar pit")
			return _job("build_tar_pit", "Grounded plan wants slow ground")
		"build_fear_lantern":
			if is_night:
				return _job("use_fear_lantern", "Fear lantern already exists; hold the warm light") if has_valid_fear_lantern else {}
			if fear_lantern_count > 0:
				return _job("use_fear_lantern", "Fear lantern already exists; hold the warm light")
			var fear_lantern_cost := int(context.get("fear_lantern_cost", 0))
			if stone < fear_lantern_cost:
				return _job("mine_stone", "Grounded plan needs stone for lantern")
			return _job("build_fear_lantern", "Grounded plan wants warm safety")
		"build_decoy_idol":
			if is_night:
				return _job("use_decoy_idol", "Decoy already exists; hide behind the false self") if has_valid_decoy_idol else {}
			if decoy_idol_count > 0:
				return _job("use_decoy_idol", "Decoy already exists; hide behind the false self")
			var decoy_idol_cost := int(context.get("decoy_idol_cost", 0))
			if stone < decoy_idol_cost:
				return _job("mine_stone", "Grounded plan needs stone for decoy")
			return _job("build_decoy_idol", "Grounded plan wants a false self")
		"build_thorn_totem":
			if is_night:
				return _job("use_thorns", "Thorn Totem already exists; hold thorn ground") if has_valid_thorn_totem else {}
			if thorn_totem_count > 0:
				return _job("use_thorns", "Thorn Totem already exists; hold thorn ground")
			var thorn_totem_cost := int(context.get("thorn_totem_cost", 0))
			if stone < thorn_totem_cost:
				return _job("mine_stone", "Grounded plan needs stone for thorns")
			return _job("build_thorn_totem", "Grounded plan wants contact to hurt")
		"build_repair_bench":
			if is_night:
				return {}
			if repair_bench_count > 0:
				if damaged_structure_count > 0:
					return _job("repair_structure", "Repair bench exists; patch damaged safety")
				return {}
			if wall_count < mini(target_wall_count, 2):
				if stone < wall_cost:
					return _job("mine_stone", "Grounded repair plan needs stone for walls")
				return _job("build_wall", "Grounded repair plan needs walls worth repairing")
			if stone < repair_bench_cost:
				return _job("mine_stone", "Grounded plan needs stone for repair tools")
			return _job("build_repair_bench", "Grounded plan wants repair tools ready")
		"build_storm_rod", "anti_flying", "sky_answer":
			if is_night:
				return _job("use_tower", "Storm is not ready; use range against the sky") if has_valid_tower else {}
			if storm_rod_count > 0:
				if bow_tower_count > 0:
					return _job("use_tower", "Storm Rod exists; keep ranged safety")
				if stone < bow_tower_cost:
					return _job("mine_stone", "Grounded sky plan needs stone for ranged support")
				return _job("build_bow_tower", "Storm Rod exists; add ranged sky support")
			if stone < storm_rod_cost:
				return _job("mine_stone", "Grounded plan needs stone for storm rod")
			return _job("build_storm_rod", "Grounded plan answers wings with storm")
		"farm_food":
			return _job("farm_food", "Grounded plan treats food as safety") if not is_night else {}
		"eat", "eat_food":
			if int(context.get("food", 0)) > 0:
				return _job("eat_food", "Grounded plan treats food as safety")
			return _job("farm_food", "Grounded plan needs food first") if not is_night else {}
		"rest":
			return _job("rest", "Grounded plan asks for recovery") if not is_night else {}
		"reflect_library":
			if is_night or not _reflection_survival_ready(context):
				return {}
			return _job("reflect_library", "Grounded plan asks Ari to study the mistake")
		"repair":
			if damaged_structure_count > 0:
				return _job("repair_structure", "Grounded plan repairs damaged safety")
			return _job("wait_or_idle", "Grounded plan wants repair, but nothing is broken yet") if not is_night else {}
		"mine_stone":
			return _job("mine_stone", "Grounded plan gathers stone for the next defense") if not is_night else {}
		"mine_ore":
			return _job("mine_ore", "Grounded plan points to ore") if not is_night else {}
		"smith_sword":
			if is_night:
				return {}
			if sword_next_ore_cost > 0 and ore < sword_next_ore_cost:
				return _job("mine_ore", "Grounded plan needs ore before smithing")
			if sword_next_ore_cost > 0:
				return _job("smith_sword", "Grounded plan wants a stronger sword")
			return {}
		"train_sword":
			return _job("train_sword", "Grounded plan wants sword practice") if not is_night else {}
		"train_combat", "prepare_weapon":
			return _job("train_combat", "Grounded plan wants combat preparation") if not is_night else {}
		"fight", "fight_head_on":
			if _can_fight_head_on(combat_stats, ari_hp_ratio, enemy_type_counts, maxi(enemy_count, 1)):
				return _job("fight_head_on", "Grounded plan accepts direct combat")
			return _job("train_combat", "Grounded plan wants fighting, but Ari needs training") if not is_night else {}
		"stall_until_dawn", "hide_until_dawn", "survive_until_morning", "avoid_killing":
			if is_night:
				if has_valid_cover:
					return _job("hide_until_dawn", "Grounded plan says to survive until morning")
				if has_valid_aura or has_valid_tower:
					return _job("stall_until_dawn", "Grounded plan says to survive until morning")
				return _job("flee", "Grounded plan needs distance until dawn")
			return _job("wait_or_idle", "Grounded plan saves strength for night")
		"flee", "kite":
			return _job("flee", "Grounded plan asks for distance") if is_night or enemy_count > 0 else {}
	return {}


func _reflection_survival_ready(context: Dictionary) -> bool:
	var wall_count := int(context.get("wall_count", 0))
	var aura_orb_count := int(context.get("aura_orb_count", 0))
	return wall_count >= mini(2, target_wall_count) and aura_orb_count >= target_aura_orb_count


func _grounded_plan(context: Dictionary) -> Array:
	var result := []
	_append_grounded_plan_items(result, context.get("agent_grounded_plan", []), "agent")
	_append_grounded_plan_items(result, context.get("grounded_plan", []), "sign")
	return result


func _plan_has_affordance(raw_plan, affordance_id: String) -> bool:
	if typeof(raw_plan) != TYPE_ARRAY:
		return false
	for item in raw_plan:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var item_id := str(item.get("affordance_id", item.get("id", ""))).strip_edges()
		if item_id == affordance_id:
			return true
	return false


func _direct_priority_hints(context: Dictionary) -> Dictionary:
	var result := {}
	var hints = context.get("priority_hints", {})
	if typeof(hints) == TYPE_DICTIONARY:
		for key in hints.keys():
			result[str(key)] = clampf(float(hints[key]), 0.0, 1.0)
	return result


func _priority_hints(context: Dictionary) -> Dictionary:
	var result := _direct_priority_hints(context)
	for grounded_plan in [context.get("agent_grounded_plan", []), context.get("grounded_plan", [])]:
		if typeof(grounded_plan) != TYPE_ARRAY:
			continue
		for item in grounded_plan:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var key := str(item.get("affordance_id", item.get("id", "")))
			if key == "":
				continue
			result[key] = maxf(float(result.get(key, 0.0)), clampf(float(item.get("priority", 0.0)), 0.0, 1.0))
	return result


func _lesson_bias(context: Dictionary) -> Dictionary:
	var bias = context.get("lesson_priority_bias", {})
	var result := {}
	if typeof(bias) != TYPE_DICTIONARY:
		return result
	for key in bias.keys():
		result[str(key)] = clampf(float(bias[key]), -1.0, 1.0)
	return result


func _run_build(context: Dictionary) -> Dictionary:
	var run_build = context.get("run_build", {})
	if typeof(run_build) == TYPE_DICTIONARY:
		return run_build
	return {}


func _enemy_type_counts(context: Dictionary) -> Dictionary:
	var counts = context.get("enemy_type_counts", {})
	if typeof(counts) == TYPE_DICTIONARY:
		return counts
	return {}


func _combat_stats(context: Dictionary) -> Dictionary:
	var combat_stats = context.get("combat_stats", {})
	if typeof(combat_stats) == TYPE_DICTIONARY:
		return combat_stats
	return {}


func _needs(context: Dictionary) -> Dictionary:
	var needs = context.get("needs", {})
	if typeof(needs) == TYPE_DICTIONARY:
		return needs
	return {}


func _hint(hints: Dictionary, hint_name: String) -> float:
	return clampf(float(hints.get(hint_name, 0.0)), 0.0, 1.0)


func _bias_hint(hints: Dictionary, hint_name: String) -> float:
	return clampf(float(hints.get(hint_name, 0.0)), -1.0, 1.0)


func _append_grounded_plan_items(result: Array, raw_plan, source := "") -> void:
	if typeof(raw_plan) != TYPE_ARRAY:
		return
	if result.size() >= 4:
		return
	var seen := {}
	for item in result:
		if typeof(item) == TYPE_DICTIONARY:
			seen[str(item.get("affordance_id", item.get("id", "")))] = true
	for item in raw_plan:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var affordance_id := str(item.get("affordance_id", item.get("id", "")))
		if affordance_id == "" or seen.has(affordance_id):
			continue
		var priority := clampf(float(item.get("priority", 0.0)), 0.0, 1.0)
		if priority <= 0.0:
			continue
		result.append({
			"affordance_id": affordance_id,
			"priority": priority,
			"reason": str(item.get("reason", "")),
			"source": source,
		})
		seen[affordance_id] = true
		if result.size() >= 4:
			break


func _can_fight_head_on(combat_stats: Dictionary, ari_hp_ratio: float, enemy_type_counts: Dictionary, active_enemy_count := 0) -> bool:
	if ari_hp_ratio < 0.42:
		return false
	if int(enemy_type_counts.get("flying", 0)) > 0:
		return false
	var runner_count := int(enemy_type_counts.get("runner", 0))
	var brute_count := int(enemy_type_counts.get("brute", 0))
	if runner_count >= 2 and ari_hp_ratio < 0.80:
		return false
	if runner_count > 0 and active_enemy_count >= 3 and ari_hp_ratio < 0.92:
		return false
	if brute_count > 0 and active_enemy_count >= 2 and ari_hp_ratio < 0.90:
		return false
	var combat_level := float(combat_stats.get("combat_level", 0.0))
	var sword_skill := float(combat_stats.get("sword_skill", 0.0))
	var attack_damage := float(combat_stats.get("attack_damage", 7.0))
	var armor := float(combat_stats.get("armor", 0.0))
	var enemy_pressure := maxf(float(active_enemy_count), 1.0)
	var readiness := combat_level * 0.45 + sword_skill * 0.75 + (attack_damage / 18.0) + armor * 2.0
	return readiness >= 1.15 + maxf(enemy_pressure - 1.0, 0.0) * 0.25


func _build_strength(run_build: Dictionary, category: String) -> float:
	return clampf(float(_build_points(run_build, category)) / 7.0, 0.0, 1.0)


func _build_points(run_build: Dictionary, category: String) -> int:
	var points = run_build.get("points", {})
	if typeof(points) == TYPE_DICTIONARY:
		return int(points.get(category, 0))
	return int(run_build.get(category, 0))


func _job(name: String, reason: String) -> Dictionary:
	return {
		"job": name,
		"reason": reason,
	}
