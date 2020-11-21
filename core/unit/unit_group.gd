tool
extends Node


export var team := -1


func _process(_delta: float) -> void:
	if Engine.editor_hint:
		# Check if the node exists
		# If not, create one
		var node := get_node_or_null("_UnitGroup_AfterEnterBeforeReady")
		if node == null:
			print("[UnitGroup] Instancing helper node")
			node = Node.new()
			node.name = "_UnitGroup_AfterEnterBeforeReady"
			self.add_child(node)
			node.set_owner(get_tree().get_edited_scene_root())
			node.editor_description = "This node is needed so that add_units" + \
					" is called before the _ready of the child nodes but" + \
					" after _enter_tree so the children are already added to" + \
					" the tree."
		# Make sure the node is the last child in the tree
		move_child(node, get_child_count() - 1)
		# Check if the node is connected
		var connected := false
		for sig in node.get_signal_connection_list("tree_entered"):
			if sig["target"] == self:
				if not sig["flags"] & CONNECT_PERSIST:
					node.disconnect("tree_entered", self, "add_units")
				else:
					connected = true
				break
		if not connected:
			print("[UnitGroup] Connecting helper node")
			node.connect("tree_entered", self, "add_units", [], CONNECT_PERSIST)
			#NodeDock.update_lists()
	else:
		set_process(false)


func add_units() -> void:
	assert(not Engine.editor_hint)
	assert(team >= 0)
	var gm: GameMaster = GameMaster.get_game_master(self)
	assert(gm != null)
	for c in Util.get_children_recursive(self):
		if c is Unit:
			c.team = team
			gm.units[team].append(c)
