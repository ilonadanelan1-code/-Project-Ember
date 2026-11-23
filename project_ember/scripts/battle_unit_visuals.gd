extends RefCounted
class_name BattleUnitVisuals

const VisualCacheScript = preload("res://scripts/visual_cache.gd")
const Palette = preload("res://scripts/art_palette.gd")

## Procedural low-poly soldier silhouettes. Gameplay collision and stats stay in BattleUnit.

static func build(team: int, role: int) -> Node3D:
	var root := Node3D.new()
	var forward := 1.0 if team == 0 else -1.0
	var cloth_color := Palette.PLAYER_CLOTH if team == 0 else Palette.ENEMY_CLOTH
	var cloth_light := Palette.PLAYER_CLOTH_LIGHT if team == 0 else Palette.ENEMY_CLOTH_LIGHT
	var metal := _material(Palette.METAL, 0.66, 0.34)
	var gold := _material(Palette.GOLD, 0.78, 0.28)
	var leather := _material(Palette.WOOD, 0.0, 0.9)
	var cloth := _material(cloth_color, 0.0, 0.84)
	var cloth_highlight := _material(cloth_light, 0.0, 0.78)
	var skin := _material(Palette.SKIN, 0.0, 0.9)
	var boots := _material(Palette.METAL_DARK, 0.0, 0.95)

	if role == BattleUnit.UnitRole.CAVALRY:
		_add_horse(root, team, forward, leather, _material(Palette.HORSE_BROWN_PLAYER if team == 0 else Palette.HORSE_BROWN_ENEMY, 0.0, 0.95))
		_add_rider(root, forward, cloth, cloth_highlight, metal, skin, boots)
	else:
		_add_infantry(root, forward, cloth, cloth_highlight, metal, gold, leather, skin, boots, role == BattleUnit.UnitRole.COMMANDER)

	match role:
		BattleUnit.UnitRole.RANGED:
			_add_bow(root, forward, leather, gold)
		BattleUnit.UnitRole.SPEAR:
			_add_spear(root, forward, leather, metal)
		BattleUnit.UnitRole.COMMANDER:
			_add_commander_details(root, forward, gold, cloth_light)
		BattleUnit.UnitRole.MELEE:
			_add_sword_and_shield(root, forward, leather, metal, gold)
		BattleUnit.UnitRole.CAVALRY:
			_add_sword_and_shield(root, forward, leather, metal, gold)
	return root


static func _add_infantry(root: Node3D, forward: float, cloth: Material, highlight: Material, metal: Material, gold: Material, leather: Material, skin: Material, boots: Material, commander: bool) -> void:
	var scale := 1.12 if commander else 1.0
	var torso := CapsuleMesh.new()
	torso.radius = 0.34 * scale
	torso.height = 0.94 * scale
	torso.radial_segments = 7
	torso.rings = 3
	_add(root, torso, cloth, Vector3(0.0, 1.03 * scale, 0.0))
	var hem := BoxMesh.new()
	hem.size = Vector3(0.62 * scale, 0.28 * scale, 0.44 * scale)
	_add(root, hem, highlight, Vector3(0.0, 0.68 * scale, 0.0))
	var chest := BoxMesh.new()
	chest.size = Vector3(0.49 * scale, 0.55 * scale, 0.075)
	_add(root, chest, metal, Vector3(0.0, 1.08 * scale, 0.25 * scale))
	var head := SphereMesh.new()
	head.radius = 0.20 * scale
	head.height = 0.40 * scale
	head.radial_segments = 8
	head.rings = 4
	_add(root, head, skin, Vector3(0.0, 1.72 * scale, 0.0))
	var helmet := CylinderMesh.new()
	helmet.top_radius = 0.13 * scale
	helmet.bottom_radius = 0.23 * scale
	helmet.height = 0.18 * scale
	helmet.radial_segments = 7
	_add(root, helmet, gold if commander else metal, Vector3(0.0, 1.91 * scale, 0.0))
	for side in [-1.0, 1.0]:
		var leg := CylinderMesh.new()
		leg.top_radius = 0.12 * scale
		leg.bottom_radius = 0.14 * scale
		leg.height = 0.58 * scale
		leg.radial_segments = 6
		_add(root, leg, cloth, Vector3(side * 0.16 * scale, 0.34 * scale, 0.0), Vector3(0.0, 0.0, side * -0.08))
		var boot := BoxMesh.new()
		boot.size = Vector3(0.24 * scale, 0.16 * scale, 0.34 * scale)
		_add(root, boot, boots, Vector3(side * 0.16 * scale, 0.10 * scale, 0.07 * scale))
		var arm := CylinderMesh.new()
		arm.top_radius = 0.10 * scale
		arm.bottom_radius = 0.12 * scale
		arm.height = 0.62 * scale
		arm.radial_segments = 6
		_add(root, arm, cloth, Vector3(side * 0.40 * scale, 1.03 * scale, 0.0), Vector3(0.0, 0.0, side * -0.18))
		var shoulder := SphereMesh.new()
		shoulder.radius = 0.19 * scale
		shoulder.height = 0.24 * scale
		_add(root, shoulder, gold if commander else metal, Vector3(side * 0.39 * scale, 1.30 * scale, 0.0))


