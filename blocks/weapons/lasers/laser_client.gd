extends Spatial
class_name OwnWar_WeaponLaserClient


export var laser_ray: PackedScene
var server_node: OwnWar_WeaponLaser setget set_server_node
onready var fire_point: Position3D = get_node("FirePoint")


func set_server_node(value: OwnWar_WeaponLaser) -> void:
	assert(value != null, "value is null (wrong type passed?)")
	server_node = value
	var e := server_node.connect("fired", self, "_on_fired")
	assert(e == OK)


func _on_fired(at: Vector3) -> void:
	var node: Spatial = laser_ray.instance()
	get_tree().current_scene.add_child(node)
	node.translation = fire_point.global_transform.origin
	node.look_at(at, Vector3.UP)
	node.scale = Vector3(1, 1, fire_point.translation.distance_to(at))
