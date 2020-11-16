extends RigidBody


# warning-ignore:unused_class_variable
export var damage := 0
# warning-ignore:unused_class_variable
var munition_id := -1


func _init():
	add_to_group("projectiles")
