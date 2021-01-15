extends Control


const Card := preload("vehicle_list_item.gd")

export var card_template: PackedScene

var _button_group := ButtonGroup.new()

onready var _box: Control = get_node("Box/Box")
onready var _new_vehicle_gui: Control = get_node("../NewVehicle")


signal select_vehicle(path)


func _ready() -> void:
	generate_vehicle_list()


func generate_vehicle_list() -> void:
	#Util.free_children(_box)
	var prev_btn: Card = null
	for path in Util.iterate_dir("user://vehicles", "gz"):
		path = "user://vehicles".plus_file(path)
		var btn: Card = card_template.instance()
		OwnWar_Thumbnail.call_deferred("get_vehicle_thumbnail_async", path, funcref(self, "_set_thumbnail"), [btn, path])
		Util.assert_connect(btn, "pressed", self, "emit_signal", ["select_vehicle", path])
		btn.group = _button_group
		_box.add_child(btn)
		prev_btn = btn
	if prev_btn != null:
		var first_btn: Card = _box.get_child(0)
		first_btn.pressed = true
		first_btn.emit_signal("pressed")
		var first_path := first_btn.get_path()
		var last_path := prev_btn.get_path()
		prev_btn.focus_neighbour_right = first_path
		first_btn.focus_neighbour_left = last_path


func _set_thumbnail(image: Image, btn: Card, path: String) -> void:
	var tex := ImageTexture.new()
	tex.create_from_image(image)
	btn.icon.texture = tex
	btn.name_s.text = Util.humanize_file_name(path.get_file().get_basename())
