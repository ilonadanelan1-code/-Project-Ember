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
const CityDevelopmentCatalogScript = preload("res://scripts/city_development_catalog.gd")
const WorldLocationCatalogScript = preload("res://scripts/world_location_catalog.gd")
const FactionCatalogScript = preload("res://scripts/faction_catalog.gd")
const DiplomacyCatalogScript = preload("res://scripts/diplomacy_catalog.gd")
const CampaignVictoryCatalogScript = preload("res://scripts/campaign_victory_catalog.gd")
const HexTerrainTileMapRendererScript = preload("res://scripts/hex_terrain_tilemap_renderer.gd")
const StrategicMapDetailsScript = preload("res://scripts/strategic_map_details.gd")
const GameIconCatalogScript = preload("res://scripts/game_icon_catalog.gd")
const CITY_MARKER_ATLAS: Texture2D = preload("res://assets/map/city_marker_atlas.png")

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
var _hex_tileset_renderer: HexTerrainTileMapRenderer
var _owner_lookup: Dictionary = {}
var _camera_center_world: Vector2 = Vector2.ZERO
var _map_zoom: float = 1.08
var _map_mouse_pan: bool = false
var _kingdoms_panel: PanelContainer
var _kingdoms_list: VBoxContainer
var _kingdoms_button: Button
var _diplomacy_panel: PanelContainer
var _diplomacy_summary_label: Label
var _diplomacy_actions_list: VBoxContainer
var _diplomacy_selected_kingdom_id: int = -1
var _selected_kingdom_id: int = -1
var _army_selected: bool = false
var _status_label: Label
var _message_label: Label
var _hud_resource_labels: Dictionary = {}
var _city_resource_labels: Dictionary = {}
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
var _city_upgrade_buttons: Dictionary = {}
var _city_specialization_buttons: Dictionary = {}
var _city_province_buttons: Dictionary = {}
var _city_building_upgrade_buttons: Dictionary = {}
var _city_development_label: Label
var _city_upkeep_label: Label
var _message_text: String = "P — твоя армия. Неизведанные земли скрыты туманом войны."
var _safe_area: SafeAreaContainer
var _gesture_router: TouchGestureRouter
var _toast_manager: ToastManager
var _restart_confirm_dialog: ConfirmDialog
var _exit_confirm_dialog: ConfirmDialog
var _map_more_panel: PanelContainer
var _map_more_button: Button
var _world_event_panel: PanelContainer
var _world_event_title_label: Label
var _world_event_body_label: Label
var _world_event_choice_buttons: Array[Button] = []
var _victory_panel: PanelContainer
var _victory_summary_label: Label
var _victory_detail_labels: Dictionary = {}
var _victory_select_buttons: Dictionary = {}
var _victory_finish_button: Button
var _victory_continue_button: Button
var _selected_victory_type: String = ""
var _victory_prompt_shown: bool = false
var _faction_setup_panel: PanelContainer
var _faction_people_option: OptionButton
var _faction_culture_option: OptionButton
var _faction_trait_a_option: OptionButton
var _faction_trait_b_option: OptionButton
var _faction_people_description: Label
var _faction_culture_description: Label
var _faction_traits_description: Label
var _faction_summary_label: Label
var _faction_name_edit: LineEdit
var _faction_auto_name: String = ""
var _faction_confirm_button: Button
var _bottom_panel: PanelContainer


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_tree().set_auto_accept_quit(false)
	if not CampaignState.campaign_started:
		CampaignState.new_campaign()
	_build_map()
	_camera_center_world = _hex_world_position(CampaignState.player_cell)
	_hex_tileset_renderer = HexTerrainTileMapRendererScript.new()
	_hex_tileset_renderer.name = "HexTerrainTileMapRenderer"
	add_child(_hex_tileset_renderer)
	_create_ui()
	add_child(PerfOverlayScript.new())
	if CampaignState.last_battle_report_pending:
		_show_last_battle_report()
	elif CampaignState.campaign_lost:
		_message_text = "Армия уничтожена. Начни новую кампанию."
	_refresh_ui()
	_refresh_world_event_panel()
	queue_redraw()


func _draw() -> void:
	_cells = _get_visible_map_cells()
	_refresh_owner_lookup()
	for index in range(_cells.size()):
		var cell: Vector2i = _cells[index]
		var center := _hex_center(cell)
		var overlay := Color(0.0, 0.0, 0.0, 0.0)
		var owner_id := int(_owner_lookup.get(cell, -1))
		if owner_id == -2:
			overlay = Color(PLAYER_TEAM_COLOR.r, PLAYER_TEAM_COLOR.g, PLAYER_TEAM_COLOR.b, 0.075)
		elif owner_id >= 0:
			var faction_color := _kingdom_color(owner_id)
			overlay = Color(faction_color.r, faction_color.g, faction_color.b, 0.065)
		if not CampaignState.is_cell_visible(cell):
			overlay = Color(0.012, 0.020, 0.025, 0.28)
		if overlay.a > 0.0:
			draw_colored_polygon(_hex_points(center), overlay)

	if is_instance_valid(_hex_tileset_renderer):
		_hex_tileset_renderer.set_map_tiles(
			_cells,
			_map_zoom,
			_camera_center_world,
			get_viewport_rect().size
		)

	_draw_hex_grid()
	_draw_coastlines()
	_draw_roads()
	_draw_province_improvements()
	_draw_neutral_locations()
	_draw_territory_borders()

	# Explored cities remain on the map as remembered locations. Enemy armies,
	# unlike cities, are shown only while currently inside the player's sight.
	for city_index in range(CampaignState.cities.size()):
		var city_data: Dictionary = CampaignState.cities[city_index]
		var cell := WorldGeneratorScript.array_to_cell(city_data.get("cell", []))
		var center := _hex_center(cell)
		if CampaignState.is_cell_explored(cell) and _point_is_visible(center, 36.0 * _map_zoom):
			_draw_city_marker(center, PLAYER_TEAM_COLOR, city_index == 0, true)
			if StrategicMapDetailsScript.should_show_city_labels(_map_zoom):
				_draw_city_label(center, str(city_data.get("name", "Поселение")), PLAYER_TEAM_COLOR)

	for kingdom_index in range(CampaignState.kingdoms.size()):
		var kingdom: Dictionary = CampaignState.kingdoms[kingdom_index]
		var faction_color := _kingdom_color(kingdom_index)
		var kingdom_cities: Array = kingdom.get("cities", [])
		for city_index in range(kingdom_cities.size()):
			var city_data: Dictionary = kingdom_cities[city_index]
			var cell := WorldGeneratorScript.array_to_cell(city_data.get("cell", []))
			var center := _hex_center(cell)
			if CampaignState.is_cell_explored(cell) and _point_is_visible(center, 36.0 * _map_zoom):
				var remembered_color := faction_color if CampaignState.is_cell_visible(cell) else faction_color.darkened(0.34)
				_draw_city_marker(center, remembered_color, city_index == 0, false)
				if StrategicMapDetailsScript.should_show_city_labels(_map_zoom):
					_draw_city_label(center, str(city_data.get("name", "Поселение")), remembered_color)
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


func _draw_city_marker(
		center: Vector2,
		banner_color: Color = Palette.MAP_CITY_FLAG,
		is_capital: bool = false,
		is_player_city: bool = false
) -> void:
	if _map_zoom < 0.28:
		var dot_radius := maxf(3.0, (9.0 if is_capital else 7.0) * _map_zoom)
		draw_circle(center, dot_radius + 1.0, Palette.MAP_OBJECT_SHADOW)
		draw_circle(center, dot_radius, banner_color)
		if is_capital:
			draw_circle(center, maxf(1.2, dot_radius * 0.34), Palette.GOLD_LIGHT)
		return

	var marker_scale := _map_zoom * (1.0 if is_capital else 0.84)
	# Pixel Fantasy settlement sprites replace the former generic city stamp.
	# Capitals get castle silhouettes; founded towns stay visually lighter.
	var sprite_id := "castle_blue" if is_capital else "town"
	if not is_player_city:
		sprite_id = "castle_red" if is_capital else "village"
	var settlement_texture := GameIconCatalogScript.settlement_icon(sprite_id, true)
	var sprite_base_size := 94.0 if is_capital else 78.0
	var sprite_size := Vector2.ONE * sprite_base_size * marker_scale
	var sprite_position := center - Vector2(sprite_size.x * 0.5, sprite_size.y * 0.70)
	draw_circle(center + Vector2(0.0, 8.0) * marker_scale, 19.0 * marker_scale, Palette.MAP_OBJECT_SHADOW)
	if settlement_texture != null:
		draw_texture_rect(settlement_texture, Rect2(sprite_position, sprite_size), false, Color.WHITE)
	else:
		var source_x := 0.0 if is_capital else 256.0
		var source_rect := Rect2(Vector2(source_x, 0.0), Vector2(256.0, 256.0))
		draw_texture_rect_region(CITY_MARKER_ATLAS, Rect2(sprite_position, sprite_size), source_rect, Color.WHITE)

	# The faction-coloured pennant distinguishes AI kingdoms that share a red castle sprite.
	if not is_player_city:
		var flag_pole := center + Vector2(22.0, -26.0) * marker_scale
		var flag_tip := flag_pole + Vector2(0.0, -19.0) * marker_scale
		draw_line(flag_pole, flag_tip, Palette.MAP_CITY_FLAG_POLE, maxf(1.0, 1.4 * marker_scale))
		draw_colored_polygon(PackedVector2Array([
			flag_tip,
			flag_tip + Vector2(12.0, 3.0) * marker_scale,
			flag_tip + Vector2(0.0, 7.0) * marker_scale,
		]), banner_color)
	if is_capital:
		draw_circle(center + Vector2(0.0, 17.0) * marker_scale, maxf(1.0, 2.0 * marker_scale), Palette.GOLD_LIGHT)
	if is_player_city:
		draw_line(
			center + Vector2(-13.0, 14.0) * marker_scale,
			center + Vector2(13.0, 14.0) * marker_scale,
			Palette.GOLD_LIGHT,
			maxf(0.8, 1.1 * marker_scale)
		)


func _draw_hex_grid() -> void:
	if _cells.is_empty() or _map_zoom < 1.15:
		return
	var grid_segments := PackedVector2Array()
	for cell in _cells:
		var corners := _hex_points(_hex_center(cell))
		# Draw three edges per cell; the opposite three belong to neighbors.
		for direction_index in range(3):
			var edge_index := posmod(-direction_index, 6)
			grid_segments.append(corners[edge_index])
			grid_segments.append(corners[(edge_index + 1) % 6])
	if not grid_segments.is_empty():
		draw_multiline(grid_segments, Palette.MAP_HEX_GRID, maxf(0.16, 0.16 * _map_zoom), true)


