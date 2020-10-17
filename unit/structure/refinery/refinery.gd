extends Unit


const MAX_MATERIAL := 50
const MAX_FUEL := 1000
export var material := 0
export var fuel := 0
var _time_until_fuel_produced := 0.0
var _producing := false
onready var _material_id: int = Matter.name_to_id["material"]
onready var _fuel_id: int = Matter.name_to_id["fuel"]


func _physics_process(delta):
	if _producing:
		_time_until_fuel_produced += delta
		if _time_until_fuel_produced >= 1.0 and fuel < MAX_FUEL:
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
	info["Fuel"] = "%d / %d" % [fuel, MAX_FUEL]
	return info


func request_info(info: String):
	if info == "need_material":
		return MAX_MATERIAL - material
	return .request_info(info)


func get_matter_count(id: int):
	if id == _material_id:
		return material
	elif id == _fuel_id:
		return fuel
	return 0


func get_matter_space(id: int) -> int:
	if id == _material_id:
		return MAX_MATERIAL - material
	elif id == _fuel_id:
		return MAX_FUEL - fuel
	return 0


func get_put_matter_list(id: int) -> PoolIntArray:
	return PoolIntArray([_material_id])


func get_take_matter_list(id: int) -> PoolIntArray:
	return PoolIntArray([_fuel_id])


func put_matter(id: int, amount: int) -> int:
	if id == _material_id:
		material += amount
		if material > MAX_MATERIAL:
			var remainder = material - MAX_MATERIAL
			material = MAX_MATERIAL
			send_message("need_material", MAX_MATERIAL - material)
			return remainder
		send_message("need_material", MAX_MATERIAL - material)
		return 0
	return amount


func take_matter(id: int, amount: int) -> int:
	if id == _material_id:
		material -= amount
		if material < 0:
			amount += material
			material = 0
			send_message("need_material", MAX_MATERIAL - material)
		return amount
	elif id == _fuel_id:
		fuel -= amount
		if fuel < 0:
			amount += fuel
			fuel = 0
		return amount
	return 0


func put_material(amount):
	return put_matter(_material_id, amount)


func take_material(amount):
	return take_matter(_material_id, amount)


func take_fuel(amount):
	return take_matter(_fuel_id, amount)


func get_material_space():
	return get_matter_space(_material_id)
