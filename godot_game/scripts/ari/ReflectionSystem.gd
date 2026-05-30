class_name ReflectionSystem
extends RefCounted

var ai_bridge: AIBridge


func request_library_reflection(ari_context: Dictionary, chronicle: Chronicle, lesson_book: LessonBook, callback: Callable = Callable()) -> void:
	var payload := {
		"ari_context": ari_context.duplicate(true),
		"current_sign": str(ari_context.get("current_sign", "")),
		"today_scribe_notes": chronicle.get_today_scribe_notes(),
		"previous_lifetime_notes": lesson_book.get_all_notes(),
		"available_actions": ari_context.get("available_actions", []),
	}

	var bridge := _get_bridge()
	bridge.request_library_reflection(payload, func(note: Dictionary) -> void:
		var safe_note := _validate_reflection(note)
		safe_note["created_day"] = int(ari_context.get("day", safe_note.get("created_day", 0)))
		lesson_book.add_note(safe_note)
		print("Library note created: ", safe_note.get("title", ""))
		if callback.is_valid():
			callback.call(safe_note)
	)


func _validate_reflection(note: Dictionary) -> Dictionary:
	return {
		"title": _limit_text(str(note.get("title", "Ari's rough local reflection")), 120),
		"markdown": _limit_text(str(note.get("markdown", "")), 2000),
		"hypothesis": _limit_text(str(note.get("hypothesis", "")), 300),
		"plan": note.get("plan", {}).duplicate(true) if typeof(note.get("plan", {})) == TYPE_DICTIONARY else {},
		"priority_bias": _priority_bias(note.get("priority_bias", {})),
		"confidence": clampf(float(note.get("confidence", 0.35)), 0.0, 1.0),
		"thought": _limit_text(str(note.get("thought", "")), 300),
		"created_day": int(note.get("created_day", 0)),
	}


func _priority_bias(value) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in value.keys():
		result[_limit_text(str(key), 80)] = clampf(float(value[key]), -1.0, 1.0)
	return result


func _get_bridge() -> AIBridge:
	if ai_bridge != null:
		return ai_bridge
	ai_bridge = AIBridge.new()
	return ai_bridge


func _limit_text(text: String, max_length: int) -> String:
	var cleaned := text.strip_edges()
	return cleaned if cleaned.length() <= max_length else cleaned.substr(0, max_length)
