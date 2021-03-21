extends OwnWar_Weapon

export var projectile: PackedScene
onready var spawn: Spatial = get_node("Spawn")

var team := -1
var counter := 0

func fire() -> bool:
	if not is_network_master():
		return false
	var trf := spawn.global_transform
	var quat := trf.basis.get_rotation_quat()
	if quat.w < 0.0:
		quat = -quat
	rpc("launch_projectile", trf.origin, Vector3(quat.x, quat.y, quat.z), Vector3())
	return true


puppetsync func launch_projectile(pos: Vector3, rot: Vector3, vel: Vector3) -> void:
	var quat := Quat(rot.x, rot.y, rot.z, sqrt(abs(1.0 - rot.length_squared())))
	var transform = Transform(Basis(quat), pos)
	var n = projectile.instance()
	n.transform = transform
	n.velocity = transform.basis.z * 50.0 + vel
	n.team = team
	n.set_network_master(1)
	n.name = name + " - " + str(counter)
	counter += 1
	get_tree().current_scene.add_child(n, true)
