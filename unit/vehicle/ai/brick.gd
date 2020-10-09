extends AI

# Minimal (usable) AI implementaion
var random_block_coordinate = [-1, -1, -1]
var time_until_block_switch = 0


func process(mainframe, delta):
	.process(mainframe, delta)
	if len(waypoints) > 0:
		move_to_waypoint(mainframe.vehicle, waypoints[0])
		if (mainframe.vehicle.translation - waypoints[0]).length_squared() < 40:
			waypoints.remove(0)
	else:
		mainframe.vehicle.brake = 1
	# Fire at target
	mainframe.aim_weapons = false
	while len(targets) > 0:
		if targets[0] == null:
			targets.remove(0)
		else:
			fire_at(mainframe, targets[0], delta)
			break


func move_to_waypoint(vehicle, waypoint):
	var linear_velocity = vehicle.get_linear_velocity()
	var transform = vehicle.transform
	var position = transform.origin
	var forward = transform.basis.z
	var distance = waypoint - position
	var distance2d = Vector2(distance.x, distance.z)
	var forward2d = Vector2(forward.x, forward.z).normalized()
	var velocity = linear_velocity.dot(forward)
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
		vehicle.drive_forward *= 1.0 if forward2d.dot(distance2d.normalized()) > 0.5 else 0.5
		# Slow down if trying to turn
		if forward2d.dot(distance2d.normalized()) > 1:
			vehicle.brake = 0.5
			vehicle.drive_forward = 0
	# Slow down if nearby the current waypoint
	if velocity > 5 and distance2d.length() < 60:
		if linear_velocity.dot(forward) > 10:
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


func fire_at(mainframe, target, delta):
	if target is Vehicle:
		# Check if the currently targeted block is present
		var block_present = false
		if time_until_block_switch < 3:
			for body in target.voxel_bodies:
				if random_block_coordinate in body.blocks:
					block_present = true
					break
		if not block_present or time_until_block_switch >= 3:
			# Only select from bodies with blocks
			var valid_bodies = []
			for body in target.voxel_bodies:
				if len(body.blocks) > 0:
					valid_bodies.append(body)
			# Pick a random (alive) block so we don't shoot at air constantly
			var body = valid_bodies[randi() % len(valid_bodies)]
			var keys = body.blocks.keys()
			random_block_coordinate = keys[randi() % len(keys)]
			time_until_block_switch = 0
			var local_position = body.coordinate_to_vector(random_block_coordinate)
			mainframe.weapons_aim_point = body.to_global(local_position +
					Vector3.ONE * Global.BLOCK_SCALE / 2)
		time_until_block_switch += delta
	else:
		mainframe.weapons_aim_point = target.translation
	mainframe.aim_weapons = true
	mainframe.fire_weapons()


func debug_draw(mainframe, debug):
	.debug_draw(mainframe, debug)
	if len(targets) > 0:
		debug.draw_point(mainframe.weapons_aim_point, Color.red, Global.BLOCK_SCALE)
		debug.begin(Mesh.PRIMITIVE_LINES)
		debug.set_color(Color.red)
		debug.add_vertex(mainframe.vehicle.translation)
		debug.add_vertex(mainframe.weapons_aim_point)
		debug.end()
