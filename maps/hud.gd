extends Control


const HealthBar := preload("health_circle.gd")

export var camera: NodePath
export var camera_rotate_speed := 1.0
export(float, 0.1, 10.0) var camera_zoom_speed := 1.0
export(float, 0.0, 100.0) var camera_zoom_min := 5.0
export(float, 0.0, 100.0) var camera_zoom_max := 10.0
export var camera_offset := Vector3()
var player_vehicle: OwnWar_Vehicle setget set_player_vehicle

var _camera_pan := 0.0
var _camera_tilt := 0.0
var _camera_ray := RayCast.new()
var _camera_terrain_ray := RayCast.new()
onready var _camera_zoom := (camera_zoom_min + camera_zoom_max) / 2
onready var _camera: Camera = get_node(camera)
onready var _gui: Control = get_node("../GUI")
onready var _health_bar: HealthBar = get_node("Health")


func _ready() -> void:
	set_mouse_mode()
	_camera_ray.cast_to = Vector3(0, 0, -100000)
	_camera.add_child(_camera_ray)
	_camera_ray.transform = Transform.IDENTITY
	_camera.add_child(_camera_terrain_ray)
	_camera_terrain_ray.set_as_toplevel(true)
	_camera_terrain_ray.transform = Transform.IDENTITY
	_camera_terrain_ray.cast_to = Vector3(0, -1000, 0)


func _unhandled_input(event: InputEvent) -> void:
	if _gui.visible:
		return
	var mouse_event := event as InputEventMouseMotion
	if mouse_event != null:
		_camera_pan -= mouse_event.relative.x * camera_rotate_speed / 100
		_camera_tilt -= mouse_event.relative.y * camera_rotate_speed / 100
		_camera_pan = fposmod(_camera_pan, 2 * PI)
		_camera_tilt = clamp(_camera_tilt, -PI / 2, PI / 2)
		get_tree().set_input_as_handled()
	elif event.is_action_pressed("combat_zoom_in"):
		_camera_zoom = max(camera_zoom_min, _camera_zoom - camera_zoom_speed)
		get_tree().set_input_as_handled()
	elif event.is_action_pressed("combat_zoom_out"):
		_camera_zoom = min(camera_zoom_max, _camera_zoom + camera_zoom_speed)
		get_tree().set_input_as_handled()
	elif event.is_action("combat_release_cursor"):
		set_mouse_mode()
	elif event.is_action_pressed("ui_cancel"):
		_gui.visible = true
		set_mouse_mode()
	elif player_vehicle != null:
		if event.is_action("combat_turn_left"):
			player_vehicle.controller.turn_left = event.is_pressed()
		elif event.is_action("combat_turn_right"):
			player_vehicle.controller.turn_right = event.is_pressed()
		elif event.is_action("combat_pitch_up"):
			player_vehicle.controller.pitch_up = event.is_pressed()
		elif event.is_action("combat_pitch_down"):
			player_vehicle.controller.pitch_down = event.is_pressed()
		elif event.is_action("combat_move_forward"):
			player_vehicle.controller.move_forward = event.is_pressed()
		elif event.is_action("combat_move_back"):
			player_vehicle.controller.move_back = event.is_pressed()
		elif event.is_action("combat_fire"):
			player_vehicle.controller.fire = event.is_pressed()
		elif event.is_action("combat_flip_vehicle"):
			player_vehicle.controller.flip = event.is_pressed()



func _process(_delta: float) -> void:
	call_deferred("_set_camera")
	if player_vehicle != null and player_vehicle.max_cost > 0:
		_health_bar.value = player_vehicle.get_cost() / float(player_vehicle.max_cost)
	else:
		_health_bar.value = 0


func _set_camera() -> void:
	if player_vehicle == null:
		return
	var basis := Basis(Vector3(0, 1, 0), _camera_pan) * \
		Basis(Vector3(1, 0, 0), _camera_tilt)
	var pos := player_vehicle.get_visual_origin()
	pos += basis * (Vector3(0, 0, _camera_zoom) + camera_offset)
	_camera_terrain_ray.translation = pos + Vector3(0, 500, 0)
	_camera_terrain_ray.force_raycast_update()
	if _camera_terrain_ray.is_colliding():
		var r_pos := _camera_terrain_ray.get_collision_point()
		var r_normal := _camera_terrain_ray.get_collision_normal()
		var rel_pos := r_pos - pos
		if rel_pos.length_squared() < 0.25 or rel_pos.dot(r_normal) > 0:
			pos = r_pos + Vector3(0, 0.5, 0)
	_camera.transform = Transform(basis, pos)
	_camera_ray.force_raycast_update()
	if _camera_ray.is_colliding():
		player_vehicle.controller.aim_at = _camera_ray.get_collision_point()
	else:
		player_vehicle.controller.aim_at = _camera.transform * Vector3(0, 0, -10000000000)


func set_player_vehicle(p_vehicle) -> void:
	player_vehicle = p_vehicle
	if p_vehicle == null:
		return
	if _camera_ray != null:
		for body in Util.get_children_recursive(player_vehicle):
			if body is PhysicsBody:
				_camera_ray.add_exception(body)
				_camera_terrain_ray.add_exception(body)
		var aabb := player_vehicle.get_aabb()
		camera_offset.y = aabb.size.y * 1.5 * OwnWar_Block.BLOCK_SCALE
		camera_offset.z = aabb.size.z * 0.5 * OwnWar_Block.BLOCK_SCALE


func set_mouse_mode() -> void:
	if _gui.visible or Input.is_action_pressed("combat_release_cursor"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mouse_filter = MOUSE_FILTER_PASS
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		mouse_filter = MOUSE_FILTER_IGNORE


func poll_input() -> void:
	if player_vehicle != null:
		if _gui.visible:
			player_vehicle.controller.turn_left = false
			player_vehicle.controller.turn_right = false
			player_vehicle.controller.pitch_up = false
			player_vehicle.controller.pitch_down = false
			player_vehicle.controller.move_forward = false
			player_vehicle.controller.move_back = false
			player_vehicle.controller.fire = false
		else:
			player_vehicle.controller.turn_left = Input.is_action_pressed("combat_turn_left")
			player_vehicle.controller.turn_right = Input.is_action_pressed("combat_turn_right")
			player_vehicle.controller.pitch_up = Input.is_action_pressed("combat_pitch_up")
			player_vehicle.controller.pitch_down = Input.is_action_pressed("combat_pitch_down")
			player_vehicle.controller.move_forward = Input.is_action_pressed("combat_move_forward")
			player_vehicle.controller.move_back = Input.is_action_pressed("combat_move_back")
			player_vehicle.controller.fire = Input.is_action_pressed("combat_fire")
