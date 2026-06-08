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
const AriDoctrineScript = preload("res://scripts/ari/AriDoctrine.gd")
const ChronicleScript = preload("res://scripts/ari/Chronicle.gd")
const ScribeSystemScript = preload("res://scripts/ari/ScribeSystem.gd")

const OBSERVER_SNAPSHOT_INTERVAL := 5.0
const OBSERVER_SCRIBE_INTERVAL := 30.0
const FAST_PREDICTION_INTERVAL := 5.0
const FAST_PREDICTION_HIGH_SALIENCE := 0.65
const FAST_PREDICTION_AGENT_PLAN_HOLD_WINDOW := 1.0
const NIGHT_REFLECTION_SNAPSHOT_CAP := 40
const NIGHT_REFLECTION_EVENT_CAP := 80
const NIGHT_REFLECTION_SCRIBE_CAP := 10
const NIGHT_REFLECTION_DOCTRINE_CAP := 5
const AGENT_PLAN_REQUEST_COOLDOWN := 30.0
const BACKGROUND_AI_INTERVAL := 10.0
const BACKGROUND_AI_RESULT_CAP := 8
const ACTION_CONTROL_PANEL_DEFAULT_CAP := 24
const ACTION_CONTROL_PANEL_FAST_CAP := 14
const ARI_UNDERSTANDING_SCHEMA := "ari.understanding.v1"
const BEHAVIOR_EVIDENCE_SCHEMA := "ari.behavior_evidence.v1"
const BEHAVIOR_EVIDENCE_WINDOW_SECONDS := 45.0
const BEHAVIOR_ACTION_HISTORY_CAP := 32
const BEHAVIOR_EVIDENCE_CAP := 4
const AGENT_NONEXECUTABLE_ACTION_IDS := {
	"anti_flying": true,
	"anti_air_defense": true,
	"avoid_killing": true,
	"eat": true,
	"fight": true,
	"hide": true,
	"kite": true,
	"prepare_weapon": true,
	"ranged_attack": true,
	"regen_on_kill": true,
	"rely_on_regen": true,
	"sky_answer": true,
	"survive_until_morning": true,
	"train_bow": true,
	"use_armor": true,
	"use_existing_wall": true,
	"wait_behind_wall": true,
}

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
var ari_doctrine := AriDoctrineScript.new()
var chronicle := ChronicleScript.new()
var scribe_system := ScribeSystemScript.new()
var ari_rulebook := AriRulebookScript.new()
var ari_perception := AriPerceptionScript.new()
var agent_plan := {}
var agent_grounded_plan: Array = []
var ari_understanding := {}
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
var _ai_deep_interpretation_in_flight := false
var _ai_deep_interpretation_in_flight_signature := ""
var _ai_deep_interpretation_in_flight_sign_text := ""
var _ai_deep_interpretation_pending := false
var _ai_deep_interpretation_pending_sign_text := ""
var _ai_deep_interpretation_pending_show_waiting := false
var _ai_deep_interpretation_pending_bypass_cache := false
var _agent_plan_request_id := 0
var _agent_plan_replan_at := 0.0
var _agent_plan_clock := 0.0
var _agent_plan_request_in_flight := false
var _agent_plan_deferred_for_deep_interpretation := false
var _agent_plan_pending_trigger := ""
var _agent_plan_pending_at := 0.0
var _agent_plan_next_allowed_at := 0.0
var _agent_plan_request_trigger := ""
var _agent_plan_recent_outcomes: Array = []
var _agent_plan_timer_signature := ""
var _agent_plan_phase_signature := ""
var _observer_snapshot_elapsed := 0.0
var _observer_scribe_elapsed := 0.0
var _observer_scribe_request_in_flight := false
var _observer_recent_damage := 0.0
var _behavior_action_history: Array = []
var _latest_behavior_evidence := {}
var _behavior_sample_sequence := 0
var _fast_prediction_elapsed := 0.0
var _fast_prediction_request_in_flight := false
var _fast_prediction_request_id := 0
var _background_ai_elapsed := 0.0
var _background_ai_request_in_flight := false
var _background_ai_request_id := 0
var _background_ai_active_context_hash := ""
var _background_ai_results: Array = []
var _latest_body_alignment := {}
var _night_reflection_request_in_flight := false
var _night_reflection_requested := {}
var _logged_day_summary_ids := {}
var _pending_learning_trace_by_action := {}
var _learning_enabled := true
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
	scribe_system.ai_bridge = ai_bridge
	_update_ai_idle_status()
	start_run()


func _process(delta: float) -> void:
	_agent_plan_clock += maxf(delta, 0.0)
	_update_status_message(delta)
	_advance_ai_waiting(delta)
	_advance_agent_replan()
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
	advance_observer_memory(delta)
	_advance_fast_prediction(delta)
	_advance_background_ai(delta)
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
	ari_doctrine.clear()
	chronicle.clear_life()
	latest_lesson_title = ""
	_clear_agent_plan()
	_agent_plan_recent_outcomes.clear()
	_agent_plan_request_in_flight = false
	_agent_plan_pending_trigger = ""
	_agent_plan_pending_at = 0.0
	_agent_plan_next_allowed_at = 0.0
	_agent_plan_request_trigger = ""
	_agent_plan_timer_signature = ""
	_agent_plan_phase_signature = ""
	_observer_snapshot_elapsed = 0.0
	_observer_scribe_elapsed = 0.0
	_observer_scribe_request_in_flight = false
	_observer_recent_damage = 0.0
	_behavior_action_history.clear()
	_latest_behavior_evidence = {}
	_behavior_sample_sequence = 0
	_fast_prediction_elapsed = 0.0
	_fast_prediction_request_in_flight = false
	_fast_prediction_request_id = 0
	_background_ai_elapsed = 0.0
	_background_ai_request_in_flight = false
	_background_ai_request_id = 0
	_background_ai_active_context_hash = ""
	_background_ai_results.clear()
	_latest_body_alignment = {}
	ari_understanding = {}
	_night_reflection_request_in_flight = false
	_night_reflection_requested.clear()
	_logged_day_summary_ids.clear()
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
	_ai_deep_interpretation_in_flight = false
	_ai_deep_interpretation_in_flight_signature = ""
	_ai_deep_interpretation_in_flight_sign_text = ""
	_ai_deep_interpretation_pending = false
	_ai_deep_interpretation_pending_sign_text = ""
	_ai_deep_interpretation_pending_show_waiting = false
	_ai_deep_interpretation_pending_bypass_cache = false
	_finish_ai_waiting()
	_update_ai_idle_status()
	ai_survival_theory = ""
	ai_emotion = ""
	sign_grounded_plan = []
	if permanent_progression != null and permanent_progression.has_method("reset_run"):
		permanent_progression.call("reset_run")
	run_build.call("reset_run")
	_reinterpret_current_sign()
	_refresh_ari_understanding("restart")
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
	if sign_text.strip_edges() != "":
		_request_agent_plan("restart")
	queue_redraw()


func restart_run() -> void:
	start_run()


func commit_sign(text: String) -> void:
	sign_text = text.strip_edges()
	_reinterpret_current_sign()
	_refresh_ari_understanding("sign_commit")
	_set_status_message("Ari read the sign.", 1.4)
	_show_sign_interpretation_thought(true)
	_emit_state()
	_request_ai_deep_interpretation()
	_request_agent_plan("sign_commit")


func get_current_sign_text() -> String:
	return sign_text


func select_run_build_preset(preset_number: int, show_feedback := true) -> void:
	if run_build == null or not bool(run_build.call("apply_preset_key", preset_number)):
		return
	_apply_run_build_to_ari()
	_reinterpret_current_sign()
	_refresh_ari_understanding("run_build_changed")
	if show_feedback:
		_set_status_message("Run build: %s" % str(run_build.call("get_preset_name")), 1.8)
		_show_ari_thought(str(run_build.call("get_preset_thought")), true)
	_emit_state()
	if sign_text.strip_edges() != "":
		_request_ai_deep_interpretation(false)
		_request_agent_plan("run_build_changed")


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


func set_learning_enabled(enabled: bool) -> void:
	_learning_enabled = enabled


func is_learning_enabled() -> bool:
	return _learning_enabled


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
	var new_enemy_type := resolved_enemy_type != "zombie" and not bool(_noticed_enemy_types.get(resolved_enemy_type, false))
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
	_record_observer_snapshot("enemy_spawned", 0.75 if new_enemy_type else 0.45, ["new_enemy_type" if new_enemy_type else "enemy_spawned", resolved_enemy_type])
	_show_new_enemy_type_thought(resolved_enemy_type)
	if new_enemy_type:
		_request_agent_plan("new_enemy_type")


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
	_record_observer_snapshot("action_completed", 0.55, ["aura_damage_success"])


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
		"agent_plan": agent_plan,
		"agent_grounded_plan": agent_grounded_plan,
		"ari_understanding": _compact_ari_understanding(ari_understanding, 4),
		"ari_understanding_line": _limit_inline(str(ari_understanding.get("display_line", "")), 120),
		"body_alignment": _compact_body_alignment(_latest_body_alignment),
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
	if ari != null and _is_ari_alive():
		_record_observer_snapshot("phase_change", 0.55, ["phase_%s" % _phase])
	if _phase == "morning":
		_clear_enemies_for_dawn()
		if _day > 1 and ari != null and _is_ari_alive():
			_request_night_reflection("dawn_survived", "survived")
	if day_night.is_night() and ari != null:
		ari.call("stop_daytime_job", "Night has started")
		_show_current_job_thought(true)
		_request_night_reflection("night_started", "in_progress")
	_emit_state()
	_request_agent_plan("phase_changed")


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
	_record_agent_plan_outcome(_current_agent_step_action_id(), "ari_died", "Ari died before the active plan kept him safe.", "death")
	_record_observer_snapshot("death", 1.0, ["ari_died"])
	_request_night_reflection("death", "died")
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
	_observer_recent_damage = maxf(_observer_recent_damage, maxf(max_hp - hp, 1.0))
	_record_observer_snapshot("damage", 0.85, ["ari_damaged"])
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
		_record_agent_plan_outcome(_current_agent_step_action_id(), "near_death", "Ari was nearly killed while executing the plan.", "near_death")
		_show_ari_thought("That was too close. I need distance, cover, or something that hurts them first.", true)
		_request_agent_plan("near_death")
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
	_record_agent_plan_outcome(_agent_action_for_build_type(build_type), "action_completed", "%s was built." % _get_build_name(build_type), "structure_built")
	_record_observer_snapshot("action_completed", 0.55, ["structure_built", build_type])
	if sign_text.strip_edges() != "":
		_reinterpret_current_sign()
	_set_status_message("%s placed. -%d stone." % [_get_build_name(build_type), int(cost.get("stone", 0))], 1.2)
	_emit_state()
	_request_agent_plan(_structure_built_agent_plan_trigger(build_type))
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
	var destroyed_action_id := _agent_action_for_build_type(structure_type)
	_record_agent_plan_outcome(destroyed_action_id, "structure_destroyed", "%s was destroyed." % _get_build_name(structure_type), "structure_destroyed")
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
	_record_observer_snapshot("structure_destroyed", 0.9, ["structure_destroyed", structure_type])
	_show_structure_destroyed_thought(structure_type)
	var cell_to_remove = null
	for cell in structure_cells.keys():
		if structure_cells[cell] == structure:
			cell_to_remove = cell
			break
	if cell_to_remove != null:
		structure_cells.erase(cell_to_remove)
	_emit_state()
	_request_agent_plan(_structure_destroyed_agent_plan_trigger(destroyed_action_id))


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
	_record_observer_snapshot("structure_damaged", 0.65, ["structure_damaged", str(structure.get("structure_type"))])


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
	_record_observer_snapshot("action_completed", 0.55, ["enemy_killed"])
	if healed > 0.0 and not _regen_on_kill_reported:
		_regen_on_kill_reported = true
		_show_ari_thought("The kill gave a little life back.", true)
	_emit_state()


func _on_resource_changed(_resource_state: Dictionary) -> void:
	_emit_state()


func advance_observer_memory(delta: float) -> void:
	var safe_delta := maxf(delta, 0.0)
	if safe_delta <= 0.0:
		return
	_observer_snapshot_elapsed += safe_delta
	_observer_scribe_elapsed += safe_delta
	while _observer_snapshot_elapsed >= OBSERVER_SNAPSHOT_INTERVAL:
		_observer_snapshot_elapsed -= OBSERVER_SNAPSHOT_INTERVAL
		_record_observer_snapshot("timer", 0.1, [])
	if _observer_scribe_elapsed >= OBSERVER_SCRIBE_INTERVAL:
		_try_request_scribe_note()
	_observer_recent_damage = maxf(_observer_recent_damage - safe_delta * 6.0, 0.0)


func _record_observer_snapshot(trigger: String, salience := 0.0, notable_changes: Array = []) -> Dictionary:
	var snapshot := _build_observer_snapshot(trigger, salience, notable_changes)
	ari_memory.record_snapshot(snapshot)
	_prime_fast_prediction_for_snapshot(trigger, salience)
	return snapshot


func _prime_fast_prediction_for_snapshot(trigger: String, salience: float) -> void:
	if _fast_prediction_request_in_flight:
		return
	var clean_trigger := trigger.strip_edges()
	if clean_trigger == "timer" or clean_trigger == "":
		return
	if not _should_prime_fast_prediction(clean_trigger, salience):
		return
	_fast_prediction_elapsed = maxf(_fast_prediction_elapsed, FAST_PREDICTION_INTERVAL)


func _should_prime_fast_prediction(trigger: String, salience: float) -> bool:
	if [
		"damage",
		"structure_destroyed",
		"action_failed",
		"death",
	].has(trigger):
		return true
	if salience < FAST_PREDICTION_HIGH_SALIENCE:
		return false
	if ["enemy_spawned", "new_enemy_type", "structure_damaged"].has(trigger):
		return _has_urgent_prediction_risk()
	return salience >= 0.9 and _has_urgent_prediction_risk()


func _has_urgent_prediction_risk() -> bool:
	for risk in _prediction_risks(_observer_nearest_danger()):
		if typeof(risk) != TYPE_DICTIONARY:
			continue
		var risk_type := str(risk.get("type", ""))
		var severity := float(risk.get("severity", 0.0))
		if risk_type == "flying" or severity >= 0.75:
			return true
	return false


func _record_behavior_action_sample(action_id: String, status := "in_progress", reason := "", trigger := "") -> Dictionary:
	var clean_action := action_id.strip_edges()
	if clean_action == "":
		return {}
	_behavior_sample_sequence += 1
	var nearest := _observer_nearest_danger()
	var sample := {
		"sample_id": "day%d_%04d_behavior_%03d" % [day_night.day, int(round(_agent_plan_clock * 10.0)), _behavior_sample_sequence],
		"day": day_night.day,
		"phase": day_night.phase,
		"time": _agent_plan_clock,
		"action_id": clean_action,
		"status": _limit_inline(str(status), 40),
		"reason": _limit_inline(str(reason), 140),
		"trigger": _limit_inline(str(trigger), 80),
		"plan_action": _current_agent_step_action_id(),
		"stone": _stone_count(),
		"food": _food_count(),
		"ore": _ore_count(),
		"hp": float(ari.get("hp")) if ari != null else 0.0,
		"structures": structures.size(),
		"damaged_structures": _get_damaged_structure_count(),
		"enemy_count": enemies.size(),
		"enemy_type_counts": _get_enemy_type_counts(),
		"nearest_danger": nearest,
		"anchor_id": _behavior_anchor_id(clean_action, reason),
	}
	_behavior_action_history.append(sample)
	_trim_behavior_action_history()
	_latest_behavior_evidence = _build_behavior_evidence_from_history()
	return sample.duplicate(true)


func _trim_behavior_action_history() -> void:
	while _behavior_action_history.size() > BEHAVIOR_ACTION_HISTORY_CAP:
		_behavior_action_history.pop_front()
	var cutoff := _agent_plan_clock - BEHAVIOR_EVIDENCE_WINDOW_SECONDS
	while _behavior_action_history.size() > 1:
		var first = _behavior_action_history[0]
		if typeof(first) != TYPE_DICTIONARY or float(first.get("time", 0.0)) >= cutoff:
			break
		_behavior_action_history.pop_front()


func _behavior_anchor_id(action_id: String, reason: String = "") -> String:
	var text := ("%s %s" % [action_id, reason]).to_lower()
	if text.find("tower") >= 0 or text.find("range") >= 0 or text.find("perch") >= 0:
		return "tower"
	if text.find("aura") >= 0 or text.find("light") >= 0:
		return "aura"
	if text.find("wall") >= 0 or text.find("cover") >= 0:
		return "cover"
	if text.find("lantern") >= 0 or text.find("warm") >= 0:
		return "fear_lantern"
	if text.find("decoy") >= 0 or text.find("false self") >= 0:
		return "decoy"
	if text.find("thorn") >= 0:
		return "thorn"
	if text.find("repair") >= 0 or text.find("patch") >= 0:
		return "repair_target"
	if text.find("mine") >= 0 or text.find("stone") >= 0:
		return "resource_node"
	return ""


func _current_behavior_evidence() -> Dictionary:
	if _latest_behavior_evidence.is_empty():
		_latest_behavior_evidence = _build_behavior_evidence_from_history()
	return _latest_behavior_evidence.duplicate(true)


func _behavior_evidence_array(max_count: int = BEHAVIOR_EVIDENCE_CAP) -> Array:
	var items := _build_behavior_evidence_items_from_history()
	if items.is_empty() and not _latest_behavior_evidence.is_empty():
		items = [_latest_behavior_evidence]
	var result := []
	for item in items:
		var evidence := _compact_behavior_evidence(item)
		if evidence.is_empty():
			continue
		result.append(evidence)
		if result.size() >= max_count:
			break
	return result


func _behavior_evidence_compact_array(value, max_count: int = BEHAVIOR_EVIDENCE_CAP) -> Array:
	var result := []
	if typeof(value) == TYPE_DICTIONARY:
		var evidence := _compact_behavior_evidence(value)
		if not evidence.is_empty():
			result.append(evidence)
	elif typeof(value) == TYPE_ARRAY:
		for item in value:
			var evidence := _compact_behavior_evidence(item)
			if evidence.is_empty():
				continue
			result.append(evidence)
			if result.size() >= max_count:
				break
	return result


func _build_behavior_evidence_from_history() -> Dictionary:
	var items := _build_behavior_evidence_items_from_history()
	if items.is_empty():
		return {}
	return items[0].duplicate(true)


func _build_behavior_evidence_items_from_history() -> Array:
	if _behavior_action_history.size() < 2:
		return []
	var samples := []
	var first_time := float(_behavior_action_history[0].get("time", _agent_plan_clock))
	var cutoff := _agent_plan_clock - BEHAVIOR_EVIDENCE_WINDOW_SECONDS
	for item in _behavior_action_history:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if float(item.get("time", first_time)) < cutoff:
			continue
		samples.append(item)
	if samples.size() < 2:
		return []
	var first: Dictionary = samples[0]
	var last: Dictionary = samples[samples.size() - 1]
	var actions_seen: Array[String] = []
	var anchors_seen: Array[String] = []
	var evidence_ids: Array[String] = []
	var transition_count := 0
	var anchor_transition_count := 0
	var completion_count := 0
	var blocked_count := 0
	var explicit_abandoned_count := 0
	var previous_action := ""
	var previous_anchor := ""
	for sample in samples:
		var action := str(sample.get("action_id", "")).strip_edges()
		if action != "":
			_summary_append(actions_seen, action, 8)
		var anchor_id := str(sample.get("anchor_id", "")).strip_edges()
		if anchor_id != "":
			_summary_append(anchors_seen, anchor_id, 8)
		var sample_id := str(sample.get("sample_id", "")).strip_edges()
		if sample_id != "":
			_summary_append(evidence_ids, sample_id, 12)
		var status_text := str(sample.get("status", "")).strip_edges().to_lower()
		if status_text.contains("completed") or status_text == "action_completed":
			completion_count += 1
		if status_text.contains("blocked"):
			blocked_count += 1
		if status_text.contains("abandoned"):
			explicit_abandoned_count += 1
		if previous_action != "" and action != "" and action != previous_action:
			transition_count += 1
		if action != "":
			previous_action = action
		if previous_anchor != "" and anchor_id != "" and anchor_id != previous_anchor:
			anchor_transition_count += 1
		if anchor_id != "":
			previous_anchor = anchor_id
	var structures_delta := int(last.get("structures", 0)) - int(first.get("structures", 0))
	var stone_delta := int(last.get("stone", 0)) - int(first.get("stone", 0))
	var damaged_delta := int(last.get("damaged_structures", 0)) - int(first.get("damaged_structures", 0))
	var repairs_delta := maxi(0, -damaged_delta)
	var hp_delta := int(round(float(last.get("hp", 0.0)) - float(first.get("hp", 0.0))))
	var primary_pattern := ""
	if transition_count >= 4 and completion_count == 0 and structures_delta <= 0 and repairs_delta == 0:
		primary_pattern = "repeated_action_switching"
	elif blocked_count >= 2:
		primary_pattern = "repeated_blocked_action"
	elif explicit_abandoned_count >= 2 and structures_delta <= 0 and repairs_delta == 0:
		primary_pattern = "abandoned_before_progress"
	elif stone_delta < 0 and structures_delta <= 0 and repairs_delta == 0:
		primary_pattern = "resource_spend_without_progress"
	var first_danger = first.get("nearest_danger", {})
	var last_danger = last.get("nearest_danger", {})
	var first_danger_type := str(first_danger.get("type", "none")) if typeof(first_danger) == TYPE_DICTIONARY else "none"
	var last_danger_type := str(last_danger.get("type", "none")) if typeof(last_danger) == TYPE_DICTIONARY else "none"
	var first_plan := str(first.get("plan_action", ""))
	var last_plan := str(last.get("plan_action", ""))
	var window_seconds := maxf(float(last.get("time", _agent_plan_clock)) - float(first.get("time", _agent_plan_clock)), 0.0)
	var base := {
		"schema": BEHAVIOR_EVIDENCE_SCHEMA,
		"window_seconds": clampf(window_seconds, 0.0, BEHAVIOR_EVIDENCE_WINDOW_SECONDS),
		"actions_seen": actions_seen,
		"transition_count": transition_count,
		"completion_count": completion_count,
		"blocked_count": blocked_count,
		"abandoned_count": maxi(explicit_abandoned_count, transition_count - completion_count),
		"progress_delta": {
			"structures": structures_delta,
			"stone": stone_delta,
			"repairs": repairs_delta,
			"kills": 0,
			"hp": hp_delta,
		},
		"context": {
			"phase": str(last.get("phase", day_night.phase)),
			"enemy_count_before": int(first.get("enemy_count", 0)),
			"enemy_count_after": int(last.get("enemy_count", 0)),
			"nearest_danger_changed": first_danger_type != last_danger_type,
			"active_plan_changed": first_plan != last_plan,
		},
		"evidence_ids": evidence_ids,
	}
	var results := []
	if primary_pattern != "":
		var action_evidence: Dictionary = base.duplicate(true)
		action_evidence["primary_pattern"] = primary_pattern
		action_evidence["neutral_summary"] = _behavior_neutral_summary(primary_pattern, actions_seen, transition_count, completion_count, window_seconds)
		results.append(action_evidence)
	if anchor_transition_count >= 4 and completion_count == 0 and anchors_seen.size() >= 2:
		var anchor_evidence: Dictionary = base.duplicate(true)
		anchor_evidence["primary_pattern"] = "repeated_anchor_switching"
		anchor_evidence["anchors_seen"] = anchors_seen
		anchor_evidence["anchor_transition_count"] = anchor_transition_count
		anchor_evidence["neutral_summary"] = "Ari switched defensive anchors between %s %d times in %.0f seconds; no build or repair completed." % [_human_behavior_action_list(anchors_seen), anchor_transition_count, window_seconds]
		results.append(anchor_evidence)
	return results


func _behavior_neutral_summary(pattern: String, actions_seen: Array[String], transition_count: int, completion_count: int, window_seconds: float) -> String:
	var action_text := _human_behavior_action_list(actions_seen)
	match pattern:
		"repeated_action_switching":
			return "Ari switched between %s %d times in %.0f seconds; %s." % [action_text, transition_count, window_seconds, "no build or repair completed" if completion_count == 0 else "%d action(s) completed" % completion_count]
		"repeated_blocked_action":
			return "Ari repeated blocked action attempts around %s in %.0f seconds." % [action_text, window_seconds]
		"abandoned_before_progress":
			return "Ari left %s before visible progress completed in %.0f seconds." % [action_text, window_seconds]
		"resource_spend_without_progress":
			return "Ari spent resources during %s without visible structure or repair progress." % action_text
	return "Ari showed behavior pattern %s around %s." % [pattern, action_text]


func _human_behavior_action_list(actions: Array[String]) -> String:
	if actions.is_empty():
		return "unknown actions"
	if actions.size() == 1:
		return actions[0]
	if actions.size() == 2:
		return "%s and %s" % [actions[0], actions[1]]
	return "%s, and %s" % [", ".join(actions.slice(0, actions.size() - 1)), actions[actions.size() - 1]]


func _compact_behavior_evidence(value) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var pattern := _limit_inline(str(value.get("primary_pattern", "")), 80)
	if pattern == "":
		return {}
	var context = value.get("context", {})
	var safe_context := {}
	if typeof(context) == TYPE_DICTIONARY:
		safe_context = {
			"phase": _limit_inline(str(context.get("phase", "")), 40),
			"enemy_count_before": max(0, int(context.get("enemy_count_before", 0))),
			"enemy_count_after": max(0, int(context.get("enemy_count_after", 0))),
			"nearest_danger_changed": bool(context.get("nearest_danger_changed", false)),
			"active_plan_changed": bool(context.get("active_plan_changed", false)),
		}
	var progress = value.get("progress_delta", {})
	var safe_progress := {}
	if typeof(progress) == TYPE_DICTIONARY:
		safe_progress = {
			"structures": int(progress.get("structures", 0)),
			"stone": int(progress.get("stone", 0)),
			"repairs": int(progress.get("repairs", 0)),
			"kills": int(progress.get("kills", 0)),
			"hp": int(progress.get("hp", 0)),
		}
	return {
		"schema": BEHAVIOR_EVIDENCE_SCHEMA,
		"window_seconds": clampf(float(value.get("window_seconds", 0.0)), 0.0, BEHAVIOR_EVIDENCE_WINDOW_SECONDS),
		"primary_pattern": pattern,
		"actions_seen": _summary_string_array(value.get("actions_seen", []), 8, 80),
		"transition_count": max(0, int(value.get("transition_count", 0))),
		"completion_count": max(0, int(value.get("completion_count", 0))),
		"blocked_count": max(0, int(value.get("blocked_count", 0))),
		"abandoned_count": max(0, int(value.get("abandoned_count", 0))),
		"anchors_seen": _summary_string_array(value.get("anchors_seen", []), 8, 80),
		"anchor_transition_count": max(0, int(value.get("anchor_transition_count", 0))),
		"progress_delta": safe_progress,
		"context": safe_context,
		"evidence_ids": _summary_string_array(value.get("evidence_ids", []), 12, 120),
		"neutral_summary": _limit_inline(str(value.get("neutral_summary", "")), 220),
	}


