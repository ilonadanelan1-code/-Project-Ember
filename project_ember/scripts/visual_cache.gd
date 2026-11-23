extends RefCounted
class_name VisualCache
## Shared runtime resources. Builders are called once per key for the lifetime of the app.
static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}
static var _textures: Dictionary = {}
static func get_material(key: String, builder: Callable) -> Material:
	if _materials.has(key):
		return _materials[key] as Material
	if not builder.is_valid():
		push_error("VisualCache: invalid material builder for key '%s'." % key)
		return null
	var resource: Variant = builder.call()
	if not resource is Material:
		push_error("VisualCache: builder for '%s' did not return a Material." % key)
		return null
	_materials[key] = resource
	return resource as Material
static func get_mesh(key: String, builder: Callable) -> Mesh:
	if _meshes.has(key):
		return _meshes[key] as Mesh
	if not builder.is_valid():
		push_error("VisualCache: invalid mesh builder for key '%s'." % key)
		return null
	var resource: Variant = builder.call()
	if not resource is Mesh:
		push_error("VisualCache: builder for '%s' did not return a Mesh." % key)
		return null
	_meshes[key] = resource
	return resource as Mesh
static func get_texture(key: String, builder: Callable) -> Texture2D:
	if _textures.has(key):
		return _textures[key] as Texture2D
	if not builder.is_valid():
		push_error("VisualCache: invalid texture builder for key '%s'." % key)
		return null
	var resource: Variant = builder.call()
	if not resource is Texture2D:
		push_error("VisualCache: builder for '%s' did not return a Texture2D." % key)
		return null
	_textures[key] = resource
	return resource as Texture2D
static func cache_mesh_resource(mesh: Mesh) -> Mesh:
	if not is_instance_valid(mesh):
		return null
	var properties: PackedStringArray = []
	for property_info in mesh.get_property_list():
		var usage := int(property_info.get("usage", 0))
		if (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var property_name := str(property_info.get("name", ""))
		if property_name.begins_with("resource_") or property_name == "script":
			continue
		var value: Variant = mesh.get(property_name)
		if value is Resource or typeof(value) == TYPE_RID:
			continue
		properties.append(property_name + "=" + str(value))
	properties.sort()
	var key := "mesh:%s:%s" % [mesh.get_class(), ";".join(properties)]
	return get_mesh(key, func() -> Mesh:
		return mesh
	)
static func get_material_count() -> int:
	return _materials.size()
static func get_mesh_count() -> int:
	return _meshes.size()
static func get_texture_count() -> int:
	return _textures.size()
static func clear() -> void:
	_materials.clear()
	_meshes.clear()
	_textures.clear()
