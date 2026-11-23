extends Node2D

## First playable strategic-map slice: a compact axial-hex map, one player army,
## one neutral enemy army, turn-based movement and transition to tactical combat.

const MAP_RADIUS := 5
const HEX_SIZE := 26.0
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
	var font: Font = ThemeDB.fallback_font
	for cell in _cells:
		var center := _hex_center(cell)
		var points := _hex_points(center)
		draw_colored_polygon(points, _terrain_color(str(_terrain.get(cell, "plain"))))
		var outline_color := Color(0.16, 0.22, 0.25, 0.95)
		if _army_selected and cell == CampaignState.player_cell:
			outline_color = Color(1.0, 0.88, 0.25, 1.0)
		draw_polyline(_closed_polygon(points), outline_color, 2.2, true)

		var symbol := _terrain_symbol(str(_terrain.get(cell, "plain")))
		if not symbol.is_empty():
			draw_string(font, center + Vector2(-5.0, 5.0), symbol, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 15, Color(0.10, 0.15, 0.12, 0.9))

	# Claimed territory and all founded cities.
	for cell in _cells:
		if CampaignState.get_city_owner_at(cell) >= 0:
			draw_polyline(_closed_polygon(_hex_points(_hex_center(cell))), Color(0.86, 0.73, 0.35, 0.55), 1.5, true)
	for city_data in CampaignState.cities:
		var xy: Array = city_data.get("cell", [])
		if xy.size() < 2:
			continue
		var city_center := _hex_center(Vector2i(int(xy[0]), int(xy[1])))
		draw_rect(Rect2(city_center - Vector2(10.0, 10.0), Vector2(20.0, 20.0)), Color(0.91, 0.72, 0.25), true)
		draw_string(font, city_center + Vector2(-5.0, 5.0), "C", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.12, 0.12, 0.10))
	if CampaignState.settler_active:
		var settler_center := _hex_center(CampaignState.settler_cell)
		draw_circle(settler_center, 13.0, Color(0.92, 0.82, 0.32))
		draw_string(font, settler_center + Vector2(-5.0, 5.0), "S", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.10, 0.12, 0.10))

	if CampaignState.enemy_present and not CampaignState.enemy_units.is_empty():
		_draw_army_marker(CampaignState.enemy_cell, ENEMY_TEAM_COLOR, "!")
	if not CampaignState.player_units.is_empty():
		_draw_army_marker(CampaignState.player_cell, PLAYER_TEAM_COLOR, "P")

	if _army_selected:
		for offset in NEIGHBOR_OFFSETS:
			var neighbor: Vector2i = CampaignState.player_cell + offset
			if _is_traversable(neighbor) and neighbor != CampaignState.enemy_cell:
				draw_arc(_hex_center(neighbor), 7.0, 0.0, TAU, 20, Color(0.65, 0.88, 1.0, 0.75), 2.0, true)


func _draw_army_marker(cell: Vector2i, marker_color: Color, letter: String) -> void:
	var center := _hex_center(cell)
	draw_circle(center, 17.0, Color(0.025, 0.035, 0.045, 0.95))
	draw_circle(center, 13.5, marker_color)
	draw_string(ThemeDB.fallback_font, center + Vector2(-6.0, 6.0), letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color.WHITE)


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
	for building_id in ["farm", "market", "workshop", "barracks"]:
		var data := CampaignState.get_city_building_data(building_id)
		var button_text := "%s\n%d зол. · %d пр.\n%s" % [str(data.get("name", "Здание")), int(data.get("gold_cost", 0)), int(data.get("production_cost", 0)), str(data.get("description", ""))]
		var building_button := _add_button(building_grid, button_text, _queue_building.bind(building_id))
		building_button.custom_minimum_size = Vector2(0.0, 66.0)
		building_button.add_theme_font_size_override("font_size", 13)
		_city_building_buttons[building_id] = building_button

	var recruit_title := Label.new()
	recruit_title.text = "НАЙМ В КАЗАРМАХ"
	recruit_title.add_theme_font_size_override("font_size", 16)
	recruit_title.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
	details.add_child(recruit_title)

	var recruit_grid := GridContainer.new()
	recruit_grid.columns = 2
	recruit_grid.add_theme_constant_override("h_separation", 8)
	details.add_child(recruit_grid)
	var melee_button := _add_button(recruit_grid, "МЕЧНИК\n20 зол. · 3 пр.", _queue_recruit.bind(CampaignState.ROLE_MELEE))
	melee_button.custom_minimum_size = Vector2(0.0, 54.0)
	melee_button.add_theme_font_size_override("font_size", 13)
	_city_recruit_buttons[CampaignState.ROLE_MELEE] = melee_button
	var ranged_button := _add_button(recruit_grid, "ЛУЧНИК\n24 зол. · 4 пр.", _queue_recruit.bind(CampaignState.ROLE_RANGED))
	ranged_button.custom_minimum_size = Vector2(0.0, 54.0)
	ranged_button.add_theme_font_size_override("font_size", 13)
	_city_recruit_buttons[CampaignState.ROLE_RANGED] = ranged_button

	_settler_button = _add_button(details, "ПОСТРОИТЬ ПОСЕЛЕНЦА · 45 зол. · 10 пр.", _queue_settler)
	_settler_button.custom_minimum_size = Vector2(0.0, 52.0)
	_settler_button.add_theme_font_size_override("font_size", 13)

	var hint := Label.new()
	hint.text = "Заказы оплачиваются золотом сразу. Производство накапливается каждый ход. Казармы открывают найм войск. Поселенец может основать город не ближе 3 гексов от других городов."
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
		var building_data := CampaignState.get_city_building_data(building_id)
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


