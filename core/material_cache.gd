extends Object
class_name MaterialCache


const _CACHE := {}


static func get_material(color: Color) -> Material:
	var material := _CACHE.get(color) as Material
	if material == null:
		material = SpatialMaterial.new()
		material.albedo_color = color
		_CACHE[color] = material
	return material
