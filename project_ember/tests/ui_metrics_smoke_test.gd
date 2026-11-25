extends SceneTree

const UiMetricsScript = preload("res://scripts/ui_metrics.gd")
const GameSettingsScript = preload("res://scripts/game_settings.gd")
const SafeAreaContainerScript = preload("res://scripts/safe_area_container.gd")

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
	var metrics := UiMetricsScript.new()
	metrics.name = "UiMetrics"
	root.add_child(metrics)

	metrics.configure_for_test(420.0, 720.0, 1080.0, 1.0)
	_check(is_equal_approx(metrics.real_px_per_dp, 2.625), "420 dpi resolves to 2.625 physical pixels per dp")
	_check(is_equal_approx(metrics.ref_px_per_real, 2.0 / 3.0), "viewport/window height ratio resolves to 0.667")
	_check(is_equal_approx(metrics.ref_px_per_dp, 1.30), "high-density phone UI scaling is capped at 1.30 reference pixels per dp")
	_check(is_equal_approx(metrics.dp(48.0), 62.4), "48 dp retains a 62px touch target after density calibration")
	metrics.configure_for_test(0.0, 720.0, 720.0, 1.0)
	_check(is_equal_approx(metrics.real_px_per_dp, 1.0), "unavailable DPI falls back to 160 dpi")
	metrics.configure_for_test(560.0, 720.0, 720.0, 1.6)
	_check(is_equal_approx(metrics.ref_px_per_dp, 2.08), "large device DPI cannot inflate UI beyond the calibrated 1.30 baseline times accessibility scale")
	_check(int(ProjectSettings.get_setting("display/window/handheld/orientation")) == 4, "orientation is Sensor Landscape")
	var settings := root.get_node("GameSettings")
	settings.ui_scale = 1.2
	settings.settings_changed.emit()
	metrics.configure_for_test(420.0, 720.0, 1080.0, settings.ui_scale)
	_check(is_equal_approx(metrics.ref_px_per_dp, 1.56), "dp conversion recalculates with the updated UI scale")
	settings.ui_scale = 1.0

	var safe_area := SafeAreaContainerScript.new()
	root.add_child(safe_area)
	await process_frame
	_check(is_instance_valid(safe_area.get_content_root()), "safe area creates a content root")
	_check(safe_area.get_content_root().mouse_filter == Control.MOUSE_FILTER_IGNORE, "safe content does not block world input")
	safe_area.queue_free()
	metrics.queue_free()
	await process_frame

	if _failures > 0:
		printerr("UI metrics smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All UI metrics smoke tests passed.")
		quit(0)
