extends RigidBody


export var damage := 0
var munition_id := -1


func _init():
	add_to_group("projectiles")
