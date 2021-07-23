extends "turret.gd"


func _init():
	anchor_mounts = PoolVector3Array([
		Vector3(0, 1, 0),
		Vector3(1, 1, 0),
		Vector3(-1, 1, 0),
		Vector3(0, 1, 1),
		Vector3(0, 1, -1),
		Vector3(1, 1, 1),
		Vector3(1, 1, -1),
		Vector3(-1, 1, 1),
		Vector3(-1, 1, -1),
	])
