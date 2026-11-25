extends Node3D

const Palette = preload("res://scripts/art_palette.gd")

const UiThemeScript = preload("res://scripts/ui_theme.gd")
const SettingsPanelScript = preload("res://scripts/settings_panel.gd")
const PerfOverlayScript = preload("res://scripts/perf_overlay.gd")
const CombatEffectsScript = preload("res://scripts/combat_effects.gd")
const SafeAreaContainerScript = preload("res://scripts/safe_area_container.gd")
const TouchGestureRouterScript = preload("res://scripts/touch_gesture_router.gd")
const ToastManagerScript = preload("res://scripts/toast_manager.gd")

const BattlefieldVisualsScript = preload("res://scripts/battlefield_visuals.gd")

const FIELD_SIZE := Vector2(38.0, 26.0)
const PLAYER_TEAM := 0
const ENEMY_TEAM := 1
const FALLBACK_UNITS_PER_TEAM := 5
const SPEED_VALUES = [1.0, 1.5, 2.0]
const SPEED_LABELS = ["1x", "1.5x", "2x"]

enum FormationMode {
	LINE,
	COLUMN,
	WEDGE,
}

var _camera: Camera3D
var _ground_body: StaticBody3D
var _battlefield_biome_name: String = "Равнина"
var _selected_units: Array[BattleUnit] = []
var _attack_move_enabled: bool = false
var _additive_selection: bool = false
var _game_over: bool = false
var _paused: bool = false
var _battle_time: float = 0.0
var _ui_refresh_timer: float = 0.0
var _speed_index: int = 0
var _status_label: Label
var _help_label: Label
var _mode_button: Button
var _add_button: Button
var _formation_button: Button
var _pause_button: Button
var _speed_button: Button
var _result_panel: PanelContainer
var _settings_panel: SettingsPanel
var _result_title: Label
var _result_details: Label
var _formation_mode: FormationMode = FormationMode.LINE
var _focused_target: BattleUnit
var _eliminated_kills: Array[int] = [0, 0]
var _eliminated_damage: Array[float] = [0.0, 0.0]
var _combat_buttons: Array[Button] = []
var _initial_team_counts: Array[int] = [FALLBACK_UNITS_PER_TEAM, FALLBACK_UNITS_PER_TEAM]
var _selection_dragging: bool = false
var _selection_start: Vector2 = Vector2.ZERO
var _selection_end: Vector2 = Vector2.ZERO
var _selection_marquee: Panel
var _camera_dragging: bool = false
var _control_groups: Dictionary = {}
var _control_group_buttons: Dictionary = {}
var _group_store_mode: bool = false
var _group_store_button: Button
var _rally_button: Button
var _safe_area: SafeAreaContainer
var _gesture_router: TouchGestureRouter
var _toast_manager: ToastManager
var _commands_panel: PanelContainer
var _commands_button: Button


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	get_tree().paused = false
	Engine.time_scale = 1.0
	_create_environment()
	var combat_effects := CombatEffectsScript.new()
	combat_effects.name = "CombatEffects"
	add_child(combat_effects)
	_spawn_armies()
	_create_ui()
	add_child(PerfOverlayScript.new())
	_refresh_ui()


func _process(delta: float) -> void:
	if _game_over or _paused:
		return
	_battle_time += delta
	_ui_refresh_timer += delta
	if _ui_refresh_timer >= 0.5:
		_ui_refresh_timer = 0.0
		_refresh_ui()


func _create_environment() -> void:
	var biome_id := CampaignState.battlefield_biome_id if CampaignState.battle_in_progress else "grassland"
	var biome_seed := CampaignState.battlefield_seed if CampaignState.battle_in_progress else 841207
	var visual_data: Dictionary = BattlefieldVisualsScript.create(
		self,
		FIELD_SIZE,
		GameSettings.graphics_quality,
		biome_id,
		biome_seed
	)
	_ground_body = visual_data.get("ground_body") as StaticBody3D
	_camera = visual_data.get("camera") as Camera3D
	_battlefield_biome_name = str(visual_data.get("biome_name", "Равнина"))



func _spawn_armies() -> void:
	if CampaignState.battle_in_progress:
		_spawn_army_from_records(PLAYER_TEAM, CampaignState.player_units)
		_spawn_army_from_records(ENEMY_TEAM, CampaignState.enemy_units)
	else:
		# Fallback keeps CombatTest usable as an isolated development scene.
		for offset in [-2.2, 0.0, 2.2]:
			_spawn_unit(PLAYER_TEAM, Vector3(-8.0, 0.0, offset), BattleUnit.UnitRole.MELEE)
			_spawn_unit(ENEMY_TEAM, Vector3(8.0, 0.0, offset), BattleUnit.UnitRole.MELEE)
		for offset in [-1.6, 1.6]:
			_spawn_unit(PLAYER_TEAM, Vector3(-12.5, 0.0, offset), BattleUnit.UnitRole.RANGED)
			_spawn_unit(ENEMY_TEAM, Vector3(12.5, 0.0, offset), BattleUnit.UnitRole.RANGED)

	_spawn_commander(PLAYER_TEAM, CampaignState.player_hero, Vector3(-10.0, 0.0, 0.0))
	_spawn_commander(ENEMY_TEAM, CampaignState.enemy_hero, Vector3(10.0, 0.0, 0.0))
	_initial_team_counts = [_count_team(PLAYER_TEAM), _count_team(ENEMY_TEAM)]


