extends RefCounted
class_name BattlefieldVisuals

const VisualCacheScript = preload("res://scripts/visual_cache.gd")
const Palette = preload("res://scripts/art_palette.gd")
const BattlefieldBiomesScript = preload("res://scripts/battlefield_biomes.gd")

const QUALITY_LOW := 0
const QUALITY_MEDIUM := 1
const QUALITY_HIGH := 2

## Lightweight, deterministic biome dressing. Terrain props are visual-only;
## the original flat ground collider and unit movement plane remain unchanged.
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
	ground.mesh = VisualCacheScript.cache_mesh_resource(ground_mesh)
	var ground_material := VisualCacheScript.get_material("battlefield:ground:" + selected_biome, func() -> Material:
		var material := StandardMaterial3D.new()
		material.albedo_texture = _make_ground_texture(selected_biome, profile)
		material.albedo_color = Palette.GROUND_TEXTURE_TINT
		material.roughness = 1.0
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		return material
	)
	ground.material_override = ground_material
	parent.add_child(ground)

	# Keep a single, unchanged flat collision surface for all tactical units.
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
	light.light_color = profile["ambient"].lerp(Palette.GOLD_LIGHT, 0.22)
	light.light_energy = 1.15 if selected_biome != BattlefieldBiomesScript.MARSH else 0.96
	light.shadow_enabled = quality >= QUALITY_MEDIUM
	light.directional_shadow_max_distance = 48.0 if quality == QUALITY_HIGH else 34.0
	parent.add_child(light)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 27.0
	camera.position = Vector3(0.0, 23.0, 16.0)
	parent.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true

	_add_ground_accents(parent, field_size, quality, profile, seed_value)
	_add_forest_edge(parent, field_size, quality, profile, seed_value + 120884)
	_add_biome_features(parent, field_size, quality, selected_biome, profile, seed_value + 297113)
	if quality >= QUALITY_MEDIUM and selected_biome != BattlefieldBiomesScript.MARSH:
		_add_ruins(parent, profile)

	return {
		"ground_body": ground_body,
		"camera": camera,
		"biome_id": selected_biome,
		"biome_name": str(profile.get("name", "Равнина")),
	}


static func _make_ground_texture(biome_id: String, profile: Dictionary) -> Texture2D:
	return VisualCacheScript.get_texture("battlefield:ground:noise128:" + biome_id, func() -> Texture2D:
		return _build_ground_texture(profile)
	)


static func _build_ground_texture(profile: Dictionary) -> Texture2D:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	var ground_color: Color = profile["ground"]
	var highlight_color: Color = profile["highlight"]
	for y in range(128):
		for x in range(128):
			var grain := float(posmod(x * 37 + y * 71 + x * y * 13, 97)) / 96.0
			var wave := sin(float(x + y) * 0.11) * 0.018
			var blend := clampf(0.22 + grain * 0.22 + wave, 0.08, 0.62)
			image.set_pixel(x, y, ground_color.lerp(highlight_color, blend))
	return ImageTexture.create_from_image(image)


static func _scaled_count(base_count: int, density: float) -> int:
	return maxi(0, roundi(float(base_count) * density))


static func _add_ground_accents(parent: Node3D, field_size: Vector2, quality: int, profile: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var dirt_mesh := CylinderMesh.new()
	dirt_mesh.top_radius = 0.62
	dirt_mesh.bottom_radius = 0.78
	dirt_mesh.height = 0.025
	dirt_mesh.radial_segments = 7
	var dirt_material := _material(profile["dirt"], 0.0, 1.0)
	var dirt_transforms: Array[Transform3D] = []
	var dirt_base := 12 if quality == QUALITY_LOW else (24 if quality == QUALITY_MEDIUM else 32)
	var dirt_count := _scaled_count(dirt_base, 1.0 if profile["id"] == BattlefieldBiomesScript.GRASSLAND else 0.82)
	for index in range(dirt_count):
		var x := rng.randf_range(-field_size.x * 0.45, field_size.x * 0.45)
		var z := rng.randf_range(-field_size.y * 0.43, field_size.y * 0.43)
		var scale := rng.randf_range(0.65, 1.55)
		dirt_transforms.append(Transform3D(Basis().scaled(Vector3(scale, 1.0, scale)), Vector3(x, 0.018, z)))
	_add_multimesh(parent, dirt_mesh, dirt_material, dirt_transforms)

	var grass_mesh := BoxMesh.new()
	grass_mesh.size = Vector3(0.075, 0.32, 0.055)
	var grass_material := _material(profile["grass"], 0.0, 0.95)
	var grass_transforms: Array[Transform3D] = []
	var grass_base := 38 if quality == QUALITY_LOW else (90 if quality == QUALITY_MEDIUM else 140)
	var grass_count := _scaled_count(grass_base, profile["grass_density"])
	for index in range(grass_count):
		var x := rng.randf_range(-field_size.x * 0.47, field_size.x * 0.47)
		var z := rng.randf_range(-field_size.y * 0.46, field_size.y * 0.46)
		var yaw := rng.randf_range(0.0, TAU)
		var scale := rng.randf_range(0.55, 1.15)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale, scale))
		grass_transforms.append(Transform3D(basis, Vector3(x, 0.15 * scale, z)))
	_add_multimesh(parent, grass_mesh, grass_material, grass_transforms)

	var stone_mesh := SphereMesh.new()
	stone_mesh.radius = 0.32
	stone_mesh.height = 0.45
	stone_mesh.radial_segments = 6
	stone_mesh.rings = 3
	var stone_material := _material(profile["stone"], 0.0, 1.0)
	var stone_transforms: Array[Transform3D] = []
	var stone_base := 8 if quality == QUALITY_LOW else (18 if quality == QUALITY_MEDIUM else 24)
	var stone_count := _scaled_count(stone_base, profile["stone_density"])
	for index in range(stone_count):
		var x := rng.randf_range(-field_size.x * 0.46, field_size.x * 0.46)
		var z := rng.randf_range(-field_size.y * 0.44, field_size.y * 0.44)
		if absf(x) < 8.0 and absf(z) < 8.0:
			continue
		var scale := rng.randf_range(0.55, 1.35)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale, scale * 0.72, scale))
		stone_transforms.append(Transform3D(basis, Vector3(x, 0.18 * scale, z)))
	_add_multimesh(parent, stone_mesh, stone_material, stone_transforms)


