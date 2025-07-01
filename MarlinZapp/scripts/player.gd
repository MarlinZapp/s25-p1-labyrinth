extends CharacterBody3D

class_name PlayerCharacter

@export var speed = 3.0
@export var acceleration = 4.0
@export var jump_speed = 6.0
@export var rotation_speed = 12.0
@export var mouse_sensitivity = 0.0015
@export var arrow_speed: float = 15.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var jumping = false
var last_floor = true
var reloaded = false
var aiming = false
var current_arrow : Variant = null

@onready var spring_arm = $SpringArm3D
@onready var model = $Rig
@onready var anim_tree = $AnimationTree
@onready var anim_state = $AnimationTree.get("parameters/playback")

# At the top of your script, preload the arrow scene
const ARROW_SCENE = preload("res://arrow.tscn")
@onready var shoot_point: Marker3D = $"Rig/Skeleton3D/2H_Crossbow/2H_Crossbow/ShootPoint"

# crossbow aim
@export var max_aim_angle: float = 45.0  # Maximum degrees up/down
@export var crossbow_rotation: Vector3 = Vector3.ZERO

# Reference to your crossbow BoneAttachment3D
@onready var crossbow_bone: BoneAttachment3D = $"Rig/Skeleton3D/2H_Crossbow"


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(delta: float) -> void:
	# Position the arrow at the shoot point (or crossbow tip)
	if current_arrow is RigidBody3D:
		current_arrow.global_position = shoot_point.global_position
		current_arrow.global_rotation = shoot_point.get_parent_node_3d().global_rotation
		current_arrow.rotation_degrees.x -= 90


func _physics_process(delta: float) -> void:
	velocity.y += -gravity * delta
	get_move_input(delta)
	
	move_and_slide()
	if velocity.length() > 1.0:
		model.rotation.y = lerp_angle(model.rotation.y, spring_arm.rotation.y, rotation_speed * delta)
	
	if is_on_floor() and Input.is_action_just_pressed("jump") and get_viewport().gui_get_focus_owner() == null:
		velocity.y = jump_speed
		jumping = true
		anim_tree.set("parameters/conditions/jumping", true)
		anim_tree.set("parameters/conditions/grounded", false)
	if is_on_floor() and not last_floor:
		jumping = false
		anim_tree.set("parameters/conditions/jumping", false)
		anim_tree.set("parameters/conditions/grounded", true)
	if not is_on_floor() and not jumping:
		anim_state.travel("Jump_Idle")
		anim_tree.set("parameters/conditions/grounded", false)
	last_floor = is_on_floor()

func get_move_input(delta):
	# Don't process movement if UI has focus
	if get_viewport().gui_get_focus_owner() != null:
		return
	# Don't move while aiming
	if aiming == true:
		velocity = Vector3.ZERO
		return
	var vy = velocity.y
	velocity.y = 0
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir = Vector3(input.x, 0, input.y).rotated(Vector3.UP, spring_arm.rotation.y).normalized()
	velocity = lerp(velocity, dir * speed, acceleration * delta)
	var vl = velocity * model.transform.basis
	anim_tree.set("parameters/IdleWalkRun/blend_position", Vector2(vl.x, -vl.z) / speed)
	velocity.y = vy

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if aiming == true:
			handle_crossbow_aiming(event.relative)
		else:
			spring_arm.rotation.x -= event.relative.y * mouse_sensitivity
			spring_arm.rotation_degrees.x = clamp(spring_arm.rotation_degrees.x, -90.0, 30.0)
			spring_arm.rotation.y -= event.relative.x * mouse_sensitivity
	if event.is_action_pressed("attack"):
		try_shoot()
	if event.is_action_pressed("secondary_attack"):
		toggle_aim()
	if event.is_action_pressed("reload"):
		reload()

func try_shoot():
	if reloaded:
		aiming = false
		anim_state.travel("2H_Ranged_Shoot")
		shoot_arrow()
		reloaded = false
	else:
		pass

func toggle_aim():
	if aiming:
		anim_state.travel("IdleWalkRun")
		aiming = false
	else:
		anim_state.travel("2H_Ranged_Aiming")
		aiming = true

func reload():
	if reloaded:
		pass
	else:
		aiming = false
		anim_state.travel("2H_Ranged_Reload")
		
		# Instantiate the arrow
		current_arrow = ARROW_SCENE.instantiate()
		
		# Add arrow to the scene tree (use get_tree().current_scene or a specific parent)
		get_tree().current_scene.add_child(current_arrow)
		
		reloaded = true

func shoot_arrow():
	
	# Give the arrow forward velocity
	if current_arrow is RigidBody3D:
		current_arrow.linear_velocity = -current_arrow.global_transform.basis.y * arrow_speed
		current_arrow = null


func handle_crossbow_aiming(mouse_delta: Vector2):
	var last_blend_pos = anim_tree.get("parameters/2H_Ranged_Aiming/blend_position")
	var new_blend_pos = last_blend_pos + Vector2(mouse_delta.x, -mouse_delta.y) * mouse_sensitivity
	anim_tree.set("parameters/2H_Ranged_Aiming/blend_position", new_blend_pos)
