class_name AriController
extends Node2D

signal damaged(hp: float)
signal died
signal job_changed(job: String, reason: String)

@export var max_hp := 100.0
@export var radius := 16.0
@export var move_speed := 90.0
@export var mining_spot_offset := Vector2(48.0, 0.0)
@export var mining_arrive_distance := 4.0
@export var build_arrive_distance := 22.0
@export var training_arrive_distance := 6.0
@export var station_arrive_distance := 8.0
@export var max_hunger := 100.0
@export var max_stamina := 100.0
@export var max_fear := 100.0

var hp := 100.0
var hunger := 28.0
var stamina := 92.0
var fear := 18.0
var mining_enabled := false
var current_job := "wait_or_idle"
var job_reason := "Waiting"
var current_action := "idle"
var combat_level := 0.0
var accuracy_bonus := 0.0
var damage_bonus := 0.0
var defense_training := 0.0
var sword_skill := 0.0
var sword_tier := 0
var sword_tier_name := "Hands"
var sword_damage_bonus := 0.0
var armor := 0.0
var passive_regen := 0.0
var regen_on_kill := 0.0

var _mine_node: Node2D
var _resource_system: Node
var _training_dummy: Node2D
var _farm_plot: Node2D
var _bed_station: Node2D
var _library_station: Node2D
var _base_move_speed := 0.0
var _base_max_hp := 0.0
var _mining_speed_multiplier := 1.0
var _damage_taken_multiplier := 1.0
var _training_gain_multiplier := 1.0
var _defense_training_gain_multiplier := 1.0
var _farming_speed_multiplier := 1.0
var _rest_recovery_multiplier := 1.0
var _sword_strength := 0.0
var _attack_damage_bonus := 0.0
var _attack_speed_multiplier := 1.0
var _armor_bonus := 0.0
var _damage_flash := 0.0
var _action_pulse := 0.0


func _ready() -> void:
	_base_move_speed = move_speed
	_base_max_hp = max_hp


func reset_run() -> void:
	_ensure_base_move_speed()
	hp = max_hp
	hunger = 28.0
	stamina = 92.0
	fear = 18.0
	mining_enabled = false
	current_job = "wait_or_idle"
	job_reason = "Waiting"
	current_action = "idle"
	combat_level = 0.0
	accuracy_bonus = 0.0
	damage_bonus = 0.0
	defense_training = 0.0
	sword_skill = 0.0
	sword_tier = 0
	sword_tier_name = "Hands"
	sword_damage_bonus = 0.0
	armor = 0.0
	passive_regen = 0.0
	regen_on_kill = 0.0
	queue_redraw()


func setup_mining(mine_node: Node2D, resource_system: Node) -> void:
	_mine_node = mine_node
	_resource_system = resource_system


func setup_training(training_dummy: Node2D) -> void:
	_training_dummy = training_dummy


func setup_day_stations(farm_plot: Node2D, bed_station: Node2D, library_station: Node2D) -> void:
	_farm_plot = farm_plot
	_bed_station = bed_station
	_library_station = library_station


func apply_run_build_effects(effects: Dictionary) -> void:
	_ensure_base_move_speed()
	_ensure_base_max_hp()
	var previous_max_hp := max_hp
	max_hp = _base_max_hp + maxf(float(effects.get("max_hp_bonus", 0.0)), 0.0)
	if hp >= previous_max_hp - 0.1:
		hp = max_hp
	else:
		hp = minf(hp, max_hp)
	move_speed = _base_move_speed * clampf(float(effects.get("movement_speed_multiplier", 1.0)), 0.5, 2.0)
	_mining_speed_multiplier = clampf(float(effects.get("mining_speed_multiplier", 1.0)), 0.5, 2.5)
	_damage_taken_multiplier = clampf(float(effects.get("damage_taken_multiplier", 1.0)), 0.2, 1.5)
	_training_gain_multiplier = clampf(float(effects.get("training_gain_multiplier", 1.0)), 0.5, 2.0)
	_defense_training_gain_multiplier = clampf(float(effects.get("defense_training_gain_multiplier", 1.0)), 0.5, 2.0)
	_farming_speed_multiplier = clampf(float(effects.get("farming_speed_multiplier", 1.0)), 0.5, 2.5)
	_rest_recovery_multiplier = clampf(float(effects.get("rest_recovery_multiplier", 1.0)), 0.5, 2.5)
	_sword_strength = clampf(float(effects.get("sword_strength", 0.0)), 0.0, 1.0)
	_attack_damage_bonus = clampf(float(effects.get("attack_damage_bonus", 0.0)), 0.0, 1.5)
	_attack_speed_multiplier = clampf(float(effects.get("attack_speed_multiplier", 1.0)), 0.5, 2.4)
	_armor_bonus = clampf(float(effects.get("armor_bonus", 0.0)), 0.0, 0.55)
	passive_regen = clampf(float(effects.get("passive_regen_per_second", 0.0)), 0.0, 2.0)
	regen_on_kill = clampf(float(effects.get("regen_on_kill", 0.0)), 0.0, 18.0)
	_update_combat_derived_stats()


