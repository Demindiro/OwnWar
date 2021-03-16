extends Spatial
class_name OwnWar_Weapon


export var time_between_shots := -1.0
export var volley := false


func fire() -> bool:
	return false


func aim_at(_position: Vector3) -> void:
	pass
