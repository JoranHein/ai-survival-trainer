class_name RepairBench
extends "res://scripts/structures/Structure.gd"

@export var repair_radius := 86.0
@export var passive_repair_per_second := 1.1
@export var active_repair_multiplier := 1.55

var _pulse := 0.0


func _ready() -> void:
	super._ready()
	structure_type = "repair_bench"
	z_index = 2


func setup_from_data(data: Dictionary) -> void:
	max_hp = float(data.get("hp", max_hp))
	repair_radius = float(data.get("repair_radius", repair_radius))
	passive_repair_per_second = float(data.get("passive_repair_per_second", passive_repair_per_second))
	active_repair_multiplier = float(data.get("active_repair_multiplier", active_repair_multiplier))


func get_repair_rate_for(structure_position: Vector2) -> float:
	if not is_alive() or global_position.distance_to(structure_position) > repair_radius:
		return 0.0
	return passive_repair_per_second


func get_active_repair_multiplier_for(structure_position: Vector2) -> float:
	if not is_alive() or global_position.distance_to(structure_position) > repair_radius:
		return 1.0
	return active_repair_multiplier


func _process(delta: float) -> void:
	_pulse += delta * 2.0
	queue_redraw()


func _draw() -> void:
	var hp_ratio := hp / max_hp if max_hp > 0.0 else 0.0
	var glow_alpha := 0.06 + sin(_pulse) * 0.018
	draw_circle(Vector2.ZERO, repair_radius, Color(0.42, 0.84, 1.0, glow_alpha))
	draw_arc(Vector2.ZERO, repair_radius, 0.0, TAU, 64, Color(0.50, 0.92, 1.0, 0.24), 2.0)
	draw_rect(Rect2(Vector2(-22.0, -10.0), Vector2(44.0, 22.0)), Color(0.14, 0.22, 0.25, 1.0), true)
	draw_rect(Rect2(Vector2(-22.0, -10.0), Vector2(44.0, 22.0)), Color(0.58, 0.88, 0.96, 1.0), false, 2.0)
	draw_line(Vector2(-14.0, -22.0), Vector2(14.0, 6.0), Color(0.72, 0.96, 1.0, 1.0), 4.0)
	draw_line(Vector2(14.0, -22.0), Vector2(-14.0, 6.0), Color(0.72, 0.96, 1.0, 1.0), 4.0)
	draw_rect(Rect2(Vector2(-7.0, -27.0), Vector2(14.0, 14.0)), Color(0.10, 0.16, 0.18, 1.0), true)
	draw_rect(Rect2(Vector2(-19.0, 20.0), Vector2(38.0, 4.0)), Color(0.03, 0.05, 0.06, 0.9), true)
	draw_rect(Rect2(Vector2(-19.0, 20.0), Vector2(38.0 * hp_ratio, 4.0)), Color(0.58, 0.92, 1.0, 1.0), true)
