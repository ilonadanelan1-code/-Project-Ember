extends RefCounted

## Small, data-driven pool of recruitable campaign lords.
## Stage IV keeps one commander assigned to the existing field army;
## independent army records and per-army assignments are Stage V work.

const MAX_HERO_ROSTER_SIZE := 4

const CANDIDATES := [
	{
		"id": "lord_ragnar",
		"name": "Рагнар Вест",
		"title": "Маршал рубежа",
		"cost": 100,
		"specialty": "leadership",
		"description": "Опытный командир. Начинает с рангом Лидерства 1.",
	},
	{
		"id": "lord_mirena",
		"name": "Мирена Астэр",
		"title": "Полевая тактик",
		"cost": 100,
		"specialty": "tactics",
		"description": "Тактик и организатор. Начинает с рангом Тактики 1.",
	},
	{
		"id": "lord_torvald",
		"name": "Торвальд Крей",
		"title": "Чемпион авангарда",
		"cost": 100,
		"specialty": "might",
		"description": "Фронтовой боец. Начинает с рангом Силы 1.",
	},
]


static func get_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate_value in CANDIDATES:
		var candidate: Dictionary = candidate_value
		result.append(candidate.duplicate(true))
	return result


static func get_candidate(candidate_id: String) -> Dictionary:
	for candidate_value in CANDIDATES:
		var candidate: Dictionary = candidate_value
		if str(candidate.get("id", "")) == candidate_id:
			return candidate.duplicate(true)
	return {}
