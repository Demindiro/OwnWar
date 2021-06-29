extends OwnWar_Weapon
class_name OwnWar_WeaponLaser


signal fired(at)


# TODO
const BLOCK_SCALE := 0.25


export var damage := 100
export var inaccuracy := 0.05
var team: int
onready var _ray: RayCast = get_node("Ray")

var weapon_index = 0
var weapon_type = 0x000 # continuous fire, laser


func fire() -> bool:
	if not is_network_master():
		return false
	var dmg := damage
	var at: Vector3
	var dir := Vector3.BACK
	dir += Vector3.UP.rotated(Vector3.RIGHT, randf() * PI * 2) * inaccuracy * randf()
	_ray.cast_to = dir * 1000
	while true:
		_ray.force_raycast_update()
		if _ray.is_colliding():
			at = _ray.get_collision_point()
			var body = _ray.get_collider()
			if body != null && body.has_meta("ownwar_vehicle_team"):
				var vh_list = get_parent().get_meta("ownwar_vehicle_list")
				var vh_id = body.get_meta("ownwar_vehicle_index")
				var body_id = body.get_meta("ownwar_body_index")
				if body.get_meta("ownwar_vehicle_team") == team:
					var pos = vh_list[vh_id].raycast(body_id, at, global_transform.basis * dir)
					if pos != null:
						at = pos
						break
				else:
					assert(get_tree().is_network_server())
					var pos = vh_list[vh_id].raycast(body_id, at, global_transform.basis * dir)
					if pos != null:
						dmg = vh_list[vh_id].apply_ray_damage(body_id, at, global_transform.basis * dir, dmg)
						if dmg == 0:
							at = pos
							break
			else:
				break
			_ray.add_exception(body)
		else:
			at = global_transform * _ray.cast_to
			break
	_ray.clear_exceptions()
	rpc_unreliable_id(-OwnWar_NetInfo.disable_broadcast_id, "fired_feedback", at)
	return true


puppetsync func fired_feedback(at: Vector3) -> void:
	emit_signal("fired", at)
