class_name ForgeStation
extends Node2D

@export var smith_interval_seconds := 1.35
@export var radius := 25.0
@export var smith_spot_offset := Vector2(48.0, 10.0)

var _progress := 0.0
var _active := false
var _heat := 0.0


func reset_run() -> void:
	_progress = 0.0
	_heat = 0.0
	set_active(false)


func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	queue_redraw()


func get_smith_spot() -> Vector2:
	return global_position + smith_spot_offset


func smith(delta: float) -> int:
	set_active(true)
	_progress += maxf(delta, 0.0)
	var completed_cycles := 0
	var interval := maxf(smith_interval_seconds, 0.1)
	while _progress >= interval:
		_progress -= interval
		completed_cycles += 1
		_heat = 0.22
	queue_redraw()
	return completed_cycles


func get_progress_ratio() -> float:
	if smith_interval_seconds <= 0.0:
		return 1.0
	return clampf(_progress / smith_interval_seconds, 0.0, 1.0)


func get_activity_state() -> Dictionary:
	return {
		"kind": "forge",
		"active": _active,
		"progress": get_progress_ratio() if _active else 0.0,
	}


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	if _active:
		_heat = maxf(_heat - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	var base_color := Color(0.22, 0.18, 0.15, 1.0)
	var anvil_color := Color(0.40, 0.45, 0.48, 1.0)
	var heat_color := Color(1.0, 0.42, 0.18, 1.0)
	draw_circle(Vector2(4.0, 8.0), radius + 4.0, Color(0.0, 0.0, 0.0, 0.30))
	draw_rect(Rect2(Vector2(-radius, -radius * 0.55), Vector2(radius * 2.0, radius * 1.25)), base_color, true)
	draw_rect(Rect2(Vector2(-radius * 0.72, -radius * 0.38), Vector2(radius * 1.44, radius * 0.76)), Color(0.09, 0.07, 0.06, 1.0), true)
	draw_circle(Vector2.ZERO, radius * 0.44, heat_color if _active else Color(0.42, 0.16, 0.08, 1.0))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.86, 0.54, 0.28, 1.0), 2.2)
	draw_rect(Rect2(Vector2(-16.0, radius * 0.40), Vector2(32.0, 8.0)), anvil_color, true)
	draw_rect(Rect2(Vector2(-7.0, radius * 0.72), Vector2(14.0, 12.0)), anvil_color.darkened(0.16), true)
	if _active:
		var progress := get_progress_ratio()
		draw_circle(Vector2.ZERO, radius + 8.0, Color(1.0, 0.35, 0.12, 0.12 + _heat * 0.35))
		var width := radius * 1.8
		var bar_position := Vector2(-width * 0.5, radius + 16.0)
		draw_rect(Rect2(bar_position, Vector2(width, 5.0)), Color(0.08, 0.05, 0.04, 0.92), true)
		draw_rect(Rect2(bar_position, Vector2(width * progress, 5.0)), Color(1.0, 0.48, 0.18, 1.0), true)
		draw_line(Vector2(-radius - 4.0, -8.0), Vector2(radius + 4.0, 8.0), Color(1.0, 0.68, 0.28, 0.56), 2.0)