func _draw_coastlines() -> void:
	if _cells.is_empty() or _map_zoom < 0.28:
		return
	var shoreline := PackedVector2Array()
	for cell in _cells:
		if CampaignState.get_world_terrain(cell) != "water":
			continue
		var corners := _hex_points(_hex_center(cell))
		for direction_index in range(3):
			var neighbor := cell + NEIGHBOR_OFFSETS[direction_index]
			if not CampaignState.is_cell_explored(neighbor) or CampaignState.get_world_terrain(neighbor) == "water":
				continue
			var edge_index := posmod(-direction_index, 6)
			shoreline.append(corners[edge_index])
			shoreline.append(corners[(edge_index + 1) % 6])
	if not shoreline.is_empty():
		draw_multiline(shoreline, Palette.MAP_COASTLINE, maxf(0.7, 1.1 * _map_zoom), true)


func _draw_roads() -> void:
	if _map_zoom < 0.28:
		return
	var road_segments := PackedVector2Array()
	road_segments = _append_city_road_segments(CampaignState.cities, -2, road_segments)
	for kingdom_index in range(CampaignState.kingdoms.size()):
		var kingdom: Dictionary = CampaignState.kingdoms[kingdom_index]
		var cities: Array = kingdom.get("cities", [])
		road_segments = _append_city_road_segments(cities, kingdom_index, road_segments)
	if road_segments.is_empty():
		return
	draw_multiline(road_segments, Palette.MAP_ROAD_SHADOW, maxf(1.1, 4.2 * _map_zoom), true)
	draw_multiline(road_segments, Palette.MAP_ROAD_LIGHT, maxf(0.7, 1.8 * _map_zoom), true)


func _append_city_road_segments(
		cities: Array,
		owner_id: int,
		road_segments: PackedVector2Array
) -> PackedVector2Array:
	if cities.size() < 2:
		return road_segments
	var capital_data: Dictionary = cities[0]
	var capital_cell := WorldGeneratorScript.array_to_cell(capital_data.get("cell", []))
	for city_index in range(1, cities.size()):
		var city_data: Dictionary = cities[city_index]
		var destination := WorldGeneratorScript.array_to_cell(city_data.get("cell", []))
		var route: Array[Vector2i] = StrategicMapDetailsScript.axial_line(capital_cell, destination)
		for step in range(route.size() - 1):
			var start_cell := route[step]
			var finish_cell := route[step + 1]
			if not CampaignState.is_cell_explored(start_cell) or not CampaignState.is_cell_explored(finish_cell):
				continue
			if CampaignState.get_world_terrain(start_cell) == "water" or CampaignState.get_world_terrain(finish_cell) == "water":
				continue
			var start_owner := int(_owner_lookup.get(start_cell, -1))
			var finish_owner := int(_owner_lookup.get(finish_cell, -1))
			if (start_owner != -1 and start_owner != owner_id) or (finish_owner != -1 and finish_owner != owner_id):
				continue
			var start_point := _hex_center(start_cell)
			var finish_point := _hex_center(finish_cell)
			var direction := (finish_point - start_point).normalized()
			if step == 0:
				start_point += direction * 12.0 * _map_zoom
			if step == route.size() - 2:
				finish_point -= direction * 12.0 * _map_zoom
			if start_point.distance_to(finish_point) < 3.0:
				continue
			if not _point_is_visible((start_point + finish_point) * 0.5, 24.0 * _map_zoom):
				continue
			road_segments.append(start_point)
			road_segments.append(finish_point)
	return road_segments


func _draw_territory_borders() -> void:
	if _cells.is_empty():
		return
	var boundary_segments := PackedVector2Array()
	for cell in _cells:
		var cell_owner := int(_owner_lookup.get(cell, -1))
		for direction_index in range(3):
			var neighbor := cell + NEIGHBOR_OFFSETS[direction_index]
			if not CampaignState.is_cell_explored(neighbor):
				continue
			var neighbor_owner := int(_owner_lookup.get(neighbor, -1))
			if cell_owner == neighbor_owner or (cell_owner == -1 and neighbor_owner == -1):
				continue
			var corners := _hex_points(_hex_center(cell))
			var edge_index := posmod(-direction_index, 6)
			var edge_start := corners[edge_index]
			var edge_finish := corners[(edge_index + 1) % 6]
			if not _point_is_visible((edge_start + edge_finish) * 0.5, 12.0 * _map_zoom):
				continue
			boundary_segments.append(edge_start)
			boundary_segments.append(edge_finish)
	if boundary_segments.is_empty():
		return
	draw_multiline(boundary_segments, Palette.MAP_BORDER_SHADOW, maxf(0.55, 1.8 * _map_zoom), true)
	draw_multiline(boundary_segments, Palette.MAP_CLAIM_BORDER, maxf(0.4, 0.9 * _map_zoom), true)


func _draw_province_improvements() -> void:
	for city_data in CampaignState.cities:
		for improvement in city_data.get("province_improvements", []):
			var cell := WorldGeneratorScript.array_to_cell(improvement.get("cell", []))
			if not CampaignState.is_cell_explored(cell):
				continue
			var center := _hex_center(cell)
			var screen_point := center
			if not _point_is_visible(screen_point, 16.0 * _map_zoom):
				continue
			var improvement_id := str(improvement.get("id", ""))
			var marker_color := Color("#d9b65d")
			match improvement_id:
				"farm_plot": marker_color = Color("#8fb66b")
				"trade_post": marker_color = Color("#e0c16c")
				"woodland_camp": marker_color = Color("#79a879")
				"stone_quarry": marker_color = Color("#a6aab0")
			draw_circle(screen_point, maxf(2.2, 3.0 * _map_zoom), marker_color)
			draw_arc(screen_point, maxf(3.0, 4.0 * _map_zoom), 0.0, TAU, 12, Color(0.08, 0.07, 0.05, 0.9), 1.0)


func _draw_neutral_locations() -> void:
	for location in CampaignState.neutral_locations:
		var cell := WorldGeneratorScript.array_to_cell(location.get("cell", []))
		if not CampaignState.is_cell_explored(cell):
			continue
		var center := _hex_center(cell)
		if not _point_is_visible(center, 14.0 * _map_zoom):
			continue
		var type_id := str(location.get("type", "ancient_ruins"))
		var marker_color := WorldLocationCatalogScript.get_color(type_id)
		if bool(location.get("cleared", false)):
			marker_color = marker_color.darkened(0.58)
		elif not CampaignState.is_cell_visible(cell):
			marker_color = marker_color.darkened(0.30)
		var radius := maxf(4.0, 8.5 * _map_zoom)
		if _map_zoom < 0.30:
			radius = maxf(2.3, 3.2 * _map_zoom)
			draw_circle(center, radius, marker_color)
			continue
		var diamond := PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius * 0.82, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius * 0.82, 0.0),
		])
		draw_colored_polygon(diamond, Color("#171b20"))
		draw_polyline(_closed_polygon(diamond), marker_color, maxf(1.0, 1.4 * _map_zoom), true)
		draw_circle(center, maxf(1.6, 2.2 * _map_zoom), marker_color)
		if _map_zoom >= 0.56:
			var marker := WorldLocationCatalogScript.get_marker(type_id)
			draw_string(ThemeDB.fallback_font, center + Vector2(-3.5, 4.0) * _map_zoom, marker, HORIZONTAL_ALIGNMENT_LEFT, -1.0, maxi(8, roundi(10.0 * _map_zoom)), Palette.UI_TEXT_PURE)


func _draw_city_label(center: Vector2, city_name: String, faction_color: Color) -> void:
	if city_name.is_empty():
		return
	var font := ThemeDB.fallback_font
	var font_size := clampi(roundi(16.5 * _map_zoom), 14, 18)
	var measured := font.get_string_size(city_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var label_size := Vector2(measured.x + 16.0, float(font_size + 11))
	var label_origin := center + Vector2(-label_size.x * 0.5, 55.0 * _map_zoom)
	var label_rect := Rect2(label_origin, label_size)
	if not _point_is_visible(label_rect.position + label_rect.size * 0.5, label_size.x * 0.5):
		return
	draw_rect(label_rect, Palette.MAP_LABEL_BACKGROUND, true)
	draw_rect(label_rect, faction_color.darkened(0.20), false, maxf(0.65, 0.9 * _map_zoom))
	draw_string(
		font,
		label_origin + Vector2(8.0, float(font_size) + 2.0),
		city_name,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Palette.MAP_LABEL_TEXT
	)




func _draw_army_marker(cell: Vector2i, marker_color: Color, letter: String) -> void:
	var center := _hex_center(cell)
	if _map_zoom < 0.22:
		draw_circle(center, maxf(3.0, 10.0 * _map_zoom), marker_color)
		draw_string(ThemeDB.fallback_font, center + Vector2(-3.0, 3.0) * _map_zoom, letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Palette.MAP_ARMY_TEXT)
		return
	draw_circle(center + Vector2(0.0, 4.0 * _map_zoom), 19.0 * _map_zoom, Palette.MAP_ARMY_SHADOW)
	draw_circle(center, 16.0 * _map_zoom, marker_color.darkened(0.28))
	var army_icon := GameIconCatalogScript.map_marker_icon("crossed_swords")
	if army_icon != null:
		var icon_size := Vector2.ONE * 30.0 * _map_zoom
		draw_texture_rect(army_icon, Rect2(center - icon_size * 0.5, icon_size), false, Color.WHITE)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-4.0, 23.0) * _map_zoom,
		letter,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		maxi(8, roundi(10.0 * _map_zoom)),
		Palette.MAP_ARMY_TEXT
	)


func _draw_settler_marker(center: Vector2) -> void:
	draw_circle(center + Vector2(0.0, 4.0 * _map_zoom), 14.0 * _map_zoom, Palette.MAP_SETTLER_SHADOW)
	draw_circle(center, 11.0 * _map_zoom, Palette.MAP_SETTLER_BODY)
	var worker_icon := GameIconCatalogScript.unit_icon("worker")
	if worker_icon != null:
		var icon_size := Vector2.ONE * 34.0 * _map_zoom
		draw_texture_rect(worker_icon, Rect2(center - icon_size * 0.5, icon_size), false, Color.WHITE)
	draw_circle(center + Vector2(10.0, -10.0) * _map_zoom, 3.0 * _map_zoom, Palette.MAP_SETTLER_ACCENT)


func _build_map() -> void:
	_cells.clear()
	_camera_center_world = _hex_world_position(CampaignState.player_cell)
	_map_zoom = 1.08




func _terrain_color(kind: String) -> Color:
	match kind:
		"forest":
			return Palette.MAP_TERRAIN_FOREST
		"hills":
			return Palette.MAP_TERRAIN_HILLS
		"water":
			return Palette.MAP_TERRAIN_WATER
		"farmland":
			return Palette.MAP_TERRAIN_FARMLAND
		"marsh":
			return Palette.MAP_TERRAIN_MARSH
		_:
			return Palette.MAP_TERRAIN_GRASS


