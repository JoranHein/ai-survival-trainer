class_name MineNode
extends Node2D

@export var mine_interval_seconds := 1.25
@export var stone_per_cycle := 1
@export var radius := 24.0

var _progress := 0.0
var _active := false


func reset_run() -> void:
	_progress = 0.0
	set_active(false)


func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	queue_redraw()


func mine(delta: float, resource_system: Node) -> bool:
	set_active(true)
	_progress += maxf(delta, 0.0)
	var produced := false
	var interval := maxf(mine_interval_seconds, 0.1)
	while _progress >= interval:
		_progress -= interval
		if resource_system != null and resource_system.has_method("add_stone"):
			resource_system.call("add_stone", stone_per_cycle)
			produced = true
	queue_redraw()
	return produced


func get_progress_ratio() -> float:
	if mine_interval_seconds <= 0.0:
		return 1.0
	return clampf(_progress / mine_interval_seconds, 0.0, 1.0)


func _ready() -> void:
	z_index = 1


func _draw() -> void:
	var base_color := Color(0.36, 0.35, 0.34, 1.0)
	var active_color := Color(0.58, 0.55, 0.50, 1.0)
	draw_circle(Vector2.ZERO, radius, active_color if _active else base_color)
	draw_circle(Vector2(-8.0, -6.0), radius * 0.42, Color(0.48, 0.49, 0.47, 1.0))
	draw_circle(Vector2(9.0, 7.0), radius * 0.36, Color(0.25, 0.26, 0.25, 1.0))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.78, 0.76, 0.70, 1.0), 2.0)
	if _active:
		var width := radius * 1.7
		var bar_position := Vector2(-width * 0.5, radius + 8.0)
		draw_rect(Rect2(bar_position, Vector2(width, 5.0)), Color(0.08, 0.09, 0.08, 0.9), true)
		draw_rect(Rect2(bar_position, Vector2(width * get_progress_ratio(), 5.0)), Color(0.84, 0.86, 0.72, 1.0), true)
