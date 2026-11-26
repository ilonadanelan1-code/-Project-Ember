extends RefCounted
class_name EmberItemCatalog

## Stable, data-driven hero equipment definitions and deterministic battle loot.

const MAX_HERO_INVENTORY := 24
const SLOT_IDS: Array[String] = ["weapon", "armor", "relic"]
const SLOT_NAMES := {
	"weapon": "Оружие",
	"armor": "Броня",
	"relic": "Реликвия",
}

const DEFINITIONS := {
	"iron_edge": {
		"name": "Железная кромка",
		"slot": "weapon",
		"rarity": "Обычный",
		"description": "Надёжный клинок, увеличивающий силу удара.",
		"modifiers": {"attack_damage_bonus": 3.0},
	},
	"rune_blade": {
		"name": "Рунный клинок",
		"slot": "weapon",
		"rarity": "Редкий",
		"description": "Старые руны усиливают каждый точный удар.",
		"modifiers": {"attack_damage_bonus": 4.0, "attack_damage_multiplier": 1.06},
	},
	"executioner_axe": {
		"name": "Топор палача",
		"slot": "weapon",
		"rarity": "Редкий",
		"description": "Тяжёлое оружие для решающего удара.",
		"modifiers": {"attack_damage_bonus": 7.0, "attack_speed_bonus": -0.04},
	},
	"duelist_sabre": {
		"name": "Сабля дуэлянта",
		"slot": "weapon",
		"rarity": "Эпический",
		"description": "Лёгкий клинок ускоряет атаки командира.",
		"modifiers": {"attack_damage_bonus": 2.0, "attack_speed_bonus": 0.10, "attack_range_bonus": 0.08},
	},
	"reinforced_mail": {
		"name": "Усиленная кольчуга",
		"slot": "armor",
		"rarity": "Обычный",
		"description": "Дополнительные кольца лучше держат удар.",
		"modifiers": {"armor_bonus": 2.0},
	},
	"guardian_plate": {
		"name": "Доспех стража",
		"slot": "armor",
		"rarity": "Редкий",
		"description": "Тяжёлые пластины защищают жизненно важные места.",
		"modifiers": {"armor_bonus": 3.0, "max_health_bonus": 12.0},
	},
	"scout_leathers": {
		"name": "Кожаный панцирь разведчика",
		"slot": "armor",
		"rarity": "Редкий",
		"description": "Лёгкая броня не сковывает движение.",
		"modifiers": {"armor_bonus": 1.0, "move_speed_bonus": 0.16},
	},
	"royal_armor": {
		"name": "Королевский доспех",
		"slot": "armor",
		"rarity": "Эпический",
		"description": "Реликтовая броня повышает стойкость правителя.",
		"modifiers": {"armor_bonus": 4.0, "max_health_bonus": 24.0},
	},
	"war_banner": {
		"name": "Знамя клятвы",
		"slot": "relic",
		"rarity": "Редкий",
		"description": "Знамя укрепляет власть командира над войском.",
		"modifiers": {"leadership_bonus": 1},
	},
	"tacticians_compass": {
		"name": "Компас тактика",
		"slot": "relic",
		"rarity": "Редкий",
		"description": "Старинный прибор помогает находить темп боя.",
		"modifiers": {"tactics_bonus": 1},
	},
	"giants_heart": {
		"name": "Сердце великана",
		"slot": "relic",
		"rarity": "Эпический",
		"description": "Талисман придаёт командиру необычайную силу.",
		"modifiers": {"might_bonus": 1, "max_health_bonus": 16.0},
	},
	"sigil_of_command": {
		"name": "Печать полководца",
		"slot": "relic",
		"rarity": "Легендарный",
		"description": "Печать усиливает тактический голос командира.",
		"modifiers": {"leadership_bonus": 1, "tactics_bonus": 1},
	},
}

const MODIFIER_KEYS: Array[String] = [
	"attack_damage_bonus",
	"attack_damage_multiplier",
	"attack_speed_bonus",
	"attack_range_bonus",
	"armor_bonus",
	"max_health_bonus",
	"move_speed_bonus",
	"leadership_bonus",
	"tactics_bonus",
	"might_bonus",
]


static func get_item_ids() -> Array[String]:
	var result: Array[String] = []
	for item_id in DEFINITIONS.keys():
		result.append(str(item_id))
	result.sort()
	return result


static func is_valid_item(item_id: String) -> bool:
	return DEFINITIONS.has(item_id)


static func get_item(item_id: String) -> Dictionary:
	var value: Variant = DEFINITIONS.get(item_id, {})
	return value.duplicate(true) if value is Dictionary else {}


static func get_slot_name(slot_id: String) -> String:
	return str(SLOT_NAMES.get(slot_id, slot_id))


static func get_items_for_slot(slot_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item_id in get_item_ids():
		var item := get_item(item_id)
		if str(item.get("slot", "")) == slot_id:
			item["id"] = item_id
			result.append(item)
	return result


static func get_deterministic_battle_reward(
		world_seed: int,
		turn_number: int,
		reward_sequence: int,
		target_type: String,
		target_id: String,
		hero_id: String
) -> String:
	var seed_text := "%d|%d|%d|%s|%s|%s" % [
		world_seed,
		turn_number,
		reward_sequence,
		target_type,
		target_id,
		hero_id,
	]
	var seed_value := _stable_hash(seed_text)
	if posmod(seed_value, 100) >= 62:
		return ""
	var ids := get_item_ids()
	if ids.is_empty():
		return ""
	return ids[posmod(seed_value >> 7, ids.size())]


static func _stable_hash(value: String) -> int:
	var result: int = 2166136261
	for byte_value in value.to_utf8_buffer():
		result = int((result ^ int(byte_value)) * 16777619) & 0x7fffffff
	return result
