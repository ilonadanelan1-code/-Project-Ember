extends RefCounted
class_name BattlefieldVisuals

const Palette = preload("res://scripts/art_palette.gd")
const BattlefieldBiomesScript = preload("res://scripts/battlefield_biomes.gd")
const BattlefieldZoneVisualsScript = preload("res://scripts/battlefield_zone_visuals.gd")

const QUALITY_LOW := 0
const QUALITY_MEDIUM := 1
const QUALITY_HIGH := 2

const TERRAIN_ROOT := "res://assets/combat/mythryl_pixel_terrain/64px"
const GROUND_ATLAS_PATH := "res://assets/combat/mythryl_pixel_terrain/ground_atlas_64.png"
const GROUND_MANIFEST_PATH := "res://assets/combat/mythryl_pixel_terrain/ground_atlas_manifest.json"
const ATLAS_WIDTH := 512.0
const ATLAS_HEIGHT := 512.0
const ATLAS_COLUMNS := 8
const TILE_PIXEL_WIDTH := 64.0
const TILE_PIXEL_HEIGHT := 32.0
const TILE_WORLD_WIDTH := 2.0
const TILE_WORLD_HEIGHT := 1.0
const GROUND_Y := 0.035
const GROUND_CARDINAL_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
]
const WATER_NEIGHBOURS: Array[Dictionary] = [
	{"offset": Vector2i(0, -1), "bit": 1},
	{"offset": Vector2i(1, -1), "bit": 2},
	{"offset": Vector2i(1, 0), "bit": 4},
	{"offset": Vector2i(1, 1), "bit": 8},
	{"offset": Vector2i(0, 1), "bit": 16},
	{"offset": Vector2i(-1, 1), "bit": 32},
	{"offset": Vector2i(-1, 0), "bit": 64},
	{"offset": Vector2i(-1, -1), "bit": 128},
]

static var _ground_atlas: Texture2D
static var _ground_slots: Dictionary = {}
static var _coast_slots: Dictionary = {}


## Tactical movement and collision remain on the original flat 3D plane.
## The ground art is a single batched isometric mesh; nature and cliff sprites are visual-only.
static func create(
		parent: Node3D,
		field_size: Vector2,
		quality: int = QUALITY_MEDIUM,
		biome_id: String = BattlefieldBiomesScript.GRASSLAND,
		seed_value: int = 841207
) -> Dictionary:
	var selected_biome := biome_id if BattlefieldBiomesScript.biome_ids().has(biome_id) else BattlefieldBiomesScript.GRASSLAND
	var profile := BattlefieldBiomesScript.get_profile(selected_biome)

	var ground := MeshInstance3D.new()
	ground.name = "BattlefieldGround"
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = field_size
	ground.mesh = ground_mesh
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = _get_base_ground_color(selected_biome)
	ground_material.roughness = 1.0
	ground_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	ground.material_override = ground_material
	ground.position.y = -0.025
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ground)

	# Keep the exact original movement collider and collision layers.
	var ground_body := StaticBody3D.new()
	ground_body.name = "BattlefieldGroundBody"
	ground_body.collision_layer = 1
	ground_body.collision_mask = 0
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(field_size.x, 0.2, field_size.y)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.1
	ground_body.add_child(ground_collision)
	parent.add_child(ground_body)

	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = profile["sky"]
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = profile["ambient"]
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	parent.add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	light.light_color = profile["ambient"].lerp(Palette.GOLD_LIGHT, 0.18)
	light.light_energy = 0.96
	light.shadow_enabled = false
	parent.add_child(light)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 27.0
	camera.position = Vector3(0.0, 23.0, 16.0)
	parent.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true

	var tile_count := _build_isometric_ground(parent, field_size, selected_biome, seed_value)
	var prop_count := _add_nature_props(parent, field_size, quality, selected_biome, seed_value + 501173)
	var cliff_count := _add_cliff_blocks(parent, field_size, quality, selected_biome, seed_value + 918227)
	var terrain_zone_count := BattlefieldZoneVisualsScript.add_to(parent, selected_biome, field_size, seed_value)

	return {
		"ground_body": ground_body,
		"camera": camera,
		"biome_id": selected_biome,
		"biome_name": str(profile.get("name", "Равнина")),
		"visual_style": "pixel_isometric_terrain",
		"ground_tile_count": tile_count,
		"pixel_prop_count": prop_count + cliff_count,
		"cliff_count": cliff_count,
		"terrain_zone_count": terrain_zone_count,
	}


