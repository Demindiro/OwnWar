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
