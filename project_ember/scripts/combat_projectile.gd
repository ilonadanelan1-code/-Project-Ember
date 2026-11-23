class_name CombatProjectile
extends Node3D

## A lightweight visual projectile used by ranged units.
## Damage is applied only when the projectile reaches its living target.

var target: Node3D
var source: Node
var damage: float = 10.0
var speed: float = 12.0
var _life_time: float = 4.0


func _ready() -> void:
	var visual := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.22
	visual.mesh = sphere

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.72, 0.22)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.42, 0.08)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = material
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
		global_position += offset / distance * step_distance
