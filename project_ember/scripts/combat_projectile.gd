class_name CombatProjectile
extends Node3D

const Palette = preload("res://scripts/art_palette.gd")
const VisualCacheScript = preload("res://scripts/visual_cache.gd")

## Lightweight glowing bolt. Damage is applied only when it reaches its living target.

var target: Node3D
var source: Node
var damage: float = 10.0
var speed: float = 12.0
var _life_time: float = 4.0
var _trail_timer: float = 0.0


func _ready() -> void:
	var visual := MeshInstance3D.new()
	visual.name = "BoltVisual"
	visual.mesh = VisualCacheScript.get_mesh("combat:projectile:bolt:v1", func() -> Mesh:
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.045
		mesh.height = 0.34
		mesh.radial_segments = 5
		mesh.rings = 2
		return mesh
	)
	visual.rotation.x = PI * 0.5
	visual.material_override = VisualCacheScript.get_material("combat:projectile:bolt:material:v1", func() -> Material:
		var material := StandardMaterial3D.new()
		material.albedo_color = Palette.PROJECTILE_CORE
		material.emission_enabled = true
		material.emission = Palette.PROJECTILE_GLOW
		material.emission_energy_multiplier = 1.4
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return material
	)
	add_child(visual)


func _physics_process(delta: float) -> void:
	_life_time -= delta
	if _life_time <= 0.0:
		queue_free()
		return

	if not is_instance_valid(target) or target.is_queued_for_deletion():
		queue_free()
		return

	var aim_position: Vector3 = target.global_position + Vector3(0.0, 0.95, 0.0)
	var offset: Vector3 = aim_position - global_position
	var distance: float = offset.length()
	var step_distance: float = speed * delta

	if distance <= step_distance or distance <= 0.14:
		if target.has_method("take_damage"):
			var valid_source: Node = source if is_instance_valid(source) else null
			target.call("take_damage", damage, valid_source)
		queue_free()
		return

	if distance > 0.001:
		var direction := offset / distance
		global_position += direction * step_distance
		look_at(global_position + direction, Vector3.UP)
		_trail_timer = maxf(0.0, _trail_timer - delta)
		if _trail_timer <= 0.0:
			_trail_timer = 0.085
			var effects := get_tree().get_first_node_in_group("battle_effects")
			if is_instance_valid(effects) and effects.has_method("spawn_effect"):
				var source_team := int(source.get("team")) if is_instance_valid(source) else 0
				effects.call("spawn_effect", "trail", global_position, source_team, direction)
