extends RigidBody
class_name Cannon


var _voxel_body: VoxelBody
var _desired_direction := Vector3.FORWARD


func _physics_process(_delta):
	var other_forward = _voxel_body.global_transform.basis.z
	var self_normal = global_transform.basis.x
	var t = -self_normal.dot(other_forward) / self_normal.length_squared()
	var projected_other_forward = (other_forward + t * self_normal).normalized()
	var abs_desired_direction = global_transform.basis * _desired_direction
	var error = 1.0 - projected_other_forward.dot(abs_desired_direction)
	var direction = -sign(projected_other_forward \
			.cross(abs_desired_direction) \
			.dot(self_normal))
	if abs(direction) < 1e-5:
		direction = 1.0
	var turn_rate = 0 if error < 1e-4 else direction
	$Generic6DOFJoint.set("angular_motor_x/target_velocity", turn_rate)


func init(_coordinate, _block_data, _rotation, voxel_body, _vehicle):
	set_as_toplevel(true)
	$Generic6DOFJoint.set("nodes/node_b", $Generic6DOFJoint.get_path_to(voxel_body))
	_voxel_body = voxel_body


func aim_at(position: Vector3, _velocity := Vector3.ZERO):
	var rel_pos = to_local(position)
	var self_normal = global_transform.basis.x
	var t = -self_normal.dot(rel_pos) / self_normal.length_squared()
	_desired_direction = (rel_pos + t * self_normal).normalized()


func set_angle(angle):
	_desired_direction = Vector3.BACK.rotated(Vector3.RIGHT, angle)