func _terrain_symbol(kind: String) -> String:
	match kind:
		"forest":
			return "F"
		"hills":
			return "H"
		"water":
			return "~"
		"farmland":
			return "▧"
		"marsh":
			return "≈"
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
		points.append(center + Vector2(cos(angle), sin(angle)) * HEX_SIZE * 1.0 * _map_zoom)
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
	top_panel.offset_bottom = UiMetrics.dp(78.0)
	root.add_child(top_panel)

	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", int(UiMetrics.dp(1.0)))
	top_panel.add_child(top_box)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(13))
	_status_label.add_theme_color_override("font_color", Palette.UI_TEXT_PURE)
	_status_label.clip_text = true
	_status_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	top_box.add_child(_status_label)

	var hud_resources := HBoxContainer.new()
	hud_resources.add_theme_constant_override("separation", int(UiMetrics.dp(10.0)))
	top_box.add_child(hud_resources)
	_hud_resource_labels["gold"] = _add_icon_value(hud_resources, GameIconCatalogScript.resource_icon("gold"), 12)
	_hud_resource_labels["food"] = _add_icon_value(hud_resources, GameIconCatalogScript.resource_icon("food"), 12)
	_hud_resource_labels["production"] = _add_icon_value(hud_resources, GameIconCatalogScript.resource_icon("production"), 12)

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_message_label.clip_text = true
	_message_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(10))
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
	_map_more_panel.offset_bottom = -UiMetrics.dp(74.0)
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
	_set_button_icon(_attack_button, GameIconCatalogScript.command_icon("attack"))
	_add_button(more_grid, "НОВАЯ КАМПАНИЯ", _restart_campaign)
	_found_city_button = _add_button(more_grid, "ОСНОВАТЬ ГОРОД", _found_city)
	_set_button_icon(_found_city_button, GameIconCatalogScript.unit_icon("worker"))
	_add_button(more_grid, "НАСТРОЙКИ", _open_settings)
	_kingdoms_button = _add_button(more_grid, "КОРОЛЕВСТВА", _open_kingdoms_panel)
	_add_button(more_grid, "ЦЕЛИ ПОБЕДЫ", _open_campaign_victory_panel)

	_bottom_panel = PanelContainer.new()
	_bottom_panel.name = "MobileHudQuickDock"
	_bottom_panel.anchor_left = 0.0
	_bottom_panel.anchor_top = 1.0
	_bottom_panel.anchor_right = 1.0
	_bottom_panel.anchor_bottom = 1.0
	_bottom_panel.offset_left = UiMetrics.dp(10.0)
	_bottom_panel.offset_top = -UiMetrics.dp(66.0)
	_bottom_panel.offset_right = -UiMetrics.dp(10.0)
	_bottom_panel.offset_bottom = -UiMetrics.dp(8.0)
	root.add_child(_bottom_panel)

	var quick_row := HBoxContainer.new()
	quick_row.add_theme_constant_override("separation", int(UiMetrics.dp(5.0)))
	_bottom_panel.add_child(quick_row)
	_selection_button = _add_button(quick_row, "АРМИЯ", _select_player_army)
	_set_button_icon(_selection_button, GameIconCatalogScript.unit_icon("melee"))
	_city_button = _add_button(quick_row, "ГОРОД", _open_city)
	_set_button_icon(_city_button, GameIconCatalogScript.settlement_icon("castle_blue"))
	_turn_button = _add_button(quick_row, "ХОД", _advance_turn)
	_map_more_button = _add_button(quick_row, "ЕЩЁ", _toggle_map_commands)
	_create_city_panel(root)
	_create_kingdoms_panel(root)
	_create_world_event_panel(root)
	_create_campaign_victory_panel(root)
	_create_faction_setup_panel(root)
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
	if CampaignState.faction_setup_pending:
		_open_faction_setup_panel()


func _create_world_event_panel(root: Control) -> void:
	_world_event_panel = PanelContainer.new()
	_world_event_panel.name = "WorldEventChoicePanel"
	_world_event_panel.anchor_left = 0.39
	_world_event_panel.anchor_top = 0.12
	_world_event_panel.anchor_right = 0.97
	_world_event_panel.anchor_bottom = 0.58
	_world_event_panel.visible = false
	root.add_child(_world_event_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(UiMetrics.dp(12.0)))
	margin.add_theme_constant_override("margin_top", int(UiMetrics.dp(10.0)))
	margin.add_theme_constant_override("margin_right", int(UiMetrics.dp(12.0)))
	margin.add_theme_constant_override("margin_bottom", int(UiMetrics.dp(10.0)))
	_world_event_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(UiMetrics.dp(8.0)))
	margin.add_child(content)
	_world_event_title_label = Label.new()
	_world_event_title_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(21))
	_world_event_title_label.add_theme_color_override("font_color", Palette.UI_TEXT_CITY_TITLE)
	content.add_child(_world_event_title_label)
	_world_event_body_label = Label.new()
	_world_event_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_world_event_body_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(15))
	_world_event_body_label.add_theme_color_override("font_color", Palette.UI_TEXT_BODY)
	content.add_child(_world_event_body_label)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", int(UiMetrics.dp(8.0)))
	choices.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_child(choices)
	for index in range(2):
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(52.0))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", UiThemeScript.font_size(13))
		button.pressed.connect(_resolve_world_event_choice.bind(index))
		choices.add_child(button)
		_world_event_choice_buttons.append(button)


func _refresh_world_event_panel() -> void:
	if not is_instance_valid(_world_event_panel):
		return
	var event_data: Dictionary = CampaignState.pending_world_event
	_world_event_panel.visible = not event_data.is_empty()
	if event_data.is_empty():
		return
	_world_event_title_label.text = str(event_data.get("title", "Событие мира"))
	_world_event_body_label.text = str(event_data.get("body", "Путешественцы принесли новости."))
	var choices: Array = event_data.get("choices", [])
	for index in range(_world_event_choice_buttons.size()):
		var button: Button = _world_event_choice_buttons[index]
		if index >= choices.size() or not choices[index] is Dictionary:
			button.visible = false
			continue
		var choice: Dictionary = choices[index]
		var choice_id := str(choice.get("id", ""))
		button.visible = true
		button.text = str(choice.get("label", "Выбрать"))
		button.disabled = not CampaignState.can_resolve_world_event(choice_id)


func _resolve_world_event_choice(choice_index: int) -> void:
	var choices: Array = CampaignState.pending_world_event.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size() or not choices[choice_index] is Dictionary:
		return
	var choice: Dictionary = choices[choice_index]
	var choice_id := str(choice.get("id", ""))
	if not CampaignState.resolve_world_event(choice_id):
		if is_instance_valid(_toast_manager):
			var choice_effect: Dictionary = choices[choice_index].get("effect", {})
			var reason := "Не хватает золота или еды"
			if int(choice_effect.get("population_gain", 0)) > 0 and CampaignState.city_population >= 20:
				reason = "Город достиг предела населения"
			_toast_manager.show_toast(reason, 2.0, "!")
		return
	_message_text = CampaignState.last_world_event_text
	_refresh_world_event_panel()
	_refresh_ui()
	queue_redraw()
	Haptics.confirm(15)


