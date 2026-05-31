class_name ThoughtBubble
extends Node2D

@export var follow_offset := Vector2(0.0, -128.0)
@export var lifetime_seconds := 4.0
@export var fade_seconds := 0.8
@export var cooldown_seconds := 1.0
@export var pointer_color := Color(0.90, 0.96, 1.0, 0.82)

@onready var thought_label: Label = %ThoughtLabel

var _target: Node2D
var _time_left := 0.0
var _cooldown_left := 0.0
var _last_text := ""


func _ready() -> void:
	visible = false


func follow(target: Node2D) -> void:
	_target = target
	_update_follow_position()


func show_thought(text: String, force := false) -> void:
	var clean_text := text.strip_edges()
	if clean_text == "":
		return
	if not force and _cooldown_left > 0.0:
		return
	if not force and visible and clean_text == _last_text:
		return

	_last_text = clean_text
	thought_label.text = clean_text
	_time_left = lifetime_seconds
	_cooldown_left = cooldown_seconds
	visible = true
	modulate.a = 1.0
	_update_follow_position()
	queue_redraw()


func clear() -> void:
	visible = false
	_time_left = 0.0
	_cooldown_left = 0.0
	_last_text = ""
	thought_label.text = ""
	queue_redraw()


func get_current_text() -> String:
	return _last_text if visible else ""


func _process(delta: float) -> void:
	_update_follow_position()
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if not visible:
		return

	_time_left -= delta
	if _time_left <= 0.0:
		visible = false
		queue_redraw()
		return

	if fade_seconds > 0.0 and _time_left < fade_seconds:
		modulate.a = clampf(_time_left / fade_seconds, 0.0, 1.0)


func _update_follow_position() -> void:
	if is_instance_valid(_target):
		var desired := _target.global_position + follow_offset
		var viewport_size := get_viewport_rect().size
		if viewport_size.x > 0.0 and viewport_size.y > 0.0:
			var reserved_right_ui := 595.0
			var min_x := 170.0
			var max_x := maxf(min_x, viewport_size.x - reserved_right_ui)
			var min_y := minf(viewport_size.y - 150.0, 430.0)
			var max_y := maxf(min_y, viewport_size.y - 112.0)
			desired.x = clampf(desired.x, min_x, max_x)
			desired.y = clampf(desired.y, min_y, max_y)
		global_position = desired
		queue_redraw()


func _draw() -> void:
	if not visible or not is_instance_valid(_target):
		return
	var target_local := to_local(_target.global_position)
	draw_line(Vector2(0.0, -8.0), target_local + Vector2(0.0, -14.0), pointer_color, 2.0)
	draw_circle(target_local + Vector2(0.0, -14.0), 3.0, pointer_color)
