class_name Chronicle
extends RefCounted

var today_scribe_notes: Array = []
var lifetime_scribe_notes: Array = []


func add_scribe_note(note: Dictionary) -> void:
	var safe_note := _validate_scribe_note(note)
	today_scribe_notes.append(safe_note)
	lifetime_scribe_notes.append(safe_note.duplicate(true))


func get_today_scribe_notes() -> Array:
	return _copy_array(today_scribe_notes)


func get_lifetime_scribe_notes() -> Array:
	return _copy_array(lifetime_scribe_notes)


func clear_day() -> void:
	today_scribe_notes.clear()


func clear_life() -> void:
	today_scribe_notes.clear()
	lifetime_scribe_notes.clear()


func _validate_scribe_note(note: Dictionary) -> Dictionary:
	return {
		"t_start": float(note.get("t_start", 0.0)),
		"t_end": float(note.get("t_end", 0.0)),
		"note": _limit_text(str(note.get("note", "")), 300),
		"tags": _string_array(note.get("tags", []), 8, 40),
		"salience": clampf(float(note.get("salience", 0.3)), 0.0, 1.0),
	}


func _copy_array(source: Array) -> Array:
	var result := []
	for item in source:
		result.append(item.duplicate(true) if typeof(item) == TYPE_DICTIONARY else item)
	return result


func _string_array(value, max_count: int, max_length: int) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		result.append(_limit_text(str(item), max_length))
		if result.size() >= max_count:
			break
	return result


func _limit_text(text: String, max_length: int) -> String:
	var cleaned := text.strip_edges()
	return cleaned if cleaned.length() <= max_length else cleaned.substr(0, max_length)
