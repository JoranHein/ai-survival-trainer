extends SceneTree

const MainScene := preload("res://scenes/main/Main.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Control = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	_test_main_scene_boots(main)
	_test_ari_exists_and_survival_hud(main)
	await _test_night_spawns_zombies(main)
	_test_zombies_move_toward_ari(main)
	await _test_ari_damage_death_and_restart(main)
	_test_night_survived_event(main)
	_test_runtime_snapshot_tracks_real_values(main)

	if failures.is_empty():
		print("Main playable survival tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_main_scene_boots(main: Control) -> void:
	_assert(main != null, "Main scene should instantiate")
	_assert(main.has_node("%DebugLabel"), "Main scene should keep the debug label")
	_assert(main.has_node("%SurvivalLabel"), "Main scene should expose a survival HUD label")


func _test_ari_exists_and_survival_hud(main: Control) -> void:
	_assert(main.get("ari_position") is Vector2, "Ari should have a world position")
	_assert(_float_property(main, "ari_hp", -1.0) == _float_property(main, "ari_max_hp", -2.0), "Ari should start at max HP")
	_assert(_bool_property(main, "ari_alive", false), "Ari should start alive")
	var text := _visible_text(main)
	_assert(text.contains("Ari HP:"), "survival HUD should show Ari HP")
	_assert(text.contains("Fear:"), "survival HUD should show fear")
	_assert(text.contains("Hunger:"), "survival HUD should show hunger")
	_assert(text.contains("Stamina:"), "survival HUD should show stamina")


func _test_night_spawns_zombies(main: Control) -> void:
	if not _require_method(main, "set_time_of_day_for_test"):
		return
	if not _require_method(main, "advance_runtime_memory"):
		return

	main.restart_run()
	main.set_time_of_day_for_test(2.0)
	main.advance_runtime_memory(10.0)
	await process_frame
	_assert(_int_property(main, "world_enemy_count", -1) == 0, "zombies should not auto-spawn before night")

	main.set_time_of_day_for_test(19.0)
	main.advance_runtime_memory(3.0)
	await process_frame
	_assert(_int_property(main, "world_enemy_count", -1) > 0, "zombies should spawn during night")
	_assert(_has_event(main, "night_started"), "entering night should record a night_started event")
	_assert(_has_event(main, "enemy_spawned"), "spawning a zombie should record enemy_spawned")


func _test_ari_damage_death_and_restart(main: Control) -> void:
	if not _require_method(main, "spawn_zombie"):
		return
	if not _require_method(main, "damage_ari"):
		return

	main.restart_run()
	main.set_time_of_day_for_test(19.0)
	main.spawn_zombie(main.get("ari_position") + Vector2(10.0, 0.0))
	var hp_before := _float_property(main, "ari_hp", -1.0)
	main.advance_runtime_memory(0.2)
	await process_frame
	_assert(_float_property(main, "ari_hp", 9999.0) < hp_before, "Ari should take damage when a zombie is close")
	_assert(_has_event(main, "ari_damaged"), "Ari damage should record ari_damaged")

	main.damage_ari(999.0, "test")
	_assert(_float_property(main, "ari_hp", -1.0) == 0.0, "Ari HP should clamp at zero")
	_assert(not _bool_property(main, "ari_alive", true), "Ari should die at zero HP")
	_assert(_has_event(main, "ari_died"), "Ari death should record ari_died")

	_press_key(main, KEY_R)
	await process_frame
	_assert(_bool_property(main, "ari_alive", false), "pressing R should restart Ari alive")
	_assert(_float_property(main, "ari_hp", -1.0) == _float_property(main, "ari_max_hp", -2.0), "restart should restore max HP")
	_assert(_int_property(main, "world_enemy_count", -1) == 0, "restart should despawn zombies")


func _test_zombies_move_toward_ari(main: Control) -> void:
	if not _require_method(main, "spawn_zombie"):
		return

	main.restart_run()
	main.set_time_of_day_for_test(19.0)
	var spawn_position: Vector2 = main.get("ari_position") + Vector2(180.0, 0.0)
	main.spawn_zombie(spawn_position)
	var zombies: Array = main.get("zombies")
	var first_zombie: Dictionary = zombies[0]
	var starting_distance := (first_zombie.get("position", Vector2.ZERO) as Vector2).distance_to(main.get("ari_position"))
	main.advance_runtime_memory(0.5)
	first_zombie = main.get("zombies")[0]
	var ending_distance := (first_zombie.get("position", Vector2.ZERO) as Vector2).distance_to(main.get("ari_position"))
	_assert(ending_distance < starting_distance, "zombies should move toward Ari")


func _test_night_survived_event(main: Control) -> void:
	if not _require_method(main, "set_time_of_day_for_test"):
		return

	main.restart_run()
	main.set_time_of_day_for_test(23.0)
	main.advance_runtime_memory(2.0)
	_assert(int(main.current_day) == 2, "surviving past night should advance the day")
	_assert(_has_event(main, "night_survived"), "surviving through night should record night_survived")


func _test_runtime_snapshot_tracks_real_values(main: Control) -> void:
	if not _require_method(main, "spawn_zombie"):
		return

	main.restart_run()
	main.spawn_zombie(main.get("ari_position") + Vector2(80.0, 0.0))
	main.damage_ari(12.0, "test")
	main._record_runtime_snapshot()

	var snapshots: Array = main.memory.get_recent_snapshots(20)
	var latest_snapshot: Dictionary = snapshots[snapshots.size() - 1] if not snapshots.is_empty() else {}
	var ari: Dictionary = latest_snapshot.get("ari", {})
	var world: Dictionary = latest_snapshot.get("world", {})

	_assert(ari.get("hp", -1) == main.ari_hp, "snapshot Ari HP should match the live Ari HP")
	_assert(world.get("enemy_count", -1) == main.world_enemy_count, "snapshot enemy_count should match live zombies")


func _press_key(main: Control, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	main._unhandled_input(event)


func _visible_text(main: Control) -> String:
	var debug_text := ""
	var survival_text := ""
	if main.has_node("%DebugLabel"):
		debug_text = main.get_node("%DebugLabel").text
	if main.has_node("%SurvivalLabel"):
		survival_text = main.get_node("%SurvivalLabel").text
	return survival_text + "\n" + debug_text


func _has_event(main: Control, event_type: String) -> bool:
	for event in main.memory.get_recent_events(200):
		if typeof(event) == TYPE_DICTIONARY and event.get("type", "") == event_type:
			return true
	return false


func _require_method(main: Control, method_name: String) -> bool:
	var exists := main.has_method(method_name)
	_assert(exists, "Main should expose " + method_name)
	return exists


func _float_property(main: Control, property_name: String, fallback: float) -> float:
	var value = main.get(property_name)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


func _int_property(main: Control, property_name: String, fallback: int) -> int:
	var value = main.get(property_name)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return int(value)
	return fallback


func _bool_property(main: Control, property_name: String, fallback: bool) -> bool:
	var value = main.get(property_name)
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	return fallback


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
