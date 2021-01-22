extends PanelContainer


signal new_vehicle_path(from, to)


export var _gui_name := NodePath()
export var _gui_cost := NodePath()
export var _gui_blocks := NodePath()
export var _gui_mass := NodePath()
export var _gui_size := NodePath()


var _original_path := ""
onready var gui_name: LineEdit = get_node(_gui_name)
onready var gui_cost: Label = get_node(_gui_cost)
onready var gui_blocks: Label = get_node(_gui_blocks)
onready var gui_mass: Label = get_node(_gui_mass)
onready var gui_size: Label = get_node(_gui_size)


func set_vehicle(path: String, vehicle: OwnWar_VehiclePreview) -> void:
	# TODO this is almost certainly a bug in the engine
	if gui_name == null:
		call_deferred("set_vehicle", path, vehicle)
		return
	_original_path = path
	gui_name.text = OwnWar.get_vehicle_name(path)
	gui_cost.text = str(vehicle.cost)
	gui_blocks.text = str(vehicle.block_count)
	gui_mass.text = str(vehicle.mass)
	gui_size.text = str(vehicle.aabb.size)
	gui_size.text = gui_size.text.substr(1, len(gui_size.text) - 2)


func edit_name(_new_text := "") -> void:
	var new_path := OwnWar.get_vehicle_path(gui_name.text)
	if _original_path != new_path:
		emit_signal("new_vehicle_path", _original_path, new_path)
		_original_path = new_path
	gui_name.release_focus()


func on_vehicle_renamed(_from: String, to: String) -> void:
	_original_path = to
	gui_name.text = OwnWar.get_vehicle_name(to)