func _spawn_army_from_records(team: int, records: Array[Dictionary]) -> void:
	var role_counts: Dictionary = {}
	var role_indices: Dictionary = {}
	for role_id in [CampaignState.ROLE_MELEE, CampaignState.ROLE_RANGED, CampaignState.ROLE_SPEAR, CampaignState.ROLE_CAVALRY]:
		role_counts[role_id] = 0
		role_indices[role_id] = 0
	for record in records:
		var role_id := str(record.get("role", CampaignState.ROLE_MELEE))
		if role_counts.has(role_id):
			role_counts[role_id] = int(role_counts[role_id]) + 1

	var side_x := -8.0 if team == PLAYER_TEAM else 8.0
	for record in records:
		var role_name := str(record.get("role", CampaignState.ROLE_MELEE))
		var role := _battle_role_from_id(role_name)
		var count := maxi(1, int(role_counts.get(role_name, 1)))
		var index := int(role_indices.get(role_name, 0))
		role_indices[role_name] = index + 1
		var spacing := 2.2
		var row_x := side_x
		match role:
			BattleUnit.UnitRole.RANGED:
				spacing = 3.0
				row_x = side_x * 1.52
			BattleUnit.UnitRole.SPEAR:
				spacing = 2.1
				row_x = side_x * 0.78
			BattleUnit.UnitRole.CAVALRY:
				spacing = 3.2
				row_x = side_x * 1.22
		var safe_spacing := minf(spacing, 18.0 / float(maxi(count - 1, 1)))
		var lateral_offset := (float(index) - float(count - 1) * 0.5) * safe_spacing
		var spawn_position := Vector3(row_x, 0.0, lateral_offset)
		_spawn_unit(team, spawn_position, role, float(record.get("health", -1.0)))


func _battle_role_from_id(role_name: String) -> int:
	match role_name:
		CampaignState.ROLE_RANGED:
			return BattleUnit.UnitRole.RANGED
		CampaignState.ROLE_SPEAR:
			return BattleUnit.UnitRole.SPEAR
		CampaignState.ROLE_CAVALRY:
			return BattleUnit.UnitRole.CAVALRY
	return BattleUnit.UnitRole.MELEE


func _spawn_commander(team: int, hero_record: Dictionary, spawn_position: Vector3) -> void:
	var unit := BattleUnit.new()
	unit.team = team
	unit.role = BattleUnit.UnitRole.COMMANDER
	unit.commander_level = clampi(int(hero_record.get("level", 1)), 1, 30)
	var skills_value: Variant = hero_record.get("skills", {})
	var skills: Dictionary = skills_value if skills_value is Dictionary else {}
	unit.commander_leadership = clampi(int(skills.get("leadership", 0)), 0, 5)
	unit.commander_tactics = clampi(int(skills.get("tactics", 0)), 0, 5)
	unit.commander_might = clampi(int(skills.get("might", 0)), 0, 5)
	unit.starting_health = float(hero_record.get("health", -1.0))
	unit.position = spawn_position
	unit.eliminated.connect(_on_unit_eliminated)
	add_child(unit)


func _get_commander_health(team: int) -> float:
	for node in get_tree().get_nodes_in_group("battle_units"):
		if node is BattleUnit and not node.is_queued_for_deletion():
			var unit := node as BattleUnit
			if unit.team == team and unit.role == BattleUnit.UnitRole.COMMANDER:
				return maxf(0.0, unit.health)
	return 0.0


func _activate_commander_rally() -> void:
	for node in get_tree().get_nodes_in_group("battle_units"):
		if node is BattleUnit:
			var unit := node as BattleUnit
			if unit.team == PLAYER_TEAM and unit.role == BattleUnit.UnitRole.COMMANDER:
				var activated := unit.activate_rally()
				_refresh_ui()
				if activated:
					Haptics.confirm(40)
					_help_label.text = "БОЕВОЙ КЛИЧ! Ближайшие отряды восстановили силы и получили боевой бонус."
				else:
					_help_label.text = "Боевой клич пока недоступен или рядом нет союзных отрядов."
				return
	_help_label.text = "Командир не участвует в этом сражении."


func _spawn_unit(team: int, spawn_position: Vector3, unit_role: int, unit_health: float = -1.0) -> void:
	var unit := BattleUnit.new()
	unit.team = team
	unit.role = unit_role
	unit.starting_health = unit_health
	unit.position = spawn_position
	unit.eliminated.connect(_on_unit_eliminated)
	add_child(unit)


