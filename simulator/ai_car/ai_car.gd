extends VehicleBody3D


@export var STEER_SPEED = 1.5
@export var STEER_LIMIT = 0.6
var steer_target = 0
@export var engine_force_value = 100


var steer : float = 0.0
var gas : float = 0.0
var rev : float = 0.0
var brake_ : float = 0.0

var camera_offset : Vector3

func _ready() -> void:
	camera_offset = $SubViewport/capture_cam.global_position

func _physics_process(delta):
	var speed = linear_velocity.length()*Engine.get_frames_per_second()*delta
	traction(speed)
	

	var fwd_mps = transform.basis.x.x
	steer_target = steer
	steer_target *= STEER_LIMIT
	if rev:
	# Increase engine force at low speeds to make the initial acceleration faster.

		if speed < 20 and speed != 0:
			engine_force = clamp(engine_force_value * 3 / speed, 0, 300)
		else:
			engine_force = engine_force_value
	else:
		engine_force = 0
	if gas:
		# Increase engine force at low speeds to make the initial acceleration faster.
		if fwd_mps >= -1:
			engine_force = -engine_force_value * gas
		else:
			brake = 1
	else:
		brake = 0.0
		
	if brake_:
		brake=3
		$wheal2.wheel_friction_slip=0.8
		$wheal3.wheel_friction_slip=0.8
	else:
		$wheal2.wheel_friction_slip=3
		$wheal3.wheel_friction_slip=3
	steering = move_toward(steering, steer_target, STEER_SPEED * delta)

func traction(speed):
	apply_central_force(Vector3.DOWN*speed)

## capturer
@export var road_material: Material
@export var void_material: Material
@export var capture_viewport: SubViewport

var i : int = 0


func generate_mask_image():
	var all_geometry = get_tree().root.find_children("*", "GeometryInstance3D", true, false)
	
	for node in all_geometry:
		if node is CSGPolygon3D or "Road" in node.name:
			node.material_override = road_material
		else:
			node.material_override = void_material
	
	var camera = capture_viewport.get_camera_3d()
	var old_env = camera.environment # Save the old sky/lighting
	
	var mask_env = Environment.new()
	mask_env.background_mode = Environment.BG_COLOR
	mask_env.background_color = Color.BLACK
	camera.environment = mask_env
	
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	
	var img = capture_viewport.get_texture().get_image()
	
	# restore original visuals
	camera.environment = old_env
	for node in all_geometry:
		node.material_override = null
	
	
	return img


func capture_render_frame():
	$"SubViewport/capture_cam".global_position = global_position + camera_offset
	$"SubViewport/capture_cam".rotation = rotation
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	
	return capture_viewport.get_texture().get_image()

func capture_data_frame(_i):
	var file_path = "/home/adi/Codes/Python-Codes/Hackathons/self driving car/datas/temp/data" + str(_i)
	$"SubViewport/capture_cam".global_position = global_position + camera_offset
	$"SubViewport/capture_cam".rotation = rotation
	
	capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var render = capture_viewport.get_texture().get_image()
	
	
	var mask = await generate_mask_image()
	

	render.save_jpg(file_path + ".jpg")
	mask.save_png(file_path + "_mask.png")
	print("Frame ", _i, " captured successfully.")
