extends CharacterBody3D

@export var speed = 5.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var target_position: Vector3
@onready var navigation_agent = $NavigationAgent3D
@onready var model = $Rig
@onready var anim_tree = $AnimationTree
@onready var anim_state = $AnimationTree.get("parameters/playback")


func _ready():
	# Wait for navigation to be ready
	call_deferred("setup_navigation")

func setup_navigation():
	# Connect to navigation finished signal
	navigation_agent.navigation_finished.connect(_on_navigation_finished)
	
	# Set agent properties
	navigation_agent.max_speed = speed
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = 0.5

func move_to_position(pos: Vector3):
	target_position = pos
	navigation_agent.set_target_position(pos)

func _physics_process(delta):
	if navigation_agent.is_navigation_finished():
		return
	
	# Get the next position in the path
	var next_path_position = navigation_agent.get_next_path_position()
	
	# Calculate direction to next waypoint
	var direction = (next_path_position - global_position).normalized()
	
	# Apply movement
	velocity = direction * speed
	move_and_slide()
	
	# Optional: Make NPC face movement direction
	if velocity.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)

func _on_navigation_finished():
	print("NPC reached destination!")
	velocity = Vector3.ZERO
