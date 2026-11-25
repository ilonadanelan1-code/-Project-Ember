extends RefCounted
class_name BattleUnitVisuals

const VisualCacheScript = preload("res://scripts/visual_cache.gd")
const Palette = preload("res://scripts/art_palette.gd")

# Numeric role IDs mirror the battle unit enum. Keep this mapping local to
# avoid a cyclic script preload between the unit and its visual builder.
enum UnitRole { MELEE = 0, RANGED = 1, SPEAR = 2, CAVALRY = 3, COMMANDER = 4 }

## Legacy procedural 3D prototype retained for resource experiments only.
## Not a permitted runtime renderer for Project Ember combat units; production units use pixel-art SpriteFrames.

static func build(team: int, role: int) -> Node3D:
	var forward := 1.0 if team == 0 else -1.0
	var action_pivot := Vector3(forward * 0.40, 1.03, 0.0)
	if role == UnitRole.CAVALRY:
		action_pivot = Vector3(forward * 0.34, 1.53, 0.12)
	elif role == UnitRole.COMMANDER:
		action_pivot = Vector3(-forward * 0.30, 2.08, -0.32)

	var parts: Dictionary = {
		"body": [],
		"action": [],
		"action_pivot": action_pivot,
	}

	if role == UnitRole.CAVALRY:
		_build_cavalry(parts, team, forward)
	else:
		_build_infantry(parts, team, role, forward)

	match role:
		UnitRole.MELEE:
			_add_sword_and_shield(parts, forward)
		UnitRole.RANGED:
			_add_archer_gear(parts, forward)
		UnitRole.SPEAR:
			_add_spear_gear(parts, forward)
		UnitRole.CAVALRY:
			_add_cavalry_weapon(parts, forward)
		UnitRole.COMMANDER:
			_add_commander_banner(parts, team, forward)

	var root := Node3D.new()
	root.name = "VisualRoot"

	var vertex_material := _get_vertex_material()
	var body_mesh := MeshInstance3D.new()
	body_mesh.name = "BodyMesh"
	body_mesh.mesh = VisualCacheScript.get_mesh(
		"unit:merged:v3:%d:%d:body" % [team, role],
		func() -> Mesh:
			return _build_merged_mesh(parts["body"])
	)
	body_mesh.material_override = vertex_material
	root.add_child(body_mesh)

	var action_mesh := MeshInstance3D.new()
	action_mesh.name = "ActionMesh"
	action_mesh.position = action_pivot
	action_mesh.mesh = VisualCacheScript.get_mesh(
		"unit:merged:v3:%d:%d:action" % [team, role],
		func() -> Mesh:
			return _build_merged_mesh(parts["action"])
	)
	action_mesh.material_override = vertex_material
	root.add_child(action_mesh)

	return root


static func get_hit_flash_material() -> Material:
	return VisualCacheScript.get_material("unit:hit_flash:shared", func() -> Material:
		var material := StandardMaterial3D.new()
		material.albedo_color = Palette.UNIT_HIT_FLASH
		material.emission_enabled = true
		material.emission = Palette.UNIT_HIT_FLASH_GLOW
		material.emission_energy_multiplier = 0.65
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return material
	)


static func _get_vertex_material() -> Material:
	return VisualCacheScript.get_material("unit:vertex_colour:shared", func() -> Material:
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.metallic = 0.18
		material.roughness = 0.76
		return material
	)