func _create_ui() -> void:
	var layer := CanvasLayer.new()
	# Keep the command interface responsive while the battle tree is paused.
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	_safe_area = SafeAreaContainerScript.new()
	layer.add_child(_safe_area)
	var root := _safe_area.get_content_root()
	root.theme = UiThemeScript.create_theme(GameSettings.ui_scale)
	_gesture_router = TouchGestureRouterScript.new()
	_gesture_router.name = "TouchGestureRouter"
	_gesture_router.set_ui_root(root)
	root.add_child(_gesture_router)
	_toast_manager = ToastManagerScript.new()
	_toast_manager.name = "ToastManager"
	root.add_child(_toast_manager)
	_create_selection_marquee(root)

	var top_panel := PanelContainer.new()
	top_panel.name = "BattleHudTop"
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

	_help_label = Label.new()
	_help_label.add_theme_font_size_override("font_size", UiThemeScript.font_size(11))
	_help_label.add_theme_color_override("font_color", Palette.UI_TEXT_HELP)
	_help_label.clip_text = true
	_help_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	top_box.add_child(_help_label)

	_commands_panel = PanelContainer.new()
	_commands_panel.name = "BattleCommandsDrawer"
	_commands_panel.anchor_left = 0.0
	_commands_panel.anchor_top = 1.0
	_commands_panel.anchor_right = 1.0
	_commands_panel.anchor_bottom = 1.0
	_commands_panel.offset_left = UiMetrics.dp(8.0)
	_commands_panel.offset_top = -UiMetrics.dp(254.0)
	_commands_panel.offset_right = -UiMetrics.dp(8.0)
	_commands_panel.offset_bottom = -UiMetrics.dp(94.0)
	_commands_panel.visible = false
	root.add_child(_commands_panel)

	var drawer_margin := MarginContainer.new()
	drawer_margin.add_theme_constant_override("margin_left", int(UiMetrics.dp(6.0)))
	drawer_margin.add_theme_constant_override("margin_top", int(UiMetrics.dp(5.0)))
	drawer_margin.add_theme_constant_override("margin_right", int(UiMetrics.dp(6.0)))
	drawer_margin.add_theme_constant_override("margin_bottom", int(UiMetrics.dp(5.0)))
	_commands_panel.add_child(drawer_margin)

	var drawer_scroll := ScrollContainer.new()
	drawer_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drawer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	drawer_margin.add_child(drawer_scroll)

	var drawer_content := VBoxContainer.new()
	drawer_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_content.add_theme_constant_override("separation", int(UiMetrics.dp(5.0)))
	drawer_scroll.add_child(drawer_content)

	var buttons := GridContainer.new()
	buttons.columns = 4
	buttons.add_theme_constant_override("h_separation", int(UiMetrics.dp(5.0)))
	buttons.add_theme_constant_override("v_separation", int(UiMetrics.dp(4.0)))
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_content.add_child(buttons)

	_add_button = _add_action_button(buttons, "ДОБОР: ВЫКЛ", _toggle_additive_selection)
	_add_action_button(buttons, "ДЕРЖАТЬ", _hold_selected_units)
	_add_action_button(buttons, "СТОП", _stop_selected_units)
	_add_action_button(buttons, "СНЯТЬ", _clear_selection_from_button)
	_formation_button = _add_action_button(buttons, "СТРОЙ: ЛИНИЯ", _cycle_formation_mode)
	_add_action_button(buttons, "ОТСТУП", _retreat_selected_units)
	_speed_button = _add_action_button(buttons, "СКОРОСТЬ: 1x", _cycle_speed)
	_add_action_button(buttons, "ЗУМ +", _zoom_in)
	_add_action_button(buttons, "ЗУМ -", _zoom_out)
	_rally_button = _add_action_button(buttons, "БОЕВОЙ КЛИЧ", _activate_commander_rally)
	for child in buttons.get_children():
		if child is Button:
			_combat_buttons.append(child as Button)

	var group_row := HBoxContainer.new()
	group_row.add_theme_constant_override("separation", int(UiMetrics.dp(4.0)))
	drawer_content.add_child(group_row)
	_group_store_button = _add_action_button(group_row, "ЗАПИСЬ", _toggle_group_store_mode)
	_group_store_button.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(48.0))
	for group_id in range(1, 5):
		var group_button := _add_action_button(group_row, "ГР. %d" % group_id, _on_control_group_button.bind(group_id))
		group_button.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(48.0))
		_control_group_buttons[group_id] = group_button
	var settings_button := _add_action_button(group_row, "НАСТРОЙКИ", _open_settings)
	settings_button.custom_minimum_size = Vector2(UiMetrics.dp(100.0), UiThemeScript.touch_target(48.0))

	var bottom_panel := PanelContainer.new()
	bottom_panel.name = "BattleHudQuickDock"
	bottom_panel.anchor_left = 0.0
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_left = UiMetrics.dp(8.0)
	bottom_panel.offset_top = -UiMetrics.dp(86.0)
	bottom_panel.offset_right = -UiMetrics.dp(8.0)
	bottom_panel.offset_bottom = -UiMetrics.dp(8.0)
	root.add_child(bottom_panel)

	var quick_row := HBoxContainer.new()
	quick_row.add_theme_constant_override("separation", int(UiMetrics.dp(5.0)))
	bottom_panel.add_child(quick_row)
	var select_all_button := _add_action_button(quick_row, "ВСЕ", _select_all_player_units)
	_combat_buttons.append(select_all_button)
	_mode_button = _add_action_button(quick_row, "МАРШ", _toggle_order_mode)
	_combat_buttons.append(_mode_button)
	_pause_button = _add_action_button(quick_row, "ПАУЗА", _toggle_pause)
	_combat_buttons.append(_pause_button)
	_commands_button = _add_action_button(quick_row, "КОМАНДЫ", _toggle_commands_panel)
	_create_result_panel(root)
	_settings_panel = SettingsPanelScript.new()
	_settings_panel.pause_game_on_open = true
	root.add_child(_settings_panel)


