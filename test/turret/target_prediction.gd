tool
extends ImmediateGeometry


export var velocity := 10.0
export var gravity := 9.81
export var time_step := 0.02


func _process(_delta):
	clear()
	
	begin(Mesh.PRIMITIVE_LINES)
	set_color(Color.red)
	add_vertex(Vector3.ZERO)
	add_vertex($Target.translation)
	end()
	
	var target_position = $Target.translation
	var distance_xz = Vector2(target_position.x, target_position.z).length()
	var distance_y = target_position.y
	var normal_xz = target_position
	normal_xz.y = 0
	normal_xz = normal_xz.normalized()
	
	var x = distance_xz
	var y = distance_y
	var v2 = velocity * velocity
	var g = gravity
	
	var angle = atan2(v2 - sqrt(v2 * v2 - g * (g * x * x + 2 * y * v2)), g * x)

	var projectile_velocity = Vector3(cos(angle) * normal_xz.x, sin(angle),
			cos(angle) * normal_xz.z) * velocity
	var projectile_position = Vector3.ZERO
	
	begin(Mesh.PRIMITIVE_LINES)
	set_color(Color.cyan)
	add_vertex(projectile_position)
	add_vertex(projectile_velocity)
	end()

	begin(Mesh.PRIMITIVE_LINE_STRIP)
	set_color(Color.lightgreen)
	for i in range(int(2.0 / time_step)):
		add_vertex(projectile_position)
		projectile_velocity.y -= gravity * time_step / 2
		projectile_position += projectile_velocity * time_step
		projectile_velocity.y -= gravity * time_step / 2
	end()
