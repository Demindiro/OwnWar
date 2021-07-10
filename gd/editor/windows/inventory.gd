extends "window.gd"


# TODO
const BLOCK_SCALE := 0.25

# TODO
var BlockManager := OwnWar_BlockManager.new()

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
	_preview_mesh.get_parent().rotate_y(delta * 0.3)


func show_category(var category):
	_block_container_init(category)


func show_block(id: int):
	var block = BlockManager.get_block(id)
	_preview_mesh.mesh = block.mesh
	var scl = Vector3.ONE / max(block.aabb.size.x, max(block.aabb.size.y, block.aabb.size.z))
	_preview_mesh.scale = scl
	_preview_mesh.translation = (-block.aabb.position - block.aabb.size / 2 + Vector3(0.5, 0.5, 0.5)) * scl * BLOCK_SCALE
	for child in _preview_mesh.get_children():
		child.queue_free()
	if block.editor_node != null:
		var node = block.editor_node.duplicate()
		node.set_color(Color.white)
		node.set("team_color", OwnWar.ALLY_COLOR)
		if node.has_method("set_preview_mode"):
			node.set_preview_mode(true)
		_preview_mesh.add_child(node)


func _resolve_node_paths():
	_preview_mesh = get_node(preview_mesh)
	_designer = find_parent("Designer")


func _category_container_init():
	for category in categories:
		var node := Button.new()
		node.text = category
		var e := node.connect("pressed", self, "show_category", [category])
		assert(e == OK)
		category_list.add_child(node)


func _block_container_init(var category):
	Util.free_children(block_list)
	for id in categories[category]:
		var node: Control = block_item.instance()
		var _created := OwnWar_Thumbnail.get_block_thumbnail_async(id, funcref(self, "_block_set_thumbnail"), [node])
		Util.assert_connect(node, "mouse_entered", self, "show_block", [id])
		Util.assert_connect(node, "pressed", _designer, "select_block", [id])
		Util.assert_connect(node, "pressed", _designer, "hide_windows")
		block_list.add_child(node)


func _block_set_thumbnail(img: Image, button: Control) -> void:
	assert(img != null)
	assert(button != null)
	var tex := ImageTexture.new()
	tex.create_from_image(img)
	button.get_node("Icon").texture = tex


func _get_categories():
	for block in OwnWar_BlockManager.new().get_all_blocks():
		var arr: PoolIntArray = categories.get(block.human_category, PoolIntArray())
		arr.push_back(block.id)
		categories[block.human_category] = arr