func _process(delta: float) -> void:
	if _damage_flash > 0.0:
		_damage_flash = maxf(0.0, _damage_flash - delta)
		queue_redraw()
	if not get_action_cue().is_empty():
		_action_pulse = fmod(_action_pulse + maxf(delta, 0.0), 1000.0)
		queue_redraw()


func advance_survival_needs(delta: float, phase: String) -> void:
	if not is_alive():
		return
	var safe_delta := maxf(delta, 0.0)
	var hunger_gain := 0.10
	if current_action.begins_with("moving"):
		hunger_gain += 0.035
	if current_action == "training combat" or current_action == "training sword" or current_action == "mining" or current_action == "mining ore" or current_action == "smithing" or current_action == "fighting head on":
		hunger_gain += 0.045
	hunger = minf(max_hunger, hunger + hunger_gain * safe_delta)

	if current_action.begins_with("moving") or current_action == "training combat" or current_action == "training sword" or current_action == "mining" or current_action == "mining ore" or current_action == "smithing" or current_action == "fighting head on":
		stamina = maxf(0.0, stamina - 0.18 * safe_delta)
	else:
		stamina = minf(max_stamina, stamina + 0.10 * safe_delta)

	match phase:
		"dusk":
			fear = minf(max_fear, fear + 0.18 * safe_delta)
		"night":
			fear = minf(max_fear, fear + 0.34 * safe_delta)
		_:
			fear = maxf(0.0, fear - 0.06 * safe_delta)

	if hunger >= max_hunger:
		take_damage(1.2 * safe_delta)


func set_mining_enabled(enabled: bool) -> void:
	mining_enabled = enabled
	if not mining_enabled:
		_stop_mining()
	queue_redraw()


func advance_daytime_behavior(delta: float, can_mine: bool) -> void:
	if not mining_enabled:
		return
	advance_mining_job(delta, can_mine, "Debug mining")


func advance_mining_job(delta: float, can_mine: bool, reason: String) -> void:
	_set_job("mine_stone", reason)
	if not is_alive():
		stop_daytime_job("Dead")
		return
	if not can_mine or _mine_node == null or _resource_system == null:
		stop_daytime_job("Cannot mine now")
		return

	var mining_spot := _mine_node.global_position + mining_spot_offset
	var to_spot := mining_spot - global_position
	if to_spot.length() > mining_arrive_distance:
		current_action = "moving to mine"
		_mine_node.call("set_active", false)
		global_position += to_spot.normalized() * minf(move_speed * delta, to_spot.length())
	else:
		current_action = "mining"
		_mine_node.call("mine", delta * _mining_speed_multiplier, _resource_system)
	queue_redraw()


