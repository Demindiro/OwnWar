extends "res://block/chassis/variant/complex/cube_b.gd"



func step():
	.step()
	while not _is_valid():
		.step()
		if finished:
			return


func _is_valid():
	var x = result[0]
	var y = result[1]
	var z = result[2]
	var u = result[3]
	var v = result[4]
	var w = result[5]
	var a = result[6]
	# Dedup
	if x.x < y.y or y.y < z.z:
		return false
	# No pointiness
	if (y.y < u.y or z.z < u.z) or (x.x < v.x or z.z < v.z) or (x.x < w.x or y.y < w.y):
		return false
	var a_x = min(v.x, w.x)
	var a_y = min(u.y, w.y)
	var a_z = min(u.z, v.z)
	if a_x < a.x or a_y < a.y or a_z < a.z:
		return false
	# No mirror
	if u.y < u.z or v.x < v.z or w.y < w.z:
		return false
	if a.x < a.y or a.y < a.z:
		return false
	return true
