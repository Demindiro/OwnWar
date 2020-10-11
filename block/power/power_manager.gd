extends Reference


const _ENERGY_PER_FUEL := 1000
var _engines := []
var _fuel_tanks := []
var _max_power := 0
var _max_fuel := 0
var _fuel := 0
var _reserved_power := {}
var _remaining_power := 0
var _energy := 0
var _vehicle: Vehicle


func init(vehicle: Vehicle) -> void:
	_vehicle = vehicle
	vehicle.add_function(self, "get_fuel_count")
	vehicle.add_function(self, "get_fuel_space")
	vehicle.add_function(self, "take_fuel")
	vehicle.add_function(self, "put_fuel")
	vehicle.add_function(self, "reserve_power")
	vehicle.add_function(self, "unreserve_power")
	vehicle.add_info(self, "get_info")


func process(_delta: float) -> void:
	var requested_power := 0
	var needed_energy := 0
	var power_fraction_up := 1
	var power_fraction_down := 1
	var used_energy := 0
	_remaining_power = _max_power

	for power in _reserved_power.values():
		requested_power += power

	if requested_power > _max_power:
		power_fraction_up = requested_power
		power_fraction_down = requested_power

	if requested_power > 0:
# warning-ignore:integer_division
		needed_energy = requested_power / Engine.iterations_per_second
		used_energy = needed_energy
		if needed_energy > _energy:
			# Round up (https://stackoverflow.com/a/503201/7327379)
# warning-ignore:integer_division
			var needed_fuel = (needed_energy - _energy - 1) / _ENERGY_PER_FUEL + 1
			var fuel = take_fuel(needed_fuel)
			_energy += fuel * _ENERGY_PER_FUEL
			if needed_energy > _energy:
				assert(fuel < needed_fuel)
				power_fraction_up *= int(_energy)
				power_fraction_down *= int(needed_energy)
				used_energy = _energy

	for requester in _reserved_power:
		var power = _reserved_power[requester] * power_fraction_up / power_fraction_down
		requester.supply_power(power)
		_remaining_power -= power

	assert(_remaining_power >= 0)
	_energy -= used_energy


func get_fuel_count():
	return _fuel


func get_fuel_space():
	return _max_fuel - _fuel


func take_fuel(amount):
	_fuel -= amount
	if _fuel < 0:
		amount += _fuel
		_fuel = 0
	return amount


func put_fuel(amount):
	_fuel += amount
	if _fuel > _max_fuel:
		var remainder = _fuel - _max_fuel
		_fuel = _max_fuel
		return remainder
	return 0


func reserve_power(object, amount):
	_reserved_power[object] = amount


func unreserve_power(object):
# warning-ignore:return_value_discarded
	 _reserved_power.erase(object)


func add_engine(engine: Node) -> void:
	_engines.append(engine)
	_max_power += engine.max_power


func add_fuel_tank(fuel_tank: Node) -> void:
	_fuel_tanks.append(fuel_tank)
	_max_fuel += fuel_tank.max_fuel


func get_info(info):
	info["Power"] = "%d / %d" % [_remaining_power, _max_power]
	info["Fuel"] = "%d / %d" % [_fuel, _max_fuel]


func _engine_destroyed(engine: Node) -> void:
	_engines.erase(engine)
	_max_power -= engine.max_power


func _fuel_tank_destroyed(fuel_tank: Node) -> void:
	_fuel_tanks.erase(fuel_tank)
	_max_fuel -= fuel_tank.max_fuel
