extends RigidBody3D

@export var damage: int = 25

func _ready():
	contact_monitor = true
	max_contacts_reported = 5
	body_entered.connect(_on_arrow_body_entered)

func _on_arrow_body_entered(body: Node):
	if body.is_in_group("npcs"):
		body._on_hit_by_arrow()

func _stick_to_body(body: Node):
	# Stop the arrow's physics
	freeze = true
	
	var transform = global_transform
	
	get_parent().remove_child(self)
	body.add_child(self)
	
	global_transform = transform
	
