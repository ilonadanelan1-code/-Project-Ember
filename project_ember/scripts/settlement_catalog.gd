extends RefCounted
class_name EmberSettlementCatalog

## Единый баланс поселений: города, заставы, основания, аннексия,
## территориальное влияние, содержание и решения ИИ.
## Здесь хранятся только правила и числа. Состояние кампании остаётся в CampaignState.

const CityDevelopmentCatalogScript = preload("res://scripts/city_development_catalog.gd")

const TYPE_CITY := "city"
const TYPE_OUTPOST := "outpost"

# -----------------------------------------------------------------------------
# Лимиты и расширение
# -----------------------------------------------------------------------------

## Мягкий порог: первые пять городов не требуют дополнительного содержания.
const SOFT_CITY_LIMIT := 5

## Технический предел защищает кампанию от бесконтрольного разрастания записей.
## Это не экономический запрет: до него расширение ограничивается ценой и содержанием.
const MAX_PLAYER_SETTLEMENTS := 12
const MAX_AI_SETTLEMENTS := 10
## ИИ может развить до четырёх полноценных городов; остальные точки роста — заставы.
const MAX_AI_CITIES := 4

## Цена поселенца растёт за каждое поселение после стартовой столицы.
const SETTLER_BASE_GOLD_COST := 45
const SETTLER_BASE_PRODUCTION_COST := 10
const SETTLER_GOLD_PER_EXTRA_SETTLEMENT := 10
const SETTLER_PRODUCTION_PER_EXTRA_SETTLEMENT := 2
const SETTLER_MIN_POPULATION := 3
const SETTLER_POPULATION_COST := 1

# -----------------------------------------------------------------------------
# Стоимость основания
# -----------------------------------------------------------------------------

## Дополнительная оплата после выпуска поселенца.
const CITY_FOUND_GOLD_COST := 40
const CITY_FOUND_PRODUCTION_COST := 10
const OUTPOST_FOUND_GOLD_COST := 15
const OUTPOST_FOUND_PRODUCTION_COST := 4

# -----------------------------------------------------------------------------
# Размещение
# -----------------------------------------------------------------------------

## Минимум гексов между центрами поселений соответствующих типов.
const CITY_MIN_CITY_DISTANCE := 3
const CITY_MIN_OUTPOST_DISTANCE := 2
const OUTPOST_MIN_CITY_DISTANCE := 2
const OUTPOST_MIN_OUTPOST_DISTANCE := 2

## Застава может быть основана на своей территории. Чужая и спорная территория
## остаётся запрещённой так же, как для города.
const OUTPOST_ALLOWED_ON_PLAYER_TERRITORY := true
const OUTPOST_ALLOWED_ON_UNCLAIMED_TERRITORY := true
const OUTPOST_ALLOWED_ON_DISPUTED_TERRITORY := false
const OUTPOST_ALLOWED_ON_ENEMY_TERRITORY := false

# -----------------------------------------------------------------------------
# Аннексия
# -----------------------------------------------------------------------------

## Если город находится на расстоянии не более двух гексов, застава может
## присоединиться к нему. Иначе она может стать городом на собственном месте.
const OUTPOST_MERGE_MAX_DISTANCE := 2
const ANNEX_MERGE_GOLD_COST := 35
const ANNEX_MERGE_PRODUCTION_COST := 8
const ANNEX_UPGRADE_GOLD_COST := 85
const ANNEX_UPGRADE_PRODUCTION_COST := 18

## Застава ограничена двумя провинциальными улучшениями и не имеет очереди зданий.
const OUTPOST_MAX_PROVINCE_IMPROVEMENTS := 2
const MAX_CITY_PROVINCE_SLOTS := 6

# -----------------------------------------------------------------------------
# Содержание
# -----------------------------------------------------------------------------

const OUTPOST_UPKEEP_PER_TURN := 1
const CITY_UPKEEP_PER_TURN_ABOVE_SOFT_LIMIT := 2

# -----------------------------------------------------------------------------
# Территориальное влияние
# -----------------------------------------------------------------------------

## Формула города сохранена из v0.36.1.
const CITY_BASE_INFLUENCE_POWER := 46.0
const CITY_POPULATION_INFLUENCE_POWER := 1.8
const CITY_CAPITAL_INFLUENCE_BONUS := 12.0
const CITY_MILITARY_INFLUENCE_BONUS := 5.0
const CITY_INFLUENCE_FALLOFF := 9.25
const CITY_MIN_INFLUENCE_RADIUS := 3
const CITY_MAX_INFLUENCE_RADIUS := 8

## Сила заставы расположена строго между городом (минимум 47,8) и армией
## (максимум 46). Это параметры контроля карты, не боевые характеристики.
const OUTPOST_INFLUENCE_POWER := 47.0
const OUTPOST_INFLUENCE_FALLOFF := 8.5
const OUTPOST_INFLUENCE_RADIUS := 5

## Башня сохранена. Влияние армии ограничено значением 46, чтобы застава
## с силой 47 оставалась между полем и городом.
const ARMY_BASE_INFLUENCE_POWER := 24.0
const ARMY_PER_UNIT_INFLUENCE_POWER := 1.0
const ARMY_MAX_ADDITIONAL_INFLUENCE_POWER := 22.0
const ARMY_INFLUENCE_FALLOFF := 10.0
const ARMY_MIN_INFLUENCE_RADIUS := 2
const ARMY_MAX_INFLUENCE_RADIUS := 4

