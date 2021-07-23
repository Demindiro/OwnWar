extends "../weapons/weapon.gd"

export var max_impulse := 300
export var offset := Vector3()

var max_turn_speed := PI / 2
var _aim_pos := Vector3()
var _body_b_mount: Spatial

var _joint_rid := RID()

var base_position
var body_offset
var steppable_index = 0
var turret_index = 0
var anchor_index = 0
var anchor_mounts = PoolVector3Array([Vector3(0, 1, 0)])
var anchor_mount_body


func _ready() -> void:
	call_deferred("_ready_deferred")


func _ready_deferred():
	var mount_b
	if anchor_mount_body != null:
		mount_b = _create_joint()

		_body_b_mount = Spatial.new()
		anchor_mount_body.add_child(_body_b_mount)
		_body_b_mount.transform = Transform(transform.basis, mount_b.origin)
		var e := _body_b_mount.connect("tree_exiting", self, "set", ["_body_b_mount", null])
		assert(e == OK)


func step(delta) -> void:
	if _body_b_mount != null && _joint_rid != RID():
		delta = delta / 256.0
		var g_trf := _body_b_mount.global_transform
		var plane := Plane(g_trf.basis.y, 0)
		var proj_pos := plane.project(_aim_pos - g_trf.origin)
		var angle_diff := abs(g_trf.basis.z.angle_to(proj_pos.normalized()))
		var side := -sign(g_trf.basis.x.dot(proj_pos))
		var max_turn: float = max_turn_speed * delta
		var turn_rate := max_turn_speed * min(1.0, angle_diff / max_turn * 0.5)
		PhysicsServer.hinge_joint_set_param(
			_joint_rid,
			PhysicsServer.HINGE_JOINT_MOTOR_TARGET_VELOCITY,
			turn_rate * side
		)


func aim_at(position: Vector3):
	_aim_pos = position


func _create_joint():
	var body_a = get_parent()
	var body_b = anchor_mount_body
	var vh = body_a.get_meta("ownwar_vehicle_list")[body_a.get_meta("ownwar_vehicle_index")]
	var bd_a = body_a.get_meta("ownwar_body_index")
	var bd_b = body_b.get_meta("ownwar_body_index")
	var z_up = transform.basis * Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
	var mount_a = Transform(z_up, vh.voxel_to_translation(bd_a, base_position + body_offset) + offset)
	var mount_b = Transform(z_up, vh.voxel_to_translation(bd_b, base_position + body_offset) + offset)
	_joint_rid = PhysicsServer.joint_create_hinge(
		body_a.get_rid(),
		mount_a,
		body_b.get_rid(),
		mount_b
	)
	PhysicsServer.hinge_joint_set_param(
		_joint_rid,
		PhysicsServer.HINGE_JOINT_MOTOR_MAX_IMPULSE,
		max_impulse * 0.01
	)
	return mount_b


func _remove_joint() -> void:
	if _joint_rid != RID():
		PhysicsServer.free_rid(_joint_rid)
