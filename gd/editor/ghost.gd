extends MeshInstance


var manager := OwnWar_BlockManager.new()

onready var orig_translation = translation


func ghost_block(id: int) -> void:
	var block = manager.get_block(id)
	mesh = block.mesh
	for c in get_children():
		c.queue_free()
	if block.editor_node != null:
		var n = block.editor_node.duplicate()
		add_child(n)
		for c in Util.get_children_recursive(n):
			if c is VisualInstance:
				c.layers = layers
		n.transform = Transform()
		if n.has_method("set_color"):
			n.set_color(material_override.albedo_color)
		n.set("team_color", OwnWar.ALLY_COLOR)
		if n.has_method("set_transparency"):
			n.set_transparency(material_override.albedo_color.a)
		if n.has_method("set_preview_mode"):
			n.set_preview_mode(true)

	# FIXME ugly, ugly hack
	if name == "Mesh":
		var BLOCK_SCALE := 0.25
		scale = Vector3.ONE / max(block.aabb.size.x, max(block.aabb.size.y, block.aabb.size.z))
		translation = orig_translation - (-block.aabb.position - block.aabb.size / 2 + Vector3(0.5, 0.5, 0.5)) * scale * BLOCK_SCALE


func ghost_color(color: Color) -> void:
	color.a = material_override.albedo_color.a
	material_override.albedo_color = color


func ghost_rotation(rotation: int) -> void:
	transform.basis = manager.rotation_to_basis(rotation).scaled(Vector3(4, 4, 4))
