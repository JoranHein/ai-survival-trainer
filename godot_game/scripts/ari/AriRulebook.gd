class_name AriRulebook
extends RefCounted

const RULEBOOK_PATH := "res://data/game_rulebook.json"

var _cached_rulebook := {}


func get_rulebook() -> Dictionary:
	if _cached_rulebook.is_empty():
		_cached_rulebook = _load_rulebook()
	return _cached_rulebook.duplicate(true)


func _load_rulebook() -> Dictionary:
	if FileAccess.file_exists(RULEBOOK_PATH):
		var file := FileAccess.open(RULEBOOK_PATH, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				return _compact_dictionary(parsed, 40, 420)
	return _fallback_rulebook()


func _fallback_rulebook() -> Dictionary:
	return {
		"version": "ari_strategy_rulebook_v1_fallback",
		"rules": {
			"walls": "Walls delay ground enemies but not flying enemies.",
			"aura_orb": "Aura Orb hurts enemies inside its circle.",
			"tower": "Towers allow ranged attacks when built.",
			"storm_rod": "Storm Rod answers flying enemies.",
			"food": "Food and rest keep Ari stable enough to act.",
			"library": "Library reflection turns mistakes into lessons.",
		},
	}


func _compact_dictionary(value: Dictionary, max_items: int, max_text: int) -> Dictionary:
	var result := {}
	var count := 0
	for raw_key in value.keys():
		if count >= max_items:
			break
		var key := _limit_text(str(raw_key), 80)
		var raw_value = value[raw_key]
		if typeof(raw_value) == TYPE_DICTIONARY:
			result[key] = _compact_dictionary(raw_value, max_items, max_text)
		elif typeof(raw_value) == TYPE_ARRAY:
			result[key] = _compact_array(raw_value, max_items, max_text)
		else:
			result[key] = _limit_text(str(raw_value), max_text)
		count += 1
	return result


func _compact_array(value: Array, max_items: int, max_text: int) -> Array:
	var result := []
	for item in value:
		if result.size() >= max_items:
			break
		if typeof(item) == TYPE_DICTIONARY:
			result.append(_compact_dictionary(item, max_items, max_text))
		else:
			result.append(_limit_text(str(item), max_text))
	return result


func _limit_text(text: String, max_length: int) -> String:
	var clean := text.replace("\n", " ").replace("\t", " ").strip_edges()
	if clean.length() <= max_length:
		return clean
	return clean.substr(0, max_length - 3).strip_edges() + "..."
