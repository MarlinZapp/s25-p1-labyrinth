extends NPCBase

class_name NPCRogue

@onready var model = $Rig
@onready var anim_tree : AnimationTree = $AnimationTree
@onready var anim_state : AnimationNodeStateMachinePlayback = $AnimationTree.get("parameters/playback")
@onready var mesh_instance: MeshInstance3D
@onready var shape_cast = $ShapeCast3D

@export var attack_range: float = 1.0
@export var attack_wait_time: float = 1.5
@export var post_attack_wait_time: float = 1.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var current_fight_state: FightState = FightState.NONE
var attack_timer: float = 0.0

enum FightState {
	NONE,
	CHASING,
	ATTACKING,
	WAITING
}

var attacks = [
	"1H_Melee_Attack_Chop",
	"1H_Melee_Attack_Slice_Diagonal",
	"1H_Melee_Attack_Slice_Horizontal",
]

func _ready():
	super._ready()
	# Enable the shapecast
	shape_cast.enabled = true
	# Configure what to detect
	shape_cast.collide_with_areas = false
	shape_cast.collide_with_bodies = true
	navigation_agent.target_desired_distance = attack_range

func _on_hit_by_arrow():
	var message = "You have been hit by a crossbow bolt."
	if knows_players.size() > 0:
		message = "You have been hit by the players crossbow bolt."
	request_behavior_decision(message)

func _process(delta):
	# Check if anything is detected
	if shape_cast.is_colliding():
		handle_detection()

func start_attack_behavior():
	current_fight_state = FightState.CHASING

func _on_navigation_finished():
	if self.current_behavior_state == BehaviorState.FIGHTING:
		pass
	else:
		super._on_navigation_finished()

func handle_detection():
	for i in range(shape_cast.get_collision_count()):
		var collider = shape_cast.get_collider(i)
		var collision_point = shape_cast.get_collision_point(i)
		var collision_normal = shape_cast.get_collision_normal(i)
		
		if collider.is_in_group("player"):
			_on_player_seen(collider)

func _physics_process(delta):
	super._physics_process(delta)
	match current_fight_state:
		FightState.NONE:
			pass
		FightState.CHASING:
			handle_chasing(delta)
		FightState.ATTACKING:
			handle_attacking(delta)
		FightState.WAITING:
			handle_waiting(delta)
	
	if navigation_agent.is_navigation_finished():
		velocity = Vector3.ZERO
	else:
		# Get the next position in the path
		var next_path_position = navigation_agent.get_next_path_position()
	
		# Calculate direction to next waypoint
		var direction = (next_path_position - global_position).normalized()
	
		var vy = velocity.y
		velocity.y = 0

		# Apply movement
		velocity = lerp(velocity, direction * speed, acceleration * delta)
	
		velocity.y = vy
		
		if velocity.length() > 0.1:
			look_at(global_position + direction, Vector3.UP)
	
	move_and_slide()
	var vl = velocity * model.transform.basis
	anim_tree.set("parameters/IdleWalkRun/blend_position", Vector2(vl.x, -vl.z) / speed)
	

func handle_chasing(delta):
	if not current_player:
		return
	
	set_target_position(current_player.global_position)
	
	# Check if we're close enough to attack
	var distance_to_player = global_position.distance_to(current_player.global_position)
	if distance_to_player <= attack_range:
		start_attack()
		return

func handle_attacking(delta):	
	look_at_player()
	
	# Wait for attack animation to finish
	attack_timer -= delta
	if attack_timer <= 0.0:
		current_fight_state = FightState.WAITING
		attack_timer = post_attack_wait_time
	
	velocity = Vector3.ZERO

func handle_waiting(delta):
	
	attack_timer -= delta
	if attack_timer <= 0.0:
		current_fight_state = FightState.CHASING
	
	velocity = Vector3.ZERO

func start_attack():
	current_fight_state = FightState.ATTACKING
	attack_timer = attack_wait_time
	
	anim_state.travel(attacks.pick_random())

func set_target_position(pos: Vector3):
	navigation_agent.target_position = pos
