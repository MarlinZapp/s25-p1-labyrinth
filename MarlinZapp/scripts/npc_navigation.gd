extends Node3D

@onready var npc = $Rogue

func _ready() -> void:
	call_deferred("move_npc")

func move_npc() -> void:
	npc.move_to_position(Vector3(5, 0, 5))
