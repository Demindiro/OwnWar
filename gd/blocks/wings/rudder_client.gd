extends Spatial


var team_color setget set_team_color

var server_node

onready var moving = $Moving


func _process(_delta):
	moving.transform.basis = Basis(Vector3(0, 1, 0), server_node.current_angle)


func set_color(color):
	$Moving/Rudder.color = color
	$Fixed/Rudder.color = color

func set_team_color(color):
	team_color = color
	$Moving/Glow.color = color
