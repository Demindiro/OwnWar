tool
extends Spatial
class_name OwnWar_SetColor


var color_node_paths := []
var transparency_node_paths := []


func _get_property_list() -> Array:
	var props := []
	for i in len(color_node_paths):
		props.push_back({
			"name": "color_node_%d" % i,
			"type": TYPE_NODE_PATH,
			"hint": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		})
	props.push_back({
		"name": "color_node_%d" % len(color_node_paths),
		"type": TYPE_NODE_PATH,
		"hint": PROPERTY_USAGE_EDITOR,
	})
	for i in len(transparency_node_paths):
		props.push_back({
			"name": "transparency_node_%d" % i,
			"type": TYPE_NODE_PATH,
			"hint": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		})
	props.push_back({
		"name": "transparency_node_%d" % len(transparency_node_paths),
		"type": TYPE_NODE_PATH,
		"hint": PROPERTY_USAGE_EDITOR,
	})
	return props


func _get(name: String):
	if name.begins_with("color_node_"):
		var index := int(name.substr(len("color_node")))
		if index < 0 or index >= len(color_node_paths):
			return
		return color_node_paths[index]
	elif name.begins_with("transparency_node_"):
		var index := int(name.substr(len("transparency_node")))
		if index < 0 or index >= len(transparency_node_paths):
			return
		return transparency_node_paths[index]


func _set(name: String, value) -> bool:
	if name.begins_with("color_node_"):
		var index := int(name.substr(len("color_node")))
		if index >= 0 and index <= len(color_node_paths):
			if value is NodePath:
				if value == NodePath():
					if index < len(color_node_paths):
						color_node_paths.remove(index)
						property_list_changed_notify()
						return true
				elif true or get_node(value) is GeometryInstance:
					if len(color_node_paths) == index:
						color_node_paths.push_back(value)
					else:
						color_node_paths[index] = value
					property_list_changed_notify()
					return true
	elif name.begins_with("transparency_node_"):
		var index := int(name.substr(len("transparency_node")))
		if index >= 0 and index <= len(transparency_node_paths):
			if value is NodePath:
				if value == NodePath():
					if index < len(transparency_node_paths):
						transparency_node_paths.remove(index)
						property_list_changed_notify()
						return true
				elif true or get_node(value) is GeometryInstance:
					if len(transparency_node_paths) == index:
						transparency_node_paths.push_back(value)
					else:
						transparency_node_paths[index] = value
					property_list_changed_notify()
					return true
	return false


func set_color(color: Color) -> void:
	for path in color_node_paths:
		var node: GeometryInstance = get_node(path)
		var mi := node as MeshInstance
		if mi != null:
			mi.mesh = mi.mesh.duplicate()
			for i in mi.mesh.get_surface_count():
				var base_mat := mi.mesh.surface_get_material(i)
				var mat := MaterialCache.get_material(color, base_mat)
				mi.mesh.surface_set_material(i, mat)
		else:
			var sprite := node as Sprite3D
			if sprite != null:
				sprite.modulate = color


func set_transparency(alpha: float) -> void:
	for path in transparency_node_paths:
		var node: GeometryInstance = get_node(path)
		var mi := node as MeshInstance
		if mi != null:
			mi.mesh = mi.mesh.duplicate()
			for i in mi.mesh.get_surface_count():
				var base_mat := mi.mesh.surface_get_material(i)
				assert(base_mat != null, "base_mat is null. Check if the node has already been added")
				assert(base_mat is SpatialMaterial, "TODO: handle other material types")
				var color := (base_mat as SpatialMaterial).albedo_color
				color.a *= alpha
				var mat := MaterialCache.get_material(color, base_mat)
		else:
			var sprite := node as Sprite3D
			if sprite != null:
				sprite.transparent = true
				sprite.modulate.a *= alpha
