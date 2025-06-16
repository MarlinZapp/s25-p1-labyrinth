# NPCBase.gd
class_name NPCBase
extends CharacterBody3D

enum BehaviorState {
	IDLE,
	PATROLLING,
	INVESTIGATING,
	TALKING,
	ALERTED
}

signal behavior_updated(new_state: BehaviorState, reason: String)
signal dialogue_spoken(text: String)
signal player_entered_range(player: CharacterBody3D)
signal player_exited_range()

@export var character_name: String = "NPC"
@export var character_description: String = "A generic NPC"

@export var speed = 3.0
@export var acceleration = 4.0

var current_behavior_state: BehaviorState = BehaviorState.IDLE
var conversation_history: Array = []
var current_player: Node
@onready var interaction_area: Area3D
@onready var dialogue_panel: Control
@onready var navigation_agent = $NavigationAgent3D


func _ready():
	# Get reference to AI manager (assuming it's an autoload or in scene)	
	connect_dialog_panel()
	# Setup 3D interaction area
	setup_interaction_area()
	
	setup_navigation()

func setup_navigation():
	# Connect to navigation finished signal
	navigation_agent.navigation_finished.connect(_on_navigation_finished)
	
	# Set agent properties
	navigation_agent.max_speed = speed
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = 0.5

func _on_navigation_finished():
	print("NPC reached destination!")
	velocity = Vector3.ZERO

func connect_dialog_panel():
	var node = get_node("../../UI/DialoguePanel")
	print(node)
	if node is DialoguePanel:
		dialogue_panel = node
		dialogue_panel.dialogue_input_submitted.connect(request_dialogue_response)

func setup_interaction_area():
	"""Create 3D interaction detection area"""
	if not interaction_area:
		interaction_area = Area3D.new()
		add_child(interaction_area)
		
		# Create collision shape for interaction
		var collision_shape = CollisionShape3D.new()
		var sphere_shape = SphereShape3D.new()
		sphere_shape.radius = 3.0  # 3 meter interaction radius
		collision_shape.shape = sphere_shape
		interaction_area.add_child(collision_shape)
		
		# Connect signals
		interaction_area.body_entered.connect(_on_interaction_area_entered)
		interaction_area.body_exited.connect(_on_interaction_area_exited)
		
		# Set collision layers (interact only with player)
		interaction_area.collision_layer = 3
		interaction_area.collision_mask = 1  # Assuming player is on layer 1

func _on_interaction_area_entered(body):
	if body.is_in_group("player"):
		current_player = body
		player_entered_range.emit(body)
		_on_player_approached()

func can_interact() -> bool:
	"""Check if player can interact with this NPC"""
	return current_player != null

func _on_player_approached():
	print("A player is approaching "+character_name)
	request_behavior_decision("", "The player is approaching.")

func _on_interaction_area_exited(body):
	"""Player left interaction range"""
	if body == current_player:
		current_player = null
		player_exited_range.emit()

func is_player_visible() -> bool:
	"""Check if player is visible (basic line of sight)"""
	if not current_player:
		return false
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 1.5, 0),  # From NPC eye level
		current_player.global_position + Vector3(0, 1, 0)  # To player center
	)
	
	var result = space_state.intersect_ray(query)
	return result.is_empty() or result.collider == current_player


# Methods that NPCs must implement to work with AI system
func _get_ai_context() -> String:
	"""Override this to provide character-specific context"""
	return """
	You are %s. %s
	Your current state is: %s
	""" % [character_name, character_description, BehaviorState.keys()[current_behavior_state]]

func _get_available_actions() -> Array:
	"""Override this to provide available actions for this NPC"""
	return [
		{"name": "PATROL", "description": "Walk to a different location"},
		{"name": "INVESTIGATE", "description": "Examine something suspicious"},
		{"name": "TALK", "description": "Initiate conversation with someone"},
		{"name": "IDLE", "description": "Stay in place and observe"},
		{"name": "ALERT", "description": "Become suspicious or alarmed"}
	]

func _get_conversation_history() -> String:
	"""Get formatted conversation history"""
	var history_text = ""
	for entry in conversation_history.slice(-6):  # Last 6 entries
		history_text += "%s: %s\n" % [entry.speaker, entry.message]
	return history_text

# Public methods for triggering AI decisions
func request_behavior_decision(situation: String, player_action: String = ""):
	"""Request AI to decide what to do next"""
	AiBehaviourManager.request_behavior_decision(self, situation, player_action)

func request_dialogue_response(player_message: String):
	"""Request AI dialogue response"""
	add_to_conversation_history("Player", player_message)
	AiBehaviourManager.request_dialogue_response(self, player_message)

# Signal handlers
func _on_behavior_decision_received(npc: Node, action: String, reason: String):
	if npc != self:
		return
	
	var old_state = current_behavior_state
	execute_behavior_action(action)
	
	if current_behavior_state != old_state:
		behavior_updated.emit(current_behavior_state, reason)

func _on_dialogue_response_received(npc: Node, response: String):
	if npc != self:
		return
	
	add_to_conversation_history(character_name, response)
	dialogue_spoken.emit(response)

# Behavior execution - override these in specific NPCs
func execute_behavior_action(action: String):
	"""Execute the behavior action - override for specific implementations"""
	match action:
		"PATROL":
			change_state(BehaviorState.PATROLLING)
			start_patrol_behavior()
		"INVESTIGATE":
			change_state(BehaviorState.INVESTIGATING)
			start_investigate_behavior()
		"TALK":
			change_state(BehaviorState.TALKING)
			start_talk_behavior()
		"IDLE":
			change_state(BehaviorState.IDLE)
			start_idle_behavior()
		"ALERT":
			change_state(BehaviorState.ALERTED)
			start_alert_behavior()

func change_state(new_state: BehaviorState):
	"""Change behavior state"""
	current_behavior_state = new_state

# Virtual methods - override in specific NPC classes
func start_patrol_behavior():
	"""Override this for patrol behavior"""
	pass

func start_investigate_behavior():
	"""Override this for investigation behavior"""
	pass

func start_talk_behavior():
	"""Override this for talk behavior"""
	if current_player:
		look_at_player()

func start_idle_behavior():
	"""Override this for idle behavior"""
	pass

func start_alert_behavior():
	"""Override this for alert behavior"""
	pass

func look_at_player():
	"""Make NPC face the player"""
	if current_player:
		var direction = (current_player.global_position - global_position).normalized()
		direction.y = 0  # Keep on same Y level
		if direction.length() > 0:
			look_at(global_position + direction, Vector3.UP)

# Conversation history management
func add_to_conversation_history(speaker: String, message: String):
	conversation_history.append({
		"speaker": speaker,
		"message": message,
		"timestamp": Time.get_unix_time_from_system()
	})
	
	# Keep only recent history (last 10 exchanges)
	if conversation_history.size() > 10:
		conversation_history = conversation_history.slice(-10)
