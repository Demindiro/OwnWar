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
	var velocity = vehicle.linear_velocity.dot(forward)
	# Correct azimuth
	var error = distance2d.dot(forward2d)
	if error < 1e-5:
		error = 0
	else:
		error = 1 - error / distance2d.length()
	var right2d = Vector2(transform.basis.x.x, transform.basis.x.z).normalized()
	vehicle.drive_yaw = -clamp(right2d.dot(distance2d) * 0.1, -1, 1) * 0.3
	# Prevent turning too hard when going fast
	vehicle.drive_yaw /= clamp(abs(velocity) * 0.15, 1, 1000)
	# Correct distance
	vehicle.drive_forward = 1 if distance2d.length() > 10 else 0
	if velocity > 20:
		# Just prevent going too damn fast for now, driving is hard
		vehicle.drive_forward = 0
	elif velocity > 10:
		# Prevent going too fast when trying to make a sharp turn
		vehicle.drive_forward *= 1 if forward2d.dot(distance2d.normalized()) > 0.5 else 0.5
		# Slow down if trying to turn
		if forward2d.dot(distance2d.normalized()) > 1:
			vehicle.brake = 0.5
			vehicle.drive_forward = 0
	# Slow down if nearby the current waypoint
	if velocity > 5 and distance2d.length() < 60:
		if vehicle.linear_velocity.dot(forward) > 10:
			vehicle.brake = 0.5
			vehicle.drive_forward = 0
		else:
			vehicle.brake = 0
			vehicle.drive_forward *= 0.5
	else:
		vehicle.brake = 0
	# Stop and brake if the drive is low
	if vehicle.drive_forward < 0.01:
		vehicle.drive_yaw = 0.0
		vehicle.drive_forward = 0.0
		vehicle.brake = 1.0
		# Don't slam the brakes if going too fast
		if velocity > 10:
			vehicle.brake = 0.4
	# Fire at target
	if target != null:
		vehicle.aim_weapons = true
		vehicle.weapons_aim_point = target.translation
		vehicle.fire_weapons()
	else:
		vehicle.aim_weapons = false
	
	
func debug_draw(debug):
	.debug_draw(debug)
	if target != null:
		debug.draw_point(vehicle.weapons_aim_point, Color.red, 1)
		debug.begin(Mesh.PRIMITIVE_LINES)
		debug.set_color(Color.red)
		debug.add_vertex(vehicle.translation)
		debug.add_vertex(vehicle.weapons_aim_point)
		debug.end()
