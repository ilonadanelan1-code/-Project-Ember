extends SceneTree

const BattlefieldVisualsScript = preload("res://scripts/battlefield_visuals.gd")
const BattleUnitScript = preload("res://scripts/battle_unit.gd")
const CombatSpriteLibraryScript = preload("res://scripts/combat_sprite_library.gd")
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


func _contains_mesh_node(node: Node) -> bool:
	for child in node.get_children():
		if child is MeshInstance3D or _contains_mesh_node(child):
			return true
	return false


func _run() -> void:
	var scene_root := Node3D.new()
	root.add_child(scene_root)
	var environment_data: Dictionary = BattlefieldVisualsScript.create(scene_root, Vector2(38.0, 26.0))
	_check(environment_data.get("ground_body") is StaticBody3D, "pixel battlefield preserves its ground collision body")
	_check(environment_data.get("camera") is Camera3D, "pixel battlefield creates the tactical camera")

	VisualCacheScript.clear()
	var sprite_atlas_present := CombatSpriteLibraryScript.has_assets()
	_check(sprite_atlas_present == ResourceLoader.exists("res://assets/combat/tiny_swords/combat_units_atlas.png"), "combat sprite availability reflects the integrated licensed atlas")
	var battle_unit_source := FileAccess.get_file_as_string("res://scripts/battle_unit.gd")
	_check(not battle_unit_source.contains("BattleUnitVisualsScript.build("), "active BattleUnit runtime never calls the procedural 3D model builder")

	# A representative full-size battle must retain the compact sprite-only path.
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
	var sprite_renderer_ok := true
	var source_checkout_stays_mesh_free := true
	for unit in units:
		if _count_nodes(unit) > 8:
			node_budget_ok = false
		var visual_root := unit.get_node_or_null("VisualRoot") as Node3D
		if not is_instance_valid(visual_root):
			sprite_renderer_ok = false
			continue
		var sprite := visual_root.get_node_or_null("CombatSprite") as AnimatedSprite3D
		var expected_frames: SpriteFrames = CombatSpriteLibraryScript.get_frames(unit.team, unit.role)
		if is_instance_valid(expected_frames):
			if not is_instance_valid(sprite) or sprite.sprite_frames != expected_frames:
				sprite_renderer_ok = false
			elif sprite.texture_filter != BaseMaterial3D.TEXTURE_FILTER_NEAREST:
				sprite_renderer_ok = false
			elif sprite.shaded or sprite.alpha_cut != SpriteBase3D.ALPHA_CUT_DISCARD:
				sprite_renderer_ok = false
		else:
			if visual_root.get_child_count() != 0 or _contains_mesh_node(visual_root):
				source_checkout_stays_mesh_free = false
	_check(node_budget_ok, "all 50 live BattleUnit instances stay at or below eight nodes")
	_check(sprite_renderer_ok, "every available combat atlas frame is rendered by nearest-filtered pixel sprites")
	_check(source_checkout_stays_mesh_free, "source-only checkout never substitutes low-poly meshes when licensed pixel art is absent")

	var material_count_after_spawn := VisualCacheScript.get_material_count()
	var health_before_hit := units[0].health
	units[0].take_damage(1.0)
	_check(units[0].health < health_before_hit, "damage updates unit health in sprite and source-only builds")
	if is_instance_valid(units[0]._combat_sprite):
		_check(units[0]._hit_flash_timer > 0.0, "pixel-sprite hit feedback starts when the licensed atlas is present")
	else:
		_check(not CombatSpriteLibraryScript.has_assets() and not _contains_mesh_node(units[0].get_node("VisualRoot")), "missing licensed art never produces a procedural hit-flash substitute")
	var flash_material_count := VisualCacheScript.get_material_count()
	units[1].take_damage(1.0)
	_check(VisualCacheScript.get_material_count() == flash_material_count, "repeated hit feedback does not create per-unit materials")
	_check(material_count_after_spawn <= flash_material_count, "hit feedback adds at most one shared material to the cache")
	_check(units[0]._health_background.visible and units[0]._health_fill.visible, "health bar becomes visible after damage")

	units[2].set_selected(true)
	_check((units[2].get_node("SelectionRing") as MeshInstance3D).visible, "selection is represented by one cached ring mesh")
	units[2].set_targeted(true)
	_check(_count_nodes(units[2]) <= 8, "selection and target states do not exceed the eight-node budget")

	units[4].play_attack_animation()
	_check(units[4]._attack_animation_elapsed == 0.0, "role-specific attack animation triggers without a Tween node")
	if is_instance_valid(units[4]._combat_sprite):
		_check(units[4]._combat_sprite.is_playing(), "pixel attack animation starts on the animated sprite")

	var original_damage := units[4].attack_damage
	units[4].take_damage(1.0)
	_check(is_equal_approx(units[4].attack_damage, original_damage), "visual hit reaction does not alter combat damage")

	# The lethal probe must exceed the target's armor, not just its current health.
	units[5].take_damage(units[5].health + units[5].armor + 1.0)
	_check(not units[5].is_in_group("battle_units"), "defeated units leave the combat group immediately")
	_check(units[5]._is_corpse and units[5].is_processing(), "defeated units remain as short-lived battle corpses")

	for unit in units:
		if is_instance_valid(unit):
			unit.free()
	scene_root.free()

	if _failures > 0:
		printerr("Pixel-art unit visual smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All pixel-art visual and 50-unit budget tests passed.")
		quit(0)


func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total
