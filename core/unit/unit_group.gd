tool
extends Node


func _process(_delta: float) -> void:
	if Engine.editor_hint:
		for c in Util.get_children_recursive(self):
			if c is OwnWar.Unit:
				c.team = name
		var node := get_node_or_null("_UnitGroup_AfterEnterBeforeReady")
		if node != null:
			print("[UnitGroup] Removing helper node")
			node.free()
	else:
		set_process(false)
