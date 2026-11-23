extends Node3D

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
var _result_title: Label
var _result_details: Label
var _formation_mode: FormationMode = FormationMode.LINE
var _focused_target: BattleUnit
var _eliminated_kills: Array[int] = [0, 0]
var _eliminated_damage: Array[float] = [0.0, 0.0]
var _combat_buttons: Array[Button] = []
var _initial_team_counts: Array[int] = [FALLBACK_UNITS_PER_TEAM, FALLBACK_UNITS_PER_TEAM]


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	_create_environment()
	_spawn_armies()
	_create_ui()
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
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = FIELD_SIZE
	ground.mesh = ground_mesh
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.20, 0.29, 0.20)
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	add_child(ground)

	_ground_body = StaticBody3D.new()
	_ground_body.collision_layer = 1
	_ground_body.collision_mask = 0
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(FIELD_SIZE.x, 0.2, FIELD_SIZE.y)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.1
	_ground_body.add_child(ground_collision)
	add_child(_ground_body)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52.0, -25.0, 0.0)
	light.shadow_enabled = false
	add_child(light)

	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 27.0
	_camera.position = Vector3(0.0, 23.0, 16.0)
	add_child(_camera)
	_camera.look_at(Vector3.ZERO, Vector3.UP)
	_camera.current = true


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

	_initial_team_counts = [_count_team(PLAYER_TEAM), _count_team(ENEMY_TEAM)]


func _spawn_army_from_records(team: int, records: Array[Dictionary]) -> void:
	var melee_count := 0
	var ranged_count := 0
	for record in records:
		if str(record.get("role", CampaignState.ROLE_MELEE)) == CampaignState.ROLE_RANGED:
			ranged_count += 1
		else:
			melee_count += 1

	var melee_index := 0
	var ranged_index := 0
	var side_x := -8.0 if team == PLAYER_TEAM else 8.0
	for record in records:
		var role_name := str(record.get("role", CampaignState.ROLE_MELEE))
		var role := BattleUnit.UnitRole.RANGED if role_name == CampaignState.ROLE_RANGED else BattleUnit.UnitRole.MELEE
		var spawn_position := Vector3.ZERO
		if role == BattleUnit.UnitRole.RANGED:
			# Keep even a fully ranged 16-unit army inside the tactical field.
			var ranged_spacing := minf(3.2, 16.0 / float(maxi(ranged_count - 1, 1)))
			var ranged_offset := (float(ranged_index) - float(ranged_count - 1) * 0.5) * ranged_spacing
			spawn_position = Vector3(side_x * 1.55, 0.0, ranged_offset)
			ranged_index += 1
		else:
			var melee_spacing := minf(2.2, 14.0 / float(maxi(melee_count - 1, 1)))
			var melee_offset := (float(melee_index) - float(melee_count - 1) * 0.5) * melee_spacing
			spawn_position = Vector3(side_x, 0.0, melee_offset)
			melee_index += 1
		_spawn_unit(team, spawn_position, role, float(record.get("health", -1.0)))


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
	top_panel.offset_bottom = 78.0
	top_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.035, 0.055, 0.075, 0.92)))
	root.add_child(top_panel)

	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 1)
	top_panel.add_child(top_box)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	top_box.add_child(_status_label)

	_help_label = Label.new()
	_help_label.add_theme_font_size_override("font_size", 13)
	_help_label.add_theme_color_override("font_color", Color(0.85, 0.91, 0.96))
	top_box.add_child(_help_label)

	# Three compact rows: selection/orders, formation/retreat, battle controls.
	var bottom_panel := Panel.new()
	bottom_panel.anchor_left = 0.0
	bottom_panel.anchor_top = 1.0
	bottom_panel.anchor_right = 1.0
	bottom_panel.anchor_bottom = 1.0
	bottom_panel.offset_left = 8.0
	bottom_panel.offset_top = -214.0
	bottom_panel.offset_right = -8.0
	bottom_panel.offset_bottom = -8.0
	bottom_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.025, 0.035, 0.05, 0.96)))
	root.add_child(bottom_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 7)
	bottom_panel.add_child(margin)

	var buttons := GridContainer.new()
	buttons.columns = 4
	buttons.add_theme_constant_override("h_separation", 7)
	buttons.add_theme_constant_override("v_separation", 5)
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(buttons)

	_add_action_button(buttons, "ВСЕ", _select_all_player_units)
	_add_button = _add_action_button(buttons, "ДОБОР: ВЫКЛ", _toggle_additive_selection)
	_mode_button = _add_action_button(buttons, "МАРШ: ВЫКЛ", _toggle_order_mode)
	_add_action_button(buttons, "ДЕРЖАТЬ", _hold_selected_units)
	_add_action_button(buttons, "СТОП", _stop_selected_units)
	_add_action_button(buttons, "СНЯТЬ", _clear_selection_from_button)
	_formation_button = _add_action_button(buttons, "СТРОЙ: ЛИНИЯ", _cycle_formation_mode)
	_add_action_button(buttons, "ОТСТУП", _retreat_selected_units)
	_pause_button = _add_action_button(buttons, "ПАУЗА", _toggle_pause)
	_speed_button = _add_action_button(buttons, "СКОРОСТЬ: 1x", _cycle_speed)
	_add_action_button(buttons, "ЗУМ +", _zoom_in)
	_add_action_button(buttons, "ЗУМ -", _zoom_out)
	for child in buttons.get_children():
		if child is Button:
			_combat_buttons.append(child as Button)

	_create_result_panel(root)


