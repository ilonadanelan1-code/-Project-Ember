extends RefCounted
class_name BattleEstimator

## Read-only tactical forecast. It estimates relative combat pressure using the same
## unit catalogue, veterancy, upgrades and role-target priorities as the real battle.
## It never applies damage, changes campaign records or resolves the engagement.

const UnitCatalogScript = preload("res://scripts/unit_catalog.gd")
const ArmyUpgradeCatalogScript = preload("res://scripts/army_upgrade_catalog.gd")
const BattleAITacticsScript = preload("res://scripts/battle_ai_tactics.gd")

const ROLE_MELEE := 0
const ROLE_RANGED := 1
const ROLE_SPEAR := 2
const ROLE_CAVALRY := 3
const ROLE_COMMANDER := 4

const CONFIDENCE_MARGIN := 12
const TERRAIN_EXPOSURE := 0.30


static func estimate(
		player_units: Array,
		enemy_units: Array,
		player_hero: Dictionary = {},
		enemy_hero: Dictionary = {},
		player_hero_stats: Dictionary = {},
		enemy_hero_stats: Dictionary = {},
		player_upgrades: Dictionary = {},
		enemy_upgrades: Dictionary = {},
		biome_id: String = "grassland",
		player_territory_armor_bonus: float = 0.0
) -> Dictionary:
	var player_force := _build_force(player_units, player_hero, player_hero_stats, player_upgrades, player_territory_armor_bonus)
	var enemy_force := _build_force(enemy_units, enemy_hero, enemy_hero_stats, enemy_upgrades, 0.0)
	var player_count := int(player_force.get("unit_count", 0))
	var enemy_count := int(enemy_force.get("unit_count", 0))
	if player_count <= 0 or enemy_count <= 0:
		return {
			"valid": false,
			"message": "Для оценки нужны две армии с боеспособными отрядами.",
			"player_units": player_count,
			"enemy_units": enemy_count,
		}
	var player_dps := _calculate_force_dps(
		player_force.get("combatants", []),
		enemy_force.get("combatants", []),
		biome_id,
		int(player_force.get("leadership", 0)),
		int(player_force.get("tactics", 0))
	)
	var enemy_dps := _calculate_force_dps(
		enemy_force.get("combatants", []),
		player_force.get("combatants", []),
		biome_id,
		int(enemy_force.get("leadership", 0)),
		int(enemy_force.get("tactics", 0))
	)
	var player_health := maxf(1.0, float(player_force.get("total_health", 0.0)))
	var enemy_health := maxf(1.0, float(enemy_force.get("total_health", 0.0)))
	var time_to_defeat_enemy := enemy_health / maxf(0.1, player_dps)
	var time_to_defeat_player := player_health / maxf(0.1, enemy_dps)
	var longest_time := maxf(1.0, maxf(time_to_defeat_enemy, time_to_defeat_player))
	var relative_advantage := clampf((time_to_defeat_player - time_to_defeat_enemy) / longest_time, -1.0, 1.0)
	var player_win_chance := clampi(roundi(50.0 + relative_advantage * 45.0), 5, 95)
	var battle_duration := minf(time_to_defeat_enemy, time_to_defeat_player)
	var player_remaining_ratio := clampf(
		(player_health - enemy_dps * battle_duration) / player_health,
		0.0,
		1.0
	)
	var enemy_remaining_ratio := clampf(
		(enemy_health - player_dps * battle_duration) / enemy_health,
		0.0,
		1.0
	)
	var player_survivors := _estimate_survivors(player_force.get("combatants", []), player_remaining_ratio)
	var enemy_survivors := _estimate_survivors(enemy_force.get("combatants", []), enemy_remaining_ratio)
	var outcome_label := "Силы примерно равны"
	if player_win_chance >= 66:
		outcome_label = "Заметное преимущество твоей армии"
	elif player_win_chance >= 56:
		outcome_label = "Небольшое преимущество твоей армии"
	elif player_win_chance <= 34:
		outcome_label = "Заметное преимущество противника"
	elif player_win_chance <= 44:
		outcome_label = "Небольшое преимущество противника"
	return {
		"valid": true,
		"player_win_chance": player_win_chance,
		"enemy_win_chance": 100 - player_win_chance,
		"confidence_low": maxi(3, player_win_chance - CONFIDENCE_MARGIN),
		"confidence_high": mini(97, player_win_chance + CONFIDENCE_MARGIN),
		"outcome_label": outcome_label,
		"player_units": player_count,
		"enemy_units": enemy_count,
		"player_survivors": player_survivors,
		"enemy_survivors": enemy_survivors,
		"player_losses": maxi(0, player_count - player_survivors),
		"enemy_losses": maxi(0, enemy_count - enemy_survivors),
		"player_dps": snappedf(player_dps, 0.01),
		"enemy_dps": snappedf(enemy_dps, 0.01),
		"player_strength": snappedf(_get_strength_score(player_force, player_dps), 0.1),
		"enemy_strength": snappedf(_get_strength_score(enemy_force, enemy_dps), 0.1),
		"player_hero_included": bool(player_force.get("hero_included", false)),
		"enemy_hero_included": bool(enemy_force.get("hero_included", false)),
		"biome_id": biome_id,
		"estimate_note": "Оценка учитывает каталог войск, здоровье, опыт, улучшения, броню, классовые взаимодействия, командиров и биом. Расстановка, ручное управление, фланги и решения в бою могут изменить исход.",
	}


