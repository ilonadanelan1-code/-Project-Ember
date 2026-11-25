extends SceneTree

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)


func _run() -> void:
	var map_source := FileAccess.get_file_as_string("res://scripts/strategy_map.gd")
	var battle_source := FileAccess.get_file_as_string("res://scripts/combat_test.gd")
	var palette_source := FileAccess.get_file_as_string("res://scripts/art_palette.gd")
	_check(not map_source.is_empty(), "strategy HUD source is readable")
	_check(not battle_source.is_empty(), "battle HUD source is readable")

	_check(map_source.contains('top_panel.offset_bottom = UiMetrics.dp(48.0)'), "strategy top bar uses the reduced height")
	_check(map_source.contains('bottom_panel.offset_top = -UiMetrics.dp(66.0)'), "strategy quick dock has a reduced height budget")
	_check(map_source.contains('_map_more_panel.offset_bottom = -UiMetrics.dp(74.0)'), "secondary command drawer clears the compact quick dock")
	_check(map_source.contains('font_size(14)'), "quick actions use compact readable labels")
	_check(map_source.contains('UiThemeScript.touch_target(48.0)'), "quick actions preserve a 48dp minimum touch target")
	_check(map_source.contains('maxf(0.18, 0.22 * _map_zoom)'), "map grid uses thinner strokes")
	_check(palette_source.contains('const MAP_HEX_GRID := Color(0.20, 0.24, 0.20, 0.08)'), "base hex grid opacity is reduced without changing special map overlays")
	_check(map_source.contains('bottom_panel.name = "MobileHudQuickDock"'), "strategy quick dock is present")
	_check(map_source.contains('_map_more_panel.visible = false'), "strategy secondary commands start collapsed")
	_check(map_source.contains('more_grid.columns = 2'), "strategy secondary commands use a compact two-column layout")
	_check(map_source.contains('_map_more_panel.visible = not _map_more_panel.visible'), "strategy drawer supports expand and collapse")
	_check(map_source.contains('_toggle_map_commands()'), "strategy drawer is reachable from the map controls")
	_check(map_source.contains('if is_instance_valid(_map_more_panel) and _map_more_panel.visible:'), "Android Back can close the strategy drawer")

	_check(battle_source.contains('top_panel.offset_bottom = UiMetrics.dp(62.0)'), "battle top bar uses the compact height")
	_check(battle_source.contains('bottom_panel.offset_top = -UiMetrics.dp(86.0)'), "battle quick dock has a compact height budget")
	_check(battle_source.contains('bottom_panel.name = "BattleHudQuickDock"'), "battle quick dock is present")
	_check(battle_source.contains('_commands_panel.visible = false'), "battle secondary commands start collapsed")
	_check(battle_source.contains('var drawer_scroll := ScrollContainer.new()'), "battle commands are contained in a scrollable drawer")
	_check(battle_source.contains('buttons.columns = 4'), "battle secondary actions use a compact four-column grid")
	_check(battle_source.contains('_commands_panel.visible = not _commands_panel.visible'), "battle drawer supports expand and collapse")
	_check(battle_source.contains('_commands_button.text = "ЗАКРЫТЬ" if _commands_panel.visible else "КОМАНДЫ"'), "battle drawer exposes an explicit close state")
	_check(battle_source.contains('_combat_buttons.append(_pause_button)'), "pause remains available in the quick dock")
	_check(battle_source.contains('_combat_buttons.append(_mode_button)'), "march remains available in the quick dock")

	if _failures > 0:
		printerr("Mobile HUD layout tests failed: %d" % _failures)
		quit(1)
	else:
		print("All mobile HUD layout smoke tests passed.")
		quit(0)
