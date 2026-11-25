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

	var test_capital := World.array_to_cell(first.get("capital_cell", []))
	var candidate := test_capital + Vector2i(5, 0)
	var score_a := Planner.score_expansion_cell(candidate, test_capital, first_cities, kingdoms, 0, Vector2i(-2, 0), [], seed, World.WORLD_GENERATION_VERSION, [])
	var score_b := Planner.score_expansion_cell(candidate, test_capital, first_cities, kingdoms, 0, Vector2i(-2, 0), [], seed, World.WORLD_GENERATION_VERSION, [])
	_check(is_finite(score_a) and score_a == score_b, "expansion scoring is deterministic and returns a finite value")
	_check(CampaignStateScript.SAVE_VERSION == 1, "the strategic planner keeps legacy campaign save schema version one")

	if _failures == 0:
		print("All %d strategic AI checks passed." % _checks)
		quit(0)
	else:
		push_error("Strategic AI smoke test failed: %d/%d checks." % [_failures, _checks])
		quit(1)
