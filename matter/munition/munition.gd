class_name Munition
extends Resource


export var human_name := ""
# warning-ignore:unused_class_variable
export var shell: PackedScene
# warning-ignore:unused_class_variable
export var mesh: Mesh
# warning-ignore:unused_class_variable
export var cost := 1
# warning-ignore:unused_class_variable
export var shells_per_batch := 1
# warning-ignore:unused_class_variable
export var gauge := -1


func _to_string():
	return human_name


static func is_munition(id: int) -> bool:
	return id in RegisterMunition.id_to_munitions
