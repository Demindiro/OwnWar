extends OwnWar_Weapon

export var projectile: PackedScene
onready var spawn: Spatial = get_node("Spawn")

var team := -1

func fire() -> bool:
	if not is_network_master():
		return false
	var n = projectile.instance()
	n.transform = spawn.global_transform
	n.velocity = spawn.global_transform.basis.z * 50.0
	n.team = team
	get_tree().current_scene.add_child(n)
	return true
