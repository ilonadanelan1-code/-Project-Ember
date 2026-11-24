extends SceneTree
const GameSettingsScript = preload("res://scripts/game_settings.gd")
const UiMetricsScript = preload("res://scripts/ui_metrics.gd")
const UiThemeScript = preload("res://scripts/ui_theme.gd")
const VisualCacheScript = preload("res://scripts/visual_cache.gd")
var _failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("TEST FAILED: " + description)
func _run() -> void:
	var metrics := UiMetricsScript.new()
	metrics.name = "UiMetrics"
	root.add_child(metrics)
	metrics.configure_for_test(160.0, 1280.0, 1280.0, 1.0)
	_test_visual_cache()
	_test_theme()
	_test_settings_persistence()
	metrics.queue_free()
	if _failures > 0:
		printerr("Foundation smoke tests failed: %d" % _failures)
		quit(1)
	else:
		print("All Foundation smoke tests passed.")
		quit(0)
func _test_visual_cache() -> void:
	VisualCacheScript.clear()
	var first_material := VisualCacheScript.get_material("foundation:test:material", func() -> Material:
		return StandardMaterial3D.new()
	)
	var second_material := VisualCacheScript.get_material("foundation:test:material", func() -> Material:
		return StandardMaterial3D.new()
	)
	_check(first_material == second_material, "the same material cache key returns the same resource")
	_check(VisualCacheScript.get_material_count() == 1, "material cache stores one resource per key")
	var first_mesh := VisualCacheScript.get_mesh("foundation:test:mesh", func() -> Mesh:
		return SphereMesh.new()
	)
	var second_mesh := VisualCacheScript.get_mesh("foundation:test:mesh", func() -> Mesh:
		return BoxMesh.new()
	)
	_check(first_mesh == second_mesh, "the same mesh cache key returns the same resource")
	_check(VisualCacheScript.get_mesh_count() == 1, "mesh cache stores one resource per key")
func _test_theme() -> void:
	var theme := UiThemeScript.create_theme(1.0)
	_check(theme.get_stylebox("normal", "Button") != null, "Theme has a normal button style")
	_check(theme.get_stylebox("hover", "Button") != null, "Theme has a hover button style")
	_check(theme.get_stylebox("pressed", "Button") != null, "Theme has a pressed button style")
	_check(theme.get_stylebox("disabled", "Button") != null, "Theme has a disabled button style")
	_check(theme.get_stylebox("focus", "Button") != null, "Theme has a focus button style")
	_check(theme.get_stylebox("panel", "PanelContainer") != null, "Theme has a shared panel style")
	_check(theme.get_stylebox("fill", "ProgressBar") != null, "Theme has a progress bar fill style")
	_check(theme.default_font_size >= 14, "base button font size is at least 14 dp at default density")
func _test_settings_persistence() -> void:
	var settings := GameSettingsScript.new()
	settings.name = "FoundationSettingsTest"
	root.add_child(settings)
	var original_quality := settings.graphics_quality
	var original_master := settings.master_volume
	var original_scale := settings.ui_scale
	var original_overlay := settings.show_fps_overlay
	settings.graphics_quality = GameSettingsScript.GraphicsQuality.LOW
	settings.master_volume = 0.37
	settings.ui_scale = 1.15
	settings.show_fps_overlay = true
	_check(settings.save_settings(), "settings are written to a separate ConfigFile")
	settings.graphics_quality = GameSettingsScript.GraphicsQuality.HIGH
	settings.master_volume = 0.9
	settings.ui_scale = 0.8
	settings.show_fps_overlay = false
	_check(settings.load_settings(), "settings file loads successfully")
	_check(settings.graphics_quality == GameSettingsScript.GraphicsQuality.LOW, "graphics quality persists")
	_check(is_equal_approx(settings.master_volume, 0.37), "master volume persists")
	_check(is_equal_approx(settings.ui_scale, 1.15), "UI scale persists")
	_check(settings.show_fps_overlay, "debug overlay preference persists")
	settings.graphics_quality = original_quality
	settings.master_volume = original_master
	settings.ui_scale = original_scale
	settings.show_fps_overlay = original_overlay
	settings.save_settings()
	settings.queue_free()