static func _add_rider(root: Node3D, forward: float, cloth: Material, highlight: Material, metal: Material, skin: Material, boots: Material) -> void:
	var torso := CapsuleMesh.new()
	torso.radius = 0.29
	torso.height = 0.78
	torso.radial_segments = 7
	_add(root, torso, cloth, Vector3(0.0, 1.48, 0.0))
	var chest := BoxMesh.new()
	chest.size = Vector3(0.43, 0.45, 0.08)
	_add(root, chest, metal, Vector3(0.0, 1.52, 0.22))
	var head := SphereMesh.new()
	head.radius = 0.18
	head.height = 0.36
	head.radial_segments = 8
	_add(root, head, skin, Vector3(0.0, 2.02, 0.0))
	var helmet := CylinderMesh.new()
	helmet.top_radius = 0.12
	helmet.bottom_radius = 0.20
	helmet.height = 0.16
	helmet.radial_segments = 7
	_add(root, helmet, metal, Vector3(0.0, 2.20, 0.0))
	for side in [-1.0, 1.0]:
		var arm := CylinderMesh.new()
		arm.top_radius = 0.09
		arm.bottom_radius = 0.11
		arm.height = 0.55
		arm.radial_segments = 6
		_add(root, arm, cloth, Vector3(side * 0.34, 1.53, 0.12), Vector3(0.0, 0.0, side * -0.4))
		var leg := CylinderMesh.new()
		leg.top_radius = 0.10
		leg.bottom_radius = 0.12
		leg.height = 0.48
		leg.radial_segments = 6
		_add(root, leg, highlight, Vector3(side * 0.30, 1.02, 0.0), Vector3(0.0, 0.0, side * 0.8))


static func _add_horse(root: Node3D, team: int, forward: float, leather: Material, coat: Material) -> void:
	var body := CapsuleMesh.new()
	body.radius = 0.36
	body.height = 1.65
	body.radial_segments = 8
	body.rings = 4
	_add(root, body, coat, Vector3(0.0, 0.62, 0.0), Vector3(0.0, 0.0, PI * 0.5))
	var neck := CapsuleMesh.new()
	neck.radius = 0.19
	neck.height = 0.82
	neck.radial_segments = 7
	_add(root, neck, coat, Vector3(forward * 0.67, 0.99, 0.0), Vector3(0.0, 0.0, -forward * 0.53))
	var head := SphereMesh.new()
	head.radius = 0.22
	head.height = 0.43
	head.radial_segments = 7
	_add(root, head, coat, Vector3(forward * 1.02, 1.28, 0.0), Vector3(0.0, 0.0, -forward * 0.24))
	var mane := BoxMesh.new()
	mane.size = Vector3(0.16, 0.55, 0.34)
	_add(root, mane, leather, Vector3(forward * 0.72, 1.38, 0.0))
	var saddle := BoxMesh.new()
	saddle.size = Vector3(0.60, 0.17, 0.58)
	_add(root, saddle, leather, Vector3(0.0, 0.91, 0.0))
	var blanket := BoxMesh.new()
	blanket.size = Vector3(0.66, 0.10, 0.62)
	var blanket_material := _material(Palette.PLAYER_TEAM if team == 0 else Palette.ENEMY_TEAM, 0.0, 0.85)
	_add(root, blanket, blanket_material, Vector3(0.0, 0.81, 0.0))
	for side in [-1.0, 1.0]:
		for direction in [-1.0, 1.0]:
			var leg := CylinderMesh.new()
			leg.top_radius = 0.085
			leg.bottom_radius = 0.10
			leg.height = 0.62
			leg.radial_segments = 6
			_add(root, leg, coat, Vector3(direction * 0.46, 0.31, side * 0.22), Vector3(0.0, 0.0, direction * 0.08))
	var tail := CylinderMesh.new()
	tail.top_radius = 0.035
	tail.bottom_radius = 0.09
	tail.height = 0.55
	tail.radial_segments = 5
	_add(root, tail, leather, Vector3(-forward * 0.82, 0.53, 0.0), Vector3(0.0, 0.0, forward * 0.35))


