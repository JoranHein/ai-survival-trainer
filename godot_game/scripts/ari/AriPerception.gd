class_name AriPerception
extends RefCounted

const MAX_ENEMIES := 5
const MAX_STRUCTURES := 8
const MAX_FACTS := 10


func build_report(world: Node) -> Dictionary:
	var ari: Node2D = world.get("ari") if world != null else null
	var ari_position := ari.global_position if ari != null else _world_center(world)
	var day_night: Node = world.get("day_night") if world != null else null
	var phase := str(day_night.get("phase")) if day_night != null else ""
	var time_left := float(day_night.call("get_time_left")) if day_night != null and day_night.has_method("get_time_left") else 0.0
	var is_night := bool(day_night.call("is_night")) if day_night != null and day_night.has_method("is_night") else phase == "night"
	var resources := _resources(world)
	var enemies := _nearby_enemies(world, ari_position)
	var structures := _nearby_structures(world, ari_position)
	var report := {
		"phase": phase,
		"time_left": time_left,
		"is_night": is_night,
		"is_dawn_soon": is_night and time_left <= 15.0,
		"ari": _ari_state(world, ari),
		"resources": resources,
		"run_build": _run_build(world),
		"sword_tier": int(resources.get("sword_tier", 0)),
		"current_sign": _limit_text(str(world.get("sign_text")) if world != null else "", 180),
		"current_theory": _limit_text(str(world.get("ai_survival_theory")) if world != null else "", 120),
		"latest_library_note": _latest_library_note(world),
		"nearby_enemies": enemies,
		"nearby_structures": structures,
	}
	report["tactical_facts"] = _tactical_facts(world, report)
	report["available_safe_moves"] = _available_safe_moves(world, report)
	return report


func _ari_state(world: Node, ari: Node2D) -> Dictionary:
	var needs := {}
	if ari != null and ari.has_method("get_needs"):
		var raw_needs = ari.call("get_needs")
		if typeof(raw_needs) == TYPE_DICTIONARY:
			needs = raw_needs
	return {
		"hp": float(ari.get("hp")) if ari != null else 0.0,
		"max_hp": float(ari.get("max_hp")) if ari != null else 0.0,
		"hunger": float(needs.get("hunger", 0.0)),
		"stamina": float(needs.get("stamina", 0.0)),
		"fear": float(needs.get("fear", 0.0)),
		"current_job": str(ari.call("get_current_job")) if ari != null and ari.has_method("get_current_job") else "wait_or_idle",
		"current_reason": _limit_text(str(ari.call("get_job_reason")) if ari != null and ari.has_method("get_job_reason") else "", 120),
	}


func _resources(world: Node) -> Dictionary:
	return {
		"stone": _int_world_call(world, "_stone_count"),
		"food": _int_world_call(world, "_food_count"),
		"ore": _int_world_call(world, "_ore_count"),
		"sword_tier": _int_world_call(world, "_current_sword_tier"),
		"wall_count": _int_world_call(world, "get_wall_count"),
		"aura_orb_count": _int_world_call(world, "get_aura_orb_count"),
		"bow_tower_count": _int_world_call(world, "get_bow_tower_count"),
		"storm_rod_count": _int_world_call(world, "get_storm_rod_count"),
		"enemy_count": _int_world_call(world, "get_enemy_count"),
	}


func _run_build(world: Node) -> Dictionary:
	if world != null and world.has_method("_get_run_build_context"):
		var context = world.call("_get_run_build_context")
		if typeof(context) == TYPE_DICTIONARY:
			return context
	return {}


