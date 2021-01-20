extends Control


export(NodePath) var preview_mesh
export var block_item: PackedScene
export var _category_list := NodePath()
export var _block_list := NodePath()

var categories := {}

onready var category_list: Control = get_node(_category_list)
onready var block_list: Control = get_node(_block_list)

var _preview_mesh: MeshInstance
var _designer: Node
var _escape_pressed := false


func _ready():
	_resolve_node_paths()
	_get_categories()
	_category_container_init()
	for c in categories:
		show_category(c)
		break
	_preview_mesh.mesh = null


func _process(delta: float) -> void:
	_preview_mesh.rotate_y(delta * 0.3)


func show_category(var category):
	_block_container_init(category)


func show_block(var block_name):
	var block = OwnWar_Block.get_block(block_name)
	_preview_mesh.mesh = block.mesh
	_preview_mesh.transform = Transform.IDENTITY
	_preview_mesh.scale = \
		Vector3.ONE / max(block.aabb.size.x, max(block.aabb.size.y, block.aabb.size.z))
	for child in _preview_mesh.get_children():
		child.queue_free()
	if block.editor_node != null:
		_preview_mesh.add_child(block.editor_node.duplicate())


func _resolve_node_paths():
	_preview_mesh = get_node(preview_mesh)
	_designer = find_parent("Designer")


func _category_container_init():
	for category in categories:
		var node := Button.new()
		node.text = category
		node.connect("pressed", self, "show_category", [category])
		category_list.add_child(node)


func _block_container_init(var category):
	Util.free_children(block_list)
	for block_name in categories[category]:
		var node: Control = block_item.instance()
		OwnWar_Thumbnail.get_block_thumbnail_async(block_name,
			funcref(self, "_block_set_thumbnail"), [node])
		Util.assert_connect(node, "mouse_entered", self, "show_block", [block_name])
		Util.assert_connect(node, "pressed", _designer, "select_block", [block_name])
		Util.assert_connect(node, "pressed", _designer, "set_enabled", [true])
		block_list.add_child(node)


func _block_set_thumbnail(img: Image, button: Control) -> void:
	assert(img != null)
	assert(button != null)
	var tex := ImageTexture.new()
	tex.create_from_image(img)
	button.get_node("Icon").texture = tex


func _get_categories():
	for block in OwnWar_Block.get_all_blocks():
		if not block.category in categories:
			categories[block.category] = PoolIntArray([block.id])
		else:
			categories[block.category].push_back(block.id)
