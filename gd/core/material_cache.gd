extends Object
class_name MaterialCache


const _CACHE := {}


static func get_material(color: Color, base_material: Material = null) -> Material:
	var dict: Dictionary = _CACHE.get(base_material, {})
	if len(dict) == 0:
		_CACHE[base_material] = dict
	var material: Material = dict.get(color)
	if material == null:
		material = base_material.duplicate() if base_material != null else SpatialMaterial.new()
		var sm := material as SpatialMaterial
		if sm != null:
			sm.roughness = 0.4
			sm.albedo_color = color
			sm.flags_transparent = color.a < 0.999
			sm.params_blend_mode = SpatialMaterial.BLEND_MODE_MIX if color.a >= 0.999 else SpatialMaterial.BLEND_MODE_ADD
		else:
			assert(false, "TODO handle other material types somehow")
		dict[color] = material
	assert(material != null)
	return material


const _MESH_CACHE := {}

static func get_mesh(tag, create_func: FuncRef) -> Mesh:
	var m: Mesh = _MESH_CACHE.get(tag)
	if m == null:
		m = create_func.call_func(tag)
		_MESH_CACHE[tag] = m
	return m
