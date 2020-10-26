extends "vehicle_selector.gd"


signal save_vehicle(path)

onready var name_box = find_node("Name")
onready var path_box = find_node("Path")
onready var files_box = find_node("Files")
onready var template


func _ready():
	template = files_box.get_node("Template")
	files_box.remove_child(template)
	_on_Name_text_changed(name_box.text)
	scan_directory()


func scan_directory():
	for child in files_box.get_children():
		files_box.remove_child(child)
	for file in .scan_directory():
		var node = template.duplicate()
		files_box.add_child(node)
		node.text = path_to_name(file)
		node.connect("pressed", self, "set_path", [file])


func set_path(path):
	if path.ends_with(FILE_EXTENSION):
		name_box.text = path_to_name(path)
		_on_Name_text_changed(name_box.text)
		
		
func set_full_path(path):
	assert(path.begins_with("user://vehicles/"))
	set_path(path.substr(len("user://vehicles/")))


func _on_Save_pressed():
	var path = name_to_path(name_box.text)
	assert(path.is_valid_filename())
	path = directory.get_current_dir().plus_file(path)
	emit_signal("save_vehicle", path)
	

func _on_Name_text_changed(new_text):
	if new_text == "":
		path_box.text = "Enter a name"
	else:
		var path = name_to_path(name_box.text)
		if path.is_valid_filename():
			path_box.text = "Will be saved as '%s'" % path
		else:
			path_box.text = "Invalid filename ('%s')" % path
