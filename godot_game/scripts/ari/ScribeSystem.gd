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
		_print_structured_scribe_log(safe_note)
		if callback.is_valid():
			callback.call(safe_note)
	)


func _build_payload(memory: AriMemory, context: Dictionary) -> Dictionary:
	var payload := context.duplicate(true)
	if not payload.has("schema"):
		payload["schema"] = "ari.scribe.request.v1"
	payload["recent_events"] = memory.get_recent_events(50)
	payload["recent_snapshots"] = memory.get_recent_snapshots(10)
	if not payload.has("snapshots"):
		payload["snapshots"] = payload["recent_snapshots"]

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
		"behavior_evidence": _behavior_evidence_array(note.get("behavior_evidence", []), 3),
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


func _behavior_evidence_array(value, max_count: int) -> Array:
	var result := []
	if typeof(value) == TYPE_DICTIONARY:
		var evidence := _behavior_evidence(value)
		if not evidence.is_empty():
			result.append(evidence)
	elif typeof(value) == TYPE_ARRAY:
		for item in value:
			var evidence := _behavior_evidence(item)
			if evidence.is_empty():
				continue
			result.append(evidence)
			if result.size() >= max_count:
				break
	return result


func _behavior_evidence(value) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var pattern := _limit_text(str(value.get("primary_pattern", "")), 80)
	if pattern == "":
		return {}
	var context = value.get("context", {})
	var safe_context := {}
	if typeof(context) == TYPE_DICTIONARY:
		safe_context = {
			"phase": _limit_text(str(context.get("phase", "")), 40),
			"enemy_count_before": max(0, int(context.get("enemy_count_before", 0))),
			"enemy_count_after": max(0, int(context.get("enemy_count_after", 0))),
			"nearest_danger_changed": bool(context.get("nearest_danger_changed", false)),
			"active_plan_changed": bool(context.get("active_plan_changed", false)),
		}
	var progress = value.get("progress_delta", {})
	var safe_progress := {}
	if typeof(progress) == TYPE_DICTIONARY:
		safe_progress = {
			"structures": int(progress.get("structures", 0)),
			"stone": int(progress.get("stone", 0)),
			"repairs": int(progress.get("repairs", 0)),
			"kills": int(progress.get("kills", 0)),
			"hp": int(progress.get("hp", 0)),
		}
	return {
		"schema": "ari.behavior_evidence.v1",
		"window_seconds": clampf(float(value.get("window_seconds", 0.0)), 0.0, 120.0),
		"primary_pattern": pattern,
		"actions_seen": _string_array(value.get("actions_seen", []), 8, 80),
		"transition_count": max(0, int(value.get("transition_count", 0))),
		"completion_count": max(0, int(value.get("completion_count", 0))),
		"blocked_count": max(0, int(value.get("blocked_count", 0))),
		"abandoned_count": max(0, int(value.get("abandoned_count", 0))),
		"anchors_seen": _string_array(value.get("anchors_seen", []), 8, 80),
		"anchor_transition_count": max(0, int(value.get("anchor_transition_count", 0))),
		"progress_delta": safe_progress,
		"context": safe_context,
		"evidence_ids": _string_array(value.get("evidence_ids", []), 12, 120),
		"neutral_summary": _limit_text(str(value.get("neutral_summary", "")), 220),
	}


func _print_structured_scribe_log(note: Dictionary) -> void:
	if OS.get_environment("ARI_SCRIBE_LOG").strip_edges() != "1":
		return
	var payload := {
		"schema": "ari.scribe.log.v1",
		"note": note.get("note", ""),
		"tags": note.get("tags", []),
		"facts": note.get("facts", []),
		"actions": note.get("actions", []),
		"dangers": note.get("dangers", []),
		"world_changes": note.get("world_changes", []),
		"priority_hints": note.get("priority_hints", {}),
		"plan_alignment": note.get("plan_alignment", "unknown"),
		"immediate_risk": note.get("immediate_risk", "none"),
		"risk_reason": note.get("risk_reason", ""),
		"resource_blockers": note.get("resource_blockers", []),
		"mistake_candidates": note.get("mistake_candidates", []),
		"opportunity_candidates": note.get("opportunity_candidates", []),
		"lesson_candidates": note.get("lesson_candidates", []),
		"source": note.get("source", ""),
		"origin": note.get("origin", ""),
		"evidence_ids": note.get("evidence_ids", []),
		"behavior_evidence": note.get("behavior_evidence", []),
		"confidence": note.get("confidence", 0.0),
	}
	print("SCRIBE ", JSON.stringify(payload))


func _limit_text(text: String, max_length: int) -> String:
	var cleaned := text.strip_edges()
	return cleaned if cleaned.length() <= max_length else cleaned.substr(0, max_length)
