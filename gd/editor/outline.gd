extends Node

var map := {}
onready var outline = get_node("Outline")
var manager := OwnWar_BlockManager.new()


func add_mesh(mesh: Mesh) -> void:
	var node = outline.add_outline_direct(mesh)
	node.scale = Vector3(4, 4, 4)
	node.translation = Vector3.ONE / 2.0
	map[mesh] = node


func remove_mesh(mesh: Mesh) -> void:
	map[mesh].queue_free()
	map.erase(mesh)


func add_node(position: Vector3, rotation: int, node: Spatial) -> void:
	node = node.duplicate()
	var basis: Basis = manager.rotation_to_basis(rotation).scaled(Vector3(4, 4, 4))
	node.transform = Transform(basis, position + Vector3.ONE / 2.0)
	var outline_nodes = []
	for c in Util.get_children_recursive(node):
		var n
		if c is VisualInstance:
			c.layers = 0
			continue
		elif c is MeshInstance:
			n = outline.add_outline_direct(c)
		# "Right operand of 'is' is not a class (type: 'NativeScript')"
		# Thanks Godot
		elif c.get_script() == BatchedMeshInstance:
			n = outline.add_outline_direct(c)
		else:
			continue
		var trf = c.transform
		while c != node:
			c = c.get_parent()
			trf = c.transform * trf
		n.transform = trf
		outline_nodes.push_back(n)
			
	map[PoolIntArray([position.x, position.y, position.z])] = outline_nodes
	

func remove_node(position: Vector3) -> void:
	var key := PoolIntArray([position.x, position.y, position.z])
	for n in map[key]:
		n.queue_free()
	map.erase(key)
