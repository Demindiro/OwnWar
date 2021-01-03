extends PanelContainer


export var add_texture: Texture
onready var _box: Control = get_node("Box/Box")
onready var _new_vehicle_gui: Control = get_node("../NewVehicle")


signal select_vehicle(path)


func _ready() -> void:
	generate_vehicle_list()
	if _box.get_child_count() > 0:
		_box.get_child(0).call_deferred("grab_focus")


func generate_vehicle_list() -> void:
	Util.free_children(_box)
	var prev_btn: BaseButton = null
	for path in Util.iterate_dir("user://vehicles", "json"):
		path = "user://vehicles".plus_file(path)
		var btn := TextureButton.new()
		if not OwnWar_Thumbnail.get_vehicle_thumbnail_async(path,
			funcref(self, "_set_thumbnail"), [btn, path]):
			btn.texture_normal = preload("res://editor/ellipsis.png")
		Util.assert_connect(btn, "mouse_entered", self, "_button_mouse_entered", [btn])
		Util.assert_connect(btn, "mouse_exited", self, "_button_mouse_exited", [btn])
		Util.assert_connect(btn, "focus_entered", self, "emit_signal", ["select_vehicle", path])
		Util.assert_connect(btn, "focus_entered", self, "_button_mouse_entered", [btn])
		Util.assert_connect(btn, "focus_exited", self, "_button_mouse_exited", [btn])
		btn.set_meta("mouse_inside", false)
		_box.add_child(btn)
		prev_btn = btn
	if prev_btn != null:
		var first_btn: BaseButton = _box.get_child(0)
		var first_path := first_btn.get_path()
		var last_path := prev_btn.get_path()
		prev_btn.focus_neighbour_right = first_path
		first_btn.focus_neighbour_left = last_path


func _set_thumbnail(image: Image, btn: TextureButton, path: String) -> void:
	var tex := ImageTexture.new()
	tex.create_from_image(image)
	btn.texture_normal = tex


func _button_mouse_entered(node: Control) -> void:
	node.modulate = Color(0.8, 0.8, 0.8, 1.0)
	if not node.has_focus():
		node.grab_focus()


func _button_mouse_exited(node: Control) -> void:
	if not node.has_focus():
		node.modulate = Color(1.0, 1.0, 1.0, 1.0)
