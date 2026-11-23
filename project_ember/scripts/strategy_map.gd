extends Node2D

## First playable strategic-map slice: a compact axial-hex map, one player army,
## one neutral enemy army, turn-based movement and transition to tactical combat.

const MAP_RADIUS := 5
const HEX_SIZE := 30.0
const PLAYER_TEAM_COLOR := Color(0.16, 0.52, 1.0)
const ENEMY_TEAM_COLOR := Color(0.91, 0.23, 0.18)

const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]

var _cells: Array[Vector2i] = []
var _terrain: Dictionary = {}
var _army_selected: bool = false
var _status_label: Label
var _message_label: Label
var _attack_button: Button
var _turn_button: Button
var _selection_button: Button
var _city_button: Button
var _city_panel: PanelContainer
var _city_overview_label: Label
var _city_title_label: Label
var _settler_button: Button
var _found_city_button: Button
var _settler_selected: bool = false
var _city_income_label: Label
var _city_queue_label: Label
var _hero_overview_label: Label
var _hero_skill_buttons: Dictionary = {}
var _city_building_buttons: Dictionary = {}
var _city_recruit_buttons: Dictionary = {}
var _message_text: String = "P — твоя армия, ! — враг. Выбери P и коснись соседнего гекса."


func _ready() -> void:
	if not CampaignState.campaign_started:
		CampaignState.new_campaign()
	_build_map()
	_create_ui()
	if CampaignState.last_battle_report_pending:
		_show_last_battle_report()
	elif CampaignState.campaign_lost:
		_message_text = "Армия уничтожена. Начни новую кампанию."
	_refresh_ui()
	queue_redraw()


func _draw() -> void:
	for cell in _cells:
		_draw_hex_tile(cell)

	# Claimed borders, settlements, and travelling forces are drawn over the terrain.
	for cell in _cells:
		if CampaignState.get_city_owner_at(cell) >= 0:
			draw_polyline(_closed_polygon(_hex_points(_hex_center(cell))), Color(0.91, 0.72, 0.34, 0.72), 2.0, true)

	for city_data in CampaignState.cities:
		var xy: Array = city_data.get("cell", [])
		if xy.size() >= 2:
			_draw_city_marker(_hex_center(Vector2i(int(xy[0]), int(xy[1]))))

	if CampaignState.settler_active:
		_draw_settler_marker(_hex_center(CampaignState.settler_cell))

	if CampaignState.enemy_present and not CampaignState.enemy_units.is_empty():
		_draw_army_marker(CampaignState.enemy_cell, ENEMY_TEAM_COLOR, "!")
	if not CampaignState.player_units.is_empty():
		_draw_army_marker(CampaignState.player_cell, PLAYER_TEAM_COLOR, "P")

	if _army_selected:
		for offset in NEIGHBOR_OFFSETS:
			var neighbor: Vector2i = CampaignState.player_cell + offset
			if _is_traversable(neighbor) and neighbor != CampaignState.enemy_cell:
				draw_colored_polygon(_hex_points(_hex_center(neighbor)), Color(0.40, 0.73, 0.91, 0.11))
				draw_polyline(_closed_polygon(_hex_points(_hex_center(neighbor))), Color(0.77, 0.91, 1.0, 0.92), 2.3, true)


func _draw_hex_tile(cell: Vector2i) -> void:
	var center := _hex_center(cell)
	var kind := str(_terrain.get(cell, "plain"))
	var points := _hex_points(center)
	var shadow := PackedVector2Array()
	var inner := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(0.0, 4.0))
		inner.append(center + (point - center) * 0.91)
	draw_colored_polygon(shadow, Color(0.015, 0.025, 0.022, 0.62))
	draw_colored_polygon(points, Color(0.10, 0.14, 0.12, 1.0))
	draw_colored_polygon(inner, _terrain_color(kind))
	draw_polyline(_closed_polygon(points), Color(0.28, 0.34, 0.27, 0.95), 1.4, true)

	match kind:
		"forest":
			for index in range(3):
				var offset := Vector2(float(posmod(cell.x * 13 + cell.y * 7 + index * 11, 17) - 8), float(posmod(cell.x * 5 - cell.y * 9 + index * 7, 15) - 7))
				_draw_map_tree(center + offset * 0.72, 0.72 + float(index % 2) * 0.12)
		"hills":
			_draw_map_hills(center, cell)
		"water":
			_draw_map_water(center, cell)
		_:
			_draw_map_grass(center, cell)


