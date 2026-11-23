class_name BattleUnit
extends CharacterBody3D

signal eliminated(unit: BattleUnit, killer: BattleUnit)

enum OrderMode {
	AUTO,
	MOVE,
	ATTACK,
	ATTACK_MOVE,
	HOLD,
	STOP,
	RETREAT,
}

enum UnitRole {
	MELEE,
	RANGED,
}

@export var team: int = 0 # 0 = player, 1 = enemy
@export_enum("Мечник", "Лучник") var role: int = UnitRole.MELEE
@export var move_speed: float = 3.8
@export var max_health: float = 100.0
@export var attack_damage: float = 16.0
@export var attack_range: float = 1.55
@export var attack_cooldown: float = 1.0
@export var detection_range: float = 13.0
@export var preferred_range: float = 1.4
@export var projectile_speed: float = 12.0

var health: float
var starting_health: float = -1.0
var kills: int = 0
var damage_dealt: float = 0.0
var _attack_timer: float = 0.0
var _destination: Vector3 = Vector3.ZERO
var _order_mode: OrderMode = OrderMode.AUTO
var _target: BattleUnit
var _selection_ring: MeshInstance3D
var _target_ring: MeshInstance3D
var _health_fill: MeshInstance3D
var _health_fill_material: StandardMaterial3D


func _ready() -> void:
	_apply_role_stats()
	health = max_health if starting_health < 0.0 else clampf(starting_health, 0.0, max_health)
	collision_layer = 2
	collision_mask = 0
	add_to_group("battle_units")
	_build_visuals()
	_update_health_bar()


func _apply_role_stats() -> void:
	if role == UnitRole.RANGED:
		max_health = 72.0
		move_speed = 3.35
		attack_damage = 13.0
		attack_range = 8.0
		attack_cooldown = 1.45
		detection_range = 16.0
		preferred_range = 5.7
		projectile_speed = 12.0
	else:
		max_health = 125.0
		move_speed = 3.8
		attack_damage = 19.0
		attack_range = 1.65
		attack_cooldown = 0.9
		detection_range = 13.0
		preferred_range = 1.4


func _build_visuals() -> void:
	var body_mesh := MeshInstance3D.new()
	var body_material := StandardMaterial3D.new()
	if team == 0:
		body_material.albedo_color = Color(0.16, 0.48, 0.95)
	else:
		body_material.albedo_color = Color(0.88, 0.20, 0.17)
	body_material.roughness = 0.82

	if role == UnitRole.RANGED:
		var ranged_body := CapsuleMesh.new()
		ranged_body.radius = 0.29
		ranged_body.height = 1.30
		body_mesh.mesh = ranged_body
		body_mesh.position.y = 0.68
	else:
		var melee_body := CapsuleMesh.new()
		melee_body.radius = 0.38
		melee_body.height = 1.45
		body_mesh.mesh = melee_body
		body_mesh.position.y = 0.76

	body_mesh.material_override = body_material
	add_child(body_mesh)

	var collision := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	if role == UnitRole.RANGED:
		capsule_shape.radius = 0.29
		capsule_shape.height = 1.30
		collision.position.y = 0.68
	else:
		capsule_shape.radius = 0.38
		capsule_shape.height = 1.45
		collision.position.y = 0.76
	collision.shape = capsule_shape
	add_child(collision)

	_create_role_marker()

	_selection_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.48
	ring_mesh.outer_radius = 0.58
	_selection_ring.mesh = ring_mesh
	_selection_ring.position.y = 0.055
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(1.0, 0.88, 0.22)
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_selection_ring.material_override = ring_material
	_selection_ring.visible = false
	add_child(_selection_ring)

	_target_ring = MeshInstance3D.new()
	var target_ring_mesh := TorusMesh.new()
	target_ring_mesh.inner_radius = 0.64
	target_ring_mesh.outer_radius = 0.76
	_target_ring.mesh = target_ring_mesh
	_target_ring.position.y = 0.075
	var target_ring_material := StandardMaterial3D.new()
	target_ring_material.albedo_color = Color(1.0, 0.38, 0.12)
	target_ring_material.emission_enabled = true
	target_ring_material.emission = Color(0.8, 0.12, 0.025)
	target_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_target_ring.material_override = target_ring_material
	_target_ring.visible = false
	add_child(_target_ring)

	_create_health_bar()


