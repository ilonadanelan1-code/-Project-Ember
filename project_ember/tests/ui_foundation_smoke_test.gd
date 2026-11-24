extends SceneTree

const ConfirmDialogScript = preload("res://scripts/confirm_dialog.gd")
const BottomSheetScript = preload("res://scripts/bottom_sheet.gd")
const IconButtonScript = preload("res://scripts/icon_button.gd")
const ToastManagerScript = preload("res://scripts/toast_manager.gd")
const HapticsScript = preload("res://scripts/haptics.gd")
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
	var metrics: Node = root.get_node_or_null("UiMetrics")
	var owns_metrics := false
	if not is_instance_valid(metrics):
		metrics = UiMetricsScript.new()
		metrics.name = "UiMetrics"
		root.add_child(metrics)
		owns_metrics = true
	var haptics := root.get_node_or_null("Haptics")
	if not is_instance_valid(haptics):
		haptics = HapticsScript.new()
		haptics.name = "Haptics"
		root.add_child(haptics)

	var dialog := ConfirmDialogScript.new()
	root.add_child(dialog)
	await process_frame
	dialog.configure("СБРОС", "Удалить прогресс?", "СТЕРЕТЬ", "ОТМЕНА", true)
	dialog.confirmed.connect(func() -> void: _confirmed_count += 1)
	dialog.open()
	dialog.call("_on_confirm_pressed")
	_check(dialog.visible and _confirmed_count == 0, "destructive action does not confirm with a normal press")
	dialog.call("_on_confirm_button_down")
	await create_timer(1.1).timeout
	_check(_confirmed_count == 1 and not dialog.visible, "destructive confirmation completes only after a full hold")

	var sheet := BottomSheetScript.new()
	root.add_child(sheet)
	await process_frame
	sheet.open()
	_check(sheet.visible, "bottom sheet opens")
	sheet.close()
	_check(not sheet.visible, "bottom sheet closes")

	var icon_button := IconButtonScript.new()
	icon_button.fallback_icon = "⚙"
	icon_button.label_text = "Настройки"
	root.add_child(icon_button)
	await process_frame
	_check(icon_button.custom_minimum_size.y >= float(metrics.call("dp", 48.0)), "IconButton enforces a 48 dp target")

	var toast_manager := ToastManagerScript.new()
	root.add_child(toast_manager)
	await process_frame
	toast_manager.show_toast("Первое сообщение")
	toast_manager.show_toast("Второе сообщение")
	toast_manager.show_toast("Третье сообщение")
	_check(toast_manager.get_toast_count() == 2, "ToastManager keeps at most two simultaneous toasts")

	haptics.set("_last_vibration_msec", 1000)
	_check(not haptics.can_vibrate_at(1079), "Haptics rate limit blocks calls before 80 ms")
	_check(haptics.can_vibrate_at(1080), "Haptics permits the next call at the 80 ms boundary")

	for node in [dialog, sheet, icon_button, toast_manager]:
		node.queue_free()
	if is_instance_valid(haptics) and haptics.name != "Haptics":
		haptics.queue_free()
	if owns_metrics:
		metrics.queue_free()
	await process_frame
	if _failures > 0:
		printerr("UI foundation tests failed: %d" % _failures)
		quit(1)
	else:
		print("All UI foundation smoke tests passed.")
		quit(0)
