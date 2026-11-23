class_name BattleUnit
extends CharacterBody3D

const BattleUnitVisualsScript = preload("res://scripts/battle_unit_visuals.gd")
const VisualCacheScript = preload("res://scripts/visual_cache.gd")
const Palette = preload("res://scripts/art_palette.gd")

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
	SPEAR,
	CAVALRY,
	COMMANDER,
}

const UNIT_CATALOG_SCRIPT = preload("res://scripts/unit_catalog.gd")

@export var team: int = 0 # 0 = player, 1 = enemy
@export_enum("Мечник", "Лучник", "Копейщик", "Кавалерист", "Командир") var role: int = UnitRole.MELEE
@export var move_speed: float = 3.8
@export var max_health: float = 100.0
@export var attack_damage: float = 16.0
@export var attack_range: float = 1.55
@export var attack_cooldown: float = 1.0
@export var detection_range: float = 13.0
@export var preferred_range: float = 1.4
@export var projectile_speed: float = 12.0
var armor: float = 0.0
var anti_cavalry_multiplier: float = 1.0
var charge_multiplier: float = 1.0
var commander_level: int = 1
var commander_leadership: int = 0
var commander_tactics: int = 0
var commander_might: int = 0
var command_damage_bonus: float = 0.0
var command_speed_bonus: float = 0.0
var command_aura_timer: float = 0.0
var rally_damage_bonus: float = 0.0
var rally_speed_bonus: float = 0.0
var rally_timer: float = 0.0
var rally_cooldown_timer: float = 0.0

var health: float
var starting_health: float = -1.0
var kills: int = 0
var damage_dealt: float = 0.0
var _attack_timer: float = 0.0
var _charge_timer: float = 0.0
var _moving_fast: bool = false
var _charge_armed: bool = false
var _destination: Vector3 = Vector3.ZERO
var _order_mode: OrderMode = OrderMode.AUTO
var _target: BattleUnit
var _selection_ring: MeshInstance3D
var _target_ring: MeshInstance3D
var _health_fill: MeshInstance3D
var _health_fill_material: StandardMaterial3D
var _visual_root: Node3D
var _animation_clock: float = 0.0


func _ready() -> void:
	_apply_role_stats()
	health = max_health if starting_health < 0.0 else clampf(starting_health, 0.0, max_health)
	collision_layer = 2
	collision_mask = 0
	add_to_group("battle_units")
	_build_visuals()
	_update_health_bar()


func _apply_role_stats() -> void:
	if role == UnitRole.COMMANDER:
		commander_level = clampi(commander_level, 1, 30)
		commander_leadership = clampi(commander_leadership, 0, 5)
		commander_tactics = clampi(commander_tactics, 0, 5)
		commander_might = clampi(commander_might, 0, 5)
		max_health = 210.0 + float(commander_level - 1) * 16.0 + float(commander_might) * 14.0
		move_speed = 4.0 + float(commander_tactics) * 0.06
		attack_damage = 24.0 + float(commander_level - 1) * 2.4 + float(commander_might) * 3.5
		attack_range = 1.9
		attack_cooldown = 0.88
		detection_range = 16.0
		preferred_range = 1.7
		projectile_speed = 0.0
		armor = 4.0 + float(commander_might) * 0.8
		anti_cavalry_multiplier = 1.0
		charge_multiplier = 1.0
		return
	var data: Dictionary = UNIT_CATALOG_SCRIPT.get_data(_get_role_id())
	max_health = float(data.get("max_health", 125.0))
	move_speed = float(data.get("move_speed", 3.8))
	attack_damage = float(data.get("damage", 19.0))
	attack_range = float(data.get("attack_range", 1.65))
	attack_cooldown = float(data.get("attack_cooldown", 0.9))
	detection_range = float(data.get("detection_range", 13.0))
	preferred_range = float(data.get("preferred_range", 1.4))
	projectile_speed = float(data.get("projectile_speed", 0.0))
	armor = float(data.get("armor", 0.0))
	anti_cavalry_multiplier = float(data.get("anti_cavalry_multiplier", 1.0))
	charge_multiplier = float(data.get("charge_multiplier", 1.0))


