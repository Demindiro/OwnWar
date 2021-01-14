extends OwnWar_Weapon
class_name OwnWar_WeaponLaser


signal fired(at)


export var damage := 100
export var inaccuracy := 0.05
var fire_timer: SceneTreeTimer = null
var team: int
onready var _ray: RayCast = get_node("Ray")


func fire() -> bool:
	if not is_network_master():
		return false
	if fire_timer == null:
		var dmg := damage
		var at: Vector3
		var dir := Vector3.BACK
		dir += Vector3.UP.rotated(Vector3.RIGHT, randf() * PI * 2) * inaccuracy * randf()
		_ray.cast_to = dir * 1000
		while true:
			_ray.force_raycast_update()
			if _ray.is_colliding():
				at = _ray.get_collision_point()
				var collider := _ray.get_collider()
				var body := collider as OwnWar.VoxelBody
				if body != null:
					if body.team == team:
						if not body.can_ray_pass_through(at, global_transform * dir):
							break
					else:
						assert(get_tree().is_network_server())
						dmg = body.apply_damage(at, global_transform.basis * dir, dmg)
						if dmg == 0:
							var pos := body.last_hit_position
							pos += Vector3(0.5, 0.5, 0.5)
							pos *= OwnWar_Block.BLOCK_SCALE
							pos -= body.center_of_mass
							at = body.to_global(pos)
							break
				else:
					break
				_ray.add_exception(collider)
			else:
				at = global_transform * _ray.cast_to
				break
		_ray.clear_exceptions()
		rpc_unreliable_id(-OwnWar_NetInfo.disable_broadcast_id, "fired_feedback", at)
		fire_timer = get_tree().create_timer(time_between_shots, false)
		var e := fire_timer.connect("timeout", self, "set", ["fire_timer", null])
		assert(e == OK)
		return true
	return false


puppetsync func fired_feedback(at: Vector3) -> void:
	emit_signal("fired", at)


func _exit_tree() -> void:
	if fire_timer != null:
		fire_timer.disconnect("timeout", self, "set")


func debug_draw() -> void:
	_ray.force_raycast_update()
	var at: Vector3
	if _ray.is_colliding():
		at = _ray.get_collision_point()
	else:
		at = global_transform * _ray.cast_to
	Debug.draw_point(at, Color.red, 0.1)
