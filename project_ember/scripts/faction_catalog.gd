extends RefCounted
class_name EmberFactionCatalog

## Data-only faction creator. The selected people, culture and two traits
## modify the existing three-resource economy and existing army roles.
## No unit, building or resource IDs are replaced.

const LEGACY_ID := "legacy"
const MAX_TRAITS := 2

const PEOPLES := {
	"riverfolk": {
		"name": "Речные люди",
		"description": "Плодородные долины и рыбацкие поселения. Начинают с запасом еды; фермы дают немного больше.",
		"kingdom_name": "Речная держава",
		"effects": {"starting_food_bonus": 12, "farm_food_bonus": 1},
	},
	"stoneborn": {
		"name": "Каменнорождённые",
		"description": "Трудолюбивые горные общины. Начинают с запасом производства; мастерские эффективнее.",
		"kingdom_name": "Каменный союз",
		"effects": {"starting_production_bonus": 8, "workshop_production_bonus": 1},
	},
	"steppe_clans": {
		"name": "Степные кланы",
		"description": "Кочевые всадники и быстрые набеги. Кавалерия дешевле в найме и содержании.",
		"kingdom_name": "Степной союз",
		"effects": {"cavalry_recruit_multiplier": 0.88, "cavalry_upkeep_multiplier": 0.90},
	},
	"woodland_kin": {
		"name": "Лесные общины",
		"description": "Следопыты и мастера засад. Лучники дешевле в найме, армия видит дальше.",
		"kingdom_name": "Лесной круг",
		"effects": {"ranged_recruit_multiplier": 0.88, "army_vision_bonus": 1},
	},
}

const CULTURES := {
	"agrarian": {
		"name": "Земледельцы",
		"description": "Упор на поля и продовольственную устойчивость. Каждая построенная ферма даёт +2 еды за ход.",
		"effects": {"farm_food_bonus": 2},
	},
	"mercantile": {
		"name": "Торговые города",
		"description": "Рынки и обмен поддерживают казну. Каждый построенный рынок даёт +2 золота за ход.",
		"effects": {"market_gold_bonus": 2},
	},
	"artisan": {
		"name": "Ремесленные гильдии",
		"description": "Мастерские и производственные цепочки. Каждая мастерская даёт +2 производства за ход.",
		"effects": {"workshop_production_bonus": 2},
	},
	"warrior": {
		"name": "Военные дружины",
		"description": "Организованный набор и служба. Найм всех существующих ролей дешевле на 6%.",
		"effects": {"recruit_multiplier": 0.94},
	},
}

const TRAITS := {
	"disciplined": {
		"name": "Строгая дисциплина",
		"description": "Содержание армии дешевле на 8%.",
		"effects": {"army_upkeep_multiplier": 0.92},
	},
	"veteran_cadre": {
		"name": "Костяк ветеранов",
		"description": "Каждый стартовый боец начинает с 20 опыта.",
		"effects": {"starting_unit_experience": 20},
	},
	"frontier_guides": {
		"name": "Проводники рубежей",
		"description": "Армия раскрывает туман войны на 1 гекс дальше.",
		"effects": {"army_vision_bonus": 1},
	},
	"provincial_charters": {
		"name": "Провинциальные грамоты",
		"description": "+1 дополнительный участок в каждом городе.",
		"effects": {"province_slot_bonus": 1},
	},
	"guild_charters": {
		"name": "Хартии гильдий",
		"description": "Найм всех существующих ролей дешевле на 6%.",
		"effects": {"recruit_multiplier": 0.94},
	},
	"public_granaries": {
		"name": "Общественные амбары",
		"description": "+1 еда за ход в каждом городе.",
		"effects": {"city_food_income_bonus": 1},
	},
}

