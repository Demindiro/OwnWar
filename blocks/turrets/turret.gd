extends "../weapons/weapon.gd"


var max_turn_speed := PI
#var _desired_direction := Vector3(0, 0, 1)
var _body_a: OwnWar.VoxelBody
var _body_b: OwnWar.VoxelBody
var _aim_pos := Vector3()
var _body_b_mount := Spatial.new()
onready var _joint: Generic6DOFJoint = get_node("Joint")
onready var _compensation: PhysicsJointCompensationNode = get_node("Compensation")


func init(coordinate, _block_data, _rotation, voxel_body, vehicle, _meta):
	_joint = get_node("Joint")
	_compensation = get_node("Compensation")
	var connecting_coordinate = get_connecting_coordinate(coordinate)
	for body in vehicle.voxel_bodies:
		if body != voxel_body:
			var other_block: OwnWar.VoxelBody.BodyBlock = \
				body.blocks.get(connecting_coordinate)
			if other_block != null:
				_create_joint(voxel_body, body, vehicle)


func _ready() -> void:
	set_physics_process(_body_a != null)
	#set_physics_process_internal(_body_a != null)
	if _body_a != null:
		_body_b.add_child(_body_b_mount)
		_body_b_mount.global_transform = global_transform


func _physics_process(delta: float) -> void:
	var g_trf := _body_b_mount.global_transform
	var plane := Plane(g_trf.basis.y, 0)
	var proj_pos := plane.project(_aim_pos) - g_trf.origin
	var curr_dir := g_trf.basis.z
	var angle_diff := curr_dir.angle_to(proj_pos.normalized())
	var side := sign(g_trf.basis.x.dot(proj_pos))
	var max_turn := max_turn_speed * delta
	var turn_rate := max_turn_speed * min(1.0, angle_diff / max_turn * 0.5)
	_joint.set("angular_motor_z/target_velocity", turn_rate * side)


# Taken from https://github.com/godotengine/godot/blob/d4360b64994fa22836b8a6f6fcb057e75feb7008/scene/3d/physics_bone_3d.cpp
func _notification(what: int) -> void:
	if what != NOTIFICATION_INTERNAL_PHYSICS_PROCESS:
		return
	var state := PhysicsServer.body_get_direct_state(_body_b.get_rid())
	var comp_origin := _compensation.last_transform.origin
	var comp_rotation := Transform(_compensation.transform_delta.basis, Vector3())
	# Compensate for rotation
	if false:
		var rotated_gt := state.transform
		rotated_gt.origin -= comp_origin
		rotated_gt = comp_rotation * rotated_gt
		rotated_gt.origin += comp_origin
		state.transform = rotated_gt
		_body_b.global_transform = rotated_gt
	# Compensate for velocity
	state.linear_velocity += _compensation.linear_velocity_delta
	state.angular_velocity += _compensation.angular_velocity_delta


func debug_draw():
	Debug.draw_line(global_transform.origin, \
			global_transform.origin + global_transform.basis.z * 10.0)
	Debug.draw_line(global_transform.origin, _aim_pos, Color.red)
	#Debug.draw_line(global_transform.origin, \
	#		global_transform.origin + global_transform.basis * _desired_direction * 20.0,
	#		Color.red)
	Debug.draw_line(global_transform.origin,
			global_transform.origin + global_transform.basis.z * 20.0)
	var bbmt := _body_b_mount.global_transform
	Debug.draw_line(bbmt.origin,
			bbmt.origin + bbmt.basis.x * 5.0,
			Color.red)
	Debug.draw_line(bbmt.origin,
			bbmt.origin + bbmt.basis.y * 5.0,
			Color.green)
	Debug.draw_line(bbmt.origin,
			bbmt.origin + bbmt.basis.z * 5.0,
			Color.blue)


func aim_at(position: Vector3):
	_aim_pos = position
#	var rel_pos = to_local(position)
#	var self_normal = Vector3.UP
#	var t = -self_normal.dot(rel_pos) / self_normal.length_squared()
#	_desired_direction = (rel_pos + t * self_normal).normalized()


func get_connecting_coordinate(coordinate):
	var up = transform.basis.y.round()
	var x = int(up.x)
	var y = int(up.y)
	var z = int(up.z)
	return [coordinate[0] + x, coordinate[1] + y, coordinate[2] + z]


func _create_joint(body_a: PhysicsBody, body_b: PhysicsBody, vehicle: OwnWar_Vehicle) -> void:
	_body_a = body_a
	_body_b = body_b
	_joint.set("nodes/node_a", _joint.get_path_to(body_a))
	_joint.set("nodes/node_b", _joint.get_path_to(body_b))
	# Needed to prevent bullet from complaining ("assert_no_constraints")
	Util.assert_connect(body_a, "tree_exiting", self, "_remove_joint")
	Util.assert_connect(body_b, "tree_exiting", self, "_remove_joint")
	_compensation.tracking_node_path = _compensation.get_path_to(body_a)
	var i := -1
	for j in len(vehicle.voxel_bodies):
		if body_a == vehicle.voxel_bodies[j]:
			i = j
			break
	assert(i >= 0)
	#_joint.set("solver/priority", 7 - i)
	#process_priority = -i


func _remove_joint() -> void:
	if _joint != null:
		_joint.set("nodes/node_a", null)
		_joint.set("nodes/node_b", null)
		_joint.free()
		_joint = null
