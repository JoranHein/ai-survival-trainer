class_name WaveDirector
extends Node

@export var spawn_interval_seconds := 3.0
@export var max_enemies := 8
@export var enemy_data_path := "res://data/enemies.json"

var _world: Node = null
var _spawn_accumulator := 0.0
var _wave_rules: Array = []


func setup(world: Node) -> void:
	_world = world
	_load_wave_rules()


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
	return choose_enemy_type_for_day(_current_day())


func choose_enemy_type_for_day(day: int, roll := -1.0) -> String:
	if _wave_rules.is_empty():
		_load_wave_rules()
	var rule := _wave_rule_for_day(day)
	var flying_chance := clampf(float(rule.get("flying_chance", 0.0)), 0.0, 1.0)
	var brute_chance := clampf(float(rule.get("brute_chance", 0.0)), 0.0, 1.0 - flying_chance)
	var runner_chance := clampf(float(rule.get("runner_chance", 0.0)), 0.0, 1.0 - flying_chance - brute_chance)
	var spawn_roll := randf() if roll < 0.0 else clampf(roll, 0.0, 1.0)
	if spawn_roll < flying_chance:
		return "flying"
	if spawn_roll < flying_chance + brute_chance:
		return "brute"
	if spawn_roll < flying_chance + brute_chance + runner_chance:
		return "runner"
	return "zombie"


func _current_day() -> int:
	if _world == null:
		return 1
	var day_night = _world.get("day_night")
	if day_night == null:
		return 1
	return maxi(1, int(day_night.get("day")))


func _load_wave_rules() -> void:
	_wave_rules = []
	var file := FileAccess.open(enemy_data_path, FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			var raw_rules = parsed.get("waves", [])
			if typeof(raw_rules) == TYPE_ARRAY:
				for raw_rule in raw_rules:
					if typeof(raw_rule) != TYPE_DICTIONARY:
						continue
					_wave_rules.append({
						"from_day": maxi(1, int(raw_rule.get("from_day", 1))),
						"runner_chance": clampf(float(raw_rule.get("runner_chance", 0.0)), 0.0, 1.0),
						"brute_chance": clampf(float(raw_rule.get("brute_chance", 0.0)), 0.0, 1.0),
						"flying_chance": clampf(float(raw_rule.get("flying_chance", 0.0)), 0.0, 1.0),
					})
	if _wave_rules.is_empty():
		_wave_rules = _default_wave_rules()
	_wave_rules.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("from_day", 1)) < int(b.get("from_day", 1))
	)


func _wave_rule_for_day(day: int) -> Dictionary:
	var selected: Dictionary = _default_wave_rules()[0]
	if not _wave_rules.is_empty():
		selected = _wave_rules[0]
	for rule in _wave_rules:
		if int(rule.get("from_day", 1)) <= day:
			selected = rule
	return selected


func _default_wave_rules() -> Array:
	return [
		{"from_day": 1, "runner_chance": 0.0, "brute_chance": 0.0, "flying_chance": 0.0},
		{"from_day": 2, "runner_chance": 0.25, "brute_chance": 0.0, "flying_chance": 0.0},
		{"from_day": 3, "runner_chance": 0.28, "brute_chance": 0.12, "flying_chance": 0.0},
		{"from_day": 5, "runner_chance": 0.34, "brute_chance": 0.18, "flying_chance": 0.12},
	]
