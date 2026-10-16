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
var speed
const CROUCH_SPEED = 3.0
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const JUMP_VELOCITY = 4.5
const SENS = 0.005
var CROUCHING_DEBTH = -0.5
var free_look_tilt_amount = 5
var direction = Vector3.ZERO

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
var slide_vector = Vector2.ZERO
var slide_speed = 13.0

# Double jump vars
const POSSIBLE_JUMPS = 2
var currentJumpCount = 0

# Head bob variables
const head_bobbing_sprinting_speed = 22.0
const head_bobbing_walking_speed = 14.0
const head_bobbing_crouching_speed = 10.0

const head_bobbing_sprinting_intensity = 0.2
const head_bobbing_walking_intensity = 0.1
const head_bobbing_crouching_intensity = 0.05

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbing_current_intensity = 0.0

#fov variables
const BASE_FOV = 75.0
const FOV_CHANGE = 1.5

# Eliminate Mouse
func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	
# Move Camera
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		if free_looking:
			nek.rotate_y(-event.relative.x * SENS)
		else:
			head.rotate_y(-event.relative.x * SENS)
			camera.rotate_x(-event.relative.y * SENS)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		
func _physics_process(delta: float) -> void:
	
		
	# Getting movement direction
	var input_dir := Input.get_vector("left", "right", "forward", "back")
	
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		sliding = false
		currentJumpCount = 1
	# Handle double jump
	elif Input.is_action_just_pressed("jump") and currentJumpCount == 1:
		velocity.y = JUMP_VELOCITY
		currentJumpCount += 1
		
	# Handle sprint/crouch.
	if Input.is_action_pressed("crouch") || sliding:
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
			print("Start Slide")
		
		
		walking = false
		sprinting = false
		crouching = true
	
	elif !ray_cast_3d.is_colliding():
		
		# Standing
		head.position.y = lerp(head.position.y, 0.0, delta * 7.0)
		standing_collision.disabled = false
		crouching_collision.disabled = true
		
		if Input.is_action_pressed("sprint"):
			
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
			
	# Handle free looking 
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

	# Handle Sliding
	if sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			sliding = false 
			free_looking = false
			print("End Slide")
		
	# Handle headbob
	if sprinting:
		head_bobbing_current_intensity = head_bobbing_sprinting_intensity
		head_bobbing_index += head_bobbing_sprinting_speed * delta
	elif walking: 
		head_bobbing_current_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed * delta
	elif crouching:
		head_bobbing_current_intensity = head_bobbing_crouching_intensity
		head_bobbing_index += head_bobbing_crouching_speed * delta
		
	if is_on_floor() && !sliding && input_dir != Vector2.ZERO:
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index/2)+0.5
		
		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y * (head_bobbing_current_intensity / 2.0), delta * 10.0)
		eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x * head_bobbing_current_intensity, delta * 10.0)
		
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * 10.0)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * 10.0)
		
	# Get the input direction and handle the movement/deceleration.
	if is_on_floor():
		direction = lerp(direction,(head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * 7.0)
	else:
		if input_dir != Vector2.ZERO:
			direction = lerp(direction,(head.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta * 3.0)
	if sliding:
		direction = slide_vector
		
	if direction:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 10.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 10.0)
			
		if sliding:
				velocity.x = direction.x * (slide_timer + 0.1) * slide_speed
				velocity.z = direction.z * slide_timer * slide_speed
				
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	
	#FOV
	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	
	move_and_slide()
	
	#ignore this comment, this is to test if github will sync
