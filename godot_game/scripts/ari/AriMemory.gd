class_name AriMemory
extends RefCounted

const MAX_EVENTS := 300
const MAX_SNAPSHOTS := 80
const MAX_NOTES := 60
const MEANINGFUL_EVENTS := [
	"wall_destroyed",
	"structure_damaged",
	"structure_destroyed",
	"enemy_killed",
	"ari_damaged",
	"ari_near_death",
	"near_death",
	"aura_damage_success",
	"tower_ranged_success",
	"ari_ranged_hit",
	"hunger_high",
	"hunger_pressure",
	"death",
]

var events: Array = []
var snapshots: Array = []
var lifetime_notes: Array = []
var _next_event_sequence := 1
var _last_reflected_sequence := 0


func record_event(event_type: String, data: Dictionary = {}) -> void:
	var event := data.duplicate(true)
	event["type"] = event_type
	if not event.has("sequence"):
		event["sequence"] = _next_event_sequence
		_next_event_sequence += 1
	if not event.has("event_id"):
		event["event_id"] = "event_%04d" % int(event.get("sequence", _next_event_sequence))
	if not event.has("timestamp"):
		event["timestamp"] = Time.get_ticks_msec() / 1000.0
	if not event.has("source"):
		event["source"] = "godot"
	if not event.has("origin"):
		event["origin"] = "world_event"
	events.append(event)
	_trim_array(events, MAX_EVENTS)


func record_snapshot(snapshot: Dictionary) -> void:
	var safe_snapshot := snapshot.duplicate(true)
	if not safe_snapshot.has("snapshot_id") or str(safe_snapshot.get("snapshot_id", "")).strip_edges() == "":
		safe_snapshot["snapshot_id"] = "snap_%04d" % (snapshots.size() + 1)
	if not safe_snapshot.has("timestamp"):
		safe_snapshot["timestamp"] = Time.get_ticks_msec() / 1000.0
	if not safe_snapshot.has("source"):
		safe_snapshot["source"] = "godot"
	if not safe_snapshot.has("origin"):
		safe_snapshot["origin"] = "observer_snapshot"
	snapshots.append(safe_snapshot)
	_trim_array(snapshots, MAX_SNAPSHOTS)


func get_recent_events(max_count: int = 50) -> Array:
	return _recent_copy(events, max_count)


func get_recent_snapshots(max_count: int = 10) -> Array:
	return _recent_copy(snapshots, max_count)


func clear_day_memory() -> void:
	events.clear()
	snapshots.clear()


func clear_life_memory() -> void:
	clear_day_memory()
	lifetime_notes.clear()
	_last_reflected_sequence = 0
	_next_event_sequence = 1


func get_meaningful_event_count(max_count: int = 30) -> int:
	var count := 0
	for event in get_recent_events(max_count):
		if _is_meaningful_event(event) and int(event.get("sequence", 0)) > _last_reflected_sequence:
			count += 1
	return count


func create_lifetime_note_from_recent_events(created_day: int) -> Dictionary:
	var event := _latest_unreflected_meaningful_event()
	if event.is_empty():
		return {}
	var note := add_lifetime_note(_note_from_event(event, created_day))
	_last_reflected_sequence = int(event.get("sequence", _last_reflected_sequence))
	return note


func add_lifetime_note(note: Dictionary) -> Dictionary:
	var safe_note := _validate_note(note)
	lifetime_notes.append(safe_note)
	_trim_array(lifetime_notes, MAX_NOTES)
	return safe_note.duplicate(true)


func get_lifetime_notes(max_count: int = MAX_NOTES) -> Array:
	return _recent_copy(lifetime_notes, max_count)


func get_latest_lifetime_note() -> Dictionary:
	if lifetime_notes.is_empty():
		return {}
	return lifetime_notes[lifetime_notes.size() - 1].duplicate(true)


func get_note_priority_bias(max_count: int = 3) -> Dictionary:
	var result := {}
	var notes := get_lifetime_notes(max_count)
	var weight := 1.0
	for i in range(notes.size() - 1, -1, -1):
		var note: Dictionary = notes[i]
		var hints: Dictionary = note.get("priority_hints", {})
		for key in hints.keys():
			var next_value := clampf(float(hints[key]) * weight, 0.0, 1.0)
			result[str(key)] = clampf(float(result.get(str(key), 0.0)) + next_value, 0.0, 1.0)
		weight *= 0.50
	return result


func _recent_copy(source: Array, max_count: int) -> Array:
	var count = clampi(max_count, 0, source.size())
	var start = source.size() - count
	var result := []
	for i in range(start, source.size()):
		var item = source[i]
		result.append(item.duplicate(true) if typeof(item) == TYPE_DICTIONARY else item)
	return result


func _trim_array(source: Array, max_count: int) -> void:
	while source.size() > max_count:
		source.pop_front()


