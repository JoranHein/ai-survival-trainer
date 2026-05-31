class_name World
extends Node2D

signal state_changed(state: Dictionary)

const WALL_MATERIAL_ID := "crumbly_stone"
const WALL_BUILD_ID := "wall"
const AURA_ORB_BUILD_ID := "aura_orb"

@export var arena_margin := Vector2(48.0, 96.0)
@export var arena_min_size := Vector2(640.0, 360.0)
@export var ari_scene: PackedScene
@export var zombie_scene: PackedScene
@export var wall_scene: PackedScene
@export var aura_orb_scene: PackedScene

@onready var resource_system: Node = $ResourceSystem
@onready var day_night: Node = $DayNightCycle
@onready var wave_director: Node = $WaveDirector
@onready var ari_mind: Node = $AriMind
@onready var sign_mind: Node = $SignMind
@onready var personality: Node = $Personality
@onready var run_build: Node = $RunBuild
@onready var build_grid: Node2D = $BuildGrid
@onready var mine_node: Node2D = $MineNode
@onready var thought_bubble: Node2D = $ThoughtBubble
@onready var darkness_overlay: ColorRect = $DarknessOverlay

var ari: Node2D
var enemies: Array = []
var structures: Array = []
var walls: Array = []
var aura_orbs: Array = []
var structure_cells := {}
var build_mode := false
var selected_build_type := WALL_BUILD_ID
var status_message := ""
var status_message_time := 0.0
var latest_thought := ""
var sign_text := ""
var sign_interpretation := "No sign yet."
var sign_priority_hints := {}
var sign_confusion := 1.0
var personality_traits := {}
var personality_summary := "Ari: balanced"


func _ready() -> void:
	day_night.phase_changed.connect(_on_phase_changed)
	if resource_system.has_signal("changed"):
		resource_system.connect("changed", Callable(self, "_on_resource_changed"))
	wave_director.setup(self)
	start_run()


func _process(delta: float) -> void:
	_update_status_message(delta)
	day_night.advance(delta)
	wave_director.advance(delta, day_night.is_night(), _is_ari_alive())
	_position_mine_node()
	_advance_ari_daytime(delta)
	build_grid.call("set_arena_rect", get_arena_rect())
	build_grid.call("set_selected_build_type", selected_build_type)
	build_grid.call("set_preview_radius", _get_selected_preview_radius())
	build_grid.call("set_can_afford", _can_afford_selected_build())
	if build_mode:
		build_grid.call("update_preview", get_global_mouse_position())
	_update_darkness_overlay()
	_emit_state()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			_select_wall_build_mode()
		elif event.keycode == KEY_O:
			_select_aura_orb_build_mode()
		elif event.keycode == KEY_M:
			set_mining_enabled(not _is_mining_enabled())
		elif event.keycode == KEY_1:
			select_run_build_preset(1)
		elif event.keycode == KEY_2:
			select_run_build_preset(2)
		elif event.keycode == KEY_3:
			select_run_build_preset(3)
		elif event.keycode == KEY_4:
			select_run_build_preset(4)
	if event is InputEventMouseButton and event.pressed:
		if build_mode and event.button_index == MOUSE_BUTTON_LEFT:
			place_selected_structure_at(event.position)
			get_viewport().set_input_as_handled()


func start_run() -> void:
	clear_enemies()
	clear_structures()
	resource_system.call("reset_run")
	mine_node.call("reset_run")
	status_message = ""
	status_message_time = 0.0
	latest_thought = ""
	run_build.call("reset_run")
	personality.call("randomize_for_run")
	personality_traits = personality.call("get_traits")
	personality_summary = str(personality.call("get_summary"))
	_reinterpret_current_sign()
	selected_build_type = WALL_BUILD_ID
	day_night.restart()
	wave_director.restart()
	build_grid.call("set_arena_rect", get_arena_rect())
	build_grid.call("set_selected_build_type", selected_build_type)
	build_grid.call("set_preview_radius", _get_selected_preview_radius())
	build_grid.call("set_can_afford", _can_afford_selected_build())
	_position_mine_node()
	_spawn_or_reset_ari()
	_apply_run_build_to_ari()
	thought_bubble.call("clear")
	set_build_mode(false, false)
	_show_personality_start_thought(true)
	_update_darkness_overlay()
	_emit_state()
	queue_redraw()


func restart_run() -> void:
	start_run()


