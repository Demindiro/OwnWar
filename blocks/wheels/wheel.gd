class_name Wheel
extends Spatial

export(float) var friction = 0.1
export(float) var roll_friction = 0.1
export(float) var radius = 1
export(float) var driving_torque = 1000
export(float) var braking_torque = 1000
export(float) var suspension_max_force = 1000
export(float) var suspension_max_length = 1
export(float) var suspension_damping = 0.1

onready var _raycast: RayCast = RayCast.new()
onready var _parent: RigidBody = get_parent()


func _ready():
	_raycast.add_exception(_parent)


func _physics_process(delta):
	if _raycast.is_colliding():
		var collision_point = _raycast.get_collision_point()
		var wheel_point = to_global(Vector3.ZERO)
		var distance = (collision_point - wheel_point).length
		var suspension_length = suspension_max_length - distance
		assert(suspension_length > 0)
		var suspension_compression = 1 - suspension_length / suspension_max_length
		var suspension_force = suspension_compression * suspension_max_force
		_parent.add_force(translation, transform.basis.y)