func _create_result_panel(parent: Control) -> void:
	_result_panel = PanelContainer.new()
	_result_panel.anchor_left = 0.5
	_result_panel.anchor_top = 0.5
	_result_panel.anchor_right = 0.5
	_result_panel.anchor_bottom = 0.5
	_result_panel.offset_left = -UiMetrics.dp(270.0)
	_result_panel.offset_top = -UiMetrics.dp(158.0)
	_result_panel.offset_right = UiMetrics.dp(270.0)
	_result_panel.offset_bottom = UiMetrics.dp(158.0)
	_result_panel.custom_minimum_size = Vector2(UiMetrics.dp(540.0), UiMetrics.dp(316.0))
	_result_panel.visible = false
	parent.add_child(_result_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	_result_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", int(UiMetrics.dp(8)))
	margin.add_child(content)

	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_size_override("font_size", UiThemeScript.font_size(27))
	_result_title.add_theme_color_override("font_color", Palette.UI_RESULT_GOLD)
	content.add_child(_result_title)

	_result_details = Label.new()
	_result_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_details.add_theme_font_size_override("font_size", UiThemeScript.font_size(14))
	_result_details.add_theme_color_override("font_color", Palette.UI_TEXT_BODY)
	content.add_child(_result_details)

	var return_button := _add_action_button(content, "НА СТРАТЕГИЧЕСКУЮ КАРТУ", _return_to_strategy_map)
	return_button.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(56.0))



