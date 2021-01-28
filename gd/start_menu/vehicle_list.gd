extends Control


const Card := preload("vehicle_list_item.gd")

export var card_template: PackedScene

var _button_group := ButtonGroup.new()

onready var _box: Control = get_node("Box/Box")


# TODO
# warning-ignore:unused_signal
signal select_vehicle(path)


func _ready() -> void:
	generate_vehicle_list()


func create_vehicle_directory() -> void:
	var dir := Directory.new()
	if not dir.dir_exists("user://vehicles/"):
		print("Creating vehicle directory")
		dir.make_dir("user://vehicles/")
		for f in ["at-at_chicken.owv", "skunk.owv", "tank.owv"]:
			print("Copying %s" % f)
			var e := dir.copy("res://default_user_dir/vehicles/%s" % f, "user://vehicles/%s" %f)
			assert(e == OK)


func generate_vehicle_list() -> void:
	create_vehicle_directory()
	Util.free_children(_box)
	var prev_btn: Card = null
	for path in Util.iterate_dir("user://vehicles", OwnWar.VEHICLE_EXTENSION):
		path = "user://vehicles".plus_file(path)
		var btn: Card = card_template.instance()
		OwnWar_Thumbnail.call_deferred("get_vehicle_thumbnail_async", path, funcref(self, "_set_thumbnail"), [btn, path])
		var e := btn.connect("pressed", self, "emit_signal", ["select_vehicle", path])
		assert(e == OK)
		btn.group = _button_group
		_box.add_child(btn)
		prev_btn = btn
		if path == OwnWar_Settings.selected_vehicle_path:
			btn.pressed = true
			btn.grab_focus()
	if prev_btn != null:
		var first_btn: Card = _box.get_child(0)
		var first_path := first_btn.get_path()
		var last_path := prev_btn.get_path()
		prev_btn.focus_neighbour_right = first_path
		first_btn.focus_neighbour_left = last_path


func _set_thumbnail(image: Image, btn: Card, path: String) -> void:
	var tex := ImageTexture.new()
	tex.create_from_image(image)
	btn.icon.texture = tex
	btn.name_s.text = Util.humanize_file_name(path.get_file().get_basename())


func on_vehicle_renamed(from: String, to: String) -> void:
	var from_name := OwnWar.get_vehicle_name(from)
	for child in _box.get_children():
		if child.name_s.text == from_name:
			child.name_s.text = OwnWar.get_vehicle_name(to) 
			child.disconnect("pressed", self, "emit_signal")
			var e: int = child.connect("pressed", self, "emit_signal", ["select_vehicle", to])
			assert(e == OK)
			return
	assert(false, "Item not found!")
