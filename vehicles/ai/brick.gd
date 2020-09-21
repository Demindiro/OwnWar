extends AI

# Minimal (usable) AI implementaion


func process():
	.process()
	var transform = vehicle.transform
	var position = transform.origin
	var forward = transform.basis.z
	var distance = waypoint - position
	var distance2d = Vector2(distance.x, distance.z)
	var forward2d = Vector2(forward.x, forward.z).normalized()
	# Correct azimuth
	var error = distance2d.dot(forward2d)
	if error < 1e-5:
		error = 0
	else:
		error = 1 - error / distance2d.length()
	var right2d = Vector2(transform.basis.x.x, transform.basis.x.z)
	vehicle.drive_yaw = -clamp(right2d.dot(distance2d) * 0.1, -1, 1) * 0.2
	# Correct distance
	vehicle.drive_forward = 1 if distance2d.length() > 20 else 0
	# Stop if nearby
	if abs(vehicle.drive_yaw) < 0.1 and vehicle.drive_forward < 0.1:
		vehicle.drive_yaw = 0.0
		vehicle.drive_forward = 0.0
		vehicle.brake = 1.0
	# Aim at some random point
	vehicle.weapons_aim_point = Vector3(5, 25, 5)
	
	
func debug_draw(debug):
	.debug_draw(debug)
	for axis in [[Vector3.UP, Vector3.RIGHT], [Vector3.FORWARD, Vector3.UP],
			[Vector3.RIGHT, Vector3.FORWARD]]:
		debug.begin(Mesh.PRIMITIVE_LINE_LOOP)
		debug.set_color(Color.red)
		for i in range(16):
			debug.add_vertex(axis[0].rotated(axis[1], PI / 8 * i) + vehicle.weapons_aim_point)
		debug.end()
	debug.begin(Mesh.PRIMITIVE_LINES)
	debug.set_color(Color.red)
	debug.add_vertex(vehicle.translation)
	debug.add_vertex(vehicle.weapons_aim_point)
	debug.end()