static func _build_infantry(parts: Dictionary, team: int, role: int, forward: float) -> void:
	var commander := role == UnitRole.COMMANDER
	var scale := 1.10 if commander else 1.0
	var cloth := Palette.PLAYER_CLOTH if team == 0 else Palette.ENEMY_CLOTH
	var cloth_light := Palette.PLAYER_CLOTH_LIGHT if team == 0 else Palette.ENEMY_CLOTH_LIGHT
	var metal := Palette.METAL
	var shoulder_color := Palette.GOLD if commander else Palette.METAL
	var skin := Palette.SKIN
	var boots := Palette.METAL_DARK

	_add_part(parts, "body", _capsule(0.34 * scale, 0.94 * scale, 7, 3), cloth, Vector3(0.0, 1.03 * scale, 0.0))
	_add_part(parts, "body", _box(Vector3(0.62, 0.28, 0.44) * scale), cloth_light, Vector3(0.0, 0.68 * scale, 0.0))
	_add_part(parts, "body", _box(Vector3(0.49, 0.55, 0.075) * scale), metal, Vector3(0.0, 1.08 * scale, 0.25 * scale))
	_add_part(parts, "body", _box(Vector3(0.58, 0.10, 0.48) * scale), Palette.WOOD, Vector3(0.0, 0.79 * scale, 0.0))
	_add_part(parts, "body", _sphere(0.20 * scale, 0.40 * scale, 8, 4), skin, Vector3(0.0, 1.72 * scale, 0.0))

	match role:
		UnitRole.RANGED:
			_add_part(parts, "body", _sphere(0.22 * scale, 0.22 * scale, 7, 3), Palette.WOOD.lightened(0.12), Vector3(0.0, 1.87 * scale, 0.0))
			_add_part(parts, "body", _box(Vector3(0.28, 0.055, 0.12) * scale), Palette.GOLD, Vector3(0.0, 1.91 * scale, 0.02))
		UnitRole.SPEAR:
			_add_part(parts, "body", _cylinder(0.13 * scale, 0.22 * scale, 0.18 * scale, 7), metal, Vector3(0.0, 1.91 * scale, 0.0))
			_add_part(parts, "body", _cylinder(0.012, 0.045, 0.34, 5), Palette.REWARD, Vector3(0.0, 2.13 * scale, 0.0))
		UnitRole.COMMANDER:
			_add_part(parts, "body", _cylinder(0.14 * scale, 0.23 * scale, 0.17 * scale, 8), Palette.GOLD, Vector3(0.0, 1.94 * scale, 0.0))
			for side in [-1.0, 0.0, 1.0]:
				_add_part(parts, "body", _cylinder(0.0, 0.045, 0.19, 5), Palette.GOLD_LIGHT, Vector3(side * 0.13, 2.10 * scale, 0.0))
			_add_part(parts, "body", _sphere(0.065, 0.13, 6, 3), Palette.WATER_LIGHT, Vector3(0.0, 2.12 * scale, 0.11))
		_:
			_add_part(parts, "body", _cylinder(0.13 * scale, 0.23 * scale, 0.18 * scale, 7), metal, Vector3(0.0, 1.91 * scale, 0.0))
			_add_part(parts, "body", _box(Vector3(0.30, 0.07, 0.08)), metal.darkened(0.12), Vector3(0.0, 2.02 * scale, 0.0))

	for side in [-1.0, 1.0]:
		var leg_color := cloth if side < 0.0 else cloth_light
		_add_part(parts, "body", _cylinder(0.12 * scale, 0.14 * scale, 0.58 * scale, 6), leg_color, Vector3(side * 0.16 * scale, 0.34 * scale, 0.0), Vector3(0.0, 0.0, side * -0.08))
		_add_part(parts, "body", _box(Vector3(0.24, 0.16, 0.34) * scale), boots, Vector3(side * 0.16 * scale, 0.10 * scale, 0.07 * scale))
		_add_part(parts, "body", _sphere(0.19 * scale, 0.24 * scale, 7, 3), shoulder_color, Vector3(side * 0.39 * scale, 1.30 * scale, 0.0))

	# Left arm stays in the body batch; the right arm is joined to the role weapon and animated.
	_add_part(parts, "body", _cylinder(0.10 * scale, 0.12 * scale, 0.62 * scale, 6), cloth, Vector3(-forward * 0.40 * scale, 1.03 * scale, 0.0), Vector3(0.0, 0.0, forward * 0.18))
	_add_part(parts, "action", _cylinder(0.10 * scale, 0.12 * scale, 0.62 * scale, 6), cloth, Vector3(forward * 0.40 * scale, 1.03 * scale, 0.0), Vector3(0.0, 0.0, -forward * 0.18))

	if role == UnitRole.COMMANDER:
		_add_part(parts, "body", _box(Vector3(0.58, 0.92, 0.09)), cloth.darkened(0.28), Vector3(-forward * 0.13, 1.03, -0.30))
		_add_part(parts, "body", _sphere(0.11, 0.20, 7, 3), Palette.GOLD, Vector3(-forward * 0.39, 1.30, 0.0))
	else:
		_add_part(parts, "body", _box(Vector3(0.12, 0.24, 0.18)), Palette.METAL_DARK, Vector3(-forward * 0.37, 1.05, 0.15))


static func _add_sword_and_shield(parts: Dictionary, forward: float) -> void:
	_add_part(parts, "body", _cylinder(0.30, 0.34, 0.11, 8), Palette.METAL, Vector3(forward * 0.49, 0.88, 0.30), Vector3(PI * 0.5, 0.0, 0.0))
	_add_part(parts, "body", _sphere(0.10, 0.15, 7, 3), Palette.GOLD, Vector3(forward * 0.49, 0.88, 0.37))
	_add_part(parts, "action", _cylinder(0.025, 0.065, 0.78, 5), Palette.METAL.lightened(0.18), Vector3(forward * 0.43, 1.40, -0.34), Vector3(0.0, 0.0, -forward * 0.16))
	_add_part(parts, "action", _box(Vector3(0.26, 0.07, 0.07)), Palette.GOLD, Vector3(forward * 0.43, 1.01, -0.34))
	_add_part(parts, "action", _box(Vector3(0.10, 0.17, 0.10)), Palette.WOOD, Vector3(forward * 0.43, 0.84, -0.34))