const WATCHTOWER_INFLUENCE_POWER := 92.0
const WATCHTOWER_INFLUENCE_FALLOFF := 10.5
const WATCHTOWER_INFLUENCE_RADIUS := 8
const TERRITORY_CONTEST_MARGIN := 6.0

# Валовый доход заставы — 2 золота; после содержания в 1 золото остаётся +1.
const OUTPOST_BASE_FOOD_INCOME := 0
const OUTPOST_BASE_GOLD_INCOME := 2
const OUTPOST_BASE_PRODUCTION_INCOME := 0
const OUTPOST_VISION_RADIUS := 3

# -----------------------------------------------------------------------------
# ИИ
# -----------------------------------------------------------------------------

## ИИ не тратит последние деньги на заставу и избегает новых поселений рядом
## с крупной вражеской армией.
const AI_CITY_FOUND_GOLD_COST := 65
const AI_CITY_FOUND_MIN_POPULATION := 6
const AI_OUTPOST_MIN_GOLD_RESERVE := 100
const AI_ANNEX_MIN_GOLD_RESERVE := 140
const AI_OUTPOST_THREAT_DISTANCE := 3
const AI_OUTPOST_MIN_SCORE := 18.0


static func is_valid_settlement_type(settlement_type: String) -> bool:
	return settlement_type == TYPE_CITY or settlement_type == TYPE_OUTPOST


static func get_settler_cost(city_count: int, outpost_count: int) -> Dictionary:
	var owned_settlements := maxi(0, city_count) + maxi(0, outpost_count)
	var extra_settlements := maxi(0, owned_settlements - 1)
	return {
		"gold": SETTLER_BASE_GOLD_COST + extra_settlements * SETTLER_GOLD_PER_EXTRA_SETTLEMENT,
		"production": SETTLER_BASE_PRODUCTION_COST + extra_settlements * SETTLER_PRODUCTION_PER_EXTRA_SETTLEMENT,
		"population": SETTLER_POPULATION_COST,
		"minimum_population": SETTLER_MIN_POPULATION,
	}


static func get_foundation_cost(settlement_type: String) -> Dictionary:
	match settlement_type:
		TYPE_CITY:
			return {"gold": CITY_FOUND_GOLD_COST, "production": CITY_FOUND_PRODUCTION_COST}
		TYPE_OUTPOST:
			return {"gold": OUTPOST_FOUND_GOLD_COST, "production": OUTPOST_FOUND_PRODUCTION_COST}
	return {}


static func get_minimum_spacing(settlement_type: String, other_type: String) -> int:
	if settlement_type == TYPE_CITY:
		return CITY_MIN_OUTPOST_DISTANCE if other_type == TYPE_OUTPOST else CITY_MIN_CITY_DISTANCE
	if settlement_type == TYPE_OUTPOST:
		return OUTPOST_MIN_OUTPOST_DISTANCE if other_type == TYPE_OUTPOST else OUTPOST_MIN_CITY_DISTANCE
	return 999999


static func get_upkeep(city_count: int, outpost_count: int) -> Dictionary:
	var extra_cities := maxi(0, city_count - SOFT_CITY_LIMIT)
	var city_upkeep := extra_cities * CITY_UPKEEP_PER_TURN_ABOVE_SOFT_LIMIT
	var outpost_upkeep := maxi(0, outpost_count) * OUTPOST_UPKEEP_PER_TURN
	return {
		"cities": city_upkeep,
		"outposts": outpost_upkeep,
		"total": city_upkeep + outpost_upkeep,
	}


static func get_city_influence_power(population: int, city_index: int, specialization: String) -> float:
	var power := CITY_BASE_INFLUENCE_POWER + float(clampi(population, 1, 20)) * CITY_POPULATION_INFLUENCE_POWER
	if city_index == 0:
		power += CITY_CAPITAL_INFLUENCE_BONUS
	if specialization == "military":
		power += CITY_MILITARY_INFLUENCE_BONUS
	return power


static func get_city_influence_radius(population: int, city_index: int, specialization: String) -> int:
	var power := get_city_influence_power(population, city_index, specialization)
	return clampi(floori(power / CITY_INFLUENCE_FALLOFF), CITY_MIN_INFLUENCE_RADIUS, CITY_MAX_INFLUENCE_RADIUS)


static func get_army_influence_power(unit_count: int) -> float:
	return ARMY_BASE_INFLUENCE_POWER + minf(ARMY_MAX_ADDITIONAL_INFLUENCE_POWER, float(maxi(0, unit_count)) * ARMY_PER_UNIT_INFLUENCE_POWER)


static func get_army_influence_radius(unit_count: int) -> int:
	var power := get_army_influence_power(unit_count)
	return clampi(floori(power / ARMY_INFLUENCE_FALLOFF), ARMY_MIN_INFLUENCE_RADIUS, ARMY_MAX_INFLUENCE_RADIUS)


static func get_outpost_income(improvements: Array) -> Dictionary:
	var result := {
		"food": OUTPOST_BASE_FOOD_INCOME,
		"gold": OUTPOST_BASE_GOLD_INCOME,
		"production": OUTPOST_BASE_PRODUCTION_INCOME,
	}
	for improvement in improvements:
		if not improvement is Dictionary:
			continue
		var data := CityDevelopmentCatalogScript.get_improvement_data(str(improvement.get("id", "")))
		result["food"] = int(result["food"]) + int(data.get("food", 0))
		result["gold"] = int(result["gold"]) + int(data.get("gold", 0))
		result["production"] = int(result["production"]) + int(data.get("production", 0))
	return result
