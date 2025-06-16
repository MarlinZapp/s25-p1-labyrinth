extends NPCBase

class_name NPCRogue

@onready var model = $Rig
@onready var anim_tree = $AnimationTree
@onready var anim_state = $AnimationTree.get("parameters/playback")
@onready var mesh_instance: MeshInstance3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var target_position: Vector3

# HTTP request node for AI communication
var http_request: HTTPRequest
var ollama_url = "http://localhost:11434/api/generate"

# NPC state and context
var npc_name = "Guard"
var npc_role = "A medieval castle guard"
var current_context = ""

func _ready():
	super._ready()
	# Initialize NPC context
	character_name = "Guard"
	character_description = """
	You are a vigilant guard patrolling the area. You are suspicious of strangers 
	but willing to talk if approached peacefully. You take your duties seriously 
	and will investigate anything unusual.
	"""

func move_to_position(pos: Vector3):
	target_position = pos
	navigation_agent.set_target_position(pos)

func _physics_process(delta):
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
