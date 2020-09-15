class_name Block

extends Resource

export(Mesh) var mesh


func _init(p_mesh: Mesh = null):
	mesh = p_mesh


static func add_block(name: String, block: Block):
	if name in Global.blocks:
		push_error("Block name is already registered: '%s'" % name)
		return
	Global.blocks[name] = block