static func _add_archer_gear(parts: Dictionary, forward: float) -> void:
	_add_part(parts, "body", _cylinder(0.10, 0.12, 0.55, 6), Palette.WOOD, Vector3(-forward * 0.22, 1.28, -0.28), Vector3(0.0, 0.0, -0.20))
	for index in range(3):
		_add_part(parts, "body", _cylinder(0.012, 0.018, 0.58, 4), Palette.GOLD_LIGHT, Vector3(-forward * (0.25 + float(index) * 0.045), 1.61, -0.28))
	_add_part(parts, "action", _torus(0.27, 0.045, 6, 8), Palette.WOOD.lightened(0.18), Vector3(forward * 0.48, 1.12, 0.30), Vector3(PI * 0.5, 0.0, 0.0))
	_add_part(parts, "action", _cylinder(0.012, 0.012, 0.55, 4), Palette.GOLD_LIGHT, Vector3(forward * 0.48, 1.12, 0.30))


static func _add_spear_gear(parts: Dictionary, forward: float) -> void:
	_add_part(parts, "action", _cylinder(0.022, 0.035, 1.90, 5), Palette.WOOD.lightened(0.18), Vector3(forward * 0.45, 1.38, -0.24), Vector3(0.0, 0.0, -forward * 0.14))
	_add_part(parts, "action", _cylinder(0.0, 0.095, 0.30, 5), Palette.METAL.lightened(0.18), Vector3(forward * 0.58, 2.42, -0.24), Vector3(0.0, 0.0, -forward * 0.14))


static func _add_commander_banner(parts: Dictionary, team: int, forward: float) -> void:
	var cloth := Palette.PLAYER_TEAM if team == 0 else Palette.ENEMY_TEAM
	_add_part(parts, "action", _cylinder(0.025, 0.035, 1.35, 5), Palette.GOLD, Vector3(-forward * 0.30, 2.08, -0.32))
	var banner_mesh := _box(Vector3(0.46, 0.34, 0.045))
	_add_part(parts, "action", banner_mesh, cloth, Vector3(-forward * 0.30, 2.49, -0.32))


static func _build_cavalry(parts: Dictionary, team: int, forward: float) -> void:
	var coat := Palette.HORSE_BROWN_PLAYER if team == 0 else Palette.HORSE_BROWN_ENEMY
	var cloth := Palette.PLAYER_CLOTH if team == 0 else Palette.ENEMY_CLOTH
	var light_cloth := Palette.PLAYER_CLOTH_LIGHT if team == 0 else Palette.ENEMY_CLOTH_LIGHT

	# Horse body, neck and head are one merged static silhouette.
	_add_part(parts, "body", _capsule(0.36, 1.65, 8, 4), coat, Vector3(0.0, 0.62, 0.0), Vector3(0.0, 0.0, PI * 0.5))
	_add_part(parts, "body", _capsule(0.19, 0.82, 7, 3), coat.lightened(0.04), Vector3(forward * 0.67, 0.99, 0.0), Vector3(0.0, 0.0, -forward * 0.53))
	_add_part(parts, "body", _sphere(0.22, 0.43, 7, 3), coat, Vector3(forward * 1.02, 1.28, 0.0), Vector3(0.0, 0.0, -forward * 0.24))
	_add_part(parts, "body", _cylinder(0.0, 0.065, 0.21, 5), Palette.WOOD, Vector3(forward * 1.06, 1.55, 0.10), Vector3(0.0, 0.0, -forward * 0.10))
	_add_part(parts, "body", _box(Vector3(0.16, 0.55, 0.34)), Palette.WOOD, Vector3(forward * 0.72, 1.38, 0.0))
	_add_part(parts, "body", _cylinder(0.035, 0.09, 0.55, 5), Palette.WOOD, Vector3(-forward * 0.82, 0.53, 0.0), Vector3(0.0, 0.0, forward * 0.35))
	_add_part(parts, "body", _box(Vector3(0.60, 0.17, 0.58)), Palette.WOOD, Vector3(0.0, 0.91, 0.0))
	_add_part(parts, "body", _box(Vector3(0.66, 0.10, 0.62)), Palette.PLAYER_TEAM if team == 0 else Palette.ENEMY_TEAM, Vector3(0.0, 0.81, 0.0))
	_add_part(parts, "body", _cylinder(0.025, 0.035, 0.54, 5), Palette.GOLD, Vector3(forward * 0.65, 1.04, 0.26), Vector3(PI * 0.5, 0.0, 0.0))

	for side in [-1.0, 1.0]:
		for direction in [-1.0, 1.0]:
			_add_part(parts, "body", _cylinder(0.085, 0.10, 0.62, 6), coat, Vector3(direction * 0.46, 0.31, side * 0.22), Vector3(0.0, 0.0, direction * 0.08))

	# Rider silhouette sits high above the horse's caparison.
	_add_part(parts, "body", _capsule(0.29, 0.78, 7, 3), cloth, Vector3(0.0, 1.48, 0.0))
	_add_part(parts, "body", _box(Vector3(0.43, 0.45, 0.08)), Palette.METAL, Vector3(0.0, 1.52, 0.22))
	_add_part(parts, "body", _sphere(0.18, 0.36, 8, 4), Palette.SKIN, Vector3(0.0, 2.02, 0.0))
	_add_part(parts, "body", _cylinder(0.12, 0.20, 0.16, 7), Palette.METAL, Vector3(0.0, 2.20, 0.0))
	_add_part(parts, "body", _cylinder(0.0, 0.055, 0.25, 5), Palette.GOLD, Vector3(0.0, 2.40, 0.0))
	for side in [-1.0, 1.0]:
		_add_part(parts, "body", _box(Vector3(0.16, 0.40, 0.22)), Palette.METAL_DARK, Vector3(side * 0.30, 1.05, 0.03))
		_add_part(parts, "body", _cylinder(0.10, 0.12, 0.48, 6), light_cloth, Vector3(side * 0.30, 1.02, 0.0), Vector3(0.0, 0.0, side * 0.8))

	_add_part(parts, "action", _cylinder(0.09, 0.11, 0.55, 6), cloth, Vector3(forward * 0.34, 1.53, 0.12), Vector3(0.0, 0.0, -forward * 0.40))
	_add_part(parts, "action", _cylinder(0.025, 0.06, 0.78, 5), Palette.METAL, Vector3(forward * 0.48, 1.92, -0.30), Vector3(0.0, 0.0, -forward * 0.16))
	_add_part(parts, "action", _box(Vector3(0.26, 0.07, 0.07)), Palette.GOLD, Vector3(forward * 0.48, 1.52, -0.30))


