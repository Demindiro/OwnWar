extends "vehicle_selector.gd"


signal load_vehicle(path)
# warning-ignore:unused_signal
signal cancel()

onready var name_box = find_node("Name")
onready var files_box = find_node("Files")
onready var template


func _ready():
	template = files_box.get_node("Template")
	files_box.remove_child(template)
	scan_directory()


func scan_directory():
	for child in files_box.get_children():
		files_box.remove_child(child)
	var err = directory.list_dir_begin(true)
	assert(err == OK)
	var file = directory.get_next()
	while file != "":
		if file.ends_with(FILE_EXTENSION) and directory.file_exists(file):
			var node = template.duplicate()
			files_box.add_child(node)
			node.text = path_to_name(file)
			node.connect("pressed", self, "set_path", [file])
		file = directory.get_next()
	directory.list_dir_end()


func set_path(path):
	if path.ends_with(FILE_EXTENSION):
		name_box.text = path_to_name(path)


func _on_Load_pressed():
	var path = name_to_path(name_box.text)
	assert(path.is_valid_filename())
	var absolute_path = directory.get_current_dir().plus_file(path)
	emit_signal("load_vehicle", absolute_path)
