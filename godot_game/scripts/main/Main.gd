extends Node

@onready var world: Node = $World
@onready var hud: CanvasLayer = $HUD
@onready var sign_panel: SignPanel = $SignPanel
@onready var screenshot_capture: Node = $ScreenshotCapture
@onready var visual_review_scenario: Node = $VisualReviewScenario

var _quit_when_visual_review_done := false


func _ready() -> void:
	world.state_changed.connect(_on_world_state_changed)
	sign_panel.sign_committed.connect(_on_sign_committed)
	visual_review_scenario.scenario_finished.connect(_on_visual_review_scenario_finished)
	visual_review_scenario.setup(world, screenshot_capture)
	world.start_run()
	call_deferred("_run_command_line_debug_actions")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if sign_panel.is_editing():
			if event.keycode == KEY_T:
				sign_panel.focus_editor()
				get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_T:
			sign_panel.open_editor(str(world.call("get_current_sign_text")))
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:
			world.restart_run()
		# Debug tooling: P saves one screenshot of the current viewport.
		elif event.keycode == KEY_P:
			_capture_manual_screenshot()
		# Debug tooling: V stages and captures the visual review scenario set.
		elif event.keycode == KEY_V:
			visual_review_scenario.start_sequence()


func _on_world_state_changed(state: Dictionary) -> void:
	hud.update_state(state)
	sign_panel.update_state(state)


func _on_sign_committed(text: String) -> void:
	world.call("commit_sign", text)


func _on_visual_review_scenario_finished(_paths: Array) -> void:
	if not _quit_when_visual_review_done:
		return
	print("Visual review complete; quitting.")
	get_tree().quit(0)


func _capture_manual_screenshot() -> void:
	var path: String = await screenshot_capture.capture("manual")
	if path != "":
		print("Manual screenshot captured: ", path)


func _run_command_line_debug_actions() -> void:
	var args := OS.get_cmdline_args()
	args.append_array(OS.get_cmdline_user_args())
	if args.has("--visual-review"):
		_quit_when_visual_review_done = true
		visual_review_scenario.start_sequence()
