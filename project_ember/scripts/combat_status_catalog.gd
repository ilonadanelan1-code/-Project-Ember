extends RefCounted
class_name CombatStatusCatalog

const EXPOSED := "exposed"

const STATUS_DATA := {
	EXPOSED: {
		"name": "Открытая защита",
		"duration": 1.8,
		"incoming_damage_multiplier": 1.10,
		"marker": "!",
		"color_html": "#FFAD33",
	}
}

static func get_data(status_id: String) -> Dictionary:
	var data: Dictionary = STATUS_DATA.get(status_id, {})
	return data.duplicate(true)
