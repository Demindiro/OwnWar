# REEEEEEEEEEEEEEEEEEEEEe
# https://github.com/godotengine/godot/issues/18251
# Godot, come on, really? What is this trash UX?


extends CollisionShape



func _init():
	var s: CylinderShape = shape
	s.radius = 0.115
