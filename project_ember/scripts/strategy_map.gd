extends Node2D

const UiThemeScript = preload("res://scripts/ui_theme.gd")
const SettingsPanelScript = preload("res://scripts/settings_panel.gd")
const PerfOverlayScript = preload("res://scripts/perf_overlay.gd")
const Palette = preload("res://scripts/art_palette.gd")
const BattlefieldBiomesScript = preload("res://scripts/battlefield_biomes.gd")
const SafeAreaContainerScript = preload("res://scripts/safe_area_container.gd")
const TouchGestureRouterScript = preload("res://scripts/touch_gesture_router.gd")
const ToastManagerScript = preload("res://scripts/toast_manager.gd")
const ConfirmDialogScript = preload("res://scripts/confirm_dialog.gd")
const WorldGeneratorScript = preload("res://scripts/world_generator.gd")
const HexMapBatchRendererScript = preload("res://scripts/hex_map_batch_renderer.gd")

## Explored-world strategic map: fog of war, viewport streaming and AI kingdom markers.

const MAP_RADIUS := WorldGeneratorScript.WORLD_RADIUS
const HEX_SIZE := 30.0
const MAP_ZOOM_MIN := 0.075
const MAP_ZOOM_MAX := 1.25
const PLAYER_TEAM_COLOR := Palette.PLAYER_TEAM
const ENEMY_TEAM_COLOR := Palette.ENEMY_TEAM

const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]

var _cells: Array[Vector2i] = []
var _terrain_renderer: HexMapBatchRenderer
var _owner_lookup: Dictionary = {}
var _camera_center_world: Vector2 = Vector2.ZERO
var _map_zoom: float = 0.9
var _map_mouse_pan: bool = false
var _kingdoms_panel: PanelContainer
var _kingdoms_list: VBoxContainer
var _kingdoms_button: Button
var _selected_kingdom_id: int = -1
var _army_selected: bool = false
var _status_label: Label
var _message_label: Label
var _attack_button: Button
var _turn_button: Button
var _selection_button: Button
var _city_button: Button
var _city_panel: PanelContainer
var _settings_panel: SettingsPanel
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
var _message_text: String = "P — твоя армия. Неизведанные земли скрыты туманом войны."
var _safe_area: SafeAreaContainer
var _gesture_router: TouchGestureRouter
var _toast_manager: ToastManager
var _restart_confirm_dialog: ConfirmDialog
var _exit_confirm_dialog: ConfirmDialog
var _map_more_panel: PanelContainer
var _map_more_button: Button


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	if not CampaignState.campaign_started:
		CampaignState.new_campaign()
	_build_map()
	_camera_center_world = _hex_world_position(CampaignState.player_cell)
	_terrain_renderer = HexMapBatchRendererScript.new()
	_terrain_renderer.name = "BatchedWorldTerrain"
	add_child(_terrain_renderer)
	_create_ui()
	add_child(PerfOverlayScript.new())
	if CampaignState.last_battle_report_pending:
		_show_last_battle_report()
	elif CampaignState.campaign_lost:
		_message_text = "Армия уничтожена. Начни новую кампанию."
	_refresh_ui()
	queue_redraw()


func _draw() -> void:
	_cells = _get_visible_map_cells()
	_refresh_owner_lookup()
	var centers := PackedVector2Array()
	var colors := PackedColorArray()
	centers.resize(_cells.size())
	colors.resize(_cells.size())
	for index in range(_cells.size()):
		var cell: Vector2i = _cells[index]
		centers[index] = _hex_center(cell)
		var tint := _terrain_color(CampaignState.get_world_terrain(cell))
		var owner_id := int(_owner_lookup.get(cell, -1))
		if owner_id == -2:
			tint = tint.lerp(PLAYER_TEAM_COLOR, 0.22)
		elif owner_id >= 0:
			tint = tint.lerp(_kingdom_color(owner_id), 0.20)
		if not CampaignState.is_cell_visible(cell):
			tint = tint.darkened(0.58)
		colors[index] = tint
	if is_instance_valid(_terrain_renderer):
		_terrain_renderer.set_map_tiles(_cells, centers, colors, Vector2(56.0, 64.0), _map_zoom)

	# Explored cities remain on the map as remembered locations. Enemy armies,
	# unlike cities, are shown only while currently inside the player's sight.
	for city_data in CampaignState.cities:
		var cell := WorldGeneratorScript.array_to_cell(city_data.get("cell", []))
		var center := _hex_center(cell)
		if CampaignState.is_cell_explored(cell) and _point_is_visible(center, 36.0 * _map_zoom):
			_draw_city_marker(center, Palette.MAP_CITY_FLAG)

	for kingdom_index in range(CampaignState.kingdoms.size()):
		var kingdom: Dictionary = CampaignState.kingdoms[kingdom_index]
		var faction_color := _kingdom_color(kingdom_index)
		for city_data in kingdom.get("cities", []):
			var cell := WorldGeneratorScript.array_to_cell(city_data.get("cell", []))
			var center := _hex_center(cell)
			if CampaignState.is_cell_explored(cell) and _point_is_visible(center, 36.0 * _map_zoom):
				var remembered_color := faction_color if CampaignState.is_cell_visible(cell) else faction_color.darkened(0.58)
				_draw_city_marker(center, remembered_color)
		var army: Array = kingdom.get("army", [])
		if not army.is_empty():
			var army_cell := WorldGeneratorScript.array_to_cell(kingdom.get("army_cell", []))
			var army_center := _hex_center(army_cell)
			if CampaignState.is_cell_visible(army_cell) and _point_is_visible(army_center, 30.0 * _map_zoom):
				_draw_army_marker(army_cell, faction_color, str(kingdom_index + 1))

	if CampaignState.settler_active:
		var settler_center := _hex_center(CampaignState.settler_cell)
		if CampaignState.is_cell_visible(CampaignState.settler_cell) and _point_is_visible(settler_center, 24.0 * _map_zoom):
			_draw_settler_marker(settler_center)
	if not CampaignState.player_units.is_empty():
		var player_center := _hex_center(CampaignState.player_cell)
		if _point_is_visible(player_center, 30.0 * _map_zoom):
			_draw_army_marker(CampaignState.player_cell, PLAYER_TEAM_COLOR, "P")

	if _army_selected:
		for offset in NEIGHBOR_OFFSETS:
			var neighbor: Vector2i = CampaignState.player_cell + offset
			if _is_traversable(neighbor) and CampaignState.get_kingdom_index_at_army(neighbor) < 0:
				draw_colored_polygon(_hex_points(_hex_center(neighbor)), Palette.MAP_MOVE_FILL)
				draw_polyline(_closed_polygon(_hex_points(_hex_center(neighbor))), Palette.MAP_MOVE_BORDER, maxf(1.0, 2.3 * _map_zoom), true)


