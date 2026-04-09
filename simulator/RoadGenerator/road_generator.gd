@tool
class_name RoadGenerator extends Path3D

@export_group("Editor Tools")
@export var generate_new_button: bool = false:
	set(val):
		if not fixed_seed:
			seed_value = randi()
		generate_real_road()

@export_group("Road Geometry")
@export var total_length_meters: float = 400.0:
	set(val):
		total_length_meters = max(1.0, val)
		generate_real_road()
@export_range(0.01, 5.0) var resolution: float = 0.5:
	set(val):
		resolution = val
		generate_real_road()

## Length of Bezier handles (0.0 to 1.0)
@export_range(0.0, 1.0) var smooth_factor: float = 0.5:
	set(val):
		smooth_factor = val
		generate_real_road()

@export_group("Tuning")
@export_range(0.0, 1.0) var curviness: float = 0.5:
	set(val):
		curviness = val
		generate_real_road()

## Maximum degrees the road can turn per meter
@export var max_turn_rate: float = 0.2:
	set(val):
		max_turn_rate = val
		generate_real_road()

@export_group("Noise Settings")
@export var noise_frequency: float = 0.01:
	set(val):
		noise_frequency = val
		generate_real_road()

@export var fixed_seed: bool = false
@export var seed_value: int = 0:
	set(val):
		seed_value = val
		generate_real_road()

func _ready() -> void:
	generate_real_road()

func generate_real_road():
	if not curve:
		curve = Curve3D.new()
	
	var noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = noise_frequency
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

	var step_size = 1.0 / resolution
	var num_steps = int(total_length_meters * resolution)
	
	var straight_threshold = lerp(0.9, 0.1, curviness)

	var road_points: Array[Vector3] = []
	var current_pos = Vector3.ZERO
	var current_angle = 0.0
	var noise_offset = 1000.0 # Deep in the noise map to avoid artifacts
	
	road_points.push_back(current_pos)

	for i in range(1, num_steps):
		var distance_along_path = i * step_size
		var n = noise.get_noise_1d(noise_offset + distance_along_path)
		
		var steer_per_meter = 0.0
		if abs(n) > straight_threshold:
			var turn_strength = (abs(n) - straight_threshold) / (1.0 - straight_threshold)
			steer_per_meter = turn_strength * sign(n) * max_turn_rate
		
		current_angle += steer_per_meter * step_size
		
		var dir = Vector3(sin(current_angle), 0, cos(current_angle))
		current_pos += dir * step_size
		road_points.push_back(current_pos)

	var new_curve = Curve3D.new()
	new_curve.bake_interval = step_size
	
	for i in range(road_points.size()):
		var p = road_points[i]
		var in_h = Vector3.ZERO
		var out_h = Vector3.ZERO
		
		if i > 0 and i < road_points.size() - 1:
			var prev = road_points[i-1]
			var next = road_points[i+1]
			var dir = (next - prev).normalized()
			
			var h_len = step_size * smooth_factor
			in_h = -dir * h_len
			out_h = dir * h_len
			
		new_curve.add_point(p, in_h, out_h)
	
	curve = new_curve


func generate_real_random(_seed):
	if not curve:
		curve = Curve3D.new()
	
	var noise = FastNoiseLite.new()
	noise.seed = _seed
	noise.frequency = noise_frequency
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

	var step_size = 1.0 / resolution
	var num_steps = int(total_length_meters * resolution)
	
	var straight_threshold = lerp(0.9, 0.1, curviness)

	var road_points: Array[Vector3] = []
	var current_pos = Vector3.ZERO
	var current_angle = 0.0
	var noise_offset = 1000.0 # Deep in the noise map to avoid artifacts
	
	road_points.push_back(current_pos)

	for i in range(1, num_steps):
		var distance_along_path = i * step_size
		var n = noise.get_noise_1d(noise_offset + distance_along_path)
		
		var steer_per_meter = 0.0
		if abs(n) > straight_threshold:
			var turn_strength = (abs(n) - straight_threshold) / (1.0 - straight_threshold)
			steer_per_meter = turn_strength * sign(n) * max_turn_rate
		
		current_angle += steer_per_meter * step_size
		
		var dir = Vector3(sin(current_angle), 0, cos(current_angle))
		current_pos += dir * step_size
		road_points.push_back(current_pos)

	var new_curve = Curve3D.new()
	new_curve.bake_interval = step_size
	
	for i in range(road_points.size()):
		var p = road_points[i]
		var in_h = Vector3.ZERO
		var out_h = Vector3.ZERO
		
		if i > 0 and i < road_points.size() - 1:
			var prev = road_points[i-1]
			var next = road_points[i+1]
			var dir = (next - prev).normalized()
			
			var h_len = step_size * smooth_factor
			in_h = -dir * h_len
			out_h = dir * h_len
			
		new_curve.add_point(p, in_h, out_h)
	
	curve = new_curve
	
