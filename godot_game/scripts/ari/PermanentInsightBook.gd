class_name PermanentInsightBook
extends RefCounted

var insights: Array = []


func add_or_merge_insight(insight: Dictionary) -> void:
	var safe_insight := _validate_insight(insight)
	var existing := _find_existing_insight(safe_insight)
	if not existing.is_empty():
		existing["summary"] = safe_insight.get("summary", existing.get("summary", ""))
		existing["confidence"] = clampf(max(float(existing.get("confidence", 0.0)), float(safe_insight.get("confidence", 0.0))), 0.0, 1.0)
		existing["times_confirmed"] = int(existing.get("times_confirmed", 1)) + int(safe_insight.get("times_confirmed", 1))
		existing["conditions"] = _merged_string_array(existing.get("conditions", []), safe_insight.get("conditions", []))
		existing["suggested_actions"] = _merged_string_array(existing.get("suggested_actions", []), safe_insight.get("suggested_actions", []))
		existing["counters"] = _merged_string_array(existing.get("counters", []), safe_insight.get("counters", []))
		existing["source_lives"] = _merged_string_array(existing.get("source_lives", []), safe_insight.get("source_lives", []))
		print("Insight added/merged: ", existing.get("title", ""))
		return
	insights.append(safe_insight)
	print("Insight added/merged: ", safe_insight.get("title", ""))


func update_matching_insight(insight: Dictionary) -> bool:
	var safe_insight := _validate_insight(insight)
	var existing := _find_existing_insight(safe_insight)
	if existing.is_empty():
		return false

	existing["title"] = safe_insight.get("title", existing.get("title", ""))
	existing["summary"] = safe_insight.get("summary", existing.get("summary", ""))
	existing["confidence"] = clampf(float(safe_insight.get("confidence", existing.get("confidence", 0.0))), 0.0, 1.0)
	existing["conditions"] = _merged_string_array(existing.get("conditions", []), safe_insight.get("conditions", []))
	existing["suggested_actions"] = _merged_string_array(existing.get("suggested_actions", []), safe_insight.get("suggested_actions", []))
	existing["counters"] = _merged_string_array(existing.get("counters", []), safe_insight.get("counters", []))
	existing["source_lives"] = _merged_string_array(existing.get("source_lives", []), safe_insight.get("source_lives", []))
	print("Insight added/merged: ", existing.get("title", ""))
	return true


func _find_existing_insight(insight: Dictionary) -> Dictionary:
	var normalized_title := _normalize_title(insight.get("title", ""))
	var id := str(insight.get("id", "")).strip_edges()
	for existing in insights:
		var existing_insight: Dictionary = existing
		if id != "" and str(existing_insight.get("id", "")) == id:
			return existing_insight
		if _normalize_title(existing_insight.get("title", "")) == normalized_title:
			return existing_insight
	return {}


func get_all_insights() -> Array:
	var result := []
	for insight in insights:
		result.append(insight.duplicate(true))
	return result


func find_relevant_insights(context: Dictionary) -> Array:
	var context_words := _context_words(context)
	var result := []
	for insight in insights:
		var conditions: Array = insight.get("conditions", [])
		if conditions.is_empty():
			result.append(insight.duplicate(true))
			continue
		for condition in conditions:
			if context_words.has(str(condition).to_lower()):
				result.append(insight.duplicate(true))
				break
	return result


func _validate_insight(insight: Dictionary) -> Dictionary:
	var title := _limit_text(str(insight.get("title", "Untitled Insight")), 120)
	return {
		"id": _limit_text(str(insight.get("id", _normalize_title(title))), 120),
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


func _context_words(context: Dictionary) -> Dictionary:
	var words := {}
	for key in context.keys():
		words[str(key).to_lower()] = true
		words[str(context[key]).to_lower()] = true
	return words


func _merged_string_array(a, b) -> Array[String]:
	var result: Array[String] = []
	for value in _string_array(a, 20, 120):
		if not result.has(value):
			result.append(value)
	for value in _string_array(b, 20, 120):
		if not result.has(value):
			result.append(value)
		if result.size() >= 20:
			break
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


func _normalize_title(text: String) -> String:
	return text.to_lower().strip_edges().replace(" ", "_").replace("-", "_")


func _limit_text(text: String, max_length: int) -> String:
	var cleaned := text.strip_edges()
	return cleaned if cleaned.length() <= max_length else cleaned.substr(0, max_length)
