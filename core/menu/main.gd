extends Control


const WAYPOINT_MIN_RADIUS = 100
const WAYPOINT_MAX_RADIUS = 200
onready var _timer: Timer = $"../Timer"
onready var _version: Label = $Main/Version
onready var _vehicle: Vehicle = $"../Vehicle"
onready var _button_campaign: Control = $Campaign
onready var _button_plugins: Control = $Plugins
onready var _button_saves: Control = $Saves
onready var _background := $"../Background"


func _ready():
	call_deferred("_ready_deferred")


func _ready_deferred():
	randomize()
	for p in ["chassis_blocks", "power_manager", "engine", "movement_manager",
			"wheel"]:
		if not Plugin.is_plugin_enabled(p):
			print("Missing plugin %s" % p)
			return
	call_deferred("_on_Timer_timeout")
	_timer.start()
	_version.text = Util.version_vector_to_str(OwnWar.VERSION)


func _on_Timer_timeout():
	var angle = randf() * PI * 2
	var distance = rand_range(WAYPOINT_MIN_RADIUS, WAYPOINT_MAX_RADIUS)
	var mainframes = _vehicle.get_blocks("mainframe")
	for mainframe in mainframes:
		mainframe.node.ai.waypoints = [Vector3(distance * cos(angle), 0, distance * sin(angle))]
		break


func _on_Campaign_pressed():
	_button_campaign.visible = not _button_campaign.visible
	_button_plugins.visible = false
	_button_saves.visible = false


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
	_button_plugins.visible = not _button_plugins.visible
	_button_campaign.visible = false
	_button_saves.visible = false


func _on_Saves_pressed():
	_button_saves.visible = not _button_saves.visible
	_button_campaign.visible = false
	_button_plugins.visible = false
