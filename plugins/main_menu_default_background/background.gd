extends Node


const WAYPOINT_MIN_RADIUS = 100
const WAYPOINT_MAX_RADIUS = 200
onready var _timer_a: Timer = $TimerA
onready var _timer_b: Timer = $TimerB
onready var _vehicle_a: OwnWar.Vehicle = $VehicleA
onready var _vehicle_b: OwnWar.Vehicle = $VehicleB
onready var _camera: FollowCamera = $FollowCamera


func _ready():
	_on_Timer_timeout(0)
	_on_Timer_timeout(1)
	_vehicle_a.get_manager("mainframe")._mainframes[0].ai.targets = [_vehicle_b]
	_vehicle_b.get_manager("mainframe")._mainframes[0].ai.targets = [_vehicle_a]


func _on_Timer_timeout(which: int) -> void:
	var tim := _timer_a if which == 0 else _timer_b
	var veh := _vehicle_a if which == 0 else _vehicle_b
	var angle = randf() * PI * 2
	var distance = rand_range(WAYPOINT_MIN_RADIUS, WAYPOINT_MAX_RADIUS)
	var mainframes = veh.get_blocks("mainframe")
	for mainframe in mainframes:
		var waypoint := Vector3(distance * cos(angle), 0, distance * sin(angle))
		mainframe.node.ai.waypoints = [waypoint]
		break
	var _r := veh.put_matter(OwnWar.Matter.get_matter_id("fuel"), 100000)
	_r = veh.put_matter(OwnWar.Matter.get_matter_id("160mm AP"), 100000)
	tim.wait_time = randi() % 7


func _on_TimerCamera_timeout() -> void:
	if randf() < 0.25:
		if _camera.node_path == _vehicle_a.get_path():
			_camera.node_path = _vehicle_b.get_path()
		else:
			_camera.node_path = _vehicle_a.get_path()
