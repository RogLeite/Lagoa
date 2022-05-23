extends LuaController

export var duck_idx := 0

onready var thread_id := get_instance_id()

func _ready():	
	set_methods_to_register({
		"swim":"swim",
		"stop":"stop",
		"kill":"kill"
		})
	
# [TODO] Write a good error handler for DuckControllerScript
func lua_error_handler(call_error_code: int, message: String) -> void:
	print("Controller #%d | code : %d | message : \"%s\""%[duck_idx, call_error_code, message])

func kill() -> void :
	if get_force_stop():
		return
	
	ThreadSincronizer.await_permission(thread_id)
	# print("Controller %d Called kill()"%duck_idx)
	set_force_stop(true)
	# print("Controller %d get_force_stop() = %s"% [duck_idx, ("true" if get_force_stop() else "false")] )

func swim(angle, target) -> void :
	if get_force_stop():
		return
	
	ThreadSincronizer.await_permission(thread_id)
	var duck = get_duck()
	# duck.call_deferred("swim", angle, target)
	if duck:
		duck.swim(angle, target)
	
func stop() -> void :
	if get_force_stop():
		return

	ThreadSincronizer.await_permission(thread_id)
	var duck = get_duck()
	# duck.call_deferred("stop")
	if duck:
		duck.stop()
	
func get_duck():
	var path = PlayerData.ducks[duck_idx]
	if is_inside_tree() and has_node(path):
		return get_node(path)
	else:
		return null
