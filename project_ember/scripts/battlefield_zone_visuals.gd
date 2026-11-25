extends RefCounted
class_name BattlefieldZoneVisuals

const BattlefieldRulesScript = preload("res://scripts/battlefield_rules.gd")

static func add_to(parent: Node3D, biome_id: String, field_size: Vector2, seed_value: int) -> int:
	var zones := BattlefieldRulesScript.get_zones(biome_id, field_size, seed_value)
	for zone in zones:
		var zone_type := str(zone.get("type", ""))
		var center: Vector3 = zone.get("center", Vector3.ZERO)
		var radius := float(zone.get("radius", BattlefieldRulesScript.ZONE_RADIUS))
		var color := _zone_color(zone_type)
		_add_zone_fill(parent, center, radius, color, str(zone.get("id", "zone")))
		_add_zone_border(parent, center, radius, color, str(zone.get("id", "zone")))
	return zones.size()


static func _add_zone_fill(parent: Node3D, center: Vector3, radius: float, color: Color, zone_id: String) -> void:
	var fill := MeshInstance3D.new()
	fill.name = "BattlefieldZoneFill_" + zone_id
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.012
	mesh.radial_segments = 32
	fill.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.12)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill.material_override = material
	fill.position = Vector3(center.x, 0.047, center.z)
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(fill)


static func _add_zone_border(parent: Node3D, center: Vector3, radius: float, color: Color, zone_id: String) -> void:
	var border := MeshInstance3D.new()
	border.name = "BattlefieldZoneBorder_" + zone_id
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - 0.055
	mesh.outer_radius = radius
	mesh.rings = 4
	mesh.ring_segments = 32
	border.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.58)
	material.emission_enabled = true
	material.emission = color.darkened(0.25)
	material.emission_energy_multiplier = 0.35
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	border.material_override = material
	border.position = Vector3(center.x, 0.071, center.z)
	border.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(border)


static func _zone_color(zone_type: String) -> Color:
	match zone_type:
		"forest_cover":
			return Color(0.20, 0.72, 0.34, 1.0)
		"high_ground":
			return Color(0.92, 0.67, 0.25, 1.0)
		"mud":
			return Color(0.22, 0.68, 0.68, 1.0)
		_:
			return Color(0.70, 0.70, 0.70, 1.0)
