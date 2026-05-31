class_name PermanentProgression
extends Node

signal changed(state: Dictionary)

@export var save_path := "user://ai_survival_trainer_permanent.json"
@export var seconds_per_time_point := 18.0

const UPGRADE_ORDER := [
	"max_hp",
	"attack",
	"defense",
	"mining_efficiency",
	"building_efficiency",
	"farming_yield",
	"warding_power",
	"trapcraft",
	"regeneration",
	"sign_understanding",
]

const UPGRADE_DEFS := {
	"max_hp": {"label": "Max HP", "base_cost": 3, "cost_step": 2, "max_level": 6},
	"attack": {"label": "Attack", "base_cost": 3, "cost_step": 2, "max_level": 6},
	"defense": {"label": "Defense", "base_cost": 3, "cost_step": 2, "max_level": 6},
	"mining_efficiency": {"label": "Mining", "base_cost": 2, "cost_step": 2, "max_level": 6},
	"building_efficiency": {"label": "Building", "base_cost": 3, "cost_step": 2, "max_level": 6},
	"farming_yield": {"label": "Farming", "base_cost": 2, "cost_step": 2, "max_level": 6},
	"warding_power": {"label": "Warding", "base_cost": 3, "cost_step": 2, "max_level": 6},
	"trapcraft": {"label": "Trapcraft", "base_cost": 3, "cost_step": 2, "max_level": 6},
	"regeneration": {"label": "Recovery", "base_cost": 3, "cost_step": 2, "max_level": 6},
	"sign_understanding": {"label": "Sign Sense", "base_cost": 4, "cost_step": 3, "max_level": 6},
}

var time_points := 0
var upgrades := {}
var deaths := 0
var best_day := 1

var _survival_seconds := 0.0


func _ready() -> void:
	_reset_upgrades_if_needed()
	_load()
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
	time_points += earned
	_save()
	changed.emit(get_state())


func award_death_reward(day: int) -> int:
	deaths += 1
	best_day = maxi(best_day, day)
	var earned := maxi(1, day)
	time_points += earned
	_save()
	changed.emit(get_state())
	return earned


func buy_upgrade_key(key_number: int) -> bool:
	var index := key_number - 1
	if key_number == 0:
		index = 9
	if index < 0 or index >= UPGRADE_ORDER.size():
		return false
	return buy_upgrade(str(UPGRADE_ORDER[index]))


func buy_upgrade(upgrade_id: String) -> bool:
	if not UPGRADE_DEFS.has(upgrade_id):
		return false
	var level := get_upgrade_level(upgrade_id)
	var max_level := int(UPGRADE_DEFS[upgrade_id].get("max_level", 6))
	if level >= max_level:
		return false
	var cost := get_upgrade_cost(upgrade_id)
	if time_points < cost:
		return false
	time_points -= cost
	upgrades[upgrade_id] = level + 1
	_save()
	changed.emit(get_state())
	return true


func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrades.get(upgrade_id, 0))


func get_upgrade_cost(upgrade_id: String) -> int:
	if not UPGRADE_DEFS.has(upgrade_id):
		return 999
	var level := get_upgrade_level(upgrade_id)
	var max_level := int(UPGRADE_DEFS[upgrade_id].get("max_level", 6))
	if level >= max_level:
		return 0
	return int(UPGRADE_DEFS[upgrade_id].get("base_cost", 3)) + level * int(UPGRADE_DEFS[upgrade_id].get("cost_step", 2))


