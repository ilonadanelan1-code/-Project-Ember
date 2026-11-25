extends RefCounted
class_name EmberArmyUpgradeCatalog

## Two permanent, empire-wide upgrade ranks per existing troop role.
## Rank data is additive and safe for legacy saves (missing ranks default to zero).

const MAX_RANK := 2
const DEFINITIONS := {
	"melee": {
		"name": "Мечники",
		"building_id": "barracks",
		"building_name": "Казармы",
		"ranks": [
			{"gold_cost": 55, "name": "Усиленные щиты", "description": "+1 броня мечникам", "armor_bonus": 1.0},
			{"gold_cost": 90, "name": "Закалённые доспехи", "description": "+2 брони суммарно", "armor_bonus": 2.0},
		],
	},
	"ranged": {
		"name": "Лучники",
		"building_id": "archery_range",
		"building_name": "Стрельбище",
		"ranks": [
			{"gold_cost": 65, "name": "Улучшенные наконечники", "description": "+6% урона лучников", "damage_multiplier": 1.06},
			{"gold_cost": 105, "name": "Составные луки", "description": "+12% урона суммарно", "damage_multiplier": 1.12},
		],
	},
	"spear": {
		"name": "Копейщики",
		"building_id": "barracks",
		"building_name": "Казармы",
		"ranks": [
			{"gold_cost": 60, "name": "Утяжелённые наконечники", "description": "+0,10 к бонусу против кавалерии", "anti_cavalry_bonus": 0.10},
			{"gold_cost": 95, "name": "Строевая подготовка", "description": "+0,20 к бонусу против кавалерии суммарно", "anti_cavalry_bonus": 0.20},
		],
	},
	"cavalry": {
		"name": "Кавалерия",
		"building_id": "stable",
		"building_name": "Конюшня",
		"ranks": [
			{"gold_cost": 85, "name": "Боевые сёдла", "description": "+0,08 к множителю разгона", "charge_bonus": 0.08},
			{"gold_cost": 135, "name": "Тяжёлая сбруя", "description": "+0,16 к множителю разгона суммарно", "charge_bonus": 0.16},
		],
	},
}


static func role_ids() -> Array[String]:
	return ["melee", "ranged", "spear", "cavalry"]


static func get_definition(role_id: String) -> Dictionary:
	var value: Variant = DEFINITIONS.get(role_id, {})
	return value.duplicate(true) if value is Dictionary else {}


static func get_rank_data(role_id: String, rank: int) -> Dictionary:
	var definition := get_definition(role_id)
	var ranks: Array = definition.get("ranks", [])
	if rank <= 0 or rank > ranks.size():
		return {}
	var result: Dictionary = ranks[rank - 1].duplicate(true)
	result["role_name"] = str(definition.get("name", role_id))
	result["building_id"] = str(definition.get("building_id", "barracks"))
	result["building_name"] = str(definition.get("building_name", "Казармы"))
	result["rank"] = rank
	return result


static func get_bonuses(role_id: String, rank: int) -> Dictionary:
	return get_rank_data(role_id, clampi(rank, 0, MAX_RANK))
