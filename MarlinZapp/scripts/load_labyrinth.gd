@tool
extends Node3D

@export var labyrinth_path: String = "res://labyrinth_generated.json"

@export var absorbing_material: Material
@export var reflecting_material: Material
@export var transparent_material: Material
@export var metallic_material: Material

const WALL_SIZE_X = 1.0
const WALL_SIZE_Z = 1.0
const WALL_SIZE_Y = 3.0

@export_tool_button("Load labyrinth walls!") var action = load_labyrinth

func add_as_child_to_scene(new_node: Node3D, parent_node: Node3D):
	parent_node.add_child(new_node)
	# The line below is required to make the node visible in the Scene tree dock
	# and persist changes made by the tool script to the saved scene file.
	new_node.owner = get_tree().edited_scene_root
	

func load_labyrinth():
	if not Engine.is_editor_hint():
		return

	# Remove existing children (clean previous generation)
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var file = FileAccess.open(labyrinth_path, FileAccess.READ)
	if not file:
		push_error("Failed to open labyrinth.json")
		return

	var json_text = file.get_as_text()
	var data = JSON.parse_string(json_text)
	if data == null:
		push_error("Failed to parse JSON")
		return

	if not data.has("walls"):
		push_error("No walls in JSON")
		return

	for wall_data in data["walls"]:
		create_wall_segment(wall_data)
		
	for wall_lantern in data["lanterns"]:
		create_wall_lantern(wall_lantern)
		

func create_wall_segment(wall_data):
	var material_type = wall_data["material"]
	var wall = StaticBody3D.new()
	wall.position = get_position_from_json(wall_data)
	wall.name = "Wall-"+str(wall.position)
	
	var mesh_instance = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = get_size_from_json(wall_data)
	mesh.add_uv2 = true
	mesh_instance.mesh = mesh
	
	var material = get_material_by_type(material_type)
	if material:
		mesh_instance.material_override = material

	var collision = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = get_size_from_json(wall_data)
	collision.shape = shape
	
	add_as_child_to_scene(wall, self)
	add_as_child_to_scene(mesh_instance, wall)
	add_as_child_to_scene(collision, wall)
	

func get_position_from_json(wall_data) -> Vector3:
	if wall_data.has("position"):
		var position = wall_data["position"]
		return Vector3(position["x"], WALL_SIZE_Y/2, position["z"])
	else:
		var start_pos = Vector2(wall_data["startPosition"]["x"], wall_data["startPosition"]["z"])
		var end_pos = Vector2(wall_data["endPosition"]["x"], wall_data["endPosition"]["z"])
		var center = (start_pos + end_pos) * 0.5
		return Vector3(center.x, WALL_SIZE_Y/2, center.y)

func get_size_from_json(wall_data) -> Vector3:
	if wall_data.has("position"):
		return Vector3(WALL_SIZE_X, WALL_SIZE_Y, WALL_SIZE_Z)
	else:
		var start_pos = Vector2(wall_data["startPosition"]["x"], wall_data["startPosition"]["z"])
		var end_pos = Vector2(wall_data["endPosition"]["x"], wall_data["endPosition"]["z"])
		if start_pos.x == end_pos.x:
			return Vector3(WALL_SIZE_X, WALL_SIZE_Y, WALL_SIZE_Z * start_pos.distance_to(end_pos) + 1)
		else:
			return Vector3(WALL_SIZE_X * start_pos.distance_to(end_pos) + 1, WALL_SIZE_Y, WALL_SIZE_Z)

func get_material_by_type(material_type: String) -> Material:
	match material_type:
		"absorbing":
			return absorbing_material
		"reflecting":
			return reflecting_material
		"transparent":
			return transparent_material
		"metallic":
			return metallic_material
		_:
			return null


func create_wall_lantern(lantern_data):
	var lantern = OmniLight3D.new()
	lantern.position = Vector3(lantern_data["position"]["x"], 2.2, lantern_data["position"]["z"])
	lantern.name = "Lantern-"+str(lantern.position)
	lantern.light_energy = 0.2
	lantern.shadow_enabled = true
	lantern.light_bake_mode = Light3D.BAKE_STATIC
	if lantern_data["direction"] == "north":
		lantern.rotation_degrees = Vector3(0,270,0)
	elif lantern_data["direction"] == "west":
		lantern.rotation_degrees = Vector3(0,180,0)
	elif lantern_data["direction"] == "south":
		lantern.rotation_degrees = Vector3(0,90,0)
	
	var lantern_scene = preload("res://lamp.tscn").instantiate()
	lantern_scene.position = Vector3(0.165, 0.155, 0.007)
	lantern_scene.rotation_degrees.y = 17
	lantern_scene.scale = Vector3(0.175, 0.175, 0.175)
	
	add_as_child_to_scene(lantern, self)
	add_as_child_to_scene(lantern_scene, lantern)
