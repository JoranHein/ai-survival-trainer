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
		_world.spawn_zombie_at_edge()
