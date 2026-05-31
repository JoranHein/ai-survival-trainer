extends CanvasLayer

const BuildPaletteIconScript := preload("res://scripts/ui/BuildPaletteIcon.gd")

@onready var status_label: Label = %StatusLabel
@onready var meter_strip: Control = %MeterStrip
@onready var mind_label: Label = %MindLabel
@onready var build_label: Label = %BuildLabel
@onready var build_palette_panel: PanelContainer = %PalettePanel
@onready var build_palette: GridContainer = %BuildPalette


func update_state(state: Dictionary) -> void:
	var day := int(state.get("day", 1))
	var phase := str(state.get("phase", "morning"))
	var time_left := float(state.get("time_left", 0.0))
	var ari_hp := float(state.get("ari_hp", 0.0))
	var ari_max_hp := float(state.get("ari_max_hp", 0.0))
	var enemy_count := int(state.get("enemy_count", 0))
	var stone := int(state.get("stone", 0))
	var food := int(state.get("food", 0))
	var selected_build_type := str(state.get("selected_build_type", "wall"))
	var selected_build_name := str(state.get("selected_build_name", "Wall"))
	var build_mode := false
	var build_mode_value = state.get("build_mode", false)
	if typeof(build_mode_value) == TYPE_BOOL:
		build_mode = build_mode_value
	var mining_enabled := false
	var mining_value = state.get("mining_enabled", false)
	if typeof(mining_value) == TYPE_BOOL:
		mining_enabled = mining_value
	var ari_job_reason := str(state.get("ari_job_reason", "Waiting"))
	var ari_action := str(state.get("ari_action", "idle"))
	var combat_stats := _combat_stats(state)
	var needs := _needs(state)
	var personality_summary := str(state.get("personality_summary", "Ari: balanced"))
	var run_build_line := _run_build_line(state)
	var status_message := str(state.get("status_message", ""))
	var inspect_text := str(state.get("inspect_text", ""))
	var death_recap := str(state.get("death_recap", ""))
	var sign_action_focus := str(state.get("sign_action_focus", ""))
	var ai_status := str(state.get("ai_status", "AI disabled"))
	var progression := _progression(state)
	var time_points := int(progression.get("time_points", 0))
	var permanent_summary := str(progression.get("permanent_summary", "No permanent upgrades yet"))
	var lesson_count := int(state.get("lesson_count", 0))
	var latest_lesson_title := str(state.get("latest_lesson_title", ""))
	var ari_alive := true
	var alive_value = state.get("ari_alive", true)
	if typeof(alive_value) == TYPE_BOOL:
		ari_alive = alive_value

	var short_upgrade_summary := permanent_summary
	if permanent_summary == "No permanent upgrades yet":
		short_upgrade_summary = "No upgrades"
	elif permanent_summary.length() > 34:
		short_upgrade_summary = permanent_summary.substr(0, 31) + "..."

	var status_lines := [
		_status_header_line(day, phase, time_left, ari_hp, ari_max_hp, enemy_count, stone, food),
	]
	var mind_lines := [
		"%s    Build: %s" % [
			personality_summary,
			run_build_line,
		],
		"Doing: %s    Why: %s" % [
			ari_action,
			ari_job_reason,
		],
	]
	var build_lines := []
	if not ari_alive:
		status_lines.append("Ari died. Press R to restart.")
		mind_lines = [_compact_death_summary(death_recap)]
		build_lines = [_death_resource_line(time_points, short_upgrade_summary)]
	else:
		var selected_cost := _selected_build_cost(state, selected_build_type)
		build_lines = [
			"Build: %s %dst %s    %s" % [
				selected_build_name,
				selected_cost,
				"ON" if build_mode else "OFF",
				_build_counts_line(state),
			],
		]
		var support_line := _support_counts_line(state)
		if support_line != "Support: none":
			build_lines.append(support_line)
		build_lines.append(_combat_summary_line(combat_stats, lesson_count, time_points, short_upgrade_summary))
		if latest_lesson_title != "":
			mind_lines.append("Note: %s" % latest_lesson_title)
		if sign_action_focus != "":
			mind_lines.append(sign_action_focus)
		if ai_status != "":
			mind_lines.append(ai_status)
		if inspect_text != "":
			mind_lines.append(inspect_text)
		if status_message != "":
			mind_lines.append(status_message)
		if mining_enabled:
			build_lines.append("Mining debug ON")
	_update_meter_strip(ari_hp, ari_max_hp, needs)
	status_label.text = "\n".join(status_lines)
	mind_label.text = "\n".join(mind_lines)
	build_label.text = "\n".join(build_lines)
	_update_build_palette(state, selected_build_type, stone, build_mode)


