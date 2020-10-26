extends "res://core/menu/dialog/independent_panel.gd"


const VEHICLE_DIRECTORY = "vehicles"
const FILE_EXTENSION = ".json"

onready var directory = Directory.new()


func _ready():
	directory.open('user://')
	if not directory.dir_exists(VEHICLE_DIRECTORY):
		directory.make_dir(VEHICLE_DIRECTORY)
	directory.change_dir(VEHICLE_DIRECTORY)


func scan_directory():
	var files = []
	var err = directory.list_dir_begin(true)
	assert(err == OK)
	var file = directory.get_next()
	while file != "":
		if file.ends_with(FILE_EXTENSION) and not directory.current_is_dir():
			files.append(file)
		file = directory.get_next()
	directory.list_dir_end()
	return files


func name_to_path(name):
	return Vehicle.name_to_path(name)
	
	
func path_to_name(path):
	return Vehicle.path_to_name(path)