func _refresh_owner_lookup() -> void:
	_owner_lookup.clear()
	var claim_offsets: Array[Vector2i] = [Vector2i.ZERO]
	claim_offsets.append_array(NEIGHBOR_OFFSETS)
	for city_data in CampaignState.cities:
		var capital_cell := WorldGeneratorScript.array_to_cell(city_data.get("cell", []))
		for offset in claim_offsets:
			_owner_lookup[capital_cell + offset] = -2
	for kingdom_index in range(CampaignState.kingdoms.size()):
		var kingdom: Dictionary = CampaignState.kingdoms[kingdom_index]
		for city_data in kingdom.get("cities", []):
			var city_cell := WorldGeneratorScript.array_to_cell(city_data.get("cell", []))
			for offset in claim_offsets:
				var claimed_cell := city_cell + offset
				if not _owner_lookup.has(claimed_cell):
					_owner_lookup[claimed_cell] = kingdom_index


func _get_visible_map_cells() -> Array[Vector2i]:
	# Choose the cheaper source: scan the small viewport rectangle when zoomed
	# in, or scan the sparse explored-cell index when zoomed out over the world.
	var result: Array[Vector2i] = []
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return result
	var half_world := viewport_size * (0.5 / _map_zoom) + Vector2(HEX_SIZE * 2.5, HEX_SIZE * 2.5)
	var corners := [
		_camera_center_world + Vector2(-half_world.x, -half_world.y),
		_camera_center_world + Vector2(half_world.x, -half_world.y),
		_camera_center_world + Vector2(half_world.x, half_world.y),
		_camera_center_world + Vector2(-half_world.x, half_world.y),
	]
	var min_q := 9999.0
	var max_q := -9999.0
	var min_r := 9999.0
	var max_r := -9999.0
	for corner in corners:
		var axial := _world_to_axial(corner)
		min_q = minf(min_q, axial.x)
		max_q = maxf(max_q, axial.x)
		min_r = minf(min_r, axial.y)
		max_r = maxf(max_r, axial.y)
	var q_start := maxi(-MAP_RADIUS, floori(min_q) - 2)
	var q_end := mini(MAP_RADIUS, ceili(max_q) + 2)
	var r_start := maxi(-MAP_RADIUS, floori(min_r) - 2)
	var r_end := mini(MAP_RADIUS, ceili(max_r) + 2)
	var rectangle_candidates := maxi(0, q_end - q_start + 1) * maxi(0, r_end - r_start + 1)

	if rectangle_candidates <= CampaignState.explored_cells.size():
		for q in range(q_start, q_end + 1):
			for r in range(r_start, r_end + 1):
				var cell := Vector2i(q, r)
				if not WorldGeneratorScript.is_inside_world(cell) or not CampaignState.is_cell_explored(cell):
					continue
				var world_center := _hex_world_position(cell)
				if absf(world_center.x - _camera_center_world.x) <= half_world.x and absf(world_center.y - _camera_center_world.y) <= half_world.y:
					result.append(cell)
	else:
		for encoded_value in CampaignState.explored_cells.keys():
			var cell := WorldGeneratorScript.decode_cell(int(encoded_value))
			if cell == Vector2i(9999, 9999):
				continue
			var world_center := _hex_world_position(cell)
			if absf(world_center.x - _camera_center_world.x) > half_world.x:
				continue
			if absf(world_center.y - _camera_center_world.y) > half_world.y:
				continue
			result.append(cell)
	return result


func _world_to_axial(world_position: Vector2) -> Vector2:
	var r := (2.0 / 3.0) * world_position.y / HEX_SIZE
	var q := world_position.x / (sqrt(3.0) * HEX_SIZE) - r * 0.5
	return Vector2(q, r)


func _point_is_visible(point: Vector2, margin: float = 0.0) -> bool:
	var size := get_viewport_rect().size
	return point.x >= -margin and point.y >= -margin and point.x <= size.x + margin and point.y <= size.y + margin


func _kingdom_color(index: int) -> Color:
	return Color.from_hsv(float(posmod(index, WorldGeneratorScript.KINGDOM_COUNT)) / float(WorldGeneratorScript.KINGDOM_COUNT), 0.68, 0.92, 1.0)