func _get_role_id() -> String:
	return UNIT_CATALOG_SCRIPT.get_role_for_battle_index(role)


func _build_visuals() -> void:
	_visual_root = BattleUnitVisualsScript.build(team, role)
	add_child(_visual_root)

	var body_radius := 0.38
	var body_height := 1.65
	var body_y := 0.84
	if role == UnitRole.RANGED:
		body_radius = 0.32
		body_height = 1.55
		body_y = 0.78
	elif role == UnitRole.SPEAR:
		body_radius = 0.36
		body_height = 1.65
		body_y = 0.84
	elif role == UnitRole.CAVALRY:
		body_radius = 0.60
		body_height = 1.85
		body_y = 0.88
	elif role == UnitRole.COMMANDER:
		body_radius = 0.46
		body_height = 2.10
		body_y = 1.05

	var collision := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = body_radius
	capsule_shape.height = body_height
	collision.position.y = body_y
	collision.shape = capsule_shape
	add_child(collision)

	_selection_ring = MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.48
	ring_mesh.outer_radius = 0.58
	_selection_ring.mesh = VisualCacheScript.cache_mesh_resource(ring_mesh)
	_selection_ring.position.y = 0.055
	var ring_material := VisualCacheScript.get_material("unit:ring:selection", func() -> Material:
		var material := StandardMaterial3D.new()
		material.albedo_color = Palette.GOLD_LIGHT
		material.emission_enabled = true
		material.emission = Palette.GOLD.darkened(0.55)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return material
	)
	_selection_ring.material_override = ring_material
	_selection_ring.visible = false
	add_child(_selection_ring)

	_target_ring = MeshInstance3D.new()
	var target_ring_mesh := TorusMesh.new()
	target_ring_mesh.inner_radius = 0.64
	target_ring_mesh.outer_radius = 0.76
	_target_ring.mesh = VisualCacheScript.cache_mesh_resource(target_ring_mesh)
	_target_ring.position.y = 0.075
	var target_ring_material := VisualCacheScript.get_material("unit:ring:target", func() -> Material:
		var material := StandardMaterial3D.new()
		material.albedo_color = Palette.WARNING
		material.emission_enabled = true
		material.emission = Palette.WARNING.darkened(0.3)
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return material
	)
	_target_ring.material_override = target_ring_material
	_target_ring.visible = false
	add_child(_target_ring)

	_create_health_bar()



func _add_cavalry_mount() -> void:
	var mount := MeshInstance3D.new()
	var mount_mesh := CapsuleMesh.new()
	mount_mesh.radius = 0.46
	mount_mesh.height = 1.75
	mount.mesh = mount_mesh
	mount.rotation.x = PI / 2.0
	mount.position = Vector3(0.0, 0.48, 0.0)
	var mount_material := StandardMaterial3D.new()
	mount_material.albedo_color = Palette.HORSE_BROWN_PLAYER if team == 0 else Palette.HORSE_BROWN_ENEMY
	mount_material.roughness = 0.9
	mount.material_override = mount_material
	add_child(mount)

	var saddle := MeshInstance3D.new()
	var saddle_mesh := BoxMesh.new()
	saddle_mesh.size = Vector3(0.54, 0.18, 0.72)
	saddle.mesh = saddle_mesh
	saddle.position = Vector3(0.0, 0.79, 0.0)
	var saddle_material := StandardMaterial3D.new()
	saddle_material.albedo_color = Palette.GOLD
	saddle.material_override = saddle_material
	add_child(saddle)


