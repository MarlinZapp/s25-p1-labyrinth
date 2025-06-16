# AIBehaviorManager.gd
class_name AIBehaviorManager
extends Node

signal behavior_decision_made(npc: Node, action: String, reason: String)
signal dialogue_response_received(npc: Node, response: String)

var ollama_url: String = "http://localhost:11434/api/generate"
var http_request: HTTPRequest
var pending_requests: Dictionary = {}

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_ai_response_received)

func request_behavior_decision(npc: Node, situation: String, player_action: String = ""):
	"""Request AI decision for NPC behavior"""
	var npc_context = npc._get_ai_context() if npc.has_method("_get_ai_context") else ""
	var available_actions = npc._get_available_actions() if npc.has_method("_get_available_actions") else []
	var conversation_history = npc._get_conversation_history() if npc.has_method("_get_conversation_history") else ""
	
	var prompt = _build_behavior_prompt(npc_context, situation, player_action, available_actions, conversation_history)
	print("Sending behavior prompt for %s: %s" % [npc.name, prompt])
	_send_ollama_request(prompt, "behavior", npc)

func request_dialogue_response(npc: Node, player_message: String):
	"""Request AI dialogue response"""
	var npc_context = npc._get_ai_context() if npc.has_method("_get_ai_context") else ""
	var conversation_history = npc._get_conversation_history() if npc.has_method("_get_conversation_history") else ""
	
	var prompt = _build_dialogue_prompt(npc_context, player_message, conversation_history)
	print("Sending dialogue prompt for %s: %s" % [npc.name, prompt])
	_send_ollama_request(prompt, "dialogue", npc)

func _build_behavior_prompt(context: String, situation: String, player_action: String, available_actions: Array, history: String) -> String:
	var actions_text = ""
	for action in available_actions:
		if typeof(action) == TYPE_DICTIONARY:
			actions_text += "- %s: %s\n" % [action.name, action.description]
		else:
			actions_text += "- %s\n" % str(action)
	
	var prompt = """
	%s
	
	Current situation: %s
	Player action: %s
	
	Recent conversation history:
	%s
	
	Available actions:
	%s
	
	Based on this situation, decide what you should do next. Respond with one of the available actions.
	
	Respond with just the action name and a brief reason (max 20 words).
	Format: ACTION: reason
	""" % [context, situation, player_action, history, actions_text]
	
	return prompt

func _build_dialogue_prompt(context: String, player_message: String, history: String) -> String:
	var prompt = """
	%s
	
	Player says: "%s"
	
	Previous conversation:
	%s
	
	Respond as your character would. Keep responses under 50 words and stay in character.
	Don't break the fourth wall or mention being an AI.
	""" % [context, player_message, history]
	
	return prompt

func _send_ollama_request(prompt: String, request_type: String, npc: Node):
	var headers = ["Content-Type: application/json"]
	var body = {
		"model": "devstral",
		"prompt": prompt,
		"stream": false,
		"options": {
			"temperature": 0.7,
			"max_tokens": 150
		}
	}
	
	# Generate unique request ID
	var request_id = str(Time.get_unix_time_from_system()) + "_" + str(randi())
	pending_requests[request_id] = {
		"type": request_type,
		"npc": npc,
		"timestamp": Time.get_unix_time_from_system()
	}
	
	# Store request ID in metadata
	http_request.set_meta("request_id", request_id)
	http_request.request(ollama_url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_ai_response_received(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code != 200:
		print("AI request failed: ", response_code)
		return
	
	var request_id = http_request.get_meta("request_id")
	if not pending_requests.has(request_id):
		print("Unknown request ID: ", request_id)
		return
	
	var request_data = pending_requests[request_id]
	pending_requests.erase(request_id)
	
	var json = JSON.new()
	var parse_result = json.parse(body.get_string_from_utf8())
	
	if parse_result != OK:
		print("Failed to parse AI response")
		return
	
	var response_data = json.data
	var ai_response = response_data.get("response", "")
	
	match request_data.type:
		"behavior":
			_process_behavior_response(ai_response, request_data.npc)
		"dialogue":
			_process_dialogue_response(ai_response, request_data.npc)

func _process_behavior_response(ai_response: String, npc: Node):
	"""Parse AI behavior decision and emit signal"""
	var lines = ai_response.split("\n")
	var action_line = ""
	
	for line in lines:
		if line.contains(":"):
			action_line = line
			break
	
	if action_line.is_empty():
		return
	
	var parts = action_line.split(":", false, 1)
	if parts.size() < 2:
		return
	
	var action = parts[0].strip_edges().to_upper()
	var reason = parts[1].strip_edges()
	
	print("AI Decision for %s: %s - %s" % [npc.name, action, reason])
	behavior_decision_made.emit(npc, action, reason)

func _process_dialogue_response(ai_response: String, npc: Node):
	"""Handle AI dialogue response"""
	var cleaned_response = ai_response.strip_edges()
	print("AI Response for %s: %s" % [npc.name, cleaned_response])
	dialogue_response_received.emit(npc, cleaned_response)