func commit_sign(text: String) -> void:
	sign_text = text.strip_edges()
	_reinterpret_current_sign()
	_set_status_message("Ari read the sign.", 1.4)
	_show_sign_interpretation_thought(true)
	_emit_state()


func get_current_sign_text() -> String:
	return sign_text


func select_run_build_preset(preset_number: int, show_feedback := true) -> void:
	if run_build == null or not bool(run_build.call("apply_preset_key", preset_number)):
		return
	_apply_run_build_to_ari()
	_reinterpret_current_sign()
	if show_feedback:
		_set_status_message("Run build: %s" % str(run_build.call("get_preset_name")), 1.8)
		_show_ari_thought(str(run_build.call("get_preset_thought")), true)
	_emit_state()


func stage_visual_review_moment(moment: String) -> void:
	start_run()
	match moment:
		"midday_alive":
			select_run_build_preset(1, false)
			commit_sign("build stone walls")
			day_night.advance(21.0)
			_advance_debug_daytime(8.0)
			_set_status_message("Ari read the sign.", 1.8)
			_show_sign_interpretation_thought(true)
		"dusk_darkening":
			day_night.advance(57.5)
		"night_zombies":
			day_night.advance(68.0)
			var arena := get_arena_rect()
			resource_system.call("add_stone", 5)
			_place_wall_at_cell(build_grid.call("world_to_cell", arena.get_center() + Vector2(64.0, 0.0)))
			_place_aura_orb_at_cell(build_grid.call("world_to_cell", arena.get_center() + Vector2(112.0, 0.0)))
			_place_wall_at_cell(build_grid.call("world_to_cell", arena.get_center() + Vector2(160.0, 0.0)))
			selected_build_type = AURA_ORB_BUILD_ID
			build_grid.call("set_selected_build_type", selected_build_type)
			_set_status_message("Aura Orb radius active.", 2.0)
			_spawn_zombie(arena.position + Vector2(arena.size.x * 0.82, arena.size.y * 0.40))
			_spawn_zombie(arena.position + Vector2(arena.size.x * 0.58, arena.size.y * 0.84))
			_spawn_zombie(arena.position + Vector2(arena.size.x * 0.18, arena.size.y * 0.78))
		"ari_dead_or_damaged":
			day_night.advance(68.0)
			var arena := get_arena_rect()
			_spawn_zombie(arena.position + Vector2(arena.size.x * 0.82, arena.size.y * 0.42))
			if ari != null:
				ari.call("take_damage", 999.0)
		_:
			pass
	_update_darkness_overlay()
	_emit_state()
	queue_redraw()


func set_build_mode(enabled: bool, show_status := true) -> void:
	build_mode = enabled
	build_grid.call("set_build_mode", build_mode)
	if show_status:
		var label := _get_selected_build_name()
		_set_status_message("%s build ON." % label if build_mode else "Build mode OFF.", 1.2)
	_emit_state()


func set_mining_enabled(enabled: bool) -> void:
	if ari == null:
		return
	ari.call("set_mining_enabled", enabled)
	_set_status_message("Mining ON." if enabled else "Mining OFF.", 1.4)
	_emit_state()


func _select_wall_build_mode() -> void:
	if build_mode and selected_build_type == WALL_BUILD_ID:
		set_build_mode(false)
		return
	selected_build_type = WALL_BUILD_ID
	build_grid.call("set_selected_build_type", selected_build_type)
	set_build_mode(true)


func _select_aura_orb_build_mode() -> void:
	selected_build_type = AURA_ORB_BUILD_ID
	build_grid.call("set_selected_build_type", selected_build_type)
	build_grid.call("set_preview_radius", _get_selected_preview_radius())
	set_build_mode(true)


func place_wall_at(world_position: Vector2) -> void:
	if wall_scene == null:
		return
	var cell: Vector2i = build_grid.call("world_to_cell", world_position)
	_place_wall_at_cell(cell)


func place_selected_structure_at(world_position: Vector2) -> void:
	var cell: Vector2i = build_grid.call("world_to_cell", world_position)
	_place_structure_at_cell(selected_build_type, cell)


func get_structures() -> Array:
	return structures.duplicate()


func get_enemies() -> Array:
	return enemies.duplicate()


func get_wall_count() -> int:
	return walls.size()


func get_aura_orb_count() -> int:
	return aura_orbs.size()


func get_enemy_count() -> int:
	return enemies.size()


func spawn_zombie_at_edge() -> void:
	_spawn_zombie(_edge_spawn_position())