func _draw_map_grass(center: Vector2, cell: Vector2i) -> void:
	for index in range(4):
		var seed_value := cell.x * 37 + cell.y * 61 + index * 19
		var offset := Vector2(float(posmod(seed_value, 17) - 8), float(posmod(seed_value * 3, 15) - 7))
		var origin := center + offset
		draw_line(origin, origin + Vector2(-2.0, -4.0), Color(0.68, 0.73, 0.43, 0.58), 1.3, true)
		draw_line(origin, origin + Vector2(2.0, -5.0), Color(0.78, 0.79, 0.49, 0.52), 1.2, true)


func _draw_map_tree(position: Vector2, scale: float) -> void:
	draw_line(position + Vector2(0.0, 2.0), position + Vector2(0.0, 9.0) * scale, Color(0.24, 0.15, 0.09), 2.2, true)
	var crown := PackedVector2Array([
		position + Vector2(0.0, -13.0) * scale,
		position + Vector2(-8.5, 3.0) * scale,
		position + Vector2(8.5, 3.0) * scale,
	])
	draw_colored_polygon(crown, Color(0.12, 0.26, 0.15))
	var crown_light := PackedVector2Array([
		position + Vector2(0.0, -12.0) * scale,
		position + Vector2(-1.0, 1.0) * scale,
		position + Vector2(7.0, 1.0) * scale,
	])
	draw_colored_polygon(crown_light, Color(0.27, 0.42, 0.22, 0.95))


func _draw_map_hills(center: Vector2, cell: Vector2i) -> void:
	var shift := float(posmod(cell.x * 5 + cell.y * 7, 7)) - 3.0
	var hill_back := PackedVector2Array([center + Vector2(-18.0, 6.0), center + Vector2(-3.0 + shift, -12.0), center + Vector2(12.0, 6.0)])
	var hill_front := PackedVector2Array([center + Vector2(-10.0, 8.0), center + Vector2(5.0, -6.0), center + Vector2(19.0, 8.0)])
	draw_colored_polygon(hill_back, Color(0.36, 0.34, 0.25))
	draw_colored_polygon(hill_front, Color(0.54, 0.48, 0.32))
	draw_line(center + Vector2(-3.0 + shift, -12.0), center + Vector2(2.0 + shift, -3.0), Color(0.79, 0.73, 0.55, 0.75), 1.5, true)


func _draw_map_water(center: Vector2, cell: Vector2i) -> void:
	for index in range(3):
		var y := float(index * 8 - 7)
		var offset := float(posmod(cell.x * 9 + cell.y * 13 + index * 5, 9)) - 4.0
		draw_line(center + Vector2(-13.0 + offset, y), center + Vector2(-3.0, y - 2.0), Color(0.65, 0.82, 0.87, 0.65), 1.6, true)
		draw_line(center + Vector2(1.0, y - 2.0), center + Vector2(13.0 - offset * 0.4, y), Color(0.80, 0.89, 0.89, 0.55), 1.4, true)


func _draw_city_marker(center: Vector2) -> void:
	draw_circle(center + Vector2(0.0, 3.0), 17.0, Color(0.02, 0.025, 0.02, 0.55))
	draw_rect(Rect2(center + Vector2(-11.0, -7.0), Vector2(22.0, 17.0)), Color(0.61, 0.54, 0.39))
	draw_rect(Rect2(center + Vector2(-15.0, -12.0), Vector2(8.0, 18.0)), Color(0.72, 0.64, 0.45))
	draw_rect(Rect2(center + Vector2(7.0, -12.0), Vector2(8.0, 18.0)), Color(0.72, 0.64, 0.45))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-17.0, -12.0), center + Vector2(-11.0, -20.0), center + Vector2(-5.0, -12.0)]), Color(0.45, 0.20, 0.15))
	draw_colored_polygon(PackedVector2Array([center + Vector2(5.0, -12.0), center + Vector2(11.0, -20.0), center + Vector2(17.0, -12.0)]), Color(0.45, 0.20, 0.15))
	draw_rect(Rect2(center + Vector2(-3.0, 1.0), Vector2(6.0, 9.0)), Color(0.21, 0.19, 0.15))
	draw_line(center + Vector2(0.0, -19.0), center + Vector2(0.0, -29.0), Color(0.78, 0.66, 0.39), 2.0)
	draw_colored_polygon(PackedVector2Array([center + Vector2(1.0, -28.0), center + Vector2(12.0, -25.0), center + Vector2(1.0, -21.0)]), Color(0.72, 0.22, 0.16))


