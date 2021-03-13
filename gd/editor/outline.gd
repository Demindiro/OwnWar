extends Node

var map := {}
onready var outline = get_node("Outline")
var manager := OwnWar_BlockManager.new()


func add_mesh(mesh: Mesh) -> void:
	var node := MeshInstance.new()
	node.mesh = mesh
	node.layers = 0
	node.scale = Vector3(4, 4, 4)
	add_child(node)
	outline.add_outline(node)
	map[mesh] = node


func remove_mesh(mesh: Mesh) -> void:
	map[mesh].queue_free()
	map.erase(mesh)


func add_node(position: Vector3, rotation: int, node: Spatial) -> void:
	node = node.duplicate()
	add_child(node)
	var basis: Basis = manager.rotation_to_basis(rotation).scaled(Vector3(4, 4, 4))
	node.transform = Transform(basis, position)
	for c in Util.get_children_recursive(node):
		if c is VisualInstance:
			c.layers = 0
		if c is MeshInstance:
			outline.add_outline(c)
	map[PoolIntArray([position.x, position.y, position.z])] = node
	

func remove_node(position: Vector3) -> void:
	var key := PoolIntArray([position.x, position.y, position.z])
	map[key].queue_free()
	map.erase(key)