func _spawn_zombie(spawn_position: Vector2) -> void:
	if zombie_scene == null or ari == null:
		return

	var enemy := zombie_scene.instantiate() as Node2D
	add_child(enemy)
	enemy.global_position = spawn_position
	enemy.connect("died", Callable(self, "_on_enemy_died"))
	enemy.call("setup", ari, self)
	enemies.append(enemy)


func clear_enemies() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()


func clear_structures() -> void:
	for structure in structures:
		if is_instance_valid(structure):
			structure.queue_free()
	structures.clear()
	walls.clear()
	aura_orbs.clear()
	structure_cells.clear()


func get_arena_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1152.0, 648.0)

	var size := Vector2(
		maxf(arena_min_size.x, viewport_size.x - arena_margin.x * 2.0),
		maxf(arena_min_size.y, viewport_size.y - arena_margin.y - 48.0)
	)
	var position := Vector2(
		(viewport_size.x - size.x) * 0.5,
		arena_margin.y
	)
	return Rect2(position, size)


func _spawn_or_reset_ari() -> void:
	if ari == null:
		if ari_scene == null:
			return
		ari = ari_scene.instantiate() as Node2D
		add_child(ari)
		ari.connect("died", Callable(self, "_on_ari_died"))
		ari.connect("damaged", Callable(self, "_on_ari_damaged"))
		ari.connect("job_changed", Callable(self, "_on_ari_job_changed"))
	ari.call("reset_run")
	ari.call("setup_mining", mine_node, resource_system)
	ari.global_position = get_arena_rect().get_center()
	thought_bubble.call("follow", ari)


func _edge_spawn_position() -> Vector2:
	var arena := get_arena_rect()
	var edge := randi() % 4
	match edge:
		0:
			return Vector2(lerpf(arena.position.x, arena.end.x, randf()), arena.position.y)
		1:
			return Vector2(lerpf(arena.position.x, arena.end.x, randf()), arena.end.y)
		2:
			return Vector2(arena.position.x, lerpf(arena.position.y, arena.end.y, randf()))
	return Vector2(arena.end.x, lerpf(arena.position.y, arena.end.y, randf()))


func _update_darkness_overlay() -> void:
	var arena := get_arena_rect()
	darkness_overlay.position = arena.position
	darkness_overlay.size = arena.size
	darkness_overlay.color = Color(0.0, 0.0, 0.08, day_night.get_darkness_alpha())


func _emit_state() -> void:
	state_changed.emit({
		"day": day_night.day,
		"phase": day_night.phase,
		"time_left": day_night.get_time_left(),
		"ari_hp": float(ari.get("hp")) if ari != null else 0.0,
		"ari_max_hp": float(ari.get("max_hp")) if ari != null else 0.0,
		"ari_alive": _is_ari_alive(),
		"enemy_count": enemies.size(),
		"build_mode": build_mode,
		"selected_build_type": selected_build_type,
		"selected_build_name": _get_selected_build_name(),
		"wall_count": walls.size(),
		"aura_orb_count": aura_orbs.size(),
		"stone": _stone_count(),
		"wall_cost": int(_get_wall_cost().get("stone", 0)),
		"orb_cost": int(_get_aura_orb_cost().get("stone", 0)),
		"mining_enabled": _is_mining_enabled(),
		"ari_job": str(ari.call("get_current_job")) if ari != null else "wait_or_idle",
		"ari_job_reason": str(ari.call("get_job_reason")) if ari != null else "Waiting",
		"ari_action": str(ari.call("get_current_action")) if ari != null else "idle",
		"latest_thought": latest_thought,
		"sign_text": sign_text,
		"sign_interpretation": sign_interpretation,
		"sign_confusion": sign_confusion,
		"sign_priority_hints": sign_priority_hints,
		"personality": personality_traits,
		"personality_summary": personality_summary,
		"run_build": _get_run_build_context(),
		"run_build_name": str(run_build.call("get_preset_name")) if run_build != null else "Balanced",
		"run_build_summary": str(run_build.call("get_summary")) if run_build != null else "Balanced",
		"status_message": status_message,
	})


func _is_ari_alive() -> bool:
	return ari != null and bool(ari.call("is_alive"))


func _on_phase_changed(_day: int, _phase: String) -> void:
	if day_night.is_night() and ari != null:
		ari.call("stop_daytime_job", "Night has started")
	_emit_state()


