extends "res://plugins/weapon_manager/projectile.gd"


export var despawn_time := 5.0
var life_time := 0.0
onready var mesh = $MeshInstance
onready var previous_position = translation


func _process(_delta):
	mesh.global_transform.basis.z = linear_velocity.normalized()
	mesh.global_transform.basis.y = transform.basis.x.cross(mesh.global_transform.basis.z)
	mesh.global_transform.basis.x = transform.basis.x


func _physics_process(delta):
	var space = get_world().direct_space_state
	var result = space.intersect_ray(previous_position, translation)
	if len(result) > 0:
		if result.collider.has_method("projectile_hit"):
			damage = result.collider.projectile_hit(previous_position,
					translation - previous_position, damage)
			if damage == 0:
				queue_free()
		else:
			queue_free()
	life_time += delta
	if life_time > despawn_time:
		queue_free()
	previous_position = translation
