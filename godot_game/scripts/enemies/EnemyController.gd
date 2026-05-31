class_name EnemyController
extends Node2D

signal died(enemy: Node)

@export var max_hp := 35.0
@export var speed := 70.0
@export var radius := 13.0
@export var attack_range := 24.0
@export var attack_damage := 10.0
@export var attack_cooldown_seconds := 1.0
@export var structure_attack_damage := 8.0

var target: Node2D
var world: Node
var hp := 35.0
var _attack_cooldown := 0.0


func setup(ari: Node2D, world_node: Node = null) -> void:
	target = ari
	world = world_node
	hp = max_hp
	queue_redraw()


func _process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if not is_alive() or target == null or not bool(target.call("is_alive")):
		return

	var blocking_structure := _find_blocking_structure()
	if blocking_structure != null:
		_move_or_attack_structure(blocking_structure, delta)
		return

	var to_target: Vector2 = target.global_position - global_position
	var distance := to_target.length()
	if distance > attack_range:
		global_position += to_target.normalized() * speed * delta
	elif _attack_cooldown <= 0.0:
		target.call("take_damage", attack_damage)
		_attack_cooldown = attack_cooldown_seconds


func take_damage(amount: float) -> void:
	if not is_alive():
		return
	hp = maxf(0.0, hp - maxf(amount, 0.0))
	if hp <= 0.0:
		died.emit(self)
		queue_free()
	else:
		queue_redraw()


func is_alive() -> bool:
	return hp > 0.0


func _find_blocking_structure() -> Node:
	if world == null or not world.has_method("get_structures"):
		return null
	var closest_structure: Node = null
	var closest_distance := INF
	for structure in world.call("get_structures"):
		if not is_instance_valid(structure) or not bool(structure.call("is_alive")):
			continue
		var rect: Rect2 = structure.call("get_blocking_rect")
		if _segment_hits_rect(global_position, target.global_position, rect.grow(radius * 0.75)):
			var structure_position: Vector2 = structure.get("global_position")
			var distance := global_position.distance_to(structure_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_structure = structure
	return closest_structure


func _move_or_attack_structure(structure: Node, delta: float) -> void:
	var rect: Rect2 = structure.call("get_blocking_rect")
	var distance := _distance_to_rect(global_position, rect)
	if distance <= attack_range:
		if _attack_cooldown <= 0.0:
			structure.call("take_damage", structure_attack_damage)
			_attack_cooldown = attack_cooldown_seconds
		return

	var structure_position: Vector2 = structure.get("global_position")
	var direction := structure_position - global_position
	if direction.length() <= 0.01:
		return
	var step := minf(speed * delta, maxf(0.0, distance - attack_range))
	global_position += direction.normalized() * step


func _segment_hits_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	for i in range(13):
		var t := float(i) / 12.0
		if rect.has_point(from.lerp(to, t)):
			return true
	return false


func _distance_to_rect(point: Vector2, rect: Rect2) -> float:
	var dx := maxf(maxf(rect.position.x - point.x, 0.0), point.x - rect.end.x)
	var dy := maxf(maxf(rect.position.y - point.y, 0.0), point.y - rect.end.y)
	return Vector2(dx, dy).length()


func _draw() -> void:
	var hp_ratio := hp / max_hp if max_hp > 0.0 else 0.0
	draw_circle(Vector2.ZERO, radius, Color(0.84, 0.10, 0.10, 1.0))
	draw_circle(Vector2.ZERO, radius * 0.45, Color(0.22, 0.02, 0.02, 1.0))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1.0, 0.42, 0.36, 1.0), 2.0)
	draw_rect(Rect2(Vector2(-14.0, -22.0), Vector2(28.0, 4.0)), Color(0.08, 0.02, 0.02, 0.9), true)
	draw_rect(Rect2(Vector2(-14.0, -22.0), Vector2(28.0 * hp_ratio, 4.0)), Color(1.0, 0.48, 0.34, 1.0), true)
