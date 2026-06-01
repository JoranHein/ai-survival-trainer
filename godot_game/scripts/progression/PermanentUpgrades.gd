class_name PermanentUpgrades
extends Node

signal changed(state: Dictionary)

@export var data_path := "res://data/permanent_upgrades.json"
@export var save_path := "user://permanent_upgrades.json"
@export var seconds_per_time_point := 18.0

var time_points := 0
var upgrades := {}
var deaths := 0
var best_day := 1

var _survival_seconds := 0.0
var _upgrade_order: Array = []
var _upgrade_defs := {}


func _init() -> void:
	_load_definitions()
	_reset_upgrades_if_needed()


func _ready() -> void:
	load_now()
	changed.emit(get_state())


func reset_run() -> void:
	_survival_seconds = 0.0
	changed.emit(get_state())


func advance_survival(delta: float, is_night: bool, ari_alive: bool) -> void:
	if not ari_alive:
		return
	var weight := 1.35 if is_night else 0.45
	_survival_seconds += maxf(delta, 0.0) * weight
	if _survival_seconds < seconds_per_time_point:
		return
	var earned := int(floor(_survival_seconds / seconds_per_time_point))
	_survival_seconds -= float(earned) * seconds_per_time_point
	grant_time_points(earned)


func award_death_reward(day: int) -> int:
	deaths += 1
	best_day = maxi(best_day, day)
	var earned := maxi(1, day)
	grant_time_points(earned)
	return earned


func grant_time_points(amount: int) -> void:
	var safe_amount := maxi(amount, 0)
	if safe_amount <= 0:
		return
	time_points += safe_amount
	save_now()
	changed.emit(get_state())


func buy_upgrade_key(key_number: int) -> bool:
	var index := key_number - 1
	if key_number == 0:
		index = 9
	if index < 0 or index >= _upgrade_order.size():
		return false
	return buy_upgrade(str(_upgrade_order[index]))


func buy_upgrade(upgrade_id: String) -> bool:
	if not _upgrade_defs.has(upgrade_id):
		return false
	var level := get_upgrade_level(upgrade_id)
	var max_level := int(_definition(upgrade_id).get("max_level", 6))
	if level >= max_level:
		return false
	var cost := get_upgrade_cost(upgrade_id)
	if time_points < cost:
		return false
	time_points -= cost
	upgrades[upgrade_id] = level + 1
	save_now()
	changed.emit(get_state())
	return true


func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))


func get_upgrade_cost(upgrade_id: String) -> int:
	if not _upgrade_defs.has(upgrade_id):
		return 999
	var level := get_upgrade_level(upgrade_id)
	var definition := _definition(upgrade_id)
	var max_level := int(definition.get("max_level", 6))
	if level >= max_level:
		return 0
	return int(definition.get("base_cost", 3)) + level * int(definition.get("cost_step", 2))


func get_effects() -> Dictionary:
	var movement_multiplier := 1.0 + get_upgrade_level("movement_speed_small") * _effect("movement_speed_small")
	movement_multiplier = minf(movement_multiplier, float(_definition("movement_speed_small").get("max_multiplier", 1.10)))
	var farming_bonus := get_upgrade_level("farming_yield") * _effect("farming_yield")
	return {
		"max_hp_bonus": get_upgrade_level("max_hp") * _effect("max_hp"),
		"base_damage_multiplier": 1.0 + get_upgrade_level("base_damage") * _effect("base_damage"),
		"damage_taken_multiplier": maxf(0.80, 1.0 - get_upgrade_level("defense") * _effect("defense")),
		"mining_speed_multiplier": 1.0 + get_upgrade_level("mining_efficiency") * _effect("mining_efficiency"),
		"stone_cost_multiplier": maxf(0.78, 1.0 - get_upgrade_level("building_efficiency") * _effect("building_efficiency")),
		"farming_yield_multiplier": 1.0 + farming_bonus,
		"farming_speed_multiplier": 1.0 + farming_bonus * 0.35,
		"aura_damage_multiplier": 1.0 + get_upgrade_level("warding_power") * _effect("warding_power"),
		"rest_recovery_multiplier": 1.0 + get_upgrade_level("regeneration") * _effect("regeneration"),
		"movement_speed_multiplier": movement_multiplier,
		"sign_strength_bonus": get_upgrade_level("sign_understanding") * _effect("sign_understanding"),
		"sign_resonance_bonus": get_upgrade_level("sign_understanding") * _effect("sign_understanding") * 0.70,
	}


