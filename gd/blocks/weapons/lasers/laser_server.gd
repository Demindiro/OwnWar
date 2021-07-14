extends OwnWar_Weapon
class_name OwnWar_WeaponLaser


signal fired(at)


# TODO
const BLOCK_SCALE := 0.25


export var damage := 100
export var inaccuracy := 0.05
var team: int
onready var _ray = $Ray

var weapon_index = 0
var weapon_type = 0x000 # continuous fire, laser


func fire() -> bool:
	if not is_network_master():
		return false

	var dmg := damage
	var at
	var trf = _ray.global_transform
	var dir = (trf.basis.z + Vector3.UP.rotated(Vector3.RIGHT, randf() * PI * 2) * inaccuracy * randf()) * 1000
	var from = trf.origin
	var to = from + dir

	var results = PhysicsServer.space_intersections_with_ray(
		get_world().space,
		from,
		to,
		true
	)
	while len(results) > 0:
		# Find the closest entry
		var res = results.pop_back()
		var toi = res["time_of_impact"]
		for i in len(results):
			var r = results[i]
			var t = r["time_of_impact"]
			if t < toi:
				results[i] = res
				res = r
				toi = t

		# Check what we hit
		at = res["position"]
		var body = instance_from_id(res["object_id"])
		if body != null && body.has_meta("ownwar_vehicle_team"):
			# We hit a vehicle
			var vh_list = get_parent().get_meta("ownwar_vehicle_list")
			var vh_id = body.get_meta("ownwar_vehicle_index")
			var body_id = body.get_meta("ownwar_body_index")
			if body.get_meta("ownwar_vehicle_team") == team:
				# We hit a friendly vehicle, check if the ray can pass
				at = vh_list[vh_id].raycast(body_id, at, dir)
				if at != null:
					break
			else:
				assert(get_tree().is_network_server())
				# We hit an enemy vehicle, apply damage if we hit
				at = vh_list[vh_id].raycast(body_id, at, dir)
				if at != null:
					dmg = vh_list[vh_id].apply_ray_damage(body_id, at, dir, dmg)
					if dmg == 0:
						break
		else:
			# We hit something non-voxel & indestructible
			break

	if at == null:
		at = to
	rpc_unreliable_id(-OwnWar_NetInfo.disable_broadcast_id, "fired_feedback", at)
	return true


puppetsync func fired_feedback(at: Vector3) -> void:
	emit_signal("fired", at)
