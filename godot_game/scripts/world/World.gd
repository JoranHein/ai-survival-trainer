class_name World
extends Node2D

signal state_changed(state: Dictionary)

const WALL_MATERIAL_ID := "crumbly_stone"
const WALL_BUILD_ID := "wall"
const AURA_ORB_BUILD_ID := "aura_orb"
const SPIKE_TRAP_BUILD_ID := "spike_trap"
const BOW_TOWER_BUILD_ID := "bow_tower"
const TAR_PIT_BUILD_ID := "tar_pit"
const FEAR_LANTERN_BUILD_ID := "fear_lantern"
const DECOY_IDOL_BUILD_ID := "decoy_idol"
const THORN_TOTEM_BUILD_ID := "thorn_totem"
const REPAIR_BENCH_BUILD_ID := "repair_bench"
const STORM_ROD_BUILD_ID := "storm_rod"
const AriPerceptionScript = preload("res://scripts/ari/AriPerception.gd")
const AriRulebookScript = preload("res://scripts/ari/AriRulebook.gd")

@export var arena_margin := Vector2(48.0, 340.0)
@export var arena_min_size := Vector2(640.0, 260.0)
@export var ari_scene: PackedScene
@export var zombie_scene: PackedScene
@export var wall_scene: PackedScene
@export var aura_orb_scene: PackedScene
@export var spike_trap_scene: PackedScene
@export var bow_tower_scene: PackedScene
@export var tar_pit_scene: PackedScene
@export var fear_lantern_scene: PackedScene
@export var decoy_idol_scene: PackedScene
@export var thorn_totem_scene: PackedScene
@export var repair_bench_scene: PackedScene
@export var storm_rod_scene: PackedScene
@export var enemy_data_path := "res://data/enemies.json"
@export var weapons_data_path := "res://data/weapons.json"

@onready var resource_system: Node = $ResourceSystem
@onready var day_night: Node = $DayNightCycle
@onready var wave_director: Node = $WaveDirector
@onready var ari_mind: Node = $AriMind
@onready var sign_mind: Node = $SignMind
@onready var run_build: Node = $RunBuild
@onready var permanent_progression: Node = $PermanentProgression
@onready var build_grid: Node2D = $BuildGrid
@onready var mine_node: Node2D = $MineNode
@onready var training_dummy: Node2D = $TrainingDummy
@onready var farm_plot: Node2D = $FarmPlot
@onready var bed_station: Node2D = $BedStation
@onready var library_station: Node2D = $Library
@onready var forge_station: Node2D = $ForgeStation
@onready var thought_bubble: Node2D = $ThoughtBubble
@onready var darkness_overlay: ColorRect = $DarknessOverlay

var ari: Node2D
var enemies: Array = []
var structures: Array = []
var walls: Array = []
var aura_orbs: Array = []
var spike_traps: Array = []
var bow_towers: Array = []
var tar_pits: Array = []
var fear_lanterns: Array = []
var decoy_idols: Array = []
var thorn_totems: Array = []
var repair_benches: Array = []
var storm_rods: Array = []
var structure_cells := {}
var build_mode := false
var selected_build_type := WALL_BUILD_ID
var status_message := ""
var status_message_time := 0.0
var latest_thought := ""
var death_recap := ""
var death_reward := 0
var sign_text := ""
var sign_interpretation := "No sign yet."
var sign_priority_hints := {}
var sign_grounded_plan: Array = []
var sign_strength := 0.0
var sign_resonance := 0.0
var ai_bridge: AIBridge
var ai_status := "AI disabled"
var ai_survival_theory := ""
var ai_emotion := ""
var ari_memory := AriMemory.new()
var lesson_book := LessonBook.new()
var ari_rulebook := AriRulebookScript.new()
var ari_perception := AriPerceptionScript.new()
var latest_lesson_title := ""
var _visual_review_staging := false
var _ari_intent_active := false
var _ari_intent_target := Vector2.ZERO
var _ari_intent_label := ""
var _fear_pressure_reported := false
var _hunger_pressure_reported := false
var _stamina_pressure_reported := false
var _near_death_reported := false
var _aura_damage_reported := false
var _ai_sign_request_id := 0
var _ai_waiting_active := false
var _ai_waiting_elapsed := 0.0
var _ai_waiting_last_second := -1
var _ai_waiting_still_thought_shown := false
var _ari_ranged_cooldown := 0.0
var _ari_ranged_flash_time := 0.0
var _ari_ranged_flash_from := Vector2.ZERO
var _ari_ranged_flash_to := Vector2.ZERO
var _ari_melee_cooldown := 0.0
var _ari_melee_flash_time := 0.0
var _ari_melee_flash_from := Vector2.ZERO
var _ari_melee_flash_to := Vector2.ZERO
var _dawn_clear_flash_time := 0.0
var _farming_yield_remainder := 0.0
var _enemy_data := {}
var _noticed_enemy_types := {}
var _weapon_data := {}
var _sword_order: Array[String] = []
var _current_sword_id := "none"
var _regen_on_kill_reported := false


func _ready() -> void:
	day_night.phase_changed.connect(_on_phase_changed)
	if resource_system.has_signal("changed"):
		resource_system.connect("changed", Callable(self, "_on_resource_changed"))
	if permanent_progression.has_signal("changed"):
		permanent_progression.connect("changed", Callable(self, "_on_permanent_progression_changed"))
	_load_enemy_data()
	_load_weapon_data()
	wave_director.setup(self)
	ai_bridge = AIBridge.new()
	add_child(ai_bridge)
	_update_ai_idle_status()
	start_run()


func _process(delta: float) -> void:
	_update_status_message(delta)
	_advance_ai_waiting(delta)
	_update_ari_ranged_attack_timers(delta)
	day_night.advance(delta)
	wave_director.advance(delta, day_night.is_night(), _is_ari_alive())
	_position_mine_node()
	_position_training_dummy()
	_position_farm_plot()
	_position_bed_station()
	_position_library_station()
	_position_forge_station()
	if ari != null:
		ari.call("advance_survival_needs", delta, day_night.phase)
		if ari.has_method("apply_passive_regen"):
			ari.call("apply_passive_regen", delta)
		_apply_structure_support_effects(delta)
		_apply_passive_repairs(delta)
		_update_survival_pressure_thoughts()
	if permanent_progression != null and permanent_progression.has_method("advance_survival") and not _visual_review_staging:
		permanent_progression.call("advance_survival", delta, day_night.is_night(), _is_ari_alive())
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
		elif event.keycode == KEY_X:
			_select_spike_trap_build_mode()
		elif event.keycode == KEY_Y:
			_select_bow_tower_build_mode()
		elif event.keycode == KEY_C:
			_select_tar_pit_build_mode()
		elif event.keycode == KEY_F:
			_select_fear_lantern_build_mode()
		elif event.keycode == KEY_D:
			_select_decoy_idol_build_mode()
		elif event.keycode == KEY_H:
			_select_thorn_totem_build_mode()
		elif event.keycode == KEY_K:
			_select_repair_bench_build_mode()
		elif event.keycode == KEY_L:
			_select_storm_rod_build_mode()
		elif event.keycode == KEY_M:
			set_mining_enabled(not _is_mining_enabled())
		elif event.keycode == KEY_F6:
			toggle_remote_ai()
		elif event.keycode == KEY_F7:
			retry_ai_interpretation()
		elif event.keycode == KEY_F8:
			clear_ai_interpretation_cache()
		elif event.keycode == KEY_1:
			select_run_build_preset(1)
		elif event.keycode == KEY_2:
			select_run_build_preset(2)
		elif event.keycode == KEY_3:
			select_run_build_preset(3)
		elif event.keycode == KEY_4:
			select_run_build_preset(4)
		elif event.keycode == KEY_5:
			select_run_build_preset(5)
		elif event.keycode == KEY_6:
			select_run_build_preset(6)
		elif event.keycode == KEY_7:
			select_run_build_preset(7)
		elif event.keycode == KEY_8:
			select_run_build_preset(8)
		elif event.keycode == KEY_9:
			select_run_build_preset(9)
		elif event.keycode == KEY_0:
			select_run_build_preset(10)
	if event is InputEventMouseButton and event.pressed:
		if build_mode and event.button_index == MOUSE_BUTTON_LEFT:
			place_selected_structure_at(event.position)
			get_viewport().set_input_as_handled()


func start_run() -> void:
	clear_enemies()
	clear_structures()
	resource_system.call("reset_run")
	mine_node.call("reset_run")
	training_dummy.call("reset_run")
	farm_plot.call("reset_run")
	bed_station.call("reset_run")
	library_station.call("reset_run")
	forge_station.call("reset_run")
	if ari_memory.has_method("clear_life_memory"):
		ari_memory.call("clear_life_memory")
	else:
		ari_memory.clear_day_memory()
	lesson_book.clear_life()
	latest_lesson_title = ""
	_clear_ari_intent()
	_reset_survival_pressure_flags()
	_ari_ranged_cooldown = 0.0
	_ari_ranged_flash_time = 0.0
	_ari_melee_cooldown = 0.0
	_ari_melee_flash_time = 0.0
	_dawn_clear_flash_time = 0.0
	_noticed_enemy_types = {}
	_current_sword_id = "none"
	_regen_on_kill_reported = false
	_farming_yield_remainder = 0.0
	status_message = ""
	status_message_time = 0.0
	latest_thought = ""
	death_recap = ""
	death_reward = 0
	_ai_sign_request_id += 1
	_finish_ai_waiting()
	_update_ai_idle_status()
	ai_survival_theory = ""
	ai_emotion = ""
	sign_grounded_plan = []
	if permanent_progression != null and permanent_progression.has_method("reset_run"):
		permanent_progression.call("reset_run")
	run_build.call("reset_run")
	_reinterpret_current_sign()
	selected_build_type = WALL_BUILD_ID
	day_night.restart()
	wave_director.restart()
	build_grid.call("set_arena_rect", get_arena_rect())
	build_grid.call("set_selected_build_type", selected_build_type)
	build_grid.call("set_preview_radius", _get_selected_preview_radius())
	build_grid.call("set_can_afford", _can_afford_selected_build())
	_position_mine_node()
	_position_training_dummy()
	_position_farm_plot()
	_position_bed_station()
	_position_library_station()
	_position_forge_station()
	_spawn_or_reset_ari()
	_apply_current_sword_to_ari()
	_apply_run_build_to_ari()
	thought_bubble.call("clear")
	set_build_mode(false, false)
	_update_darkness_overlay()
	_emit_state()
	if sign_text.strip_edges() != "" and ai_bridge != null and ai_bridge.is_ai_enabled():
		_request_ai_deep_interpretation(false)
	queue_redraw()


func restart_run() -> void:
	start_run()


func commit_sign(text: String) -> void:
	sign_text = text.strip_edges()
	_reinterpret_current_sign()
	_set_status_message("Ari read the sign.", 1.4)
	_show_sign_interpretation_thought(true)
	_emit_state()
	_request_ai_deep_interpretation()


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
	if sign_text.strip_edges() != "":
		_request_ai_deep_interpretation(false)


func stage_visual_review_moment(moment: String) -> void:
	_visual_review_staging = true
	start_run()
	match moment:
		"morning_idle":
			_stage_morning_intent_path()
		"midday_alive":
			select_run_build_preset(4, false)
			commit_sign("think about what went wrong")
			resource_system.call("add_stone", 24)
			resource_system.call("add_food", 2)
			ari.global_position = library_station.global_position + Vector2(-82.0, 8.0)
			ari_memory.record_event("structure_destroyed", {
				"structure_type": WALL_BUILD_ID,
				"day": day_night.day,
				"phase": "midday",
			})
			sign_interpretation = "Ari reads memory and wants the library's lesson."
			sign_priority_hints = _normalize_ai_priority_hints({
				"reflect_library": 0.9,
			})
			sign_grounded_plan = _normalize_grounded_plan([{
				"affordance_id": "reflect_library",
				"priority": 0.9,
				"reason": "The sign asks Ari to think about what went wrong.",
			}])
			sign_strength = 0.82
			sign_resonance = 0.80
			ai_survival_theory = "library_reflection"
			ai_emotion = "curious regret"
			ai_status = "AI: active"
			_stage_ari_needs(28.0, 88.0, 24.0)
			day_night.advance(28.0)
			_advance_debug_daytime(4.0)
			_set_status_message("Library reflection staged.", 1.8)
			_show_current_job_thought(true)
			selected_build_type = WALL_BUILD_ID
			build_grid.call("set_selected_build_type", selected_build_type)
			set_build_mode(false, false)
		"dusk_darkening":
			day_night.advance(68.0)
		"night_zombies":
			day_night.advance(82.0)
			var arena := get_arena_rect()
			resource_system.call("add_stone", 84)
			_place_visual_review_defense_layout(arena)
			_damage_structure_near(arena.get_center() + Vector2(72.0, -16.0), 26.0)
			commit_sign("build a mountain where arrows rain while storm answers wings")
			sign_interpretation = "Ari reads height, arrows, and storm. The tower can shoot while the rod answers the sky."
			sign_priority_hints = _normalize_ai_priority_hints({
				"use_tower": 0.95,
				"ranged_attack": 0.9,
				"lure_to_aura": 0.45,
				"anti_flying": 0.85,
			})
			sign_grounded_plan = _normalize_grounded_plan([
				{
					"affordance_id": "use_tower",
					"priority": 0.95,
					"reason": "The sign asks for height and arrows.",
				},
				{
					"affordance_id": "anti_flying",
					"priority": 0.85,
					"reason": "The sign says storm should answer wings.",
				},
			])
			sign_strength = 0.80
			sign_resonance = 0.78
			ai_survival_theory = "tower_range"
			ai_emotion = "focused fear"
			ai_status = "AI: active"
			selected_build_type = BOW_TOWER_BUILD_ID
			build_grid.call("set_selected_build_type", selected_build_type)
			_set_status_message("Tower and storm range active.", 2.0)
			_spawn_enemy(arena.get_center() + Vector2(260.0, -112.0), "zombie")
			_spawn_enemy(arena.position + Vector2(arena.size.x * 0.58, arena.size.y * 0.84), "runner")
			_spawn_enemy(arena.position + Vector2(arena.size.x * 0.18, arena.size.y * 0.78), "brute")
			_spawn_enemy(arena.position + Vector2(arena.size.x * 0.75, arena.size.y * 0.18), "flying")
			_advance_ari_night_tactic(3.0)
			_show_current_job_thought(true)
			_damage_structure_near(arena.get_center() + Vector2(72.0, -16.0), 999.0)
		"ari_dead_or_damaged":
			day_night.advance(82.0)
			var arena := get_arena_rect()
			_spawn_enemy(arena.position + Vector2(arena.size.x * 0.82, arena.size.y * 0.42), "runner")
			if ari != null:
				ari.call("take_damage", 999.0)
		_:
			pass
	_visual_review_staging = false
	_update_darkness_overlay()
	_emit_state()
	queue_redraw()


func _stage_morning_intent_path() -> void:
	var arena := get_arena_rect()
	if ari != null:
		ari.global_position = arena.position + Vector2(arena.size.x * 0.18, arena.size.y * 0.78)
		ari.call("stop_daytime_job", "Choosing the first wall")
		ari.queue_redraw()
	_advance_ari_daytime(0.05)
	_show_current_job_thought(true)


func _stage_ari_needs(next_hunger: float, next_stamina: float, next_fear: float) -> void:
	if ari == null:
		return
	ari.set("hunger", clampf(next_hunger, 0.0, float(ari.get("max_hunger"))))
	ari.set("stamina", clampf(next_stamina, 0.0, float(ari.get("max_stamina"))))
	ari.set("fear", clampf(next_fear, 0.0, float(ari.get("max_fear"))))
	ari.queue_redraw()


func _place_visual_review_defense_layout(arena: Rect2) -> void:
	var anchor := arena.get_center()
	_place_wall_at_cell(build_grid.call("world_to_cell", anchor + Vector2(72.0, -16.0)))
	_place_wall_at_cell(build_grid.call("world_to_cell", anchor + Vector2(144.0, -16.0)))
	_place_wall_at_cell(build_grid.call("world_to_cell", anchor + Vector2(72.0, 40.0)))
	_place_aura_orb_at_cell(build_grid.call("world_to_cell", anchor + Vector2(108.0, 12.0)))
	_place_spike_trap_at_cell(build_grid.call("world_to_cell", anchor + Vector2(216.0, -36.0)))
	_place_bow_tower_at_cell(build_grid.call("world_to_cell", anchor + Vector2(144.0, -112.0)))
	_place_tar_pit_at_cell(build_grid.call("world_to_cell", anchor + Vector2(216.0, 56.0)))
	_place_fear_lantern_at_cell(build_grid.call("world_to_cell", anchor + Vector2(-8.0, 16.0)))
	_place_decoy_idol_at_cell(build_grid.call("world_to_cell", anchor + Vector2(308.0, -16.0)))
	_place_thorn_totem_at_cell(build_grid.call("world_to_cell", anchor + Vector2(-96.0, -48.0)))
	_place_repair_bench_at_cell(build_grid.call("world_to_cell", anchor + Vector2(-160.0, 48.0)))
	_place_storm_rod_at_cell(build_grid.call("world_to_cell", anchor + Vector2(244.0, -112.0)))


func buy_permanent_upgrade_key(key_number: int) -> bool:
	if permanent_progression == null or not permanent_progression.has_method("buy_upgrade_key"):
		return false
	if not bool(permanent_progression.call("buy_upgrade_key", key_number)):
		_set_status_message("Not enough Time Points for that upgrade.", 1.8)
		_emit_state()
		return false
	_apply_run_build_to_ari()
	_reinterpret_current_sign()
	_set_status_message("Permanent upgrade learned.", 1.6)
	_show_ari_thought("I feel a little more ready for the next night.", true)
	_emit_state()
	return true


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


func toggle_remote_ai() -> void:
	if ai_bridge == null:
		return
	ai_bridge.set_ai_enabled(not ai_bridge.is_ai_enabled())
	if not ai_bridge.is_ai_enabled():
		_finish_ai_waiting()
	_update_ai_idle_status()
	_set_status_message("Remote AI ON." if ai_bridge.is_ai_enabled() else "Remote AI OFF.", 1.4)
	_emit_state()
	if ai_bridge.is_ai_enabled() and sign_text.strip_edges() != "":
		_request_ai_deep_interpretation()


