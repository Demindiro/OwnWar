extends ViewportContainer


export var camera_pan_speed := 0.2
export var camera_distance := 10.0
export var camera_tilt := PI / 6
export var camera_pan := 0.0
var _vehicle: OwnWar_Vehicle = null
onready var _viewport: Viewport = get_node("Viewport")
onready var _camera: Camera = get_node("Viewport/Camera")
onready var _origin: Spatial = get_node("Viewport/Origin")


func set_preview(path: String) -> void:
	if _vehicle != null:
		_vehicle.queue_free()
	_vehicle = OwnWar_Vehicle.new()
	var e := _vehicle.load_from_file(path)
	assert(e == OK)
	_vehicle.transform = _origin.transform
	_vehicle.translation.y += (_vehicle.get_aabb().size.y / 2) * OwnWar.Block.BLOCK_SCALE
	_vehicle.aim_at = _vehicle.translation + Vector3(0, 0, 10000000000)
	_viewport.add_child(_vehicle)


func _process(delta: float) -> void:
	camera_pan += delta * camera_pan_speed
	var basis := Basis().rotated(Vector3.UP, camera_pan) * \
		Basis().rotated(Vector3.RIGHT, -camera_tilt)
	_camera.transform = Transform(
		basis,
		_origin.translation + basis * Vector3(0, 0, camera_distance)
	)
