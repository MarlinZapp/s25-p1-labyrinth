# NPCBase.gd
class_name NPCBase
extends CharacterBody3D

enum BehaviorState {
	IDLE,
	MOVING,
	TALKING,
	ALERTED,
	FIGHTING
}

signal behavior_updated(new_state: BehaviorState, reason: String)
signal dialogue_spoken(text: String)

@export var character_name: String = "NPC"
@export var character_description: String = "A generic NPC"

@export var speed = 3.0
@export var acceleration = 4.0
@export var turn_speed: float = 2.0  # How fast the NPC turns (radians per second)

var target_rotation: float
var original_rotation: float
var is_turning: bool = false
var target_position: Vector3
var current_behavior_state: BehaviorState = BehaviorState.IDLE
var current_player: PlayerCharacter
var pending_ai_request: bool =  false
var knows_players : Array[PlayerCharacter] = []

@onready var interaction_area: Area3D
@onready var dialogue_panel: Control
@onready var navigation_agent : NavigationAgent3D = $NavigationAgent3D
@onready var thinking_indicator : ThinkingIndicator = $ThinkingIndicator

class Action:
	func _init(name: String, description: String, parameters: Array[Parameter]):
		self.name = name
		self.description = description
		self.parameters = parameters
	
	var name : String
	var description : String
	var parameters : Array[Parameter]
	
	class Parameter:
		func _init(name: String, description: String, required: bool):
			self.name = name
			self.description = description
			self.required = required
		
		var name : String
		var description : String
		var required : bool

func _ready():
	connect_ai_manager()
	
	connect_dialog_panel()
	# Setup 3D interaction area
	setup_interaction_area()
	
	setup_navigation()


func _physics_process(delta):
	# Handle the turning animation
	if is_turning:
		var rotation_diff = target_rotation - rotation.y
		
		# Handle wraparound (choosing the shortest rotation path)
		if rotation_diff > PI:
			rotation_diff -= 2 * PI
		elif rotation_diff < -PI:
			rotation_diff += 2 * PI
		
		# Check if we're close enough to the target
		if abs(rotation_diff) < 0.1:
			rotation.y = target_rotation
			is_turning = false
		else:
			# Smoothly rotate towards target
			var rotation_step = sign(rotation_diff) * turn_speed * delta
			if abs(rotation_step) > abs(rotation_diff):
				rotation_step = rotation_diff
			rotation.y += rotation_step

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
	request_behavior_decision("You have reached the destination!")

func move_to_position(pos: Vector3):
	target_position = pos
	navigation_agent.set_target_position(pos)

func connect_ai_manager():
	AiBehaviourManager.behavior_decision_made.connect(_on_behavior_decision_received)
	AiBehaviourManager.dialogue_response_received.connect(_on_dialogue_response_received)

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
		_on_player_heard(body)

func can_interact() -> bool:
	"""Check if player can interact with this NPC"""
	return current_player != null

func _on_player_seen(player: PlayerCharacter):
	current_player = player
	if knows_players.has(current_player):
		pass
		# request_behavior_decision("You see the player. You do already know him.")
	else:
		request_behavior_decision("You see the player. You do not know him yet.")
		knows_players.push_back(player)

func _on_player_heard(player: PlayerCharacter):
	print(character_name+" has heard the player!")
	current_player = player
	if knows_players.has(current_player):
		print(character_name+ " hears the player but already knows him.")
		# request_behavior_decision("You hear the player. You do already know him.")
	else:
		request_behavior_decision("You hear the player. You do not know him yet.")
		knows_players.push_back(player)

func _on_interaction_area_exited(body):
	"""Player left interaction range"""
	if body == current_player:
		current_player = null

func start_thinking():
	pending_ai_request = true
	thinking_indicator.start_thinking_animation()
	thinking_indicator.visible = true

func end_thinking():
	pending_ai_request = false
	thinking_indicator.stop_thinking_animation()
	thinking_indicator.visible = false

# Methods that NPCs must implement to work with AI system
func _get_ai_context() -> String:
	"""Override this to provide character-specific context"""
	var action_text = AiBehaviourManager.get_actions_text(_get_available_actions())
	return """
	You are %s. %s\n
	You can act in the following ways:\n%s
	""" % [character_name, character_description, action_text]

func _get_state() -> String:
	var state = BehaviorState.keys()[current_behavior_state]
	return "Your current state: %s\n" % [state]

