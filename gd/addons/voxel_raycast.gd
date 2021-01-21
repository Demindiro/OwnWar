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

extends Reference
# Voxel Raycasting Algorithm based on "A Fast Voxel Traversal Algorithm for Ray
# Tracing"


var x: int setget _prevent_set
var y: int setget _prevent_set
var z: int setget _prevent_set
var voxel: Array setget _prevent_set, _get_voxel
var finished: bool = true setget _prevent_set

var _limit_x: int
var _limit_y: int
var _limit_z: int
var _step_x: int
var _step_y: int
var _step_z: int
var _t_max: Vector3
var _t_delta: Vector3
var _last_step: int


func start(start: Vector3, direction: Vector3, limit_x: int, limit_y: int, limit_z: int) -> void:
	assert(limit_x > 0)
	assert(limit_y > 0)
	assert(limit_z > 0)
	var aabb = AABB(Vector3.ZERO, Vector3(limit_x, limit_y, limit_z))
	var in_aabb = aabb.has_point(start)
	if not in_aabb:
		var t_a = (aabb.position - start) / direction
		var t_b = (aabb.end - start) / direction
		var t_min = max(max(min(t_a.x, t_b.x), min(t_a.y, t_b.y)), min(t_a.z, t_b.z))
		var t_max = min(min(max(t_a.x, t_b.x), max(t_a.y, t_b.y)), max(t_a.z, t_b.z))
		if t_min > t_max or t_min < 0:
			finished = true
			_last_step = 0
			return
		start += direction * t_min
		match t_min:
			t_a.x, t_b.x: _last_step = 1
			t_a.y, t_b.y: _last_step = 2
			t_a.z, t_b.z: _last_step = 3
			_: assert(false)

	x = int(floor(start.x))
	y = int(floor(start.y))
	z = int(floor(start.z))

	var step = direction.sign()
	_step_x = int(step.x)
	_step_y = int(step.y)
	_step_z = int(step.z)

	_limit_x = limit_x if _step_x > 0 else -1
	_limit_y = limit_y if _step_y > 0 else -1
	_limit_z = limit_z if _step_z > 0 else -1

	var planes = Vector3(
			1 if _step_x > 0 else 0,
			1 if _step_y > 0 else 0,
			1 if _step_z > 0 else 0)
	var impact_rel_pos = start - Vector3(x, y, z)
	_t_max = (planes - impact_rel_pos) / direction
	_t_delta = step / direction

	if in_aabb:
		if _t_max.x > _t_max.y:
			if _t_max.x > _t_max.z:
				_last_step = 1
			else:
				_last_step = 3
		else:
			if _t_max.y > _t_max.z:
				_last_step = 2
			else:
				_last_step = 3

	finished = false


func step() -> void:
	assert(not finished)
	if _t_max.x < _t_max.y:
		if _t_max.x < _t_max.z:
			x += _step_x
			if x == _limit_x:
				finished = true
			_t_max.x += _t_delta.x
			_last_step = 1
		else:
			z += _step_z
			if z == _limit_z:
				finished = true
			_t_max.z += _t_delta.z
			_last_step = 3
	else:
		if _t_max.y < _t_max.z:
			y += _step_y
			if y == _limit_y:
				finished = true
			_t_max.y += _t_delta.y
			_last_step = 2
		else:
			z += _step_z
			if z == _limit_z:
				finished = true
			_t_max.z += _t_delta.z
			_last_step = 3


func get_normal() -> Array:
	match _last_step:
		1:
			return [-_step_x, 0, 0]
		2:
			return [0, -_step_y, 0]
		3:
			return [0, 0, -_step_z]
		_:
			assert(false)
			return [0, 0, 0]


func _prevent_set(_x):
	push_error("Attempt to set read-only variable")
	assert(false)


func _get_voxel() -> Array:
	return [x, y, z]
