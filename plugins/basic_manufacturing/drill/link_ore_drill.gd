tool
extends Node


func _ready() -> void:
	if not Engine.editor_hint:
		var drill: Spatial = null
		var ore: Spatial = null
		var children = get_children()
		assert(len(children) == 2)

		if children[0] is preload("drill.gd"):
			drill = children[0]
			ore = children[1]
		else:
			drill = children[1]
			ore = children[0]
		assert(drill is preload("drill.gd"))
		assert(ore is preload("ore.gd"))

		drill.init(ore)


func _get_configuration_warning() -> String:
	var root := get_tree().get_edited_scene_root()
	if root == self:
		return ""
	var has_drill := false
	var has_ore := false
	for child in get_children():
		if child is preload("drill.gd"):
			if has_drill:
				return "Two ore more drills attached! Remove all but one please"
			has_drill = true
		elif child is preload("ore.gd"):
			if has_ore:
				return "Two or more ores attached! Remove all but one please"
			has_ore = true
		else:
			return "Non-drill or ore attached! Remove it please"
	if not has_drill:
		print("Adding drill scene")
		var node: Node = preload("drill.tscn").instance()
		add_child(node)
		node.set_owner(root)
	if not has_ore:
		print("Adding ore scene")
		var node: Node = preload("ore.tscn").instance()
		add_child(node)
		node.set_owner(root)
	return ""
