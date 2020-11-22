extends Control


const WAYPOINT_MIN_RADIUS = 100
const WAYPOINT_MAX_RADIUS = 200


func _ready():
	call_deferred("_ready_deferred")


func _ready_deferred():
	randomize()
	for p in ["chassis_blocks", "power_manager", "engine", "movement_manager",
			"wheel"]:
		if not Plugin.is_plugin_enabled(p):
			print("Missing plugin %s" % p)
			return
	$"../Vehicle".load_from_file("user://vehicles/apc.json")
	call_deferred("_on_Timer_timeout")
	$"../Timer".start()
	$Main/Version.text = Util.version_vector_to_str(Constants.VERSION)


func _on_Timer_timeout():
	var angle = randf() * PI * 2
	var distance = rand_range(WAYPOINT_MIN_RADIUS, WAYPOINT_MAX_RADIUS)
	var mainframes = $"../Vehicle".get_blocks("mainframe")
	for mainframe in mainframes:
		mainframe[2].ai.waypoints = [Vector3(distance * cos(angle), 0, distance * sin(angle))]
		break


func _on_Campaign_pressed():
	$Campaign.visible = not $Campaign.visible
	$Plugins.visible = false
	$Saves.visible = false


func _on_RandomMap_pressed():
	pass # Replace with function body.


func _on_Designer_pressed():
	Global.goto_scene(Global.SCENE_DESIGNER)


func _on_Settings_pressed():
	pass # Replace with function body.


func _on_Exit_pressed():
	get_tree().quit()


func _on_Tutorial_pressed():
	Global.goto_scene("res://campaign/tutorial/hill.tscn")


func _on_Plugins_pressed():
	$Plugins.visible = not $Plugins.visible
	$Campaign.visible = false
	$Saves.visible = false


func _on_Saves_pressed():
	$Saves.visible = not $Saves.visible
	$Campaign.visible = false
	$Plugins.visible = false