func advance_training_job(delta: float, can_train: bool, reason: String) -> void:
	_set_job("train_combat", reason)
	if not is_alive():
		stop_daytime_job("Dead")
		return
	if not can_train or _training_dummy == null:
		stop_daytime_job("Cannot train now")
		return

	var training_spot: Vector2 = _training_dummy.call("get_training_spot")
	var to_spot := training_spot - global_position
	if to_spot.length() > training_arrive_distance:
		current_action = "moving to train"
		_training_dummy.call("set_active", false)
		global_position += to_spot.normalized() * minf(move_speed * delta, to_spot.length())
	else:
		current_action = "training combat"
		var completed_cycles := int(_training_dummy.call("train", delta * _training_gain_multiplier))
		for _i in range(completed_cycles):
			_apply_training_cycle()
	queue_redraw()


func advance_sword_training_job(delta: float, can_train: bool, reason: String) -> void:
	_set_job("train_sword", reason)
	if not is_alive():
		stop_daytime_job("Dead")
		return
	if not can_train or _training_dummy == null:
		stop_daytime_job("Cannot train sword now")
		return

	var training_spot: Vector2 = _training_dummy.call("get_training_spot")
	var to_spot := training_spot - global_position
	if to_spot.length() > training_arrive_distance:
		current_action = "moving to sword training"
		_training_dummy.call("set_active", false)
		global_position += to_spot.normalized() * minf(move_speed * delta, to_spot.length())
	else:
		current_action = "training sword"
		var completed_cycles := int(_training_dummy.call("train", delta * _training_gain_multiplier * (1.0 + _sword_strength * 0.30)))
		for _i in range(completed_cycles):
			_apply_sword_training_cycle()
	queue_redraw()


func advance_farming_job(delta: float, can_farm: bool, reason: String) -> int:
	_set_job("farm_food", reason)
	if not is_alive():
		stop_daytime_job("Dead")
		return 0
	if not can_farm or _farm_plot == null or _resource_system == null:
		stop_daytime_job("Cannot farm now")
		return 0

	var farm_spot: Vector2 = _farm_plot.call("get_work_spot")
	var to_spot := farm_spot - global_position
	if to_spot.length() > station_arrive_distance:
		current_action = "moving to farm"
		_farm_plot.call("set_active", false)
		global_position += to_spot.normalized() * minf(move_speed * delta, to_spot.length())
		queue_redraw()
		return 0

	current_action = "farming"
	var produced := int(_farm_plot.call("farm", delta * _farming_speed_multiplier, _resource_system))
	queue_redraw()
	return produced


func advance_rest_job(delta: float, can_rest: bool, reason: String) -> void:
	_set_job("rest", reason)
	if not is_alive():
		stop_daytime_job("Dead")
		return
	if not can_rest or _bed_station == null:
		stop_daytime_job("Cannot rest now")
		return

	var rest_spot: Vector2 = _bed_station.call("get_rest_spot")
	var to_spot := rest_spot - global_position
	if to_spot.length() > station_arrive_distance:
		current_action = "moving to bed"
		_bed_station.call("set_active", false)
		global_position += to_spot.normalized() * minf(move_speed * delta, to_spot.length())
	else:
		current_action = "resting"
		_bed_station.call("rest", delta * _rest_recovery_multiplier, self)
	queue_redraw()


func advance_reflection_job(delta: float, can_reflect: bool, reason: String) -> int:
	_set_job("reflect_library", reason)
	if not is_alive():
		stop_daytime_job("Dead")
		return 0
	if not can_reflect or _library_station == null:
		stop_daytime_job("Cannot reflect now")
		return 0

	var reflection_spot: Vector2 = _library_station.call("get_reflection_spot")
	var to_spot := reflection_spot - global_position
	if to_spot.length() > station_arrive_distance:
		current_action = "moving to library"
		_library_station.call("set_active", false)
		global_position += to_spot.normalized() * minf(move_speed * delta, to_spot.length())
		queue_redraw()
		return 0

	current_action = "reflecting"
	var completed := int(_library_station.call("reflect", delta))
	queue_redraw()
	return completed


func advance_move_job(delta: float, job: String, reason: String, target_position: Vector2, arrived_action: String) -> bool:
	_set_job(job, reason)
	if not is_alive():
		stop_daytime_job("Dead")
		return false

	var to_target := target_position - global_position
	if to_target.length() > build_arrive_distance:
		current_action = _moving_action_for_job(job)
		global_position += to_target.normalized() * minf(move_speed * delta, to_target.length())
		queue_redraw()
		return false

	current_action = arrived_action
	queue_redraw()
	return true


