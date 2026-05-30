class_name AriMemory
extends RefCounted

const MAX_EVENTS := 300
const MAX_SNAPSHOTS := 80

var events: Array = []
var snapshots: Array = []


func record_event(event_type: String, data: Dictionary = {}) -> void:
	var event := data.duplicate(true)
	event["type"] = event_type
	if not event.has("timestamp"):
		event["timestamp"] = Time.get_ticks_msec() / 1000.0
	events.append(event)
	_trim_array(events, MAX_EVENTS)


func record_snapshot(snapshot: Dictionary) -> void:
	var safe_snapshot := snapshot.duplicate(true)
	if not safe_snapshot.has("timestamp"):
		safe_snapshot["timestamp"] = Time.get_ticks_msec() / 1000.0
	snapshots.append(safe_snapshot)
	_trim_array(snapshots, MAX_SNAPSHOTS)


func get_recent_events(max_count: int = 50) -> Array:
	return _recent_copy(events, max_count)


func get_recent_snapshots(max_count: int = 10) -> Array:
	return _recent_copy(snapshots, max_count)


func clear_day_memory() -> void:
	events.clear()
	snapshots.clear()


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
