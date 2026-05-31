class_name DecoyIdol
extends "res://scripts/structures/Structure.gd"

@export var taunt_radius := 118.0
@export var max_lifetime_seconds := 120.0

var lifetime_left := 120.0
var _pulse := 0.0


func _ready() -> void:
	super._ready()
	structure_type = "decoy_idol"
	z_index = 2
	lifetime_left = max_lifetime_seconds


func setup_from_data(data: Dictionary) -> void:
	max_hp = float(data.get("hp", max_hp))
	taunt_radius = float(data.get("taunt_radius", taunt_radius))
	max_lifetime_seconds = float(data.get("lifetime_seconds", max_lifetime_seconds))
	lifetime_left = max_lifetime_seconds


func setup(cell: Vector2i, world_position: Vector2) -> void:
	super.setup(cell, world_position)
	lifetime_left = max_lifetime_seconds


func is_active_for(enemy_position: Vector2, _enemy_type := "zombie") -> bool:
	return is_alive() and lifetime_left > 0.0 and global_position.distance_to(enemy_position) <= taunt_radius


func _process(delta: float) -> void:
	if not is_alive():
		return
	_pulse += delta * 3.2
	lifetime_left = maxf(0.0, lifetime_left - maxf(delta, 0.0))
	if lifetime_left <= 0.0:
		destroyed.emit(self)
		queue_free()
	queue_redraw()


func _draw() -> void:
	var hp_ratio := hp / max_hp if max_hp > 0.0 else 0.0
	var time_ratio := lifetime_left / max_lifetime_seconds if max_lifetime_seconds > 0.0 else 0.0
	var pulse_alpha := 0.075 + sin(_pulse) * 0.025
	draw_circle(Vector2.ZERO, taunt_radius, Color(1.0, 0.34, 0.52, pulse_alpha))
	draw_arc(Vector2.ZERO, taunt_radius, 0.0, TAU, 72, Color(1.0, 0.42, 0.60, 0.30), 2.0)
	draw_rect(Rect2(Vector2(-12.0, -18.0), Vector2(24.0, 36.0)), Color(0.34, 0.09, 0.16, 1.0), true)
	draw_rect(Rect2(Vector2(-12.0, -18.0), Vector2(24.0, 36.0)), Color(1.0, 0.46, 0.58, 1.0), false, 2.0)
	draw_arc(Vector2(0.0, -3.0), 12.0, 0.0, TAU, 32, Color(1.0, 0.68, 0.78, 1.0), 2.0)
	draw_circle(Vector2.ZERO, 7.0, Color(1.0, 0.32, 0.50, 1.0))
	draw_circle(Vector2(0.0, -2.0), 3.0, Color(0.12, 0.02, 0.04, 1.0))
	draw_line(Vector2(-16.0, 0.0), Vector2(-28.0, -8.0), Color(1.0, 0.46, 0.58, 1.0), 3.0)
	draw_line(Vector2(16.0, 0.0), Vector2(28.0, -8.0), Color(1.0, 0.46, 0.58, 1.0), 3.0)
	draw_rect(Rect2(Vector2(-18.0, 24.0), Vector2(36.0, 4.0)), Color(0.06, 0.02, 0.03, 0.9), true)
	draw_rect(Rect2(Vector2(-18.0, 24.0), Vector2(36.0 * hp_ratio, 4.0)), Color(1.0, 0.48, 0.58, 1.0), true)
	draw_rect(Rect2(Vector2(-18.0, 30.0), Vector2(36.0, 3.0)), Color(0.06, 0.02, 0.03, 0.9), true)
	draw_rect(Rect2(Vector2(-18.0, 30.0), Vector2(36.0 * time_ratio, 3.0)), Color(0.86, 0.32, 0.82, 1.0), true)