func _add_commander_visuals() -> void:
	var shoulder_material := StandardMaterial3D.new()
	shoulder_material.albedo_color = Palette.GOLD
	shoulder_material.metallic = 0.72
	for side in [-1.0, 1.0]:
		var shoulder := MeshInstance3D.new()
		var shoulder_mesh := SphereMesh.new()
		shoulder_mesh.radius = 0.22
		shoulder_mesh.height = 0.26
		shoulder.mesh = shoulder_mesh
		shoulder.position = Vector3(0.0, 1.24, side * 0.38)
		shoulder.material_override = shoulder_material
		add_child(shoulder)

	var crown := MeshInstance3D.new()
	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.17
	crown_mesh.bottom_radius = 0.23
	crown_mesh.height = 0.16
	crown.mesh = crown_mesh
	crown.position = Vector3(0.0, 1.79, 0.0)
	var crown_material := StandardMaterial3D.new()
	crown_material.albedo_color = Palette.GOLD_LIGHT
	crown_material.metallic = 0.88
	crown_material.roughness = 0.24
	crown.material_override = crown_material
	add_child(crown)

	var jewel := MeshInstance3D.new()
	var jewel_mesh := SphereMesh.new()
	jewel_mesh.radius = 0.075
	jewel_mesh.height = 0.15
	jewel.mesh = jewel_mesh
	jewel.position = Vector3(0.0, 1.90, -0.02)
	var jewel_material := StandardMaterial3D.new()
	jewel_material.albedo_color = Palette.WATER_LIGHT
	jewel_material.emission_enabled = true
	jewel_material.emission = Palette.WATER.darkened(0.3)
	jewel.material_override = jewel_material
	add_child(jewel)


func _add_spear_visual() -> void:
	var spear := MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.025
	shaft.bottom_radius = 0.035
	shaft.height = 1.65
	spear.mesh = shaft
	spear.position = Vector3(0.34, 1.0, -0.02)
	spear.rotation.z = -0.24
	var shaft_material := StandardMaterial3D.new()
	shaft_material.albedo_color = Palette.WOOD.lightened(0.2)
	spear.material_override = shaft_material
	add_child(spear)

	var spear_tip := MeshInstance3D.new()
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.0
	tip_mesh.bottom_radius = 0.085
	tip_mesh.bottom_radius = 0.085
	tip_mesh.height = 0.22
	spear_tip.mesh = tip_mesh
	spear_tip.position = Vector3(0.53, 1.80, -0.02)
	spear_tip.rotation.z = -0.24
	var tip_material := StandardMaterial3D.new()
	tip_material.albedo_color = Palette.METAL.lightened(0.15)
	spear_tip.material_override = tip_material
	add_child(spear_tip)


func _create_role_marker() -> void:
	var marker := MeshInstance3D.new()
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.13
	marker_mesh.height = 0.26
	marker.mesh = marker_mesh
	marker.position = Vector3(0.0, 1.53, 0.0)

	var marker_material := StandardMaterial3D.new()
	match role:
		UnitRole.RANGED:
			marker_material.albedo_color = Palette.GOLD_LIGHT
			marker_material.emission_enabled = true
			marker_material.emission = Palette.GOLD.darkened(0.45)
		UnitRole.SPEAR:
			marker_material.albedo_color = Palette.REWARD
		UnitRole.CAVALRY:
			marker_material.albedo_color = Palette.GOLD
			marker_material.emission_enabled = true
			marker_material.emission = Palette.GOLD.darkened(0.55)
		_:
			marker_material.albedo_color = Palette.METAL.lightened(0.2)
	marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = marker_material
	add_child(marker)


func _create_health_bar() -> void:
	var bar_root := Node3D.new()
	bar_root.position = Vector3(0.0, 2.02 if role == UnitRole.CAVALRY else 1.82, 0.0)
	add_child(bar_root)

	var background := MeshInstance3D.new()
	var background_mesh := BoxMesh.new()
	background_mesh.size = Vector3(1.02, 0.10, 0.08)
	background.mesh = VisualCacheScript.cache_mesh_resource(background_mesh)
	var background_material := VisualCacheScript.get_material("unit:health:background", func() -> Material:
		var material := StandardMaterial3D.new()
		material.albedo_color = Palette.UI_BRONZE_DARK
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return material
	)
	background.material_override = background_material
	bar_root.add_child(background)

	_health_fill = MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(0.92, 0.065, 0.09)
	_health_fill.mesh = VisualCacheScript.cache_mesh_resource(fill_mesh)
	_health_fill_material = _get_health_material("good")
	_health_fill.material_override = _health_fill_material
	bar_root.add_child(_health_fill)