func _on_ari_died() -> void:
	wave_director.restart()
	set_mining_enabled(false)
	_emit_state()


func _on_ari_damaged(hp: float) -> void:
	if ari == null:
		return
	var max_hp := float(ari.get("max_hp"))
	var thought: String = str(ari_mind.call("thought_for_damage", hp, max_hp))
	_show_ari_thought(thought)


func _on_ari_job_changed(job: String, reason: String) -> void:
	var thought: String = str(ari_mind.call("thought_for_job", job, reason, personality_traits, _get_run_build_context()))
	_show_ari_thought(thought)


func _place_wall_at_cell(cell: Vector2i) -> bool:
	return _place_structure_at_cell(WALL_BUILD_ID, cell)


func _place_aura_orb_at_cell(cell: Vector2i) -> bool:
	return _place_structure_at_cell(AURA_ORB_BUILD_ID, cell)


func _place_structure_at_cell(build_type: String, cell: Vector2i) -> bool:
	var scene := _get_build_scene(build_type)
	if scene == null:
		_set_status_message("No scene for %s." % _get_build_name(build_type), 1.8)
		return false
	if not bool(build_grid.call("is_cell_in_arena", cell)):
		_set_status_message("Place structures inside the arena.", 1.8)
		return false
	if structure_cells.has(cell):
		_set_status_message("That grid cell already has a structure.", 1.8)
		return false

	var cost := _get_build_cost(build_type)
	if not _spend_cost(cost):
		_set_status_message("Not enough stone for %s. Need %d." % [_get_build_name(build_type), int(cost.get("stone", 0))], 2.2)
		return false

	var structure := scene.instantiate() as Node2D
	_configure_structure(structure, build_type)
	add_child(structure)
	structure.call("setup", cell, build_grid.call("cell_to_world_center", cell))
	if build_type == AURA_ORB_BUILD_ID:
		structure.call("setup_aura", self)
	structure.connect("destroyed", Callable(self, "_on_structure_destroyed"))
	structures.append(structure)
	structure_cells[cell] = structure
	if build_type == WALL_BUILD_ID:
		walls.append(structure)
	elif build_type == AURA_ORB_BUILD_ID:
		aura_orbs.append(structure)
	_set_status_message("%s placed. -%d stone." % [_get_build_name(build_type), int(cost.get("stone", 0))], 1.2)
	_emit_state()
	return true


func _on_structure_destroyed(structure: Node) -> void:
	structures.erase(structure)
	walls.erase(structure)
	aura_orbs.erase(structure)
	var cell_to_remove = null
	for cell in structure_cells.keys():
		if structure_cells[cell] == structure:
			cell_to_remove = cell
			break
	if cell_to_remove != null:
		structure_cells.erase(cell_to_remove)
	_emit_state()


func _on_enemy_died(enemy: Node) -> void:
	enemies.erase(enemy)
	_emit_state()


func _on_resource_changed(_resource_state: Dictionary) -> void:
	_emit_state()


func _spend_cost(cost: Dictionary) -> bool:
	if resource_system == null or not resource_system.has_method("spend"):
		return false
	return bool(resource_system.call("spend", cost))


func _can_afford_selected_build() -> bool:
	if resource_system == null or not resource_system.has_method("can_afford"):
		return false
	return bool(resource_system.call("can_afford", _get_build_cost(selected_build_type)))


func _advance_ari_daytime(delta: float) -> void:
	if ari == null or not _is_ari_alive():
		return
	if day_night.is_night():
		ari.call("stop_daytime_job", "Night has started")
		return

	if _is_mining_enabled():
		ari.call("advance_mining_job", delta, true, "Debug mining")
		return

	var decision: Dictionary = ari_mind.call("choose_daytime_job", _get_ari_mind_context())
	var job := str(decision.get("job", "wait_or_idle"))
	var reason := str(decision.get("reason", "Waiting"))
	match job:
		"mine_stone":
			ari.call("advance_mining_job", delta, true, reason)
		"build_wall":
			_advance_ari_build_job(delta, WALL_BUILD_ID, reason)
		"place_aura_orb":
			_advance_ari_build_job(delta, AURA_ORB_BUILD_ID, reason)
		_:
			ari.call("wait_near", delta, _get_defense_wait_position(), reason)


