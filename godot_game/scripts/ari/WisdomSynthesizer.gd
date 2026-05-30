class_name WisdomSynthesizer
extends RefCounted

var ai_bridge: AIBridge


func request_background_synthesis(life_archive: LifeArchive, insight_book: PermanentInsightBook, callback: Callable = Callable()) -> void:
	var payload := {
		"recent_life_summaries": life_archive.get_recent_life_summaries(10),
		"current_permanent_insights": insight_book.get_all_insights(),
	}
	var bridge := _get_bridge()
	bridge.request_wisdom_synthesis(payload, func(result: Dictionary) -> void:
		var safe_result := _validate_wisdom_result(result)
		_apply_safe_changes(safe_result, insight_book)
		print("Wisdom synthesis created: ", safe_result.get("new_insights", []).size(), " new insight(s).")
		if callback.is_valid():
			callback.call(safe_result)
	)


func _apply_safe_changes(result: Dictionary, insight_book: PermanentInsightBook) -> void:
	for insight in result.get("new_insights", []):
		if typeof(insight) == TYPE_DICTIONARY:
			insight_book.add_or_merge_insight(insight)

	for insight in result.get("updated_insights", []):
		if typeof(insight) == TYPE_DICTIONARY:
			insight_book.update_matching_insight(insight)


func _validate_wisdom_result(result: Dictionary) -> Dictionary:
	return {
		"new_insights": _insight_array(result.get("new_insights", [])),
		"updated_insights": _insight_array(result.get("updated_insights", [])),
		"weakened_insights": _insight_array(result.get("weakened_insights", [])),
		"merged_insights": _insight_array(result.get("merged_insights", [])),
		"retired_insights": _string_array(result.get("retired_insights", []), 16, 120),
	}


func _insight_array(value) -> Array:
	var results := []
	if typeof(value) != TYPE_ARRAY:
		return results
	for item in value:
		if typeof(item) == TYPE_DICTIONARY:
			results.append(_validate_insight(item))
		if results.size() >= 8:
			break
	return results


func _validate_insight(insight: Dictionary) -> Dictionary:
	var title := _limit_text(str(insight.get("title", "Untitled Insight")), 120)
	return {
		"id": _limit_text(str(insight.get("id", title.to_lower().replace(" ", "_"))), 120),
		"title": title,
		"summary": _limit_text(str(insight.get("summary", "")), 500),
		"conditions": _string_array(insight.get("conditions", []), 12, 80),
		"suggested_actions": _string_array(insight.get("suggested_actions", []), 12, 80),
		"counters": _string_array(insight.get("counters", []), 12, 80),
		"confidence": clampf(float(insight.get("confidence", 0.35)), 0.0, 1.0),
		"times_confirmed": max(1, int(insight.get("times_confirmed", 1))),
		"times_failed": max(0, int(insight.get("times_failed", 0))),
		"source_lives": _string_array(insight.get("source_lives", []), 20, 120),
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