func _create_campaign_victory_panel(root: Control) -> void:
	_victory_panel = PanelContainer.new()
	_victory_panel.name = "CampaignVictoryPanel"
	_victory_panel.anchor_left = 0.06
	_victory_panel.anchor_top = 0.10
	_victory_panel.anchor_right = 0.94
	_victory_panel.anchor_bottom = 0.90
	_victory_panel.visible = false
	_victory_panel.z_index = 14
	root.add_child(_victory_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(UiMetrics.dp(10.0)))
	margin.add_theme_constant_override("margin_top", int(UiMetrics.dp(8.0)))
	margin.add_theme_constant_override("margin_right", int(UiMetrics.dp(10.0)))
	margin.add_theme_constant_override("margin_bottom", int(UiMetrics.dp(8.0)))
	_victory_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(UiMetrics.dp(7.0)))
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = "ПУТИ К ПОБЕДЕ"
	title.add_theme_font_size_override("font_size", UiThemeScript.font_size(19))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := _add_button(header, "ЗАКРЫТЬ", _close_campaign_victory_panel)
	close_button.custom_minimum_size = Vector2(UiMetrics.dp(104.0), UiThemeScript.touch_target(48.0))

	_victory_summary_label = Label.new()
	_victory_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_victory_summary_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(13))
	_victory_summary_label.add_theme_color_override("font_color", Palette.UI_TEXT_HELP)
	content.add_child(_victory_summary_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", int(UiMetrics.dp(6.0)))
	scroll.add_child(rows)

	var row_titles := {
		"military": "ВОЕННОЕ ПРЕВОСХОДСТВО",
		"economic": "ЭКОНОМИЧЕСКОЕ ПРЕВОСХОДСТВО",
		"diplomatic": "ДИПЛОМАТИЧЕСКОЕ ПРЕВОСХОДСТВО",
	}
	for type_id in CampaignVictoryCatalogScript.VICTORY_TYPES:
		var row := PanelContainer.new()
		rows.add_child(row)
		var row_margin := MarginContainer.new()
		row_margin.add_theme_constant_override("margin_left", int(UiMetrics.dp(8.0)))
		row_margin.add_theme_constant_override("margin_top", int(UiMetrics.dp(5.0)))
		row_margin.add_theme_constant_override("margin_right", int(UiMetrics.dp(8.0)))
		row_margin.add_theme_constant_override("margin_bottom", int(UiMetrics.dp(5.0)))
		row.add_child(row_margin)
		var row_content := VBoxContainer.new()
		row_content.add_theme_constant_override("separation", int(UiMetrics.dp(3.0)))
		row_margin.add_child(row_content)
		var row_title := Label.new()
		row_title.text = str(row_titles.get(type_id, type_id.to_upper()))
		row_title.add_theme_font_size_override("font_size", UiThemeScript.font_size(14))
		row_content.add_child(row_title)
		var detail := Label.new()
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_theme_font_size_override("font_size", UiThemeScript.font_size(12))
		detail.add_theme_color_override("font_color", Palette.UI_TEXT_HELP)
		row_content.add_child(detail)
		var select_button := _add_button(row_content, "ВЫБРАТЬ", _select_campaign_victory.bind(type_id))
		select_button.custom_minimum_size.y = UiThemeScript.touch_target(48.0)
		_victory_detail_labels[type_id] = detail
		_victory_select_buttons[type_id] = select_button

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", int(UiMetrics.dp(6.0)))
	content.add_child(footer)
	_victory_finish_button = _add_button(footer, "ЗАВЕРШИТЬ КАМПАНИЮ", _finish_campaign_victory)
	_victory_continue_button = _add_button(footer, "ПРОДОЛЖИТЬ ИГРУ", _continue_campaign_victory)


func _open_campaign_victory_panel() -> void:
	if is_instance_valid(_map_more_panel) and _map_more_panel.visible:
		_toggle_map_commands()
	if is_instance_valid(_victory_panel):
		_victory_panel.visible = true
		_refresh_campaign_victory_panel()


func _close_campaign_victory_panel() -> void:
	if is_instance_valid(_victory_panel):
		_victory_panel.visible = false


func _select_campaign_victory(victory_type: String) -> void:
	var progress := CampaignState.get_campaign_victory_progress()
	var unlocked: Array = progress.get("unlocked_types", [])
	if not unlocked.has(victory_type):
		return
	_selected_victory_type = victory_type
	_refresh_campaign_victory_panel()


func _finish_campaign_victory() -> void:
	if _selected_victory_type.is_empty():
		return
	if CampaignState.choose_campaign_victory(_selected_victory_type, false):
		_message_text = "Кампания завершена: " + _selected_victory_type
		_refresh_campaign_victory_panel()
		_refresh_ui()
		Haptics.confirm(20)


func _continue_campaign_victory() -> void:
	if _selected_victory_type.is_empty():
		return
	if CampaignState.choose_campaign_victory(_selected_victory_type, true):
		_message_text = "Победа достигнута. Кампания продолжается в свободном режиме."
		_close_campaign_victory_panel()
		_refresh_ui()
		Haptics.confirm(15)


func _refresh_campaign_victory_panel() -> void:
	if not is_instance_valid(_victory_panel):
		return
	var progress := CampaignState.get_campaign_victory_progress()
	var unlocked: Array = progress.get("unlocked_types", [])
	var status := str(CampaignState.campaign_victory.get("status", "none"))
	var wins := int(progress.get("military_wins", 0))
	var army_size := int(progress.get("army_size", 0))
	var military_text := "Победы над разными державами: %d / %d. Живых бойцов: %d / %d." % [
		wins, int(progress.get("military_required", 6)), army_size, int(progress.get("military_army_required", 8))
	]
	var economic_text := "Метрополии: %d / %d. Золото в казнах: %d / %d. Чистый доход: %d / %d за ход. Удержание: %d / %d ходов." % [
		int(progress.get("metropolises", 0)), int(progress.get("metropolises_required", 2)),
		int(progress.get("total_gold", 0)), int(progress.get("gold_required", 600)),
		int(progress.get("net_gold_income", 0)), int(progress.get("net_gold_required", 12)),
		int(progress.get("economic_hold_turns", 0)), int(progress.get("economic_hold_required", 5))
	]
	var diplomatic_text := "Дружественные державы: %d / %d. Действующие договоры: %d / %d. Союзы и вассалитет: %d / %d. Удержание: %d / %d ходов." % [
		int(progress.get("friendly_kingdoms", 0)), int(progress.get("friendly_required", 5)),
		int(progress.get("active_positive_treaties", 0)), int(progress.get("treaties_required", 3)),
		int(progress.get("major_treaties", 0)), int(progress.get("major_treaties_required", 2)),
		int(progress.get("diplomatic_hold_turns", 0)), int(progress.get("diplomatic_hold_required", 3))
	]
	_victory_detail_labels["military"].text = military_text
	_victory_detail_labels["economic"].text = economic_text
	_victory_detail_labels["diplomatic"].text = diplomatic_text

	for type_id in CampaignVictoryCatalogScript.VICTORY_TYPES:
		var button: Button = _victory_select_buttons[type_id]
		var is_unlocked := unlocked.has(type_id)
		button.disabled = not is_unlocked or status == "claimed"
		button.text = "ВЫБРАНО" if _selected_victory_type == type_id else ("ВЫБРАТЬ ПУТЬ" if is_unlocked else "УСЛОВИЯ НЕ ВЫПОЛНЕНЫ")

	if status == "claimed":
		_victory_summary_label.text = "Кампания завершена на ходу %d. Победа: %s. Чтобы начать заново, используй «Новая кампания»." % [
			int(CampaignState.campaign_victory.get("turn", CampaignState.turn_number)),
			str(CampaignState.campaign_victory.get("type", "")).to_upper()
		]
	elif status == "continued":
		_victory_summary_label.text = "Победа уже достигнута на ходу %d. Кампания продолжается в свободном режиме." % int(CampaignState.campaign_victory.get("turn", 0))
	else:
		_victory_summary_label.text = "Ход %d. Проверка путей победы начинается с %d-го хода. Выбери достигнутый путь." % [CampaignState.turn_number, CampaignVictoryCatalogScript.MIN_CAMPAIGN_TURN]
	_victory_finish_button.disabled = _selected_victory_type.is_empty() or not unlocked.has(_selected_victory_type) or status == "claimed"
	_victory_continue_button.disabled = _victory_finish_button.disabled or status == "continued"
	_victory_finish_button.text = "КАМПАНИЯ ЗАВЕРШЕНА" if status == "claimed" else "ЗАВЕРШИТЬ КАМПАНИЮ"
	_victory_continue_button.text = "СВОБОДНЫЙ РЕЖИМ" if status == "continued" else "ПРОДОЛЖИТЬ ИГРУ"


func _create_faction_setup_panel(root: Control) -> void:
	_faction_setup_panel = PanelContainer.new()
	_faction_setup_panel.name = "FactionFoundingPanel"
	_faction_setup_panel.anchor_left = 0.035
	_faction_setup_panel.anchor_top = 0.035
	_faction_setup_panel.anchor_right = 0.965
	_faction_setup_panel.anchor_bottom = 0.965
	_faction_setup_panel.visible = false
	_faction_setup_panel.z_index = 30
	root.add_child(_faction_setup_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(UiMetrics.dp(16.0)))
	margin.add_theme_constant_override("margin_top", int(UiMetrics.dp(12.0)))
	margin.add_theme_constant_override("margin_right", int(UiMetrics.dp(16.0)))
	margin.add_theme_constant_override("margin_bottom", int(UiMetrics.dp(12.0)))
	_faction_setup_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", int(UiMetrics.dp(7.0)))
	margin.add_child(layout)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	layout.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", int(UiMetrics.dp(6.0)))
	scroll.add_child(content)

	var title := Label.new()
	title.text = "ОСНОВАНИЕ КОРОЛЕВСТВА"
	title.add_theme_font_size_override("font_size", UiThemeScript.font_size(24))
	title.add_theme_color_override("font_color", Palette.UI_TEXT_CITY_TITLE)
	content.add_child(title)
	var intro := Label.new()
	intro.text = "Народ, культура и две черты определяют стиль кампании."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", UiThemeScript.font_size(13))
	intro.add_theme_color_override("font_color", Palette.UI_TEXT_HELP)
	content.add_child(intro)

	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", int(UiMetrics.dp(12.0)))
	choices.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(choices)

	var people_column := VBoxContainer.new()
	people_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	people_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	people_column.add_theme_constant_override("separation", int(UiMetrics.dp(5.0)))
	choices.add_child(people_column)
	var people_title := Label.new()
	people_title.text = "1. НАРОД"
	people_title.add_theme_font_size_override("font_size", UiThemeScript.font_size(16))
	people_title.add_theme_color_override("font_color", Palette.UI_TEXT_HERO)
	people_column.add_child(people_title)
	_faction_people_option = OptionButton.new()
	_faction_people_option.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(50.0))
	_faction_people_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_faction_people_option.add_theme_font_size_override("font_size", UiThemeScript.font_size(14))
	_populate_faction_option(_faction_people_option, FactionCatalogScript.people_ids(), "people")
	_faction_people_option.item_selected.connect(_on_faction_option_changed)
	people_column.add_child(_faction_people_option)
	_faction_people_description = _make_faction_description_label(people_column)

	var culture_column := VBoxContainer.new()
	culture_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	culture_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	culture_column.add_theme_constant_override("separation", int(UiMetrics.dp(5.0)))
	choices.add_child(culture_column)
	var culture_title := Label.new()
	culture_title.text = "2. КУЛЬТУРА"
	culture_title.add_theme_font_size_override("font_size", UiThemeScript.font_size(16))
	culture_title.add_theme_color_override("font_color", Palette.UI_TEXT_HERO)
	culture_column.add_child(culture_title)
	_faction_culture_option = OptionButton.new()
	_faction_culture_option.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(50.0))
	_faction_culture_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_faction_culture_option.add_theme_font_size_override("font_size", UiThemeScript.font_size(14))
	_populate_faction_option(_faction_culture_option, FactionCatalogScript.culture_ids(), "culture")
	_faction_culture_option.item_selected.connect(_on_faction_option_changed)
	culture_column.add_child(_faction_culture_option)
	_faction_culture_description = _make_faction_description_label(culture_column)

	var traits_column := VBoxContainer.new()
	traits_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	traits_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	traits_column.add_theme_constant_override("separation", int(UiMetrics.dp(5.0)))
	choices.add_child(traits_column)
	var traits_title := Label.new()
	traits_title.text = "3. ДВЕ ЧЕРТЫ"
	traits_title.add_theme_font_size_override("font_size", UiThemeScript.font_size(16))
	traits_title.add_theme_color_override("font_color", Palette.UI_TEXT_HERO)
	traits_column.add_child(traits_title)
	_faction_trait_a_option = OptionButton.new()
	_faction_trait_a_option.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(50.0))
	_faction_trait_a_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_faction_trait_a_option.add_theme_font_size_override("font_size", UiThemeScript.font_size(13))
	_populate_faction_option(_faction_trait_a_option, FactionCatalogScript.trait_ids(), "trait")
	_faction_trait_a_option.item_selected.connect(_on_faction_option_changed)
	traits_column.add_child(_faction_trait_a_option)
	_faction_trait_b_option = OptionButton.new()
	_faction_trait_b_option.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(50.0))
	_faction_trait_b_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_faction_trait_b_option.add_theme_font_size_override("font_size", UiThemeScript.font_size(13))
	_populate_faction_option(_faction_trait_b_option, FactionCatalogScript.trait_ids(), "trait")
	_faction_trait_b_option.item_selected.connect(_on_faction_option_changed)
	_faction_trait_b_option.select(1)
	traits_column.add_child(_faction_trait_b_option)
	_faction_traits_description = _make_faction_description_label(traits_column)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", int(UiMetrics.dp(8.0)))
	content.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "ИМЯ КОРОЛЕВСТВА"
	name_label.custom_minimum_size = Vector2(UiMetrics.dp(180.0), UiMetrics.dp(48.0))
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(14))
	name_row.add_child(name_label)
	_faction_name_edit = LineEdit.new()
	_faction_name_edit.text = "Речная держава"
	_faction_auto_name = "Речная держава"
	_faction_name_edit.placeholder_text = "Название королевства"
	_faction_name_edit.max_length = 28
	_faction_name_edit.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(50.0))
	_faction_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_faction_name_edit.add_theme_font_size_override("font_size", UiThemeScript.font_size(15))
	_faction_name_edit.text_changed.connect(_on_faction_name_changed)
	name_row.add_child(_faction_name_edit)

	_faction_summary_label = Label.new()
	_faction_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_faction_summary_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(13))
	_faction_summary_label.add_theme_color_override("font_color", Palette.UI_TEXT_INCOME)
	content.add_child(_faction_summary_label)
	var footer := HBoxContainer.new()
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(footer)
	_faction_confirm_button = _add_button(footer, "ОСНОВАТЬ КОРОЛЕВСТВО", _confirm_faction_setup)
	_faction_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_faction_confirm_button.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(56.0))
	_faction_confirm_button.add_theme_font_size_override("font_size", UiThemeScript.font_size(16))
	_on_faction_option_changed()


func _make_faction_description_label(parent: Container) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.add_theme_font_size_override("font_size", UiThemeScript.font_size(12))
	label.add_theme_color_override("font_color", Palette.UI_TEXT_BODY)
	parent.add_child(label)
	return label


