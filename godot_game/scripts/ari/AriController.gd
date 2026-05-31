class_name AriController
extends Node2D

signal damaged(hp: float)
signal died
signal job_changed(job: String, reason: String)

@export var max_hp := 100.0
@export var radius := 16.0
@export var move_speed := 90.0
@export var mining_spot_offset := Vector2(48.0, 0.0)
@export var mining_arrive_distance := 4.0
@export var build_arrive_distance := 22.0

var hp := 100.0
var mining_enabled := false
var current_job := "wait_or_idle"
var job_reason := "Waiting"
var current_action := "idle"

var _mine_node: Node2D
var _resource_system: Node
var _base_move_speed := 0.0
var _mining_speed_multiplier := 1.0
var _damage_taken_multiplier := 1.0


func _ready() -> void:
	_base_move_speed = move_speed


func reset_run() -> void:
	_ensure_base_move_speed()
	hp = max_hp
	mining_enabled = false
	current_job = "wait_or_idle"
	job_reason = "Waiting"
	current_action = "idle"
	queue_redraw()


func setup_mining(mine_node: Node2D, resource_system: Node) -> void:
	_mine_node = mine_node
	_resource_system = resource_system


func apply_run_build_effects(effects: Dictionary) -> void:
	_ensure_base_move_speed()
	move_speed = _base_move_speed * clampf(float(effects.get("movement_speed_multiplier", 1.0)), 0.5, 2.0)
	_mining_speed_multiplier = clampf(float(effects.get("mining_speed_multiplier", 1.0)), 0.5, 2.5)
	_damage_taken_multiplier = clampf(float(effects.get("damage_taken_multiplier", 1.0)), 0.2, 1.5)


func set_mining_enabled(enabled: bool) -> void:
	mining_enabled = enabled
	if not mining_enabled:
		_stop_mining()
	queue_redraw()


func advance_daytime_behavior(delta: float, can_mine: bool) -> void:
	if not mining_enabled:
		return
	advance_mining_job(delta, can_mine, "Debug mining")


func advance_mining_job(delta: float, can_mine: bool, reason: String) -> void:
	_set_job("mine_stone", reason)
	if not is_alive():
		stop_daytime_job("Dead")
		return
	if not can_mine or _mine_node == null or _resource_system == null:
		stop_daytime_job("Cannot mine now")
		return

	var mining_spot := _mine_node.global_position + mining_spot_offset
	var to_spot := mining_spot - global_position
	if to_spot.length() > mining_arrive_distance:
		current_action = "moving to mine"
		_mine_node.call("set_active", false)
		global_position += to_spot.normalized() * minf(move_speed * delta, to_spot.length())
	else:
		current_action = "mining"
		_mine_node.call("mine", delta * _mining_speed_multiplier, _resource_system)
	queue_redraw()


func advance_move_job(delta: float, job: String, reason: String, target_position: Vector2, arrived_action: String) -> bool:
	_set_job(job, reason)
	if not is_alive():
		stop_daytime_job("Dead")
		return false

	var to_target := target_position - global_position
	if to_target.length() > build_arrive_distance:
		current_action = "moving to %s" % job
		global_position += to_target.normalized() * minf(move_speed * delta, to_target.length())
		queue_redraw()
		return false

	current_action = arrived_action
	queue_redraw()
	return true


func wait_near(delta: float, target_position: Vector2, reason: String) -> void:
	if advance_move_job(delta, "wait_or_idle", reason, target_position, "waiting near defenses"):
		current_action = "waiting near defenses"


func stop_daytime_job(reason := "Waiting") -> void:
	_set_job("wait_or_idle", reason)
	_stop_mining()
	queue_redraw()


func get_current_action() -> String:
	return current_action


func get_current_job() -> String:
	return current_job


func get_job_reason() -> String:
	return job_reason


func take_damage(amount: float) -> void:
	if not is_alive():
		return
	hp = maxf(0.0, hp - maxf(amount, 0.0) * _damage_taken_multiplier)
	damaged.emit(hp)
	if hp <= 0.0:
		died.emit()
	queue_redraw()


func is_alive() -> bool:
	return hp > 0.0


func _stop_mining() -> void:
	current_action = "idle"
	if is_instance_valid(_mine_node):
		_mine_node.call("set_active", false)


func _ensure_base_move_speed() -> void:
	if _base_move_speed <= 0.0:
		_base_move_speed = move_speed


func _set_job(job: String, reason: String) -> void:
	if current_job == job and job_reason == reason:
		return
	current_job = job
	job_reason = reason
	job_changed.emit(current_job, job_reason)


func _draw() -> void:
	var body_color := Color(0.10, 0.42, 1.0, 1.0) if is_alive() else Color(0.22, 0.25, 0.30, 1.0)
	draw_circle(Vector2.ZERO, radius, body_color)
	draw_circle(Vector2(5.0, -5.0), 3.0, Color(0.85, 0.95, 1.0, 1.0))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.75, 0.9, 1.0, 1.0), 2.0)
	if current_action == "mining":
		draw_line(Vector2(6.0, -8.0), Vector2(20.0, -16.0), Color(0.94, 0.88, 0.60, 1.0), 3.0)
