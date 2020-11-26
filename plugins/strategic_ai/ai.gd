extends Timer

const BM := preload("res://plugins/basic_manufacturing/plugin.gd")
const WorkerDrone := preload("res://plugins/worker_drone/drone.gd")
const Munition := preload("res://plugins/weapon_manager/munition.gd")

export var _vehicle_path := ""
const _ORE_MAX_DISTANCE_2 := 100.0 * 100.0

var _units := []
# matter = resources in literally every other game
var _matter_index := PoolIntArray()
var _matter_needs_index := PoolIntArray()
onready var _material_id := Matter.get_matter_id("material")


func _ready() -> void:
	_matter_index.resize(Matter.get_matter_types_count())
	_matter_needs_index.resize(Matter.get_matter_types_count())
	process_mode = Timer.TIMER_PROCESS_PHYSICS
	wait_time = 1.0
	autostart = true
	var e := connect("timeout", self, "_ai_process")
	assert(e == OK)


func _ai_process() -> void:
	_units = get_tree().get_nodes_in_group("units_" + name)
	for u in _units:
		assert(u is Unit)
	_index_matter()
	_index_matter_needs()
	for id in range(len(_matter_index)):
		var amount := _matter_needs_index[id] - _matter_index[id]
		if amount > 0:
			if id == _material_id:
				_build_mining_post()
			elif Munition.is_munition(id):
				_produce_munition(id, amount)
	_supply_munition()


func _index_matter() -> void:
	for i in range(len(_matter_index)):
		_matter_index[i] = 0
	for u in _units:
		for id in u.get_take_matter_list():
			_matter_index[id] += u.get_matter_count(id)


func _index_matter_needs() -> void:
	for i in range(len(_matter_needs_index)):
		_matter_needs_index[i] = 0
	for u in _units:
		for id in u.get_put_matter_list():
			_matter_needs_index[id] += u.needs_matter(id)


func _build_structure(position: Vector3, structure_name: String) -> void:
	var worker := _get_idle_worker(position)
	if worker != null:
		_debug("Building %s" % structure_name)
		if structure_name == "drill":
			worker.build_drill(0, position)
		else:
			worker.build_ghost(0, position, 0, structure_name)
	else:
		_debug("No idle workers found to build %s" % structure_name)


func _build_mining_post() -> void:
	if _matter_index[_material_id] >= 10:
		var ore := _get_closest_ore()
		if ore != null:
			_build_structure(ore.global_transform.origin, "drill")
		else:
			_debug("No nearby ores found")
	else:
		_debug("Not enough material to build a drill")


func _build_munitions_factory() -> void:
	# Build it near a storage pod with a lot of material and a roboport
	var pod := _find_best_storage_pod(_material_id)
	if pod != null:
		var pod_org := pod.global_transform.origin
		var roboport: BM.Roboport = _find_closest_unit(pod_org, BM.Roboport)
		if roboport != null:
			var roboport_org := roboport.global_transform.origin
#			var roboport_pod_dist2 := roboport_org.distance_to_squared(pod_org)
#			if roboport_pod_dist2 > roboport._radius2:
#				var fraction := sqrt(roboport_pod_dist2
			var build_coord := pod_org + (roboport_org - pod_org) / 2
			_build_structure(build_coord, "Munition Factory")
		else:
			_debug("No roboport found")
	else:
		_debug("No storage pod found")


func _find_best_storage_pod(matter_id: int) -> BM.StoragePod:
	var best: BM.StoragePod = null
	var amount := 0
	for u in _units:
		if u is BM.StoragePod:
			var a: int = u.get_matter_count(matter_id)
			if a > amount:
				best = u
				amount = a
	return best


func _find_closest_unit(position: Vector3, unit_type: GDScript = Unit) -> Unit:
	var closest_unit: Unit = null
	var distance2 := INF
	for u in _units:
		if u is unit_type:
			var org: Vector3 = u.global_transform.origin
			var d2 := org.distance_squared_to(position)
			if d2 < distance2:
				closest_unit = u
				distance2 = d2
	return closest_unit


# Get any worker without any tasks
func _get_idle_worker(closest_to: Vector3) -> WorkerDrone:
	var closest: WorkerDrone = null
	var closest_distance2 := INF
	for u in _units:
		if u is WorkerDrone and len(u.tasks) == 0:
			var pos: Vector3 = u.global_transform.origin
			var d2 := pos.distance_squared_to(closest_to)
			if d2 < closest_distance2:
				closest = u
				closest_distance2 = d2
	return closest


# Get any ore that is the closest to any of our structures and doesn't have a
# drill yet.
func _get_closest_ore() -> BM.Ore:
	var closest_ore: BM.Ore = null
	var closest_distance2 := _ORE_MAX_DISTANCE_2
	for ore in get_tree().get_nodes_in_group("ores"):
		assert(ore is BM.Ore)
		if ore.drill == null:
			var ore_pos = ore.global_transform.origin
			for u in _units:
				var u_pos: Vector3 = u.global_transform.origin
				var dist2 := u_pos.distance_squared_to(ore_pos)
				if dist2 < closest_distance2:
					closest_ore = ore
					closest_distance2 = dist2
	return closest_ore


# Produce munition of the given ID
func _produce_munition(id: int, amount: int) -> void:
	assert(amount > 0)
	var count := 0
	var m := Munition.get_munition(id)
	for u in _units:
		if u is BM.MunitionsFactory:
			var cm: Munition = u.get_current_munition_type()
			if cm == null:
				u.set_munition_type(0, m)
				count += 1
			elif cm == m:
				count += 1
			if count >= amount:
				break
	if count == 0:
		_build_munitions_factory()


func _supply_munition() -> void:
	var id := Matter.get_matter_id("160mm AP")
	if _matter_index[id] > 0:
		# Get any vehicle that needs munition
		var vehicle: Vehicle = null
		var amount := 0
		for u in _units:
			if u is Vehicle:
				var a: int = u.needs_matter(id)
				if a > amount:
					vehicle = u
					amount = a
		if amount > 0:
			var worker := _get_idle_worker(vehicle.global_transform.origin)
			if worker != null:
				var task := WorkerDrone.TaskPut.new(vehicle, id, true)
				worker.add_task(task, true)
	else:
		_debug("No %s available" % Matter.get_matter_name(id))


func _debug(message: String) -> void:
	if OS.is_debug_build():
		_log("DEBUG", message)


func _log(type: String, message: String) -> void:
	var f := Engine.get_physics_frames()
	print("[%8d] [AI:%s:%s] %s" % [f, type, name, message])
