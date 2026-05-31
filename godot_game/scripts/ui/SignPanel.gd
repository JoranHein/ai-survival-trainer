class_name SignPanel
extends CanvasLayer

signal sign_committed(text: String)
signal sign_cancelled

@onready var editor_panel: PanelContainer = %EditorPanel
@onready var sign_text_edit: TextEdit = %SignTextEdit
@onready var commit_button: Button = %CommitButton
@onready var cancel_button: Button = %CancelButton
@onready var sign_label: Label = %SignLabel
@onready var interpretation_label: Label = %InterpretationLabel
@onready var confusion_label: Label = %ConfusionLabel

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
	var run_build_summary := str(state.get("run_build_summary", "Balanced"))
	var confusion := clampf(float(state.get("sign_confusion", 1.0)), 0.0, 1.0)

	sign_label.text = "Sign: %s" % _display_sign_text(_current_sign_text)
	interpretation_label.text = "%s\nBuild: %s\nAri reads: %s" % [personality_summary, run_build_summary, interpretation]
	confusion_label.text = "Confusion: %d%%" % int(round(confusion * 100.0))


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
