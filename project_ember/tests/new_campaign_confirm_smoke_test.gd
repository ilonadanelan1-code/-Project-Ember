extends SceneTree

const StrategyMapScript = preload("res://scripts/strategy_map.gd")
const GameSettingsScript = preload("res://scripts/game_settings.gd")
const UiMetricsScript = preload("res://scripts/ui_metrics.gd")
const HapticsScript = preload("res://scripts/haptics.gd")
const CampaignStateScript = preload("res://scripts/campaign_state.gd")

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)


func _run() -> void:
	if root.get_node_or_null("GameSettings") == null:
		var settings := GameSettingsScript.new()
		settings.name = "GameSettings"
		root.add_child(settings)
	if root.get_node_or_null("UiMetrics") == null:
		var metrics := UiMetricsScript.new()
		metrics.name = "UiMetrics"
		root.add_child(metrics)
	if root.get_node_or_null("Haptics") == null:
		var haptics := HapticsScript.new()
		haptics.name = "Haptics"
		root.add_child(haptics)
	if root.get_node_or_null("CampaignState") == null:
		var campaign := CampaignStateScript.new()
		campaign.name = "CampaignState"
		root.add_child(campaign)

	var original_gold := CampaignState.city_gold
	var map := StrategyMapScript.new()
	map.name = "CampaignResetConfirmationTest"
	root.add_child(map)
	await process_frame
	CampaignState.city_gold = 777
	map.call("_restart_campaign")
	var dialog := map.get("_restart_confirm_dialog") as ConfirmDialog
	_check(is_instance_valid(dialog) and dialog.visible, "new campaign first opens a destructive confirmation")
	if is_instance_valid(dialog):
		dialog.call("_on_confirm_pressed")
	_check(CampaignState.city_gold == 777, "a normal confirm press cannot erase campaign progress")
	if is_instance_valid(dialog):
		dialog.call("_on_confirm_button_down")
		await create_timer(1.1).timeout
	_check(CampaignState.city_gold == 120, "campaign resets only after the full destructive hold")

	CampaignState.city_gold = original_gold
	CampaignState.save_campaign()
	map.queue_free()
	await process_frame
	if _failures > 0:
		printerr("Campaign reset confirmation tests failed: %d" % _failures)
		quit(1)
	else:
		print("All campaign reset confirmation smoke tests passed.")
		quit(0)
