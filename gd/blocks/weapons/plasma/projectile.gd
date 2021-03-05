extends Spatial


const GRAVITY = 9.81
var velocity := Vector3()

export var explosion: PackedScene

var damage := 500
var radius := 3
var team := -1

func _physics_process(delta: float) -> void:
	var old_tr := translation
	translation += velocity * delta
	velocity.y -= GRAVITY * delta

	var state := get_world().direct_space_state
	var result := state.intersect_ray(old_tr, translation)
	if len(result) > 0:
		var collider = result["collider"]
		var pos: Vector3 = result["position"]
		# GODOT PLS
		#if collider is OwnWar_VoxelBody:
		if collider.has_method("apply_explosion_damage") and collider.get("team") != team:
			collider.apply_explosion_damage(pos, radius, damage)
		explode(pos)


func explode(position: Vector3) -> void:
	queue_free()
	var n: Spatial = explosion.instance()
	n.translation = position
	get_tree().current_scene.add_child(n)