func wait_near(delta: float, target_position: Vector2, reason: String) -> void:
	if advance_move_job(delta, "wait_or_idle", reason, target_position, "waiting near defenses"):
		current_action = "waiting near defenses"


func stop_daytime_job(reason := "Waiting") -> void:
	_set_job("wait_or_idle", reason)
	_stop_mining()
	queue_redraw()


func mark_eating_food(reason := "Eating food") -> void:
	_set_job("eat_food", reason)
	_stop_mining()
	current_action = "eating food"
	queue_redraw()


func get_current_action() -> String:
	return current_action


func get_action_cue() -> Dictionary:
	var action := current_action.to_lower()
	if action == "" or action == "idle":
		return {}
	var phase := "moving" if action.begins_with("moving") else "active"
	if action.find("mine") >= 0:
		return _make_action_cue("mine", phase, Color(0.86, 0.82, 0.68, 1.0))
	if action.find("train") >= 0 or action.find("combat") >= 0:
		return _make_action_cue("train", phase, Color(1.0, 0.68, 0.28, 1.0))
	if action.find("sword") >= 0 or action.find("fighting") >= 0:
		return _make_action_cue("sword", phase, Color(1.0, 0.48, 0.24, 1.0))
	if action.find("farm") >= 0:
		return _make_action_cue("farm", phase, Color(0.48, 0.88, 0.36, 1.0))
	if action.find("eat") >= 0 or action.find("food") >= 0:
		return _make_action_cue("food", phase, Color(0.48, 0.88, 0.36, 1.0))
	if action.find("bed") >= 0 or action.find("rest") >= 0:
		return _make_action_cue("rest", phase, Color(0.95, 0.82, 0.42, 1.0))
	if action.find("library") >= 0 or action.find("reflect") >= 0:
		return _make_action_cue("reflect", phase, Color(0.74, 0.66, 1.0, 1.0))
	if action.find("repair") >= 0:
		return _make_action_cue("repair", phase, Color(0.48, 0.88, 1.0, 1.0))
	if action.find("flee") >= 0:
		return _make_action_cue("flee", phase, Color(1.0, 0.46, 0.34, 1.0))
	if action.find("tower") >= 0 or action.find("range") >= 0 or action.find("shoot") >= 0:
		return _make_action_cue("range", phase, Color(1.0, 0.78, 0.30, 1.0))
	if action.find("cover") >= 0 or action.find("lure") >= 0 or action.find("aura") >= 0:
		return _make_action_cue("wait", phase, Color(0.70, 0.88, 1.0, 1.0))
	if (
		action.find("build") >= 0
		or action.find("wall") >= 0
		or action.find("placing") >= 0
		or action.find("setting") >= 0
		or action.find("digging") >= 0
		or action.find("lighting") >= 0
		or action.find("raising") >= 0
	):
		return _make_action_cue("build", phase, Color(0.78, 0.70, 0.50, 1.0))
	if action.find("wait") >= 0:
		return _make_action_cue("wait", phase, Color(0.70, 0.82, 0.95, 1.0))
	return {}


func get_current_job() -> String:
	return current_job


func get_job_reason() -> String:
	return job_reason


func take_damage(amount: float) -> void:
	if not is_alive():
		return
	var trained_defense_multiplier := maxf(0.55, 1.0 - defense_training)
	var armor_multiplier := maxf(0.42, 1.0 - armor)
	hp = maxf(0.0, hp - maxf(amount, 0.0) * _damage_taken_multiplier * trained_defense_multiplier * armor_multiplier)
	fear = minf(max_fear, fear + 8.0)
	_damage_flash = 0.18
	damaged.emit(hp)
	if hp <= 0.0:
		died.emit()
	queue_redraw()


func is_alive() -> bool:
	return hp > 0.0


