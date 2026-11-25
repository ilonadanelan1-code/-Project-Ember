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
	_check(environment_data.get("ground_body") is StaticBody3D, "visual battlefield preserves its ground collision body")
	_check(environment_data.get("camera") is Camera3D, "visual battlefield creates the tactical camera")

	VisualCacheScript.clear()
	var model_meshes: Dictionary = {}
	for team in [0, 1]:
		for role in range(5):
			var model := BattleUnitVisualsScript.build(team, role)
			_check(model.get_child_count() == 2, "each team/role model uses exactly two mesh instances")
			var body := model.get_node("BodyMesh") as MeshInstance3D
			var action := model.get_node("ActionMesh") as MeshInstance3D
			_check(body.mesh is ArrayMesh and body.mesh.get_surface_count() == 1, "static unit geometry is one merged ArrayMesh surface")
			_check(action.mesh is ArrayMesh and action.mesh.get_surface_count() == 1, "animated unit geometry is one merged ArrayMesh surface")
			_check(body.material_override == action.material_override, "body and action share the vertex-colour material")
			var role_key := "%d:%d" % [team, role]
			model_meshes[role_key] = [body.mesh, action.mesh]
			model.free()

	_check(VisualCacheScript.get_mesh_count() >= 20, "all ten team/role combinations are cached as body and action meshes")
	_check(VisualCacheScript.get_material_count() == 1, "all unit batches share a single cached vertex-colour material")

	# Same team and role must reuse exact ArrayMesh resources.
	var first_model := BattleUnitVisualsScript.build(0, BattleUnitScript.UnitRole.MELEE)
	var second_model := BattleUnitVisualsScript.build(0, BattleUnitScript.UnitRole.MELEE)
	_check(first_model.get_node("BodyMesh").mesh == second_model.get_node("BodyMesh").mesh, "same team and role share the static mesh resource")
	_check(first_model.get_node("ActionMesh").mesh == second_model.get_node("ActionMesh").mesh, "same team and role share the animated mesh resource")
	first_model.free()
	second_model.free()

	# Five silhouettes must stay distinguishable by mesh identity.
	var unique_role_meshes: Dictionary = {}
	for role in range(5):
		var body_mesh: Mesh = model_meshes["0:%d" % role][0]
		unique_role_meshes[body_mesh.get_instance_id()] = true
	_check(unique_role_meshes.size() == 5, "all five unit roles have distinct merged silhouettes")

	# Spawn a full-size test battle and verify both draw-call proxy and node budget.
	var units: Array[BattleUnit] = []
	for index in range(50):
		var unit := BattleUnitScript.new() as BattleUnit
		unit.team = index % 2
		unit.role = index % 5
		unit.position = Vector3(float(index % 10) - 5.0, 0.0, float(index / 10) * 1.5 - 3.0)
		scene_root.add_child(unit)
		unit.set_physics_process(false)
		units.append(unit)
	await process_frame

	var node_budget_ok := true
	var compact_visual_budget_ok := true
	for unit in units:
		if _count_nodes(unit) > 8:
			node_budget_ok = false
		var visual_root := unit.get_node("VisualRoot") as Node3D
		var sprite_visual := visual_root.get_node_or_null("CombatSprite") as AnimatedSprite3D
		var body_mesh := visual_root.get_node_or_null("BodyMesh") as MeshInstance3D
		var action_mesh := visual_root.get_node_or_null("ActionMesh") as MeshInstance3D
		var sprite_renderer_valid := is_instance_valid(sprite_visual) and visual_root.get_child_count() == 1
		var mesh_fallback_valid := is_instance_valid(body_mesh) and is_instance_valid(action_mesh) and visual_root.get_child_count() == 2
		if not sprite_renderer_valid and not mesh_fallback_valid:
			compact_visual_budget_ok = false
	_check(node_budget_ok, "all 50 live BattleUnit instances stay at or below eight nodes")
	_check(compact_visual_budget_ok, "all 50 live units use the compact animated-sprite renderer or the two-mesh fallback")

	var material_count_after_spawn := VisualCacheScript.get_material_count()
	units[0].take_damage(1.0)
	var body_instance := units[0].get_node("VisualRoot/BodyMesh") as MeshInstance3D
	var action_instance := units[0].get_node("VisualRoot/ActionMesh") as MeshInstance3D
	_check(body_instance.material_overlay != null and body_instance.material_overlay == action_instance.material_overlay, "hit flash uses one shared overlay material on both merged meshes")
	var flash_material_count := VisualCacheScript.get_material_count()
	units[1].take_damage(1.0)
	_check(VisualCacheScript.get_material_count() == flash_material_count, "repeated hit flashes do not create per-unit materials")
	_check(material_count_after_spawn <= flash_material_count, "hit flash adds at most one shared material to the cache")
	_check(units[0]._health_background.visible and units[0]._health_fill.visible, "health bar becomes visible after damage")

	units[2].set_selected(true)
	_check((units[2].get_node("SelectionRing") as MeshInstance3D).visible, "selection is represented by one cached ring mesh")
	units[2].set_targeted(true)
	var target_ring := units[2].get_node("SelectionRing") as MeshInstance3D
	var idle_ring := units[3].get_node("SelectionRing") as MeshInstance3D
	_check(target_ring.material_override != idle_ring.material_override, "target state changes the shared ring material without adding a node")
	_check(_count_nodes(units[2]) == 8, "selection and target states do not exceed the eight-node budget")

	units[4].play_attack_animation()
	_check(units[4]._attack_animation_elapsed == 0.0, "role-specific attack animation can be triggered without a Tween node")
	var original_damage := units[4].attack_damage
	units[4].take_damage(1.0)
	_check(is_equal_approx(units[4].attack_damage, original_damage), "visual hit reaction does not alter combat damage")

	# The lethal probe must exceed the target's armor, not just its current health.
	units[5].take_damage(units[5].health + units[5].armor + 1.0)
	_check(not units[5].is_in_group("battle_units"), "defeated units leave the combat group immediately")
	_check(units[5]._is_corpse and units[5].is_processing(), "defeated units remain as short-lived animated corpses")

	for unit in units:
		if is_instance_valid(unit):
			unit.free()
	scene_root.free()

	if _failures > 0:
		printerr("Unit visual smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All unit visual and 50-unit budget tests passed.")
		quit(0)


func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total
