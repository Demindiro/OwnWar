class_name OwnWar


const Action := preload("map/action.gd")
const Maps := preload("maps.gd")
const GameMaster := preload("map/game_master.gd")

const Unit := preload("unit/unit.gd")
const Structure := preload("unit/structure.gd")
const Ghost := preload("unit/ghost.gd")
const Vehicle := preload("unit/vehicle.gd")

const Matter := preload("matter.gd")

const Block := preload("block/block.gd")
const VoxelBody := preload("voxel_body.gd")
const VoxelMesh := preload("voxel_mesh.gd")

const Plugin := preload("plugin/loader.gd")
const Compatibility := preload("compatibility.gd")


const VERSION := Vector3(0, 16, 0)
const COLLISION_MASK_TERRAIN := 1 << (8 - 1)
const COLLISION_MASK_UNIT := 1 << (19 - 1)
const COLLISION_MASK_STRUCTURE := 1 << (20 - 1)
const _MAIN_MENU := "res://core/menu/main_menu/main.tscn"
const _MAIN_MENU_SCENES := PoolStringArray()


static func add_main_menu_background(path: String) -> void:
	assert(path.is_abs_path())
	assert(File.new().file_exists(path))
	_MAIN_MENU_SCENES.append(path)


static func get_random_main_menu_background() -> PackedScene:
	if len(_MAIN_MENU_SCENES) == 0:
		return null
	var i := randi() % len(_MAIN_MENU_SCENES)
	var ret: PackedScene = load(_MAIN_MENU_SCENES[i])
	return ret


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
	tree.change_scene(_MAIN_MENU)
	tree.paused = false
