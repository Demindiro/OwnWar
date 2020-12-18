extends OwnWar_Structure


signal spawned(unit)
var worker = load("res://plugins/worker_drone/drone.tscn")
var material = 0 setget set_material
var queued_vehicle = null
var queued_vehicle_name
var queued_vehicle_path := ""
onready var _material_id := OwnWar.Matter.get_matter_id("material")
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
	if queued_vehicle != null:
		info["Material"] = "%d / %d" % [material, queued_vehicle.get_cost()]
		info["Queued"] = queued_vehicle_name
	else:
		info["Material"] = "%d" % material
	return info


func get_actions():
	var drone_texture := ImageTexture.new()
	var actions = [
		OwnWar.Action.new(
			"Spawn Drone",
			drone_texture,
			Action.INPUT_NONE,
			funcref(self, "spawn_worker")
		)
	]
	OwnWar_Thumbnail.get_unit_thumbnail_async(
		"worker",
		funcref(drone_texture, "create_from_image")
	)
	var directory = Directory.new()
	var err = directory.open(Global.DIRECTORY_USER_VEHICLES)
	if err == OK:
		directory.list_dir_begin(true)
		var file_name = directory.get_next()
		while file_name != "":
			if not directory.current_is_dir() and \
					file_name.ends_with(Global.FILE_EXTENSION):
				var action_name = "Spawn " + OwnWar.Vehicle.path_to_name(file_name)
				var path = directory.get_current_dir() + '/' + file_name
				var texture := ImageTexture.new()
				actions.append(
					OwnWar.Action.new(
						action_name,
						texture,
						Action.INPUT_NONE,
						funcref(self, "spawn_vehicle"),
						[path]
					)
				)
				OwnWar_Thumbnail.get_vehicle_thumbnail_async(
					path,
					funcref(texture, "create_from_image")
				)
			file_name = directory.get_next()
	else:
		Global.error(err)
	return actions


func get_interaction_port() -> Vector3:
	return _interaction_port.global_transform.origin


func is_busy() -> bool:
	return queued_vehicle != null


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


func spawn_vehicle(_flags: int, path: String) -> void:
	if queued_vehicle != null:
		queued_vehicle.free()
	queued_vehicle = OwnWar.Vehicle.new()
	var err = queued_vehicle.load_from_file(path)
	if err != OK:
		Global.error("Failed to spawn vehicle from '%s'" % path, err)
		queued_vehicle.free()
		queued_vehicle = null
		_indicator_vehicle_material.albedo_color = Color.red
	else:
		queued_vehicle.translate(Vector3.UP * 5)
		queued_vehicle.rotate_y(PI)
		_indicator_vehicle_material.albedo_color = Color.orange
		queued_vehicle_name = OwnWar.Vehicle.path_to_name(path.get_file())
		queued_vehicle_path = path
	emit_signal("need_matter", _material_id, _get_needed_material())


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
			queued_vehicle.transform = global_transform
			queued_vehicle.translate(Vector3.UP * 5.0)
			# Rotate 180° because I cba to fix it properly
			queued_vehicle.rotate_y(PI)
			OwnWar.GameMaster.get_game_master(self).add_child(queued_vehicle)
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
			assert(queued_vehicle_path != "")
			data["queued_path"] = queued_vehicle_path
	return data


func deserialize_json(data: Dictionary) -> void:
	material = data["material"]
	var queued_type: String = data.get("queued", "")
	if queued_type != "":
		_indicator_vehicle_material.albedo_color = Color.orange
		if queued_type == "worker":
			queued_vehicle = worker.instance()
		elif queued_type == "vehicle":
			queued_vehicle = OwnWar.Vehicle.new()
			queued_vehicle_path = data["queued_path"]
			var e: int = queued_vehicle.load_from_file(queued_vehicle_path)
			assert(e == OK)
			if e != OK:
				push_error("Failed to load vehicle from %s: %d" % [
					queued_vehicle_path, e
				])
				_indicator_vehicle_material.albedo_color = Color.red
				queued_vehicle = null
				queued_vehicle_path = ""
	else:
		_indicator_vehicle_material.albedo_color = Color.green


func _get_needed_material():
	return 0 if queued_vehicle == null else queued_vehicle.get_cost() - material