func _populate_faction_option(option: OptionButton, ids: Array[String], group_id: String) -> void:
	for item_id in ids:
		var definition: Dictionary = FactionCatalogScript.get_people(item_id) if group_id == "people" else FactionCatalogScript.get_culture(item_id) if group_id == "culture" else FactionCatalogScript.get_trait(item_id)
		var item_index := option.item_count
		option.add_item(str(definition.get("name", item_id)))
		option.set_item_metadata(item_index, item_id)
	if option.item_count > 0:
		option.select(0)


func _get_faction_option_id(option: OptionButton) -> String:
	if not is_instance_valid(option) or option.item_count <= 0 or option.selected < 0:
		return ""
	return str(option.get_item_metadata(option.selected))


func _on_faction_option_changed(_index: int = -1) -> void:
	if not is_instance_valid(_faction_people_option):
		return
	if is_instance_valid(_faction_trait_a_option) and is_instance_valid(_faction_trait_b_option):
		if _faction_trait_a_option.selected == _faction_trait_b_option.selected:
			_faction_trait_b_option.select(posmod(_faction_trait_b_option.selected + 1, _faction_trait_b_option.item_count))
	_refresh_faction_setup_default_name()
	var people_id := _get_faction_option_id(_faction_people_option)
	var culture_id := _get_faction_option_id(_faction_culture_option)
	var trait_a_id := _get_faction_option_id(_faction_trait_a_option)
	var trait_b_id := _get_faction_option_id(_faction_trait_b_option)
	var people_data := FactionCatalogScript.get_people(people_id)
	var culture_data := FactionCatalogScript.get_culture(culture_id)
	var trait_a_data := FactionCatalogScript.get_trait(trait_a_id)
	var trait_b_data := FactionCatalogScript.get_trait(trait_b_id)
	_faction_people_description.text = str(people_data.get("description", ""))
	_faction_culture_description.text = str(culture_data.get("description", ""))
	_faction_traits_description.text = "%s\n\n%s" % [str(trait_a_data.get("description", "")), str(trait_b_data.get("description", ""))]
	var selection := {"people_id": people_id, "culture_id": culture_id, "trait_ids": [trait_a_id, trait_b_id]}
	var effects := FactionCatalogScript.get_effects(selection)
	var bonus_lines: Array[String] = []
	if int(effects.get("farm_food_bonus", 0)) > 0:
		bonus_lines.append("Фермы: +%d еды/ход" % int(effects.get("farm_food_bonus", 0)))
	if int(effects.get("market_gold_bonus", 0)) > 0:
		bonus_lines.append("Рынки: +%d золота/ход" % int(effects.get("market_gold_bonus", 0)))
	if int(effects.get("workshop_production_bonus", 0)) > 0:
		bonus_lines.append("Мастерские: +%d производства/ход" % int(effects.get("workshop_production_bonus", 0)))
	if float(effects.get("recruit_multiplier", 1.0)) < 1.0:
		bonus_lines.append("Общий найм: −%d%% золота" % roundi((1.0 - float(effects.get("recruit_multiplier", 1.0))) * 100.0))
	if float(effects.get("ranged_recruit_multiplier", 1.0)) < 1.0:
		bonus_lines.append("Найм лучников: дополнительно −%d%%" % roundi((1.0 - float(effects.get("ranged_recruit_multiplier", 1.0))) * 100.0))
	if float(effects.get("cavalry_recruit_multiplier", 1.0)) < 1.0:
		bonus_lines.append("Найм кавалерии: дополнительно −%d%%" % roundi((1.0 - float(effects.get("cavalry_recruit_multiplier", 1.0))) * 100.0))
	if float(effects.get("cavalry_upkeep_multiplier", 1.0)) < 1.0:
		bonus_lines.append("Содержание кавалерии: дополнительно −%d%%" % roundi((1.0 - float(effects.get("cavalry_upkeep_multiplier", 1.0))) * 100.0))
	if float(effects.get("army_upkeep_multiplier", 1.0)) < 1.0:
		bonus_lines.append("Содержание армии: −%d%%" % roundi((1.0 - float(effects.get("army_upkeep_multiplier", 1.0))) * 100.0))
	if int(effects.get("army_vision_bonus", 0)) > 0:
		bonus_lines.append("Обзор армии: +%d гекс." % int(effects.get("army_vision_bonus", 0)))
	if int(effects.get("province_slot_bonus", 0)) > 0:
		bonus_lines.append("Провинции: +%d участок/город" % int(effects.get("province_slot_bonus", 0)))
	if int(effects.get("city_food_income_bonus", 0)) > 0:
		bonus_lines.append("Каждый город: +%d еды/ход" % int(effects.get("city_food_income_bonus", 0)))
	if int(effects.get("starting_food_bonus", 0)) > 0:
		bonus_lines.append("Запас еды: +%d" % int(effects.get("starting_food_bonus", 0)))
	if int(effects.get("starting_production_bonus", 0)) > 0:
		bonus_lines.append("Запас производства: +%d" % int(effects.get("starting_production_bonus", 0)))
	if int(effects.get("starting_unit_experience", 0)) > 0:
		bonus_lines.append("Опыт стартовых бойцов: +%d" % int(effects.get("starting_unit_experience", 0)))
	_faction_summary_label.text = "ЭФФЕКТЫ: " + (" · ".join(bonus_lines) if not bonus_lines.is_empty() else "без дополнительных бонусов")
	if is_instance_valid(_faction_confirm_button):
		_faction_confirm_button.disabled = not FactionCatalogScript.is_valid_selection(selection) or _faction_name_edit.text.strip_edges().length() < 2


func _on_faction_name_changed(_value: String) -> void:
	if is_instance_valid(_faction_confirm_button):
		_faction_confirm_button.disabled = _faction_name_edit.text.strip_edges().length() < 2


func _open_faction_setup_panel() -> void:
	if not CampaignState.faction_setup_pending or not is_instance_valid(_faction_setup_panel):
		return
	_faction_setup_panel.visible = true
	if is_instance_valid(_city_panel):
		_city_panel.visible = false
	if is_instance_valid(_kingdoms_panel):
		_kingdoms_panel.visible = false
	if is_instance_valid(_map_more_panel):
		_map_more_panel.visible = false
	if is_instance_valid(_bottom_panel):
		_bottom_panel.visible = false
	_refresh_faction_setup_default_name()
	_on_faction_option_changed()


func _refresh_faction_setup_default_name() -> void:
	if not is_instance_valid(_faction_name_edit) or not is_instance_valid(_faction_people_option):
		return
	var people_id := _get_faction_option_id(_faction_people_option)
	var people_data := FactionCatalogScript.get_people(people_id)
	var next_default := str(people_data.get("kingdom_name", "Новое королевство"))
	if _faction_name_edit.text.strip_edges().is_empty() or _faction_name_edit.text == _faction_auto_name:
		_faction_name_edit.text = next_default
	_faction_auto_name = next_default


func _confirm_faction_setup() -> void:
	var selection := {
		"people_id": _get_faction_option_id(_faction_people_option),
		"culture_id": _get_faction_option_id(_faction_culture_option),
		"trait_ids": [_get_faction_option_id(_faction_trait_a_option), _get_faction_option_id(_faction_trait_b_option)],
		"kingdom_name": _faction_name_edit.text.strip_edges(),
	}
	if not CampaignState.apply_player_faction(selection):
		if is_instance_valid(_toast_manager):
			_toast_manager.show_toast("Проверь народ, культуру и две разные черты.", 2.8, "!")
		return
	_faction_setup_panel.visible = false
	if is_instance_valid(_bottom_panel):
		_bottom_panel.visible = true
	var people_data := FactionCatalogScript.get_people(str(selection.get("people_id", "")))
	var culture_data := FactionCatalogScript.get_culture(str(selection.get("culture_id", "")))
	_message_text = "%s основано: %s · %s. Выбери синюю армию и начни исследование." % [str(selection.get("kingdom_name", "Королевство")), str(people_data.get("name", "Народ")), str(culture_data.get("name", "Культура"))]
	_refresh_ui()
	queue_redraw()
	if is_instance_valid(_toast_manager):
		_toast_manager.show_toast("Королевство основано", 2.2, "✓")
	Haptics.confirm()


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

	_diplomacy_panel = PanelContainer.new()
	_diplomacy_panel.name = "DiplomacyDetailPanel"
	_diplomacy_panel.anchor_left = 0.06
	_diplomacy_panel.anchor_top = 0.10
	_diplomacy_panel.anchor_right = 0.94
	_diplomacy_panel.anchor_bottom = 0.90
	_diplomacy_panel.visible = false
	_diplomacy_panel.z_index = 12
	root.add_child(_diplomacy_panel)
	var diplomacy_margin := MarginContainer.new()
	diplomacy_margin.add_theme_constant_override("margin_left", int(UiMetrics.dp(10.0)))
	diplomacy_margin.add_theme_constant_override("margin_top", int(UiMetrics.dp(8.0)))
	diplomacy_margin.add_theme_constant_override("margin_right", int(UiMetrics.dp(10.0)))
	diplomacy_margin.add_theme_constant_override("margin_bottom", int(UiMetrics.dp(8.0)))
	_diplomacy_panel.add_child(diplomacy_margin)
	var diplomacy_content := VBoxContainer.new()
	diplomacy_content.add_theme_constant_override("separation", int(UiMetrics.dp(7.0)))
	diplomacy_margin.add_child(diplomacy_content)
	var diplomacy_header := HBoxContainer.new()
	diplomacy_content.add_child(diplomacy_header)
	var diplomacy_title := Label.new()
	diplomacy_title.text = "ДИПЛОМАТИЯ"
	diplomacy_title.add_theme_font_size_override("font_size", UiThemeScript.font_size(19))
	diplomacy_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diplomacy_header.add_child(diplomacy_title)
	var diplomacy_back := _add_button(diplomacy_header, "НАЗАД", _close_diplomacy_panel)
	diplomacy_back.custom_minimum_size = Vector2(UiMetrics.dp(104.0), UiThemeScript.touch_target(48.0))
	_diplomacy_summary_label = Label.new()
	_diplomacy_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diplomacy_summary_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(13))
	diplomacy_content.add_child(_diplomacy_summary_label)
	var diplomacy_scroll := ScrollContainer.new()
	diplomacy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	diplomacy_content.add_child(diplomacy_scroll)
	_diplomacy_actions_list = VBoxContainer.new()
	_diplomacy_actions_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diplomacy_actions_list.add_theme_constant_override("separation", int(UiMetrics.dp(6.0)))
	diplomacy_scroll.add_child(_diplomacy_actions_list)


