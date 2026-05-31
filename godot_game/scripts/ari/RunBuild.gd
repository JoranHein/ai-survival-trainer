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
	return category


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
	}
