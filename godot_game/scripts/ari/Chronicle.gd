class_name Chronicle
extends RefCounted

var today_scribe_notes: Array = []
var lifetime_scribe_notes: Array = []
var _next_scribe_note_sequence := 1


func add_scribe_note(note: Dictionary) -> void:
	var raw_note := note.duplicate(true)
	if str(raw_note.get("note_id", "")).strip_edges() == "":
		raw_note["note_id"] = "scribe_%04d" % _next_scribe_note_sequence
	_next_scribe_note_sequence += 1
	var safe_note := _validate_scribe_note(raw_note)
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
	_next_scribe_note_sequence = 1


func _validate_scribe_note(note: Dictionary) -> Dictionary:
	return {
		"schema": "ari.scribe.note.v2",
		"note_id": _limit_text(str(note.get("note_id", note.get("id", ""))), 120),
		"t_start": float(note.get("t_start", 0.0)),
		"t_end": float(note.get("t_end", 0.0)),
		"note": _limit_text(str(note.get("note", "")), 300),
		"tags": _string_array(note.get("tags", []), 8, 40),
		"facts": _string_array(note.get("facts", []), 8, 120),
		"actions": _action_array(note.get("actions", []), 4),
		"dangers": _danger_array(note.get("dangers", []), 4),
		"world_changes": _string_array(note.get("world_changes", note.get("notable_changes", [])), 6, 80),
		"priority_hints": _priority_hints(note.get("priority_hints", {})),
		"plan_alignment": _plan_alignment(note.get("plan_alignment", "unknown")),
		"immediate_risk": _risk_level(note.get("immediate_risk", "none")),
		"risk_reason": _limit_text(str(note.get("risk_reason", "")), 180),
		"resource_blockers": _string_array(note.get("resource_blockers", []), 5, 80),
		"mistake_candidates": _string_array(note.get("mistake_candidates", []), 5, 140),
		"opportunity_candidates": _string_array(note.get("opportunity_candidates", []), 5, 140),
		"lesson_candidates": _string_array(note.get("lesson_candidates", []), 5, 140),
		"confidence": clampf(float(note.get("confidence", 0.35)), 0.0, 1.0),
		"salience": clampf(float(note.get("salience", 0.3)), 0.0, 1.0),
		"source": _limit_text(str(note.get("source", "")), 64),
		"failure_reason": _limit_text(str(note.get("failure_reason", "")), 64),
		"origin": _limit_text(str(note.get("origin", "")), 80),
		"evidence_ids": _string_array(note.get("evidence_ids", note.get("evidence_snapshot_ids", [])), 12, 120),
	}


func _plan_alignment(value) -> String:
	var text := str(value).strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	if text == "support":
		text = "supporting"
	if ["aligned", "supporting", "mismatch", "unknown"].has(text):
		return text
	return "unknown"


func _risk_level(value) -> String:
	var text := str(value).strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	if ["none", "low", "medium", "high", "lethal"].has(text):
		return text
	return "none"


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
		var text := _limit_text(str(item), max_length)
		if text != "" and not result.has(text):
			result.append(text)
		if result.size() >= max_count:
			break
	return result


func _action_array(value, max_count: int) -> Array:
	var result := []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var action := _limit_text(str(item.get("action", item.get("action_id", item.get("id", "")))), 80)
		if action == "":
			continue
		result.append({
			"action": action,
			"status": _limit_text(str(item.get("status", item.get("outcome", "observed"))), 40),
			"reason": _limit_text(str(item.get("reason", "")), 160),
		})
		if result.size() >= max_count:
			break
	return result


func _danger_array(value, max_count: int) -> Array:
	var result := []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var danger_type := _limit_text(str(item.get("type", item.get("enemy_type", ""))), 60)
		if danger_type == "":
			continue
		result.append({
			"type": danger_type,
			"distance": maxf(0.0, float(item.get("distance", 0.0))),
			"severity": clampf(float(item.get("severity", item.get("salience", 0.0))), 0.0, 1.0),
		})
		if result.size() >= max_count:
			break
	return result


func _priority_hints(value) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in value.keys():
		var hint_key := _limit_text(str(key), 80)
		if hint_key == "":
			continue
		result[hint_key] = clampf(float(value[key]), -1.0, 1.0)
	return result


func _limit_text(text: String, max_length: int) -> String:
	var cleaned := text.strip_edges()
	return cleaned if cleaned.length() <= max_length else cleaned.substr(0, max_length)
