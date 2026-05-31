extends SceneTree

const MindLogScene := preload("res://scenes/ui/MindLog.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var mind_log := MindLogScene.instantiate()
	root.add_child(mind_log)
	await process_frame

	await _test_mind_log_keeps_fewer_higher_signal_thoughts(mind_log)
	await _test_mind_log_truncates_long_lines(mind_log)

	root.remove_child(mind_log)
	mind_log.free()

	if failures.is_empty():
		print("Mind Log priority tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_mind_log_keeps_fewer_higher_signal_thoughts(mind_log: Node) -> void:
	_push_thought(mind_log, "I will listen, then choose what keeps me alive.")
	_push_thought(mind_log, "The sign is strange. I want to understand it.")
	_push_thought(mind_log, "I need a little rest before the dark arrives.")
	_push_thought(mind_log, "That was too close. I need distance, cover, or something that hurts them first.")
	_push_thought(mind_log, "I died. The sign was not enough yet.")
	await process_frame

	var text := _lines_text(mind_log)
	var displayed := text.split("\n", false)
	_assert(displayed.size() <= 3, "Mind Log should show at most three thought lines")
	_assert(text.contains("I died."), "Mind Log should retain death thoughts")
	_assert(text.contains("That was too close."), "Mind Log should retain danger thoughts")
	_assert(text.contains("The sign is strange."), "Mind Log should retain sign interpretation thoughts")
	_assert(not text.contains("I will listen"), "Mind Log should drop low-signal routine thoughts first")
	_assert(not text.contains("little rest"), "Mind Log should drop routine job chatter before high-signal thoughts")


func _test_mind_log_truncates_long_lines(mind_log: Node) -> void:
	_push_thought(mind_log, "The wall broke and the dark got through the gap before I could understand what failed.")
	await process_frame
	var text := _lines_text(mind_log)
	for line in text.split("\n", false):
		_assert(line.length() <= 62, "Mind Log thought lines should stay compact")


func _push_thought(mind_log: Node, thought: String) -> void:
	mind_log.call("update_state", {"latest_thought": thought})


func _lines_text(mind_log: Node) -> String:
	var label: Label = mind_log.get_node("%LinesLabel")
	return label.text


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
