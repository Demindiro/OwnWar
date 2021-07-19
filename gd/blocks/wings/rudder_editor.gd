extends Spatial


var team_color setget set_team_color


func set_color(color):
	$Moving/Rudder.color = color
	$Fixed/Rudder.color = color

func set_team_color(color):
	team_color = color
	$Moving/Glow.color = color
