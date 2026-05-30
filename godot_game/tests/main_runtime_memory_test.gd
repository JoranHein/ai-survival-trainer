extends SceneTree

const MainScene := preload("res://scenes/main/Main.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Control = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	_test_runtime_memory_accumulates(main)
	_test_debug_keys_use_accumulated_memory(main)

	if failures.is_empty():
		print("Main runtime memory tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_runtime_memory_accumulates(main: Control) -> void:
	_assert(main.has_method("advance_runtime_memory"), "Main should expose deterministic runtime memory stepping")
	if not main.has_method("advance_runtime_memory"):
		return

	for i in range(10):
		main.advance_runtime_memory(1.0)
	await process_frame

	var snapshots: Array = main.memory.get_recent_snapshots(20)
	var latest_snapshot: Dictionary = snapshots[snapshots.size() - 1] if not snapshots.is_empty() else {}
	var text := _label_text(main)

	_assert(snapshots.size() >= 10, "Main should record a runtime snapshot every simulated second")
	_assert(latest_snapshot.get("time", -1.0) >= 10.0, "runtime snapshots should include elapsed time")
	_assert(latest_snapshot.get("phase", "") == "debug", "runtime snapshots should use safe default phase")
	_assert(latest_snapshot.get("day", 0) == 1, "runtime snapshots should include safe default day")
	_assert(latest_snapshot.get("ari", {}).get("hp", -1) == 100.0, "runtime snapshots should include safe default Ari HP")
	_assert(latest_snapshot.get("ari", {}).get("fear", -1) == 0.0, "runtime snapshots should include safe default Ari fear")
	_assert(latest_snapshot.get("ari", {}).get("hunger", -1) == 0.0, "runtime snapshots should include safe default Ari hunger")
	_assert(latest_snapshot.get("ari", {}).get("stamina", -1) == 100.0, "runtime snapshots should include safe default Ari stamina")
	_assert(latest_snapshot.get("ari", {}).get("current_action", "") == "debug_idle", "runtime snapshots should use safe default Ari action")
	_assert(latest_snapshot.get("world", {}).get("enemy_count", -1) == 0, "runtime snapshots should include safe world defaults")
	_assert(latest_snapshot.get("world", {}).get("stone", -1) == 0, "runtime snapshots should include safe default stone")
	_assert(latest_snapshot.get("world", {}).get("wall_count", -1) == 0, "runtime snapshots should include safe default wall count")
	_assert(latest_snapshot.get("world", {}).get("aura_orb_count", -1) == 0, "runtime snapshots should include safe default aura orb count")
	_assert(main.chronicle.get_lifetime_scribe_notes().size() >= 2, "Main should auto-create scribe notes every five simulated seconds")
	_assert(text.contains("Snapshots:"), "debug UI should show snapshot count")
	_assert(text.contains("Memory events:"), "debug UI should show memory event count")
	_assert(text.contains("Latest scribe:"), "debug UI should show latest automatic scribe note")


func _test_debug_keys_use_accumulated_memory(main: Control) -> void:
	var notes_before: int = main.lesson_book.get_all_notes().size()
	_press_key(main, KEY_2)
	await process_frame
	_assert(main.lesson_book.get_all_notes().size() == notes_before + 1, "key 2 should create a lesson from accumulated notes")

	_press_key(main, KEY_3)
	await process_frame
	_assert(_label_text(main).contains("Latest sleep: I read the last note again."), "key 3 should use accumulated lesson notes for sleep plan")

	var summaries_before: int = main.life_archive.get_all_life_summaries().size()
	_press_key(main, KEY_4)
	await process_frame
	_assert(main.life_archive.get_all_life_summaries().size() == summaries_before + 1, "key 4 should archive a life summary from accumulated memory")

	_press_key(main, KEY_5)
	await process_frame
	_assert(_label_text(main).contains("Latest wisdom: 1 permanent insight(s)"), "key 5 should synthesize wisdom without crashing")


func _press_key(main: Control, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	main._unhandled_input(event)


func _label_text(main: Control) -> String:
	return main.get_node("%DebugLabel").text


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
