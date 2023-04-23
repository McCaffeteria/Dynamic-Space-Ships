extends RigidBody3D

@onready var camera_first_person = $CameraFirstPerson
@onready var camera_third_person = $CameraThirdPerson

var move_speed = 3 #meters per second, average walking speed is 1.4
var look_speed = 1.5 #radians
var input_multiplier = 100

var input_dir = Vector3.ZERO
var output_dir_basis = Basis()
var output_dir = Vector3.ZERO
var input_rot = Vector3.ZERO
var output_rot_basis = Basis()
var output_rot = Vector3.ZERO

var current_gravity = Vector3.ZERO
var flight_assist = false
var max_flight_assist_force = input_multiplier * move_speed
var max_flight_assist_torque = input_multiplier * look_speed

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	self.position = get_node("../PlayerSpawnLocation").position

func _ready():
	if not is_multiplayer_authority(): return
	
	camera_third_person.current = true
	
func _process(delta):
	if Input.is_action_just_pressed("change_camera"):
		toggle_camera()
	
	if Input.is_action_just_pressed("toggle_flight_assist"):
		toggle_flight_assist()

func _physics_process(delta):
	if not is_multiplayer_authority(): return
	
	current_gravity = get_node("..").calc_grav(self)
	apply_central_force(current_gravity)
	
	collect_input()
	
	local_to_parent_input()
	
	if flight_assist == true:
		calc_flight_assist()
	
	#parent refference
	apply_central_force(output_dir)
	apply_torque(output_rot)

func toggle_camera():
	if camera_first_person.current == true:
		camera_third_person.current = true
		camera_first_person.current = false
	else:
		camera_first_person.current = true
		camera_third_person.current = false

func toggle_flight_assist():
	if flight_assist == true:
		flight_assist = false
		print("Flight assst off.")
	else:
		flight_assist = true
		print("Flight assst on.")

func collect_input():
	#Local refference
	input_dir = Vector3.ZERO
	input_rot = Vector3.ZERO
	input_dir.x -= Input.get_action_strength("move_left")
	input_dir.x += Input.get_action_strength("move_right")
	input_dir.y -= Input.get_action_strength("move_down")
	input_dir.y += Input.get_action_strength("move_up")
	input_dir.z -= Input.get_action_strength("move_forward")
	input_dir.z += Input.get_action_strength("move_backward")
	input_dir = input_dir * move_speed * input_multiplier
	input_rot.x -= Input.get_action_strength("look_down")
	input_rot.x += Input.get_action_strength("look_up")
	input_rot.y -= Input.get_action_strength("look_right")
	input_rot.y += Input.get_action_strength("look_left")
	input_rot.z -= Input.get_action_strength("roll_right")
	input_rot.z += Input.get_action_strength("roll_left")
	input_rot = input_rot * look_speed * input_multiplier

func local_to_parent_input():
	#Converts from local to parent space
	output_dir_basis.x = input_dir.x * transform.basis.x
	output_dir_basis.y = input_dir.y * transform.basis.y
	output_dir_basis.z = input_dir.z * transform.basis.z
	output_dir = output_dir_basis.x + output_dir_basis.y + output_dir_basis.z
	output_rot_basis.x = input_rot.x * transform.basis.x
	output_rot_basis.y = input_rot.y * transform.basis.y
	output_rot_basis.z = input_rot.z * transform.basis.z
	output_rot = output_rot_basis.x + output_rot_basis.y + output_rot_basis.z

func calc_flight_assist():
	output_dir = output_dir - current_gravity - (self.linear_velocity * 60)
	if output_dir.length() > max_flight_assist_force:
		output_dir = output_dir.limit_length(max_flight_assist_force)
	
	output_rot = output_rot - (self.angular_velocity * 60)
	if output_rot.length() > max_flight_assist_torque:
		output_rot = output_rot.limit_length(max_flight_assist_torque)
