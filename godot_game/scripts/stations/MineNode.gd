class_name MineNode
extends Node2D

@export var mine_interval_seconds := 1.25
@export var stone_per_cycle := 1
@export var ore_per_cycle := 1
@export var ore_interval_cycles := 4
@export var radius := 24.0

var _progress := 0.0
var _active := false
var _ore_mode := false
var _pulse := 0.0
var _stone_cycles_since_ore := 0


func reset_run() -> void:
	_progress = 0.0
	_stone_cycles_since_ore = 0
	set_active(false)


func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	queue_redraw()


func mine(delta: float, resource_system: Node) -> bool:
	set_active(true)
	_ore_mode = false
	_progress += maxf(delta, 0.0)
	var produced := false
	var interval := maxf(mine_interval_seconds, 0.1)
	while _progress >= interval:
		_progress -= interval
		if resource_system != null and resource_system.has_method("add_stone"):
			resource_system.call("add_stone", stone_per_cycle)
			produced = true
		_stone_cycles_since_ore += 1
		if _stone_cycles_since_ore >= maxi(ore_interval_cycles, 1):
			_stone_cycles_since_ore = 0
			if resource_system != null and resource_system.has_method("add_ore"):
				resource_system.call("add_ore", ore_per_cycle)
				produced = true
	queue_redraw()
	return produced


func mine_ore(delta: float, resource_system: Node) -> bool:
	set_active(true)
	_ore_mode = true
	_progress += maxf(delta, 0.0)
	var produced := false
	var interval := maxf(mine_interval_seconds * 1.15, 0.1)
	while _progress >= interval:
		_progress -= interval
		if resource_system != null and resource_system.has_method("add_ore"):
			resource_system.call("add_ore", ore_per_cycle)
			produced = true
		if resource_system != null and resource_system.has_method("add_stone"):
			resource_system.call("add_stone", maxi(stone_per_cycle - 1, 0))
	queue_redraw()
	return produced


func get_progress_ratio() -> float:
	if mine_interval_seconds <= 0.0:
		return 1.0
	return clampf(_progress / mine_interval_seconds, 0.0, 1.0)


func get_activity_state() -> Dictionary:
	return {
		"kind": "mine_ore" if _ore_mode else "mine",
		"active": _active,
		"progress": get_progress_ratio() if _active else 0.0,
	}


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	if _active:
		_pulse = fmod(_pulse + maxf(delta, 0.0) * 3.6, 1000.0)
		queue_redraw()


func _draw() -> void:
	var base_color := Color(0.36, 0.35, 0.34, 1.0)
	var active_color := Color(0.58, 0.55, 0.50, 1.0)
	var ore_color := Color(0.74, 0.46, 0.26, 1.0)
	draw_circle(Vector2.ZERO, radius, active_color if _active else base_color)
	draw_circle(Vector2(-8.0, -6.0), radius * 0.42, Color(0.48, 0.49, 0.47, 1.0))
	draw_circle(Vector2(9.0, 7.0), radius * 0.36, ore_color if _ore_mode else Color(0.25, 0.26, 0.25, 1.0))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.78, 0.76, 0.70, 1.0), 2.0)
	if _active:
		var width := radius * 1.7
		var bar_position := Vector2(-width * 0.5, radius + 8.0)
		draw_rect(Rect2(bar_position, Vector2(width, 5.0)), Color(0.08, 0.09, 0.08, 0.9), true)
		draw_rect(Rect2(bar_position, Vector2(width * get_progress_ratio(), 5.0)), Color(0.84, 0.86, 0.72, 1.0), true)
		_draw_mining_sparks()


func _draw_mining_sparks() -> void:
	var progress := get_progress_ratio()
	var glow := 0.32 + sin(_pulse) * 0.10
	var spark_color := Color(0.95, 0.58, 0.28, glow) if _ore_mode else Color(0.86, 0.82, 0.58, glow)
	draw_arc(Vector2.ZERO, radius + 7.0, -PI * 0.10, PI * 1.10, 32, spark_color, 1.6)
	for i in range(4):
		var angle := _pulse + float(i) * PI * 0.5
		var distance := radius * (0.62 + progress * 0.28)
		var chip := Vector2(cos(angle), sin(angle)) * distance
		draw_rect(Rect2(chip - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color(0.95, 0.58, 0.28, 0.78) if _ore_mode else Color(0.88, 0.84, 0.62, 0.72), true)
