class_name BowTower
extends "res://scripts/structures/Structure.gd"

@export var range_radius := 150.0
@export var damage := 10.0
@export var shot_cooldown_seconds := 0.7

var world: Node
var _shot_cooldown := 0.0
var _flash := 0.0


func _ready() -> void:
	super._ready()
	structure_type = "bow_tower"
	z_index = 3


func setup_from_data(data: Dictionary) -> void:
	max_hp = float(data.get("hp", max_hp))
	range_radius = float(data.get("range", range_radius))
	damage = float(data.get("damage", damage))
	shot_cooldown_seconds = float(data.get("shot_cooldown_seconds", shot_cooldown_seconds))


func setup_tower(world_node: Node) -> void:
	world = world_node


func _process(delta: float) -> void:
	_shot_cooldown = maxf(0.0, _shot_cooldown - delta)
	_flash = maxf(0.0, _flash - delta)
	if _shot_cooldown <= 0.0:
		_try_shoot()
	queue_redraw()


func _try_shoot() -> void:
	if world == null or not world.has_method("get_enemies"):
		return
	var target_enemy: Node = null
	var target_distance := INF
	for enemy in world.call("get_enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var enemy_position: Vector2 = enemy.get("global_position")
		var distance := global_position.distance_to(enemy_position)
		if distance <= range_radius and distance < target_distance:
			target_enemy = enemy
			target_distance = distance
	if target_enemy == null:
		return
	target_enemy.call("take_damage", damage)
	_shot_cooldown = maxf(shot_cooldown_seconds, 0.1)
	_flash = 0.16


func _draw() -> void:
	var hp_ratio := hp / max_hp if max_hp > 0.0 else 0.0
	var range_alpha := 0.030 + (_flash * 0.18)
	draw_circle(Vector2.ZERO, range_radius, Color(0.92, 0.76, 0.32, range_alpha))
	draw_arc(Vector2.ZERO, range_radius, 0.0, TAU, 80, Color(0.95, 0.78, 0.38, 0.26), 2.0)
	draw_rect(Rect2(Vector2(-8.0, -2.0), Vector2(16.0, 34.0)), Color(0.34, 0.24, 0.12, 1.0), true)
	draw_rect(Rect2(Vector2(-24.0, -26.0), Vector2(48.0, 26.0)), Color(0.54, 0.38, 0.18, 1.0), true)
	draw_rect(Rect2(Vector2(-24.0, -26.0), Vector2(48.0, 26.0)), Color(0.96, 0.75, 0.34, 1.0), false, 2.0)
	draw_arc(Vector2(0.0, -11.0), 18.0, -0.70, 0.70, 18, Color(1.0, 0.88, 0.50, 1.0), 3.0)
	draw_line(Vector2(-16.0, -11.0), Vector2(18.0, -11.0), Color(0.96, 0.82, 0.46, 1.0), 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(18.0, -17.0), Vector2(28.0, -11.0), Vector2(18.0, -5.0)]), Color(1.0, 0.88, 0.50, 1.0))
	if _flash > 0.0:
		draw_line(Vector2(0.0, -11.0), Vector2(36.0, -28.0), Color(1.0, 0.92, 0.48, 1.0), 3.0)
	draw_rect(Rect2(Vector2(-22.0, 34.0), Vector2(44.0, 5.0)), Color(0.06, 0.05, 0.03, 0.9), true)
	draw_rect(Rect2(Vector2(-22.0, 34.0), Vector2(44.0 * hp_ratio, 5.0)), Color(0.95, 0.78, 0.34, 1.0), true)
