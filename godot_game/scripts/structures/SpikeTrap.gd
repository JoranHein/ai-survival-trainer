class_name SpikeTrap
extends "res://scripts/structures/Structure.gd"

@export var trigger_radius := 22.0
@export var damage := 18.0
@export var max_uses := 4

var world: Node
var uses_left := 4
var _cooldown := 0.0
var _flash := 0.0


func _ready() -> void:
	super._ready()
	structure_type = "spike_trap"
	z_index = 2
	uses_left = max_uses


func setup_from_data(data: Dictionary) -> void:
	max_hp = float(data.get("hp", max_hp))
	trigger_radius = float(data.get("radius", trigger_radius))
	damage = float(data.get("damage", damage))
	max_uses = maxi(int(data.get("uses", max_uses)), 1)
	uses_left = max_uses


func setup_trap(world_node: Node) -> void:
	world = world_node


func setup(cell: Vector2i, world_position: Vector2) -> void:
	super.setup(cell, world_position)
	uses_left = max_uses


func get_blocking_rect() -> Rect2:
	return Rect2(global_position, Vector2.ZERO)


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_flash = maxf(0.0, _flash - delta)
	if _cooldown <= 0.0:
		_try_trigger()
	queue_redraw()


func _try_trigger() -> void:
	if world == null or not world.has_method("get_enemies") or uses_left <= 0:
		return
	for enemy in world.call("get_enemies"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var enemy_position: Vector2 = enemy.get("global_position")
		if global_position.distance_to(enemy_position) <= trigger_radius:
			enemy.call("take_damage", damage)
			uses_left -= 1
			_flash = 0.16
			_cooldown = 0.35
			if uses_left <= 0:
				destroyed.emit(self)
				queue_free()
			return


func _draw() -> void:
	var rect := Rect2(-size * 0.5, size)
	var base_color := Color(0.22, 0.20, 0.18, 1.0)
	if _flash > 0.0:
		base_color = Color(0.90, 0.78, 0.45, 1.0)
	draw_rect(rect, base_color, true)
	draw_rect(rect, Color(0.74, 0.70, 0.62, 1.0), false, 2.0)
	for x in [-9.0, 0.0, 9.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(x, -13.0), Vector2(x - 6.0, 5.0), Vector2(x + 6.0, 5.0)]), Color(0.95, 0.90, 0.70, 1.0))
		draw_line(Vector2(x, 10.0), Vector2(x, -10.0), Color(0.88, 0.84, 0.68, 1.0), 3.0)
		draw_line(Vector2(x, -10.0), Vector2(x - 4.0, -3.0), Color(0.88, 0.84, 0.68, 1.0), 2.0)
		draw_line(Vector2(x, -10.0), Vector2(x + 4.0, -3.0), Color(0.88, 0.84, 0.68, 1.0), 2.0)
	var ratio := float(uses_left) / float(max_uses) if max_uses > 0 else 0.0
	draw_rect(Rect2(Vector2(-16.0, 19.0), Vector2(32.0, 4.0)), Color(0.06, 0.05, 0.04, 0.9), true)
	draw_rect(Rect2(Vector2(-16.0, 19.0), Vector2(32.0 * ratio, 4.0)), Color(0.95, 0.76, 0.34, 1.0), true)
