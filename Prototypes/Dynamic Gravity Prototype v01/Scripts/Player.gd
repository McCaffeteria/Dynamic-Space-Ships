extends RigidBody3D

@onready var camera_first_person = $"AstronautRigged/Astronaut_Armature/Skeleton3D/Physical Bone Neck/CameraFirstPerson_fixer/CameraFirstPerson_joint/CameraFirstPerson"
@onready var camera_third_person = get_node("AstronautRigged/Astronaut_Armature/Skeleton3D/Physical Bone Head/CameraThirdPerson")
@onready var astronaut_rigged_head = get_node("AstronautRigged/Astronaut_Armature/Skeleton3D/Physical Bone Head")
@onready var astronaut_head_joint = $"AstronautRigged/Astronaut_Armature/Skeleton3D/Physical Bone Neck/CameraFirstPerson_fixer/CameraFirstPerson_joint"

#This whole section with speed modifiers is fucked, consoldate it once I figure out my final control scheme.
var move_speed = 3 #meters per second, average walking speed is 1.4
var look_speed = 1.5 #radians
var look_speed_mouse = .005 #multiplied with look speed.
var look_speed_controller = .1 #multiplied with look speed.
var input_multiplier = 100

var input_look = Vector2.ZERO
var input_move = Vector4.ZERO
var global_look_conversion = Vector3.ZERO
var basic_x_basis = Vector3(1, 0, 0)
var basic_y_basis = Vector3(0, 1, 0)
var basic_z_basis = Vector3(0, 0, 1)
var post_input_head_rotation = Vector3.ZERO #This is stored durring physics processing and is used later durring the idle process to reorient the camera after the physics has been calculated but before the frame is drawn.
var is_first_physics_process = true #This is set to be true during _process() in ppreperation for the next loop and is set false durring the first _physics_process() of the loop.

var input_dir = Vector3.ZERO
var output_dir_basis = Basis()
var output_dir = Vector3.ZERO
var input_rot = Vector3.ZERO
var output_rot_basis = Basis()
var output_rot = Vector3.ZERO
var output_rot_mouse_basis = Basis()
var output_rot_mouse = Vector3.ZERO

var current_gravity = Vector3.ZERO
var flight_assist = false
var max_flight_assist_force = input_multiplier * move_speed
var max_flight_assist_torque = input_multiplier * look_speed

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())
	self.position = get_node("../PlayerSpawnLocation").position

func _ready():
	if not is_multiplayer_authority(): return
	
	camera_first_person.current = true
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	if event is InputEventMouseMotion: #Mouse input handling
		#astronaut_rigged_head.rotate_y(-event.relative.x * look_speed_mouse) #Parent space, no conversion
		#astronaut_rigged_head.rotate(astronaut_rigged_head.transform.basis.x, (event.relative.y * look_speed_mouse)) #Converted fromt local space
		collect_mouse_input(event)

func _physics_process(delta):
	counter_rotate_player_head()
	print("Physics Process starting rotation: " + str(astronaut_head_joint.global_rotation))
	if not is_multiplayer_authority(): return
	
	current_gravity = get_node("..").calc_grav(self)
	#apply_central_force(current_gravity)
	
	if is_first_physics_process == true:
		collect_input_map()
		rotate_player_head_physics()
		
		is_first_physics_process = false
	
	rotate_player_body_toward_look_direction()
	
	#collect_input()
	#local_to_parent_input()
	
	#Calculate flight assist which includes aligning body to match head direction
	if flight_assist == true:
		calc_flight_assist()
			#flight assist towards head look angle, apply flight assist force, calculate/read new rotation, subtract that cahnge in flight assist rotation from the head bone rotation so that the head is in the same spot it started in before FA.
	
	#These forces are aplied from the rigid body's parent's refference.
	apply_central_force(output_dir)
	apply_torque(output_rot)

func _process(delta):
	if Input.is_action_just_pressed("change_camera"):
		toggle_camera()
	
	if Input.is_action_just_pressed("toggle_flight_assist"):
		toggle_flight_assist()
	
	print("Idle process starting rotation: " + str(astronaut_head_joint.global_rotation))
	#counter_rotate_player_head()
	
	#Clean up for next loop
	is_first_physics_process = true
	input_look = Vector2.ZERO
	input_move = Vector4.ZERO

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

func collect_input(): #Old
	#These vectors are measured from the rigid body's local refference.
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

func collect_mouse_input(mouse_movement):
	input_look.x -= mouse_movement.relative.x * look_speed_mouse
	input_look.y -= mouse_movement.relative.y * look_speed_mouse
	#Mouse input: Up is posotive Y, Left is positive X (for some ungodly reason)
	#Game orientation: Up is positive Y, Left is NEGATIVE X

