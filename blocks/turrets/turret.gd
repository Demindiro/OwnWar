extends "../weapons/weapon.gd"


var max_turn_speed := PI / 2
#var _desired_direction := Vector3(0, 0, 1)
var _body_a: OwnWar.VoxelBody
var _body_b: OwnWar.VoxelBody
var _aim_pos := Vector3()
var _body_b_mount := Spatial.new()
onready var _joint: Generic6DOFJoint = get_node("Joint")
onready var _compensation: PhysicsJointCompensationNode = get_node("Compensation")


func init(coordinate: Vector3, voxel_body: OwnWar.VoxelBody, vehicle: OwnWar_Vehicle) -> void:
	_joint = get_node("Joint")
	_compensation = get_node("Compensation")
	var connecting_coordinate := coordinate + transform.basis.y.round()
	for body in vehicle.voxel_bodies:
		if body != voxel_body:
			var other_id: int = body.get_block_id(connecting_coordinate)
			if other_id > 0:
				_create_joint(voxel_body, body, vehicle)
				_anchor_bodies(coordinate, connecting_coordinate)


func _ready() -> void:
	set_physics_process(_body_a != null)
	set_physics_process_internal(_body_a != null)
	if _body_a != null:
		_body_b.add_child(_body_b_mount)
		_body_b_mount.global_transform = global_transform
		var e := _body_b_mount.connect("tree_exiting", self, "set", ["_body_b_mount", null])
		assert(e == OK)
		e = _body_b.connect("tree_exiting", self, "set_physics_process", [false])
		assert(e == OK)
		e = _body_b.connect("tree_exiting", self, "set_physics_process_internal", [false])
		assert(e == OK)


func _physics_process(delta: float) -> void:
	var g_trf := _body_b_mount.global_transform
	var plane := Plane(g_trf.basis.y, 0)
	var proj_pos := plane.project(_aim_pos - g_trf.origin)
	var angle_diff := abs(g_trf.basis.z.angle_to(proj_pos.normalized()))
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
	if not is_inside_tree() or _body_b_mount == null or not _body_b_mount.is_inside_tree():
		return
	Debug.draw_line(global_transform.origin, \
			global_transform.origin + global_transform.basis.z * 10.0)
	Debug.draw_line(global_transform.origin, _aim_pos, Color.red)
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
	var g_trf := _body_b_mount.global_transform
	var plane := Plane(g_trf.basis.y, 0)
	var proj_pos := plane.project(_aim_pos - g_trf.origin).normalized()
	Debug.draw_point(proj_pos * 5.0 + g_trf.origin, Color.cyan, 0.1)


func aim_at(position: Vector3):
	_aim_pos = position


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
	_joint.set("solver/priority", 7 - i)
	process_priority = -i
	_compensation.process_priority = -i - 1


func _anchor_bodies(coordinate: Vector3, connecting_coordinate: Vector3) -> void:
	var e := connect("tree_exiting", _body_a, "remove_anchor", [coordinate, _body_b])
	assert(e == OK)
	e = connect("tree_exiting", _body_b, "remove_anchor", [connecting_coordinate, _body_a])
	assert(e == OK)
	# Make sure we don't pass a freed object to remove_anchor by disconnecting the signal
	# It looks a bit confusing but it should also be the fastest method of doing it
	e = _body_a.connect("tree_exiting", self, "disconnect", ["tree_exiting", _body_b, "remove_anchor"])
	assert(e == OK)
	e = _body_b.connect("tree_exiting", self, "disconnect", ["tree_exiting", _body_a, "remove_anchor"])
	assert(e == OK)
	_body_a.add_anchor(coordinate, _body_b)
	_body_b.add_anchor(connecting_coordinate, _body_a)



func _remove_joint() -> void:
	if _joint != null:
		_joint.set("nodes/node_a", null)
		_joint.set("nodes/node_b", null)
		_joint.free()
		_joint = null
