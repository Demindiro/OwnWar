extends Node


const Worker := preload("res://plugins/worker_drone/drone.gd")
const BM := preload("res://plugins/basic_manufacturing/plugin.gd")


export var team := "EvilAI"
onready var game_master: OwnWar.GameMaster = OwnWar.GameMaster.get_game_master(self)
var _worker: Worker
var _spawned_vehicle: OwnWar.Vehicle
var _refinery: BM.Refinery
var _factory: BM.MunitionsFactory
var _platform: BM.SpawnPlatform
var _target: OwnWar.Unit
var _enemies_in_territory := []
onready var _idle_point: Spatial = $IdlePoint



func _ready():
	_platform = game_master.get_units(team, "spawn_platform")[0]
	var e := _platform.connect("spawned", self, "_vehicle_spawned")
	assert(e == OK)


func _physics_process(_delta):
	if _worker == null:
		var units := game_master.get_units(team, "worker")
		if len(units) > 0:
			_worker = units[0]
			var e := _worker.connect("task_completed", self, "_worker_task_completed")
			assert(e == OK)
			if _refinery != null:
				_worker.put_matter_in(1, [_refinery], false)
			if _factory != null:
				_worker.put_matter_in(1, [_factory], false)
			if _platform != null:
				_worker.put_matter_in(1, [_platform], false)
	if _worker != null:
		var floor_pos = _worker.translation
		floor_pos.y = 0
		if _refinery == null and \
			len(game_master.get_units(team, "refinery_ghost")) == 0:
			_worker.build_ghost(1, floor_pos + Vector3.FORWARD * 3, 0, "refinery")
		elif _factory == null and \
			len(game_master.get_units(team, "munitions_factory_ghost")) == 0:
			_worker.build_ghost(1, floor_pos + Vector3.BACK * 3, 0, "munitions_factory")
		elif _platform == null and \
			len(game_master.get_units(team, "spawn_platform_ghost")) == 0:
			_worker.build_ghost(1, floor_pos + Vector3.LEFT * 10, 0, "spawn_platform")
			_platform = game_master.get_units(team, "spawn_platform")[0]
		var dir: String = Util.get_script_dir(self)
		if _spawned_vehicle == null and _platform != null:
			if not _platform.is_busy():
				_platform.spawn_vehicle(0, dir.plus_file("vehicles/tank.json"))

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
	if body is OwnWar.Unit and body.team != team:
		_enemies_in_territory.append(body)
	elif body is OwnWar.VoxelBody and body.get_parent().team != team:
		_enemies_in_territory.append(body.get_parent())


func _on_Area_body_exited(body):
	_enemies_in_territory.erase(body)


func _worker_task_completed(task):
	if task is _worker.TaskBuild:
		if task.built_unit is BM.Refinery:
			_refinery = task.built_unit
			_worker.put_matter_in(1, [_refinery], false)
		elif task.built_unit is BM.MunitionsFactory:
			_factory = task.built_unit
			_worker.put_matter_in(1, [_factory], false)
		elif task.built_unit is BM.SpawnPlatform:
			_platform = task.built_unit
			_worker.put_matter_in(1, [_platform], false)
			var e := _platform.connect("spawned", self, "_vehicle_spawned")
			assert(e == OK)


func _vehicle_spawned(vehicle: OwnWar.Unit):
	_spawned_vehicle = vehicle
	_worker.put_matter_in(1, [vehicle], false)


func _on_Hill_save_game(data: Dictionary) -> void:
	var d := {}
	if _worker != null:
		d["worker"] = _worker.uid
	if _refinery != null:
		d["refinery"] = _refinery.uid
	if _factory != null:
		d["factory"] = _factory.uid
	if _platform != null:
		d["platform"] = _platform.uid
	if _target != null:
		d["target"] = _target.uid
	data["tutorial_hill:evilai"] = d


func _on_Hill_load_game(data: Dictionary) -> void:
	var d: Dictionary = data["tutorial_hill:evilai"]
	var worker_uid: int = d.get("worker", -1)
	if worker_uid != -1:
		_worker = game_master.get_unit_by_uid(worker_uid)
		var e := _worker.connect("task_completed", self, "_worker_task_completed")
		assert(e == OK)
	var refinery_uid: int = d.get("refinery", -1)
	if refinery_uid != -1:
		_refinery = game_master.get_unit_by_uid(refinery_uid)
	var factory_uid: int = d.get("factory", -1)
	if factory_uid != -1:
		_factory = game_master.get_unit_by_uid(factory_uid)
	var platform_uid: int = d.get("platform", -1)
	if platform_uid != -1:
		_platform = game_master.get_unit_by_uid(platform_uid)
		var e := _platform.connect("spawned", self, "_vehicle_spawned")
		assert(e == OK)
	var target_uid: int = d.get("target", -1)
	if target_uid != -1:
		_target = game_master.get_unit_by_uid(target_uid)


func _on_Hill_unit_added(unit: OwnWar.Unit) -> void:
	if unit == _worker:
		_worker = null
	elif unit == _refinery:
		_refinery = null
	elif unit == _factory:
		_factory = null
	elif unit == _platform:
		_platform = null
	elif unit == _target:
		_target = null
