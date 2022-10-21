extends Control
class_name PondMatch

signal pond_state_updated (p_pond_state)
signal match_run_requested
signal match_reset_requested
signal match_step_requested
signal match_scripts_ended

export var is_visualizing : bool = true
export var is_simulating : bool  = true
export var is_step_by_step : bool = false
export var duck_amount := 4


var is_running : bool = false
var threads : Array
var scripts : Array
var controllers : Array

var pond_state : State setget set_pond_state, get_pond_state
var tick : int
var pond_events: Dictionary setget set_pond_events, get_pond_events
var duck_pond_states : Array setget set_duck_pond_states, get_duck_pond_states
var projectile_pond_states : Array setget set_projectile_pond_states, get_projectile_pond_states

var pond_events_mutex : Mutex

onready var script_scene := preload("res://src/UI/Elements/LuaScriptEditor.tscn")
onready var controller_scene := preload("res://src/World/Characters/DuckController.tscn")

# References to Nodes
onready var run_reset_btn := $UI/Gameplay/HBoxContainer/RunResetButton
onready var step_btn := $UI/Gameplay/HBoxContainer/StepButton

func _init():

	threads = []
	scripts = []
	controllers = []
	
	pond_state = State.new()
	tick = 0
	pond_events = {
		"vfx" : {},
		"sfx" : {}
	}
	duck_pond_states = []
	projectile_pond_states = []

	pond_events_mutex = Mutex.new()

func _ready():
	var pond_visualization := CurrentVisualization.get_current()
	pond_visualization.duck_amount = duck_amount
	pond_visualization.visible = is_visualizing
	pond_visualization.is_simulating = is_simulating
	
	scripts.resize(duck_amount)
	controllers.resize(duck_amount)

	for i in duck_amount:

		scripts[i] = script_scene.instance()
		scripts[i].name = "PlayerScript%d"%i
		$UI/ScriptTabs.add_child(scripts[i])
		
		controllers[i] = controller_scene.instance()
		controllers[i].name = "DuckController%d"%i
		controllers[i].duck_idx = i
		add_child(controllers[i])
		
	# Set the first script tab as visible
	$UI/ScriptTabs.current_tab = 0

	# pond_match initialization occurs in reset_pond_match()

	reset_pond_match()

func _physics_process(_delta: float) -> void:
	if is_running:
		if not is_step_by_step:
			script_step()
		if are_controllers_finished() :
			is_running = false
			join_controllers()
			CurrentVisualization.get_current().stop()
			emit_signal("match_scripts_ended")

# [TODO] Implement
func add_script(_username : String, _script : String) -> void:
	pass

# If it's is_running, busy waits for every thread to arrive
func script_step():
	if not is_running : 
		return
	# Clears the events to register
	tick += 1
	while not ThreadSincronizer.everyone_arrived() :
		continue
	if is_simulating:
		emit_signal("pond_state_updated", self.pond_state)
	
	clear_events()
	ThreadSincronizer.give_permission() 
		
# Prepare the threads, ThreadSincronizer, and PondVisualization for a new match
func reset_pond_match():
	run_reset_btn.swap_role("run")
	step_btn.hide()

	tick = 0
	clear_events()

	force_join_controllers()

	var controller_ids := []
	controller_ids.resize(duck_amount)
	
	threads.resize(duck_amount)

	CurrentVisualization.get_current().reset()

	for i in duck_amount:
		threads[i] = Thread.new()		
		# Store the instance id to use with ThreadSincronizer.prepare_participants()
		controller_ids[i] = controllers[i].get_instance_id()
		
		#Connects a Duck's energy_changed signal to it's corresponding energy bar
		# [TODO] Make the duck's signals and connections not a problem for PondMatch (maybe delegate to a "set_energy_visualization" method) 
		#warning-ignore: return_value_discarded
		var duck : Duck = PlayerData.get_duck(i)
		var bar : EnergyBar = find_node("EnergyBar%d"%i)
		if not duck.is_connected("energy_changed", bar, "set_energy"):
			duck.connect("energy_changed", bar, "set_energy")

	# The script execution threads use the instance_id of the LuaController node
	ThreadSincronizer.prepare_participants(controller_ids)

	# Initializes pond_state
	pond_state = State.new(self.tick, self.duck_amount, self.pond_events, self.duck_pond_states, self.projectile_pond_states)
	

func run():
	run_reset_btn.swap_role("reset")
	step_btn.visible = is_step_by_step

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

func set_pond_events(p_events_state : Dictionary):
	pond_events_mutex.lock()

	var current := CurrentVisualization.get_current()
	# Pushes sfx
	current.play_sfx(p_events_state["sfx"])
	
	# Pushes vfx
	current.play_vfx(p_events_state["vfx"])
	
	pond_events_mutex.unlock()

func get_pond_events() -> Dictionary :
	pond_events_mutex.lock()
	var ret = pond_events
	pond_events_mutex.unlock()
	return ret


func clear_events():
	pond_events = {
		"sfx" : {},
		"vfx" : {
			"vision_cone" : [],
			"blast" : []
		}
	}


func get_duck_pond_states() -> Array:
	var states := PlayerData.get_ducks_array()
	for i in states.size():
		states[i] = states[i].pond_state
	return states