static func _add_cavalry_weapon(parts: Dictionary, forward: float) -> void:
	# The shield is fixed to the rider; sword and hand remain in the animated action batch.
	_add_part(parts, "body", _cylinder(0.27, 0.31, 0.10, 8), Palette.METAL, Vector3(forward * 0.49, 1.22, 0.32), Vector3(PI * 0.5, 0.0, 0.0))
	_add_part(parts, "body", _sphere(0.08, 0.12, 7, 3), Palette.GOLD, Vector3(forward * 0.49, 1.22, 0.38))


static func _add_part(parts: Dictionary, bucket: String, mesh: Mesh, color: Color, position: Vector3, rotation: Vector3 = Vector3.ZERO) -> void:
	var anchor: Vector3 = parts["action_pivot"] if bucket == "action" else Vector3.ZERO
	var transform := Transform3D(Basis.from_euler(rotation), position - anchor)
	var part_list: Array = parts[bucket]
	part_list.append({"mesh": mesh, "color": color, "transform": transform})


static func _build_merged_mesh(parts: Array) -> Mesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertex_count := 0
	for part_value in parts:
		var part: Dictionary = part_value
		var source_mesh: Mesh = part["mesh"]
		var color: Color = part["color"]
		var transform: Transform3D = part["transform"]
		var normal_transform: Basis = transform.basis.inverse().transposed()
		for surface_index in range(source_mesh.get_surface_count()):
			var arrays: Array = source_mesh.surface_get_arrays(surface_index)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for vertex_index in range(vertices.size()):
					_append_vertex(surface, vertices[vertex_index], normals, vertex_index, normal_transform, transform, color)
					vertex_count += 1
			else:
				for source_index in indices:
					_append_vertex(surface, vertices[source_index], normals, source_index, normal_transform, transform, color)
					vertex_count += 1
	if vertex_count == 0:
		return ArrayMesh.new()
	surface.index()
	return surface.commit()


static func _append_vertex(surface: SurfaceTool, vertex: Vector3, normals: PackedVector3Array, vertex_index: int, normal_transform: Basis, transform: Transform3D, color: Color) -> void:
	var normal := Vector3.UP
	if vertex_index < normals.size():
		normal = (normal_transform * normals[vertex_index]).normalized()
	surface.set_color(color)
	surface.set_normal(normal)
	surface.add_vertex(transform * vertex)


static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func _sphere(radius: float, height: float, segments: int = 8, rings: int = 4) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


static func _capsule(radius: float, height: float, segments: int = 7, rings: int = 3) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


static func _cylinder(top_radius: float, bottom_radius: float, height: float, segments: int = 6) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	return mesh


static func _torus(inner_radius: float, outer_radius: float, rings: int = 6, ring_segments: int = 8) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = rings
	mesh.ring_segments = ring_segments
	return mesh
