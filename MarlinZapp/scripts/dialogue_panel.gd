# DialoguePanel.gd - Attach this to a Control node
extends Control

class_name DialoguePanel

# UI Components - assign these in the inspector or create them in code
@onready var dialogue_container = $DialogueContainer
@onready var speaker_label = $DialogueContainer/SpeakerLabel
@onready var message_label = $DialogueContainer/MessageLabel
@onready var input_field = $DialogueContainer/InputContainer/InputField
@onready var send_button = $DialogueContainer/InputContainer/SendButton
@onready var close_button = $DialogueContainer/InputContainer/CloseButton
@onready var background_panel = $BackgroundPanel

# Dialogue state
var player: PlayerCharacter
var current_npc: NPCBase
var is_dialogue_active = false

# Signals
signal dialogue_input_submitted(text: String)
signal dialogue_closed()

func _ready():
	# Connect signals
	if send_button:
		send_button.pressed.connect(_on_send_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	if input_field:
		input_field.text_submitted.connect(_on_input_submitted)
	
	# Initially hide the dialogue panel
	visible = false
	
	connect_to_npcs()

func find_player():
	"""Find the player in the scene"""
	# Try different common player paths
	var node = get_tree().get_first_node_in_group("player")
	if node is PlayerCharacter:
		player = node
	else:
		print("Cannot find player!")

func connect_to_npcs():
	"""Find and connect to all NPCs in the scene"""
	var all_npcs = get_tree().get_nodes_in_group("npcs")
	for npc in all_npcs:
		if npc is NPCBase:
			connect_npc(npc)

func connect_npc(npc: NPCBase):
	npc.behavior_updated.connect(_on_npc_behavior_updated.bind(npc))
	npc.dialogue_spoken.connect(_on_npc_dialogue_received.bind(npc))

func _on_npc_behavior_updated(
	new_behaviour: NPCBase.BehaviorState,
	reason: String,
	npc: NPCBase
) -> void:
	if new_behaviour == NPCBase.BehaviorState.TALKING or new_behaviour == NPCBase.BehaviorState.ALERTED:
		if not visible:
			show_dialogue(npc)
	elif visible:
		var timer = Timer.new()
		timer.start(2)
		timer.timeout.connect(hide_dialogue)

func _on_npc_dialogue_received(text: String, npc: NPCBase) -> void:
	show_message(npc.character_name, text)
	input_field.grab_focus()
	input_field.edit()

func show_message(speaker: String, message: String):
	"""Display a message in the dialogue UI"""
	"""Add a message to the dialogue history display"""
	var formatted_message = "\n[color=yellow]%s:[/color] %s\n" % [speaker, message]
	message_label.text += formatted_message
	
	# Auto-scroll to bottom if needed
	message_label.scroll_to_line(message_label.get_line_count() - 1)

func show_dialogue(npc: NPCBase):
	"""Show the dialogue panel"""
	speaker_label.text = npc.character_name
	visible = true
	is_dialogue_active = true
	input_field.grab_focus()
	
	# Optional: Pause the game or change time scale
	# get_tree().paused = true

func hide_dialogue():
	"""Hide the dialogue panel"""
	visible = false
	is_dialogue_active = false
	current_npc = null
	
	# Resume game if it was paused
	# get_tree().paused = false

func set_npc(npc: NPCBase):
	"""Set the current NPC for this dialogue"""
	current_npc = npc

func _on_send_pressed():
	_send_message()

func _on_input_submitted(text: String):
	_send_message()

func _send_message():
	var message = input_field.text.strip_edges()
	if message.is_empty():
		return
	
	# Show player message
	show_message("Player", message)
	
	# Clear input
	input_field.text = ""
	
	# Send to NPC AI
	dialogue_input_submitted.emit(message)

func _on_close_pressed():
	hide_dialogue()

func clear_dialogue():
	"""Clear all dialogue history"""
	message_label.text = ""

# Handle input when dialogue is active
func _input(event):
	if not is_dialogue_active:
		return
	
	if event.is_action_pressed("ui_cancel"):  # ESC key
		hide_dialogue()
		get_viewport().set_input_as_handled()
