class_name Unit

extends Spatial

export var max_health := 10
export var team := 0

onready var health := max_health
onready var game_master = get_tree().get_current_scene()


func projectile_hit(origin: Vector3, direction: Vector3, damage: int):
	health -= damage
	if health <= 0:
		queue_free()
		return -health
	return 0


func get_actions():
	return []