func get_effects() -> Dictionary:
	return {
		"max_hp_bonus": get_upgrade_level("max_hp") * 8.0,
		"base_damage_multiplier": 1.0 + get_upgrade_level("attack") * 0.04,
		"damage_taken_multiplier": maxf(0.80, 1.0 - get_upgrade_level("defense") * 0.025),
		"mining_speed_multiplier": 1.0 + get_upgrade_level("mining_efficiency") * 0.045,
		"stone_cost_multiplier": maxf(0.78, 1.0 - get_upgrade_level("building_efficiency") * 0.025),
		"farming_speed_multiplier": 1.0 + get_upgrade_level("farming_yield") * 0.050,
		"aura_damage_multiplier": 1.0 + get_upgrade_level("warding_power") * 0.045,
		"trapcraft_strength": get_upgrade_level("trapcraft") * 0.055,
		"rest_recovery_multiplier": 1.0 + get_upgrade_level("regeneration") * 0.055,
		"sign_strength_bonus": get_upgrade_level("sign_understanding") * 0.035,
		"sign_resonance_bonus": get_upgrade_level("sign_understanding") * 0.025,
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


func _upgrade_rows() -> Array:
	var rows := []
	for i in range(UPGRADE_ORDER.size()):
		var upgrade_id := str(UPGRADE_ORDER[i])
		var definition: Dictionary = UPGRADE_DEFS[upgrade_id]
		var level := get_upgrade_level(upgrade_id)
		var max_level := int(definition.get("max_level", 6))
		rows.append({
			"id": upgrade_id,
			"key": "0" if i == 9 else str(i + 1),
			"label": str(definition.get("label", upgrade_id)),
			"role": _upgrade_role(upgrade_id),
			"tags": _upgrade_tags(upgrade_id),
			"level": level,
			"max_level": max_level,
			"cost": get_upgrade_cost(upgrade_id),
			"can_buy": level < max_level and time_points >= get_upgrade_cost(upgrade_id),
		})
	return rows


func _upgrade_role(upgrade_id: String) -> String:
	match upgrade_id:
		"max_hp":
			return "More life"
		"attack":
			return "Hit harder"
		"defense":
			return "Take less"
		"mining_efficiency":
			return "Stone faster"
		"building_efficiency":
			return "Cheaper builds"
		"farming_yield":
			return "More food"
		"warding_power":
			return "Stronger light"
		"trapcraft":
			return "Deadlier floor"
		"regeneration":
			return "Recover faster"
		"sign_understanding":
			return "Read signs"
	return "General"


func _upgrade_tags(upgrade_id: String) -> Array:
	match upgrade_id:
		"max_hp":
			return ["HP", "survive"]
		"attack":
			return ["damage", "melee"]
		"defense":
			return ["armor", "survive"]
		"mining_efficiency":
			return ["stone", "day"]
		"building_efficiency":
			return ["walls", "cost"]
		"farming_yield":
			return ["food", "calm"]
		"warding_power":
			return ["orb", "area"]
		"trapcraft":
			return ["traps", "delay"]
		"regeneration":
			return ["rest", "heal"]
		"sign_understanding":
			return ["sign", "mind"]
	return ["general", "run"]


func _summary() -> String:
	var strongest := []
	for upgrade_id in UPGRADE_ORDER:
		var level := get_upgrade_level(str(upgrade_id))
		if level > 0:
			strongest.append("%s %d" % [str(UPGRADE_DEFS[str(upgrade_id)].get("label", upgrade_id)), level])
	if strongest.is_empty():
		return "No permanent upgrades yet"
	var shown := PackedStringArray()
	for i in range(mini(3, strongest.size())):
		shown.append(str(strongest[i]))
	return ", ".join(shown)


func _reset_upgrades_if_needed() -> void:
	for upgrade_id in UPGRADE_ORDER:
		if not upgrades.has(str(upgrade_id)):
			upgrades[str(upgrade_id)] = 0


func _load() -> void:
	_reset_upgrades_if_needed()
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("Could not read permanent progression save: %s" % save_path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Permanent progression save is not a dictionary.")
		return
	time_points = maxi(int(parsed.get("time_points", 0)), 0)
	deaths = maxi(int(parsed.get("deaths", 0)), 0)
	best_day = maxi(int(parsed.get("best_day", 1)), 1)
	var loaded_upgrades = parsed.get("upgrades", {})
	if typeof(loaded_upgrades) == TYPE_DICTIONARY:
		for upgrade_id in UPGRADE_ORDER:
			var max_level := int(UPGRADE_DEFS[str(upgrade_id)].get("max_level", 6))
			upgrades[str(upgrade_id)] = clampi(int(loaded_upgrades.get(str(upgrade_id), 0)), 0, max_level)


func _save() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write permanent progression save: %s" % save_path)
		return
	file.store_string(JSON.stringify({
		"time_points": time_points,
		"deaths": deaths,
		"best_day": best_day,
		"upgrades": upgrades,
	}, "\t"))
