extends RefCounted
class_name EmberArcaneVictoryCatalog

## Shared rules for the magical ascension race. Progress is additive save data;
## controlled leyline sites and province conduits are derived from existing world records.

const VICTORY_THRESHOLD := 120
const CONTAINMENT_THRESHOLD := 72
const CONTAINMENT_LEAD_MARGIN := 18
const NEXUS_POWER_PER_TURN := 4
const CONDUIT_POWER_PER_TURN := 2
const MAX_TURN_POWER := 18
const NEXUS_LOCATION_ID := "leyline_nexus"
const CONDUIT_IMPROVEMENT_ID := "arcane_conduit"


static func count_controlled_nexuses(locations: Array, owner_id: int) -> int:
	var count := 0
	for value in locations:
		if not value is Dictionary:
			continue
		var location: Dictionary = value
		if str(location.get("type", "")) != NEXUS_LOCATION_ID:
			continue
		if not bool(location.get("cleared", false)):
			continue
		if int(location.get("cleared_by", -2)) == owner_id:
			count += 1
	return count


static func count_arcane_conduits(cities: Array) -> int:
	var count := 0
	for city_value in cities:
		if not city_value is Dictionary:
			continue
		var improvements_value: Variant = city_value.get("province_improvements", [])
		if not improvements_value is Array:
			continue
		for improvement_value in improvements_value:
			if improvement_value is Dictionary and str(improvement_value.get("id", "")) == CONDUIT_IMPROVEMENT_ID:
				count += 1
	return count


static func get_affinity_power(profile: Dictionary) -> int:
	var affinities_value: Variant = profile.get("affinities", {})
	var affinities: Dictionary = affinities_value if affinities_value is Dictionary else {}
	var power := 0
	for affinity_id in ["astral", "materium", "shadow"]:
		var affinity_score := clampi(int(affinities.get(affinity_id, 0)), 0, 8)
		power += mini(2, floori(float(affinity_score) / 3.0))
	return power


static func calculate_turn_power(
		locations: Array,
		cities: Array,
		profile: Dictionary,
		owner_id: int
) -> int:
	var nexus_count := count_controlled_nexuses(locations, owner_id)
	var conduit_count := count_arcane_conduits(cities)
	var affinity_power := get_affinity_power(profile)
	return clampi(
		nexus_count * NEXUS_POWER_PER_TURN + conduit_count * CONDUIT_POWER_PER_TURN + affinity_power,
		0,
		MAX_TURN_POWER
	)


static func advance_progress(current_progress: int, turn_power: int) -> int:
	return clampi(current_progress + maxi(0, turn_power), 0, VICTORY_THRESHOLD)


static func needs_containment(progress: int) -> bool:
	return progress >= CONTAINMENT_THRESHOLD and progress < VICTORY_THRESHOLD


static func is_victory(progress: int) -> bool:
	return progress >= VICTORY_THRESHOLD


static func get_progress_label(progress: int) -> String:
	var normalized := clampi(progress, 0, VICTORY_THRESHOLD)
	return "%d/%d" % [normalized, VICTORY_THRESHOLD]
