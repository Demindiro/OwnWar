extends Unit


signal task_completed(task, target)
enum Task {
		TAKE_MATERIAL,
		PUT_MATERIAL,
		BUILD_STRUCTURE,
		GOTO_WAYPOINT,
		TAKE_MUNITION,
		PUT_MUNITION,
		TAKE_FUEL,
		PUT_FUEL,
	}
const SPEED = 20.0
const INTERACTION_DISTANCE = 6.0
const INTERACTION_DISTANCE_2 = INTERACTION_DISTANCE * INTERACTION_DISTANCE
export(Dictionary) var ghosts = {}
export(PackedScene) var drill_ghost
export(int) var max_material = 100
export(int) var cost = 20
var tasks = []
var material = 0 setget set_material
var last_build_frame = 0
var munition = null
var max_fuel = 20
var fuel = 0
onready var rotors = [
		$ArmLF/Rotor,
		$ArmRF/Rotor,
		$ArmLB/Rotor,
		$ArmRB/Rotor,
	]
	
	
func _ready():
	set_material(material)


func _process(delta):
	for rotor in rotors:
		rotor.rotate_object_local(Vector3.UP, delta * 50)
	draw_debug(game_master.get_node("Debug"))
		
		
func _physics_process(delta):
	if len(tasks) == 0:
		return
	var task = tasks[0]
	match task[0]:
		Task.GOTO_WAYPOINT:
			if move_towards(task[1], delta):
				current_task_completed()
		Task.BUILD_STRUCTURE:
			if material > 0:
				if translation.distance_squared_to(task[1].translation) <= INTERACTION_DISTANCE_2:
					if last_build_frame + Engine.iterations_per_second < Engine.get_physics_frames():
						material -= 1
						material += task[1].add_build_progress(1)
						set_material(material)
						last_build_frame = Engine.get_physics_frames()
				else:
					move_towards(task[1].translation, delta)
			else:
				take_materials_from_closest_pod(delta, task[1])
		Task.TAKE_MATERIAL:
			if translation.distance_squared_to(task[1].translation) <= INTERACTION_DISTANCE_2:
				var material_space = max_material - material
				self.material += task[1].take_material(material_space)
				current_task_completed()
			else:
				move_towards(task[1].translation, delta)
		Task.PUT_MATERIAL:
			if task[1].call_function("get_material_space") == 0:
				current_task_completed()
			elif material > 0:
				if translation.distance_squared_to(task[1].translation) <= INTERACTION_DISTANCE_2:
					self.material = task[1].put_material(material)
					if task[1].call_function("get_material_space") == 0:
						current_task_completed()
				else:
					move_towards(task[1].translation, delta)
			else:
				if not take_materials_from_closest_pod(delta, task[1]):
					current_task_completed()
		Task.TAKE_MUNITION:
			if munition == null and task[1].call_function("get_munition_count") > 0:
				if translation.distance_squared_to(task[1].translation) <= INTERACTION_DISTANCE_2:
					munition = task[1].call_function("take_munition")
					$MunitionMesh.mesh = munition.mesh
					current_task_completed()
				else:
					move_towards(task[1].translation, delta)
			else:
				current_task_completed()
		Task.PUT_MUNITION:
			if munition != null and task[1].call_function("get_munition_space", [munition.gauge]) > 0:
				if translation.distance_squared_to(task[1].translation) <= INTERACTION_DISTANCE_2:
					munition = task[1].call_function("put_munition", [munition])
					$MunitionMesh.mesh = null
					current_task_completed()
				else:
					move_towards(task[1].translation, delta)
			else:
				current_task_completed()
		Task.TAKE_FUEL:
			if fuel < max_fuel and task[1].call_function("get_fuel_count") > 0:
				if translation.distance_squared_to(task[1].translation) <= INTERACTION_DISTANCE_2:
					var fuel_space = max_fuel - fuel
					fuel += task[1].call_function("take_fuel", [fuel_space])
					current_task_completed()
				else:
					move_towards(task[1].translation, delta)
			else:
				current_task_completed()
		Task.PUT_FUEL:
			if fuel > 0 and task[1].call_function("get_fuel_space") > 0:
				if translation.distance_squared_to(task[1].translation) <= INTERACTION_DISTANCE_2:
					fuel = task[1].call_function("put_fuel", [fuel])
					current_task_completed()
				else:
					move_towards(task[1].translation, delta)
			else:
				current_task_completed()


