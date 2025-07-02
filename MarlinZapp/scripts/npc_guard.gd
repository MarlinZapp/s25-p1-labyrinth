extends NPCBase

class_name NPCRogue

@onready var model = $Rig
@onready var anim_tree = $AnimationTree
@onready var anim_state = $AnimationTree.get("parameters/playback")
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
		var target_pos = knows_players[0].position
		target_pos.y = 0
		print("Moving to %s" % [target_pos])
		navigation_agent.target_position = target_pos
		attack()

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