func _draw_settler_marker(center: Vector2) -> void:
	draw_circle(center + Vector2(0.0, 3.0), 13.0, Color(0.02, 0.02, 0.015, 0.5))
	draw_colored_polygon(PackedVector2Array([center + Vector2(-10.0, 5.0), center + Vector2(0.0, -9.0), center + Vector2(10.0, 5.0)]), Color(0.65, 0.48, 0.27))
	draw_line(center + Vector2(-10.0, 5.0), center + Vector2(10.0, 5.0), Color(0.90, 0.78, 0.54), 2.0)
	draw_circle(center, 3.5, Color(0.96, 0.84, 0.43))





func _build_map() -> void:
	_cells.clear()
	_terrain.clear()
	for q in range(-MAP_RADIUS, MAP_RADIUS + 1):
		for r in range(-MAP_RADIUS, MAP_RADIUS + 1):
			var cell := Vector2i(q, r)
			if _hex_distance(Vector2i.ZERO, cell) > MAP_RADIUS:
				continue
			_cells.append(cell)
			_terrain[cell] = _generate_terrain(cell)

	# Keep the initial approach between the armies open so the first campaign is playable.
	for q in range(-2, 3):
		_terrain[Vector2i(q, 0)] = "plain"
	_terrain[CampaignState.player_cell] = "plain"
	_terrain[CampaignState.enemy_cell] = "plain"
	_terrain[CampaignState.city_cell] = "plain"
	_terrain[CampaignState.city_cell + Vector2i(0, 1)] = "plain"
	if CampaignState.settler_active:
		_terrain[CampaignState.settler_cell] = "plain"


func _generate_terrain(cell: Vector2i) -> String:
	if cell.y != 0:
		var value := absi(cell.x * 17 + cell.y * 29 + cell.x * cell.y * 7)
		if value % 13 == 0:
			return "water"
		if value % 5 == 0:
			return "forest"
		if value % 7 == 0:
			return "hills"
	return "plain"


func _terrain_color(kind: String) -> Color:
	match kind:
		"forest":
			return Color(0.20, 0.39, 0.27)
		"hills":
			return Color(0.48, 0.43, 0.31)
		"water":
			return Color(0.18, 0.34, 0.49)
		_:
			return Color(0.38, 0.49, 0.32)


func _terrain_symbol(kind: String) -> String:
	match kind:
		"forest":
			return "F"
		"hills":
			return "H"
		"water":
			return "~"
		_:
			return ""


func _hex_center(cell: Vector2i) -> Vector2:
	var viewport_size := get_viewport_rect().size
	var origin := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.46)
	var x := sqrt(3.0) * HEX_SIZE * (float(cell.x) + float(cell.y) * 0.5)
	var y := 1.5 * HEX_SIZE * float(cell.y)
	return origin + Vector2(x, y)


func _hex_points(center: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		var angle := deg_to_rad(-30.0 + 60.0 * float(index))
		points.append(center + Vector2(cos(angle), sin(angle)) * HEX_SIZE * 0.94)
	return points


func _closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	if not closed.is_empty():
		closed.append(closed[0])
	return closed


func _create_ui() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var top_panel := PanelContainer.new()
	top_panel.anchor_left = 0.0
	top_panel.anchor_top = 0.0
	top_panel.anchor_right = 1.0
	top_panel.anchor_bottom = 0.0
	top_panel.offset_left = 10.0
	top_panel.offset_top = 8.0
	top_panel.offset_right = -10.0
	top_panel.offset_bottom = 92.0
	top_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.075, 0.94)))
	root.add_child(top_panel)

	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 2)
	top_panel.add_child(top_box)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	top_box.add_child(_status_label)

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", 13)
	_message_label.add_theme_color_override("font_color", Color(0.84, 0.91, 0.96))
	top_box.add_child(_message_label)

	var bottom_panel := PanelContainer.new()
	bottom_panel.anchor_left = 0.0
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_left = 10.0
	bottom_panel.offset_top = -180.0
	bottom_panel.offset_right = -10.0
	bottom_panel.offset_bottom = -8.0
	bottom_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.035, 0.05, 0.96)))
	root.add_child(bottom_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_bottom", 6)
	bottom_panel.add_child(margin)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 5)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(grid)

	_selection_button = _add_button(grid, "ВЫБРАТЬ АРМИЮ", _select_player_army)
	_city_button = _add_button(grid, "ОТКРЫТЬ ГОРОД", _open_city)
	_turn_button = _add_button(grid, "СЛЕДУЮЩИЙ ХОД", _advance_turn)
	_attack_button = _add_button(grid, "АТАКОВАТЬ", _attack_enemy)
	_add_button(grid, "НОВАЯ КАМПАНИЯ", _restart_campaign)
	_found_city_button = _add_button(grid, "ОСНОВАТЬ ГОРОД", _found_city)
	_create_city_panel(root)
	_refresh_ui()