func _draw_city_marker(center: Vector2, banner_color: Color = Palette.MAP_CITY_FLAG) -> void:
	if _map_zoom < 0.28:
		draw_circle(center, maxf(2.5, 9.0 * _map_zoom), banner_color)
		return
	draw_circle(center + Vector2(0.0, 3.0 * _map_zoom), 17.0 * _map_zoom, Palette.MAP_OBJECT_SHADOW)
	draw_rect(Rect2(center + Vector2(-11.0, -7.0) * _map_zoom, Vector2(22.0, 17.0) * _map_zoom), Palette.MAP_CITY_WALL)
	draw_rect(Rect2(center + Vector2(-15.0, -12.0) * _map_zoom, Vector2(8.0, 18.0) * _map_zoom), Palette.MAP_CITY_TOWER)
	draw_rect(Rect2(center + Vector2(7.0, -12.0) * _map_zoom, Vector2(8.0, 18.0) * _map_zoom), Palette.MAP_CITY_TOWER)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-17.0, -12.0) * _map_zoom, center + Vector2(-11.0, -20.0) * _map_zoom, center + Vector2(-5.0, -12.0) * _map_zoom]), banner_color.lightened(0.18))
	draw_colored_polygon(PackedVector2Array([center + Vector2(5.0, -12.0) * _map_zoom, center + Vector2(11.0, -20.0) * _map_zoom, center + Vector2(17.0, -12.0) * _map_zoom]), banner_color.lightened(0.18))
	draw_rect(Rect2(center + Vector2(-3.0, 1.0) * _map_zoom, Vector2(6.0, 9.0) * _map_zoom), Palette.MAP_CITY_DOOR)
	draw_line(center + Vector2(0.0, -19.0) * _map_zoom, center + Vector2(0.0, -29.0) * _map_zoom, Palette.MAP_CITY_FLAG_POLE, maxf(0.7, 2.0 * _map_zoom))
	draw_colored_polygon(PackedVector2Array([center + Vector2(1.0, -28.0) * _map_zoom, center + Vector2(12.0, -25.0) * _map_zoom, center + Vector2(1.0, -21.0) * _map_zoom]), banner_color)


func _draw_army_marker(cell: Vector2i, marker_color: Color, letter: String) -> void:
	var center := _hex_center(cell)
	if _map_zoom < 0.22:
		draw_circle(center, maxf(3.0, 10.0 * _map_zoom), marker_color)
		draw_string(ThemeDB.fallback_font, center + Vector2(-3.0, 3.0) * _map_zoom, letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Palette.MAP_ARMY_TEXT)
		return
	draw_circle(center + Vector2(0.0, 4.0 * _map_zoom), 18.0 * _map_zoom, Palette.MAP_ARMY_SHADOW)
	draw_circle(center, 16.0 * _map_zoom, Palette.MAP_ARMY_BASE)
	var shield := PackedVector2Array([
		center + Vector2(-10.0, -9.0) * _map_zoom,
		center + Vector2(10.0, -9.0) * _map_zoom,
		center + Vector2(9.0, 5.0) * _map_zoom,
		center + Vector2(0.0, 13.0) * _map_zoom,
		center + Vector2(-9.0, 5.0) * _map_zoom,
	])
	draw_colored_polygon(shield, marker_color)
	draw_polyline(_closed_polygon(shield), Palette.MAP_SHIELD_OUTLINE, maxf(0.7, 1.4 * _map_zoom), true)
	draw_line(center + Vector2(0.0, -12.0) * _map_zoom, center + Vector2(0.0, -24.0) * _map_zoom, Palette.MAP_ARMY_FLAG_POLE, maxf(0.7, 2.0 * _map_zoom))
	draw_colored_polygon(PackedVector2Array([center + Vector2(1.0, -23.0) * _map_zoom, center + Vector2(13.0, -20.0) * _map_zoom, center + Vector2(1.0, -16.0) * _map_zoom]), marker_color.lightened(0.22))
	draw_string(ThemeDB.fallback_font, center + Vector2(-5.0, 4.5) * _map_zoom, letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, maxi(8, roundi(12.0 * _map_zoom)), Palette.MAP_ARMY_TEXT)


func _draw_settler_marker(center: Vector2) -> void:
	draw_circle(center + Vector2(0.0, 3.0 * _map_zoom), 13.0 * _map_zoom, Palette.MAP_SETTLER_SHADOW)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-10.0, 5.0) * _map_zoom, center + Vector2(0.0, -9.0) * _map_zoom, center + Vector2(10.0, 5.0) * _map_zoom]), Palette.MAP_SETTLER_BODY)
	draw_line(center + Vector2(-10.0, 5.0) * _map_zoom, center + Vector2(10.0, 5.0) * _map_zoom, Palette.MAP_SETTLER_BASE, maxf(0.7, 2.0 * _map_zoom))
	draw_circle(center, 3.5 * _map_zoom, Palette.MAP_SETTLER_ACCENT)


func _build_map() -> void:
	_cells.clear()
	_camera_center_world = _hex_world_position(CampaignState.player_cell)
	_map_zoom = 0.9




func _terrain_color(kind: String) -> Color:
	match kind:
		"forest":
			return Palette.FOREST
		"hills":
			return Palette.HILLS
		"water":
			return Palette.WATER
		_:
			return Palette.GRASS


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
	var viewport_center := get_viewport_rect().size * 0.5
	return viewport_center + (_hex_world_position(cell) - _camera_center_world) * _map_zoom


func _hex_world_position(cell: Vector2i) -> Vector2:
	var x := sqrt(3.0) * HEX_SIZE * (float(cell.x) + float(cell.y) * 0.5)
	var y := 1.5 * HEX_SIZE * float(cell.y)
	return Vector2(x, y)


