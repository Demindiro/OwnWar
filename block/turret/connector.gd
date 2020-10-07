extends Spatial


var connected = false
var joint
var desired_direction := Vector3(0, 0, 1)
var body_a
var body_b
var other_connector
var _forward_axis := -1


func init(coordinate, _block_data, _rotation, voxel_body, vehicle):
	if connected:
		return
	var connecting_coordinate = get_connecting_coordinate(coordinate)
	var id = Global.blocks["turret_connector"].id
	for body in vehicle.voxel_bodies:
		if body != voxel_body:
			var other_block = body.blocks.get(connecting_coordinate)
			if other_block != null and other_block[0] == id:
				other_connector = other_block[2].get_child(0)
				if other_connector.get_connecting_coordinate(connecting_coordinate) \
						== coordinate:
					_create_joint(voxel_body, body)
					connected = true
					other_connector.connected = true
					return
				other_connector = null


var _angle = 0.0
func _physics_process(delta):
	if joint == null:
		return
	var other_forward = other_connector.global_transform.basis.x # TODO figure out why X is "forward"
	var self_forward = global_transform.basis.z
	var self_normal = global_transform.basis.y
	var t = -self_normal.dot(other_forward) / self_normal.length_squared()
	var projected_other_forward = (other_forward + t * self_normal).normalized()
	var abs_desired_direction = global_transform.rotated(self_normal, _angle).basis.z
	var error = 1.0 - projected_other_forward.dot(abs_desired_direction)
	var direction = -sign(projected_other_forward \
			.cross(abs_desired_direction) \
			.dot(self_normal))
	if abs(direction) < 1e-5:
		direction = 1.0
	__e = error
	__d = direction
#	__e = other_forward
#	__d = self_forward
	var turn_rate = 0 if error < 1e-4 else direction
	joint.set("angular_motor_x/target_velocity", turn_rate)

var __e
var __d
func _process(_delta):
	if joint == null:
		return
	print("[", _angle, "] ", __e, "   ", __d)
	var debug = get_tree().current_scene.find_node("Debug")
	debug.draw_line(global_transform.origin, global_transform.origin + global_transform.basis.z * 10.0)
#	debug.draw_line(other_connector.global_transform.origin, 
#			other_connector.global_transform.origin + other_connector.global_transform.basis.z * 10.0)
	debug.draw_line(other_connector.global_transform.origin, 
			other_connector.global_transform.origin + other_connector.global_transform.basis.x * 20.0)
#	.draw_point(to_global(rel_pos))


func _input(event):
	if event is InputEventKey and event.scancode == KEY_KP_5 and event.pressed:
		_angle += PI / 4
		_angle = fposmod(_angle, PI * 2)
		turn(_angle)


func turn(angle):
	pass
#	desired_direction = Vector3.FORWARD.rotated(Vector3.UP, angle)


func get_connecting_coordinate(coordinate):
	var up = get_parent().transform.basis.y.round()
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
	joint.set("angular_motor_x/force_limit", 1000000.0)
