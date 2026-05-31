extends SceneTree

const SignPanelScene := preload("res://scenes/ui/SignPanel.tscn")
const MindLogScene := preload("res://scenes/ui/MindLog.tscn")
const UpgradePanelScene := preload("res://scenes/ui/UpgradePanel.tscn")

const RIGHT_LEFT := -424.0
const RIGHT_RIGHT := -24.0
const STACK_GAP := 6.0

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sign_panel := SignPanelScene.instantiate()
	var mind_log := MindLogScene.instantiate()
	var upgrade_panel := UpgradePanelScene.instantiate()
	root.add_child(sign_panel)
	root.add_child(mind_log)
	root.add_child(upgrade_panel)
	await process_frame

	_test_right_panel_widths_match(sign_panel, mind_log, upgrade_panel)
	_test_right_panel_gaps_are_consistent(sign_panel, mind_log, upgrade_panel)
	_test_mind_log_has_section_hierarchy(mind_log)

	root.remove_child(sign_panel)
	root.remove_child(mind_log)
	root.remove_child(upgrade_panel)
	sign_panel.free()
	mind_log.free()
	upgrade_panel.free()

	if failures.is_empty():
		print("Right panel stack layout tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_right_panel_widths_match(sign_panel: Node, mind_log: Node, upgrade_panel: Node) -> void:
	var panels := [
		sign_panel.get_node("DisplayPanel"),
		mind_log.get_node("LogPanel"),
		upgrade_panel.get_node("Panel"),
	]
	for panel in panels:
		_assert(is_equal_approx(panel.offset_left, RIGHT_LEFT), "%s should share the right-stack left edge" % panel.name)
		_assert(is_equal_approx(panel.offset_right, RIGHT_RIGHT), "%s should share the right-stack right edge" % panel.name)


func _test_right_panel_gaps_are_consistent(sign_panel: Node, mind_log: Node, upgrade_panel: Node) -> void:
	var sign_display: Control = sign_panel.get_node("DisplayPanel")
	var log_panel: Control = mind_log.get_node("LogPanel")
	var upgrade: Control = upgrade_panel.get_node("Panel")
	_assert(is_equal_approx(log_panel.offset_top - sign_display.offset_bottom, STACK_GAP), "SignPanel and MindLog should have a consistent stack gap")
	_assert(is_equal_approx(upgrade.offset_top - log_panel.offset_bottom, STACK_GAP), "MindLog and UpgradePanel should have a consistent stack gap")


func _test_mind_log_has_section_hierarchy(mind_log: Node) -> void:
	_assert(mind_log.find_child("TitleLabel", true, false) != null, "MindLog should have a dedicated title label")
	_assert(mind_log.find_child("LinesLabel", true, false) != null, "MindLog should have a dedicated thought-lines label")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
