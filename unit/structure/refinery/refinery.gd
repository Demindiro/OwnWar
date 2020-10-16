extends Unit


const MAX_MATERIAL := 50
export var max_fuel := 1000
export var material := 0
export var fuel := 0
var _time_until_fuel_produced := 0.0
var _producing := false


func _physics_process(delta):
	if _producing:
		_time_until_fuel_produced += delta
		if _time_until_fuel_produced >= 1.0 and fuel < max_fuel:
			fuel += 1
			_time_until_fuel_produced = 0.0
			_producing = false
	if not _producing:
		if material >= 2:
			material -= 2
			send_message("need_material", MAX_MATERIAL - material)
			_producing = true


func get_info():
	var info = .get_info()
	info["Material"] = "%d / %d" % [material, MAX_MATERIAL]
	info["Fuel"] = "%d / %d" % [fuel, max_fuel]
	return info


func request_info(info: String):
	if info == "need_material":
		return MAX_MATERIAL - material
	return .request_info(info)


func put_material(amount):
	material += amount
	if material > MAX_MATERIAL:
		var remainder = material - MAX_MATERIAL
		material = MAX_MATERIAL
		send_message("need_material", MAX_MATERIAL - material)
		return remainder
	send_message("need_material", MAX_MATERIAL - material)
	return 0


func take_material(amount):
	material -= amount
	if material < 0:
		amount += material
		material = 0
		send_message("need_material", MAX_MATERIAL - material)
	return amount


func take_fuel(amount):
	fuel -= amount
	if fuel < 0:
		amount += fuel
		fuel = 0
	return amount


func get_fuel_count():
	return fuel


func get_material_space():
	return MAX_MATERIAL - material
