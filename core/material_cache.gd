extends Node


var _cache := {}


func get_material(color: Color) -> Material:
	var material := _cache.get(color) as Material
	if material == null:
		material = SpatialMaterial.new()
		material.albedo_color = color
		_cache[color] = material
	return material
