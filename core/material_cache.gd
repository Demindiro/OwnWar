extends Object
class_name MaterialCache


const _CACHE := {}


static func get_material(color: Color) -> Material:
	var material: SpatialMaterial = _CACHE.get(color)
	if material == null:
		material = SpatialMaterial.new()
		material.albedo_color = color
		if color.a < 0.99999:
			material.flags_transparent = true
		_CACHE[color] = material
	return material
