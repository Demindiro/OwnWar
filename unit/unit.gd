class_name Unit

extends Spatial

export var max_health := 10
export var team := 0

onready var health := max_health


func projectile_hit(origin: Vector3, direction: Vector3, damage: int):
	health -= damage
	if health == 0:
		queue_free()
