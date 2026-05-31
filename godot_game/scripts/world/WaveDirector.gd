class_name WaveDirector
extends Node

@export var spawn_interval_seconds := 3.0
@export var max_enemies := 8

var _world: Node = null
var _spawn_accumulator := 0.0


func setup(world: Node) -> void:
	_world = world


func restart() -> void:
	_spawn_accumulator = 0.0


func advance(delta: float, is_night: bool, ari_alive: bool) -> void:
	if not is_night or not ari_alive:
		_spawn_accumulator = 0.0
		return
	if _world == null:
		return
	if _world.get_enemy_count() >= max_enemies:
		return

	_spawn_accumulator += maxf(delta, 0.0)
	while _spawn_accumulator >= spawn_interval_seconds and _world.get_enemy_count() < max_enemies:
		_spawn_accumulator -= spawn_interval_seconds
		if _world.has_method("spawn_enemy_at_edge"):
			_world.spawn_enemy_at_edge(_choose_enemy_type())
		else:
			_world.spawn_zombie_at_edge()


func _choose_enemy_type() -> String:
	if _world == null:
		return "zombie"
	var day := 1
	var day_night = _world.get("day_night")
	if day_night != null:
		day = int(day_night.get("day"))
	var roll := randf()
	if day >= 4 and roll < 0.12:
		return "flying"
	if day >= 3 and roll < 0.18:
		return "brute"
	if day >= 2 and roll < 0.38:
		return "runner"
	return "zombie"
