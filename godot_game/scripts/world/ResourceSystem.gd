class_name ResourceSystem
extends Node

signal changed(state: Dictionary)

@export var materials_path := "res://data/materials.json"
@export var structures_path := "res://data/structures.json"
@export var starting_stone := 10
@export var starting_food := 1

var stone := 0
var food := 0
var materials := {}
var structures := {}


func _ready() -> void:
	_load_materials()
	_load_structures()
	reset_run()


func reset_run() -> void:
	stone = starting_stone
	food = starting_food
	changed.emit(get_state())


func add_stone(amount: int) -> void:
	var safe_amount: int = maxi(amount, 0)
	if safe_amount <= 0:
		return
	stone += safe_amount
	changed.emit(get_state())


func add_food(amount: int) -> void:
	var safe_amount: int = maxi(amount, 0)
	if safe_amount <= 0:
		return
	food += safe_amount
	changed.emit(get_state())


func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	stone -= maxi(int(cost.get("stone", 0)), 0)
	food -= maxi(int(cost.get("food", 0)), 0)
	changed.emit(get_state())
	return true


func can_afford(cost: Dictionary) -> bool:
	return stone >= maxi(int(cost.get("stone", 0)), 0) and food >= maxi(int(cost.get("food", 0)), 0)


func get_stone() -> int:
	return stone


func get_food() -> int:
	return food


func spend_food(amount: int) -> bool:
	var safe_amount := maxi(amount, 0)
	if food < safe_amount:
		return false
	food -= safe_amount
	changed.emit(get_state())
	return true


func get_state() -> Dictionary:
	return {
		"stone": stone,
		"food": food,
	}


func get_material(material_id: String) -> Dictionary:
	var material = materials.get(material_id, {})
	if typeof(material) == TYPE_DICTIONARY:
		return material.duplicate(true)
	return {}


func get_wall_cost(material_id: String) -> Dictionary:
	var material := get_material(material_id)
	var cost = material.get("wall_cost", {"stone": 5})
	if typeof(cost) == TYPE_DICTIONARY:
		return cost.duplicate(true)
	return {"stone": 5}


func get_wall_hp(material_id: String) -> float:
	var material := get_material(material_id)
	return float(material.get("wall_hp", 40.0))


func get_structure(structure_id: String) -> Dictionary:
	var structure = structures.get(structure_id, {})
	if typeof(structure) == TYPE_DICTIONARY:
		return structure.duplicate(true)
	return {}


func get_structure_cost(structure_id: String) -> Dictionary:
	var structure := get_structure(structure_id)
	return {
		"stone": maxi(int(structure.get("stone_cost", 0)), 0),
	}


func get_structure_display_name(structure_id: String) -> String:
	var structure := get_structure(structure_id)
	return str(structure.get("display_name", structure_id))


func _load_materials() -> void:
	materials = _default_materials()
	if not FileAccess.file_exists(materials_path):
		push_warning("Materials file missing, using defaults: %s" % materials_path)
		return

	var file := FileAccess.open(materials_path, FileAccess.READ)
	if file == null:
		push_warning("Could not read materials file, using defaults: %s" % materials_path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Materials file was not a dictionary, using defaults: %s" % materials_path)
		return

	var loaded_materials = parsed.get("materials", parsed)
	if typeof(loaded_materials) == TYPE_DICTIONARY:
		materials = loaded_materials


func _load_structures() -> void:
	structures = _default_structures()
	if not FileAccess.file_exists(structures_path):
		push_warning("Structures file missing, using defaults: %s" % structures_path)
		return

	var file := FileAccess.open(structures_path, FileAccess.READ)
	if file == null:
		push_warning("Could not read structures file, using defaults: %s" % structures_path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Structures file was not a dictionary, using defaults: %s" % structures_path)
		return

	var loaded_structures = parsed.get("structures", parsed)
	if typeof(loaded_structures) == TYPE_DICTIONARY:
		structures = loaded_structures


func _default_materials() -> Dictionary:
	return {
		"crumbly_stone": {
			"display_name": "Crumbly Stone",
			"wall_hp": 40.0,
			"wall_cost": {
				"stone": 5,
			},
		},
	}


func _default_structures() -> Dictionary:
	return {
		"aura_orb": {
			"display_name": "Aura Orb",
			"hp": 28.0,
			"radius": 96.0,
			"damage_per_second": 7.0,
			"stone_cost": 5,
		},
		"spike_trap": {
			"display_name": "Spike Trap",
			"hp": 18.0,
			"radius": 22.0,
			"damage": 18.0,
			"uses": 4,
			"stone_cost": 4,
		},
		"bow_tower": {
			"display_name": "Bow Tower",
			"hp": 34.0,
			"range": 150.0,
			"damage": 10.0,
			"shot_cooldown_seconds": 0.7,
			"stone_cost": 8,
		},
		"tar_pit": {
			"display_name": "Tar Pit",
			"hp": 22.0,
			"slow_radius": 58.0,
			"slow_multiplier": 0.48,
			"stone_cost": 4,
		},
		"fear_lantern": {
			"display_name": "Fear Lantern",
			"hp": 26.0,
			"soothe_radius": 82.0,
			"fear_reduction_per_second": 2.0,
			"enemy_damage_multiplier": 0.90,
			"stone_cost": 5,
		},
		"decoy_idol": {
			"display_name": "Decoy Idol",
			"hp": 24.0,
			"taunt_radius": 118.0,
			"lifetime_seconds": 120.0,
			"stone_cost": 6,
		},
		"thorn_totem": {
			"display_name": "Thorn Totem",
			"hp": 30.0,
			"thorn_radius": 76.0,
			"recoil_damage": 4.5,
			"stone_cost": 6,
		},
		"repair_bench": {
			"display_name": "Repair Bench",
			"hp": 32.0,
			"repair_radius": 86.0,
			"passive_repair_per_second": 1.1,
			"active_repair_multiplier": 1.55,
			"stone_cost": 6,
		},
		"storm_rod": {
			"display_name": "Storm Rod",
			"hp": 30.0,
			"range": 132.0,
			"flying_damage": 18.0,
			"ground_damage": 4.0,
			"shot_cooldown_seconds": 1.05,
			"stone_cost": 7,
		},
	}
