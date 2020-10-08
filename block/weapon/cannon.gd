extends RigidBody
class_name Cannon


const GRAVITY = 9.8
export var projectile: PackedScene
export var reload_time := 5.0
export var projectile_velocity := 1000.0
export var projectile_damage := 400
var _voxel_body: VoxelBody
var _desired_direction := Vector3.FORWARD
var _time_of_last_shot := 0.0
var _rel_offset: Vector3


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


func _process(delta):
	var debug = get_tree().current_scene.find_node("Debug")
	var projectile_position = $ProjectileSpawn.global_transform.origin
	var projectile_velocity_v = $ProjectileSpawn.global_transform.basis.z * projectile_velocity
	debug.begin(Mesh.PRIMITIVE_LINE_STRIP)
	debug.set_color(Color.lightgreen)
	for i in range(int(20.0 / 0.1)):
		debug.add_vertex(projectile_position)
		projectile_velocity_v.y -= GRAVITY * 0.1 / 2
		projectile_position += projectile_velocity_v * 0.1
		projectile_velocity_v.y -= GRAVITY * 0.1 / 2
	debug.end()


func init(_coordinate, _block_data, _rotation, voxel_body, _vehicle):
	_rel_offset = translation
	print(_rel_offset)
	set_as_toplevel(true)
	$Generic6DOFJoint.set("nodes/node_b", $Generic6DOFJoint.get_path_to(voxel_body))
	_voxel_body = voxel_body


func aim_at(position: Vector3, _velocity := Vector3.ZERO):
	var rel_pos = _voxel_body.to_local(position) - _rel_offset
#	var self_normal = Vector3.RIGHT
#	var t = -self_normal.dot(rel_pos) / self_normal.length_squared()
#	_desired_direction = (rel_pos + t * self_normal).normalized()
#	_desired_direction.y = -_desired_direction.y

	var distance_xz = Vector2(rel_pos.x, rel_pos.z).length()
	var distance_y = rel_pos.y

	var normal_xz = rel_pos
	normal_xz.y = 0
	normal_xz = normal_xz.normalized()
	
	var projectile_spawn_y = $ProjectileSpawn.translation.y
	var projectile_spawn_z = $ProjectileSpawn.translation.z
	
	distance_xz -= projectile_spawn_y * _desired_direction.y + \
			projectile_spawn_z * _desired_direction.z
	distance_y -= projectile_spawn_y * _desired_direction.z + \
			projectile_spawn_z * -_desired_direction.y
	
	var x = distance_xz
	var y = distance_y
	var v2 = projectile_velocity * projectile_velocity
	var g = GRAVITY
	
	var f = v2 * v2 - g * (g * x * x + 2 * y * v2)
	if f >= 0:
		set_angle(atan2(v2 - sqrt(f), g * x) if f >= 0 else 0)


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
