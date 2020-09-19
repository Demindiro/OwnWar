extends Control


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
	return name.to_lower().replace(' ', '_') + '.json'
	
	
func path_to_name(path):
	assert(path.ends_with(FILE_EXTENSION))
	return path.substr(0, len(path) - len(FILE_EXTENSION)).capitalize()