func get_combat_stats() -> Dictionary:
	_update_combat_derived_stats()
	return {
		"combat_level": combat_level,
		"accuracy_bonus": accuracy_bonus,
		"damage_bonus": damage_bonus,
		"defense_training": defense_training,
		"sword_skill": sword_skill,
		"sword_tier": sword_tier,
		"sword_tier_name": sword_tier_name,
		"attack_damage": get_melee_damage(),
		"attack_speed": get_attack_speed(),
		"armor": armor,
		"passive_regen": passive_regen,
		"regen_on_kill": regen_on_kill,
	}


func get_needs() -> Dictionary:
	return {
		"hunger": hunger,
		"max_hunger": max_hunger,
		"stamina": stamina,
		"max_stamina": max_stamina,
		"fear": fear,
		"max_fear": max_fear,
	}


func restore_from_food(food_power := 28.0) -> void:
	hunger = maxf(0.0, hunger - maxf(float(food_power), 0.0))
	stamina = minf(max_stamina, stamina + 10.0)
	fear = maxf(0.0, fear - 5.0)
	queue_redraw()


func restore_from_rest(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	hp = minf(max_hp, hp + 1.8 * safe_delta)
	stamina = minf(max_stamina, stamina + 2.6 * safe_delta)
	fear = maxf(0.0, fear - 1.8 * safe_delta)
	hunger = maxf(0.0, hunger - 0.04 * safe_delta)
	queue_redraw()


func apply_passive_regen(delta: float) -> float:
	if not is_alive() or passive_regen <= 0.0 or hp >= max_hp:
		return 0.0
	var healed := minf(max_hp - hp, passive_regen * maxf(delta, 0.0))
	hp += healed
	if healed > 0.0:
		queue_redraw()
	return healed


func restore_from_kill() -> float:
	if not is_alive() or regen_on_kill <= 0.0:
		return 0.0
	var healed := minf(max_hp - hp, regen_on_kill)
	hp += healed
	fear = maxf(0.0, fear - minf(regen_on_kill * 0.20, 4.0))
	if healed > 0.0:
		queue_redraw()
	return healed


func set_sword_tier(next_tier: int, display_name: String, damage_bonus: float, armor_bonus := 0.0) -> void:
	sword_tier = maxi(next_tier, 0)
	sword_tier_name = display_name.strip_edges() if display_name.strip_edges() != "" else "Sword"
	sword_damage_bonus = maxf(damage_bonus, 0.0)
	_armor_bonus = maxf(_armor_bonus, maxf(armor_bonus, 0.0))
	_update_combat_derived_stats()
	queue_redraw()


func get_melee_damage() -> float:
	return maxf(1.0, 7.0 + sword_damage_bonus + sword_skill * 2.4 + combat_level * 1.2 + _attack_damage_bonus * 10.0 + _sword_strength * 3.0)


func get_attack_speed() -> float:
	return clampf(_attack_speed_multiplier * (1.0 + sword_skill * 0.035), 0.4, 3.0)


func get_melee_cooldown() -> float:
	return clampf(0.88 / get_attack_speed(), 0.22, 1.4)


func soothe_fear(amount: float) -> void:
	fear = maxf(0.0, fear - maxf(amount, 0.0))
	queue_redraw()


func _stop_mining() -> void:
	current_action = "idle"
	if is_instance_valid(_mine_node):
		_mine_node.call("set_active", false)
	if is_instance_valid(_training_dummy):
		_training_dummy.call("set_active", false)
	if is_instance_valid(_farm_plot):
		_farm_plot.call("set_active", false)
	if is_instance_valid(_bed_station):
		_bed_station.call("set_active", false)
	if is_instance_valid(_library_station):
		_library_station.call("set_active", false)


func _ensure_base_move_speed() -> void:
	if _base_move_speed <= 0.0:
		_base_move_speed = move_speed


func _ensure_base_max_hp() -> void:
	if _base_max_hp <= 0.0:
		_base_max_hp = max_hp


func _set_job(job: String, reason: String) -> void:
	if current_job == job and job_reason == reason:
		return
	current_job = job
	job_reason = reason
	job_changed.emit(current_job, job_reason)


func _apply_training_cycle() -> void:
	combat_level = clampf(combat_level + 0.14, 0.0, 5.0)
	accuracy_bonus = clampf(accuracy_bonus + 0.010, 0.0, 0.30)
	damage_bonus = clampf(damage_bonus + 0.014, 0.0, 0.40)
	defense_training = clampf(defense_training + 0.014 * _defense_training_gain_multiplier, 0.0, 0.35)
	_update_combat_derived_stats()


func _apply_sword_training_cycle() -> void:
	combat_level = clampf(combat_level + 0.08, 0.0, 5.0)
	sword_skill = clampf(sword_skill + 0.16 + _sword_strength * 0.04, 0.0, 5.0)
	damage_bonus = clampf(damage_bonus + 0.010, 0.0, 0.40)
	defense_training = clampf(defense_training + 0.006 * _defense_training_gain_multiplier, 0.0, 0.35)
	_update_combat_derived_stats()


func _update_combat_derived_stats() -> void:
	armor = clampf(defense_training * 0.35 + _armor_bonus, 0.0, 0.65)


func _make_action_cue(kind: String, phase: String, color: Color) -> Dictionary:
	return {
		"kind": kind,
		"phase": phase,
		"color": color,
	}


func _moving_action_for_job(job: String) -> String:
	match job:
		"use_cover":
			return "moving to wall cover"
		"lure_to_aura":
			return "moving to aura lure"
		"use_tower":
			return "moving to tower"
		"flee":
			return "fleeing"
	return "moving to %s" % job


func _draw() -> void:
	var body_color := Color(0.10, 0.42, 1.0, 1.0) if is_alive() else Color(0.22, 0.25, 0.30, 1.0)
	var outline_color := Color(0.78, 0.94, 1.0, 1.0) if is_alive() else Color(0.80, 0.86, 0.92, 1.0)
	if _damage_flash > 0.0:
		body_color = Color(1.0, 0.72, 0.46, 1.0)
		outline_color = Color(1.0, 0.96, 0.72, 1.0)
	draw_circle(Vector2(3.0, 7.0), radius + 7.0, Color(0.0, 0.0, 0.0, 0.34))
	_draw_need_state_cues()
	draw_circle(Vector2.ZERO, radius + 5.0, Color(0.02, 0.04, 0.08, 0.96))
	draw_arc(Vector2.ZERO, radius + 7.0, 0.0, TAU, 42, Color(0.48, 0.84, 1.0, 0.40), 2.0)
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_circle(Vector2(5.0, -5.0), 3.4, Color(0.92, 0.99, 1.0, 1.0))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, outline_color, 3.0)
	if armor > 0.03:
		draw_arc(Vector2.ZERO, radius + 10.0, -PI * 0.25, PI * 1.25, 32, Color(0.78, 0.86, 0.88, 0.24 + armor * 0.55), 2.4)
	if sword_tier > 0:
		draw_line(Vector2(radius * 0.45, radius * 0.50), Vector2(radius + 8.0, -radius * 0.40), Color(0.94, 0.80, 0.56, 0.86), 2.1)
	if _damage_flash > 0.0:
		draw_arc(Vector2.ZERO, radius + 10.0, -PI * 0.20, PI * 1.20, 32, Color(1.0, 0.44, 0.28, 0.72), 3.0)
	if not is_alive():
		draw_line(Vector2(-9.0, -9.0), Vector2(9.0, 9.0), Color(0.96, 0.98, 1.0, 0.95), 3.0)
		draw_line(Vector2(9.0, -9.0), Vector2(-9.0, 9.0), Color(0.96, 0.98, 1.0, 0.95), 3.0)
	_draw_action_cue(get_action_cue())