func _add_action_button(parent: Container, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size = Vector2(0.0, UiThemeScript.touch_target(56.0))
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", UiThemeScript.font_size(16))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _create_selection_marquee(parent: Control) -> void:
	_selection_marquee = Panel.new()
	_selection_marquee.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_marquee.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.UI_SELECTION_FILL
	style.border_color = Palette.UI_SELECTION_BORDER
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	_selection_marquee.add_theme_stylebox_override("panel", style)
	parent.add_child(_selection_marquee)


func _unhandled_input(event: InputEvent) -> void:
	if _game_over or _paused:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_begin_selection_drag(event.position)
			else:
				_finish_selection_drag(event.position, _additive_selection or Input.is_key_pressed(KEY_SHIFT))
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_issue_command(event.position)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_camera_dragging = event.pressed
	elif event is InputEventMouseMotion:
		if _selection_dragging:
			_update_selection_drag(event.position)
			get_viewport().set_input_as_handled()
		elif _camera_dragging:
			_pan_camera(event.relative)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		# The second finger pans the battlefield on touch screens. The first finger
		# remains available for taps and drag-box selection via mouse emulation.
		if event.index > 0:
			_pan_camera(event.relative)
			get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		_set_camera_zoom(_camera.size / maxf(event.factor, 0.1))
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A:
				_toggle_order_mode()
			KEY_H:
				_hold_selected_units()
			KEY_Q:
				_activate_commander_rally()
			KEY_S:
				_stop_selected_units()
			KEY_ESCAPE:
				_clear_selection_from_button()
			KEY_R:
				_restart_battle()
			KEY_LEFT:
				_pan_camera(Vector2(-42.0, 0.0))
			KEY_RIGHT:
				_pan_camera(Vector2(42.0, 0.0))
			KEY_UP:
				_pan_camera(Vector2(0.0, -42.0))
			KEY_DOWN:
				_pan_camera(Vector2(0.0, 42.0))
			KEY_1, KEY_2, KEY_3, KEY_4:
				_handle_control_group_key(event)


func _begin_selection_drag(screen_position: Vector2) -> void:
	_selection_dragging = true
	_selection_start = screen_position
	_selection_end = screen_position
	_selection_marquee.visible = false


func _update_selection_drag(screen_position: Vector2) -> void:
	_selection_end = screen_position
	var rectangle := _get_drag_rectangle()
	_selection_marquee.position = rectangle.position
	_selection_marquee.size = rectangle.size
	_selection_marquee.visible = rectangle.size.length() >= 8.0


func _finish_selection_drag(screen_position: Vector2, add_to_selection: bool) -> void:
	if not _selection_dragging:
		return
	_selection_dragging = false
	_selection_end = screen_position
	var rectangle := _get_drag_rectangle()
	_selection_marquee.visible = false
	if rectangle.size.length() >= 12.0:
		_select_units_in_rectangle(rectangle, add_to_selection)
	else:
		_handle_primary_tap(screen_position, add_to_selection)


func _get_drag_rectangle() -> Rect2:
	var left := minf(_selection_start.x, _selection_end.x)
	var top := minf(_selection_start.y, _selection_end.y)
	var right := maxf(_selection_start.x, _selection_end.x)
	var bottom := maxf(_selection_start.y, _selection_end.y)
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


func _select_units_in_rectangle(rectangle: Rect2, add_to_selection: bool) -> void:
	if not add_to_selection:
		_clear_selection()
	for node in get_tree().get_nodes_in_group("battle_units"):
		if not node is BattleUnit:
			continue
		var unit := node as BattleUnit
		if unit.team != PLAYER_TEAM or unit.is_queued_for_deletion():
			continue
		if _camera.is_position_behind(unit.global_position):
			continue
		var screen_point := _camera.unproject_position(unit.global_position + Vector3(0.0, 0.75, 0.0))
		if rectangle.has_point(screen_point) and unit not in _selected_units:
			_selected_units.append(unit)
			unit.set_selected(true)
	_refresh_ui()


func _pan_camera(screen_delta: Vector2) -> void:
	if not is_instance_valid(_camera):
		return
	var scale := _camera.size / maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var camera_speed := GameSettings.camera_speed
	_camera.position.x = clampf(_camera.position.x - screen_delta.x * scale * camera_speed, -20.0, 20.0)
	_camera.position.z = clampf(_camera.position.z + screen_delta.y * scale * camera_speed, 5.0, 30.0)


func _set_camera_zoom(new_size: float) -> void:
	_camera.size = clampf(new_size, 16.0, 42.0)
	_refresh_ui()


func _handle_control_group_key(event: InputEventKey) -> void:
	var group_id := int(event.keycode - KEY_1) + 1
	if event.ctrl_pressed:
		_save_control_group(group_id)
	else:
		_select_control_group(group_id)


func _toggle_group_store_mode() -> void:
	_group_store_mode = not _group_store_mode
	_refresh_ui()


func _on_control_group_button(group_id: int) -> void:
	if _group_store_mode:
		_save_control_group(group_id)
		_group_store_mode = false
	else:
		_select_control_group(group_id)
	_refresh_ui()


func _save_control_group(group_id: int) -> void:
	if group_id < 1 or group_id > 4:
		return
	var saved: Array[BattleUnit] = []
	for unit in _selected_units:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion():
			saved.append(unit)
	if saved.is_empty():
		return
	_control_groups[group_id] = saved
	Haptics.confirm(30)
	if is_instance_valid(_toast_manager):
		_toast_manager.show_toast("Группа %d сохранена" % group_id, 2.0, "✓")


func _select_control_group(group_id: int) -> void:
	if not _control_groups.has(group_id):
		return
	_clear_selection()
	for unit in _control_groups[group_id]:
		if is_instance_valid(unit) and not unit.is_queued_for_deletion():
			_selected_units.append(unit)
			unit.set_selected(true)
	Haptics.tap(10)


func _handle_primary_tap(screen_position: Vector2, add_to_selection: bool) -> void:
	var hit := _raycast(screen_position)
	if hit.is_empty():
		return

	var collider: Object = hit.get("collider")
	if collider is BattleUnit:
		var unit := collider as BattleUnit
		if unit.team == PLAYER_TEAM:
			_select_at(screen_position, add_to_selection)
			return
		if not _selected_units.is_empty():
			_issue_command(screen_position)
		return

	if not _selected_units.is_empty():
		_issue_command(screen_position)
	else:
		_clear_selection()
		_refresh_ui()


func _select_at(screen_position: Vector2, add_to_selection: bool) -> void:
	var hit := _raycast(screen_position)
	if hit.is_empty():
		return

	var collider: Object = hit.get("collider")
	if not add_to_selection:
		_clear_selection()

	if collider is BattleUnit:
		var unit := collider as BattleUnit
		if unit.team == PLAYER_TEAM:
			if add_to_selection and unit in _selected_units:
				_selected_units.erase(unit)
				unit.set_selected(false)
			elif unit not in _selected_units:
				_selected_units.append(unit)
				unit.set_selected(true)

	_refresh_ui()


func _issue_command(screen_position: Vector2) -> void:
	if _selected_units.is_empty():
		return

	var hit := _raycast(screen_position)
	if hit.is_empty():
		return

	var collider: Object = hit.get("collider")
	if collider is BattleUnit:
		var target := collider as BattleUnit
		if target.team == ENEMY_TEAM:
			_set_focused_target(target)
			for unit in _selected_units:
				if is_instance_valid(unit):
					unit.order_attack(target)
			_attack_move_enabled = false
			_refresh_ui()
			Haptics.confirm(15)
		return

	_clear_focused_target()
	var destination: Vector3 = hit.get("position", Vector3.ZERO)
	_issue_formation_order(destination)
	Haptics.confirm(15)


func _issue_formation_order(destination: Vector3) -> void:
	var melee_units: Array[BattleUnit] = []
	var ranged_units: Array[BattleUnit] = []
	var spear_units: Array[BattleUnit] = []
	var cavalry_units: Array[BattleUnit] = []
	var formation_center := Vector3.ZERO
	var valid_count := 0

	for unit in _selected_units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion():
			continue
		formation_center += unit.global_position
		valid_count += 1
		match unit.role:
			BattleUnit.UnitRole.RANGED:
				ranged_units.append(unit)
			BattleUnit.UnitRole.SPEAR:
				spear_units.append(unit)
			BattleUnit.UnitRole.CAVALRY:
				cavalry_units.append(unit)
			_:
				melee_units.append(unit)

	if valid_count == 0:
		return

	formation_center /= float(valid_count)
	var forward := destination - formation_center
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3(1.0, 0.0, 0.0)
	else:
		forward = forward.normalized()
	var side := Vector3.UP.cross(forward).normalized()

	match _formation_mode:
		FormationMode.LINE:
			# Spears form the first rank, swordsmen support them, archers stay behind.
			_place_formation_row(spear_units, destination, side, forward, 0.0, 1.8)
			_place_formation_row(melee_units, destination, side, forward, 1.45, 1.7)
			_place_cavalry_wings(cavalry_units, destination, side, forward, 0.55)
			var ranged_depth := 3.25 if not melee_units.is_empty() or not spear_units.is_empty() else 0.0
			_place_formation_row(ranged_units, destination, side, forward, ranged_depth, 1.8)
		FormationMode.COLUMN:
			var ordered_units: Array[BattleUnit] = []
			ordered_units.append_array(spear_units)
			ordered_units.append_array(melee_units)
			ordered_units.append_array(cavalry_units)
			ordered_units.append_array(ranged_units)
			for index in range(ordered_units.size()):
				var slot := destination - forward * (float(index) * 1.5)
				_issue_order_to_slot(ordered_units[index], slot)
		FormationMode.WEDGE:
			var front_units: Array[BattleUnit] = []
			front_units.append_array(spear_units)
			front_units.append_array(melee_units)
			_place_wedge(front_units, destination, side, forward)
			_place_cavalry_wings(cavalry_units, destination, side, forward, 0.8)
			var rear_depth := _get_wedge_rear_depth(front_units.size()) + 3.0
			if front_units.is_empty():
				rear_depth = 0.0
			_place_formation_row(ranged_units, destination, side, forward, rear_depth, 1.8)

	_refresh_ui()


func _place_cavalry_wings(units: Array[BattleUnit], destination: Vector3, side: Vector3, forward: Vector3, depth: float) -> void:
	for index in range(units.size()):
		var rank := floori(float(index) / 2.0)
		var side_sign := -1.0 if index % 2 == 0 else 1.0
		var lateral_offset := side_sign * minf(2.6 + float(rank) * 1.25, 10.5)
		var slot := destination - forward * (depth + float(rank) * 1.2) + side * lateral_offset
		_issue_order_to_slot(units[index], slot)


func _place_formation_row(units: Array[BattleUnit], destination: Vector3, side: Vector3, forward: Vector3, depth: float, spacing: float) -> void:
	var count := units.size()
	if count == 0:
		return
	# Keep even a large regiment inside the 18 m command envelope.
	var safe_spacing := minf(spacing, 18.0 / float(maxi(count - 1, 1)))
	for index in range(count):
		var lateral_offset := (float(index) - float(count - 1) * 0.5) * safe_spacing
		var slot := destination - forward * depth + side * lateral_offset
		_issue_order_to_slot(units[index], slot)


func _place_wedge(units: Array[BattleUnit], destination: Vector3, side: Vector3, forward: Vector3) -> void:
	for index in range(units.size()):
		var lateral_offset := 0.0
		var depth := 0.0
		if index > 0:
			var row := ceili(float(index) / 2.0)
			var is_left := index % 2 == 1
			var wedge_spacing := minf(1.55, 18.0 / float(maxi(ceili(float(units.size() - 1) / 2.0), 1)))
			lateral_offset = float(row) * wedge_spacing * (-1.0 if is_left else 1.0)
			depth = float(row) * 1.25
		var slot := destination - forward * depth + side * lateral_offset
		_issue_order_to_slot(units[index], slot)


func _get_wedge_rear_depth(unit_count: int) -> float:
	if unit_count <= 1:
		return 0.0
	return float(ceili(float(unit_count - 1) / 2.0)) * 1.35


func _issue_order_to_slot(unit: BattleUnit, slot: Vector3) -> void:
	if not is_instance_valid(unit) or unit.is_queued_for_deletion():
		return
	if _attack_move_enabled:
		unit.order_attack_move(slot)
	else:
		unit.order_move(slot)


func _toggle_commands_panel() -> void:
	if not is_instance_valid(_commands_panel) or not is_instance_valid(_commands_button):
		return
	_commands_panel.visible = not _commands_panel.visible
	_commands_button.text = "ЗАКРЫТЬ" if _commands_panel.visible else "КОМАНДЫ"


func _open_settings() -> void:
	if is_instance_valid(_commands_panel) and _commands_panel.visible:
		_toggle_commands_panel()
	if is_instance_valid(_settings_panel):
		_settings_panel.open_panel()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_instance_valid(_settings_panel) and _settings_panel.visible:
			_settings_panel.close_panel()
		elif not _game_over:
			if not _paused:
				_toggle_pause()
			else:
				_toggle_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_pause_for_background()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		if _paused and is_instance_valid(_toast_manager):
			_toast_manager.show_toast("Бой приостановлен", 2.5, "Ⅱ")


func _pause_for_background() -> void:
	if _game_over:
		return
	if not _paused:
		_paused = true
		get_tree().paused = true
	if is_instance_valid(_pause_button):
		_pause_button.text = "ПРОДОЛЖИТЬ"
	# CampaignState.save_campaign() intentionally refuses to write during a
	# tactical battle, preserving the last safe strategic save and battle result.




func _raycast(screen_position: Vector2) -> Dictionary:
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = _camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 200.0)
	query.collision_mask = 3
	return get_world_3d().direct_space_state.intersect_ray(query)


