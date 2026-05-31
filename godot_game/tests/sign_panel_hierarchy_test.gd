extends SceneTree

const SignPanelScene := preload("res://scenes/ui/SignPanel.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sign_panel := SignPanelScene.instantiate()
	root.add_child(sign_panel)
	await process_frame

	_test_sign_panel_has_dedicated_signal_footer(sign_panel)
	await _test_signal_footer_updates_as_two_scan_tokens(sign_panel)

	root.remove_child(sign_panel)
	sign_panel.free()

	if failures.is_empty():
		print("Sign panel hierarchy tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_sign_panel_has_dedicated_signal_footer(sign_panel: Node) -> void:
	_assert(sign_panel.find_child("SignalSeparator", true, false) != null, "SignPanel should separate interpretation from signal footer")
	_assert(sign_panel.find_child("SignalRow", true, false) != null, "SignPanel should use a footer row for signal values")
	_assert(sign_panel.find_child("SignalLabel", true, false) != null, "SignPanel should have a dedicated signal label")
	_assert(sign_panel.find_child("ResonanceLabel", true, false) != null, "SignPanel should have a dedicated resonance label")
	_assert(sign_panel.find_child("StrengthLabel", true, false) == null, "SignPanel should not use a combined strength label")


func _test_signal_footer_updates_as_two_scan_tokens(sign_panel: Node) -> void:
	sign_panel.call("update_state", {
		"sign_text": "build stone walls before night",
		"sign_interpretation": "Ari reads stone and protection.",
		"personality_summary": "Ari: careful",
		"run_build": {"preset_name": "Balanced", "role": "Flexible prep", "tags": ["building 2", "mining 2"]},
		"sign_strength": 0.82,
		"sign_resonance": 0.64,
	})
	await process_frame
	var signal_label: Label = sign_panel.find_child("SignalLabel", true, false)
	var resonance_label: Label = sign_panel.find_child("ResonanceLabel", true, false)
	if signal_label == null or resonance_label == null:
		return
	_assert(signal_label.text == "SIGNAL 82%", "signal footer should show a compact signal token")
	_assert(resonance_label.text == "RESONANCE 64%", "signal footer should show a compact resonance token")
	_assert(not signal_label.text.contains("|"), "signal token should not use pipe separators")
	_assert(not resonance_label.text.contains("|"), "resonance token should not use pipe separators")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
