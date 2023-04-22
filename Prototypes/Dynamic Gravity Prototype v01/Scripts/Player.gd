extends RigidBody3D

func _physics_process(delta):
	apply_central_force(get_node("..").calc_grav(self))
