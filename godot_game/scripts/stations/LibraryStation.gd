class_name LibraryStation
extends Node2D

@export var reflection_interval_seconds := 3.0
@export var reflection_spot_offset := Vector2(-54.0, 4.0)
@export var size := Vector2(58.0, 46.0)

var _progress := 0.0
var _active := false
var _pulse := 0.0


func reset_run() -> void:
	_progress = 0.0
	set_active(false)


func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	queue_redraw()


func get_reflection_spot() -> Vector2:
	return global_position + reflection_spot_offset


func reflect(delta: float) -> int:
	set_active(true)
	_progress += maxf(delta, 0.0)
	var completed := 0
	var interval := maxf(reflection_interval_seconds, 0.2)
	while _progress >= interval:
		_progress -= interval
		completed += 1
	queue_redraw()
	return completed


func get_progress_ratio() -> float:
	if reflection_interval_seconds <= 0.0:
		return 1.0
	return clampf(_progress / reflection_interval_seconds, 0.0, 1.0)


func get_activity_state() -> Dictionary:
	return {
		"kind": "reflect",
		"active": _active,
		"progress": get_progress_ratio() if _active else 0.0,
	}


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	if _active:
		_pulse = fmod(_pulse + maxf(delta, 0.0) * 2.4, 1000.0)
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, Color(0.20, 0.17, 0.30, 1.0), true)
	draw_rect(rect, Color(0.72, 0.64, 0.96, 1.0), false, 2.0)
	for i in range(4):
		var x := -size.x * 0.38 + float(i) * 12.0
		var book_height := 22.0 + float(i % 2) * 8.0
		draw_rect(Rect2(Vector2(x, -book_height * 0.5), Vector2(8.0, book_height)), Color(0.50 + float(i) * 0.08, 0.42, 0.82, 1.0), true)
	draw_line(Vector2(-size.x * 0.4, 10.0), Vector2(size.x * 0.4, 10.0), Color(0.86, 0.80, 1.0, 1.0), 2.0)
	draw_line(Vector2(-12.0, -18.0), Vector2(0.0, -10.0), Color(0.92, 0.88, 1.0, 1.0), 3.0)
	draw_line(Vector2(12.0, -18.0), Vector2(0.0, -10.0), Color(0.92, 0.88, 1.0, 1.0), 3.0)
	draw_line(Vector2(0.0, -10.0), Vector2(0.0, 8.0), Color(0.92, 0.88, 1.0, 1.0), 2.0)
	if _active:
		_draw_reflection_cues()
		var width := size.x
		var bar_position := Vector2(-width * 0.5, size.y * 0.5 + 9.0)
		draw_rect(Rect2(bar_position, Vector2(width, 5.0)), Color(0.06, 0.05, 0.10, 0.9), true)
		draw_rect(Rect2(bar_position, Vector2(width * get_progress_ratio(), 5.0)), Color(0.76, 0.68, 1.0, 1.0), true)


func _draw_reflection_cues() -> void:
	var progress := get_progress_ratio()
	var glow := 0.18 + progress * 0.14 + sin(_pulse) * 0.04
	draw_circle(Vector2(0.0, -5.0), 34.0, Color(0.68, 0.58, 1.0, glow))
	for i in range(3):
		var y := -20.0 + float(i) * 9.0
		var width := 10.0 + progress * 12.0 + sin(_pulse + float(i)) * 2.0
		draw_line(Vector2(-width * 0.5, y), Vector2(width * 0.5, y), Color(0.92, 0.88, 1.0, 0.78), 1.4)
