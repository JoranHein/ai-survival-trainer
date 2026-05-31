extends SceneTree

const AriControllerScript := preload("res://scripts/ari/AriController.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ari: AriController = AriControllerScript.new()
	root.add_child(ari)

	_test_moving_to_mine_has_mining_cue(ari)
	_test_building_wall_has_build_cue(ari)
	_test_moving_to_bed_has_rest_cue(ari)
	_test_training_has_training_cue(ari)
	_test_idle_has_no_action_cue(ari)

	if failures.is_empty():
		print("Ari action cue tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_moving_to_mine_has_mining_cue(ari: AriController) -> void:
	_assert(ari.has_method("get_action_cue"), "Ari should expose action cue state")
	if not ari.has_method("get_action_cue"):
		return
	ari.current_action = "moving to mine"
	var cue: Dictionary = ari.call("get_action_cue")
	_assert(cue.get("kind", "") == "mine", "moving to mine should use the mine cue")
	_assert(cue.get("phase", "") == "moving", "moving to mine should mark the cue as moving")


func _test_building_wall_has_build_cue(ari: AriController) -> void:
	_assert(ari.has_method("get_action_cue"), "Ari should expose action cue state")
	if not ari.has_method("get_action_cue"):
		return
	ari.current_action = "building wall"
	var cue: Dictionary = ari.call("get_action_cue")
	_assert(cue.get("kind", "") == "build", "building wall should use the build cue")
	_assert(cue.get("phase", "") == "active", "building wall should mark the cue as active")


func _test_moving_to_bed_has_rest_cue(ari: AriController) -> void:
	_assert(ari.has_method("get_action_cue"), "Ari should expose action cue state")
	if not ari.has_method("get_action_cue"):
		return
	ari.current_action = "moving to bed"
	var cue: Dictionary = ari.call("get_action_cue")
	_assert(cue.get("kind", "") == "rest", "moving to bed should use the rest cue")
	_assert(cue.get("phase", "") == "moving", "moving to bed should mark the cue as moving")


func _test_training_has_training_cue(ari: AriController) -> void:
	_assert(ari.has_method("get_action_cue"), "Ari should expose action cue state")
	if not ari.has_method("get_action_cue"):
		return
	ari.current_action = "training combat"
	var cue: Dictionary = ari.call("get_action_cue")
	_assert(cue.get("kind", "") == "train", "training combat should use the train cue")
	_assert(cue.get("phase", "") == "active", "training combat should mark the cue as active")


func _test_idle_has_no_action_cue(ari: AriController) -> void:
	_assert(ari.has_method("get_action_cue"), "Ari should expose action cue state")
	if not ari.has_method("get_action_cue"):
		return
	ari.current_action = "idle"
	var cue: Dictionary = ari.call("get_action_cue")
	_assert(cue.is_empty(), "idle Ari should not show an action cue")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
