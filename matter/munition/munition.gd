class_name Munition
extends Resource


export var human_name := ""
export var shell: PackedScene
export var mesh: Mesh
export var cost := 3
export var gauge := -1


func _to_string():
	return human_name


static func is_munition(id: int) -> bool:
	return id in RegisterMunition.id_to_munitions