func _select_all_player_units() -> void:
	_clear_selection()
	for node in get_tree().get_nodes_in_group("battle_units"):
		if node is BattleUnit:
			var unit := node as BattleUnit
			if unit.team == PLAYER_TEAM:
				_selected_units.append(unit)
				unit.set_selected(true)
	if not _selected_units.is_empty():
		Haptics.tap(10)
	_refresh_ui()


func _toggle_additive_selection() -> void:
	_additive_selection = not _additive_selection
	_refresh_ui()


func _cycle_formation_mode() -> void:
	match _formation_mode:
		FormationMode.LINE:
			_formation_mode = FormationMode.COLUMN
		FormationMode.COLUMN:
			_formation_mode = FormationMode.WEDGE
		FormationMode.WEDGE:
			_formation_mode = FormationMode.LINE
	_refresh_ui()


func _get_formation_name() -> String:
	match _formation_mode:
		FormationMode.LINE:
			return "ЛИНИЯ"
		FormationMode.COLUMN:
			return "КОЛОННА"
		FormationMode.WEDGE:
			return "КЛИН"
	return "ЛИНИЯ"


func _toggle_order_mode() -> void:
	_attack_move_enabled = not _attack_move_enabled
	_refresh_ui()


func _hold_selected_units() -> void:
	_clear_focused_target()
	for unit in _selected_units:
		if is_instance_valid(unit):
			unit.order_hold()
	_attack_move_enabled = false
	_refresh_ui()


