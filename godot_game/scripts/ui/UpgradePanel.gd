extends CanvasLayer

const UpgradeIconScript := preload("res://scripts/ui/UpgradeIcon.gd")

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var summary_label: Label = %SummaryLabel
@onready var grid: GridContainer = %UpgradeGrid


func _ready() -> void:
	panel.visible = false
	grid.add_theme_constant_override("v_separation", 3)


func toggle() -> void:
	panel.visible = not panel.visible


func set_open(open: bool) -> void:
	panel.visible = open


func is_open() -> bool:
	return panel.visible


func update_state(state: Dictionary) -> void:
	var progression := _progression_state(state)
	var time_points := int(progression.get("time_points", 0))
	var deaths := int(progression.get("deaths", 0))
	var best_day := int(progression.get("best_day", 1))
	var rows := _upgrade_rows(progression)
	title_label.text = "Permanent Upgrades"
	summary_label.text = "TP %d  deaths %d  best day %d  |  1-0 buys, U closes" % [time_points, deaths, best_day]
	_clear_grid()
	for row in rows:
		grid.add_child(_make_upgrade_card(row))


func _progression_state(state: Dictionary) -> Dictionary:
	var progression = state.get("permanent_progression", {})
	if typeof(progression) == TYPE_DICTIONARY:
		return progression
	return {}


func _upgrade_rows(progression: Dictionary) -> Array:
	var rows = progression.get("upgrade_rows", [])
	if typeof(rows) == TYPE_ARRAY:
		return rows
	return []


func _clear_grid() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()


func _make_upgrade_card(row: Dictionary) -> PanelContainer:
	var level := int(row.get("level", 0))
	var max_level := int(row.get("max_level", 0))
	var cost := int(row.get("cost", 0))
	var can_buy := bool(row.get("can_buy", false))
	var is_maxed := level >= max_level

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(176.0, 42.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _card_style(can_buy, is_maxed))

	var row_box := HBoxContainer.new()
	row_box.layout_mode = 2
	row_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_box.add_theme_constant_override("separation", 5)
	card.add_child(row_box)

	row_box.add_child(_make_icon_badge(row, can_buy, is_maxed))

	var text := Label.new()
	text.layout_mode = 2
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_color_override("font_color", Color(0.98, 0.94, 0.78, 1.0))
	text.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	text.add_theme_constant_override("shadow_offset_x", 1)
	text.add_theme_constant_override("shadow_offset_y", 1)
	text.add_theme_font_size_override("font_size", 10)

	var state_text := "max" if is_maxed else "cost %d" % cost
	var ready_text := "ready" if can_buy else state_text
	var role := str(row.get("role", "")).strip_edges()
	var tags := _format_tags(row.get("tags", []))
	var role_line := role if role != "" else "General"
	if tags != "":
		role_line = "%s | %s" % [role_line, tags]
	text.text = "%s %s  L%d/%d %s\n%s" % [
		str(row.get("key", "?")),
		str(row.get("label", "Upgrade")),
		level,
		max_level,
		ready_text,
		role_line,
	]
	row_box.add_child(text)
	return card


func _make_icon_badge(row: Dictionary, can_buy: bool, is_maxed: bool) -> PanelContainer:
	var upgrade_id := str(row.get("id", ""))
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(30.0, 30.0)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", _badge_style(upgrade_id, can_buy, is_maxed))

	var icon := UpgradeIconScript.new()
	icon.layout_mode = 2
	icon.custom_minimum_size = Vector2(24.0, 24.0)
	icon.setup(upgrade_id, _badge_color(upgrade_id), can_buy, is_maxed)
	badge.add_child(icon)
	return badge


func _format_tags(raw_tags) -> String:
	if typeof(raw_tags) != TYPE_ARRAY:
		return ""
	var tags := PackedStringArray()
	for raw_tag in raw_tags:
		var clean_tag := str(raw_tag).strip_edges()
		if clean_tag == "":
			continue
		tags.append(clean_tag)
		if tags.size() >= 2:
			break
	return "/".join(tags)


func _card_style(can_buy: bool, is_maxed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.073, 0.060, 0.88)
	style.border_color = Color(0.36, 0.34, 0.20, 0.86)
	if can_buy:
		style.bg_color = Color(0.13, 0.11, 0.045, 0.94)
		style.border_color = Color(0.86, 0.68, 0.22, 0.96)
	elif is_maxed:
		style.bg_color = Color(0.055, 0.090, 0.070, 0.90)
		style.border_color = Color(0.36, 0.70, 0.46, 0.86)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.content_margin_left = 7.0
	style.content_margin_top = 5.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 5.0
	return style


func _badge_style(upgrade_id: String, can_buy: bool, is_maxed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var base_color := _badge_color(upgrade_id)
	style.bg_color = base_color.darkened(0.35)
	style.border_color = base_color.lightened(0.18)
	if can_buy:
		style.bg_color = base_color.darkened(0.15)
		style.border_color = Color(1.0, 0.84, 0.34, 1.0)
	elif is_maxed:
		style.bg_color = Color(0.08, 0.18, 0.12, 0.96)
		style.border_color = Color(0.52, 0.92, 0.58, 1.0)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.content_margin_left = 2.0
	style.content_margin_top = 2.0
	style.content_margin_right = 2.0
	style.content_margin_bottom = 2.0
	return style


func _badge_color(upgrade_id: String) -> Color:
	match upgrade_id:
		"max_hp":
			return Color(0.78, 0.16, 0.22, 1.0)
		"base_damage":
			return Color(0.92, 0.45, 0.14, 1.0)
		"defense":
			return Color(0.34, 0.50, 0.80, 1.0)
		"mining_efficiency":
			return Color(0.52, 0.50, 0.46, 1.0)
		"building_efficiency":
			return Color(0.62, 0.44, 0.24, 1.0)
		"farming_yield":
			return Color(0.38, 0.68, 0.28, 1.0)
		"warding_power":
			return Color(0.20, 0.62, 0.88, 1.0)
		"trapcraft":
			return Color(0.84, 0.66, 0.24, 1.0)
		"regeneration":
			return Color(0.36, 0.72, 0.58, 1.0)
		"movement_speed_small":
			return Color(0.42, 0.74, 0.82, 1.0)
		"sign_understanding":
			return Color(0.70, 0.42, 0.88, 1.0)
	return Color(0.55, 0.55, 0.55, 1.0)
