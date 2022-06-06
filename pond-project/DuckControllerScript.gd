extends LuaController

export var duck_idx := 0

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
	print("Controller #%d | code : %d | message : \"%s\""%[duck_idx, call_error_code, message])

func tire(value) -> void :
	if get_force_stop():
		return
	
	ThreadSincronizer.await_permission(thread_id)
	var duck = get_duck()
	if duck:
		duck.tire(value)

func swim(angle, target) -> void :
	if get_force_stop():
		return
	
	ThreadSincronizer.await_permission(thread_id)
	var duck = get_duck()
	if duck:
		duck.swim(angle, target)
	
func stop() -> void :
	if get_force_stop():
		return

	ThreadSincronizer.await_permission(thread_id)
	var duck = get_duck()
	if duck:
		duck.stop()

func scan(angle):
	if get_force_stop():
		return "infinity"

	ThreadSincronizer.await_permission(thread_id)
	var duck = get_duck()
	if duck:
		var result = duck.scan(duck_idx, angle)
		if result == INF:
			return "infinity"
		return result
	return "infinity"
	
func launch(angle, distance) : 
	if get_force_stop():
		return

	ThreadSincronizer.await_permission(thread_id)
	var duck = get_duck()
	if duck:
		duck.launcher(angle, distance)

func get_duck():
	return PlayerData.get_duck(duck_idx)
