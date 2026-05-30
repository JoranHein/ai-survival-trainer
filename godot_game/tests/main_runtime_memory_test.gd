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
	var ari: Dictionary = latest_snapshot.get("ari", {})
	var world: Dictionary = latest_snapshot.get("world", {})

	_assert(snapshots.size() >= 10, "Main should record a runtime snapshot every simulated second")
	_assert(latest_snapshot.get("time", -1.0) >= 10.0, "runtime snapshots should include elapsed time")
	_assert(["morning", "midday", "dusk", "night"].has(latest_snapshot.get("phase", "")), "runtime snapshots should include the current survival phase")
	_assert(latest_snapshot.get("day", 0) == main.current_day, "runtime snapshots should include the current survival day")
	_assert(ari.get("hp", -1) == main.ari_hp, "runtime snapshots should include real Ari HP")
	_assert(ari.get("fear", -1) == main.ari_fear, "runtime snapshots should include real Ari fear")
	_assert(ari.get("hunger", -1) == main.ari_hunger, "runtime snapshots should include real Ari hunger")
	_assert(ari.get("stamina", -1) == main.ari_stamina, "runtime snapshots should include real Ari stamina")
	_assert(ari.get("current_action", "") == main.ari_current_action, "runtime snapshots should include Ari's real current action")
	_assert(world.get("enemy_count", -1) == main.world_enemy_count, "runtime snapshots should include real enemy count")
	_assert(world.get("stone", -1) == 0, "runtime snapshots should keep unimplemented stone at zero")
	_assert(world.get("wall_count", -1) == 0, "runtime snapshots should keep unimplemented wall count at zero")
	_assert(world.get("aura_orb_count", -1) == 0, "runtime snapshots should keep unimplemented aura orb count at zero")
	_assert(main.chronicle.get_lifetime_scribe_notes().size() >= 2, "Main should auto-create scribe notes every five simulated seconds")
	_assert(text.contains("Day:"), "survival UI should show day")
	_assert(text.contains("Ari HP:"), "survival UI should show Ari HP")
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
	var text := ""
	if main.has_node("%SurvivalLabel"):
		text += main.get_node("%SurvivalLabel").text + "\n"
	if main.has_node("%DebugLabel"):
		text += main.get_node("%DebugLabel").text
	return text


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
