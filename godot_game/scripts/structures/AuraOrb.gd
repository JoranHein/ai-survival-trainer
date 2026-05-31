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
			var damage := damage_per_second * maxf(delta, 0.0)
			enemy.call("take_damage", damage)
			if world.has_method("record_aura_damage_success"):
				world.call("record_aura_damage_success", enemy, damage)


func _draw() -> void:
	var hp_ratio := hp / max_hp if max_hp > 0.0 else 0.0
	var pulse := 0.5 + sin(_pulse) * 0.5
	var pulse_alpha := 0.065 + pulse * 0.030
	draw_circle(Vector2(4.0, 8.0), 23.0, Color(0.0, 0.0, 0.0, 0.30))
	draw_circle(Vector2.ZERO, aura_radius, Color(0.18, 0.62, 1.0, pulse_alpha))
	draw_circle(Vector2.ZERO, aura_radius * 0.58, Color(0.58, 0.92, 1.0, 0.035 + pulse * 0.025))
	draw_arc(Vector2.ZERO, aura_radius, 0.0, TAU, 72, Color(0.68, 0.94, 1.0, 0.50), 2.4)
	draw_arc(Vector2.ZERO, aura_radius * (0.82 + pulse * 0.05), 0.0, TAU, 72, Color(0.94, 1.0, 1.0, 0.20 + pulse * 0.18), 1.7)
	draw_circle(Vector2.ZERO, 24.0 + pulse * 2.0, Color(0.28, 0.82, 1.0, 0.20))
	draw_circle(Vector2.ZERO, 17.0, Color(0.04, 0.18, 0.26, 1.0))
	draw_circle(Vector2.ZERO, 14.0, Color(0.16, 0.68, 1.0, 1.0))
	draw_circle(Vector2.ZERO, 7.0 + pulse * 1.2, Color(0.86, 0.99, 1.0, 1.0))
	draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 36, Color(0.92, 1.0, 1.0, 1.0), 2.4)

	var bar_width := 36.0
	var bar_position := Vector2(-bar_width * 0.5, 24.0)
	draw_rect(Rect2(bar_position, Vector2(bar_width, 5.0)), Color(0.05, 0.07, 0.08, 0.95), true)
	draw_rect(Rect2(bar_position, Vector2(bar_width * hp_ratio, 5.0)), Color(0.68, 0.92, 1.0, 1.0), true)
