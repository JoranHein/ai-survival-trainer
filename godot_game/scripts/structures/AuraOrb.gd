class_name AuraOrb
extends "res://scripts/structures/Structure.gd"

@export var aura_radius := 96.0
@export var damage_per_second := 7.0
@export var stone_cost := 5

var world: Node
var _pulse := 0.0


func _ready() -> void:
	super._ready()
	structure_type = "aura_orb"
	z_index = 3


func setup_from_data(data: Dictionary) -> void:
	max_hp = float(data.get("hp", max_hp))
	aura_radius = float(data.get("radius", aura_radius))
	damage_per_second = float(data.get("damage_per_second", damage_per_second))
	stone_cost = maxi(int(data.get("stone_cost", stone_cost)), 0)


func setup_aura(world_node: Node) -> void:
	world = world_node


func _process(delta: float) -> void:
	if not is_alive():
		return
	_pulse += delta * 2.2
	_damage_enemies(delta)
	queue_redraw()


func _damage_enemies(delta: float) -> void:
	if world == null or not world.has_method("get_enemies"):
		return
	for enemy in world.call("get_enemies"):
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_method("take_damage"):
			continue
		var enemy_position: Vector2 = enemy.get("global_position")
		if global_position.distance_to(enemy_position) <= aura_radius:
			enemy.call("take_damage", damage_per_second * maxf(delta, 0.0))


func _draw() -> void:
	var hp_ratio := hp / max_hp if max_hp > 0.0 else 0.0
	var pulse_alpha := 0.055 + sin(_pulse) * 0.018
	draw_circle(Vector2.ZERO, aura_radius, Color(0.26, 0.72, 1.0, pulse_alpha))
	draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 64, Color(0.55, 0.90, 1.0, 0.42), 2.0)
	draw_circle(Vector2.ZERO, 15.0, Color(0.16, 0.62, 0.96, 1.0))
	draw_circle(Vector2.ZERO, 8.0, Color(0.78, 0.96, 1.0, 1.0))
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, Color(0.85, 0.98, 1.0, 1.0), 2.0)

	var bar_width := 36.0
	var bar_position := Vector2(-bar_width * 0.5, 24.0)
	draw_rect(Rect2(bar_position, Vector2(bar_width, 5.0)), Color(0.05, 0.07, 0.08, 0.95), true)
	draw_rect(Rect2(bar_position, Vector2(bar_width * hp_ratio, 5.0)), Color(0.68, 0.92, 1.0, 1.0), true)
