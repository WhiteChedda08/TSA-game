extends CharacterBody3D

# Player pivots
@onready var nek: Node3D = $nek
@onready var head: Node3D = $nek/head
@onready var eyes: Node3D = $nek/head/eyes
@onready var camera: Camera3D = $nek/head/eyes/camera

# Animation Stuff

# Crouchng stuff
@onready var crouching_collision: CollisionShape3D = $Crouching_collision
@onready var standing_collision: CollisionShape3D = $Standing_collision
@onready var ray_cast_3d: RayCast3D = $RayCast3D

# Different stuff
const minimum_speed = 2.0
const maximum_speed = 100.0 #this is the true max speed, cool stuff can increase it maybe
var speed
var current_speed = 0.0
var acceleration = 20.0
const CROUCH_SPEED = 3.0
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const SENS = 0.005
var CROUCHING_DEBTH = -0.5
var free_look_tilt_amount = 5
var direction = Vector3.ZERO
var head_position = Vector3.ZERO
# States
var walking = false
var sprinting = false
var crouching = false
var free_looking = false
var sliding = false
var idle = true

# Slide vars
var slide_timer = 0.0
var slide_timer_max = 1.0
var slide_vector = Vector3.ZERO
var slide_speed = 13.0

# Double jump vars
const POSSIBLE_JUMPS = 2
var currentJumpCount = 0

# Head bob variables
const headbob_vars = {
	sprinting = {
		speed =  22.0,
		intensity = 0.2
	},
	walking = {
		speed =  14.0,
		intensity = 0.1
	},
	crouching = {
		speed =  10.0,
		intensity = 0.05
	},
}
#use this table for assigning the motion 
var motion = {
	velocity = {
		local = Vector3.ZERO, #this is velocity relative to the player and camera rotation
		global = Vector3.ZERO, #this is velocity relative to the world
	},
	direction = {
		local = Vector3.ZERO, #this is direction relative to the player and camera rotation
		global = Vector3.ZERO, #this is direction relative to the world
	}
}
var friction = {
	floor = 20.0, #speed reduction when moving
	air = 1.0, #speed reduction when in the air 
}
#held keys for stuff
var held_keys = {}

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbing_current_intensity = 0.0

#coyote time
var coyote_time_delta = 0.0
const coyote_time_value = 0.15

#fov variables
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

# Eliminate Mouse
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	head_position = head.position
# Move Camera
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		if free_looking:
			nek.rotate_y(-event.relative.x * SENS)
		else:
			head.rotate_y(-event.relative.x * SENS)
			camera.rotate_x(-event.relative.y * SENS)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))	

func _input(event):
	if event is InputEventKey: #on press
		if event.pressed:
			held_keys[event.keycode] = true
			if event.keycode == game.settings.keybinds.jump:
				on_jump()
		else:
			held_keys[event.keycode] = false
			if event.keycode == game.settings.keybinds.crouch:
				if sliding:
					exit_slide()
			
#this function returns the current movement type of the player based on the movement variables
func get_movement_type() -> String:
	if sprinting:
		return "sprinting"
	elif crouching:
		return "crouching"
	return "walking"
	
func free_look(delta:float):
	if Input.is_action_pressed("free_look") || sliding:
		free_looking = true

		nek.rotation.y = clamp(nek.rotation.y, deg_to_rad(-120), deg_to_rad(120))
		if sliding:
			eyes.rotation.z =  lerp(eyes.rotation.z, -deg_to_rad(6.5), delta * 7.0)
		else: 
			eyes.rotation.z =  -deg_to_rad(nek.rotation.y * free_look_tilt_amount)
	else: 
		free_looking = false
		nek.rotation.y = lerp(nek.rotation.y,0.0, delta * 6.0)
		eyes.rotation.z = lerp(camera.rotation.y,0.0, delta * 6.0)
	
#do spongbob
func headbob(delta:float, input_dir:Vector2):
	var movement_type = get_movement_type()
	var final_headbob_location = Vector2.ZERO
	head_bobbing_current_intensity = headbob_vars[movement_type].intensity
	head_bobbing_index += headbob_vars[movement_type].speed * delta
	head_bobbing_vector.y = sin(head_bobbing_index)
	head_bobbing_vector.x = sin(head_bobbing_index/2)+0.5
	if is_on_floor() && !sliding && input_dir != Vector2.ZERO:
		final_headbob_location.y = head_bobbing_vector.y * (head_bobbing_current_intensity / 2.0)
		final_headbob_location.x = head_bobbing_vector.x * head_bobbing_current_intensity
	eyes.position.y = lerp(eyes.position.y, final_headbob_location.y, delta * 10.0)
	eyes.position.x = lerp(eyes.position.x, final_headbob_location.x, delta * 10.0)

