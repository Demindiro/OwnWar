extends Node


export(String, FILE) var file := "user://vehicles/fancy_box.json"


func _ready():
	$Vehicle.set_physics_process(false)
	$Vehicle.set_process(false)
	$Vehicle.load_from_file(file)