func _refresh_kingdoms_panel() -> void:
	if not is_instance_valid(_kingdoms_list):
		return
	for child in _kingdoms_list.get_children():
		child.queue_free()
	if not CampaignState.pending_diplomacy_offers.is_empty():
		var offers_title := Label.new()
		offers_title.text = "ДИПЛОМАТИЧЕСКИЕ ПОСЛАНИЯ"
		offers_title.add_theme_font_size_override("font_size", UiThemeScript.font_size(15))
		_kingdoms_list.add_child(offers_title)
		for offer_value in CampaignState.pending_diplomacy_offers:
			var offer: Dictionary = offer_value
			var offer_id := str(offer.get("offer_id", ""))
			var offer_kingdom_id := int(offer.get("kingdom_id", -1))
			if offer_kingdom_id < 0 or offer_kingdom_id >= CampaignState.kingdoms.size():
				continue
			var offer_name := str(CampaignState.kingdoms[offer_kingdom_id].get("name", "Держава"))
			var offer_action := str(offer.get("action", ""))
			var offer_text := "торговый договор" if offer_action == "offer_trade" else "союз" if offer_action == "offer_alliance" else "мир"
			var offer_label := Label.new()
			offer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			offer_label.text = "%s предлагает: %s · истекает через %d хода(ов)." % [offer_name, offer_text, maxi(0, int(offer.get("expires_turn", 0)) - CampaignState.turn_number)]
			_kingdoms_list.add_child(offer_label)
			var offer_actions := HBoxContainer.new()
			offer_actions.add_theme_constant_override("separation", int(UiMetrics.dp(6.0)))
			_kingdoms_list.add_child(offer_actions)
			_add_button(offer_actions, "ПРИНЯТЬ", Callable(self, "_respond_to_diplomacy_offer").bind(offer_id, true))
			_add_button(offer_actions, "ОТКЛОНИТЬ", Callable(self, "_respond_to_diplomacy_offer").bind(offer_id, false))
		_kingdoms_list.add_child(HSeparator.new())
	var player_identity := Label.new()
	player_identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	player_identity.add_theme_font_size_override("font_size", UiThemeScript.font_size(14))
	player_identity.add_theme_color_override("font_color", PLAYER_TEAM_COLOR)
	player_identity.text = "ТВОЁ КОРОЛЕВСТВО: %s\n%s" % [str(CampaignState.player_faction.get("kingdom_name", "Наследная держава")), CampaignState.get_player_faction_summary()]
	_kingdoms_list.add_child(player_identity)
	_kingdoms_list.add_child(HSeparator.new())
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
			var faction_line := "Народ и культура неизвестны"
			if capital_known:
				var faction_data: Dictionary = kingdom.get("faction", {})
				var people_data := FactionCatalogScript.get_people(str(faction_data.get("people_id", "")))
				var culture_data := FactionCatalogScript.get_culture(str(faction_data.get("culture_id", "")))
				faction_line = "%s · %s" % [str(people_data.get("name", "Народ")), str(culture_data.get("name", "Культура"))]
			label.text = "%d. %s — %s\n%s\nИзвестных городов: %d · Войск видно: %s\n%s" % [
				index + 1,
				str(kingdom.get("name", "Королевство")),
				str(kingdom.get("ruler", "Правитель")) if capital_known else "Правитель неизвестен",
				faction_line,
				known_city_count,
				army_status,
				latest_intel,
			]
		_kingdoms_list.add_child(label)
		var diplomacy_record := CampaignState.get_diplomacy_record(index)
		if capital_known:
			var relation_value := int(diplomacy_record.get("relation", 0))
			var treaty_value := str(diplomacy_record.get("treaty", "peace"))
			var relationship_label := Label.new()
			relationship_label.text = "%s · отношение %d (%s)" % [DiplomacyCatalogScript.treaty_label(treaty_value), relation_value, DiplomacyCatalogScript.relation_label(relation_value)]
			relationship_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(12))
			_kingdoms_list.add_child(relationship_label)
		var diplomacy_button := _add_button(_kingdoms_list, "ДИПЛОМАТИЯ", Callable(self, "_open_diplomacy_panel").bind(index))
		diplomacy_button.disabled = not capital_known or not bool(kingdom.get("alive", true))
		_kingdoms_list.add_child(HSeparator.new())


func _open_diplomacy_panel(kingdom_id: int) -> void:
	if kingdom_id < 0 or kingdom_id >= CampaignState.kingdoms.size() or not is_instance_valid(_diplomacy_panel):
		return
	_diplomacy_selected_kingdom_id = kingdom_id
	if is_instance_valid(_kingdoms_panel):
		_kingdoms_panel.visible = false
	_refresh_diplomacy_panel()
	_diplomacy_panel.visible = true


func _close_diplomacy_panel() -> void:
	if is_instance_valid(_diplomacy_panel):
		_diplomacy_panel.visible = false
	if is_instance_valid(_kingdoms_panel):
		_refresh_kingdoms_panel()
		_kingdoms_panel.visible = true


func _refresh_diplomacy_panel() -> void:
	if not is_instance_valid(_diplomacy_panel) or not is_instance_valid(_diplomacy_summary_label) or not is_instance_valid(_diplomacy_actions_list):
		return
	var kingdom_id := _diplomacy_selected_kingdom_id
	if kingdom_id < 0 or kingdom_id >= CampaignState.kingdoms.size():
		return
	var kingdom: Dictionary = CampaignState.kingdoms[kingdom_id]
	var record := CampaignState.get_diplomacy_record(kingdom_id)
	var relation_value := int(record.get("relation", 0))
	var treaty_value := str(record.get("treaty", "peace"))
	var personality := DiplomacyCatalogScript.get_personality(kingdom_id)
	var army_count := int(kingdom.get("army", []).size())
	var until_turn := int(record.get("treaty_until", 0))
	var duration_text := ""
	if until_turn > 0:
		duration_text = "\nДо окончания договора: %d ход(а/ов)." % maxi(0, until_turn - CampaignState.turn_number)
	var war_text := "\nУсталость от войны: %d/100." % int(record.get("war_exhaustion", 0)) if treaty_value == "war" else ""
	var war_reason := str(record.get("war_reason", "none"))
	var war_reason_text := ""
	if treaty_value == "war":
		match war_reason:
			"player_declaration": war_reason_text = "\nПовод: объявление войны игроком."
			"battle_provocation": war_reason_text = "\nПовод: нападение на армию в мирное время."
			"border_tension": war_reason_text = "\nПовод: пограничная напряжённость."
	var overlord_text := ""
	if treaty_value == "tribute" or treaty_value == "vassal":
		overlord_text = "\nПолучатель выплат: %s." % ("твоё королевство" if int(record.get("overlord_id", -99)) == -1 else "другая держава")
	_diplomacy_summary_label.text = "%s · %s\nХарактер: %s\n%s\nОтношение: %d — %s\nДоговор: %s%s%s%s%s\nАрмия по последним сведениям: %d бойцов" % [
		str(kingdom.get("name", "Королевство")),
		str(kingdom.get("ruler", "Правитель")),
		str(personality.get("name", "Неизвестен")),
		str(personality.get("description", "")),
		relation_value,
		DiplomacyCatalogScript.relation_label(relation_value),
		DiplomacyCatalogScript.treaty_label(treaty_value),
		duration_text,
		war_text,
		war_reason_text,
		overlord_text,
		army_count,
	]
	for child in _diplomacy_actions_list.get_children():
		child.queue_free()
	var action_options := [
		{"id": "offer_trade", "label": "ПРЕДЛОЖИТЬ ТОРГОВЛЮ"},
		{"id": "offer_alliance", "label": "ПРЕДЛОЖИТЬ СОЮЗ"},
		{"id": "offer_peace", "label": "ПРЕДЛОЖИТЬ МИР"},
		{"id": "demand_tribute", "label": "ПОТРЕБОВАТЬ ДАНЬ"},
		{"id": "demand_vassalage", "label": "ПОТРЕБОВАТЬ ВАССАЛИТЕТ"},
		{"id": "declare_war", "label": "ОБЪЯВИТЬ ВОЙНУ"},
	]
	for action_value in action_options:
		var action_id := str(action_value.get("id", ""))
		var preview := CampaignState.get_diplomacy_action_preview(kingdom_id, action_id)
		var chance_text := "" if action_id == "declare_war" else " · шанс %d%%" % int(preview.get("chance", 0))
		var action_button := _add_button(
			_diplomacy_actions_list,
			str(action_value.get("label", "ДЕЙСТВИЕ")) + chance_text,
			Callable(self, "_perform_diplomacy_action").bind(action_id, kingdom_id)
		)
		action_button.disabled = not bool(preview.get("available", false)) or CampaignState.campaign_lost
		var reason_label := Label.new()
		reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		reason_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(11))
		reason_label.text = str(preview.get("reason", ""))
		_diplomacy_actions_list.add_child(action_button)
		_diplomacy_actions_list.add_child(reason_label)


func _perform_diplomacy_action(action_id: String, kingdom_id: int) -> void:
	var result := CampaignState.perform_diplomacy_action(action_id, kingdom_id)
	_message_text = str(result.get("message", "Дипломатическое действие не удалось."))
	_refresh_diplomacy_panel()
	_refresh_kingdoms_panel()
	_refresh_ui()
	queue_redraw()
	if bool(result.get("ok", false)):
		Haptics.confirm(12)
		if is_instance_valid(_toast_manager):
			_toast_manager.show_toast(_message_text, 3.0, "⚖")
	else:
		Haptics.warn()


func _respond_to_diplomacy_offer(offer_id: String, accept: bool) -> void:
	var result := CampaignState.respond_to_diplomacy_offer(offer_id, accept)
	_message_text = str(result.get("message", "Предложение не обработано."))
	_refresh_kingdoms_panel()
	_refresh_diplomacy_panel()
	_refresh_ui()
	if bool(result.get("ok", false)):
		Haptics.confirm(12)