func _draw_action_cue(cue: Dictionary) -> void:
	if cue.is_empty() or not is_alive():
		return
	var kind := str(cue.get("kind", ""))
	var phase := str(cue.get("phase", "active"))
	var color_value = cue.get("color", Color(0.86, 0.86, 0.74, 1.0))
	var color: Color = color_value if typeof(color_value) == TYPE_COLOR else Color(0.86, 0.86, 0.74, 1.0)
	var center := Vector2(radius + 20.0, -radius - 11.0)
	var pulse := 0.5 + sin(_action_pulse * 5.5) * 0.5
	if phase == "moving":
		_draw_moving_action_link(center, color, pulse)
	else:
		draw_circle(center, 12.0 + pulse * 1.4, Color(color.r, color.g, color.b, 0.15))
	draw_circle(center, 9.5, Color(0.06, 0.08, 0.08, 0.86))
	draw_arc(center, 9.5, 0.0, TAU, 26, Color(color.r, color.g, color.b, 0.78), 1.5)
	_draw_action_symbol(kind, center, color)


func _draw_moving_action_link(center: Vector2, color: Color, pulse: float) -> void:
	var start := Vector2(radius * 0.70, -radius * 0.35)
	var direction := (center - start).normalized()
	var side := Vector2(-direction.y, direction.x)
	draw_line(start, center - direction * 11.0, Color(color.r, color.g, color.b, 0.40), 1.5)
	for i in range(3):
		var t := float(i + 1) / 4.0
		var dot := start.lerp(center - direction * 13.0, t) + side * sin((_action_pulse * 4.0) + float(i)) * 1.5
		draw_circle(dot, 2.0 + pulse * 0.6, Color(color.r, color.g, color.b, 0.42 + pulse * 0.18))
	draw_colored_polygon(PackedVector2Array([
		center - direction * 6.0,
		center - direction * 13.0 + side * 4.0,
		center - direction * 13.0 - side * 4.0,
	]), Color(color.r, color.g, color.b, 0.72))


