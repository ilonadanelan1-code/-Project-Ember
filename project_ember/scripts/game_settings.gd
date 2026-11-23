extends Node
## Player preferences are stored independently from campaign saves.
signal settings_changed
enum GraphicsQuality { LOW, MEDIUM, HIGH }
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_MASTER_VOLUME := 1.0
const DEFAULT_MUSIC_VOLUME := 0.72
const DEFAULT_SFX_VOLUME := 0.82
var graphics_quality: int = GraphicsQuality.MEDIUM
var master_volume: float = DEFAULT_MASTER_VOLUME
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
var ui_scale: float = 1.0
var show_fps_overlay: bool = false
var vibration_enabled: bool = true
var camera_speed: float = 1.0
var quality_auto_detected: bool = false
func _ready() -> void:
	load_settings()
	_ensure_audio_buses()
	_apply_audio_settings()
	_apply_ui_scale()
func load_settings() -> bool:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
	if error != OK:
		graphics_quality = _detect_initial_quality()
		master_volume = DEFAULT_MASTER_VOLUME
		music_volume = DEFAULT_MUSIC_VOLUME
		sfx_volume = DEFAULT_SFX_VOLUME
		ui_scale = 1.0
		show_fps_overlay = false
		vibration_enabled = true
		camera_speed = 1.0
		quality_auto_detected = true
		save_settings()
		return false
	graphics_quality = clampi(int(config.get_value("graphics", "quality", _detect_initial_quality())), GraphicsQuality.LOW, GraphicsQuality.HIGH)
	master_volume = clampf(float(config.get_value("audio", "master", DEFAULT_MASTER_VOLUME)), 0.0, 1.0)
	music_volume = clampf(float(config.get_value("audio", "music", DEFAULT_MUSIC_VOLUME)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx", DEFAULT_SFX_VOLUME)), 0.0, 1.0)
	ui_scale = clampf(float(config.get_value("interface", "scale", 1.0)), 0.8, 1.3)
	show_fps_overlay = bool(config.get_value("debug", "show_fps_overlay", false))
	vibration_enabled = bool(config.get_value("accessibility", "vibration", true))
	camera_speed = clampf(float(config.get_value("controls", "camera_speed", 1.0)), 0.5, 2.0)
	quality_auto_detected = bool(config.get_value("graphics", "auto_detected", false))
	_apply_audio_settings()
	_apply_ui_scale()
	settings_changed.emit()
	return true
func save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value("graphics", "quality", graphics_quality)
	config.set_value("graphics", "auto_detected", quality_auto_detected)
	config.set_value("audio", "master", master_volume)
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("interface", "scale", ui_scale)
	config.set_value("debug", "show_fps_overlay", show_fps_overlay)
	config.set_value("accessibility", "vibration", vibration_enabled)
	config.set_value("controls", "camera_speed", camera_speed)
	return config.save(SETTINGS_PATH) == OK
func set_graphics_quality(value: int) -> void:
	graphics_quality = clampi(value, GraphicsQuality.LOW, GraphicsQuality.HIGH)
	quality_auto_detected = false
	_commit_change()
func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_audio_settings()
	_commit_change()
func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_audio_settings()
	_commit_change()
func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_audio_settings()
	_commit_change()
func set_ui_scale(value: float) -> void:
	ui_scale = clampf(value, 0.8, 1.3)
	_apply_ui_scale()
	_commit_change()
func set_show_fps_overlay(value: bool) -> void:
	show_fps_overlay = value
	_commit_change()
func set_vibration_enabled(value: bool) -> void:
	vibration_enabled = value
	_commit_change()
func set_camera_speed(value: float) -> void:
	camera_speed = clampf(value, 0.5, 2.0)
	_commit_change()
func get_quality_name() -> String:
	match graphics_quality:
		GraphicsQuality.LOW:
			return "Низкое"
		GraphicsQuality.HIGH:
			return "Высокое"
		_:
			return "Среднее"
func _commit_change() -> void:
	save_settings()
	settings_changed.emit()
func _detect_initial_quality() -> int:
	var screen_size := DisplayServer.screen_get_size()
	var processor_count := OS.get_processor_count()
	if OS.has_feature("mobile"):
		if minf(float(screen_size.x), float(screen_size.y)) < 720.0 or processor_count <= 4:
			return GraphicsQuality.LOW
		return GraphicsQuality.MEDIUM
	return GraphicsQuality.HIGH
func _apply_ui_scale() -> void:
	if is_inside_tree() and get_tree().root is Window:
		get_tree().root.content_scale_factor = ui_scale
func _ensure_audio_buses() -> void:
	_ensure_audio_bus("Music")
	_ensure_audio_bus("SFX")
func _ensure_audio_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var bus_index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus_index, bus_name)
	AudioServer.set_bus_send(bus_index, "Master")
func _apply_audio_settings() -> void:
	_apply_bus_volume("Master", master_volume)
	_apply_bus_volume("Music", music_volume)
	_apply_bus_volume("SFX", sfx_volume)
func _apply_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var volume_db := -80.0 if linear_volume <= 0.001 else linear_to_db(linear_volume)
	AudioServer.set_bus_volume_db(bus_index, volume_db)
