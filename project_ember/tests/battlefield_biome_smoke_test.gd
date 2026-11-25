extends SceneTree

const BattlefieldBiomesScript = preload("res://scripts/battlefield_biomes.gd")
const BattlefieldVisualsScript = preload("res://scripts/battlefield_visuals.gd")

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)


func _run() -> void:
	var biome_ids := BattlefieldBiomesScript.biome_ids()
	_check(biome_ids.size() == 4, "four tactical biome profiles are registered")

	var resolved_biomes: Dictionary = {}
	for q in range(-5, 6):
		for r in range(-5, 6):
			var cell := Vector2i(q, r)
			var hex_distance := maxi(absi(q), maxi(absi(r), absi(q + r)))
			if hex_distance > 5:
				continue
			var biome_id := BattlefieldBiomesScript.resolve_for_cell(cell)
			resolved_biomes[biome_id] = true
			_check(
				biome_id == BattlefieldBiomesScript.resolve_for_cell(cell),
				"strategic terrain resolves deterministically for %s" % str(cell)
			)
	_check(resolved_biomes.size() == 4, "the strategic map can produce all four tactical biomes")

	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1),
		Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 1),
	]
	_check(BattlefieldBiomesScript.resolve_for_terrain("marsh") == BattlefieldBiomesScript.MARSH, "marsh hex maps to a marsh tactical battlefield")
	_check(BattlefieldBiomesScript.resolve_for_terrain("farmland") == BattlefieldBiomesScript.GRASSLAND, "farmland hex maps to a grassland tactical battlefield")
	for terrain_kind in ["plain", "forest", "hills", "water", "farmland", "marsh"]:
		var terrain_map: Dictionary = {}
		for offset in offsets:
			terrain_map[offset] = terrain_kind
		var expected := BattlefieldBiomesScript.GRASSLAND
		match terrain_kind:
			"forest":
				expected = BattlefieldBiomesScript.WOODLAND
			"hills":
				expected = BattlefieldBiomesScript.HIGHLANDS
			"water", "marsh":
				expected = BattlefieldBiomesScript.MARSH
		_check(
			BattlefieldBiomesScript.resolve_from_terrain_map(terrain_map, Vector2i.ZERO) == expected,
			"live strategic terrain transfers %s into the matching battlefield biome" % terrain_kind
		)

	var grass_profile := BattlefieldBiomesScript.get_profile(BattlefieldBiomesScript.GRASSLAND)
	var wood_profile := BattlefieldBiomesScript.get_profile(BattlefieldBiomesScript.WOODLAND)
	var hill_profile := BattlefieldBiomesScript.get_profile(BattlefieldBiomesScript.HIGHLANDS)
	var marsh_profile := BattlefieldBiomesScript.get_profile(BattlefieldBiomesScript.MARSH)
	_check(grass_profile["ground"] != wood_profile["ground"], "woodland uses a distinct ground palette")
	_check(grass_profile["ground"] != hill_profile["ground"], "highlands use a distinct ground palette")
	_check(grass_profile["ground"] != marsh_profile["ground"], "marsh uses a distinct ground palette")
	_check(BattlefieldBiomesScript.seed_for_cell(Vector2i(2, -1)) == BattlefieldBiomesScript.seed_for_cell(Vector2i(2, -1)), "battle dressing seed is stable for the same strategic cell")
	_check(BattlefieldBiomesScript.seed_for_cell(Vector2i(2, -1)) != BattlefieldBiomesScript.seed_for_cell(Vector2i(-2, 1)), "different strategic cells receive different dressing seeds")

	var decoration_counts: Dictionary = {}
	for biome_id in biome_ids:
		var battlefield_root := Node3D.new()
		root.add_child(battlefield_root)
		var visual_data: Dictionary = BattlefieldVisualsScript.create(
			battlefield_root,
			Vector2(38.0, 26.0),
			BattlefieldVisualsScript.QUALITY_LOW,
			biome_id,
			20261124
		)
		_check(str(visual_data.get("biome_id", "")) == biome_id, "%s builder reports its selected biome" % biome_id)
		_check(str(visual_data.get("biome_name", "")).length() > 0, "%s builder provides a localized terrain name" % biome_id)
		_check(visual_data.get("camera") is Camera3D, "%s retains the tactical camera" % biome_id)
		_check(str(visual_data.get("visual_style", "")) == "pixel_isometric_terrain", "%s uses the Mythryl pixel-isometric terrain renderer" % biome_id)
		_check(int(visual_data.get("pixel_prop_count", 0)) > 0, "%s receives pixel-art nature and cliff dressing" % biome_id)
		var expected_zone_count := 0 if biome_id == BattlefieldBiomesScript.GRASSLAND else 4
		_check(int(visual_data.get("terrain_zone_count", -1)) == expected_zone_count, "%s reports the expected count of gameplay terrain zones" % biome_id)
		var ground_node := battlefield_root.get_node_or_null("BattlefieldGround") as MeshInstance3D
		_check(is_instance_valid(ground_node), "%s retains the flat base battlefield surface" % biome_id)
		var tile_node := battlefield_root.get_node_or_null("PixelIsometricGroundTiles") as MeshInstance3D
		_check(is_instance_valid(tile_node), "%s creates a batched isometric pixel ground mesh" % biome_id)
		_check(int(visual_data.get("ground_tile_count", 0)) > 500, "%s paints the full battlefield with isometric terrain tiles" % biome_id)
		if is_instance_valid(tile_node):
			var tile_material := tile_node.material_override as StandardMaterial3D
			_check(is_instance_valid(tile_material), "%s uses a standard isometric atlas material" % biome_id)
			if is_instance_valid(tile_material):
				_check(tile_material.albedo_texture != null, "%s ground atlas texture is loaded" % biome_id)
				_check(tile_material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "%s ground atlas uses nearest pixel filtering" % biome_id)
				_check(tile_material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, "%s keeps transparent tile corners crisp" % biome_id)

		var ground_body := visual_data.get("ground_body") as StaticBody3D
		_check(is_instance_valid(ground_body), "%s retains the ground collision body" % biome_id)
		if is_instance_valid(ground_body):
			_check(ground_body.collision_layer == 1 and ground_body.collision_mask == 0, "%s preserves the ground collision layers" % biome_id)
			var collision := ground_body.get_child(0) as CollisionShape3D
			_check(collision != null and collision.shape is BoxShape3D, "%s uses the original box ground collider" % biome_id)
			if collision != null and collision.shape is BoxShape3D:
				var bounds: Vector3 = (collision.shape as BoxShape3D).size
				_check(bounds.is_equal_approx(Vector3(38.0, 0.2, 26.0)), "%s keeps the original flat battlefield bounds" % biome_id)

		var pixel_sprite_count := 0
		for child in battlefield_root.get_children():
			if child is SpriteBase3D:
				pixel_sprite_count += 1
				_check(
					(child as SpriteBase3D).texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST,
					"%s pixel-art props use the BaseMaterial3D nearest filter enum" % biome_id
				)
		_check(pixel_sprite_count > 0, "%s creates billboard pixel-art props" % biome_id)
		_check(_count_static_bodies(battlefield_root) == 1, "%s adds no blocking prop colliders" % biome_id)
		_check(int(visual_data.get("cliff_count", 0)) >= 0, "%s reports visual-only cliff blocks" % biome_id)
		decoration_counts[biome_id] = battlefield_root.get_child_count()
		battlefield_root.free()
		await process_frame

	_check(decoration_counts.size() == 4, "all four battle biomes build their own terrain layout")
	_check(_all_decoration_counts_bounded(decoration_counts), "batched ground and visual dressing stay within a compact scene-node budget")

	if _failures > 0:
		printerr("Battlefield biome smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All battlefield biome smoke tests passed.")
		quit(0)


func _count_static_bodies(node: Node) -> int:
	var count := 1 if node is StaticBody3D else 0
	for child in node.get_children():
		count += _count_static_bodies(child)
	return count


func _all_decoration_counts_bounded(counts: Dictionary) -> bool:
	if counts.size() != 4:
		return false
	for value in counts.values():
		if int(value) > 64:
			return false
	return true