func _stop_selected_units() -> void:
	_clear_focused_target()
	for unit in _selected_units:
		if is_instance_valid(unit):
			unit.order_stop()
	_attack_move_enabled = false
	_refresh_ui()


func _retreat_selected_units() -> void:
	_clear_focused_target()
	for unit in _selected_units:
		if is_instance_valid(unit):
			unit.order_retreat()
	_attack_move_enabled = false
	_refresh_ui()


func _toggle_pause() -> void:
	if _game_over:
		return
	_paused = not _paused
	get_tree().paused = _paused
	_pause_button.text = "ПРОДОЛЖИТЬ" if _paused else "ПАУЗА"


func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEED_VALUES.size()
	Engine.time_scale = SPEED_VALUES[_speed_index]
	_speed_button.text = "СКОРОСТЬ: %s" % SPEED_LABELS[_speed_index]


func _zoom_in() -> void:
	_set_camera_zoom(_camera.size - 2.0)


func _zoom_out() -> void:
	_set_camera_zoom(_camera.size + 2.0)


func _set_focused_target(target: BattleUnit) -> void:
	_clear_focused_target()
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		_focused_target = target
		_focused_target.set_targeted(true)


func _clear_focused_target() -> void:
	if is_instance_valid(_focused_target):
		_focused_target.set_targeted(false)
	_focused_target = null


func _clear_selection_from_button() -> void:
	_clear_selection()
	_clear_focused_target()
	_attack_move_enabled = false
	_additive_selection = false
	_refresh_ui()


func _clear_selection() -> void:
	for unit in _selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	_selected_units.clear()


func _restart_battle() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()


func _on_unit_eliminated(unit: BattleUnit, _killer: BattleUnit) -> void:
	if unit.team >= 0 and unit.team < _eliminated_kills.size():
		_eliminated_kills[unit.team] += unit.kills
		_eliminated_damage[unit.team] += unit.damage_dealt
	if unit in _selected_units:
		_selected_units.erase(unit)
	if unit == _focused_target:
		_clear_focused_target()
	call_deferred("_check_battle_result")
	call_deferred("_refresh_ui")


func _check_battle_result() -> void:
	if _game_over:
		return
	var player_count := _count_team(PLAYER_TEAM)
	var enemy_count := _count_team(ENEMY_TEAM)
	if player_count == 0 or enemy_count == 0:
		_game_over = true
		_paused = false
		get_tree().paused = false
		Engine.time_scale = 1.0
		var victory := enemy_count == 0 and player_count > 0
		_result_title.text = "ПОБЕДА!" if victory else "ПОРАЖЕНИЕ"
		var elapsed := _format_battle_time(_battle_time)
		var player_losses := _initial_team_counts[PLAYER_TEAM] - player_count
		var enemy_losses := _initial_team_counts[ENEMY_TEAM] - enemy_count
		var player_kills := _get_team_kills(PLAYER_TEAM)
		var enemy_kills := _get_team_kills(ENEMY_TEAM)
		var player_damage := _get_team_damage(PLAYER_TEAM)
		var enemy_damage := _get_team_damage(ENEMY_TEAM)
		var player_composition := _get_team_composition(PLAYER_TEAM)
		var enemy_composition := _get_team_composition(ENEMY_TEAM)
		_result_details.text = "Время боя: %s\nТвои потери: %d из %d\nПотери врага: %d из %d\nУничтожено врагов: %d\nОсталось у тебя: %s\nОсталось у врага: %s\nУрон: твои %.0f · враг %.0f" % [
			elapsed,
			player_losses,
			_initial_team_counts[PLAYER_TEAM],
			enemy_losses,
			_initial_team_counts[ENEMY_TEAM],
			player_kills,
			player_composition,
			enemy_composition,
			player_damage,
			enemy_damage,
		]
		if CampaignState.battle_in_progress:
			var stats := {
				"duration": _battle_time,
				"player_losses": player_losses,
				"enemy_losses": enemy_losses,
				"player_kills": player_kills,
				"enemy_kills": enemy_kills,
				"player_damage": player_damage,
				"enemy_damage": enemy_damage,
			}
			CampaignState.complete_battle(
				_collect_survivors(PLAYER_TEAM),
				_collect_survivors(ENEMY_TEAM),
				victory,
				stats,
				_get_commander_health(PLAYER_TEAM),
				_get_commander_health(ENEMY_TEAM)
			)
		_result_panel.visible = true
		for button in _combat_buttons:
			button.disabled = true
		_refresh_ui()