func _create_city_panel(root: Control) -> void:
	_city_panel = PanelContainer.new()
	_city_panel.anchor_left = 0.07
	_city_panel.anchor_top = 0.11
	_city_panel.anchor_right = 0.93
	_city_panel.anchor_bottom = 0.88
	_city_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.075, 0.985)))
	_city_panel.visible = false
	root.add_child(_city_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_city_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	_city_title_label = Label.new()
	_city_title_label.text = "ГОРОД — " + CampaignState.city_name
	_city_title_label.add_theme_font_size_override("font_size", 23)
	_city_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
	_city_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_city_title_label)
	var close_button := _add_button(header, "ЗАКРЫТЬ", _close_city)
	close_button.custom_minimum_size = Vector2(120.0, 42.0)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	scroll.add_child(details)

	_city_overview_label = Label.new()
	_city_overview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_city_overview_label.add_theme_font_size_override("font_size", 16)
	_city_overview_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.98))
	details.add_child(_city_overview_label)

	_city_income_label = Label.new()
	_city_income_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_city_income_label.add_theme_font_size_override("font_size", 14)
	_city_income_label.add_theme_color_override("font_color", Color(0.65, 0.85, 0.72))
	details.add_child(_city_income_label)

	_city_queue_label = Label.new()
	_city_queue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_city_queue_label.add_theme_font_size_override("font_size", 14)
	_city_queue_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.48))
	details.add_child(_city_queue_label)

	var hero_title := Label.new()
	hero_title.text = "ПРАВИТЕЛЬ И КОМАНДИР"
	hero_title.add_theme_font_size_override("font_size", 17)
	hero_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.38))
	details.add_child(hero_title)

	_hero_overview_label = Label.new()
	_hero_overview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hero_overview_label.add_theme_font_size_override("font_size", 14)
	_hero_overview_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.98))
	details.add_child(_hero_overview_label)

	var hero_skill_grid := GridContainer.new()
	hero_skill_grid.columns = 3
	hero_skill_grid.add_theme_constant_override("h_separation", 7)
	hero_skill_grid.add_theme_constant_override("v_separation", 5)
	details.add_child(hero_skill_grid)
	for skill_id in ["leadership", "tactics", "might"]:
		var skill_button := _add_button(hero_skill_grid, "НАВЫК", _upgrade_hero_skill.bind(skill_id))
		skill_button.custom_minimum_size = Vector2(0.0, 58.0)
		skill_button.add_theme_font_size_override("font_size", 12)
		_hero_skill_buttons[skill_id] = skill_button

	var building_title := Label.new()
	building_title.text = "СТРОИТЕЛЬСТВО"
	building_title.add_theme_font_size_override("font_size", 16)
	building_title.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	details.add_child(building_title)

	var building_grid := GridContainer.new()
	building_grid.columns = 2
	building_grid.add_theme_constant_override("h_separation", 8)
	building_grid.add_theme_constant_override("v_separation", 6)
	details.add_child(building_grid)
	for building_id in ["farm", "market", "workshop", "barracks", "archery_range", "stable"]:
		var data: Dictionary = CampaignState.get_city_building_data(building_id)
		var button_text := "%s\n%d зол. · %d пр.\n%s" % [str(data.get("name", "Здание")), int(data.get("gold_cost", 0)), int(data.get("production_cost", 0)), str(data.get("description", ""))]
		var building_button := _add_button(building_grid, button_text, _queue_building.bind(building_id))
		building_button.custom_minimum_size = Vector2(0.0, 66.0)
		building_button.add_theme_font_size_override("font_size", 13)
		_city_building_buttons[building_id] = building_button

	var recruit_title := Label.new()
	recruit_title.text = "НАЙМ ВОЙСК"
	recruit_title.add_theme_font_size_override("font_size", 16)
	recruit_title.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	details.add_child(recruit_title)

	var recruit_grid := GridContainer.new()
	recruit_grid.columns = 2
	recruit_grid.add_theme_constant_override("h_separation", 8)
	recruit_grid.add_theme_constant_override("v_separation", 6)
	details.add_child(recruit_grid)
	for role_id in [CampaignState.ROLE_MELEE, CampaignState.ROLE_RANGED, CampaignState.ROLE_SPEAR, CampaignState.ROLE_CAVALRY]:
		var recruit_data: Dictionary = CampaignState.get_recruit_data(role_id)
		var button_text := "%s\n%d зол. · %d пр." % [str(recruit_data.get("name", "Отряд")), int(recruit_data.get("gold_cost", 0)), int(recruit_data.get("production_cost", 0))]
		var recruit_button := _add_button(recruit_grid, button_text, _queue_recruit.bind(role_id))
		recruit_button.custom_minimum_size = Vector2(0.0, 58.0)
		recruit_button.add_theme_font_size_override("font_size", 13)
		_city_recruit_buttons[role_id] = recruit_button

	_settler_button = _add_button(details, "ПОСТРОИТЬ ПОСЕЛЕНЦА · 45 зол. · 10 пр.", _queue_settler)
	_settler_button.custom_minimum_size = Vector2(0.0, 52.0)
	_settler_button.add_theme_font_size_override("font_size", 13)

	var hint := Label.new()
	hint.text = "Заказы оплачиваются золотом сразу, производство накапливается каждый ход. Казармы открывают мечников и копейщиков; стрельбище — лучников; конюшня — кавалерию. Стрельбище и конюшня требуют казарм. Поселенец основывает город не ближе 3 гексов."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.68, 0.75, 0.83))
	details.add_child(hint)
	_refresh_city_panel()


