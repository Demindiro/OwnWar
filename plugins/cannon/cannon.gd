extends "../weapon_manager/weapon.gd"


signal fired()
const GRAVITY = 9.8
export var reload_time := 5.0
export var projectile_velocity := 1000.0
export var inaccuracy := 0.01
export var gauge := -1
export var recoil_impulse := NAN
var _voxel_body: VoxelBody
var _desired_direction := Vector3.FORWARD
var _time_of_last_shot := 0.0
var _rel_offset: Vector3
var _error: float
onready var _projectile_spawn: Spatial = $ProjectileSpawn


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


func debug_draw():
	var projectile_position = _projectile_spawn.global_transform.origin
	var projectile_velocity_v = _projectile_spawn.global_transform.basis.z * \
			projectile_velocity
	var l := int(10.0 / 0.5)
	var arr := PoolVector3Array()
	arr.resize(l)
	for i in range(l):
		arr[i] = projectile_position
		projectile_velocity_v.y -= GRAVITY * 0.5 / 2
		projectile_position += projectile_velocity_v * 0.5
		projectile_velocity_v.y -= GRAVITY * 0.5 / 2
	Debug.draw_graph(arr, Color.lightgreen)


func init(_coordinate, _block_data, _rotation, voxel_body, vehicle, _meta):
	.init(_coordinate, _block_data, _rotation, voxel_body, vehicle, _meta)
	_rel_offset = translation
	set_as_toplevel(true)
	$Generic6DOFJoint.set("nodes/node_b", $Generic6DOFJoint.get_path_to(voxel_body))
	_voxel_body = voxel_body


func aim_at(position: Vector3, _velocity := Vector3.ZERO):
	var rel_pos = _voxel_body.to_local(position) - _rel_offset

	var distance_xz = Vector2(rel_pos.x, rel_pos.z).length()
	var distance_y = rel_pos.y

	var normal_xz = rel_pos
	normal_xz.y = 0
	normal_xz = normal_xz.normalized()

	var projectile_spawn_y = _projectile_spawn.translation.y
	var projectile_spawn_z = _projectile_spawn.translation.z

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
		var munitions: Dictionary = weapon_manager.take_munition(gauge, 1)
		for id in munitions:
			if munitions[id] > 0:
				var g_trans := _projectile_spawn.global_transform
				var munition = Munition.get_munition(id)
				var y = g_trans.basis.y
				var z = g_trans.basis.z
				var direction = (y.rotated(z, randf() * PI * 2) * inaccuracy + z)\
						.normalized()
				var node = munition.shell.instance()
				node.munition_id = id
				node.global_transform = _projectile_spawn.global_transform
				node.linear_velocity = direction * projectile_velocity
				var s = self
				assert(s is RigidBody)
				assert(not is_nan(recoil_impulse))
				Util.add_impulse(s, g_trans.origin, -g_trans.basis.z * \
						recoil_impulse)
				get_tree().current_scene.add_child(node)
				_time_of_last_shot = current_time
				emit_signal("fired")
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


func serialize_json() -> Dictionary:
	return { "transform": var2str(global_transform) }


func deserialize_json(data: Dictionary) -> void:
	global_transform = str2var(data["transform"])
