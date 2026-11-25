extends SceneTree

const ConfirmDialogScript = preload("res://scripts/confirm_dialog.gd")
const UiMetricsScript = preload("res://scripts/ui_metrics.gd")
const GameSettingsScript = preload("res://scripts/game_settings.gd")

var _failures := 0
var _confirmed_count := 0


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

	var source_file := FileAccess.open("res://scripts/strategy_map.gd", FileAccess.READ)
	var source := source_file.get_as_text() if source_file != null else ""
	if source_file != null:
		source_file.close()
	var request_start := source.find("func _restart_campaign() -> void:")
	var perform_start := source.find("func _perform_restart_campaign() -> void:")
	var next_function := source.find("\n\nfunc ", perform_start + 1)
	var request_block := source.substr(request_start, perform_start - request_start) if request_start >= 0 and perform_start > request_start else ""
	var perform_block := source.substr(perform_start, next_function - perform_start) if perform_start >= 0 and next_function > perform_start else source.substr(perform_start) if perform_start >= 0 else ""
	_check(request_start >= 0 and perform_start > request_start, "strategy map has separate request and execution functions")
	_check(request_block.contains("_restart_confirm_dialog.open()"), "new campaign request opens the confirmation dialog")
	_check(not request_block.contains("CampaignState.new_campaign()"), "request path cannot clear campaign progress directly")
	_check(perform_block.contains("CampaignState.prepare_new_campaign(false)"), "actual reset opens the protected faction-founding flow behind the confirmation callback")

	var dialog := ConfirmDialogScript.new()
	root.add_child(dialog)
	await process_frame
	dialog.configure("Новая кампания", "Стереть прогресс?", "СТЕРЕТЬ ПРОГРЕСС", "ОТМЕНА", true)
	dialog.confirmed.connect(func() -> void: _confirmed_count += 1)
	dialog.open()
	dialog.call("_on_confirm_pressed")
	_check(dialog.visible and _confirmed_count == 0, "a normal tap does not confirm a destructive reset")
	dialog.call("_on_confirm_button_down")
	await create_timer(1.1).timeout
	_check(_confirmed_count == 1 and not dialog.visible, "destructive reset confirmation emits only after a full one-second hold")

	dialog.queue_free()
	await process_frame
	if _failures > 0:
		printerr("Campaign reset confirmation tests failed: %d" % _failures)
		quit(1)
	else:
		print("All campaign reset confirmation smoke tests passed.")
		quit(0)