func _create_role_marker() -> void:
	var marker := MeshInstance3D.new()
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.13
	marker_mesh.height = 0.26
	marker.mesh = marker_mesh
	marker.position = Vector3(0.0, 1.53, 0.0)

	var marker_material := StandardMaterial3D.new()
	if role == UnitRole.RANGED:
		marker_material.albedo_color = Color(1.0, 0.76, 0.20)
		marker_material.emission_enabled = true
		marker_material.emission = Color(0.65, 0.30, 0.04)
	else:
		marker_material.albedo_color = Color(0.78, 0.84, 0.92)
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = marker_material
	add_child(marker)


func _create_health_bar() -> void:
	var bar_root := Node3D.new()
	bar_root.position = Vector3(0.0, 1.82, 0.0)
	add_child(bar_root)

	var background := MeshInstance3D.new()
	var background_mesh := BoxMesh.new()
	background_mesh.size = Vector3(1.02, 0.10, 0.08)
	background.mesh = background_mesh
	var background_material := StandardMaterial3D.new()
	background_material.albedo_color = Color(0.025, 0.03, 0.035, 1.0)
	background_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	background.material_override = background_material
	bar_root.add_child(background)

	_health_fill = MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(0.92, 0.065, 0.09)
	_health_fill.mesh = fill_mesh
	_health_fill_material = StandardMaterial3D.new()
	_health_fill_material.albedo_color = Color(0.20, 0.88, 0.32, 1.0)
	_health_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_health_fill.material_override = _health_fill_material
	bar_root.add_child(_health_fill)


func _update_health_bar() -> void:
	if not is_instance_valid(_health_fill):
		return
	var ratio := clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
	_health_fill.scale.x = maxf(ratio, 0.001)
	_health_fill.position.x = -0.46 * (1.0 - ratio)
	if ratio > 0.55:
		_health_fill_material.albedo_color = Color(0.20, 0.88, 0.32, 1.0)
	elif ratio > 0.25:
		_health_fill_material.albedo_color = Color(1.0, 0.67, 0.16, 1.0)
	else:
		_health_fill_material.albedo_color = Color(0.92, 0.20, 0.16, 1.0)


func set_selected(value: bool) -> void:
	if is_instance_valid(_selection_ring):
		_selection_ring.visible = value


func set_targeted(value: bool) -> void:
	if is_instance_valid(_target_ring):
		_target_ring.visible = value


func order_move(point: Vector3) -> void:
	_target = null
	_destination = Vector3(point.x, 0.0, point.z)
	_order_mode = OrderMode.MOVE


func order_attack(enemy: BattleUnit) -> void:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return
	_target = enemy
	_order_mode = OrderMode.ATTACK


func order_attack_move(point: Vector3) -> void:
	_target = null
	_destination = Vector3(point.x, 0.0, point.z)
	_order_mode = OrderMode.ATTACK_MOVE


func order_hold() -> void:
	_target = null
	_order_mode = OrderMode.HOLD
	velocity = Vector3.ZERO


func order_stop() -> void:
	_target = null
	_order_mode = OrderMode.STOP
	velocity = Vector3.ZERO


func order_retreat() -> void:
	_target = null
	var retreat_x := -16.0 if team == 0 else 16.0
	_destination = Vector3(retreat_x, 0.0, clampf(global_position.z, -11.0, 11.0))
	_order_mode = OrderMode.RETREAT


func take_damage(amount: float, attacker: BattleUnit = null) -> void:
	if health <= 0.0:
		return
	var applied_damage := minf(health, maxf(amount, 0.0))
	health = maxf(0.0, health - applied_damage)
	if is_instance_valid(attacker) and attacker != self:
		attacker.damage_dealt += applied_damage
	_update_health_bar()
	if health <= 0.0:
		if is_instance_valid(attacker) and attacker != self:
			attacker.kills += 1
		eliminated.emit(self, attacker)
		queue_free()


