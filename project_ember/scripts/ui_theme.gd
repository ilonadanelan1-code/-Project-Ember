extends RefCounted
class_name UiTheme
const Palette = preload("res://scripts/art_palette.gd")
static func create_theme(ui_scale: float = 1.0) -> Theme:
	var theme := Theme.new()
	var scale := clampf(ui_scale, 0.8, 1.6)
	theme.default_font = ThemeDB.fallback_font
	theme.default_font_size = int(UiMetrics.dp(14.0))
	theme.default_base_scale = 1.0
	var panel := _panel_style(Palette.UI_BRONZE, scale)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "PopupPanel", panel)
	theme.set_stylebox("panel", "TooltipPanel", panel)
	theme.set_stylebox("normal", "Button", _button_style(Palette.UI_BRONZE_LIGHT, Palette.UI_GOLD, scale))
	theme.set_stylebox("hover", "Button", _button_style(Palette.UI_BUTTON_HOVER, Palette.GOLD_LIGHT, scale))
	theme.set_stylebox("pressed", "Button", _button_style(Palette.UI_BUTTON_PRESSED, Palette.REWARD, scale))
	theme.set_stylebox("disabled", "Button", _button_style(Palette.UI_BUTTON_DISABLED, Palette.UI_BUTTON_DISABLED_BORDER, scale, 0.55))
	theme.set_stylebox("focus", "Button", _focus_style(scale))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		theme.set_color(color_name, "Button", Palette.UI_TEXT)
	theme.set_color("font_disabled_color", "Button", Palette.UI_MUTED.darkened(0.35))
	theme.set_font_size("font_size", "Button", int(UiMetrics.dp(14.0)))
	theme.set_color("font_color", "Label", Palette.UI_TEXT)
	theme.set_font_size("font_size", "Label", int(UiMetrics.dp(14.0)))
	theme.set_stylebox("background", "ProgressBar", _flat_style(Palette.UI_PROGRESS_BACKGROUND, Palette.UI_PROGRESS_BORDER, scale))
	theme.set_stylebox("fill", "ProgressBar", _flat_style(Palette.REWARD, Palette.GOLD, scale))
	theme.set_color("font_color", "ProgressBar", Palette.UI_TEXT)
	theme.set_constant("separation", "VBoxContainer", int(UiMetrics.dp(8.0)))
	theme.set_constant("separation", "HBoxContainer", int(UiMetrics.dp(8.0)))
	return theme
static func apply_safe_area(control: Control) -> void:
	# Kept as a compatibility shim while older screens migrate to SafeAreaContainer.
	# The container listens to size changes and recomputes insets after rotation.
	if not is_instance_valid(control):
		return
	if control is SafeAreaContainer:
		(control as SafeAreaContainer).refresh_safe_area()

static func font_size(requested_size: int) -> int:
	return int(UiMetrics.dp(maxi(14, requested_size)))

static func touch_target(requested_size: float = 48.0) -> float:
	return UiMetrics.dp(maxf(48.0, requested_size))
static func _panel_style(background: Color, scale: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Palette.UI_GOLD.darkened(0.12)
	style.set_border_width_all(maxi(1, roundi(UiMetrics.dp(2.0))))
	style.set_corner_radius_all(roundi(UiMetrics.dp(10.0)))
	style.shadow_color = Palette.UI_SHADOW
	style.shadow_size = roundi(UiMetrics.dp(5.0))
	style.content_margin_left = UiMetrics.dp(10.0)
	style.content_margin_top = UiMetrics.dp(8.0)
	style.content_margin_right = UiMetrics.dp(10.0)
	style.content_margin_bottom = UiMetrics.dp(8.0)
	return style
static func _button_style(background: Color, border: Color, scale: float, alpha: float = 1.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var background_tint := background
	background_tint.a = alpha
	style.bg_color = background_tint
	style.border_color = border
	style.set_border_width_all(maxi(1, roundi(UiMetrics.dp(1.5))))
	style.set_corner_radius_all(roundi(UiMetrics.dp(7.0)))
	style.content_margin_left = UiMetrics.dp(10.0)
	style.content_margin_top = UiMetrics.dp(7.0)
	style.content_margin_right = UiMetrics.dp(10.0)
	style.content_margin_bottom = UiMetrics.dp(7.0)
	return style
static func _flat_style(background: Color, border: Color, scale: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(maxi(1, roundi(UiMetrics.dp(1.0))))
	style.set_corner_radius_all(roundi(UiMetrics.dp(4.0)))
	return style
static func _focus_style(scale: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.UI_TRANSPARENT
	style.border_color = Palette.GOLD_LIGHT
	style.set_border_width_all(maxi(2, roundi(UiMetrics.dp(2.0))))
	style.set_corner_radius_all(roundi(7.0 * scale))
	return style
