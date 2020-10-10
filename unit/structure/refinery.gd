extends Unit


export var max_material := 10
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
			_producing = true


func get_info():
	var info = .get_info()
	info["Material"] = "%d / %d" % [material, max_material]
	info["Fuel"] = "%d / %d" % [fuel, max_fuel]
	return info


func put_material(amount):
	material += amount
	if material > max_material:
		var remainder = material - max_material
		material = max_material
		return remainder
	return 0


func take_material(amount):
	material -= amount
	if material < 0:
		amount += material
		material = 0
	return amount


func take_fuel(amount):
	fuel -= amount
	if fuel < 0:
		amount += fuel
		fuel = 0
	return amount
