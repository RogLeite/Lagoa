extends HBoxContainer
class_name Match

# References to Buttons
onready var run_reset_btn := $Gameplay/HBoxContainer/RunResetButton
onready var step_btn := $Gameplay/HBoxContainer/StepButton

export var is_step_by_step : bool = true
export var duck_amount := 1

var threads : Array
var scripts : Array
var controllers : Array

onready var script_scene := preload("res://PlayerScriptTemplate.tscn")
onready var controller_scene := preload("res://DuckControllerTemplate.tscn")
onready var visualization_scene := preload("res://PondVisualization.tscn")
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
	
	# Set the first script tab as visible
	$ScriptTabs.current_tab = 0
	
	reset_match()

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
	# for t in threads :
	# 	print("Thread is %s"%("alive" if t.is_alive() else "inalive"))
	# 	print("Thread is %s\n"%("active" if t.is_active() else "inactive"))
	ThreadSincronizer.give_permission() 
		
# Prepare the threads, ThreadSincronizer, and PondVisualization for a new match
func reset_match():
	run_reset_btn.swap_role("run")

	force_join_controllers()

	var controller_ids := []
	controller_ids.resize(duck_amount)
	
	threads.resize(duck_amount)

	# var bars := []
	# for i in duck_amount:
	# 	# Disconnects ducks from energy bars
	# 	bars.append($Gameplay/EnergyBars.get_node("EnergyBar%d"%i))
	# 	if get_node(PlayerData.ducks[i]).is_connected("energy_changed", bars[i], "set_energy") : 
	# 		get_node(PlayerData.ducks[i]).disconnect("energy_changed", bars[i], "set_energy")

	# var flag := get_tree().GROUP_CALL_REALTIME
	# # Interrupts sound effects
	# get_tree().call_group_flags(flag, "sound_effects", "stop")
	# get_tree().call_group_flags(flag, "sound_effects", "queue_free")
	# # Interrupts visual effects
	# get_tree().call_group_flags(flag, "visual_effects", "stop")
	# get_tree().call_group_flags(flag, "visual_effects", "queue_free")
	
	# # [TODO] Resolve error in Viewport when resetting the visualization with stopped ducks
	# var parent := $Gameplay/PondContainer/PondViewport
	# var old_instance = $Gameplay/PondContainer/PondViewport/PondVisualization
	# var new_instance = visualization_scene.instance()
	# old_instance.name = "PondVisualization_is_queued_for_deletion"
	# old_instance.queue_free()
	# parent.remove_child(old_instance)
	# new_instance.name = "PondVisualization"
	# parent.add_child(new_instance)
	# parent.move_child(new_instance,0)
	CurrentVisualization.get_current().reset()

	for i in duck_amount:
		# Connects Ducks to the energy bars
		# [TODO] Maybe needs to check return value to see if connection was successfull
		# get_node(PlayerData.ducks[i]).connect("energy_changed", bars[i], "set_energy")
		# bars[i].set_energy(100)
		
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
			reset_match()
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
	print("Match seemingly exited the tree graciously")

