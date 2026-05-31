class_name AriMind
extends Node

@export var target_wall_count := 2
@export var target_aura_orb_count := 1
@export var night_close_seconds := 8.0


func choose_daytime_job(context: Dictionary) -> Dictionary:
	if bool(context.get("is_night", false)):
		return _job("wait_or_idle", "Night has started")

	var wall_count := int(context.get("wall_count", 0))
	var aura_orb_count := int(context.get("aura_orb_count", 0))
	var stone := int(context.get("stone", 0))
	var wall_cost := int(context.get("wall_cost", 0))
	var aura_orb_cost := int(context.get("aura_orb_cost", 0))
	var night_close := bool(context.get("night_close", false))
	var has_defenses := wall_count > 0 or aura_orb_count > 0
	var priority_hints := _priority_hints(context)
	var personality := _personality(context)
	var run_build := _run_build(context)
	var fearfulness := _trait(personality, "fearfulness")
	var aggression := _trait(personality, "aggression")
	var curiosity := _trait(personality, "curiosity")
	var perseverance := _trait(personality, "perseverance")
	var mining_points := _build_points(run_build, "mining")
	var building_points := _build_points(run_build, "building")
	var warding_points := _build_points(run_build, "warding")
	var mining_instinct := _build_strength(run_build, "mining")
	var building_instinct := _build_strength(run_build, "building")
	var warding_instinct := _build_strength(run_build, "warding")
	var defense_instinct := _build_strength(run_build, "defense")
	var fear_control_instinct := _build_strength(run_build, "fear_control")
	var sign_wall_preference := _hint(priority_hints, "wall")
	var sign_aura_preference := _hint(priority_hints, "aura_orb")
	var sign_mining_preference := _hint(priority_hints, "mining")
	var wall_preference := sign_wall_preference
	var aura_preference := sign_aura_preference
	var mining_preference := sign_mining_preference
	var range_preference := _hint(priority_hints, "range")
	var defensive_wait_preference := _hint(priority_hints, "defensive_wait")
	wall_preference = clampf(wall_preference + (fearfulness * 0.22 if wall_preference > 0.0 or fearfulness >= 0.66 else 0.0), 0.0, 1.0)
	aura_preference = clampf(aura_preference + (fearfulness * 0.12 + curiosity * 0.10 if aura_preference > 0.0 else 0.0), 0.0, 1.0)
	mining_preference = clampf(mining_preference + (curiosity * 0.10 if mining_preference > 0.0 else 0.0), 0.0, 1.0)
	range_preference = clampf(range_preference + (aggression * 0.14 if range_preference > 0.0 else 0.0), 0.0, 1.0)
	defensive_wait_preference = clampf(defensive_wait_preference + (fearfulness * 0.25 if defensive_wait_preference > 0.0 or fearfulness >= 0.66 else 0.0) - aggression * 0.25, 0.0, 1.0)
	wall_preference = clampf(wall_preference + building_instinct * 0.18, 0.0, 1.0)
	aura_preference = clampf(aura_preference + warding_instinct * 0.24, 0.0, 1.0)
	mining_preference = clampf(mining_preference + mining_instinct * 0.18, 0.0, 1.0)
	defensive_wait_preference = clampf(defensive_wait_preference + fear_control_instinct * 0.12 + defense_instinct * 0.08, 0.0, 1.0)
	var desired_wall_count := target_wall_count
	if fearfulness >= 0.66:
		desired_wall_count += 1
	if building_points >= 4:
		desired_wall_count += 1
	if building_points >= 7:
		desired_wall_count += 1
	if wall_preference > 0.25:
		desired_wall_count += 1
	if wall_preference >= 0.85:
		desired_wall_count += 1

	var current_job := str(context.get("current_job", "wait_or_idle"))
	var desired_stone_reserve := maxi(wall_cost, aura_orb_cost) + int(ceil(mining_preference * 4.0)) + int(ceil(float(mining_points) * 0.5))
	if perseverance >= 0.70:
		var sticky_job := _sticky_job(current_job, stone, wall_cost, aura_orb_cost, wall_count, aura_orb_count, desired_wall_count, desired_stone_reserve)
		if sticky_job != "":
			return _job(sticky_job, _sticky_reason(sticky_job))

	if night_close and has_defenses and aggression < 0.65:
		return _job("wait_or_idle", "Night is close; stay near defenses")

	var aura_can_lead := wall_count > 0 or sign_aura_preference > 0.0 or warding_points >= 5
	if aura_preference > 0.0 and aura_orb_count < target_aura_orb_count and aura_can_lead:
		if stone < aura_orb_cost:
			return _job("mine_stone", "Need stone for sign's light" if sign_aura_preference > 0.0 else "Need stone for Aura Orb")
		return _job("place_aura_orb", "Sign points to light" if sign_aura_preference > 0.0 else "Build favors Aura Orb")

	if mining_preference > 0.0 and stone < desired_stone_reserve:
		return _job("mine_stone", "Sign keeps pointing to stone" if sign_mining_preference > 0.0 else "Build favors mining")

	if wall_count < desired_wall_count:
		if stone < wall_cost:
			return _job("mine_stone", "Need stone for wall")
		if sign_wall_preference > 0.0:
			return _job("build_wall", "Sign wants stronger walls")
		if building_points >= 4:
			return _job("build_wall", "Build favors walls")
		return _job("build_wall", "Too few walls")

	if wall_count > 0 and aura_orb_count < target_aura_orb_count:
		if stone < aura_orb_cost:
			return _job("mine_stone", "Need stone for Aura Orb")
		return _job("place_aura_orb", "No aura orb yet")

	if defensive_wait_preference > 0.25 and has_defenses and aggression < 0.55:
		return _job("wait_or_idle", "Sign asks for safety")

	if range_preference > 0.0:
		return _job("wait_or_idle", "Sign asks for arrows; no bow yet")

	if defensive_wait_preference > 0.0 and has_defenses:
		return _job("wait_or_idle", "Sign asks for safety")

	return _job("wait_or_idle", "Basic defenses ready")


