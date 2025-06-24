extends CharacterBody3D

class_name PlayerCharacter

@export var speed = 3.0
@export var acceleration = 4.0
@export var jump_speed = 6.0
@export var rotation_speed = 12.0
@export var mouse_sensitivity = 0.0015

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var jumping = false
var last_floor = true
var attacks = [
	"1H_Melee_Attack_Chop",
	"1H_Melee_Attack_Slice_Diagonal",
	"1H_Melee_Attack_Slice_Horizontal",
]

@onready var spring_arm = $SpringArm3D
@onready var model = $Rig
@onready var anim_tree = $AnimationTree
@onready var anim_state = $AnimationTree.get("parameters/playback")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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
		spring_arm.rotation.x -= event.relative.y * mouse_sensitivity
		spring_arm.rotation_degrees.x = clamp(spring_arm.rotation_degrees.x, -90.0, 30.0)
		spring_arm.rotation.y -= event.relative.x * mouse_sensitivity
	if event.is_action_pressed("attack"):
		anim_state.travel(attacks.pick_random())