static func _get_base_ground_color(biome_id: String) -> Color:
	match biome_id:
		BattlefieldBiomesScript.WOODLAND:
			return Color(0.10, 0.25, 0.16, 1.0)
		BattlefieldBiomesScript.HIGHLANDS:
			return Color(0.20, 0.24, 0.23, 1.0)
		BattlefieldBiomesScript.MARSH:
			return Color(0.15, 0.25, 0.20, 1.0)
		_:
			return Color(0.12, 0.30, 0.18, 1.0)


static func _load_ground_manifest() -> bool:
	if not _ground_slots.is_empty() and not _coast_slots.is_empty() and is_instance_valid(_ground_atlas):
		return true
	var manifest_file := FileAccess.open(GROUND_MANIFEST_PATH, FileAccess.READ)
	if manifest_file == null:
		push_error("Battlefield terrain atlas manifest is missing: " + GROUND_MANIFEST_PATH)
		return false
	var parsed: Variant = JSON.parse_string(manifest_file.get_as_text())
	if not (parsed is Dictionary):
		push_error("Battlefield terrain atlas manifest is invalid JSON.")
		return false
	var slots_value: Variant = parsed.get("slots", {})
	var coasts_value: Variant = parsed.get("coast_masks", {})
	if not (slots_value is Dictionary) or not (coasts_value is Dictionary):
		push_error("Battlefield terrain atlas manifest does not contain slot maps.")
		return false
	_ground_slots = slots_value.duplicate(true)
	_coast_slots = coasts_value.duplicate(true)
	_ground_atlas = load(GROUND_ATLAS_PATH) as Texture2D
	if not is_instance_valid(_ground_atlas):
		push_error("Battlefield terrain atlas could not be loaded: " + GROUND_ATLAS_PATH)
		return false
	return true


static func _build_isometric_ground(
		parent: Node3D,
		field_size: Vector2,
		biome_id: String,
		seed_value: int
) -> int:
	if not _load_ground_manifest():
		return 0

	var half_width := field_size.x * 0.5
	var half_depth := field_size.y * 0.5
	var grid_limit := ceili(half_width + half_depth + 4.0)
	var cells: Array[Dictionary] = []
	var terrain_lookup: Dictionary = {}

	# The tile lattice matches Mythryl's 64x32 isometric ground geometry:
	# col step (+1, +0.5), row step (-1, +0.5) in battlefield units.
	for col in range(-grid_limit, grid_limit + 1):
		for row in range(-grid_limit, grid_limit + 1):
			var center := Vector2(float(col - row), float(col + row) * 0.5)
			if absf(center.x) > half_width + 1.1 or absf(center.y) > half_depth + 0.6:
				continue
			var cell := Vector2i(col, row)
			var terrain_kind := _classify_ground(center, biome_id)
			terrain_lookup[cell] = terrain_kind
			cells.append({"cell": cell, "center": center, "kind": terrain_kind})

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell_data in cells:
		var cell: Vector2i = cell_data["cell"]
		var center: Vector2 = cell_data["center"]
		var kind := str(cell_data["kind"])
		var tile_slot := _select_ground_slot(cell, kind, terrain_lookup, seed_value)
		_append_ground_quad(surface, center, tile_slot)

	surface.index()
	var mesh := surface.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		push_error("Isometric battlefield ground mesh could not be built.")
		return 0

	var material := StandardMaterial3D.new()
	material.albedo_texture = _ground_atlas
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PixelIsometricGroundTiles"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position.y = GROUND_Y
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)
	return cells.size()