func _screen_to_world(screen_position: Vector2) -> Vector2:
	return _camera_center_world + (screen_position - get_viewport_rect().size * 0.5) / _map_zoom


func _center_map_on_cell(cell: Vector2i) -> void:
	_camera_center_world = _hex_world_position(cell)
	queue_redraw()


func _pan_map(delta_screen: Vector2) -> void:
	_camera_center_world -= delta_screen / _map_zoom
	queue_redraw()


func _zoom_map(factor: float, screen_anchor: Vector2) -> void:
	var before := _screen_to_world(screen_anchor)
	_map_zoom = clampf(_map_zoom * factor, MAP_ZOOM_MIN, MAP_ZOOM_MAX)
	var after := _screen_to_world(screen_anchor)
	_camera_center_world += before - after
	queue_redraw()


func _on_mobile_map_drag(_position: Vector2, delta: Vector2) -> void:
	_pan_map(delta)


func _on_mobile_map_pinch(factor: float, center: Vector2) -> void:
	_zoom_map(factor, center)


func _on_mobile_map_two_finger_pan(delta: Vector2) -> void:
	_pan_map(delta)


func _on_mobile_map_double_tap(position: Vector2) -> void:
	_zoom_map(1.2, position)




func _hex_points(center: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		var angle := deg_to_rad(-30.0 + 60.0 * float(index))
		points.append(center + Vector2(cos(angle), sin(angle)) * HEX_SIZE * 0.94 * _map_zoom)
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

	_safe_area = SafeAreaContainerScript.new()
	layer.add_child(_safe_area)
	var root := _safe_area.get_content_root()
	root.theme = UiThemeScript.create_theme(GameSettings.ui_scale)
	_gesture_router = TouchGestureRouterScript.new()
	_gesture_router.name = "TouchGestureRouter"
	_gesture_router.set_ui_root(root)
	if OS.has_feature("mobile"):
		_gesture_router.consume_mouse_events = true
		_gesture_router.tap.connect(_handle_map_tap)
		_gesture_router.double_tap.connect(_on_mobile_map_double_tap)
		_gesture_router.drag.connect(_on_mobile_map_drag)
		_gesture_router.pinch.connect(_on_mobile_map_pinch)
		_gesture_router.two_finger_pan.connect(_on_mobile_map_two_finger_pan)
	root.add_child(_gesture_router)
	_toast_manager = ToastManagerScript.new()
	_toast_manager.name = "ToastManager"
	root.add_child(_toast_manager)

	var top_panel := PanelContainer.new()
	top_panel.name = "MobileHudTop"
	top_panel.anchor_left = 0.0
	top_panel.anchor_top = 0.0
	top_panel.anchor_right = 1.0
	top_panel.anchor_bottom = 0.0
	top_panel.offset_left = UiMetrics.dp(10.0)
	top_panel.offset_top = UiMetrics.dp(8.0)
	top_panel.offset_right = -UiMetrics.dp(10.0)
	top_panel.offset_bottom = UiMetrics.dp(62.0)
	root.add_child(top_panel)

	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", int(UiMetrics.dp(1.0)))
	top_panel.add_child(top_box)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(15))
	_status_label.add_theme_color_override("font_color", Palette.UI_TEXT_PURE)
	_status_label.clip_text = true
	_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	top_box.add_child(_status_label)

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_message_label.clip_text = true
	_message_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(11))
	_message_label.add_theme_color_override("font_color", Palette.UI_TEXT_HELP)
	top_box.add_child(_message_label)

	_map_more_panel = PanelContainer.new()
	_map_more_panel.name = "MobileHudMoreCommands"
	_map_more_panel.anchor_left = 0.0
	_map_more_panel.anchor_top = 1.0
	_map_more_panel.anchor_right = 1.0
	_map_more_panel.anchor_bottom = 1.0
	_map_more_panel.offset_left = UiMetrics.dp(10.0)
	_map_more_panel.offset_top = -UiMetrics.dp(276.0)
	_map_more_panel.offset_right = -UiMetrics.dp(10.0)
	_map_more_panel.offset_bottom = -UiMetrics.dp(88.0)
	_map_more_panel.visible = false
	root.add_child(_map_more_panel)

	var more_margin := MarginContainer.new()
	more_margin.add_theme_constant_override("margin_left", int(UiMetrics.dp(5.0)))
	more_margin.add_theme_constant_override("margin_top", int(UiMetrics.dp(4.0)))
	more_margin.add_theme_constant_override("margin_right", int(UiMetrics.dp(5.0)))
	more_margin.add_theme_constant_override("margin_bottom", int(UiMetrics.dp(4.0)))
	_map_more_panel.add_child(more_margin)

	var more_grid := GridContainer.new()
	more_grid.columns = 2
	more_grid.add_theme_constant_override("h_separation", int(UiMetrics.dp(6.0)))
	more_grid.add_theme_constant_override("v_separation", int(UiMetrics.dp(4.0)))
	more_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	more_margin.add_child(more_grid)

	_attack_button = _add_button(more_grid, "АТАКОВАТЬ", _attack_enemy)
	_add_button(more_grid, "НОВАЯ КАМПАНИЯ", _restart_campaign)
	_found_city_button = _add_button(more_grid, "ОСНОВАТЬ ГОРОД", _found_city)
	_add_button(more_grid, "НАСТРОЙКИ", _open_settings)
	_kingdoms_button = _add_button(more_grid, "КОРОЛЕВСТВА", _open_kingdoms_panel)

	var bottom_panel := PanelContainer.new()
	bottom_panel.name = "MobileHudQuickDock"
	bottom_panel.anchor_left = 0.0
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_left = UiMetrics.dp(10.0)
	bottom_panel.offset_top = -UiMetrics.dp(80.0)
	bottom_panel.offset_right = -UiMetrics.dp(10.0)
	bottom_panel.offset_bottom = -UiMetrics.dp(8.0)
	root.add_child(bottom_panel)

	var quick_row := HBoxContainer.new()
	quick_row.add_theme_constant_override("separation", int(UiMetrics.dp(5.0)))
	bottom_panel.add_child(quick_row)
	_selection_button = _add_button(quick_row, "АРМИЯ", _select_player_army)
	_city_button = _add_button(quick_row, "ГОРОД", _open_city)
	_turn_button = _add_button(quick_row, "ХОД", _advance_turn)
	_map_more_button = _add_button(quick_row, "ЕЩЁ", _toggle_map_commands)
	_create_city_panel(root)
	_create_kingdoms_panel(root)
	_settings_panel = SettingsPanelScript.new()
	_settings_panel.pause_game_on_open = false
	root.add_child(_settings_panel)
	_restart_confirm_dialog = ConfirmDialogScript.new()
	_restart_confirm_dialog.configure("Новая кампания", "Текущий прогресс будет стёрт. Удерживай красную кнопку одну секунду, чтобы начать заново.", "СТЕРЕТЬ ПРОГРЕСС", "ОТМЕНА", true)
	_restart_confirm_dialog.confirmed.connect(_perform_restart_campaign)
	root.add_child(_restart_confirm_dialog)
	_exit_confirm_dialog = ConfirmDialogScript.new()
	_exit_confirm_dialog.configure("Закрыть игру?", "Кампания сохранена. Закрыть Project Ember?", "ВЫЙТИ", "ОСТАТЬСЯ", false)
	_exit_confirm_dialog.confirmed.connect(func() -> void: get_tree().quit())
	root.add_child(_exit_confirm_dialog)
	_refresh_ui()


