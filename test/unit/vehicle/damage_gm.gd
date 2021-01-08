extends Node


func _enter_tree():
	get_node("Vehicle").team = 0
	get_tree().debug_collisions_hint = true
