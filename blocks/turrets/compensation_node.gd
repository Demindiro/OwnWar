extends Spatial
class_name PhysicsJointCompensationNode


export var tracking_node_path := NodePath() setget set_node_path
var translation_delta: Vector3
var rotation_delta: Basis
var rotation_delta_angle: float
var last_transform: Transform
var transform_delta: Transform
var last_angular_velocity: Vector3
var last_linear_velocity: Vector3
var angular_velocity_delta: Vector3
var linear_velocity_delta: Vector3

var _tracking_node: PhysicsBody


func _notification(what: int) -> void:
	if what == NOTIFICATION_INTERNAL_PHYSICS_PROCESS and _tracking_node != null:
		var body := PhysicsServer.body_get_direct_state(_tracking_node.get_rid())
		var current_transform := body.transform
		transform_delta = last_transform.affine_inverse() * current_transform;

		rotation_delta_angle = Util.get_rotation_angle(transform_delta.basis)

		last_transform = current_transform

		var current_angular_velocity := body.angular_velocity
		var current_linear_velocity := body.linear_velocity

		angular_velocity_delta = current_angular_velocity - last_angular_velocity;
		linear_velocity_delta = current_linear_velocity - last_linear_velocity;

		last_angular_velocity = current_angular_velocity;
		last_linear_velocity = current_linear_velocity;



func set_node_path(p_value: NodePath) -> void:
	if tracking_node_path == p_value:
		return
	tracking_node_path = p_value
	_tracking_node = get_node_or_null(p_value)
	set_physics_process_internal(_tracking_node != null);
