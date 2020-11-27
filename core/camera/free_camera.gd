extends Camera
class_name FreeCamera

export var speed := 10.0
export var angular_speed := 0.01
export var always_capture := false

var _rot_x := 0.0
var _rot_y := 0.0
var enabled := true setget set_enabled


func _ready():
	set_transform(transform)


func _input(event):
	if not enabled:
		return
	if event is InputEventMouseMotion:
		if always_capture or event.button_mask & BUTTON_MASK_RIGHT:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			_rot_x -= event.relative.x * angular_speed
			_rot_y -= event.relative.y * angular_speed
			transform.basis = Basis()
			rotate_object_local(Vector3(0, 1, 0), _rot_x)
			rotate_object_local(Vector3(1, 0, 0), _rot_y)
	elif event is InputEventMouseButton:
		if not always_capture and event.button_index == BUTTON_RIGHT:
			if event.is_pressed():
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(delta):
	var direction = Vector3()
	var actions = ["camera_left", "camera_right", "camera_forward", "camera_back", "camera_up", "camera_down"]
	var directions = [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, Vector3.UP, Vector3.DOWN]
	for i in range(len(actions)):
		if Input.is_action_pressed(actions[i]):
			direction += directions[i]
	translate_object_local(direction * speed * delta)


func set_transform(p_transform: Transform) -> void:
	transform = p_transform
	var euler = transform.basis.get_euler()
	_rot_x = euler.y
	_rot_y = euler.x


func set_enabled(var p_enabled):
	enabled = p_enabled
	set_process(enabled)
	if enabled:
		if always_capture:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
