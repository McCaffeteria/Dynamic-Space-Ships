extends RigidBody3D

@onready var camera_first_person = $"AstronautRigged/Astronaut_Armature/Skeleton3D/Physical Bone Neck/CameraFirstPerson_fixer/CameraFirstPerson_joint/CameraFirstPerson"
@onready var camera_third_person = get_node("AstronautRigged/Astronaut_Armature/Skeleton3D/Physical Bone Head/CameraThirdPerson")
@onready var astronaut_rigged_head = get_node("AstronautRigged/Astronaut_Armature/Skeleton3D/Physical Bone Head")
@onready var astronaut_head_joint = $"AstronautRigged/Astronaut_Armature/Skeleton3D/Physical Bone Neck/CameraFirstPerson_fixer/CameraFirstPerson_joint"

var process_delta = 0
var process_delta_previous = 0
var physics_process_delta = 0
var physics_process_delta_previous = 0
var self_rotation = Vector3.ZERO
var self_rotation_previous = Vector3.ZERO

var first_frame = true

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

#used in player_body_look_activation_function() to set the turn-to-face activation force.
var body_rotation_activation_scaler = 10
var body_rotation_activation_threshold = .005

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
	physics_process_delta_previous = physics_process_delta
	physics_process_delta_previous = delta
	self_rotation_previous = self_rotation
	self_rotation = self.get_global_rotation()
	
	if first_frame == true:
		self.set_angular_velocity(Vector3(0, 0, 1))
		first_frame = false
	
	counter_rotate_player_head()
	
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
	process_delta_previous = process_delta
	process_delta = delta
	
	if Input.is_action_just_pressed("change_camera"):
		toggle_camera()
	
	if Input.is_action_just_pressed("toggle_flight_assist"):
		toggle_flight_assist()
	
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
	
	#The YXZ-Euler rotation is a series of local rotations, so I need to generate a few Basis vectors and rotate them as well in order to have local axis refferences while I'm mid-rotation. The built in object basis parameters are all post rotation which is unhelpful here.
	#Normally when I rotate the input by 90 degrees i would invert the x values, but x is ALREADY backwards in mouse input so they are both positive here.
	#The local vector that represents the torque vector I want to rotate the head and body along is calulated by rotating the input vector 90 degrees clockwise (based on the right hand rule, double check that this is correct later)
	#The global_rotation property of the head tells me the amount i need to rotate the local vector by to "line up" with the head. The global_rotation property is defined in YXZ-Euler angles, so I rotate the input vector by each of those steps in order to get the gloabl input vector.
	#The gloabl input vector is now the "global axis" that I want to rotate the head around. I will need to use a normalized version of it to rotate around, and I will need to rotate it by it's magnitude.
	pass