func _draw_action_symbol(kind: String, center: Vector2, color: Color) -> void:
	var bright := color.lightened(0.20)
	match kind:
		"mine":
			draw_line(center + Vector2(-5.0, 4.0), center + Vector2(5.0, -6.0), bright, 2.2)
			draw_line(center + Vector2(-6.0, -5.0), center + Vector2(4.0, -7.0), color, 1.8)
			draw_circle(center + Vector2(5.0, 4.0), 1.5, bright)
		"train":
			draw_line(center + Vector2(-6.0, 5.0), center + Vector2(6.0, -5.0), bright, 2.2)
			draw_line(center + Vector2(-5.0, -4.0), center + Vector2(5.0, 5.0), color, 2.0)
		"farm":
			draw_line(center + Vector2(0.0, 6.0), center + Vector2(0.0, -4.0), bright, 1.8)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -3.0),
				center + Vector2(-6.0, -6.0),
				center + Vector2(-4.0, 2.0),
			]), color)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(1.0, -3.0),
				center + Vector2(6.0, -6.0),
				center + Vector2(4.0, 2.0),
			]), bright)
		"rest":
			draw_arc(center, 5.8, PI * 0.35, PI * 1.45, 16, bright, 2.0)
			draw_circle(center + Vector2(5.0, -5.0), 1.5, color)
		"reflect":
			draw_rect(Rect2(center + Vector2(-5.0, -6.0), Vector2(10.0, 12.0)), Color(color.r, color.g, color.b, 0.58), true)
			draw_line(center + Vector2(0.0, -6.0), center + Vector2(0.0, 6.0), bright, 1.1)
			draw_line(center + Vector2(-3.0, -2.0), center + Vector2(-1.0, -2.0), bright, 1.0)
			draw_line(center + Vector2(2.0, 1.0), center + Vector2(4.0, 1.0), bright, 1.0)
		"repair":
			draw_line(center + Vector2(-5.0, 5.0), center + Vector2(5.0, -5.0), bright, 2.0)
			draw_line(center + Vector2(2.0, -7.0), center + Vector2(7.0, -2.0), color, 1.6)
			draw_circle(center + Vector2(-5.0, 5.0), 2.0, Color(color.r, color.g, color.b, 0.64))
		"range":
			draw_arc(center + Vector2(-1.0, 0.0), 7.0, -0.8, 0.8, 16, bright, 2.0)
			draw_line(center + Vector2(-7.0, 0.0), center + Vector2(7.0, 0.0), bright, 2.0)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(7.0, -4.0),
				center + Vector2(13.0, 0.0),
				center + Vector2(7.0, 4.0),
			]), color)
		"sword":
			draw_line(center + Vector2(-6.0, 6.0), center + Vector2(7.0, -7.0), bright, 2.4)
			draw_line(center + Vector2(-7.0, 2.0), center + Vector2(-2.0, 7.0), color, 2.0)
			draw_circle(center + Vector2(7.0, -7.0), 1.6, bright)
		"wait":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -7.0),
				center + Vector2(6.0, -3.0),
				center + Vector2(4.0, 5.0),
				center + Vector2(0.0, 7.0),
				center + Vector2(-4.0, 5.0),
				center + Vector2(-6.0, -3.0),
			]), Color(color.r, color.g, color.b, 0.56))
			draw_line(center + Vector2(0.0, -5.0), center + Vector2(0.0, 5.0), bright, 1.3)
		_:
			draw_rect(Rect2(center + Vector2(-5.0, -5.0), Vector2(10.0, 10.0)), Color(color.r, color.g, color.b, 0.52), true)
			draw_line(center + Vector2(-6.0, 4.0), center + Vector2(4.0, -6.0), bright, 2.0)


