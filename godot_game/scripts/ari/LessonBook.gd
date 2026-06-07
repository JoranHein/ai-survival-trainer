class_name LessonBook
extends RefCounted

var notes: Array = []


func add_note(note: Dictionary) -> void:
	notes.append(_validate_note(note))


func get_all_notes() -> Array:
	return _copy_array(notes)


func get_latest_note() -> Dictionary:
	if notes.is_empty():
		return {}
	return notes[notes.size() - 1].duplicate(true)


func get_note_summaries(max_count: int = 10) -> Array:
	var result := []
	var count = clampi(max_count, 0, notes.size())
	var start = notes.size() - count
	for i in range(start, notes.size()):
		var note: Dictionary = notes[i]
		result.append({
			"title": note.get("title", ""),
			"hypothesis": note.get("hypothesis", ""),
			"confidence": note.get("confidence", 0.0),
			"created_day": note.get("created_day", 0),
		})
	return result


func clear_life() -> void:
	notes.clear()


func _validate_note(note: Dictionary) -> Dictionary:
	return {
		"note_id": _limit_text(str(note.get("note_id", note.get("id", ""))), 120),
		"reflection_id": _limit_text(str(note.get("reflection_id", "")), 120),
		"summary_id": _limit_text(str(note.get("summary_id", "")), 120),
		"title": _limit_text(str(note.get("title", "Ari's rough local reflection")), 120),
		"markdown": _limit_text(str(note.get("markdown", "")), 2000),
		"hypothesis": _limit_text(str(note.get("hypothesis", "")), 300),
		"plan": _dictionary_copy(note.get("plan", {})),
		"priority_bias": _priority_bias(note.get("priority_bias", {})),
		"doctrines": _doctrines(note.get("doctrines", [])),
		"confidence": clampf(float(note.get("confidence", 0.0)), 0.0, 1.0),
		"thought": _limit_text(str(note.get("thought", "")), 300),
		"created_day": int(note.get("created_day", 0)),
		"source": _limit_text(str(note.get("source", "")), 64),
		"failure_reason": _limit_text(str(note.get("failure_reason", "")), 64),
		"origin": _limit_text(str(note.get("origin", "")), 80),
		"evidence_ids": _string_array(note.get("evidence_ids", note.get("evidence_snapshot_ids", [])), 20, 120),
	}


func _priority_bias(value) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in value.keys():
		result[_limit_text(str(key), 80)] = clampf(float(value[key]), -1.0, 1.0)
	return result


func _dictionary_copy(value) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return value.duplicate(true)


func _string_array(value, max_count: int, max_length: int) -> Array:
	var result := []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		if result.size() >= max_count:
			break
		var text := _limit_text(str(item), max_length)
		if text != "" and not result.has(text):
			result.append(text)
	return result


func _doctrines(value) -> Array:
	var doctrine_validator := AriDoctrine.new()
	return doctrine_validator.add_doctrines(value)


func _copy_array(source: Array) -> Array:
	var result := []
	for item in source:
		result.append(item.duplicate(true) if typeof(item) == TYPE_DICTIONARY else item)
	return result


func _limit_text(text: String, max_length: int) -> String:
	var cleaned := text.strip_edges()
	return cleaned if cleaned.length() <= max_length else cleaned.substr(0, max_length)