func _collect_summary_behavior_evidence(source, behavior_evidence: Array, behavior_patterns: Array[String], evidence_ids: Array[String], what_changed: Array[String], went_wrong: Array[String], candidate_lessons: Array[String]) -> void:
	if typeof(source) == TYPE_ARRAY:
		for item in source:
			_collect_summary_behavior_evidence(item, behavior_evidence, behavior_patterns, evidence_ids, what_changed, went_wrong, candidate_lessons)
		return
	var evidence := _compact_behavior_evidence(source)
	if evidence.is_empty():
		return
	var pattern := str(evidence.get("primary_pattern", "")).strip_edges()
	if pattern == "":
		return
	_summary_append(behavior_patterns, pattern, BEHAVIOR_EVIDENCE_CAP)
	_summary_append(what_changed, pattern, 10)
	var neutral_summary := str(evidence.get("neutral_summary", "")).strip_edges()
	if neutral_summary != "":
		_summary_append(went_wrong, neutral_summary, 8)
	_summary_append(candidate_lessons, "review whether %s helped survival" % pattern, 8)
	for evidence_id in _summary_string_array(evidence.get("evidence_ids", []), 12, 120):
		_summary_append(evidence_ids, evidence_id, 12)
	var duplicate := false
	for existing in behavior_evidence:
		if typeof(existing) == TYPE_DICTIONARY and str(existing.get("primary_pattern", "")) == pattern:
			duplicate = true
			break
	if not duplicate and behavior_evidence.size() < BEHAVIOR_EVIDENCE_CAP:
		behavior_evidence.append(evidence)


func _build_observer_snapshot(trigger: String, salience := 0.0, notable_changes: Array = []) -> Dictionary:
	_refresh_ari_understanding(trigger)
	var ari_job := str(ari.call("get_current_job")) if ari != null and ari.has_method("get_current_job") else "wait_or_idle"
	var ari_action := str(ari.call("get_current_action")) if ari != null and ari.has_method("get_current_action") else "idle"
	var ari_reason := str(ari.call("get_job_reason")) if ari != null and ari.has_method("get_job_reason") else "Waiting"
	var needs := _get_ari_needs()
	var nearest_danger := _observer_nearest_danger()
	var plan_source := str(agent_plan.get("source", ""))
	if plan_source == "":
		plan_source = "agent_plan" if not agent_plan.is_empty() else "fallback"
	var next_action := _current_agent_step_action_id()
	if next_action == "":
		next_action = _local_fallback_agent_action_id()
	_record_behavior_action_sample(ari_action, "in_progress", ari_reason, trigger)
	var behavior_evidence := _current_behavior_evidence()
	return {
		"schema": "ari.observer.snapshot.v1",
		"snapshot_id": "day%d_%04d_%s" % [day_night.day, int(round(_agent_plan_clock * 10.0)), trigger],
		"trigger": trigger,
		"day": day_night.day,
		"phase": day_night.phase,
		"time_left": day_night.get_time_left(),
		"ari": {
			"hp": float(ari.get("hp")) if ari != null else 0.0,
			"max_hp": float(ari.get("max_hp")) if ari != null else 0.0,
			"fear": float(needs.get("fear", 0.0)),
			"hunger": float(needs.get("hunger", 0.0)),
			"stamina": float(needs.get("stamina", 0.0)),
			"current_job": ari_job,
			"current_action": ari_action,
			"current_reason": ari_reason,
		},
		"sign": {
			"text": sign_text,
			"interpretation": sign_interpretation,
			"survival_theory": ai_survival_theory,
			"resonance": sign_resonance,
		},
		"plan": {
			"goal": str(agent_plan.get("goal", "survive_next_night")) if not agent_plan.is_empty() else "survive_next_night",
			"next_action": next_action,
			"current_step": int(agent_plan.get("step_index", 0)) if not agent_plan.is_empty() else 0,
			"source": plan_source,
			"age_seconds": maxf(_agent_plan_clock - float(agent_plan.get("created_at_seconds", _agent_plan_clock)), 0.0) if not agent_plan.is_empty() else 0.0,
			"recent_outcomes": _observer_recent_outcome_labels(6),
		},
		"understanding": _compact_ari_understanding(ari_understanding, 4),
		"body_alignment": _compact_body_alignment(_latest_body_alignment),
		"behavior_evidence": behavior_evidence,
		"world": {
			"resources": {"food": _food_count(), "stone": _stone_count(), "ore": _ore_count()},
			"run_build": _observer_run_build_summary(),
			"structures": {
				"walls": walls.size(),
				"aura_orbs": aura_orbs.size(),
				"spike_traps": spike_traps.size(),
				"towers": bow_towers.size(),
				"tar_pits": tar_pits.size(),
				"fear_lanterns": fear_lanterns.size(),
				"decoy_idols": decoy_idols.size(),
				"thorn_totems": thorn_totems.size(),
				"repair_benches": repair_benches.size(),
				"storm_rods": storm_rods.size(),
				"damaged": _get_damaged_structure_count(),
			},
			"enemies": {
				"count": enemies.size(),
				"types": _get_enemy_type_counts(),
			},
			"nearest_danger": nearest_danger,
			"recent_damage": _observer_recent_damage,
			"notable_changes": _observer_string_array(notable_changes, 8),
		},
		"salience": clampf(salience, 0.0, 1.0),
	}


func _try_request_scribe_note() -> void:
	if _observer_scribe_request_in_flight:
		return
	_observer_scribe_elapsed = 0.0
	if scribe_system == null or chronicle == null or ari_memory == null:
		return
	if ari_memory.get_recent_snapshots(1).is_empty() and ari_memory.get_recent_events(1).is_empty():
		return
	_observer_scribe_request_in_flight = true
	scribe_system.ai_bridge = ai_bridge
	scribe_system.create_scribe_note_from_recent_memory(ari_memory, chronicle, _build_scribe_context(), func(_note: Dictionary) -> void:
		_observer_scribe_request_in_flight = false
		_emit_state()
	)


func _build_scribe_context() -> Dictionary:
	_refresh_ari_understanding("scribe")
	return {
		"schema": "ari.scribe.request.v1",
		"day": day_night.day,
		"phase": day_night.phase,
		"current_sign": sign_text,
		"active_plan": _agent_current_plan_payload(),
		"understanding": _compact_ari_understanding(ari_understanding, 4),
		"body_alignment": _compact_body_alignment(_latest_body_alignment),
		"behavior_evidence": _behavior_evidence_array(BEHAVIOR_EVIDENCE_CAP),
		"snapshots": ari_memory.get_recent_snapshots(10),
		"max_words": 35,
	}


func _request_night_reflection(trigger: String, outcome: String) -> void:
	if not _should_spend_smart_reflection(trigger, outcome):
		return
	if ai_bridge == null or _night_reflection_request_in_flight:
		return
	var key := "%d:%s" % [day_night.day, trigger]
	if bool(_night_reflection_requested.get(key, false)):
		return
	_night_reflection_requested[key] = true
	_night_reflection_request_in_flight = true
	var payload := _build_night_reflection_payload(trigger, outcome)
	ai_bridge.request_library_reflection(payload, func(note: Dictionary) -> void:
		_night_reflection_request_in_flight = false
		_handle_night_reflection_response(note, trigger)
	)


func _should_spend_smart_reflection(trigger: String, outcome: String) -> bool:
	if trigger == "library_reflection" or trigger == "death":
		return true
	if trigger == "dawn_survived" and outcome == "survived":
		return true
	return false


func _build_night_reflection_payload(trigger: String, outcome: String) -> Dictionary:
	_refresh_ari_understanding(trigger)
	var doctrine_context := _doctrine_context()
	var day_summary := _build_day_summary(trigger, outcome)
	_log_day_summary(day_summary)
	return {
		"schema": "ari.night_reflection.request.v2",
		"trigger": trigger,
		"day": day_night.day,
		"outcome": outcome,
		"sign": {
			"text": sign_text,
			"interpretation": sign_interpretation,
			"survival_theory": ai_survival_theory,
			"priority_hints": sign_priority_hints,
			"grounded_plan": sign_grounded_plan,
			"resonance": sign_resonance,
		},
		"understanding": _compact_ari_understanding(ari_understanding, 4),
		"body_alignment": _compact_body_alignment(_latest_body_alignment),
		"day_summary": day_summary,
		"behavior_evidence": _behavior_evidence_array(BEHAVIOR_EVIDENCE_CAP),
		"snapshots": _reflection_snapshot_selection(NIGHT_REFLECTION_SNAPSHOT_CAP),
		"recent_events": ari_memory.get_recent_events(NIGHT_REFLECTION_EVENT_CAP),
		"scribe_notes": _recent_scribe_notes(NIGHT_REFLECTION_SCRIBE_CAP),
		"active_doctrines": _learned_active_doctrines(doctrine_context, NIGHT_REFLECTION_DOCTRINE_CAP),
		"agent_plan_outcomes": _agent_recent_outcomes(12),
		"latest_lifetime_notes": ari_memory.get_lifetime_notes(5),
		"max_words": 160,
	}


func _day_summary_id(trigger: String, outcome: String) -> String:
	var clean_trigger := trigger.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var clean_outcome := outcome.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	if clean_trigger == "":
		clean_trigger = "summary"
	if clean_outcome == "":
		clean_outcome = "unknown"
	return "day%d_%s_%s_summary" % [day_night.day, clean_trigger, clean_outcome]


func _build_day_summary(trigger: String, outcome: String) -> Dictionary:
	var snapshots := _reflection_snapshot_selection(NIGHT_REFLECTION_SNAPSHOT_CAP)
	var events := ari_memory.get_recent_events(NIGHT_REFLECTION_EVENT_CAP) if ari_memory != null else []
	var notes := _recent_scribe_notes(NIGHT_REFLECTION_SCRIBE_CAP)
	var timeline: Array[String] = []
	var what_changed: Array[String] = []
	var worked: Array[String] = []
	var went_wrong: Array[String] = []
	var misunderstood: Array[String] = []
	var plan_mismatches: Array[String] = []
	var prerequisite_progress: Array[String] = []
	var safety_substitutions: Array[String] = []
	var resource_blockers: Array[String] = []
	var threats: Array[String] = []
	var candidate_lessons: Array[String] = []
	var recommended_priority_hints: Array[String] = []
	var evidence_snapshot_ids: Array[String] = []
	var behavior_patterns: Array[String] = []
	var behavior_evidence: Array = []
	var alignment_counts := {"aligned": 0, "supporting": 0, "mismatch": 0, "unknown": 0}
	var current_understanding := _compact_ari_understanding(ari_understanding, 3)

	for snapshot in snapshots:
		if typeof(snapshot) != TYPE_DICTIONARY:
			continue
		var snapshot_id := str(snapshot.get("snapshot_id", "")).strip_edges()
		if snapshot_id != "":
			_summary_append(evidence_snapshot_ids, snapshot_id, 12)
		var snapshot_understanding = snapshot.get("understanding", {})
		if current_understanding.is_empty() and typeof(snapshot_understanding) == TYPE_DICTIONARY and str(snapshot_understanding.get("schema", "")) == ARI_UNDERSTANDING_SCHEMA:
			current_understanding = _compact_ari_understanding(snapshot_understanding, 3)
		var body_alignment = snapshot.get("body_alignment", {})
		if typeof(body_alignment) == TYPE_DICTIONARY:
			var relation := str(body_alignment.get("relation", "")).strip_edges()
			var alignment_line := _body_alignment_summary_line(body_alignment)
			if relation == "prerequisite_progress":
				_summary_append(prerequisite_progress, alignment_line, 8)
				_summary_append(worked, alignment_line, 8)
			elif relation == "safety_substitution":
				_summary_append(safety_substitutions, alignment_line, 8)
				_summary_append(worked, alignment_line, 8)
			elif relation == "mismatch":
				_summary_append(plan_mismatches, alignment_line, 8)
				_summary_append(misunderstood, "Ari's body did not match the active plan.", 8)
		_collect_summary_behavior_evidence(snapshot.get("behavior_evidence", {}), behavior_evidence, behavior_patterns, evidence_snapshot_ids, what_changed, went_wrong, candidate_lessons)
		var world_state = snapshot.get("world", {})
		if typeof(world_state) != TYPE_DICTIONARY:
			continue
		var nearest = world_state.get("nearest_danger", {})
		if typeof(nearest) == TYPE_DICTIONARY:
			var danger_type := str(nearest.get("type", "")).strip_edges()
			if danger_type != "" and danger_type != "none":
				_summary_append(threats, danger_type, 8)
		var enemies_state = world_state.get("enemies", {})
		if typeof(enemies_state) == TYPE_DICTIONARY:
			var enemy_types = enemies_state.get("types", {})
			if typeof(enemy_types) == TYPE_DICTIONARY:
				for enemy_type in enemy_types.keys():
					if int(enemy_types[enemy_type]) > 0:
						_summary_append(threats, str(enemy_type), 8)
		for change in _summary_string_array(world_state.get("notable_changes", []), 6, 80):
			_summary_append(what_changed, change, 10)
		if float(world_state.get("recent_damage", 0.0)) > 0.0:
			_summary_append(went_wrong, "Ari took recent damage.", 8)
		var resources = world_state.get("resources", {})
		if typeof(resources) == TYPE_DICTIONARY and float(resources.get("stone", 99.0)) <= 3.0:
			_summary_append(resource_blockers, "low_stone", 8)

	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var event_type := str(event.get("type", "")).strip_edges()
		if event_type == "":
			continue
		match event_type:
			"enemy_spawned", "new_enemy_type":
				_summary_append(what_changed, event_type, 10)
				var enemy_type := str(event.get("enemy_type", "")).strip_edges()
				if enemy_type != "":
					_summary_append(threats, enemy_type, 8)
			"ari_damaged", "near_death", "death", "structure_destroyed":
				_summary_append(went_wrong, event_type, 8)
			"structure_built", "structure_repaired", "enemy_killed", "tower_ranged_success", "aura_damage_success":
				_summary_append(worked, event_type, 8)

	for note in notes:
		if typeof(note) != TYPE_DICTIONARY:
			continue
		var note_text := str(note.get("note", "")).strip_edges()
		if note_text != "":
			_summary_append(timeline, note_text, 8)
		var alignment := str(note.get("plan_alignment", "unknown")).strip_edges()
		if not alignment_counts.has(alignment):
			alignment = "unknown"
		alignment_counts[alignment] = int(alignment_counts[alignment]) + 1
		if alignment == "mismatch":
			_summary_append(plan_mismatches, note_text if note_text != "" else "Ari's body action did not match the active plan.", 8)
			_summary_append(misunderstood, "Ari's body did not match the active plan.", 8)
		elif alignment == "supporting":
			_summary_append(worked, note_text if note_text != "" else "Ari supported the active plan.", 8)
		for danger in note.get("dangers", []):
			if typeof(danger) == TYPE_DICTIONARY:
				var danger_name := str(danger.get("type", "")).strip_edges()
				if danger_name != "" and danger_name != "none":
					_summary_append(threats, danger_name, 8)
		for change in _summary_string_array(note.get("world_changes", []), 6, 80):
			_summary_append(what_changed, change, 10)
			if change == "prerequisite_progress":
				_summary_append(prerequisite_progress, note_text if note_text != "" else "Ari made prerequisite progress toward the active plan.", 8)
			elif change == "safety_substitution":
				_summary_append(safety_substitutions, note_text if note_text != "" else "Ari chose a safer substitute under pressure.", 8)
		_collect_summary_behavior_evidence(note.get("behavior_evidence", []), behavior_evidence, behavior_patterns, evidence_snapshot_ids, what_changed, went_wrong, candidate_lessons)
		for blocker in _summary_string_array(note.get("resource_blockers", []), 5, 80):
			_summary_append(resource_blockers, blocker, 8)
		for mistake in _summary_string_array(note.get("mistake_candidates", []), 5, 140):
			_summary_append(went_wrong, mistake, 8)
		for lesson in _summary_string_array(note.get("lesson_candidates", []), 5, 140):
			_summary_append(candidate_lessons, lesson, 8)
		for evidence_id in _summary_string_array(note.get("evidence_ids", note.get("evidence_snapshot_ids", [])), 8, 120):
			_summary_append(evidence_snapshot_ids, evidence_id, 12)
		var hints = note.get("priority_hints", {})
		if typeof(hints) == TYPE_DICTIONARY:
			for hint_key in hints.keys():
				if absf(float(hints[hint_key])) > 0.0:
					_summary_append(recommended_priority_hints, str(hint_key), 10)

	for outcome_record in _agent_recent_outcomes(12):
		if typeof(outcome_record) != TYPE_DICTIONARY:
			continue
		var outcome_id := str(outcome_record.get("outcome", "")).strip_edges()
		var action_id := str(outcome_record.get("action_id", "")).strip_edges()
		var label := "%s:%s" % [action_id, outcome_id]
		if outcome_id.contains("failed") or outcome_id.contains("death") or outcome_id.contains("near"):
			_summary_append(went_wrong, label, 8)
		elif outcome_id.contains("completed") or outcome_id.contains("built") or outcome_id.contains("repaired"):
			_summary_append(worked, label, 8)

	if threats.has("flying"):
		_summary_append(candidate_lessons, "when wings appear, answer the sky first", 8)
		_summary_append(recommended_priority_hints, "anti_air_defense", 10)
		_summary_append(recommended_priority_hints, "build_storm_rod", 10)
		if _array_text_contains_local(went_wrong, "wall") or _array_text_contains_local(plan_mismatches, "wall"):
			_summary_append(misunderstood, "Ari treated flying danger like ground danger.", 8)
	_collect_summary_behavior_evidence(_behavior_evidence_array(BEHAVIOR_EVIDENCE_CAP), behavior_evidence, behavior_patterns, evidence_snapshot_ids, what_changed, went_wrong, candidate_lessons)

	return {
		"schema": "ari.day_summary.v1",
		"summary_id": _day_summary_id(trigger, outcome),
		"trigger": trigger,
		"day": day_night.day,
		"outcome": outcome,
		"source": "deterministic",
		"failure_reason": "",
		"origin": "day_summary",
		"sign": {
			"text": sign_text,
			"interpretation": sign_interpretation,
		},
		"timeline": timeline,
		"what_changed": what_changed,
		"worked": worked,
		"went_wrong": went_wrong,
		"misunderstood": misunderstood,
		"plan_alignment": alignment_counts,
		"plan_mismatches": plan_mismatches,
		"prerequisite_progress": prerequisite_progress,
		"safety_substitutions": safety_substitutions,
		"resource_blockers": resource_blockers,
		"threats": threats,
		"behavior_patterns": behavior_patterns,
		"behavior_evidence": behavior_evidence,
		"candidate_lessons": candidate_lessons,
		"recommended_priority_hints": recommended_priority_hints,
		"current_understanding": current_understanding,
		"evidence_snapshot_ids": evidence_snapshot_ids,
		"evidence_ids": evidence_snapshot_ids,
	}


func _build_rolling_tactical_summary(trigger: String = "") -> Dictionary:
	var snapshots := ari_memory.get_recent_snapshots(8) if ari_memory != null else []
	var notes := _recent_scribe_notes(4)
	var threats: Array[String] = []
	var current_actions: Array[String] = []
	var plan_actions: Array[String] = []
	var plan_mismatches: Array[String] = []
	var resource_blockers: Array[String] = []
	var world_changes: Array[String] = []
	var lesson_candidates: Array[String] = []
	var evidence_snapshot_ids: Array[String] = []
	var moment_notes: Array[String] = []
	var priority_hints := {}
	var risk_level := "none"

	for snapshot in snapshots:
		if typeof(snapshot) != TYPE_DICTIONARY:
			continue
		var snapshot_id := str(snapshot.get("snapshot_id", "")).strip_edges()
		if snapshot_id != "":
			_summary_append(evidence_snapshot_ids, snapshot_id, 8)
		var ari_state = snapshot.get("ari", {})
		if typeof(ari_state) == TYPE_DICTIONARY:
			var action := str(ari_state.get("current_action", ari_state.get("current_job", ""))).strip_edges()
			if action != "":
				_summary_append(current_actions, action, 6)
		var plan_state = snapshot.get("plan", {})
		if typeof(plan_state) == TYPE_DICTIONARY:
			var next_action := str(plan_state.get("next_action", "")).strip_edges()
			if next_action != "":
				_summary_append(plan_actions, next_action, 6)
		var world_state = snapshot.get("world", {})
		if typeof(world_state) != TYPE_DICTIONARY:
			continue
		var nearest = world_state.get("nearest_danger", {})
		if typeof(nearest) == TYPE_DICTIONARY:
			var danger_type := str(nearest.get("type", "")).strip_edges()
			if danger_type != "" and danger_type != "none":
				_summary_append(threats, danger_type, 6)
				risk_level = _max_risk_label(risk_level, _rolling_risk_from_distance(danger_type, float(nearest.get("distance", 0.0))))
		var enemies_state = world_state.get("enemies", {})
		if typeof(enemies_state) == TYPE_DICTIONARY:
			var enemy_types = enemies_state.get("types", {})
			if typeof(enemy_types) == TYPE_DICTIONARY:
				for enemy_type in enemy_types.keys():
					if int(enemy_types[enemy_type]) > 0:
						_summary_append(threats, str(enemy_type), 6)
						if str(enemy_type) == "flying":
							risk_level = _max_risk_label(risk_level, "high")
		for change in _summary_string_array(world_state.get("notable_changes", []), 4, 80):
			_summary_append(world_changes, change, 8)
		if float(world_state.get("recent_damage", 0.0)) > 0.0:
			risk_level = _max_risk_label(risk_level, "high")
		var resources = world_state.get("resources", {})
		if typeof(resources) == TYPE_DICTIONARY and float(resources.get("stone", 99.0)) <= 3.0:
			_summary_append(resource_blockers, "low_stone", 6)

	for note in notes:
		if typeof(note) != TYPE_DICTIONARY:
			continue
		var note_text := str(note.get("note", "")).strip_edges()
		if note_text != "":
			_summary_append(moment_notes, note_text, 4)
		var alignment := str(note.get("plan_alignment", "unknown")).strip_edges()
		if alignment == "mismatch":
			_summary_append(plan_mismatches, note_text if note_text != "" else "Ari's body action did not match the plan.", 6)
		risk_level = _max_risk_label(risk_level, str(note.get("immediate_risk", "none")))
		for danger in note.get("dangers", []):
			if typeof(danger) == TYPE_DICTIONARY:
				var danger_name := str(danger.get("type", "")).strip_edges()
				if danger_name != "" and danger_name != "none":
					_summary_append(threats, danger_name, 6)
		for blocker in _summary_string_array(note.get("resource_blockers", []), 4, 80):
			_summary_append(resource_blockers, blocker, 6)
		for lesson in _summary_string_array(note.get("lesson_candidates", []), 4, 120):
			_summary_append(lesson_candidates, lesson, 6)
		for evidence_id in _summary_string_array(note.get("evidence_ids", note.get("evidence_snapshot_ids", [])), 6, 120):
			_summary_append(evidence_snapshot_ids, evidence_id, 8)
		for mistake in _summary_string_array(note.get("mistake_candidates", []), 4, 120):
			_summary_append(plan_mismatches, mistake, 6)
		for change in _summary_string_array(note.get("world_changes", []), 4, 80):
			_summary_append(world_changes, change, 8)
		var note_hints = note.get("priority_hints", {})
		if typeof(note_hints) == TYPE_DICTIONARY:
			for key in note_hints.keys():
				priority_hints[str(key)] = maxf(float(priority_hints.get(str(key), 0.0)), clampf(float(note_hints[key]), 0.0, 1.0))

	if threats.has("flying"):
		priority_hints["build_storm_rod"] = maxf(float(priority_hints.get("build_storm_rod", 0.0)), 0.65)
		_summary_append(lesson_candidates, "answer flying danger before ordinary wall work", 6)

	return {
		"schema": "ari.rolling_tactical_summary.v1",
		"trigger": trigger,
		"day": day_night.day,
		"phase": day_night.phase,
		"source": "deterministic",
		"failure_reason": "",
		"origin": "rolling_tactical_summary",
		"time_left": day_night.get_time_left(),
		"risk_level": risk_level,
		"threats": threats,
		"current_actions": current_actions,
		"plan_actions": plan_actions,
		"plan_mismatches": plan_mismatches,
		"resource_blockers": resource_blockers,
		"world_changes": world_changes,
		"moment_notes": moment_notes,
		"lesson_candidates": lesson_candidates,
		"priority_hints": priority_hints,
		"evidence_snapshot_ids": evidence_snapshot_ids,
		"evidence_ids": evidence_snapshot_ids,
	}


func _rolling_risk_from_distance(enemy_type: String, distance: float) -> String:
	if enemy_type == "flying":
		return "high"
	if distance <= 32.0:
		return "lethal"
	if distance <= 96.0:
		return "high"
	if distance <= 180.0:
		return "medium"
	return "low"


func _max_risk_label(left: String, right: String) -> String:
	var labels := ["none", "low", "medium", "high", "lethal"]
	var left_index := labels.find(left)
	var right_index := labels.find(right)
	if left_index < 0:
		left_index = 0
	if right_index < 0:
		right_index = 0
	return labels[maxi(left_index, right_index)]


