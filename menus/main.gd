extends Node


const WAYPOINT_MIN_RADIUS = 100
const WAYPOINT_MAX_RADIUS = 200


func _ready():
	randomize()
	$Vehicle.load_from_file("user://vehicles/apc.json")
	call_deferred("_on_Timer_timeout")


func _on_Timer_timeout():
	var angle = randf() * PI * 2
	var distance = rand_range(WAYPOINT_MIN_RADIUS, WAYPOINT_MAX_RADIUS)
	$Vehicle.ai.waypoint = Vector3(distance * cos(angle), 0, distance * sin(angle))


func _on_Campaign_pressed():
	pass # Replace with function body.


func _on_RandomMap_pressed():
	pass # Replace with function body.


func _on_Designer_pressed():
	Global.goto_scene("res://designer/designer.tscn")


func _on_DesignerMap_pressed():
	Global.goto_scene("res://maps/designer.tscn")


func _on_Settings_pressed():
	pass # Replace with function body.


func _on_Exit_pressed():
	get_tree().quit()
