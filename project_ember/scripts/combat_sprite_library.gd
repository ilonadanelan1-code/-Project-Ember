extends RefCounted
class_name CombatSpriteLibrary

const VisualAssetCatalogScript = preload("res://scripts/visual_asset_catalog.gd")

## Required Tiny Swords pixel-art atlas for every playable release.
## The public source checkout omits this licensed runtime PNG and must not replace it with 3D models.
const ATLAS_PATH := "res://assets/combat/tiny_swords/combat_units_atlas.png"
const CAVALRY_ROOT := "res://assets/combat/cavalry/"
const CELL_SIZE := 96
const ROWS_PER_TEAM := 12
const FRAME_FPS := {
	"idle": 8.0, "run": 12.0, "attack_a": 12.0, "attack_b": 12.0,
	"attack": 12.0, "shoot": 14.0, "guard": 8.0, "defend": 8.0,
}
const ROWS := {
	"warrior_idle": [0, 8], "warrior_run": [1, 6],
	"warrior_attack_a": [2, 4], "warrior_attack_b": [3, 4],
	"warrior_guard": [4, 6], "archer_idle": [5, 6],
	"archer_run": [6, 4], "archer_shoot": [7, 8],
	"lancer_idle": [8, 12], "lancer_run": [9, 6],
	"lancer_attack": [10, 3], "lancer_defence": [11, 6],
}

static var _atlas: Texture2D
static var _frames_cache: Dictionary = {}
static var _cavalry_textures: Dictionary = {}
static var _missing_asset_warning_printed: bool = false


static func has_assets() -> bool:
	return ResourceLoader.exists(ATLAS_PATH)


static func has_cavalry_assets() -> bool:
	return ResourceLoader.exists(CAVALRY_ROOT + "blue_animations.png") and ResourceLoader.exists(CAVALRY_ROOT + "red_animations.png")

static func get_frames(team: int, role: int) -> SpriteFrames:
	var safe_team := clampi(team, 0, 1)
	var safe_role := clampi(role, 0, 4)
	if safe_role == 3:
		return _get_cavalry_frames(safe_team)
	if not has_assets():
		if not _missing_asset_warning_printed:
			push_warning("CombatSpriteLibrary: required Tiny Swords pixel-art atlas is missing. This source-only checkout is not a playable release; No low-poly substitute will be rendered.")
			_missing_asset_warning_printed = true
		return null
	var cache_key := "%d:%d" % [safe_team, safe_role]
	if _frames_cache.has(cache_key):
		return _frames_cache[cache_key] as SpriteFrames
	if not is_instance_valid(_atlas):
		_atlas = load(ATLAS_PATH) as Texture2D
	if not is_instance_valid(_atlas):
		push_warning("CombatSpriteLibrary: unable to load the required pixel-art atlas. No low-poly substitute will be rendered.")
		return null

	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var faction_offset := safe_team * ROWS_PER_TEAM
	var class_key := _get_class_name(role)
	_add_animation(frames, "idle", ROWS[class_key + "_idle"], faction_offset, true)
	_add_animation(frames, "run", ROWS[class_key + "_run"], faction_offset, true)
	if class_key == "warrior":
		_add_animation(frames, "attack_a", ROWS["warrior_attack_a"], faction_offset, false)
		_add_animation(frames, "attack_b", ROWS["warrior_attack_b"], faction_offset, false)
		_add_animation(frames, "guard", ROWS["warrior_guard"], faction_offset, true)
	elif class_key == "archer":
		_add_animation(frames, "shoot", ROWS["archer_shoot"], faction_offset, false)
	else:
		_add_animation(frames, "attack", ROWS["lancer_attack"], faction_offset, false)
		_add_animation(frames, "defend", ROWS["lancer_defence"], faction_offset, true)
	_frames_cache[cache_key] = frames
	return frames


static func get_monster_frames(monster_id: String) -> SpriteFrames:
	return VisualAssetCatalogScript.get_monster_frames(monster_id)


static func get_red_knight_frames() -> SpriteFrames:
	return VisualAssetCatalogScript.get_red_knight_frames()


