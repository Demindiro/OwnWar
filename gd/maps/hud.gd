extends Control


# TODO
const BLOCK_SCALE := 0.25


const HealthBar := preload("health_circle.gd")

export var camera: NodePath
export(float, 0.0, 100.0) var camera_zoom_min := 5.0
export(float, 0.0, 100.0) var camera_zoom_max := 10.0
export var camera_offset := Vector3()
var player_vehicle_id = -1 setget set_player_vehicle
var vehicles

var _camera_pan := 0.0
var _camera_tilt := 0.0
var _camera_ray := RayCast.new()
var _camera_terrain_ray := RayCast.new()
onready var _camera_zoom := (camera_zoom_min + camera_zoom_max) / 2
onready var _camera: Camera = get_node(camera)
onready var _gui: Control = get_node("../GUI")
onready var _health_bar: HealthBar = get_node("Health")

var old_player_vehicle


func _ready() -> void:
	set_mouse_mode()
	_camera_ray.cast_to = Vector3(0, 0, -100000)
	_camera.add_child(_camera_ray)
	_camera_ray.transform = Transform.IDENTITY
	_camera_ray.collision_mask = 0xffffffff
	_camera.add_child(_camera_terrain_ray)
	_camera_terrain_ray.set_as_toplevel(true)
	_camera_terrain_ray.transform = Transform.IDENTITY
	_camera_terrain_ray.collision_mask = 0xffffffff


func _unhandled_input(event: InputEvent) -> void:
	if _gui.visible:
		return
	var mouse_event := event as InputEventMouseMotion
	if mouse_event != null:
		var rel := mouse_event.relative * OwnWar_Settings.mouse_move_sensitivity / 100
		_camera_pan -= rel.x
		_camera_tilt -= rel.y
		_camera_pan = fposmod(_camera_pan, 2 * PI)
		_camera_tilt = clamp(_camera_tilt, -PI / 2, PI / 2)
		get_tree().set_input_as_handled()
	elif event.is_action_pressed("combat_zoom_in"):
		_camera_zoom = max(camera_zoom_min, _camera_zoom - OwnWar_Settings.mouse_scroll_sensitivity)
		get_tree().set_input_as_handled()
	elif event.is_action_pressed("combat_zoom_out"):
		_camera_zoom = min(camera_zoom_max, _camera_zoom + OwnWar_Settings.mouse_scroll_sensitivity)
		get_tree().set_input_as_handled()
	elif event.is_action("combat_release_cursor"):
		set_mouse_mode()
	elif event.is_action_pressed("ui_cancel"):
		_gui.visible = true
		set_mouse_mode()


func _process(_delta: float) -> void:
	call_deferred("_set_camera")
	if player_vehicle_id < 0:
		_health_bar.value = 0
	else:
		var player_vehicle = vehicles[player_vehicle_id]
		if player_vehicle != null and player_vehicle.max_cost() > 0:
			_health_bar.value = player_vehicle.get_cost() / float(player_vehicle.max_cost())
		else:
			_health_bar.value = 0

	# Polling is a lot more reliable than _unhandled_input. No stuck keys or whatever
	if player_vehicle_id >= 0 and not _gui.visible:
		var player_vehicle = vehicles[player_vehicle_id]
		if player_vehicle != null:
			player_vehicle.turn_left = Input.is_action_pressed("combat_turn_left")
			player_vehicle.turn_right = Input.is_action_pressed("combat_turn_right")
			player_vehicle.pitch_up = Input.is_action_pressed("combat_pitch_up")
			player_vehicle.pitch_down = Input.is_action_pressed("combat_pitch_down")
			player_vehicle.move_forward = Input.is_action_pressed("combat_move_forward")
			player_vehicle.move_back = Input.is_action_pressed("combat_move_back")
			player_vehicle.fire = Input.is_action_pressed("combat_fire")
			player_vehicle.flip = Input.is_action_pressed("combat_flip_vehicle")


