extends SceneTree

const SignPanelScene := preload("res://scenes/ui/SignPanel.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sign_panel := SignPanelScene.instantiate()
	root.add_child(sign_panel)
	await process_frame

	_test_sign_panel_groups_sign_and_ai(sign_panel)
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


func _test_sign_panel_groups_sign_and_ai(sign_panel: Node) -> void:
	_assert(sign_panel.find_child("SignHeaderLabel", true, false) != null, "SignPanel should group the written sign under a Sign header")
	_assert(sign_panel.find_child("AIHeaderLabel", true, false) != null, "SignPanel should group interpretation state under an AI header")
	_assert(sign_panel.find_child("ContextRow", true, false) == null, "SignPanel should not duplicate Ari/run context from the HUD")
	_assert(sign_panel.find_child("AriContextLabel", true, false) == null, "SignPanel should leave Ari state to the HUD")
	_assert(sign_panel.find_child("RunContextLabel", true, false) == null, "SignPanel should leave build/run state to the HUD")
	_assert(sign_panel.find_child("ReadingLabel", true, false) != null, "SignPanel should have a dedicated sign reading label")
	_assert(sign_panel.find_child("TheoryLabel", true, false) != null, "SignPanel should show survival theory as sign/AI state")
	_assert(sign_panel.find_child("PlanLabel", true, false) != null, "SignPanel should show the top grounded plan as its own line")
	_assert(sign_panel.find_child("InterpretationLabel", true, false) == null, "SignPanel should not use one combined multiline interpretation label")


func _test_sign_panel_keeps_long_readings_bounded(sign_panel: Node) -> void:
	sign_panel.call("update_state", {
		"sign_text": "build stone walls before night",
		"sign_interpretation": "Ari reads stone and protection, then decides that walls matter more than anything else until the dark arrives and teeth start pressing against the outer edge.",
		"run_build": {"preset_name": "Fast Coward", "role": "Kite and calm", "tags": ["move 7", "fear 3", "building 2"]},
		"ai_survival_theory": "Use existing cover instead of adding stone.",
		"ai_top_grounded_plan": "use_existing_wall: Keep the wall between Ari and teeth.",
		"sign_strength": 0.91,
		"sign_resonance": 0.97,
	})
	await process_frame

	var sign_header_label: Label = sign_panel.find_child("SignHeaderLabel", true, false)
	var ai_header_label: Label = sign_panel.find_child("AIHeaderLabel", true, false)
	var sign_label: Label = sign_panel.find_child("SignLabel", true, false)
	var reading_label: Label = sign_panel.find_child("ReadingLabel", true, false)
	var theory_label: Label = sign_panel.find_child("TheoryLabel", true, false)
	var plan_label: Label = sign_panel.find_child("PlanLabel", true, false)
	if sign_header_label == null or ai_header_label == null or sign_label == null or reading_label == null or theory_label == null or plan_label == null:
		return
	_assert(sign_header_label.text == "SIGN", "Sign header should be short and scannable")
	_assert(ai_header_label.text == "AI", "AI header should be short and scannable")
	_assert(not sign_label.text.begins_with("The sign says:"), "Sign text should not repeat the Sign header")
	_assert(reading_label.text.begins_with("Meaning: "), "Reading line should have a clear scan prefix")
	_assert(reading_label.text.length() <= 104, "Reading line should be bounded so it does not press into the footer")
	_assert(theory_label.text.begins_with("Theory: "), "Theory line should have a short scan prefix")
	_assert(theory_label.text.length() <= 104, "Theory line should be bounded")
	_assert(plan_label.text.begins_with("Plan: "), "Grounded plan line should have a short scan prefix")
	_assert(plan_label.text.length() <= 104, "Grounded plan line should be bounded")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