func _create_kingdoms_panel(root: Control) -> void:
	_kingdoms_panel = PanelContainer.new()
	_kingdoms_panel.name = "KingdomsOverviewPanel"
	_kingdoms_panel.anchor_left = 0.06
	_kingdoms_panel.anchor_top = 0.10
	_kingdoms_panel.anchor_right = 0.94
	_kingdoms_panel.anchor_bottom = 0.90
	_kingdoms_panel.visible = false
	root.add_child(_kingdoms_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(UiMetrics.dp(10.0)))
	margin.add_theme_constant_override("margin_top", int(UiMetrics.dp(8.0)))
	margin.add_theme_constant_override("margin_right", int(UiMetrics.dp(10.0)))
	margin.add_theme_constant_override("margin_bottom", int(UiMetrics.dp(8.0)))
	_kingdoms_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(UiMetrics.dp(6.0)))
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = "ДЕРЖАВЫ МИРА"
	title.add_theme_font_size_override("font_size", UiThemeScript.font_size(19))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := _add_button(header, "ЗАКРЫТЬ", _close_kingdoms_panel)
	close_button.custom_minimum_size = Vector2(UiMetrics.dp(108.0), UiThemeScript.touch_target(48.0))

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_kingdoms_list = VBoxContainer.new()
	_kingdoms_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kingdoms_list.add_theme_constant_override("separation", int(UiMetrics.dp(5.0)))
	scroll.add_child(_kingdoms_list)


func _refresh_kingdoms_panel() -> void:
	if not is_instance_valid(_kingdoms_list):
		return
	for child in _kingdoms_list.get_children():
		child.queue_free()
	for index in range(CampaignState.kingdoms.size()):
		var kingdom: Dictionary = CampaignState.kingdoms[index]
		var cities: Array = kingdom.get("cities", [])
		var army: Array = kingdom.get("army", [])
		var known_city_count := 0
		for city_data in cities:
			var city_cell := WorldGeneratorScript.array_to_cell(city_data.get("cell", []))
			if CampaignState.is_cell_explored(city_cell):
				known_city_count += 1
		var capital_cell := WorldGeneratorScript.array_to_cell(kingdom.get("capital_cell", []))
		var capital_known := CampaignState.is_cell_explored(capital_cell)
		var army_cell := WorldGeneratorScript.array_to_cell(kingdom.get("army_cell", []))
		var army_visible := not army.is_empty() and CampaignState.is_cell_visible(army_cell)
		var has_intel := capital_known or known_city_count > 0 or army_visible
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", UiThemeScript.font_size(13))
		label.add_theme_color_override("font_color", _kingdom_color(index))
		if not has_intel:
			label.text = "%d. %s\nТерритория не разведана · Нет данных" % [
				index + 1,
				str(kingdom.get("name", "Неизвестная держава")),
			]
		else:
			var army_status := str(army.size()) if army_visible else "Не наблюдается"
			var latest_intel := str(kingdom.get("last_action", "Развивается")) if capital_known and CampaignState.is_cell_visible(capital_cell) else "Последние сведения устарели"
			label.text = "%d. %s — %s\nИзвестных городов: %d · Войск видно: %s\n%s" % [
				index + 1,
				str(kingdom.get("name", "Королевство")),
				str(kingdom.get("ruler", "Правитель")) if capital_known else "Правитель неизвестен",
				known_city_count,
				army_status,
				latest_intel,
			]
		_kingdoms_list.add_child(label)
		_kingdoms_list.add_child(HSeparator.new())


