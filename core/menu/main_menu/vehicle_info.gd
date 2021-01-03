extends PanelContainer


signal new_vehicle_name(from, to)


var _original_name := ""
# Box Box Box Box Box Box CEPTION
onready var _gui_name: LineEdit = get_node("Box/Box/Name")
onready var _gui_cost: Label = get_node("Box/Box/Box/CostValue")
onready var _gui_blocks: Label = get_node("Box/Box/Box/BlocksValue")
onready var _gui_mass: Label = get_node("Box/Box/Box/MassValue")
onready var _gui_size: Label = get_node("Box/Box/Box/SizeValue")


func set_vehicle(vehicle: OwnWar_Vehicle) -> void:
	set_vehicle_name(Util.humanize_file_name(vehicle.get_file_path().get_file()))
	_gui_cost.text = str(vehicle.get_cost())
	_gui_blocks.text = str(vehicle.get_block_count())
	_gui_mass.text = str(vehicle.get_mass())
	_gui_size.text = str(vehicle.get_aabb().size)
	_gui_size.text = _gui_size.text.substr(1, len(_gui_size.text) - 2)


func set_vehicle_name(p_name: String) -> void:
	_gui_name.text = p_name
	_original_name = p_name


func edit_name(zzzzzzidontneedthisvarargswhenpls = null) -> void:
	if _original_name != _gui_name.text:
		emit_signal("new_vehicle_name", _original_name, _gui_name.text)
		_original_name = _gui_name.text
	_gui_name.release_focus()