func exit_slide():
	sliding = false
	free_looking = false
	slide_vector = Vector3.ZERO

func get_current_input_direction()->Vector2:
	var vec = Vector2()
	if held_keys.get(game.settings.keybinds.right, false):
		vec.x += 1
	if held_keys.get(game.settings.keybinds.left, false):
		vec.x -= 1
	if held_keys.get(game.settings.keybinds.backward, false):
		vec.y += 1
	if held_keys.get(game.settings.keybinds.forward, false):
		vec.y -= 1
	return vec.normalized()
func set_movement_state(delta:float, input_dir:Vector2):
	if Input.is_key_pressed(game.settings.keybinds.crouch) || sliding:
		speed = CROUCH_SPEED
		head.position.y = lerp(head.position.y,CROUCHING_DEBTH, delta * 7.0)
		standing_collision.disabled = true
		crouching_collision.disabled = false
		# Slide begin logic
		if sprinting && input_dir != Vector2.ZERO:
			sliding = true
			free_looking = true
			slide_timer = slide_timer_max
			slide_vector = (head.global_transform.basis *  Vector3(input_dir.x, 0, input_dir.y)).normalized()
			slide_speed = velocity.length()
			print("Start Slide")
		walking = false
		sprinting = false
		crouching = true
	elif !ray_cast_3d.is_colliding():
		# Standing
		head.position.y = lerp(head.position.y, 0.0, delta * 7.0)
		standing_collision.disabled = false
		crouching_collision.disabled = true
		
		if Input.is_key_pressed(game.settings.keybinds.sprint):
			# Sprinting
			speed = SPRINT_SPEED
			walking = false
			sprinting = true
			crouching = false
		else:
			# Walking
			speed = WALK_SPEED
			walking = true
			sprinting = false
			crouching = false

func jump():
	motion.velocity.global.y = JUMP_VELOCITY
	if sliding: 
		exit_slide()
#this is the loop that detects when a jump is supposed to happen, and runs the jump function
#the reset on jumps is in the _physics_process function
func on_jump():
	if currentJumpCount >= POSSIBLE_JUMPS:
		return
	jump()
	currentJumpCount += 1
		

func _physics_process(delta: float) -> void:
	#subtract all deltatimes here
	coyote_time_delta -= delta
	# Getting movement direction
	var input_dir := get_current_input_direction()
	
	# Add the gravity.
	if is_on_floor():
		currentJumpCount = 0
		coyote_time_delta = coyote_time_value
		motion.velocity.global.y = max(motion.velocity.global.y, 0)
	else:
		motion.velocity.global += get_gravity() * delta
		
	set_movement_state(delta, input_dir)
	free_look(delta)
	headbob(delta, input_dir)
	
	#accelerate when input keys are pressed, adjusted to the target speed
	var reduction = friction.floor * delta
	if not is_on_floor():
		reduction = friction.air * delta
	if (input_dir.length() > 0):
		var c = motion.direction.local.normalized() * acceleration * delta * 5
		if not is_on_floor():
			c *= 0.2
		motion.velocity.local += c
		motion.velocity.local =  motion.velocity.local.limit_length(speed)
	else:
		motion.velocity.local = motion.velocity.local.normalized() * max(motion.velocity.local.length() - reduction, 0)			
	#basically velocity is now divided into a global and local component
	#global velocity will move relative to world, and local relative to the player
	motion.direction.local = Vector3(input_dir.x, 0, input_dir.y).normalized()
	motion.direction.global = head.transform.basis * Vector3(input_dir.x, 0, input_dir.y).normalized()
	#no regular movement if sliding
	var local_mult = 1
	if sliding:
		local_mult = 0
	velocity = (head.transform.basis * motion.velocity.local * local_mult) + motion.velocity.global + Vector3(
		slide_vector.x, slide_vector.y, slide_vector.z
	) * slide_speed
	slide_speed = max(slide_speed - friction.floor * 0.1 * delta,0)
	#the velocity components are now added together
	#velocity = (head.transform.basis * motion.velocity.local) + motion.velocity.global
	#FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	move_and_slide()
