class_name StormRod
extends "res://scripts/structures/Structure.gd"

@export var range_radius := 132.0
@export var flying_damage := 18.0
@export var ground_damage := 4.0
@export var shot_cooldown_seconds := 1.05

var world: Node
var _shot_cooldown := 0.0
var _flash := 0.0
var _last_bolt := Vector2.ZERO
var _pulse := 0.0


func _ready() -> void:
	super._ready()
	structure_type = "storm_rod"
	z_index = 3


func setup_from_data(data: Dictionary) -> void:
	max_hp = float(data.get("hp", max_hp))
	range_radius = float(data.get("range", range_radius))
	flying_damage = float(data.get("flying_damage", flying_damage))
	ground_damage = float(data.get("ground_damage", ground_damage))
	shot_cooldown_seconds = float(data.get("shot_cooldown_seconds", shot_cooldown_seconds))


func setup_storm_rod(world_node: Node) -> void:
	world = world_node


func _process(delta: float) -> void:
	_pulse += delta * 2.8
	_shot_cooldown = maxf(0.0, _shot_cooldown - delta)
	_flash = maxf(0.0, _flash - delta)
	if _shot_cooldown <= 0.0:
		_try_shock()
	queue_redraw()


func _try_shock() -> void:
	if world == null or not world.has_method("get_enemies"):
		return
	var target_enemy := _choose_target()
	if target_enemy == null:
		return
	var enemy_type := str(target_enemy.get("enemy_type"))
	var damage := flying_damage if enemy_type == "flying" else ground_damage
	target_enemy.call("take_damage", damage)
	_last_bolt = target_enemy.global_position - global_position
	_shot_cooldown = maxf(shot_cooldown_seconds, 0.1)
	_flash = 0.18


func _choose_target() -> Node2D:
	var fallback_enemy: Node2D = null
	var fallback_distance := INF
	var flying_enemy: Node2D = null
	var flying_distance := INF
	for enemy in world.call("get_enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var enemy_position: Vector2 = enemy.global_position
		var distance := global_position.distance_to(enemy_position)
		if distance > range_radius:
			continue
		if str(enemy.get("enemy_type")) == "flying":
			if distance < flying_distance:
				flying_distance = distance
				flying_enemy = enemy
		elif distance < fallback_distance:
			fallback_distance = distance
			fallback_enemy = enemy
	return flying_enemy if flying_enemy != null else fallback_enemy


func _draw() -> void:
	var hp_ratio := hp / max_hp if max_hp > 0.0 else 0.0
	var glow_alpha := 0.035 + (_flash * 0.16) + sin(_pulse) * 0.010
	draw_circle(Vector2.ZERO, range_radius, Color(0.36, 0.78, 1.0, glow_alpha))
	draw_arc(Vector2.ZERO, range_radius, 0.0, TAU, 80, Color(0.56, 0.88, 1.0, 0.28), 2.0)
	draw_rect(Rect2(Vector2(-6.0, -28.0), Vector2(12.0, 48.0)), Color(0.12, 0.20, 0.28, 1.0), true)
	draw_rect(Rect2(Vector2(-13.0, 15.0), Vector2(26.0, 12.0)), Color(0.18, 0.30, 0.38, 1.0), true)
	draw_line(Vector2.ZERO, Vector2(-16.0, -18.0), Color(0.58, 0.92, 1.0, 1.0), 3.0)
	draw_line(Vector2.ZERO, Vector2(16.0, -18.0), Color(0.58, 0.92, 1.0, 1.0), 3.0)
	draw_line(Vector2(0.0, -25.0), Vector2(0.0, -40.0), Color(0.82, 0.98, 1.0, 1.0), 4.0)
	draw_circle(Vector2(0.0, -42.0), 6.0, Color(0.74, 0.96, 1.0, 1.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.0, -51.0),
		Vector2(7.0, -51.0),
		Vector2(1.0, -41.0),
		Vector2(9.0, -41.0),
		Vector2(-5.0, -24.0),
		Vector2(-1.0, -37.0),
		Vector2(-9.0, -37.0),
	]), Color(0.92, 1.0, 0.86, 1.0))
	if _flash > 0.0:
		draw_polyline(PackedVector2Array([Vector2.ZERO, _last_bolt * 0.35 + Vector2(8.0, -10.0), _last_bolt * 0.70 + Vector2(-6.0, 6.0), _last_bolt]), Color(0.86, 1.0, 1.0, 1.0), 3.0)
	draw_rect(Rect2(Vector2(-18.0, 31.0), Vector2(36.0, 4.0)), Color(0.03, 0.05, 0.07, 0.9), true)
	draw_rect(Rect2(Vector2(-18.0, 31.0), Vector2(36.0 * hp_ratio, 4.0)), Color(0.58, 0.90, 1.0, 1.0), true)