const DEFAULT_EFFECTS := {
	"starting_food_bonus": 0,
	"starting_gold_bonus": 0,
	"starting_production_bonus": 0,
	"farm_food_bonus": 0,
	"market_gold_bonus": 0,
	"workshop_production_bonus": 0,
	"city_food_income_bonus": 0,
	"recruit_multiplier": 1.0,
	"ranged_recruit_multiplier": 1.0,
	"cavalry_recruit_multiplier": 1.0,
	"army_upkeep_multiplier": 1.0,
	"cavalry_upkeep_multiplier": 1.0,
	"starting_unit_experience": 0,
	"army_vision_bonus": 0,
	"province_slot_bonus": 0,
}


static func people_ids() -> Array[String]:
	return ["riverfolk", "stoneborn", "steppe_clans", "woodland_kin"]


static func culture_ids() -> Array[String]:
	return ["agrarian", "mercantile", "artisan", "warrior"]


static func trait_ids() -> Array[String]:
	return ["disciplined", "veteran_cadre", "frontier_guides", "provincial_charters", "guild_charters", "public_granaries"]


static func get_people(people_id: String) -> Dictionary:
	var value: Variant = PEOPLES.get(people_id, {})
	return value.duplicate(true) if value is Dictionary else {}


static func get_culture(culture_id: String) -> Dictionary:
	var value: Variant = CULTURES.get(culture_id, {})
	return value.duplicate(true) if value is Dictionary else {}


static func get_trait(trait_id: String) -> Dictionary:
	var value: Variant = TRAITS.get(trait_id, {})
	return value.duplicate(true) if value is Dictionary else {}


static func get_legacy_selection() -> Dictionary:
	return {
		"people_id": LEGACY_ID,
		"culture_id": LEGACY_ID,
		"trait_ids": [],
		"kingdom_name": "Старое королевство",
	}


static func get_default_selection() -> Dictionary:
	return {
		"people_id": "riverfolk",
		"culture_id": "agrarian",
		"trait_ids": ["disciplined", "veteran_cadre"],
		"kingdom_name": "Речная держава",
	}


static func is_valid_selection(value: Dictionary) -> bool:
	var people_id := str(value.get("people_id", ""))
	var culture_id := str(value.get("culture_id", ""))
	var traits_value: Variant = value.get("trait_ids", [])
	if not PEOPLES.has(people_id) or not CULTURES.has(culture_id) or not traits_value is Array:
		return false
	var traits: Array = traits_value
	if traits.size() != MAX_TRAITS:
		return false
	if str(traits[0]) == str(traits[1]):
		return false
	return TRAITS.has(str(traits[0])) and TRAITS.has(str(traits[1]))


