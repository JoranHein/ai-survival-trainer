class_name RunBuild
extends Node

@export var data_path := "res://data/instinct_points.json"

const TOTAL_POINTS := 12
const CATEGORIES := [
	"mining",
	"building",
	"warding",
	"movement",
	"defense",
	"fear_control",
	"sign_faith",
	"curiosity",
	"farming",
	"regeneration",
	"trapcraft",
	"bow",
	"attack_range",
	"thorns",
	"sword",
	"attack_damage",
	"attack_speed",
	"armor",
	"smithing",
]

var preset_id := "balanced"
var preset_name := "Balanced"
var points := {}

var _presets := {}


func _ready() -> void:
	_load_data()
	reset_run()


func reset_run() -> void:
	apply_preset("balanced")


func apply_preset_key(key_number: int) -> bool:
	match key_number:
		1:
			return apply_preset("builder")
		2:
			return apply_preset("aura_monk")
		3:
			return apply_preset("fast_coward")
		4:
			return apply_preset("curious_sign_reader")
		5:
			return apply_preset("tower_archer")
		6:
			return apply_preset("thorn_tank")
		7:
			return apply_preset("trap_architect")
		8:
			return apply_preset("farmer_survivor")
		9:
			return apply_preset("sword_killer")
		10:
			return apply_preset("heavy_armor_tank")
		11:
			return apply_preset("dawn_survivor")
		12:
			return apply_preset("smith")
	return false


func apply_preset(next_preset_id: String) -> bool:
	var preset := _preset_data(next_preset_id)
	if preset.is_empty():
		return false

	var next_points := _validated_points(preset.get("points", {}))
	preset_id = next_preset_id
	preset_name = str(preset.get("display_name", next_preset_id.capitalize()))
	points = next_points
	return true


func get_context() -> Dictionary:
	return {
		"preset_id": preset_id,
		"preset_name": preset_name,
		"role": get_role(),
		"tags": get_tags(),
		"top_categories": get_top_categories(),
		"total_points": TOTAL_POINTS,
		"points": get_points(),
	}


func get_points() -> Dictionary:
	return points.duplicate(true)


func get_value(category: String) -> int:
	return int(points.get(category, 0))


func get_strength(category: String) -> float:
	return clampf(float(get_value(category)) / 7.0, 0.0, 1.0)


func get_summary() -> String:
	if preset_id == "balanced":
		return "Balanced | mixed 12"
	var parts := PackedStringArray()
	for category in CATEGORIES:
		var value := get_value(category)
		if value > 0:
			parts.append("%s %d" % [_category_label(category), value])
	return "%s | %s" % [preset_name, " ".join(parts)]


func get_role() -> String:
	var preset := _preset_data(preset_id)
	var role := str(preset.get("role", "")).strip_edges()
	if role != "":
		return role
	match preset_id:
		"balanced":
			return "Flexible prep"
		"builder":
			return "Fortify"
		"aura_monk":
			return "Ward focus"
		"fast_coward":
			return "Kite and calm"
		"curious_sign_reader":
			return "Sign reader"
		"tower_archer":
			return "Range plan"
		"thorn_tank":
			return "Endure contact"
		"trap_architect":
			return "Trap lanes"
		"farmer_survivor":
			return "Food recovery"
		"sword_killer":
			return "Melee killer"
		"heavy_armor_tank":
			return "Armor and regen"
		"dawn_survivor":
			return "Outlast dawn"
		"smith":
			return "Forge weapons"
	return _derived_role()


func get_tags() -> Array:
	var preset := _preset_data(preset_id)
	var raw_tags = preset.get("tags", [])
	var tags := []
	if typeof(raw_tags) == TYPE_ARRAY:
		for raw_tag in raw_tags:
			var clean_tag := str(raw_tag).strip_edges()
			if clean_tag == "":
				continue
			tags.append(_compact_text(clean_tag, 16))
			if tags.size() >= 3:
				break
	if tags.size() >= 2:
		return tags

	for category in get_top_categories(3):
		tags.append("%s %d" % [
			str(category.get("label", "instinct")),
			int(category.get("value", 0)),
		])
	while tags.size() < 2:
		tags.append("mixed")
	return tags


