extends PanelContainer


export var add_texture: Texture
onready var _box: Control = get_node("Box/Box")
onready var _new_vehicle_gui: Control = get_node("../NewVehicle")


signal select_vehicle(path)


func _ready() -> void:
	for path in Util.iterate_dir("user://vehicles", "json"):
		path = "user://vehicles".plus_file(path)
		var btn := TextureButton.new()
		if not OwnWar_Thumbnail.get_vehicle_thumbnail_async(path,
			funcref(self, "_set_thumbnail"), [btn, path]):
			btn.texture_normal = preload("res://core/designer/ellipsis.png")
		var e := btn.connect("mouse_entered", self, "_button_mouse_entered", [btn])
		assert(e == OK)
		e = btn.connect("mouse_exited", self, "_button_mouse_exited", [btn])
		assert(e == OK)
		e = btn.connect("button_up", self, "_button_up", [btn])
		assert(e == OK)
		e = btn.connect("button_down", self, "_button_down", [btn])
		assert(e == OK)
		e = btn.connect("pressed", self, "emit_signal", ["select_vehicle", path])
		assert(e == OK)
		btn.set_meta("mouse_inside", false)
		_box.add_child(btn)
	var btn := TextureButton.new()
	btn.texture_normal = add_texture
	btn.rect_min_size = Vector2(96, 96)
	btn.expand = true
	var e := btn.connect("mouse_entered", self, "_button_mouse_entered", [btn])
	assert(e == OK)
	e = btn.connect("mouse_exited", self, "_button_mouse_exited", [btn])
	assert(e == OK)
	e = btn.connect("button_up", self, "_button_up", [btn])
	assert(e == OK)
	e = btn.connect("button_down", self, "_button_down", [btn])
	assert(e == OK)
	e = btn.connect("pressed", _new_vehicle_gui, "activate")
	assert(e == OK)
	btn.set_meta("mouse_inside", false)
	_box.add_child(btn)


func _set_thumbnail(image: Image, btn: TextureButton, path: String) -> void:
	var tex := ImageTexture.new()
	tex.create_from_image(image)
	btn.texture_normal = tex


func _button_mouse_entered(node: Control) -> void:
	node.modulate = Color(0.8, 0.8, 0.8, 1.0)
	node.set_meta("mouse_inside", true)


func _button_mouse_exited(node: Control) -> void:
	node.modulate = Color(1.0, 1.0, 1.0, 1.0)
	node.set_meta("mouse_inside", false)


func _button_up(node: Control) -> void:
	if node.get_meta("mouse_inside"):
		node.modulate = Color(0.8, 0.8, 0.8, 1.0)
	else:
		node.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _button_down(node: Control) -> void:
	node.modulate = Color(0.6, 0.6, 0.6, 1.0)
