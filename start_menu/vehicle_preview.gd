extends Control


signal loaded_vehicle(path, vehicle)


export var camera_pan_speed := 0.2
export var camera_distance := 10.0
export var camera_tilt := PI / 6
export var camera_pan := 0.0
export(float, 0.01, 10.0) var camera_input_speed := 1.0
export(float, 0.01, 10.0) var camera_input_zoom_speed := 1.0
export(float, 0.1, 20.0) var camera_zoom_min := 5.0
export(float, 0.1, 20.0) var camera_zoom_max := 15.0
export(float, 0.0, 1.0) var camera_floor_offset := 0.3
var _vehicle: OwnWar_VehiclePreview = null
var _auto_pan := true
onready var _camera: Camera = get_node("Camera")
onready var _origin: Spatial = get_node("Origin")
onready var _input_timer: Timer = get_node("InputTimer")
onready var _camera_origin: Spatial = get_node("CameraOrigin")


func set_preview(path: String) -> void:
	if _vehicle != null:
		_vehicle.queue_free()
	_vehicle = OwnWar_VehiclePreview.new()
	var e := _vehicle.load_from_file(path)
	assert(e == OK)
	_vehicle.transform = _origin.transform
	_vehicle.translation.y += 25 * OwnWar_Block.BLOCK_SCALE / 2
	OwnWar_Lobby.player_vehicle_valid = _vehicle.is_valid()
	add_child(_vehicle)
	emit_signal("loaded_vehicle", path, _vehicle)


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseMotion
	if mouse_event != null:
		if mouse_event.button_mask & BUTTON_MASK_LEFT:
			_auto_pan = false
			_input_timer.start()
			camera_pan -= mouse_event.relative.x * camera_input_speed / 200
			camera_tilt += mouse_event.relative.y * camera_input_speed / 200
			camera_tilt = clamp(camera_tilt, -PI / 2, PI / 2)
			get_tree().set_input_as_handled()
	elif event.is_action_pressed("main_menu_zoom_in"):
		camera_distance = max(camera_distance - camera_input_zoom_speed, camera_zoom_min)
	elif event.is_action_pressed("main_menu_zoom_out"):
		camera_distance = min(camera_distance + camera_input_zoom_speed, camera_zoom_max)


func _process(delta: float) -> void:
	if _auto_pan:
		camera_pan += delta * camera_pan_speed
	var basis := Basis().rotated(Vector3.UP, camera_pan) * \
		Basis().rotated(Vector3.RIGHT, -camera_tilt)
	_camera.transform = Transform(
		basis,
		_camera_origin.translation + basis * Vector3(0, 0, camera_distance)
	)
	_camera.translation.y = max(_camera.translation.y, camera_floor_offset)


func input_timeout() -> void:
	_auto_pan = true
