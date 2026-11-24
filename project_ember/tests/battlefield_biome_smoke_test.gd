extends SceneTree

const BattlefieldBiomesScript = preload("res://scripts/battlefield_biomes.gd")
const BattlefieldVisualsScript = preload("res://scripts/battlefield_visuals.gd")
const VisualCacheScript = preload("res://scripts/visual_cache.gd")

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
	VisualCacheScript.clear()
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
	for terrain_kind in ["plain", "forest", "hills", "water"]:
		var terrain_map: Dictionary = {}
		for offset in offsets:
			terrain_map[offset] = terrain_kind
		var expected := BattlefieldBiomesScript.GRASSLAND
		match terrain_kind:
			"forest":
				expected = BattlefieldBiomesScript.WOODLAND
			"hills":
				expected = BattlefieldBiomesScript.HIGHLANDS
			"water":
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

		var ground_body := visual_data.get("ground_body") as StaticBody3D
		_check(is_instance_valid(ground_body), "%s retains the ground collision body" % biome_id)
		if is_instance_valid(ground_body):
			_check(ground_body.collision_layer == 1 and ground_body.collision_mask == 0, "%s preserves the ground collision layers" % biome_id)
			var collision := ground_body.get_child(0) as CollisionShape3D
			_check(collision != null and collision.shape is BoxShape3D, "%s uses the original box ground collider" % biome_id)
			if collision != null and collision.shape is BoxShape3D:
				var bounds: Vector3 = (collision.shape as BoxShape3D).size
				_check(bounds.is_equal_approx(Vector3(38.0, 0.2, 26.0)), "%s keeps the original flat battlefield bounds" % biome_id)

		_check(_count_static_bodies(battlefield_root) == 1, "%s adds no blocking prop colliders" % biome_id)
		decoration_counts[biome_id] = battlefield_root.get_child_count()
		battlefield_root.free()
		await process_frame

	_check(VisualCacheScript.get_texture_count() >= 4, "each biome ground texture is cached independently")
	_check(_all_decoration_counts_bounded(decoration_counts), "biome dressing stays within a compact scene-node budget")

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
		if int(value) > 36:
			return false
	return true