static func _classify_ground(world_position: Vector2, biome_id: String) -> String:
	# A gently winding old road with two short spurs gives the ground a readable layout.
	var road_center := sin(world_position.x * 0.205) * 1.08 + world_position.x * 0.025
	var road_edge_noise := sin(world_position.x * 0.48 + world_position.y * 0.37) * 0.12
	var road_width := 0.62
	match biome_id:
		BattlefieldBiomesScript.WOODLAND:
			road_width = 0.52
		BattlefieldBiomesScript.HIGHLANDS:
			road_width = 0.76
		BattlefieldBiomesScript.MARSH:
			road_width = 0.60

	# Marsh water is kept to the far corner of the battlefield so it frames the arena
	# without covering the normal army deployment and engagement lanes.
	if biome_id == BattlefieldBiomesScript.MARSH:
		var pond := Vector2((world_position.x - 14.0) / 4.0, (world_position.y + 8.0) / 2.8)
		var edge_noise := sin(world_position.x * 0.72 + world_position.y * 0.91) * 0.055
		if pond.length_squared() + edge_noise < 0.88:
			return "water"

	# Biome-specific clearings and small worn patches break the repeated grass pattern.
	match biome_id:
		BattlefieldBiomesScript.GRASSLAND:
			var meadow_clearing := Vector2((world_position.x + 8.0) / 2.8, (world_position.y - 4.2) / 1.9)
			if meadow_clearing.length_squared() < 0.88:
				return "dirt"
		BattlefieldBiomesScript.WOODLAND:
			var forest_clearing := Vector2((world_position.x - 7.8) / 2.4, (world_position.y + 5.6) / 1.7)
			if forest_clearing.length_squared() < 0.82:
				return "dirt"
		BattlefieldBiomesScript.HIGHLANDS:
			var stony_patch := Vector2((world_position.x + 7.0) / 2.5, (world_position.y - 5.2) / 1.8)
			if stony_patch.length_squared() < 0.90:
				return "dirt"
	# A pair of branch paths fades into the outer clearings, away from deployment edges.
	if world_position.x > -10.0 and world_position.x < -2.0:
		var branch_a := road_center - 1.20 + (world_position.x + 10.0) * 0.68
		if absf(world_position.y - branch_a) < 0.38:
			return "dirt"
	if world_position.x > 6.0 and world_position.x < 13.5:
		var branch_b := road_center + 1.15 - (world_position.x - 6.0) * 0.82
		if absf(world_position.y - branch_b) < 0.38:
			return "dirt"
	if absf(world_position.y - road_center) < road_width + road_edge_noise:
		return "dirt"
	# Four small edge clearings add irregular dirt/grass transitions on every biome.
	var edge_patches: Array[Vector3] = [
		Vector3(-13.2, -7.8, 1.8),
		Vector3(13.8, 7.8, 1.65),
		Vector3(-13.8, 7.5, 1.35),
		Vector3(13.2, -7.5, 1.5),
	]
	for patch in edge_patches:
		var patch_position := Vector2(patch.x, patch.y)
		var patch_scale := Vector2(patch.z, patch.z * 0.68)
		var patch_delta := (world_position - patch_position) / patch_scale
		var patch_noise := sin(world_position.x * 0.92 + world_position.y * 0.77) * 0.075
		if patch_delta.length_squared() < 1.0 + patch_noise:
			return "dirt"
	return "grass"


static func _select_ground_slot(
		cell: Vector2i,
		kind: String,
		terrain_lookup: Dictionary,
		seed_value: int
) -> int:
	if kind == "water":
		return _slot_for_variant("shallow", cell, seed_value, 4)
	if kind == "dirt":
		return _slot_for_variant("dirt", cell, seed_value, 4)

	var water_mask := 0
	for neighbour in WATER_NEIGHBOURS:
		var neighbour_cell: Vector2i = cell + neighbour["offset"]
		if str(terrain_lookup.get(neighbour_cell, "")) == "water":
			water_mask |= int(neighbour["bit"])
	if water_mask > 0:
		var coast_slot := int(_coast_slots.get(str(water_mask), -1))
		if coast_slot >= 0:
			return coast_slot

	var dirt_mask := 0
	for index in range(GROUND_CARDINAL_OFFSETS.size()):
		var neighbour_cell: Vector2i = cell + GROUND_CARDINAL_OFFSETS[index]
		if str(terrain_lookup.get(neighbour_cell, "")) == "dirt":
			dirt_mask |= 1 << index
	if dirt_mask > 0:
		var edge_key := "edge_%02d" % dirt_mask
		if _ground_slots.has(edge_key):
			return int(_ground_slots[edge_key])
	return _slot_for_variant("grass", cell, seed_value, 4)


static func _slot_for_variant(prefix: String, cell: Vector2i, seed_value: int, variant_count: int) -> int:
	var hash_value := absi(cell.x * 73856093 + cell.y * 19349663 + seed_value * 8349271)
	var variant := posmod(hash_value, variant_count) + 1
	var slot_key := "%s_%d" % [prefix, variant]
	return int(_ground_slots.get(slot_key, 0))


