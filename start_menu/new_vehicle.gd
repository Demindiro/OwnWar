extends PanelContainer


onready var _name_gui: LineEdit = get_node("Box/Name")
onready var _button_gui: BaseButton = get_node("Box/Create")
onready var _box_gui: Control = get_node("Box")


signal create_vehicle(path)


func _ready() -> void:
	_button_gui.disabled = _name_gui.text == ""


func goto_editor(_signals_pls_i_no_want_text_sadface = null) -> void:
	if _name_gui.text != "":
		emit_signal("create_vehicle", OwnWar.get_vehicle_path(_name_gui.text))


func activate() -> void:
	visible = true
	_name_gui.grab_focus()


func name_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		visible = false


func focus_lost() -> void:
	call_deferred("_focus_lost")


func _focus_lost() -> void:
	for child in _box_gui.get_children():
		if child.has_focus():
			return
	visible = false


func on_name_changed(text: String) -> void:
	_button_gui.disabled = text == ""
