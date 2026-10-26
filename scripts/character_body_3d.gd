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
@onready var crouch_raycast: RayCast3D = $CrouchRaycast

#wallrun stuff
@onready var wallrun_raycasts = {
	left = $nek/head/RayCastLeft,
	right = $nek/head/RayCastRight
}

# Different stuff
const minimum_speed = 2.0
const maximum_speed = 100.0 #this is the true max speed, cool stuff can increase it maybe
var speed
var current_speed = 0.0
var acceleration = 25.0
const CROUCH_SPEED = 3.0
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const SENS = (1.0) / 500
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
var jumping = false

# Slide vars
var slide_timer = 0.0
var slide_timer_max = 1.0
var slide_vector = Vector3.ZERO
var slide_speed = 13.0

# Double jump vars
const POSSIBLE_JUMPS = 1
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
var external_motion = {
	slide = {
		local = Vector3.ZERO,
		global = Vector3.ZERO
	},
	wallrun = {
		local = Vector3.ZERO,
		global = Vector3.ZERO
	}
}
var friction = {
	floor = 40.0, #speed reduction when on ground
	air = 8.0, #speed reduction when in the air 
}
#wallrunning
const max_wallrun = 2
var current_wallrun = 0
var can_wallrun = false
var in_wallrun = false
var wallrun_raycast = {
	object = null,
	normal = Vector3.ZERO
}
var wallrun_gravity_multiplier = 0.2
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
		if sprinting && input_dir != Vector2.ZERO && is_on_floor():
			sliding = true
			free_looking = true
			slide_timer = slide_timer_max
			slide_speed = velocity.length()
			slide_vector = (head.global_transform.basis *  Vector3(input_dir.x, 0, input_dir.y)).normalized()
		walking = false
		sprinting = false
		crouching = true
	elif !crouch_raycast.is_colliding():
		# Standing
		head.position.y = lerp(head.position.y, 0.0, delta * 7.0)
		standing_collision.disabled = false
		crouching_collision.disabled = true
		
		if Input.is_key_pressed(game.settings.keybinds.sprint) || (sprinting && get_current_input_direction().length() > 0):
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

func jump(vector=Vector3.ZERO):
	motion.velocity.global.y = JUMP_VELOCITY
	motion.velocity.global += vector
	in_wallrun = false
	if sliding: 
		exit_slide()
#this is the loop that detects when a jump is supposed to happen, and runs the jump function
#the reset on jumps is in the _physics_process function
func on_jump():
	if can_wallrun && !is_on_floor():
		if in_wallrun:
			var normal_vector = (wallrun_raycast.object.transform.basis * wallrun_raycast.normal)
			var loc = (head.global_basis.inverse() * normal_vector).normalized() * JUMP_VELOCITY
			motion.velocity.local += loc
			jump()
		elif not in_wallrun and current_wallrun < max_wallrun:
			motion.velocity.global.y = 0
			current_wallrun += 1
			in_wallrun = true
	else:
		if is_on_floor():
			jump()
		elif currentJumpCount < POSSIBLE_JUMPS:
			jump()
			currentJumpCount += 1
	
func usable_raycast(ray:RayCast3D):
	var b = ray.get_collider()
	if b:
		var dot = (b.transform.basis * ray.get_collision_normal()).y
		return (abs(dot) < 0.1)
	return false 
				
func wall_run():
	var used = null
	var left_cast = usable_raycast(wallrun_raycasts.left)
	var right_cast = usable_raycast(wallrun_raycasts.right)
	if left_cast:
		used = "left"
	elif right_cast:
		used = "right"
	if used == null:
		in_wallrun = false
		wallrun_raycast.object = null
		wallrun_raycast.normal = Vector3.ZERO
	else:
		var ray = wallrun_raycasts[used]
		wallrun_raycast.object = ray.get_collider()
		wallrun_raycast.normal = ray.get_collision_normal()
	can_wallrun = (used != null) and (not is_on_floor())
	if in_wallrun and can_wallrun:
		var obj = wallrun_raycast.object
		var norm = wallrun_raycast.normal
		if obj:
			external_motion.wallrun.global = (obj.transform.basis * norm).normalized() * -5 * Vector3(1,0,1)
	else:
		external_motion.wallrun.global = Vector3.ZERO
func _physics_process(delta: float) -> void:
	var gravity = get_gravity()
	#subtract all deltatimes here
	coyote_time_delta -= delta
	# Getting movement direction
	var input_dir := get_current_input_direction()
	if in_wallrun:
		gravity *= wallrun_gravity_multiplier
	# Add the gravity.
	if is_on_floor():
		currentJumpCount = 0
		current_wallrun = 0
		coyote_time_delta = coyote_time_value
		motion.velocity.global.y = max(motion.velocity.global.y, 0)
	else:
		motion.velocity.global += gravity * delta
		
	wall_run()
	set_movement_state(delta, input_dir)
	free_look(delta)
	headbob(delta, input_dir)
	
	#accelerate when input keys are pressed, adjusted to the target speed
	motion.direction.local = Vector3(input_dir.x, 0, input_dir.y).normalized()
	motion.direction.global = head.transform.basis * Vector3(input_dir.x, 0, input_dir.y).normalized()
	var current_accel = acceleration
	var reduction = friction.floor * delta
	if not is_on_floor():
		current_accel = acceleration * 0.66 # Lower air acceleration for smoother feel
		reduction = friction.air * delta

	if input_dir.length() > 0:
		var target_velocity = motion.direction.local * speed
		if is_on_floor():
			if motion.velocity.local.length() < speed:
				motion.velocity.local += motion.direction.local * current_accel * delta
			else:
				motion.velocity.local = motion.velocity.local.move_toward(target_velocity, reduction)
		else:
			motion.velocity.local.x = move_toward(motion.velocity.local.x, target_velocity.x, current_accel * delta)
			motion.velocity.local.z = move_toward(motion.velocity.local.z, target_velocity.z, current_accel * delta)
	else:
		motion.velocity.local.x = move_toward(motion.velocity.local.x, 0, reduction)
		motion.velocity.local.z = move_toward(motion.velocity.local.z, 0, reduction)
		
	#basically velocity is now divided into a global and local component
	#global velocity will move relative to world, and local relative to the player
	#no regular movement if sliding
	external_motion.slide.global = slide_vector * slide_speed
	slide_speed = max(slide_speed - friction.floor * 0.1 * delta,0)
	var local_mult = 1
	if sliding:
		local_mult = 0
	#the velocity components are now added together
	velocity = motion.velocity.global + head.transform.basis * motion.velocity.local
	for m in external_motion.keys():
		velocity += external_motion[m].global
		velocity += head.transform.basis * external_motion[m].local
	#FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	move_and_slide()
