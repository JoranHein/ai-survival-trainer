class_name Structure
extends Node2D

signal destroyed(structure: Node)

@export var max_hp := 40.0
@export var size := Vector2(32.0, 32.0)
@export var structure_type := "structure"
@export var show_nameplate := false

var hp := 40.0
var grid_cell := Vector2i.ZERO
var _damage_flash := 0.0


func _ready() -> void:
	hp = max_hp
	_apply_nameplate_visibility()


func _process(delta: float) -> void:
	if _damage_flash <= 0.0:
		return
	_damage_flash = maxf(0.0, _damage_flash - delta)
	queue_redraw()


func setup(cell: Vector2i, world_position: Vector2) -> void:
	grid_cell = cell
	global_position = world_position
	hp = max_hp
	_damage_flash = 0.0
	_apply_nameplate_visibility()
	queue_redraw()


func take_damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp = maxf(0.0, hp - maxf(amount, 0.0))
	if hp <= 0.0:
		destroyed.emit(self)
		queue_free()
	else:
		_damage_flash = 0.16
		queue_redraw()


func repair(amount: float) -> float:
	if hp <= 0.0:
		return 0.0
	var before := hp
	hp = minf(max_hp, hp + maxf(amount, 0.0))
	if hp > before:
		queue_redraw()
	return hp - before


func is_alive() -> bool:
	return hp > 0.0


func needs_repair() -> bool:
	return is_alive() and hp < max_hp - 0.1


func get_hp_ratio() -> float:
	if max_hp <= 0.0:
		return 0.0
	return clampf(hp / max_hp, 0.0, 1.0)


func get_damage_flash_amount() -> float:
	return clampf(_damage_flash / 0.16, 0.0, 1.0)


func get_blocking_rect() -> Rect2:
	return Rect2(global_position - size * 0.5, size)


func _apply_nameplate_visibility() -> void:
	var nameplate := get_node_or_null("Nameplate")
	if nameplate is CanvasItem:
		nameplate.visible = show_nameplate