func _open_kingdoms_panel() -> void:
	if is_instance_valid(_map_more_panel):
		_map_more_panel.visible = false
	if is_instance_valid(_map_more_button):
		_map_more_button.text = "ЕЩЁ"
	if is_instance_valid(_city_panel):
		_city_panel.visible = false
	_refresh_kingdoms_panel()
	_kingdoms_panel.visible = true


func _close_kingdoms_panel() -> void:
	if is_instance_valid(_kingdoms_panel):
		_kingdoms_panel.visible = false


func _create_city_panel(root: Control) -> void:
	_city_panel = PanelContainer.new()
	_city_panel.anchor_left = 0.07
	_city_panel.anchor_top = 0.11
	_city_panel.anchor_right = 0.93
	_city_panel.anchor_bottom = 0.88
	_city_panel.visible = false
	root.add_child(_city_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_city_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(UiMetrics.dp(8)))
	margin.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	_city_title_label = Label.new()
	_city_title_label.text = "ГОРОД — " + CampaignState.city_name
	_city_title_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(23))
	_city_title_label.add_theme_color_override("font_color", Palette.UI_TEXT_CITY_TITLE)
	_city_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_city_title_label)
	var close_button := _add_button(header, "ЗАКРЫТЬ", _close_city)
	close_button.custom_minimum_size = Vector2(120.0, UiThemeScript.touch_target(48.0))

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", int(UiMetrics.dp(8)))
	scroll.add_child(details)

	_city_overview_label = Label.new()
	_city_overview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_city_overview_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(16))
	_city_overview_label.add_theme_color_override("font_color", Palette.UI_TEXT_BODY)
	details.add_child(_city_overview_label)

	_city_income_label = Label.new()
	_city_income_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_city_income_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(14))
	_city_income_label.add_theme_color_override("font_color", Palette.UI_TEXT_INCOME)
	details.add_child(_city_income_label)

	_city_queue_label = Label.new()
	_city_queue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_city_queue_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(14))
	_city_queue_label.add_theme_color_override("font_color", Palette.UI_TEXT_QUEUE)
	details.add_child(_city_queue_label)

	var hero_title := Label.new()
	hero_title.text = "ПРАВИТЕЛЬ И КОМАНДИР"
	hero_title.add_theme_font_size_override("font_size", UiThemeScript.font_size(17))
	hero_title.add_theme_color_override("font_color", Palette.UI_TEXT_HERO)
	details.add_child(hero_title)

	_hero_overview_label = Label.new()
	_hero_overview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hero_overview_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(14))
	_hero_overview_label.add_theme_color_override("font_color", Palette.UI_TEXT_BODY)
	details.add_child(_hero_overview_label)

	var hero_skill_grid := GridContainer.new()
	hero_skill_grid.columns = 3
	hero_skill_grid.add_theme_constant_override("h_separation", 7)
	hero_skill_grid.add_theme_constant_override("v_separation", 5)
	details.add_child(hero_skill_grid)
	for skill_id in ["leadership", "tactics", "might"]:
		var skill_button := _add_button(hero_skill_grid, "НАВЫК", _upgrade_hero_skill.bind(skill_id))
		skill_button.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(64.0))
		skill_button.add_theme_font_size_override("font_size", UiThemeScript.font_size(12))
		_hero_skill_buttons[skill_id] = skill_button

	var building_title := Label.new()
	building_title.text = "СТРОИТЕЛЬСТВО"
	building_title.add_theme_font_size_override("font_size", UiThemeScript.font_size(16))
	building_title.add_theme_color_override("font_color", Palette.UI_TEXT_BUILDING)
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
		building_button.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(76.0))
		building_button.add_theme_font_size_override("font_size", UiThemeScript.font_size(13))
		_city_building_buttons[building_id] = building_button

	var recruit_title := Label.new()
	recruit_title.text = "НАЙМ ВОЙСК"
	recruit_title.add_theme_font_size_override("font_size", UiThemeScript.font_size(16))
	recruit_title.add_theme_color_override("font_color", Palette.UI_TEXT_BUILDING)
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
		recruit_button.custom_minimum_size = Vector2(UiMetrics.dp(0.0), UiMetrics.dp(58.0))
		recruit_button.add_theme_font_size_override("font_size", UiThemeScript.font_size(13))
		_city_recruit_buttons[role_id] = recruit_button

	_settler_button = _add_button(details, "ПОСТРОИТЬ ПОСЕЛЕНЦА · 45 зол. · 10 пр.", _queue_settler)
	_settler_button.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(56.0))
	_settler_button.add_theme_font_size_override("font_size", UiThemeScript.font_size(13))

	var hint := Label.new()
	hint.text = "Заказы оплачиваются золотом сразу, производство накапливается каждый ход. Казармы открывают мечников и копейщиков; стрельбище — лучников; конюшня — кавалерию. Стрельбище и конюшня требуют казарм. Поселенец основывает город не ближе 3 гексов."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", UiThemeScript.font_size(12))
	hint.add_theme_color_override("font_color", Palette.UI_TEXT_HINT)
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
		_settler_selected = false
		_message_text = "Основан новый город: " + CampaignState.city_name
		Haptics.confirm(30)
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



func _add_button(parent: Container, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(48.0))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", UiThemeScript.font_size(16))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _toggle_map_commands() -> void:
	if not is_instance_valid(_map_more_panel) or not is_instance_valid(_map_more_button):
		return
	_map_more_panel.visible = not _map_more_panel.visible
	_map_more_button.text = "ЗАКРЫТЬ" if _map_more_panel.visible else "ЕЩЁ"