func retry_ai_interpretation() -> void:
	if ai_bridge == null or not ai_bridge.is_ai_enabled():
		_update_ai_idle_status()
		_set_status_message("Remote AI is disabled.", 1.4)
		_emit_state()
		return
	if sign_text.strip_edges() == "":
		_set_status_message("Write a sign before retrying AI.", 1.4)
		_emit_state()
		return
	_request_ai_deep_interpretation(true, true)


func clear_ai_interpretation_cache() -> void:
	if ai_bridge == null or not ai_bridge.has_method("clear_deep_interpretation_cache"):
		return
	ai_bridge.call("clear_deep_interpretation_cache")
	if not _ai_waiting_active:
		_update_ai_idle_status()
	_set_status_message("AI cache cleared.", 1.4)
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


func _select_spike_trap_build_mode() -> void:
	selected_build_type = SPIKE_TRAP_BUILD_ID
	build_grid.call("set_selected_build_type", selected_build_type)
	build_grid.call("set_preview_radius", _get_selected_preview_radius())
	set_build_mode(true)


func _select_bow_tower_build_mode() -> void:
	selected_build_type = BOW_TOWER_BUILD_ID
	build_grid.call("set_selected_build_type", selected_build_type)
	build_grid.call("set_preview_radius", _get_selected_preview_radius())
	set_build_mode(true)


func _select_tar_pit_build_mode() -> void:
	selected_build_type = TAR_PIT_BUILD_ID
	build_grid.call("set_selected_build_type", selected_build_type)
	build_grid.call("set_preview_radius", _get_selected_preview_radius())
	set_build_mode(true)


func _select_fear_lantern_build_mode() -> void:
	selected_build_type = FEAR_LANTERN_BUILD_ID
	build_grid.call("set_selected_build_type", selected_build_type)
	build_grid.call("set_preview_radius", _get_selected_preview_radius())
	set_build_mode(true)


func _select_decoy_idol_build_mode() -> void:
	selected_build_type = DECOY_IDOL_BUILD_ID
	build_grid.call("set_selected_build_type", selected_build_type)
	build_grid.call("set_preview_radius", _get_selected_preview_radius())
	set_build_mode(true)


func _select_thorn_totem_build_mode() -> void:
	selected_build_type = THORN_TOTEM_BUILD_ID
	build_grid.call("set_selected_build_type", selected_build_type)
	build_grid.call("set_preview_radius", _get_selected_preview_radius())
	set_build_mode(true)


func _select_repair_bench_build_mode() -> void:
	selected_build_type = REPAIR_BENCH_BUILD_ID
	build_grid.call("set_selected_build_type", selected_build_type)
	build_grid.call("set_preview_radius", _get_selected_preview_radius())
	set_build_mode(true)


func _select_storm_rod_build_mode() -> void:
	selected_build_type = STORM_ROD_BUILD_ID
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


func get_existing_walls() -> Array:
	return walls.duplicate()


func get_aura_orbs() -> Array:
	return aura_orbs.duplicate()


func get_spike_trap_count() -> int:
	return spike_traps.size()


func get_bow_tower_count() -> int:
	return bow_towers.size()


func get_tar_pit_count() -> int:
	return tar_pits.size()


func get_fear_lantern_count() -> int:
	return fear_lanterns.size()


func get_decoy_idol_count() -> int:
	return decoy_idols.size()


func get_thorn_totem_count() -> int:
	return thorn_totems.size()


func get_repair_bench_count() -> int:
	return repair_benches.size()


func get_storm_rod_count() -> int:
	return storm_rods.size()


func get_enemy_count() -> int:
	return enemies.size()


func get_enemy_type_counts() -> Dictionary:
	return _get_enemy_type_counts()


func spawn_zombie_at_edge() -> void:
	spawn_enemy_at_edge("zombie")


func spawn_enemy_at_edge(enemy_type := "zombie") -> void:
	_spawn_enemy(_edge_spawn_position(), enemy_type)


func _spawn_zombie(spawn_position: Vector2) -> void:
	_spawn_enemy(spawn_position, "zombie")


func _spawn_enemy(spawn_position: Vector2, enemy_type := "zombie") -> void:
	if zombie_scene == null or ari == null:
		return

	var resolved_enemy_type := _normalize_enemy_type(enemy_type)
	var enemy := zombie_scene.instantiate() as Node2D
	add_child(enemy)
	enemy.global_position = spawn_position
	if enemy.has_method("configure_from_data"):
		enemy.call("configure_from_data", resolved_enemy_type, _get_enemy_data(resolved_enemy_type))
	elif enemy.has_method("configure_type"):
		enemy.call("configure_type", resolved_enemy_type)
	enemy.connect("died", Callable(self, "_on_enemy_died"))
	enemy.call("setup", ari, self)
	enemies.append(enemy)
	ari_memory.record_event("enemy_spawned", {
		"enemy_type": resolved_enemy_type,
		"day": day_night.day,
		"phase": day_night.phase,
	})
	_show_new_enemy_type_thought(resolved_enemy_type)


