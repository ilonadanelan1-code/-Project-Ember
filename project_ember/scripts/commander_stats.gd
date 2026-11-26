extends RefCounted
class_name EmberCommanderStats

## Single source of truth for commander campaign and tactical combat statistics.

static func calculate(
		hero_record: Dictionary,
		equipment_modifiers: Dictionary = {},
		territory_armor_bonus: float = 0.0
) -> Dictionary:
	var level := clampi(int(hero_record.get("level", 1)), 1, 30)
	var skills_value: Variant = hero_record.get("skills", {})
	var skills: Dictionary = skills_value if skills_value is Dictionary else {}

	var leadership := clampi(int(skills.get("leadership", 0)) + int(equipment_modifiers.get("leadership_bonus", 0)), 0, 8)
	var tactics := clampi(int(skills.get("tactics", 0)) + int(equipment_modifiers.get("tactics_bonus", 0)), 0, 8)
	var might := clampi(int(skills.get("might", 0)) + int(equipment_modifiers.get("might_bonus", 0)), 0, 8)

	var max_health := maxf(1.0, 210.0 + float(level - 1) * 16.0 + float(might) * 14.0 + float(equipment_modifiers.get("max_health_bonus", 0.0)))
	var attack_damage := 24.0 + float(level - 1) * 2.4 + float(might) * 3.5
	attack_damage = (attack_damage + float(equipment_modifiers.get("attack_damage_bonus", 0.0))) * maxf(0.1, float(equipment_modifiers.get("attack_damage_multiplier", 1.0)))
	var attack_speed_bonus := float(equipment_modifiers.get("attack_speed_bonus", 0.0))
	var move_speed := maxf(2.0, 4.0 + float(tactics) * 0.06 + float(equipment_modifiers.get("move_speed_bonus", 0.0)))
	var armor := maxf(0.0, 4.0 + float(might) * 0.8 + float(equipment_modifiers.get("armor_bonus", 0.0)) + territory_armor_bonus)

	return {
		"level": level,
		"leadership": leadership,
		"tactics": tactics,
		"might": might,
		"max_health": max_health,
		"attack_damage": attack_damage,
		"move_speed": move_speed,
		"attack_range": maxf(1.0, 1.9 + float(equipment_modifiers.get("attack_range_bonus", 0.0))),
		"attack_cooldown": clampf(0.88 - attack_speed_bonus, 0.45, 1.5),
		"detection_range": 16.0,
		"preferred_range": 1.7,
		"armor": armor,
		"projectile_speed": 0.0,
	}
