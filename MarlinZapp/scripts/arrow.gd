# Option 1: RigidBody3D Arrow (most realistic physics)
extends RigidBody3D

@export var damage: int = 25

func _ready():
	# Set up collision detection
	body_entered.connect(_on_body_entered)
	
	# Apply gravity after a short delay for more realistic arc
	await get_tree().create_timer(0.1).timeout
	gravity_scale = 1.0

func _on_body_entered(body):
	if body != self:
		# Arrow hit something
		hit_target(body)

func hit_target(target):
	# Stop the arrow's movement
	freeze = true
	
	# Deal damage if target has health
	if target.has_method("take_damage"):
		target.take_damage(damage)
	
	# Optional: Stick arrow to target or remove after delay
	await get_tree().create_timer(5.0).timeout
	queue_free()
