extends "turret_color.gd"

export var turret_offset := Vector3()

var server_node

onready var top = $Top


var prev_trf := Transform()
var curr_trf := Transform()
var prev_steer := 0.0
var curr_steer := 0.0
var trf_dirty := false


func _process(_delta):
	if server_node._body_b_mount == null:
		set_process(false)
		set_physics_process(false)
		return
	if trf_dirty:
		prev_trf = curr_trf
		curr_trf = server_node._body_b_mount.global_transform
		trf_dirty = false
	var frac := Engine.get_physics_interpolation_fraction()
	top.global_transform = prev_trf.interpolate_with(curr_trf, frac)
	top.rotate_y(PI / 2)
	top.translation += turret_offset
	top.scale *= Vector3(size, 1, size)


func _physics_process(_delta: float) -> void:
	trf_dirty = true
