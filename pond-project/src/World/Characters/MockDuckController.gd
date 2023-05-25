extends LuaController

onready var thread_id := get_instance_id()

func _ready():	
	set_methods_to_register({
		"swim":"swim",
		"stop":"stop",
		"scan":"scan",
		"launch":"launch",
		"tire":"tire" # [TODO] Remove this method in the final version
		})

# [TODO] Write a good error handler for DuckControllerScript
func lua_error_handler(call_error_code: int, message: String) -> void:
	print("MockDuckController | code : %d | message : \"%s\""%[call_error_code, message])

func tire(_value) -> void :
	if get_force_stop():
		return

func swim(_angle, _target) -> void :
	if get_force_stop():
		return
	
func stop() -> void :
	if get_force_stop():
		return

func scan(_angle):
	if get_force_stop():
		return "infinity"

	if randi()%10 == 0:
		return "infinity"
		
	return randi()%600
	
func launch(_angle, _distance) : 
	if get_force_stop():
		return
