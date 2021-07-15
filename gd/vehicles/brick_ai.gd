class_name BrickAI

var min_distance := 3.0
var max_distance := 30.0

var vehicle_id = -1


func step(vehicles, _delta: float) -> void:
	if vehicle_id == -1:
		return

	var vehicle = vehicles[vehicle_id]
	if vehicle == null:
		return

	vehicle.turn_left = false
	vehicle.turn_right = false
	vehicle.move_forward = false
	vehicle.flip = false
	var trf = vehicle.get_node().transform

	# Flip if necessary
	if trf.basis.y.dot(Vector3.DOWN) > 0.7:
		vehicle.flip = true

	# Find nearest enemy
	var closest_vehicle
	var closest_distance_2 := INF
	for i in len(vehicles):
		if i == vehicle_id:
			continue
		var v = vehicles[i]
		if v == null:
			continue
		var d2: float = v.get_node().translation.distance_squared_to(trf.origin)
		if d2 < closest_distance_2:
			closest_vehicle = v
			closest_distance_2 = d2
	var v = closest_vehicle

	# Drive towards & fire at the nearest enemy
	if v != null:
		var rel_pos = v.get_node().translation - trf.origin
		var dir = rel_pos.normalized()
		var angle = acos(trf.basis.z.dot(dir))
		var side = sign(trf.basis.x.dot(dir))
		angle *= side

		# Check if broadsiding would be useful
		var desired_angle := PI / 2
		if closest_distance_2 < min_distance * min_distance:
			desired_angle = PI
		elif closest_distance_2 > max_distance * max_distance:
			desired_angle = 0.0

		# Attempt to achieve the desired angle
		var angle_diff := fposmod(desired_angle - angle, 2 * PI)
		if angle_diff > PI:
			angle_diff = -(PI * 2 - angle_diff)

		if angle_diff < -PI / 5:
			vehicle.turn_left = true
		elif angle_diff > PI / 5:
			vehicle.turn_right = true

		# Apply movement
		vehicle.move_forward = true
		vehicle.aim_at = v.get_node().translation
		vehicle.fire = true