func _set_camera() -> void:
	if player_vehicle_id < 0:
		return
	var player_vehicle = vehicles[player_vehicle_id]
	if player_vehicle == null:
		return

	if old_player_vehicle != player_vehicle:
		# Add collision exceptions
		for n in Util.get_children_recursive(player_vehicle.get_node()) + [player_vehicle.get_node()]:
			if n is PhysicsBody:
				_camera_ray.add_exception(n)
				_camera_terrain_ray.add_exception(n)
				var e = n.connect("tree_exiting", _camera_ray, "remove_exception", [n])
				assert(e == OK)
				e = n.connect("tree_exiting", _camera_terrain_ray, "remove_exception", [n])
				assert(e == OK)
		old_player_vehicle = player_vehicle

	var basis := Basis(Vector3(0, 1, 0), _camera_pan) * \
		Basis(Vector3(1, 0, 0), _camera_tilt)
	var pos: Vector3 = player_vehicle.get_visual_origin() + camera_offset
	_camera_terrain_ray.translation = pos
	pos += basis * (Vector3(0, 0, _camera_zoom))

	_camera_terrain_ray.cast_to = pos - _camera_terrain_ray.translation
	_camera_terrain_ray.cast_to += _camera_terrain_ray.cast_to.normalized()
	_camera_terrain_ray.force_raycast_update()

	if _camera_terrain_ray.is_colliding():
		var r_pos := _camera_terrain_ray.get_collision_point()
		var r_normal := _camera_terrain_ray.get_collision_normal()
		var rel_pos := r_pos - pos
		if rel_pos.length_squared() < 0.25 or rel_pos.dot(r_normal) > 0:
			# Multiply factor determined by trial and error
			# I have no idea why 0.5 is "right"
			pos = r_pos - _camera_terrain_ray.cast_to.normalized() * 0.5

	_camera.transform = Transform(basis, pos)
	_camera_ray.force_raycast_update()
	
	var except_list = []
	while true:
		if _camera_ray.is_colliding():
			var col = _camera_ray.get_collider()
			var p = _camera_ray.get_collision_point()
			if col.has_meta("ownwar_vehicle_index"):
				var v = vehicles[col.get_meta("ownwar_vehicle_index")]
				var d = basis * _camera_ray.cast_to
				p = v.raycast(col.get_meta("ownwar_body_index"), p, d * 1000)
				if p != null:
					player_vehicle.aim_at = p
					break
				_camera_ray.add_exception(col)
				except_list.push_back(col)
				_camera_ray.force_raycast_update()
			else:
				player_vehicle.aim_at = p
				break
		else:
			player_vehicle.aim_at = _camera.transform * Vector3(0, 0, -10000000000)
			break
	for e in except_list:
		_camera_ray.remove_exception(e)


func set_player_vehicle(vehicle_id) -> void:
	player_vehicle_id = vehicle_id
	if vehicle_id < 0:
		return
	var v = vehicles[vehicle_id]
	if _camera_ray != null:
		var aabb: AABB = v.get_aabb()
		camera_offset.y = aabb.size.y * BLOCK_SCALE + 1

	if false: # TODO doesn't work with the raycast in _set_camera (intersect_ray pls)
		# Create exception list
		for c in Util.get_children_recursive(v.get_node()):
			if c is RigidBody:
				_camera_terrain_ray.add_exception(c)
				var e = c.connect("tree_exiting", self, "remove_camera_ray_exception")
				assert(e == OK)


func remove_camera_ray_exception(body):
	_camera_terrain_ray.remove_exception(body)


func set_mouse_mode() -> void:
	if _gui.visible or Input.is_action_pressed("combat_release_cursor"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mouse_filter = MOUSE_FILTER_PASS
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_filter = MOUSE_FILTER_IGNORE


func poll_input() -> void:
	if player_vehicle_id < 0:
		return
	var player_vehicle = vehicles[player_vehicle_id]
	if player_vehicle != null:
		if _gui.visible:
			player_vehicle.turn_left = false
			player_vehicle.turn_right = false
			player_vehicle.pitch_up = false
			player_vehicle.pitch_down = false
			player_vehicle.move_forward = false
			player_vehicle.move_back = false
			player_vehicle.fire = false
		else:
			player_vehicle.turn_left = Input.is_action_pressed("combat_turn_left")
			player_vehicle.turn_right = Input.is_action_pressed("combat_turn_right")
			player_vehicle.pitch_up = Input.is_action_pressed("combat_pitch_up")
			player_vehicle.pitch_down = Input.is_action_pressed("combat_pitch_down")
			player_vehicle.move_forward = Input.is_action_pressed("combat_move_forward")
			player_vehicle.move_back = Input.is_action_pressed("combat_move_back")
			player_vehicle.fire = Input.is_action_pressed("combat_fire")

func debug_draw():
	if player_vehicle_id < 0:
		return
	var player_vehicle = vehicles[player_vehicle_id]
	if player_vehicle != null:
		Debug.draw_point(player_vehicle.aim_at, Color.green, 0.13)
