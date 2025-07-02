extends NPCBase

class_name NPCRogue

@onready var model = $Rig
@onready var anim_tree : AnimationTree = $AnimationTree
@onready var anim_state : AnimationNodeStateMachinePlayback = $AnimationTree.get("parameters/playback")
@onready var mesh_instance: MeshInstance3D
@onready var shape_cast = $ShapeCast3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# HTTP request node for AI communication
var http_request: HTTPRequest
var ollama_url = "http://localhost:11434/api/generate"

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
	anim_tree.animation_finished.connect(_on_animation_finished)

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
	if knows_players.size() > 0:
		var target_pos = knows_players[0].global_position
		# Calculate direction from self to target
		var direction = (target_pos - global_position).normalized()
		# Move the target position 1 unit back along the direction
		var offset_target = target_pos - direction * 1.0
		offset_target.y = 0.0
		print("Moving to %s" % [offset_target])
		navigation_agent.set_target_position(offset_target)

func _on_navigation_finished():
	if self.current_behavior_state == BehaviorState.FIGHTING:
		look_at_player()
		attack()
	else:
		super._on_navigation_finished()

func _on_animation_finished(anim_name: StringName):
	# Check if the finished animation was one of our attack animations
	if current_behavior_state == BehaviorState.FIGHTING and anim_name in attacks:
		print("Attack animation finished: %s" % anim_name)
		
		# Check if player is still in range and we should continue fighting
		if knows_players.size() > 0:
			# Small delay before starting next attack cycle (optional)
			await get_tree().create_timer(0.5).timeout
			start_attack_behavior()  # Restart the attack cycle
		else:
			print("No players in range, stopping attack behavior")

func handle_detection():
	for i in range(shape_cast.get_collision_count()):
		var collider = shape_cast.get_collider(i)
		var collision_point = shape_cast.get_collision_point(i)
		var collision_normal = shape_cast.get_collision_normal(i)
		
		if collider.is_in_group("player"):
			_on_player_seen(collider)

func _physics_process(delta):
	super._physics_process(delta)
	var vl = velocity * model.transform.basis
	anim_tree.set("parameters/IdleWalkRun/blend_position", Vector2(vl.x, -vl.z) / speed)
	
	if navigation_agent.is_navigation_finished():
		return
	
	# Get the next position in the path
	var next_path_position = navigation_agent.get_next_path_position()
	
	# Calculate direction to next waypoint
	var direction = (next_path_position - global_position).normalized()
	
	var vy = velocity.y
	velocity.y = 0

	# Apply movement
	velocity = lerp(velocity, direction * speed, acceleration * delta)
	
	velocity.y = vy
	
	move_and_slide()
	
	# Optional: Make NPC face movement direction
	if velocity.length() > 0.1:
		look_at(global_position + direction, Vector3.UP)

func attack():
	anim_state.travel(attacks.pick_random())
