# AIBehaviorManager.gd
class_name AIBehaviorManager
extends Node

"""action format: {name: value, parameters: [name: value]}"""
signal behavior_decision_made(npc: NPCBase, action: Dictionary, reason: String)
signal dialogue_response_received(npc: NPCBase, response: String)

var ollama_url: String = "http://localhost:11434/api/chat"
var http_request: HTTPRequest
var pending_requests: Dictionary = {}
var message_history: Dictionary = {}
const dialogue_response_format = {
	"type" : "object",
	"properties" : {
		"response" : { "type" : "string" },
		"action" : {
			"type" : "object",
			"properties" : {
				"name" : { "type" : "string" },
				"parameters" : {
					"type" : "array",
					"items" : {
						"type" : "object",
						"properties" : {
							"name" : { "type" : "string" },
							"value" : { "type" : "string" }
						},
						"required" : [ "name", "value" ]
					}
				}
			},
			"required" : [ "name" ]
		}
	},
	"required" : [ "response" ]
}
const action_response_format = {
	"type" : "object",
	"properties" : {
		"action" : {
			"type" : "object",
			"properties" : {
				"name" : { "type" : "string" },
				"parameters" : {
					"type" : "array",
					"items" : {
						"type" : "object",
						"properties" : {
							"name" : { "type" : "string" },
							"value" : { "type" : "string" }
						},
						"required" : [ "name", "value" ]
					}
				}
			},
			"required" : [ "name" ]
		},
		"reason" : { "type" : "string" }
	},
	"required" : [ "action", "reason" ]
}

func _ready():
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_ai_response_received)

func get_actions_text(available_actions: Array[NPCBase.Action]) -> String:
	var actions_text = ""
	for action in available_actions:
		var parameters_text = "parameters: ["
		for parameter in action.parameters:
			parameters_text += "%s (required: %s): %s" % [parameter.name, str(parameter.required), parameter.description]
			if action.parameters.back().name != parameter.name:
				parameters_text += ","
		parameters_text += "]"
		actions_text += "- %s: %s %s\n" % [action.name, parameters_text, action.description]
	return actions_text

func request_behavior_decision(npc: NPCBase, situation: String):
	"""Request AI decision for NPC behavior"""
	var npc_context = npc._get_ai_context() if npc.has_method("_get_ai_context") else ""
	var conversation_history = npc._get_conversation_history() if npc.has_method("_get_conversation_history") else ""

	var prompt = _build_behavior_prompt(situation)
	print("Sending behavior prompt for %s: %s" % [npc.character_name, prompt])
	_send_ollama_request(prompt, "behavior", npc, action_response_format)

func request_dialogue_response(npc: NPCBase, situation: String, player_message: String):
	"""Request AI dialogue response"""
	var prompt = _build_dialogue_prompt(situation, player_message)
	print("Sending dialogue prompt for %s: %s" % [npc.character_name, prompt])
	_send_ollama_request(prompt, "dialogue", npc, dialogue_response_format)

func _build_behavior_prompt(situation: String) -> String:
	var prompt = """
	%s

	Based on this situation, decide what you should do next. Respond with one of your actions and a very short reason.
	""" % [situation]

	return prompt

func _build_dialogue_prompt(situation: String, player_message: String) -> String:
	var prompt = """
	%s
	Player says: %s

	Respond as your character would Keep responses under 50 words and stay in character.
	Don't break the fourth wall or mention being an AI.
	You should end the dialog with one of your available actions if you feel that way.
	""" % [situation, player_message]

	return prompt

func npc_has_pending_request(npc: NPCBase) -> bool:
	for value in pending_requests.values():
		if value.npc == npc.get_instance_id():
			return true
	return false

func get_message_history(npc: NPCBase) -> Array:
	var messages = message_history.get(npc.get_instance_id())
	if typeof(messages) == TYPE_NIL:
		messages = []
		message_history.set(npc.get_instance_id(), messages)
	return messages

func set_message_history(npc: NPCBase, messages: Array) -> void:
	return message_history.set(npc.get_instance_id(), messages)

func add_to_message_history(npc: NPCBase, messages: Array) -> void:
	var message_history = get_message_history(npc)
	if len(message_history) == 0:
		message_history.push_back({
			"role" : "system",
			"content" : npc._get_ai_context()
		})
	for message in messages:
		message_history.push_back(message)
	message_history.set(npc.get_instance_id(), message_history)

func _send_ollama_request(prompt: String, request_type: String, npc: NPCBase, format: Dictionary):
	if npc_has_pending_request(npc):
		print("There is a pending request for "+npc.character_name+"... Abort new request!")
		return

	add_to_message_history(npc, [{
		"role" : "user",
		"content" : prompt
	}])

	var headers = ["Content-Type: application/json"]
	var body = {
		"model": "devstral",
		"messages": get_message_history(npc),
		"stream": false,
		"format": format
	}

	# Generate unique request ID
	var request_id = str(Time.get_unix_time_from_system()) + "_" + str(randi())
	pending_requests[request_id] = {
		"type": request_type,
		"npc": npc.get_instance_id(),
		"timestamp": Time.get_unix_time_from_system()
	}

	# Store request ID in metadata
	http_request.set_meta("request_id", request_id)
	http_request.request(ollama_url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))

func _on_ai_response_received(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if response_code != 200:
		print("AI request failed: ", response_code)
		print(body.get_string_from_ascii())
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
	var ai_response = response_data.message.content

	var npc : NPCBase = instance_from_id(request_data.npc)
	match request_data.type:
		"behavior":
			_process_behavior_response(ai_response, npc)
		"dialogue":
			_process_dialogue_response(ai_response, npc)


func _process_behavior_response(ai_response: String, npc: NPCBase):
	"""Parse AI behavior decision and emit signal (Godot 4.x version)"""
	var json = JSON.new()
	var parse_result = json.parse(ai_response)
	if parse_result != OK:
		print("Failed to parse AI response")
		return
	var response_data = json.data

	var action = response_data.action
	var reason = response_data.reason

	add_to_message_history(npc, [{
		"role" : "assistant",
		"content" : ai_response
	}])
	behavior_decision_made.emit(npc, action, reason)

func _process_dialogue_response(ai_response: String, npc: NPCBase):
	"""Handle AI dialogue response"""
	var json = JSON.new()
	var parse_result = json.parse(ai_response)
	if parse_result != OK:
		print("Failed to parse AI response")
		return
	var response_data = json.data

	var action : Variant = null
	if response_data.has("action"):
		action = response_data.action
	print("AI Response for %s: %s" % [npc.character_name, response_data.response])
	if action != null:
		print("Action: %s" % [response_data.action.name])
	add_to_message_history(npc, [{
		"role" : "assistant",
		"content" : ai_response
	}])
	dialogue_response_received.emit(npc, response_data.response, action)
