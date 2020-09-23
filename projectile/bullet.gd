extends RigidBody


var velocity := Vector3.ZERO
var damage := 0

onready var mesh = $MeshInstance
onready var previous_position = translation


func _process(_delta):
	mesh.global_transform.basis.z = linear_velocity.normalized()
	mesh.global_transform.basis.y = transform.basis.x.cross(mesh.global_transform.basis.z)
	mesh.global_transform.basis.x = transform.basis.x


func _physics_process(_delta):
	var space = get_world().direct_space_state
	var result = space.intersect_ray(previous_position, translation)
	if len(result) > 0:
		var vehicle := result.collider as Vehicle
		if vehicle == null:
			queue_free()
		else:
			damage = vehicle.projectile_hit(previous_position,
					translation - previous_position, damage)
			if damage == 0:
				queue_free()
	previous_position = translation