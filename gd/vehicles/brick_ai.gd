extends Node
class_name BrickAI

var min_distance := 10.0
var max_distance := 30.0

onready var vehicle: OwnWar_Vehicle = get_parent()
onready var controller = get_node("../Controller")


func _physics_process(_delta) -> void:
	controller.clear()
	var closest_vehicle: OwnWar_Vehicle = null
	var closest_distance_2 := INF
	for v in get_tree().get_nodes_in_group("vehicles"):
		if v == vehicle:
			continue
		var d2: float = v.translation.distance_squared_to(vehicle.translation)
		if d2 < closest_distance_2:
			closest_vehicle = v
			closest_distance_2 = d2
	var v := closest_vehicle
	if v != null:
		var rel_pos := v.translation - vehicle.translation
		var dir := rel_pos.normalized()
		var angle := acos(vehicle.transform.basis.z.dot(dir))
		var side := sign(vehicle.transform.basis.x.dot(dir))
		var desired_angle := PI / 2
		if closest_distance_2 < min_distance * min_distance:
			desired_angle = PI
		elif closest_distance_2 > max_distance * max_distance:
			desired_angle = 0.0
		var angle_diff := fposmod(desired_angle - angle, 2 * PI)
		if angle_diff > PI:
			angle_diff = -(PI * 2 - angle_diff)
		if angle_diff < -PI / 6:
			controller.turn_left = true
		elif angle_diff > PI / 6:
			controller.turn_right = true
		controller.move_forward = true
		controller.aim_at = v.translation
		controller.fire = true
