class_name ThornTotem
extends "res://scripts/structures/Structure.gd"

@export var thorn_radius := 76.0
@export var recoil_damage := 4.5

var _pulse := 0.0


func _ready() -> void:
	super._ready()
	structure_type = "thorn_totem"
	z_index = 2


func setup_from_data(data: Dictionary) -> void:
	max_hp = float(data.get("hp", max_hp))
	thorn_radius = float(data.get("thorn_radius", thorn_radius))
	recoil_damage = float(data.get("recoil_damage", recoil_damage))


func get_recoil_damage_for(enemy_position: Vector2, victim_position: Vector2, _enemy_type := "zombie") -> float:
	if not is_alive():
		return 0.0
	if global_position.distance_to(enemy_position) <= thorn_radius or global_position.distance_to(victim_position) <= thorn_radius:
		return recoil_damage
	return 0.0


func _process(delta: float) -> void:
	_pulse += delta * 2.2
	queue_redraw()


func _draw() -> void:
	var hp_ratio := hp / max_hp if max_hp > 0.0 else 0.0
	var glow_alpha := 0.08 + sin(_pulse) * 0.025
	draw_circle(Vector2.ZERO, thorn_radius, Color(0.22, 0.78, 0.34, glow_alpha))
	draw_arc(Vector2.ZERO, thorn_radius, 0.0, TAU, 64, Color(0.40, 0.95, 0.50, 0.28), 2.0)
	draw_rect(Rect2(Vector2(-10.0, -18.0), Vector2(20.0, 36.0)), Color(0.10, 0.22, 0.12, 1.0), true)
	draw_rect(Rect2(Vector2(-10.0, -18.0), Vector2(20.0, 36.0)), Color(0.50, 0.92, 0.44, 1.0), false, 2.0)
	for angle in [0.0, PI * 0.33, PI * 0.66, PI, PI * 1.33, PI * 1.66]:
		var outer := Vector2(cos(angle), sin(angle)) * 22.0
		var inner := Vector2(cos(angle), sin(angle)) * 7.0
		draw_line(inner, outer, Color(0.62, 1.0, 0.52, 1.0), 3.0)
	draw_circle(Vector2.ZERO, 6.0, Color(0.77, 1.0, 0.42, 1.0))
	draw_rect(Rect2(Vector2(-17.0, 23.0), Vector2(34.0, 4.0)), Color(0.03, 0.06, 0.03, 0.9), true)
	draw_rect(Rect2(Vector2(-17.0, 23.0), Vector2(34.0 * hp_ratio, 4.0)), Color(0.58, 1.0, 0.44, 1.0), true)
