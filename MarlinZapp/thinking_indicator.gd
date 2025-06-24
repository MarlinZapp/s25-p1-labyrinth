extends Node3D
class_name ThinkingIndicator

@onready var dot1: MeshInstance3D = $Dot1
@onready var dot2: MeshInstance3D = $Dot2  
@onready var dot3: MeshInstance3D = $Dot3

var original_positions: Array[Vector3] = []
var animation_tween: Tween
var is_animating = false

func _ready():
	# Store original positions
	original_positions = [dot1.position, dot2.position, dot3.position]

func start_thinking_animation():
	if is_animating:
		return
		
	is_animating = true
	animate_dots_sequence()

func animate_dots_sequence():
	if not is_animating:
		return
		
	animation_tween = create_tween()
	animation_tween.set_loops()  # Infinite loop
	
	# Animate each dot with a delay for wave effect
	var bounce_height = 0.3
	var bounce_duration = 0.4
	var delay_between_dots = 0.15
	
	# Dot 1
	animation_tween.parallel().tween_property(dot1, "position:y", 
		original_positions[0].y + bounce_height, bounce_duration)
	animation_tween.parallel().tween_property(dot1, "position:y", 
		original_positions[0].y, bounce_duration).set_delay(bounce_duration)
	
	# Dot 2 (delayed)
	animation_tween.parallel().tween_property(dot2, "position:y", 
		original_positions[1].y + bounce_height, bounce_duration).set_delay(delay_between_dots)
	animation_tween.parallel().tween_property(dot2, "position:y", 
		original_positions[1].y, bounce_duration).set_delay(delay_between_dots + bounce_duration)
	
	# Dot 3 (more delayed)
	animation_tween.parallel().tween_property(dot3, "position:y", 
		original_positions[2].y + bounce_height, bounce_duration).set_delay(delay_between_dots * 2)
	animation_tween.parallel().tween_property(dot3, "position:y", 
		original_positions[2].y, bounce_duration).set_delay(delay_between_dots * 2 + bounce_duration)
	
	# Pause between cycles
	animation_tween.tween_interval(1.0)

func stop_thinking_animation():
	is_animating = false
	if animation_tween:
		animation_tween.kill()
	
	# Reset positions
	dot1.position = original_positions[0]
	dot2.position = original_positions[1] 
	dot3.position = original_positions[2]
