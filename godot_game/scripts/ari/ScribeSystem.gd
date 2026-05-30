class_name ScribeSystem
extends RefCounted

var ai_bridge: AIBridge


func create_scribe_note_from_recent_memory(memory: AriMemory, chronicle: Chronicle, context: Dictionary = {}, callback: Callable = Callable()) -> void:
	var payload := _build_payload(memory, context)
	var bridge := _get_bridge()
	bridge.request_scribe(payload, func(note: Dictionary) -> void:
		var safe_note := _validate_scribe_note(note)
		chronicle.add_scribe_note(safe_note)
		print("Scribe note created: ", safe_note.get("note", ""))
		if callback.is_valid():
			callback.call(safe_note)
	)


func _build_payload(memory: AriMemory, context: Dictionary) -> Dictionary:
	var payload := context.duplicate(true)
	payload["recent_events"] = memory.get_recent_events(50)
	payload["recent_snapshots"] = memory.get_recent_snapshots(10)

	if not payload.has("ari"):
		payload["ari"] = {}
		var snapshots: Array = payload.get("recent_snapshots", [])
		if not snapshots.is_empty() and typeof(snapshots[snapshots.size() - 1]) == TYPE_DICTIONARY:
			var latest_snapshot: Dictionary = snapshots[snapshots.size() - 1]
			if typeof(latest_snapshot.get("ari", {})) == TYPE_DICTIONARY:
				payload["ari"] = latest_snapshot.get("ari", {})

	if not payload.has("phase"):
		var ari: Dictionary = payload.get("ari", {})
		payload["phase"] = str(ari.get("phase", "unknown"))

	return payload


func _validate_scribe_note(note: Dictionary) -> Dictionary:
	return {
		"t_start": float(note.get("t_start", 0.0)),
		"t_end": float(note.get("t_end", 0.0)),
		"note": _limit_text(str(note.get("note", "")), 300),
		"tags": _string_array(note.get("tags", []), 8, 40),
		"salience": clampf(float(note.get("salience", 0.3)), 0.0, 1.0),
	}


func _get_bridge() -> AIBridge:
	if ai_bridge != null:
		return ai_bridge
	ai_bridge = AIBridge.new()
	return ai_bridge


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