func _open_city() -> void:
	if CampaignState.cities.is_empty() or not is_instance_valid(_city_panel):
		return
	_city_panel.visible = true
	_refresh_city_panel()


func _close_city() -> void:
	if is_instance_valid(_city_panel):
		_city_panel.visible = false


func _queue_building(building_id: String) -> void:
	if CampaignState.queue_building(building_id):
		var building_data: Dictionary = CampaignState.get_city_building_data(building_id)
		_message_text = "%s добавлена в очередь. Производство завершится за несколько ходов." % str(building_data.get("name", "Постройка"))
	else:
		_message_text = "Не хватает золота или это здание уже построено/заказано."
	_refresh_city_panel()
	_refresh_ui()
	queue_redraw()


func _queue_recruit(role_name: String) -> void:
	if CampaignState.queue_recruit(role_name):
		_message_text = "Отряд добавлен в очередь найма."
	else:
		_message_text = "Для найма нужны готовые казармы, золото и свободное место в армии."
	_refresh_city_panel()
	_refresh_ui()


func _upgrade_hero_skill(skill_id: String) -> void:
	if CampaignState.upgrade_hero_skill(skill_id):
		var skill_names := {"leadership": "Лидерство", "tactics": "Тактика", "might": "Сила"}
		_message_text = "Навык героя улучшен: %s. Изменения действуют со следующего сражения." % str(skill_names.get(skill_id, skill_id))
	else:
		_message_text = "Нет очков навыков или этот навык уже достиг максимального ранга."
	_refresh_city_panel()
	_refresh_ui()


func _queue_settler() -> void:
	if CampaignState.queue_settler():
		_message_text = "Поселенец добавлен в очередь города."
	else:
		_message_text = "Нужны 45 золота, 3 жителя и отсутствие другого поселенца."
	_refresh_city_panel()
	_refresh_ui()

func _found_city() -> void:
	if CampaignState.found_city(CampaignState.settler_cell):
		if _terrain.has(CampaignState.city_cell):
			_terrain[CampaignState.city_cell] = "plain"
		_settler_selected = false
		_message_text = "Основан новый город: " + CampaignState.city_name
		_close_city()
	else:
		_message_text = "Нужно свободное место не ближе 3 гексов от других городов."
	_refresh_city_panel()
	_refresh_ui()
	queue_redraw()

