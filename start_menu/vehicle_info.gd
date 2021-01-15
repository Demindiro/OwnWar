extends PanelContainer


signal new_vehicle_name(from, to)


export var _gui_name := NodePath()
export var _gui_cost := NodePath()
export var _gui_blocks := NodePath()
export var _gui_mass := NodePath()
export var _gui_size := NodePath()


var _original_name := ""
onready var gui_name: LineEdit = get_node(_gui_name)
onready var gui_cost: Label = get_node(_gui_cost)
onready var gui_blocks: Label = get_node(_gui_blocks)
onready var gui_mass: Label = get_node(_gui_mass)
onready var gui_size: Label = get_node(_gui_size)


func set_vehicle(vehicle: OwnWar_Vehicle) -> void:
	set_vehicle_name(Util.humanize_file_name(vehicle.get_file_path().get_file()))
	gui_cost.text = str(vehicle.get_cost())
	gui_blocks.text = str(vehicle.get_block_count())
	gui_mass.text = str(vehicle.get_mass())
	gui_size.text = str(vehicle.get_aabb().size)
	gui_size.text = gui_size.text.substr(1, len(gui_size.text) - 2)


func set_vehicle_name(p_name: String) -> void:
	gui_name.text = p_name
	_original_name = p_name


func edit_name(_zzzzzzidontneedthisvarargswhenpls = null) -> void:
	if _original_name != gui_name.text:
		emit_signal("new_vehicle_name", _original_name, gui_name.text)
		_original_name = gui_name.text
	gui_name.release_focus()
