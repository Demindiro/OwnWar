extends Control


const WAYPOINT_MIN_RADIUS = 100
const WAYPOINT_MAX_RADIUS = 200


func _ready():
	randomize()
	$"../Vehicle".load_from_file("user://vehicles/apc.json")
	call_deferred("_on_Timer_timeout")
	$Main/Version.text = str(Global.VERSION)


func _on_Timer_timeout():
	var angle = randf() * PI * 2
	var distance = rand_range(WAYPOINT_MIN_RADIUS, WAYPOINT_MAX_RADIUS)
	var mainframes = $"../Vehicle".get_blocks("mainframe")
	for mainframe in mainframes:
		mainframe[2].get_child(0).ai.waypoints = [Vector3(distance * cos(angle), 0, distance * sin(angle))]
		break


func _on_Campaign_pressed():
	$Campaign.visible = not $Campaign.visible


func _on_RandomMap_pressed():
	pass # Replace with function body.


func _on_Designer_pressed():
	Global.goto_scene(Global.SCENE_DESIGNER)


func _on_DesignerMap_pressed():
	Global.goto_scene(Global.SCENE_DESIGNER_MAP)


func _on_Settings_pressed():
	pass # Replace with function body.


func _on_Exit_pressed():
	get_tree().quit()


func _on_Tutorial_pressed():
	Global.goto_scene("res://campaign/tutorial/hill.tscn")
