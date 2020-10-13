extends Node


var _time_until_next := 0.0
var _count := 0


func _ready():
	var shape := $StaticBody/CollisionShape.shape as HeightMapShape
	var map_data := shape.map_data
	for x in range(shape.map_depth):
		var i = x * shape.map_width
		map_data[i] = 1.0
	for y in range(shape.map_width):
		map_data[y] = 1.0
	for x in range(shape.map_depth):
		var i = x * shape.map_width + (shape.map_depth - 1)
		map_data[i] = 1.0
	for y in range(shape.map_width):
		var i = (shape.map_depth - 1) * shape.map_width + y
		map_data[i] = 1.0
	shape.map_data = map_data


func _process(delta):
	_time_until_next -= delta
	if _time_until_next <= 0.0:
		var vehicle = Vehicle.new()
		vehicle.load_from_file("user://vehicles/tank.json")
		vehicle.translation = Vector3(_count & 0xf, 0.5, (_count >> 4) & 0xf) * 8
		add_child(vehicle)
		_count += 1
		_time_until_next = 1.0
