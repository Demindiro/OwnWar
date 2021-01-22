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
			sm.albedo_color = color
			if color.a < 0.999:
				sm.flags_transparent = true
		else:
			assert(false, "TODO handle other material types somehow")
		dict[color] = material
	assert(material != null)
	return material
