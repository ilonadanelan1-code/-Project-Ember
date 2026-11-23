extends RefCounted
class_name UiTheme
const Palette = preload("res://scripts/art_palette.gd")
static func create_theme(ui_scale: float = 1.0) -> Theme:
	var theme := Theme.new()
	var scale := clampf(ui_scale, 0.8, 1.3)
	theme.default_font = ThemeDB.fallback_font
	theme.default_font_size = maxi(16, roundi(17.0 * scale))
	theme.default_base_scale = scale
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
	theme.set_font_size("font_size", "Button", maxi(16, roundi(16.0 * scale)))
	theme.set_color("font_color", "Label", Palette.UI_TEXT)
	theme.set_font_size("font_size", "Label", maxi(16, roundi(16.0 * scale)))
	theme.set_stylebox("background", "ProgressBar", _flat_style(Palette.UI_PROGRESS_BACKGROUND, Palette.UI_PROGRESS_BORDER, scale))
	theme.set_stylebox("fill", "ProgressBar", _flat_style(Palette.REWARD, Palette.GOLD, scale))
	theme.set_color("font_color", "ProgressBar", Palette.UI_TEXT)
	theme.set_constant("separation", "VBoxContainer", roundi(8.0 * scale))
	theme.set_constant("separation", "HBoxContainer", roundi(8.0 * scale))
	return theme
static func apply_safe_area(control: Control) -> void:
	if not is_instance_valid(control):
		return
	var safe_area := DisplayServer.get_display_safe_area()
	if safe_area.size.x <= 0 or safe_area.size.y <= 0:
		return
	var screen_size := DisplayServer.screen_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0:
		return
	var viewport_size := control.get_viewport_rect().size
	var scale_x := viewport_size.x / float(screen_size.x)
	var scale_y := viewport_size.y / float(screen_size.y)
	var right_inset := maxi(0, screen_size.x - safe_area.position.x - safe_area.size.x)
	var bottom_inset := maxi(0, screen_size.y - safe_area.position.y - safe_area.size.y)
	control.offset_left = maxf(control.offset_left, float(safe_area.position.x) * scale_x)
	control.offset_top = maxf(control.offset_top, float(safe_area.position.y) * scale_y)
	control.offset_right = minf(control.offset_right, -float(right_inset) * scale_x)
	control.offset_bottom = minf(control.offset_bottom, -float(bottom_inset) * scale_y)
static func font_size(requested_size: int) -> int:
	return maxi(16, requested_size)
static func touch_target(requested_size: float = 48.0) -> float:
	return maxf(48.0, requested_size)
static func _panel_style(background: Color, scale: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Palette.UI_GOLD.darkened(0.12)
	style.set_border_width_all(maxi(1, roundi(2.0 * scale)))
	style.set_corner_radius_all(roundi(10.0 * scale))
	style.shadow_color = Palette.UI_SHADOW
	style.shadow_size = roundi(5.0 * scale)
	style.content_margin_left = 10.0 * scale
	style.content_margin_top = 8.0 * scale
	style.content_margin_right = 10.0 * scale
	style.content_margin_bottom = 8.0 * scale
	return style
static func _button_style(background: Color, border: Color, scale: float, alpha: float = 1.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var background_tint := background
	background_tint.a = alpha
	style.bg_color = background_tint
	style.border_color = border
	style.set_border_width_all(maxi(1, roundi(1.5 * scale)))
	style.set_corner_radius_all(roundi(7.0 * scale))
	style.content_margin_left = 10.0 * scale
	style.content_margin_top = 7.0 * scale
	style.content_margin_right = 10.0 * scale
	style.content_margin_bottom = 7.0 * scale
	return style
static func _flat_style(background: Color, border: Color, scale: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(maxi(1, roundi(scale)))
	style.set_corner_radius_all(roundi(4.0 * scale))
	return style
static func _focus_style(scale: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.UI_TRANSPARENT
	style.border_color = Palette.GOLD_LIGHT
	style.set_border_width_all(maxi(2, roundi(2.0 * scale)))
	style.set_corner_radius_all(roundi(7.0 * scale))
	return style
