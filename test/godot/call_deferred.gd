extends Node
# Quick test to see if call_deferred refers to the _current_ frame or the
# actual _idle_ frame ("Calls the method on the object during idle time.")
#
# How to check: when the program breaks, check the array.
# If the pattern is [0, 1, 0, 1, ...] the description refers to the current frame
# Otherwise, it refers to the idle frame
#
# Conclusion: it refers to the actual current frame
# So in _physics_process it refers to the physics frame


var dsum := 0.0
var array := []


func _init():
	Engine.iterations_per_second = 2000


func _physics_process(delta):
	dsum += delta
	if dsum > 0.05:
		breakpoint
		return
	array.append(0)
	call_deferred("deferred")


func deferred():
	array.append(1)