static func _build_force(
		unit_values: Array,
		hero: Dictionary,
		hero_stats: Dictionary,
		upgrades: Dictionary,
		territory_armor_bonus: float
) -> Dictionary:
	var combatants: Array[Dictionary] = []
	var total_health := 0.0
	for unit_value in unit_values:
		if not unit_value is Dictionary:
			continue
		var unit: Dictionary = unit_value
		var role_id := str(unit.get("role", UnitCatalogScript.ROLE_MELEE))
		var data := UnitCatalogScript.get_data(role_id)
		if data.is_empty():
			continue
		var max_health := maxf(1.0, float(data.get("max_health", 1.0)))
		var current_health := clampf(float(unit.get("health", max_health)), 0.0, max_health)
		if current_health <= 0.0:
			continue
		var veterancy := UnitCatalogScript.get_veterancy_data(clampi(int(unit.get("experience", 0)), 0, 999999))
		var upgrade_rank := clampi(int(upgrades.get(role_id, 0)), 0, ArmyUpgradeCatalogScript.MAX_RANK)
		var upgrade := ArmyUpgradeCatalogScript.get_bonuses(role_id, upgrade_rank)
		var damage := float(data.get("damage", 1.0))
		damage *= float(veterancy.get("damage_multiplier", 1.0))
		damage *= float(upgrade.get("damage_multiplier", 1.0))
		var armor := float(data.get("armor", 0.0))
		armor += float(veterancy.get("armor_bonus", 0.0))
		armor += float(upgrade.get("armor_bonus", 0.0))
		armor += territory_armor_bonus
		combatants.append({
			"role_id": role_id,
			"role_index": _get_role_index(role_id),
			"health": current_health,
			"max_health": max_health,
			"damage": maxf(1.0, damage),
			"armor": maxf(0.0, armor),
			"cooldown": maxf(0.2, float(data.get("attack_cooldown", 1.0))),
			"anti_cavalry_multiplier": maxf(1.0, float(data.get("anti_cavalry_multiplier", 1.0)) + float(upgrade.get("anti_cavalry_bonus", 0.0))),
			"charge_multiplier": maxf(1.0, float(data.get("charge_multiplier", 1.0)) + float(upgrade.get("charge_bonus", 0.0))),
		})
		total_health += current_health
	var hero_included := false
	if not hero.is_empty() and not hero_stats.is_empty():
		var hero_max_health := maxf(1.0, float(hero_stats.get("max_health", 210.0)))
		var hero_health := clampf(float(hero.get("health", hero_max_health)), 0.0, hero_max_health)
		if hero_health <= 0.0:
			hero_health = hero_max_health * 0.35
		if hero_health > 0.0:
			combatants.append({
				"role_id": "commander",
				"role_index": ROLE_COMMANDER,
				"health": hero_health,
				"max_health": hero_max_health,
				"damage": maxf(1.0, float(hero_stats.get("attack_damage", 24.0))),
				"armor": maxf(0.0, float(hero_stats.get("armor", 4.0))),
				"cooldown": maxf(0.2, float(hero_stats.get("attack_cooldown", 0.88))),
				"anti_cavalry_multiplier": 1.0,
				"charge_multiplier": 1.0,
			})
			total_health += hero_health
			hero_included = true
	return {
		"combatants": combatants,
		"unit_count": combatants.size(),
		"total_health": total_health,
		"leadership": clampi(int(hero_stats.get("leadership", 0)), 0, 8) if hero_included else 0,
		"tactics": clampi(int(hero_stats.get("tactics", 0)), 0, 8) if hero_included else 0,
		"hero_included": hero_included,
	}


