extends RefCounted
class_name BattlefieldVisuals

## Lightweight, procedural battlefield dressing for Project Ember.
## Everything is generated from meshes/materials at runtime; no external asset packs.

static func create(parent: Node3D, field_size: Vector2) -> Dictionary:
	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = field_size
	ground.mesh = ground_mesh
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_texture = _make_ground_texture()
	ground_material.albedo_color = Color(0.82, 0.91, 0.73)
	ground_material.roughness = 1.0
	ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	ground.material_override = ground_material
	parent.add_child(ground)

	var ground_body := StaticBody3D.new()
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
	environment.background_color = Color(0.12, 0.16, 0.14)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.70, 0.77, 0.68)
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	parent.add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	light.light_color = Color(1.0, 0.88, 0.70)
	light.light_energy = 1.15
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 48.0
	parent.add_child(light)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 27.0
	camera.position = Vector3(0.0, 23.0, 16.0)
	parent.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true

	_add_ground_accents(parent, field_size)
	_add_forest_edge(parent, field_size)
	_add_ruins(parent)
	return {"ground_body": ground_body, "camera": camera}


static func _make_ground_texture() -> Texture2D:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		for x in range(128):
			var grain := float(posmod(x * 37 + y * 71 + x * y * 13, 97)) / 96.0
			var wave := sin(float(x + y) * 0.11) * 0.018
			var shade := (grain - 0.5) * 0.075 + wave
			var green := clampf(0.30 + shade, 0.0, 1.0)
			image.set_pixel(x, y, Color(0.19 + shade * 0.62, green, 0.15 + shade * 0.48, 1.0))
	return ImageTexture.create_from_image(image)


static func _add_ground_accents(parent: Node3D, field_size: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 841207
	var dirt_mesh := CylinderMesh.new()
	dirt_mesh.top_radius = 0.62
	dirt_mesh.bottom_radius = 0.78
	dirt_mesh.height = 0.025
	dirt_mesh.radial_segments = 7
	var dirt_material := _material(Color(0.30, 0.25, 0.16), 0.0, 1.0)
	var dirt_transforms: Array[Transform3D] = []
	for index in range(24):
		var x := rng.randf_range(-field_size.x * 0.45, field_size.x * 0.45)
		var z := rng.randf_range(-field_size.y * 0.43, field_size.y * 0.43)
		var scale := rng.randf_range(0.65, 1.55)
		dirt_transforms.append(Transform3D(Basis().scaled(Vector3(scale, 1.0, scale)), Vector3(x, 0.018, z)))
	_add_multimesh(parent, dirt_mesh, dirt_material, dirt_transforms)

	var grass_mesh := BoxMesh.new()
	grass_mesh.size = Vector3(0.075, 0.32, 0.055)
	var grass_material := _material(Color(0.40, 0.53, 0.27), 0.0, 0.95)
	var grass_transforms: Array[Transform3D] = []
	for index in range(115):
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
	var stone_material := _material(Color(0.34, 0.36, 0.32), 0.0, 1.0)
	var stone_transforms: Array[Transform3D] = []
	for index in range(20):
		var x := rng.randf_range(-field_size.x * 0.46, field_size.x * 0.46)
		var z := rng.randf_range(-field_size.y * 0.44, field_size.y * 0.44)
		if absf(x) < 8.0 and absf(z) < 8.0:
			continue
		var scale := rng.randf_range(0.55, 1.35)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale, scale * 0.72, scale))
		stone_transforms.append(Transform3D(basis, Vector3(x, 0.18 * scale, z)))
	_add_multimesh(parent, stone_mesh, stone_material, stone_transforms)


static func _add_forest_edge(parent: Node3D, field_size: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 120884
	var tree_positions: Array[Vector2] = []
	for index in range(42):
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
	var trunk_material := _material(Color(0.27, 0.17, 0.10), 0.0, 1.0)
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.0
	crown_mesh.bottom_radius = 0.78
	crown_mesh.height = 1.75
	crown_mesh.radial_segments = 6
	var crown_material := _material(Color(0.16, 0.31, 0.17), 0.0, 0.95)
	var crown_light := _material(Color(0.25, 0.42, 0.20), 0.0, 0.95)
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


static func _add_ruins(parent: Node3D) -> void:
	var stone := _material(Color(0.39, 0.40, 0.36), 0.0, 1.0)
	var trim := _material(Color(0.53, 0.48, 0.36), 0.0, 0.95)
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
		pillar.mesh = pillar_mesh
		pillar.position = positions[index] + Vector3(0.0, pillar_mesh.size.y * 0.5, 0.0)
		pillar.rotation.y = float(index) * 0.31
		pillar.material_override = stone
		parent.add_child(pillar)
		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(0.88, 0.16, 0.88)
		cap.mesh = cap_mesh
		cap.position = pillar.position + Vector3(0.0, pillar_mesh.size.y * 0.5 + 0.06, 0.0)
		cap.material_override = trim
		parent.add_child(cap)


static func _add_multimesh(parent: Node3D, mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	parent.add_child(instance)


static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material
