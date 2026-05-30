class_name LifeArchive
extends RefCounted

var life_summaries: Array = []


func add_life_summary(summary: Dictionary) -> void:
	life_summaries.append(_validate_summary(summary))


func get_all_life_summaries() -> Array:
	return _copy_array(life_summaries)


func get_recent_life_summaries(max_count: int = 10) -> Array:
	var count = clampi(max_count, 0, life_summaries.size())
	var start = life_summaries.size() - count
	var result := []
	for i in range(start, life_summaries.size()):
		result.append(life_summaries[i].duplicate(true))
	return result


func _validate_summary(summary: Dictionary) -> Dictionary:
	return {
		"life_id": _limit_text(str(summary.get("life_id", "")), 120),
		"result": _limit_text(str(summary.get("result", "unknown")), 80),
		"survived_days": max(0, int(summary.get("survived_days", 0))),
		"life_summary_markdown": _limit_text(str(summary.get("life_summary_markdown", "")), 2500),
		"candidate_insights": _insight_array(summary.get("candidate_insights", [])),
		"next_life_hint": _limit_text(str(summary.get("next_life_hint", "")), 300),
	}


func _insight_array(value) -> Array:
	var result := []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		if typeof(item) == TYPE_DICTIONARY:
			result.append(item.duplicate(true))
		if result.size() >= 8:
			break
	return result


func _copy_array(source: Array) -> Array:
	var result := []
	for item in source:
		result.append(item.duplicate(true) if typeof(item) == TYPE_DICTIONARY else item)
	return result


func _limit_text(text: String, max_length: int) -> String:
	var cleaned := text.strip_edges()
	return cleaned if cleaned.length() <= max_length else cleaned.substr(0, max_length)
