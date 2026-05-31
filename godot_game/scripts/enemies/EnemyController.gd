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
@export var enemy_type := "zombie"

var target: Node2D
var world: Node
var hp := 35.0
var _attack_cooldown := 0.0
var _hit_flash := 0.0
var _facing_direction := Vector2.RIGHT


func _ready() -> void:
	configure_type(enemy_type)


func configure_type(next_type: String) -> void:
	configure_from_data(next_type, {})


func configure_from_data(next_type: String, data: Dictionary) -> void:
	var resolved_type := _known_type(next_type)
	var stats := _default_stats(resolved_type)
	for key in data.keys():
		if stats.has(key):
			stats[key] = data[key]
	enemy_type = resolved_type
	max_hp = float(stats.get("max_hp", max_hp))
	speed = float(stats.get("speed", speed))
	radius = float(stats.get("radius", radius))
	attack_damage = float(stats.get("attack_damage", attack_damage))
	attack_range = float(stats.get("attack_range", attack_range))
	attack_cooldown_seconds = float(stats.get("attack_cooldown_seconds", attack_cooldown_seconds))
	structure_attack_damage = float(stats.get("structure_attack_damage", structure_attack_damage))
	hp = clampf(hp, 0.0, max_hp)
	if hp <= 0.0:
		hp = max_hp
	queue_redraw()


func setup(ari: Node2D, world_node: Node = null) -> void:
	target = ari
	world = world_node
	hp = max_hp
	queue_redraw()


func _process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
		queue_redraw()
	if not is_alive() or target == null or not bool(target.call("is_alive")):
		return

	var attraction_target := _attraction_target()
	if attraction_target != null:
		_move_or_attack_attraction(attraction_target, delta)
		return

	var blocking_structure := _find_blocking_structure()
	if blocking_structure != null:
		_move_or_attack_structure(blocking_structure, delta)
		return

	var to_target: Vector2 = target.global_position - global_position
	_face_towards(target.global_position)
	var distance := to_target.length()
	if distance > attack_range:
		global_position += to_target.normalized() * speed * _speed_multiplier() * delta
	elif _attack_cooldown <= 0.0:
		target.call("take_damage", attack_damage * _attack_damage_multiplier())
		_apply_contact_recoil(target.global_position)
		_attack_cooldown = attack_cooldown_seconds


func take_damage(amount: float) -> void:
	if not is_alive():
		return
	hp = maxf(0.0, hp - maxf(amount, 0.0))
	if hp <= 0.0:
		died.emit(self)
		queue_free()
	else:
		_hit_flash = 0.12
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
	var structure_position: Vector2 = structure.get("global_position")
	_face_towards(structure_position)
	var distance := _distance_to_rect(global_position, rect)
	if distance <= attack_range:
		if _attack_cooldown <= 0.0:
			var damage := structure_attack_damage * _attack_damage_multiplier()
			structure.call("take_damage", damage)
			if world != null and world.has_method("record_structure_damaged"):
				world.call("record_structure_damaged", structure, damage)
			_apply_contact_recoil(structure_position)
			_attack_cooldown = attack_cooldown_seconds
		return

	var direction := structure_position - global_position
	if direction.length() <= 0.01:
		return
	var step := minf(speed * delta, maxf(0.0, distance - attack_range))
	step *= _speed_multiplier()
	global_position += direction.normalized() * step


func _move_or_attack_attraction(attraction: Node2D, delta: float) -> void:
	if not is_instance_valid(attraction) or not attraction.has_method("take_damage"):
		return
	var to_attraction := attraction.global_position - global_position
	_face_towards(attraction.global_position)
	var distance := to_attraction.length()
	if distance > attack_range:
		global_position += to_attraction.normalized() * speed * _speed_multiplier() * delta
	elif _attack_cooldown <= 0.0:
		var damage := structure_attack_damage * _attack_damage_multiplier()
		attraction.call("take_damage", damage)
		if world != null and world.has_method("record_structure_damaged"):
			world.call("record_structure_damaged", attraction, damage)
		_apply_contact_recoil(attraction.global_position)
		_attack_cooldown = attack_cooldown_seconds


func _attraction_target() -> Node2D:
	if world == null or not world.has_method("get_enemy_attraction_target"):
		return null
	var attraction = world.call("get_enemy_attraction_target", global_position, enemy_type)
	if attraction is Node2D and is_instance_valid(attraction):
		return attraction
	return null


func _speed_multiplier() -> float:
	if world != null and world.has_method("get_enemy_speed_multiplier"):
		return clampf(float(world.call("get_enemy_speed_multiplier", global_position, enemy_type)), 0.10, 1.25)
	return 1.0


func _attack_damage_multiplier() -> float:
	if world != null and world.has_method("get_enemy_attack_damage_multiplier"):
		return clampf(float(world.call("get_enemy_attack_damage_multiplier", global_position, enemy_type)), 0.50, 1.25)
	return 1.0


