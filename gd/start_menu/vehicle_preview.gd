extends Control


signal loaded_vehicle(path, vehicle)


# TODO
const BLOCK_SCALE := 0.25
const GRID_SIZE := 37


export var camera_pan_speed := 0.2
export var camera_distance := 10.0
export var camera_tilt := PI / 6
export var camera_pan := 0.0
export(float, 0.1, 20.0) var camera_zoom_min := 5.0
export(float, 0.1, 20.0) var camera_zoom_max := 15.0
export(float, 0.0, 1.0) var camera_floor_offset := 0.3
var _vehicle: OwnWar_VehiclePreview = null
var _auto_pan := true
onready var _camera: Camera = get_node("Camera")
onready var _origin: Spatial = get_node("Origin")
onready var _input_timer: Timer = get_node("InputTimer")
onready var _camera_origin: Spatial = get_node("CameraOrigin")


func _ready() -> void:
	if OwnWar_Settings.selected_vehicle_path != "":
		set_preview(OwnWar_Settings.selected_vehicle_path, false)


func set_preview(path: String, save := true) -> void:
	if _vehicle != null:
		_vehicle.queue_free()
	_vehicle = OwnWar_VehiclePreview.new()
	var e := _vehicle.load_from_file(path)
	if e != OK:
		print("Failed to load vehicle at %s: %s" % [path, Global.ERROR_TO_STRING[e]])
		#assert(false, "Failed to load vehicle")
		return
	_vehicle.transform = _origin.transform
	_vehicle.translation.y += GRID_SIZE * BLOCK_SCALE / 2
	OwnWar_Lobby.player_vehicle_valid = _vehicle.is_valid
	OwnWar_Lobby.player_vehicle_invalid_reason = _vehicle.invalid_reason
	if save:
		OwnWar_Settings.dirty = true
	add_child(_vehicle)
	emit_signal("loaded_vehicle", path, _vehicle)


func _gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseMotion
	if mouse_event != null:
		if mouse_event.button_mask & BUTTON_MASK_LEFT:
			_auto_pan = false
			_input_timer.start()
			var rel := mouse_event.relative * OwnWar_Settings.mouse_move_sensitivity / 100
			camera_pan -= rel.x
			camera_tilt += rel.y
			camera_tilt = clamp(camera_tilt, -PI / 2, PI / 2)
			get_tree().set_input_as_handled()
	elif event.is_action_pressed("main_menu_zoom_in"):
		camera_distance = max(camera_distance - OwnWar_Settings.mouse_scroll_sensitivity, camera_zoom_min)
	elif event.is_action_pressed("main_menu_zoom_out"):
		camera_distance = min(camera_distance + OwnWar_Settings.mouse_scroll_sensitivity, camera_zoom_max)


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
