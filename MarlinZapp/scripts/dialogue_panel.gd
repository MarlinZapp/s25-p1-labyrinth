# DialoguePanel.gd - Attach this to a Control node
extends Control

class_name DialoguePanel

# UI Components - assign these in the inspector or create them in code
@onready var dialogue_container: VBoxContainer
@onready var speaker_label: Label
@onready var message_label: RichTextLabel
@onready var input_field: LineEdit
@onready var send_button: Button
@onready var close_button: Button
@onready var background_panel: Panel

# Dialogue state
var player: PlayerCharacter
var current_npc: NPCBase
var is_dialogue_active = false

# Signals
signal dialogue_input_submitted(text: String)
signal dialogue_closed()

func _ready():
	# Create UI elements if they don't exist
	setup_ui_elements()
	
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

func setup_ui_elements():
	"""Create UI elements programmatically if not assigned"""
	if not dialogue_container:
		dialogue_container = VBoxContainer.new()
		add_child(dialogue_container)
	
	if not background_panel:
		background_panel = Panel.new()
		add_child(background_panel)
		move_child(background_panel, 0)  # Move to back
		
		# Style the background
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0, 0, 0, 0.8)
		style_box.border_width_left = 2
		style_box.border_width_right = 2
		style_box.border_width_top = 2
		style_box.border_width_bottom = 2
		style_box.border_color = Color(0.7, 0.7, 0.7, 1.0)
		style_box.corner_radius_top_left = 10
		style_box.corner_radius_top_right = 10
		style_box.corner_radius_bottom_left = 10
		style_box.corner_radius_bottom_right = 10
		background_panel.add_theme_stylebox_override("panel", style_box)
	
	if not speaker_label:
		speaker_label = Label.new()
		speaker_label.text = "NPC Name"
		speaker_label.add_theme_font_size_override("font_size", 18)
		speaker_label.add_theme_color_override("font_color", Color.YELLOW)
		dialogue_container.add_child(speaker_label)
	
	if not message_label:
		message_label = RichTextLabel.new()
		message_label.custom_minimum_size = Vector2(400, 100)
		message_label.fit_content = true
		message_label.bbcode_enabled = true
		message_label.add_theme_font_size_override("normal_font_size", 14)
		dialogue_container.add_child(message_label)
	
	# Input section
	var input_container = HBoxContainer.new()
	dialogue_container.add_child(input_container)
	
	if not input_field:
		input_field = LineEdit.new()
		input_field.custom_minimum_size = Vector2(300, 30)
		input_field.placeholder_text = "Type your response..."
		input_container.add_child(input_field)
	
	if not send_button:
		send_button = Button.new()
		send_button.text = "Send"
		send_button.custom_minimum_size = Vector2(60, 30)
		input_container.add_child(send_button)
	
	if not close_button:
		close_button = Button.new()
		close_button.text = "Close"
		close_button.custom_minimum_size = Vector2(60, 30)
		input_container.add_child(close_button)
	
	# Set anchors and margins for responsive design
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(450, 200)

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
		hide_dialogue()

func _on_npc_dialogue_received(text: String, npc: NPCBase) -> void:
	show_message(npc.character_name, text)

func show_message(speaker: String, message: String):
	"""Display a message in the dialogue UI"""
	message_label.text = message

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
	add_message("Player", message)
	
	# Clear input
	input_field.text = ""
	
	# Send to NPC AI
	dialogue_input_submitted.emit(message)

func _on_close_pressed():
	hide_dialogue()

func add_message(speaker: String, message: String):
	"""Add a message to the dialogue history display"""
	var formatted_message = "[color=yellow]%s:[/color] %s\n" % [speaker, message]
	message_label.text += formatted_message
	
	# Auto-scroll to bottom if needed
	# message_label.scroll_to_line(message_label.get_line_count() - 1)

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
