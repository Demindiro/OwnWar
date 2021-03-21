extends OwnWar_Weapon

export var projectile: PackedScene
onready var spawn: Spatial = get_node("Spawn")

var team := -1

func fire() -> bool:
	if not is_network_master():
		return false
	var quat := global_transform.basis.get_rotation_quat()
	rpc("launch_projectile", global_transform.origin, Vector3(quat.x, quat.y, quat.z))
	return true


puppetsync func launch_projectile(position: Vector3, rot: Vector3) -> void:
	var quat := Quat(rot.x, rot.y, rot.z, 1.0 - rot.length())
	var n = projectile.instance()
	n.transform = spawn.global_transform
	n.velocity = spawn.global_transform.basis.z * 50.0
	n.team = team
	n.set_network_master(1)
	get_tree().current_scene.add_child(n)