func _open_kingdoms_panel() -> void:
	if is_instance_valid(_diplomacy_panel):
		_diplomacy_panel.visible = false
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
	if is_instance_valid(_diplomacy_panel):
		_diplomacy_panel.visible = false


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

	var city_resources := HBoxContainer.new()
	city_resources.add_theme_constant_override("separation", int(UiMetrics.dp(12.0)))
	details.add_child(city_resources)
	_city_resource_labels["gold"] = _add_icon_value(city_resources, GameIconCatalogScript.resource_icon("gold"), 14)
	_city_resource_labels["food"] = _add_icon_value(city_resources, GameIconCatalogScript.resource_icon("food"), 14)
	_city_resource_labels["production"] = _add_icon_value(city_resources, GameIconCatalogScript.resource_icon("production"), 14)

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
		_set_button_icon(building_button, GameIconCatalogScript.building_icon(building_id))
		building_button.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(76.0))
		building_button.add_theme_font_size_override("font_size", UiThemeScript.font_size(13))
		_city_building_buttons[building_id] = building_button

	var development_title := Label.new()
	development_title.text = "РАЗВИТИЕ ГОРОДА И СПЕЦИАЛИЗАЦИЯ"
	development_title.add_theme_font_size_override("font_size", UiThemeScript.font_size(16))
	development_title.add_theme_color_override("font_color", Palette.UI_TEXT_HERO)
	details.add_child(development_title)
	_city_development_label = Label.new()
	_city_development_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_city_development_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(13))
	_city_development_label.add_theme_color_override("font_color", Palette.UI_TEXT_BODY)
	details.add_child(_city_development_label)
	var specialization_grid := GridContainer.new()
	specialization_grid.columns = 2
	specialization_grid.add_theme_constant_override("h_separation", 8)
	specialization_grid.add_theme_constant_override("v_separation", 6)
	details.add_child(specialization_grid)
	for specialization_id in ["agriculture", "commerce", "industry", "military"]:
		var spec_data: Dictionary = CityDevelopmentCatalogScript.SPECIALIZATIONS[specialization_id]
		var spec_button := _add_button(specialization_grid, "%s\n%s" % [str(spec_data.get("name", "Специализация")), str(spec_data.get("description", ""))], _choose_city_specialization.bind(specialization_id))
		spec_button.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(64.0))
		spec_button.add_theme_font_size_override("font_size", UiThemeScript.font_size(12))
		_city_specialization_buttons[specialization_id] = spec_button
	var province_title := Label.new()
	province_title.text = "ПРОВИНЦИЯ"
	province_title.add_theme_font_size_override("font_size", UiThemeScript.font_size(16))
	province_title.add_theme_color_override("font_color", Palette.UI_TEXT_BUILDING)
	details.add_child(province_title)
	var province_grid := GridContainer.new()
	province_grid.columns = 2
	province_grid.add_theme_constant_override("h_separation", 8)
	province_grid.add_theme_constant_override("v_separation", 6)
	details.add_child(province_grid)
	for improvement_id in CityDevelopmentCatalogScript.IMPROVEMENT_ORDER:
		var improvement_data: Dictionary = CityDevelopmentCatalogScript.get_improvement_data(improvement_id)
		var province_button := _add_button(province_grid, "%s\n%d зол. · %d пр.\n%s" % [str(improvement_data.get("name", "Улучшение")), int(improvement_data.get("gold_cost", 0)), int(improvement_data.get("production_cost", 0)), str(improvement_data.get("description", ""))], _build_province_improvement.bind(improvement_id))
		province_button.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(68.0))
		province_button.add_theme_font_size_override("font_size", UiThemeScript.font_size(12))
		_city_province_buttons[improvement_id] = province_button
	var building_upgrade_title := Label.new()
	building_upgrade_title.text = "УЛУЧШЕНИЕ ЗДАНИЙ"
	building_upgrade_title.add_theme_font_size_override("font_size", UiThemeScript.font_size(16))
	building_upgrade_title.add_theme_color_override("font_color", Palette.UI_TEXT_BUILDING)
	details.add_child(building_upgrade_title)
	var building_upgrade_grid := GridContainer.new()
	building_upgrade_grid.columns = 2
	building_upgrade_grid.add_theme_constant_override("h_separation", 8)
	building_upgrade_grid.add_theme_constant_override("v_separation", 6)
	details.add_child(building_upgrade_grid)
	for building_id in ["farm", "market", "workshop", "barracks", "archery_range", "stable"]:
		var building_data: Dictionary = CampaignState.get_city_building_data(building_id)
		var building_upgrade_button := _add_button(building_upgrade_grid, str(building_data.get("name", "Здание")) + "\nУЛУЧШИТЬ", _upgrade_city_building.bind(building_id))
		building_upgrade_button.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(64.0))
		building_upgrade_button.add_theme_font_size_override("font_size", UiThemeScript.font_size(12))
		_city_building_upgrade_buttons[building_id] = building_upgrade_button
	_city_upkeep_label = Label.new()
	_city_upkeep_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_city_upkeep_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(13))
	_city_upkeep_label.add_theme_color_override("font_color", Palette.UI_TEXT_INCOME)
	details.add_child(_city_upkeep_label)

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
		_set_button_icon(recruit_button, GameIconCatalogScript.unit_icon(str(role_id)))
		recruit_button.custom_minimum_size = Vector2(UiMetrics.dp(0.0), UiMetrics.dp(58.0))
		recruit_button.add_theme_font_size_override("font_size", UiThemeScript.font_size(13))
		_city_recruit_buttons[role_id] = recruit_button

	var training_title := Label.new()
	training_title.text = "ВОЕННАЯ ПОДГОТОВКА"
	training_title.add_theme_font_size_override("font_size", UiThemeScript.font_size(16))
	training_title.add_theme_color_override("font_color", Palette.UI_TEXT_HERO)
	details.add_child(training_title)
	var training_grid := GridContainer.new()
	training_grid.columns = 2
	training_grid.add_theme_constant_override("h_separation", 8)
	training_grid.add_theme_constant_override("v_separation", 6)
	details.add_child(training_grid)
	for role_id in [CampaignState.ROLE_MELEE, CampaignState.ROLE_RANGED, CampaignState.ROLE_SPEAR, CampaignState.ROLE_CAVALRY]:
		var recruit_data: Dictionary = CampaignState.get_recruit_data(role_id)
		var upgrade_button := _add_button(
			training_grid,
			str(recruit_data.get("name", "Отряд")) + "\nУЛУЧШЕНИЕ",
			_purchase_army_upgrade.bind(role_id)
		)
		_set_button_icon(upgrade_button, GameIconCatalogScript.unit_icon(str(role_id)))
		upgrade_button.custom_minimum_size = Vector2(UiMetrics.dp(0.0), UiMetrics.dp(72.0))
		upgrade_button.add_theme_font_size_override("font_size", UiThemeScript.font_size(12))
		_city_upgrade_buttons[role_id] = upgrade_button
	var training_hint := Label.new()
	training_hint.text = "Покупка оплачивается золотом один раз и усиливает все войска выбранной роли — нынешние и будущие. Новый ранг применяется со следующего боя."
	training_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	training_hint.add_theme_font_size_override("font_size", UiThemeScript.font_size(12))
	training_hint.add_theme_color_override("font_color", Palette.UI_TEXT_HINT)
	details.add_child(training_hint)

	_settler_button = _add_button(details, "ПОСТРОИТЬ ПОСЕЛЕНЦА · 45 зол. · 10 пр.", _queue_settler)
	_set_button_icon(_settler_button, GameIconCatalogScript.unit_icon("settler"))
	_settler_button.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(56.0))
	_settler_button.add_theme_font_size_override("font_size", UiThemeScript.font_size(13))

	var hint := Label.new()
	hint.text = "Золото оплачивает заказы сразу, производство — по завершении. Уровень города растёт при населении 8 и 14; специализация открывается на уровне 2. Провинции улучшаются на подходящих соседних гексах. Содержание армии списывается из казны всех городов."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", UiThemeScript.font_size(12))
	hint.add_theme_color_override("font_color", Palette.UI_TEXT_HINT)
	details.add_child(hint)
	_refresh_city_panel()


func _choose_city_specialization(specialization_id: String) -> void:
	if CampaignState.choose_city_specialization(specialization_id):
		var data: Dictionary = CityDevelopmentCatalogScript.SPECIALIZATIONS.get(specialization_id, {})
		_message_text = "Город выбрал специализацию: %s." % str(data.get("name", specialization_id))
	else:
		_message_text = "Специализация открывается на 2-м уровне города и выбирается один раз."
	_refresh_city_panel()
	_refresh_ui()


func _build_province_improvement(improvement_id: String) -> void:
	if CampaignState.queue_province_improvement(improvement_id):
		var data: Dictionary = CityDevelopmentCatalogScript.get_improvement_data(improvement_id)
		_message_text = "%s добавлено в очередь провинции." % str(data.get("name", "Улучшение"))
	else:
		_message_text = "Нет подходящей свободной клетки, места в провинции или золота."
	_refresh_city_panel()
	_refresh_ui()


func _upgrade_city_building(building_id: String) -> void:
	if CampaignState.queue_city_building_upgrade(building_id):
		_message_text = "Улучшение здания добавлено в очередь."
	else:
		_message_text = "Для улучшения нужен уровень города и свободная очередь."
	_refresh_city_panel()
	_refresh_ui()


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


func _purchase_army_upgrade(role_id: String) -> void:
	if CampaignState.purchase_army_upgrade(role_id):
		_message_text = "Вооружение армии улучшено. Новый ранг действует на всех бойцов этой роли."
		Haptics.confirm(35)
	else:
		_message_text = "Улучшение недоступно: проверь здание, золото и максимальный ранг."
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
	_city_overview_label.text = "%s · %s\nКоролевство: %s · %s\nУровень %d · население: %d · армия: %d/%d\nСостав: %s\nОпыт: %s" % [
		CampaignState.city_name,
		CampaignState.get_city_level_name(),
		str(CampaignState.player_faction.get("kingdom_name", "Наследная держава")),
		CampaignState.get_player_faction_summary(),
		CampaignState.get_city_level(),
		CampaignState.city_population,
		CampaignState.player_units.size(),
		CampaignState.ARMY_CAPACITY,
		_get_army_composition_text(),
		CampaignState.get_army_veterancy_summary(),
	]
	if _city_resource_labels.has("gold"):
		_city_resource_labels["gold"].text = str(CampaignState.city_gold)
		_city_resource_labels["food"].text = str(CampaignState.city_food)
		_city_resource_labels["production"].text = str(CampaignState.city_production_bank)
	_city_income_label.text = "Доход за ход: +%d еды · +%d золота · +%d производства" % [
		int(income["food"]),
		int(income["gold"]),
		int(income["production"]),
	]
	if is_instance_valid(_city_development_label):
		var spec_name := "Не выбрана"
		if CityDevelopmentCatalogScript.SPECIALIZATIONS.has(CampaignState.city_specialization):
			spec_name = str(CityDevelopmentCatalogScript.SPECIALIZATIONS[CampaignState.city_specialization].get("name", "Не выбрана"))
		_city_development_label.text = "Специализация: %s\nПровинциальных участков: %d/%d · улучшения зданий доступны с уровня города 2/3." % [spec_name, CampaignState.city_province_improvements.size(), CampaignState.get_city_province_slots()]
	for specialization_id in _city_specialization_buttons:
		var button: Button = _city_specialization_buttons[specialization_id]
		var spec_data: Dictionary = CityDevelopmentCatalogScript.SPECIALIZATIONS[specialization_id]
		if CampaignState.city_specialization == specialization_id:
			button.text = "%s\nВЫБРАНО" % str(spec_data.get("name", specialization_id))
			button.disabled = true
		else:
			button.text = "%s\n%s" % [str(spec_data.get("name", specialization_id)), str(spec_data.get("description", ""))]
			button.disabled = not CampaignState.can_choose_city_specialization(specialization_id)
	for improvement_id in _city_province_buttons:
		var button: Button = _city_province_buttons[improvement_id]
		var data: Dictionary = CityDevelopmentCatalogScript.get_improvement_data(str(improvement_id))
		var cell := CampaignState.get_next_province_cell(str(improvement_id))
		button.text = "%s\n%d зол. · %d пр.\n%s" % [str(data.get("name", "Улучшение")), int(data.get("gold_cost", 0)), int(data.get("production_cost", 0)), str(data.get("description", ""))]
		button.disabled = not CampaignState.can_queue_province_improvement(str(improvement_id))
		if cell != Vector2i(9999, 9999):
			button.tooltip_text = "Будет построено на гексе %d:%d" % [cell.x, cell.y]
		else:
			button.tooltip_text = "Нет подходящего свободного гекса"
	for building_id in _city_building_upgrade_buttons:
		var button: Button = _city_building_upgrade_buttons[building_id]
		var building_data: Dictionary = CampaignState.get_city_building_data(str(building_id))
		var current_level := CampaignState.get_city_building_level(str(building_id))
		var upgrade_data := CampaignState.get_next_city_building_upgrade_data(str(building_id))
		if current_level <= 0:
			button.text = "%s\nНЕ ПОСТРОЕНО" % str(building_data.get("name", building_id)).to_upper()
			button.disabled = true
		elif upgrade_data.is_empty():
			button.text = "%s\nМАКС. УРОВЕНЬ %d" % [str(building_data.get("name", building_id)).to_upper(), current_level]
			button.disabled = true
		else:
			var target_level := current_level + 1
			button.text = "%s · %d→%d\n%d зол. · %d пр.\n%s" % [str(building_data.get("name", building_id)).to_upper(), current_level, target_level, int(upgrade_data.get("gold_cost", 0)), int(upgrade_data.get("production_cost", 0)), str(upgrade_data.get("description", ""))]
			button.disabled = not CampaignState.can_queue_city_building_upgrade(str(building_id))
	if is_instance_valid(_city_upkeep_label):
		_city_upkeep_label.text = CampaignState.get_army_upkeep_summary()
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

	for role_id in _city_upgrade_buttons:
		var role_name := str(role_id)
		var upgrade_button: Button = _city_upgrade_buttons[role_name]
		var role_data: Dictionary = CampaignState.get_recruit_data(role_name)
		var upgrade_data: Dictionary = CampaignState.get_next_army_upgrade_data(role_name)
		var current_rank := CampaignState.get_army_upgrade_rank(role_name)
		if upgrade_data.is_empty():
			upgrade_button.text = "%s\nУЛУЧШЕНИЕ 2/2\nМАКСИМУМ" % str(role_data.get("name", role_name)).to_upper()
			upgrade_button.disabled = true
			continue
		var building_id := str(upgrade_data.get("building_id", "barracks"))
		if not CampaignState.city_has_building(building_id):
			upgrade_button.text = "%s\nРАНГ %d/2\nНУЖНО: %s" % [
				str(role_data.get("name", role_name)).to_upper(),
				current_rank,
				str(upgrade_data.get("building_name", "Казармы")).to_upper(),
			]
		else:
			upgrade_button.text = "%s · %d→%d\n%d ЗОЛ.\n%s" % [
				str(role_data.get("name", role_name)).to_upper(),
				current_rank,
				current_rank + 1,
				int(upgrade_data.get("gold_cost", 0)),
				str(upgrade_data.get("description", "")),
			]
		upgrade_button.disabled = not CampaignState.can_purchase_army_upgrade(role_name)


