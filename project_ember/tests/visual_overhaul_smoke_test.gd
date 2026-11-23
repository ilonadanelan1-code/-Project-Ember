extends SceneTree

const BattlefieldVisualsScript = preload("res://scripts/battlefield_visuals.gd")
const BattleUnitVisualsScript = preload("res://scripts/battle_unit_visuals.gd")
const BattleUnitScript = preload("res://scripts/battle_unit.gd")
const VisualCacheScript = preload("res://scripts/visual_cache.gd")

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
	var scene_root := Node3D.new()
	root.add_child(scene_root)
	var environment_data: Dictionary = BattlefieldVisualsScript.create(scene_root, Vector2(38.0, 26.0))
	_check(environment_data.get("ground_body") is StaticBody3D, "visual battlefield preserves a clickable ground collision body")
	_check(environment_data.get("camera") is Camera3D, "visual battlefield creates the tactical camera")
	_check(scene_root.get_child_count() >= 8, "visual battlefield adds lighting, world environment and procedural decoration")

	VisualCacheScript.clear()
	var swordsman := BattleUnitVisualsScript.build(0, BattleUnitScript.UnitRole.MELEE)
	var material_count_after_first_swordsman := VisualCacheScript.get_material_count()
	var second_swordsman := BattleUnitVisualsScript.build(0, BattleUnitScript.UnitRole.MELEE)
	_check(swordsman.get_child(0).mesh == second_swordsman.get_child(0).mesh, "same team and role share the same first-part mesh")
	_check(VisualCacheScript.get_material_count() == material_count_after_first_swordsman, "spawning a second same-role unit does not create new materials")
	var archer := BattleUnitVisualsScript.build(0, BattleUnitScript.UnitRole.RANGED)
	var cavalry := BattleUnitVisualsScript.build(1, BattleUnitScript.UnitRole.CAVALRY)
	var commander := BattleUnitVisualsScript.build(0, BattleUnitScript.UnitRole.COMMANDER)
	_check(swordsman.get_child_count() >= 15, "swordsman uses a multi-part stylized model")
	_check(archer.get_child_count() >= 18, "archer has a distinct bow and quiver silhouette")
	_check(cavalry.get_child_count() >= 20, "cavalry includes a horse and rider model")
	_check(commander.get_child_count() >= 18, "commander includes hero armor and a banner")
	swordsman.free()
	second_swordsman.free()
	archer.free()
	cavalry.free()
	commander.free()
	scene_root.free()

	if _failures > 0:
		printerr("Visual overhaul smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All visual overhaul smoke tests passed.")
		quit(0)
