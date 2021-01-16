tool
extends Node
class_name OwnWar_Settings_Applier


var paths := []


func _get_property_list() -> Array:
	var props := []
	for i in len(paths):
		props.push_back({
			"name": "lights/%d" % i,
			"type": TYPE_NODE_PATH,
		})
	props.push_back({
		"name": "lights/%d" % len(paths),
		"type": TYPE_NODE_PATH,
		"usage": PROPERTY_USAGE_EDITOR,
	})
	return props


func _get(property: String):
	if property.begins_with("lights/"):
		var index_str := property.substr(len("lights/"))
		if not index_str.is_valid_integer():
			return
		var index := int(index_str)
		if index < 0:
			return
		if index > len(paths):
			return
		if index == len(paths):
			return NodePath()
		return paths[index]


func _set(property: String, value) -> bool:
	if property.begins_with("lights/"):
		if not value is NodePath and value != null:
			return false
		var index_str := property.substr(len("lights/"))
		if not index_str.is_valid_integer():
			return false
		var index := int(index_str)
		if index < 0:
			return false
		if index > len(paths):
			return false
		if index == len(paths):
			if value != null and value != NodePath():
				paths.push_back(value)
				property_list_changed_notify()
		else:
			if value != null and value != NodePath():
				paths[index] = value
			else:
				paths.remove(index)
			property_list_changed_notify()
		return true
	return false


func _ready() -> void:
	var e := OwnWar_Settings.connect("shadows_toggled", self, "enable_shadows")
	assert(e == OK)
	enable_shadows(OwnWar_Settings.enable_shadows)


func enable_shadows(enable: bool) -> void:
	for path in paths:
		var node: Light = get_node(path)
		node.shadow_enabled = enable


func _exit_tree() -> void:
	OwnWar_Settings.disconnect("shadows_toggled", self, "enable_shadows")