static func _append_ground_quad(surface: SurfaceTool, center: Vector2, slot: int) -> void:
	var atlas_col := posmod(slot, ATLAS_COLUMNS)
	var atlas_row := floori(float(slot) / float(ATLAS_COLUMNS))
	var u0 := (float(atlas_col) * TILE_PIXEL_WIDTH + 0.25) / ATLAS_WIDTH
	var u1 := (float(atlas_col + 1) * TILE_PIXEL_WIDTH - 0.25) / ATLAS_WIDTH
	var v0 := (float(atlas_row) * TILE_PIXEL_HEIGHT + 0.25) / ATLAS_HEIGHT
	var v1 := (float(atlas_row + 1) * TILE_PIXEL_HEIGHT - 0.25) / ATLAS_HEIGHT
	var left_back := Vector3(center.x - TILE_WORLD_WIDTH * 0.5, 0.0, center.y - TILE_WORLD_HEIGHT * 0.5)
	var right_back := Vector3(center.x + TILE_WORLD_WIDTH * 0.5, 0.0, center.y - TILE_WORLD_HEIGHT * 0.5)
	var right_front := Vector3(center.x + TILE_WORLD_WIDTH * 0.5, 0.0, center.y + TILE_WORLD_HEIGHT * 0.5)
	var left_front := Vector3(center.x - TILE_WORLD_WIDTH * 0.5, 0.0, center.y + TILE_WORLD_HEIGHT * 0.5)

	# Counter-clockwise from above, so the surface normal points upward.
	surface.set_normal(Vector3.UP)
	surface.set_uv(Vector2(u0, v0))
	surface.add_vertex(left_back)
	surface.set_normal(Vector3.UP)
	surface.set_uv(Vector2(u1, v1))
	surface.add_vertex(right_front)
	surface.set_normal(Vector3.UP)
	surface.set_uv(Vector2(u1, v0))
	surface.add_vertex(right_back)

	surface.set_normal(Vector3.UP)
	surface.set_uv(Vector2(u0, v0))
	surface.add_vertex(left_back)
	surface.set_normal(Vector3.UP)
	surface.set_uv(Vector2(u0, v1))
	surface.add_vertex(left_front)
	surface.set_normal(Vector3.UP)
	surface.set_uv(Vector2(u1, v1))
	surface.add_vertex(right_front)


static func _add_nature_props(
		parent: Node3D,
		field_size: Vector2,
		quality: int,
		biome_id: String,
		seed_value: int
) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tree_count := 10 if quality == QUALITY_LOW else (16 if quality == QUALITY_MEDIUM else 23)
	var bush_count := 5 if quality == QUALITY_LOW else (9 if quality == QUALITY_MEDIUM else 14)
	var rock_count := 6 if quality == QUALITY_LOW else (10 if quality == QUALITY_MEDIUM else 15)
	var flower_count := 8 if quality == QUALITY_LOW else (14 if quality == QUALITY_MEDIUM else 22)
	match biome_id:
		BattlefieldBiomesScript.WOODLAND:
			tree_count += 7
			bush_count += 4
			flower_count = maxi(5, flower_count - 3)
		BattlefieldBiomesScript.HIGHLANDS:
			tree_count = maxi(5, tree_count - 5)
			rock_count += 7
			flower_count = maxi(4, flower_count - 5)
		BattlefieldBiomesScript.MARSH:
			tree_count = maxi(5, tree_count - 3)
			bush_count += 4

	var added := 0
	for index in range(tree_count):
		var point := _random_edge_position(rng, field_size, 3.2, 2.8)
		var is_pine := biome_id == BattlefieldBiomesScript.WOODLAND or (biome_id == BattlefieldBiomesScript.HIGHLANDS and index % 2 == 0)
		var texture_path := "%s/nature/trees/common-tree-1/common-tree-1_%d.png" % [TERRAIN_ROOT, _random_turn(rng)]
		var pivot_y := 218.0
		var world_height := 5.4
		if is_pine:
			texture_path = "%s/nature/trees/pine-1/pine-1_%d.png" % [TERRAIN_ROOT, _random_turn(rng)]
			pivot_y = 239.0
			world_height = 6.4
		added += int(_add_nature_sprite(parent, "TerrainTree", texture_path, point, world_height, pivot_y, rng.randf_range(0.84, 1.12)))

	for index in range(bush_count):
		var point := _random_edge_position(rng, field_size, 1.8, 1.5)
		var texture_path := "%s/nature/bushes/bush-common/bush-common_%d.png" % [TERRAIN_ROOT, _random_turn(rng)]
		added += int(_add_nature_sprite(parent, "TerrainBush", texture_path, point, 1.1, 48.0, rng.randf_range(0.82, 1.18)))

	for index in range(rock_count):
		var point := _random_edge_position(rng, field_size, 1.4, 1.2)
		var texture_path := "%s/nature/rocks/rock-medium-1/rock-medium-1_%d.png" % [TERRAIN_ROOT, _random_turn(rng)]
		added += int(_add_nature_sprite(parent, "TerrainRock", texture_path, point, 1.3, 68.0, rng.randf_range(0.78, 1.15)))

	for index in range(flower_count):
		var point := Vector2(
			rng.randf_range(-field_size.x * 0.43, field_size.x * 0.43),
			rng.randf_range(-field_size.y * 0.40, field_size.y * 0.40)
		)
		if absf(point.x) < 10.5 and absf(point.y) < 6.8:
			continue
		var texture_path := "%s/nature/flowers/flower-patch-mixed/flower-patch-mixed_%d.png" % [TERRAIN_ROOT, _random_turn(rng)]
		added += int(_add_nature_sprite(parent, "TerrainFlowers", texture_path, point, 0.3, 28.0, rng.randf_range(0.9, 1.2)))
	return added


