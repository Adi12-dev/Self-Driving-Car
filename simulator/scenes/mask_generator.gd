extends Node

@export var road_material: Material
@export var void_material: Material
@export var capture_viewport: SubViewport

var i : int = 0

var camera_offset : Vector3

func _ready() -> void:
	camera_offset = $"../SubViewport/capture_cam".global_position

func _process(_delta: float) -> void:
	$"../SubViewport/capture_cam".global_position = $"..".global_position + camera_offset
	$"../SubViewport/capture_cam".rotation = $"..".rotation
	
	if Input.is_action_just_pressed("ui_accept"):
		capture_data_frame(i)
		i += 1

func generate_mask_image():
	# 1. Find all 3D objects (Meshes and CSG)
	var all_geometry = get_tree().root.find_children("*", "GeometryInstance3D", true, false)
	
	# 2. Apply the mask materials
	for node in all_geometry:
		# Check if it's your CSG road or has "Road" in the name
		if node is CSGPolygon3D or "Road" in node.name:
			node.material_override = road_material
		else:
			node.material_override = void_material
	
	# 3. Force a pure black background
	var camera = capture_viewport.get_camera_3d()
	var old_env = camera.environment # Save the old sky/lighting
	
	var mask_env = Environment.new()
	mask_env.background_mode = Environment.BG_COLOR
	mask_env.background_color = Color.BLACK
	camera.environment = mask_env
	
	# 4. Wait for the frame to render
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	
	# 5. Capture the image
	var img = capture_viewport.get_texture().get_image()
	
	# 6. Restore original visuals
	camera.environment = old_env
	for node in all_geometry:
		node.material_override = null
	
	
	return img

func capture_data_frame(i):
	var file_path = "/home/adi/Codes/Python-Codes/Hackathons/self driving car/datas /data" + str(i)
	
	# First, grab the normal render
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var render = capture_viewport.get_texture().get_image()
	
	# Then, grab the mask (this function handles the material swap)
	var mask = await generate_mask_image()
	
	# SAVE AS PNG (Crucial for machine learning/binary masks!)
	render.save_png(file_path + ".png")
	mask.save_png(file_path + "_mask.png")
	print("Frame ", i, " captured successfully.")
	
 
