extends Spatial
class_name OwnWar_Wheel


export var max_power := 300.0
export var max_angle := 0.0
export var max_brake := 8.0
export var max_rpm := 900.0
export var suspension_max_force := 1500.0


var steering := 0.0 setget set_steering
var brake := 0.0 setget set_brake
var engine_force := 0.0 setget set_engine_force


onready var wheel: VehicleWheel = get_child(0)


func _ready() -> void:
	call_deferred("_post_ready")


func _post_ready() -> void:
	remove_child(wheel)
	wheel.transform = transform * wheel.transform
	var e := connect("tree_exiting", wheel, "queue_free")
	assert(e == OK)
	get_parent().add_child(wheel)


func set_steering(value: float) -> void:
	steering = value
	wheel.steering = value


func set_brake(value: float) -> void:
	brake = value
	wheel.brake = value


func set_engine_force(value: float) -> void:
	engine_force = value
	wheel.engine_force = value


func get_rpm() -> float:
	return wheel.get_rpm()
