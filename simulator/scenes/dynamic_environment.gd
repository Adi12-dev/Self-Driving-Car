extends Node3D

@onready var road_generator: RoadGenerator = $RoadGenerator
@onready var ai_car: VehicleBody3D = $ai_car


func _ready() -> void:
	await randomize_scene()
	#get_tree().quit()
	pass

func randomize_scene(capture = false):
	for i in range(1):
		#await road_generator.generate_real_random(randi())
		await _randomize_obstacles()
		await _randomize_environment()
		await _randomize_car_position()
		if capture:
			await ai_car.capture_data_frame(i)

func _randomize_obstacles():
	for obs in $obstacles.get_children():
		#obs.position.z = randf_range(5, 40)
		#obs.position.x = randf_range(-20, 20)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(randf(), randf(), randf(), 1.0)
		obs.material_override = mat
		
func _randomize_environment():
	$DirectionalLight3D.rotation_degrees = Vector3(randf_range(-180, 0), randf_range(0, 180), randf_range(-180, 0))
	
func _randomize_car_position():
	ai_car.position.x = randf_range(-3, 3)
