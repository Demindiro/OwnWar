extends Unit


export var drone_scene: PackedScene
export var drone_limit := 10
var _drones := []
var _radius2 := 100.0 * 100.0
var _immediate_geometry: ImmediateGeometry
var _units := []
var _needs_material := {}
var _provides_material := []
var _takes_material := []
var _dumps_material := {}
onready var _spawn_timer := get_tree().create_timer(1.0, false)


func _ready():
	_set_radius2(_radius2)
	game_master.connect("unit_added", self, "_unit_added")


func _process(_delta):
	var debug := get_tree().current_scene.find_node("Debug")
	if debug != null:
		draw_debug(debug)


func _physics_process(_delta: float) -> void:
	if len(_provides_material) > 0:
		for unit in _needs_material:
			var amount: int = unit.request_info("need_material")
			var drone: Unit = _needs_material[unit]
			var provider := _get_nearest(unit, _provides_material)
			if amount > 0:
				if drone == null:
					drone = _get_idle_drone(PoolVector3Array([provider, unit]))
					if drone == null:
						break
					drone.task = 1
					drone.task_data = [provider, unit]
					drone.connect("task_completed", self, "_task_completed", [unit, drone])
					_needs_material[unit] = drone
	if len(_takes_material) > 0:
		for unit in _dumps_material:
			var amount := unit.request_info("dump_material") as int
			var drone := _dumps_material[unit] as Unit
			var taker := _get_nearest(unit, _takes_material)
			if amount > 0:
				if drone == null:
					drone = _get_idle_drone(PoolVector3Array([taker, unit]))
					if drone == null:
						break
					drone.task = 2
					drone.task_data = [unit, taker]
					drone.connect("task_completed", self, "_task_completed", [unit, drone])
					_dumps_material[unit] = drone


func get_actions() -> Array:
	var actions := .get_actions()
	actions += [
			["Set Coverage", Action.INPUT_COORDINATE, "set_coverage_radius", []]
		]
	return actions

func get_info() -> Dictionary:
	var info = .get_info()
	info["Drones"] = "%d / %d" % [len(_drones), drone_limit]
	info["Requesters"] = str(len(_needs_material))
	info["Providers"] = str(len(_provides_material))
	info["Takers"] = str(len(_takes_material))
	info["Dumpers"] = str(len(_dumps_material))
	return info


func show_feedback():
	if _immediate_geometry == null:
		_immediate_geometry = ImmediateGeometry.new()
		_immediate_geometry.material_override = SpatialMaterial.new()
		_immediate_geometry.material_override.albedo_color = Color.orange
		_immediate_geometry.material_override.flags_unshaded = true
		add_child(_immediate_geometry)
	_draw_circle(sqrt(_radius2))


func hide_feedback():
	if _immediate_geometry != null:
		_immediate_geometry.queue_free()
		_immediate_geometry = null


func show_action_feedback(function: String, viewport: Viewport, arguments: Array) -> void:
	match function:
		"set_coverage_radius":
			var position := arguments[1] as Vector3
			var projected_position := Plane(transform.basis.y, 0).project(position)
			_draw_circle(translation.distance_to(projected_position))
		_:
			.show_action_feedback(function, viewport, arguments)


func set_coverage_radius(_flags: int, position: Vector3) -> void:
	_set_radius2(translation.distance_squared_to(position))


func _draw_circle(radius: float) -> void:
	var space_state := get_world().direct_space_state
	_immediate_geometry.clear()
	_immediate_geometry.begin(Mesh.PRIMITIVE_LINE_LOOP)
	for i in range(128):
		var r := i * 2.0 * PI / 128
		var v := to_global(Vector3(cos(r) * radius, 0.0, sin(r) * radius))
		# NOTE: raycast tests against large bodies are very inaccurate because
		# reasons (https://pybullet.org/Bullet/phpBB3/viewtopic.php?t=3524)
		var result := space_state.intersect_ray(v + Vector3.UP * 1000,
				v + Vector3.DOWN * 1000, [], Global.COLLISION_MASK_TERRAIN)
		if len(result) > 0:
			v = result.position + Vector3.UP * 0.025
		_immediate_geometry.add_vertex(to_local(v))
	_immediate_geometry.end()