func _latest_unreflected_meaningful_event() -> Dictionary:
	for i in range(events.size() - 1, -1, -1):
		var event = events[i]
		if typeof(event) != TYPE_DICTIONARY:
			continue
		if int(event.get("sequence", 0)) <= _last_reflected_sequence:
			continue
		if _is_meaningful_event(event):
			return event.duplicate(true)
	return {}


func _is_meaningful_event(event) -> bool:
	if typeof(event) != TYPE_DICTIONARY:
		return false
	return MEANINGFUL_EVENTS.has(str(event.get("type", "")))


func _note_from_event(event: Dictionary, created_day: int) -> Dictionary:
	var event_type := str(event.get("type", "event"))
	var title := "Day %d - I need a clearer plan" % created_day
	var body := "Something happened, and I should not let it vanish.\n"
	var hypothesis := "Preparation before night improves survival."
	var tags := [event_type]
	var hints := {"build_wall": 0.06, "place_aura_orb": 0.06}
	var doctrines := []
	match event_type:
		"wall_destroyed", "structure_destroyed":
			var structure_type := str(event.get("structure_type", "structure"))
			title = "Day %d - The wall was not enough" % created_day if structure_type == "wall" else "Day %d - %s broke" % [created_day, structure_type.capitalize()]
			body = "A structure broke while I was trying to survive.\nMore wall is not always more safety.\nI need damage, repair, or better placement before contact.\n"
			hypothesis = "Weak walls need damage or repair behind them."
			tags.append_array(["structure_destroyed", structure_type])
			hints = {"build_wall": 0.10, "place_aura_orb": 0.08, "build_repair_bench": 0.10}
			doctrines = [{
				"id": "%s_failure_repair_support" % structure_type,
				"summary": "A broken wall means Ari should add repair tools and damage behind cover before more reflection.",
				"when": {"structure_destroyed": structure_type},
				"bias": {"build_repair_bench": 0.65, "place_aura_orb": 0.35, "build_wall": 0.20},
				"plan": [
					{
						"affordance_id": "build_repair_bench",
						"priority": 0.72,
						"reason": "The last wall failed; tools make the next wall line recoverable.",
					},
					{
						"affordance_id": "place_aura_orb",
						"priority": 0.42,
						"reason": "Repair needs damage behind the cover so enemies do not only chew stone.",
					},
				],
				"confidence": 0.72,
			}]
		"structure_damaged":
			var damaged_type := str(event.get("structure_type", "structure"))
			title = "Day %d - %s started to crack" % [created_day, damaged_type.capitalize()]
			body = "The defense did not fall, but it was wounded.\nA thing that cracks in daylight may fail at night.\n"
			hypothesis = "Damaged defenses need repair or a second layer."
			tags.append_array(["structure_damaged", damaged_type])
			hints = {"repair_structure": 0.12, "build_repair_bench": 0.10, "build_wall": 0.06}
		"enemy_killed":
			var enemy_type := str(event.get("enemy_type", "enemy"))
			title = "Day %d - Damage worked" % created_day
			body = "An enemy died before it could decide the whole night.\nWhatever hurt it bought me time.\n"
			hypothesis = "Damage before contact can solve part of the night."
			tags.append_array(["enemy_killed", enemy_type])
			hints = {"place_aura_orb": 0.12, "train_combat": 0.08, "build_tower": 0.06}
		"ari_damaged", "ari_near_death", "near_death":
			title = "Day %d - Teeth reached me" % created_day
			body = "I was hurt recently.\nThe plan did not keep teeth far enough away.\nTraining, walls, light, and distance all matter before night.\n"
			hypothesis = "If enemies touch me, I need distance, walls, or training."
			tags.append_array(["ari_damaged"])
			hints = {"train_combat": 0.12, "build_wall": 0.10, "use_cover": 0.08}
		"aura_damage_success":
			title = "Day %d - The light hurt them" % created_day
			body = "The circle did real work.\nIf enemies cross the light, I do not have to touch them first.\n"
			hypothesis = "Aura damage matters when enemies are pulled through it."
			tags.append_array(["aura", "damage"])
			hints = {"place_aura_orb": 0.14, "lure_to_aura": 0.10}
		"tower_ranged_success", "ari_ranged_hit":
			title = "Day %d - The tower bought distance" % created_day
			body = "A shot landed before teeth reached me.\nHeight helped against ground pressure.\n"
			hypothesis = "The tower saved me from teeth, not wings."
			tags.append_array(["tower", "range"])
			hints = {"build_tower": 0.14, "use_tower": 0.10, "train_combat": 0.06}
		"hunger_high", "hunger_pressure":
			title = "Day %d - Hunger made the dark louder" % created_day
			body = "The empty stomach became another danger.\nFood is not courage, but it keeps fear smaller.\n"
			hypothesis = "Food keeps hunger from turning fear into danger."
			tags.append_array(["hunger", "food"])
			hints = {"farm_food": 0.14, "rest": 0.06}
		"death":
			title = "Day %d - I died" % created_day
			body = "The run ended.\nSomething reached me that preparation did not answer.\n"
			hypothesis = "A failed run needs clearer layers of safety and damage."
			tags.append_array(["death"])
			hints = {"build_wall": 0.08, "place_aura_orb": 0.08, "train_combat": 0.08}

	var markdown_text := "# %s\n\n%s\nNext focus:\n" % [title, body]
	for key in hints.keys():
		markdown_text += "- %s\n" % str(key).replace("_", " ")
	return {
		"title": title,
		"markdown_text": markdown_text,
		"markdown": markdown_text,
		"hypothesis": hypothesis,
		"tags": _string_array(tags, 8, 40),
		"priority_hints": hints,
		"priority_bias": hints,
		"doctrines": doctrines,
		"confidence": 0.45,
		"thought": _thought_for_event(event_type),
		"created_day": created_day,
		"source": "local_fallback",
		"failure_reason": "deterministic_event_reflection",
		"origin": "event_fallback",
		"evidence_ids": [_limit_text(str(event.get("event_id", "event_%04d" % int(event.get("sequence", 0)))), 120)],
	}