static func _calculate_force_dps(
		attackers: Array,
		defenders: Array,
		biome_id: String,
		leadership: int,
		tactics: int
) -> float:
	if attackers.is_empty() or defenders.is_empty():
		return 0.1
	var command_damage_multiplier := 1.0 + minf(0.18, (0.04 + float(leadership) * 0.025) * 0.65)
	command_damage_multiplier += minf(0.06, (0.02 + float(tactics) * 0.01) * 0.30)
	var total_dps := 0.0
	for attacker_value in attackers:
		if not attacker_value is Dictionary:
			continue
		var attacker: Dictionary = attacker_value
		var attacker_role := str(attacker.get("role_id", ""))
		var attacker_index := int(attacker.get("role_index", ROLE_MELEE))
		var expected_damage := 0.0
		var target_weight_total := 0.0
		for defender_value in defenders:
			if not defender_value is Dictionary:
				continue
			var defender: Dictionary = defender_value
			var defender_role := str(defender.get("role_id", ""))
			var defender_index := int(defender.get("role_index", ROLE_MELEE))
			var target_ratio := float(defender.get("health", 1.0)) / maxf(1.0, float(defender.get("max_health", 1.0)))
			var target_weight := maxf(1.0, BattleAITacticsScript.get_target_score(attacker_index, defender_index, 0.0, target_ratio))
			var strike_damage := float(attacker.get("damage", 1.0))
			if attacker_role == UnitCatalogScript.ROLE_SPEAR and defender_role == UnitCatalogScript.ROLE_CAVALRY:
				strike_damage *= float(attacker.get("anti_cavalry_multiplier", 1.0))
			elif attacker_role == UnitCatalogScript.ROLE_CAVALRY:
				var charge_fraction := 0.32 if biome_id != "marsh" else 0.05
				strike_damage *= lerpf(1.0, float(attacker.get("charge_multiplier", 1.0)), charge_fraction)
			if attacker_role != UnitCatalogScript.ROLE_RANGED:
				strike_damage *= 1.06
			var terrain_dealt := 1.0
			var terrain_taken := 1.0
			if attacker_role == UnitCatalogScript.ROLE_RANGED:
				if biome_id == "highlands":
					terrain_dealt = lerpf(1.0, 1.10, TERRAIN_EXPOSURE)
				if biome_id == "woodland":
					terrain_taken = lerpf(1.0, 0.82, TERRAIN_EXPOSURE)
				elif biome_id == "highlands":
					terrain_taken = lerpf(1.0, 0.92, TERRAIN_EXPOSURE)
			var mitigated_damage := maxf(1.0, strike_damage * terrain_dealt - float(defender.get("armor", 0.0)))
			mitigated_damage *= terrain_taken
			expected_damage += mitigated_damage * target_weight
			target_weight_total += target_weight
		if target_weight_total <= 0.0:
			continue
		var average_hit := expected_damage / target_weight_total
		var readiness := _get_attack_readiness(attacker_role, biome_id)
		var health_ratio := clampf(float(attacker.get("health", 1.0)) / maxf(1.0, float(attacker.get("max_health", 1.0))), 0.0, 1.0)
		total_dps += average_hit / maxf(0.2, float(attacker.get("cooldown", 1.0))) * readiness * sqrt(health_ratio) * command_damage_multiplier
	return maxf(0.1, total_dps)


static func _get_attack_readiness(role_id: String, biome_id: String) -> float:
	match role_id:
		UnitCatalogScript.ROLE_RANGED:
			return 0.92
		UnitCatalogScript.ROLE_CAVALRY:
			return 0.68 if biome_id == "marsh" else 0.78
		UnitCatalogScript.ROLE_SPEAR:
			return 0.72
		_:
			return 0.76


static func _get_role_index(role_id: String) -> int:
	match role_id:
		UnitCatalogScript.ROLE_RANGED:
			return ROLE_RANGED
		UnitCatalogScript.ROLE_SPEAR:
			return ROLE_SPEAR
		UnitCatalogScript.ROLE_CAVALRY:
			return ROLE_CAVALRY
		_:
			return ROLE_MELEE


static func _estimate_survivors(combatants: Array, remaining_ratio: float) -> int:
	var remaining := clampf(remaining_ratio, 0.0, 1.0)
	var survivors := 0
	for combatant_value in combatants:
		if not combatant_value is Dictionary:
			continue
		var combatant: Dictionary = combatant_value
		var health := float(combatant.get("health", 0.0)) * remaining
		var max_health := maxf(1.0, float(combatant.get("max_health", 1.0)))
		if health >= max_health * 0.12:
			survivors += 1
	return survivors


static func _get_strength_score(force: Dictionary, dps: float) -> float:
	var total_health := maxf(0.0, float(force.get("total_health", 0.0)))
	return sqrt(maxf(0.0, total_health * maxf(0.1, dps)))
