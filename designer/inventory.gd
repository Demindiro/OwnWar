extends Control


export(NodePath) var category_button_template
export(NodePath) var block_button_template
export(NodePath) var preview_mesh

var categories := {}

var _category_button_template: Button
var _category_container: Node
var _block_button_template: Button
var _block_container: Node
var _preview_mesh: MeshInstance
var _designer: Node


func _ready():
	_resolve_node_paths()
	_get_categories()
	_category_container_init()
	for c in categories:
		show_category(c)
		break
	
	
func show_category(var category):
	_block_container_init(category)
	
	
func show_block(var block_name):
	var block = Global.blocks[block_name]
	_preview_mesh.mesh = block.mesh
	_preview_mesh.material_override = block.material
	
	
func _resolve_node_paths():
	_category_button_template = get_node(category_button_template) as Button
	_category_container = _category_button_template.get_parent()
	_category_container.remove_child(_category_button_template)
	_block_button_template = get_node(block_button_template) as Button
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
		var node = _block_button_template.duplicate() as Button
		node.text = block_name
		node.connect("mouse_entered", self, "show_block", [block_name])
		node.connect("pressed", _designer, "select_block", [block_name])
		node.connect("pressed", _designer, "set_enabled", [true])
		_block_container.add_child(node)

	
func _get_categories():
	for block_name in Global.blocks:
		var block = Global.blocks[block_name] as Block
		if not block.category in categories:
			categories[block.category] = []
		categories[block.category].append(block.name)