static func normalize_selection(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return get_legacy_selection()
	var raw: Dictionary = value
	var people_id := str(raw.get("people_id", LEGACY_ID))
	var culture_id := str(raw.get("culture_id", LEGACY_ID))
	if people_id == LEGACY_ID or culture_id == LEGACY_ID:
		return get_legacy_selection()
	if not PEOPLES.has(people_id) or not CULTURES.has(culture_id):
		return get_legacy_selection()
	var raw_traits: Variant = raw.get("trait_ids", [])
	if not raw_traits is Array:
		return get_legacy_selection()
	var traits: Array[String] = []
	for raw_trait in raw_traits:
		var trait_id := str(raw_trait)
		if TRAITS.has(trait_id) and not traits.has(trait_id) and traits.size() < MAX_TRAITS:
			traits.append(trait_id)
	if traits.size() != MAX_TRAITS:
		return get_legacy_selection()
	var kingdom_name := str(raw.get("kingdom_name", "")).strip_edges()
	if kingdom_name.length() < 2:
		kingdom_name = str(PEOPLES[people_id].get("kingdom_name", "Новое королевство"))
	if kingdom_name.length() > 28:
		kingdom_name = kingdom_name.substr(0, 28)
	return {
		"people_id": people_id,
		"culture_id": culture_id,
		"trait_ids": traits,
		"kingdom_name": kingdom_name,
	}


static func get_effects(selection: Dictionary) -> Dictionary:
	var effects: Dictionary = DEFAULT_EFFECTS.duplicate(true)
	var people_data := get_people(str(selection.get("people_id", LEGACY_ID)))
	var culture_data := get_culture(str(selection.get("culture_id", LEGACY_ID)))
	_merge_effects(effects, people_data.get("effects", {}))
	_merge_effects(effects, culture_data.get("effects", {}))
	var traits_value: Variant = selection.get("trait_ids", [])
	if traits_value is Array:
		for trait_id in traits_value:
			var trait_data := get_trait(str(trait_id))
			_merge_effects(effects, trait_data.get("effects", {}))
	return effects


static func apply_income_modifiers(income: Dictionary, buildings: Array, selection: Dictionary) -> Dictionary:
	var result: Dictionary = income.duplicate(true)
	var effects := get_effects(selection)
	if buildings.has("farm"):
		result["food"] = int(result.get("food", 0)) + int(effects.get("farm_food_bonus", 0))
	if buildings.has("market"):
		result["gold"] = int(result.get("gold", 0)) + int(effects.get("market_gold_bonus", 0))
	if buildings.has("workshop"):
		result["production"] = int(result.get("production", 0)) + int(effects.get("workshop_production_bonus", 0))
	result["food"] = int(result.get("food", 0)) + int(effects.get("city_food_income_bonus", 0))
	return result


static func get_recruit_multiplier(role_id: String, selection: Dictionary) -> float:
	var effects := get_effects(selection)
	var multiplier := float(effects.get("recruit_multiplier", 1.0))
	if role_id == "ranged":
		multiplier *= float(effects.get("ranged_recruit_multiplier", 1.0))
	elif role_id == "cavalry":
		multiplier *= float(effects.get("cavalry_recruit_multiplier", 1.0))
	return clampf(multiplier, 0.75, 1.0)


static func get_upkeep_multiplier(role_id: String, selection: Dictionary) -> float:
	var effects := get_effects(selection)
	var multiplier := float(effects.get("army_upkeep_multiplier", 1.0))
	if role_id == "cavalry":
		multiplier *= float(effects.get("cavalry_upkeep_multiplier", 1.0))
	return clampf(multiplier, 0.75, 1.0)


static func apply_starting_bonus(selection: Dictionary, city_resources: Dictionary, army: Array[Dictionary]) -> Dictionary:
	var effects := get_effects(selection)
	var resources: Dictionary = city_resources.duplicate(true)
	resources["food"] = maxi(0, int(resources.get("food", 0)) + int(effects.get("starting_food_bonus", 0)))
	resources["gold"] = maxi(0, int(resources.get("gold", 0)) + int(effects.get("starting_gold_bonus", 0)))
	resources["production"] = maxi(0, int(resources.get("production", 0)) + int(effects.get("starting_production_bonus", 0)))
	var unit_xp := maxi(0, int(effects.get("starting_unit_experience", 0)))
	for unit in army:
		unit["experience"] = clampi(int(unit.get("experience", 0)) + unit_xp, 0, 999999)
	return resources


static func make_ai_selection(index: int, kingdom_name: String) -> Dictionary:
	var people_options := people_ids()
	var culture_options := culture_ids()
	var trait_options := trait_ids()
	var first_trait_index := posmod(index * 2, trait_options.size())
	var second_trait_index := posmod(first_trait_index + 1 + (index % 3), trait_options.size())
	return normalize_selection({
		"people_id": people_options[posmod(index, people_options.size())],
		"culture_id": culture_options[posmod(index * 3 + 1, culture_options.size())],
		"trait_ids": [trait_options[first_trait_index], trait_options[second_trait_index]],
		"kingdom_name": kingdom_name,
	})


static func _merge_effects(target: Dictionary, source_value: Variant) -> void:
	if not source_value is Dictionary:
		return
	var source: Dictionary = source_value
	for key in source:
		var effect_id := str(key)
		if effect_id.ends_with("_multiplier"):
			target[key] = float(target.get(key, 1.0)) * float(source[key])
		else:
			target[key] = int(target.get(key, 0)) + int(source[key])
