extends SceneTree

const MainScene := preload("res://scenes/main/Main.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Control = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	_test_initial_control_text(main)
	_press_key(main, KEY_1)
	await process_frame
	_test_scribe_requested(main)

	_press_key(main, KEY_2)
	await process_frame
	_test_reflection_requested(main)

	_press_key(main, KEY_3)
	await process_frame
	_test_sleep_requested(main)

	_press_key(main, KEY_4)
	await process_frame
	_test_life_summary_requested(main)

	_press_key(main, KEY_5)
	await process_frame
	_test_wisdom_requested(main)

	if failures.is_empty():
		print("Main controls tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


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


func _test_initial_control_text(main: Control) -> void:
	var text := _label_text(main)
	_assert(not text.contains("F6"), "debug instructions should not mention F6")
	_assert(not text.contains("F10"), "debug instructions should not mention F10")
	_assert(text.contains("1 = create fake scribe note"), "debug instructions should show key 1 for scribe")
	_assert(text.contains("2 = request library reflection"), "debug instructions should show key 2 for reflection")
	_assert(text.contains("3 = request sleep plan"), "debug instructions should show key 3 for sleep")
	_assert(text.contains("4 = request life summary"), "debug instructions should show key 4 for life summary")
	_assert(text.contains("5 = request wisdom synthesis"), "debug instructions should show key 5 for wisdom")


func _test_scribe_requested(main: Control) -> void:
	var text := _label_text(main)
	_assert(text.contains("1: Scribe note requested"), "pressing 1 should show scribe request confirmation")
	_assert(text.contains("Scribe notes: 1"), "pressing 1 should increase scribe note count")
	_assert(text.contains("Latest scribe:"), "pressing 1 should show latest scribe note")


func _test_reflection_requested(main: Control) -> void:
	var text := _label_text(main)
	_assert(text.contains("2: Library reflection requested"), "pressing 2 should show reflection request confirmation")
	_assert(text.contains("Lesson notes: 1"), "pressing 2 should increase lesson note count")
	_assert(text.contains("Latest reflection:"), "pressing 2 should show latest reflection title")


func _test_sleep_requested(main: Control) -> void:
	var text := _label_text(main)
	_assert(text.contains("3: Sleep plan requested"), "pressing 3 should show sleep request confirmation")
	_assert(text.contains("Latest sleep:"), "pressing 3 should show latest sleep thought")


func _test_life_summary_requested(main: Control) -> void:
	var text := _label_text(main)
	_assert(text.contains("4: Life summary requested"), "pressing 4 should show life summary request confirmation")
	_assert(text.contains("Life summaries: 1"), "pressing 4 should increase life summary count")
	_assert(text.contains("Latest life summary:"), "pressing 4 should show latest life summary hint")


func _test_wisdom_requested(main: Control) -> void:
	var text := _label_text(main)
	_assert(text.contains("5: Wisdom synthesis requested"), "pressing 5 should show wisdom request confirmation")
	_assert(text.contains("Latest wisdom:"), "pressing 5 should show latest wisdom count")
