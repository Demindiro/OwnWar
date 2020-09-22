extends RigidBody


var velocity = Vector3.ZERO

onready var mesh = $MeshInstance


func _process(_delta):
	mesh.global_transform.basis.z = linear_velocity.normalized()
	mesh.global_transform.basis.y = transform.basis.x.cross(mesh.global_transform.basis.z)
	mesh.global_transform.basis.x = transform.basis.x
