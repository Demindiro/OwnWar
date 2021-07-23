extends Spatial
class_name OwnWar_Wheel


export var max_power := 300.0
export var max_angle := 0.0
export var max_brake := 8.0
export var max_rpm := 900.0
export var suspension_max_force := 1500.0

onready var wheel: VehicleWheel = get_child(0)

var movement_index = 0
var temporary_index = 0
var body_center_of_mass
var base_position


func _ready() -> void:
	call_deferred("_post_ready")


func _post_ready() -> void:
	remove_child(wheel)
	wheel.transform = transform * wheel.transform
	var e := connect("tree_exiting", wheel, "queue_free")
	assert(e == OK)
	get_parent().add_child(wheel)


func drive(forward: float, yaw: float, pitch: float, roll: float) -> void:
	var delta = base_position - body_center_of_mass
	forward *= (1.0 - clamp(abs(wheel.get_rpm()) / max_rpm, 0.0, 1.0))
	yaw *= 0.2 * (delta.z / abs(delta.x))
	wheel.brake = 1.0 if forward == 0.0 else 0.0
	wheel.engine_force = forward * max_power
	wheel.steering = yaw
