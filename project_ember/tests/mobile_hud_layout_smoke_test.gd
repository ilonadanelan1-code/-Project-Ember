extends SceneTree

const StrategyScene = preload("res://scenes/strategy_map.tscn")
const BattleScene = preload("res://scenes/combat_test.tscn")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _dp(value: float) -> float:
	var metrics := root.get_node_or_null("UiMetrics")
	if is_instance_valid(metrics) and metrics.has_method("dp"):
		return float(metrics.call("dp", value))
	return value


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)


func _run() -> void:
	var map_scene := StrategyScene.instantiate()
	root.add_child(map_scene)
	await process_frame
	await process_frame

	var map_top := map_scene.find_child("MobileHudTop", true, false) as Control
	var map_dock := map_scene.find_child("MobileHudQuickDock", true, false) as Control
	var map_drawer := map_scene.find_child("MobileHudMoreCommands", true, false) as Control
	_check(is_instance_valid(map_top), "strategy HUD top status panel is created")
	_check(is_instance_valid(map_dock), "strategy quick dock is created")
	_check(is_instance_valid(map_drawer), "strategy secondary command drawer is created")
	if is_instance_valid(map_dock) and is_instance_valid(map_drawer):
		_check(not map_drawer.visible, "strategy secondary commands start collapsed")
		_check(map_dock.size.y <= _dp(84.0), "strategy quick dock stays within a compact vertical budget")
		map_scene.call("_toggle_map_commands")
		_check(map_drawer.visible, "strategy secondary commands can be opened")
		map_scene.call("_toggle_map_commands")
		_check(not map_drawer.visible, "strategy secondary commands can be closed")
	if is_instance_valid(map_top) and is_instance_valid(map_dock):
		_check(map_dock.position.y > map_top.position.y + map_top.size.y, "strategy status and quick dock leave a central map area")

	map_scene.queue_free()
	await process_frame

	var battle_scene := BattleScene.instantiate()
	root.add_child(battle_scene)
	await process_frame
	await process_frame

	var battle_top := battle_scene.find_child("BattleHudTop", true, false) as Control
	var battle_dock := battle_scene.find_child("BattleHudQuickDock", true, false) as Control
	var battle_drawer := battle_scene.find_child("BattleCommandsDrawer", true, false) as Control
	_check(is_instance_valid(battle_top), "battle HUD top status panel is created")
	_check(is_instance_valid(battle_dock), "battle quick dock is created")
	_check(is_instance_valid(battle_drawer), "battle command drawer is created")
	if is_instance_valid(battle_dock) and is_instance_valid(battle_drawer):
		_check(not battle_drawer.visible, "battle secondary commands start collapsed")
		_check(battle_dock.size.y <= _dp(90.0), "battle quick dock stays within a compact vertical budget")
		battle_scene.call("_toggle_commands_panel")
		_check(battle_drawer.visible, "battle command drawer can be opened")
		battle_scene.call("_toggle_commands_panel")
		_check(not battle_drawer.visible, "battle command drawer can be closed")
	if is_instance_valid(battle_top) and is_instance_valid(battle_dock):
		_check(battle_dock.position.y > battle_top.position.y + battle_top.size.y, "battle status and quick dock leave a central battlefield area")

	battle_scene.queue_free()
	await process_frame
	if _failures > 0:
		printerr("Mobile HUD layout tests failed: %d" % _failures)
		quit(1)
	else:
		print("All mobile HUD layout smoke tests passed.")
		quit(0)
