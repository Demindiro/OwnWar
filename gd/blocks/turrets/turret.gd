extends "../weapons/weapon.gd"


var max_turn_speed := PI / 2
#var _desired_direction := Vector3(0, 0, 1)
var _body_a: OwnWar_VoxelBody
var _body_b: OwnWar_VoxelBody
var _coord_a: Vector3
var _coord_b: Vector3
var _aim_pos := Vector3()
var _body_b_mount := Spatial.new()
onready var _joint: Generic6DOFJoint = get_node("Joint")


func init(coordinate: Vector3, voxel_body: OwnWar_VoxelBody, vehicle: OwnWar_Vehicle) -> void:
	_joint = get_node("Joint")
	var connecting_coordinate := coordinate + transform.basis.y.round()
	for body in vehicle.voxel_bodies:
		if body != null and body != voxel_body:
			var other_id: int = body.get_block_id(connecting_coordinate)
			if other_id > 0:
				_create_joint(voxel_body, body, vehicle)
				_body_a.add_anchor(coordinate, _body_b)
				_body_b.add_anchor(connecting_coordinate, _body_a)
				var e := _body_a.connect("destroyed", self, "set", ["_body_a", null])
				assert(e == OK)
				e = _body_b.connect("destroyed", self, "set", ["_body_b", null])
				assert(e == OK)
				_coord_a = coordinate
				_coord_b = connecting_coordinate


func destroy() -> void:
	if _body_a != null and _body_b != null:
		_body_a.remove_anchor(_coord_a, _body_b)
	if _body_a != null and _body_b != null:
		_body_b.remove_anchor(_coord_b, _body_a)


func _ready() -> void:
	set_physics_process(_body_a != null)
	if _body_a != null:
		_body_b.add_child(_body_b_mount)
		_body_b_mount.global_transform = global_transform
		var e := _body_b_mount.connect("tree_exiting", self, "set", ["_body_b_mount", null])
		assert(e == OK)
		e = _body_b.connect("tree_exiting", self, "set_physics_process", [false])
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
	var i := -1
	for j in len(vehicle.voxel_bodies):
		if body_a == vehicle.voxel_bodies[j]:
			i = j
			break
	assert(i >= 0)
	_joint.set("solver/priority", 7 - i)
	process_priority = -i


func _remove_joint() -> void:
	if _joint != null:
		_joint.set("nodes/node_a", null)
		_joint.set("nodes/node_b", null)
		_joint.free()
		_joint = null
