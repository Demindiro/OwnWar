extends Camera
class_name FollowCamera


export(NodePath) var node_path
export(float) var max_distance = 50
export(float) var height = 10


func _process(delta: float) -> void:
	var node = get_node_or_null(node_path)
	if node != null:
		var move_position = node.translation + Vector3.UP * height
		var basis_look = get_basis(node.translation)
		var basis_move = get_basis(move_position)
		var move_distance = (move_position - translation).length() - max_distance
		var move = basis_move * Vector3.FORWARD * move_distance
		transform = Transform(
			transform.basis.slerp(basis_look, delta * 3.0),
			translation.linear_interpolate(translation + move, delta * 2.0)
		)


func get_basis(position):
	var rel_pos = position - translation
	var rel_pos_xz = Vector3(rel_pos.x, 0, rel_pos.z)
	var basis_azi = Basis.IDENTITY
	var basis_elev = Basis.IDENTITY
	if rel_pos_xz.length() > 1e-4:
		var cos_azi = Vector3.FORWARD.dot(rel_pos_xz.normalized())
		var sin_azi = sqrt(1 - cos_azi * cos_azi) * sign(-rel_pos.x)
		basis_azi = Basis(
				Vector3(cos_azi, 0, -sin_azi),
				Vector3.UP,
				Vector3(sin_azi, 0, cos_azi))
	if rel_pos.length() > 1e-4:
		var cos_elev = Vector3.UP.dot(rel_pos.normalized())
		var sin_elev = sqrt(1 - cos_elev * cos_elev)
		basis_elev = Basis(
				Vector3.RIGHT,
				Vector3(0, sin_elev, cos_elev),
				Vector3(0, -cos_elev, sin_elev))
	return basis_azi * basis_elev
