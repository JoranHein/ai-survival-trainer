class_name Tower
extends "res://scripts/structures/Structure.gd"

@export var range_radius := 150.0
@export var range_bonus := 32.0
@export var damage := 10.0
@export var shot_cooldown_seconds := 0.7
@export var perch_offset := Vector2(0.0, -18.0)

var world: Node
var _shot_flash := 0.0


func _ready() -> void:
	super._ready()
	structure_type = "bow_tower"
	size = Vector2(42.0, 42.0)
	z_index = 3


func _process(delta: float) -> void:
	super._process(delta)
	if _shot_flash > 0.0:
		_shot_flash = maxf(0.0, _shot_flash - delta)
		queue_redraw()


func setup_from_data(data: Dictionary) -> void:
	max_hp = float(data.get("hp", max_hp))
	range_radius = float(data.get("range", range_radius))
	range_bonus = float(data.get("range_bonus", range_bonus))
	damage = float(data.get("damage", damage))
	shot_cooldown_seconds = float(data.get("shot_cooldown_seconds", shot_cooldown_seconds))


func setup_tower(world_node: Node) -> void:
	world = world_node


func get_perch_position() -> Vector2:
	return global_position + perch_offset


func get_range_radius() -> float:
	return range_radius + range_bonus


func get_attack_damage() -> float:
	return damage


func get_shot_cooldown_seconds() -> float:
	return shot_cooldown_seconds


func record_shot() -> void:
	_shot_flash = 0.18
	queue_redraw()


func _draw() -> void:
	var hp_ratio := hp / max_hp if max_hp > 0.0 else 0.0
	var range_alpha := 0.025 + (_shot_flash * 0.18)
	var wood := Color(0.38, 0.25, 0.12, 1.0)
	var platform := Color(0.58, 0.40, 0.18, 1.0)
	var gold := Color(0.96, 0.76, 0.34, 1.0)
	var shadow := Color(0.08, 0.05, 0.03, 0.90)

	draw_circle(Vector2.ZERO, get_range_radius(), Color(0.94, 0.72, 0.28, range_alpha))
	draw_arc(Vector2.ZERO, get_range_radius(), 0.0, TAU, 80, Color(0.96, 0.78, 0.34, 0.22), 2.0)
	draw_rect(Rect2(Vector2(-28.0, 22.0), Vector2(56.0, 16.0)), Color(0.0, 0.0, 0.0, 0.24), true)
	draw_rect(Rect2(Vector2(-7.0, -2.0), Vector2(14.0, 34.0)), wood, true)
	draw_line(Vector2(-18.0, 30.0), Vector2(18.0, -20.0), Color(0.24, 0.14, 0.06, 1.0), 3.0)
	draw_line(Vector2(18.0, 30.0), Vector2(-18.0, -20.0), Color(0.24, 0.14, 0.06, 1.0), 3.0)
	draw_rect(Rect2(Vector2(-27.0, -30.0), Vector2(54.0, 30.0)), Color(0.10, 0.06, 0.03, 0.95), true)
	draw_rect(Rect2(Vector2(-25.0, -28.0), Vector2(50.0, 26.0)), platform, true)
	draw_rect(Rect2(Vector2(-25.0, -28.0), Vector2(50.0, 26.0)), gold, false, 3.0)
	draw_arc(Vector2(0.0, -13.0), 18.0, -0.70, 0.70, 18, Color(1.0, 0.88, 0.50, 1.0), 3.0)
	draw_line(Vector2(-16.0, -13.0), Vector2(18.0, -13.0), Color(0.96, 0.82, 0.46, 1.0), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(18.0, -19.0), Vector2(29.0, -13.0), Vector2(18.0, -7.0)]), Color(1.0, 0.88, 0.50, 1.0))
	if _shot_flash > 0.0:
		draw_circle(Vector2(0.0, -13.0), 18.0, Color(1.0, 0.88, 0.34, 0.18))
	draw_rect(Rect2(Vector2(-22.0, 34.0), Vector2(44.0, 5.0)), shadow, true)
	draw_rect(Rect2(Vector2(-22.0, 34.0), Vector2(44.0 * hp_ratio, 5.0)), gold, true)
