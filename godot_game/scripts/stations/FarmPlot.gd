class_name FarmPlot
extends Node2D

@export var harvest_interval_seconds := 2.0
@export var food_per_cycle := 1
@export var size := Vector2(56.0, 36.0)
@export var work_spot_offset := Vector2(-52.0, 0.0)

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


func get_work_spot() -> Vector2:
	return global_position + work_spot_offset


func farm(delta: float, resource_system: Node) -> int:
	set_active(true)
	_progress += maxf(delta, 0.0)
	var produced := 0
	var interval := maxf(harvest_interval_seconds, 0.1)
	while _progress >= interval:
		_progress -= interval
		produced += food_per_cycle
	if produced > 0 and resource_system != null and resource_system.has_method("add_food"):
		resource_system.call("add_food", produced)
	queue_redraw()
	return produced


func get_progress_ratio() -> float:
	if harvest_interval_seconds <= 0.0:
		return 1.0
	return clampf(_progress / harvest_interval_seconds, 0.0, 1.0)


func get_activity_state() -> Dictionary:
	return {
		"kind": "farm",
		"active": _active,
		"progress": get_progress_ratio() if _active else 0.0,
	}


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	if _active:
		_pulse = fmod(_pulse + maxf(delta, 0.0) * 2.8, 1000.0)
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	draw_rect(rect, Color(0.19, 0.33, 0.18, 1.0), true)
	draw_rect(rect, Color(0.58, 0.78, 0.44, 1.0), false, 2.0)
	for x in [-16.0, 0.0, 16.0]:
		draw_line(Vector2(x, -size.y * 0.42), Vector2(x, size.y * 0.42), Color(0.42, 0.58, 0.26, 1.0), 2.0)
		draw_circle(Vector2(x, -6.0), 4.0, Color(0.76, 0.92, 0.45, 1.0))
		draw_circle(Vector2(x, 8.0), 4.0, Color(0.92, 0.72, 0.34, 1.0))
	if _active:
		_draw_growth_cues()
		var width := size.x
		var bar_position := Vector2(-width * 0.5, size.y * 0.5 + 9.0)
		draw_rect(Rect2(bar_position, Vector2(width, 5.0)), Color(0.06, 0.08, 0.05, 0.9), true)
		draw_rect(Rect2(bar_position, Vector2(width * get_progress_ratio(), 5.0)), Color(0.82, 0.95, 0.42, 1.0), true)


func _draw_growth_cues() -> void:
	var progress := get_progress_ratio()
	draw_rect(Rect2(-size * 0.5, size), Color(0.42, 0.82, 0.30, 0.08 + progress * 0.08), true)
	for i in range(3):
		var x := -16.0 + float(i) * 16.0
		var bob := sin(_pulse + float(i) * 0.8) * 2.0
		var top := Vector2(x, -14.0 - progress * 8.0 + bob)
		draw_line(Vector2(x, 4.0), top, Color(0.74, 0.94, 0.38, 0.80), 1.8)
		draw_circle(top + Vector2(-3.0, 2.0), 3.0, Color(0.72, 0.94, 0.38, 0.72))
		draw_circle(top + Vector2(3.0, 2.0), 3.0, Color(0.92, 0.78, 0.30, 0.72))