func _draw_need_state_cues() -> void:
	if not is_alive():
		return
	var hunger_ratio := _safe_ratio(hunger, max_hunger)
	var stamina_ratio := _safe_ratio(stamina, max_stamina)
	var fear_ratio := _safe_ratio(fear, max_fear)
	if hunger_ratio <= 0.34 and stamina_ratio >= 0.64 and fear_ratio <= 0.34:
		_draw_calm_cue()
		return
	if hunger_ratio > 0.34:
		_draw_need_chip(Vector2(-24.0, 18.0), Color(0.95, 0.56, 0.24, 1.0), hunger_ratio, "hunger")
	if stamina_ratio < 0.64:
		_draw_need_chip(Vector2(0.0, 24.0), Color(0.42, 0.88, 0.66, 1.0), stamina_ratio, "stamina")
	if fear_ratio > 0.34:
		_draw_fear_cue(fear_ratio)


func _draw_need_chip(center: Vector2, color: Color, ratio: float, kind: String) -> void:
	var fill := clampf(ratio if kind == "hunger" else 1.0 - ratio, 0.0, 1.0)
	draw_circle(center, 7.0, Color(color.r, color.g, color.b, 0.22 + fill * 0.28))
	draw_arc(center, 7.0, -PI * 0.50, -PI * 0.50 + TAU * fill, 18, color.lightened(0.18), 2.0)
	match kind:
		"hunger":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-3.0, -2.0),
				center + Vector2(3.0, -2.0),
				center + Vector2(0.0, 4.0),
			]), color.lightened(0.18))
		"stamina":
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(1.0, -5.0),
				center + Vector2(-4.0, 1.0),
				center + Vector2(0.0, 1.0),
				center + Vector2(-2.0, 6.0),
				center + Vector2(5.0, -1.0),
				center + Vector2(1.0, -1.0),
			]), color.lightened(0.20))


func _draw_fear_cue(fear_ratio: float) -> void:
	var intensity := clampf((fear_ratio - 0.34) / 0.66, 0.0, 1.0)
	var color := Color(0.72, 0.40, 0.95, 0.34 + intensity * 0.38)
	draw_arc(Vector2.ZERO, radius + 6.0, -PI * 0.85, PI * 0.85, 28, color, 2.2)
	draw_line(Vector2(-11.0, -radius - 8.0), Vector2(-7.0, -radius - 3.0), color.lightened(0.16), 1.4)
	draw_line(Vector2(10.0, -radius - 8.0), Vector2(6.0, -radius - 3.0), color.lightened(0.16), 1.4)


func _draw_calm_cue() -> void:
	draw_arc(Vector2.ZERO, radius + 4.0, PI * 0.15, PI * 0.85, 12, Color(0.55, 0.86, 1.0, 0.32), 1.5)


func _safe_ratio(value: float, max_value: float) -> float:
	if max_value <= 0.0:
		return 1.0
	return clampf(value / max_value, 0.0, 1.0)
