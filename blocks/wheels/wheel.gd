extends VehicleWheel


# warning-ignore:unused_class_variable
export var max_power := 300.0
# warning-ignore:unused_class_variable
export var max_angle := 0.0
export var max_brake := 8.0
onready var _prev_transform := transform
onready var _next_transform := transform
onready var _visual: Spatial = get_node("Visual")


func _ready() -> void:
	if OS.has_feature("Server"):
		set_process(false)
		set_physics_process(false)
		_visual.free()
	elif not OwnWar.is_in_designer(get_tree()):
		_visual.set_as_toplevel(true)


func _process(_delta: float) -> void:
	var frac := Engine.get_physics_interpolation_fraction()
	var trf := _prev_transform.interpolate_with(_next_transform, frac)
	_visual.transform = trf


func _physics_process(_delta: float) -> void:
	_prev_transform = _next_transform
	_next_transform = global_transform