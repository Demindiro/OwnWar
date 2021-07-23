extends ViewportContainer
class_name OwnWar_Outline


export var outline_material: Material
export var main_camera_path := NodePath()

onready var root: Viewport = get_node("Viewport")
onready var main_camera: Camera = get_node(main_camera_path)
onready var camera: Camera = get_node("Viewport/Camera")

var outline_to_nodes := {}
var nodes_to_outline := {}

const MESH_CACHE := {}


# Add an outline node or mesh without tracking position & removals
#
# Returns the newly created node.
func add_outline_direct(node):
	var n

	if node is Mesh:
		n = MeshInstance.new()
		n.mesh = node
		n.material_override = outline_material
	elif node is MeshInstance:
		n = MeshInstance.new()
		n.mesh = node.mesh
		n.material_override = outline_material
	elif node.get_script() == BatchedMeshInstance:
		var mesh = MESH_CACHE.get(node.mesh)
		if mesh == null:
			mesh = node.mesh.duplicate()
			mesh.surface_set_material(0, outline_material)
			MESH_CACHE[node.mesh] = mesh
		n = BatchedMeshInstance.new()
		n.mesh = mesh
	else:
		assert(false, "Node is not a mesh instance")
		return

	root.add_child(n)

	return n


func add_outline(node):
	assert(not node in nodes_to_outline, "Node has already been added! %s & %s" % [
		node.get_path(),
		nodes_to_outline[node].get_path() if node in nodes_to_outline else "",
	])

	var n = add_outline_direct(node)

	var e = node.connect("tree_exited", self, "remove_node", [n])
	assert(e == OK)
	outline_to_nodes[n] = node
	nodes_to_outline[node] = n


func remove_outline(node) -> void:
	var n: MeshInstance = nodes_to_outline[node]
	nodes_to_outline.erase(node)
	outline_to_nodes.erase(n)
	node.disconnect("tree_exited", self, "remove_node")
	n.queue_free()


func clear_outlines() -> void:
	for n in outline_to_nodes:
		n.queue_free()
	for n in nodes_to_outline:
		n.disconnect("tree_exited", self, "remove_node")
	outline_to_nodes.clear()
	nodes_to_outline.clear()


func _process(_delta) -> void:
	call_deferred("post_process")


func post_process() -> void:
	camera.fov = main_camera.fov
	camera.near = main_camera.near
	camera.far = main_camera.far
	camera.transform = main_camera.global_transform
	for n in outline_to_nodes:
		n.transform = outline_to_nodes[n].global_transform


func remove_node(node) -> void:
	var n = outline_to_nodes[node]
	n.disconnect("tree_exited", self, "remove_node")
	nodes_to_outline.erase(n)
	outline_to_nodes.erase(node)
	node.queue_free()

