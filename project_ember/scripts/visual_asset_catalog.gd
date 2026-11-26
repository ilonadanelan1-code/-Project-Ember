extends RefCounted
class_name VisualAssetCatalog

## Runtime atlas catalog for the additional licensed Project Ember visual packs.
## A single lossless WebP is embedded in a compact JSON resource to avoid hundreds
## of loose mobile asset files. Decoded textures and frame resources are cached.
const VisualAssetDataScript = preload("res://scripts/visual_asset_data.gd")

static var _loaded: bool = false
static var _data: Dictionary = {}
static var _atlas_texture: Texture2D
static var _frame_cache: Dictionary = {}
static var _sprite_frames_cache: Dictionary = {}


static func _get_data() -> Dictionary:
	if _loaded:
		return _data
	_loaded = true
	var parsed: Variant = JSON.parse_string(VisualAssetDataScript.META_JSON)
	if parsed is Dictionary:
		_data = parsed
	else:
		push_warning("VisualAssetCatalog: runtime visual atlas JSON is invalid.")
	return _data


static func has_assets() -> bool:
	return not VisualAssetDataScript.IMAGE_WEBP_BASE64.is_empty()


static func _get_meta() -> Dictionary:
	var value: Variant = _get_data().get("meta", {})
	return value if value is Dictionary else {}


static func _get_texture() -> Texture2D:
	if is_instance_valid(_atlas_texture):
		return _atlas_texture
	var encoded := VisualAssetDataScript.IMAGE_WEBP_BASE64
	if encoded.is_empty():
		return null
	var bytes := Marshalls.base64_to_raw(encoded)
	if bytes.is_empty():
		push_warning("VisualAssetCatalog: atlas payload could not be decoded.")
		return null
	var image := Image.new()
	var error := image.load_webp_from_buffer(bytes)
	if error != OK:
		push_warning("VisualAssetCatalog: lossless WebP atlas could not be loaded (%s)." % error_string(error))
		return null
	_atlas_texture = ImageTexture.create_from_image(image)
	return _atlas_texture


static func get_frame(atlas_id: String, frame_id: String) -> Texture2D:
	var cache_key := atlas_id + ":" + frame_id
	if _frame_cache.has(cache_key):
		return _frame_cache[cache_key] as Texture2D
	var atlas := _get_texture()
	if not is_instance_valid(atlas):
		return null
	var metadata := _get_meta()
	var atlas_regions_value: Variant = metadata.get("atlas_regions", {})
	if not atlas_regions_value is Dictionary:
		return null
	var atlas_region: Dictionary = atlas_regions_value.get(atlas_id, {})
	var offset_value: Variant = atlas_region.get("offset", [])
	if not offset_value is Array or offset_value.size() < 2:
		return null
	var atlas_data: Dictionary = metadata.get(atlas_id, {})
	var frames_value: Variant = atlas_data.get("frames", {})
	if not frames_value is Dictionary:
		return null
	var frame_value: Variant = frames_value.get(frame_id, {})
	if not frame_value is Dictionary:
		return null
	var x := int(offset_value[0]) + int(frame_value.get("x", 0))
	var y := int(offset_value[1]) + int(frame_value.get("y", 0))
	var width := int(frame_value.get("w", 0))
	var height := int(frame_value.get("h", 0))
	if width <= 0 or height <= 0:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(x, y, width, height)
	_frame_cache[cache_key] = texture
	return texture


static func get_faction_banner(index: int) -> Texture2D:
	var metadata := _get_meta()
	var factions: Dictionary = metadata.get("factions", {})
	var order_value: Variant = factions.get("order", [])
	if not order_value is Array or order_value.is_empty():
		return null
	var safe_index := posmod(index, order_value.size())
	return get_frame("factions", str(order_value[safe_index]))


static func get_monster_frames(monster_id: String) -> SpriteFrames:
	var cache_key := "monster:" + monster_id
	if _sprite_frames_cache.has(cache_key):
		return _sprite_frames_cache[cache_key] as SpriteFrames
	var metadata := _get_meta()
	var monster_meta: Dictionary = metadata.get("monsters", {})
	var monster_value: Variant = monster_meta.get("monsters", {})
	if not monster_value is Dictionary:
		return null
	var monster_data_value: Variant = monster_value.get(monster_id, {})
	if not monster_data_value is Dictionary:
		return null
	var monster_data: Dictionary = monster_data_value
	var atlas := _get_texture()
	if not is_instance_valid(atlas):
		return null
	var atlas_region: Dictionary = metadata.get("atlas_regions", {}).get("monsters", {})
	var offset_value: Array = atlas_region.get("offset", [0, 0])
	var base_x := int(offset_value[0])
	var base_y := int(offset_value[1])
	var frame_size := int(monster_meta.get("frame_size", 32))
	var row := int(monster_data.get("row", -1))
	if row < 0:
		return null
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_speed("idle", float(monster_meta.get("fps", {}).get("idle", 6)))
	frames.set_animation_loop("idle", true)
	frames.add_animation("attack")
	frames.set_animation_speed("attack", float(monster_meta.get("fps", {}).get("attack", 8)))
	frames.set_animation_loop("attack", false)
	for frame_index in range(4):
		var idle_frame := AtlasTexture.new()
		idle_frame.atlas = atlas
		idle_frame.region = Rect2(base_x + frame_index * frame_size, base_y + row * frame_size, frame_size, frame_size)
		frames.add_frame("idle", idle_frame)
		var attack_frame := AtlasTexture.new()
		attack_frame.atlas = atlas
		attack_frame.region = Rect2(base_x + (frame_index + 4) * frame_size, base_y + row * frame_size, frame_size, frame_size)
		frames.add_frame("attack", attack_frame)
	_sprite_frames_cache[cache_key] = frames
	return frames


static func get_red_knight_frames() -> SpriteFrames:
	const CACHE_KEY := "red_knight"
	if _sprite_frames_cache.has(CACHE_KEY):
		return _sprite_frames_cache[CACHE_KEY] as SpriteFrames
	var metadata := _get_meta()
	var knight_meta: Dictionary = metadata.get("red_knight", {})
	var animations_value: Variant = knight_meta.get("animations", {})
	if not animations_value is Dictionary:
		return null
	var atlas := _get_texture()
	if not is_instance_valid(atlas):
		return null
	var atlas_region: Dictionary = metadata.get("atlas_regions", {}).get("red_knight", {})
	var offset_value: Array = atlas_region.get("offset", [0, 0])
	var base_x := int(offset_value[0])
	var base_y := int(offset_value[1])
	var cell_value: Array = knight_meta.get("cell", [71, 54])
	var cell_width := int(cell_value[0])
	var cell_height := int(cell_value[1])
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	for animation_id in ["idle", "run", "attack"]:
		var animation_data: Dictionary = animations_value.get(animation_id, {})
		var row := int(animation_data.get("row", -1))
		var count := int(animation_data.get("frames", 0))
		if row < 0 or count <= 0:
			continue
		frames.add_animation(animation_id)
		frames.set_animation_speed(animation_id, float(knight_meta.get("fps", 10)))
		frames.set_animation_loop(animation_id, animation_id != "attack")
		for frame_index in range(count):
			var frame := AtlasTexture.new()
			frame.atlas = atlas
			frame.region = Rect2(base_x + frame_index * cell_width, base_y + row * cell_height, cell_width, cell_height)
			frames.add_frame(animation_id, frame)
	_sprite_frames_cache[CACHE_KEY] = frames
	return frames
