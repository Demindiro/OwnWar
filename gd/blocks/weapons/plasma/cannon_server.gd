extends OwnWar_Weapon

export var projectile: PackedScene
onready var spawn: Spatial = get_node("Spawn")
onready var spawn_translation = translation + transform.basis * spawn.translation

var team := -1
var counter := 0

var weapon_index = 0
var weapon_type = 0x101 # volley fire, plasma

var color := Color.purple

func _ready():
	var b = get_parent()
	color = b.get_meta("ownwar_vehicle_list")[b.get_meta("ownwar_vehicle_index")].get_team_color()


func fire() -> bool:
	if not is_network_master():
		return false
	var trf := spawn.global_transform
	var quat := trf.basis.get_rotation_quat()
	if quat.w < 0.0:
		quat = -quat
	var prt = get_parent()
	var vel = trf.basis.z * 50.0 \
			+ prt.linear_velocity \
			+ prt.angular_velocity.cross(trf.basis * spawn_translation)
	rpc(
		"launch_projectile",
		trf.origin,
		Vector3(quat.x, quat.y, quat.z),
		vel
	)
	return true


puppetsync func launch_projectile(pos: Vector3, rot: Vector3, vel: Vector3) -> void:
	var quat := Quat(rot.x, rot.y, rot.z, sqrt(abs(1.0 - rot.length_squared())))
	var transform = Transform(Basis(quat), pos)
	var n = projectile.instance()
	n.transform = transform
	n.velocity = vel
	n.team = team
	n.set_network_master(1)
	n.name = name + " - " + str(counter)
	n.color = color
	counter += 1
	get_tree().current_scene.add_child(n, true)
