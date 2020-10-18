extends RigidBody
class_name Cannon


const GRAVITY = 9.8
export var reload_time := 5.0
export var projectile_velocity := 1000.0
export var inaccuracy := 0.01
export var gauge := -1
var _voxel_body: VoxelBody
var _desired_direction := Vector3.FORWARD
var _time_of_last_shot := 0.0
var _rel_offset: Vector3
var _error: float
var _manager: Reference


func _physics_process(_delta):
	var other_forward = _voxel_body.global_transform.basis.z
	var self_normal = global_transform.basis.x
	var t = -self_normal.dot(other_forward) / self_normal.length_squared()
	var projected_other_forward = (other_forward + t * self_normal).normalized()
	var abs_desired_direction = global_transform.basis * _desired_direction
	_error = 1.0 - projected_other_forward.dot(abs_desired_direction)
	var direction = -projected_other_forward \
			.cross(abs_desired_direction) \
			.dot(self_normal)
	if _error > 1e-2 and abs(direction) < 1e-5:
		direction = 1.0
	var turn_rate = 0 if _error < 1e-10 else direction * PI * 10
	turn_rate = clamp(turn_rate, -PI / 2, PI / 2)
	$Generic6DOFJoint.set("angular_motor_x/target_velocity", turn_rate)


func _process(_delta):
	var debug = get_tree().current_scene.find_node("Debug")
	var projectile_position = $ProjectileSpawn.global_transform.origin
	var projectile_velocity_v = $ProjectileSpawn.global_transform.basis.z * projectile_velocity
	debug.begin(Mesh.PRIMITIVE_LINE_STRIP)
	debug.set_color(Color.lightgreen)
	for _i in range(int(20.0 / 0.1)):
		debug.add_vertex(projectile_position)
		projectile_velocity_v.y -= GRAVITY * 0.1 / 2
		projectile_position += projectile_velocity_v * 0.1
		projectile_velocity_v.y -= GRAVITY * 0.1 / 2
	debug.end()


func init(_coordinate, _block_data, _rotation, voxel_body, vehicle, _meta):
	_rel_offset = translation
	set_as_toplevel(true)
	$Generic6DOFJoint.set("nodes/node_b", $Generic6DOFJoint.get_path_to(voxel_body))
	_voxel_body = voxel_body
	_manager = vehicle.get_manager("weapon", preload("res://block/weapon/weapon_manager.gd"))
	_manager.add_cannon(self)


func aim_at(position: Vector3, _velocity := Vector3.ZERO):
	var rel_pos = _voxel_body.to_local(position) - _rel_offset

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
	set_angle(atan2(v2 - sqrt(f), g * x) if f >= 0.0 else 0.0)


func fire():
	var current_time := float(Engine.get_physics_frames()) / Engine.iterations_per_second
	if current_time >= _time_of_last_shot + reload_time:
		var munitions: Dictionary = _manager.take_munition(gauge, 1)
		for id in munitions:
			if munitions[id] > 0:
				var munition: Munition = RegisterMunition.id_to_munitions[id]
				var y = $ProjectileSpawn.global_transform.basis.y
				var z = $ProjectileSpawn.global_transform.basis.z
				var direction = (y.rotated(z, randf() * PI * 2) * inaccuracy + z).normalized()
				var node = munition.shell.instance()
				node.global_transform = $ProjectileSpawn.global_transform
				node.linear_velocity = direction * projectile_velocity
				get_tree().current_scene.add_child(node)
				_time_of_last_shot = current_time
				break


func set_angle(angle):
	_desired_direction = Vector3.BACK.rotated(Vector3.RIGHT, angle)


func get_error() -> float:
	return _error


func get_total_error(_target: Vector3) -> float:
	assert(false)
#	var direction_to_target = (target - global_transform.origin).normalized()
#	var cannon_direction = global_transform.basis.z
#	return 1.0 - cannon_direction.dot(direction_to_target)
	return _error
