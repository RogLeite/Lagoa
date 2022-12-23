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
export var can_send_script : bool = false


var is_running : bool = false
var threads : Array
var scripts : Array
var controllers : Array
var controller_ids : Array

var pond_state : State setget set_pond_state, get_pond_state
var tick : int
var pond_events: Dictionary setget set_pond_events, get_pond_events
var duck_pond_states : Array setget set_duck_pond_states, get_duck_pond_states
var projectile_pond_states : Array setget set_projectile_pond_states, get_projectile_pond_states
var pond_events_mutex : Mutex

var _reset_requested : bool


onready var script_scene := preload("res://src/UI/Elements/LuaScriptEditor.tscn")
onready var controller_scene := preload("res://src/World/Characters/DuckController.tscn")

# References to Nodes
onready var run_reset_btn := $UI/Gameplay/HBoxContainer/RunResetButton
onready var step_btn := $UI/Gameplay/HBoxContainer/StepButton
onready var send_script_btn := $UI/Gameplay/HBoxContainer/SendScriptButton

func _init():

	threads = []
	scripts = []
	controllers = [] 
	controller_ids = [] 
	
	pond_state = State.new()
	tick = 0
	pond_events = {
		"vfx" : {},
		"sfx" : {}
	}
	duck_pond_states = []
	projectile_pond_states = []

	pond_events_mutex = Mutex.new()
	
	_reset_requested = false

func _ready():
	var pond_visualization := CurrentVisualization.get_current()
	pond_visualization.visible = is_visualizing
	pond_visualization.is_simulating = is_simulating
	
	send_script_btn.visible = can_send_script
	
	threads.resize(PlayerData.MAX_PLAYERS_PER_MATCH)
	scripts.resize(PlayerData.MAX_PLAYERS_PER_MATCH)
	controllers.resize(PlayerData.MAX_PLAYERS_PER_MATCH)

	# If there are already players, enable them
	for i in PlayerData.count():
		if PlayerData.is_present(i):
			enable_player(i)

	# pond_match initialization occurs in reset_pond_match()

	reset_pond_match()

	
	# Connects signals
	# warning-ignore:return_value_discarded
	PlayerData.connect("player_joined", self, "_on_PlayerData_player_joined")
	# warning-ignore:return_value_discarded
	PlayerData.connect("player_left", self, "_on_PlayerData_player_left")
	# warning-ignore:return_value_discarded
	PlayerData.connect("pond_script_changed", self, "_on_PlayerData_pond_script_changed")

func _physics_process(_delta: float) -> void:
	if is_running:
		if not is_step_by_step:
			script_step()
		if are_controllers_finished() :
			is_running = false
			join_controllers()
			CurrentVisualization.get_current().stop()
			emit_signal("match_scripts_ended")

# [TODO] Allows adding a script to PondMatch
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
# No matter how many times its called, the reset occurs once in the next idle frame
func reset_pond_match() -> void:
	if not _reset_requested:
		call_deferred("_reset_pond_match")
		_reset_requested = true
		set_deferred("_reset_requested", false)
	
func _reset_pond_match() -> void:
	run_reset_btn.swap_role("run")
	step_btn.hide()

	tick = 0
	clear_events()

	force_join_controllers()

	var player_count : int = PlayerData.count()	

	CurrentVisualization.get_current().reset()

	for i in player_count:
		if not PlayerData.is_present(i):
			continue
		
		#Connects a Duck's energy_changed signal to it's corresponding energy bar
		# [TODO] Make the duck's signals and connections not a problem for PondMatch (maybe delegate to a "set_energy_visualization" method) 
		#warning-ignore: return_value_discarded
		var duck : Duck = PlayerData.get_duck_node(i)
		var bar : EnergyBar = find_node("EnergyBar%d"%i)
		if not duck.is_connected("energy_changed", bar, "set_energy"):
			duck.connect("energy_changed", bar, "set_energy")

	# The script execution threads use the instance_id of the LuaController node
	ThreadSincronizer.prepare_participants(controller_ids)

	# Initializes pond_state
	pond_state = State.new(self.tick, self.pond_events, self.duck_pond_states, self.projectile_pond_states)
	

func run():
	run_reset_btn.swap_role("reset")
	step_btn.visible = is_step_by_step

	var player_count : int = PlayerData.count()
	var successfully_compiled := true
	for i in player_count:
		# Skips absent Players
		if not PlayerData.is_present(i):
			continue
		
		# [TODO] when implemented, grab the script from PlayerData/Datum
		controllers[i].set_lua_code(scripts[i].text)
		var error_message = ""
		if controllers[i].compile() != OK :
			successfully_compiled = false
			error_message = controllers[i].get_error_message()
			if error_message != "" :
				# [TODO] Better compilation error treatment; Maybe a signal warning the error
				# I could also parse the error message to get the line with error and highlight it 
				print("Compilation error in controller %d " % i + error_message)

	if successfully_compiled:
		var any_thread_failed := false
		for i in player_count:
			# Skips absent Players
			if not PlayerData.is_present(i):
				continue
			
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
	if return_code != OK:
		# [TODO] Better error treatment. Maybe a log? Maybe a return value?
		print("When thread %d finished: " % index + controllers[index].get_error_message())
	return return_code

