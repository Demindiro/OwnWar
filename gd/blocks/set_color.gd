tool
extends Spatial
class_name OwnWar_SetColor


var color_node_paths := []
var transparency_node_paths := []
var team_glow_node_paths := []

const MESH_CACHE = {}

export var solid_material: Material = preload("res://effects/team_metal.tres")
export var solid_team_glow: Material = preload("res://effects/team_glow.tres")
export var transparent_material: Material = preload("res://effects/team_metal_transparent.tres")
export var transparent_team_glow: Material = preload("res://effects/team_glow_transparent.tres")

var transparent = false
var team_color: Color


func _get_property_list() -> Array:
	var props := []
	add_properties(props, "color_node", color_node_paths)
	add_properties(props, "transparency_node", transparency_node_paths)
	add_properties(props, "team_glow_node", team_glow_node_paths)
	return props


func add_properties(properties: Array, name: String, list: Array) -> void:
	for i in len(list):
		properties.push_back({
			"name": "%s_%d" % [name, i],
			"type": TYPE_NODE_PATH,
			"hint": PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_EDITOR,
		})
	properties.push_back({
		"name": "%s_%d" % [name, len(list)],
		"type": TYPE_NODE_PATH,
		"hint": PROPERTY_USAGE_EDITOR,
	})


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
	elif name.begins_with("team_glow_node_"):
		var index := int(name.substr(len("team_glow_node")))
		if index < 0 or index >= len(team_glow_node_paths):
			return
		return team_glow_node_paths[index]


func _set(name: String, value) -> bool:
	var b := false
	b = b or try_set_path(name, "color_node", color_node_paths, value)
	b = b or try_set_path(name, "transparency_node", transparency_node_paths, value)
	b = b or try_set_path(name, "team_glow_node", team_glow_node_paths, value)
	return b


func try_set_path(name: String, prefix: String, list: Array, value) -> bool:
	if name.begins_with("%s_" % prefix):
		var index := int(name.substr(len(prefix)))
		if index >= 0 and index <= len(list):
			if value is NodePath:
				if value == NodePath():
					if index < len(list):
						list.remove(index)
						property_list_changed_notify()
						return true
				elif true or get_node(value) is GeometryInstance:
					if len(list) == index:
						list.push_back(value)
					else:
						list[index] = value
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


func set_transparent(enable: bool) -> void:
	if transparent == enable:
		return
	transparent = enable

	for path in transparency_node_paths:
		var node: GeometryInstance = get_node(path)
		var mi := node as MeshInstance
		if mi != null:
			var mesh = MESH_CACHE.get(mi.mesh)
			if mesh == null:
				mesh = mi.mesh.duplicate()
				for i in mi.mesh.get_surface_count():
					mi.mesh.surface_set_material(i, transparent_material)
				MESH_CACHE[mi.mesh] = mesh
			mi.mesh = mesh
		else:
			var sprite := node as Sprite3D
			if sprite != null:
				sprite.transparent = true
				sprite.modulate.a = 0.25 if enable else 1.0
	for path in team_glow_node_paths:
		var mi = get_node(path)
		if mi != null:
			var mesh = MESH_CACHE.get(mi.mesh)
			if mesh == null:
				mesh = mi.mesh.duplicate()
				for i in mi.mesh.get_surface_count():
					mi.mesh.surface_set_material(i, transparent_material)
				MESH_CACHE[mi.mesh] = mesh
			mi.mesh = mesh


func _ready() -> void:
	for path in team_glow_node_paths:
		var node = get_node(path)
		node.mesh = node.mesh.duplicate()
		for i in node.mesh.get_surface_count():
			var mat = node.mesh.surface_get_material(i)
			mat = mat.duplicate()
			mat.emission = team_color * 5.0
			node.mesh.surface_set_material(i, mat)