func _update_health_bar() -> void:
	if not is_instance_valid(_health_fill):
		return
	var ratio := clampf(health / maxf(max_health, 1.0), 0.0, 1.0)
	_health_fill.scale.x = maxf(ratio, 0.001)
	_health_fill.position.x = -0.46 * (1.0 - ratio)
	var health_band := "good"
	if ratio <= 0.25:
		health_band = "critical"
	elif ratio <= 0.55:
		health_band = "warning"
	_health_fill_material = _get_health_material(health_band)
	_health_fill.material_override = _health_fill_material


func _get_health_material(band: String) -> StandardMaterial3D:
	var color := Palette.HEALTH_GOOD
	if band == "warning":
		color = Palette.HEALTH_WARNING
	elif band == "critical":
		color = Palette.HEALTH_CRITICAL
	return VisualCacheScript.get_material("unit:health:" + band, func() -> Material:
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return material
	) as StandardMaterial3D


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


func apply_rally(duration: float, damage_bonus: float, speed_bonus: float) -> void:
	rally_timer = maxf(rally_timer, duration)
	rally_damage_bonus = maxf(rally_damage_bonus, damage_bonus)
	rally_speed_bonus = maxf(rally_speed_bonus, speed_bonus)
	if health > 0.0:
		health = minf(max_health, health + max_health * 0.12)
		_update_health_bar()


func activate_rally() -> bool:
	if role != UnitRole.COMMANDER or rally_cooldown_timer > 0.0 or health <= 0.0:
		return false
	var radius := 8.0 + float(commander_leadership) * 0.85
	var duration := 6.0 + float(commander_tactics) * 1.5
	var damage_bonus := 0.12 + float(commander_tactics) * 0.025
	var speed_bonus := 0.08 + float(commander_tactics) * 0.015
	var affected := 0
	for node in get_tree().get_nodes_in_group("battle_units"):
		if not node is BattleUnit or node.is_queued_for_deletion():
			continue
		var ally := node as BattleUnit
		if ally.team != team or ally.health <= 0.0:
			continue
		if global_position.distance_to(ally.global_position) <= radius:
			ally.apply_rally(duration, damage_bonus, speed_bonus)
			affected += 1
	if affected <= 0:
		return false
	rally_cooldown_timer = maxf(14.0, 28.0 - float(commander_tactics) * 2.5)
	return true


func _refresh_commander_aura() -> void:
	if role != UnitRole.COMMANDER or health <= 0.0:
		return
	var radius := 7.0 + float(commander_leadership) * 0.85
	var damage_bonus := 0.04 + float(commander_leadership) * 0.025
	var speed_bonus := 0.035 + float(commander_leadership) * 0.018
	for node in get_tree().get_nodes_in_group("battle_units"):
		if not node is BattleUnit or node.is_queued_for_deletion():
			continue
		var ally := node as BattleUnit
		if ally.team != team or ally.health <= 0.0:
			continue
		if global_position.distance_to(ally.global_position) <= radius:
			ally.command_aura_timer = 0.35
			ally.command_damage_bonus = maxf(ally.command_damage_bonus, damage_bonus)
			ally.command_speed_bonus = maxf(ally.command_speed_bonus, speed_bonus)


