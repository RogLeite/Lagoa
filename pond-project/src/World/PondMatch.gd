extends HBoxContainer
class_name PondMatch

# References to Buttons
onready var run_reset_btn := $Gameplay/HBoxContainer/RunResetButton
onready var step_btn := $Gameplay/HBoxContainer/StepButton

export var is_step_by_step : bool = true
export var duck_amount := 1

var threads : Array
var scripts : Array
var controllers : Array

onready var script_scene := preload("res://src/UI/Elements/LuaScriptEditor.tscn")
onready var controller_scene := preload("res://src/World/Characters/DuckController.tscn")
onready var visualization_scene := preload("res://src/World/PondVisualization.tscn")
var is_running : bool = false


func _ready():
	step_btn.visible = is_step_by_step
	
	scripts.resize(duck_amount)
	controllers.resize(duck_amount)

	for i in duck_amount:

		scripts[i] = script_scene.instance()
		scripts[i].name = "PlayerScript%d"%i
		$ScriptTabs.add_child(scripts[i])
		
		controllers[i] = controller_scene.instance()
		controllers[i].name = "DuckController%d"%i
		controllers[i].duck_idx = i
		add_child(controllers[i])
		
		#Connects a Duck's energy_changed signal to it's corresponding energy bar
		# [TODO] Make the duck's signals and connections not a problem for PondMatch (maybe delegate to a "set_energy_visualization" method) 
		#warning-ignore: return_value_discarded
		PlayerData.get_duck(i).connect("energy_changed", find_node("EnergyBar%d"%i), "set_energy")
		
	# Set the first script tab as visible
	$ScriptTabs.current_tab = 0
	
	reset_pond_match()

func _physics_process(_delta: float) -> void:
	if not is_step_by_step:
		script_step()
	if is_running and are_controllers_finished() :
		is_running = false
		join_controllers()

# If it's is_running, busy waits for every thread to arrive
func script_step():
	if not is_running : 
		return
	while not ThreadSincronizer.everyone_arrived() :
		continue
	ThreadSincronizer.give_permission() 
		
# Prepare the threads, ThreadSincronizer, and PondVisualization for a new match
func reset_pond_match():
	run_reset_btn.swap_role("run")

	force_join_controllers()

	var controller_ids := []
	controller_ids.resize(duck_amount)
	
	threads.resize(duck_amount)

	CurrentVisualization.get_current().reset()

	for i in duck_amount:
		threads[i] = Thread.new()		
		# Store the instance id to use with ThreadSincronizer.prepare_participants()
		controller_ids[i] = controllers[i].get_instance_id()

	# The script execution threads use the instance_id of the LuaController node
	ThreadSincronizer.prepare_participants(controller_ids)
	

func run():
	run_reset_btn.swap_role("reset")

	var successfully_compiled := true
	for i in duck_amount:
		# [TODO] when implemented, grab the script from PlayerData/Datum
		controllers[i].set_lua_code(scripts[i].text)
		var error_message = ""
		if controllers[i].compile() != OK :
			successfully_compiled = false
			error_message = controllers[i].get_error_message()
			if error_message != "" :
				# [TODO] Better compilation error treatment; Maybe a alert icon.
				# I could also parse the error message to get the line with error and highlight it 
				print("Compilation error in controller %d " % i + error_message)

	if successfully_compiled:
		var any_thread_failed := false
		for i in duck_amount:
			if threads[i].start(self, "controller_run_wrapper", i) != OK:
				push_error("thread for controller %d can't be created" % i)
				any_thread_failed = true
				break
		if any_thread_failed:
			reset_pond_match()
			is_running = false
		else:
			is_running = true
		

func controller_run_wrapper(index : int) -> int :
	var return_code = controllers[index].run()
	ThreadSincronizer.remove_participant(controllers[index].get_instance_id())
	# print("Thread %d finished"%index)
	if return_code != OK:
		# [TODO] Better error treatment. Maybe a log? Maybe a return value?
		print("When thread %d finished: " % index + controllers[index].get_error_message())
	return return_code

# Force threads to stop and then joins them
func force_join_controllers() :
	if not is_running:
		return

	for ctrl in controllers:
		ctrl.set_force_stop(true)
	
	ThreadSincronizer.give_permission()

	join_controllers()
	
# join_controllers() only checks if a thread exists before trying to join 
func join_controllers():
	for thread in threads :
		if thread != null :
			var _run_return = thread.wait_to_finish()
	is_running = false

func are_controllers_finished() -> bool :
	for thread in threads : 
		if thread.is_alive():
			return false
	return true

func _exit_tree():
	force_join_controllers()
	# print("Match seemingly exited the tree graciously")

# [TODO] Implement the class as adapter for PondMatch, not the fake match used in multiplayer tests
#JSONable class for PondMath
class State extends JSONable:
	var ball_position : Vector2
	
	func _init(p_ball_position := Vector2.ZERO):
		ball_position = p_ball_position
	
	func to() -> Dictionary:
		return {"ball_position" : .vector2_to(ball_position)}
		
	func from(from : Dictionary) -> JSONable:
		ball_position = .vector2_from(from.ball_position)
		return self