func _refresh_city_panel() -> void:
	if not is_instance_valid(_city_overview_label):
		return
	var income: Dictionary = CampaignState.get_city_income()
	if is_instance_valid(_city_title_label):
		_city_title_label.text = "ГОРОД — " + CampaignState.city_name
	_city_overview_label.text = "%s · население: %d · армия: %d/%d\nЗолото: %d · Еда: %d · Производство в запасе: %d\nСостав: %s" % [
		CampaignState.city_name,
		CampaignState.city_population,
		CampaignState.player_units.size(),
		CampaignState.ARMY_CAPACITY,
		CampaignState.city_gold,
		CampaignState.city_food,
		CampaignState.city_production_bank,
		_get_army_composition_text(),
	]
	_city_income_label.text = "Доход за ход: +%d еды · +%d золота · +%d производства" % [
		int(income["food"]),
		int(income["gold"]),
		int(income["production"]),
	]
	_city_queue_label.text = CampaignState.get_city_queue_summary()
	var hero: Dictionary = CampaignState.player_hero
	var hero_skills_value: Variant = hero.get("skills", {})
	var hero_skills: Dictionary = hero_skills_value if hero_skills_value is Dictionary else {}
	var hero_health := float(hero.get("health", CampaignState.get_hero_max_health(hero)))
	var hero_max_health := CampaignState.get_hero_max_health(hero)
	_hero_overview_label.text = "%s · %s\nУровень %d · Опыт %d/%d · Очки навыков: %d\nЗдоровье: %.0f/%.0f · Раны: %d" % [
		str(hero.get("name", "Правитель")),
		str(hero.get("title", "Командир")),
		int(hero.get("level", 1)),
		int(hero.get("experience", 0)),
		CampaignState.get_hero_xp_to_next_level(),
		int(hero.get("skill_points", 0)),
		hero_health,
		hero_max_health,
		int(hero.get("wounded_turns", 0)),
	]
	var skill_names := {"leadership": "ЛИДЕРСТВО", "tactics": "ТАКТИКА", "might": "СИЛА"}
	for skill_id in _hero_skill_buttons:
		var skill_rank := clampi(int(hero_skills.get(skill_id, 0)), 0, 5)
		var skill_button: Button = _hero_skill_buttons[skill_id]
		skill_button.text = "%s\nРАНГ %d/5" % [str(skill_names.get(skill_id, skill_id)).to_upper(), skill_rank]
		skill_button.disabled = int(hero.get("skill_points", 0)) <= 0 or skill_rank >= 5

	if is_instance_valid(_settler_button):
		_settler_button.disabled = not CampaignState.can_queue_settler()
	for building_id in _city_building_buttons:
		var button: Button = _city_building_buttons[building_id]
		var data: Dictionary = CampaignState.get_city_building_data(str(building_id))
		if CampaignState.city_has_building(str(building_id)):
			button.text = "%s\nПОСТРОЕНО" % str(data.get("name", "Здание"))
			button.disabled = true
		elif CampaignState.city_is_building_queued(str(building_id)):
			button.text = "%s\nВ ОЧЕРЕДИ" % str(data.get("name", "Здание"))
			button.disabled = true
		else:
			button.text = "%s\n%d зол. · %d пр.\n%s" % [str(data.get("name", "Здание")), int(data.get("gold_cost", 0)), int(data.get("production_cost", 0)), str(data.get("description", ""))]
			button.disabled = not CampaignState.can_queue_building(str(building_id))

	for role_id in _city_recruit_buttons:
		var role_name := str(role_id)
		var recruit_button: Button = _city_recruit_buttons[role_name]
		var recruit_data: Dictionary = CampaignState.get_recruit_data(role_name)
		var unlock_building := str(recruit_data.get("unlock_building", "barracks"))
		var building_data: Dictionary = CampaignState.get_city_building_data(unlock_building)
		var unlocked := CampaignState.city_has_building(unlock_building)
		recruit_button.disabled = not CampaignState.can_queue_recruit(role_name)
		if not unlocked:
			recruit_button.text = "%s\nНУЖНО: %s" % [str(recruit_data.get("name", "Отряд")).to_upper(), str(building_data.get("name", "Здание")).to_upper()]
		else:
			recruit_button.text = "%s\n%d зол. · %d пр." % [str(recruit_data.get("name", "Отряд")).to_upper(), int(recruit_data.get("gold_cost", 0)), int(recruit_data.get("production_cost", 0))]


func _get_army_composition_text() -> String:
	var counts := {"melee": 0, "ranged": 0, "spear": 0, "cavalry": 0}
	for record in CampaignState.player_units:
		var role_id := str(record.get("role", "melee"))
		if counts.has(role_id):
			counts[role_id] = int(counts[role_id]) + 1
	return "мечники %d · лучники %d · копейщики %d · кавалерия %d" % [
		counts["melee"], counts["ranged"], counts["spear"], counts["cavalry"],
	]


func _panel_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.59, 0.45, 0.25, 0.96)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	style.shadow_size = 5
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	return style


func _add_button(parent: Container, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.14, 0.12, 0.09)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.24, 0.19, 0.12)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.25, 0.28, 0.15)))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.19, 0.16, 0.11)))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _button_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.66, 0.54, 0.34, 0.96)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 3
	return style


