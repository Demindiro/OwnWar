class_name OwnWar


const VERSION := Vector3(0, 18, 1)
const COLLISION_MASK_TERRAIN := 1 << (8 - 1)
const COLLISION_MASK_UNIT := 1 << (19 - 1)
const COLLISION_MASK_STRUCTURE := 1 << (20 - 1)
const MAIN_MENU := "res://start_menu/main.tscn"
const VEHICLE_DIRECTORY := "user://vehicles"
const VEHICLE_EXTENSION := "owv"
const NET_COMPRESSION := NetworkedMultiplayerENet.COMPRESS_RANGE_CODER
const SETTINGS_FILE := "user://settings.cfg"
const MAINFRAME_ID := 76

const ALLY_COLOR := Color(0.0, 1.0, 0.976471)
const ENEMY_COLOR := Color(1.0, 0.15, 0.15)


static func snap_transform(node) -> void:
	var transform: Transform = node.global_transform
	var org := transform.origin
	var basis := transform.basis
	# Apply offset
	org -= basis * node.position_offset
	# Snap X and Z to 0.5 resolution
	org = (org * 2).round() / 2
	# Snap to floor
	var state = node.get_world().get_direct_space_state()
	var res = state.intersect_ray(
			org + Vector3.UP * 1_000.0,
			org + Vector3.DOWN * 1_000.0,
			[], COLLISION_MASK_TERRAIN)
	if len(res) > 0:
		org.y = res["position"].y
	# Snap rotation
	# Get the "aligned" basis, determine the angle and the direction
	# and determine current rotation from that
	var ta_basis := Util.get_aligned_basis(basis.y)
	var rot = ta_basis.x.angle_to(basis.x)
	rot *= sign(ta_basis.x.dot(basis.z))
	rot = Util.round_res(rot, 24 / (PI * 2))
	# Align with normal and apply rotation
	var up: Vector3 = res["normal"] if len(res) > 0 else Vector3.UP
	basis = Util.get_aligned_basis(up)
	basis = basis.rotated(up, rot)
	# Apply offset along normal
	org += basis * node.position_offset
	# Apply transform (unless it's pretty much equal)
	var n_transform := Transform(basis, org)
	if not Util.is_transform_approx_eq(n_transform, transform,
			1e-3, 1e-3):
		node.global_transform = n_transform


static func goto_main_menu(tree: SceneTree) -> void:
	var e := tree.change_scene(MAIN_MENU)
	assert(e == OK)
	tree.paused = false


static func is_in_designer(tree: SceneTree) -> bool:
	return tree.current_scene != null and \
		tree.current_scene.filename == "res://core/designer/designer.tscn"


static func get_vehicle_path(name: String) -> String:
	var f := Util.filenamize_human_name(name)
	return VEHICLE_DIRECTORY.plus_file(f) + "." + VEHICLE_EXTENSION


static func get_vehicle_name(path: String) -> String:
	path = path.get_file()
	path = path.substr(0, len(path) - 1 - len(VEHICLE_EXTENSION))
	return Util.humanize_file_name(path)