func rotate_player_body_toward_look_direction():
	var perpendicular_vector_x = self.basis.x - astronaut_head_joint.basis.x
	var perpendicular_vector_y = self.basis.y - astronaut_head_joint.basis.y
	var midpoint_vector_x = astronaut_head_joint.basis.x.slerp(self.basis.x, .5)
	var midpoint_vector_y = astronaut_head_joint.basis.y.slerp(self.basis.y, .5)
	#var circle_vector_x = perpendicular_vector_x.rotated(midpoint_vector_x, .5 * PI)
	#var circle_vector_y = perpendicular_vector_y.rotated(midpoint_vector_y, .5 * PI)
	var intersection_vector = perpendicular_vector_x.cross(perpendicular_vector_y) #This is my axis of rotation that will get me where I want, but I don't know how far to rotate.
	
	#If the angle between midpoint_vector and intersection_vector is 0 or 180 then the required rotation is 180 degrees. If the angle is 90 degrees then the required rotation is the angle between self.basis and astronaut_head_joint.basis. The true required rotation is somewhere inbetween.
	#self.basis + (.5 * perpendicular_vector) to (0,0) forms the hypotanuse of a right triangle. The angle between intersection_vector and midpoint_vector is one of the two remaining angles, and the third can just be calculated. Since I know the hypotenuse and all of the angles I can calculate the length of the side that aligns with intersection_vector and simply normalize then multiply that vector by the length to get the vector for that triangle edge. The vectors pointing from that point to self.basis and to astronaut_head_joint then give me the angle I need to rotate.
	var intersection_vector_short = intersection_vector.normalized() * (self.basis.x + (.5 * perpendicular_vector_x)).length() * cos(intersection_vector.angle_to(midpoint_vector_x))
	var intersect_short_to_self_x = self.basis.x - intersection_vector_short
	var intersect_short_to_head_x = astronaut_head_joint.basis.x - intersection_vector_short
	var final_rotation = intersection_vector.normalized() * intersect_short_to_self_x.angle_to(intersect_short_to_head_x)
	print("Body look vector: " + str(final_rotation) + " " + str(final_rotation.length()))
	
	#I still need to calculate the current vector of angular velocity. It should be the same process, except I may have to save the state each frame and freer to that to do the calculation. Once I have it I have to subtract it somehow from my target angular velocity.
	var global_vector_x = Vector3(1, 0, 0)
	var global_vector_y = Vector3(0, 1, 0)
	var global_vector_z = Vector3(0, 0, 1)
	var self_basis_previous = Basis(global_vector_x, global_vector_y, global_vector_z)
	self_basis_previous.x = self_basis_previous.x.rotated(global_vector_y, self_rotation_previous.y)
	self_basis_previous.y = self_basis_previous.y.rotated(global_vector_y, self_rotation_previous.y)
	self_basis_previous.z = self_basis_previous.z.rotated(global_vector_y, self_rotation_previous.y)
	self_basis_previous.x = self_basis_previous.x.rotated(global_vector_x, self_rotation_previous.x)
	self_basis_previous.y = self_basis_previous.y.rotated(global_vector_x, self_rotation_previous.x)
	self_basis_previous.z = self_basis_previous.z.rotated(global_vector_x, self_rotation_previous.x)
	self_basis_previous.x = self_basis_previous.x.rotated(global_vector_z, self_rotation_previous.z)
	self_basis_previous.y = self_basis_previous.y.rotated(global_vector_z, self_rotation_previous.z)
	self_basis_previous.z = self_basis_previous.z.rotated(global_vector_z, self_rotation_previous.z)
	var perpendicular_vector_x_previous = self_basis_previous.x - self.basis.x
	var perpendicular_vector_y_previous = self_basis_previous.y - self.basis.y
	var midpoint_vector_x_previous = self.basis.x.slerp(self_basis_previous.x, .5)
	var midpoint_vector_y_previous = self.basis.y.slerp(self_basis_previous.x, .5)
	var intersection_vector_previous = perpendicular_vector_x_previous.cross(perpendicular_vector_y_previous) #This is the axis of rotation
	print("perpendicular_vector_x_previous: " + str(perpendicular_vector_x_previous))
	print("perpendicular_vector_y_previous: " + str(perpendicular_vector_y_previous))
	print("intersection_vector_previous: " + str(intersection_vector_previous))
	var intersection_vector_short_previous = intersection_vector_previous.normalized() * (self_basis_previous.x + (.5 * perpendicular_vector_x_previous)).length() * cos(intersection_vector_previous.angle_to(midpoint_vector_x_previous))
	var intersect_short_to_past_x_previous = self_basis_previous.x - intersection_vector_short_previous
	var intersect_short_to_present_x_previous = self.basis.x - intersection_vector_short_previous
	print("intersect_short_to_past_x_previous.angle_to: " + str(intersect_short_to_past_x_previous.angle_to(intersect_short_to_present_x_previous)))
	print("intersection_vector_previous: " + str(intersection_vector_previous))
	var final_rotation_previous = intersection_vector_previous.normalized() * intersect_short_to_past_x_previous.angle_to(intersect_short_to_present_x_previous) #This is the axis of rotation and it's magnitude is the rotation angle in radians.
	print("Current angular vector: " + str(final_rotation_previous) + " " + str(final_rotation_previous.length()))
	
	#Once I have the current rotational angle and the target rotation, I need to combine them. I should be able to just subtract the past vector from the other and the result is what I want.
	final_rotation = final_rotation - final_rotation_previous
	print("Final torque vector: " + str(final_rotation) + " " + str(final_rotation.length()))
	
	#Once I have the required angle I need to rotate I can use that to calculate how much force to use. I can use some sort of lerp function where I take a fraction of the remaining angle and try to accelerate or decelerate the body to that value. I can tweak the feeling of the body look by picking a different fraction for the lerp function, as well as implementing a max force value. I might also multiply the angle by some value so that the target speed is something specific in the case where the rotation is 180 degrees.
	var body_look_angular_velocity_multiplier = 1
	var body_look_lerp_fraction = .5
	var body_look_max_force = 150
	var final_torque_vector = final_rotation * body_look_angular_velocity_multiplier * body_look_lerp_fraction
	if final_torque_vector.length() > body_look_max_force:
		final_torque_vector = final_torque_vector.normalized() * body_look_max_force
	
	self.apply_torque(final_torque_vector.normalized() * 100)
	pass

