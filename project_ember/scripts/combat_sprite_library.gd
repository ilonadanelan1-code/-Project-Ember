extends RefCounted
class_name CombatSpriteLibrary

## Optional Tiny Swords sprite atlas. Missing assets use the original renderer.
const ATLAS_PATH := "res://assets/combat/tiny_swords/combat_units_atlas.png"
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


static func has_assets() -> bool:
	return ResourceLoader.exists(ATLAS_PATH)


static func get_frames(team: int, role: int) -> SpriteFrames:
	if not has_assets():
		return null
	var cache_key := "%d:%d" % [clampi(team, 0, 1), clampi(role, 0, 4)]
	if _frames_cache.has(cache_key):
		return _frames_cache[cache_key] as SpriteFrames
	if not is_instance_valid(_atlas):
		_atlas = load(ATLAS_PATH) as Texture2D
	if not is_instance_valid(_atlas):
		push_warning("CombatSpriteLibrary: unable to load atlas; using the fallback renderer.")
		return null

	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var faction_offset := clampi(team, 0, 1) * ROWS_PER_TEAM
	var class_key := _get_class_name(role)
	_add_animation(frames, "idle", ROWS[class_key + "_idle"], faction_offset, true)
	_add_animation(frames, "run", ROWS[class_key + "_run"], faction_offset, true)
	if class_key == "warrior":
		_add_animation(frames, "attack_a", ROWS["warrior_attack_a"], faction_offset, false)
		_add_animation(frames, "attack_b", ROWS["warrior_attack_b"], faction_offset, false)
		_add_animation(frames, "guard", ROWS["warrior_guard"], faction_offset, false)
	elif class_key == "archer":
		_add_animation(frames, "shoot", ROWS["archer_shoot"], faction_offset, false)
	else:
		_add_animation(frames, "attack", ROWS["lancer_attack"], faction_offset, false)
		_add_animation(frames, "defend", ROWS["lancer_defence"], faction_offset, true)
	_frames_cache[cache_key] = frames
	return frames


static func get_attack_animation(role: int, alternate: bool = false) -> StringName:
	match role:
		1:
			return &"shoot"
		2, 3:
			return &"attack"
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
			return 0.205
		_:
			return 0.155


static func get_recovery_animation(role: int, frames: SpriteFrames) -> StringName:
	if not is_instance_valid(frames):
		return &"idle"
	if (role == 0 or role == 4) and frames.has_animation("guard"):
		return &"guard"
	if role == 2 and frames.has_animation("defend"):
		return &"defend"
	return &"idle"


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
