class_name Block

extends Resource

export(String) var name
export(Mesh) var mesh
export(PackedScene) var scene

var id


func _init(p_mesh: Mesh = null):
	mesh = p_mesh


static func add_block(block: Block):
	if block.name in Global.blocks:
		push_error("Block name is already registered: '%s'" % block.name)
		return
	Global.blocks[block.name] = block