func _set_radius2(radius2: float) -> void:
	_radius2 = radius2
	for unit in _units:
		unit.disconnect("message", self, "_get_message")
		unit.disconnect("destroyed", self, "_unit_destroyed")
	_needs_material = {}
	_provides_material = []
	_takes_material = []
	_needs_material = {}
	_units = []
	for unit in game_master.get_units(team):
		if translation.distance_squared_to(unit.translation) < radius2:
			_add_unit(unit)


func _get_message(message, data, unit):
	match message:
		"need_material":
			var amount = data as int
			if not unit in _needs_material:
				_needs_material[unit] = null
		"provide_material":
			var amount = data as int
			if amount == 0:
				_provides_material.erase(unit)
			else:
				if not unit in _provides_material:
					_provides_material.append(unit)
		"take_material":
			var amount = data as int
			if amount == 0:
				_takes_material.erase(unit)
			else:
				if not unit in _takes_material:
					_takes_material.append(unit)
		"dump_material":
			var amount = data as int
			if not unit in _dumps_material:
				_dumps_material[unit] = null


func _unit_destroyed(unit):
	_units.erase(unit)


func _get_idle_drone(near_points := PoolVector3Array()) -> Unit:
	var shortest_distance := INF
	var candidate: Unit = null
	for drone in _drones:
		if drone.task == drone.Task.NONE:
			var nearest_distance := INF
			for point in near_points:
				var distance: float = drone.translation.distance_squared_to(point)
				if distance < nearest_distance:
					nearest_distance = distance
			if nearest_distance < shortest_distance:
				shortest_distance = nearest_distance
				candidate = drone
	if candidate != null:
		return candidate

	if _spawn_timer.time_left < 1e-4 and len(_drones) < drone_limit:
		var drone = drone_scene.instance()
		drone.transform = $SpawnPoint.global_transform
		_drones.append(drone)
		game_master.add_unit(team, drone)
		_spawn_timer = get_tree().create_timer(1.0)
		return drone
	return null


func _task_completed(unit: Unit, drone: Unit) -> void:
	if drone.task == 1:
		var value = _needs_material.get(unit)
		if value == drone:
			_needs_material[unit] = null
	else:
		var value = _dumps_material.get(unit)
		if value == drone:
			_dumps_material[unit] = null
	drone.disconnect("task_completed", self, "_task_completed")


func _get_nearest(unit, unit_list) -> Unit:
	var provider: Unit
	var shortest_distance := INF
	for prov in unit_list:
		var dist: float = prov.translation.distance_squared_to(unit.translation)
		if dist < shortest_distance:
			provider = prov
			shortest_distance = dist
	return provider


func _unit_added(unit: Unit) -> void:
	if unit.team == team and unit.translation.distance_squared_to(translation) < _radius2:
		_add_unit(unit)


func _add_unit(unit: Unit) -> void:
	_units.append(unit)
	unit.connect("message", self, "_get_message", [unit])
	unit.connect("destroyed", self, "_unit_destroyed")
	var needs = unit.request_info("need_material")
	if needs != null and needs > 0:
		_needs_material[unit] = null
	var provides = unit.request_info("provide_material")
	if provides != null and provides > 0:
		_provides_material.append(unit)
	var takes = unit.request_info("take_material")
	if takes != null and takes > 0:
		_takes_material.append(unit)
	var dumps = unit.request_info("dump_material")
	if dumps != null and dumps > 0:
		_dumps_material[unit] = null


func draw_debug(debug):
	for drone in _drones:
		debug.draw_line(translation, drone.translation, Color.orange)
		drone.draw_debug(debug)
