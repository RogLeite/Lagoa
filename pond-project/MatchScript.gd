extends HBoxContainer
class_name Match

# [TODO] Make this scene adaptable to any number of players

onready var scripts := [$ScriptTabs/PlayerScript1, $ScriptTabs/PlayerScript2]
onready var controllers := [$DuckController1, $DuckController2]

var threads : Array

func _ready():
	threads.resize(controllers.size())

func run():
	
	# Inclui 0 e 1, exclui 2
	for i in 2:
		controllers[i].set_lua_code(scripts[i].text)
		var error_message = ""
		if controllers[i].compile() != OK :
			error_message = controllers[i].get_error_message()
		else:
			threads[i] = Thread.new()
			assert(threads[i].start(controllers[i], "run") == OK, "thread for controller %d can't be created" % i)

		if error_message != "" :
			print_debug("Compilation error in controller %d " % i + error_message)


# Thread must be disposed (or "joined"), for portability.
func _exit_tree():
	# [TODO] Take the code out of this method, so Match can check regularly if the script had any error
	# [TODO] Also: use is_alive() so i don't get blocked on the call to wait_to_finish
	for i in 2:
		var run_returned = threads[i].wait_to_finish()
		if run_returned != OK:
			print_debug("When thread %d finished: " % i +controllers[i].get_error_message())
