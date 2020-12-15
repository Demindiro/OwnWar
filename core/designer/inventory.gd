extends Control


export(NodePath) var category_button_template
export(NodePath) var block_button_template
export(NodePath) var preview_mesh
export var _thumbnail_placeholder: Texture

var categories := {}

var _category_button_template: Button
var _category_container: Node
var _block_button_template: TextureButton
var _block_container: Node
var _preview_mesh: MeshInstance
var _designer: Node
var _escape_pressed := false
onready var _parent: Control = get_parent()


func _ready():
	_resolve_node_paths()
	_get_categories()
	_category_container_init()
	for c in categories:
		show_category(c)
		break
	_preview_mesh.mesh = null


func _unhandled_input(event):
	if not _parent.visible:
		return
	if event.is_action("ui_cancel") or event.is_action("designer_open_inventory"):
		if event.pressed:
			_escape_pressed = true
		elif _escape_pressed:
			_parent.visible = false
			_escape_pressed = false


func show_category(var category):
	_block_container_init(category)


func show_block(var block_name):
	var block = OwnWar.Block.get_block(block_name)
	_preview_mesh.mesh = block.mesh
	_preview_mesh.material_override = block.material
	_preview_mesh.scale = \
		Vector3.ONE / max(block.size.x, max(block.size.y, block.size.z))
	for child in _preview_mesh.get_children():
		child.queue_free()
	if block.scene != null:
		_preview_mesh.add_child(block.scene.instance())


func _resolve_node_paths():
	_category_button_template = get_node(category_button_template) as Button
	_category_container = _category_button_template.get_parent()
	_category_container.remove_child(_category_button_template)
	_block_button_template = get_node(block_button_template)
	_block_container = _block_button_template.get_parent()
	_block_container.remove_child(_block_button_template)
	_preview_mesh = get_node(preview_mesh)
	_designer = find_parent("Designer")


func _category_container_init():
	for category in categories:
		var node = _category_button_template.duplicate() as Button
		node.text = category
		node.connect("pressed", self, "show_category", [category])
		_category_container.add_child(node)


func _block_container_init(var category):
	for child in _block_container.get_children():
		_block_container.remove_child(child)
	for block_name in categories[category]:
		var node: TextureButton = _block_button_template.duplicate()
		#node.text = OwnWar.Block.get_block(block_name).human_name
		if not OwnWar_Thumbnail.get_thumbnail_async(block_name,
			funcref(self, "_block_set_thumbnail"), [node]):
			_block_set_thumbnail(_thumbnail_placeholder, node)
		node.connect("mouse_entered", self, "show_block", [block_name])
		node.connect("pressed", _designer, "select_block", [block_name])
		node.connect("pressed", _designer, "set_enabled", [true])
		_block_container.add_child(node)


func _block_set_thumbnail(img, button: TextureButton) -> void:
	if img is Image:
		var tex := ImageTexture.new()
		tex.create_from_image(img)
		img = tex
	button.texture_normal = img


func _get_categories():
	for block in OwnWar.Block.get_all_blocks():
		if not block.category in categories:
			categories[block.category] = []
		categories[block.category].append(block.name)