func collect_input_map():
	input_look.x -= Input.get_action_strength("look_right") * look_speed_controller
	input_look.x += Input.get_action_strength("look_left") * look_speed_controller
	input_look.y -= Input.get_action_strength("look_down") * look_speed_controller
	input_look.y += Input.get_action_strength("look_up") * look_speed_controller
	
	input_move.x -= Input.get_action_strength("move_left")
	input_move.x += Input.get_action_strength("move_right")
	input_move.y -= Input.get_action_strength("move_down")
	input_move.y += Input.get_action_strength("move_up")
	input_move.z -= Input.get_action_strength("move_forward")
	input_move.z += Input.get_action_strength("move_backward")
	input_move.w -= Input.get_action_strength("roll_right")
	input_move.w += Input.get_action_strength("roll_left")

func rotate_player_head_physics():
	global_look_conversion = Vector3.ZERO
	basic_x_basis = Vector3(1, 0, 0)
	basic_y_basis = Vector3(0, 1, 0)
	basic_z_basis = Vector3(0, 0, 1)
	
	#Rotate Y
	global_look_conversion = Vector3(input_look.y, input_look.x, 0).rotated(basic_y_basis, astronaut_head_joint.global_rotation.y)
	basic_x_basis = basic_x_basis.rotated(basic_y_basis, astronaut_head_joint.global_rotation.y)
	basic_z_basis = basic_z_basis.rotated(basic_y_basis, astronaut_head_joint.global_rotation.y)
	#Rotate X
	global_look_conversion = global_look_conversion.rotated(basic_x_basis, astronaut_head_joint.global_rotation.x)
	basic_z_basis = basic_z_basis.rotated(basic_x_basis, astronaut_head_joint.global_rotation.x)
	#Rotate Z
	global_look_conversion = global_look_conversion.rotated(basic_z_basis, astronaut_head_joint.global_rotation.z)
	#Execute
	astronaut_head_joint.global_rotate(global_look_conversion.normalized(), global_look_conversion.length())
	#At this point I have a 3D vector in global coordinates who's direction represents the axis that the camera rotates around and who's magnitude repsents the amount to rotate. This might be better off using the .global_rotate() method but I'm not sure. It might only work now because the player's body is always aligned with the global coordinates.
	
	post_input_head_rotation = astronaut_head_joint.global_rotation #This is being saved so that I can refference it next frame.
	print("Post input rotation: " + str(astronaut_head_joint.global_rotation))
	
	#The YXZ-Euler rotation is a series of local rotations, so I need to generate a few Basis vectors and rotate them as well in order to have local axis refferences while I'm mid-rotation. The built in object basis parameters are all post rotation which is unhelpful here.
	#Normally when I rotate the input by 90 degrees i would invert the x values, but x is ALREADY backwards in mouse input so they are both positive here.
	#The local vector that represents the torque vector I want to rotate the head and body along is calulated by rotating the input vector 90 degrees clockwise (based on the right hand rule, double check that this is correct later)
	#The global_rotation property of the head tells me the amount i need to rotate the local vector by to "line up" with the head. The global_rotation property is defined in YXZ-Euler angles, so I rotate the input vector by each of those steps in order to get the gloabl input vector.
	#The gloabl input vector is now the "global axis" that I want to rotate the head around. I will need to use a normalized version of it to rotate around, and I will need to rotate it by it's magnitude.
	pass

func rotate_player_body_toward_look_direction():
	#Check whether the body matches the head global rotation, and if not then rotate the body towards it.
	#I think this will apply torque in "parent space" which is technically different to global space. Keep in mind that if I ever put this in a scene where the player's parent object is rotated then this code will not work because I'm checking against the gloabl rotation and applying parent rotation. If the parent isn't globally aligned then it will just rotate forever the wrong way.
	
	#This assumes the camera node and the player body node are both facing the same exact direction globally by default, which I think I made sure was the case.
	if (astronaut_head_joint.rotation.y > .005) or (astronaut_head_joint.rotation.y < -.005):
		self.apply_torque(Vector3(0, astronaut_head_joint.rotation.y, 0))
	if (astronaut_head_joint.rotation.x > .005) or (astronaut_head_joint.rotation.x < -.005):
		self.apply_torque(Vector3(astronaut_head_joint.rotation.x, 0, 0))
	if (astronaut_head_joint.rotation.z > .005) or (astronaut_head_joint.rotation.z < -.005):
		self.apply_torque(Vector3(0, 0, astronaut_head_joint.rotation.z))
	#These are over rotating, probably because I'm not doing them stepwise and they overlap a bit. Either that or because they need deceleration forces.
	#What I actually need is an activation function that defines a target velocity at any given rotation and calculates the difference in actual vs target velocity and then applies a force based on that difference.

func counter_rotate_player_head():
	astronaut_head_joint.set_global_rotation(post_input_head_rotation)

func local_to_parent_input(): #Old
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
