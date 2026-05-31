class_name BuildGrid
extends Node2D

@export var cell_size := 32
@export var line_color := Color(0.68, 0.76, 0.68, 0.28)
@export var preview_color := Color(0.78, 0.84, 0.78, 0.22)
@export var blocked_preview_color := Color(0.95, 0.26, 0.20, 0.28)

var build_mode := false
var can_afford := true
var selected_build_type := "wall"
var preview_radius := 0.0
var arena_rect := Rect2()
var preview_cell := Vector2i.ZERO


func set_build_mode(enabled: bool) -> void:
	build_mode = enabled
	queue_redraw()


func set_can_afford(enabled: bool) -> void:
	can_afford = enabled
	queue_redraw()


func set_selected_build_type(build_type: String) -> void:
	selected_build_type = build_type
	queue_redraw()


func set_preview_radius(radius: float) -> void:
	preview_radius = maxf(radius, 0.0)
	queue_redraw()


func set_arena_rect(rect: Rect2) -> void:
	arena_rect = rect
	queue_redraw()


func world_to_cell(world_position: Vector2) -> Vector2i:
	var local := world_position - arena_rect.position
	return Vector2i(floori(local.x / cell_size), floori(local.y / cell_size))


func cell_to_world_center(cell: Vector2i) -> Vector2:
	return arena_rect.position + Vector2(cell) * float(cell_size) + Vector2.ONE * float(cell_size) * 0.5


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		arena_rect.position + Vector2(cell) * float(cell_size),
		Vector2.ONE * float(cell_size)
	)


func is_cell_in_arena(cell: Vector2i) -> bool:
	var rect := cell_rect(cell)
	return arena_rect.encloses(rect)


func update_preview(world_position: Vector2) -> void:
	preview_cell = world_to_cell(world_position)
	queue_redraw()


func _draw() -> void:
	if not build_mode or arena_rect.size == Vector2.ZERO:
		return

	for x in range(int(arena_rect.position.x), int(arena_rect.end.x) + 1, cell_size):
		draw_line(Vector2(x, arena_rect.position.y), Vector2(x, arena_rect.end.y), line_color, 1.0)
	for y in range(int(arena_rect.position.y), int(arena_rect.end.y) + 1, cell_size):
		draw_line(Vector2(arena_rect.position.x, y), Vector2(arena_rect.end.x, y), line_color, 1.0)

	if is_cell_in_arena(preview_cell):
		var fill_color := preview_color if can_afford else blocked_preview_color
		var border_color := Color(0.9, 0.95, 0.9, 0.75) if can_afford else Color(1.0, 0.48, 0.42, 0.9)
		if selected_build_type == "aura_orb":
			var center := cell_to_world_center(preview_cell)
			if preview_radius > 0.0:
				draw_circle(center, preview_radius, Color(fill_color.r, fill_color.g, fill_color.b, 0.12))
				draw_arc(center, preview_radius, 0.0, TAU, 64, border_color, 2.0)
			draw_circle(center, float(cell_size) * 0.35, fill_color)
			draw_arc(center, float(cell_size) * 0.35, 0.0, TAU, 32, border_color, 2.0)
		else:
			draw_rect(cell_rect(preview_cell), fill_color, true)
			draw_rect(cell_rect(preview_cell), border_color, false, 2.0)