func _create_result_panel(parent: Control) -> void:
	_result_panel = PanelContainer.new()
	_result_panel.anchor_left = 0.5
	_result_panel.anchor_top = 0.5
	_result_panel.anchor_right = 0.5
	_result_panel.anchor_bottom = 0.5
	_result_panel.offset_left = -230.0
	_result_panel.offset_top = -118.0
	_result_panel.offset_right = 230.0
	_result_panel.offset_bottom = 118.0
	_result_panel.custom_minimum_size = Vector2(460.0, 236.0)
	_result_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.035, 0.055, 0.075, 0.98)))
	_result_panel.visible = false
	parent.add_child(_result_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	_result_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_size_override("font_size", 27)
	_result_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	content.add_child(_result_title)

	_result_details = Label.new()
	_result_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_details.add_theme_font_size_override("font_size", 16)
	_result_details.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
	content.add_child(_result_details)

	var return_button := _add_action_button(content, "НА СТРАТЕГИЧЕСКУЮ КАРТУ", _return_to_strategy_map)
	return_button.custom_minimum_size = Vector2(0.0, 48.0)


func _make_panel_style(background: Color) -> StyleBoxFlat:
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


func _add_action_button(parent: Container, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(0.0, 52.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.94, 0.65))
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.12, 0.20, 0.29)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.17, 0.29, 0.40)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.25, 0.35, 0.22)))
	button.add_theme_stylebox_override("focus", _make_button_style(Color(0.16, 0.24, 0.32)))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _make_button_style(background: Color) -> StyleBoxFlat:
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
	if _game_over or _paused:
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_handle_primary_tap(event.position, _additive_selection or Input.is_key_pressed(KEY_SHIFT))
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_issue_command(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A:
				_toggle_order_mode()
			KEY_H:
				_hold_selected_units()
			KEY_S:
				_stop_selected_units()
			KEY_ESCAPE:
				_clear_selection_from_button()
			KEY_R:
				_restart_battle()


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
		return

	_clear_focused_target()
	var destination: Vector3 = hit.get("position", Vector3.ZERO)
	_issue_formation_order(destination)


func _issue_formation_order(destination: Vector3) -> void:
	var melee_units: Array[BattleUnit] = []
	var ranged_units: Array[BattleUnit] = []
	var formation_center := Vector3.ZERO
	var valid_count := 0

	for unit in _selected_units:
		if not is_instance_valid(unit) or unit.is_queued_for_deletion():
			continue
		formation_center += unit.global_position
		valid_count += 1
		if unit.role == BattleUnit.UnitRole.RANGED:
			ranged_units.append(unit)
		else:
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
			_place_formation_row(melee_units, destination, side, forward, 0.0, 1.65)
			var ranged_depth := 2.0 if not melee_units.is_empty() else 0.0
			_place_formation_row(ranged_units, destination, side, forward, ranged_depth, 1.65)
		FormationMode.COLUMN:
			var ordered_units: Array[BattleUnit] = []
			ordered_units.append_array(melee_units)
			ordered_units.append_array(ranged_units)
			for index in range(ordered_units.size()):
				var slot := destination - forward * (float(index) * 1.5)
				_issue_order_to_slot(ordered_units[index], slot)
		FormationMode.WEDGE:
			_place_wedge(melee_units, destination, side, forward)
			var rear_depth := _get_wedge_rear_depth(melee_units.size()) + 2.0
			if melee_units.is_empty():
				rear_depth = 0.0
			_place_formation_row(ranged_units, destination, side, forward, rear_depth, 1.65)

	_refresh_ui()


func _place_formation_row(units: Array[BattleUnit], destination: Vector3, side: Vector3, forward: Vector3, depth: float, spacing: float) -> void:
	var count := units.size()
	for index in range(count):
		var lateral_offset := (float(index) - float(count - 1) * 0.5) * spacing
		var slot := destination - forward * depth + side * lateral_offset
		_issue_order_to_slot(units[index], slot)


func _place_wedge(units: Array[BattleUnit], destination: Vector3, side: Vector3, forward: Vector3) -> void:
	for index in range(units.size()):
		var lateral_offset := 0.0
		var depth := 0.0
		if index > 0:
			var row := ceili(float(index) / 2.0)
			var is_left := index % 2 == 1
			lateral_offset = float(row) * 1.55 * (-1.0 if is_left else 1.0)
			depth = float(row) * 1.35
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
	_camera.size = maxf(18.0, _camera.size - 2.0)
	_refresh_ui()


func _zoom_out() -> void:
	_camera.size = minf(36.0, _camera.size + 2.0)
	_refresh_ui()


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
		_result_details.text = "Время боя: %s\nТвои потери: %d из %d\nПотери врага: %d из %d\nУничтожено врагов: %d\nУрон: твои %.0f · враг %.0f" % [
			elapsed,
			player_losses,
			_initial_team_counts[PLAYER_TEAM],
			enemy_losses,
			_initial_team_counts[ENEMY_TEAM],
			player_kills,
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
				stats
			)
		_result_panel.visible = true
		for button in _combat_buttons:
			button.disabled = true
		_refresh_ui()


func _collect_survivors(team: int) -> Array[Dictionary]:
	var survivors: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group("battle_units"):
		if not node is BattleUnit or node.is_queued_for_deletion():
			continue
		var unit := node as BattleUnit
		if unit.team != team or unit.health <= 0.0:
			continue
		var role_name := CampaignState.ROLE_RANGED if unit.role == BattleUnit.UnitRole.RANGED else CampaignState.ROLE_MELEE
		survivors.append({"role": role_name, "health": unit.health})
	return survivors


func _return_to_strategy_map() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/strategy_map.tscn")


func _format_battle_time(seconds: float) -> String:
	var total_seconds := int(floor(seconds))
	var minutes := int(total_seconds / 60)
	var remaining_seconds := total_seconds % 60
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
		_help_label.text = "МЕЧНИКИ + ЛУЧНИКИ · %s · %s · ЗУМ %.0f" % [
			_get_formation_name(),
			target_text,
			_camera.size,
		]
	if is_instance_valid(_mode_button):
		_mode_button.text = "МАРШ: ВКЛ" if _attack_move_enabled else "МАРШ: ВЫКЛ"
	if is_instance_valid(_add_button):
		_add_button.text = "ДОБОР: ВКЛ" if _additive_selection else "ДОБОР: ВЫКЛ"
	if is_instance_valid(_formation_button):
		_formation_button.text = "СТРОЙ: %s" % _get_formation_name()