static func _add_forest_edge(parent: Node3D, field_size: Vector2, quality: int, profile: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tree_positions: Array[Vector2] = []
	var tree_base := 18 if quality == QUALITY_LOW else (38 if quality == QUALITY_MEDIUM else 52)
	var tree_count := _scaled_count(tree_base, profile["tree_density"])
	for index in range(tree_count):
		var x := rng.randf_range(-field_size.x * 0.48, field_size.x * 0.48)
		var z := rng.randf_range(-field_size.y * 0.47, field_size.y * 0.47)
		if absf(x) < 9.5 and absf(z) < 8.5:
			continue
		tree_positions.append(Vector2(x, z))

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.10
	trunk_mesh.bottom_radius = 0.16
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 6
	var trunk_material := _material(Palette.WOOD, 0.0, 1.0)
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.0
	crown_mesh.bottom_radius = 0.78
	crown_mesh.height = 1.75
	crown_mesh.radial_segments = 6
	var crown_material := _material(profile["tree"], 0.0, 0.95)
	var crown_light := _material(profile["tree_light"], 0.0, 0.95)
	var trunk_transforms: Array[Transform3D] = []
	var crown_transforms: Array[Transform3D] = []
	var crown_light_transforms: Array[Transform3D] = []
	for point in tree_positions:
		var scale := rng.randf_range(0.82, 1.28)
		var yaw := rng.randf_range(0.0, TAU)
		var trunk_basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale * 1.2, scale))
		trunk_transforms.append(Transform3D(trunk_basis, Vector3(point.x, scale * 0.58, point.y)))
		var crown_basis := Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale, scale))
		crown_transforms.append(Transform3D(crown_basis, Vector3(point.x, scale * 1.60, point.y)))
		crown_light_transforms.append(Transform3D(crown_basis.scaled(Vector3(0.68, 0.68, 0.68)), Vector3(point.x - 0.14 * scale, scale * 1.88, point.y - 0.10 * scale)))
	_add_multimesh(parent, trunk_mesh, trunk_material, trunk_transforms)
	_add_multimesh(parent, crown_mesh, crown_material, crown_transforms)
	_add_multimesh(parent, crown_mesh, crown_light, crown_light_transforms)


static func _add_biome_features(parent: Node3D, field_size: Vector2, quality: int, biome_id: String, profile: Dictionary, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	match biome_id:
		BattlefieldBiomesScript.WOODLAND:
			var log_mesh := BoxMesh.new()
			log_mesh.size = Vector3(1.35, 0.18, 0.22)
			var log_material := _material(profile["dirt"], 0.0, 1.0)
			var logs: Array[Transform3D] = []
			var log_count := 3 if quality == QUALITY_LOW else (7 if quality == QUALITY_MEDIUM else 10)
			for index in range(log_count):
				var point := _random_edge_point(rng, field_size)
				var yaw := rng.randf_range(0.0, TAU)
				var scale := rng.randf_range(0.7, 1.2)
				logs.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale, scale)), Vector3(point.x, 0.10, point.y)))
			_add_multimesh(parent, log_mesh, log_material, logs)
		BattlefieldBiomesScript.HIGHLANDS:
			_add_rock_shelves(parent, field_size, quality, profile, rng)
		BattlefieldBiomesScript.MARSH:
			_add_marsh_pools(parent, field_size, quality, profile, rng)


static func _random_edge_point(rng: RandomNumberGenerator, field_size: Vector2) -> Vector2:
	var point := Vector2.ZERO
	for attempt in range(8):
		point = Vector2(
			rng.randf_range(-field_size.x * 0.46, field_size.x * 0.46),
			rng.randf_range(-field_size.y * 0.43, field_size.y * 0.43)
		)
		if not (absf(point.x) < 9.0 and absf(point.y) < 8.0):
			return point
	return Vector2(signf(point.x) * field_size.x * 0.42, signf(point.y) * field_size.y * 0.40)