func _build_strategy_packet(trigger: String = "") -> Dictionary:
	var doctrine_context := _doctrine_context()
	var summary := _build_day_summary(trigger if trigger != "" else "strategy", "in_progress")
	var rolling_summary := _build_rolling_tactical_summary(trigger)
	var priority_hints := {}
	for hint in summary.get("recommended_priority_hints", []):
		var hint_id := str(hint).strip_edges()
		if hint_id != "":
			priority_hints[hint_id] = maxf(float(priority_hints.get(hint_id, 0.0)), 0.55)
	for key in rolling_summary.get("priority_hints", {}).keys():
		priority_hints[str(key)] = maxf(float(priority_hints.get(str(key), 0.0)), float(rolling_summary.get("priority_hints", {}).get(key, 0.0)))
	for key in sign_priority_hints.keys():
		priority_hints[str(key)] = maxf(float(priority_hints.get(str(key), 0.0)), float(sign_priority_hints[key]) * 0.5)
	var doctrine_bias := _learned_doctrine_bias(doctrine_context)
	var negative_doctrine_actions: Array[String] = []
	if typeof(doctrine_bias) == TYPE_DICTIONARY:
		for key in doctrine_bias.keys():
			var action_bias := clampf(float(doctrine_bias[key]), -1.0, 1.0)
			if action_bias > 0.0:
				priority_hints[str(key)] = maxf(float(priority_hints.get(str(key), 0.0)), action_bias)
			elif action_bias < 0.0:
				_summary_append(negative_doctrine_actions, "avoid " + str(key), 8)
	var avoid_repeating: Array[String] = []
	for item in summary.get("went_wrong", []):
		_summary_append(avoid_repeating, str(item), 8)
	for item in summary.get("misunderstood", []):
		_summary_append(avoid_repeating, str(item), 8)
	for item in summary.get("plan_mismatches", []):
		_summary_append(avoid_repeating, str(item), 8)
	for item in negative_doctrine_actions:
		_summary_append(avoid_repeating, item, 8)
	var try_next: Array[String] = []
	if priority_hints.has("build_storm_rod") or priority_hints.has("anti_air_defense"):
		_summary_append(try_next, "build_storm_rod", 8)
	if priority_hints.has("use_tower"):
		_summary_append(try_next, "use_tower", 8)
	for lesson in summary.get("candidate_lessons", []):
		_summary_append(try_next, str(lesson), 8)
	var background_notes := _background_ai_notes(4)
	for result in _background_ai_current_results():
		var result_hints = result.get("priority_hints", {})
		if typeof(result_hints) == TYPE_DICTIONARY:
			for key in result_hints.keys():
				priority_hints[str(key)] = maxf(float(priority_hints.get(str(key), 0.0)), absf(float(result_hints[key])))
		var result_strategy = result.get("strategy_packet", {})
		if typeof(result_strategy) == TYPE_DICTIONARY:
			for item in result_strategy.get("try_next", []):
				_summary_append(try_next, str(item), 8)
			for item in result_strategy.get("avoid_repeating", []):
				_summary_append(avoid_repeating, str(item), 8)
	var strategy_evidence_ids: Array[String] = []
	for evidence_id in _summary_string_array(summary.get("evidence_ids", summary.get("evidence_snapshot_ids", [])), 14, 120):
		_summary_append(strategy_evidence_ids, evidence_id, 14)
	for evidence_id in _summary_string_array(rolling_summary.get("evidence_ids", rolling_summary.get("evidence_snapshot_ids", [])), 14, 120):
		_summary_append(strategy_evidence_ids, evidence_id, 14)
	var active_doctrines := _learned_active_doctrines(doctrine_context, NIGHT_REFLECTION_DOCTRINE_CAP)
	for doctrine in active_doctrines:
		if typeof(doctrine) != TYPE_DICTIONARY:
			continue
		for evidence_id in _summary_string_array(doctrine.get("evidence_ids", []), 6, 120):
			_summary_append(strategy_evidence_ids, evidence_id, 14)
	return {
		"schema": "ari.strategy_packet.v1",
		"summary_id": str(summary.get("summary_id", "")),
		"trigger": trigger,
		"day": day_night.day,
		"source": "deterministic",
		"failure_reason": "",
		"origin": "strategy_packet",
		"main_risks": summary.get("threats", []),
		"current_lessons": summary.get("candidate_lessons", []),
		"rolling_summary": rolling_summary,
		"active_doctrines": active_doctrines,
		"priority_hints": priority_hints,
		"avoid_repeating": avoid_repeating,
		"try_next": try_next,
		"behavior_patterns": summary.get("behavior_patterns", []),
		"behavior_evidence": summary.get("behavior_evidence", []),
		"prerequisite_progress": summary.get("prerequisite_progress", []),
		"safety_substitutions": summary.get("safety_substitutions", []),
		"understanding": _compact_ari_understanding(ari_understanding, 4),
		"evidence": _strategy_evidence(summary.get("evidence_snapshot_ids", []), background_notes, 14),
		"evidence_ids": strategy_evidence_ids,
		"confidence": 0.55 if not summary.get("candidate_lessons", []).is_empty() else 0.35,
	}


func _build_agent_plan_strategy_packet(trigger: String = "") -> Dictionary:
	var strategy := _build_strategy_packet(trigger)
	var packet := {
		"schema": "ari.strategy_packet.v1",
		"summary_id": str(strategy.get("summary_id", "")),
		"trigger": trigger,
		"day": day_night.day,
		"source": str(strategy.get("source", "deterministic")),
		"origin": str(strategy.get("origin", "strategy_packet")),
		"main_risks": _summary_string_array(strategy.get("main_risks", []), 5, 60),
		"current_lessons": _summary_string_array(strategy.get("current_lessons", []), 4, 100),
		"priority_hints": _compact_priority_map(strategy.get("priority_hints", {}), 8),
		"avoid_repeating": _summary_string_array(strategy.get("avoid_repeating", []), 4, 100),
		"try_next": _summary_string_array(strategy.get("try_next", []), 5, 80),
		"behavior_evidence": _behavior_evidence_compact_array(strategy.get("behavior_evidence", []), 2),
		"prerequisite_progress": _summary_string_array(strategy.get("prerequisite_progress", []), 3, 100),
		"safety_substitutions": _summary_string_array(strategy.get("safety_substitutions", []), 2, 100),
		"understanding": _compact_ari_understanding(strategy.get("understanding", {}), 3),
		"evidence": _summary_string_array(strategy.get("evidence", []), 4, 80),
		"evidence_ids": _summary_string_array(strategy.get("evidence_ids", []), 4, 80),
		"confidence": clampf(float(strategy.get("confidence", 0.35)), 0.0, 1.0),
	}
	var failure_reason := str(strategy.get("failure_reason", "")).strip_edges()
	if failure_reason != "":
		packet["failure_reason"] = failure_reason
	return packet


func _compact_active_doctrines_for_plan(doctrines: Array, max_count: int) -> Array:
	var result := []
	for doctrine in doctrines:
		if typeof(doctrine) != TYPE_DICTIONARY:
			continue
		var compact := {
			"id": _limit_inline(str(doctrine.get("id", "")), 80),
			"summary": _limit_inline(str(doctrine.get("summary", "")), 140),
			"when": doctrine.get("when", {}) if typeof(doctrine.get("when", {})) == TYPE_DICTIONARY else {},
			"bias": _compact_priority_map(doctrine.get("bias", doctrine.get("priority_bias", {})), 6),
			"plan": _compact_doctrine_plan(doctrine.get("plan", doctrine.get("plan_templates", [])), 3),
			"control": _compact_doctrine_control(doctrine.get("control", {})),
			"confidence": clampf(float(doctrine.get("confidence", 0.0)), 0.0, 1.0),
			"source": _limit_inline(str(doctrine.get("source", "")), 60),
			"origin": _limit_inline(str(doctrine.get("origin", "")), 60),
			"evidence_ids": _summary_string_array(doctrine.get("evidence_ids", []), 4, 80),
		}
		result.append(compact)
		if result.size() >= max_count:
			break
	return result


func _advance_background_ai(delta: float) -> void:
	if ai_bridge == null or not ai_bridge.is_ai_enabled():
		return
	if not ai_bridge.has_method("request_background_job"):
		return
	if _background_ai_request_in_flight or _fast_prediction_request_in_flight:
		return
	_background_ai_elapsed += maxf(delta, 0.0)
	if _background_ai_elapsed < BACKGROUND_AI_INTERVAL:
		return
	_background_ai_elapsed = 0.0
	if ari_memory == null:
		return
	if ari_memory.get_recent_snapshots(1).is_empty() and ari_memory.get_recent_events(1).is_empty():
		return
	_dispatch_background_ai_job(_build_background_ai_job("strategy_candidate", "normal"))


func _advance_fast_prediction(delta: float) -> void:
	if ai_bridge == null or not ai_bridge.is_ai_enabled():
		return
	if not ai_bridge.has_method("request_fast_prediction"):
		return
	if _fast_prediction_request_in_flight:
		return
	if _should_hold_fast_prediction_for_due_agent_plan():
		return
	_fast_prediction_elapsed += maxf(delta, 0.0)
	if _fast_prediction_elapsed < FAST_PREDICTION_INTERVAL:
		return
	_fast_prediction_elapsed = 0.0
	if sign_text.strip_edges() == "" and enemies.is_empty():
		return
	_fast_prediction_request_in_flight = true
	_fast_prediction_request_id += 1
	var request_id := _fast_prediction_request_id
	var payload := _build_fast_prediction_payload()
	ai_bridge.call("request_fast_prediction", payload, func(result: Dictionary) -> void:
		if request_id != _fast_prediction_request_id:
			return
		_fast_prediction_request_in_flight = false
		_on_fast_prediction_response(result)
	)


func _should_hold_fast_prediction_for_due_agent_plan() -> bool:
	if _agent_plan_request_in_flight:
		return false
	if _agent_plan_pending_trigger.strip_edges() == "":
		return false
	return _agent_plan_pending_at <= _agent_plan_clock + FAST_PREDICTION_AGENT_PLAN_HOLD_WINDOW


func _build_fast_prediction_payload() -> Dictionary:
	_refresh_ari_understanding("fast_prediction")
	var nearest := _observer_nearest_danger()
	var risks := _prediction_risks(nearest)
	var rolling_summary := _build_rolling_tactical_summary("fast_prediction")
	var strategy_packet := _build_prediction_strategy_packet(rolling_summary)
	return {
		"schema": "ari.prediction.request.v1",
		"context_hash": _background_context_hash(),
		"day": day_night.day,
		"phase": day_night.phase,
		"time_left": day_night.get_time_left(),
		"ari": {
			"hp": float(ari.get("hp")) if ari != null else 0.0,
			"max_hp": float(ari.get("max_hp")) if ari != null else 0.0,
			"fear": float(ari.get("fear")) if ari != null else 0.0,
			"hunger": float(ari.get("hunger")) if ari != null else 0.0,
			"stamina": float(ari.get("stamina")) if ari != null else 0.0,
			"current_action": str(ari.call("get_current_job")) if ari != null else "wait_or_idle",
			"current_reason": str(ari.call("get_job_reason")) if ari != null else "",
		},
		"risks": risks,
		"resources": {
			"food": _food_count(),
			"stone": _stone_count(),
			"ore": _ore_count(),
		},
		"structures": {
			"walls": walls.size(),
			"towers": bow_towers.size(),
			"storm_rods": storm_rods.size(),
			"damaged": _get_damaged_structure_count(),
		},
		"current_plan": _agent_current_plan_prediction_payload(),
		"rolling_summary": _build_prediction_rolling_summary(rolling_summary),
		"strategy_packet": strategy_packet,
		"legal_actions": _current_agent_legal_actions_prediction_compact(12),
		"action_control_panel": _build_prediction_action_control_panel(7),
		"max_words": 28,
	}


func _build_prediction_rolling_summary(rolling_summary: Dictionary) -> Dictionary:
	return {
		"schema": "ari.rolling_tactical_summary.v1",
		"risk_level": str(rolling_summary.get("risk_level", "none")),
		"threats": _summary_string_array(rolling_summary.get("threats", []), 4, 40),
		"plan_mismatches": _summary_string_array(rolling_summary.get("plan_mismatches", []), 2, 90),
		"resource_blockers": _summary_string_array(rolling_summary.get("resource_blockers", []), 3, 60),
		"world_changes": _summary_string_array(rolling_summary.get("world_changes", []), 3, 60),
		"lesson_candidates": _summary_string_array(rolling_summary.get("lesson_candidates", []), 2, 90),
		"priority_hints": _compact_priority_map(rolling_summary.get("priority_hints", {}), 5),
	}


func _build_prediction_strategy_packet(rolling_summary: Dictionary) -> Dictionary:
	var strategy := _build_strategy_packet("fast_prediction")
	var priority_hints := _compact_priority_map(strategy.get("priority_hints", {}), 6)
	for key in rolling_summary.get("priority_hints", {}).keys():
		var hint_id := str(key)
		if hint_id == "":
			continue
		priority_hints[hint_id] = maxf(float(priority_hints.get(hint_id, 0.0)), clampf(float(rolling_summary.get("priority_hints", {}).get(key, 0.0)), 0.0, 1.0))
	var packet := {
		"schema": "ari.strategy_packet.v1",
		"main_risks": _summary_string_array(strategy.get("main_risks", rolling_summary.get("threats", [])), 4, 50),
		"current_lessons": _summary_string_array(strategy.get("current_lessons", rolling_summary.get("lesson_candidates", [])), 1, 70),
		"priority_hints": _compact_priority_map(priority_hints, 6),
		"understanding": _compact_ari_understanding_for_prediction(strategy.get("understanding", {})),
	}
	var prerequisite_progress := _summary_string_array(strategy.get("prerequisite_progress", []), 2, 90)
	if not prerequisite_progress.is_empty():
		packet["prerequisite_progress"] = prerequisite_progress
	var safety_substitutions := _summary_string_array(strategy.get("safety_substitutions", []), 1, 90)
	if not safety_substitutions.is_empty():
		packet["safety_substitutions"] = safety_substitutions
	var failure_reason := str(strategy.get("failure_reason", "")).strip_edges()
	if failure_reason != "":
		packet["failure_reason"] = failure_reason
	return packet


func _agent_current_plan_prediction_payload() -> Dictionary:
	if agent_plan.is_empty():
		return {}
	return {
		"current_action": _current_agent_step_action_id(),
		"next_action": _action_choice_id(agent_plan.get("next_action", {})),
		"age_seconds": maxf(_agent_plan_clock - float(agent_plan.get("created_at_seconds", _agent_plan_clock)), 0.0),
		"failures": _limit_agent_records(agent_plan.get("failures", []), 1),
		"outcomes": _limit_agent_records(agent_plan.get("outcomes", []), 1),
		"source": str(agent_plan.get("source", "")),
	}


func _current_agent_legal_actions_prediction_compact(max_count: int) -> Array:
	var result := []
	for action in _current_agent_legal_actions():
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var action_id := str(action.get("id", "")).strip_edges()
		if action_id == "":
			continue
		var compact := {
			"id": _limit_inline(action_id, 80),
			"available": bool(action.get("available", true)),
		}
		var reason := str(action.get("reason_unavailable", "")).strip_edges()
		if reason != "":
			compact["reason_unavailable"] = _limit_inline(reason, 80)
		result.append(compact)
		if result.size() >= max_count:
			break
	return result


func _build_prediction_action_control_panel(max_actions: int) -> Dictionary:
	var panel := _build_action_control_panel(max_actions)
	var compact_actions := []
	for raw in panel.get("actions", []):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var entry := {
			"id": _limit_inline(str(raw.get("id", "")), 80),
			"available": bool(raw.get("available", true)),
			"category": _limit_inline(str(raw.get("category", "")), 32),
			"description": _limit_inline(str(raw.get("description", "")), 70),
		}
		var counters := _summary_string_array(raw.get("counters", []), 3, 32)
		if not counters.is_empty():
			entry["counters"] = counters
		var enables := _summary_string_array(raw.get("enables", []), 2, 32)
		if not enables.is_empty():
			entry["enables"] = enables
		var preconditions := _summary_string_array(raw.get("preconditions", []), 3, 36)
		if not preconditions.is_empty():
			entry["preconditions"] = preconditions
		var good_when := _summary_string_array(raw.get("good_when", []), 3, 36)
		if not good_when.is_empty():
			entry["good_when"] = good_when
		var failure_modes := _summary_string_array(raw.get("failure_modes", []), 2, 42)
		if not failure_modes.is_empty():
			entry["failure_modes"] = failure_modes
		var cost = raw.get("cost", {})
		if typeof(cost) == TYPE_DICTIONARY and not cost.is_empty():
			entry["cost"] = cost
		var reason := str(raw.get("reason_unavailable", "")).strip_edges()
		if reason != "":
			entry["reason_unavailable"] = _limit_inline(reason, 50)
		compact_actions.append(entry)
	return {
		"schema": "ari.action_control_panel.v1",
		"actions": compact_actions,
	}


func _prediction_risks(nearest: Dictionary) -> Array:
	var risks := []
	var nearest_type := str(nearest.get("type", "none")).strip_edges()
	if nearest_type != "" and nearest_type != "none":
		var distance := float(nearest.get("distance", 0.0))
		risks.append({
			"type": nearest_type,
			"distance": distance,
			"severity": _prediction_severity(nearest_type, distance),
		})
	var enemy_counts := _get_enemy_type_counts()
	for enemy_type in enemy_counts.keys():
		if int(enemy_counts[enemy_type]) <= 0:
			continue
		if _prediction_risk_has_type(risks, str(enemy_type)):
			continue
		risks.append({
			"type": str(enemy_type),
			"distance": -1.0,
			"severity": 0.9 if str(enemy_type) == "flying" else 0.55,
		})
	return risks


func _prediction_severity(enemy_type: String, distance: float) -> float:
	if enemy_type == "flying":
		return 0.95
	if distance <= 32.0:
		return 0.95
	if distance <= 96.0:
		return 0.75
	if distance <= 180.0:
		return 0.55
	return 0.3


func _prediction_risk_has_type(risks: Array, enemy_type: String) -> bool:
	for risk in risks:
		if typeof(risk) == TYPE_DICTIONARY and str(risk.get("type", "")) == enemy_type:
			return true
	return false


func _on_fast_prediction_response(result: Dictionary) -> void:
	if typeof(result) != TYPE_DICTIONARY:
		return
	if str(result.get("schema", "")) != "ari.prediction.v1":
		return
	if str(result.get("context_hash", "")) != _background_context_hash():
		return
	if str(result.get("failure_reason", "")).strip_edges() != "":
		return
	if str(result.get("source", "")).strip_edges() == "local_fallback":
		return
	var action_bias = result.get("next_action_bias", {})
	var action_id := ""
	if typeof(action_bias) == TYPE_DICTIONARY:
		action_id = str(action_bias.get("action_id", "")).strip_edges()
	var priority_hints = result.get("priority_hints", {})
	var strategy_hints: Dictionary = {}
	if typeof(priority_hints) == TYPE_DICTIONARY:
		strategy_hints = priority_hints.duplicate(true)
	if action_id != "":
		strategy_hints[action_id] = maxf(float(strategy_hints.get(action_id, 0.0)), float(action_bias.get("urgency", 0.5)) if typeof(action_bias) == TYPE_DICTIONARY else 0.5)
	var prediction_text := _limit_inline(str(result.get("prediction", "")), 180)
	var background_result := {
		"schema": "ari.background_result.v1",
		"job_id": "prediction_%d_%04d" % [day_night.day, int(round(_agent_plan_clock * 10.0))],
		"kind": "fast_prediction",
		"context_hash": str(result.get("context_hash", "")),
		"status": "fallback" if str(result.get("failure_reason", "")) != "" else "ok",
		"notes": [prediction_text] if prediction_text != "" else [],
		"priority_hints": strategy_hints,
		"strategy_packet": {
			"schema": "ari.strategy_packet.v1",
			"day": day_night.day,
			"main_risks": [str(result.get("risk_level", ""))],
			"current_lessons": [],
			"active_doctrines": [],
			"priority_hints": strategy_hints,
			"avoid_repeating": result.get("avoid", []),
			"try_next": [action_id] if action_id != "" else [],
			"evidence": [prediction_text] if prediction_text != "" else [],
			"confidence": clampf(float(result.get("confidence", 0.35)), 0.0, 1.0),
		},
		"confidence": clampf(float(result.get("confidence", 0.35)), 0.0, 1.0),
		"source": str(result.get("source", "")),
		"failure_reason": str(result.get("failure_reason", "")),
	}
	_on_background_ai_result(background_result)


func _build_background_ai_job(kind: String, priority: String = "normal") -> Dictionary:
	var safe_kind := kind.strip_edges()
	if not ["scribe_enrich", "summary_review", "reflection_draft", "strategy_candidate", "doctrine_review", "playtest_analysis"].has(safe_kind):
		safe_kind = "strategy_candidate"
	var safe_priority := priority.strip_edges()
	if not ["low", "normal", "high"].has(safe_priority):
		safe_priority = "normal"
	var context_hash := _background_context_hash()
	var job_id := "day%d_%04d_%s" % [day_night.day, int(round(_agent_plan_clock * 10.0)), safe_kind]
	return {
		"schema": "ari.background_job.v1",
		"job_id": job_id,
		"kind": safe_kind,
		"priority": safe_priority,
		"context_hash": context_hash,
		"expires_at_game_time": _agent_plan_clock + 45.0,
		"current_game_time": _agent_plan_clock,
		"payload": {
			"rolling_summary": _build_rolling_tactical_summary(safe_kind),
			"day_summary": _build_day_summary(safe_kind, "in_progress"),
			"strategy_packet": _build_strategy_packet(safe_kind),
			"recent_scribe_notes": _recent_scribe_notes(4),
			"active_plan": _agent_current_plan_payload(),
			"current_sign": sign_text,
		},
	}


func _dispatch_background_ai_job(job: Dictionary) -> void:
	if ai_bridge == null or not ai_bridge.has_method("request_background_job"):
		return
	_background_ai_request_in_flight = true
	_background_ai_request_id += 1
	_background_ai_active_context_hash = str(job.get("context_hash", ""))
	var request_id := _background_ai_request_id
	ai_bridge.call("request_background_job", job, func(result: Dictionary) -> void:
		if request_id != _background_ai_request_id:
			return
		_background_ai_request_in_flight = false
		_on_background_ai_result(result)
	)


func _on_background_ai_result(result: Dictionary) -> void:
	if typeof(result) != TYPE_DICTIONARY:
		return
	if str(result.get("schema", "")) != "ari.background_result.v1":
		return
	if str(result.get("status", "")) == "stale":
		return
	var context_hash := str(result.get("context_hash", ""))
	if context_hash == "" or context_hash != _background_context_hash():
		return
	_background_ai_results.append(result.duplicate(true))
	while _background_ai_results.size() > BACKGROUND_AI_RESULT_CAP:
		_background_ai_results.pop_front()


func _background_context_hash() -> String:
	var current_plan := _agent_current_plan_payload()
	var next_action := ""
	var raw_next_action = current_plan.get("next_action", "")
	if typeof(raw_next_action) == TYPE_DICTIONARY:
		next_action = str(raw_next_action.get("action_id", raw_next_action.get("id", "")))
	else:
		next_action = str(raw_next_action)
	var run_context := _get_run_build_context()
	var data := {
		"sign": sign_text,
		"day": day_night.day,
		"phase": day_night.phase,
		"enemy_types": _get_enemy_type_counts(),
		"known_enemy_types": _known_enemy_types(),
		"next_action": next_action,
		"run_build": {
			"preset_id": str(run_context.get("preset_id", "")),
			"tags": run_context.get("tags", []),
			"top_categories": run_context.get("top_categories", []),
		},
		"latest_lesson": latest_lesson_title,
	}
	var value := int(hash(JSON.stringify(data)))
	if value < 0:
		value = -value
	return str(value)


func _background_ai_current_results() -> Array:
	var context_hash := _background_context_hash()
	var results := []
	for item in _background_ai_results:
		if typeof(item) == TYPE_DICTIONARY and str(item.get("context_hash", "")) == context_hash:
			results.append(item)
	return results


func _background_ai_notes(max_count: int) -> Array[String]:
	var notes: Array[String] = []
	for result in _background_ai_current_results():
		for note in result.get("notes", []):
			_summary_append(notes, str(note), max_count)
			if notes.size() >= max_count:
				return notes
	return notes


func _strategy_evidence(snapshot_ids, background_notes: Array[String], max_count: int) -> Array[String]:
	var evidence: Array[String] = []
	for item in _summary_string_array(snapshot_ids, max_count, 120):
		_summary_append(evidence, item, max_count)
	for note in background_notes:
		_summary_append(evidence, note, max_count)
	return evidence


func _summary_append(target: Array, value: String, max_count: int) -> void:
	var text := _limit_inline(value, 180)
	if text == "" or target.has(text):
		return
	if target.size() >= max_count:
		return
	target.append(text)


func _day_summary_log_line(summary: Dictionary) -> String:
	return "DAY_SUMMARY " + JSON.stringify({
		"schema": str(summary.get("schema", "ari.day_summary.v1")),
		"summary_id": str(summary.get("summary_id", "")),
		"trigger": str(summary.get("trigger", "")),
		"day": int(summary.get("day", 0)),
		"outcome": str(summary.get("outcome", "")),
		"source": str(summary.get("source", "")),
		"origin": str(summary.get("origin", "")),
		"candidate_lessons": _summary_string_array(summary.get("candidate_lessons", []), 8, 140),
		"evidence_snapshot_ids": _summary_string_array(summary.get("evidence_snapshot_ids", summary.get("evidence_ids", [])), 12, 120),
		"threats": _summary_string_array(summary.get("threats", []), 8, 80),
		"plan_mismatches": _summary_string_array(summary.get("plan_mismatches", []), 6, 140),
		"resource_blockers": _summary_string_array(summary.get("resource_blockers", []), 6, 80),
	})


func _log_day_summary(summary: Dictionary) -> void:
	if not _should_log_day_summary():
		return
	var summary_id := str(summary.get("summary_id", "")).strip_edges()
	if summary_id != "":
		if bool(_logged_day_summary_ids.get(summary_id, false)):
			return
		_logged_day_summary_ids[summary_id] = true
	print(_day_summary_log_line(summary))


func _should_log_day_summary() -> bool:
	return OS.get_environment("ARI_DAY_SUMMARY_LOG").strip_edges() == "1" \
		or OS.get_environment("ARI_PLAN_LOG").strip_edges() == "1"


func _summary_string_array(value, max_count: int, max_length: int) -> Array[String]:
	var result: Array[String] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		var text := _limit_inline(str(item), max_length)
		if text != "" and not result.has(text):
			result.append(text)
		if result.size() >= max_count:
			break
	return result


func _array_text_contains_local(items: Array, fragment: String) -> bool:
	var needle := fragment.to_lower()
	for item in items:
		if str(item).to_lower().contains(needle):
			return true
	return false


