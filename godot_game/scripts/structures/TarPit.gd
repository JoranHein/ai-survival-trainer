class_name TarPit
extends "res://scripts/structures/Structure.gd"

@export var slow_radius := 58.0
@export var slow_multiplier := 0.48

var world: Node
var _pulse := 0.0


func _ready() -> void:
	super._ready()
	structure_type = "tar_pit"
	z_index = 1


func setup_from_data(data: Dictionary) -> void:
	max_hp = float(data.get("hp", max_hp))
	slow_radius = float(data.get("slow_radius", slow_radius))
	slow_multiplier = clampf(float(data.get("slow_multiplier", slow_multiplier)), 0.10, 1.0)


func setup_tar_pit(world_node: Node) -> void:
	world = world_node


func get_blocking_rect() -> Rect2:
	return Rect2(global_position, Vector2.ZERO)


func get_speed_multiplier_for(enemy_position: Vector2, enemy_type := "zombie") -> float:
	if enemy_type == "flying" or not is_alive():
		return 1.0
	if global_position.distance_to(enemy_position) <= slow_radius:
		return slow_multiplier
	return 1.0


func _process(delta: float) -> void:
	_pulse += delta * 1.4
	queue_redraw()


func _draw() -> void:
	var hp_ratio := hp / max_hp if max_hp > 0.0 else 0.0
	var pulse_alpha := 0.16 + sin(_pulse) * 0.035
	draw_circle(Vector2.ZERO, slow_radius, Color(0.12, 0.09, 0.15, pulse_alpha))
	draw_arc(Vector2.ZERO, slow_radius, 0.0, TAU, 64, Color(0.40, 0.30, 0.48, 0.42), 2.0)
	draw_rect(Rect2(Vector2(-17.0, -12.0), Vector2(34.0, 24.0)), Color(0.11, 0.08, 0.12, 1.0), true)
	draw_rect(Rect2(Vector2(-17.0, -12.0), Vector2(34.0, 24.0)), Color(0.42, 0.34, 0.48, 1.0), false, 2.0)
	for offset in [Vector2(-8.0, -2.0), Vector2(4.0, 4.0), Vector2(10.0, -5.0)]:
		draw_circle(offset, 4.0, Color(0.28, 0.21, 0.34, 1.0))
	draw_arc(Vector2.ZERO, 11.0, 0.25, TAU * 0.92, 28, Color(0.74, 0.58, 0.86, 1.0), 2.0)
	draw_line(Vector2(7.0, -3.0), Vector2(2.0, -8.0), Color(0.74, 0.58, 0.86, 1.0), 2.0)
	draw_rect(Rect2(Vector2(-17.0, 18.0), Vector2(34.0, 4.0)), Color(0.05, 0.04, 0.06, 0.9), true)
	draw_rect(Rect2(Vector2(-17.0, 18.0), Vector2(34.0 * hp_ratio, 4.0)), Color(0.58, 0.45, 0.68, 1.0), true)