func _nearby_enemies(world: Node, ari_position: Vector2) -> Array:
	var rows := []
	if world == null or not world.has_method("get_enemies"):
		return rows
	for enemy in world.call("get_enemies"):
		if not is_instance_valid(enemy):
			continue
		var enemy_position: Vector2 = enemy.get("global_position")
		var enemy_type := str(enemy.get("enemy_type"))
		var distance := ari_position.distance_to(enemy_position)
		rows.append({
			"type": enemy_type,
			"distance": round(distance),
			"direction": _direction_label(enemy_position - ari_position),
			"danger": _enemy_danger(enemy_type, distance, bool(enemy.get("ignores_walls"))),
			"is_flying": bool(enemy.get("ignores_walls")) or enemy_type == "flying",
			"tactical_note": _enemy_note(enemy_type, bool(enemy.get("ignores_walls"))),
			"_sort_distance": distance,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("_sort_distance", 0.0)) < float(b.get("_sort_distance", 0.0))
	)
	var result := []
	for row in rows:
		row.erase("_sort_distance")
		result.append(row)
		if result.size() >= MAX_ENEMIES:
			break
	return result


func _nearby_structures(world: Node, ari_position: Vector2) -> Array:
	var rows := []
	if world == null:
		return rows
	if world.has_method("get_structures"):
		for structure in world.call("get_structures"):
			if not is_instance_valid(structure):
				continue
			rows.append(_structure_row(structure, ari_position))
	for station in _station_nodes(world):
		if is_instance_valid(station.get("node")):
			rows.append(_station_row(station, ari_position))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("_sort_distance", 0.0)) < float(b.get("_sort_distance", 0.0))
	)
	var result := []
	for row in rows:
		row.erase("_sort_distance")
		result.append(row)
		if result.size() >= MAX_STRUCTURES:
			break
	return result


func _structure_row(structure: Node, ari_position: Vector2) -> Dictionary:
	var structure_position: Vector2 = structure.get("global_position")
	var structure_type := str(structure.get("structure_type"))
	var distance := ari_position.distance_to(structure_position)
	return {
		"type": structure_type,
		"distance": round(distance),
		"direction": _direction_label(structure_position - ari_position),
		"condition": _structure_condition(structure),
		"tactical_use": _structure_use(structure_type),
		"_sort_distance": distance,
	}


func _station_row(station: Dictionary, ari_position: Vector2) -> Dictionary:
	var node: Node2D = station.get("node")
	var station_position := node.global_position
	var distance := ari_position.distance_to(station_position)
	return {
		"type": str(station.get("type", "")),
		"distance": round(distance),
		"direction": _direction_label(station_position - ari_position),
		"condition": "available",
		"tactical_use": str(station.get("use", "")),
		"_sort_distance": distance,
	}


func _station_nodes(world: Node) -> Array:
	var stations := []
	for item in [
		{"property": "mine_node", "type": "mine", "use": "stone and ore"},
		{"property": "training_dummy", "type": "training_dummy", "use": "combat practice"},
		{"property": "farm_plot", "type": "farm", "use": "food"},
		{"property": "bed_station", "type": "bed", "use": "rest"},
		{"property": "library_station", "type": "library", "use": "reflection"},
		{"property": "forge_station", "type": "forge", "use": "smith sword"},
	]:
		var node = world.get(str(item.get("property", "")))
		if node is Node2D:
			stations.append({
				"node": node,
				"type": item.get("type", ""),
				"use": item.get("use", ""),
			})
	return stations