func _apply_night_reflection_note(note: Dictionary, trigger: String) -> Dictionary:
	var normalized := note.duplicate(true)
	normalized["created_day"] = int(normalized.get("created_day", day_night.day))
	var summary := _build_day_summary(trigger, "in_progress")
	if str(normalized.get("summary_id", "")).strip_edges() == "":
		normalized["summary_id"] = str(summary.get("summary_id", ""))
	if str(normalized.get("reflection_id", "")).strip_edges() == "":
		normalized["reflection_id"] = _reflection_id(trigger)
	if str(normalized.get("note_id", "")).strip_edges() == "":
		normalized["note_id"] = str(normalized.get("reflection_id", ""))
	if str(normalized.get("source", "")).strip_edges() == "":
		normalized["source"] = "local_fallback"
	if not normalized.has("failure_reason"):
		normalized["failure_reason"] = ""
	if str(normalized.get("origin", "")).strip_edges() == "":
		normalized["origin"] = "night_reflection"
	var evidence_ids := _summary_string_array(normalized.get("evidence_ids", normalized.get("evidence_snapshot_ids", [])), 20, 120)
	for evidence_id in _summary_string_array(summary.get("evidence_ids", summary.get("evidence_snapshot_ids", [])), 20, 120):
		_summary_append(evidence_ids, evidence_id, 20)
	normalized["evidence_ids"] = evidence_ids
	if not normalized.has("markdown_text"):
		normalized["markdown_text"] = str(normalized.get("markdown", ""))
	if not normalized.has("priority_hints") and normalized.has("priority_bias"):
		normalized["priority_hints"] = normalized.get("priority_bias", {})
	normalized["doctrines"] = _doctrines_with_reflection_provenance(normalized.get("doctrines", []), normalized)
	var safe_note := ari_memory.add_lifetime_note(normalized)
	_store_night_reflection_note(safe_note, trigger)
	return safe_note


func _reflection_id(trigger: String) -> String:
	var clean_trigger := trigger.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	if clean_trigger == "":
		clean_trigger = "reflection"
	var next_index := ari_memory.get_lifetime_notes(AriMemory.MAX_NOTES).size() + 1 if ari_memory != null else 1
	return "day%d_%s_reflection_%04d" % [day_night.day, clean_trigger, next_index]


func _doctrines_with_reflection_provenance(raw_doctrines, note: Dictionary) -> Array:
	var result := []
	if typeof(raw_doctrines) != TYPE_ARRAY:
		return result
	for raw_doctrine in raw_doctrines:
		if typeof(raw_doctrine) != TYPE_DICTIONARY:
			continue
		var doctrine: Dictionary = raw_doctrine.duplicate(true)
		for key in ["source", "failure_reason", "origin", "reflection_id", "summary_id"]:
			if str(doctrine.get(key, "")).strip_edges() == "":
				doctrine[key] = note.get(key, "")
		var evidence_ids := _summary_string_array(doctrine.get("evidence_ids", doctrine.get("evidence_snapshot_ids", [])), 20, 120)
		for evidence_id in _summary_string_array(note.get("evidence_ids", []), 20, 120):
			_summary_append(evidence_ids, evidence_id, 20)
		doctrine["evidence_ids"] = evidence_ids
		result.append(doctrine)
	return result


func _handle_night_reflection_response(note: Dictionary, trigger: String) -> Dictionary:
	if _is_usable_night_reflection_response(note):
		return _apply_night_reflection_note(note, trigger)
	return _apply_night_reflection_fallback(trigger)


func _is_usable_night_reflection_response(note: Dictionary) -> bool:
	if note.is_empty():
		return false
	if str(note.get("schema", "")) != "ari.night_reflection.v1":
		return false
	if str(note.get("title", "")).strip_edges() != "":
		return true
	if str(note.get("markdown", note.get("markdown_text", ""))).strip_edges() != "":
		return true
	var doctrines = note.get("doctrines", [])
	if typeof(doctrines) == TYPE_ARRAY and not doctrines.is_empty():
		return true
	var hints = note.get("priority_hints", note.get("priority_bias", {}))
	return typeof(hints) == TYPE_DICTIONARY and not hints.is_empty()


func _apply_night_reflection_fallback(trigger: String) -> Dictionary:
	var note := {}
	if ari_memory.has_method("create_lifetime_note_from_recent_events"):
		note = ari_memory.call("create_lifetime_note_from_recent_events", day_night.day)
	if note.is_empty():
		var fallback_markdown := "# Ari's rough local reflection\n\nI remember fragments of what happened. Preparation before night improves survival."
		note = ari_memory.add_lifetime_note({
			"title": "Day %d - Ari's rough local reflection" % day_night.day,
			"markdown": fallback_markdown,
			"markdown_text": fallback_markdown,
			"hypothesis": "Preparation before night improves survival.",
			"priority_hints": {"build_wall": 0.08, "place_aura_orb": 0.08},
			"priority_bias": {"build_wall": 0.08, "place_aura_orb": 0.08},
			"confidence": 0.25,
			"thought": "I wrote down what I could remember.",
			"created_day": day_night.day,
		})
	_store_night_reflection_note(note, trigger)
	return note


func _store_night_reflection_note(note: Dictionary, trigger: String) -> void:
	if note.is_empty():
		return
	if str(note.get("reflection_id", "")).strip_edges() == "":
		note["reflection_id"] = _reflection_id(trigger)
	if str(note.get("note_id", "")).strip_edges() == "":
		note["note_id"] = str(note.get("reflection_id", ""))
	if str(note.get("summary_id", "")).strip_edges() == "":
		note["summary_id"] = _day_summary_id(trigger, "in_progress")
	if str(note.get("source", "")).strip_edges() == "":
		note["source"] = "local_fallback"
	if not note.has("failure_reason"):
		note["failure_reason"] = ""
	if str(note.get("origin", "")).strip_edges() == "":
		note["origin"] = "night_reflection"
	note["evidence_ids"] = _summary_string_array(note.get("evidence_ids", note.get("evidence_snapshot_ids", [])), 20, 120)
	note["doctrines"] = _doctrines_with_reflection_provenance(note.get("doctrines", []), note)
	var title := str(note.get("title", "Ari's rough local reflection"))
	lesson_book.add_note(note)
	var added_doctrines := ari_doctrine.add_doctrines(note.get("doctrines", []))
	var added_doctrine_ids: Array[String] = []
	for doctrine in added_doctrines:
		if typeof(doctrine) == TYPE_DICTIONARY:
			var doctrine_id := str(doctrine.get("id", "")).strip_edges()
			if doctrine_id != "" and not added_doctrine_ids.has(doctrine_id):
				added_doctrine_ids.append(doctrine_id)
	latest_lesson_title = title
	ari_memory.record_event("night_reflection_created", {
		"title": title,
		"trigger": trigger,
		"day": day_night.day,
		"phase": day_night.phase,
		"source": str(note.get("source", "")),
		"failure_reason": str(note.get("failure_reason", "")),
		"origin": str(note.get("origin", "")),
		"reflection_id": str(note.get("reflection_id", "")),
		"summary_id": str(note.get("summary_id", "")),
		"evidence_ids": note.get("evidence_ids", []),
		"doctrine_ids": added_doctrine_ids,
	})
	var thought := str(note.get("thought", "")).strip_edges()
	if thought == "":
		thought = "I wrote it down. Maybe I will believe it when I sleep."
	_show_ari_thought(thought, true)
	_set_status_message("Reflection note: %s" % title, 2.4)
	_emit_state()
	if _night_reflection_should_request_agent_plan(note, trigger, added_doctrines):
		_request_agent_plan("library_note_created" if trigger == "library_reflection" else "night_reflection")


func _night_reflection_should_request_agent_plan(note: Dictionary, trigger: String, added_doctrines: Array) -> bool:
	if trigger == "library_reflection":
		return true
	if not added_doctrines.is_empty():
		return true
	var raw_doctrines = note.get("doctrines", [])
	if typeof(raw_doctrines) == TYPE_ARRAY and not raw_doctrines.is_empty():
		return false
	var hints = note.get("priority_hints", note.get("priority_bias", {}))
	if typeof(hints) != TYPE_DICTIONARY:
		return false
	for key in hints.keys():
		if absf(float(hints[key])) >= 0.5:
			return true
	return false


func _reflection_snapshot_selection(max_count: int) -> Array:
	var source := ari_memory.get_recent_snapshots(AriMemory.MAX_SNAPSHOTS)
	var selected := []
	var seen := {}
	for snapshot in source:
		if typeof(snapshot) != TYPE_DICTIONARY:
			continue
		if float(snapshot.get("salience", 0.0)) < 0.65:
			continue
		_observer_append_snapshot(selected, seen, snapshot, max_count)
	for i in range(source.size() - 1, -1, -1):
		if selected.size() >= max_count:
			break
		var snapshot = source[i]
		if typeof(snapshot) == TYPE_DICTIONARY:
			_observer_append_snapshot(selected, seen, snapshot, max_count)
	selected.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("snapshot_id", "")) < str(b.get("snapshot_id", ""))
	)
	return selected


func _observer_append_snapshot(selected: Array, seen: Dictionary, snapshot: Dictionary, max_count: int) -> void:
	if selected.size() >= max_count:
		return
	var snapshot_id := str(snapshot.get("snapshot_id", snapshot.get("timestamp", "")))
	if seen.has(snapshot_id):
		return
	seen[snapshot_id] = true
	selected.append(snapshot.duplicate(true))


func _recent_scribe_notes(max_count: int) -> Array:
	if chronicle == null:
		return []
	var notes: Array = chronicle.get_today_scribe_notes()
	var start = maxi(notes.size() - max_count, 0)
	var result := []
	for i in range(start, notes.size()):
		var note = notes[i]
		result.append(note.duplicate(true) if typeof(note) == TYPE_DICTIONARY else note)
	return result


func _observer_nearest_danger() -> Dictionary:
	var result := {"type": "none", "distance": -1.0}
	if ari == null:
		return result
	var closest_distance := INF
	var closest_type := "none"
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance := ari.global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_type = str(enemy.get("enemy_type"))
	if closest_distance < INF:
		result["type"] = closest_type
		result["distance"] = closest_distance
	return result


func _observer_run_build_summary() -> Dictionary:
	var context := _get_run_build_context()
	var levels := []
	var top_categories = context.get("top_categories", [])
	if typeof(top_categories) == TYPE_ARRAY:
		for item in top_categories:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			levels.append("%s_%d" % [str(item.get("id", "instinct")), int(item.get("value", 0))])
	var tools := []
	var tags = context.get("tags", [])
	if typeof(tags) == TYPE_ARRAY:
		for tag in tags:
			tools.append(str(tag))
	return {
		"preset_id": str(context.get("preset_id", "")),
		"preset_name": str(context.get("preset_name", "")),
		"levels": levels,
		"tools": tools,
	}


func _observer_recent_outcome_labels(max_count: int) -> Array:
	var labels := []
	for outcome in _agent_recent_outcomes(max_count):
		if typeof(outcome) != TYPE_DICTIONARY:
			continue
		var action_id := str(outcome.get("action_id", "action"))
		var result := str(outcome.get("outcome", "outcome"))
		labels.append("%s:%s" % [action_id, result])
	return labels


func _observer_string_array(value, max_count: int) -> Array:
	var result := []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		var text := str(item).strip_edges()
		if text != "" and not result.has(text):
			result.append(text)
		if result.size() >= max_count:
			break
	return result


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

	var mind_context := _get_ari_mind_context()
	var decision: Dictionary = ari_mind.call("choose_daytime_job", mind_context)
	_latest_body_alignment = _build_body_alignment_trace(decision, mind_context)
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
				_record_observer_snapshot("action_completed", 0.4, ["food_harvested"])
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
		"lure_to_tar_pit":
			_advance_ari_tar_lure_job(delta, reason)
		"use_fear_lantern":
			_advance_ari_fear_lantern_job(delta, reason)
		"use_decoy_idol":
			_advance_ari_decoy_job(delta, reason)
		"use_thorns":
			_advance_ari_thorn_job(delta, reason)
		"flee":
			_advance_ari_flee_job(delta, reason)
		_:
			var wait_position := _get_defense_wait_position()
			_set_ari_intent(wait_position, "Wait")
			ari.call("wait_near", delta, wait_position, reason)


func _advance_ari_night_tactic(delta: float) -> void:
	var tactic_context := _get_night_tactic_context()
	var decision: Dictionary = ari_mind.call("choose_night_tactic", tactic_context)
	_latest_body_alignment = _build_body_alignment_trace(decision, tactic_context)
	var job := str(decision.get("job", "wait_or_idle"))
	var reason := str(decision.get("reason", "Night has started"))
	if enemies.is_empty() and job == "wait_or_idle":
		_clear_ari_intent()
		ari.call("stop_daytime_job", reason)
		return
	match job:
		"use_tower":
			_advance_ari_tower_job(delta, reason)
		"use_cover":
			_advance_ari_cover_job(delta, reason)
		"lure_to_aura":
			_advance_ari_aura_lure_job(delta, reason)
		"lure_to_tar_pit":
			_advance_ari_tar_lure_job(delta, reason)
		"use_fear_lantern":
			_advance_ari_fear_lantern_job(delta, reason)
		"use_decoy_idol":
			_advance_ari_decoy_job(delta, reason)
		"use_thorns":
			_advance_ari_thorn_job(delta, reason)
		"fight_head_on":
			_advance_ari_melee_job(delta, reason)
		"stall_until_dawn", "hide_until_dawn":
			_advance_ari_stall_job(delta, job, reason)
		"eat_food":
			_advance_ari_eat_job(reason)
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
			_record_observer_snapshot("action_completed", 0.45, ["ore_mined"])


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
	_record_observer_snapshot("action_completed", 0.6, ["sword_smithed"])
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
		_record_observer_snapshot("action_completed", 0.45, ["structure_repaired"])


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


func _advance_ari_tar_lure_job(delta: float, reason: String) -> void:
	var lure := _find_tar_lure_position()
	if not bool(lure.get("valid", false)):
		_advance_ari_flee_job(delta, "The slow ground is gone; find another answer")
		return
	var target_position: Vector2 = lure["position"]
	if day_night.is_night() and _is_position_too_dangerous(target_position):
		_advance_ari_flee_job(delta, "Enemies are too close; move")
		return
	_set_ari_intent(target_position, "Mud")
	ari.call("advance_move_job", delta, "lure_to_tar_pit", reason, target_position, "luring through tar pit")


func _advance_ari_fear_lantern_job(delta: float, reason: String) -> void:
	var hold := _find_fear_lantern_position()
	if not bool(hold.get("valid", false)):
		_advance_ari_flee_job(delta, "The warm light is gone; find another answer")
		return
	var target_position: Vector2 = hold["position"]
	if day_night.is_night() and _is_position_too_dangerous(target_position):
		_advance_ari_flee_job(delta, "Enemies are too close; move")
		return
	_set_ari_intent(target_position, "Lantern")
	ari.call("advance_move_job", delta, "use_fear_lantern", reason, target_position, "holding fear lantern light")


func _advance_ari_decoy_job(delta: float, reason: String) -> void:
	var hold := _find_decoy_position()
	if not bool(hold.get("valid", false)):
		_advance_ari_flee_job(delta, "The decoy is gone; find another answer")
		return
	var target_position: Vector2 = hold["position"]
	if day_night.is_night() and _is_position_too_dangerous(target_position):
		_advance_ari_flee_job(delta, "Enemies are too close; move")
		return
	_set_ari_intent(target_position, "Decoy")
	ari.call("advance_move_job", delta, "use_decoy_idol", reason, target_position, "using decoy idol")


func _advance_ari_thorn_job(delta: float, reason: String) -> void:
	var hold := _find_thorn_position()
	if not bool(hold.get("valid", false)):
		_advance_ari_flee_job(delta, "The thorn ground is gone; find another answer")
		return
	var target_position: Vector2 = hold["position"]
	if day_night.is_night() and _is_position_too_dangerous(target_position, 32.0):
		_advance_ari_flee_job(delta, "Enemies are too close; move")
		return
	_set_ari_intent(target_position, "Thorns")
	ari.call("advance_move_job", delta, "use_thorns", reason, target_position, "holding thorn ground")


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
	_record_observer_snapshot("action_completed", 0.45, ["ari_melee_hit"])


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
	_record_observer_snapshot("action_completed", 0.5, ["ari_ranged_hit", "tower_ranged_success"])


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
		"agent_grounded_plan": _active_agent_grounded_plan(),
		"understanding": _compact_ari_understanding(ari_understanding, 3),
		"body_alignment": _compact_body_alignment(_latest_body_alignment),
		"run_build": _get_run_build_context(),
		"current_job": str(ari.call("get_current_job")) if ari != null else "wait_or_idle",
	}


func _get_night_tactic_context() -> Dictionary:
	var context := _get_ari_mind_context()
	var cover := _find_cover_position()
	var lure := _find_aura_lure_position()
	var tar_lure := _find_tar_lure_position()
	var lantern_hold := _find_fear_lantern_position()
	var decoy_hold := _find_decoy_position()
	var thorn_hold := _find_thorn_position()
	var tower := _nearest_valid_structure(bow_towers)
	context["enemy_count"] = enemies.size()
	context["nearest_enemy_distance"] = _nearest_enemy_distance_from(ari.global_position if ari != null else _get_defense_anchor())
	context["ari_hp_ratio"] = _get_ari_hp_ratio()
	context["has_valid_cover"] = bool(cover.get("valid", false))
	context["has_valid_aura"] = bool(lure.get("valid", false))
	context["has_valid_tar_pit"] = bool(tar_lure.get("valid", false))
	context["has_valid_fear_lantern"] = bool(lantern_hold.get("valid", false))
	context["has_valid_decoy_idol"] = bool(decoy_hold.get("valid", false))
	context["decoy_idol_hp_ratio"] = 1.0
	if bool(decoy_hold.get("valid", false)) and decoy_hold.has("structure"):
		var decoy_structure = decoy_hold["structure"]
		if is_instance_valid(decoy_structure) and decoy_structure.has_method("get_hp_ratio"):
			context["decoy_idol_hp_ratio"] = float(decoy_structure.call("get_hp_ratio"))
	context["has_valid_thorn_totem"] = bool(thorn_hold.get("valid", false))
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
	var result := {}
	if ari_memory != null and ari_memory.has_method("get_note_priority_bias"):
		var memory_bias = ari_memory.call("get_note_priority_bias")
		_merge_signed_bias(result, memory_bias)
	var latest_note := lesson_book.get_latest_note()
	if not latest_note.is_empty():
		_merge_signed_bias(result, latest_note.get("priority_bias", {}))
	_merge_signed_bias(result, _learned_doctrine_bias(_doctrine_context()))
	return result


func _active_agent_grounded_plan() -> Array:
	var combined := []
	for source in [agent_grounded_plan, _learned_doctrine_plan(_doctrine_context())]:
		if typeof(source) != TYPE_ARRAY:
			continue
		for item in source:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			combined.append(item.duplicate(true))
	return _normalize_grounded_plan(combined)


func _merge_signed_bias(target: Dictionary, source) -> void:
	if typeof(source) != TYPE_DICTIONARY:
		return
	for raw_key in source.keys():
		var key := str(raw_key)
		target[key] = clampf(float(target.get(key, 0.0)) + clampf(float(source[raw_key]), -1.0, 1.0), -1.0, 1.0)


func _doctrine_context() -> Dictionary:
	var behavior_evidence := _behavior_evidence_array(BEHAVIOR_EVIDENCE_CAP)
	var behavior_patterns: Array[String] = []
	var danger_changed := false
	for evidence in behavior_evidence:
		if typeof(evidence) != TYPE_DICTIONARY:
			continue
		var pattern := str(evidence.get("primary_pattern", "")).strip_edges()
		if pattern != "" and not behavior_patterns.has(pattern):
			behavior_patterns.append(pattern)
		var context = evidence.get("context", {})
		if typeof(context) == TYPE_DICTIONARY and bool(context.get("nearest_danger_changed", false)):
			danger_changed = true
	return {
		"day": day_night.day,
		"phase": day_night.phase,
		"enemy_type_counts": _get_enemy_type_counts(),
		"known_enemy_types": _known_enemy_types(),
		"ari_hp_ratio": _get_ari_hp_ratio(),
		"recent_events": ari_memory.get_recent_events(30) if ari_memory != null and ari_memory.has_method("get_recent_events") else [],
		"behavior_patterns": behavior_patterns,
		"behavior_evidence": behavior_evidence,
		"danger_changed": danger_changed,
	}


func _learned_doctrine_bias(context: Dictionary) -> Dictionary:
	if not _learning_enabled or ari_doctrine == null:
		return {}
	return ari_doctrine.get_active_bias(context)


func _learned_doctrine_plan(context: Dictionary) -> Array:
	if not _learning_enabled or ari_doctrine == null:
		return []
	return ari_doctrine.get_active_plan(context)


func _learned_active_doctrines(context: Dictionary, max_count: int = NIGHT_REFLECTION_DOCTRINE_CAP) -> Array:
	if not _learning_enabled or ari_doctrine == null:
		return []
	return ari_doctrine.get_active_doctrines(context, max_count)


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
		Vector2(108.0, -52.0),
		Vector2(108.0, 76.0),
	]


func _spike_trap_slot_offsets() -> Array:
	return [
		Vector2(216.0, -36.0),
		Vector2(216.0, 40.0),
	]


