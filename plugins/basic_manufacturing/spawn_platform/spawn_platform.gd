extends Structure


signal spawned(unit)
var worker = load("res://plugins/worker_drone/drone.tscn")
var material = 0 setget set_material
var queued_vehicle = null
var queued_vehicle_name
onready var _material_id = Matter.get_matter_id("material")
onready var _indicator_material: Spatial = $IndicatorMaterial
onready var _indicator_vehicle_material: SpatialMaterial
onready var _interaction_port: Spatial = $InteractionPort


func _ready():
	unit_name = "spawn_platform"
	set_material(material)
	var indic: MeshInstance = $IndicatorVehicle
	_indicator_vehicle_material = indic.material_override.duplicate()
	indic.material_override = _indicator_vehicle_material
	_indicator_vehicle_material.albedo_color = Color.green


func _notification(notification):
	match notification:
		NOTIFICATION_PREDELETE:
			if queued_vehicle != null:
				queued_vehicle.free()


func get_info():
	var info = .get_info()
	info["Material"] = "%d / %d" % [material, _get_needed_material()]
	if queued_vehicle != null:
		info["Queued"] = queued_vehicle_name
	return info


func get_actions():
	var actions = [["Spawn Drone", Action.INPUT_NONE, "spawn_worker", []]]
	var directory = Directory.new()
	var err = directory.open(Global.DIRECTORY_USER_VEHICLES)
	if err == OK:
		directory.list_dir_begin(true)
		var file_name = directory.get_next()
		while file_name != "":
			if not directory.current_is_dir() and \
					file_name.ends_with(Global.FILE_EXTENSION):
				var action_name = "Spawn " + Vehicle.path_to_name(file_name)
				var path = directory.get_current_dir() + '/' + file_name
				actions.append([action_name, 0, "spawn_vehicle", [path]])
			file_name = directory.get_next()
	else:
		Global.error(err)
	return actions


func get_interaction_port() -> Vector3:
	return _interaction_port.global_transform.origin


func spawn_worker(_flags):
	if queued_vehicle != null:
		queued_vehicle.free()
	queued_vehicle = worker.instance()
	_indicator_vehicle_material.albedo_color = Color.orange
	queued_vehicle.global_transform = global_transform
	queued_vehicle.translate(Vector3.UP * 5)
	queued_vehicle.rotate_y(PI)
	queued_vehicle_name = "Worker Drone"
	emit_signal("need_matter", _material_id, _get_needed_material())
	return queued_vehicle


func spawn_vehicle(_flags, path):
	if queued_vehicle != null:
		queued_vehicle.free()
	queued_vehicle = Vehicle.new()
	var err = queued_vehicle.load_from_file(path)
	if err != OK:
		Global.error("Failed to spawn vehicle from '%s'" % path, err)
		queued_vehicle.free()
		queued_vehicle = null
		_indicator_vehicle_material.albedo_color = Color.red
	else:
		queued_vehicle.global_transform = global_transform
		queued_vehicle.translate(Vector3.UP * 5)
		queued_vehicle.rotate_y(PI)
		_indicator_vehicle_material.albedo_color = Color.orange
		queued_vehicle_name = Vehicle.path_to_name(path.get_file())
	emit_signal("need_matter", _material_id, _get_needed_material())
	return queued_vehicle


func set_material(p_material):
	assert(0 <= p_material)
	material = p_material
	emit_signal("need_matter", _material_id, _get_needed_material())
	if queued_vehicle == null:
		_indicator_material.scale.z = 0 if material == 0 else 1
	else:
		_indicator_material.scale.z = clamp(float(material) / queued_vehicle.get_cost(), 0, 1)


func get_matter_count(id: int) -> int:
	if id == _material_id and queued_vehicle != null:
		return queued_vehicle.get_cost()
	return 0


func get_matter_space(id: int) -> int:
	if id == _material_id and queued_vehicle != null:
		return queued_vehicle.get_cost() - material
	return 0


func get_put_matter_list() -> PoolIntArray:
	return PoolIntArray([_material_id])


func get_take_matter_list() -> PoolIntArray:
	return PoolIntArray([_material_id])


func needs_matter(id: int) -> int:
	if id == _material_id:
		return _get_needed_material()
	return 0


func dumps_matter(id: int) -> int:
	if id == _material_id and queued_vehicle == null:
		return material
	return 0


func put_matter(id: int, amount: int) -> int:
	if id == _material_id:
		if queued_vehicle == null:
			return amount
		set_material(material + amount)
		if material >= queued_vehicle.get_cost():
			queued_vehicle.team = team
			GameMaster.get_game_master(self).add_child(queued_vehicle)
			emit_signal("spawned", queued_vehicle)
			var remainder = material - queued_vehicle.get_cost()
			queued_vehicle = null
			set_material(0)
			_indicator_vehicle_material.albedo_color = Color.green
			return remainder
		return 0
	return amount


func serialize_json() -> Dictionary:
	var data := {
		"material": material,
	}
	if queued_vehicle != null:
		if queued_vehicle.unit_name == "worker":
			data["queued"] = "worker"
		else:
			data["queued"] = "vehicle"
		data["queued_data"] = queued_vehicle.serialize_json()
	return data


func deserialize_json(data: Dictionary) -> void:
	material = data["material"]
	var queued_type: String = data.get("queued", "")
	if queued_type != "":
		if queued_type == "worker":
			queued_vehicle = worker.instance()
		elif queued_type == "vehicle":
			queued_vehicle = Vehicle.new()
		queued_vehicle.deserialize_json(data["queued_data"])


func _get_needed_material():
	return 0 if queued_vehicle == null else queued_vehicle.get_cost() - material