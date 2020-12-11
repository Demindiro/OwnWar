extends Node


export var team := "EvilAI"
onready var game_master = GameMaster.get_game_master(self)
var _worker
var _spawned_vehicle
var _target
var _enemies_in_territory = []
onready var _idle_point: Spatial = $IdlePoint



func _ready():
	call_deferred("_assign_tasks")


func _physics_process(_delta):
	if _spawned_vehicle != null:
		var mainframes = _spawned_vehicle.get_blocks("mainframe")
		if len(mainframes) > 0:
			if _target == null and len(_enemies_in_territory) > 0:
				_target = _enemies_in_territory[0]
			if _target != null:
				var direction = (_target.translation - _spawned_vehicle.translation).normalized()
				mainframes[0].node.ai.targets = [_target]
				mainframes[0].node.ai.waypoints = [_target.translation - direction * 100.0]
			else:
				mainframes[0].node.ai.waypoints = [_idle_point.translation]


func _on_Area_body_entered(body):
	if body is Unit and body.team != team:
		_enemies_in_territory.append(body)
	elif body is VoxelBody and body.get_parent().team != team:
		_enemies_in_territory.append(body.get_parent())


func _on_Area_body_exited(body):
	_enemies_in_territory.erase(body)


func _assign_tasks():
	_worker = game_master.get_units(team, "worker")[0]
	var floor_pos = _worker.translation
	floor_pos.y = 0
	_worker.connect("task_completed", self, "_worker_task_completed")
	_worker.build_ghost(1, floor_pos + Vector3.FORWARD * 3, 0, "Refinery")
	_worker.build_ghost(1, floor_pos + Vector3.BACK * 3, 0, "Munition Factory")
	var platform = game_master.get_units(team, "spawn_platform")[0]
	_worker.put_matter_in(1, [platform], false)
	platform.connect("spawned", self, "_vehicle_spawned")
	var dir: String = Util.get_script_dir(self) 
	_spawned_vehicle = platform.spawn_vehicle(0, dir.plus_file("vehicles/tank.json"))


func _worker_task_completed(task, target):
	if task == _worker.Task.BUILD_STRUCTURE:
		if target.unit_name == "refinery":
			yield(get_tree(), "idle_frame")
			_worker.put_matter_in(1, [target], false)
		elif target.unit_name == "munitions_factory":
			yield(get_tree(), "idle_frame")
			_worker.put_matter_in(1, [target], false)


func _vehicle_spawned(p_vehicle):
	_worker.put_matter_in(1, [p_vehicle], false)
