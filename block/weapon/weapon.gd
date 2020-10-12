class_name Weapon

extends Spatial


export(NodePath) var azimuth_node_path
export(NodePath) var elevation_node_path
export(NodePath) var projectile_spawn_path
export(PackedScene) var projectile
export(int) var projectile_velocity = 100
export(int) var projectile_damage = 150
export(float) var reload_time = 1.0

var rel_spawn_pos
var offset_y
var offset_spawn_y
var _time_since_last_shot = 0.0

onready var _azimuth_node = get_node(azimuth_node_path)
onready var _elevation_node = get_node(elevation_node_path)
onready var _projectile_spawn_node = get_node(projectile_spawn_path)


func _ready():
	rel_spawn_pos = to_local(_projectile_spawn_node.global_transform.origin)
	offset_y = to_local(_elevation_node.global_transform.origin).y
	offset_spawn_y = rel_spawn_pos.y - offset_y


func _process(_delta):
	pass
#	_azimuth_node.transform.basis = Basis(Vector3.UP, _desired_azimuth)
#	_elevation_node.transform.basis = Basis(Vector3.RIGHT, _desired_elevation)


func _physics_process(delta):
	_time_since_last_shot += delta


func init(_coordinate, _block_data, _rotation, _voxel_body, vehicle, _meta):
	var manager = vehicle.get_manager("weapon", preload("res://block/weapon/weapon_manager.gd"))
	manager.add_weapon(self)


# TODO: reduce the amount of variables
# I lost countless hours trying to debug this due to the sheer amount of
# variables
func aim_at(position: Vector3, _velocity := Vector3.ZERO):
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


func fire():
	if _time_since_last_shot >= reload_time:
		var node = projectile.instance()
		node.global_transform = _projectile_spawn_node.global_transform
		node.linear_velocity = _projectile_spawn_node.global_transform.basis.z
		node.linear_velocity *= projectile_velocity
		node.damage = projectile_damage
		get_tree().root.get_child(1).add_child(node) # TODO ugly
		_time_since_last_shot = 0.0


func debug_draw(debug):
	debug.begin(Mesh.PRIMITIVE_LINES)
	debug.set_color(Color.blue)
	debug.add_vertex(_projectile_spawn_node.to_global(Vector3.ZERO))
	debug.add_vertex(_projectile_spawn_node.to_global(-Vector3.FORWARD * 1e3))
	debug.end()