func _advance_ari_build_job(delta: float, build_type: String, reason: String) -> void:
	var slot := _get_next_build_slot(build_type)
	if not slot.has("cell"):
		ari.call("stop_daytime_job", "No open defense slot")
		return

	var cell: Vector2i = slot["cell"]
	var target_position: Vector2 = build_grid.call("cell_to_world_center", cell)
	var action := "building wall" if build_type == WALL_BUILD_ID else "placing aura orb"
	var arrived: bool = bool(ari.call("advance_move_job", delta, _job_name_for_build_type(build_type), reason, target_position, action))
	if arrived:
		_place_structure_at_cell(build_type, cell)


func _get_ari_mind_context() -> Dictionary:
	return {
		"is_night": day_night.is_night(),
		"phase": day_night.phase,
		"time_left": day_night.get_time_left(),
		"night_close": day_night.phase == "dusk" and day_night.get_time_left() <= float(ari_mind.get("night_close_seconds")),
		"stone": _stone_count(),
		"wall_cost": int(_get_wall_cost().get("stone", 0)),
		"aura_orb_cost": int(_get_aura_orb_cost().get("stone", 0)),
		"wall_count": walls.size(),
		"aura_orb_count": aura_orbs.size(),
		"priority_hints": sign_priority_hints,
		"personality": personality_traits,
		"run_build": _get_run_build_context(),
		"current_job": str(ari.call("get_current_job")) if ari != null else "wait_or_idle",
	}


func _get_run_build_context() -> Dictionary:
	if run_build != null and run_build.has_method("get_context"):
		var context = run_build.call("get_context")
		if typeof(context) == TYPE_DICTIONARY:
			return context
	return {}


func _get_run_build_effects() -> Dictionary:
	if run_build != null and run_build.has_method("get_effects"):
		var effects = run_build.call("get_effects")
		if typeof(effects) == TYPE_DICTIONARY:
			return effects
	return {}


func _apply_run_build_to_ari() -> void:
	if ari == null or not ari.has_method("apply_run_build_effects"):
		return
	ari.call("apply_run_build_effects", _get_run_build_effects())


func _get_next_build_slot(build_type: String) -> Dictionary:
	var offsets := _wall_slot_offsets() if build_type == WALL_BUILD_ID else _aura_orb_slot_offsets()
	for offset in offsets:
		var cell: Vector2i = build_grid.call("world_to_cell", _get_defense_anchor() + offset)
		if bool(build_grid.call("is_cell_in_arena", cell)) and not structure_cells.has(cell):
			return {
				"cell": cell,
			}
	return {}


func _wall_slot_offsets() -> Array:
	return [
		Vector2(64.0, 0.0),
		Vector2(160.0, 0.0),
		Vector2(64.0, 48.0),
		Vector2(160.0, 48.0),
	]


func _aura_orb_slot_offsets() -> Array:
	return [
		Vector2(112.0, 0.0),
	]


func _get_defense_anchor() -> Vector2:
	return get_arena_rect().get_center()


func _get_defense_wait_position() -> Vector2:
	return _get_defense_anchor() + Vector2(-32.0, 0.0)


func _job_name_for_build_type(build_type: String) -> String:
	if build_type == AURA_ORB_BUILD_ID:
		return "place_aura_orb"
	return "build_wall"


func _get_build_scene(build_type: String) -> PackedScene:
	if build_type == AURA_ORB_BUILD_ID:
		return aura_orb_scene
	return wall_scene


func _configure_structure(structure: Node2D, build_type: String) -> void:
	structure.set("structure_type", build_type)
	if build_type == AURA_ORB_BUILD_ID:
		structure.call("setup_from_data", _get_aura_orb_data())
	else:
		structure.set("max_hp", _get_wall_hp())


func _get_build_cost(build_type: String) -> Dictionary:
	if build_type == AURA_ORB_BUILD_ID:
		return _get_aura_orb_cost()
	return _get_wall_cost()


func _get_build_name(build_type: String) -> String:
	if build_type == AURA_ORB_BUILD_ID:
		if resource_system != null and resource_system.has_method("get_structure_display_name"):
			return str(resource_system.call("get_structure_display_name", AURA_ORB_BUILD_ID))
		return "Aura Orb"
	return "Wall"


func _get_selected_build_name() -> String:
	return _get_build_name(selected_build_type)


func _get_selected_preview_radius() -> float:
	if selected_build_type == AURA_ORB_BUILD_ID:
		return float(_get_aura_orb_data().get("radius", 96.0))
	return 0.0