func _try_auto_rally() -> void:
	if role != UnitRole.COMMANDER or team == 0 or rally_cooldown_timer > 0.0:
		return
	var radius := 8.0 + float(commander_leadership) * 0.85
	var nearby_allies := 0
	var wounded_allies := 0
	for node in get_tree().get_nodes_in_group("battle_units"):
		if not node is BattleUnit or node.is_queued_for_deletion():
			continue
		var ally := node as BattleUnit
		if ally.team != team or ally.health <= 0.0:
			continue
		if global_position.distance_to(ally.global_position) <= radius:
			nearby_allies += 1
			if ally.health <= ally.max_health * 0.72:
				wounded_allies += 1
	if nearby_allies >= 3 and wounded_allies >= 2:
		activate_rally()


func take_damage(amount: float, attacker: BattleUnit = null) -> void:
	if health <= 0.0:
		return
	var mitigated_damage := maxf(1.0, amount - armor)
	var applied_damage := minf(health, maxf(mitigated_damage, 0.0))
	health = maxf(0.0, health - applied_damage)
	if is_instance_valid(attacker) and attacker != self:
		attacker.damage_dealt += applied_damage
	_update_health_bar()
	if health <= 0.0:
		if is_instance_valid(attacker) and attacker != self:
			attacker.kills += 1
		eliminated.emit(self, attacker)
		queue_free()



func _process(delta: float) -> void:
	if not is_instance_valid(_visual_root):
		return
	var moving := velocity.length_squared() > 0.08
	_animation_clock += delta * (7.0 if moving else 1.8)
	var bob := sin(_animation_clock) * (0.055 if moving else 0.018)
	_visual_root.position.y = bob
	if moving:
		var desired_angle := atan2(-velocity.z, velocity.x)
		if team == 1:
			desired_angle -= PI
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, desired_angle, minf(delta * 7.0, 1.0))

func _physics_process(delta: float) -> void:
	if health <= 0.0:
		return

	_attack_timer = maxf(0.0, _attack_timer - delta * (1.0 + command_speed_bonus + rally_speed_bonus))
	_charge_timer = maxf(0.0, _charge_timer - delta)
	rally_cooldown_timer = maxf(0.0, rally_cooldown_timer - delta)
	rally_timer = maxf(0.0, rally_timer - delta)
	command_aura_timer = maxf(0.0, command_aura_timer - delta)
	if command_aura_timer <= 0.0:
		command_damage_bonus = 0.0
		command_speed_bonus = 0.0
	if rally_timer <= 0.0:
		rally_damage_bonus = 0.0
		rally_speed_bonus = 0.0
	_moving_fast = false
	if role == UnitRole.COMMANDER:
		_refresh_commander_aura()
		if team == 1:
			_try_auto_rally()

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
			var strike_damage := get_strike_damage_against(_target) * (1.0 + command_damage_bonus + rally_damage_bonus)
			if role == UnitRole.CAVALRY and _charge_armed and _charge_timer <= 0.0:
				_charge_timer = 4.5
				_charge_armed = false
			_target.take_damage(strike_damage, self)
			_attack_timer = attack_cooldown
	elif _order_mode == OrderMode.HOLD:
		# Hold means defend this exact position, not chase a target.
		_target = null
		velocity = Vector3.ZERO
	else:
		_steer(offset.normalized())


func get_strike_damage_against(target: BattleUnit) -> float:
	var strike_damage := attack_damage
	if role == UnitRole.SPEAR and is_instance_valid(target) and target.role == UnitRole.CAVALRY:
		strike_damage *= anti_cavalry_multiplier
	if role == UnitRole.CAVALRY and _charge_armed and _charge_timer <= 0.0:
		strike_damage *= charge_multiplier
	return strike_damage


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
	projectile.damage = attack_damage * (1.0 + command_damage_bonus + rally_damage_bonus)
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
	velocity = desired_direction * move_speed * (1.0 + command_speed_bonus + rally_speed_bonus)
	_moving_fast = role == UnitRole.CAVALRY and velocity.length() >= move_speed * 0.75
	if _moving_fast and _charge_timer <= 0.0:
		_charge_armed = true


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