static func _add_rock_shelves(parent: Node3D, field_size: Vector2, quality: int, profile: Dictionary, rng: RandomNumberGenerator) -> void:
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.92
	rock_mesh.height = 1.05
	rock_mesh.radial_segments = 6
	rock_mesh.rings = 3
	var rock_material := _material(profile["stone"], 0.0, 1.0)
	var transforms: Array[Transform3D] = []
	var base_count := 5 if quality == QUALITY_LOW else (10 if quality == QUALITY_MEDIUM else 14)
	var count := _scaled_count(base_count, profile["rock_density"])
	for index in range(count):
		var point := _random_edge_point(rng, field_size)
		var scale := rng.randf_range(0.75, 1.5)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale, rng.randf_range(0.55, 0.95), scale))
		transforms.append(Transform3D(basis, Vector3(point.x, 0.30 * scale, point.y)))
	_add_multimesh(parent, rock_mesh, rock_material, transforms)


static func _add_marsh_pools(parent: Node3D, field_size: Vector2, quality: int, profile: Dictionary, rng: RandomNumberGenerator) -> void:
	var pool_mesh := CylinderMesh.new()
	pool_mesh.top_radius = 1.0
	pool_mesh.bottom_radius = 1.0
	pool_mesh.height = 0.022
	pool_mesh.radial_segments = 12
	var water_material := StandardMaterial3D.new()
	var water_color: Color = profile["water"]
	water_material.albedo_color = Color(water_color.r, water_color.g, water_color.b, 0.78)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.34
	water_material.metallic = 0.08
	var pools: Array[Transform3D] = []
	var pool_base := 3 if quality == QUALITY_LOW else (6 if quality == QUALITY_MEDIUM else 9)
	var pool_count := _scaled_count(pool_base, profile["pool_density"])
	for index in range(pool_count):
		var point := _random_edge_point(rng, field_size)
		var scale := rng.randf_range(0.75, 1.55)
		pools.append(Transform3D(Basis().scaled(Vector3(scale, 1.0, scale)), Vector3(point.x, 0.027, point.y)))
	_add_multimesh(parent, pool_mesh, water_material, pools)

	var reed_mesh := CylinderMesh.new()
	reed_mesh.top_radius = 0.012
	reed_mesh.bottom_radius = 0.028
	reed_mesh.height = 0.62
	reed_mesh.radial_segments = 5
	var reed_material := _material(Palette.MARSH_REED, 0.0, 0.9)
	var reeds: Array[Transform3D] = []
	var reed_base := 15 if quality == QUALITY_LOW else (32 if quality == QUALITY_MEDIUM else 48)
	var reed_count := _scaled_count(reed_base, profile["reed_density"])
	for index in range(reed_count):
		var point := _random_edge_point(rng, field_size)
		var scale := rng.randf_range(0.65, 1.25)
		var yaw := rng.randf_range(0.0, TAU)
		reeds.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(scale, scale, scale)), Vector3(point.x, 0.31 * scale, point.y)))
	_add_multimesh(parent, reed_mesh, reed_material, reeds)


static func _add_ruins(parent: Node3D, profile: Dictionary) -> void:
	var stone := _material(profile["stone"], 0.0, 1.0)
	var trim := _material(profile["dirt"].lightened(0.12), 0.0, 0.95)
	var positions := [
		Vector3(-17.0, 0.0, -10.2),
		Vector3(-15.8, 0.0, -10.0),
		Vector3(16.8, 0.0, 9.8),
		Vector3(15.5, 0.0, 10.2),
	]
	for index in range(positions.size()):
		var pillar := MeshInstance3D.new()
		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(0.72, 1.45 if index % 2 == 0 else 0.88, 0.72)
		pillar.mesh = VisualCacheScript.cache_mesh_resource(pillar_mesh)
		pillar.position = positions[index] + Vector3(0.0, pillar_mesh.size.y * 0.5, 0.0)
		pillar.rotation.y = float(index) * 0.31
		pillar.material_override = stone
		parent.add_child(pillar)
		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(0.88, 0.16, 0.88)
		cap.mesh = VisualCacheScript.cache_mesh_resource(cap_mesh)
		cap.position = pillar.position + Vector3(0.0, pillar_mesh.size.y * 0.5 + 0.06, 0.0)
		cap.material_override = trim
		parent.add_child(cap)


static func _add_multimesh(parent: Node3D, mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = VisualCacheScript.cache_mesh_resource(mesh)
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	parent.add_child(instance)


static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var key := "battlefield:%02x%02x%02x:%02d:%02d" % [roundi(color.r * 255.0), roundi(color.g * 255.0), roundi(color.b * 255.0), roundi(metallic * 100.0), roundi(roughness * 100.0)]
	return VisualCacheScript.get_material(key, func() -> Material:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.metallic = metallic
		material.roughness = roughness
		return material
	) as StandardMaterial3D
