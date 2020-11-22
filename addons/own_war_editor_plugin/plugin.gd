tool
extends EditorPlugin


var _structures := []


func _enter_tree() -> void:
	get_tree().connect("node_added", self, "_node_added")
	get_tree().connect("node_removed", self, "_node_removed")
	var root := get_tree().get_edited_scene_root()
	for c in Util.get_children_recursive(root):
		if c is Structure:
			_structures.append(c)


func _process(_delta: float) -> void:
	var root := get_tree().get_edited_scene_root()
	if root is GameMaster:
		for c in _structures:
			assert(c is Structure)
			var transform: Transform = c.global_transform
			var org := transform.origin
			# Snap X and Z to 0.5 resolution
			org = (org * 2).round() / 2
			# Snap to floor
			var state = c.get_world().get_direct_space_state()
			var res = state.intersect_ray(
					org + Vector3.UP * 1_000.0,
					org + Vector3.DOWN * 1_000.0,
					[], Constants.COLLISION_MASK_TERRAIN)
			if len(res) > 0:
				org.y = res["position"].y + c.position_offset.y
			# Snap rotation
			var basis := transform.basis
			# Get the "aligned" basis, determine the angle and the direction
			# and determine current rotation from that
			var ta_basis := Util.get_aligned_basis(basis.y)
			var rot = ta_basis.x.angle_to(basis.x)
			rot *= sign(ta_basis.x.dot(basis.z))
			rot = Util.round_res(rot, 24 / (PI * 2))
			# Align with normal and apply rotation
			var up: Vector3 = res["normal"] if len(res) > 0 else Vector3.UP
			basis = Util.get_aligned_basis(up)
			basis = basis.rotated(up, rot)
			# Apply transform (unless it's pretty much equal)
			var n_transform := Transform(basis, org)
			if not Util.is_transform_approx_eq(n_transform, transform,
					1e-5, 1e-4):
				c.global_transform = n_transform


func _node_added(node: Node):
	if node is Structure:
		_structures.append(node)


func _node_removed(node: Node):
	if node is Structure:
		_structures.erase(node)