func get_actions():
	return [
			["Set waypoint", Action.INPUT_COORDINATE, "set_waypoint", []],
			["Take", Action.SUBACTION, "get_take_actions", []],
			["Put", Action.SUBACTION, "get_put_actions", []],
			["Build", Action.SUBACTION, "get_build_actions", []],
			["Clear tasks", Action.INPUT_NONE, "clear_tasks", []],
		]


func get_take_actions(flags):
	return [
			["Take material", Action.INPUT_OWN_UNITS, "take_material_from", []],
			["Take munition", Action.INPUT_OWN_UNITS, "take_munition_from", []],
			["Take fuel", Action.INPUT_OWN_UNITS, "take_fuel_from", []],
		]


func get_put_actions(flags):
	return [
			["Put material", Action.INPUT_OWN_UNITS, "put_material_in", []],
			["Put munition", Action.INPUT_OWN_UNITS, "put_munition_in", []],
			["Put fuel", Action.INPUT_OWN_UNITS, "put_fuel_in", []],
		]


func get_build_actions(flags):
	var actions = [
			["Build", Action.INPUT_OWN_UNITS, "build", []],
			["Build drill", Action.INPUT_COORDINATE, "build_drill", []],
		]
	for ghost_name in ghosts:
		actions += [["Build " + ghost_name, Action.INPUT_COORDINATE | Action.INPUT_SCROLL,
				"build_ghost", [ghost_name]]]
	return actions


func get_info():
	var info = .get_info()
	var task_string
	if len(tasks) > 0:
		match tasks[0][0]:
			Task.GOTO_WAYPOINT:
				task_string = "Goto"
			Task.BUILD_STRUCTURE:
				task_string = "Build"
			Task.TAKE_MATERIAL:
				task_string = "Take"
			Task.PUT_MATERIAL:
				task_string = "Put"
			Task.TAKE_MUNITION:
				task_string = "Take munition"
			Task.PUT_MUNITION:
				task_string = "Put munition"
			Task.TAKE_FUEL:
				task_string = "Take fuel"
			Task.PUT_FUEL:
				task_string = "Put fuel"
			_:
				task_string = "Unknown (BUG)"
	else:
		task_string = "None"
	info["Current task"] = task_string
	info["Total tasks"] = str(len(tasks))
	info["Material"] = "%d / %d" % [material, max_material]
	info["Fuel"] = "%d / %d" % [fuel, max_fuel]
	return info


func add_task(task, force_append):
	if not force_append:
		clear_tasks(0)
	if task[1] is Unit and not task[1].is_connected("destroyed", self, "_unit_destroyed"):
		task[1].connect("destroyed", self, "_unit_destroyed", [task])
	tasks.append(task)


func set_waypoint(flags, coordinate):
	add_task([Task.GOTO_WAYPOINT, coordinate], flags & 0x1 > 0)


func move_towards(position, delta):
	var distance = position - translation
	var distance_xz = Vector3(distance.x, 0, distance.z)
	var distance_xz_length2 = distance_xz.length_squared()
	var speed = SPEED if distance_xz_length2 > SPEED * SPEED * delta * delta else \
			sqrt(distance_xz_length2) / delta
	var velocity_direction = distance_xz.normalized()
	var height = translation.y - $RayCast.get_collision_point().y if \
			$RayCast.is_colliding() else 5
	if height < 1:
		velocity_direction = (velocity_direction + Vector3.UP).normalized()
	elif height > 4:
		velocity_direction = (velocity_direction + Vector3.DOWN).normalized()
	if distance_xz_length2 > 1e-5:
		$".".move_and_slide(velocity_direction * speed, Vector3.UP,
				false, 4, PI / 4, false)
		return false
	else:
		return true


func build(flags, units):
	var force_append = flags & 0x1 > 0
	for ghost in units:
		if ghost is Ghost:
			add_task([Task.BUILD_STRUCTURE, ghost], force_append)
			ghost.connect("built", self, "_ghost_built")
			force_append = true
			
			
func build_ghost(flags, position, scroll, ghost_name):
	var ghost = ghosts[ghost_name].instance()
	ghost.transform = Transform(Basis.IDENTITY.rotated(Vector3.UP, scroll * PI / 8), position)
	game_master.add_unit(team, ghost)
	add_task([Task.BUILD_STRUCTURE, ghost], flags & 0x1 > 0)
	ghost.connect("built", self, "_ghost_built")


