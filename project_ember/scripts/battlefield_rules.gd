extends RefCounted
class_name BattlefieldRules

const BattlefieldBiomesScript = preload("res://scripts/battlefield_biomes.gd")

const ZONE_RADIUS := 2.65
const FOREST_MOVE_MULTIPLIER := 0.90
const FOREST_RANGED_TAKEN_MULTIPLIER := 0.82
const HIGHLANDS_MOVE_MULTIPLIER := 0.95
const HIGHLANDS_RANGED_DEALT_MULTIPLIER := 1.10
const HIGHLANDS_RANGED_TAKEN_MULTIPLIER := 0.92
const MARSH_INFANTRY_MOVE_MULTIPLIER := 0.82
const MARSH_CAVALRY_MOVE_MULTIPLIER := 0.65

static var _cached_key: String = ""
static var _cached_zones: Array[Dictionary] = []


## Four compact, symmetric tactical zones are generated from the existing battle seed.
## The zones are gameplay overlays only: they do not create collision bodies.
static func get_zones(biome_id: String, field_size: Vector2, seed_value: int) -> Array[Dictionary]:
	var selected_biome := biome_id if BattlefieldBiomesScript.biome_ids().has(biome_id) else BattlefieldBiomesScript.GRASSLAND
	var cache_key := "%s|%.2f|%.2f|%d" % [selected_biome, field_size.x, field_size.y, seed_value]
	if cache_key == _cached_key:
		return _cached_zones

	var zones: Array[Dictionary] = []
	var zone_type := ""
	var zone_name := ""
	match selected_biome:
		BattlefieldBiomesScript.WOODLAND:
			zone_type = "forest_cover"
			zone_name = "Лесное укрытие"
		BattlefieldBiomesScript.HIGHLANDS:
			zone_type = "high_ground"
			zone_name = "Возвышенность"
		BattlefieldBiomesScript.MARSH:
			zone_type = "mud"
			zone_name = "Топь"
		_:
			_cached_key = cache_key
			_cached_zones = zones
			return zones

	var half_x := maxf(0.0, field_size.x * 0.5 - ZONE_RADIUS - 1.0)
	var half_z := maxf(0.0, field_size.y * 0.5 - ZONE_RADIUS - 1.0)
	var center_x := minf(8.0, half_x)
	var center_z := minf(4.3, half_z)
	var jitter_x := float(posmod(absi(seed_value * 31 + 7919), 1000)) / 1000.0 * 0.42 - 0.21
	var jitter_z := float(posmod(absi(seed_value * 47 + 104729), 1000)) / 1000.0 * 0.42 - 0.21
	center_x = clampf(center_x + jitter_x, 0.0, half_x)
	center_z = clampf(center_z + jitter_z, 0.0, half_z)

	var zone_index := 0
	for sign_x in [-1.0, 1.0]:
		for sign_z in [-1.0, 1.0]:
			var center := Vector3(center_x * sign_x, 0.0, center_z * sign_z)
			zones.append({
				"id": "%s_%d" % [zone_type, zone_index + 1],
				"type": zone_type,
				"name": zone_name,
				"center": center,
				"radius": ZONE_RADIUS,
			})
			zone_index += 1

	_cached_key = cache_key
	_cached_zones = zones
	return zones


static func get_effects_at_position(
		world_position: Vector3,
		biome_id: String,
		field_size: Vector2,
		seed_value: int,
		unit_role: int = -1
) -> Dictionary:
	var effects := {
		"zone_id": "open_ground",
		"zone_type": "open_ground",
		"zone_name": "Открытая местность",
		"movement_multiplier": 1.0,
		"ranged_damage_dealt_multiplier": 1.0,
		"ranged_damage_taken_multiplier": 1.0,
		"charge_allowed": true,
	}
	for zone in get_zones(biome_id, field_size, seed_value):
		var center: Vector3 = zone.get("center", Vector3.ZERO)
		var dx := world_position.x - center.x
		var dz := world_position.z - center.z
		var radius := float(zone.get("radius", ZONE_RADIUS))
		if dx * dx + dz * dz > radius * radius:
			continue

		var zone_type := str(zone.get("type", "open_ground"))
		effects["zone_id"] = str(zone.get("id", ""))
		effects["zone_type"] = zone_type
		effects["zone_name"] = str(zone.get("name", "Открытая местность"))
		match zone_type:
			"forest_cover":
				effects["movement_multiplier"] = FOREST_MOVE_MULTIPLIER
				effects["ranged_damage_taken_multiplier"] = FOREST_RANGED_TAKEN_MULTIPLIER
			"high_ground":
				effects["movement_multiplier"] = HIGHLANDS_MOVE_MULTIPLIER
				effects["ranged_damage_dealt_multiplier"] = HIGHLANDS_RANGED_DEALT_MULTIPLIER if unit_role == 1 else 1.0
				effects["ranged_damage_taken_multiplier"] = HIGHLANDS_RANGED_TAKEN_MULTIPLIER
			"mud":
				effects["movement_multiplier"] = MARSH_CAVALRY_MOVE_MULTIPLIER if unit_role == 3 else MARSH_INFANTRY_MOVE_MULTIPLIER
				effects["charge_allowed"] = false
		break
	return effects


static func get_biome_summary(biome_id: String) -> String:
	match biome_id:
		BattlefieldBiomesScript.WOODLAND:
			return "ЛЕС: −18% стрелкового урона"
		BattlefieldBiomesScript.HIGHLANDS:
			return "ВЫСОТЫ: стрелки +10%, защита +8%"
		BattlefieldBiomesScript.MARSH:
			return "ТОПИ: пехота −18%, конница −35%"
		_:
			return "РАВНИНА: без бонусов"