func set_duck_pond_states(p_states : Array) :
	var ducks := PlayerData.get_ducks_array()
	for i in ducks.size():
		if i < p_states.size():
			ducks[i].pond_state = p_states[i]
			ducks[i].set_participating(true)
			# ducks[i].show()
		else:
			ducks[i].set_participating(false)
			# ducks[i].hide()

func get_projectile_pond_states() -> Array:
	return CurrentVisualization.get_current().projectile_pond_states
func set_projectile_pond_states(p_states : Array) :
	CurrentVisualization.get_current().projectile_pond_states = p_states
	
func get_pond_state() -> State:
	pond_state.tick = self.tick
	pond_state.duck_amount = self.duck_amount
	pond_state.pond_events = self.pond_events
	pond_state.duck_pond_states = self.duck_pond_states
	pond_state.projectile_pond_states = self.projectile_pond_states
	return pond_state

func set_pond_state(p_state : State) -> void:
	self.tick = p_state.tick
	self.duck_amount = p_state.duck_amount
	self.pond_events = p_state.pond_events
	self.duck_pond_states = p_state.duck_pond_states
	self.projectile_pond_states = p_state.projectile_pond_states
	pond_state = p_state


func _on_PondVisualization_sfx_played(p_effect_name : String):
	pond_events_mutex.lock()
	pond_events["sfx"][p_effect_name] = true
	pond_events_mutex.unlock()

func _on_PondVisualization_vfx_played(p_effect_name: String, p_pond_state):
	pond_events_mutex.lock()
	pond_events["vfx"][p_effect_name].push_back(p_pond_state)
	pond_events_mutex.unlock()


func _on_StepButton_pressed():
	emit_signal("match_step_requested")


func _on_RunResetButton_reset():
	emit_signal("match_reset_requested")


func _on_RunResetButton_run():
	emit_signal("match_run_requested")

#JSONable class for PondMath
class State extends JSONable:
	var tick : int
	var duck_amount : int
	var pond_events : Dictionary
	var duck_pond_states : Array
	var projectile_pond_states : Array

	
	func _init(
		p_tick := 0,
		p_duck_amount := 0,
		p_pond_events := {
			"vfx" : {
				"vision_cone" : [],
				"blast" : []
			},
			"sfx" : {}
		},
		p_duck_pond_states := [],
		p_projectile_pond_states := []):
		tick = p_tick
		duck_amount = p_duck_amount
		pond_events = p_pond_events
		duck_pond_states = p_duck_pond_states
		projectile_pond_states = p_projectile_pond_states

	func to(pond_match : PondMatch = null) -> Dictionary:
		if pond_match:
			tick = pond_match.tick
			duck_amount = pond_match.duck_amount
			pond_events = pond_match.pond_events
			duck_pond_states = pond_match.duck_pond_states
			projectile_pond_states = pond_match.projectile_pond_states

		# Populates `pond_events` with Strings converted from the State's booleans
		# To possibly avoid bugs when Nakama receives the message
		var events_dict := {
			"vfx" : {
				"vision_cone" : [],
				"blast" : []
			},
			"sfx" : {}
		}
		for fx_name in pond_events["sfx"]:
			events_dict["sfx"][fx_name] = "true" if pond_events["sfx"][fx_name] else "false"
		
		if pond_events["vfx"].has("vision_cone"):
			var cone_states := []
			for cone_state in pond_events["vfx"]["vision_cone"] :
				cone_states.append(cone_state.to())
			events_dict["vfx"]["vision_cone"] = cone_states

		if pond_events["vfx"].has("blast"):
			var blast_states := []
			for blast_state in pond_events["vfx"]["blast"] :
				blast_states.append(blast_state.to())
			events_dict["vfx"]["blast"] = blast_states


		var duck_states := []
		for elem in duck_pond_states:
			duck_states.append(elem.to())

		var projectile_states := []
		for elem in projectile_pond_states:
			projectile_states.append(elem.to())

		return {
			"tick" : tick,
			"duck_amount" : duck_amount,
			"pond_events" : events_dict,
			"duck_pond_states" : duck_states,
			"projectile_pond_states" : projectile_states
		}
		
	func from(p_from : Dictionary) -> JSONable:
		tick = p_from.tick
		duck_amount = p_from.duck_amount
		pond_events = {}
		duck_pond_states = []
		projectile_pond_states = []

		# Populates `pond_events` with booleans converted p_from the received Dictionary's Strings
		pond_events = p_from.pond_events.duplicate(true)
		for fx_name in p_from.pond_events["sfx"]:
			pond_events[fx_name] = true if p_from.pond_events.has(fx_name) and p_from.pond_events[fx_name] == "true" else false
		
		
		if pond_events["vfx"].has("vision_cone"):
			for i in pond_events["vfx"]["vision_cone"].size() :
				pond_events["vfx"]["vision_cone"][i] = VisionCone.State.new().from(pond_events["vfx"]["vision_cone"][i])

		if pond_events["vfx"].has("blast"):
			for i in pond_events["vfx"]["blast"].size() :
				pond_events["vfx"]["blast"][i] = Blast.State.new().from(pond_events["vfx"]["blast"][i])

		# Populates `duck_pond_states` with states converted from the received Dictionary
		for elem in p_from.duck_pond_states:
			duck_pond_states.append(Duck.State.new().from(elem))

		# Populates `projectile_pond_states` with states converted from the received Dictionary
		for elem in p_from.projectile_pond_states:
			projectile_pond_states.append(Projectile.State.new().from(elem))
		
		return self
