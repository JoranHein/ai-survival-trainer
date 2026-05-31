class_name Structure
extends Node2D

signal destroyed(structure: Node)

@export var max_hp := 40.0
@export var size := Vector2(32.0, 32.0)
@export var structure_type := "structure"

var hp := 40.0
var grid_cell := Vector2i.ZERO


func _ready() -> void:
	hp = max_hp


func setup(cell: Vector2i, world_position: Vector2) -> void:
	grid_cell = cell
	global_position = world_position
	hp = max_hp
	queue_redraw()


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(0.0, hp - maxf(amount, 0.0))
	if hp <= 0.0:
		destroyed.emit(self)
		queue_free()
	else:
		queue_redraw()


func is_alive() -> bool:
	return hp > 0.0


func get_blocking_rect() -> Rect2:
	return Rect2(global_position - size * 0.5, size)