func thought_for_job(job: String, reason: String, personality := {}, run_build := {}) -> String:
	var lower_reason := reason.to_lower()
	match job:
		"mine_stone":
			if lower_reason.find("build favors mining") >= 0:
				return "This build starts with stone. I should fill my hands."
			if lower_reason.find("sticking") >= 0:
				return "I chose this plan. I should not drop it yet."
			if lower_reason.find("sign keeps pointing") >= 0:
				return "The sign keeps saying stone. I should mine more."
			if lower_reason.find("aura") >= 0:
				return "I need stone before the light can protect me."
			if lower_reason.find("sign's light") >= 0:
				return "I need stone before the light can protect me."
			return "Stone first. Weak walls only pretend to protect me."
		"build_wall":
			if lower_reason.find("build favors walls") >= 0:
				return "This build wants shape and cover. I will make walls."
			if lower_reason.find("sticking") >= 0:
				return "The wall plan still feels unfinished."
			if lower_reason.find("sign wants") >= 0:
				return "The sign wants walls. I can make the teeth wait outside."
			if _trait(personality, "fearfulness") >= 0.68:
				return "Fear keeps asking for another wall."
			return "I need a wall before the night comes."
		"place_aura_orb":
			if lower_reason.find("build favors aura") >= 0:
				return "This build trusts the circle. Let it hurt them first."
			if lower_reason.find("sticking") >= 0:
				return "The light plan is still the plan."
			if _trait(personality, "curiosity") >= 0.66:
				return "The orb feels like an answer I want to test."
			return "The light can hurt them before they reach me."
		"wait_or_idle":
			if lower_reason.find("no bow yet") >= 0:
				return "The sign wants arrows, but I do not have arrows yet."
			if lower_reason.find("sign asks for safety") >= 0:
				return "The sign says safe. I will stay near what can protect me."
			if lower_reason.find("night has started") >= 0:
				return "The dark is here. I need to stop preparing."
			if lower_reason.find("defenses ready") >= 0 or lower_reason.find("stay near defenses") >= 0:
				return "I have done what I can. Now I wait."
	return ""


func thought_for_damage(hp: float, max_hp: float) -> String:
	if hp <= 0.0:
		return ""
	if max_hp > 0.0 and hp / max_hp <= 0.3:
		return "That hurt. I am too close to dying."
	return "That hurt. I do not want them near me."


func _priority_hints(context: Dictionary) -> Dictionary:
	var hints = context.get("priority_hints", {})
	if typeof(hints) == TYPE_DICTIONARY:
		return hints
	return {}


func _personality(context: Dictionary) -> Dictionary:
	var personality = context.get("personality", {})
	if typeof(personality) == TYPE_DICTIONARY:
		return personality
	return {}


func _run_build(context: Dictionary) -> Dictionary:
	var run_build = context.get("run_build", {})
	if typeof(run_build) == TYPE_DICTIONARY:
		return run_build
	return {}


func _hint(hints: Dictionary, hint_name: String) -> float:
	return clampf(float(hints.get(hint_name, 0.0)), 0.0, 1.0)


func _trait(personality: Dictionary, trait_name: String) -> float:
	return clampf(float(personality.get(trait_name, 0.5)), 0.0, 1.0)


func _build_strength(run_build: Dictionary, category: String) -> float:
	return clampf(float(_build_points(run_build, category)) / 7.0, 0.0, 1.0)


func _build_points(run_build: Dictionary, category: String) -> int:
	var points = run_build.get("points", {})
	if typeof(points) == TYPE_DICTIONARY:
		return int(points.get(category, 0))
	return int(run_build.get(category, 0))


func _sticky_job(current_job: String, stone: int, wall_cost: int, aura_orb_cost: int, wall_count: int, aura_orb_count: int, desired_wall_count: int, desired_stone_reserve: int) -> String:
	match current_job:
		"mine_stone":
			if stone < desired_stone_reserve + 2:
				return "mine_stone"
		"build_wall":
			if wall_count < desired_wall_count and stone >= wall_cost:
				return "build_wall"
		"place_aura_orb":
			if aura_orb_count < target_aura_orb_count and stone >= aura_orb_cost:
				return "place_aura_orb"
	return ""


func _sticky_reason(job: String) -> String:
	match job:
		"mine_stone":
			return "Sticking with stone plan"
		"build_wall":
			return "Sticking with wall plan"
		"place_aura_orb":
			return "Sticking with light plan"
	return "Sticking with plan"


func _job(name: String, reason: String) -> Dictionary:
	return {
		"job": name,
		"reason": reason,
	}