func _get_wall_cost() -> Dictionary:
	if resource_system != null and resource_system.has_method("get_wall_cost"):
		var cost = resource_system.call("get_wall_cost", WALL_MATERIAL_ID)
		if typeof(cost) == TYPE_DICTIONARY:
			return cost
	return {"stone": 5}


func _get_wall_hp() -> float:
	if resource_system != null and resource_system.has_method("get_wall_hp"):
		return float(resource_system.call("get_wall_hp", WALL_MATERIAL_ID))
	return 40.0


func _get_aura_orb_data() -> Dictionary:
	var data := {
		"display_name": "Aura Orb",
		"hp": 28.0,
		"radius": 96.0,
		"damage_per_second": 7.0,
		"stone_cost": 5,
	}
	if resource_system != null and resource_system.has_method("get_structure"):
		var resource_data = resource_system.call("get_structure", AURA_ORB_BUILD_ID)
		if typeof(resource_data) == TYPE_DICTIONARY:
			data = resource_data.duplicate(true)
	var effects := _get_run_build_effects()
	data["damage_per_second"] = float(data.get("damage_per_second", 7.0)) * float(effects.get("aura_damage_multiplier", 1.0))
	return data


func _get_aura_orb_cost() -> Dictionary:
	if resource_system != null and resource_system.has_method("get_structure_cost"):
		var cost = resource_system.call("get_structure_cost", AURA_ORB_BUILD_ID)
		if typeof(cost) == TYPE_DICTIONARY:
			return cost
	return {"stone": 5}


func _stone_count() -> int:
	if resource_system != null and resource_system.has_method("get_stone"):
		return int(resource_system.call("get_stone"))
	return 0


func _is_mining_enabled() -> bool:
	return ari != null and bool(ari.get("mining_enabled"))


func _position_mine_node() -> void:
	if mine_node == null:
		return
	var arena := get_arena_rect()
	mine_node.global_position = arena.get_center() + Vector2(-80.0, 150.0)


func _set_status_message(message: String, seconds := 2.0) -> void:
	status_message = message
	status_message_time = seconds if message != "" else 0.0


func _update_status_message(delta: float) -> void:
	if status_message_time <= 0.0:
		return
	status_message_time -= maxf(delta, 0.0)
	if status_message_time <= 0.0:
		status_message = ""


func _show_current_job_thought(force := false) -> void:
	if ari == null:
		return
	var job := str(ari.call("get_current_job"))
	var reason := str(ari.call("get_job_reason"))
	var thought: String = str(ari_mind.call("thought_for_job", job, reason, personality_traits, _get_run_build_context()))
	_show_ari_thought(thought, force)


func _show_sign_interpretation_thought(force := false) -> void:
	var interpretation := {
		"interpretation_text": sign_interpretation,
		"priority_hints": sign_priority_hints,
		"confusion": sign_confusion,
	}
	var thought: String = str(sign_mind.call("thought_for_interpretation", sign_text, interpretation, personality_traits, _get_run_build_context()))
	_show_ari_thought(thought, force)


func _show_personality_start_thought(force := false) -> void:
	var thought: String = str(personality.call("get_run_start_thought"))
	_show_ari_thought(thought, force)


func _show_ari_thought(thought: String, force := false) -> void:
	var clean_thought := thought.strip_edges()
	if clean_thought == "":
		return
	latest_thought = clean_thought
	thought_bubble.call("show_thought", clean_thought, force)


func _reinterpret_current_sign() -> void:
	var interpretation: Dictionary = sign_mind.call("interpret_sign", sign_text, personality_traits, _get_run_build_context())
	sign_interpretation = str(interpretation.get("interpretation_text", "Ari can read the words, but not a useful plan yet."))
	var hints = interpretation.get("priority_hints", {})
	sign_priority_hints = hints.duplicate(true) if typeof(hints) == TYPE_DICTIONARY else {}
	sign_confusion = clampf(float(interpretation.get("confusion", 1.0)), 0.0, 1.0)


func _advance_debug_daytime(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		var delta := minf(1.0 / 30.0, seconds - elapsed)
		day_night.advance(delta)
		_position_mine_node()
		_advance_ari_daytime(delta)
		elapsed += delta


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1152.0, 648.0)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.05, 0.06, 0.055, 1.0), true)

	var arena := get_arena_rect()
	draw_rect(arena, Color(0.12, 0.16, 0.12, 1.0), true)
	draw_rect(arena, Color(0.44, 0.50, 0.42, 1.0), false, 3.0)