func _apply_contact_recoil(victim_position: Vector2) -> void:
	if world == null or not world.has_method("get_contact_recoil_damage"):
		return
	var recoil := float(world.call("get_contact_recoil_damage", global_position, victim_position, enemy_type))
	if recoil > 0.0:
		take_damage(recoil)


func _face_towards(world_position: Vector2) -> void:
	var direction := world_position - global_position
	if direction.length() > 0.01:
		_facing_direction = direction.normalized()


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
	var body_color := Color(0.84, 0.10, 0.10, 1.0)
	var core_color := Color(0.22, 0.02, 0.02, 1.0)
	var ring_color := Color(1.0, 0.42, 0.36, 1.0)
	var outline_width := 2.4
	match enemy_type:
		"runner":
			body_color = Color(1.0, 0.36, 0.14, 1.0)
			core_color = Color(0.34, 0.08, 0.02, 1.0)
			ring_color = Color(1.0, 0.74, 0.38, 1.0)
			outline_width = 2.0
		"brute":
			body_color = Color(0.55, 0.05, 0.08, 1.0)
			core_color = Color(0.12, 0.00, 0.02, 1.0)
			ring_color = Color(1.0, 0.20, 0.24, 1.0)
			outline_width = 3.5
	if _hit_flash > 0.0:
		body_color = Color(1.0, 0.82, 0.48, 1.0)
	draw_circle(Vector2(3.0, 6.0), radius + 5.0, Color(0.0, 0.0, 0.0, 0.34))
	draw_circle(Vector2.ZERO, radius + 3.5, Color(0.08, 0.00, 0.01, 0.96))
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_circle(Vector2.ZERO, radius * 0.45, core_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, ring_color, outline_width)
	_draw_facing_mark(ring_color)
	if enemy_type == "runner":
		draw_line(Vector2(-radius - 6.0, radius + 2.0), Vector2(radius + 3.0, radius + 2.0), ring_color, 2.4)
		draw_line(Vector2(-radius - 3.0, radius + 7.0), Vector2(radius - 1.0, radius + 7.0), Color(1.0, 0.58, 0.20, 0.70), 1.8)
	elif enemy_type == "brute":
		draw_rect(Rect2(Vector2(-radius * 0.75, -radius * 0.75), Vector2(radius * 1.5, radius * 1.5)), Color(0.18, 0.02, 0.03, 0.5), false, 2.0)
		draw_rect(Rect2(Vector2(-radius * 0.45, -radius * 1.05), Vector2(radius * 0.9, radius * 0.32)), ring_color.darkened(0.12), true)
	else:
		draw_line(Vector2(-radius * 0.55, radius * 0.86), Vector2(radius * 0.55, radius * 0.86), ring_color, 1.8)
	draw_rect(Rect2(Vector2(-14.0, -22.0), Vector2(28.0, 4.0)), Color(0.08, 0.02, 0.02, 0.9), true)
	draw_rect(Rect2(Vector2(-14.0, -22.0), Vector2(28.0 * hp_ratio, 4.0)), Color(1.0, 0.48, 0.34, 1.0), true)
	if _hit_flash > 0.0:
		draw_arc(Vector2.ZERO, radius + 8.0, -PI * 0.1, PI * 1.1, 28, Color(1.0, 0.88, 0.45, 0.72), 3.0)


func _known_type(next_type: String) -> String:
	if ["zombie", "runner", "brute"].has(next_type):
		return next_type
	return "zombie"


func _default_stats(next_type: String) -> Dictionary:
	match _known_type(next_type):
		"runner":
			return {
				"max_hp": 22.0,
				"speed": 118.0,
				"radius": 10.0,
				"attack_damage": 7.0,
				"attack_range": 22.0,
				"attack_cooldown_seconds": 0.75,
				"structure_attack_damage": 5.0,
			}
		"brute":
			return {
				"max_hp": 95.0,
				"speed": 42.0,
				"radius": 18.0,
				"attack_damage": 16.0,
				"attack_range": 28.0,
				"attack_cooldown_seconds": 1.25,
				"structure_attack_damage": 22.0,
			}
	return {
		"max_hp": 35.0,
		"speed": 70.0,
		"radius": 13.0,
		"attack_damage": 10.0,
		"attack_range": 24.0,
		"attack_cooldown_seconds": 1.0,
		"structure_attack_damage": 8.0,
	}


func _draw_facing_mark(mark_color: Color) -> void:
	var tip := _facing_direction * (radius + 5.0)
	var left := _facing_direction.rotated(2.45) * 5.5 + _facing_direction * (radius * 0.20)
	var right := _facing_direction.rotated(-2.45) * 5.5 + _facing_direction * (radius * 0.20)
	draw_colored_polygon(PackedVector2Array([tip, left, right]), mark_color)