func _unhandled_input(event: InputEvent) -> void:
	if CampaignState.campaign_lost or CampaignState.battle_in_progress:
		return
	# Android touch is translated to mouse input by project.godot; using one
	# event path prevents a single tap from being processed twice.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_map_tap(event.position)


func _handle_map_tap(screen_position: Vector2) -> void:
	var cell := _screen_to_cell(screen_position)
	if cell == Vector2i(9999, 9999):
		return

	if CampaignState.settler_active and cell == CampaignState.settler_cell:
		_settler_selected = true
		_army_selected = false
		_message_text = "Поселенец выбран. Перемести его на свободный гекс и нажми ОСНОВАТЬ ГОРОД."
		_refresh_ui()
		queue_redraw()
		return

	if _settler_selected and CampaignState.settler_active:
		if _hex_distance(CampaignState.settler_cell, cell) == 1 and _is_traversable(cell) and CampaignState.get_city_index_at(cell) < 0 and cell != CampaignState.player_cell and (not CampaignState.enemy_present or cell != CampaignState.enemy_cell) and CampaignState.settler_moves_left > 0:
			CampaignState.settler_cell = cell
			CampaignState.settler_moves_left -= 1
			CampaignState.save_campaign()
			_message_text = "Поселенец перемещён. Нажми ОСНОВАТЬ ГОРОД."
			_refresh_ui()
			queue_redraw()
			return

	if CampaignState.get_city_index_at(cell) >= 0:
		CampaignState.select_city_at(cell)
		_open_city()
		_refresh_city_panel()
		return

	if cell == CampaignState.player_cell:
		_settler_selected = false
		_army_selected = true
		_message_text = "Армия выбрана. Коснись соседнего гекса для перемещения."
		_refresh_ui()
		queue_redraw()
		return

	if CampaignState.enemy_present and cell == CampaignState.enemy_cell:
		if _hex_distance(CampaignState.player_cell, CampaignState.enemy_cell) <= 1:
			_attack_enemy()
		else:
			_message_text = "Вражеская армия далеко: подойди к ней по соседним гексам."
		_refresh_ui()
		return

	if not _army_selected:
		_message_text = "Сначала выбери синюю армию или нажми ВЫБРАТЬ АРМИЮ."
		_refresh_ui()
		return

	if not _is_traversable(cell):
		_message_text = "Вода непроходима. Выбери другой гекс."
		_refresh_ui()
		return

	if _hex_distance(CampaignState.player_cell, cell) != 1:
		_message_text = "За один ход армия перемещается на соседний гекс."
		_refresh_ui()
		return

	if CampaignState.player_moves_left <= 0:
		_message_text = "Движение на этот ход закончено. Нажми СЛЕДУЮЩИЙ ХОД."
		_refresh_ui()
		return

	CampaignState.player_cell = cell
	CampaignState.player_moves_left -= 1
	CampaignState.save_campaign()
	_message_text = "Армия переместилась. Теперь можно завершить ход или атаковать врага, если он рядом."
	_refresh_ui()
	queue_redraw()


func _screen_to_cell(screen_position: Vector2) -> Vector2i:
	var closest_cell := Vector2i(9999, 9999)
	var closest_distance := HEX_SIZE
	for cell in _cells:
		var distance := screen_position.distance_to(_hex_center(cell))
		if distance < closest_distance:
			closest_distance = distance
			closest_cell = cell
	return closest_cell


func _select_player_army() -> void:
	_settler_selected = false
	_army_selected = true
	_message_text = "Армия выбрана. Коснись соседнего гекса для перемещения."
	_refresh_ui()
	queue_redraw()


func _attack_enemy() -> void:
	if not CampaignState.enemy_present:
		_message_text = "Вражеского отряда больше нет."
		_refresh_ui()
		return
	if _hex_distance(CampaignState.player_cell, CampaignState.enemy_cell) > 1:
		_message_text = "Чтобы начать бой, подойди к вражеской армии вплотную."
		_refresh_ui()
		return
	if CampaignState.begin_battle():
		get_tree().change_scene_to_file("res://scenes/combat_test.tscn")


