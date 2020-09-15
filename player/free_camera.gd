extends Camera

export(float) var speed = 10
export(float) var angular_speed = 0.01

var _rot_x = 0
var _rot_y = 0


func _input(event):
	if event is InputEventMouseMotion and event.button_mask & 0b10:
		_rot_x -= event.relative.x * angular_speed
		_rot_y -= event.relative.y * angular_speed
		transform.basis = Basis()
		rotate_object_local(Vector3(0, 1, 0), _rot_x)
		rotate_object_local(Vector3(1, 0, 0), _rot_y)


func _process(delta):
	var direction = Vector3()
	var actions = ["ui_left", "ui_right", "ui_forward", "ui_back", "ui_up", "ui_down"]
	var directions = [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, Vector3.UP, Vector3.DOWN]
	for i in range(len(actions)):
		if Input.is_action_pressed(actions[i]):
			direction += directions[i]
	translate_object_local(direction * speed * delta)
