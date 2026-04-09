extends Node


var socket = StreamPeerTCP.new()
const WIDTH = 640
const HEIGHT = 480

var steer : float
var speed : float
var SPEED_SCALE : float = 0.25
var STEER_SCALE : float = 10.0

var t_steer : float
var t_speed : float

@export var ai_viewport : SubViewport

var waiting_for_ai : bool = false

func _ready():
	socket.connect_to_host("127.0.0.1", 4243)

func _process(delta: float) -> void:
	if not waiting_for_ai:
		test_mode()
	$"..".gas = speed
	$"..".steer = steer
	
	speed = lerp(speed, 0.0, delta*50)
	steer = lerp(steer, 0.0, delta*50)
	
	
	

func send_grayscale_image(render_image):
	render_image.resize(WIDTH, HEIGHT) 
	render_image.convert(Image.FORMAT_L8)
	socket.put_data(render_image.get_data())

func send_mask_image(render_image):
	render_image.resize(WIDTH, HEIGHT) 
	socket.put_data(render_image.get_data())


func reconnect() -> void:
	socket.connect_to_host("127.0.0.1", 4242)


func get_response():
	# Wait until at least 8 bytes (2 floats) are available in the buffer
	while socket.get_available_bytes() < 8:
		socket.poll()
		if socket.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return null
		# Wait for the next engine frame so we don't freeze the game
		await get_tree().process_frame
	
	# Read the 8 bytes
	var result = socket.get_data(8)
	if result[0] == OK:
		var data_bytes = result[1]
		# Decode the little-endian floats (matching struct.pack("<ff", ...))
		var received_speed = data_bytes.decode_float(0)
		var received_steer = data_bytes.decode_float(4)
		return {"speed": received_speed, "steer": received_steer}
	return null

func test_mode():
	waiting_for_ai = true
	socket.poll()
	if socket.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var render_image = await $"..".capture_render_frame()
		send_grayscale_image(render_image)
		
		var res = await get_response()
		
		if res:
			speed = res.speed * SPEED_SCALE
			steer = -res.steer * STEER_SCALE
			print("Speed: " + str(speed) + ", Steer: " + str(steer))
	waiting_for_ai = false