static func get_attack_animation(role: int, alternate: bool = false, charge_attack: bool = false, visual_override_id: String = "") -> StringName:
	if not visual_override_id.is_empty():
		return &"attack"
	match role:
		1:
			return &"shoot"
		2:
			return &"attack"
		3:
			return &"charge" if charge_attack else &"attack"
		_:
			return &"attack_b" if alternate else &"attack_a"


static func get_animation_duration(frames: SpriteFrames, animation_name: StringName) -> float:
	if not is_instance_valid(frames) or not frames.has_animation(animation_name):
		return 0.36
	var frame_count := maxi(1, frames.get_frame_count(animation_name))
	var speed := maxf(1.0, frames.get_animation_speed(animation_name))
	return float(frame_count) / speed


static func get_contact_time(role: int) -> float:
	match role:
		1:
			return 0.285
		2:
			return 0.125
		3:
			return 0.38
		_:
			return 0.155


static func get_recovery_animation(role: int, frames: SpriteFrames) -> StringName:
	if not is_instance_valid(frames):
		return &"idle"
	if role == 3:
		return &"idle"
	if (role == 0 or role == 4) and frames.has_animation("guard"):
		return &"guard"
	if role == 2 and frames.has_animation("defend"):
		return &"defend"
	return &"idle"


static func _get_cavalry_frames(team: int) -> SpriteFrames:
	var safe_team := clampi(team, 0, 1)
	var cache_key := "cavalry:%d" % safe_team
	if _frames_cache.has(cache_key):
		return _frames_cache[cache_key] as SpriteFrames

	var faction_prefix := "blue_" if safe_team == 0 else "red_"
	var atlas_path := CAVALRY_ROOT + faction_prefix + "animations.png"
	if not ResourceLoader.exists(atlas_path):
		return null
	var atlas := _load_cavalry_texture(atlas_path)
	if atlas == null:
		return null

	# The source sheets have different vertical strides. They are normalized
	# into a shared 88x82 cell atlas so every animation keeps the same sprite
	# anchor and the horse never jumps vertically when the state changes.
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_add_cavalry_animation(frames, &"idle", atlas, 0, 0, 11, Vector2i(88, 82), 8.0, true)
	_add_cavalry_animation(frames, &"run", atlas, 1, 0, 8, Vector2i(88, 82), 12.0, true)
	_add_cavalry_animation(frames, &"attack", atlas, 2, 0, 12, Vector2i(88, 82), 14.0, false)
	_add_cavalry_animation(frames, &"charge", atlas, 3, 0, 16, Vector2i(88, 82), 16.0, false)
	_frames_cache[cache_key] = frames
	return frames

static func _load_cavalry_texture(path: String) -> Texture2D:
	if _cavalry_textures.has(path):
		return _cavalry_textures[path] as Texture2D
	var texture := load(path) as Texture2D
	if is_instance_valid(texture):
		_cavalry_textures[path] = texture
	return texture


static func _add_cavalry_animation(
		frames: SpriteFrames,
		animation_name: StringName,
		texture: Texture2D,
		row: int,
		start_column: int,
		frame_count: int,
		frame_size: Vector2i,
		fps: float,
		loop: bool
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, fps)
	for frame_index in range(frame_count):
		var atlas_frame := AtlasTexture.new()
		atlas_frame.atlas = texture
		atlas_frame.region = Rect2(
			float((start_column + frame_index) * frame_size.x),
			float(row * frame_size.y),
			float(frame_size.x),
			float(frame_size.y)
		)
		frames.add_frame(animation_name, atlas_frame)


static func _get_class_name(role: int) -> String:
	match role:
		1:
			return "archer"
		2, 3:
			return "lancer"
		_:
			return "warrior"


static func _add_animation(
		frames: SpriteFrames,
		animation_name: StringName,
		row_data: Array,
		faction_offset: int,
		loop: bool
) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, float(FRAME_FPS.get(String(animation_name), 10.0)))
	var row := int(row_data[0]) + faction_offset
	var count := int(row_data[1])
	for frame_index in range(count):
		var atlas_frame := AtlasTexture.new()
		atlas_frame.atlas = _atlas
		atlas_frame.region = Rect2(
			float(frame_index * CELL_SIZE),
			float(row * CELL_SIZE),
			float(CELL_SIZE),
			float(CELL_SIZE)
		)
		frames.add_frame(animation_name, atlas_frame)
