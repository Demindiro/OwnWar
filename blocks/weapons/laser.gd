extends "weapon.gd"


signal fired()
export var reload_time := 5.0
export var inaccuracy := 0.01
export var damage := 1000.0
export var recoil_impulse := 1000.0
export var max_turn_speed := PI / 2
var _voxel_body: OwnWar.VoxelBody
var _time_of_last_shot := -INF
var _aim_pos := Vector3()
var _interpolation_dirty := true
var _curr_transform := transform
var _prev_transform := transform
onready var _projectile_spawn: Spatial = get_node("ProjectileSpawn")
onready var _joint: HingeJoint = get_node("Joint")
onready var _visual: Spatial = get_node("Visual")


func _ready() -> void:
	if OS.has_feature("Server"):
		set_process(false)
		_visual.free()
	elif not OwnWar.is_in_designer(get_tree()):
		_visual.set_as_toplevel(true)


func _process(_delta: float) -> void:
	if _interpolation_dirty:
		_prev_transform = _curr_transform
		_curr_transform = global_transform
		_interpolation_dirty = false
	var frac := Engine.get_physics_interpolation_fraction()
	var trf := _prev_transform.interpolate_with(transform, frac)
	_visual.transform = trf


func _physics_process(delta: float) -> void:
	var curr_dir := (_aim_pos - global_transform.origin).normalized()
	var error := curr_dir.dot(global_transform.basis.z)
	var side := -sign(curr_dir.dot(global_transform.basis.y))
	var angle_diff := acos(clamp(error, -1.0, 1.0))
	var max_turn := max_turn_speed * delta
	# Multiply by 0.5 because I'm doing something wrong (idk what tho :/)
	var turn_rate := max_turn_speed * min(1.0, angle_diff / max_turn * 0.5)
	_joint.set("motor/target_velocity", turn_rate * side)
	if _interpolation_dirty:
		_prev_transform = _curr_transform
		_curr_transform = transform
	_interpolation_dirty = true


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
	var current_time := float(Engine.get_physics_frames()) / Engine.iterations_per_second
	Debug.draw_text(
		_visual.transform.origin,
		"Reload: %.3f / %.3f" % [
			min(current_time - _time_of_last_shot, reload_time),
			reload_time,
		],
		Color.red
	)


func init(_coordinate, _block_data, _rotation, voxel_body, vehicle, _meta):
	_joint = get_node("Joint")
	set_as_toplevel(true)
	_joint.set("nodes/node_b", _joint.get_path_to(voxel_body))
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
		var state := get_world().get_direct_space_state()
		var dmg := damage
		var ignore := []
		while dmg > 0:
			var result := state.intersect_ray(
				g_trans.origin,
				g_trans.origin + g_trans.basis.z * 10000,
				ignore
			)
			if len(result) > 0:
				var body = result["collider"]
				if body.has_method("projectile_hit"):
					var pos: Vector3 = result["position"]
					dmg = body.projectile_hit(pos, g_trans.basis.z * 10000, dmg)
					ignore.append(body)
					continue
			break
		emit_signal("fired")


func serialize_json() -> Dictionary:
	return { "transform": var2str(global_transform) }


func deserialize_json(data: Dictionary) -> void:
	global_transform = str2var(data["transform"])
