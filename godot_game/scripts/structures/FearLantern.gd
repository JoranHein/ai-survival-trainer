class_name FearLantern
extends "res://scripts/structures/Structure.gd"

@export var soothe_radius := 82.0
@export var fear_reduction_per_second := 2.0
@export var enemy_damage_multiplier := 0.90

var _pulse := 0.0


func _ready() -> void:
	super._ready()
	structure_type = "fear_lantern"
	z_index = 2


func setup_from_data(data: Dictionary) -> void:
	max_hp = float(data.get("hp", max_hp))
	soothe_radius = float(data.get("soothe_radius", soothe_radius))
	fear_reduction_per_second = float(data.get("fear_reduction_per_second", fear_reduction_per_second))
	enemy_damage_multiplier = clampf(float(data.get("enemy_damage_multiplier", enemy_damage_multiplier)), 0.50, 1.0)


func get_fear_reduction_for(ari_position: Vector2) -> float:
	if not is_alive() or global_position.distance_to(ari_position) > soothe_radius:
		return 0.0
	return fear_reduction_per_second


func get_enemy_damage_multiplier_for(enemy_position: Vector2, _enemy_type := "zombie") -> float:
	if not is_alive() or global_position.distance_to(enemy_position) > soothe_radius:
		return 1.0
	return enemy_damage_multiplier


func _process(delta: float) -> void:
	_pulse += delta * 2.6
	queue_redraw()


func _draw() -> void:
	var hp_ratio := hp / max_hp if max_hp > 0.0 else 0.0
	var glow_alpha := 0.10 + sin(_pulse) * 0.025
	draw_circle(Vector2.ZERO, soothe_radius, Color(1.0, 0.72, 0.26, glow_alpha))
	draw_arc(Vector2.ZERO, soothe_radius, 0.0, TAU, 64, Color(1.0, 0.78, 0.34, 0.28), 2.0)
	draw_rect(Rect2(Vector2(-8.0, -12.0), Vector2(16.0, 28.0)), Color(0.36, 0.23, 0.11, 1.0), true)
	draw_rect(Rect2(Vector2(-13.0, -18.0), Vector2(26.0, 14.0)), Color(0.76, 0.50, 0.20, 1.0), true)
	draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.74, 0.26, 1.0))
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.96, 0.62, 1.0))
	draw_rect(Rect2(Vector2(-17.0, 22.0), Vector2(34.0, 4.0)), Color(0.05, 0.04, 0.03, 0.9), true)
	draw_rect(Rect2(Vector2(-17.0, 22.0), Vector2(34.0 * hp_ratio, 4.0)), Color(1.0, 0.76, 0.30, 1.0), true)