func _bow_tower_slot_offsets() -> Array:
	return [
		Vector2(144.0, -112.0),
		Vector2(72.0, -112.0),
		Vector2(216.0, -112.0),
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


func _find_tar_lure_position() -> Dictionary:
	var tar_pit := _nearest_valid_structure(tar_pits)
	if tar_pit == null:
		return {"valid": false}
	var anchor := _get_defense_anchor()
	var pit_position: Vector2 = tar_pit.global_position
	var direction := anchor - pit_position
	var enemy := get_nearest_enemy(pit_position)
	if enemy != null:
		direction = pit_position - enemy.global_position
	elif direction.length() < 0.1 and ari != null:
		direction = ari.global_position - pit_position
	if direction.length() < 0.1:
		direction = Vector2.LEFT
	var radius := float(_get_tar_pit_data().get("slow_radius", 58.0))
	var radius_value = tar_pit.get("slow_radius")
	if typeof(radius_value) == TYPE_FLOAT or typeof(radius_value) == TYPE_INT:
		radius = float(radius_value)
	return {
		"valid": true,
		"position": _clamp_point_to_arena(pit_position + direction.normalized() * minf(radius * 0.62, 48.0)),
		"structure": tar_pit,
	}


func _find_fear_lantern_position() -> Dictionary:
	var lantern := _nearest_valid_structure(fear_lanterns)
	if lantern == null:
		return {"valid": false}
	var anchor := _get_defense_anchor()
	var lantern_position: Vector2 = lantern.global_position
	var direction := anchor - lantern_position
	var enemy := get_nearest_enemy(lantern_position)
	if enemy != null:
		direction = lantern_position - enemy.global_position
	elif direction.length() < 0.1 and ari != null:
		direction = ari.global_position - lantern_position
	if direction.length() < 0.1:
		direction = Vector2.LEFT
	var radius := float(_get_fear_lantern_data().get("soothe_radius", 82.0))
	var radius_value = lantern.get("soothe_radius")
	if typeof(radius_value) == TYPE_FLOAT or typeof(radius_value) == TYPE_INT:
		radius = float(radius_value)
	return {
		"valid": true,
		"position": _clamp_point_to_arena(lantern_position + direction.normalized() * minf(radius * 0.45, 42.0)),
		"structure": lantern,
	}


func _find_decoy_position() -> Dictionary:
	var decoy := _nearest_valid_structure(decoy_idols)
	if decoy == null:
		return {"valid": false}
	var anchor := _get_defense_anchor()
	var decoy_position: Vector2 = decoy.global_position
	var direction := anchor - decoy_position
	var enemy := get_nearest_enemy(decoy_position)
	if enemy != null:
		direction = decoy_position - enemy.global_position
	elif direction.length() < 0.1 and ari != null:
		direction = ari.global_position - decoy_position
	if direction.length() < 0.1:
		direction = Vector2.LEFT
	var radius := float(_get_decoy_idol_data().get("taunt_radius", 118.0))
	var radius_value = decoy.get("taunt_radius")
	if typeof(radius_value) == TYPE_FLOAT or typeof(radius_value) == TYPE_INT:
		radius = float(radius_value)
	return {
		"valid": true,
		"position": _clamp_point_to_arena(decoy_position + direction.normalized() * minf(radius * 0.72, 82.0)),
		"structure": decoy,
	}


func _find_thorn_position() -> Dictionary:
	var thorn_totem := _nearest_valid_structure(thorn_totems)
	if thorn_totem == null:
		return {"valid": false}
	var anchor := _get_defense_anchor()
	var thorn_position: Vector2 = thorn_totem.global_position
	var direction := anchor - thorn_position
	var enemy := get_nearest_enemy(thorn_position)
	if enemy != null:
		direction = thorn_position - enemy.global_position
	elif direction.length() < 0.1 and ari != null:
		direction = ari.global_position - thorn_position
	if direction.length() < 0.1:
		direction = Vector2.LEFT
	var radius := float(_get_thorn_totem_data().get("thorn_radius", 76.0))
	var radius_value = thorn_totem.get("thorn_radius")
	if typeof(radius_value) == TYPE_FLOAT or typeof(radius_value) == TYPE_INT:
		radius = float(radius_value)
	return {
		"valid": true,
		"position": _clamp_point_to_arena(thorn_position + direction.normalized() * minf(radius * 0.42, 36.0)),
		"structure": thorn_totem,
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
	if resource_system != null and bool(resource_system.call("spend_food", 1)):
		if ari.has_method("mark_eating_food"):
			ari.call("mark_eating_food", reason)
		else:
			ari.call("stop_daytime_job", reason)
		ari.call("restore_from_food", 30.0)
		ari_memory.record_event("food_eaten", {"day": day_night.day, "phase": day_night.phase})
		_show_ari_thought("Food makes the dark feel a little farther away.", true)
	else:
		ari.call("stop_daytime_job", reason)
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
	_record_observer_snapshot("library", 0.7, ["library_reflection"])
	_request_night_reflection("library_reflection", "in_progress")


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


func _request_agent_plan(trigger: String) -> void:
	var clean_trigger := trigger.strip_edges()
	if ai_bridge == null:
		return
	if clean_trigger == "sign_commit" and _should_defer_sign_commit_for_deep_interpretation():
		_agent_plan_deferred_for_deep_interpretation = true
		_seed_local_agent_plan("sign_commit")
		_agent_plan_pending_trigger = ""
		_agent_plan_pending_at = 0.0
		return
	if sign_text.strip_edges() == "" and enemies.is_empty():
		_agent_plan_pending_trigger = ""
		_agent_plan_pending_at = 0.0
		_clear_agent_plan()
		return
	if clean_trigger == "phase_changed" and not _agent_phase_replan_needed():
		_refresh_agent_plan_context_signatures()
		if _agent_plan_pending_trigger.strip_edges() == "phase_changed":
			_agent_plan_pending_trigger = ""
			_agent_plan_pending_at = 0.0
		return
	if clean_trigger == "timer" and not _agent_timer_replan_needed():
		_refresh_agent_plan_context_signatures()
		_postpone_agent_timer_replan()
		return
	if _agent_plan_request_in_flight:
		_set_pending_agent_plan_trigger(trigger)
		return
	if _fast_prediction_request_in_flight and not _is_critical_agent_plan_trigger(clean_trigger):
		_set_pending_agent_plan_trigger(clean_trigger)
		return
	if not _can_start_agent_plan_request(trigger):
		_set_pending_agent_plan_trigger(trigger)
		return
	_agent_plan_request_in_flight = true
	_agent_plan_request_id += 1
	_agent_plan_request_trigger = trigger
	var request_id := _agent_plan_request_id
	var payload := _build_agent_plan_payload(trigger)
	ai_bridge.request_agent_plan(payload, func(result: Dictionary) -> void:
		_on_agent_plan_response(request_id, result)
	)


func _should_defer_sign_commit_for_deep_interpretation() -> bool:
	if ai_bridge == null or not ai_bridge.has_method("get_provider_mode"):
		return false
	if str(ai_bridge.call("get_provider_mode")) != "remote_server":
		return false
	if _sign_needs_remote_bootstrap_plan():
		return false
	return _ai_deep_interpretation_in_flight or _agent_plan_request_trigger == "deep_interpretation"


func _sign_needs_remote_bootstrap_plan() -> bool:
	for hint_id in ["smith_sword", "mine_ore", "train_sword", "combat_training", "prepare_weapon", "fight_head_on"]:
		if float(sign_priority_hints.get(hint_id, 0.0)) >= 0.5:
			return true
	return false


func _advance_agent_replan() -> void:
	if _agent_plan_pending_trigger.strip_edges() != "" and not _agent_plan_request_in_flight and _agent_plan_clock >= _agent_plan_pending_at:
		var pending_trigger := _agent_plan_pending_trigger
		_agent_plan_pending_trigger = ""
		_agent_plan_pending_at = 0.0
		_request_agent_plan(pending_trigger)
		return
	if _agent_plan_replan_at <= 0.0:
		return
	if _agent_plan_clock < _agent_plan_replan_at:
		return
	_agent_plan_replan_at = 0.0
	if ai_bridge == null or not ai_bridge.is_ai_enabled():
		return
	_request_agent_plan("timer")


func _on_agent_plan_response(request_id: int, result: Dictionary) -> void:
	if _agent_plan_request_id > 0 and request_id != _agent_plan_request_id:
		return
	_agent_plan_request_in_flight = false
	_agent_plan_next_allowed_at = maxf(_agent_plan_next_allowed_at, _agent_plan_clock + AGENT_PLAN_REQUEST_COOLDOWN)
	var response_trigger := _agent_plan_request_trigger
	_agent_plan_request_trigger = ""
	var queued_trigger := _agent_plan_pending_trigger
	_agent_plan_pending_trigger = ""
	_agent_plan_pending_at = 0.0
	if str(result.get("schema", "")) != "ari.agent.plan.v1":
		_clear_agent_plan()
		_request_pending_agent_plan(queued_trigger)
		return
	var failed := not bool(result.get("ok", false))
	if failed and _should_keep_current_agent_plan_after_failed_replan(response_trigger):
		_request_pending_agent_plan(queued_trigger)
		return
	if failed and not _has_explicit_fallback_agent_plan(result):
		_clear_agent_plan()
		_emit_state()
		_request_pending_agent_plan(queued_trigger)
		return
	agent_plan = result.duplicate(true)
	agent_plan["step_index"] = clampi(int(agent_plan.get("step_index", 0)), 0, _agent_plan_step_count(agent_plan))
	agent_plan["created_at_seconds"] = _agent_plan_clock
	agent_plan["outcomes"] = []
	agent_plan["failures"] = []
	agent_plan["abandoned"] = false
	agent_plan["stale_reason"] = ""
	_refresh_agent_plan_context_signatures()
	agent_grounded_plan = _agent_plan_to_grounded_plan(result)
	_refresh_ari_understanding(response_trigger)
	_record_agent_plan_created(response_trigger, result)
	_agent_plan_replan_at = _agent_plan_clock + clampf(float(result.get("replan_after_seconds", 8.0)), 3.0, 45.0)
	var source := str(result.get("source", ""))
	var remote_success := bool(result.get("ok", false)) and source == "remote_server"
	var thought := str(result.get("thought", "")).strip_edges()
	if remote_success and thought != "":
		_show_ari_thought(thought, true)
	var theory := str(result.get("survival_theory", "")).strip_edges()
	if theory != "":
		ai_survival_theory = theory
	if remote_success:
		ai_status = "AI: planner active"
	elif failed and source != "local_fallback":
		var failure_reason := _ai_failure_reason_label(result)
		ai_status = "AI: planner fallback" if failure_reason == "" else "AI: planner fallback (%s)" % failure_reason
	_emit_state()
	_request_pending_agent_plan(queued_trigger)


func _record_agent_plan_created(trigger: String, plan_result: Dictionary) -> void:
	if ari_memory == null:
		return
	var next_action = plan_result.get("next_action", {})
	var action_id := _action_choice_id(next_action)
	var reason := ""
	if typeof(next_action) == TYPE_DICTIONARY:
		reason = _limit_inline(str(next_action.get("reason", "")), 180)
	var plan_id := str(plan_result.get("plan_id", "")).strip_edges()
	if plan_id == "":
		plan_id = "plan_day%d_%04d_%s" % [day_night.day, int(round(_agent_plan_clock * 10.0)), action_id if action_id != "" else "unknown"]
	var doctrine_matches := _doctrines_for_plan_action(action_id)
	var doctrine_influenced := reason.to_lower().contains("doctrine") or not doctrine_matches.is_empty()
	var doctrine_ids: Array[String] = []
	var evidence_ids: Array[String] = []
	var reflection_id := ""
	var summary_id := ""
	for doctrine in doctrine_matches:
		if typeof(doctrine) != TYPE_DICTIONARY:
			continue
		var doctrine_id := str(doctrine.get("id", "")).strip_edges()
		if doctrine_id != "" and not doctrine_ids.has(doctrine_id):
			doctrine_ids.append(doctrine_id)
		for evidence_id in _summary_string_array(doctrine.get("evidence_ids", []), 12, 120):
			_summary_append(evidence_ids, evidence_id, 20)
		if reflection_id == "" and str(doctrine.get("reflection_id", "")).strip_edges() != "":
			reflection_id = str(doctrine.get("reflection_id", ""))
		if summary_id == "" and str(doctrine.get("summary_id", "")).strip_edges() != "":
			summary_id = str(doctrine.get("summary_id", ""))
	ari_memory.record_event("agent_plan_created", {
		"plan_id": plan_id,
		"trigger": trigger,
		"action_id": action_id,
		"reason": reason,
		"source": str(plan_result.get("source", "")),
		"failure_reason": str(plan_result.get("failure_reason", "")),
		"origin": str(plan_result.get("origin", "agent_planner")),
		"goal": _limit_inline(str(plan_result.get("goal", "")), 120),
		"confidence": clampf(float(plan_result.get("confidence", 0.0)), 0.0, 1.0),
		"doctrine_influenced": doctrine_influenced,
		"doctrine_ids": doctrine_ids,
		"reflection_id": reflection_id,
		"summary_id": summary_id,
		"evidence_ids": evidence_ids,
		"day": day_night.day,
		"phase": day_night.phase,
	})
	if doctrine_influenced and action_id != "" and not doctrine_ids.is_empty():
		_pending_learning_trace_by_action[action_id] = {
			"schema": "ari.learning_trace.v1",
			"day": day_night.day,
			"phase": day_night.phase,
			"evidence_ids": evidence_ids,
			"behavior_evidence": _behavior_evidence_array(2),
			"scribe_note_ids": _recent_scribe_note_ids_for_evidence(evidence_ids, 6),
			"summary_id": summary_id,
			"reflection_id": reflection_id,
			"doctrine_id": doctrine_ids[0],
			"doctrine_ids": doctrine_ids,
			"later_plan_id": plan_id,
			"later_action_id": action_id,
			"outcome": "pending",
			"improvement_claim": "pending outcome for doctrine-influenced action",
			"source": "godot",
			"origin": "learning_trace",
		}


func _doctrines_for_plan_action(action_id: String) -> Array:
	var result := []
	var clean_action := action_id.strip_edges()
	if clean_action == "" or ari_doctrine == null or not _learning_enabled:
		return result
	for doctrine in ari_doctrine.get_all_doctrines():
		if typeof(doctrine) != TYPE_DICTIONARY:
			continue
		if _world_doctrine_mentions_action(doctrine, clean_action):
			result.append(doctrine)
	return result


func _world_doctrine_mentions_action(doctrine: Dictionary, action_id: String) -> bool:
	var bias = doctrine.get("bias", {})
	if typeof(bias) == TYPE_DICTIONARY:
		for key in bias.keys():
			if _agent_actions_equivalent(str(key), action_id):
				return true
	var plan = doctrine.get("plan", [])
	if typeof(plan) == TYPE_ARRAY:
		for step in plan:
			if typeof(step) != TYPE_DICTIONARY:
				continue
			var step_action := str(step.get("affordance_id", step.get("action_id", ""))).strip_edges()
			if _agent_actions_equivalent(step_action, action_id):
				return true
	return false


func _recent_scribe_note_ids_for_evidence(evidence_ids: Array, max_count: int) -> Array[String]:
	var result: Array[String] = []
	if chronicle == null:
		return result
	for note in chronicle.get_lifetime_scribe_notes():
		if typeof(note) != TYPE_DICTIONARY:
			continue
		var note_evidence := _summary_string_array(note.get("evidence_ids", []), 12, 120)
		var matched := false
		for evidence_id in evidence_ids:
			if note_evidence.has(str(evidence_id)):
				matched = true
				break
		if not matched:
			continue
		var note_id := str(note.get("note_id", "")).strip_edges()
		if note_id != "" and not result.has(note_id):
			result.append(note_id)
		if result.size() >= max_count:
			break
	return result


func _clear_agent_plan() -> void:
	agent_plan = {}
	agent_grounded_plan = []
	_latest_body_alignment = {}
	_refresh_ari_understanding("plan_cleared")
	_agent_plan_replan_at = 0.0
	_agent_plan_timer_signature = ""
	_agent_plan_phase_signature = ""


func _seed_local_agent_plan(trigger: String) -> void:
	var result := _agent_local_fallback(true)
	var raw_plan = result.get("plan", [])
	if typeof(raw_plan) != TYPE_ARRAY or raw_plan.is_empty():
		return
	result["schema"] = "ari.agent.plan.v1"
	result["ok"] = false
	result["source"] = "local_fallback"
	agent_plan = result.duplicate(true)
	agent_plan["step_index"] = clampi(int(agent_plan.get("step_index", 0)), 0, _agent_plan_step_count(agent_plan))
	agent_plan["created_at_seconds"] = _agent_plan_clock
	agent_plan["outcomes"] = []
	agent_plan["failures"] = []
	agent_plan["abandoned"] = false
	agent_plan["stale_reason"] = ""
	_refresh_agent_plan_context_signatures()
	agent_grounded_plan = _agent_plan_to_grounded_plan(agent_plan)
	_refresh_ari_understanding(trigger)
	_record_agent_plan_created(trigger, agent_plan)
	_agent_plan_replan_at = _agent_plan_clock + clampf(float(agent_plan.get("replan_after_seconds", 8.0)), 3.0, 45.0)
	_emit_state()


func _refresh_agent_plan_context_signatures() -> void:
	if agent_plan.is_empty():
		return
	_agent_plan_timer_signature = _agent_timer_context_signature()
	_agent_plan_phase_signature = _agent_phase_context_signature()
	agent_plan["timer_context_signature"] = _agent_plan_timer_signature
	agent_plan["phase_context_signature"] = _agent_plan_phase_signature


func _should_keep_current_agent_plan_after_failed_replan(trigger: String) -> bool:
	if trigger != "structure_built":
		return false
	return _agent_has_remaining_plan_steps()


func _agent_has_remaining_plan_steps() -> bool:
	return not agent_plan.is_empty() and not bool(agent_plan.get("abandoned", false)) and int(agent_plan.get("step_index", 0)) < _agent_plan_step_count(agent_plan)


func _record_agent_plan_outcome(action_id: String, outcome: String, reason: String, trigger := "") -> void:
	if agent_plan.is_empty():
		return
	var clean_action_id := action_id.strip_edges()
	if clean_action_id == "":
		return
	var step_index := clampi(int(agent_plan.get("step_index", 0)), 0, _agent_plan_step_count(agent_plan))
	var matched_step_index := _find_agent_plan_step_index(clean_action_id, step_index)
	var step_id := ""
	if matched_step_index >= 0:
		var steps: Array = agent_plan.get("plan", [])
		if matched_step_index < steps.size() and typeof(steps[matched_step_index]) == TYPE_DICTIONARY:
			step_id = str(steps[matched_step_index].get("step_id", ""))
	var record := {
		"trigger": trigger,
		"action_id": clean_action_id,
		"outcome": outcome.strip_edges(),
		"reason": _limit_inline(reason, 180),
		"step_id": step_id,
		"day": day_night.day,
		"phase": day_night.phase,
		"time": _agent_plan_clock,
	}
	_agent_plan_recent_outcomes.push_front(record.duplicate(true))
	while _agent_plan_recent_outcomes.size() > 12:
		_agent_plan_recent_outcomes.pop_back()
	if ari_doctrine != null and ari_doctrine.has_method("apply_outcome_feedback"):
		ari_doctrine.call("apply_outcome_feedback", record)
	_complete_pending_learning_trace(clean_action_id, record)
	var plan_outcomes = agent_plan.get("outcomes", [])
	if typeof(plan_outcomes) != TYPE_ARRAY:
		plan_outcomes = []
	plan_outcomes.push_front(record.duplicate(true))
	while plan_outcomes.size() > 8:
		plan_outcomes.pop_back()
	agent_plan["outcomes"] = plan_outcomes
	agent_plan["last_outcome"] = record.duplicate(true)
	if outcome == "action_completed" and matched_step_index >= 0:
		if matched_step_index == step_index or _agent_plan_steps_before_satisfied(matched_step_index):
			agent_plan["step_index"] = clampi(matched_step_index + 1, 0, _agent_plan_step_count(agent_plan))
		agent_grounded_plan = _agent_plan_to_grounded_plan(agent_plan)
	elif outcome != "action_completed":
		var failures = agent_plan.get("failures", [])
		if typeof(failures) != TYPE_ARRAY:
			failures = []
		failures.push_front(record.duplicate(true))
		while failures.size() > 6:
			failures.pop_back()
		agent_plan["failures"] = failures
		if _agent_outcome_contradicts_current_plan(clean_action_id, outcome, step_index, matched_step_index):
			_abandon_agent_plan(record)
	if outcome != "action_completed":
		_record_observer_snapshot("action_failed", 0.75, [outcome, clean_action_id])


func _complete_pending_learning_trace(action_id: String, outcome_record: Dictionary) -> void:
	if ari_memory == null:
		return
	if not _pending_learning_trace_by_action.has(action_id):
		return
	var trace: Dictionary = _pending_learning_trace_by_action.get(action_id, {}).duplicate(true)
	_pending_learning_trace_by_action.erase(action_id)
	trace["outcome"] = str(outcome_record.get("outcome", ""))
	trace["outcome_reason"] = _limit_inline(str(outcome_record.get("reason", "")), 180)
	trace["outcome_trigger"] = str(outcome_record.get("trigger", ""))
	trace["completed_day"] = day_night.day
	trace["completed_phase"] = day_night.phase
	trace["completed_time"] = float(outcome_record.get("time", _agent_plan_clock))
	trace["improvement_claim"] = _learning_trace_improvement_claim(trace, outcome_record)
	ari_memory.record_event("learning_trace_created", {
		"trace": trace,
		"doctrine_id": str(trace.get("doctrine_id", "")),
		"later_plan_id": str(trace.get("later_plan_id", "")),
		"outcome": str(trace.get("outcome", "")),
		"source": "godot",
		"origin": "learning_trace",
		"evidence_ids": trace.get("evidence_ids", []),
	})
	print("LEARNING_TRACE ", JSON.stringify(trace))


func _learning_trace_improvement_claim(trace: Dictionary, outcome_record: Dictionary) -> String:
	var action_id := str(trace.get("later_action_id", outcome_record.get("action_id", ""))).strip_edges()
	var outcome := str(outcome_record.get("outcome", "")).strip_edges()
	if outcome == "action_completed":
		for evidence in trace.get("behavior_evidence", []):
			if typeof(evidence) == TYPE_DICTIONARY and str(evidence.get("primary_pattern", "")) == "repeated_action_switching":
				return "Doctrine-influenced plan completed %s after prior repeated switching; this is plausible learning evidence, not survival proof by itself." % action_id
		return "Doctrine-influenced plan completed %s; this is plausible learning evidence, not survival proof by itself." % action_id
	if outcome == "":
		outcome = "unknown_outcome"
	return "Doctrine-influenced plan chose %s but produced %s; treat this as feedback, not a success claim." % [action_id, outcome]


func _agent_outcome_contradicts_current_plan(action_id: String, outcome: String, step_index: int, matched_step_index: int) -> bool:
	var normalized_outcome := outcome.strip_edges().to_lower()
	if not ["near_death", "ari_near_death", "ari_died", "death", "structure_destroyed", "action_failed"].has(normalized_outcome):
		return false
	if matched_step_index == step_index:
		return true
	var current_action := _current_agent_step_action_id()
	if current_action == "":
		return false
	if _agent_actions_equivalent(current_action, action_id):
		return true
	if normalized_outcome == "structure_destroyed":
		return _destroyed_structure_breaks_current_plan(action_id, current_action)
	return false


func _destroyed_structure_breaks_current_plan(destroyed_action_id: String, current_action_id: String) -> bool:
	if destroyed_action_id == "build_wall" and ["use_cover", "use_existing_wall", "wait_behind_wall", "hide"].has(current_action_id):
		return true
	if destroyed_action_id == "place_aura_orb" and current_action_id == "lure_to_aura":
		return true
	if destroyed_action_id == "build_tower" and ["use_tower", "ranged_attack", "train_bow"].has(current_action_id):
		return true
	if destroyed_action_id == "build_storm_rod" and ["anti_flying", "sky_answer", "anti_air_defense"].has(current_action_id):
		return true
	return false


func _abandon_agent_plan(record: Dictionary) -> void:
	if agent_plan.is_empty() or bool(agent_plan.get("abandoned", false)):
		return
	var outcome := str(record.get("outcome", "")).strip_edges()
	var action_id := str(record.get("action_id", "")).strip_edges()
	agent_plan["abandoned"] = true
	agent_plan["stale_reason"] = "%s:%s" % [outcome, action_id]
	agent_plan["abandoned_at_seconds"] = _agent_plan_clock
	agent_plan["abandon_reason"] = _limit_inline(str(record.get("reason", "")), 180)
	agent_grounded_plan = []
	_agent_plan_replan_at = 0.0
	_show_ari_thought("That plan is wrong now. I need to change it.", true)


func _find_agent_plan_step_index(action_id: String, start_index: int) -> int:
	var steps = agent_plan.get("plan", [])
	if typeof(steps) != TYPE_ARRAY:
		return -1
	var from_index := clampi(start_index, 0, steps.size())
	for i in range(from_index, steps.size()):
		if typeof(steps[i]) != TYPE_DICTIONARY:
			continue
		var step_action := str(steps[i].get("action_id", "")).strip_edges()
		if _agent_actions_equivalent(step_action, action_id):
			return i
	return -1


func _agent_actions_equivalent(plan_action: String, completed_action: String) -> bool:
	if plan_action == completed_action:
		return true
	if plan_action == "build_tower" and completed_action == "build_bow_tower":
		return true
	if plan_action == "build_bow_tower" and completed_action == "build_tower":
		return true
	return false


func _agent_plan_steps_before_satisfied(stop_index: int) -> bool:
	var steps = agent_plan.get("plan", [])
	if typeof(steps) != TYPE_ARRAY:
		return false
	var safe_stop := clampi(stop_index, 0, steps.size())
	for i in range(safe_stop):
		if typeof(steps[i]) != TYPE_DICTIONARY:
			return false
		var action_id := str(steps[i].get("action_id", "")).strip_edges()
		if not _agent_plan_step_satisfied_by_world(action_id):
			return false
	return true


func _agent_plan_step_satisfied_by_world(action_id: String) -> bool:
	match action_id:
		"build_wall":
			return walls.size() > 0
		"place_aura_orb":
			return aura_orbs.size() > 0
		"build_tower", "build_bow_tower":
			return bow_towers.size() > 0
		"build_storm_rod":
			return storm_rods.size() > 0
		"build_tar_pit":
			return tar_pits.size() > 0
		"build_fear_lantern":
			return fear_lanterns.size() > 0
		"build_decoy_idol":
			return decoy_idols.size() > 0
		"build_thorn_totem":
			return thorn_totems.size() > 0
		"build_repair_bench":
			return repair_benches.size() > 0
	return false


func _agent_plan_step_count(plan: Dictionary) -> int:
	var steps = plan.get("plan", [])
	return steps.size() if typeof(steps) == TYPE_ARRAY else 0


func _current_agent_step_action_id() -> String:
	if agent_plan.is_empty():
		return ""
	var steps = agent_plan.get("plan", [])
	if typeof(steps) != TYPE_ARRAY:
		return ""
	var step_index := clampi(int(agent_plan.get("step_index", 0)), 0, steps.size())
	if step_index >= steps.size() or typeof(steps[step_index]) != TYPE_DICTIONARY:
		return ""
	return str(steps[step_index].get("action_id", "")).strip_edges()


func _agent_action_for_build_type(build_type: String) -> String:
	if build_type == WALL_BUILD_ID:
		return "build_wall"
	if build_type == AURA_ORB_BUILD_ID:
		return "place_aura_orb"
	if build_type == SPIKE_TRAP_BUILD_ID:
		return "build_spike_trap"
	if build_type == BOW_TOWER_BUILD_ID:
		return "build_tower"
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
	return build_type


func _structure_built_agent_plan_trigger(build_type: String) -> String:
	if build_type == STORM_ROD_BUILD_ID:
		return "anti_air_structure_built"
	return "structure_built"


func _structure_destroyed_agent_plan_trigger(destroyed_action_id: String) -> String:
	var clean_action_id := destroyed_action_id.strip_edges()
	if clean_action_id == "":
		return "structure_destroyed"
	if agent_plan.is_empty() or bool(agent_plan.get("abandoned", false)):
		return "structure_destroyed"
	var current_action := _current_agent_step_action_id()
	if current_action == "":
		return "structure_destroyed_minor"
	if _destroyed_structure_breaks_current_plan(clean_action_id, current_action):
		return "structure_destroyed"
	if not enemies.is_empty() and ["build_tower", "place_aura_orb", "build_storm_rod"].has(clean_action_id):
		return "structure_destroyed"
	return "structure_destroyed_minor"


func _request_pending_agent_plan(trigger: String) -> void:
	if trigger.strip_edges() == "":
		return
	_request_agent_plan(trigger)


func _agent_timer_replan_needed() -> bool:
	if agent_plan.is_empty() or bool(agent_plan.get("abandoned", false)):
		return true
	var previous_signature := _agent_plan_timer_signature
	if previous_signature == "":
		previous_signature = str(agent_plan.get("timer_context_signature", ""))
	if previous_signature == "":
		return true
	var current_signature := _agent_timer_context_signature()
	if current_signature == previous_signature:
		return false
	if _agent_can_keep_safe_daytime_hold_plan() and _agent_safe_daytime_hold_signature(current_signature) == _agent_safe_daytime_hold_signature(previous_signature):
		return false
	return true


func _postpone_agent_timer_replan() -> void:
	if _agent_plan_pending_trigger.strip_edges() == "timer":
		_agent_plan_pending_trigger = ""
		_agent_plan_pending_at = 0.0
	_agent_plan_replan_at = maxf(_agent_plan_clock + AGENT_PLAN_REQUEST_COOLDOWN, _agent_plan_next_allowed_at)


func _agent_phase_replan_needed() -> bool:
	if _is_critical_agent_plan_trigger("phase_changed"):
		return true
	if agent_plan.is_empty() or bool(agent_plan.get("abandoned", false)):
		return true
	var previous_signature := _agent_plan_phase_signature
	if previous_signature == "":
		previous_signature = str(agent_plan.get("phase_context_signature", ""))
	if previous_signature == "":
		return true
	var current_signature := _agent_phase_context_signature()
	if current_signature == previous_signature:
		return false
	if _agent_can_keep_safe_daytime_hold_plan() and _agent_safe_daytime_hold_signature(current_signature) == _agent_safe_daytime_hold_signature(previous_signature):
		return false
	if _agent_can_keep_safe_night_hold_plan() and _agent_safe_night_hold_signature(current_signature) == _agent_safe_night_hold_signature(previous_signature):
		return false
	return true


func _agent_can_keep_safe_daytime_hold_plan() -> bool:
	if day_night == null:
		return false
	var phase := str(day_night.phase)
	if not ["morning", "midday"].has(phase):
		return false
	if not enemies.is_empty():
		return false
	if _get_damaged_structure_count() > 0:
		return false
	if not _active_doctrine_defense_ready_for_dusk():
		return false
	if _agent_has_safe_daytime_upgrade_opportunity():
		return false
	var action_id := _current_agent_step_action_id()
	if action_id == "":
		var next_action = agent_plan.get("next_action", {})
		if typeof(next_action) == TYPE_DICTIONARY:
			action_id = _action_choice_id(next_action)
	match action_id:
		"use_tower", "ranged_attack", "train_bow":
			return bow_towers.size() > 0
		"lure_to_aura":
			return aura_orbs.size() > 0
	return false


func _agent_can_keep_safe_night_hold_plan() -> bool:
	if day_night == null or str(day_night.phase) != "night":
		return false
	if not enemies.is_empty():
		return false
	if _get_damaged_structure_count() > 0:
		return false
	if not _active_doctrine_defense_ready_for_dusk():
		return false
	var action_id := _current_agent_step_action_id()
	if action_id == "":
		var next_action = agent_plan.get("next_action", {})
		if typeof(next_action) == TYPE_DICTIONARY:
			action_id = _action_choice_id(next_action)
	match action_id:
		"use_tower", "ranged_attack", "train_bow":
			return bow_towers.size() > 0
		"lure_to_aura":
			return aura_orbs.size() > 0
		"use_fear_lantern":
			return fear_lanterns.size() > 0
		"use_decoy_idol":
			return decoy_idols.size() > 0
		"use_thorns":
			return thorn_totems.size() > 0
		"use_cover", "hide_until_dawn", "stall_until_dawn", "survive_until_morning":
			return walls.size() > 0 or aura_orbs.size() > 0 or bow_towers.size() > 0 or fear_lanterns.size() > 0 or decoy_idols.size() > 0
	return false


func _agent_has_safe_daytime_upgrade_opportunity() -> bool:
	var upgrade_ids := {
		"repair": true,
		"smith_sword": true,
		"build_wall": true,
		"place_aura_orb": true,
		"build_tower": true,
		"build_storm_rod": true,
		"build_spike_trap": true,
		"build_tar_pit": true,
		"build_fear_lantern": true,
		"build_decoy_idol": true,
		"build_thorn_totem": true,
		"build_repair_bench": true,
	}
	for affordance in _current_affordances():
		if typeof(affordance) != TYPE_DICTIONARY:
			continue
		var action_id := str(affordance.get("id", "")).strip_edges()
		if bool(affordance.get("available", false)) and upgrade_ids.has(action_id):
			return true
	return false


func _agent_safe_daytime_hold_signature(signature: String) -> String:
	var parts := signature.split("|", false)
	var kept: Array[String] = []
	for part in parts:
		var text := str(part)
		if text.begins_with("day:") or text.begins_with("enemies:") or text.begins_with("enemy_"):
			continue
		kept.append(text)
	return "|".join(kept)


func _agent_safe_night_hold_signature(signature: String) -> String:
	var parts := signature.split("|", false)
	var kept: Array[String] = []
	for part in parts:
		var text := str(part)
		if text.begins_with("day:") or text.begins_with("stone:") or text.begins_with("food:") or text.begins_with("ore:") or text.begins_with("enemies:") or text.begins_with("enemy_"):
			continue
		kept.append(text)
	return "|".join(kept)


func _agent_phase_context_signature() -> String:
	return _agent_material_context_signature(false)


func _agent_timer_context_signature() -> String:
	return _agent_material_context_signature(false)


func _agent_material_context_signature(include_phase: bool) -> String:
	var parts: Array[String] = [
		"day:%d" % day_night.day,
		"stone:%d" % _stone_count(),
		"food:%d" % _food_count(),
		"ore:%d" % _ore_count(),
		"sword:%d" % _current_sword_tier(),
		"walls:%d" % walls.size(),
		"aura:%d" % aura_orbs.size(),
		"tower:%d" % bow_towers.size(),
		"storm:%d" % storm_rods.size(),
		"tar:%d" % tar_pits.size(),
		"lantern:%d" % fear_lanterns.size(),
		"thorn:%d" % thorn_totems.size(),
		"repair:%d" % repair_benches.size(),
		"enemies:%d" % enemies.size(),
		"step:%d" % int(agent_plan.get("step_index", 0)),
	]
	if include_phase:
		parts.insert(1, "phase:%s" % str(day_night.phase))
	var enemy_counts := _get_enemy_type_counts()
	var enemy_types := enemy_counts.keys()
	enemy_types.sort()
	for raw_type in enemy_types:
		var enemy_type := str(raw_type)
		parts.append("enemy_%s:%d" % [enemy_type, int(enemy_counts.get(raw_type, 0))])
	return "|".join(parts)


func _can_start_agent_plan_request(trigger: String) -> bool:
	return _is_critical_agent_plan_trigger(trigger) or _agent_plan_clock >= _agent_plan_next_allowed_at


func _set_pending_agent_plan_trigger(trigger: String) -> void:
	var clean_trigger := trigger.strip_edges()
	if clean_trigger == "":
		return
	_agent_plan_pending_trigger = _merge_agent_plan_trigger(_agent_plan_pending_trigger, clean_trigger)
	_agent_plan_pending_at = _agent_plan_clock if _is_critical_agent_plan_trigger(_agent_plan_pending_trigger) else maxf(_agent_plan_next_allowed_at, _agent_plan_clock)


func _merge_agent_plan_trigger(existing: String, incoming: String) -> String:
	if existing.strip_edges() == "":
		return incoming
	if _is_critical_agent_plan_trigger(incoming) and not _is_critical_agent_plan_trigger(existing):
		return incoming
	return existing


func _agent_has_ready_dusk_plan() -> bool:
	if agent_plan.is_empty() or bool(agent_plan.get("abandoned", false)):
		return false
	if not _active_doctrine_defense_ready_for_dusk():
		return false
	var action_id := _current_agent_step_action_id()
	if action_id == "":
		var next_action = agent_plan.get("next_action", {})
		if typeof(next_action) == TYPE_DICTIONARY:
			action_id = _action_choice_id(next_action)
	match action_id:
		"use_tower", "ranged_attack", "train_bow":
			return bow_towers.size() > 0
		"lure_to_aura":
			return aura_orbs.size() > 0
		"use_fear_lantern":
			return fear_lanterns.size() > 0
		"use_decoy_idol":
			return decoy_idols.size() > 0
		"use_thorns":
			return thorn_totems.size() > 0
		"use_cover", "hide_until_dawn", "stall_until_dawn", "survive_until_morning":
			return walls.size() > 0 or aura_orbs.size() > 0 or bow_towers.size() > 0 or fear_lanterns.size() > 0 or decoy_idols.size() > 0
	return false


func _active_doctrine_defense_ready_for_dusk() -> bool:
	if ari_doctrine == null:
		return true
	var active_plan = _learned_doctrine_plan(_doctrine_context())
	if typeof(active_plan) != TYPE_ARRAY:
		return true
	for item in active_plan:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var action_id := str(item.get("affordance_id", item.get("action_id", ""))).strip_edges()
		if _active_doctrine_step_blocks_dusk_ready(action_id, active_plan):
			return false
	return true


func _active_doctrine_step_blocks_dusk_ready(action_id: String, active_plan: Array) -> bool:
	match action_id:
		"build_storm_rod":
			return storm_rods.is_empty()
		"build_tower":
			return bow_towers.is_empty() and _doctrine_plan_has_action(active_plan, ["use_tower", "ranged_attack"])
		"place_aura_orb":
			return aura_orbs.is_empty() and _doctrine_plan_has_action(active_plan, ["lure_to_aura"])
		"build_fear_lantern":
			return fear_lanterns.is_empty() and _doctrine_plan_has_action(active_plan, ["use_fear_lantern"])
		"build_decoy_idol":
			return decoy_idols.is_empty() and _doctrine_plan_has_action(active_plan, ["use_decoy_idol"])
		"build_thorn_totem":
			return thorn_totems.is_empty() and _doctrine_plan_has_action(active_plan, ["use_thorns"])
	return false


func _is_critical_agent_plan_trigger(trigger: String) -> bool:
	var clean_trigger := trigger.strip_edges()
	if clean_trigger == "phase_changed":
		var phase := str(day_night.phase) if day_night != null else ""
		if phase == "dusk" and enemies.is_empty() and _agent_has_ready_dusk_plan():
			return false
		if phase == "night" and _agent_can_keep_safe_night_hold_plan():
			return false
		return phase == "dusk" or phase == "night" or enemies.size() > 0
	return [
		"sign_commit",
		"restart",
		"run_build_changed",
		"new_enemy_type",
		"near_death",
		"death",
		"structure_destroyed",
		"anti_air_structure_built",
		"library_note_created",
		"night_reflection",
		"deep_interpretation",
	].has(clean_trigger)


func _build_agent_plan_payload(trigger: String) -> Dictionary:
	_refresh_ari_understanding(trigger)
	var ari_job := str(ari.call("get_current_job")) if ari != null else "wait_or_idle"
	var ari_job_reason := str(ari.call("get_job_reason")) if ari != null else "Waiting"
	var doctrine_context := _doctrine_context()
	var active_doctrines := _learned_active_doctrines(doctrine_context, 3)
	return {
		"schema": "ari.agent.plan.request.v1",
		"trigger": trigger,
		"decision_kind": _agent_decision_kind_for_trigger(trigger),
		"objective": {
			"primary": "survive_next_night",
			"secondary": ["respect_sign_when_safe", "preserve_hp"],
		},
		"sign": {
			"text": _limit_inline(sign_text, 360),
			"interpretation": _limit_inline(sign_interpretation, 180),
			"priority_hints": _compact_priority_map(sign_priority_hints, 8),
			"grounded_plan": _compact_grounded_plan(sign_grounded_plan, 3),
			"strength": sign_strength,
			"resonance": sign_resonance,
		},
		"ari": {
			"hp": float(ari.get("hp")) if ari != null else 0.0,
			"hp_ratio": _get_ari_hp_ratio(),
			"fear": float(ari.get("fear")) if ari != null else 0.0,
			"hunger": float(ari.get("hunger")) if ari != null else 0.0,
			"stamina": float(ari.get("stamina")) if ari != null else 0.0,
			"current_job": ari_job,
			"current_reason": _limit_inline(ari_job_reason, 120),
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
			"damaged_structure_count": _get_damaged_structure_count(),
		},
		"current_plan": _agent_current_plan_payload(),
		"strategy_packet": _build_agent_plan_strategy_packet(trigger),
		"behavior_evidence": _behavior_evidence_array(BEHAVIOR_EVIDENCE_CAP),
		"active_doctrines": _compact_active_doctrines_for_plan(active_doctrines, 3),
		"recent_outcomes": _agent_recent_outcomes(8),
		"legal_actions": _current_agent_legal_actions_compact(),
		"action_control_panel": _build_action_control_panel(12),
		"active_doctrine_plan": _compact_doctrine_plan(_learned_doctrine_plan(doctrine_context), 4),
		"local_fallback": _agent_local_fallback(),
	}


func _agent_local_fallback(include_priority_hints := false) -> Dictionary:
	var action_id := _local_fallback_agent_action_id(include_priority_hints)
	var plan := []
	if action_id != "":
		plan.append({
			"step_id": "local_%s" % action_id,
			"action_id": action_id,
			"reason": "Local sign interpretation selected this legal action.",
			"success": "action_completed",
		})
	return {
		"goal": "survive_next_night",
		"survival_theory": ai_survival_theory if ai_survival_theory.strip_edges() != "" else "Use the safest legal action from Ari's local interpretation.",
		"plan": plan,
		"next_action": {"action_id": action_id, "urgency": 0.45, "reason": "Local fallback action."} if action_id != "" else {},
		"fallback_action": {"action_id": _first_available_action_id("flee"), "urgency": 0.25, "reason": "Distance remains legal when the plan stalls."},
		"belief_updates": [],
		"thought": "I can still follow the part I understand.",
		"confidence": 0.35,
		"replan_after_seconds": 8.0,
	}


func _agent_decision_kind_for_trigger(trigger: String) -> String:
	match trigger:
		"restart", "sign_commit", "run_build_changed":
			return "morning_plan"
		"phase_changed":
			if day_night.phase == "dusk":
				return "dusk_plan"
			if day_night.phase == "night":
				return "night_emergency"
			return "day_replan"
		"near_death":
			return "night_emergency"
		"structure_destroyed", "structure_destroyed_minor", "timer", "structure_built", "anti_air_structure_built", "new_enemy_type":
			return "day_replan"
		"library_note_created":
			return "library_doctrine"
		"night_reflection":
			return "library_doctrine"
		"death":
			return "post_failure_review"
	return "day_replan"


func _agent_current_plan_payload() -> Dictionary:
	if agent_plan.is_empty():
		return {}
	var step_count := _agent_plan_step_count(agent_plan)
	var step_index := clampi(int(agent_plan.get("step_index", 0)), 0, step_count)
	return {
		"goal": _limit_inline(str(agent_plan.get("goal", "")), 120),
		"survival_theory": _limit_inline(str(agent_plan.get("survival_theory", "")), 180),
		"step_index": step_index,
		"step_count": step_count,
		"current_action": _current_agent_step_action_id(),
		"age_seconds": maxf(_agent_plan_clock - float(agent_plan.get("created_at_seconds", _agent_plan_clock)), 0.0),
		"failures": _limit_agent_records(agent_plan.get("failures", []), 4),
		"outcomes": _limit_agent_records(agent_plan.get("outcomes", []), 4),
		"abandoned": bool(agent_plan.get("abandoned", false)),
		"stale_reason": _limit_inline(str(agent_plan.get("stale_reason", "")), 120),
		"source": str(agent_plan.get("source", "")),
	}


func _agent_recent_outcomes(max_count: int) -> Array:
	return _limit_agent_records(_agent_plan_recent_outcomes, max_count)


func _limit_agent_records(records, max_count: int) -> Array:
	var result := []
	if typeof(records) != TYPE_ARRAY:
		return result
	for record in records:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		result.append(record.duplicate(true))
		if result.size() >= max_count:
			break
	return result


func _agent_plan_to_grounded_plan(plan_result: Dictionary) -> Array:
	if bool(plan_result.get("abandoned", false)):
		return []
	var raw_steps = plan_result.get("plan", [])
	var grounded := []
	var next_action_id := _action_choice_id(plan_result.get("next_action", {}))
	var step_index := 0
	if typeof(raw_steps) == TYPE_ARRAY:
		step_index = clampi(int(plan_result.get("step_index", 0)), 0, raw_steps.size())
	if typeof(raw_steps) == TYPE_ARRAY:
		for i in range(step_index, raw_steps.size()):
			var raw_step = raw_steps[i]
			if typeof(raw_step) != TYPE_DICTIONARY:
				continue
			var action_id := str(raw_step.get("action_id", raw_step.get("affordance_id", raw_step.get("id", "")))).strip_edges()
			if action_id == "":
				continue
			var priority := float(raw_step.get("priority", 0.0))
			if priority <= 0.0:
				priority = float(plan_result.get("confidence", 0.6))
			if action_id == next_action_id:
				var next_action = plan_result.get("next_action", {})
				if typeof(next_action) == TYPE_DICTIONARY:
					priority = maxf(priority, float(next_action.get("urgency", 0.0)))
			grounded.append({
				"affordance_id": action_id,
				"priority": clampf(priority, 0.05, 1.0),
				"reason": str(raw_step.get("reason", plan_result.get("survival_theory", ""))),
			})
	var plan_has_remaining_steps: bool = typeof(raw_steps) == TYPE_ARRAY and step_index < raw_steps.size()
	var plan_has_completed_all_steps: bool = typeof(raw_steps) == TYPE_ARRAY and raw_steps.size() > 0 and step_index >= raw_steps.size()
	if grounded.is_empty() and next_action_id != "" and not plan_has_remaining_steps and not plan_has_completed_all_steps:
		var next_action = plan_result.get("next_action", {})
		grounded.append({
			"affordance_id": next_action_id,
			"priority": clampf(float(next_action.get("urgency", plan_result.get("confidence", 0.5))) if typeof(next_action) == TYPE_DICTIONARY else 0.5, 0.05, 1.0),
			"reason": str(next_action.get("reason", plan_result.get("survival_theory", ""))) if typeof(next_action) == TYPE_DICTIONARY else str(plan_result.get("survival_theory", "")),
		})
	return _normalize_grounded_plan(grounded)


func _action_choice_id(value) -> String:
	if typeof(value) != TYPE_DICTIONARY:
		return ""
	return str(value.get("action_id", value.get("id", ""))).strip_edges()


func _local_fallback_agent_action_id(include_priority_hints := false) -> String:
	var doctrine_context := _doctrine_context()
	var active_bias := _learned_doctrine_bias(doctrine_context)
	var candidates := {}
	_collect_local_fallback_candidates(candidates, sign_grounded_plan, active_bias)
	if include_priority_hints:
		_collect_priority_hint_fallback_candidates(candidates, sign_priority_hints, active_bias)
	_collect_local_fallback_candidates(candidates, _learned_doctrine_plan(doctrine_context), active_bias, true)
	var best_action := ""
	var best_score := 0.0
	for action_id in candidates.keys():
		var score := clampf(float(candidates[action_id]), 0.0, 1.0)
		if score > best_score:
			best_action = str(action_id)
			best_score = score
	return best_action


func _collect_local_fallback_candidates(candidates: Dictionary, source, active_bias: Dictionary, progress_doctrine_steps := false) -> void:
	if typeof(source) != TYPE_ARRAY:
		return
	var next_unsatisfied_action := _first_unsatisfied_doctrine_action_id(source) if progress_doctrine_steps else ""
	for item in source:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var raw_action_id := str(item.get("affordance_id", item.get("action_id", ""))).strip_edges()
		var action_id := _concrete_local_fallback_action_id(raw_action_id)
		if action_id == "" or not _is_action_available(action_id):
			continue
		if progress_doctrine_steps and _doctrine_action_step_satisfied(raw_action_id, source):
			continue
		var base_priority := clampf(float(item.get("priority", 0.45)), 0.0, 1.0)
		var learned_bias := clampf(float(active_bias.get(action_id, 0.0)), -1.0, 1.0)
		var step_progress_bonus := 0.25 if progress_doctrine_steps and raw_action_id == next_unsatisfied_action else 0.0
		var score := clampf(base_priority + learned_bias + step_progress_bonus, 0.0, 1.0)
		candidates[action_id] = maxf(float(candidates.get(action_id, 0.0)), score)


func _concrete_local_fallback_action_id(action_id: String) -> String:
	var clean := action_id.strip_edges()
	if clean == "":
		return ""
	match clean:
		"train_bow", "ranged_attack":
			if _is_action_available("use_tower"):
				return "use_tower"
			return _available_setup_action_or_mine("build_tower")
		"use_existing_wall", "wait_behind_wall", "hide":
			if _is_action_available("use_cover"):
				return "use_cover"
			var cover_setup := _available_setup_action_or_mine("build_wall")
			return cover_setup if cover_setup != "" else "flee"
		"anti_flying", "sky_answer", "anti_air_defense":
			if _is_action_available("build_storm_rod"):
				return "build_storm_rod"
			if _is_action_available("use_tower"):
				return "use_tower"
			var sky_setup := _available_setup_action_or_mine("build_storm_rod")
			return sky_setup if sky_setup != "" else "flee"
		"eat":
			if _is_action_available("eat_food"):
				return "eat_food"
			return "farm_food" if _is_action_available("farm_food") else ""
		"fight", "prepare_weapon":
			if _is_action_available("fight_head_on"):
				return "fight_head_on"
			return "train_combat" if _is_action_available("train_combat") else ""
		"kite":
			return "flee" if _is_action_available("flee") else ""
		"avoid_killing", "survive_until_morning":
			return "stall_until_dawn" if _is_action_available("stall_until_dawn") else ""
		"repair":
			return "repair_structure" if _is_action_available("repair_structure") else ""
	if AGENT_NONEXECUTABLE_ACTION_IDS.has(clean):
		return ""
	if _is_action_available(clean):
		return clean
	return _available_setup_action_or_mine(clean)


func _available_setup_action_or_mine(action_id: String) -> String:
	if _is_action_available(action_id):
		return action_id
	if ["build_wall", "place_aura_orb", "build_tower", "build_storm_rod", "build_spike_trap", "build_tar_pit", "build_fear_lantern", "build_decoy_idol", "build_thorn_totem", "build_repair_bench"].has(action_id):
		return "mine_stone" if _is_action_available("mine_stone") else ""
	return ""


func _collect_priority_hint_fallback_candidates(candidates: Dictionary, hints, active_bias: Dictionary) -> void:
	if typeof(hints) != TYPE_DICTIONARY:
		return
	for raw_key in hints.keys():
		var action_id := _priority_hint_to_fallback_action(str(raw_key))
		if action_id == "":
			continue
		var score := clampf(float(hints.get(raw_key, 0.0)) + float(active_bias.get(action_id, 0.0)), 0.0, 1.0)
		if score <= 0.0:
			continue
		candidates[action_id] = maxf(float(candidates.get(action_id, 0.0)), score)


func _priority_hint_to_fallback_action(hint_id: String) -> String:
	var clean_hint := hint_id.strip_edges()
	match clean_hint:
		"combat_training":
			clean_hint = "train_combat"
		"range":
			clean_hint = "use_tower" if bow_towers.size() > 0 else "build_tower"
		"mining":
			clean_hint = "mine_stone"
		"farming":
			clean_hint = "farm_food"
	var build_actions := ["build_wall", "place_aura_orb", "build_tower", "build_storm_rod", "build_spike_trap", "build_tar_pit", "build_fear_lantern", "build_decoy_idol", "build_thorn_totem", "build_repair_bench"]
	var concrete_setup_actions := [
		"mine_stone",
		"mine_ore",
		"smith_sword",
		"train_combat",
		"train_sword",
		"prepare_weapon",
		"farm_food",
		"eat_food",
		"rest",
		"use_tower",
		"ranged_attack",
		"lure_to_aura",
		"use_fear_lantern",
		"use_decoy_idol",
		"use_thorns",
	]
	if not concrete_setup_actions.has(clean_hint) and not build_actions.has(clean_hint):
		return ""
	if _is_action_available(clean_hint):
		return clean_hint
	if clean_hint == "smith_sword" and _next_sword_ore_cost() > 0:
		return "mine_ore"
	if build_actions.has(clean_hint):
		return "mine_stone"
	return ""


func _first_unsatisfied_doctrine_action_id(source) -> String:
	if typeof(source) != TYPE_ARRAY:
		return ""
	for item in source:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var action_id := str(item.get("affordance_id", item.get("action_id", ""))).strip_edges()
		if action_id != "" and _is_action_available(action_id) and not _doctrine_action_step_satisfied(action_id, source):
			return action_id
	return ""


func _doctrine_action_step_satisfied(action_id: String, source) -> bool:
	match action_id:
		"build_storm_rod":
			return storm_rods.size() > 0
		"build_tower":
			return bow_towers.size() > 0 and _doctrine_plan_has_action(source, ["use_tower", "ranged_attack"])
	return false


func _doctrine_plan_has_action(source, action_ids: Array) -> bool:
	if typeof(source) != TYPE_ARRAY:
		return false
	for item in source:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var action_id := str(item.get("affordance_id", item.get("action_id", ""))).strip_edges()
		if action_ids.has(action_id):
			return true
	return false


func _has_explicit_fallback_agent_plan(result: Dictionary) -> bool:
	var raw_plan = result.get("plan", [])
	if typeof(raw_plan) != TYPE_ARRAY:
		return false
	for step in raw_plan:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var step_id := str(step.get("step_id", ""))
		var reason := str(step.get("reason", ""))
		if step_id.begins_with("local_") or reason.contains("Local sign interpretation") or reason.contains("Doctrine"):
			return true
	return false


func _is_action_available(action_id: String) -> bool:
	var lookup_id := action_id
	if lookup_id == "repair_structure":
		lookup_id = "repair"
	for action in _current_affordances():
		if typeof(action) == TYPE_DICTIONARY and str(action.get("id", "")) == lookup_id:
			return bool(action.get("available", false))
	return false


func _first_available_action_id(preferred := "") -> String:
	var first_id := ""
	for action in _current_affordances():
		if typeof(action) != TYPE_DICTIONARY or not bool(action.get("available", false)):
			continue
		var action_id := str(action.get("id", ""))
		if first_id == "":
			first_id = action_id
		if preferred != "" and action_id == preferred:
			return action_id
	return first_id


func _request_ai_deep_interpretation(show_waiting := true, bypass_cache := false) -> void:
	if ai_bridge == null or not ai_bridge.is_ai_enabled():
		_ai_deep_interpretation_in_flight = false
		_clear_pending_ai_deep_interpretation()
		_finish_ai_waiting()
		_update_ai_idle_status()
		return
	if sign_text.strip_edges() == "":
		_ai_deep_interpretation_in_flight = false
		_clear_pending_ai_deep_interpretation()
		_finish_ai_waiting()
		ai_status = "AI: active"
		_emit_state()
		return
	var signature := _deep_interpretation_signature(bypass_cache)
	if _ai_deep_interpretation_in_flight:
		if signature == _ai_deep_interpretation_in_flight_signature and not bypass_cache:
			return
		_queue_pending_ai_deep_interpretation(show_waiting, bypass_cache)
		return
	_ai_sign_request_id += 1
	var request_id := _ai_sign_request_id
	_ai_deep_interpretation_in_flight = true
	_ai_deep_interpretation_in_flight_signature = signature
	_ai_deep_interpretation_in_flight_sign_text = sign_text.strip_edges()
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
	var applies_to_current_sign := sign_text.strip_edges() == _ai_deep_interpretation_in_flight_sign_text
	_ai_deep_interpretation_in_flight = false
	_ai_deep_interpretation_in_flight_signature = ""
	_ai_deep_interpretation_in_flight_sign_text = ""
	_finish_ai_waiting()
	if not applies_to_current_sign and _ai_deep_interpretation_pending:
		_start_pending_ai_deep_interpretation()
		return
	if not bool(result.get("ok", false)):
		var failure_reason := _ai_failure_reason_label(result)
		ai_status = "AI: failed/fallback" if failure_reason == "" else "AI: failed/fallback (%s)" % failure_reason
		_show_ari_thought("I cannot hear more from the sign. I will use what I understood.", true)
		_emit_state()
		if _ai_deep_interpretation_pending:
			_start_pending_ai_deep_interpretation()
			return
		if _agent_plan_deferred_for_deep_interpretation:
			_agent_plan_deferred_for_deep_interpretation = false
			_request_agent_plan("sign_commit")
		return

	sign_interpretation = str(result.get("interpretation", sign_interpretation))
	sign_grounded_plan = _normalize_grounded_plan(result.get("grounded_plan", []))
	sign_priority_hints = _merge_priority_hints(sign_priority_hints, _priority_hints_from_grounded_plan(sign_grounded_plan), result.get("priority_hints", {}))
	sign_strength = clampf(float(result.get("sign_strength", sign_strength)), 0.0, 1.0)
	sign_resonance = clampf(float(result.get("resonance", sign_resonance)), 0.0, 1.0)
	ai_survival_theory = str(result.get("survival_theory", "")).strip_edges()
	ai_emotion = str(result.get("emotion", "")).strip_edges()
	_refresh_ari_understanding("deep_interpretation")
	var used_cache := bool(result.get("cached", false)) or str(result.get("source", "")) == "cache"
	ai_status = "AI: cached" if used_cache else "AI: active"
	var thought := "I remember this sign." if used_cache else str(result.get("thought", "")).strip_edges()
	if thought == "":
		thought = "Now I see it."
	_show_ari_thought(thought, true)
	_emit_state()
	_agent_plan_deferred_for_deep_interpretation = false
	_request_agent_plan("deep_interpretation")
	if _ai_deep_interpretation_pending:
		_start_pending_ai_deep_interpretation()


func _deep_interpretation_signature(bypass_cache := false) -> String:
	var build_state := _get_run_build_context()
	var world_part := "%d:%s:%d:%d:%d:%d:%d:%d" % [
		day_night.day if day_night != null else 1,
		str(day_night.phase) if day_night != null else "",
		_stone_count(),
		_food_count(),
		_ore_count(),
		walls.size(),
		bow_towers.size(),
		storm_rods.size(),
	]
	return "%s|%s|%s|%s" % [
		sign_text.strip_edges(),
		JSON.stringify(build_state),
		world_part,
		"bypass" if bypass_cache else "cache",
	]


func _queue_pending_ai_deep_interpretation(show_waiting := true, bypass_cache := false) -> void:
	_ai_deep_interpretation_pending = true
	_ai_deep_interpretation_pending_sign_text = sign_text.strip_edges()
	_ai_deep_interpretation_pending_show_waiting = _ai_deep_interpretation_pending_show_waiting or show_waiting
	_ai_deep_interpretation_pending_bypass_cache = _ai_deep_interpretation_pending_bypass_cache or bypass_cache
	if show_waiting and not _ai_waiting_active:
		_begin_ai_waiting()
		_emit_state()


func _clear_pending_ai_deep_interpretation() -> void:
	_ai_deep_interpretation_pending = false
	_ai_deep_interpretation_pending_sign_text = ""
	_ai_deep_interpretation_pending_show_waiting = false
	_ai_deep_interpretation_pending_bypass_cache = false


func _start_pending_ai_deep_interpretation() -> void:
	if not _ai_deep_interpretation_pending:
		return
	var show_waiting := _ai_deep_interpretation_pending_show_waiting
	var bypass_cache := _ai_deep_interpretation_pending_bypass_cache
	_clear_pending_ai_deep_interpretation()
	_request_ai_deep_interpretation(show_waiting, bypass_cache)


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


func _ai_failure_reason_label(result: Dictionary) -> String:
	var reason := str(result.get("failure_reason", result.get("source", ""))).strip_edges().to_lower()
	match reason:
		"timeout", "parse", "auth", "offline", "request_canceled":
			return reason
	if reason.begins_with("http_"):
		return reason
	if reason == "invalid_json":
		return "parse"
	if reason == "request_failed":
		return "request_failed"
	return ""


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
			"survival_theory": ai_survival_theory,
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


func _get_agent_plan_perception() -> Dictionary:
	var report := _get_ai_perception()
	if report.is_empty():
		return {}
	return {
		"phase": report.get("phase", ""),
		"time_left": report.get("time_left", 0.0),
		"is_night": report.get("is_night", false),
		"is_dawn_soon": report.get("is_dawn_soon", false),
		"ari": report.get("ari", {}),
		"resources": report.get("resources", {}),
		"sword_tier": report.get("sword_tier", 0),
		"nearby_enemies": _compact_dictionary_array(report.get("nearby_enemies", []), 4, 120),
		"nearby_structures": _compact_dictionary_array(report.get("nearby_structures", []), 6, 100),
		"tactical_facts": _summary_string_array(report.get("tactical_facts", []), 8, 100),
		"available_safe_moves": _summary_string_array(report.get("available_safe_moves", []), 6, 80),
	}


func _compact_dictionary_array(value, max_count: int, max_text_length: int) -> Array:
	var result := []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		if typeof(item) == TYPE_DICTIONARY:
			var compact := {}
			for key in item.keys():
				var raw_value = item[key]
				if typeof(raw_value) == TYPE_STRING:
					compact[str(key)] = _limit_inline(str(raw_value), max_text_length)
				elif typeof(raw_value) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
					compact[str(key)] = raw_value
			result.append(compact)
		else:
			result.append(_limit_inline(str(item), max_text_length))
		if result.size() >= max_count:
			break
	return result


func _compact_priority_map(value, max_count: int) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	var keys: Array = value.keys()
	keys.sort_custom(func(a, b) -> bool:
		return absf(float(value[a])) > absf(float(value[b]))
	)
	for key in keys:
		var amount := clampf(float(value[key]), -1.0, 1.0)
		if absf(amount) <= 0.0:
			continue
		result[_limit_inline(str(key), 80)] = amount
		if result.size() >= max_count:
			break
	return result


func _compact_grounded_plan(value, max_count: int) -> Array:
	var result := []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var affordance_id := str(item.get("affordance_id", item.get("id", ""))).strip_edges()
		if affordance_id == "":
			continue
		result.append({
			"affordance_id": affordance_id,
			"priority": clampf(float(item.get("priority", 0.0)), 0.0, 1.0),
			"reason": _limit_inline(str(item.get("reason", "")), 120),
		})
		if result.size() >= max_count:
			break
	return result


func _compact_structure_state(value, max_count: int) -> Array:
	var result := []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		if typeof(item) == TYPE_DICTIONARY:
			result.append({
				"type": _limit_inline(str(item.get("type", "")), 60),
				"status": _limit_inline(str(item.get("status", "")), 40),
			})
		if result.size() >= max_count:
			break
	return result


func _compact_doctrine_plan(value, max_count: int) -> Array:
	var result := []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		result.append({
			"affordance_id": _limit_inline(str(item.get("affordance_id", item.get("action_id", ""))), 80),
			"priority": clampf(float(item.get("priority", 0.0)), 0.0, 1.0),
			"reason": _limit_inline(str(item.get("reason", "")), 120),
		})
		if result.size() >= max_count:
			break
	return result


func _compact_doctrine_control(value) -> Dictionary:
	var result := {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	var anchor_kind := str(value.get("preferred_anchor_kind", "")).strip_edges()
	if anchor_kind != "":
		result["preferred_anchor_kind"] = _limit_inline(anchor_kind, 80)
	if value.has("min_hold_seconds"):
		result["min_hold_seconds"] = clampf(float(value.get("min_hold_seconds", 0.0)), 0.0, 120.0)
	var avoid_actions := _summary_string_array(value.get("avoid_action_ids", []), 6, 80)
	if not avoid_actions.is_empty():
		result["avoid_action_ids"] = avoid_actions
	var break_reasons := _summary_string_array(value.get("allowed_break_reasons", []), 6, 80)
	if not break_reasons.is_empty():
		result["allowed_break_reasons"] = break_reasons
	return result


func _refresh_ari_understanding(trigger: String = "") -> void:
	ari_understanding = _build_ari_understanding_packet(trigger)


func _build_ari_understanding_packet(trigger: String = "") -> Dictionary:
	var sky_danger := _understanding_mentions_sky_danger()
	var intended_action := _understanding_intended_action(sky_danger)
	var prerequisite_ladder := _build_understanding_prerequisite_ladder(intended_action, sky_danger)
	var legal_answers := _build_understanding_legal_answers(prerequisite_ladder, sky_danger)
	var active_doctrines := _learned_active_doctrines(_doctrine_context(), 2)
	var memory_relevance := []
	for doctrine in active_doctrines:
		if typeof(doctrine) != TYPE_DICTIONARY:
			continue
		memory_relevance.append({
			"id": _limit_inline(str(doctrine.get("id", "")), 80),
			"summary": _limit_inline(str(doctrine.get("summary", doctrine.get("lesson", ""))), 120),
		})
	var blockers: Array[String] = []
	for step in prerequisite_ladder:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		var status := str(step.get("status", ""))
		if status == "blocked" or status == "needed":
			_summary_append(blockers, str(step.get("reason", "")), 5)
	var evidence_ids: Array[String] = []
	if ari_memory != null:
		for snapshot in ari_memory.get_recent_snapshots(4):
			if typeof(snapshot) == TYPE_DICTIONARY:
				var snapshot_id := str(snapshot.get("snapshot_id", "")).strip_edges()
				if snapshot_id != "":
					_summary_append(evidence_ids, snapshot_id, 4)
	var packet := {
		"schema": ARI_UNDERSTANDING_SCHEMA,
		"trigger": trigger,
		"source": "deterministic",
		"sign_thesis": _understanding_sign_thesis(sky_danger),
		"survival_question": _understanding_survival_question(sky_danger),
		"intended_strategy": _limit_inline(_understanding_intended_strategy(intended_action, sky_danger), 160),
		"legal_answers": legal_answers,
		"prerequisite_ladder": prerequisite_ladder,
		"body_alignment": _compact_body_alignment(_latest_body_alignment),
		"blockers": _summary_string_array(blockers, 5, 90),
		"memory_relevance": memory_relevance,
		"evidence_ids": evidence_ids,
		"display_line": _understanding_display_line(intended_action, sky_danger),
		"confidence": 0.62 if sky_danger or intended_action != "" else 0.35,
	}
	return packet


func _understanding_mentions_sky_danger() -> bool:
	var text := "%s %s %s" % [sign_text, sign_interpretation, ai_survival_theory]
	text = text.to_lower()
	if text.contains("wing") or text.contains("flying") or text.contains("sky") or text.contains("storm"):
		return true
	for key in sign_priority_hints.keys():
		var action_id := str(key)
		if ["build_storm_rod", "anti_flying", "anti_air_defense", "sky_answer"].has(action_id) and float(sign_priority_hints[key]) > 0.0:
			return true
	var enemy_types := _get_enemy_type_counts()
	return int(enemy_types.get("flying", 0)) > 0


func _understanding_intended_action(sky_danger: bool) -> String:
	var current_agent_action := _current_agent_step_action_id()
	if current_agent_action != "":
		return current_agent_action
	var active_plan := _active_agent_grounded_plan()
	if not active_plan.is_empty() and typeof(active_plan[0]) == TYPE_DICTIONARY:
		var planned := str(active_plan[0].get("affordance_id", active_plan[0].get("action_id", ""))).strip_edges()
		if planned != "":
			return planned
	if sky_danger:
		return "build_storm_rod"
	if not sign_grounded_plan.is_empty() and typeof(sign_grounded_plan[0]) == TYPE_DICTIONARY:
		return str(sign_grounded_plan[0].get("affordance_id", "")).strip_edges()
	return _local_fallback_agent_action_id(true)


func _understanding_sign_thesis(sky_danger: bool) -> String:
	if sign_text.strip_edges() == "":
		return "Ari has no sign yet, so survival defaults to local caution."
	if sky_danger:
		return "Ari reads the sign as a sky or wing danger that ordinary walls may not answer."
	if sign_interpretation.strip_edges() != "":
		return _limit_inline(sign_interpretation, 160)
	return "Ari has a freeform sign, but only a local survival reading so far."


func _understanding_survival_question(sky_danger: bool) -> String:
	if sky_danger:
		return "How can Ari answer the sky before wings reach him?"
	if sign_text.strip_edges() == "":
		return "What keeps Ari alive until the next readable sign?"
	return "What concrete legal action best preserves Ari while respecting the sign?"


func _understanding_intended_strategy(intended_action: String, sky_danger: bool) -> String:
	if sky_danger:
		if storm_rods.size() <= 0:
			return "Gather what is needed, build a Storm Rod, then use height or cover as support."
		return "Use the built sky answer, then keep range and cover ready."
	if intended_action != "":
		return "Progress toward %s without letting model output move Ari's body directly." % _understanding_action_name(intended_action)
	return "Watch danger, preserve HP, and use local fallback safety."


func _understanding_display_line(intended_action: String, sky_danger: bool) -> String:
	if sky_danger:
		if storm_rods.size() <= 0:
			return "Ari thinks: wings mean sky answer; get Storm Rod ready."
		return "Ari thinks: sky answer exists; keep range alive."
	if intended_action != "":
		return "Ari thinks: %s is the current survival answer." % _understanding_action_name(intended_action)
	return "Ari thinks: stay alive while the sign stays unclear."


func _build_understanding_prerequisite_ladder(intended_action: String, sky_danger: bool) -> Array:
	var ladder := []
	var is_night: bool = day_night != null and day_night.is_night()
	if sky_danger or intended_action == "build_storm_rod":
		var storm_cost := int(_get_storm_rod_cost().get("stone", 0))
		if storm_rods.size() <= 0:
			if _stone_count() < storm_cost:
				_append_understanding_step(ladder, "mine_stone", "needed", "Need %d stone for Storm Rod; Ari has %d." % [storm_cost, _stone_count()], not is_night)
				_append_understanding_step(ladder, "build_storm_rod", "blocked", "Needs stone before the sky answer can be built.", false)
			else:
				_append_understanding_step(ladder, "build_storm_rod", "ready", "Enough stone exists for the sky answer.", _is_action_available("build_storm_rod"))
		else:
			_append_understanding_step(ladder, "build_storm_rod", "accepted", "Storm Rod already exists.", true)
		if bow_towers.size() <= 0:
			var tower_cost := int(_get_bow_tower_cost().get("stone", 0))
			var tower_status := "ready" if _stone_count() >= tower_cost and not is_night else "later"
			_append_understanding_step(ladder, "build_tower", tower_status, "Height supports the sky answer after Storm Rod.", _is_action_available("build_tower"))
		else:
			_append_understanding_step(ladder, "use_tower", "ready", "Tower range can support anti-flying defense.", _is_action_available("use_tower"))
	if ladder.is_empty() and intended_action != "":
		_append_understanding_step(ladder, intended_action, "ready" if _is_action_available(intended_action) else "blocked", "Current sign or planner action.", _is_action_available(intended_action))
	return ladder


func _append_understanding_step(ladder: Array, action_id: String, status: String, reason: String, available: bool) -> void:
	if action_id.strip_edges() == "" or ladder.size() >= 6:
		return
	ladder.append({
		"action_id": action_id,
		"status": status,
		"available": available,
		"reason": _limit_inline(reason, 120),
	})


func _build_understanding_legal_answers(prerequisite_ladder: Array, sky_danger: bool) -> Array:
	var relevant := _understanding_relevant_actions(prerequisite_ladder, sky_danger)
	var answers := []
	for action in _current_agent_legal_actions():
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var action_id := str(action.get("id", "")).strip_edges()
		if action_id == "":
			continue
		if not relevant.has(action_id) and answers.size() >= 6:
			continue
		var entry := {
			"action_id": action_id,
			"available": bool(action.get("available", true)),
			"role": _understanding_action_role(action_id),
			"reason_unavailable": _limit_inline(str(action.get("reason_unavailable", "")), 80),
			"_score": _understanding_action_score(action_id, relevant, bool(action.get("available", true))),
		}
		answers.append(entry)
	answers.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return float(left.get("_score", 0.0)) > float(right.get("_score", 0.0))
	)
	var capped := []
	for entry in answers:
		var clean: Dictionary = entry.duplicate(true)
		clean.erase("_score")
		if str(clean.get("reason_unavailable", "")) == "":
			clean.erase("reason_unavailable")
		capped.append(clean)
		if capped.size() >= 8:
			break
	return capped


func _understanding_relevant_actions(prerequisite_ladder: Array, sky_danger: bool) -> Dictionary:
	var relevant := {}
	for step in prerequisite_ladder:
		if typeof(step) == TYPE_DICTIONARY:
			relevant[str(step.get("action_id", ""))] = true
	if sky_danger:
		for action_id in ["build_storm_rod", "mine_stone", "build_tower", "use_tower", "use_cover", "flee"]:
			relevant[action_id] = true
	for key in sign_priority_hints.keys():
		if float(sign_priority_hints[key]) > 0.0:
			relevant[str(key)] = true
	return relevant


func _understanding_action_score(action_id: String, relevant: Dictionary, available: bool) -> float:
	var score := 10.0 if available else 0.0
	if relevant.has(action_id):
		score += 100.0
	score += clampf(float(sign_priority_hints.get(action_id, 0.0)), 0.0, 1.0) * 30.0
	if action_id == _current_agent_step_action_id():
		score += 40.0
	if ["build_storm_rod", "mine_stone", "build_tower", "use_tower"].has(action_id):
		score += 10.0
	return score


func _understanding_action_role(action_id: String) -> String:
	match action_id:
		"mine_stone":
			return "prerequisite"
		"build_storm_rod":
			return "sky_answer"
		"build_tower", "use_tower":
			return "range_support"
		"use_cover", "flee", "stall_until_dawn", "hide_until_dawn":
			return "safety_fallback"
		"repair_structure":
			return "preserve_support"
	return "legal_action"


func _compact_ari_understanding(value, max_ladder: int) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	if str(value.get("schema", "")) != ARI_UNDERSTANDING_SCHEMA:
		return {}
	var compact := {
		"schema": ARI_UNDERSTANDING_SCHEMA,
		"sign_thesis": _limit_inline(str(value.get("sign_thesis", "")), 140),
		"survival_question": _limit_inline(str(value.get("survival_question", "")), 120),
		"intended_strategy": _limit_inline(str(value.get("intended_strategy", "")), 140),
		"prerequisite_ladder": _compact_understanding_ladder(value.get("prerequisite_ladder", []), max_ladder),
		"body_alignment": _compact_body_alignment(value.get("body_alignment", {})),
		"display_line": _limit_inline(str(value.get("display_line", "")), 120),
	}
	var legal_answers := []
	for answer in value.get("legal_answers", []):
		if typeof(answer) != TYPE_DICTIONARY:
			continue
		legal_answers.append({
			"action_id": _limit_inline(str(answer.get("action_id", "")), 80),
			"available": bool(answer.get("available", true)),
			"role": _limit_inline(str(answer.get("role", "")), 60),
		})
		if legal_answers.size() >= 5:
			break
	compact["legal_answers"] = legal_answers
	return compact


func _compact_ari_understanding_for_prediction(value) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	if str(value.get("schema", "")) != ARI_UNDERSTANDING_SCHEMA:
		return {}
	var ladder := []
	for step in value.get("prerequisite_ladder", []):
		if typeof(step) != TYPE_DICTIONARY:
			continue
		ladder.append({
			"action_id": _limit_inline(str(step.get("action_id", "")), 50),
			"status": _limit_inline(str(step.get("status", "")), 24),
		})
		if ladder.size() >= 2:
			break
	var alignment := _compact_body_alignment(value.get("body_alignment", {}))
	var compact := {
		"schema": ARI_UNDERSTANDING_SCHEMA,
		"survival_question": _limit_inline(str(value.get("survival_question", "")), 60),
		"prerequisite_ladder": ladder,
	}
	if not alignment.is_empty():
		compact["body_alignment"] = {
			"relation": alignment.get("relation", ""),
			"planned_action": alignment.get("planned_action", ""),
			"body_job": alignment.get("body_job", ""),
		}
	return compact


func _compact_understanding_ladder(value, max_count: int) -> Array:
	var result := []
	if typeof(value) != TYPE_ARRAY:
		return result
	for step in value:
		if typeof(step) != TYPE_DICTIONARY:
			continue
		result.append({
			"action_id": _limit_inline(str(step.get("action_id", "")), 80),
			"status": _limit_inline(str(step.get("status", "")), 40),
			"available": bool(step.get("available", false)),
			"reason": _limit_inline(str(step.get("reason", "")), 100),
		})
		if result.size() >= max_count:
			break
	return result


func _compact_body_alignment(value) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var relation := str(value.get("relation", "")).strip_edges()
	if relation == "":
		return {}
	return {
		"relation": _limit_inline(relation, 40),
		"planned_action": _limit_inline(str(value.get("planned_action", "")), 80),
		"body_job": _limit_inline(str(value.get("body_job", "")), 80),
		"body_action": _limit_inline(str(value.get("body_action", "")), 80),
		"reason": _limit_inline(str(value.get("reason", "")), 120),
		"confidence": clampf(float(value.get("confidence", 0.5)), 0.0, 1.0),
	}


func _build_body_alignment_trace(decision: Dictionary, context: Dictionary = {}) -> Dictionary:
	var raw_job := str(decision.get("job", decision.get("current_job", ""))).strip_edges()
	if raw_job == "" and ari != null and ari.has_method("get_current_job"):
		raw_job = str(ari.call("get_current_job"))
	var body_action := _normalize_body_job_action(raw_job)
	var planned_action := _planned_action_from_context(context)
	var relation := "unknown"
	if planned_action == "":
		relation = "unknown"
	elif _body_actions_equivalent(body_action, planned_action):
		relation = "accepted"
	elif _body_job_is_prerequisite(body_action, planned_action):
		relation = "prerequisite_progress"
	elif _body_job_is_safety_substitution(body_action, planned_action, context):
		relation = "safety_substitution"
	elif not _is_action_available(planned_action):
		relation = "blocked"
	else:
		relation = "mismatch"
	var trace := {
		"schema": "ari.body_alignment.v1",
		"relation": relation,
		"planned_action": planned_action,
		"body_job": raw_job,
		"body_action": body_action,
		"body_reason": _limit_inline(str(decision.get("reason", "")), 120),
		"reason": _body_alignment_reason(relation, body_action, planned_action, decision),
		"confidence": 0.8 if relation in ["accepted", "prerequisite_progress", "safety_substitution"] else 0.55,
	}
	_latest_body_alignment = trace.duplicate(true)
	return trace


func _planned_action_from_context(context: Dictionary) -> String:
	var planned := _current_agent_step_action_id()
	if planned != "":
		return planned
	var current_plan = context.get("current_plan", {})
	if typeof(current_plan) == TYPE_DICTIONARY:
		planned = str(current_plan.get("current_action", current_plan.get("next_action", ""))).strip_edges()
		if planned != "":
			return planned
	var grounded = context.get("agent_grounded_plan", [])
	if typeof(grounded) == TYPE_ARRAY and not grounded.is_empty() and typeof(grounded[0]) == TYPE_DICTIONARY:
		planned = str(grounded[0].get("affordance_id", grounded[0].get("action_id", ""))).strip_edges()
		if planned != "":
			return planned
	return _local_fallback_agent_action_id(true)


func _normalize_body_job_action(job: String) -> String:
	var clean := job.strip_edges()
	match clean:
		"build_bow_tower":
			return "build_tower"
		"moving_to_build_site":
			return "build_site"
		"moving_to_mine", "mining":
			return "mine_stone"
		"mining_ore":
			return "mine_ore"
		"moving_to_repair_structure":
			return "repair_structure"
		"moving_to_tower", "using_tower_perch":
			return "use_tower"
		"moving_to_cover", "waiting_near_defenses":
			return "use_cover"
		"moving_to_aura_lure", "luring_through_aura":
			return "lure_to_aura"
		"moving_to_tar_lure":
			return "lure_to_tar_pit"
		"moving_to_use_fear_lantern":
			return "use_fear_lantern"
		"moving_to_decoy":
			return "use_decoy_idol"
		"moving_to_use_thorns":
			return "use_thorns"
		"moving_to_bed":
			return "rest"
		"moving_to_farm":
			return "farm_food"
		"moving_to_train":
			return "train_combat"
		"moving_to_fight_head_on":
			return "fight_head_on"
	return clean


func _body_actions_equivalent(body_action: String, planned_action: String) -> bool:
	if body_action == "" or planned_action == "":
		return false
	if body_action == planned_action:
		return true
	if body_action == "build_site" and (planned_action.begins_with("build_") or planned_action.begins_with("place_")):
		return true
	if body_action == "use_cover" and ["hide_until_dawn", "stall_until_dawn"].has(planned_action):
		return true
	return false


func _body_job_is_prerequisite(body_action: String, planned_action: String) -> bool:
	if body_action == "" or planned_action == "":
		return false
	if body_action == "mine_stone" and (planned_action.begins_with("build_") or planned_action.begins_with("place_") or ["repair_structure", "use_tower", "build_storm_rod"].has(planned_action)):
		return true
	if body_action == "mine_ore" and ["smith_sword", "fight_head_on", "train_sword"].has(planned_action):
		return true
	if body_action in ["train_combat", "train_sword"] and planned_action in ["fight_head_on", "smith_sword"]:
		return true
	if body_action == "repair_structure" and planned_action in ["use_tower", "use_cover", "build_storm_rod", "lure_to_aura"]:
		return true
	if body_action in ["farm_food", "eat_food", "rest"] and planned_action in ["fight_head_on", "use_tower", "build_storm_rod", "use_cover"]:
		return true
	return false


func _body_job_is_safety_substitution(body_action: String, _planned_action: String, context: Dictionary) -> bool:
	if not ["use_cover", "flee", "stall_until_dawn", "hide_until_dawn", "eat_food", "rest"].has(body_action):
		return false
	var needs = context.get("needs", {})
	var hp_ratio := float(context.get("ari_hp_ratio", _get_ari_hp_ratio()))
	var fear := float(needs.get("fear", 0.0)) if typeof(needs) == TYPE_DICTIONARY else 0.0
	var hunger := float(needs.get("hunger", 0.0)) if typeof(needs) == TYPE_DICTIONARY else 0.0
	var enemy_count := int(context.get("enemy_count", enemies.size()))
	return hp_ratio <= 0.35 or fear >= 70.0 or hunger >= 80.0 or enemy_count > 0 or (day_night != null and day_night.is_night())


func _body_alignment_reason(relation: String, body_action: String, planned_action: String, decision: Dictionary) -> String:
	if relation == "prerequisite_progress":
		if body_action == "mine_stone":
			return "Mining stone unlocks %s." % _understanding_action_name(planned_action)
		if body_action == "mine_ore":
			return "Mining ore unlocks %s." % _understanding_action_name(planned_action)
		if body_action == "repair_structure":
			return "Repair preserves support for %s." % _understanding_action_name(planned_action)
		return "%s prepares %s." % [_understanding_action_name(body_action), _understanding_action_name(planned_action)]
	if relation == "safety_substitution":
		return "%s is safer than forcing %s under pressure." % [_understanding_action_name(body_action), _understanding_action_name(planned_action)]
	if relation == "accepted":
		return "Ari's body is executing %s." % _understanding_action_name(planned_action)
	if relation == "blocked":
		return "%s is blocked by current preconditions." % _understanding_action_name(planned_action)
	if relation == "mismatch":
		return "%s does not currently support %s." % [_understanding_action_name(body_action), _understanding_action_name(planned_action)]
	return _limit_inline(str(decision.get("reason", "")), 120)


func _body_alignment_summary_line(alignment: Dictionary) -> String:
	var relation := str(alignment.get("relation", "")).strip_edges()
	var planned := str(alignment.get("planned_action", "")).strip_edges()
	var body := str(alignment.get("body_action", alignment.get("body_job", ""))).strip_edges()
	var reason := str(alignment.get("reason", "")).strip_edges()
	if reason != "":
		return reason
	if relation == "prerequisite_progress":
		return "%s prepared %s." % [_understanding_action_name(body), _understanding_action_name(planned)]
	if relation == "safety_substitution":
		return "%s safely substituted for %s." % [_understanding_action_name(body), _understanding_action_name(planned)]
	if relation == "mismatch":
		return "%s diverged from %s." % [_understanding_action_name(body), _understanding_action_name(planned)]
	return "%s matched %s." % [_understanding_action_name(body), _understanding_action_name(planned)]


func _understanding_action_name(action_id: String) -> String:
	match action_id:
		"build_storm_rod":
			return "Storm Rod"
		"mine_stone":
			return "mining stone"
		"build_tower":
			return "tower"
		"use_tower":
			return "tower range"
		"use_cover":
			return "cover"
		"flee":
			return "distance"
		"repair_structure":
			return "repair"
		"lure_to_aura":
			return "aura lure"
		"fight_head_on":
			return "melee"
		"smith_sword":
			return "sword forge"
	return action_id.replace("_", " ")


func _current_affordances() -> Array:
	var stone := _stone_count()
	var food := _food_count()
	var ore := _ore_count()
	var is_night: bool = day_night != null and day_night.is_night()
	var has_wall := walls.size() > 0
	var has_aura := aura_orbs.size() > 0
	var has_tower := bow_towers.size() > 0
	var has_tar_pit := tar_pits.size() > 0
	var has_fear_lantern := fear_lanterns.size() > 0
	var has_decoy := decoy_idols.size() > 0
	var has_forge := forge_station != null
	var next_sword_cost := _next_sword_ore_cost()
	var damaged_count := _get_damaged_structure_count()
	return [
		_affordance("mine_stone", "Mine stone for structures and defenses.", not is_night, "night prevents mining"),
		_affordance("mine_ore", "Mine low-tier ore for sword upgrades at the forge.", not is_night, "night prevents mining"),
		_affordance("build_wall", "Spend stone to build a new wall block.", not is_night and stone >= int(_get_wall_cost().get("stone", 0)), "night prevents building" if is_night else "not enough stone"),
		_affordance("use_existing_wall", "Move near an existing wall so enemies must hit or go around it before reaching Ari.", has_wall, "no wall exists"),
		_affordance("wait_behind_wall", "Wait on the safe side of an existing wall.", has_wall, "no wall exists"),
		_affordance("use_cover", "Use current cover instead of adding a new structure.", has_wall or has_tower, "no cover exists"),
		_affordance("place_aura_orb", "Spend stone to place an Aura Orb that damages enemies inside its circle.", not is_night and stone >= int(_get_aura_orb_cost().get("stone", 0)), "night prevents building" if is_night else "not enough stone"),
		_affordance("lure_to_aura", "Stand near the safe side of an Aura Orb so enemies pass through the damaging circle.", has_aura, "no Aura Orb exists"),
		_affordance("train_combat", "Practice at the training dummy to improve combat readiness.", not is_night, "night prevents training"),
		_affordance("train_sword", "Practice sword handling at the training dummy.", not is_night, "night prevents training"),
		_affordance("prepare_weapon", "Prepare Ari for direct danger through combat training.", not is_night, "night prevents training"),
		_affordance("build_forge", "Forge station is already present in this prototype.", false, "forge already exists"),
		_affordance("smith_sword", "Spend ore at the forge to improve Ari's sword tier.", not is_night and has_forge and next_sword_cost > 0 and ore >= next_sword_cost, "night prevents smithing" if is_night else "need ore or max sword"),
		_affordance("fight_head_on", "Use direct melee combat against ground enemies.", enemies.size() > 0, "no enemy to fight"),
		_affordance("use_armor", "Lean on armor and defense stats when contact is unavoidable.", true),
		_affordance("rely_on_regen", "Treat passive or kill recovery as support, not a direct command.", true),
		_affordance("regen_on_kill", "Recover HP after kills if the current build supports it.", true),
		_affordance("build_tower", "Spend stone to build a bow tower for height and ranged safety.", not is_night and stone >= int(_get_bow_tower_cost().get("stone", 0)), "night prevents building" if is_night else "not enough stone"),
		_affordance("use_tower", "Use an existing tower perch to keep distance from ground enemies.", has_tower, "no tower exists"),
		_affordance("ranged_attack", "Attack from tower range when a tower and target exist.", has_tower, "no tower exists"),
		_affordance("train_bow", "Practice ranged thinking through tower and combat preparation.", not is_night, "night prevents training"),
		_affordance("farm_food", "Work the farm plot to create food.", not is_night, "night prevents farming"),
		_affordance("eat_food", "Eat stored food to lower hunger pressure.", food > 0, "no food stored"),
		_affordance("eat", "Use food as survival support when any is stored.", food > 0, "no food stored"),
		_affordance("rest", "Rest at the bed to recover HP, stamina, and fear.", not is_night, "night prevents resting"),
		_affordance("reflect_library", "Go to the library to turn recent events into a lesson.", not is_night and _get_meaningful_event_count() > 0, "night prevents library reflection" if is_night else "no fresh meaningful event"),
		_affordance("repair", "Repair a damaged structure.", not is_night and damaged_count > 0, "night prevents repair" if is_night else "nothing is damaged"),
		_affordance("flee", "Move away from immediate danger.", true),
		_affordance("kite", "Keep distance while danger approaches.", true),
		_affordance("hide", "Stay near safer cover and avoid direct contact.", has_wall or has_aura or has_tower, "no safe place exists"),
		_affordance("stall_until_dawn", "Delay and stay alive until sunrise clears the night pressure.", true),
		_affordance("hide_until_dawn", "Use cover and distance to survive until dawn.", has_wall or has_aura or has_tower, "no safe place exists"),
		_affordance("avoid_killing", "Avoid unnecessary direct kills when survival until morning is the goal.", true),
		_affordance("survive_until_morning", "Prioritize lasting until dawn instead of clearing every enemy.", true),
		_affordance("fight", "Accept direct combat if avoidance fails.", true),
		_affordance("build_storm_rod", "Build a Storm Rod as an anti-flying sky defense.", not is_night and stone >= int(_get_storm_rod_cost().get("stone", 0)), "night prevents building" if is_night else "not enough stone"),
		_affordance("anti_flying", "Prioritize answers that work against flying enemies.", true),
		_affordance("sky_answer", "Treat the sky as the threat and prefer storm or range over walls alone.", true),
		_affordance("build_spike_trap", "Spend stone to build a spike trap that punishes enemies on the ground.", not is_night and stone >= int(_get_spike_trap_cost().get("stone", 0)), "night prevents building" if is_night else "not enough stone"),
		_affordance("build_tar_pit", "Spend stone to build a tar pit that slows enemies.", not is_night and stone >= int(_get_tar_pit_cost().get("stone", 0)), "night prevents building" if is_night else "not enough stone"),
		_affordance("lure_to_tar_pit", "Stand on the safe side of a tar pit so ground enemies cross slow mud before reaching Ari.", has_tar_pit, "no tar pit exists"),
		_affordance("build_fear_lantern", "Spend stone to build a lantern that helps calm fear.", not is_night and stone >= int(_get_fear_lantern_cost().get("stone", 0)), "night prevents building" if is_night else "not enough stone"),
		_affordance("use_fear_lantern", "Hold position inside a Fear Lantern radius so fear calms and enemy damage is softened.", has_fear_lantern, "no Fear Lantern exists"),
		_affordance("build_decoy_idol", "Spend stone to build a decoy that pulls enemies away.", not is_night and stone >= int(_get_decoy_idol_cost().get("stone", 0)), "night prevents building" if is_night else "not enough stone"),
		_affordance("use_decoy_idol", "Keep the decoy between Ari and enemies so the false Ari takes pressure first.", has_decoy, "no decoy exists"),
		_affordance("build_thorn_totem", "Spend stone to build thorns that punish contact.", not is_night and stone >= int(_get_thorn_totem_cost().get("stone", 0)), "night prevents building" if is_night else "not enough stone"),
		_affordance("build_repair_bench", "Spend stone to build repair support for damaged defenses.", not is_night and stone >= int(_get_repair_bench_cost().get("stone", 0)), "night prevents building" if is_night else "not enough stone"),
		_affordance("use_thorns", "Lean on thorn defenses to punish enemies that touch Ari's protection.", thorn_totems.size() > 0, "no thorns exist"),
	]


func _current_agent_legal_actions() -> Array:
	var result := []
	for action in _current_affordances():
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var action_id := str(action.get("id", "")).strip_edges()
		if action_id == "repair":
			var repair_action: Dictionary = action.duplicate(true)
			repair_action["id"] = "repair_structure"
			repair_action["description"] = "Repair a damaged structure."
			result.append(repair_action)
			continue
		if action_id == "eat_food" and _agent_should_withhold_eat_food_action():
			continue
		if AGENT_NONEXECUTABLE_ACTION_IDS.has(action_id):
			continue
		result.append(action)
	return result


func _current_agent_legal_actions_compact() -> Array:
	var result := []
	for action in _current_agent_legal_actions():
		if typeof(action) != TYPE_DICTIONARY:
			continue
		var compact := {
			"id": _limit_inline(str(action.get("id", "")), 80),
			"available": bool(action.get("available", true)),
		}
		var reason := str(action.get("reason_unavailable", "")).strip_edges()
		if reason != "":
			compact["reason_unavailable"] = _limit_inline(reason, 80)
		result.append(compact)
	return result


func _build_action_control_panel(max_actions := ACTION_CONTROL_PANEL_DEFAULT_CAP) -> Dictionary:
	var actions := []
	for action in _current_agent_legal_actions():
		if typeof(action) != TYPE_DICTIONARY:
			continue
		actions.append(_action_control_entry(action))
	actions.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_score := float(left.get("_score", 0.0))
		var right_score := float(right.get("_score", 0.0))
		if is_equal_approx(left_score, right_score):
			return str(left.get("id", "")) < str(right.get("id", ""))
		return left_score > right_score
	)
	var capped := []
	for entry in actions:
		var clean_entry: Dictionary = entry.duplicate(true)
		clean_entry.erase("_score")
		capped.append(clean_entry)
		if capped.size() >= max_actions:
			break
	return {
		"schema": "ari.action_control_panel.v1",
		"objective": "Choose or bias one legal action id. Godot executes the body and validates every precondition.",
		"engine_owns": ["movement", "combat", "building", "resources", "damage", "collision", "pathfinding"],
		"llm_may": ["rank legal actions", "explain risk", "suggest priority_hints", "flag blockers"],
		"actions": capped,
	}


func _action_control_entry(action: Dictionary) -> Dictionary:
	var action_id := _limit_inline(str(action.get("id", "")), 80)
	var available := bool(action.get("available", true))
	var entry := {
		"id": action_id,
		"available": available,
		"category": _action_control_category(action_id),
		"description": _limit_inline(str(action.get("description", "")), 140),
		"counters": _action_control_counters(action_id),
		"enables": _action_control_enables(action_id),
		"preconditions": _action_control_preconditions(action_id),
		"good_when": _action_control_good_when(action_id),
		"failure_modes": _action_control_failure_modes(action_id),
		"cost": _action_control_cost(action_id),
		"_score": _action_control_score(action_id, available),
	}
	var reason := str(action.get("reason_unavailable", "")).strip_edges()
	if reason != "":
		entry["reason_unavailable"] = _limit_inline(reason, 80)
	return entry


func _action_control_score(action_id: String, available: bool) -> float:
	var score := 100.0 if available else 0.0
	score += _action_control_base_priority(action_id)
	var risk_types := _current_action_risk_types()
	for counter in _action_control_counters(action_id):
		if risk_types.has(str(counter)):
			score += 80.0
	var current_next := _action_choice_id(agent_plan.get("next_action", {})) if typeof(agent_plan) == TYPE_DICTIONARY else ""
	if current_next == action_id:
		score += 40.0
	if sign_priority_hints.has(action_id):
		score += clampf(float(sign_priority_hints.get(action_id, 0.0)), 0.0, 1.0) * 35.0
	return score


func _current_action_risk_types() -> Dictionary:
	var risk_types := {}
	var enemy_counts := _get_enemy_type_counts()
	for enemy_type in enemy_counts.keys():
		if int(enemy_counts[enemy_type]) > 0:
			risk_types[str(enemy_type)] = true
	var nearest := _observer_nearest_danger()
	var nearest_type := str(nearest.get("type", "")).strip_edges()
	if nearest_type != "" and nearest_type != "none":
		risk_types[nearest_type] = true
	return risk_types


func _action_control_base_priority(action_id: String) -> float:
	match action_id:
		"build_storm_rod":
			return 34.0
		"use_cover", "flee", "stall_until_dawn", "hide_until_dawn":
			return 30.0
		"build_wall", "repair_structure", "use_tower", "build_tower", "place_aura_orb", "lure_to_aura":
			return 24.0
		"mine_stone", "mine_ore", "farm_food", "eat_food", "rest":
			return 18.0
		"build_spike_trap", "build_tar_pit", "build_fear_lantern", "build_decoy_idol", "build_thorn_totem", "build_repair_bench":
			return 14.0
		"fight_head_on", "train_combat", "train_sword", "smith_sword":
			return 12.0
	return 4.0


func _action_control_category(action_id: String) -> String:
	if action_id.begins_with("build_") or action_id == "place_aura_orb":
		return "build"
	if action_id.begins_with("use_") or action_id.begins_with("lure_") or action_id in ["stall_until_dawn", "hide_until_dawn"]:
		return "position"
	if action_id.begins_with("mine_") or action_id in ["farm_food", "eat_food", "rest", "reflect_library"]:
		return "resource"
	if action_id.begins_with("train_") or action_id in ["smith_sword", "fight_head_on"]:
		return "combat"
	if action_id in ["flee"]:
		return "movement"
	if action_id.begins_with("repair"):
		return "repair"
	return "survival"


func _action_control_counters(action_id: String) -> Array:
	match action_id:
		"build_storm_rod":
			return ["flying"]
		"build_tower", "use_tower":
			return ["ground", "zombie", "runner"]
		"place_aura_orb", "lure_to_aura":
			return ["ground", "zombie", "brute", "runner"]
		"build_spike_trap", "build_tar_pit", "lure_to_tar_pit":
			return ["ground", "runner", "brute"]
		"build_wall", "repair_structure", "use_cover":
			return ["ground", "zombie", "runner"]
		"build_fear_lantern", "use_fear_lantern":
			return ["fear", "contact"]
		"build_decoy_idol", "use_decoy_idol", "flee", "stall_until_dawn", "hide_until_dawn":
			return ["contact", "overwhelm"]
		"fight_head_on", "train_combat", "train_sword", "smith_sword":
			return ["melee"]
	return []


func _action_control_enables(action_id: String) -> Array:
	match action_id:
		"mine_stone":
			return ["build_wall", "build_tower", "build_storm_rod", "place_aura_orb", "repair_structure"]
		"mine_ore":
			return ["smith_sword"]
		"build_tower":
			return ["use_tower"]
		"place_aura_orb":
			return ["lure_to_aura"]
		"build_tar_pit":
			return ["lure_to_tar_pit"]
		"build_fear_lantern":
			return ["use_fear_lantern"]
		"build_decoy_idol":
			return ["use_decoy_idol"]
	return []


func _action_control_preconditions(action_id: String) -> Array:
	match action_id:
		"mine_stone", "mine_ore", "farm_food", "rest", "reflect_library", "train_combat", "train_sword":
			return ["daytime_body_work"]
		"build_wall", "place_aura_orb", "build_tower", "build_storm_rod", "build_spike_trap", "build_tar_pit", "build_fear_lantern", "build_decoy_idol", "build_thorn_totem", "build_repair_bench":
			return ["daytime_building", "stone_available"]
		"repair_structure":
			return ["daytime_repair", "damaged_structure", "reachable_structure"]
		"smith_sword":
			return ["daytime_forge", "ore_available"]
		"use_cover":
			return ["living_wall_or_tower", "reachable_cover"]
		"use_tower":
			return ["living_bow_tower", "reachable_perch"]
		"lure_to_aura":
			return ["living_aura_orb", "reachable_light_edge"]
		"lure_to_tar_pit":
			return ["living_tar_pit", "reachable_slow_ground"]
		"use_fear_lantern":
			return ["living_fear_lantern", "inside_lantern_radius"]
		"use_decoy_idol":
			return ["living_decoy_idol", "decoy_between_ari_and_enemy"]
		"use_thorns":
			return ["living_thorn_totem", "contact_is_unavoidable"]
		"fight_head_on":
			return ["enemy_present", "combat_ready", "hp_margin"]
		"eat_food":
			return ["food_stored", "safe_enough_to_eat"]
		"flee", "kite":
			return ["path_available"]
	return []


func _action_control_good_when(action_id: String) -> Array:
	match action_id:
		"mine_stone":
			return ["resource_blocker:stone", "daytime_before_night"]
		"mine_ore":
			return ["blade_plan", "ore_blocker"]
		"build_wall", "use_cover":
			return ["ground_enemy_pressure", "needs_contact_delay"]
		"place_aura_orb", "lure_to_aura":
			return ["ground_enemy_pressure", "need_damage_zone"]
		"build_tower", "use_tower":
			return ["ground_enemy_at_range", "tower_has_support"]
		"build_storm_rod":
			return ["flying_enemy_seen", "sky_risk"]
		"build_tar_pit", "lure_to_tar_pit":
			return ["brute_or_runner_pressure", "need_slow_ground"]
		"build_fear_lantern", "use_fear_lantern":
			return ["fear_high", "contact_damage_needs_softening"]
		"build_decoy_idol", "use_decoy_idol":
			return ["overwhelmed", "need_enemy_distraction"]
		"build_thorn_totem", "use_thorns":
			return ["armor_ready", "contact_is_planned"]
		"repair_structure", "build_repair_bench":
			return ["defense_plan_working_but_damaged", "structure_pressure"]
		"train_combat", "train_sword", "smith_sword", "fight_head_on":
			return ["blade_plan", "melee_is_intended"]
		"eat_food", "farm_food":
			return ["hunger_pressure"]
		"rest":
			return ["low_hp_or_fear", "defenses_ready"]
		"flee", "kite", "stall_until_dawn", "hide_until_dawn":
			return ["danger_too_close", "survive_until_morning"]
	return []


func _action_control_failure_modes(action_id: String) -> Array:
	match action_id:
		"mine_stone", "mine_ore", "farm_food", "train_combat", "train_sword", "smith_sword":
			return ["unsafe_when_enemies_close", "night_blocks_action"]
		"build_wall", "use_cover":
			return ["flying_bypasses_wall", "brute_can_break_wall"]
		"build_tower", "use_tower":
			return ["brute_or_runner_can_destroy_support", "fails_without_repair_or_slow_ground"]
		"build_storm_rod":
			return ["too_late_after_flying_contact", "needs_stone_before_night"]
		"place_aura_orb", "lure_to_aura":
			return ["fails_if_aura_breaks", "requires_positioning"]
		"build_tar_pit", "lure_to_tar_pit":
			return ["does_not_stop_flying", "fails_if_enemy_bypasses_lane"]
		"repair_structure", "build_repair_bench":
			return ["cannot_repair_at_night", "too_late_if_structure_collapses"]
		"fight_head_on":
			return ["low_hp_or_group_pressure", "runners_and_brutes_punish_contact"]
		"eat_food", "rest":
			return ["unsafe_with_active_contact"]
		"flee", "kite":
			return ["cornered_or_low_stamina"]
	return []


func _action_control_cost(action_id: String) -> Dictionary:
	match action_id:
		"build_wall":
			return _get_wall_cost()
		"place_aura_orb":
			return _get_aura_orb_cost()
		"build_tower":
			return _get_bow_tower_cost()
		"build_storm_rod":
			return _get_storm_rod_cost()
		"build_spike_trap":
			return _get_spike_trap_cost()
		"build_tar_pit":
			return _get_tar_pit_cost()
		"build_fear_lantern":
			return _get_fear_lantern_cost()
		"build_decoy_idol":
			return _get_decoy_idol_cost()
		"build_thorn_totem":
			return _get_thorn_totem_cost()
		"build_repair_bench":
			return _get_repair_bench_cost()
		"smith_sword":
			var cost := _next_sword_ore_cost()
			return {"ore": cost} if cost > 0 else {}
	return {}


func _agent_should_withhold_eat_food_action() -> bool:
	if day_night == null or not day_night.is_night():
		return false
	return not enemies.is_empty()


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
		"lure_to_tar_pit":
			return job == "lure_to_tar_pit"
		"use_fear_lantern":
			return job == "use_fear_lantern"
		"use_decoy_idol":
			return job == "use_decoy_idol"
		"use_tower", "ranged_attack", "train_bow":
			return job == "use_tower" or job == "build_bow_tower"
		"build_tower":
			return job == "build_bow_tower"
		"build_storm_rod", "anti_flying", "sky_answer", "anti_air_defense":
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
		"use_thorns":
			return job == "use_thorns"
	return false


func _affordance_label(affordance_id: String) -> String:
	match affordance_id:
		"use_existing_wall", "wait_behind_wall", "use_cover":
			return "cover"
		"lure_to_aura", "place_aura_orb":
			return "light"
		"lure_to_tar_pit", "build_tar_pit":
			return "slow ground"
		"use_fear_lantern", "build_fear_lantern":
			return "warm safety"
		"use_decoy_idol", "build_decoy_idol":
			return "decoy"
		"use_thorns", "build_thorn_totem":
			return "thorns"
		"use_tower", "build_tower", "ranged_attack", "train_bow":
			return "tower range"
		"build_storm_rod", "anti_flying", "sky_answer", "anti_air_defense":
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
	_set_hint_max(normalized, "build_tar_pit", maxf(
		float(normalized.get("build_tar_pit", 0.0)),
		float(normalized.get("lure_to_tar_pit", 0.0)) * 0.35
	))
	_set_hint_max(normalized, "build_fear_lantern", maxf(
		float(normalized.get("build_fear_lantern", 0.0)),
		float(normalized.get("use_fear_lantern", 0.0)) * 0.35
	))
	_set_hint_max(normalized, "build_decoy_idol", maxf(
		float(normalized.get("build_decoy_idol", 0.0)),
		float(normalized.get("use_decoy_idol", 0.0)) * 0.35
	))
	_set_hint_max(normalized, "build_thorn_totem", maxf(
		float(normalized.get("build_thorn_totem", 0.0)),
		float(normalized.get("use_thorns", 0.0)) * 0.35
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
		maxf(maxf(float(normalized.get("anti_flying", 0.0)), float(normalized.get("sky_answer", 0.0))), float(normalized.get("anti_air_defense", 0.0)))
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
	for raw_type in _noticed_enemy_types.keys():
		var noticed_type := str(raw_type)
		if noticed_type != "" and not types.has(noticed_type):
			types.append(noticed_type)
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_type := str(enemy.get("enemy_type"))
		if enemy_type == "":
			enemy_type = "zombie"
		if not types.has(enemy_type):
			types.append(enemy_type)
	if not types.has("zombie"):
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
	_apply_contextual_local_sign_plan()
	var effects := _get_run_build_effects()
	sign_strength = clampf(float(interpretation.get("sign_strength", 0.0)) + float(effects.get("sign_strength_bonus", 0.0)), 0.0, 1.0)
	sign_resonance = clampf(float(interpretation.get("resonance", 0.0)) + float(effects.get("sign_resonance_bonus", 0.0)), 0.0, 1.0)


func _apply_contextual_local_sign_plan() -> void:
	if not _sign_has_bow_or_ranged_language(sign_text):
		return
	sign_interpretation = "Ari reads this as a ranged-fighting sign."
	ai_survival_theory = "ranged safety"
	_set_hint_max(sign_priority_hints, "range", 0.95)
	_set_hint_max(sign_priority_hints, "train_bow", 0.82)
	var plan := []
	var has_tower := bow_towers.size() > 0
	var has_aura := aura_orbs.size() > 0
	var has_enemy := enemies.size() > 0
	var wants_light := float(sign_priority_hints.get("aura_orb", 0.0)) > 0.0
	var aura_cost := int(_get_aura_orb_cost().get("stone", 0))
	var tower_cost := int(_get_bow_tower_cost().get("stone", 0))
	if has_tower and has_enemy:
		_set_hint_max(sign_priority_hints, "ranged_attack", 0.95)
		_set_hint_max(sign_priority_hints, "use_tower", 0.90)
		plan.append({
			"affordance_id": "ranged_attack",
			"priority": 0.95,
			"reason": "The sign asks for bow range and a target is present.",
		})
		plan.append({
			"affordance_id": "use_tower",
			"priority": 0.90,
			"reason": "The tower is the current bow perch.",
		})
	elif has_tower and (_is_night_close() or day_night.is_night()):
		_set_hint_max(sign_priority_hints, "use_tower", 0.92)
		_set_hint_max(sign_priority_hints, "ranged_attack", 0.75)
		plan.append({
			"affordance_id": "use_tower",
			"priority": 0.92,
			"reason": "Night pressure makes the bow perch matter now.",
		})
	elif has_tower and wants_light and not has_aura and not day_night.is_night():
		_set_hint_max(sign_priority_hints, "aura_orb", 0.92)
		plan.append({
			"affordance_id": "place_aura_orb",
			"priority": 0.92,
			"reason": "The sign also says the dead should walk through light.",
		})
		if _stone_count() < aura_cost:
			_set_hint_max(sign_priority_hints, "mining", 0.45)
	elif has_tower and wants_light and has_aura:
		_set_hint_max(sign_priority_hints, "lure_to_aura", 0.88)
		plan.append({
			"affordance_id": "lure_to_aura",
			"priority": 0.88,
			"reason": "The light exists; use it with the tower plan.",
		})
	elif has_tower:
		_set_hint_max(sign_priority_hints, "train_bow", 0.88)
		_set_hint_max(sign_priority_hints, "use_tower", 0.70)
		plan.append({
			"affordance_id": "train_bow",
			"priority": 0.88,
			"reason": "There is no immediate target; practice ranged readiness.",
		})
	elif _stone_count() >= tower_cost and not day_night.is_night():
		_set_hint_max(sign_priority_hints, "build_tower", 0.88)
		plan.append({
			"affordance_id": "build_tower",
			"priority": 0.88,
			"reason": "A bow plan needs a tower perch first.",
		})
	else:
		_set_hint_max(sign_priority_hints, "train_bow", 0.78)
		_set_hint_max(sign_priority_hints, "train_combat", 0.58)
		plan.append({
			"affordance_id": "train_bow",
			"priority": 0.78,
			"reason": "No ranged perch exists yet, so Ari practices bow readiness.",
		})
	sign_grounded_plan = _normalize_grounded_plan(plan)


func _sign_has_bow_or_ranged_language(text: String) -> bool:
	var tokens := text.to_lower().split(" ", false)
	for token in tokens:
		var clean := str(token).strip_edges().replace(".", "").replace(",", "").replace("!", "").replace("?", "")
		if ["bow", "bows", "shoot", "shooting", "arrow", "arrows", "ranged", "range"].has(clean):
			return true
	return false


func _is_night_close() -> bool:
	return str(day_night.phase) == "dusk" or (not day_night.is_night() and day_night.get_time_left() <= 8.0)


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
