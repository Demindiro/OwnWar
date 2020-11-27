extends "../weapon_manager/weapon.gd"


signal destroyed()
var connected = false
var joint
var body_a
var body_b
var other_connector
var _desired_direction := Vector3(0, 0, 1)


func init(coordinate, _block_data, _rotation, voxel_body, vehicle, _meta):
	if connected:
		return
	var connecting_coordinate = get_connecting_coordinate(coordinate)
	var id = Block.get_block("turret_connector").id
	for body in vehicle.voxel_bodies:
		if body != voxel_body:
			var other_block: VoxelBody.BodyBlock = body.blocks.get(connecting_coordinate)
			if other_block != null and other_block.id == id:
				other_connector = other_block.node
				if other_connector.get_connecting_coordinate(connecting_coordinate) == coordinate:
					_create_joint(voxel_body, body)
					connected = true
					other_connector.connected = true
					var e := connect("destroyed", other_connector, "_other_connector_destroyed")
					assert(e == OK)
					other_connector.connect("destroyed", self, "_other_connector_destroyed")
					.init(coordinate, _block_data, _rotation, voxel_body, vehicle, _meta)
					return
				if other_connector != null:
					print(other_connector)
				other_connector = null


func _physics_process(_delta):
	if joint == null:
		return
	if other_connector == null:
		# Other connector got destroyed, remove the joint
		joint.queue_free()
		joint = null
		return
	var other_forward = other_connector.global_transform.basis.z
	var self_normal = global_transform.basis.y
	var t = -self_normal.dot(other_forward) / self_normal.length_squared()
	var projected_other_forward = (other_forward + t * self_normal).normalized()
	var abs_desired_direction = global_transform.basis * _desired_direction
	var error = 1.0 - projected_other_forward.dot(abs_desired_direction)
	var direction = -projected_other_forward \
			.cross(abs_desired_direction) \
			.dot(self_normal)
	if error > 1e-2 and abs(direction) < 1e-5:
		direction = 1.0
	var turn_rate = 0 if error < 1e-10 else direction * PI * 20
	turn_rate = clamp(turn_rate, -PI / 2, PI / 2)
	joint.set("angular_motor_x/target_velocity", turn_rate)


func _notification(what):
	match what:
		NOTIFICATION_PREDELETE:
			if joint != null:
				joint.queue_free()
			emit_signal("destroyed")


func debug_draw():
	if joint == null:
		return
	Debug.draw_line(global_transform.origin, \
			global_transform.origin + global_transform.basis.z * 10.0)
	Debug.draw_line(global_transform.origin, \
			global_transform.origin + global_transform.basis * _desired_direction * 20.0)
	Debug.draw_line(other_connector.global_transform.origin,
			other_connector.global_transform.origin + other_connector.global_transform.basis.z * 20.0)


func set_angle(angle):
	_desired_direction = Vector3.BACK.rotated(Vector3.UP, angle)


func aim_at(position: Vector3, _velocity := Vector3.ZERO):
	var rel_pos = to_local(position)
	var self_normal = Vector3.UP
	var t = -self_normal.dot(rel_pos) / self_normal.length_squared()
	_desired_direction = (rel_pos + t * self_normal).normalized()


func get_connecting_coordinate(coordinate):
	var up = transform.basis.y.round()
	var x = int(up.x)
	var y = int(up.y)
	var z = int(up.z)
	return [coordinate[0] + x, coordinate[1] + y, coordinate[2] + z]


func _create_joint(p_body_a, p_body_b):
	body_a = p_body_a
	body_b = p_body_b
	joint = Generic6DOFJoint.new()
	add_child(joint)
	joint.transform = Transform.IDENTITY
	joint.rotate_z(PI / 2)
	joint.set("nodes/node_a", joint.get_path_to(body_a))
	joint.set("nodes/node_b", joint.get_path_to(body_b))
	joint.set("angular_limit_x/enabled", false)
	joint.set("angular_motor_x/enabled", true)
	joint.set("angular_motor_x/force_limit", 1500.0)


func _other_connector_destroyed():
	if joint != null:
		joint.queue_free()
	other_connector = null
	joint = null