static func _random_edge_position(rng: RandomNumberGenerator, field_size: Vector2, band_x: float, band_z: float) -> Vector2:
	var half_width := field_size.x * 0.5
	var half_depth := field_size.y * 0.5
	for _attempt in range(24):
		var point := Vector2(
			rng.randf_range(-half_width + 1.2, half_width - 1.2),
			rng.randf_range(-half_depth + 1.0, half_depth - 1.0)
		)
		match rng.randi_range(0, 3):
			0:
				point.x = -half_width + rng.randf_range(0.6, band_x)
			1:
				point.x = half_width - rng.randf_range(0.6, band_x)
			2:
				point.y = -half_depth + rng.randf_range(0.6, band_z)
			_:
				point.y = half_depth - rng.randf_range(0.6, band_z)
		if absf(point.x) > 11.5 or absf(point.y) > 7.3:
			return point
	return Vector2(-half_width + 1.5, -half_depth + 1.5)


static func _random_turn(rng: RandomNumberGenerator) -> int:
	return [0, 90, 180, 270][rng.randi_range(0, 3)]


static func _add_nature_sprite(
		parent: Node3D,
		node_name: String,
		texture_path: String,
		ground_position: Vector2,
		world_height: float,
		pivot_y: float,
		scale_value: float = 1.0
) -> bool:
	var texture := load(texture_path) as Texture2D
	if not is_instance_valid(texture):
		push_warning("BattlefieldVisuals: missing Mythryl terrain sprite %s" % texture_path)
		return false
	var sprite := Sprite3D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.pixel_size = world_height / float(texture.get_height())
	sprite.offset = Vector2.ZERO
	sprite.scale = Vector3.ONE * scale_value
	var pivot_lift := (pivot_y - float(texture.get_height()) * 0.5) * sprite.pixel_size * scale_value
	sprite.position = Vector3(ground_position.x, GROUND_Y + pivot_lift, ground_position.y)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.transparent = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sprite)
	return true


static func _add_cliff_blocks(
		parent: Node3D,
		field_size: Vector2,
		quality: int,
		biome_id: String,
		seed_value: int
) -> int:
	if biome_id == BattlefieldBiomesScript.MARSH:
		return 0
	var count := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var block_count := 2 if quality == QUALITY_LOW else (4 if quality == QUALITY_MEDIUM else 6)
	if biome_id == BattlefieldBiomesScript.HIGHLANDS:
		block_count += 3
	elif biome_id == BattlefieldBiomesScript.WOODLAND:
		block_count = maxi(1, block_count - 1)
	var texture_path := "%s/cliffs/crags/grass/crags-grass_full_1.png" % TERRAIN_ROOT
	for index in range(block_count):
		var position := _random_edge_position(rng, field_size, 3.4, 3.0)
		count += int(_add_cliff_sprite(parent, texture_path, position, rng.randf_range(0.86, 1.16)))
	return count


static func _add_cliff_sprite(parent: Node3D, texture_path: String, ground_position: Vector2, scale_value: float) -> bool:
	var texture := load(texture_path) as Texture2D
	if not is_instance_valid(texture):
		push_warning("BattlefieldVisuals: missing cliff tile %s" % texture_path)
		return false
	var sprite := Sprite3D.new()
	sprite.name = "IsometricGrassCliff"
	sprite.texture = texture
	sprite.pixel_size = TILE_WORLD_WIDTH / TILE_PIXEL_WIDTH
	sprite.offset = Vector2.ZERO
	sprite.scale = Vector3.ONE * scale_value
	var pivot_lift := float(texture.get_height()) * 0.5 * sprite.pixel_size * scale_value
	sprite.position = Vector3(ground_position.x, GROUND_Y + pivot_lift, ground_position.y)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.transparent = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sprite)
	return true