func _get_team_composition(team: int) -> String:
	var counts := [0, 0, 0, 0, 0]
	for node in get_tree().get_nodes_in_group("battle_units"):
		if node is BattleUnit and not node.is_queued_for_deletion():
			var unit := node as BattleUnit
			if unit.team == team:
				counts[clampi(unit.role, 0, 4)] += 1
	return "М%d Л%d Кп%d Кв%d Км%d" % [counts[0], counts[1], counts[2], counts[3], counts[4]]


func _collect_survivors(team: int) -> Array[Dictionary]:
	var survivors: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("battle_units"):
		if not node is BattleUnit or node.is_queued_for_deletion():
			continue
		var unit := node as BattleUnit
		if unit.team != team or unit.health <= 0.0 or unit.role == BattleUnit.UnitRole.COMMANDER:
			continue
		var role_name := CampaignState.ROLE_MELEE
		match unit.role:
			BattleUnit.UnitRole.RANGED:
				role_name = CampaignState.ROLE_RANGED
			BattleUnit.UnitRole.SPEAR:
				role_name = CampaignState.ROLE_SPEAR
			BattleUnit.UnitRole.CAVALRY:
				role_name = CampaignState.ROLE_CAVALRY
		survivors.append({"role": role_name, "health": unit.health})
	return survivors


func _return_to_strategy_map() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/strategy_map.tscn")


func _format_battle_time(seconds: float) -> String:
	var total_seconds: int = maxi(0, floori(seconds))
	var minutes: int = floori(float(total_seconds) / 60.0)
	var remaining_seconds: int = total_seconds - minutes * 60
	return "%02d:%02d" % [minutes, remaining_seconds]


func _get_team_kills(team: int) -> int:
	var total := 0
	for node in get_tree().get_nodes_in_group("battle_units"):
		if node is BattleUnit and not node.is_queued_for_deletion():
			var unit := node as BattleUnit
			if unit.team == team:
				total += unit.kills
	# Include units that have already been eliminated: their final stats are captured below.
	return total + _eliminated_kills[team]


func _get_team_damage(team: int) -> float:
	var total := _eliminated_damage[team]
	for node in get_tree().get_nodes_in_group("battle_units"):
		if node is BattleUnit and not node.is_queued_for_deletion():
			var unit := node as BattleUnit
			if unit.team == team:
				total += unit.damage_dealt
	return total



func _count_team(team: int) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("battle_units"):
		if node is BattleUnit and node.team == team and not node.is_queued_for_deletion():
			count += 1
	return count


func _count_role(team: int, unit_role: int) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("battle_units"):
		if node is BattleUnit:
			var unit := node as BattleUnit
			if unit.team == team and unit.role == unit_role and not unit.is_queued_for_deletion():
				count += 1
	return count


func _refresh_ui() -> void:
	if not is_instance_valid(_status_label):
		return
	if _game_over:
		_status_label.text = _result_title.text
		_help_label.text = "Сражение завершено · выбери новое сражение"
	else:
		_status_label.text = "СИНИЕ %d    КРАСНЫЕ %d    ВЫБРАНО %d    ВРЕМЯ %s" % [
			_count_team(PLAYER_TEAM),
			_count_team(ENEMY_TEAM),
			_selected_units.size(),
			_format_battle_time(_battle_time),
		]
		var target_text := "ЦЕЛЬ: враг отмечен" if is_instance_valid(_focused_target) else "ЦЕЛЬ: не выбрана"
		var commander_level := int(CampaignState.player_hero.get("level", 1))
		_help_label.text = "МЕСТНОСТЬ: %s · КОМАНДИР УР.%d · %s · %s · ЗУМ %.0f" % [
			_battlefield_biome_name,
			commander_level,
			_get_formation_name(),
			target_text,
			_camera.size,
		]
	if is_instance_valid(_mode_button):
		_mode_button.text = "МАРШ ВКЛ" if _attack_move_enabled else "МАРШ"
	if is_instance_valid(_add_button):
		_add_button.text = "ДОБОР: ВКЛ" if _additive_selection else "ДОБОР: ВЫКЛ"
	if is_instance_valid(_formation_button):
		_formation_button.text = "СТРОЙ: %s" % _get_formation_name()
	if is_instance_valid(_rally_button):
		var commander_cooldown := 0.0
		for node in get_tree().get_nodes_in_group("battle_units"):
			if node is BattleUnit:
				var commander := node as BattleUnit
				if commander.team == PLAYER_TEAM and commander.role == BattleUnit.UnitRole.COMMANDER:
					commander_cooldown = commander.rally_cooldown_timer
					break
		_rally_button.disabled = _game_over or commander_cooldown > 0.0
		_rally_button.text = "КЛИЧ: %d с" % ceili(commander_cooldown) if commander_cooldown > 0.0 else "БОЕВОЙ КЛИЧ"
