extends SceneTree

const Planner = preload("res://scripts/strategic_ai_planner.gd")
const KingdomAI = preload("res://scripts/kingdom_ai.gd")
const World = preload("res://scripts/world_generator.gd")
const Diplomacy = preload("res://scripts/diplomacy_catalog.gd")
const UnitCatalog = preload("res://scripts/unit_catalog.gd")
const CampaignStateScript = preload("res://scripts/campaign_state.gd")

var _checks := 0
var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)


func _run() -> void:
	var seed := 531902
	var kingdoms := KingdomAI.create_initial_kingdoms(seed)
	var relations := Diplomacy.create_initial_relations(kingdoms.size(), seed)
	var first: Dictionary = kingdoms[0]
	var first_cities: Array = first.get("cities", [])
	var capital: Dictionary = first_cities[0]
	capital["gold"] = 0
	capital["food"] = 6
	first_cities[0] = capital
	first["cities"] = first_cities
	first["military_doctrine"] = 2
	kingdoms[0] = first

	var plan := Planner.evaluate_kingdom(first, kingdoms, relations, 4, Vector2i(-2, 0), [])
	_check(str(plan.get("economy_focus", "")) == "gold", "low treasury and negative net income trigger a gold-first plan")
	_check(int(plan.get("desired_army_size", 0)) >= first.get("army", []).size(), "army target accounts for the existing troops")
	_check(not bool(plan.get("expansion_allowed", true)), "a kingdom without an expansion reserve does not found another city")
	var recruit_role := str(plan.get("recruit_role", ""))
	_check(UnitCatalog.is_valid_role(recruit_role), "strategic recruitment selects a valid stable unit role")
	_check(
		recruit_role == Planner.select_recruitment_role(first, kingdoms, relations, int(plan.get("desired_army_size", 8))),
		"recruitment choice is deterministic for identical kingdom state"
	)

	Diplomacy.set_treaty(relations, Diplomacy.PLAYER_ID, 0, "war", 4)
	var player_war_plan := Planner.select_war_target(first, kingdoms, relations, Vector2i(4, 0), [])
	_check(bool(player_war_plan.get("war_active", false)), "planner detects an active war against the player")
	_check(int(player_war_plan.get("kingdom_id", -99)) == Diplomacy.PLAYER_ID, "player remains a valid strategic war target")
	_check(player_war_plan.get("cell", Planner.INVALID_CELL) == Vector2i(4, 0), "war target selection returns the player army position")

	Diplomacy.set_treaty(relations, 0, 1, "war", 5)
	var ai_war_plan := Planner.select_war_target(first, kingdoms, relations, Vector2i(4, 0), [])
	_check(bool(ai_war_plan.get("war_active", false)), "planner detects AI-versus-AI war treaties")
	_check(int(ai_war_plan.get("kingdom_id", -99)) in [Diplomacy.PLAYER_ID, 1], "war planner chooses only an active treaty opponent")

	var peaceful_relations := Diplomacy.create_initial_relations(kingdoms.size(), seed)
	var peaceful_plan := Planner.select_war_target(first, kingdoms, peaceful_relations, Vector2i(4, 0), [])
	_check(not bool(peaceful_plan.get("war_active", false)), "planner never invents a war target during peace")
	_check(not bool(peaceful_plan.get("has_target", false)), "peaceful kingdoms have no strategic war destination")

	# A hostile peace-time neighbor should trigger defensive readiness without
	# being treated as an active war or an automatic movement target.
	var threat_kingdoms := KingdomAI.create_initial_kingdoms(seed)
	var defender: Dictionary = threat_kingdoms[0].duplicate(true)
	var rival: Dictionary = threat_kingdoms[1].duplicate(true)
	var defender_cities: Array = defender.get("cities", [])
	var defender_capital: Dictionary = defender_cities[0].duplicate(true)
	var defender_cell := World.array_to_cell(defender_capital.get("cell", []))
	defender_capital["gold"] = 500
	defender_cities[0] = defender_capital
	defender["cities"] = defender_cities
	defender["army"] = []
	rival["army_cell"] = World.cell_to_array(defender_cell + Vector2i(3, 0))
	threat_kingdoms[0] = defender
	threat_kingdoms[1] = rival

	var hostile_relations := Diplomacy.create_initial_relations(threat_kingdoms.size(), seed)
	var hostile_record: Dictionary = Diplomacy.get_record(hostile_relations, 0, 1)
	hostile_record["relation"] = -75
	hostile_record["treaty"] = "peace"
	Diplomacy.set_record(hostile_relations, 0, 1, hostile_record)
	var hostile_plan := Planner.evaluate_kingdom(defender, threat_kingdoms, hostile_relations, 12, Vector2i(28, 28), [])
	_check(bool(hostile_plan.get("threatened", false)), "nearby hostile neighbor triggers defensive readiness before war")
	_check(int(hostile_plan.get("threat_score", 0)) >= 55, "hostile border threat crosses the deterministic alert threshold")
	_check(int(hostile_plan.get("threat_source_id", -99)) == 1, "defensive alert identifies the hostile neighboring kingdom")
	_check(bool(hostile_plan.get("can_recruit", false)), "a threatened but peaceful kingdom may recruit from sufficient reserves")
	_check(not bool(hostile_plan.get("expansion_allowed", true)), "a threatened weaker kingdom delays expansion until it can defend itself")
	_check(str(hostile_plan.get("defensive_posture", "")) == "alert", "peace-time threat is exposed as an alert posture")

	var claim_relations := Diplomacy.create_initial_relations(threat_kingdoms.size(), seed)
	var claim_record: Dictionary = Diplomacy.get_record(claim_relations, 0, 1)
	claim_record["relation"] = 0
	claim_record["treaty"] = "peace"
	Diplomacy.set_record(claim_relations, 0, 1, claim_record)
	var incoming_claim := Diplomacy.create_casus_belli(claim_relations, 1, 0, "border_encroachment", 12, 2)
	_check(not incoming_claim.is_empty(), "rival can hold a formal claim during peace")
	var claim_plan := Planner.evaluate_kingdom(defender, threat_kingdoms, claim_relations, 12, Vector2i(28, 28), [])
	_check(bool(claim_plan.get("threatened", false)), "nearby incoming casus belli raises a defensive alert even before relations collapse")

	var neutral_relations := Diplomacy.create_initial_relations(threat_kingdoms.size(), seed)
	var neutral_record: Dictionary = Diplomacy.get_record(neutral_relations, 0, 1)
	neutral_record["relation"] = 0
	neutral_record["treaty"] = "peace"
	Diplomacy.set_record(neutral_relations, 0, 1, neutral_record)
	var neutral_neighbor_plan := Planner.evaluate_kingdom(defender, threat_kingdoms, neutral_relations, 12, Vector2i(28, 28), [])
	_check(not bool(neutral_neighbor_plan.get("threatened", false)), "a strong nearby neutral neighbor does not trigger a false defensive alert")
	_check(not bool(Planner.select_war_target(defender, threat_kingdoms, neutral_relations, Vector2i(28, 28), []).get("war_active", false)), "peace-time threat assessment never creates a war target")

	var test_capital := World.array_to_cell(first.get("capital_cell", []))
	var candidate := test_capital + Vector2i(5, 0)
	var score_a := Planner.score_expansion_cell(candidate, test_capital, first_cities, kingdoms, 0, Vector2i(-2, 0), [], seed, World.WORLD_GENERATION_VERSION, [])
	var score_b := Planner.score_expansion_cell(candidate, test_capital, first_cities, kingdoms, 0, Vector2i(-2, 0), [], seed, World.WORLD_GENERATION_VERSION, [])
	_check(is_finite(score_a) and score_a == score_b, "expansion scoring is deterministic and returns a finite value")
	var outpost_kingdom: Dictionary = first.duplicate(true)
	outpost_kingdom["outposts"] = [{"cell": [test_capital.x + 2, test_capital.y], "gold": 30, "food": 0, "production_bank": 0, "province_improvements": []}]
	var outpost_kingdoms: Array[Dictionary] = [outpost_kingdom]
	var outpost_plan := Planner.evaluate_kingdom(outpost_kingdom, outpost_kingdoms, peaceful_relations, 9, Vector2i(28, 28), [])
	_check(int(outpost_plan.get("outpost_count", 0)) == 1 and int(outpost_plan.get("settlement_upkeep", 0)) == 1, "strategic planner counts outpost upkeep as part of the realm economy")
	_check(int(outpost_plan.get("gold_reserve", 0)) >= 30, "strategic planner includes outpost stores in the kingdom reserve")
	var outpost_blocked_score := Planner.score_expansion_cell(
		candidate, test_capital, [], [], -1, Vector2i(28, 28), [], seed,
		World.WORLD_GENERATION_VERSION, [], [candidate + Vector2i(1, 0)], []
	)
	_check(outpost_blocked_score <= -999999.0, "strategic expansion avoids founding cities beside player outposts")
	_check(CampaignStateScript.SAVE_VERSION == 1, "the strategic planner keeps legacy campaign save schema version one")

	# Regression: a peaceful AI realm must actually found cities over a long campaign.
	# Previously the desired army size rose to 10 before the first expansion, so
	# maintenance consumed almost all market income and expansion funds never grew.
	var growth_seed := 842173
	var growth_kingdoms := KingdomAI.create_initial_kingdoms(growth_seed)
	var growth_relations: Dictionary = {}
	var initial_city_count := 0
	for growth_kingdom in growth_kingdoms:
		initial_city_count += (growth_kingdom.get("cities", []) as Array).size()
	for growth_turn in range(1, 181):
		KingdomAI.process_turns(
			growth_kingdoms, growth_turn, Vector2i(-2, 0), [], growth_seed,
			World.WORLD_GENERATION_VERSION, [], growth_relations, [], []
		)
	var grown_city_count := 0
	var grown_outpost_count := 0
	var expanded_kingdom_count := 0
	for growth_kingdom in growth_kingdoms:
		var kingdom_cities: Array = growth_kingdom.get("cities", [])
		var kingdom_outposts: Array = growth_kingdom.get("outposts", [])
		grown_city_count += kingdom_cities.size()
		grown_outpost_count += kingdom_outposts.size()
		if kingdom_cities.size() > 1 or not kingdom_outposts.is_empty():
			expanded_kingdom_count += 1
	_check(grown_city_count > initial_city_count, "AI kingdoms found additional cities within 180 peaceful turns")
	_check(expanded_kingdom_count >= 3, "AI expansion is distributed across several kingdoms, not just one")
	_check(grown_outpost_count > 0 or grown_city_count >= initial_city_count + 4, "AI uses outposts or additional cities to extend its frontier")

	if _failures == 0:
		print("All %d strategic AI checks passed." % _checks)
		quit(0)
	else:
		push_error("Strategic AI smoke test failed: %d/%d checks." % [_failures, _checks])
		quit(1)
