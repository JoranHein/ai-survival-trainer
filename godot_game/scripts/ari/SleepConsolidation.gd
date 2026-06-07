class_name SleepConsolidation
extends RefCounted

var ai_bridge: AIBridge


func request_sleep_plan(ari_context: Dictionary, lesson_book: LessonBook, callback: Callable = Callable()) -> void:
	var payload := {
		"ari_context": ari_context.duplicate(true),
		"lifetime_notes": lesson_book.get_all_notes(),
		"latest_note": lesson_book.get_latest_note(),
	}
	var bridge := _get_bridge()
	bridge.request_sleep_plan(payload, func(plan: Dictionary) -> void:
		var safe_plan := _validate_sleep_plan(plan)
		print("Sleep plan created: ", safe_plan.get("wake_thought", ""))
		if callback.is_valid():
			callback.call(safe_plan)
	)


func _validate_sleep_plan(plan: Dictionary) -> Dictionary:
	return {
		"dominant_memory": _limit_text(str(plan.get("dominant_memory", "")), 500),
		"tomorrow_focus": _string_array(plan.get("tomorrow_focus", ["prepare"]), 8, 50),
		"priority_bias": _priority_bias(plan.get("priority_bias", {})),
		"doctrines": _doctrines(plan.get("doctrines", [])),
		"wake_thought": _limit_text(str(plan.get("wake_thought", "")), 300),
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


func _doctrines(value) -> Array:
	var doctrine_validator := AriDoctrine.new()
	return doctrine_validator.add_doctrines(value)


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