func get_state() -> Dictionary:
	return {
		"time_points": time_points,
		"deaths": deaths,
		"best_day": best_day,
		"upgrades": upgrades.duplicate(true),
		"upgrade_rows": _upgrade_rows(),
		"permanent_summary": _summary(),
	}


func save_now() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write permanent upgrades save: %s" % save_path)
		return
	file.store_string(JSON.stringify({
		"time_points": time_points,
		"deaths": deaths,
		"best_day": best_day,
		"upgrades": upgrades,
	}, "\t"))


func load_now() -> void:
	_load_definitions()
	_reset_upgrades_if_needed()
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("Could not read permanent upgrades save: %s" % save_path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Permanent upgrades save is not a dictionary.")
		return
	time_points = maxi(int(parsed.get("time_points", 0)), 0)
	deaths = maxi(int(parsed.get("deaths", 0)), 0)
	best_day = maxi(int(parsed.get("best_day", 1)), 1)
	var loaded_upgrades = parsed.get("upgrades", {})
	if typeof(loaded_upgrades) == TYPE_DICTIONARY:
		for upgrade_id in _upgrade_order:
			var id := str(upgrade_id)
			var max_level := int(_definition(id).get("max_level", 6))
			upgrades[id] = clampi(int(loaded_upgrades.get(id, 0)), 0, max_level)


func _load_definitions() -> void:
	_upgrade_order = []
	_upgrade_defs = {}
	var parsed = {}
	if FileAccess.file_exists(data_path):
		var file := FileAccess.open(data_path, FileAccess.READ)
		if file != null:
			parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		var order = parsed.get("upgrade_order", [])
		if typeof(order) == TYPE_ARRAY:
			for item in order:
				_upgrade_order.append(str(item))
		var defs = parsed.get("upgrades", {})
		if typeof(defs) == TYPE_DICTIONARY:
			for key in defs.keys():
				if typeof(defs[key]) == TYPE_DICTIONARY:
					_upgrade_defs[str(key)] = defs[key].duplicate(true)
	if _upgrade_order.is_empty() or _upgrade_defs.is_empty():
		_load_fallback_definitions()


func _load_fallback_definitions() -> void:
	_upgrade_order = [
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
	]
	_upgrade_defs = {}
	for upgrade_id in _upgrade_order:
		_upgrade_defs[str(upgrade_id)] = {
			"label": str(upgrade_id).replace("_", " ").capitalize(),
			"role": "General",
			"tags": ["run", "small"],
			"base_cost": 3,
			"cost_step": 2,
			"max_level": 6,
			"effect_per_level": 0.04,
		}


func _reset_upgrades_if_needed() -> void:
	for upgrade_id in _upgrade_order:
		var id := str(upgrade_id)
		if not upgrades.has(id):
			upgrades[id] = 0


func _upgrade_rows() -> Array:
	var rows := []
	for i in range(_upgrade_order.size()):
		var upgrade_id := str(_upgrade_order[i])
		var definition := _definition(upgrade_id)
		var level := get_upgrade_level(upgrade_id)
		var max_level := int(definition.get("max_level", 6))
		rows.append({
			"id": upgrade_id,
			"key": "0" if i == 9 else str(i + 1),
			"label": str(definition.get("label", upgrade_id)),
			"role": str(definition.get("role", "General")),
			"tags": _string_array(definition.get("tags", []), 3, 14),
			"level": level,
			"max_level": max_level,
			"cost": get_upgrade_cost(upgrade_id),
			"can_buy": level < max_level and time_points >= get_upgrade_cost(upgrade_id),
		})
	return rows


func _summary() -> String:
	var strongest := []
	for upgrade_id in _upgrade_order:
		var id := str(upgrade_id)
		var level := get_upgrade_level(id)
		if level > 0:
			strongest.append("%s %d" % [str(_definition(id).get("label", id)), level])
	if strongest.is_empty():
		return "No permanent upgrades yet"
	var shown := PackedStringArray()
	for i in range(mini(3, strongest.size())):
		shown.append(str(strongest[i]))
	return ", ".join(shown)


func _definition(upgrade_id: String) -> Dictionary:
	var definition = _upgrade_defs.get(upgrade_id, {})
	if typeof(definition) == TYPE_DICTIONARY:
		return definition
	return {}


func _effect(upgrade_id: String) -> float:
	return float(_definition(upgrade_id).get("effect_per_level", 0.0))


func _string_array(value, max_count: int, max_length: int) -> Array:
	var result := []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		if result.size() >= max_count:
			break
		var text := str(item).strip_edges()
		if text.length() > max_length:
			text = text.substr(0, max_length)
		if text != "":
			result.append(text)
	return result
