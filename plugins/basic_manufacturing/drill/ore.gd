tool
extends Spatial


export var max_material := 10000
# warning-ignore:unused_class_variable
var drill : OwnWar.Unit
onready var material := max_material


func _init():
	add_to_group("ores")


func _process(_delta: float) -> void:
	if Engine.editor_hint:
		var org := global_transform.origin
		# Snap to grid
		org = (org * 2.0).round() / 2.0
		# Snap to terrain
		var state := get_world().get_direct_space_state()
		var result := state.intersect_ray(
				org + Vector3.UP * 1_000.0,
				org + Vector3.DOWN * 1_000.0,
				[], OwnWar.COLLISION_MASK_TERRAIN)
		if len(result) > 0:
			org.y = result["position"].y
		else:
			org.y = 0
		# Set random rotation
		var basis := Basis.IDENTITY
		global_transform = Transform(basis, org)


func take_material(amount):
	material -= amount
	if material < 0:
		amount += material
		material = 0
	return amount