func _advance_turn() -> void:
	if CampaignState.campaign_lost or CampaignState.battle_in_progress:
		return
	# A turn can be ended early; any unused movement point is simply forfeited.
	CampaignState.advance_campaign_turn()
	if CampaignState.settler_active and _terrain.has(CampaignState.settler_cell):
		_terrain[CampaignState.settler_cell] = "plain"
	_enemy_take_turn()
	CampaignState.save_campaign()
	if CampaignState.enemy_present and _hex_distance(CampaignState.player_cell, CampaignState.enemy_cell) <= 1:
		_message_text = "Вражеская армия приблизилась! Нажми АТАКОВАТЬ, чтобы начать бой."
	else:
		_message_text = "Наступил ход %d. Твоя армия может переместиться на один гекс." % CampaignState.turn_number
	if not CampaignState.city_last_event.is_empty():
		_message_text += " Город: " + CampaignState.city_last_event
	_refresh_city_panel()
	_refresh_ui()
	queue_redraw()


func _enemy_take_turn() -> void:
	if not CampaignState.enemy_present:
		return
	var current_distance := _hex_distance(CampaignState.enemy_cell, CampaignState.player_cell)
	if current_distance <= 1:
		return

	var best_cell: Vector2i = CampaignState.enemy_cell
	var best_distance: int = current_distance
	for offset in NEIGHBOR_OFFSETS:
		var candidate: Vector2i = CampaignState.enemy_cell + offset
		if not _is_traversable(candidate) or candidate == CampaignState.player_cell or CampaignState.get_city_index_at(candidate) >= 0:
			continue
		var candidate_distance := _hex_distance(candidate, CampaignState.player_cell)
		if candidate_distance < best_distance:
			best_distance = candidate_distance
			best_cell = candidate
	if best_cell != CampaignState.enemy_cell:
		CampaignState.enemy_cell = best_cell


func _restart_campaign() -> void:
	_close_city()
	CampaignState.new_campaign()
	_army_selected = false
	_message_text = "Новая кампания началась. Выбери синюю армию."
	_build_map()
	_refresh_ui()
	queue_redraw()


func _show_last_battle_report() -> void:
	var result: Dictionary = CampaignState.last_battle_result
	var victory := bool(result.get("victory", false))
	var losses := int(result.get("player_losses", 0))
	var survivors := int(result.get("player_survivors", CampaignState.player_units.size()))
	var hero_xp_gained := int(result.get("hero_xp_gained", 0))
	var hero_level := int(result.get("hero_level", CampaignState.player_hero.get("level", 1)))
	if victory:
		_message_text = "Победа! Выживших: %d. Потери: %d. Командир получил %d опыта (ур. %d). Вражеский лагерь захвачен." % [survivors, losses, hero_xp_gained, hero_level]
	else:
		_message_text = "Поражение. Твоя армия уничтожена. Можно начать новую кампанию."
	CampaignState.last_battle_report_pending = false
	CampaignState.save_campaign()


func _refresh_ui() -> void:
	if not is_instance_valid(_status_label):
		return
	var enemy_count: int = CampaignState.enemy_units.size() if CampaignState.enemy_present else 0
	var hero_name := str(CampaignState.player_hero.get("name", "Правитель"))
	_status_label.text = "ХОД %d · АРМИЯ %d · ВРАГ %d · ЗОЛОТО %d · %s УР.%d" % [
		CampaignState.turn_number,
		CampaignState.player_units.size(),
		enemy_count,
		CampaignState.city_gold,
		hero_name,
		int(CampaignState.player_hero.get("level", 1)),
	]
	_message_label.text = _message_text
	if is_instance_valid(_attack_button):
		_attack_button.disabled = not CampaignState.enemy_present or _hex_distance(CampaignState.player_cell, CampaignState.enemy_cell) > 1 or CampaignState.player_units.is_empty()
	if is_instance_valid(_turn_button):
		_turn_button.disabled = CampaignState.campaign_lost
	if is_instance_valid(_selection_button):
		_selection_button.disabled = CampaignState.campaign_lost
	if is_instance_valid(_city_button):
		_city_button.disabled = CampaignState.cities.is_empty() or CampaignState.campaign_lost
	if is_instance_valid(_found_city_button):
		_found_city_button.disabled = not CampaignState.settler_active or not CampaignState.can_found_city(CampaignState.settler_cell) or not _is_traversable(CampaignState.settler_cell)
	if is_instance_valid(_city_panel) and _city_panel.visible:
		_refresh_city_panel()


func _is_traversable(cell: Vector2i) -> bool:
	return _terrain.has(cell) and str(_terrain[cell]) != "water"


func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	return int((absi(a.x - b.x) + absi(a.y - b.y) + absi((a.x + a.y) - (b.x + b.y))) / 2)