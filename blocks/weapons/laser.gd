extends "weapon.gd"


signal fired()
export var reload_time := 5.0
export var inaccuracy := 0.01
export var damage := 1000.0
export var recoil_impulse := 1000.0
export var max_turn_speed := PI / 2
var _voxel_body: OwnWar.VoxelBody
var _time_of_last_shot := 0.0
var _aim_pos := Vector3()
onready var _projectile_spawn: Spatial = $ProjectileSpawn
onready var _joint: Generic6DOFJoint = get_node("Generic6DOFJoint")
onready var _prev_transform := global_transform
onready var _visual: Spatial = get_node("Visual")


func _ready() -> void:
	if OS.has_feature("Server"):
		set_process(false)
		_visual.free()
	elif not OwnWar.is_in_designer(get_tree()):
		_visual.set_as_toplevel(true)


func _process(_delta: float) -> void:
	var frac := Engine.get_physics_interpolation_fraction()
	var trf := _prev_transform.interpolate_with(transform, frac)
	_visual.transform = trf


func _physics_process(delta: float) -> void:
	_prev_transform = global_transform
	var curr_dir := (_aim_pos - global_transform.origin).normalized()
	var error := curr_dir.dot(global_transform.basis.z)
	var side := -sign(curr_dir.dot(global_transform.basis.y))
	var angle_diff := acos(clamp(error, -1.0, 1.0))
	var max_turn := max_turn_speed * delta
	# Multiply by 0.5 because I'm doing something wrong (idk what tho :/)
	var turn_rate := max_turn_speed * min(1.0, angle_diff / max_turn * 0.5)
	_joint.set("angular_motor_x/target_velocity", turn_rate * side)


func debug_draw():
	Debug.draw_normal(
		_projectile_spawn.global_transform.origin,
		_projectile_spawn.global_transform.basis.z * 10000,
		Color.lightgreen
	)
	var curr_dir := (_aim_pos - global_transform.origin).normalized()
	Debug.draw_normal(
		translation,
		global_transform.basis.y,
		Color.red
	)
	Debug.draw_normal(
		translation,
		global_transform.basis.z,
		Color.red
	)
	Debug.draw_normal(
		translation,
		curr_dir,
		Color.blue
	)


func init(_coordinate, _block_data, _rotation, voxel_body, vehicle, _meta):
	set_as_toplevel(true)
	$Generic6DOFJoint.set("nodes/node_b", $Generic6DOFJoint.get_path_to(voxel_body))
	_voxel_body = voxel_body


func aim_at(position: Vector3):
	_aim_pos = position


func fire():
	var current_time := float(Engine.get_physics_frames()) / Engine.iterations_per_second
	if current_time >= _time_of_last_shot + reload_time:
		var g_trans := _projectile_spawn.global_transform
		var s = self
		assert(s is RigidBody)
		assert(not is_nan(recoil_impulse))
		Util.add_impulse(s, g_trans.origin, -g_trans.basis.z * recoil_impulse)
		_time_of_last_shot = current_time
		emit_signal("fired")


func serialize_json() -> Dictionary:
	return { "transform": var2str(global_transform) }


func deserialize_json(data: Dictionary) -> void:
	global_transform = str2var(data["transform"])
