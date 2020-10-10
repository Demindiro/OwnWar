extends Node


export var max_fuel := 1000
var fuel = 1000


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle):
	vehicle.add_block_function(self, "_static_take_fuel", "take_fuel")
	vehicle.add_block_function(self, "_static_put_fuel", "put_fuel")
	vehicle.add_block_function(self, "_static_get_fuel_space", "get_fuel_space")
	vehicle.add_info_function(self, "_static_get_info_fuel", "Fuel")


static func _static_take_fuel(blocks, arguments):
	var needed = arguments[0]
	var amount = 0
	for block in blocks:
		if block.fuel >= needed:
			block.fuel -= needed
			amount += needed
			break
		else:
			amount += block.fuel
			needed -= block.fuel
			block.fuel = 0
	return amount


static func _static_put_fuel(blocks, arguments):
	var amount = arguments[0]
	for block in blocks:
		var space = block.max_fuel - block.fuel
		if space >= amount:
			block.fuel += amount
			amount = 0
			break
		else:
			block.fuel = block.max_fuel
			amount -= space
	return amount


static func _static_get_fuel_space(blocks, arguments):
	var space := 0
	for block in blocks:
		space += block.max_fuel - block.fuel
	return space


static func _static_get_info_fuel(blocks):
	var max_total_fuel = 0
	var total_fuel = 0
	for block in blocks:
		max_total_fuel += block.max_fuel
		total_fuel += block.fuel
	return "%d / %d" % [total_fuel, max_total_fuel]
