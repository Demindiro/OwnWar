class_name Unit

extends Spatial

export var max_health := 10
export var team := 0
export var unit_name := "unit"

onready var health := max_health
onready var game_master = get_tree().get_current_scene()


func projectile_hit(_origin: Vector3, _direction: Vector3, damage: int):
	health -= damage
	if health <= 0:
		game_master.remove_unit(team, self)
		return -health
	return 0


func get_actions():
	return []