static func _add_sword_and_shield(root: Node3D, forward: float, leather: Material, metal: Material, gold: Material) -> void:
	var shield := CylinderMesh.new()
	shield.top_radius = 0.30
	shield.bottom_radius = 0.34
	shield.height = 0.11
	shield.radial_segments = 8
	_add(root, shield, metal, Vector3(forward * 0.49, 0.88, 0.30), Vector3(PI * 0.5, 0.0, 0.0))
	var boss := SphereMesh.new()
	boss.radius = 0.10
	boss.height = 0.15
	_add(root, boss, gold, Vector3(forward * 0.49, 0.88, 0.37))
	var blade := CylinderMesh.new()
	blade.top_radius = 0.025
	blade.bottom_radius = 0.065
	blade.height = 0.78
	blade.radial_segments = 5
	_add(root, blade, metal, Vector3(forward * 0.43, 1.02, -0.34), Vector3(0.0, 0.0, -forward * 0.16))
	var hilt := BoxMesh.new()
	hilt.size = Vector3(0.26, 0.07, 0.07)
	_add(root, hilt, gold, Vector3(forward * 0.43, 0.63, -0.34))


static func _add_spear(root: Node3D, forward: float, leather: Material, metal: Material) -> void:
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.022
	shaft.bottom_radius = 0.035
	shaft.height = 1.90
	shaft.radial_segments = 5
	_add(root, shaft, leather, Vector3(forward * 0.45, 1.38, -0.24), Vector3(0.0, 0.0, -forward * 0.14))
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.095
	tip.height = 0.30
	tip.radial_segments = 5
	_add(root, tip, metal, Vector3(forward * 0.58, 2.42, -0.24), Vector3(0.0, 0.0, -forward * 0.14))


static func _add_bow(root: Node3D, forward: float, leather: Material, gold: Material) -> void:
	var bow := TorusMesh.new()
	bow.inner_radius = 0.27
	bow.outer_radius = 0.045
	bow.rings = 6
	bow.ring_segments = 8
	_add(root, bow, leather, Vector3(forward * 0.48, 1.12, 0.30), Vector3(PI * 0.5, 0.0, 0.0))
	var string_mesh := CylinderMesh.new()
	string_mesh.top_radius = 0.012
	string_mesh.bottom_radius = 0.012
	string_mesh.height = 0.55
	string_mesh.radial_segments = 4
	_add(root, string_mesh, gold, Vector3(forward * 0.48, 1.12, 0.30), Vector3(0.0, 0.0, 0.0))
	var quiver := CylinderMesh.new()
	quiver.top_radius = 0.10
	quiver.bottom_radius = 0.12
	quiver.height = 0.55
	quiver.radial_segments = 6
	_add(root, quiver, leather, Vector3(-forward * 0.22, 1.28, -0.28), Vector3(0.0, 0.0, -0.20))
	for index in range(3):
		var arrow := CylinderMesh.new()
		arrow.top_radius = 0.012
		arrow.bottom_radius = 0.018
		arrow.height = 0.58
		arrow.radial_segments = 4
		_add(root, arrow, gold, Vector3(-forward * (0.25 + float(index) * 0.045), 1.61, -0.28))


static func _add_commander_details(root: Node3D, forward: float, gold: Material, team_color: Color) -> void:
	var cape := BoxMesh.new()
	cape.size = Vector3(0.58, 0.92, 0.09)
	_add(root, cape, _material(team_color.darkened(0.28), 0.0, 0.88), Vector3(-forward * 0.13, 1.03, -0.30))
	var crown := CylinderMesh.new()
	crown.top_radius = 0.14
	crown.bottom_radius = 0.22
	crown.height = 0.17
	crown.radial_segments = 8
	_add(root, crown, gold, Vector3(0.0, 2.18, 0.0))
	var jewel := SphereMesh.new()
	jewel.radius = 0.065
	jewel.height = 0.13
	_add(root, jewel, _material(Palette.WATER_LIGHT, 0.25, 0.22), Vector3(forward * 0.02, 2.29, 0.10))
	var pole := CylinderMesh.new()
	pole.top_radius = 0.025
	pole.bottom_radius = 0.035
	pole.height = 1.35
	pole.radial_segments = 5
	_add(root, pole, gold, Vector3(-forward * 0.30, 2.08, -0.32))
	var banner := BoxMesh.new()
	banner.size = Vector3(0.46, 0.34, 0.045)
	_add(root, banner, _material(team_color, 0.0, 0.75), Vector3(-forward * 0.30, 2.49, -0.32))


static func _add(root: Node3D, mesh: Mesh, material: Material, position: Vector3, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = VisualCacheScript.cache_mesh_resource(mesh)
	instance.material_override = material
	instance.position = position
	instance.rotation = rotation
	root.add_child(instance)
	return instance


static func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var key := "unit:%02x%02x%02x:%02d:%02d" % [roundi(color.r * 255.0), roundi(color.g * 255.0), roundi(color.b * 255.0), roundi(metallic * 100.0), roundi(roughness * 100.0)]
	return VisualCacheScript.get_material(key, func() -> Material:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.metallic = metallic
		material.roughness = roughness
		return material
	) as StandardMaterial3D
