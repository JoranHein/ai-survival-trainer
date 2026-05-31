class_name SignPanel
extends CanvasLayer

signal sign_committed(text: String)
signal sign_cancelled

@onready var editor_panel: PanelContainer = %EditorPanel
@onready var sign_text_edit: TextEdit = %SignTextEdit
@onready var commit_button: Button = %CommitButton
@onready var cancel_button: Button = %CancelButton
@onready var sign_label: Label = %SignLabel
@onready var ari_context_label: Label = %AriContextLabel
@onready var run_context_label: Label = %RunContextLabel
@onready var reading_label: Label = %ReadingLabel
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
	var personality_summary := str(state.get("personality_summary", "Ari: balanced"))
	var sign_strength := clampf(float(state.get("sign_strength", 0.0)), 0.0, 1.0)
	var resonance := clampf(float(state.get("sign_resonance", 0.0)), 0.0, 1.0)

	sign_label.text = "The sign says:\n\"%s\"" % _display_sign_text(_current_sign_text)
	ari_context_label.text = _limit_text("Ari: %s" % personality_summary.trim_prefix("Ari: "), 34)
	run_context_label.text = _limit_text("Run: %s" % _compact_run_build_line(state), 42)
	reading_label.text = "Reads: %s" % _limit_text(interpretation, 91)
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


func _compact_run_build_line(state: Dictionary) -> String:
	var run_build = state.get("run_build", {})
	if typeof(run_build) != TYPE_DICTIONARY:
		return str(state.get("run_build_summary", "Balanced"))
	var name := str(run_build.get("preset_name", state.get("run_build_name", "Balanced")))
	var tags := _format_tags(run_build.get("tags", []), 1)
	if tags != "":
		return "%s | %s" % [name, tags]
	var role := str(run_build.get("role", "")).strip_edges()
	if role != "":
		return "%s - %s" % [name, role]
	return name


func _limit_text(text: String, max_length: int) -> String:
	if text.length() <= max_length:
		return text
	return text.substr(0, max_length - 3).strip_edges() + "..."


func _format_tags(raw_tags, limit := 3) -> String:
	if typeof(raw_tags) != TYPE_ARRAY:
		return ""
	var tags := PackedStringArray()
	for raw_tag in raw_tags:
		var clean_tag := str(raw_tag).strip_edges()
		if clean_tag == "":
			continue
		tags.append(clean_tag)
		if tags.size() >= limit:
			break
	return ", ".join(tags)
