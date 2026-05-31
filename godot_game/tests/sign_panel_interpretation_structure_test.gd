extends SceneTree

const SignPanelScene := preload("res://scenes/ui/SignPanel.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sign_panel := SignPanelScene.instantiate()
	root.add_child(sign_panel)
	await process_frame

	_test_sign_panel_splits_context_from_reading(sign_panel)
	await _test_sign_panel_keeps_long_readings_bounded(sign_panel)

	root.remove_child(sign_panel)
	sign_panel.free()

	if failures.is_empty():
		print("Sign panel interpretation structure tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_sign_panel_splits_context_from_reading(sign_panel: Node) -> void:
	_assert(sign_panel.find_child("ContextRow", true, false) != null, "SignPanel should show Ari/run context as a dedicated row")
	_assert(sign_panel.find_child("AriContextLabel", true, false) != null, "SignPanel should have a compact Ari context label")
	_assert(sign_panel.find_child("RunContextLabel", true, false) != null, "SignPanel should have a compact run context label")
	_assert(sign_panel.find_child("ReadingLabel", true, false) != null, "SignPanel should have a dedicated sign reading label")
	_assert(sign_panel.find_child("InterpretationLabel", true, false) == null, "SignPanel should not use one combined multiline interpretation label")


func _test_sign_panel_keeps_long_readings_bounded(sign_panel: Node) -> void:
	sign_panel.call("update_state", {
		"sign_text": "build stone walls before night",
		"sign_interpretation": "Ari reads stone and protection, then decides that walls matter more than anything else until the dark arrives and teeth start pressing against the outer edge.",
		"personality_summary": "Ari: brave, practical, sign-faithful",
		"run_build": {"preset_name": "Fast Coward", "role": "Kite and calm", "tags": ["move 7", "fear 3", "building 2"]},
		"sign_strength": 0.91,
		"sign_resonance": 0.97,
	})
	await process_frame

	var ari_context_label: Label = sign_panel.find_child("AriContextLabel", true, false)
	var run_context_label: Label = sign_panel.find_child("RunContextLabel", true, false)
	var reading_label: Label = sign_panel.find_child("ReadingLabel", true, false)
	if ari_context_label == null or run_context_label == null or reading_label == null:
		return
	_assert(not ari_context_label.text.contains("\n"), "Ari context should stay on one line")
	_assert(not run_context_label.text.contains("\n"), "Run context should stay on one line")
	_assert(ari_context_label.text.length() <= 34, "Ari context should be compact")
	_assert(run_context_label.text.length() <= 42, "Run context should be compact")
	_assert(reading_label.text.begins_with("Reads: "), "Reading line should have a short scan prefix")
	_assert(reading_label.text.length() <= 98, "Reading line should be bounded so it does not press into the footer")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