# Force threads to stop and then joins them
func force_join_controllers() :
	if not is_running:
		return

	for ctrl in controllers:
		if ctrl:
			ctrl.set_force_stop(true)
	
	ThreadSincronizer.give_permission()

	join_controllers()
	
# join_controllers() only checks if a thread exists before trying to join 
func join_controllers():
	for thread in threads :
		if thread :
			# warning-ignore:return_value_discarded
			thread.wait_to_finish()
	is_running = false

func are_controllers_finished() -> bool :
	for thread in threads : 
		if thread and thread.is_alive():
			return false
	return true

func enable_player(p_index : int):
	var new_script : bool = not scripts[p_index]
	if new_script:
		scripts[p_index] = script_scene.instance()
		$UI/ScriptTabs.add_child(scripts[p_index])
	
	scripts[p_index].name = PlayerData.players[p_index].username

	threads[p_index] = Thread.new()

	if controllers[p_index]:
		push_error("In PondMatch.enable_player:\n\tOverwriting a controller without removing it first. controller_ids will hold invalid ids and there will be more controllers than expected in the tree. Somehow a enable was called after a enable. If this is expected, I need to protect controllers and controller_ids.")

	controllers[p_index] = controller_scene.instance()
	controllers[p_index].name = "DuckController%d"%p_index
	controllers[p_index].duck_idx = p_index
	add_child(controllers[p_index])
	
	controller_ids.push_back(controllers[p_index].get_instance_id())

	reset_pond_match()

# Remover controllers e scripts dos players que não participarão
func disable_player(p_index : int):
	scripts[p_index] = null

	threads[p_index] = null

	if not controllers[p_index]:
		push_error("In PondMatch.disable_player:\n\tTrying to twice remove a controller. Somehow a disable was called after a disable. If this is expected, I need to protect controllers.")

	var node = get_node(controllers[p_index].name)
	controllers[p_index] = null
	remove_child(node)

	controller_ids.erase(node.get_instance_id())

	node.queue_free()
	
	reset_pond_match()

func _exit_tree():
	force_join_controllers()
	if PlayerData.is_connected("player_joined", self, "_on_PlayerData_player_joined"):
		PlayerData.disconnect("player_joined", self, "_on_PlayerData_player_joined")
	if PlayerData.is_connected("player_left", self, "_on_PlayerData_player_left"):
		PlayerData.disconnect("player_left", self, "_on_PlayerData_player_left")
	if PlayerData.is_connected("pond_script_changed", self, "_on_PlayerData_pond_script_changed"):
		PlayerData.disconnect("pond_script_changed", self, "_on_PlayerData_pond_script_changed")

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
	var nodes : Array =  PlayerData.get_duck_nodes()
	var states := []
	for node in nodes:
		states.push_back(node.pond_state)
	return states
func set_duck_pond_states(p_states : Array) :
	var ducks : Array = PlayerData.get_duck_nodes()
	for i in ducks.size():
		if i < p_states.size() and PlayerData.is_present(i):
			ducks[i].pond_state = p_states[i]
			ducks[i].set_participating(true)
		else:
			ducks[i].set_participating(false)

func get_projectile_pond_states() -> Array:
	return CurrentVisualization.get_current().projectile_pond_states
func set_projectile_pond_states(p_states : Array) :
	CurrentVisualization.get_current().projectile_pond_states = p_states
	
func get_pond_state() -> State:
	pond_state.tick = self.tick
	pond_state.pond_events = self.pond_events
	pond_state.duck_pond_states = self.duck_pond_states
	pond_state.projectile_pond_states = self.projectile_pond_states
	return pond_state

func set_pond_state(p_state : State) -> void:
	self.tick = p_state.tick
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

func _on_PlayerData_player_joined(p_index : int):
	if not is_running:
		enable_player(p_index)

func _on_PlayerData_player_left(p_index : int):
	if not is_running:
		disable_player(p_index)

func _on_PlayerData_pond_script_changed(p_index : int, p_pond_script : String):
	pass


func _on_StepButton_pressed():
	emit_signal("match_step_requested")


func _on_RunResetButton_reset():
	emit_signal("match_reset_requested")


func _on_RunResetButton_run():
	emit_signal("match_run_requested")

#JSONable class for PondMath
class State extends JSONable:
	var tick : int
	var pond_events : Dictionary
	var duck_pond_states : Array
	var projectile_pond_states : Array

	
	func _init(
		p_tick := 0,
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
		pond_events = p_pond_events
		duck_pond_states = p_duck_pond_states
		projectile_pond_states = p_projectile_pond_states

	func to(pond_match : PondMatch = null) -> Dictionary:
		if pond_match:
			tick = pond_match.tick
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
			"pond_events" : events_dict,
			"duck_pond_states" : duck_states,
			"projectile_pond_states" : projectile_states
		}
		
	func from(p_from : Dictionary) -> JSONable:
		tick = p_from.tick
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