func rotate_player_body_toward_look_direction_OLD2():
	#Because of Godot's weird axes, this is actually manipulating the BACK of the player and camera since "forward" is -Z
	
	#Calculate rotation from tips, which I will rotate the interpolated vector around.
	var tip_vector = self.basis.z - astronaut_head_joint.basis.z #This vector points FROM self TO head, but offset onto the origin.
	print("Tip vector length: " + str(tip_vector.length()))
	if tip_vector.length() > body_rotation_activation_threshold:
		#Calculate the interpolated vector.
		var interpolated_vector = astronaut_head_joint.basis.z.slerp(self.basis.z, .5)
		print("Self basis: " + str(self.basis.z))
		print("Slerp vector: " + str(interpolated_vector))
		print("Head basis: " + str(astronaut_head_joint.basis.z))
		#Rotate the interpolated vector 90 degrees around the tip vector.
		interpolated_vector = interpolated_vector.rotated(tip_vector.normalized(), .5 * PI) #Fucking radians
		print("rotated vector: " + str(interpolated_vector))
		#Set the interpolated vector's magnitude to be poportional to the angle between starting and target vectors.
		interpolated_vector = interpolated_vector * (astronaut_head_joint.basis.z.angle_to(self.basis.z)/interpolated_vector.length())
		
		#Assuming the interpolated vector's magnitude is the speed I want to be rotating, calculate the difference between it and the current angular velocity, and then apply that as torque.
		self.apply_torque(interpolated_vector - self.get_angular_velocity())
	pass

func rotate_player_body_toward_look_direction_OLD():
	#Check whether the body matches the head global rotation, and if not then rotate the body towards it.
	#I think this will apply torque in "parent space" which is technically different to global space. Keep in mind that if I ever put this in a scene where the player's parent object is rotated then this code will not work because I'm checking against the gloabl rotation and applying parent rotation. If the parent isn't globally aligned then it will just rotate forever the wrong way.
	
	var body_torque_output = Vector3((astronaut_head_joint.rotation.x * body_rotation_activation_scaler) - self.angular_velocity.x, (astronaut_head_joint.rotation.y * body_rotation_activation_scaler) - self.angular_velocity.y, (astronaut_head_joint.rotation.z * body_rotation_activation_scaler) - self.angular_velocity.z)
	
	print("Difference in actual vs target velocity: " + str(body_torque_output))
	
	#This assumes the camera node and the player body node are both facing the same exact direction globally by default, which I think I made sure was the case.
	if (body_torque_output.y > body_rotation_activation_threshold) or (body_torque_output.y < -body_rotation_activation_threshold): #Used to be .005
		self.apply_torque(Vector3(0, body_torque_output.y, 0))
	if (body_torque_output.x > body_rotation_activation_threshold) or (body_torque_output.x < -body_rotation_activation_threshold):
		self.apply_torque(Vector3(body_torque_output.x, 0, 0))
	if (body_torque_output.z > body_rotation_activation_threshold) or (body_torque_output.z < -body_rotation_activation_threshold):
		self.apply_torque(Vector3(0, 0, body_torque_output.z))
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