func _combat_stats(state: Dictionary) -> Dictionary:
	var combat_stats = state.get("combat_stats", {})
	if typeof(combat_stats) == TYPE_DICTIONARY:
		return combat_stats
	return {}


func _needs(state: Dictionary) -> Dictionary:
	var needs = state.get("needs", {})
	if typeof(needs) == TYPE_DICTIONARY:
		return needs
	return {}


func _progression(state: Dictionary) -> Dictionary:
	var progression = state.get("permanent_progression", {})
	if typeof(progression) == TYPE_DICTIONARY:
		return progression
	return {}


func _status_header_line(day: int, phase: String, time_left: float, ari_hp: float, ari_max_hp: float, enemy_count: int, stone: int, food: int) -> String:
	return "D%d %s %.0fs   HP %.0f/%.0f   E%d   Stone %d Food %d" % [
		day,
		phase,
		time_left,
		ari_hp,
		ari_max_hp,
		enemy_count,
		stone,
		food,
	]


func _hp_meter(value: float, maximum: float) -> String:
	return "HP [%s] %.0f/%.0f" % [
		_meter_bar(value, maximum, 6),
		value,
		maximum,
	]


func _update_meter_strip(ari_hp: float, ari_max_hp: float, needs: Dictionary) -> void:
	if meter_strip == null or not meter_strip.has_method("set_meter_values"):
		return
	meter_strip.call("set_meter_values", ari_hp, ari_max_hp, float(needs.get("hunger", 0.0)), float(needs.get("fear", 0.0)), float(needs.get("stamina", 0.0)))


func _needs_meter_line(needs: Dictionary) -> String:
	return "Needs %s  %s  %s" % [
		_meter_token("Hu", float(needs.get("hunger", 0.0))),
		_meter_token("Fr", float(needs.get("fear", 0.0))),
		_meter_token("St", float(needs.get("stamina", 0.0))),
	]


func _meter_token(label: String, value: float, maximum := 100.0) -> String:
	return "%s [%s]%.0f" % [
		label,
		_meter_bar(value, maximum, 5),
		value,
	]


func _meter_bar(value: float, maximum: float, width: int) -> String:
	var ratio := clampf(value / maxf(maximum, 1.0), 0.0, 1.0)
	var filled := clampi(int(round(ratio * float(width))), 0, width)
	return "%s%s" % [
		_repeat_char("#", filled),
		_repeat_char("-", width - filled),
	]


func _repeat_char(symbol: String, count: int) -> String:
	var result := ""
	for _i in range(maxi(count, 0)):
		result += symbol
	return result


func _build_counts_line(state: Dictionary) -> String:
	var tokens := _count_tokens(state, [
		{"key": "wall_count", "label": "Wall"},
		{"key": "aura_orb_count", "label": "Orb"},
		{"key": "spike_trap_count", "label": "Trap"},
		{"key": "bow_tower_count", "label": "Tower"},
		{"key": "tar_pit_count", "label": "Mud"},
	])
	if tokens.is_empty():
		return "Built: none"
	return "Built: %s" % "  ".join(tokens)


func _support_counts_line(state: Dictionary) -> String:
	var tokens := _count_tokens(state, [
		{"key": "fear_lantern_count", "label": "Lamp"},
		{"key": "decoy_idol_count", "label": "Decoy"},
		{"key": "thorn_totem_count", "label": "Thorn"},
		{"key": "repair_bench_count", "label": "Repair"},
		{"key": "storm_rod_count", "label": "Storm"},
		{"key": "damaged_structure_count", "label": "Dmg"},
	])
	if tokens.is_empty():
		return "Support: none"
	return "Support: %s" % "  ".join(tokens)


