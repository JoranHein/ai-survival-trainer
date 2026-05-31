class_name TrainingDummy
extends Node2D

@export var train_interval_seconds := 1.1
@export var radius := 24.0
@export var training_spot_offset := Vector2(-48.0, 8.0)

var _progress := 0.0
var _active := false
var _hit_flash := 0.0


func reset_run() -> void:
	_progress = 0.0
	_hit_flash = 0.0
	set_active(false)


func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	queue_redraw()


func get_training_spot() -> Vector2:
	return global_position + training_spot_offset


func train(delta: float) -> int:
	set_active(true)
	_progress += maxf(delta, 0.0)
	var completed_cycles := 0
	var interval := maxf(train_interval_seconds, 0.1)
	while _progress >= interval:
		_progress -= interval
		completed_cycles += 1
		_hit_flash = 0.18
	queue_redraw()
	return completed_cycles


func get_progress_ratio() -> float:
	if train_interval_seconds <= 0.0:
		return 1.0
	return clampf(_progress / train_interval_seconds, 0.0, 1.0)


func get_activity_state() -> Dictionary:
	return {
		"kind": "train",
		"active": _active,
		"progress": get_progress_ratio() if _active else 0.0,
	}


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
		queue_redraw()


func _draw() -> void:
	var post_color := Color(0.42, 0.27, 0.13, 1.0)
	var body_color := Color(0.72, 0.52, 0.30, 1.0)
	var active_color := Color(0.92, 0.72, 0.42, 1.0)
	var accent_color := Color(0.18, 0.11, 0.06, 1.0)

	draw_rect(Rect2(Vector2(-5.0, -4.0), Vector2(10.0, 42.0)), post_color, true)
	draw_rect(Rect2(Vector2(-radius * 0.7, -radius), Vector2(radius * 1.4, radius * 1.6)), active_color if _active else body_color, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.95, 0.78, 0.48, 1.0), 2.0)
	draw_line(Vector2(-radius * 0.55, -radius * 0.45), Vector2(radius * 0.55, radius * 0.45), accent_color, 3.0)
	draw_line(Vector2(radius * 0.55, -radius * 0.45), Vector2(-radius * 0.55, radius * 0.45), accent_color, 3.0)
	if _hit_flash > 0.0:
		draw_circle(Vector2.ZERO, radius + 7.0, Color(1.0, 0.85, 0.40, 0.24))

	if _active:
		var progress := get_progress_ratio()
		draw_arc(Vector2.ZERO, radius + 8.0, -PI * 0.35, PI * (0.45 + progress), 32, Color(1.0, 0.74, 0.34, 0.34), 2.0)
		draw_line(Vector2(-radius - 8.0, -radius * 0.65), Vector2(-radius * 0.55, -radius * 0.38), Color(1.0, 0.80, 0.40, 0.50), 1.8)
		draw_line(Vector2(radius + 8.0, -radius * 0.40), Vector2(radius * 0.58, -radius * 0.24), Color(1.0, 0.80, 0.40, 0.50), 1.8)
		var width := radius * 1.8
		var bar_position := Vector2(-width * 0.5, radius + 10.0)
		draw_rect(Rect2(bar_position, Vector2(width, 5.0)), Color(0.08, 0.07, 0.05, 0.9), true)
		draw_rect(Rect2(bar_position, Vector2(width * get_progress_ratio(), 5.0)), Color(0.95, 0.72, 0.32, 1.0), true)
