extends LuaController

onready var thread_id := get_instance_id()

var energy : int = 100 setget , get_energy
var speed : int = 0
var angle : int = 0
var x : float = 50 setget , get_x
var y : float = 50 setget , get_y

func _ready():	
	set_methods_to_register({
		"swim":"swim",
		"scan":"scan",
		"launch":"launch",
		"_energy":"energy",
		"getX":"getX",
		"getY":"getY",
		"_speed":"speed"
#		"stop":"stop",
#		"tire":"tire"
		})

# [TODO] Write a good error handler for DuckControllerScript
func lua_error_handler(call_error_code: int, message: String) -> void:
	print("MockDuckController | code : %d | message : \"%s\""%[call_error_code, message])

func get_energy() -> int:
	if randi()%10 != 0:
		return energy
	energy = max( 0, energy - (randi()%15) + 1) as int
	return energy

func get_y() -> float:
	if randi()%3 != 0:
		return y
	var newy = y + sin(angle) * speed
	newy = min(100, newy)
	newy = max(0  , newy)
	y = newy
	return y

func get_x() -> float:
	if randi()%3 != 0:
		return x
	var newx = x + cos(angle) * speed
	newx = min(100, newx)
	newx = max(0  , newx)
	x = newx
	return x

func tire(_value) -> void :
	if get_force_stop():
		return

func swim(p_angle, p_target) -> void :
	if get_force_stop():
		return
	angle = p_angle
	speed = p_target
	

func stop() -> void :
	if get_force_stop():
		return

func scan(_angle):
	if get_force_stop():
		return "infinity"

	if randi()%5 == 0:
		return randi()%600
		
	return "infinity"
	
func launch(_angle, _distance) -> bool: 
	if get_force_stop():
		return false
	
	if randi()%4 == 0:
		return true
		
	return false


func _energy():
	if get_force_stop():
		return energy

	return self.energy

func getX():
	if get_force_stop():
		return x

	return self.x

func getY():
	if get_force_stop():
		return y

	return self.y

func _speed():
	if get_force_stop():
		return 0

	return speed
