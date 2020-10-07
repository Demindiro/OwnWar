extends RigidBody
class_name Cannon


export var projectile: PackedScene
export var reload_time := 5.0
export var projectile_velocity := 1000.0
export var projectile_damage := 400
var _voxel_body: VoxelBody
var _desired_direction := Vector3.FORWARD
var _time_of_last_shot := 0.0


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


var __c = 0
func aim_at(position: Vector3, _velocity := Vector3.ZERO):
	var rel_pos = _voxel_body.to_local(position)
	var self_normal = Vector3.RIGHT
	var t = -self_normal.dot(rel_pos) / self_normal.length_squared()
	_desired_direction = (rel_pos + t * self_normal).normalized()
	_desired_direction.y = -_desired_direction.y


func fire():
	var current_time := float(Engine.get_physics_frames()) / Engine.iterations_per_second
	if current_time >= _time_of_last_shot + reload_time:
		var node = projectile.instance()
		node.global_transform = $ProjectileSpawn.global_transform
		node.linear_velocity = $ProjectileSpawn.global_transform.basis.z
		node.linear_velocity *= projectile_velocity
		node.damage = projectile_damage
		get_tree().root.get_child(1).add_child(node) # TODO ugly
		_time_of_last_shot = current_time


func set_angle(angle):
	_desired_direction = Vector3.BACK.rotated(Vector3.RIGHT, angle)