func _tactical_facts(world: Node, report: Dictionary) -> Array[String]:
	var facts: Array[String] = []
	var resources: Dictionary = report.get("resources", {})
	var enemies: Array = report.get("nearby_enemies", [])
	var has_flying := false
	var has_ground := false
	for enemy in enemies:
		if typeof(enemy) != TYPE_DICTIONARY:
			continue
		has_flying = has_flying or bool(enemy.get("is_flying", false))
		has_ground = has_ground or not bool(enemy.get("is_flying", false))
		var enemy_type := str(enemy.get("type", ""))
		if enemy_type == "runner":
			_add_fact(facts, "Runners punish open layouts; distance, cover, slowing, or aura luring matters.")
		elif enemy_type == "brute":
			_add_fact(facts, "Brutes break structures; weak wall-only plans are risky.")

	if has_flying:
		_add_fact(facts, "Flying enemies ignore walls; Storm Rod or range matters.")
	if int(resources.get("wall_count", 0)) > 0 and has_ground:
		if _wall_between_ari_and_ground_enemy(world):
			_add_fact(facts, "A wall is between Ari and a ground enemy.")
		else:
			_add_fact(facts, "Existing walls can become cover against ground enemies.")
	if int(resources.get("aura_orb_count", 0)) > 0:
		_add_fact(facts, "Aura Orb can punish enemies Ari lures through light.")
		if _enemies_outside_aura(world):
			_add_fact(facts, "Enemies are outside the Aura Orb; lure_to_aura can make the light matter.")
	if int(resources.get("bow_tower_count", 0)) > 0:
		_add_fact(facts, "A bow tower can support ranged attacks.")
	if int(resources.get("storm_rod_count", 0)) > 0 and has_flying:
		_add_fact(facts, "Storm Rod can answer the sky threat.")
	if bool(report.get("is_dawn_soon", false)):
		_add_fact(facts, "Dawn is soon; stalling can be valid.")
	var ari_state: Dictionary = report.get("ari", {})
	if float(ari_state.get("hunger", 0.0)) >= 62.0:
		_add_fact(facts, "Hunger is high; food is safety.")
	if int(resources.get("ore", 0)) <= 0 and int(resources.get("sword_tier", 0)) <= 0:
		_add_fact(facts, "Smithing needs ore before a better sword exists.")
	if facts.is_empty():
		_add_fact(facts, "Ari sees no immediate special tactic beyond basic preparation.")
	return facts


func _available_safe_moves(world: Node, report: Dictionary) -> Array[String]:
	var resources: Dictionary = report.get("resources", {})
	var moves: Array[String] = []
	if int(resources.get("wall_count", 0)) > 0 or int(resources.get("bow_tower_count", 0)) > 0:
		moves.append("use_cover")
	if int(resources.get("aura_orb_count", 0)) > 0:
		moves.append("lure_to_aura")
	if int(resources.get("bow_tower_count", 0)) > 0:
		moves.append("use_tower")
	if int(resources.get("storm_rod_count", 0)) > 0:
		moves.append("anti_flying")
	if bool(report.get("is_night", false)):
		moves.append("flee")
	if bool(report.get("is_dawn_soon", false)):
		moves.append("stall_until_dawn")
	if int(resources.get("food", 0)) > 0:
		moves.append("eat_food")
	moves.append("rest")
	return _unique_strings(moves, 10)


func _latest_library_note(world: Node) -> Dictionary:
	if world == null:
		return {}
	var title := str(world.get("latest_lesson_title"))
	var text := ""
	if world.has_method("_latest_library_note_text"):
		text = str(world.call("_latest_library_note_text"))
	return {
		"title": _limit_text(title, 80),
		"summary": _limit_text(text, 220),
	}


func _wall_between_ari_and_ground_enemy(world: Node) -> bool:
	if world == null or not world.has_method("get_enemies") or not world.has_method("get_existing_walls"):
		return false
	var ari: Node2D = world.get("ari")
	if ari == null:
		return false
	for enemy in world.call("get_enemies"):
		if not is_instance_valid(enemy):
			continue
		if bool(enemy.get("ignores_walls")) or str(enemy.get("enemy_type")) == "flying":
			continue
		for wall in world.call("get_existing_walls"):
			if not is_instance_valid(wall):
				continue
			if wall.has_method("get_blocking_rect"):
				var rect: Rect2 = wall.call("get_blocking_rect")
				if _segment_hits_rect(ari.global_position, enemy.get("global_position"), rect.grow(10.0)):
					return true
	return false


