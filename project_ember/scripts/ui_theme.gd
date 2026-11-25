extends RefCounted
class_name UiTheme
const Palette = preload("res://scripts/art_palette.gd")
const SKIN_DIR := "res://assets/ui/pixel_ui_fantasy/"
static func _dp(value: float) -> float:
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var metrics: Node = main_loop.root.get_node_or_null("UiMetrics")
		if is_instance_valid(metrics) and metrics.has_method("dp"):
			return float(metrics.call("dp", value))
	return value

static func create_theme(ui_scale: float = 1.0) -> Theme:
	var theme := Theme.new()
	var scale := clampf(ui_scale, 0.8, 1.6)
	theme.default_font = ThemeDB.fallback_font
	theme.default_font_size = int(_dp(14.0))
	theme.default_base_scale = 1.0
	var panel := _skin_panel("panel", 12, Palette.UI_BRONZE, scale)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "PopupPanel", panel)
	theme.set_stylebox("panel", "TooltipPanel", panel)
	theme.set_stylebox("normal", "Button", _skin_button("button_normal", Palette.UI_BRONZE_LIGHT, Palette.UI_GOLD, scale))
	theme.set_stylebox("hover", "Button", _skin_button("button_hover", Palette.UI_BUTTON_HOVER, Palette.GOLD_LIGHT, scale))
	theme.set_stylebox("pressed", "Button", _skin_button("button_pressed", Palette.UI_BUTTON_PRESSED, Palette.REWARD, scale))
	theme.set_stylebox("disabled", "Button", _skin_button("button_disabled", Palette.UI_BUTTON_DISABLED, Palette.UI_BUTTON_DISABLED_BORDER, scale, 0.55))
	theme.set_stylebox("focus", "Button", _skin_focus(scale))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color"]:
		theme.set_color(color_name, "Button", Palette.UI_TEXT)
	theme.set_color("font_disabled_color", "Button", Palette.UI_MUTED.darkened(0.35))
	theme.set_font_size("font_size", "Button", int(_dp(14.0)))
	theme.set_color("font_color", "Label", Palette.UI_TEXT)
	theme.set_font_size("font_size", "Label", int(_dp(14.0)))
	theme.set_stylebox("background", "ProgressBar", _flat_style(Palette.UI_PROGRESS_BACKGROUND, Palette.UI_PROGRESS_BORDER, scale))
	theme.set_stylebox("fill", "ProgressBar", _flat_style(Palette.REWARD, Palette.GOLD, scale))
	theme.set_color("font_color", "ProgressBar", Palette.UI_TEXT)
	theme.set_constant("separation", "VBoxContainer", int(_dp(8.0)))
	theme.set_constant("separation", "HBoxContainer", int(_dp(8.0)))
	return theme
static func apply_safe_area(control: Control) -> void:
	# Kept as a compatibility shim while older screens migrate to SafeAreaContainer.
	# The container listens to size changes and recomputes insets after rotation.
	if not is_instance_valid(control):
		return
	if control is SafeAreaContainer:
		(control as SafeAreaContainer).refresh_safe_area()

static func font_size(requested_size: int) -> int:
	return int(_dp(maxi(14, requested_size)))

static func touch_target(requested_size: float = 48.0) -> float:
	return _dp(maxf(48.0, requested_size))
static func _panel_style(background: Color, scale: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Palette.UI_GOLD.darkened(0.12)
	style.set_border_width_all(maxi(1, roundi(_dp(2.0))))
	style.set_corner_radius_all(roundi(_dp(10.0)))
	style.shadow_color = Palette.UI_SHADOW
	style.shadow_size = roundi(_dp(5.0))
	style.content_margin_left = _dp(10.0)
	style.content_margin_top = _dp(8.0)
	style.content_margin_right = _dp(10.0)
	style.content_margin_bottom = _dp(8.0)
	return style
static func _button_style(background: Color, border: Color, _scale: float, alpha: float = 1.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var background_tint := background
	background_tint.a = alpha
	style.bg_color = background_tint
	style.border_color = border
	style.set_border_width_all(maxi(1, roundi(_dp(1.5))))
	style.set_corner_radius_all(roundi(_dp(7.0)))
	style.content_margin_left = _dp(10.0)
	style.content_margin_top = _dp(5.0)
	style.content_margin_right = _dp(10.0)
	style.content_margin_bottom = _dp(5.0)
	return style
static func _flat_style(background: Color, border: Color, _scale: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(maxi(1, roundi(_dp(1.0))))
	style.set_corner_radius_all(roundi(_dp(4.0)))
	return style
static func _focus_style(scale: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Palette.UI_TRANSPARENT
	style.border_color = Palette.GOLD_LIGHT
	style.set_border_width_all(maxi(2, roundi(_dp(2.0))))
	style.set_corner_radius_all(roundi(7.0 * scale))
	return style

# --- Pixel UI Fantasy skin (CC BY 4.0, see assets/ui/pixel_ui_fantasy/). Falls back to the old flat styles if a PNG is missing. ---
static func _skin_tex(file_name: String) -> Texture2D:
	var path := SKIN_DIR + file_name + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

static func _skin_box(file_name: String, margin: int, content_h: float, content_v: float, tile: bool = false) -> StyleBoxTexture:
	var tex := _skin_tex(file_name)
	if tex == null:
		return null
	var box := StyleBoxTexture.new()
	box.texture = tex
	box.texture_margin_left = margin
	box.texture_margin_top = margin
	box.texture_margin_right = margin
	box.texture_margin_bottom = margin
	box.content_margin_left = _dp(content_h)
	box.content_margin_right = _dp(content_h)
	box.content_margin_top = _dp(content_v)
	box.content_margin_bottom = _dp(content_v)
	if tile:
		box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return box

static func _skin_panel(file_name: String, margin: int, background: Color, scale: float) -> StyleBox:
	var box := _skin_box(file_name, margin, 14.0, 12.0, true)
	if box == null:
		return _panel_style(background, scale)
	return box

static func _skin_button(file_name: String, background: Color, border: Color, scale: float, alpha: float = 1.0) -> StyleBox:
	var box := _skin_box(file_name, 10, 14.0, 8.0)
	if box == null:
		return _button_style(background, border, scale, alpha)
	return box

static func _skin_focus(scale: float) -> StyleBox:
	var box := _skin_box("focus", 8, 0.0, 0.0)
	if box == null:
		return _focus_style(scale)
	box.draw_center = false
	return box