func _open_settings() -> void:
	if is_instance_valid(_map_more_panel) and _map_more_panel.visible:
		_toggle_map_commands()
	if is_instance_valid(_settings_panel):
		_settings_panel.open_panel()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_system_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not CampaignState.battle_in_progress:
			CampaignState.save_campaign()


func _handle_system_back() -> void:
	if is_instance_valid(_restart_confirm_dialog) and _restart_confirm_dialog.visible:
		_restart_confirm_dialog.cancel()
		return
	if is_instance_valid(_exit_confirm_dialog) and _exit_confirm_dialog.visible:
		_exit_confirm_dialog.cancel()
		return
	if is_instance_valid(_settings_panel) and _settings_panel.visible:
		_settings_panel.close_panel()
		return
	if is_instance_valid(_city_panel) and _city_panel.visible:
		_close_city()
		return
	if is_instance_valid(_kingdoms_panel) and _kingdoms_panel.visible:
		_close_kingdoms_panel()
		return
	if is_instance_valid(_map_more_panel) and _map_more_panel.visible:
		_toggle_map_commands()
		return
	# Until the dedicated map menu arrives in UI-3, Back opens the existing
	# settings sheet rather than exiting the game or discarding campaign state.
	_open_settings()

func _unhandled_input(event: InputEvent) -> void:
	if CampaignState.campaign_lost or CampaignState.battle_in_progress or OS.has_feature("mobile"):
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_map_tap(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_map(1.12, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_map(0.89, event.position)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_map_mouse_pan = event.pressed
	elif event is InputEventMouseMotion and _map_mouse_pan:
		_pan_map(event.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT:
				_pan_map(Vector2(48.0, 0.0))
			KEY_RIGHT:
				_pan_map(Vector2(-48.0, 0.0))
			KEY_UP:
				_pan_map(Vector2(0.0, 48.0))
			KEY_DOWN:
				_pan_map(Vector2(0.0, -48.0))
			KEY_PLUS, KEY_KP_ADD:
				_zoom_map(1.12, get_viewport_rect().size * 0.5)
			KEY_MINUS, KEY_KP_SUBTRACT:
				_zoom_map(0.89, get_viewport_rect().size * 0.5)


func _handle_map_tap(screen_position: Vector2) -> void:
	var cell := _screen_to_cell(screen_position)
	if cell == Vector2i(9999, 9999):
		return
	if not CampaignState.is_cell_explored(cell):
		_message_text = "Эта область скрыта туманом войны. Сначала подведи туда армию или поселенца."
		_refresh_ui()
		return

	if CampaignState.settler_active and cell == CampaignState.settler_cell:
		_settler_selected = true
		_army_selected = false
		Haptics.tap(10)
		_message_text = "Поселенец выбран. Перемести его на свободный гекс и нажми ОСНОВАТЬ ГОРОД."
		_refresh_ui()
		queue_redraw()
		return

	if _settler_selected and CampaignState.settler_active:
		if _hex_distance(CampaignState.settler_cell, cell) == 1 and _is_traversable(cell) and CampaignState.get_city_index_at(cell) < 0 and cell != CampaignState.player_cell and (not CampaignState.enemy_present or cell != CampaignState.enemy_cell) and CampaignState.settler_moves_left > 0:
			CampaignState.settler_cell = cell
			CampaignState.settler_moves_left -= 1
			CampaignState.save_campaign()
			Haptics.confirm(15)
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
		_selected_kingdom_id = -1
		_army_selected = true
		Haptics.tap(10)
		_message_text = "Армия выбрана. Коснись соседнего гекса для перемещения."
		_refresh_ui()
		queue_redraw()
		return

	var target_kingdom_id := CampaignState.get_kingdom_index_at_army(cell) if CampaignState.is_cell_visible(cell) else -1
	if target_kingdom_id >= 0:
		_selected_kingdom_id = target_kingdom_id
		var target_kingdom: Dictionary = CampaignState.kingdoms[target_kingdom_id]
		if _hex_distance(CampaignState.player_cell, cell) <= 1:
			_attack_kingdom(target_kingdom_id)
		else:
			_message_text = "%s: армия в %d гексах. Подойди ближе, чтобы атаковать." % [
				str(target_kingdom.get("name", "Враг")),
				_hex_distance(CampaignState.player_cell, cell),
			]
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
	var axial := _world_to_axial(_screen_to_world(screen_position))
	var cube_x := axial.x
	var cube_z := axial.y
	var cube_y := -cube_x - cube_z
	var rounded_x := roundf(cube_x)
	var rounded_y := roundf(cube_y)
	var rounded_z := roundf(cube_z)
	var x_diff := absf(rounded_x - cube_x)
	var y_diff := absf(rounded_y - cube_y)
	var z_diff := absf(rounded_z - cube_z)
	if x_diff > y_diff and x_diff > z_diff:
		rounded_x = -rounded_y - rounded_z
	elif y_diff > z_diff:
		rounded_y = -rounded_x - rounded_z
	else:
		rounded_z = -rounded_x - rounded_y
	var cell := Vector2i(roundi(rounded_x), roundi(rounded_z))
	if not WorldGeneratorScript.is_inside_world(cell):
		return Vector2i(9999, 9999)
	if screen_position.distance_to(_hex_center(cell)) > HEX_SIZE * _map_zoom:
		return Vector2i(9999, 9999)
	return cell




func _select_player_army() -> void:
	_settler_selected = false
	_selected_kingdom_id = -1
	_army_selected = true
	_message_text = "Армия выбрана. Коснись соседнего гекса для перемещения."
	_center_map_on_cell(CampaignState.player_cell)
	_refresh_ui()
	queue_redraw()


func _attack_enemy() -> void:
	var target_id := _selected_kingdom_id
	if target_id < 0:
		target_id = CampaignState.get_kingdom_index_at_army(CampaignState.enemy_cell)
	if target_id < 0:
		_message_text = "Выбери вражескую армию на карте."
		_refresh_ui()
		return
	_attack_kingdom(target_id)


func _attack_kingdom(kingdom_id: int) -> void:
	if kingdom_id < 0 or kingdom_id >= CampaignState.kingdoms.size():
		return
	var kingdom: Dictionary = CampaignState.kingdoms[kingdom_id]
	var target_cell := WorldGeneratorScript.array_to_cell(kingdom.get("army_cell", []))
	if _hex_distance(CampaignState.player_cell, target_cell) > 1:
		_message_text = "Чтобы начать бой с %s, подойди к армии вплотную." % str(kingdom.get("name", "королевства"))
		_refresh_ui()
		return
	var local_terrain: Dictionary = {}
	local_terrain[CampaignState.player_cell] = CampaignState.get_world_terrain(CampaignState.player_cell)
	for offset in NEIGHBOR_OFFSETS:
		var nearby := CampaignState.player_cell + offset
		local_terrain[nearby] = CampaignState.get_world_terrain(nearby)
	var biome_id := BattlefieldBiomesScript.resolve_from_terrain_map(local_terrain, CampaignState.player_cell)
	if CampaignState.begin_battle(biome_id, kingdom_id):
		get_tree().change_scene_to_file("res://scenes/combat_test.tscn")


func _advance_turn() -> void:
	if CampaignState.campaign_lost or CampaignState.battle_in_progress:
		return
	# A turn can be ended early; any unused movement point is simply forfeited.
	CampaignState.advance_campaign_turn()
	CampaignState.save_campaign()
	Haptics.confirm(15)
	var nearest_kingdom := -1
	var nearest_distance := 9999
	for index in range(CampaignState.kingdoms.size()):
		var kingdom: Dictionary = CampaignState.kingdoms[index]
		if kingdom.get("army", []).is_empty():
			continue
		var distance := _hex_distance(CampaignState.player_cell, WorldGeneratorScript.array_to_cell(kingdom.get("army_cell", [])))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_kingdom = index
	if nearest_kingdom >= 0 and nearest_distance <= 2:
		var nearest: Dictionary = CampaignState.kingdoms[nearest_kingdom]
		_message_text = "%s приблизило армию. Она в %d гексах от тебя." % [str(nearest.get("name", "Вражеское королевство")), nearest_distance]
	else:
		_message_text = "Ход %d. Девять держав продолжают развиваться." % CampaignState.turn_number
	if not CampaignState.last_kingdom_events.is_empty():
		_message_text += " " + CampaignState.last_kingdom_events[0]
	if not CampaignState.city_last_event.is_empty():
		_message_text += " Город: " + CampaignState.city_last_event
	_refresh_city_panel()
	if is_instance_valid(_kingdoms_panel) and _kingdoms_panel.visible:
		_refresh_kingdoms_panel()
	_refresh_ui()
	queue_redraw()


func _restart_campaign() -> void:
	if is_instance_valid(_restart_confirm_dialog):
		_restart_confirm_dialog.open()
		Haptics.warn()


func _perform_restart_campaign() -> void:
	_close_city()
	CampaignState.new_campaign()
	_army_selected = false
	_settler_selected = false
	_message_text = "Новая кампания началась. Выбери синюю армию."
	_build_map()
	_refresh_ui()
	queue_redraw()
	if is_instance_valid(_toast_manager):
		_toast_manager.show_toast("Начата новая кампания", 2.5, "✓")
	Haptics.confirm()


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
	_status_label.text = "ХОД %d · ДЕРЖАВ: %d · ВОЙСК ВИДНО: %d · ЗОЛОТО: %d" % [
		CampaignState.turn_number,
		CampaignState.kingdoms.size(),
		_get_visible_enemy_unit_count(),
		CampaignState.city_gold,
	]
	_message_label.text = _message_text
	if is_instance_valid(_attack_button):
		var selected_kingdom_valid := _selected_kingdom_id >= 0 and _selected_kingdom_id < CampaignState.kingdoms.size()
		var selected_army_cell := WorldGeneratorScript.array_to_cell(CampaignState.kingdoms[_selected_kingdom_id].get("army_cell", [])) if selected_kingdom_valid else CampaignState.enemy_cell
		_attack_button.disabled = not selected_kingdom_valid or _hex_distance(CampaignState.player_cell, selected_army_cell) > 1 or CampaignState.player_units.is_empty()
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
	if is_instance_valid(_kingdoms_panel) and _kingdoms_panel.visible:
		_refresh_kingdoms_panel()


func _get_visible_enemy_unit_count() -> int:
	var total := 0
	for kingdom in CampaignState.kingdoms:
		var army: Array = kingdom.get("army", [])
		var army_cell := WorldGeneratorScript.array_to_cell(kingdom.get("army_cell", []))
		if not army.is_empty() and CampaignState.is_cell_visible(army_cell):
			total += army.size()
	return total


func _is_traversable(cell: Vector2i) -> bool:
	return WorldGeneratorScript.is_inside_world(cell) and CampaignState.get_world_terrain(cell) != "water"


func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	return int((absi(a.x - b.x) + absi(a.y - b.y) + absi((a.x + a.y) - (b.x + b.y))) / 2)