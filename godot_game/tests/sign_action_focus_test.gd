extends SceneTree

const SignMindScript := preload("res://scripts/ari/SignMind.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var sign_mind: SignMind = SignMindScript.new()
	root.add_child(sign_mind)

	_test_training_sign_reports_following(sign_mind)
	_test_wall_sign_explains_mining_first(sign_mind)
	_test_wall_sign_names_hunger_override(sign_mind)
	_test_wall_sign_names_fear_override(sign_mind)
	_test_empty_sign_has_no_pull_line(sign_mind)

	if failures.is_empty():
		print("Sign action focus tests passed.")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_training_sign_reports_following(sign_mind: SignMind) -> void:
	_assert(sign_mind.has_method("describe_action_focus"), "SignMind should expose describe_action_focus")
	if not sign_mind.has_method("describe_action_focus"):
		return
	var interpretation := sign_mind.interpret_sign("train combat before night")
	var line := str(sign_mind.call(
		"describe_action_focus",
		interpretation.get("priority_hints", {}),
		"train_combat",
		"Sign says to prepare hands"
	))
	_assert(line.contains("training"), "combat sign pull should name training")
	_assert(line.contains("following"), "matching job should say Ari is following the sign")


func _test_wall_sign_explains_mining_first(sign_mind: SignMind) -> void:
	_assert(sign_mind.has_method("describe_action_focus"), "SignMind should expose describe_action_focus")
	if not sign_mind.has_method("describe_action_focus"):
		return
	var interpretation := sign_mind.interpret_sign("build stone walls")
	var line := str(sign_mind.call(
		"describe_action_focus",
		interpretation.get("priority_hints", {}),
		"mine_stone",
		"Need stone for wall"
	))
	_assert(line.contains("walls"), "wall sign pull should name walls")
	_assert(line.contains("mining first"), "mining for a hinted wall should explain the dependency")


func _test_wall_sign_names_hunger_override(sign_mind: SignMind) -> void:
	_assert(sign_mind.has_method("describe_action_focus"), "SignMind should expose describe_action_focus")
	if not sign_mind.has_method("describe_action_focus"):
		return
	var interpretation := sign_mind.interpret_sign("build stone walls")
	var line := str(sign_mind.call(
		"describe_action_focus",
		interpretation.get("priority_hints", {}),
		"eat_food",
		"Hunger is becoming dangerous"
	))
	_assert(line.contains("walls"), "wall sign pull should still name walls when overridden")
	_assert(line.contains("hunger"), "hunger override should be named in the sign-pull line")


func _test_wall_sign_names_fear_override(sign_mind: SignMind) -> void:
	_assert(sign_mind.has_method("describe_action_focus"), "SignMind should expose describe_action_focus")
	if not sign_mind.has_method("describe_action_focus"):
		return
	var interpretation := sign_mind.interpret_sign("build stone walls")
	var line := str(sign_mind.call(
		"describe_action_focus",
		interpretation.get("priority_hints", {}),
		"rest",
		"Need calm before night"
	))
	_assert(line.contains("walls"), "wall sign pull should still name walls when fear overrides it")
	_assert(line.contains("fear"), "fear override should be named in the sign-pull line")


func _test_empty_sign_has_no_pull_line(sign_mind: SignMind) -> void:
	_assert(sign_mind.has_method("describe_action_focus"), "SignMind should expose describe_action_focus")
	if not sign_mind.has_method("describe_action_focus"):
		return
	var interpretation := sign_mind.interpret_sign("")
	var line := str(sign_mind.call(
		"describe_action_focus",
		interpretation.get("priority_hints", {}),
		"wait_or_idle",
		"Basic defenses ready"
	))
	_assert(line == "", "empty signs should not add a sign-pull UI line")


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
