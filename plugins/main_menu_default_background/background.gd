extends Node


const WAYPOINT_MIN_RADIUS = 100
const WAYPOINT_MAX_RADIUS = 200
onready var _timer: Timer = $"Timer"
onready var _vehicle: OwnWar.Vehicle = $"Vehicle"


func _ready():
	_on_Timer_timeout()


func _on_Timer_timeout():
	var angle = randf() * PI * 2
	var distance = rand_range(WAYPOINT_MIN_RADIUS, WAYPOINT_MAX_RADIUS)
	var mainframes = _vehicle.get_blocks("mainframe")
	for mainframe in mainframes:
		var waypoint := Vector3(distance * cos(angle), 0, distance * sin(angle))
		mainframe.node.ai.waypoints = [waypoint]
		break