func get_top_categories(limit := 3) -> Array:
	var ranked := []
	for category in CATEGORIES:
		var value := get_value(category)
		if value <= 0:
			continue
		ranked.append({
			"id": category,
			"label": _category_label(category),
			"value": value,
		})
	ranked.sort_custom(_sort_top_category)

	var result := []
	for i in range(mini(limit, ranked.size())):
		result.append(ranked[i])
	return result


func get_preset_name() -> String:
	return preset_name


func get_preset_thought() -> String:
	return str(_preset_data(preset_id).get("thought", "This is the shape I will try."))


func get_effects() -> Dictionary:
	return {
		"movement_speed_multiplier": 1.0 + get_value("movement") * 0.035,
		"mining_speed_multiplier": 1.0 + get_value("mining") * 0.060,
		"damage_taken_multiplier": maxf(0.72, 1.0 - get_value("defense") * 0.035),
		"aura_damage_multiplier": 1.0 + get_value("warding") * 0.050,
		"training_gain_multiplier": 1.0 + get_value("curiosity") * 0.015 + get_value("fear_control") * 0.015,
		"defense_training_gain_multiplier": 1.0 + get_value("defense") * 0.080 + get_value("fear_control") * 0.040,
		"farming_speed_multiplier": 1.0 + get_value("farming") * 0.070,
		"rest_recovery_multiplier": 1.0 + get_value("regeneration") * 0.060 + get_value("fear_control") * 0.030,
		"repair_speed_multiplier": 1.0 + get_value("building") * 0.045 + get_value("defense") * 0.035,
		"bow_strength": get_strength("bow"),
		"attack_range_strength": get_strength("attack_range"),
		"trapcraft_strength": get_strength("trapcraft"),
		"defense_strength": get_strength("defense"),
		"thorns_strength": get_strength("thorns"),
		"sword_strength": get_strength("sword"),
		"attack_damage_bonus": get_value("attack_damage") * 0.045 + get_value("sword") * 0.025,
		"attack_speed_multiplier": 1.0 + get_value("attack_speed") * 0.035 + get_value("sword") * 0.015,
		"armor_bonus": get_value("armor") * 0.025,
		"passive_regen_per_second": get_value("regeneration") * 0.035,
		"regen_on_kill": get_value("regeneration") * 0.85 + get_value("sword") * 0.28,
		"smithing_speed_multiplier": 1.0 + get_value("smithing") * 0.070,
		"ore_yield_multiplier": 1.0 + get_value("mining") * 0.045 + get_value("smithing") * 0.045,
	}


func _load_data() -> void:
	_presets = _fallback_presets()
	if not FileAccess.file_exists(data_path):
		push_warning("Run build data missing: %s" % data_path)
		return

	var file := FileAccess.open(data_path, FileAccess.READ)
	if file == null:
		push_warning("Could not open run build data: %s" % data_path)
		return

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Run build data is not a dictionary.")
		return

	var parsed_presets = parsed.get("presets", {})
	if typeof(parsed_presets) == TYPE_DICTIONARY:
		_presets = parsed_presets


func _preset_data(next_preset_id: String) -> Dictionary:
	var preset = _presets.get(next_preset_id, {})
	if typeof(preset) == TYPE_DICTIONARY:
		return preset
	return {}


func _validated_points(raw_points) -> Dictionary:
	var next_points := _blank_points()
	if typeof(raw_points) != TYPE_DICTIONARY:
		return _balanced_points()

	for category in CATEGORIES:
		next_points[category] = maxi(int(raw_points.get(category, 0)), 0)

	if _point_total(next_points) != TOTAL_POINTS:
		push_warning("Run build preset must spend exactly %d points." % TOTAL_POINTS)
		return _balanced_points()
	return next_points


func _blank_points() -> Dictionary:
	var result := {}
	for category in CATEGORIES:
		result[category] = 0
	return result


func _balanced_points() -> Dictionary:
	return {
		"mining": 2,
		"building": 2,
		"warding": 2,
		"movement": 2,
		"defense": 1,
		"fear_control": 1,
		"sign_faith": 1,
		"curiosity": 1,
	}


func _point_total(value_points: Dictionary) -> int:
	var total := 0
	for category in CATEGORIES:
		total += int(value_points.get(category, 0))
	return total


