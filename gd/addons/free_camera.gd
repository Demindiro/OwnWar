# Copyright (c) 2020 David Hoppenbrouwers
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


extends Camera
class_name FreeCamera

export var speed := 10.0
export var angular_speed := 1.0
export var always_capture := false
export var actions := PoolStringArray([
	"camera_left",
	"camera_right",
	"camera_forward",
	"camera_back",
	"camera_up",
	"camera_down"
])
export var limit_tilt := true

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
			_rot_x -= event.relative.x * angular_speed / 100
			_rot_y -= event.relative.y * angular_speed / 100
			if limit_tilt:
				_rot_y = clamp(_rot_y, -PI / 2, PI / 2)
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
	if !Engine.editor_hint:
		var direction = Vector3()
		var directions = [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, Vector3.UP, Vector3.DOWN]
		for i in len(actions):
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


func set_angular_speed(value: float) -> void:
	angular_speed = value
