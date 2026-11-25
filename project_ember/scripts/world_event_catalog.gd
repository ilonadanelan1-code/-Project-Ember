extends RefCounted
class_name EmberWorldEventCatalog

## Lightweight deterministic campaign events. All effects use existing resources.

const EVENT_INTERVAL := 5
const EVENTS := [
	{
		"id": "merchant_caravan",
		"title": "Купеческий обоз",
		"body": "Караван предлагает обменять часть казны на товары и новые связи.",
		"choices": [
			{"id": "trade", "label": "Заплатить 15 золота · получить 35", "result": "Караван оставил прибыль в городской казне.", "effect": {"gold_cost": 15, "gold_gain": 35}},
			{"id": "decline", "label": "Вежливо отказаться", "result": "Караван продолжил путь.", "effect": {}},
		],
	},
	{
		"id": "refugees",
		"title": "Беженцы с тракта",
		"body": "Несколько семей ищут безопасное место после нападения разбойников.",
		"choices": [
			{"id": "shelter", "label": "Дать 10 еды · +1 население", "result": "Семьи поселились в городе.", "effect": {"food_cost": 10, "population_gain": 1}},
			{"id": "decline", "label": "Отправить дальше", "result": "Беженцы ушли к соседним землям.", "effect": {}},
		],
	},
	{
		"id": "scout_report",
		"title": "Разведчики на горизонте",
		"body": "Разведчики предлагают показать безопасные тропы и неизвестные окрестности.",
		"choices": [
			{"id": "hire_scouts", "label": "Заплатить 12 золота · открыть земли", "result": "Разведчики нанесли окрестности на карту.", "effect": {"gold_cost": 12, "reveal_bonus_radius": 4}},
			{"id": "decline", "label": "Обойтись без них", "result": "Разведчики ушли искать другого нанимателя.", "effect": {}},
		],
	},
	{
		"id": "abandoned_wagon",
		"title": "Брошенный обоз",
		"body": "У дороги найден опрокинутый обоз. Часть груза можно сохранить или продать.",
		"choices": [
			{"id": "keep_food", "label": "Забрать припасы · +12 еды", "result": "Запасы доставлены в город.", "effect": {"food_gain": 12}},
			{"id": "sell_goods", "label": "Продать груз · +18 золота", "result": "Торговцы быстро выкупили товары.", "effect": {"gold_gain": 18}},
		],
	},
	{
		"id": "veteran_instructor",
		"title": "Ветеран-инструктор",
		"body": "Опытный ветеран готов провести учения для всей армии.",
		"choices": [
			{"id": "hire_instructor", "label": "Заплатить 25 золота · +12 опыта войскам", "result": "Бойцы прошли короткий курс подготовки.", "effect": {"gold_cost": 25, "unit_xp_gain": 12}},
			{"id": "decline", "label": "Отказаться от занятий", "result": "Инструктор отправился дальше.", "effect": {}},
		],
	},
	{
		"id": "workshop_wagon",
		"title": "Телега мастеров",
		"body": "Бригада ремесленников предлагает ускорить одно из городских начинаний.",
		"choices": [
			{"id": "hire_masters", "label": "Заплатить 20 золота · +15 производства", "result": "Мастера помогли завершить часть работ.", "effect": {"gold_cost": 20, "production_gain": 15}},
			{"id": "decline", "label": "Отказаться", "result": "Бригада продолжила путь.", "effect": {}},
		],
	},
]


static func is_event_turn(turn_number: int) -> bool:
	return turn_number > 1 and turn_number % EVENT_INTERVAL == 0


static func get_event_for_turn(world_seed: int, turn_number: int) -> Dictionary:
	if EVENTS.is_empty():
		return {}
	var cycle_index := maxi(0, floori(float(turn_number) / float(EVENT_INTERVAL)) - 1)
	var event_index := posmod(world_seed + cycle_index * 7, EVENTS.size())
	return EVENTS[event_index].duplicate(true)


static func get_event_by_id(event_id: String) -> Dictionary:
	for event in EVENTS:
		if str(event.get("id", "")) == event_id:
			return event.duplicate(true)
	return {}


static func normalize_event(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		return {}
	return get_event_by_id(str(raw.get("id", "")))


static func get_choice(event_data: Dictionary, choice_id: String) -> Dictionary:
	for choice in event_data.get("choices", []):
		if str(choice.get("id", "")) == choice_id:
			return choice.duplicate(true)
	return {}
