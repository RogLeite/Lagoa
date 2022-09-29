extends HBoxContainer
class_name PondMatch

# References to Buttons
onready var run_reset_btn := $Gameplay/HBoxContainer/RunResetButton
onready var step_btn := $Gameplay/HBoxContainer/StepButton

export var is_step_by_step : bool = true
export var duck_amount := 1

var tick : int

var is_running : bool = false
var threads : Array
var scripts : Array
var controllers : Array

var pond_state : State setget set_pond_state, get_pond_state
var duck_pond_states : Array setget set_duck_pond_states, get_duck_pond_states

onready var script_scene := preload("res://src/UI/Elements/LuaScriptEditor.tscn")
onready var controller_scene := preload("res://src/World/Characters/DuckController.tscn")
onready var visualization_scene := preload("res://src/World/PondVisualization.tscn")


func _ready():
	tick = -1

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

	pond_state = State.new(self.tick, self.duck_amount, self.duck_pond_states)

	reset_pond_match()

func _physics_process(_delta: float) -> void:
	if not is_step_by_step:
		tick += 1
		script_step()
		# [TODO] If is a master in a multiplayer match, emit the state.
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

	tick = 0

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

func get_duck_pond_states() -> Array:
	var states := PlayerData.get_ducks_array()
	for i in states.size():
		states[i] = states[i].pond_state
	return states
func set_duck_pond_states(p_states : Array) :
	var ducks := PlayerData.get_ducks_array()
	for i in ducks.size():
		ducks[i].pond_state = p_states[i]

func get_pond_state() -> State:
	pond_state.tick = self.tick
	pond_state.duck_amount = self.duck_amount
	pond_state.duck_pond_states = self.duck_pond_states
	return pond_state

func set_pond_state(p_state : State) -> void:
	self.tick = p_state.tick
	self.duck_amount = p_state.duck_amount
	self.duck_pond_states = p_state.duck_pond_states
	pond_state = p_state

# [TODO] Also store the "events". Or, at least, change it into two properties: VFX and SFX
#JSONable class for PondMath
class State extends JSONable:
	var tick : int
	var duck_amount : int
	var duck_pond_states : Array
	# var events : Dictionary

	
	func _init(p_tick := -1, p_duck_amount := 0, p_duck_pond_states := []):
	# func _init(p_tick := -1, p_duck_amount := 0, p_duck_pond_states := [], p_events):
		tick = p_tick
		duck_amount = p_duck_amount
		duck_pond_states = p_duck_pond_states

	func to(pond_match : PondMatch = null) -> Dictionary:
		if pond_match:
			tick = pond_match.tick
			duck_amount = pond_match.duck_amount
			duck_pond_states = pond_match.duck_pond_states

		var states := []
		for elem in duck_pond_states:
			states.append(elem.to())

		return {
			"tick" : tick,
			"duck_amount" : duck_amount,
			"duck_pond_states" : states
		}
		
	func from(from : Dictionary) -> JSONable:
		tick = from.tick
		duck_amount = from.duck_amount
		duck_pond_states = []

		# Populates `duck_pond_states` with states converted from the received Dictionary
		for elem in from.duck_pond_states:
			duck_pond_states.append(Duck.State.new().from(elem))
		
		return self