func _get_available_actions() -> Array[Action]:
	"""Override this to provide available actions for this NPC"""
	return [
		Action.new(
			"MOVE",
			"Walk to a different location",
			[
				Action.Parameter.new(
					"target_vector",
					"A target position representing a Vector3 formatted as string like \"{15.0, 0.0, 3.0}\"",
					true
				)
			]),
		Action.new(
			"TALK",
			"Turn to a person and start or continue a conversation.",
			[
				Action.Parameter.new(
					"message",
					"What you want to say.",
					false
				)
			]),
		Action.new(
			"IDLE",
			"Stay in place and observe",
			[]),
		Action.new(
			"ALERT",
			"Become suspicious or alarmed. A conversation starts or continues.",
			[
				Action.Parameter.new(
					"message",
					"What you want to say.",
					false
				)
			]),
		Action.new(
			"ATTACK",
			"Attack the player. This would end any conversation.",
			[]
		)
	]

# Public methods for triggering AI decisions
func request_behavior_decision(situation: String = ""):
	"""Request AI to decide what to do next"""
	start_thinking()
	situation = _get_state() + situation
	AiBehaviourManager.request_behavior_decision(self, situation)

func request_dialogue_response(player_message: String):
	"""Request AI dialogue response"""
	start_thinking()
	var situation = _get_state()
	AiBehaviourManager.request_dialogue_response(self, situation, player_message)

# Signal handlers
func _on_behavior_decision_received(npc: NPCBase, action: Dictionary, reason: String):
	if npc != self:
		return
	end_thinking()
	var old_state = current_behavior_state
	execute_behavior_action(action, reason)
	
	if current_behavior_state != old_state:
		behavior_updated.emit(current_behavior_state, reason)

func _on_dialogue_response_received(npc: NPCBase, response: String, action: Variant):
	if npc != self:
		return
	end_thinking()
	dialogue_spoken.emit(response)
	if action != null:
		execute_behavior_action(action, "")

# Behavior execution - override these in specific NPCs
func execute_behavior_action(action: Dictionary, reason: String):
	"""Execute the behavior action - override for specific implementations"""
	print("AI decision from " + character_name + ": " + action.name + " ("+reason+")")
	if action.has("parameters"):
		print("Parameters: %s" % [action.parameters])
	match action.name:
		"MOVE":
			change_state(BehaviorState.MOVING, reason)
			var target : Vector3
			for param in action.parameters:
				if param.name == "target_vector":
					target = str_to_vec3(param.value)
			start_moving_behavior(target)
		"TALK":
			change_state(BehaviorState.TALKING, reason)
			var message = null
			for param in action.parameters:
				if param.name == "message" and param.has("value"):
					message = param.value
			start_talk_behavior(message)
		"IDLE":
			change_state(BehaviorState.IDLE, reason)
			start_idle_behavior()
		"ALERT":
			change_state(BehaviorState.ALERTED, reason)
			var message = null
			for param in action.parameters:
				if param.name == "message" and param.has("value"):
					message = param.value
			start_alert_behavior(message)
		"ATTACK":
			change_state(BehaviorState.FIGHTING, reason)
			start_attack_behavior()

func str_to_vec3(value: String):
	value = value.strip_edges().trim_prefix("{").trim_suffix("}")
	var numbers = value.split(",")
	if len(numbers) != 3:
		assert("Cannot parse "+value+" to Vector3")
	var vec = Vector3(
		float(numbers[0]),
		float(numbers[1]),
		float(numbers[2]))
	return vec

func change_state(new_state: BehaviorState, reason: String):
	"""Change behavior state"""
	current_behavior_state = new_state
	behavior_updated.emit(new_state, reason)

# Virtual methods - override in specific NPC classes
func start_moving_behavior(target: Vector3):
	"""Override this for other movement behavior"""
	move_to_position(target)

func start_talk_behavior(message: Variant):
	"""Override this for talk behavior"""
	if current_player:
		look_at_player()
	else:
		turn_around()
	if message != null:
		dialogue_spoken.emit(message)

func start_attack_behavior():
	"""Override this for attack behavior"""
	pass

func start_idle_behavior():
	"""Override this for idle behavior"""
	pass

func start_alert_behavior(message: Variant):
	"""Override this for alert behavior"""
	if current_player:
		look_at_player()
	else:
		turn_around()
	if message != null:
		dialogue_spoken.emit(message)


func turn_around():
	"""Makes the NPC turn around 180 degrees when called"""
	if is_turning:
		return  # Already turning, ignore new turn requests
	
	is_turning = true
	original_rotation = rotation.y
	target_rotation = original_rotation + PI  # Turn 180 degrees

func look_at_player():
	"""Make NPC face the player"""
	if current_player:
		var direction = (current_player.global_position - global_position).normalized()
		direction.y = 0  # Keep on same Y level
		if direction.length() > 0:
			look_at(global_position + direction, Vector3.UP)