func _enemies_outside_aura(world: Node) -> bool:
	if world == null or not world.has_method("get_enemies") or not world.has_method("get_aura_orbs"):
		return false
	var has_enemy := false
	for enemy in world.call("get_enemies"):
		if not is_instance_valid(enemy):
			continue
		has_enemy = true
		var enemy_position: Vector2 = enemy.get("global_position")
		var inside_any_aura := false
		for aura in world.call("get_aura_orbs"):
			if not is_instance_valid(aura):
				continue
			var aura_radius := float(aura.get("aura_radius"))
			if aura_radius <= 0.0:
				aura_radius = 92.0
			var aura_position: Vector2 = aura.get("global_position")
			if aura_position.distance_to(enemy_position) <= aura_radius:
				inside_any_aura = true
				break
		if not inside_any_aura:
			return true
	return false if has_enemy else false


func _segment_hits_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	for i in range(13):
		var t := float(i) / 12.0
		if rect.has_point(from.lerp(to, t)):
			return true
	return false


func _structure_condition(structure: Node) -> String:
	var hp := float(structure.get("hp"))
	var max_hp := float(structure.get("max_hp"))
	if max_hp <= 0.0:
		return "intact"
	var ratio := hp / max_hp
	if ratio <= 0.0:
		return "broken"
	if ratio < 0.5:
		return "damaged"
	if ratio < 0.8:
		return "worn"
	return "intact"


func _structure_use(structure_type: String) -> String:
	match structure_type:
		"wall":
			return "ground cover"
		"aura_orb":
			return "lure damage"
		"bow_tower":
			return "ranged attacks"
		"storm_rod":
			return "anti-flying"
		"spike_trap":
			return "ground damage"
		"tar_pit":
			return "slow ground enemies"
		"fear_lantern":
			return "fear control"
		"decoy_idol":
			return "enemy distraction"
		"thorn_totem":
			return "punish contact"
		"repair_bench":
			return "repair support"
	return "support"


func _enemy_danger(enemy_type: String, distance: float, is_flying: bool) -> String:
	if distance <= 48.0:
		return "critical"
	if is_flying or enemy_type == "brute":
		return "high"
	if enemy_type == "runner" or distance <= 96.0:
		return "medium"
	return "low"


func _enemy_note(enemy_type: String, is_flying: bool) -> String:
	if is_flying:
		return "Flying enemies ignore walls; use storm or range."
	match enemy_type:
		"runner":
			return "Fast ground enemy; distance, aura, or cover buys time."
		"brute":
			return "Heavy ground enemy; avoid weak wall-only plans."
	return "Ground enemy can be blocked, lured, or fought if Ari is ready."


func _direction_label(delta: Vector2) -> String:
	if delta.length() <= 0.01:
		return "here"
	var horizontal := ""
	var vertical := ""
	if delta.x > 18.0:
		horizontal = "east"
	elif delta.x < -18.0:
		horizontal = "west"
	if delta.y > 18.0:
		vertical = "south"
	elif delta.y < -18.0:
		vertical = "north"
	if vertical != "" and horizontal != "":
		if vertical == "north" and horizontal == "east":
			return "ne"
		if vertical == "north" and horizontal == "west":
			return "nw"
		if vertical == "south" and horizontal == "east":
			return "se"
		if vertical == "south" and horizontal == "west":
			return "sw"
	if vertical != "":
		return vertical
	if horizontal != "":
		return horizontal
	return "near"


func _world_center(world: Node) -> Vector2:
	if world != null and world.has_method("get_arena_rect"):
		var arena: Rect2 = world.call("get_arena_rect")
		return arena.get_center()
	return Vector2.ZERO


func _int_world_call(world: Node, method_name: String) -> int:
	if world != null and world.has_method(method_name):
		return int(world.call(method_name))
	return 0


func _add_fact(facts: Array[String], fact: String) -> void:
	if facts.size() >= MAX_FACTS:
		return
	if not facts.has(fact):
		facts.append(fact)


func _unique_strings(values: Array[String], max_items: int) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		if result.size() >= max_items:
			break
		if value.strip_edges() == "" or result.has(value):
			continue
		result.append(value)
	return result


func _limit_text(text: String, max_length: int) -> String:
	var clean := text.replace("\n", " ").replace("\t", " ").strip_edges()
	if clean.length() <= max_length:
		return clean
	return clean.substr(0, max_length - 3).strip_edges() + "..."
