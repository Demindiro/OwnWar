class_name Weapon

extends Spatial


export(NodePath) var azimuth_node_path
export(NodePath) var elevation_node_path
export(NodePath) var projectile_spawn_path

var _desired_azimuth = 0
var _desired_elevation = 0

onready var _azimuth_node = get_node(azimuth_node_path)
onready var _elevation_node = get_node(elevation_node_path)
onready var _projectile_spawn_node = get_node(projectile_spawn_path)


func _process(_delta):
	pass
#	_azimuth_node.transform.basis = Basis(Vector3.UP, _desired_azimuth)
#	_elevation_node.transform.basis = Basis(Vector3.RIGHT, _desired_elevation)


func aim_at(position: Vector3, velocity := Vector3.ZERO):
	var rel_pos = to_local(position)
	var rel_spawn_pos = to_local(_projectile_spawn_node.global_transform.origin)
	var normal = (rel_pos - rel_spawn_pos).normalized()
	
	var axis_z = transform.basis.z
	var normal_azi = Vector3(normal.x, 0, normal.z).normalized()
	var cos_azi = axis_z.dot(normal_azi)
	var sin_azi = -axis_z.cross(normal_azi).length() * sign(normal.x)
	var basis_azi = Basis(Vector3(cos_azi, 0, sin_azi), Vector3.UP,
			Vector3(-sin_azi, 0, cos_azi))
	_azimuth_node.transform.basis = basis_azi
	
	var axis_y = transform.basis.y
	var normal_elev = normal
	var cos_elev = axis_y.dot(normal_elev)
	var sin_elev = axis_y.cross(normal_elev).length()
	var basis_elev = Basis(Vector3.RIGHT, Vector3(0, sin_elev, -cos_elev),
			Vector3(0, cos_elev, sin_elev))
	_elevation_node.transform.basis = basis_elev


func debug_draw(debug):
	debug.begin(Mesh.PRIMITIVE_LINES)
	debug.set_color(Color.blue)
	debug.add_vertex(_projectile_spawn_node.to_global(Vector3.ZERO))
	debug.add_vertex(_projectile_spawn_node.to_global(-Vector3.FORWARD * 1e3))
	debug.end()
