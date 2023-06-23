extends LuaController

export var duck_idx := 0

onready var thread_id := get_instance_id()

func _ready():	
	set_methods_to_register({
		"swim":"swim",
		"scan":"scan",
		"launch":"launch",
		"energy":"energy",
		"getX":"getX",
		"getY":"getY",
		"speed":"speed"
		# "stop":"stop",
		# "tire":"tire"
		})
	
# [TODO] Write a good error handler for DuckControllerScript
func lua_error_handler(call_error_code: int, message: String) -> void:
	print("Controller #%d | code : %d | message : \"%s\""%[duck_idx, call_error_code, message])

func tire(value) -> void :
	if get_force_stop():
		return
	
	ThreadSincronizer.await_permission(thread_id)
	var duck = get_duck_node()
	if duck:
		duck.tire(value)

func swim(angle, target) -> void :
	if get_force_stop():
		return
	
	ThreadSincronizer.await_permission(thread_id)
	var duck = get_duck_node()
	if duck:
		duck.swim(angle, target)
	
func stop() -> void :
	if get_force_stop():
		return

	ThreadSincronizer.await_permission(thread_id)
	var duck = get_duck_node()
	if duck:
		duck.stop()

func scan(angle):
	if get_force_stop():
		return "infinity"

	ThreadSincronizer.await_permission(thread_id)
	var duck = get_duck_node()
	if duck:
		var result = duck.scan(duck_idx, angle)
		if result == INF:
			return "infinity"
		return result
	return "infinity"

func energy():
	if get_force_stop():
		return 100

	ThreadSincronizer.await_permission(thread_id)
	var duck = get_duck_node()
	if not duck:
		return 100
	return duck.energy

func getX():
	if get_force_stop():
		return 0

	ThreadSincronizer.await_permission(thread_id)
	var duck = get_duck_node()
	if not duck:
		return 0
	return duck.getX() 

func getY():
	if get_force_stop():
		return 0

	ThreadSincronizer.await_permission(thread_id)
	var duck = get_duck_node()
	if not duck:
		return 0
	return duck.getY()

func speed():
	if get_force_stop():
		return 0

	ThreadSincronizer.await_permission(thread_id)
	var duck = get_duck_node()
	if not duck:
		return 0
	return duck.speed
	
func launch(angle, distance) : 
	if get_force_stop():
		return false

	ThreadSincronizer.await_permission(thread_id)
	var duck = get_duck_node()
	if duck:
		return duck.launcher(angle, distance)
	return false

func get_duck_node():
	return PlayerData.get_duck_node(duck_idx)