func _validate_note(note: Dictionary) -> Dictionary:
	var markdown_text := str(note.get("markdown_text", note.get("markdown", "")))
	var hints := _priority_hints(note.get("priority_hints", note.get("priority_bias", {})))
	return {
		"note_id": _limit_text(str(note.get("note_id", note.get("id", ""))), 120),
		"reflection_id": _limit_text(str(note.get("reflection_id", "")), 120),
		"summary_id": _limit_text(str(note.get("summary_id", "")), 120),
		"title": _limit_text(str(note.get("title", "Ari's rough local reflection")), 120),
		"markdown_text": _limit_text(markdown_text, 2000),
		"markdown": _limit_text(str(note.get("markdown", markdown_text)), 2000),
		"hypothesis": _limit_text(str(note.get("hypothesis", "")), 300),
		"tags": _string_array(note.get("tags", []), 8, 40),
		"priority_hints": hints,
		"priority_bias": hints,
		"doctrines": _doctrines(note.get("doctrines", [])),
		"confidence": clampf(float(note.get("confidence", 0.45)), 0.0, 1.0),
		"thought": _limit_text(str(note.get("thought", "")), 300),
		"created_day": int(note.get("created_day", 0)),
		"source": _limit_text(str(note.get("source", "")), 64),
		"failure_reason": _limit_text(str(note.get("failure_reason", "")), 64),
		"origin": _limit_text(str(note.get("origin", "")), 80),
		"evidence_ids": _string_array(note.get("evidence_ids", note.get("evidence_snapshot_ids", [])), 20, 120),
		"behavior_evidence": _behavior_evidence_array(note.get("behavior_evidence", []), 3),
	}


func _priority_hints(value) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	for key in value.keys():
		result[_limit_text(str(key), 80)] = clampf(float(value[key]), 0.0, 1.0)
	return result


func _doctrines(value) -> Array:
	var doctrine_validator := AriDoctrine.new()
	return doctrine_validator.add_doctrines(value)


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


func _behavior_evidence_array(value, max_count: int) -> Array:
	var result := []
	if typeof(value) == TYPE_DICTIONARY:
		var evidence := _validate_behavior_evidence(value)
		if not evidence.is_empty():
			result.append(evidence)
		return result
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		var evidence := _validate_behavior_evidence(item)
		if not evidence.is_empty():
			result.append(evidence)
		if result.size() >= max_count:
			break
	return result


func _validate_behavior_evidence(value) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var pattern := _limit_text(str(value.get("primary_pattern", "")), 80)
	if pattern == "":
		return {}
	var progress = value.get("progress_delta", {})
	var context = value.get("context", {})
	return {
		"schema": "ari.behavior_evidence.v1",
		"window_seconds": clampf(float(value.get("window_seconds", 0.0)), 0.0, 120.0),
		"primary_pattern": pattern,
		"actions_seen": _string_array(value.get("actions_seen", []), 8, 80),
		"transition_count": max(0, int(value.get("transition_count", 0))),
		"completion_count": max(0, int(value.get("completion_count", 0))),
		"blocked_count": max(0, int(value.get("blocked_count", 0))),
		"abandoned_count": max(0, int(value.get("abandoned_count", 0))),
		"progress_delta": progress.duplicate(true) if typeof(progress) == TYPE_DICTIONARY else {},
		"context": context.duplicate(true) if typeof(context) == TYPE_DICTIONARY else {},
		"evidence_ids": _string_array(value.get("evidence_ids", []), 12, 120),
		"neutral_summary": _limit_text(str(value.get("neutral_summary", "")), 220),
	}


func _thought_for_event(event_type: String) -> String:
	match event_type:
		"wall_destroyed", "structure_destroyed":
			return "The wall failed because it was weak, not because walls are useless."
		"tower_ranged_success", "ari_ranged_hit":
			return "The tower saved me from teeth, not wings."
	return "I wrote it down. Maybe I will believe it when I sleep."


func _limit_text(text: String, max_length: int) -> String:
	var cleaned := text.strip_edges()
	return cleaned if cleaned.length() <= max_length else cleaned.substr(0, max_length)
