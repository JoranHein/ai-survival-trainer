class_name SignPanel
extends CanvasLayer

signal sign_committed(text: String)
signal sign_cancelled

@onready var editor_panel: PanelContainer = %EditorPanel
@onready var sign_text_edit: TextEdit = %SignTextEdit
@onready var commit_button: Button = %CommitButton
@onready var cancel_button: Button = %CancelButton
@onready var sign_label: Label = %SignLabel
@onready var reading_label: Label = %ReadingLabel
@onready var theory_label: Label = %TheoryLabel
@onready var plan_label: Label = %PlanLabel
@onready var ai_status_label: Label = %AiStatusLabel
@onready var signal_label: Label = %SignalLabel
@onready var resonance_label: Label = %ResonanceLabel

var _editing := false
var _current_sign_text := ""


func _ready() -> void:
	editor_panel.visible = false
	sign_text_edit.gui_input.connect(_on_sign_text_edit_gui_input)
	commit_button.pressed.connect(_commit_edit)
	cancel_button.pressed.connect(cancel_edit)
	update_state({})


func update_state(state: Dictionary) -> void:
	_current_sign_text = str(state.get("sign_text", _current_sign_text))
	var interpretation := str(state.get("sign_interpretation", "No sign yet."))
	var survival_theory := str(state.get("ai_survival_theory", "")).strip_edges()
	var top_plan := str(state.get("ai_top_grounded_plan", "")).strip_edges()
	var top_hint := str(state.get("ai_top_hint", "")).strip_edges()
	var ai_status := str(state.get("ai_status", "AI disabled")).strip_edges()
	var sign_strength := clampf(float(state.get("sign_strength", 0.0)), 0.0, 1.0)
	var resonance := clampf(float(state.get("sign_resonance", 0.0)), 0.0, 1.0)
	var plan_text := top_plan if top_plan != "" else _plan_text_from_hint(top_hint)
	if plan_text == "":
		plan_text = "watch and survive"
	if ai_status == "":
		ai_status = "AI disabled"

	sign_label.text = "\"%s\"" % _limit_text(_display_sign_text(_current_sign_text), 116)
	reading_label.text = "Meaning: %s" % _limit_text(interpretation, 95)
	theory_label.text = "Theory: %s" % _limit_text(survival_theory if survival_theory != "" else "local reading", 96)
	plan_label.text = "Plan: %s" % _limit_text(plan_text, 98)
	ai_status_label.text = ai_status
	ai_status_label.visible = true
	_apply_ai_status_style(ai_status)
	signal_label.text = "SIGNAL %d%%" % int(round(sign_strength * 100.0))
	resonance_label.text = "RESONANCE %d%%" % int(round(resonance * 100.0))


func open_editor(current_text := "") -> void:
	_editing = true
	editor_panel.visible = true
	sign_text_edit.text = current_text if current_text != "" else _current_sign_text
	call_deferred("_focus_editor")


func is_editing() -> bool:
	return _editing


func focus_editor() -> void:
	call_deferred("_focus_editor")


func cancel_edit() -> void:
	if not _editing:
		return
	_editing = false
	editor_panel.visible = false
	sign_cancelled.emit()


func _commit_edit() -> void:
	if not _editing:
		return
	_editing = false
	editor_panel.visible = false
	sign_committed.emit(sign_text_edit.text)


func _focus_editor() -> void:
	sign_text_edit.grab_focus()
	sign_text_edit.select_all()


func _on_sign_text_edit_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_commit_edit()
			sign_text_edit.accept_event()
		elif event.keycode == KEY_ESCAPE:
			cancel_edit()
			sign_text_edit.accept_event()


func _display_sign_text(text: String) -> String:
	var clean_text := text.strip_edges()
	if clean_text == "":
		return "(empty)"
	return clean_text.replace("\n", " / ")


func _limit_text(text: String, max_length: int) -> String:
	if text.length() <= max_length:
		return text
	return text.substr(0, max_length - 3).strip_edges() + "..."


func _apply_ai_status_style(ai_status: String) -> void:
	var status := ai_status.to_lower()
	var color := Color(0.62, 0.68, 0.70, 1.0)
	if status.contains("thinking"):
		color = Color(0.62, 0.86, 1.0, 1.0)
	elif status.contains("cached"):
		color = Color(0.58, 0.96, 0.62, 1.0)
	elif status.contains("active"):
		color = Color(0.76, 1.0, 0.72, 1.0)
	elif status.contains("failed") or status.contains("fallback"):
		color = Color(1.0, 0.74, 0.52, 1.0)
	ai_status_label.add_theme_color_override("font_color", color)


func _plan_text_from_hint(top_hint: String) -> String:
	match top_hint:
		"build_tower", "use_tower", "ranged_attack", "train_bow", "range":
			return "tower range"
		"build_storm_rod", "anti_flying", "sky_answer":
			return "sky answer"
		"place_aura_orb", "lure_to_aura", "aura_orb":
			return "light"
		"use_existing_wall", "wait_behind_wall", "use_cover", "wall", "build_wall":
			return "cover"
		"farm_food", "eat", "eat_food":
			return "food"
		"rest":
			return "rest"
		"reflect_library":
			return "library"
		"train_combat", "prepare_weapon", "fight", "combat_training":
			return "combat"
		"repair", "repair_structure":
			return "repair"
		"build_trap", "build_spike_trap":
			return "traps"
		"mine_stone", "mining":
			return "stone"
	return top_hint.replace("_", " ") if top_hint != "" else ""