func _category_label(category: String) -> String:
	match category:
		"movement":
			return "move"
		"defense":
			return "def"
		"fear_control":
			return "fear"
		"sign_faith":
			return "faith"
		"curiosity":
			return "curious"
		"regeneration":
			return "regen"
		"attack_range":
			return "range"
		"attack_damage":
			return "damage"
		"attack_speed":
			return "speed"
	return category


func _sort_top_category(a: Dictionary, b: Dictionary) -> bool:
	var a_value := int(a.get("value", 0))
	var b_value := int(b.get("value", 0))
	if a_value == b_value:
		return str(a.get("label", "")) < str(b.get("label", ""))
	return a_value > b_value


func _derived_role() -> String:
	var top := get_top_categories(2)
	if top.is_empty():
		return "Unshaped"
	if top.size() == 1:
		return "%s focus" % str(top[0].get("label", "instinct")).capitalize()
	return "%s + %s" % [
		str(top[0].get("label", "instinct")).capitalize(),
		str(top[1].get("label", "instinct")),
	]


func _compact_text(text: String, max_chars: int) -> String:
	var clean_text := text.strip_edges()
	if clean_text.length() <= max_chars:
		return clean_text
	return clean_text.substr(0, maxi(max_chars - 1, 1)).strip_edges() + "."


func _fallback_presets() -> Dictionary:
	return {
		"balanced": {
			"display_name": "Balanced",
			"points": _balanced_points(),
			"thought": "A little of everything. I will have to listen carefully.",
		},
		"builder": {
			"display_name": "Builder",
			"points": {
				"mining": 4,
				"building": 5,
				"warding": 3,
			},
			"thought": "Stone and shape. That is how I will survive.",
		},
		"aura_monk": {
			"display_name": "Aura Monk",
			"points": {
				"warding": 7,
				"building": 3,
				"fear_control": 2,
			},
			"thought": "The circle may hurt them before I have to.",
		},
		"fast_coward": {
			"display_name": "Fast Coward",
			"points": {
				"movement": 7,
				"fear_control": 3,
				"building": 2,
			},
			"thought": "If I keep moving, maybe death misses.",
		},
		"curious_sign_reader": {
			"display_name": "Curious Sign Reader",
			"points": {
				"curiosity": 5,
				"sign_faith": 5,
				"warding": 2,
			},
			"thought": "The sign is strange. I want to understand it.",
		},
		"tower_archer": {
			"display_name": "Tower Archer",
			"points": {
				"bow": 5,
				"attack_range": 4,
				"building": 3,
			},
			"thought": "Distance can be a kind of wall.",
		},
		"thorn_tank": {
			"display_name": "Thorn Tank",
			"points": {
				"thorns": 5,
				"defense": 4,
				"regeneration": 3,
			},
			"thought": "If they touch me, they should regret it.",
		},
		"trap_architect": {
			"display_name": "Trap Architect",
			"points": {
				"trapcraft": 6,
				"building": 3,
				"warding": 3,
			},
			"thought": "The floor can fight before I have to.",
		},
		"farmer_survivor": {
			"display_name": "Farmer Survivor",
			"points": {
				"farming": 6,
				"regeneration": 3,
				"fear_control": 3,
			},
			"thought": "A full stomach makes the dark smaller.",
		},
		"sword_killer": {
			"display_name": "Sword Killer",
			"points": {
				"sword": 5,
				"attack_damage": 3,
				"attack_speed": 2,
				"defense": 2,
			},
			"thought": "If I have to touch the dead, I will make the touch count.",
		},
		"heavy_armor_tank": {
			"display_name": "Heavy Armor Tank",
			"points": {
				"armor": 5,
				"defense": 4,
				"regeneration": 3,
			},
			"thought": "If I cannot run, I must make my skin patient.",
		},
		"dawn_survivor": {
			"display_name": "Dawn Survivor",
			"points": {
				"movement": 4,
				"fear_control": 3,
				"defense": 2,
				"regeneration": 3,
			},
			"thought": "I do not have to win the dark. I have to reach morning.",
		},
		"smith": {
			"display_name": "Smith",
			"points": {
				"smithing": 5,
				"mining": 4,
				"sword": 3,
			},
			"thought": "Ore can become an answer if I reach the forge.",
		},
	}