func build_drill(flags, coordinate):
	var closest_ore = null
	var max_distance = 3.0
	for ore in game_master.ores:
		var distance = (ore.translation - coordinate).length()
		if ore.drill == null and distance < max_distance:
			closest_ore = ore
			max_distance = distance
	if closest_ore != null:
		var ghost = drill_ghost.instance()
		ghost.translation = closest_ore.translation + Vector3.UP * 1.4
		ghost.init_arguments = [closest_ore]
		game_master.add_unit(team, ghost)
		add_task([Task.BUILD_STRUCTURE, ghost], flags & 0x1 > 0)
		ghost.connect("built", self, "_ghost_built")


func take_material_from(flags, units):
	var force_append = flags & 0x1 > 0
	for unit in units:
		if unit.has_method("take_material"):
			add_task([Task.TAKE_MATERIAL, unit], force_append)
			force_append = true


func put_material_in(flags, units):
	var force_append = flags & 0x1 > 0
	for unit in units:
		if unit.has_method("put_material"):
			add_task([Task.PUT_MATERIAL, unit],
					force_append)
			force_append = true


func take_munition_from(flags, units):
	var force_append = flags & 0x1 > 0
	for unit in units:
		if unit.has_function("take_munition"):
			add_task([Task.TAKE_MUNITION, unit], force_append)
			force_append = true


func put_munition_in(flags, units):
	var force_append = flags & 0x1 > 0
	for unit in units:
		if unit.has_function("put_munition"):
			add_task([Task.PUT_MUNITION, unit], force_append)
			force_append = true


func take_fuel_from(flags, units):
	var force_append = flags & 0x1 > 0
	for unit in units:
		if unit.has_function("take_fuel"):
			add_task([Task.TAKE_FUEL, unit], force_append)
			force_append = true


func put_fuel_in(flags, units):
	var force_append = flags & 0x1 > 0
	for unit in units:
		if unit.has_function("put_fuel"):
			add_task([Task.PUT_FUEL, unit], force_append)
			force_append = true


func clear_tasks(flags):
	for task in tasks:
		if task[1] is Unit:
			task[1].disconnect("destroyed", self, "_unit_destroyed")
		if task[0] == Task.BUILD_STRUCTURE and task[1] != null:
			task[1].disconnect("built", self, "emit_signal")
	tasks = []


func take_materials_from_closest_pod(delta, exclude_pod):
	var closest_pod = null
	for pod in game_master.get_units(team, "storage_pod"):
		if pod != exclude_pod and pod.get_matter_count(Matter.name_to_id["material"]) > 0 and \
				(closest_pod == null or \
				translation.distance_to(closest_pod.translation) > \
				translation.distance_to(pod.translation)):
			closest_pod = pod
	if closest_pod != null:
		if translation.distance_squared_to(closest_pod.translation) <= INTERACTION_DISTANCE_2:
			var material_space = max_material - material
			self.material += closest_pod.take_material(material_space)
		else:
			move_towards(closest_pod.translation, delta)
		return true
	return false


func current_task_completed():
	var task = tasks.pop_front()
	emit_signal("task_completed", task[0], task[1])
	tasks.push_back(task)


func set_material(p_material):
	assert(0 <= p_material and p_material <= max_material)
	material = p_material
	$Indicator.scale.z = float(material) / max_material


func get_cost():
	return cost


func draw_debug(debug):
	var start = translation
	for task in tasks:
		var color
		var position
		match task[0]:
			Task.GOTO_WAYPOINT:
				color = Color.green
				position = task[1] + Vector3.UP * Global.BLOCK_SCALE
			Task.BUILD_STRUCTURE:
				color = Color.orange
				position = task[1].translation
			Task.TAKE_MATERIAL:
				color = Color.purple
				position = task[1].translation
			Task.PUT_MATERIAL:
				color = Color.cyan
				position = task[1].translation
			Task.TAKE_MUNITION:
				color = Color.red
				position = task[1].translation
			Task.PUT_MUNITION:
				color = Color.yellow
				position = task[1].translation
			Task.TAKE_FUEL:
				color = Color.chartreuse
				position = task[1].translation
			Task.PUT_FUEL:
				color = Color.beige
				position = task[1].translation
		if color != null:
			debug.draw_circle(position, color)
			debug.draw_line(start, position, color)
			start = position


func _ghost_built(unit):
	emit_signal("task_completed", Task.BUILD_STRUCTURE, unit)


func _unit_destroyed(_unit, task):
	while true:
		var index = tasks.find_last(task)
		if index < 0:
			break
		tasks.remove(index)