func _get_army_composition_text() -> String:
	var counts := {"melee": 0, "ranged": 0, "spear": 0, "cavalry": 0}
	for record in CampaignState.player_units:
		var role_id := str(record.get("role", "melee"))
		if counts.has(role_id):
			counts[role_id] = int(counts[role_id]) + 1
	return "мечники %d · лучники %d · копейщики %d · кавалерия %d" % [
		counts["melee"], counts["ranged"], counts["spear"], counts["cavalry"],
	]



func _add_icon_value(parent: Container, icon_texture: Texture2D, font_size: int = 12) -> Label:
	var stat := HBoxContainer.new()
	stat.add_theme_constant_override("separation", int(UiMetrics.dp(4.0)))
	stat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_rect := TextureRect.new()
	icon_rect.texture = icon_texture
	icon_rect.custom_minimum_size = Vector2(UiMetrics.dp(20.0), UiMetrics.dp(20.0))
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stat.add_child(icon_rect)
	var value_label := Label.new()
	value_label.text = "0"
	value_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(font_size))
	value_label.add_theme_color_override("font_color", Palette.UI_TEXT_PURE)
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stat.add_child(value_label)
	parent.add_child(stat)
	return value_label


func _set_button_icon(button: Button, icon_texture: Texture2D) -> void:
	if not is_instance_valid(button) or icon_texture == null:
		return
	button.icon = icon_texture
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", int(UiMetrics.dp(28.0)))
	button.expand_icon = false
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _add_button(parent: Container, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(48.0))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", UiThemeScript.font_size(14))
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
	if is_instance_valid(_faction_setup_panel) and _faction_setup_panel.visible:
		return
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
	if str(CampaignState.campaign_victory.get("status", "none")) == "claimed":
		return
	if CampaignState.faction_setup_pending or CampaignState.battle_in_progress:
		return
	var cell := _screen_to_cell(screen_position)
	if cell == Vector2i(9999, 9999):
		return
	if not CampaignState.is_cell_explored(cell):
		_message_text = "Эта область скрыта туманом войны. Сначала подведи туда армию или поселенца."
		_refresh_ui()
		return

	var location_index := CampaignState.get_neutral_location_index_at(cell, false)
	if location_index >= 0:
		var location: Dictionary = CampaignState.neutral_locations[location_index]
		var location_id := str(location.get("id", ""))
		var location_name := WorldLocationCatalogScript.get_display_name(str(location.get("type", "ancient_ruins")))
		var distance := _hex_distance(CampaignState.player_cell, cell)
		if distance <= 1:
			if CampaignState.begin_location_battle(location_id):
				get_tree().change_scene_to_file("res://scenes/combat_test.tscn")
				return
			_message_text = "%s: охрана не может быть атакована сейчас." % location_name
		else:
			_message_text = "%s: локация в %d гексах. Подойди ближе, чтобы атаковать охрану." % [location_name, distance]
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
	else:
		var diplomacy_record := CampaignState.get_diplomacy_record(kingdom_id)
		if str(diplomacy_record.get("treaty", "peace")) == "vassal":
			_message_text = "Нельзя атаковать вассала, пока действует договор верховенства."
		elif CampaignState.turn_number < int(diplomacy_record.get("truce_until", 0)):
			_message_text = "Перемирие ещё действует. Сначала дождись его окончания."
		else:
			_message_text = "Сражение не удалось начать: проверь наличие армии и состояние кампании."
		_refresh_ui()


func _advance_turn() -> void:
	if CampaignState.campaign_lost or CampaignState.battle_in_progress or str(CampaignState.campaign_victory.get("status", "none")) == "claimed":
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
		var relation_record := CampaignState.get_diplomacy_record(index)
		if str(relation_record.get("treaty", "peace")) != "war":
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
	if not CampaignState.last_diplomacy_events.is_empty():
		_message_text += " " + CampaignState.last_diplomacy_events[0]
	if not CampaignState.pending_diplomacy_offers.is_empty():
		_message_text += " Новое дипломатическое послание — открой «Королевства»."
	if not CampaignState.last_kingdom_events.is_empty():
		_message_text += " " + CampaignState.last_kingdom_events[0]
	if not CampaignState.city_last_event.is_empty():
		_message_text += " Город: " + CampaignState.city_last_event
	_refresh_city_panel()
	if is_instance_valid(_kingdoms_panel) and _kingdoms_panel.visible:
		_refresh_kingdoms_panel()
	if is_instance_valid(_diplomacy_panel) and _diplomacy_panel.visible:
		_refresh_diplomacy_panel()
	_refresh_world_event_panel()
	if not CampaignState.pending_world_event.is_empty():
		_message_text = "Событие мира: " + str(CampaignState.pending_world_event.get("title", "Новые вести"))
	_refresh_ui()
	queue_redraw()


func _restart_campaign() -> void:
	if is_instance_valid(_restart_confirm_dialog):
		_restart_confirm_dialog.open()
		Haptics.warn()


func _perform_restart_campaign() -> void:
	_close_city()
	CampaignState.prepare_new_campaign(false)
	if is_instance_valid(_hex_tileset_renderer):
		_hex_tileset_renderer.invalidate_world()
	_army_selected = false
	_settler_selected = false
	_message_text = "Выбери народ, культуру и черты нового королевства."
	_build_map()
	_refresh_ui()
	_open_faction_setup_panel()
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
		if str(result.get("target_type", "kingdom")) == "location":
			_message_text = "%s очищено! Выживших: %d. Потери: %d. %s" % [str(result.get("kingdom_name", "Место")), survivors, losses, str(result.get("location_reward", "Награда получена."))]
		else:
			_message_text = "Победа! Выживших: %d. Потери: %d. Командир получил %d опыта (ур. %d). Вражеский лагерь захвачен." % [survivors, losses, hero_xp_gained, hero_level]
	else:
		if str(result.get("target_type", "kingdom")) == "location":
			_message_text = "Охрана удержала %s. Выживших: %d. Потери: %d. Можно перегруппироваться и вернуться." % [str(result.get("kingdom_name", "локацию")), survivors, losses]
		else:
			_message_text = "Поражение. Выживших: %d. Потери: %d. Армия отступила к исходной позиции." % [survivors, losses]
	CampaignState.last_battle_report_pending = false
	CampaignState.save_campaign()


func _refresh_ui() -> void:
	if not is_instance_valid(_status_label):
		return
	_status_label.text = "ХОД %d · ДЕРЖАВ: %d · ВОЙСК ВИДНО: %d" % [
		CampaignState.turn_number,
		CampaignState.kingdoms.size(),
		_get_visible_enemy_unit_count(),
	]
	if _hud_resource_labels.has("gold"):
		_hud_resource_labels["gold"].text = str(CampaignState.city_gold)
		_hud_resource_labels["food"].text = str(CampaignState.city_food)
		_hud_resource_labels["production"].text = str(CampaignState.city_production_bank)
	_message_label.text = _message_text
	if is_instance_valid(_attack_button):
		var selected_kingdom_valid := _selected_kingdom_id >= 0 and _selected_kingdom_id < CampaignState.kingdoms.size()
		var selected_army_cell := WorldGeneratorScript.array_to_cell(CampaignState.kingdoms[_selected_kingdom_id].get("army_cell", [])) if selected_kingdom_valid else CampaignState.enemy_cell
		_attack_button.disabled = not selected_kingdom_valid or _hex_distance(CampaignState.player_cell, selected_army_cell) > 1 or CampaignState.player_units.is_empty() or str(CampaignState.campaign_victory.get("status", "none")) == "claimed"
	var campaign_finished := str(CampaignState.campaign_victory.get("status", "none")) == "claimed"
	if is_instance_valid(_turn_button):
		_turn_button.disabled = CampaignState.campaign_lost or campaign_finished
	if is_instance_valid(_selection_button):
		_selection_button.disabled = CampaignState.campaign_lost or campaign_finished
	if is_instance_valid(_city_button):
		_city_button.disabled = CampaignState.cities.is_empty() or CampaignState.campaign_lost or campaign_finished
	if is_instance_valid(_found_city_button):
		_found_city_button.disabled = campaign_finished or not CampaignState.settler_active or not CampaignState.can_found_city(CampaignState.settler_cell) or not _is_traversable(CampaignState.settler_cell)
	if is_instance_valid(_city_panel) and _city_panel.visible:
		_refresh_city_panel()
	if is_instance_valid(_kingdoms_panel) and _kingdoms_panel.visible:
		_refresh_kingdoms_panel()
	_refresh_world_event_panel()
	_refresh_campaign_victory_panel()
	if str(CampaignState.campaign_victory.get("status", "none")) == "offered" and not _victory_prompt_shown:
		_victory_prompt_shown = true
		_open_campaign_victory_panel()


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