func _count_tokens(state: Dictionary, definitions: Array) -> PackedStringArray:
	var tokens := PackedStringArray()
	for definition in definitions:
		if typeof(definition) != TYPE_DICTIONARY:
			continue
		var count := int(state.get(str(definition.get("key", "")), 0))
		if count <= 0:
			continue
		tokens.append("%s %d" % [
			str(definition.get("label", "?")),
			count,
		])
	return tokens


func _combat_summary_line(combat_stats: Dictionary, lesson_count: int, time_points: int, short_upgrade_summary: String) -> String:
	return "Combat L%.1f  +%d%% dmg  +%d%% def   Notes %d  TP %d  %s" % [
		float(combat_stats.get("combat_level", 0.0)),
		int(round(float(combat_stats.get("damage_bonus", 0.0)) * 100.0)),
		int(round(float(combat_stats.get("defense_training", 0.0)) * 100.0)),
		lesson_count,
		time_points,
		short_upgrade_summary,
	]


func _compact_death_summary(death_recap: String) -> String:
	var recap := death_recap.strip_edges()
	if recap == "":
		return "Death: the night reached Ari.  Tip: add distance, light, or a wall."
	return "Death: %s.  Tip: %s." % [
		_death_cause_text(recap),
		_death_tip_text(recap),
	]


func _death_cause_text(recap: String) -> String:
	if recap.contains("A defense broke"):
		return "a defense broke"
	if recap.contains("Enemies got close enough"):
		return "enemies reached Ari"
	if recap.contains("Nothing stopped"):
		return "the first wave was unchecked"
	if recap.contains("The night reached Ari"):
		return "the night reached Ari"
	return "Ari fell"


func _death_tip_text(recap: String) -> String:
	if recap.contains("No sign guided"):
		return "write a clearer sign"
	if recap.contains("A first wall layer"):
		return "build a first wall"
	if recap.contains("Walls need damage"):
		return "put damage behind walls"
	if recap.contains("Food may keep"):
		return "stock food before night"
	return "layer distance, damage, or light"


func _death_resource_line(time_points: int, short_upgrade_summary: String) -> String:
	return "After death: TP %d  %s" % [time_points, short_upgrade_summary]


func _run_build(state: Dictionary) -> Dictionary:
	var run_build = state.get("run_build", {})
	if typeof(run_build) == TYPE_DICTIONARY:
		return run_build
	return {}


func _run_build_line(state: Dictionary) -> String:
	var run_build := _run_build(state)
	var name := str(state.get("run_build_name", run_build.get("preset_name", "Balanced")))
	var role := str(run_build.get("role", "")).strip_edges()
	var tags := _format_tags(run_build.get("tags", []), 1)
	var line := name
	if tags != "":
		line = "%s | %s" % [name, tags]
	elif role != "":
		line = "%s | %s" % [name, role]
	if line.length() > 32:
		return line.substr(0, 29).strip_edges() + "..."
	return line


func _format_tags(raw_tags, limit := 2) -> String:
	if typeof(raw_tags) != TYPE_ARRAY:
		return ""
	var tags := PackedStringArray()
	for raw_tag in raw_tags:
		var clean_tag := str(raw_tag).strip_edges()
		if clean_tag == "":
			continue
		tags.append(clean_tag)
		if tags.size() >= limit:
			break
	return ", ".join(tags)


func _update_build_palette(state: Dictionary, selected_build_type: String, stone: int, build_mode: bool) -> void:
	if build_palette_panel != null:
		build_palette_panel.visible = build_mode
	if build_palette == null:
		return
	for child in build_palette.get_children():
		build_palette.remove_child(child)
		child.queue_free()
	for item in _build_palette_items():
		build_palette.add_child(_make_build_badge(item, state, selected_build_type, stone))


