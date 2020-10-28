class_name Ore

extends Spatial


export var max_material := 10000
# warning-ignore:unused_class_variable
var drill : Unit
onready var material := max_material


func take_material(amount):
	material -= amount
	if material < 0:
		amount += material
		material = 0
	return amount