func _physics_process(delta: float) -> void:
	if health <= 0.0:
		return

	_attack_timer = maxf(0.0, _attack_timer - delta)

	# Enemy-controlled units withdraw when critically wounded instead of fighting to the last HP.
	if team == 1 and _order_mode == OrderMode.AUTO and health <= max_health * 0.22:
		order_retreat()

	if _order_mode == OrderMode.RETREAT:
		_move_to_destination()
		move_and_slide()
		return

	if not _has_valid_target():
		_target = null
		if _order_mode == OrderMode.ATTACK:
			_order_mode = OrderMode.AUTO

	var search_range: float = 0.0
	match _order_mode:
		OrderMode.AUTO:
			search_range = detection_range
		OrderMode.ATTACK_MOVE:
			search_range = attack_range + 2.5
		OrderMode.HOLD:
			search_range = attack_range

	if search_range > 0.0 and not is_instance_valid(_target):
		_target = _find_nearest_enemy(search_range)

	if _order_mode == OrderMode.STOP:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if _has_valid_target() and _order_mode != OrderMode.MOVE:
		_attack_or_chase()
		move_and_slide()
		return

	if _order_mode == OrderMode.MOVE or _order_mode == OrderMode.ATTACK_MOVE:
		_move_to_destination()
	else:
		velocity = Vector3.ZERO

	move_and_slide()


func _has_valid_target() -> bool:
	return is_instance_valid(_target) and not _target.is_queued_for_deletion()


func _attack_or_chase() -> void:
	var offset: Vector3 = _target.global_position - global_position
	offset.y = 0.0
	var distance: float = offset.length()

	if role == UnitRole.RANGED:
		_ranged_combat(offset, distance)
		return

	if distance <= attack_range:
		velocity = Vector3.ZERO
		if _attack_timer <= 0.0:
			_target.take_damage(attack_damage, self)
			_attack_timer = attack_cooldown
	elif _order_mode == OrderMode.HOLD:
		# Hold means defend this exact position, not chase a target.
		_target = null
		velocity = Vector3.ZERO
	else:
		_steer(offset.normalized())


func _ranged_combat(offset: Vector3, distance: float) -> void:
	if distance > attack_range:
		if _order_mode == OrderMode.HOLD:
			_target = null
			velocity = Vector3.ZERO
		else:
			_steer(offset.normalized())
		return

	# Archers try to stay around their preferred firing distance.
	# HOLD intentionally disables this repositioning so the line stays in place.
	if _order_mode != OrderMode.HOLD and distance < preferred_range - 1.0:
		_steer(-offset.normalized())
		return

	velocity = Vector3.ZERO
	if _attack_timer <= 0.0:
		_fire_projectile(_target)
		_attack_timer = attack_cooldown


func _fire_projectile(enemy: BattleUnit) -> void:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return
	var projectile := CombatProjectile.new()
	projectile.target = enemy
	projectile.source = self
	projectile.damage = attack_damage
	projectile.speed = projectile_speed
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector3(0.0, 1.05, 0.0)


func _steer(direction: Vector3) -> void:
	if direction.length_squared() <= 0.001:
		velocity = Vector3.ZERO
		return
	var desired_direction := direction.normalized()
	var separation := _get_separation_vector(1.15)
	if separation.length_squared() > 0.001:
		desired_direction = (desired_direction + separation * 0.8).normalized()
	velocity = desired_direction * move_speed


func _move_to_destination() -> void:
	var offset: Vector3 = _destination - global_position
	offset.y = 0.0
	if offset.length() <= 0.28:
		velocity = Vector3.ZERO
		_order_mode = OrderMode.HOLD if _order_mode == OrderMode.RETREAT else OrderMode.AUTO
		return
	_steer(offset.normalized())


func _get_separation_vector(radius: float) -> Vector3:
	var separation := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("battle_units"):
		if not node is BattleUnit:
			continue
		var other := node as BattleUnit
		if other == self or other.health <= 0.0:
			continue
		var away: Vector3 = global_position - other.global_position
		away.y = 0.0
		var distance := away.length()
		if distance > 0.001 and distance < radius:
			separation += away.normalized() * ((radius - distance) / radius)
	return separation


func _find_nearest_enemy(max_distance: float) -> BattleUnit:
	var nearest: BattleUnit = null
	var nearest_distance: float = max_distance

	for node in get_tree().get_nodes_in_group("battle_units"):
		if not node is BattleUnit:
			continue
		var candidate := node as BattleUnit
		if candidate == self or candidate.team == team or candidate.health <= 0.0 or candidate.is_queued_for_deletion():
			continue
		var distance: float = global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate

	return nearest
