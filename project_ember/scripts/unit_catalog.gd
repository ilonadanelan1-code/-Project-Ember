extends RefCounted

## Centralized unit data shared by city recruitment, saves and tactical combat.
## Keep role identifiers stable: they are written into campaign save files.

const ROLE_MELEE := "melee"
const ROLE_RANGED := "ranged"
const ROLE_SPEAR := "spear"
const ROLE_CAVALRY := "cavalry"

const VETERANCY_TIERS := [
	{"rank": 0, "id": "recruit", "name": "Новобранец", "xp_required": 0, "damage_multiplier": 1.00, "armor_bonus": 0.0},
	{"rank": 1, "id": "trained", "name": "Обученный", "xp_required": 40, "damage_multiplier": 1.03, "armor_bonus": 0.0},
	{"rank": 2, "id": "veteran", "name": "Ветеран", "xp_required": 100, "damage_multiplier": 1.06, "armor_bonus": 1.0},
	{"rank": 3, "id": "elite", "name": "Элитный", "xp_required": 180, "damage_multiplier": 1.10, "armor_bonus": 2.0},
]


static func get_veterancy_rank(experience: int) -> int:
	var rank := 0
	for tier in VETERANCY_TIERS:
		if experience >= int(tier.get("xp_required", 0)):
			rank = int(tier.get("rank", 0))
	return rank


static func get_veterancy_data(experience: int) -> Dictionary:
	var rank := get_veterancy_rank(experience)
	return VETERANCY_TIERS[rank].duplicate(true)


static func get_battle_experience(kills: int, damage_dealt: float) -> int:
	# Survivors earn a small participation award plus capped contribution XP.
	return clampi(6 + maxi(0, kills) * 8 + floori(maxf(0.0, damage_dealt) / 30.0), 6, 30)

static func get_army_upkeep(army: Array) -> int:
	var total := 0.0
	for unit in army:
		if not unit is Dictionary:
			continue
		var role_id := str(unit.get("role", ROLE_MELEE))
		var data := get_data(role_id)
		total += maxf(0.0, float(data.get("upkeep", 0.8)))
	return ceili(total)


static func role_ids() -> Array[String]:
	return [ROLE_MELEE, ROLE_RANGED, ROLE_SPEAR, ROLE_CAVALRY]


static func is_valid_role(role_id: String) -> bool:
	return role_ids().has(role_id)


static func get_data(role_id: String) -> Dictionary:
	match role_id:
		ROLE_MELEE:
			return {
				"id": ROLE_MELEE,
				"name": "Мечник",
				"description": "Надёжная пехота передовой линии",
				"max_health": 125.0,
				"move_speed": 3.8,
				"damage": 19.0,
				"attack_range": 1.65,
				"attack_cooldown": 0.9,
				"detection_range": 13.0,
				"preferred_range": 1.4,
				"projectile_speed": 0.0,
				"armor": 2.0,
				"gold_cost": 20,
				"production_cost": 3,
				"upkeep": 0.8,
				"unlock_building": "barracks",
			}
		ROLE_RANGED:
			return {
				"id": ROLE_RANGED,
				"name": "Лучник",
				"description": "Дальняя поддержка, слаб в ближнем бою",
				"max_health": 72.0,
				"move_speed": 3.35,
				"damage": 13.0,
				"attack_range": 8.0,
				"attack_cooldown": 1.45,
				"detection_range": 16.0,
				"preferred_range": 5.7,
				"projectile_speed": 12.0,
				"armor": 0.0,
				"gold_cost": 24,
				"production_cost": 4,
				"upkeep": 0.8,
				"unlock_building": "archery_range",
			}
		ROLE_SPEAR:
			return {
				"id": ROLE_SPEAR,
				"name": "Копейщик",
				"description": "Держит строй и опасен для кавалерии",
				"max_health": 108.0,
				"move_speed": 3.45,
				"damage": 18.0,
				"attack_range": 2.25,
				"attack_cooldown": 1.1,
				"detection_range": 14.0,
				"preferred_range": 1.9,
				"projectile_speed": 0.0,
				"armor": 4.0,
				"anti_cavalry_multiplier": 1.65,
				"gold_cost": 22,
				"production_cost": 4,
				"upkeep": 0.9,
				"unlock_building": "barracks",
			}
		ROLE_CAVALRY:
			return {
				"id": ROLE_CAVALRY,
				"name": "Кавалерист",
				"description": "Быстрый фланговый отряд с ударом с разбега",
				"max_health": 155.0,
				"move_speed": 5.1,
				"damage": 22.0,
				"attack_range": 1.9,
				"attack_cooldown": 1.2,
				"detection_range": 15.0,
				"preferred_range": 1.6,
				"projectile_speed": 0.0,
				"armor": 3.0,
				"charge_multiplier": 1.6,
				"gold_cost": 42,
				"production_cost": 7,
				"upkeep": 1.4,
				"unlock_building": "stable",
			}
	return {}


static func get_max_health(role_id: String) -> float:
	var data := get_data(role_id)
	return float(data.get("max_health", 125.0))


static func get_role_for_battle_index(role_index: int) -> String:
	var roles := role_ids()
	if role_index < 0 or role_index >= roles.size():
		return ROLE_MELEE
	return roles[role_index]


static func get_battle_role_index(role_id: String) -> int:
	return role_ids().find(role_id) if is_valid_role(role_id) else 0