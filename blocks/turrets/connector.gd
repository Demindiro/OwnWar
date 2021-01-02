extends "../weapons/weapon.gd"


signal destroyed()
var connected := false
var joint: HingeJoint
var body_a: PhysicsBody
var body_b: PhysicsBody
var other_connector
var max_turn_speed := PI
var _desired_direction := Vector3(0, 0, 1)
var _voxel_body: OwnWar.VoxelBody


func init(coordinate, _block_data, _rotation, voxel_body, vehicle, _meta):
	if connected:
		return
	var connecting_coordinate = get_connecting_coordinate(coordinate)
	var id = OwnWar.Block.get_block("turret_connector").id
	for body in vehicle.voxel_bodies:
		if body != voxel_body:
			var other_block: OwnWar.VoxelBody.BodyBlock = \
				body.blocks.get(connecting_coordinate)
			if other_block != null and other_block.id == id:
				other_connector = other_block.node
				if other_connector.get_connecting_coordinate(connecting_coordinate) == coordinate:
					_create_joint(voxel_body, body)
					connected = true
					other_connector.connected = true
					var e := connect("destroyed", other_connector, "_other_connector_destroyed")
					assert(e == OK)
					other_connector.connect("destroyed", self, "_other_connector_destroyed")
					#init(coordinate, _block_data, _rotation, voxel_body, vehicle, _meta)
					return
				if other_connector != null:
					print(other_connector)
				other_connector = null
				_voxel_body = voxel_body


func _physics_process(delta: float) -> void:
	if joint == null:
		return
	if other_connector == null:
		# Other connector got destroyed, remove the joint
		joint.queue_free()
		joint = null
		return
	var other_transform: Transform = other_connector.global_transform
	var other_forward := other_transform.basis.z
	var other_right := other_transform.basis.x
	var plane := Plane(other_transform.basis.y, 0)
	var projected_other_forward := plane.project(other_forward).normalized()
	var abs_desired_direction := global_transform.basis * _desired_direction
	var error := projected_other_forward.dot(abs_desired_direction)
	var side = sign(other_right.dot(abs_desired_direction))
	var angle_diff := acos(clamp(error, -1.0, 1.0))
	var max_turn := max_turn_speed * delta
	# Multiply by 0.5 because I'm doing something wrong (idk what tho :/)
	var turn_rate := max_turn_speed * min(1.0, angle_diff / max_turn * 0.5)
	joint.set("motor/target_velocity", turn_rate * side)



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


func aim_at(position: Vector3):
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
	joint = HingeJoint.new()
	add_child(joint)
	joint.transform = Transform.IDENTITY
	joint.rotate_x(-PI/ 2)
	joint.set("nodes/node_a", joint.get_path_to(body_a))
	joint.set("nodes/node_b", joint.get_path_to(body_b))
	joint.set("angular_limit/enable", false)
	joint.set("motor/enable", true)
	joint.set("motor/max_impulse", 1500.0)


func _other_connector_destroyed():
	if joint != null:
		joint.queue_free()
	other_connector = null
	joint = null
