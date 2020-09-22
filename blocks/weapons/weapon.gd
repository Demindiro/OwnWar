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
var rel_spawn_pos
var offset_y
var offset_spawn_y


func _ready():
	rel_spawn_pos = to_local(_projectile_spawn_node.global_transform.origin)
	offset_y = to_local(_elevation_node.global_transform.origin).y
	offset_spawn_y = rel_spawn_pos.y - offset_y


func _process(_delta):
	pass
#	_azimuth_node.transform.basis = Basis(Vector3.UP, _desired_azimuth)
#	_elevation_node.transform.basis = Basis(Vector3.RIGHT, _desired_elevation)


# TODO: reduce the amount of variables
# I lost countless hours trying to debug this due to the sheer amount of
# variables
func aim_at(position: Vector3, velocity := Vector3.ZERO):
	var rel_pos = to_local(position)
	var rel_pos_elev = rel_pos - Vector3.UP * offset_y
	var rel_pos_xz = Vector3(rel_pos.x, 0, rel_pos.z)

	var basis_azi_offset
	var basis_elev_offset

	# Determine offsets
	if true:
		var sin_azi_offset = rel_spawn_pos.x / rel_pos.length()
		var cos_azi_offset = sqrt(1 - sin_azi_offset * sin_azi_offset)
		basis_azi_offset = Basis(Vector3(cos_azi_offset, 0, sin_azi_offset), Vector3.UP,
				Vector3(-sin_azi_offset, 0, cos_azi_offset))
	
	if true:
		var sin_elev_offset = offset_spawn_y / rel_pos_elev.length()
		var cos_elev_offset = sqrt(1 - sin_elev_offset * sin_elev_offset)
		basis_elev_offset = Basis(Vector3.RIGHT, Vector3(0, cos_elev_offset, sin_elev_offset),
				Vector3(0, -sin_elev_offset, cos_elev_offset))
			
	# Determine default angle
	var axis_z = transform.basis.z
	var normal_azi = rel_pos_xz.normalized()
	var cos_azi = axis_z.dot(normal_azi)
	var sin_azi = -axis_z.cross(normal_azi).length() * sign(rel_pos_xz.x)
	var basis_azi = Basis(Vector3(cos_azi, 0, sin_azi), Vector3.UP,
			Vector3(-sin_azi, 0, cos_azi))

	var cos_elev = rel_pos_xz.length() / rel_pos_elev.length()
	var sin_elev = sqrt(1 - cos_elev * cos_elev) * sign(-rel_pos_elev.y)
	var basis_elev = Basis(Vector3.RIGHT, Vector3(0, cos_elev, sin_elev),
			Vector3(0, -sin_elev, cos_elev))
	
	# Apply basises
	_azimuth_node.transform.basis = basis_azi * basis_azi_offset
	_elevation_node.transform.basis = basis_elev * basis_elev_offset


func debug_draw(debug):
	debug.begin(Mesh.PRIMITIVE_LINES)
	debug.set_color(Color.blue)
	debug.add_vertex(_projectile_spawn_node.to_global(Vector3.ZERO))
	debug.add_vertex(_projectile_spawn_node.to_global(-Vector3.FORWARD * 1e3))
	debug.end()