func _load_enemy_data() -> void:
	_enemy_data = {}
	var file := FileAccess.open(enemy_data_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var enemies_data = parsed.get("enemies", {})
	if typeof(enemies_data) == TYPE_DICTIONARY:
		_enemy_data = enemies_data


func _load_weapon_data() -> void:
	_weapon_data = {
		"sword_tiers": {
			"none": {"display_name": "Hands", "tier": 0, "ore_cost": 0, "damage_bonus": 0.0, "armor_bonus": 0.0},
			"crude_sword": {"display_name": "Crude Sword", "tier": 1, "ore_cost": 2, "damage_bonus": 5.0, "armor_bonus": 0.02},
			"iron_sword": {"display_name": "Iron Sword", "tier": 2, "ore_cost": 5, "damage_bonus": 10.0, "armor_bonus": 0.06},
		},
	}
	_sword_order = ["none", "crude_sword", "iron_sword"]
	var file := FileAccess.open(weapons_data_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var tiers = parsed.get("sword_tiers", {})
	if typeof(tiers) == TYPE_DICTIONARY:
		_weapon_data["sword_tiers"] = tiers
	var raw_order = parsed.get("sword_order", [])
	if typeof(raw_order) == TYPE_ARRAY and raw_order.size() > 0:
		_sword_order.clear()
		for item in raw_order:
			_sword_order.append(str(item))


func _get_enemy_data(enemy_type: String) -> Dictionary:
	if typeof(_enemy_data) != TYPE_DICTIONARY:
		return {}
	var data = _enemy_data.get(_normalize_enemy_type(enemy_type), {})
	if typeof(data) == TYPE_DICTIONARY:
		return data
	return {}


func _normalize_enemy_type(enemy_type: String) -> String:
	if ["zombie", "runner", "brute", "flying"].has(enemy_type):
		return enemy_type
	return "zombie"


func _get_enemy_type_counts() -> Dictionary:
	var counts := {
		"zombie": 0,
		"runner": 0,
		"brute": 0,
		"flying": 0,
	}
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_type := _normalize_enemy_type(str(enemy.get("enemy_type")))
		counts[enemy_type] = int(counts.get(enemy_type, 0)) + 1
	return counts


func _show_new_enemy_type_thought(enemy_type: String) -> void:
	if enemy_type == "zombie" or bool(_noticed_enemy_types.get(enemy_type, false)):
		return
	_noticed_enemy_types[enemy_type] = true
	match enemy_type:
		"runner":
			_show_ari_thought("That one is too fast. Walls may not be enough.", true)
		"brute":
			_show_ari_thought("That thing breaks stone like it is afraid of silence.", true)
		"flying":
			_show_ari_thought("The flying ones do not care about stone.", true)


func clear_enemies() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()


func _clear_enemies_for_dawn() -> void:
	var cleared_count := enemies.size()
	if cleared_count <= 0:
		return
	clear_enemies()
	wave_director.restart()
	_dawn_clear_flash_time = 1.2
	ari_memory.record_event("dawn_enemies_vanished", {
		"count": cleared_count,
		"day": day_night.day,
		"phase": "morning",
	})
	_set_status_message("Dawn broke: %d enemies vanished." % cleared_count, 2.2)
	var current_job := str(ari.call("get_current_job")) if ari != null else ""
	var survival_hint := maxf(
		maxf(float(sign_priority_hints.get("survive_until_morning", 0.0)), float(sign_priority_hints.get("stall_until_dawn", 0.0))),
		maxf(float(sign_priority_hints.get("hide_until_dawn", 0.0)), float(sign_priority_hints.get("avoid_killing", 0.0)))
	)
	if survival_hint > 0.2 or ["stall_until_dawn", "hide_until_dawn", "use_cover", "flee"].has(current_job):
		_show_ari_thought("I only had to last until the light.", true)
	else:
		_show_ari_thought("Morning took them before they could finish me.", true)
	queue_redraw()


func clear_structures() -> void:
	for structure in structures:
		if is_instance_valid(structure):
			structure.queue_free()
	structures.clear()
	walls.clear()
	aura_orbs.clear()
	spike_traps.clear()
	bow_towers.clear()
	tar_pits.clear()
	fear_lanterns.clear()
	decoy_idols.clear()
	thorn_totems.clear()
	repair_benches.clear()
	storm_rods.clear()
	structure_cells.clear()


func get_enemy_speed_multiplier(enemy_position: Vector2, enemy_type := "zombie") -> float:
	var multiplier := 1.0
	for tar_pit in tar_pits:
		if is_instance_valid(tar_pit) and tar_pit.has_method("get_speed_multiplier_for"):
			multiplier = minf(multiplier, float(tar_pit.call("get_speed_multiplier_for", enemy_position, enemy_type)))
	return multiplier


func get_enemy_attack_damage_multiplier(enemy_position: Vector2, enemy_type := "zombie") -> float:
	var multiplier := 1.0
	for fear_lantern in fear_lanterns:
		if is_instance_valid(fear_lantern) and fear_lantern.has_method("get_enemy_damage_multiplier_for"):
			multiplier = minf(multiplier, float(fear_lantern.call("get_enemy_damage_multiplier_for", enemy_position, enemy_type)))
	return multiplier


func get_contact_recoil_damage(enemy_position: Vector2, victim_position: Vector2, enemy_type := "zombie") -> float:
	var recoil := 0.0
	for thorn_totem in thorn_totems:
		if is_instance_valid(thorn_totem) and thorn_totem.has_method("get_recoil_damage_for"):
			recoil = maxf(recoil, float(thorn_totem.call("get_recoil_damage_for", enemy_position, victim_position, enemy_type)))
	return recoil


func record_aura_damage_success(enemy: Node, damage: float) -> void:
	if _aura_damage_reported:
		return
	_aura_damage_reported = true
	ari_memory.record_event("aura_damage_success", {
		"enemy_type": str(enemy.get("enemy_type")) if enemy != null else "enemy",
		"damage": maxf(float(damage), 0.0),
		"day": day_night.day,
		"phase": day_night.phase,
	})


func get_enemy_attraction_target(enemy_position: Vector2, enemy_type := "zombie") -> Node:
	var closest_decoy: Node = null
	var closest_distance := INF
	for decoy_idol in decoy_idols:
		if not is_instance_valid(decoy_idol) or not decoy_idol.has_method("is_active_for"):
			continue
		if not bool(decoy_idol.call("is_active_for", enemy_position, enemy_type)):
			continue
		var distance := enemy_position.distance_to(decoy_idol.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_decoy = decoy_idol
	return closest_decoy


func _apply_structure_support_effects(delta: float) -> void:
	if ari == null or not _is_ari_alive():
		return
	var ari_position := ari.global_position
	for fear_lantern in fear_lanterns:
		if not is_instance_valid(fear_lantern) or not fear_lantern.has_method("get_fear_reduction_for"):
			continue
		var fear_reduction := float(fear_lantern.call("get_fear_reduction_for", ari_position))
		if fear_reduction > 0.0 and ari.has_method("soothe_fear"):
			ari.call("soothe_fear", fear_reduction * maxf(delta, 0.0))


func _apply_passive_repairs(delta: float) -> void:
	if day_night.is_night():
		return
	var safe_delta := maxf(delta, 0.0)
	if safe_delta <= 0.0:
		return
	for structure in structures:
		if not is_instance_valid(structure) or structure.get("structure_type") == REPAIR_BENCH_BUILD_ID:
			continue
		if not structure.has_method("needs_repair") or not bool(structure.call("needs_repair")):
			continue
		var repair_rate := 0.0
		for repair_bench in repair_benches:
			if is_instance_valid(repair_bench) and repair_bench.has_method("get_repair_rate_for"):
				repair_rate += float(repair_bench.call("get_repair_rate_for", structure.global_position))
		if repair_rate > 0.0 and structure.has_method("repair"):
			structure.call("repair", repair_rate * safe_delta)


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
	ari.call("setup_training", training_dummy)
	ari.call("setup_day_stations", farm_plot, bed_station, library_station)
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
	var ari_job := str(ari.call("get_current_job")) if ari != null else "wait_or_idle"
	var ari_job_reason := str(ari.call("get_job_reason")) if ari != null else "Waiting"
	state_changed.emit({
		"day": day_night.day,
		"phase": day_night.phase,
		"time_left": day_night.get_time_left(),
		"ari_hp": float(ari.get("hp")) if ari != null else 0.0,
		"ari_max_hp": float(ari.get("max_hp")) if ari != null else 0.0,
		"ari_alive": _is_ari_alive(),
		"enemy_count": enemies.size(),
		"enemy_type_counts": _get_enemy_type_counts(),
		"build_mode": build_mode,
		"selected_build_type": selected_build_type,
		"selected_build_name": _get_selected_build_name(),
		"wall_count": walls.size(),
		"aura_orb_count": aura_orbs.size(),
		"spike_trap_count": spike_traps.size(),
		"bow_tower_count": bow_towers.size(),
		"tar_pit_count": tar_pits.size(),
		"fear_lantern_count": fear_lanterns.size(),
		"decoy_idol_count": decoy_idols.size(),
		"thorn_totem_count": thorn_totems.size(),
		"repair_bench_count": repair_benches.size(),
		"storm_rod_count": storm_rods.size(),
		"damaged_structure_count": _get_damaged_structure_count(),
		"lowest_structure_hp_ratio": _get_lowest_structure_hp_ratio(),
		"stone": _stone_count(),
		"food": _food_count(),
		"ore": _ore_count(),
		"sword_tier": _current_sword_tier(),
		"sword_name": str(_current_sword_data().get("display_name", "Hands")),
		"ari_hp_ratio": _get_ari_hp_ratio(),
		"wall_cost": int(_get_wall_cost().get("stone", 0)),
		"orb_cost": int(_get_aura_orb_cost().get("stone", 0)),
		"trap_cost": int(_get_spike_trap_cost().get("stone", 0)),
		"tower_cost": int(_get_bow_tower_cost().get("stone", 0)),
		"tar_pit_cost": int(_get_tar_pit_cost().get("stone", 0)),
		"fear_lantern_cost": int(_get_fear_lantern_cost().get("stone", 0)),
		"decoy_idol_cost": int(_get_decoy_idol_cost().get("stone", 0)),
		"thorn_totem_cost": int(_get_thorn_totem_cost().get("stone", 0)),
		"repair_bench_cost": int(_get_repair_bench_cost().get("stone", 0)),
		"storm_rod_cost": int(_get_storm_rod_cost().get("stone", 0)),
		"mining_enabled": _is_mining_enabled(),
		"ari_job": ari_job,
		"ari_job_reason": ari_job_reason,
		"ari_action": str(ari.call("get_current_action")) if ari != null else "idle",
		"combat_stats": _get_ari_combat_stats(),
		"needs": _get_ari_needs(),
		"lesson_count": _get_lesson_count(),
		"latest_lesson_title": latest_lesson_title,
		"latest_thought": latest_thought,
		"death_recap": death_recap,
		"death_reward": death_reward,
		"sign_text": sign_text,
		"sign_interpretation": sign_interpretation,
		"sign_strength": sign_strength,
		"sign_resonance": sign_resonance,
		"sign_priority_hints": sign_priority_hints,
		"sign_grounded_plan": sign_grounded_plan,
		"sign_action_focus": _get_sign_action_focus(ari_job, ari_job_reason),
		"ai_status": ai_status,
		"ai_survival_theory": ai_survival_theory,
		"ai_emotion": ai_emotion,
		"ai_top_hint": _get_top_priority_hint(sign_priority_hints),
		"ai_top_grounded_plan": _get_top_grounded_plan_text(),
		"run_build": _get_run_build_context(),
		"run_build_name": str(run_build.call("get_preset_name")) if run_build != null else "Balanced",
		"run_build_summary": str(run_build.call("get_summary")) if run_build != null else "Balanced",
		"permanent_progression": _get_permanent_progression_state(),
		"inspect_text": _get_hover_inspection_text(),
		"status_message": status_message,
	})


func _get_hover_inspection_text() -> String:
	var mouse_position := get_global_mouse_position()
	if not get_arena_rect().grow(18.0).has_point(mouse_position):
		return ""

	var best_distance := 42.0
	var best_text := ""
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_position: Vector2 = enemy.get("global_position")
		var distance := mouse_position.distance_to(enemy_position)
		if distance < best_distance:
			best_distance = distance
			best_text = _enemy_inspection_text(enemy)

	for structure in structures:
		if not is_instance_valid(structure):
			continue
		var structure_position: Vector2 = structure.get("global_position")
		var structure_size := Vector2(36.0, 36.0)
		var size_value = structure.get("size")
		if typeof(size_value) == TYPE_VECTOR2:
			structure_size = size_value
		var distance := mouse_position.distance_to(structure_position)
		var hover_radius := maxf(28.0, maxf(structure_size.x, structure_size.y) * 0.65)
		if distance <= hover_radius and distance < best_distance:
			best_distance = distance
			best_text = _structure_inspection_text(structure)

	for station in _station_inspection_targets():
		var station_node = station.get("node")
		if not (station_node is Node2D) or not is_instance_valid(station_node):
			continue
		var station_position: Vector2 = station_node.global_position
		var distance := mouse_position.distance_to(station_position)
		var hover_radius := float(station.get("radius", 34.0))
		if distance <= hover_radius and distance < best_distance:
			best_distance = distance
			best_text = str(station.get("text", ""))
	return best_text


func _enemy_inspection_text(enemy: Node) -> String:
	var enemy_type := _title_from_id(str(enemy.get("enemy_type")))
	var hp := int(round(float(enemy.get("hp"))))
	var max_hp := int(round(float(enemy.get("max_hp"))))
	return "Inspect: %s HP %d/%d" % [enemy_type, hp, max_hp]


func _structure_inspection_text(structure: Node) -> String:
	var structure_type := str(structure.get("structure_type"))
	var structure_name := _get_build_name(structure_type)
	if structure_name == "":
		structure_name = _title_from_id(structure_type)
	var hp := int(round(float(structure.get("hp"))))
	var max_hp := int(round(float(structure.get("max_hp"))))
	var state := "stable"
	if structure.has_method("get_hp_ratio"):
		var ratio := float(structure.call("get_hp_ratio"))
		if ratio < 0.35:
			state = "critical"
		elif ratio < 0.70:
			state = "damaged"
	if structure_type == SPIKE_TRAP_BUILD_ID:
		var uses_left := int(structure.get("uses_left"))
		var max_uses := int(structure.get("max_uses"))
		return "Inspect: %s uses %d/%d" % [structure_name, uses_left, max_uses]
	return "Inspect: %s HP %d/%d %s" % [structure_name, hp, max_hp, state]


func _station_inspection_targets() -> Array:
	return [
		{"node": mine_node, "radius": 36.0, "text": "Inspect: Mine - Ari gathers stone here"},
		{"node": farm_plot, "radius": 42.0, "text": "Inspect: Farm - grows food over time"},
		{"node": bed_station, "radius": 42.0, "text": "Inspect: Rest - recovers and rereads notes"},
		{"node": training_dummy, "radius": 38.0, "text": "Inspect: Dummy - trains combat stats"},
		{"node": forge_station, "radius": 40.0, "text": "Inspect: Forge - turns ore into sword upgrades"},
		{"node": library_station, "radius": 44.0, "text": "Inspect: Library - writes reflection notes"},
	]


func _title_from_id(id: String) -> String:
	return id.replace("_", " ").capitalize()


func _is_ari_alive() -> bool:
	return ari != null and bool(ari.call("is_alive"))


func _on_phase_changed(_day: int, _phase: String) -> void:
	ari_memory.record_event("phase_changed", {
		"day": _day,
		"phase": _phase,
	})
	if _phase == "morning":
		_clear_enemies_for_dawn()
	if day_night.is_night() and ari != null:
		ari.call("stop_daytime_job", "Night has started")
		_show_current_job_thought(true)
	_emit_state()


func _on_ari_died() -> void:
	wave_director.restart()
	set_mining_enabled(false)
	var earned := 0
	if permanent_progression != null and permanent_progression.has_method("award_death_reward") and not _visual_review_staging:
		earned = int(permanent_progression.call("award_death_reward", day_night.day))
		_set_status_message("Death lesson: +%d Time Points." % earned, 2.4)
	death_reward = earned
	ari_memory.record_event("death", {
		"day": day_night.day,
		"phase": day_night.phase,
		"sign": sign_text,
	})
	death_recap = _build_death_recap(earned)
	_show_ari_thought("I died. The sign was not enough yet.", true)
	_emit_state()


func _on_ari_damaged(hp: float) -> void:
	if ari == null:
		return
	var max_hp := float(ari.get("max_hp"))
	var hp_ratio := hp / maxf(max_hp, 1.0)
	var thought: String = str(ari_mind.call("thought_for_damage", hp, max_hp))
	ari_memory.record_event("ari_damaged", {
		"hp": hp,
		"day": day_night.day,
		"phase": day_night.phase,
	})
	if hp_ratio <= 0.34 and not _near_death_reported:
		_near_death_reported = true
		ari_memory.record_event("near_death", {
			"hp": hp,
			"day": day_night.day,
			"phase": day_night.phase,
		})
		ari_memory.record_event("ari_near_death", {
			"hp": hp,
			"day": day_night.day,
			"phase": day_night.phase,
		})
		_show_ari_thought("That was too close. I need distance, cover, or something that hurts them first.", true)
	else:
		_show_ari_thought(thought)


func _on_ari_job_changed(job: String, reason: String) -> void:
	var thought: String = str(ari_mind.call("thought_for_job", job, reason, _get_run_build_context()))
	if job == "rest":
		var latest_note := _get_latest_lifetime_note()
		if not latest_note.is_empty():
			var hypothesis := str(latest_note.get("hypothesis", "")).strip_edges()
			if hypothesis != "":
				thought = "I read the last note again. %s" % hypothesis
			ari_memory.record_event("note_reread", {
				"title": str(latest_note.get("title", "")),
				"day": day_night.day,
				"phase": day_night.phase,
			})
	_show_ari_thought(thought)


func _place_wall_at_cell(cell: Vector2i) -> bool:
	return _place_structure_at_cell(WALL_BUILD_ID, cell)


func _place_aura_orb_at_cell(cell: Vector2i) -> bool:
	return _place_structure_at_cell(AURA_ORB_BUILD_ID, cell)


func _place_spike_trap_at_cell(cell: Vector2i) -> bool:
	return _place_structure_at_cell(SPIKE_TRAP_BUILD_ID, cell)


func _place_bow_tower_at_cell(cell: Vector2i) -> bool:
	return _place_structure_at_cell(BOW_TOWER_BUILD_ID, cell)


func _place_tar_pit_at_cell(cell: Vector2i) -> bool:
	return _place_structure_at_cell(TAR_PIT_BUILD_ID, cell)


func _place_fear_lantern_at_cell(cell: Vector2i) -> bool:
	return _place_structure_at_cell(FEAR_LANTERN_BUILD_ID, cell)


func _place_decoy_idol_at_cell(cell: Vector2i) -> bool:
	return _place_structure_at_cell(DECOY_IDOL_BUILD_ID, cell)


func _place_thorn_totem_at_cell(cell: Vector2i) -> bool:
	return _place_structure_at_cell(THORN_TOTEM_BUILD_ID, cell)


func _place_repair_bench_at_cell(cell: Vector2i) -> bool:
	return _place_structure_at_cell(REPAIR_BENCH_BUILD_ID, cell)


func _place_storm_rod_at_cell(cell: Vector2i) -> bool:
	return _place_structure_at_cell(STORM_ROD_BUILD_ID, cell)


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
	structure.connect("destroyed", Callable(self, "_on_structure_destroyed"))
	structures.append(structure)
	structure_cells[cell] = structure
	if build_type == WALL_BUILD_ID:
		walls.append(structure)
	elif build_type == AURA_ORB_BUILD_ID:
		aura_orbs.append(structure)
		structure.call("setup_aura", self)
	elif build_type == SPIKE_TRAP_BUILD_ID:
		spike_traps.append(structure)
		structure.call("setup_trap", self)
	elif build_type == BOW_TOWER_BUILD_ID:
		bow_towers.append(structure)
		structure.call("setup_tower", self)
	elif build_type == TAR_PIT_BUILD_ID:
		tar_pits.append(structure)
		structure.call("setup_tar_pit", self)
	elif build_type == FEAR_LANTERN_BUILD_ID:
		fear_lanterns.append(structure)
	elif build_type == DECOY_IDOL_BUILD_ID:
		decoy_idols.append(structure)
	elif build_type == THORN_TOTEM_BUILD_ID:
		thorn_totems.append(structure)
	elif build_type == REPAIR_BENCH_BUILD_ID:
		repair_benches.append(structure)
	elif build_type == STORM_ROD_BUILD_ID:
		storm_rods.append(structure)
		structure.call("setup_storm_rod", self)
	_set_status_message("%s placed. -%d stone." % [_get_build_name(build_type), int(cost.get("stone", 0))], 1.2)
	_emit_state()
	return true


func _on_structure_destroyed(structure: Node) -> void:
	structures.erase(structure)
	walls.erase(structure)
	aura_orbs.erase(structure)
	spike_traps.erase(structure)
	bow_towers.erase(structure)
	tar_pits.erase(structure)
	fear_lanterns.erase(structure)
	decoy_idols.erase(structure)
	thorn_totems.erase(structure)
	repair_benches.erase(structure)
	storm_rods.erase(structure)
	var structure_type := str(structure.get("structure_type"))
	ari_memory.record_event("structure_destroyed", {
		"structure_type": structure_type,
		"day": day_night.day,
		"phase": day_night.phase,
	})
	if structure_type == WALL_BUILD_ID:
		ari_memory.record_event("wall_destroyed", {
			"structure_type": structure_type,
			"day": day_night.day,
			"phase": day_night.phase,
		})
	_show_structure_destroyed_thought(structure_type)
	var cell_to_remove = null
	for cell in structure_cells.keys():
		if structure_cells[cell] == structure:
			cell_to_remove = cell
			break
	if cell_to_remove != null:
		structure_cells.erase(cell_to_remove)
	_emit_state()


func record_structure_damaged(structure: Node, damage: float) -> void:
	if structure == null or not is_instance_valid(structure):
		return
	ari_memory.record_event("structure_damaged", {
		"structure_type": str(structure.get("structure_type")),
		"damage": maxf(float(damage), 0.0),
		"hp_ratio": float(structure.call("get_hp_ratio")) if structure.has_method("get_hp_ratio") else 1.0,
		"day": day_night.day,
		"phase": day_night.phase,
	})


func _on_enemy_died(enemy: Node) -> void:
	enemies.erase(enemy)
	var healed := 0.0
	if ari != null and ari.has_method("restore_from_kill"):
		healed = float(ari.call("restore_from_kill"))
	ari_memory.record_event("enemy_killed", {
		"enemy_type": str(enemy.get("enemy_type")) if enemy != null else "enemy",
		"regen_healed": healed,
		"day": day_night.day,
		"phase": day_night.phase,
	})
	if healed > 0.0 and not _regen_on_kill_reported:
		_regen_on_kill_reported = true
		_show_ari_thought("The kill gave a little life back.", true)
	_emit_state()


func _on_resource_changed(_resource_state: Dictionary) -> void:
	_emit_state()


func _on_permanent_progression_changed(_progression_state: Dictionary) -> void:
	_apply_run_build_to_ari()
	_reinterpret_current_sign()
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
		_clear_ari_intent()
		return
	if day_night.is_night():
		_advance_ari_night_tactic(delta)
		return

	if _is_mining_enabled():
		_set_ari_intent(_get_mining_spot(), "Mine")
		ari.call("advance_mining_job", delta, true, "Debug mining")
		return

	var decision: Dictionary = ari_mind.call("choose_daytime_job", _get_ari_mind_context())
	var job := str(decision.get("job", "wait_or_idle"))
	var reason := str(decision.get("reason", "Waiting"))
	match job:
		"mine_stone":
			_set_ari_intent(_get_mining_spot(), "Mine")
			ari.call("advance_mining_job", delta, true, reason)
		"mine_ore":
			_advance_ari_mine_ore_job(delta, reason)
		"farm_food":
			_set_ari_intent(_get_station_spot(farm_plot, "get_work_spot"), "Farm")
			var produced := int(ari.call("advance_farming_job", delta, true, reason))
			if produced > 0:
				var bonus_food := _take_permanent_farming_bonus(produced)
				if bonus_food > 0 and resource_system != null and resource_system.has_method("add_food"):
					resource_system.call("add_food", bonus_food)
				ari_memory.record_event("food_harvested", {"food": produced + bonus_food, "day": day_night.day})
				_show_ari_thought("If I am fed, the night feels smaller.")
		"eat_food":
			_set_ari_intent(ari.global_position, "Eat")
			_advance_ari_eat_job(reason)
		"rest":
			_set_ari_intent(_get_station_spot(bed_station, "get_rest_spot"), "Rest")
			ari.call("advance_rest_job", delta, true, reason)
		"reflect_library":
			_set_ari_intent(_get_station_spot(library_station, "get_reflection_spot"), "Reflect")
			var completed := int(ari.call("advance_reflection_job", delta, true, reason))
			if completed > 0:
				_create_library_note()
		"build_wall":
			_advance_ari_build_job(delta, WALL_BUILD_ID, reason)
		"place_aura_orb":
			_advance_ari_build_job(delta, AURA_ORB_BUILD_ID, reason)
		"build_spike_trap":
			_advance_ari_build_job(delta, SPIKE_TRAP_BUILD_ID, reason)
		"build_bow_tower":
			_advance_ari_build_job(delta, BOW_TOWER_BUILD_ID, reason)
		"build_tar_pit":
			_advance_ari_build_job(delta, TAR_PIT_BUILD_ID, reason)
		"build_fear_lantern":
			_advance_ari_build_job(delta, FEAR_LANTERN_BUILD_ID, reason)
		"build_decoy_idol":
			_advance_ari_build_job(delta, DECOY_IDOL_BUILD_ID, reason)
		"build_thorn_totem":
			_advance_ari_build_job(delta, THORN_TOTEM_BUILD_ID, reason)
		"build_repair_bench":
			_advance_ari_build_job(delta, REPAIR_BENCH_BUILD_ID, reason)
		"build_storm_rod":
			_advance_ari_build_job(delta, STORM_ROD_BUILD_ID, reason)
		"repair_structure":
			_advance_ari_repair_job(delta, reason)
		"train_combat":
			_set_ari_intent(_get_station_spot(training_dummy, "get_training_spot"), "Train")
			ari.call("advance_training_job", delta, true, reason)
		"train_sword":
			_set_ari_intent(_get_station_spot(training_dummy, "get_training_spot"), "Train")
			ari.call("advance_sword_training_job", delta, true, reason)
		"smith_sword":
			_advance_ari_smithing_job(delta, reason)
		"fight_head_on":
			_advance_ari_melee_job(delta, reason)
		"stall_until_dawn", "hide_until_dawn":
			_advance_ari_stall_job(delta, job, reason)
		"use_tower":
			_advance_ari_tower_job(delta, reason)
		"use_cover":
			_advance_ari_cover_job(delta, reason)
		"lure_to_aura":
			_advance_ari_aura_lure_job(delta, reason)
		"flee":
			_advance_ari_flee_job(delta, reason)
		_:
			var wait_position := _get_defense_wait_position()
			_set_ari_intent(wait_position, "Wait")
			ari.call("wait_near", delta, wait_position, reason)


func _advance_ari_night_tactic(delta: float) -> void:
	if enemies.is_empty():
		_clear_ari_intent()
		ari.call("stop_daytime_job", "Night has started")
		return

	var decision: Dictionary = ari_mind.call("choose_night_tactic", _get_night_tactic_context())
	var job := str(decision.get("job", "wait_or_idle"))
	var reason := str(decision.get("reason", "Night has started"))
	match job:
		"use_tower":
			_advance_ari_tower_job(delta, reason)
		"use_cover":
			_advance_ari_cover_job(delta, reason)
		"lure_to_aura":
			_advance_ari_aura_lure_job(delta, reason)
		"fight_head_on":
			_advance_ari_melee_job(delta, reason)
		"stall_until_dawn", "hide_until_dawn":
			_advance_ari_stall_job(delta, job, reason)
		"flee":
			_advance_ari_flee_job(delta, reason)
		_:
			var wait_position := _get_defense_wait_position()
			_set_ari_intent(wait_position, "Wait")
			ari.call("wait_near", delta, wait_position, reason)


func _advance_ari_mine_ore_job(delta: float, reason: String) -> void:
	if mine_node == null or resource_system == null:
		ari.call("stop_daytime_job", "Cannot mine ore now")
		return
	var target_position := _get_mining_spot()
	_set_ari_intent(target_position, "Mine")
	var arrived: bool = bool(ari.call("advance_move_job", delta, "mine_ore", reason, target_position, "mining ore"))
	if arrived and mine_node.has_method("mine_ore"):
		var multiplier := clampf(float(_get_run_build_effects().get("ore_yield_multiplier", 1.0)), 0.5, 3.0)
		if bool(mine_node.call("mine_ore", delta * multiplier, resource_system)):
			ari_memory.record_event("ore_mined", {"ore": _ore_count(), "day": day_night.day, "phase": day_night.phase})


func _advance_ari_smithing_job(delta: float, reason: String) -> void:
	if forge_station == null:
		ari.call("stop_daytime_job", "No forge available")
		return
	var next_data := _next_sword_data()
	if next_data.is_empty():
		ari.call("stop_daytime_job", "Sword is already as good as this forge allows")
		return
	var ore_cost := maxi(int(next_data.get("ore_cost", 0)), 0)
	if _ore_count() < ore_cost:
		ari.call("stop_daytime_job", "Need ore for sword")
		return
	var target_position: Vector2 = forge_station.call("get_smith_spot") if forge_station.has_method("get_smith_spot") else forge_station.global_position
	_set_ari_intent(target_position, "Forge")
	var arrived: bool = bool(ari.call("advance_move_job", delta, "smith_sword", reason, target_position, "smithing"))
	if not arrived or not forge_station.has_method("smith"):
		return
	var multiplier := clampf(float(_get_run_build_effects().get("smithing_speed_multiplier", 1.0)), 0.5, 3.0)
	var completed := int(forge_station.call("smith", delta * multiplier))
	if completed <= 0:
		return
	if not _spend_cost({"ore": ore_cost}):
		ari.call("stop_daytime_job", "Need ore for sword")
		return
	_current_sword_id = _next_sword_id()
	_apply_current_sword_to_ari()
	ari_memory.record_event("sword_smithed", {
		"sword": str(next_data.get("display_name", _current_sword_id)),
		"tier": int(next_data.get("tier", 0)),
		"day": day_night.day,
		"phase": day_night.phase,
	})
	_set_status_message("%s forged. -%d ore." % [str(next_data.get("display_name", "Sword")), ore_cost], 2.0)
	_show_ari_thought("The sword is heavier now. Maybe I can make contact cost them.", true)


func _advance_ari_stall_job(delta: float, job: String, reason: String) -> void:
	var cover := _find_cover_position()
	if bool(cover.get("valid", false)):
		var target_position: Vector2 = cover["position"]
		_set_ari_intent(target_position, "Wait")
		ari.call("advance_move_job", delta, job, reason, target_position, "stalling until dawn")
		return
	if _nearest_enemy_distance_from(ari.global_position) < 120.0:
		_advance_ari_flee_job(delta, reason)
		return
	var wait_position := _get_defense_wait_position()
	_set_ari_intent(wait_position, "Wait")
	ari.call("advance_move_job", delta, job, reason, wait_position, "waiting for morning")


func _advance_ari_build_job(delta: float, build_type: String, reason: String) -> void:
	var slot := _get_next_build_slot(build_type)
	if not slot.has("cell"):
		ari.call("stop_daytime_job", "No open defense slot")
		return

	var cell: Vector2i = slot["cell"]
	var target_position: Vector2 = build_grid.call("cell_to_world_center", cell)
	_set_ari_intent(target_position, _intent_label_for_build_type(build_type))
	var action := _action_for_build_type(build_type)
	var arrived: bool = bool(ari.call("advance_move_job", delta, _job_name_for_build_type(build_type), reason, target_position, action))
	if arrived:
		_place_structure_at_cell(build_type, cell)


func _advance_ari_repair_job(delta: float, reason: String) -> void:
	var target_structure := _get_most_damaged_structure()
	if target_structure == null:
		ari.call("stop_daytime_job", "Nothing needs repair")
		return
	var target_position: Vector2 = target_structure.global_position
	_set_ari_intent(target_position, "Repair")
	var arrived: bool = bool(ari.call("advance_move_job", delta, "repair_structure", reason, target_position, "repairing structure"))
	if not arrived or not is_instance_valid(target_structure) or not target_structure.has_method("repair"):
		return
	var repair_amount := 7.0 * maxf(delta, 0.0) * _get_active_repair_multiplier(target_position)
	var repaired := float(target_structure.call("repair", repair_amount))
	if repaired > 0.0 and not bool(target_structure.call("needs_repair")):
		ari_memory.record_event("structure_repaired", {
			"structure_type": str(target_structure.get("structure_type")),
			"day": day_night.day,
			"phase": day_night.phase,
		})


func _advance_ari_tower_job(delta: float, reason: String) -> void:
	var tower := _nearest_valid_structure(bow_towers)
	if tower == null:
		if day_night.is_night():
			_advance_ari_flee_job(delta, "The tower is gone; find another answer")
		else:
			ari.call("stop_daytime_job", "No tower perch available")
		return

	var target_position := _get_tower_perch_position(tower)
	_set_ari_intent(target_position, "Tower")
	var arrived: bool = bool(ari.call("advance_move_job", delta, "use_tower", reason, target_position, "using tower perch"))
	if arrived:
		_advance_ari_ranged_attack(delta, tower)


func _advance_ari_cover_job(delta: float, reason: String) -> void:
	var cover := _find_cover_position()
	if not bool(cover.get("valid", false)):
		_advance_ari_flee_job(delta, "The wall is gone; find another answer")
		return
	var target_position: Vector2 = cover["position"]
	if day_night.is_night() and _is_position_too_dangerous(target_position):
		_advance_ari_flee_job(delta, "Enemies are too close; move")
		return
	_set_ari_intent(target_position, "Cover")
	ari.call("advance_move_job", delta, "use_cover", reason, target_position, "using wall cover")


func _advance_ari_aura_lure_job(delta: float, reason: String) -> void:
	var lure := _find_aura_lure_position()
	if not bool(lure.get("valid", false)):
		_advance_ari_flee_job(delta, "The light is gone; find another answer")
		return
	var target_position: Vector2 = lure["position"]
	if day_night.is_night() and _is_position_too_dangerous(target_position):
		_advance_ari_flee_job(delta, "Enemies are too close; move")
		return
	_set_ari_intent(target_position, "Lure")
	ari.call("advance_move_job", delta, "lure_to_aura", reason, target_position, "luring through aura")


func _advance_ari_flee_job(delta: float, reason: String) -> void:
	var target_position := _find_flee_position()
	_set_ari_intent(target_position, "Flee")
	ari.call("advance_move_job", delta, "flee", reason, target_position, "fleeing")


func _advance_ari_melee_job(delta: float, reason: String) -> void:
	var target_enemy := get_nearest_enemy(ari.global_position if ari != null else _get_defense_anchor())
	if target_enemy == null:
		ari.call("stop_daytime_job", "No enemy close enough to fight")
		return
	if str(target_enemy.get("enemy_type")) == "flying":
		_advance_ari_flee_job(delta, "A sword cannot answer wings")
		return
	var direction := target_enemy.global_position - ari.global_position
	var distance := direction.length()
	var target_position := target_enemy.global_position
	if distance > 29.0 and direction.length() > 0.01:
		target_position = target_enemy.global_position - direction.normalized() * 24.0
	_set_ari_intent(target_position, "Fight")
	var arrived: bool = bool(ari.call("advance_move_job", delta, "fight_head_on", reason, target_position, "fighting head on"))
	if arrived:
		_advance_ari_melee_attack(target_enemy)


func _advance_ari_melee_attack(target_enemy: Node2D) -> void:
	if _ari_melee_cooldown > 0.0 or ari == null or not _is_ari_alive():
		return
	if target_enemy == null or not is_instance_valid(target_enemy) or not target_enemy.has_method("take_damage"):
		return
	if ari.global_position.distance_to(target_enemy.global_position) > 36.0:
		return
	var origin := ari.global_position
	var target_position := target_enemy.global_position
	var damage := 8.0
	if ari.has_method("get_melee_damage"):
		damage = float(ari.call("get_melee_damage"))
	target_enemy.call("take_damage", damage)
	_ari_melee_cooldown = float(ari.call("get_melee_cooldown")) if ari.has_method("get_melee_cooldown") else 0.8
	_ari_melee_flash_time = 0.26
	_ari_melee_flash_from = origin
	_ari_melee_flash_to = target_position
	ari_memory.record_event("ari_melee_hit", {
		"damage": damage,
		"day": day_night.day,
		"phase": day_night.phase,
	})


func _advance_ari_ranged_attack(_delta: float, tower: Node2D) -> void:
	if _ari_ranged_cooldown > 0.0 or ari == null or not _is_ari_alive():
		return
	var origin := ari.global_position
	var range_radius := _get_tower_range(tower)
	var target_enemy := _nearest_enemy_in_range(origin, range_radius)
	if target_enemy == null:
		return

	var target_position := target_enemy.global_position
	var damage := _get_tower_damage(tower)
	var combat_stats := _get_ari_combat_stats()
	damage *= 1.0 + float(combat_stats.get("damage_bonus", 0.0))
	target_enemy.call("take_damage", damage)
	if is_instance_valid(tower) and tower.has_method("record_shot"):
		tower.call("record_shot")
	_ari_ranged_cooldown = _get_tower_shot_cooldown(tower)
	_ari_ranged_flash_time = 0.35
	_ari_ranged_flash_from = origin
	_ari_ranged_flash_to = target_position
	ari_memory.record_event("ari_ranged_hit", {
		"damage": damage,
		"day": day_night.day,
		"phase": day_night.phase,
	})
	ari_memory.record_event("tower_ranged_success", {
		"damage": damage,
		"day": day_night.day,
		"phase": day_night.phase,
	})


func _get_ari_mind_context() -> Dictionary:
	return {
		"is_night": day_night.is_night(),
		"phase": day_night.phase,
		"time_left": day_night.get_time_left(),
		"night_close": day_night.phase == "dusk" and day_night.get_time_left() <= float(ari_mind.get("night_close_seconds")),
		"stone": _stone_count(),
		"ore": _ore_count(),
		"sword_tier": _current_sword_tier(),
		"sword_next_ore_cost": _next_sword_ore_cost(),
		"sword_max_tier": maxi(_sword_order.size() - 1, 0),
		"wall_cost": int(_get_wall_cost().get("stone", 0)),
		"aura_orb_cost": int(_get_aura_orb_cost().get("stone", 0)),
		"spike_trap_cost": int(_get_spike_trap_cost().get("stone", 0)),
		"bow_tower_cost": int(_get_bow_tower_cost().get("stone", 0)),
		"tar_pit_cost": int(_get_tar_pit_cost().get("stone", 0)),
		"fear_lantern_cost": int(_get_fear_lantern_cost().get("stone", 0)),
		"decoy_idol_cost": int(_get_decoy_idol_cost().get("stone", 0)),
		"thorn_totem_cost": int(_get_thorn_totem_cost().get("stone", 0)),
		"repair_bench_cost": int(_get_repair_bench_cost().get("stone", 0)),
		"storm_rod_cost": int(_get_storm_rod_cost().get("stone", 0)),
		"wall_count": walls.size(),
		"aura_orb_count": aura_orbs.size(),
		"spike_trap_count": spike_traps.size(),
		"bow_tower_count": bow_towers.size(),
		"tar_pit_count": tar_pits.size(),
		"fear_lantern_count": fear_lanterns.size(),
		"decoy_idol_count": decoy_idols.size(),
		"thorn_totem_count": thorn_totems.size(),
		"repair_bench_count": repair_benches.size(),
		"storm_rod_count": storm_rods.size(),
		"enemy_type_counts": _get_enemy_type_counts(),
		"damaged_structure_count": _get_damaged_structure_count(),
		"lowest_structure_hp_ratio": _get_lowest_structure_hp_ratio(),
		"combat_stats": _get_ari_combat_stats(),
		"needs": _get_ari_needs(),
		"food": _food_count(),
		"ari_hp_ratio": _get_ari_hp_ratio(),
		"lesson_count": _get_lesson_count(),
		"meaningful_event_count": _get_meaningful_event_count(),
		"lesson_priority_bias": _get_lesson_priority_bias(),
		"priority_hints": sign_priority_hints,
		"grounded_plan": sign_grounded_plan,
		"run_build": _get_run_build_context(),
		"current_job": str(ari.call("get_current_job")) if ari != null else "wait_or_idle",
	}


func _get_night_tactic_context() -> Dictionary:
	var context := _get_ari_mind_context()
	var cover := _find_cover_position()
	var lure := _find_aura_lure_position()
	var tower := _nearest_valid_structure(bow_towers)
	context["enemy_count"] = enemies.size()
	context["nearest_enemy_distance"] = _nearest_enemy_distance_from(ari.global_position if ari != null else _get_defense_anchor())
	context["ari_hp_ratio"] = _get_ari_hp_ratio()
	context["has_valid_cover"] = bool(cover.get("valid", false))
	context["has_valid_aura"] = bool(lure.get("valid", false))
	context["has_valid_tower"] = tower != null
	return context


func _get_run_build_context() -> Dictionary:
	if run_build != null and run_build.has_method("get_context"):
		var context = run_build.call("get_context")
		if typeof(context) == TYPE_DICTIONARY:
			return context
	return {}


func _get_permanent_progression_state() -> Dictionary:
	if permanent_progression != null and permanent_progression.has_method("get_state"):
		var state = permanent_progression.call("get_state")
		if typeof(state) == TYPE_DICTIONARY:
			return state
	return {}


func _get_lesson_priority_bias() -> Dictionary:
	if ari_memory != null and ari_memory.has_method("get_note_priority_bias"):
		var memory_bias = ari_memory.call("get_note_priority_bias")
		if typeof(memory_bias) == TYPE_DICTIONARY and not memory_bias.is_empty():
			return memory_bias.duplicate(true)
	var latest_note := lesson_book.get_latest_note()
	if latest_note.is_empty():
		return {}
	var bias = latest_note.get("priority_bias", {})
	if typeof(bias) == TYPE_DICTIONARY:
		return bias.duplicate(true)
	return {}


func _get_lesson_count() -> int:
	if ari_memory != null and ari_memory.has_method("get_lifetime_notes"):
		var notes = ari_memory.call("get_lifetime_notes")
		if typeof(notes) == TYPE_ARRAY:
			return notes.size()
	return lesson_book.get_all_notes().size()


func _get_latest_lifetime_note() -> Dictionary:
	if ari_memory != null and ari_memory.has_method("get_latest_lifetime_note"):
		var note = ari_memory.call("get_latest_lifetime_note")
		if typeof(note) == TYPE_DICTIONARY:
			return note
	return lesson_book.get_latest_note()


func _get_meaningful_event_count() -> int:
	if ari_memory != null and ari_memory.has_method("get_meaningful_event_count"):
		return int(ari_memory.call("get_meaningful_event_count", 30))
	return 0


func _get_ari_combat_stats() -> Dictionary:
	if ari != null and ari.has_method("get_combat_stats"):
		var combat_stats = ari.call("get_combat_stats")
		if typeof(combat_stats) == TYPE_DICTIONARY:
			return combat_stats
	return {
		"combat_level": 0.0,
		"accuracy_bonus": 0.0,
		"damage_bonus": 0.0,
		"defense_training": 0.0,
		"sword_skill": 0.0,
		"sword_tier": 0,
		"attack_damage": 7.0,
		"attack_speed": 1.0,
		"armor": 0.0,
		"passive_regen": 0.0,
		"regen_on_kill": 0.0,
	}


func _current_sword_data() -> Dictionary:
	return _sword_data(_current_sword_id)


func _sword_data(sword_id: String) -> Dictionary:
	var tiers = _weapon_data.get("sword_tiers", {})
	if typeof(tiers) == TYPE_DICTIONARY:
		var data = tiers.get(sword_id, {})
		if typeof(data) == TYPE_DICTIONARY:
			return data.duplicate(true)
	return {}


func _current_sword_tier() -> int:
	return int(_current_sword_data().get("tier", 0))


func _next_sword_id() -> String:
	var index := _sword_order.find(_current_sword_id)
	if index < 0:
		index = 0
	if index + 1 >= _sword_order.size():
		return ""
	return _sword_order[index + 1]


func _next_sword_data() -> Dictionary:
	var next_id := _next_sword_id()
	if next_id == "":
		return {}
	return _sword_data(next_id)


func _next_sword_ore_cost() -> int:
	var next_data := _next_sword_data()
	if next_data.is_empty():
		return 0
	return maxi(int(next_data.get("ore_cost", 0)), 0)


func _apply_current_sword_to_ari() -> void:
	if ari == null or not ari.has_method("set_sword_tier"):
		return
	var data := _current_sword_data()
	ari.call(
		"set_sword_tier",
		int(data.get("tier", 0)),
		str(data.get("display_name", "Hands")),
		float(data.get("damage_bonus", 0.0)),
		float(data.get("armor_bonus", 0.0))
	)


func _get_ari_hp_ratio() -> float:
	if ari == null:
		return 0.0
	return clampf(float(ari.get("hp")) / maxf(float(ari.get("max_hp")), 1.0), 0.0, 1.0)


func _get_ari_needs() -> Dictionary:
	if ari != null and ari.has_method("get_needs"):
		var needs = ari.call("get_needs")
		if typeof(needs) == TYPE_DICTIONARY:
			return needs
	return {
		"hunger": 0.0,
		"max_hunger": 100.0,
		"stamina": 0.0,
		"max_stamina": 100.0,
		"fear": 0.0,
		"max_fear": 100.0,
	}


func _get_damaged_structure_count() -> int:
	var count := 0
	for structure in structures:
		if is_instance_valid(structure) and structure.has_method("needs_repair") and bool(structure.call("needs_repair")):
			count += 1
	return count


func _get_lowest_structure_hp_ratio() -> float:
	var lowest := 1.0
	for structure in structures:
		if not is_instance_valid(structure) or not structure.has_method("get_hp_ratio"):
			continue
		lowest = minf(lowest, float(structure.call("get_hp_ratio")))
	return lowest


func _get_most_damaged_structure() -> Node2D:
	var target_structure: Node2D = null
	var lowest := 1.0
	for structure in structures:
		if not is_instance_valid(structure) or not structure.has_method("needs_repair") or not bool(structure.call("needs_repair")):
			continue
		var ratio := float(structure.call("get_hp_ratio")) if structure.has_method("get_hp_ratio") else 1.0
		if ratio < lowest:
			lowest = ratio
			target_structure = structure
	return target_structure


func _get_active_repair_multiplier(structure_position: Vector2) -> float:
	var multiplier := float(_get_run_build_effects().get("repair_speed_multiplier", 1.0))
	for repair_bench in repair_benches:
		if is_instance_valid(repair_bench) and repair_bench.has_method("get_active_repair_multiplier_for"):
			multiplier = maxf(multiplier, float(repair_bench.call("get_active_repair_multiplier_for", structure_position)))
	return clampf(multiplier, 0.5, 3.0)


func _take_permanent_farming_bonus(produced: int) -> int:
	var multiplier := maxf(float(_get_run_build_effects().get("farming_yield_multiplier", 1.0)), 1.0)
	_farming_yield_remainder += float(maxi(produced, 0)) * (multiplier - 1.0)
	var bonus := int(floor(_farming_yield_remainder))
	if bonus > 0:
		_farming_yield_remainder -= float(bonus)
	return bonus


func _damage_structure_near(world_position: Vector2, amount: float) -> void:
	var cell: Vector2i = build_grid.call("world_to_cell", world_position)
	var structure = structure_cells.get(cell)
	if is_instance_valid(structure) and structure.has_method("take_damage"):
		structure.call("take_damage", amount)


func _get_run_build_effects() -> Dictionary:
	var effects := {}
	if run_build != null and run_build.has_method("get_effects"):
		var run_effects = run_build.call("get_effects")
		if typeof(run_effects) == TYPE_DICTIONARY:
			effects = run_effects.duplicate(true)
	if permanent_progression != null and permanent_progression.has_method("get_effects"):
		var permanent_effects = permanent_progression.call("get_effects")
		if typeof(permanent_effects) == TYPE_DICTIONARY:
			effects = _merge_effects(effects, permanent_effects)
	return effects


func _merge_effects(base_effects: Dictionary, extra_effects: Dictionary) -> Dictionary:
	var result := base_effects.duplicate(true)
	for key in extra_effects.keys():
		var effect_key := str(key)
		var value := float(extra_effects[key])
		if effect_key.ends_with("_multiplier"):
			result[effect_key] = float(result.get(effect_key, 1.0)) * value
		elif effect_key.ends_with("_bonus") or effect_key.ends_with("_strength"):
			result[effect_key] = float(result.get(effect_key, 0.0)) + value
		else:
			result[effect_key] = extra_effects[key]
	return result


func _apply_run_build_to_ari() -> void:
	if ari == null or not ari.has_method("apply_run_build_effects"):
		return
	ari.call("apply_run_build_effects", _get_run_build_effects())
	_apply_current_sword_to_ari()


func _get_next_build_slot(build_type: String) -> Dictionary:
	var offsets := _build_slot_offsets(build_type)
	for offset in offsets:
		var cell: Vector2i = build_grid.call("world_to_cell", _get_defense_anchor() + offset)
		if bool(build_grid.call("is_cell_in_arena", cell)) and not structure_cells.has(cell):
			return {
				"cell": cell,
			}
	return {}


func _build_slot_offsets(build_type: String) -> Array:
	if build_type == AURA_ORB_BUILD_ID:
		return _aura_orb_slot_offsets()
	if build_type == SPIKE_TRAP_BUILD_ID:
		return _spike_trap_slot_offsets()
	if build_type == BOW_TOWER_BUILD_ID:
		return _bow_tower_slot_offsets()
	if build_type == TAR_PIT_BUILD_ID:
		return _tar_pit_slot_offsets()
	if build_type == FEAR_LANTERN_BUILD_ID:
		return _fear_lantern_slot_offsets()
	if build_type == DECOY_IDOL_BUILD_ID:
		return _decoy_idol_slot_offsets()
	if build_type == THORN_TOTEM_BUILD_ID:
		return _thorn_totem_slot_offsets()
	if build_type == REPAIR_BENCH_BUILD_ID:
		return _repair_bench_slot_offsets()
	if build_type == STORM_ROD_BUILD_ID:
		return _storm_rod_slot_offsets()
	return _wall_slot_offsets()


func _wall_slot_offsets() -> Array:
	return [
		Vector2(72.0, -16.0),
		Vector2(144.0, -16.0),
		Vector2(72.0, 40.0),
		Vector2(144.0, 40.0),
	]


func _aura_orb_slot_offsets() -> Array:
	return [
		Vector2(108.0, 12.0),
	]


func _spike_trap_slot_offsets() -> Array:
	return [
		Vector2(216.0, -36.0),
		Vector2(216.0, 40.0),
	]


func _bow_tower_slot_offsets() -> Array:
	return [
		Vector2(144.0, -112.0),
	]


func _tar_pit_slot_offsets() -> Array:
	return [
		Vector2(216.0, 56.0),
		Vector2(276.0, 40.0),
	]


func _fear_lantern_slot_offsets() -> Array:
	return [
		Vector2(-8.0, 16.0),
		Vector2(-24.0, 64.0),
	]


func _decoy_idol_slot_offsets() -> Array:
	return [
		Vector2(308.0, -16.0),
		Vector2(308.0, 56.0),
	]


func _thorn_totem_slot_offsets() -> Array:
	return [
		Vector2(-96.0, -48.0),
		Vector2(-64.0, 8.0),
	]


func _repair_bench_slot_offsets() -> Array:
	return [
		Vector2(-160.0, 48.0),
		Vector2(-160.0, -24.0),
	]


func _storm_rod_slot_offsets() -> Array:
	return [
		Vector2(244.0, -112.0),
		Vector2(244.0, -80.0),
	]


func _get_defense_anchor() -> Vector2:
	return get_arena_rect().get_center()


func _get_defense_wait_position() -> Vector2:
	return _get_defense_anchor() + Vector2(-32.0, 0.0)


func _find_cover_position() -> Dictionary:
	var wall := _nearest_valid_structure(walls)
	if wall == null:
		return {"valid": false}
	var anchor := _get_defense_anchor()
	var wall_position: Vector2 = wall.global_position
	var direction := anchor - wall_position
	var enemy := get_nearest_enemy(wall_position)
	if enemy != null:
		direction = wall_position - enemy.global_position
	elif direction.length() < 0.1 and ari != null:
		direction = ari.global_position - wall_position
	if direction.length() < 0.1:
		direction = Vector2.LEFT
	return {
		"valid": true,
		"position": _clamp_point_to_arena(wall_position + direction.normalized() * 38.0),
		"structure": wall,
	}


func _find_aura_lure_position() -> Dictionary:
	var aura := _nearest_valid_structure(aura_orbs)
	if aura == null:
		return {"valid": false}
	var anchor := _get_defense_anchor()
	var aura_position: Vector2 = aura.global_position
	var direction := anchor - aura_position
	var enemy := get_nearest_enemy(aura_position)
	if enemy != null:
		direction = aura_position - enemy.global_position
	elif direction.length() < 0.1 and ari != null:
		direction = ari.global_position - aura_position
	if direction.length() < 0.1:
		direction = Vector2.LEFT
	var radius := 96.0
	var radius_value = aura.get("aura_radius")
	if typeof(radius_value) == TYPE_FLOAT or typeof(radius_value) == TYPE_INT:
		radius = float(radius_value)
	return {
		"valid": true,
		"position": _clamp_point_to_arena(aura_position + direction.normalized() * minf(radius * 0.55, 58.0)),
		"structure": aura,
	}


func _get_tower_perch_position(tower: Node2D) -> Vector2:
	if is_instance_valid(tower) and tower.has_method("get_perch_position"):
		var perch = tower.call("get_perch_position")
		if typeof(perch) == TYPE_VECTOR2:
			return perch
	return tower.global_position + Vector2(0.0, -18.0) if is_instance_valid(tower) else _get_defense_wait_position()


func _get_tower_range(tower: Node2D) -> float:
	if is_instance_valid(tower) and tower.has_method("get_range_radius"):
		return maxf(float(tower.call("get_range_radius")), 32.0)
	var data := _get_bow_tower_data()
	return maxf(float(data.get("range", 150.0)) + float(data.get("range_bonus", 0.0)), 32.0)


func _get_tower_damage(tower: Node2D) -> float:
	if is_instance_valid(tower) and tower.has_method("get_attack_damage"):
		return maxf(float(tower.call("get_attack_damage")), 1.0)
	return maxf(float(_get_bow_tower_data().get("damage", 10.0)), 1.0)


func _get_tower_shot_cooldown(tower: Node2D) -> float:
	if is_instance_valid(tower) and tower.has_method("get_shot_cooldown_seconds"):
		return maxf(float(tower.call("get_shot_cooldown_seconds")), 0.15)
	return maxf(float(_get_bow_tower_data().get("shot_cooldown_seconds", 0.7)), 0.15)


func _find_flee_position() -> Vector2:
	var origin := ari.global_position if ari != null else _get_defense_anchor()
	var nearest_enemy := get_nearest_enemy(origin)
	var base_direction := _get_defense_anchor() - origin
	if nearest_enemy != null:
		base_direction = origin - nearest_enemy.global_position
	if base_direction.length() < 0.1:
		base_direction = Vector2.LEFT
	base_direction = base_direction.normalized()

	var directions := [
		base_direction,
		base_direction.rotated(0.62),
		base_direction.rotated(-0.62),
		(_get_defense_anchor() - origin).normalized() if _get_defense_anchor().distance_to(origin) > 1.0 else Vector2.LEFT,
	]
	var best_position := _clamp_point_to_arena(origin + base_direction * 112.0)
	var best_distance := _nearest_enemy_distance_from(best_position)
	for direction in directions:
		var candidate := _clamp_point_to_arena(origin + direction * 112.0)
		var distance := _nearest_enemy_distance_from(candidate)
		if distance > best_distance:
			best_distance = distance
			best_position = candidate
	return best_position


func _nearest_valid_structure(candidates: Array) -> Node2D:
	var target: Node2D = null
	var best_distance := INF
	var origin := ari.global_position if ari != null else _get_defense_anchor()
	for structure in candidates:
		if not is_instance_valid(structure):
			continue
		var structure_node := structure as Node2D
		if structure_node == null:
			continue
		var distance := origin.distance_to(structure_node.global_position)
		if distance < best_distance:
			best_distance = distance
			target = structure_node
	return target


func get_nearest_enemy(origin = null) -> Node2D:
	var check_origin := ari.global_position if ari != null else _get_defense_anchor()
	if typeof(origin) == TYPE_VECTOR2:
		check_origin = origin
	var target: Node2D = null
	var best_distance := INF
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		var distance := check_origin.distance_to(enemy_node.global_position)
		if distance < best_distance:
			best_distance = distance
			target = enemy_node
	return target


func _nearest_enemy_distance_from(point: Vector2) -> float:
	var nearest_enemy := get_nearest_enemy(point)
	if nearest_enemy == null:
		return INF
	return point.distance_to(nearest_enemy.global_position)


func _nearest_enemy_in_range(point: Vector2, range_radius: float) -> Node2D:
	var target: Node2D = null
	var best_distance := INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var enemy_node := enemy as Node2D
		if enemy_node == null:
			continue
		var distance := point.distance_to(enemy_node.global_position)
		if distance <= range_radius and distance < best_distance:
			target = enemy_node
			best_distance = distance
	return target


func _is_position_too_dangerous(point: Vector2, danger_distance := 42.0) -> bool:
	return _nearest_enemy_distance_from(point) <= danger_distance


func _clamp_point_to_arena(point: Vector2) -> Vector2:
	var arena := get_arena_rect().grow(-18.0)
	return Vector2(
		clampf(point.x, arena.position.x, arena.end.x),
		clampf(point.y, arena.position.y, arena.end.y)
	)


func _set_ari_intent(target_position: Vector2, label: String) -> void:
	_ari_intent_active = true
	_ari_intent_target = target_position
	_ari_intent_label = label


func _clear_ari_intent() -> void:
	_ari_intent_active = false
	_ari_intent_target = Vector2.ZERO
	_ari_intent_label = ""


func _get_mining_spot() -> Vector2:
	var offset := Vector2(48.0, 0.0)
	if ari != null:
		var configured_offset = ari.get("mining_spot_offset")
		if typeof(configured_offset) == TYPE_VECTOR2:
			offset = configured_offset
	if mine_node != null:
		return mine_node.global_position + offset
	return _get_defense_wait_position()


func _get_station_spot(station: Node2D, method_name: String) -> Vector2:
	if station != null and station.has_method(method_name):
		var spot = station.call(method_name)
		if typeof(spot) == TYPE_VECTOR2:
			return spot
	if station != null:
		return station.global_position
	return _get_defense_wait_position()


func _intent_label_for_build_type(build_type: String) -> String:
	if build_type == AURA_ORB_BUILD_ID:
		return "Orb"
	if build_type == SPIKE_TRAP_BUILD_ID:
		return "Trap"
	if build_type == BOW_TOWER_BUILD_ID:
		return "Tower"
	if build_type == TAR_PIT_BUILD_ID:
		return "Mud"
	if build_type == FEAR_LANTERN_BUILD_ID:
		return "Lamp"
	if build_type == DECOY_IDOL_BUILD_ID:
		return "Decoy"
	if build_type == THORN_TOTEM_BUILD_ID:
		return "Thorn"
	if build_type == REPAIR_BENCH_BUILD_ID:
		return "Repair"
	if build_type == STORM_ROD_BUILD_ID:
		return "Storm"
	return "Wall"


func _job_name_for_build_type(build_type: String) -> String:
	if build_type == AURA_ORB_BUILD_ID:
		return "place_aura_orb"
	if build_type == SPIKE_TRAP_BUILD_ID:
		return "build_spike_trap"
	if build_type == BOW_TOWER_BUILD_ID:
		return "build_bow_tower"
	if build_type == TAR_PIT_BUILD_ID:
		return "build_tar_pit"
	if build_type == FEAR_LANTERN_BUILD_ID:
		return "build_fear_lantern"
	if build_type == DECOY_IDOL_BUILD_ID:
		return "build_decoy_idol"
	if build_type == THORN_TOTEM_BUILD_ID:
		return "build_thorn_totem"
	if build_type == REPAIR_BENCH_BUILD_ID:
		return "build_repair_bench"
	if build_type == STORM_ROD_BUILD_ID:
		return "build_storm_rod"
	return "build_wall"


func _action_for_build_type(build_type: String) -> String:
	if build_type == AURA_ORB_BUILD_ID:
		return "placing aura orb"
	if build_type == SPIKE_TRAP_BUILD_ID:
		return "setting spike trap"
	if build_type == BOW_TOWER_BUILD_ID:
		return "building tower"
	if build_type == TAR_PIT_BUILD_ID:
		return "digging tar pit"
	if build_type == FEAR_LANTERN_BUILD_ID:
		return "lighting fear lantern"
	if build_type == DECOY_IDOL_BUILD_ID:
		return "placing decoy idol"
	if build_type == THORN_TOTEM_BUILD_ID:
		return "raising thorn totem"
	if build_type == REPAIR_BENCH_BUILD_ID:
		return "building repair bench"
	if build_type == STORM_ROD_BUILD_ID:
		return "raising storm rod"
	return "building wall"


func _get_build_scene(build_type: String) -> PackedScene:
	if build_type == AURA_ORB_BUILD_ID:
		return aura_orb_scene
	if build_type == SPIKE_TRAP_BUILD_ID:
		return spike_trap_scene
	if build_type == BOW_TOWER_BUILD_ID:
		return bow_tower_scene
	if build_type == TAR_PIT_BUILD_ID:
		return tar_pit_scene
	if build_type == FEAR_LANTERN_BUILD_ID:
		return fear_lantern_scene
	if build_type == DECOY_IDOL_BUILD_ID:
		return decoy_idol_scene
	if build_type == THORN_TOTEM_BUILD_ID:
		return thorn_totem_scene
	if build_type == REPAIR_BENCH_BUILD_ID:
		return repair_bench_scene
	if build_type == STORM_ROD_BUILD_ID:
		return storm_rod_scene
	return wall_scene


func _configure_structure(structure: Node2D, build_type: String) -> void:
	structure.set("structure_type", build_type)
	if build_type == AURA_ORB_BUILD_ID:
		structure.call("setup_from_data", _get_aura_orb_data())
	elif build_type == SPIKE_TRAP_BUILD_ID:
		structure.call("setup_from_data", _get_spike_trap_data())
	elif build_type == BOW_TOWER_BUILD_ID:
		structure.call("setup_from_data", _get_bow_tower_data())
	elif build_type == TAR_PIT_BUILD_ID:
		structure.call("setup_from_data", _get_tar_pit_data())
	elif build_type == FEAR_LANTERN_BUILD_ID:
		structure.call("setup_from_data", _get_fear_lantern_data())
	elif build_type == DECOY_IDOL_BUILD_ID:
		structure.call("setup_from_data", _get_decoy_idol_data())
	elif build_type == THORN_TOTEM_BUILD_ID:
		structure.call("setup_from_data", _get_thorn_totem_data())
	elif build_type == REPAIR_BENCH_BUILD_ID:
		structure.call("setup_from_data", _get_repair_bench_data())
	elif build_type == STORM_ROD_BUILD_ID:
		structure.call("setup_from_data", _get_storm_rod_data())
	else:
		structure.set("max_hp", _get_wall_hp())


func _get_build_cost(build_type: String) -> Dictionary:
	if build_type == AURA_ORB_BUILD_ID:
		return _get_aura_orb_cost()
	if build_type == SPIKE_TRAP_BUILD_ID:
		return _get_spike_trap_cost()
	if build_type == BOW_TOWER_BUILD_ID:
		return _get_bow_tower_cost()
	if build_type == TAR_PIT_BUILD_ID:
		return _get_tar_pit_cost()
	if build_type == FEAR_LANTERN_BUILD_ID:
		return _get_fear_lantern_cost()
	if build_type == DECOY_IDOL_BUILD_ID:
		return _get_decoy_idol_cost()
	if build_type == THORN_TOTEM_BUILD_ID:
		return _get_thorn_totem_cost()
	if build_type == REPAIR_BENCH_BUILD_ID:
		return _get_repair_bench_cost()
	if build_type == STORM_ROD_BUILD_ID:
		return _get_storm_rod_cost()
	return _get_wall_cost()


func _get_build_name(build_type: String) -> String:
	if build_type == AURA_ORB_BUILD_ID:
		if resource_system != null and resource_system.has_method("get_structure_display_name"):
			return str(resource_system.call("get_structure_display_name", AURA_ORB_BUILD_ID))
		return "Aura Orb"
	if build_type == SPIKE_TRAP_BUILD_ID:
		if resource_system != null and resource_system.has_method("get_structure_display_name"):
			return str(resource_system.call("get_structure_display_name", SPIKE_TRAP_BUILD_ID))
		return "Spike Trap"
	if build_type == BOW_TOWER_BUILD_ID:
		if resource_system != null and resource_system.has_method("get_structure_display_name"):
			return str(resource_system.call("get_structure_display_name", BOW_TOWER_BUILD_ID))
		return "Tower"
	if build_type == TAR_PIT_BUILD_ID:
		if resource_system != null and resource_system.has_method("get_structure_display_name"):
			return str(resource_system.call("get_structure_display_name", TAR_PIT_BUILD_ID))
		return "Tar Pit"
	if build_type == FEAR_LANTERN_BUILD_ID:
		if resource_system != null and resource_system.has_method("get_structure_display_name"):
			return str(resource_system.call("get_structure_display_name", FEAR_LANTERN_BUILD_ID))
		return "Fear Lantern"
	if build_type == DECOY_IDOL_BUILD_ID:
		if resource_system != null and resource_system.has_method("get_structure_display_name"):
			return str(resource_system.call("get_structure_display_name", DECOY_IDOL_BUILD_ID))
		return "Decoy Idol"
	if build_type == THORN_TOTEM_BUILD_ID:
		if resource_system != null and resource_system.has_method("get_structure_display_name"):
			return str(resource_system.call("get_structure_display_name", THORN_TOTEM_BUILD_ID))
		return "Thorn Totem"
	if build_type == REPAIR_BENCH_BUILD_ID:
		if resource_system != null and resource_system.has_method("get_structure_display_name"):
			return str(resource_system.call("get_structure_display_name", REPAIR_BENCH_BUILD_ID))
		return "Repair Bench"
	if build_type == STORM_ROD_BUILD_ID:
		if resource_system != null and resource_system.has_method("get_structure_display_name"):
			return str(resource_system.call("get_structure_display_name", STORM_ROD_BUILD_ID))
		return "Storm Rod"
	return "Wall"


func _get_selected_build_name() -> String:
	return _get_build_name(selected_build_type)


func _get_selected_preview_radius() -> float:
	if selected_build_type == AURA_ORB_BUILD_ID:
		return float(_get_aura_orb_data().get("radius", 96.0))
	if selected_build_type == BOW_TOWER_BUILD_ID:
		var tower_data := _get_bow_tower_data()
		return float(tower_data.get("range", 150.0)) + float(tower_data.get("range_bonus", 0.0))
	if selected_build_type == TAR_PIT_BUILD_ID:
		return float(_get_tar_pit_data().get("slow_radius", 58.0))
	if selected_build_type == FEAR_LANTERN_BUILD_ID:
		return float(_get_fear_lantern_data().get("soothe_radius", 82.0))
	if selected_build_type == DECOY_IDOL_BUILD_ID:
		return float(_get_decoy_idol_data().get("taunt_radius", 118.0))
	if selected_build_type == THORN_TOTEM_BUILD_ID:
		return float(_get_thorn_totem_data().get("thorn_radius", 76.0))
	if selected_build_type == REPAIR_BENCH_BUILD_ID:
		return float(_get_repair_bench_data().get("repair_radius", 86.0))
	if selected_build_type == STORM_ROD_BUILD_ID:
		return float(_get_storm_rod_data().get("range", 132.0))
	return 0.0


func _get_wall_cost() -> Dictionary:
	if resource_system != null and resource_system.has_method("get_wall_cost"):
		var cost = resource_system.call("get_wall_cost", WALL_MATERIAL_ID)
		if typeof(cost) == TYPE_DICTIONARY:
			return _apply_cost_effects(cost)
	return _apply_cost_effects({"stone": 5})


func _apply_cost_effects(cost: Dictionary) -> Dictionary:
	var result := cost.duplicate(true)
	var multiplier := clampf(float(_get_run_build_effects().get("stone_cost_multiplier", 1.0)), 0.5, 1.5)
	if result.has("stone"):
		result["stone"] = maxi(1, int(ceil(float(result.get("stone", 0)) * multiplier)))
	return result


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
			return _apply_cost_effects(cost)
	return _apply_cost_effects({"stone": 5})


func _get_spike_trap_data() -> Dictionary:
	var data := {
		"display_name": "Spike Trap",
		"hp": 18.0,
		"radius": 22.0,
		"damage": 18.0,
		"uses": 4,
		"stone_cost": 4,
	}
	if resource_system != null and resource_system.has_method("get_structure"):
		var resource_data = resource_system.call("get_structure", SPIKE_TRAP_BUILD_ID)
		if typeof(resource_data) == TYPE_DICTIONARY:
			data = resource_data.duplicate(true)
	var effects := _get_run_build_effects()
	data["damage"] = float(data.get("damage", 18.0)) * float(effects.get("base_damage_multiplier", 1.0)) * (1.0 + float(effects.get("trapcraft_strength", 0.0)) * 0.35)
	return data


func _get_spike_trap_cost() -> Dictionary:
	if resource_system != null and resource_system.has_method("get_structure_cost"):
		var cost = resource_system.call("get_structure_cost", SPIKE_TRAP_BUILD_ID)
		if typeof(cost) == TYPE_DICTIONARY:
			return _apply_cost_effects(cost)
	return _apply_cost_effects({"stone": 4})


func _get_bow_tower_data() -> Dictionary:
	var data := {
		"display_name": "Tower",
		"hp": 34.0,
		"range": 150.0,
		"range_bonus": 32.0,
		"damage": 10.0,
		"shot_cooldown_seconds": 0.7,
		"stone_cost": 8,
	}
	if resource_system != null and resource_system.has_method("get_structure"):
		var resource_data = resource_system.call("get_structure", BOW_TOWER_BUILD_ID)
		if typeof(resource_data) == TYPE_DICTIONARY:
			data = resource_data.duplicate(true)
	var effects := _get_run_build_effects()
	data["damage"] = float(data.get("damage", 10.0)) * float(effects.get("base_damage_multiplier", 1.0)) * (1.0 + float(effects.get("bow_strength", 0.0)) * 0.35)
	data["range"] = float(data.get("range", 150.0)) * (1.0 + float(effects.get("attack_range_strength", 0.0)) * 0.25)
	data["range_bonus"] = float(data.get("range_bonus", 32.0)) * (1.0 + float(effects.get("attack_range_strength", 0.0)) * 0.25)
	return data


func _get_bow_tower_cost() -> Dictionary:
	if resource_system != null and resource_system.has_method("get_structure_cost"):
		var cost = resource_system.call("get_structure_cost", BOW_TOWER_BUILD_ID)
		if typeof(cost) == TYPE_DICTIONARY:
			return _apply_cost_effects(cost)
	return _apply_cost_effects({"stone": 8})


func _get_tar_pit_data() -> Dictionary:
	var data := {
		"display_name": "Tar Pit",
		"hp": 22.0,
		"slow_radius": 58.0,
		"slow_multiplier": 0.48,
		"stone_cost": 4,
	}
	if resource_system != null and resource_system.has_method("get_structure"):
		var resource_data = resource_system.call("get_structure", TAR_PIT_BUILD_ID)
		if typeof(resource_data) == TYPE_DICTIONARY:
			data = resource_data.duplicate(true)
	var effects := _get_run_build_effects()
	data["slow_multiplier"] = clampf(float(data.get("slow_multiplier", 0.48)) - float(effects.get("trapcraft_strength", 0.0)) * 0.08, 0.24, 0.85)
	return data


func _get_tar_pit_cost() -> Dictionary:
	if resource_system != null and resource_system.has_method("get_structure_cost"):
		var cost = resource_system.call("get_structure_cost", TAR_PIT_BUILD_ID)
		if typeof(cost) == TYPE_DICTIONARY:
			return _apply_cost_effects(cost)
	return _apply_cost_effects({"stone": 4})


func _get_fear_lantern_data() -> Dictionary:
	var data := {
		"display_name": "Fear Lantern",
		"hp": 26.0,
		"soothe_radius": 82.0,
		"fear_reduction_per_second": 2.0,
		"enemy_damage_multiplier": 0.90,
		"stone_cost": 5,
	}
	if resource_system != null and resource_system.has_method("get_structure"):
		var resource_data = resource_system.call("get_structure", FEAR_LANTERN_BUILD_ID)
		if typeof(resource_data) == TYPE_DICTIONARY:
			data = resource_data.duplicate(true)
	var effects := _get_run_build_effects()
	var aura_bonus := float(effects.get("aura_damage_multiplier", 1.0)) - 1.0
	data["fear_reduction_per_second"] = float(data.get("fear_reduction_per_second", 2.0)) * float(effects.get("rest_recovery_multiplier", 1.0))
	data["enemy_damage_multiplier"] = clampf(float(data.get("enemy_damage_multiplier", 0.90)) - aura_bonus * 0.06, 0.72, 1.0)
	return data


func _get_fear_lantern_cost() -> Dictionary:
	if resource_system != null and resource_system.has_method("get_structure_cost"):
		var cost = resource_system.call("get_structure_cost", FEAR_LANTERN_BUILD_ID)
		if typeof(cost) == TYPE_DICTIONARY:
			return _apply_cost_effects(cost)
	return _apply_cost_effects({"stone": 5})


func _get_decoy_idol_data() -> Dictionary:
	var data := {
		"display_name": "Decoy Idol",
		"hp": 24.0,
		"taunt_radius": 118.0,
		"lifetime_seconds": 120.0,
		"stone_cost": 6,
	}
	if resource_system != null and resource_system.has_method("get_structure"):
		var resource_data = resource_system.call("get_structure", DECOY_IDOL_BUILD_ID)
		if typeof(resource_data) == TYPE_DICTIONARY:
			data = resource_data.duplicate(true)
	var effects := _get_run_build_effects()
	data["taunt_radius"] = float(data.get("taunt_radius", 118.0)) * (1.0 + float(effects.get("trapcraft_strength", 0.0)) * 0.12)
	return data


func _get_decoy_idol_cost() -> Dictionary:
	if resource_system != null and resource_system.has_method("get_structure_cost"):
		var cost = resource_system.call("get_structure_cost", DECOY_IDOL_BUILD_ID)
		if typeof(cost) == TYPE_DICTIONARY:
			return _apply_cost_effects(cost)
	return _apply_cost_effects({"stone": 6})


func _get_thorn_totem_data() -> Dictionary:
	var data := {
		"display_name": "Thorn Totem",
		"hp": 30.0,
		"thorn_radius": 76.0,
		"recoil_damage": 4.5,
		"stone_cost": 6,
	}
	if resource_system != null and resource_system.has_method("get_structure"):
		var resource_data = resource_system.call("get_structure", THORN_TOTEM_BUILD_ID)
		if typeof(resource_data) == TYPE_DICTIONARY:
			data = resource_data.duplicate(true)
	var effects := _get_run_build_effects()
	data["recoil_damage"] = float(data.get("recoil_damage", 4.5)) * (1.0 + float(effects.get("thorns_strength", 0.0)) * 0.55)
	data["thorn_radius"] = float(data.get("thorn_radius", 76.0)) * (1.0 + float(effects.get("defense_strength", 0.0)) * 0.10)
	return data


func _get_thorn_totem_cost() -> Dictionary:
	if resource_system != null and resource_system.has_method("get_structure_cost"):
		var cost = resource_system.call("get_structure_cost", THORN_TOTEM_BUILD_ID)
		if typeof(cost) == TYPE_DICTIONARY:
			return _apply_cost_effects(cost)
	return _apply_cost_effects({"stone": 6})


func _get_repair_bench_data() -> Dictionary:
	var data := {
		"display_name": "Repair Bench",
		"hp": 32.0,
		"repair_radius": 86.0,
		"passive_repair_per_second": 1.1,
		"active_repair_multiplier": 1.55,
		"stone_cost": 6,
	}
	if resource_system != null and resource_system.has_method("get_structure"):
		var resource_data = resource_system.call("get_structure", REPAIR_BENCH_BUILD_ID)
		if typeof(resource_data) == TYPE_DICTIONARY:
			data = resource_data.duplicate(true)
	var effects := _get_run_build_effects()
	data["passive_repair_per_second"] = float(data.get("passive_repair_per_second", 1.1)) * float(effects.get("repair_speed_multiplier", 1.0))
	data["active_repair_multiplier"] = float(data.get("active_repair_multiplier", 1.55)) * float(effects.get("repair_speed_multiplier", 1.0))
	return data


func _get_repair_bench_cost() -> Dictionary:
	if resource_system != null and resource_system.has_method("get_structure_cost"):
		var cost = resource_system.call("get_structure_cost", REPAIR_BENCH_BUILD_ID)
		if typeof(cost) == TYPE_DICTIONARY:
			return _apply_cost_effects(cost)
	return _apply_cost_effects({"stone": 6})


func _get_storm_rod_data() -> Dictionary:
	var data := {
		"display_name": "Storm Rod",
		"hp": 30.0,
		"range": 132.0,
		"flying_damage": 18.0,
		"ground_damage": 4.0,
		"shot_cooldown_seconds": 1.05,
		"stone_cost": 7,
	}
	if resource_system != null and resource_system.has_method("get_structure"):
		var resource_data = resource_system.call("get_structure", STORM_ROD_BUILD_ID)
		if typeof(resource_data) == TYPE_DICTIONARY:
			data = resource_data.duplicate(true)
	var effects := _get_run_build_effects()
	data["flying_damage"] = float(data.get("flying_damage", 18.0)) * float(effects.get("base_damage_multiplier", 1.0)) * (1.0 + float(effects.get("attack_range_strength", 0.0)) * 0.18)
	data["ground_damage"] = float(data.get("ground_damage", 4.0)) * float(effects.get("base_damage_multiplier", 1.0))
	data["range"] = float(data.get("range", 132.0)) * (1.0 + float(effects.get("attack_range_strength", 0.0)) * 0.18)
	return data


func _get_storm_rod_cost() -> Dictionary:
	if resource_system != null and resource_system.has_method("get_structure_cost"):
		var cost = resource_system.call("get_structure_cost", STORM_ROD_BUILD_ID)
		if typeof(cost) == TYPE_DICTIONARY:
			return _apply_cost_effects(cost)
	return _apply_cost_effects({"stone": 7})


func _stone_count() -> int:
	if resource_system != null and resource_system.has_method("get_stone"):
		return int(resource_system.call("get_stone"))
	return 0


func _food_count() -> int:
	if resource_system != null and resource_system.has_method("get_food"):
		return int(resource_system.call("get_food"))
	return 0


func _ore_count() -> int:
	if resource_system != null and resource_system.has_method("get_ore"):
		return int(resource_system.call("get_ore"))
	return 0


func _advance_ari_eat_job(reason: String) -> void:
	if ari == null:
		return
	ari.call("stop_daytime_job", reason)
	if resource_system != null and bool(resource_system.call("spend_food", 1)):
		ari.call("restore_from_food", 30.0)
		ari_memory.record_event("food_eaten", {"day": day_night.day, "phase": day_night.phase})
		_show_ari_thought("Food makes the dark feel a little farther away.", true)
	else:
		_show_ari_thought("I need food, but the stores are empty.", true)


func _is_mining_enabled() -> bool:
	return ari != null and bool(ari.get("mining_enabled"))


func _position_mine_node() -> void:
	if mine_node == null:
		return
	var arena := get_arena_rect()
	mine_node.global_position = arena.get_center() + Vector2(-80.0, 88.0)


func _position_training_dummy() -> void:
	if training_dummy == null:
		return
	var arena := get_arena_rect()
	training_dummy.global_position = arena.get_center() + Vector2(316.0, 82.0)


func _position_farm_plot() -> void:
	if farm_plot == null:
		return
	var arena := get_arena_rect()
	farm_plot.global_position = arena.get_center() + Vector2(-220.0, -88.0)


func _position_bed_station() -> void:
	if bed_station == null:
		return
	var arena := get_arena_rect()
	bed_station.global_position = arena.get_center() + Vector2(-220.0, 82.0)


func _position_library_station() -> void:
	if library_station == null:
		return
	var arena := get_arena_rect()
	library_station.global_position = arena.get_center() + Vector2(326.0, -88.0)


func _position_forge_station() -> void:
	if forge_station == null:
		return
	var arena := get_arena_rect()
	forge_station.global_position = arena.get_center() + Vector2(82.0, 92.0)


func _create_library_note() -> void:
	var note := {}
	if ari_memory.has_method("create_lifetime_note_from_recent_events"):
		note = ari_memory.call("create_lifetime_note_from_recent_events", day_night.day)
	if note.is_empty():
		_show_ari_thought("I need something real to think about first.", true)
		_set_status_message("Library found no new lesson yet.", 2.0)
		_emit_state()
		return
	var title := str(note.get("title", "Ari's rough local reflection"))
	lesson_book.add_note(note)
	latest_lesson_title = title
	ari_memory.record_event("library_note_created", {
		"title": title,
		"day": day_night.day,
	})
	var thought := str(note.get("thought", "I wrote it down. Maybe I will believe it when I sleep."))
	_show_ari_thought(thought, true)
	_set_status_message("Library note: %s" % title, 2.4)
	_emit_state()


func _recent_event_count(events: Array, event_type: String) -> int:
	var count := 0
	for event in events:
		if typeof(event) == TYPE_DICTIONARY and str(event.get("type", "")) == event_type:
			count += 1
	return count


func _build_death_recap(earned_time_points: int) -> String:
	var recent := ari_memory.get_recent_events(30)
	var damaged := _recent_event_count(recent, "ari_damaged")
	var structures_lost := _recent_event_count(recent, "structure_destroyed")
	var enemies_killed := _recent_event_count(recent, "enemy_killed")
	var cause := "The night reached Ari."
	if structures_lost > 0:
		cause = "A defense broke before Ari fell."
	elif damaged > 0:
		cause = "Enemies got close enough to hurt him."
	elif enemies_killed <= 0:
		cause = "Nothing stopped the first pressure wave."

	var lesson := "Try clearer distance, stronger layers, or more damage."
	if sign_text.strip_edges() == "":
		lesson = "No sign guided him. Write a clearer warning next run."
	elif walls.is_empty():
		lesson = "A first wall layer may buy him time."
	elif aura_orbs.is_empty() and spike_traps.is_empty() and bow_towers.is_empty():
		lesson = "Walls need damage behind them."
	elif _food_count() <= 0:
		lesson = "Food may keep fear and stamina from collapsing."

	var reward_text := "+%d Time Points carried forward." % earned_time_points
	if _visual_review_staging:
		reward_text = "Visual review pauses permanent rewards."
	return "Death recap: Day %d %s. %s %s %s" % [
		day_night.day,
		day_night.phase,
		cause,
		reward_text,
		lesson,
	]


func _set_status_message(message: String, seconds := 2.0) -> void:
	status_message = message
	status_message_time = seconds if message != "" else 0.0


func _update_ari_ranged_attack_timers(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	_ari_ranged_cooldown = maxf(0.0, _ari_ranged_cooldown - safe_delta)
	_ari_melee_cooldown = maxf(0.0, _ari_melee_cooldown - safe_delta)
	if _ari_ranged_flash_time > 0.0:
		_ari_ranged_flash_time = maxf(0.0, _ari_ranged_flash_time - safe_delta)
		queue_redraw()
	if _ari_melee_flash_time > 0.0:
		_ari_melee_flash_time = maxf(0.0, _ari_melee_flash_time - safe_delta)
		queue_redraw()
	if _dawn_clear_flash_time > 0.0:
		_dawn_clear_flash_time = maxf(0.0, _dawn_clear_flash_time - safe_delta)
		queue_redraw()


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
	var thought: String = str(ari_mind.call("thought_for_job", job, reason, _get_run_build_context()))
	_show_ari_thought(thought, force)


func _show_sign_interpretation_thought(force := false) -> void:
	var interpretation := {
		"interpretation_text": sign_interpretation,
		"priority_hints": sign_priority_hints,
		"grounded_plan": sign_grounded_plan,
		"sign_strength": sign_strength,
		"resonance": sign_resonance,
	}
	var thought: String = str(sign_mind.call("thought_for_interpretation", sign_text, interpretation, _get_run_build_context()))
	_show_ari_thought(thought, force)


func _get_sign_action_focus(ari_job: String, ari_job_reason: String) -> String:
	var top_plan := _get_top_grounded_plan_item()
	if not top_plan.is_empty():
		var plan_id := str(top_plan.get("affordance_id", ""))
		if _job_matches_affordance(ari_job, plan_id):
			return "AI plan: %s -> Ari is following it." % _affordance_label(plan_id)
		var reason := str(top_plan.get("reason", "")).strip_edges()
		if reason != "":
			return "AI plan: %s -> %s" % [_affordance_label(plan_id), _limit_inline(reason, 58)]
	var ai_hint := _get_top_priority_hint(sign_priority_hints)
	if ari_job == "use_cover":
		return "AI pull: cover -> Ari is following it."
	if ari_job == "lure_to_aura":
		return "AI pull: lure to light -> Ari is following it."
	if ari_job == "use_tower":
		return "AI pull: tower range -> Ari is following it."
	if ai_hint == "repair" and ari_job_reason.to_lower().find("repair") >= 0:
		return "AI pull: repair -> Ari is reporting the gap."
	if sign_mind == null or not sign_mind.has_method("describe_action_focus"):
		return ""
	return str(sign_mind.call("describe_action_focus", sign_priority_hints, ari_job, ari_job_reason))


func _request_ai_deep_interpretation(show_waiting := true, bypass_cache := false) -> void:
	if ai_bridge == null or not ai_bridge.is_ai_enabled():
		_finish_ai_waiting()
		_update_ai_idle_status()
		return
	if sign_text.strip_edges() == "":
		_finish_ai_waiting()
		ai_status = "AI: active"
		_emit_state()
		return
	_ai_sign_request_id += 1
	var request_id := _ai_sign_request_id
	if show_waiting:
		_begin_ai_waiting()
		_emit_state()
	var payload := _build_ai_deep_interpretation_payload()
	var callback := func(result: Dictionary) -> void:
		_on_ai_deep_interpretation_response(request_id, result)
	ai_bridge.request_deep_interpretation(payload, callback, bypass_cache)


func _on_ai_deep_interpretation_response(request_id: int, result: Dictionary) -> void:
	if request_id != _ai_sign_request_id:
		return
	_finish_ai_waiting()
	if not bool(result.get("ok", false)):
		ai_status = "AI: failed/fallback"
		_show_ari_thought("I cannot hear more from the sign. I will use what I understood.", true)
		_emit_state()
		return

	sign_interpretation = str(result.get("interpretation", sign_interpretation))
	sign_grounded_plan = _normalize_grounded_plan(result.get("grounded_plan", []))
	sign_priority_hints = _merge_priority_hints(sign_priority_hints, _priority_hints_from_grounded_plan(sign_grounded_plan), result.get("priority_hints", {}))
	sign_strength = clampf(float(result.get("sign_strength", sign_strength)), 0.0, 1.0)
	sign_resonance = clampf(float(result.get("resonance", sign_resonance)), 0.0, 1.0)
	ai_survival_theory = str(result.get("survival_theory", "")).strip_edges()
	ai_emotion = str(result.get("emotion", "")).strip_edges()
	var used_cache := bool(result.get("cached", false)) or str(result.get("source", "")) == "cache"
	ai_status = "AI: cached" if used_cache else "AI: active"
	var thought := "I remember this sign." if used_cache else str(result.get("thought", "")).strip_edges()
	if thought == "":
		thought = "Now I see it."
	_show_ari_thought(thought, true)
	_emit_state()


func _update_ai_idle_status() -> void:
	if _ai_waiting_active:
		return
	ai_status = "AI: active" if ai_bridge != null and ai_bridge.is_ai_enabled() else "AI disabled"


func _begin_ai_waiting() -> void:
	_ai_waiting_active = true
	_ai_waiting_elapsed = 0.0
	_ai_waiting_last_second = -1
	_ai_waiting_still_thought_shown = false
	_update_ai_waiting_status()
	_show_ari_thought("I understand part of it. I need to turn the rest over.", true)


func _advance_ai_waiting(delta: float) -> void:
	if not _ai_waiting_active:
		return
	_ai_waiting_elapsed = maxf(0.0, _ai_waiting_elapsed + delta)
	var current_second := int(floor(_ai_waiting_elapsed))
	if current_second == _ai_waiting_last_second:
		return
	_update_ai_waiting_status()
	if _ai_waiting_elapsed >= 10.0 and not _ai_waiting_still_thought_shown:
		_ai_waiting_still_thought_shown = true
		_show_ari_thought("The sign is still unfolding.", true)
	if is_inside_tree():
		_emit_state()


func _finish_ai_waiting() -> void:
	_ai_waiting_active = false
	_ai_waiting_still_thought_shown = false


func _update_ai_waiting_status() -> void:
	var seconds := int(floor(_ai_waiting_elapsed))
	_ai_waiting_last_second = seconds
	var dots := ""
	for _i in range(seconds % 4):
		dots += "."
	ai_status = "AI: thinking %ds%s" % [seconds, dots]


func _build_ai_deep_interpretation_payload() -> Dictionary:
	var ari_job := str(ari.call("get_current_job")) if ari != null else "wait_or_idle"
	var ari_job_reason := str(ari.call("get_job_reason")) if ari != null else "Waiting"
	return {
		"sign_text": sign_text,
		"rulebook": _get_ai_rulebook(),
		"perception": _get_ai_perception(),
		"run_build": _get_run_build_context(),
		"ari": {
			"run_build": _get_run_build_context(),
			"hp": float(ari.get("hp")) if ari != null else 0.0,
			"max_hp": float(ari.get("max_hp")) if ari != null else 0.0,
			"current_job": ari_job,
			"current_reason": ari_job_reason,
			"job": ari_job,
			"reason": ari_job_reason,
		},
		"world": {
			"day": day_night.day,
			"phase": day_night.phase,
			"time_left": day_night.get_time_left(),
			"stone": _stone_count(),
			"food": _food_count(),
			"ore": _ore_count(),
			"sword_tier": _current_sword_tier(),
			"wall_count": walls.size(),
			"aura_orb_count": aura_orbs.size(),
			"bow_tower_count": bow_towers.size(),
			"storm_rod_count": storm_rods.size(),
			"enemy_count": enemies.size(),
			"enemy_type_counts": _get_enemy_type_counts(),
			"known_enemy_types": _known_enemy_types(),
			"structures": _ai_structure_state(),
		},
		"current_affordances": _current_affordances(),
		"recent_thoughts": _recent_ai_thoughts(),
		"latest_library_note": _latest_library_note_text(),
		"local_fallback": {
			"interpretation": sign_interpretation,
			"priority_hints": sign_priority_hints,
			"emotion": ai_emotion,
			"grounded_plan": sign_grounded_plan,
			"sign_strength": sign_strength,
			"resonance": sign_resonance,
		},
	}


func _get_ai_rulebook() -> Dictionary:
	if ari_rulebook != null and ari_rulebook.has_method("get_rulebook"):
		return ari_rulebook.call("get_rulebook")
	return {}


func _get_ai_perception() -> Dictionary:
	if ari_perception != null and ari_perception.has_method("build_report"):
		return ari_perception.call("build_report", self)
	return {}


func _current_affordances() -> Array:
	var stone := _stone_count()
	var food := _food_count()
	var ore := _ore_count()
	var has_wall := walls.size() > 0
	var has_aura := aura_orbs.size() > 0
	var has_tower := bow_towers.size() > 0
	var has_forge := forge_station != null
	var next_sword_cost := _next_sword_ore_cost()
	var damaged_count := _get_damaged_structure_count()
	return [
		_affordance("mine_stone", "Mine stone for structures and defenses.", true),
		_affordance("mine_ore", "Mine low-tier ore for sword upgrades at the forge.", true),
		_affordance("build_wall", "Spend stone to build a new wall block.", stone >= int(_get_wall_cost().get("stone", 0)), "not enough stone"),
		_affordance("use_existing_wall", "Move near an existing wall so enemies must hit or go around it before reaching Ari.", has_wall, "no wall exists"),
		_affordance("wait_behind_wall", "Wait on the safe side of an existing wall.", has_wall, "no wall exists"),
		_affordance("use_cover", "Use current cover instead of adding a new structure.", has_wall or has_tower, "no cover exists"),
		_affordance("place_aura_orb", "Spend stone to place an Aura Orb that damages enemies inside its circle.", stone >= int(_get_aura_orb_cost().get("stone", 0)), "not enough stone"),
		_affordance("lure_to_aura", "Stand near the safe side of an Aura Orb so enemies pass through the damaging circle.", has_aura, "no Aura Orb exists"),
		_affordance("train_combat", "Practice at the training dummy to improve combat readiness.", true),
		_affordance("train_sword", "Practice sword handling at the training dummy.", true),
		_affordance("prepare_weapon", "Prepare Ari for direct danger through combat training.", true),
		_affordance("build_forge", "Forge station is already present in this prototype.", false, "forge already exists"),
		_affordance("smith_sword", "Spend ore at the forge to improve Ari's sword tier.", has_forge and next_sword_cost > 0 and ore >= next_sword_cost, "need ore or max sword"),
		_affordance("fight_head_on", "Use direct melee combat against ground enemies.", enemies.size() > 0, "no enemy to fight"),
		_affordance("use_armor", "Lean on armor and defense stats when contact is unavoidable.", true),
		_affordance("rely_on_regen", "Treat passive or kill recovery as support, not a direct command.", true),
		_affordance("regen_on_kill", "Recover HP after kills if the current build supports it.", true),
		_affordance("build_tower", "Spend stone to build a bow tower for height and ranged safety.", stone >= int(_get_bow_tower_cost().get("stone", 0)), "not enough stone"),
		_affordance("use_tower", "Use an existing tower perch to keep distance from ground enemies.", has_tower, "no tower exists"),
		_affordance("ranged_attack", "Attack from tower range when a tower and target exist.", has_tower, "no tower exists"),
		_affordance("train_bow", "Practice ranged thinking through tower and combat preparation.", true),
		_affordance("farm_food", "Work the farm plot to create food.", true),
		_affordance("eat_food", "Eat stored food to lower hunger pressure.", food > 0, "no food stored"),
		_affordance("eat", "Use food as survival support when any is stored.", food > 0, "no food stored"),
		_affordance("rest", "Rest at the bed to recover HP, stamina, and fear.", true),
		_affordance("reflect_library", "Go to the library to turn recent events into a lesson.", _get_meaningful_event_count() > 0, "no fresh meaningful event"),
		_affordance("repair", "Repair a damaged structure.", damaged_count > 0, "nothing is damaged"),
		_affordance("flee", "Move away from immediate danger.", true),
		_affordance("kite", "Keep distance while danger approaches.", true),
		_affordance("hide", "Stay near safer cover and avoid direct contact.", has_wall or has_aura or has_tower, "no safe place exists"),
		_affordance("stall_until_dawn", "Delay and stay alive until sunrise clears the night pressure.", true),
		_affordance("hide_until_dawn", "Use cover and distance to survive until dawn.", has_wall or has_aura or has_tower, "no safe place exists"),
		_affordance("avoid_killing", "Avoid unnecessary direct kills when survival until morning is the goal.", true),
		_affordance("survive_until_morning", "Prioritize lasting until dawn instead of clearing every enemy.", true),
		_affordance("fight", "Accept direct combat if avoidance fails.", true),
		_affordance("build_storm_rod", "Build a Storm Rod as an anti-flying sky defense.", stone >= int(_get_storm_rod_cost().get("stone", 0)), "not enough stone"),
		_affordance("anti_flying", "Prioritize answers that work against flying enemies.", true),
		_affordance("sky_answer", "Treat the sky as the threat and prefer storm or range over walls alone.", true),
		_affordance("build_spike_trap", "Spend stone to build a spike trap that punishes enemies on the ground.", stone >= int(_get_spike_trap_cost().get("stone", 0)), "not enough stone"),
		_affordance("build_tar_pit", "Spend stone to build a tar pit that slows enemies.", stone >= int(_get_tar_pit_cost().get("stone", 0)), "not enough stone"),
		_affordance("build_fear_lantern", "Spend stone to build a lantern that helps calm fear.", stone >= int(_get_fear_lantern_cost().get("stone", 0)), "not enough stone"),
		_affordance("build_decoy_idol", "Spend stone to build a decoy that pulls enemies away.", stone >= int(_get_decoy_idol_cost().get("stone", 0)), "not enough stone"),
		_affordance("build_thorn_totem", "Spend stone to build thorns that punish contact.", stone >= int(_get_thorn_totem_cost().get("stone", 0)), "not enough stone"),
		_affordance("build_repair_bench", "Spend stone to build repair support for damaged defenses.", stone >= int(_get_repair_bench_cost().get("stone", 0)), "not enough stone"),
		_affordance("use_thorns", "Lean on thorn defenses to punish enemies that touch Ari's protection.", thorn_totems.size() > 0, "no thorns exist"),
	]


func _affordance(id: String, description: String, available: bool, reason_unavailable := "") -> Dictionary:
	var result := {
		"id": id,
		"description": description,
		"available": available,
	}
	if not available and reason_unavailable != "":
		result["reason_unavailable"] = reason_unavailable
	return result


func _recent_ai_thoughts() -> Array[String]:
	var thoughts: Array[String] = []
	if latest_thought.strip_edges() != "":
		thoughts.append(latest_thought)
	return thoughts


func _latest_library_note_text() -> String:
	var note := _get_latest_lifetime_note()
	if note.is_empty():
		return ""
	return str(note.get("markdown", note.get("markdown_text", note.get("hypothesis", "")))).substr(0, 1000)


func _normalize_grounded_plan(raw_plan) -> Array:
	var result := []
	var seen := {}
	if typeof(raw_plan) != TYPE_ARRAY:
		return result
	for raw_item in raw_plan:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var affordance_id := str(raw_item.get("affordance_id", raw_item.get("id", ""))).strip_edges()
		if affordance_id == "" or seen.has(affordance_id):
			continue
		var priority := clampf(float(raw_item.get("priority", 0.0)), 0.0, 1.0)
		if priority <= 0.0:
			continue
		result.append({
			"affordance_id": affordance_id,
			"priority": priority,
			"reason": _limit_inline(str(raw_item.get("reason", "")), 180),
		})
		seen[affordance_id] = true
		if result.size() >= 4:
			break
	return result


func _priority_hints_from_grounded_plan(grounded_plan: Array) -> Dictionary:
	var hints := {}
	for item in grounded_plan:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		_set_hint_max(hints, str(item.get("affordance_id", "")), float(item.get("priority", 0.0)))
	return hints


func _get_top_grounded_plan_item() -> Dictionary:
	var best := {}
	var best_priority := 0.0
	for item in sign_grounded_plan:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var priority := clampf(float(item.get("priority", 0.0)), 0.0, 1.0)
		if priority > best_priority:
			best = item
			best_priority = priority
	return best if best_priority >= 0.15 else {}


func _get_top_grounded_plan_text() -> String:
	var top_plan := _get_top_grounded_plan_item()
	if top_plan.is_empty():
		return ""
	var affordance_id := str(top_plan.get("affordance_id", ""))
	var reason := str(top_plan.get("reason", "")).strip_edges()
	if reason == "":
		return _affordance_label(affordance_id)
	return "%s: %s" % [_affordance_label(affordance_id), _limit_inline(reason, 70)]


func _job_matches_affordance(job: String, affordance_id: String) -> bool:
	if job == affordance_id:
		return true
	match affordance_id:
		"use_existing_wall", "wait_behind_wall", "use_cover", "hide":
			return job == "use_cover" or job == "wait_or_idle"
		"lure_to_aura":
			return job == "lure_to_aura"
		"use_tower", "ranged_attack", "train_bow":
			return job == "use_tower" or job == "build_bow_tower"
		"build_tower":
			return job == "build_bow_tower"
		"build_storm_rod", "anti_flying", "sky_answer":
			return job == "build_storm_rod" or job == "mine_stone"
		"eat", "eat_food":
			return job == "eat_food" or job == "farm_food"
		"prepare_weapon", "fight":
			return job == "train_combat" or job == "fight_head_on" or job == "train_sword"
		"fight_head_on":
			return job == "fight_head_on"
		"train_sword":
			return job == "train_sword"
		"smith_sword":
			return job == "smith_sword" or job == "mine_ore"
		"mine_ore":
			return job == "mine_ore"
		"stall_until_dawn", "hide_until_dawn", "survive_until_morning", "avoid_killing":
			return job == "stall_until_dawn" or job == "hide_until_dawn" or job == "use_cover" or job == "flee"
		"repair":
			return job == "repair_structure"
		"build_spike_trap":
			return job == "build_spike_trap"
	return false


func _affordance_label(affordance_id: String) -> String:
	match affordance_id:
		"use_existing_wall", "wait_behind_wall", "use_cover":
			return "cover"
		"lure_to_aura", "place_aura_orb":
			return "light"
		"use_tower", "build_tower", "ranged_attack", "train_bow":
			return "tower range"
		"build_storm_rod", "anti_flying", "sky_answer":
			return "sky answer"
		"farm_food", "eat", "eat_food":
			return "food"
		"reflect_library":
			return "library"
		"train_combat", "prepare_weapon", "fight":
			return "combat"
		"fight_head_on":
			return "melee"
		"train_sword":
			return "sword training"
		"smith_sword", "mine_ore":
			return "sword forge"
		"use_armor":
			return "armor"
		"rely_on_regen", "regen_on_kill":
			return "regen"
		"stall_until_dawn", "hide_until_dawn", "avoid_killing", "survive_until_morning":
			return "dawn survival"
		"build_spike_trap", "build_trap":
			return "traps"
	return affordance_id.replace("_", " ")


func _limit_inline(text: String, max_length: int) -> String:
	var clean_text := text.replace("\n", " ").strip_edges()
	if clean_text.length() <= max_length:
		return clean_text
	return clean_text.substr(0, max_length - 3).strip_edges() + "..."


func _normalize_ai_priority_hints(raw_hints) -> Dictionary:
	var normalized := {}
	if typeof(raw_hints) != TYPE_DICTIONARY:
		return normalized
	for raw_key in raw_hints.keys():
		var key := str(raw_key)
		var value := clampf(float(raw_hints[raw_key]), 0.0, 1.0)
		_set_hint_max(normalized, key, value)

	_set_hint_max(normalized, "mining", float(normalized.get("mine_stone", 0.0)))
	_set_hint_max(normalized, "wall", float(normalized.get("build_wall", 0.0)))
	_set_hint_max(normalized, "aura_orb", maxf(
		float(normalized.get("place_aura_orb", 0.0)),
		float(normalized.get("lure_to_aura", 0.0))
	))
	_set_hint_max(normalized, "combat_training", maxf(
		maxf(float(normalized.get("train_combat", 0.0)), float(normalized.get("fight", 0.0))),
		maxf(maxf(float(normalized.get("prepare_weapon", 0.0)), float(normalized.get("train_bow", 0.0))), float(normalized.get("train_sword", 0.0)))
	))
	_set_hint_max(normalized, "fight_head_on", maxf(
		float(normalized.get("fight_head_on", 0.0)),
		float(normalized.get("fight", 0.0)) * 0.65
	))
	_set_hint_max(normalized, "smith_sword", maxf(
		float(normalized.get("smith_sword", 0.0)),
		float(normalized.get("prepare_weapon", 0.0)) * 0.35
	))
	_set_hint_max(normalized, "mine_ore", maxf(
		float(normalized.get("mine_ore", 0.0)),
		float(normalized.get("smith_sword", 0.0)) * 0.55
	))
	_set_hint_max(normalized, "farm_food", maxf(
		maxf(float(normalized.get("farm_food", 0.0)), float(normalized.get("eat", 0.0))),
		float(normalized.get("eat_food", 0.0))
	))
	_set_hint_max(normalized, "build_tower", maxf(
		float(normalized.get("build_tower", 0.0)),
		float(normalized.get("use_tower", 0.0)) * 0.35
	))
	_set_hint_max(normalized, "defensive_wait", maxf(
		maxf(float(normalized.get("wait_or_idle", 0.0)), float(normalized.get("use_existing_wall", 0.0))),
		maxf(float(normalized.get("wait_behind_wall", 0.0)), float(normalized.get("use_cover", 0.0)))
	))
	_set_hint_max(normalized, "repair_structure", float(normalized.get("repair", 0.0)))
	_set_hint_max(normalized, "build_trap", float(normalized.get("build_spike_trap", 0.0)))
	_set_hint_max(normalized, "range", maxf(
		maxf(float(normalized.get("kite", 0.0)), float(normalized.get("flee", 0.0))),
		maxf(float(normalized.get("train_bow", 0.0)), float(normalized.get("ranged_attack", 0.0)))
	))
	_set_hint_max(normalized, "build_storm_rod", maxf(
		float(normalized.get("build_storm_rod", 0.0)),
		maxf(float(normalized.get("anti_flying", 0.0)), float(normalized.get("sky_answer", 0.0)))
	))
	_set_hint_max(normalized, "defensive_wait", maxf(
		float(normalized.get("defensive_wait", 0.0)),
		maxf(float(normalized.get("stall_until_dawn", 0.0)), float(normalized.get("hide_until_dawn", 0.0))) * 0.45
	))
	_set_hint_max(normalized, "hide", maxf(
		float(normalized.get("hide", 0.0)),
		float(normalized.get("hide_until_dawn", 0.0)) * 0.55
	))
	return normalized


func _merge_priority_hints(local_hints, plan_hints = {}, ai_hints = {}) -> Dictionary:
	var merged := {}
	for source in [local_hints, plan_hints, ai_hints]:
		if typeof(source) != TYPE_DICTIONARY:
			continue
		for raw_key in source.keys():
			_set_hint_max(merged, str(raw_key), float(source[raw_key]))
	return _normalize_ai_priority_hints(merged)


func _set_hint_max(hints: Dictionary, key: String, value: float) -> void:
	hints[key] = maxf(float(hints.get(key, 0.0)), clampf(value, 0.0, 1.0))


func _get_top_priority_hint(hints: Dictionary) -> String:
	var best_key := ""
	var best_value := 0.0
	for raw_key in hints.keys():
		var key := str(raw_key)
		var value := clampf(float(hints[raw_key]), 0.0, 1.0)
		if value > best_value:
			best_key = key
			best_value = value
	if best_value < 0.15:
		return ""
	return best_key


func _known_enemy_types() -> Array[String]:
	var types: Array[String] = []
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_type := str(enemy.get("enemy_type"))
		if enemy_type == "":
			enemy_type = "zombie"
		if not types.has(enemy_type):
			types.append(enemy_type)
	if types.is_empty():
		types.append("zombie")
	return types


func _ai_structure_state() -> Array:
	var result := []
	for structure in structures:
		if not is_instance_valid(structure):
			continue
		result.append({
			"type": str(structure.get("structure_type")),
			"status": _structure_ai_status(structure),
		})
	return result


func _structure_ai_status(structure: Node) -> String:
	var hp := float(structure.get("hp"))
	var max_hp := float(structure.get("max_hp"))
	if max_hp <= 0.0:
		return "intact"
	var ratio := hp / max_hp
	if ratio <= 0.0:
		return "broken"
	if ratio < 0.65:
		return "damaged"
	return "intact"


func _show_ari_thought(thought: String, force := false) -> void:
	var clean_thought := thought.strip_edges()
	if clean_thought == "":
		return
	latest_thought = clean_thought
	if thought_bubble != null:
		thought_bubble.call("show_thought", clean_thought, force)


func _reset_survival_pressure_flags() -> void:
	_fear_pressure_reported = false
	_hunger_pressure_reported = false
	_stamina_pressure_reported = false
	_near_death_reported = false
	_aura_damage_reported = false


func _update_survival_pressure_thoughts() -> void:
	if ari == null or not _is_ari_alive():
		return
	var needs := _get_ari_needs()
	var hunger := float(needs.get("hunger", 100.0))
	var stamina := float(needs.get("stamina", 100.0))
	var fear := float(needs.get("fear", 0.0))
	if fear >= 70.0 and not _fear_pressure_reported:
		_fear_pressure_reported = true
		ari_memory.record_event("fear_spike", {
			"fear": fear,
			"day": day_night.day,
			"phase": day_night.phase,
		})
		_show_ari_thought("Fear is getting loud. I need light, distance, or a place to breathe.", true)
	elif fear < 48.0:
		_fear_pressure_reported = false

	if hunger >= 70.0 and not _hunger_pressure_reported:
		_hunger_pressure_reported = true
		ari_memory.record_event("hunger_pressure", {
			"hunger": hunger,
			"day": day_night.day,
			"phase": day_night.phase,
		})
		ari_memory.record_event("hunger_high", {
			"hunger": hunger,
			"day": day_night.day,
			"phase": day_night.phase,
		})
		_show_ari_thought("My stomach is turning every plan into panic.", true)
	elif hunger < 50.0:
		_hunger_pressure_reported = false

	if stamina <= 26.0 and not _stamina_pressure_reported:
		_stamina_pressure_reported = true
		ari_memory.record_event("stamina_pressure", {
			"stamina": stamina,
			"day": day_night.day,
			"phase": day_night.phase,
		})
		_show_ari_thought("My legs are heavy. If I have to run now, I may not get far.", true)
	elif stamina > 46.0:
		_stamina_pressure_reported = false


func _show_structure_destroyed_thought(structure_type: String) -> void:
	match structure_type:
		WALL_BUILD_ID:
			_show_ari_thought("The wall is not safety anymore. I need another layer.", true)
		AURA_ORB_BUILD_ID:
			_show_ari_thought("The light went out. Now they can reach me cleaner.", true)
		BOW_TOWER_BUILD_ID:
			_show_ari_thought("The tower fell. Distance is gone unless I move.", true)
		FEAR_LANTERN_BUILD_ID:
			_show_ari_thought("The warm light broke. The dark feels closer.", true)
		REPAIR_BENCH_BUILD_ID:
			_show_ari_thought("My repair tools are gone. Broken things will stay broken.", true)
		STORM_ROD_BUILD_ID:
			_show_ari_thought("The sky defense fell. Wings are a problem again.", true)
		_:
			_show_ari_thought("Something I trusted broke. I need to change the plan.", true)


func _reinterpret_current_sign() -> void:
	var interpretation: Dictionary = sign_mind.call("interpret_sign", sign_text, _get_run_build_context())
	sign_interpretation = str(interpretation.get("interpretation_text", "Ari can read the words, but not a useful plan yet."))
	ai_survival_theory = ""
	ai_emotion = ""
	sign_grounded_plan = []
	var hints = interpretation.get("priority_hints", {})
	sign_priority_hints = hints.duplicate(true) if typeof(hints) == TYPE_DICTIONARY else {}
	var effects := _get_run_build_effects()
	sign_strength = clampf(float(interpretation.get("sign_strength", 0.0)) + float(effects.get("sign_strength_bonus", 0.0)), 0.0, 1.0)
	sign_resonance = clampf(float(interpretation.get("resonance", 0.0)) + float(effects.get("sign_resonance_bonus", 0.0)), 0.0, 1.0)


func _advance_debug_daytime(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		var delta := minf(1.0 / 30.0, seconds - elapsed)
		day_night.advance(delta)
		_position_mine_node()
		_position_training_dummy()
		_advance_ari_daytime(delta)
		elapsed += delta


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = Vector2(1152.0, 648.0)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.05, 0.06, 0.055, 1.0), true)

	var arena := get_arena_rect()
	draw_rect(arena, Color(0.12, 0.16, 0.12, 1.0), true)
	_draw_defense_lanes(arena)
	_draw_ari_intent()
	_draw_ari_ranged_attack()
	_draw_ari_melee_attack()
	_draw_dawn_clear_flash(arena)
	draw_rect(arena, Color(0.44, 0.50, 0.42, 1.0), false, 3.0)


func _draw_defense_lanes(arena: Rect2) -> void:
	var center := arena.get_center()
	var lane_top := arena.position.y + 12.0
	var lane_height := arena.size.y - 24.0
	var support_rect := Rect2(Vector2(center.x - 280.0, lane_top), Vector2(170.0, lane_height))
	var core_rect := Rect2(Vector2(center.x - 48.0, lane_top), Vector2(210.0, lane_height))
	var kill_rect := Rect2(Vector2(center.x + 184.0, lane_top), Vector2(190.0, lane_height))
	var air_rect := Rect2(Vector2(center.x + 96.0, lane_top), Vector2(250.0, 90.0))
	draw_rect(support_rect, Color(0.16, 0.22, 0.18, 0.16), true)
	draw_rect(core_rect, Color(0.17, 0.20, 0.15, 0.14), true)
	draw_rect(kill_rect, Color(0.22, 0.15, 0.13, 0.13), true)
	draw_rect(air_rect, Color(0.13, 0.18, 0.22, 0.14), true)
	for x in [center.x - 96.0, center.x + 176.0]:
		draw_line(Vector2(x, lane_top), Vector2(x, lane_top + lane_height), Color(0.58, 0.66, 0.55, 0.24), 1.0)


func _draw_ari_intent() -> void:
	if not _ari_intent_active or ari == null or not _is_ari_alive() or day_night.is_night():
		return
	var start := to_local(ari.global_position)
	var target := to_local(_ari_intent_target)
	var distance := start.distance_to(target)
	if distance < 8.0:
		_draw_intent_marker(target)
		return
	var color := _intent_color(_ari_intent_label)
	_draw_dashed_path(start, target, color)
	_draw_intent_marker(target)


func _draw_ari_ranged_attack() -> void:
	if _ari_ranged_flash_time <= 0.0:
		return
	var alpha := clampf(_ari_ranged_flash_time / 0.35, 0.0, 1.0)
	var start := to_local(_ari_ranged_flash_from)
	var target := to_local(_ari_ranged_flash_to)
	draw_line(start, target, Color(1.0, 0.88, 0.34, 0.92 * alpha), 4.0)
	draw_line(start, target, Color(0.38, 0.18, 0.04, 0.70 * alpha), 1.4)
	draw_circle(target, 8.0 + alpha * 5.0, Color(1.0, 0.80, 0.28, 0.22 * alpha))


func _draw_ari_melee_attack() -> void:
	if _ari_melee_flash_time <= 0.0:
		return
	var alpha := clampf(_ari_melee_flash_time / 0.26, 0.0, 1.0)
	var start := to_local(_ari_melee_flash_from)
	var target := to_local(_ari_melee_flash_to)
	var mid := start.lerp(target, 0.55)
	var direction := (target - start).normalized() if start.distance_to(target) > 0.01 else Vector2.RIGHT
	var side := Vector2(-direction.y, direction.x)
	draw_line(start + side * 8.0, target - side * 8.0, Color(1.0, 0.78, 0.38, 0.86 * alpha), 4.0)
	draw_arc(mid, 20.0, -0.45, 1.45, 18, Color(1.0, 0.42, 0.18, 0.60 * alpha), 3.0)
	draw_circle(target, 7.0 + alpha * 4.0, Color(1.0, 0.32, 0.18, 0.22 * alpha))


func _draw_dawn_clear_flash(arena: Rect2) -> void:
	if _dawn_clear_flash_time <= 0.0:
		return
	var alpha := clampf(_dawn_clear_flash_time / 1.2, 0.0, 1.0)
	draw_rect(arena, Color(1.0, 0.88, 0.52, 0.16 * alpha), true)
	draw_line(Vector2(arena.position.x, arena.position.y + 18.0), Vector2(arena.end.x, arena.position.y + 18.0), Color(1.0, 0.92, 0.58, 0.42 * alpha), 3.0)


func _draw_dashed_path(start: Vector2, target: Vector2, color: Color) -> void:
	var delta := target - start
	var length := delta.length()
	if length <= 0.1:
		return
	var direction := delta / length
	var dash_length := 8.0
	var gap_length := 5.0
	var cursor := 7.0
	while cursor < length - 7.0:
		var segment_start := start + direction * cursor
		var segment_end := start + direction * minf(cursor + dash_length, length - 7.0)
		draw_line(segment_start, segment_end, color, 2.0)
		cursor += dash_length + gap_length
	var arrow_center := target - direction * 12.0
	var side := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([
		target - direction * 5.0,
		arrow_center + side * 5.0,
		arrow_center - side * 5.0,
	]), color)


func _draw_intent_marker(center: Vector2) -> void:
	var color := _intent_color(_ari_intent_label)
	draw_circle(center, 17.0, Color(color.r, color.g, color.b, 0.14))
	draw_arc(center, 17.0, 0.0, TAU, 32, color, 2.0)
	draw_arc(center, 10.0, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.58), 1.2)
	_draw_intent_symbol(center, color)


func _draw_intent_symbol(center: Vector2, color: Color) -> void:
	var bright := color.lightened(0.32)
	match _ari_intent_label:
		"Mine":
			draw_circle(center + Vector2(-2.0, 2.0), 6.0, color.darkened(0.18))
			draw_line(center + Vector2(-7.0, 7.0), center + Vector2(7.0, -7.0), bright, 2.2)
		"Farm":
			draw_line(center + Vector2(0.0, 8.0), center + Vector2(0.0, -6.0), bright, 2.0)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0.0, -4.0),
				center + Vector2(-8.0, -8.0),
				center + Vector2(-5.0, 2.0),
			]), color)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(1.0, -5.0),
				center + Vector2(8.0, -9.0),
				center + Vector2(5.0, 1.0),
			]), color.lightened(0.12))
		"Rest":
			draw_rect(Rect2(center + Vector2(-10.0, -5.0), Vector2(20.0, 10.0)), color.darkened(0.16), true)
			draw_rect(Rect2(center + Vector2(-9.0, -4.0), Vector2(8.0, 8.0)), bright, true)
		"Reflect":
			draw_rect(Rect2(center + Vector2(-8.0, -9.0), Vector2(16.0, 18.0)), color.darkened(0.12), true)
			draw_line(center + Vector2(-4.0, -4.0), center + Vector2(5.0, -4.0), bright, 1.2)
			draw_line(center + Vector2(-4.0, 0.0), center + Vector2(3.0, 0.0), bright, 1.2)
		"Train":
			draw_line(center + Vector2(-8.0, 8.0), center + Vector2(8.0, -8.0), bright, 2.3)
			draw_line(center + Vector2(-6.0, -4.0), center + Vector2(4.0, 6.0), color, 2.3)
		"Forge":
			draw_rect(Rect2(center + Vector2(-8.0, -5.0), Vector2(16.0, 10.0)), color.darkened(0.18), true)
			draw_circle(center, 5.0, Color(1.0, 0.42, 0.16, 0.72))
			draw_line(center + Vector2(-9.0, 8.0), center + Vector2(9.0, -8.0), bright, 2.0)
		"Fight":
			draw_line(center + Vector2(-8.0, 8.0), center + Vector2(8.0, -8.0), bright, 2.6)
			draw_line(center + Vector2(-7.0, 2.0), center + Vector2(-2.0, 7.0), color, 2.1)
		"Tower":
			draw_rect(Rect2(center + Vector2(-7.0, -8.0), Vector2(14.0, 14.0)), color.darkened(0.12), true)
			draw_line(center + Vector2(-6.0, 7.0), center + Vector2(0.0, -8.0), bright, 1.8)
			draw_line(center + Vector2(6.0, 7.0), center + Vector2(0.0, -8.0), bright, 1.8)
			draw_line(center + Vector2(-8.0, -2.0), center + Vector2(8.0, -2.0), bright, 1.8)
		"Wait":
			draw_arc(center, 7.0, -PI * 0.50, PI * 1.25, 18, bright, 2.0)
			draw_line(center, center + Vector2(0.0, -7.0), bright, 1.4)
			draw_line(center, center + Vector2(5.0, 2.0), bright, 1.4)
		"Eat":
			draw_circle(center + Vector2(-3.0, 1.0), 6.0, color)
			draw_line(center + Vector2(6.0, -8.0), center + Vector2(6.0, 8.0), bright, 1.6)
		_:
			draw_rect(Rect2(center + Vector2(-7.0, -7.0), Vector2(14.0, 14.0)), color.darkened(0.08), true)
			draw_rect(Rect2(center + Vector2(-7.0, -7.0), Vector2(14.0, 14.0)), bright, false, 1.4)


func _intent_color(label: String) -> Color:
	match label:
		"Mine":
			return Color(0.74, 0.78, 0.72, 0.78)
		"Farm":
			return Color(0.54, 0.88, 0.32, 0.78)
		"Rest":
			return Color(0.92, 0.78, 0.42, 0.78)
		"Reflect":
			return Color(0.76, 0.66, 1.0, 0.78)
		"Train":
			return Color(1.0, 0.62, 0.25, 0.78)
		"Forge", "Fight":
			return Color(1.0, 0.46, 0.22, 0.78)
		"Wait":
			return Color(0.72, 0.82, 0.95, 0.72)
		"Eat":
			return Color(0.92, 0.56, 0.34, 0.78)
		"Orb", "Lamp", "Storm":
			return Color(0.38, 0.82, 1.0, 0.76)
		"Trap", "Mud", "Decoy", "Thorn", "Tower":
			return Color(0.95, 0.62, 0.30, 0.76)
	return Color(0.82, 0.88, 0.64, 0.76)