func _queue_settler() -> void:
	if CampaignState.queue_settler():
		_message_text = "Поселенец добавлен в очередь города."
	else:
		_message_text = "Нужны 45 золота, 3 жителя и отсутствие другого поселенца."
	_refresh_city_panel()
	_refresh_ui()

func _found_city() -> void:
	if CampaignState.found_city(CampaignState.settler_cell):
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
	var income := CampaignState.get_city_income()
	if is_instance_valid(_city_title_label):
		_city_title_label.text = "ГОРОД — " + CampaignState.city_name
	_city_overview_label.text = "%s · население: %d · армия: %d/16\nЗолото: %d · Еда: %d · Производство в запасе: %d" % [
		CampaignState.city_name,
		CampaignState.city_population,
		CampaignState.player_units.size(),
		CampaignState.city_gold,
		CampaignState.city_food,
		CampaignState.city_production_bank,
	]
	_city_income_label.text = "Доход за ход: +%d еды · +%d золота · +%d производства" % [
		int(income["food"]),
		int(income["gold"]),
		int(income["production"]),
	]
	_city_queue_label.text = CampaignState.get_city_queue_summary()

	if is_instance_valid(_settler_button):
		_settler_button.disabled = not CampaignState.can_queue_settler()
	for building_id in _city_building_buttons:
		var button: Button = _city_building_buttons[building_id]
		var data := CampaignState.get_city_building_data(str(building_id))
		if CampaignState.city_has_building(str(building_id)):
			button.text = "%s\nПОСТРОЕНО" % str(data.get("name", "Здание"))
			button.disabled = true
		elif CampaignState.city_is_building_queued(str(building_id)):
			button.text = "%s\nВ ОЧЕРЕДИ" % str(data.get("name", "Здание"))
			button.disabled = true
		else:
			button.text = "%s\n%d зол. · %d пр.\n%s" % [str(data.get("name", "Здание")), int(data.get("gold_cost", 0)), int(data.get("production_cost", 0)), str(data.get("description", ""))]
			button.disabled = not CampaignState.can_queue_building(str(building_id))

	var barracks_ready := CampaignState.city_has_building("barracks")
	var melee_button: Button = _city_recruit_buttons[CampaignState.ROLE_MELEE]
	var ranged_button: Button = _city_recruit_buttons[CampaignState.ROLE_RANGED]
	melee_button.disabled = not CampaignState.can_queue_recruit(CampaignState.ROLE_MELEE)
	ranged_button.disabled = not CampaignState.can_queue_recruit(CampaignState.ROLE_RANGED)
	if not barracks_ready:
		melee_button.text = "МЕЧНИК\nНУЖНЫ КАЗАРМЫ"
		ranged_button.text = "ЛУЧНИК\nНУЖНЫ КАЗАРМЫ"
	else:
		melee_button.text = "МЕЧНИК\n20 зол. · 3 пр."
		ranged_button.text = "ЛУЧНИК\n24 зол. · 4 пр."


func _panel_style(background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.36, 0.48, 0.58, 0.75)
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	return style


func _add_button(parent: Container, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0.0, 48.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.12, 0.20, 0.29)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.17, 0.29, 0.40)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.25, 0.35, 0.22)))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.16, 0.24, 0.32)))
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
	style.border_color = Color(0.48, 0.61, 0.72, 0.95)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
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
		if _hex_distance(CampaignState.settler_cell, cell) == 1 and _is_traversable(cell) and CampaignState.get_city_index_at(cell) < 0 and CampaignState.settler_moves_left > 0:
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

	var best_cell := CampaignState.enemy_cell
	var best_distance := current_distance
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
	if victory:
		_message_text = "Победа! Выживших: %d. Потери: %d. Вражеский лагерь захвачен." % [survivors, losses]
	else:
		_message_text = "Поражение. Твоя армия уничтожена. Можно начать новую кампанию."
	CampaignState.last_battle_report_pending = false
	CampaignState.save_campaign()


func _refresh_ui() -> void:
	if not is_instance_valid(_status_label):
		return
	var enemy_count := CampaignState.enemy_units.size() if CampaignState.enemy_present else 0
	_status_label.text = "ХОД %d   ·   АРМИЯ %d   ·   ВРАГ %d   ·   ЗОЛОТО %d" % [
		CampaignState.turn_number,
		CampaignState.player_units.size(),
		enemy_count,
		CampaignState.city_gold,
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