func _make_build_badge(item: Dictionary, state: Dictionary, selected_build_type: String, stone: int) -> PanelContainer:
	var build_type := str(item.get("type", "wall"))
	var cost := _selected_build_cost(state, build_type)
	var can_afford := stone >= cost
	var selected := build_type == selected_build_type
	var color: Color = item.get("color", Color(0.50, 0.56, 0.52, 1.0))

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(58.0, 31.0)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _build_badge_style(color, selected, can_afford))

	var lines := VBoxContainer.new()
	lines.layout_mode = 2
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 0)
	badge.add_child(lines)

	var top_row := HBoxContainer.new()
	top_row.layout_mode = 2
	top_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", 3)
	lines.add_child(top_row)

	var key_label := Label.new()
	key_label.layout_mode = 2
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.add_theme_color_override("font_color", Color(0.96, 1.0, 0.92, 1.0) if can_afford else Color(0.52, 0.56, 0.52, 1.0))
	key_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	key_label.add_theme_constant_override("shadow_offset_x", 1)
	key_label.add_theme_constant_override("shadow_offset_y", 1)
	key_label.add_theme_font_size_override("font_size", 9)
	key_label.text = str(item.get("key", "?"))
	top_row.add_child(key_label)

	var icon := BuildPaletteIconScript.new()
	icon.setup(build_type, color, can_afford)
	top_row.add_child(icon)

	var cost_label := Label.new()
	cost_label.layout_mode = 2
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.44, 1.0) if can_afford else Color(0.55, 0.46, 0.36, 1.0))
	cost_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	cost_label.add_theme_constant_override("shadow_offset_x", 1)
	cost_label.add_theme_constant_override("shadow_offset_y", 1)
	cost_label.add_theme_font_size_override("font_size", 9)
	cost_label.text = "%d stone" % cost
	lines.add_child(cost_label)
	return badge


func _build_badge_style(color: Color, selected: bool, can_afford: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var base_color := color
	if not can_afford:
		base_color = color.darkened(0.50)
	style.bg_color = base_color.darkened(0.28)
	style.border_color = base_color.lightened(0.12)
	if selected:
		style.bg_color = base_color.darkened(0.08)
		style.border_color = Color(1.0, 0.88, 0.38, 1.0)
	style.border_width_left = 2 if selected else 1
	style.border_width_top = 2 if selected else 1
	style.border_width_right = 2 if selected else 1
	style.border_width_bottom = 2 if selected else 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.content_margin_left = 3.0
	style.content_margin_top = 2.0
	style.content_margin_right = 3.0
	style.content_margin_bottom = 2.0
	return style


func _build_palette_items() -> Array:
	return [
		{"type": "wall", "key": "B", "color": Color(0.48, 0.52, 0.50, 1.0)},
		{"type": "aura_orb", "key": "O", "color": Color(0.18, 0.62, 0.92, 1.0)},
		{"type": "spike_trap", "key": "X", "color": Color(0.78, 0.62, 0.28, 1.0)},
		{"type": "bow_tower", "key": "Y", "color": Color(0.68, 0.46, 0.20, 1.0)},
		{"type": "tar_pit", "key": "C", "color": Color(0.42, 0.30, 0.52, 1.0)},
		{"type": "fear_lantern", "key": "F", "color": Color(0.92, 0.64, 0.24, 1.0)},
		{"type": "decoy_idol", "key": "D", "color": Color(0.86, 0.28, 0.48, 1.0)},
		{"type": "thorn_totem", "key": "H", "color": Color(0.36, 0.74, 0.34, 1.0)},
		{"type": "repair_bench", "key": "K", "color": Color(0.38, 0.78, 0.92, 1.0)},
		{"type": "storm_rod", "key": "L", "color": Color(0.50, 0.86, 1.0, 1.0)},
	]


func _selected_build_cost(state: Dictionary, selected_build_type: String) -> int:
	match selected_build_type:
		"wall":
			return int(state.get("wall_cost", 0))
		"aura_orb":
			return int(state.get("orb_cost", 0))
		"spike_trap":
			return int(state.get("trap_cost", 0))
		"bow_tower":
			return int(state.get("tower_cost", 0))
		"tar_pit":
			return int(state.get("tar_pit_cost", 0))
		"fear_lantern":
			return int(state.get("fear_lantern_cost", 0))
		"decoy_idol":
			return int(state.get("decoy_idol_cost", 0))
		"thorn_totem":
			return int(state.get("thorn_totem_cost", 0))
		"repair_bench":
			return int(state.get("repair_bench_cost", 0))
		"storm_rod":
			return int(state.get("storm_rod_cost", 0))
	return 0
