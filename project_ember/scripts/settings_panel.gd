extends PanelContainer
class_name SettingsPanel

const Palette = preload("res://scripts/art_palette.gd")
var pause_game_on_open: bool = false
var _paused_tree_here: bool = false
var _quality_option: OptionButton
var _master_slider: HSlider
var _music_slider: HSlider
var _sfx_slider: HSlider
var _scale_slider: HSlider
var _fps_toggle: CheckButton
var _vibration_toggle: CheckButton
var _camera_slider: HSlider
func _ready() -> void:
	anchor_left = 0.06
	anchor_top = 0.04
	anchor_right = 0.94
	anchor_bottom = 0.96
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_contents()
func open_panel() -> void:
	if pause_game_on_open and not get_tree().paused:
		get_tree().paused = true
		_paused_tree_here = true
	visible = true
func close_panel() -> void:
	visible = false
	if _paused_tree_here:
		get_tree().paused = false
		_paused_tree_here = false
func _build_contents() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(UiMetrics.dp(14.0)))
	margin.add_theme_constant_override("margin_top", int(UiMetrics.dp(12.0)))
	margin.add_theme_constant_override("margin_right", int(UiMetrics.dp(14.0)))
	margin.add_theme_constant_override("margin_bottom", int(UiMetrics.dp(12.0)))
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", int(UiMetrics.dp(8.0)))
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "НАСТРОЙКИ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", int(UiMetrics.dp(22.0)))
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "ЗАКРЫТЬ"
	close_button.custom_minimum_size = Vector2(UiMetrics.dp(120.0), UiMetrics.dp(48.0))
	close_button.pressed.connect(close_panel)
	header.add_child(close_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var settings := VBoxContainer.new()
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_theme_constant_override("separation", int(UiMetrics.dp(7.0)))
	scroll.add_child(settings)
	_add_section_label(settings, "ГРАФИКА")
	_quality_option = OptionButton.new()
	_quality_option.custom_minimum_size.y = UiMetrics.dp(48.0)
	_quality_option.add_item("Низкое", GameSettings.GraphicsQuality.LOW)
	_quality_option.add_item("Среднее", GameSettings.GraphicsQuality.MEDIUM)
	_quality_option.add_item("Высокое", GameSettings.GraphicsQuality.HIGH)
	_quality_option.select(GameSettings.graphics_quality)
	_quality_option.item_selected.connect(_on_quality_selected)
	settings.add_child(_quality_option)
	_add_section_label(settings, "ЗВУК")
	_master_slider = _add_slider(settings, "Общая громкость", 0.0, 1.0, GameSettings.master_volume, func(value: float) -> void: GameSettings.set_master_volume(value))
	_music_slider = _add_slider(settings, "Музыка", 0.0, 1.0, GameSettings.music_volume, func(value: float) -> void: GameSettings.set_music_volume(value))
	_sfx_slider = _add_slider(settings, "Эффекты", 0.0, 1.0, GameSettings.sfx_volume, func(value: float) -> void: GameSettings.set_sfx_volume(value))
	_add_section_label(settings, "УПРАВЛЕНИЕ И ИНТЕРФЕЙС")
	_scale_slider = _add_slider(settings, "Масштаб интерфейса", 0.8, 1.6, GameSettings.ui_scale, func(value: float) -> void: GameSettings.set_ui_scale(value))
	_camera_slider = _add_slider(settings, "Скорость камеры", 0.5, 2.0, GameSettings.camera_speed, func(value: float) -> void: GameSettings.set_camera_speed(value))
	_fps_toggle = CheckButton.new()
	_fps_toggle.text = "Показывать FPS и статистику"
	_fps_toggle.button_pressed = GameSettings.show_fps_overlay
	_fps_toggle.custom_minimum_size.y = UiMetrics.dp(48.0)
	_fps_toggle.toggled.connect(GameSettings.set_show_fps_overlay)
	settings.add_child(_fps_toggle)
	_vibration_toggle = CheckButton.new()
	_vibration_toggle.text = "Вибрация"
	_vibration_toggle.button_pressed = GameSettings.vibration_enabled
	_vibration_toggle.custom_minimum_size.y = UiMetrics.dp(48.0)
	_vibration_toggle.toggled.connect(GameSettings.set_vibration_enabled)
	settings.add_child(_vibration_toggle)
func _add_section_label(parent: VBoxContainer, text_value: String) -> void:
	var label := Label.new()
	label.text = text_value
	label.add_theme_color_override("font_color", Palette.UI_GOLD)
	label.add_theme_font_size_override("font_size", int(UiMetrics.dp(14.0)))
	parent.add_child(label)
func _add_slider(parent: VBoxContainer, title: String, minimum: float, maximum: float, initial: float, callback: Callable) -> HSlider:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", int(UiMetrics.dp(2.0)))
	parent.add_child(group)
	var label := Label.new()
	label.text = "%s · %d%%" % [title, roundi(initial * 100.0)]
	label.add_theme_font_size_override("font_size", int(UiMetrics.dp(14.0)))
	group.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(0.0, UiMetrics.dp(48.0))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(value: float) -> void:
		label.text = "%s · %d%%" % [title, roundi(value * 100.0)]
		callback.call(value)
	)
	group.add_child(slider)
	return slider
func _on_quality_selected(index: int) -> void:
	GameSettings.set_graphics_quality(_quality_option.get_item_id(index))
