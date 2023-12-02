extends Control
class_name PondMatch

signal pond_state_updated (p_pond_state)
signal match_run_requested
signal match_reset_requested
signal match_step_requested
signal match_scripts_ended
signal match_quit_requested
signal match_ended
signal send_pond_script_requested
signal reset_finished

signal match_run_started
signal match_run_stopped

const WINNER_TEMPLATE : String = "<NO WINNER DECLARED>"
const TIMER_DEFAULT : String = "-:--:--"
const TIMER_TEMPLATE : String = "%d:%02d:%02s"


# Duration of the match in seconds
export(int, 10, 300) var match_duration : int = 120
# Is the scene rendering the pond
export var is_visualizing_pond : bool = true
# Is physics_process running for visualization
export var is_visualization_physics_processing : bool  = true
# Is the scene emitting the "pond_state_updated" signal
export var is_emitting_state : bool  = false
# Will the scripts wait for the signal to continue
export var is_step_by_step : bool = false
# If true, cannot run the match with the other ducks' scripts, only simulate 
export var can_only_simulate_match : bool = false
# Are the tabs of other player's scripts visible 
export var can_see_scripts : bool  = true
# Are other player's scripts editable
export var can_edit_scripts : bool  = true
# Enables the "send_script" button
export var can_send_pond_script : bool = false


var is_running : bool = false setget set_is_running
var threads : Array
var script_editors : Array # Array of TextEdit
var controllers : Array
var controller_ids : Array
var back_disabled : bool = false setget set_back_disabled
var mock_controller : LuaController
var mock_thread : Thread

# Members updated in `pond_state`
var pond_state : State setget set_pond_state, get_pond_state
var tick : int
var pond_events: Dictionary setget set_pond_events, get_pond_events
var duck_pond_states : Array setget set_duck_pond_states, get_duck_pond_states
var projectile_pond_states : Array setget set_projectile_pond_states, get_projectile_pond_states
var time_left : float setget set_time_left, get_time_left

var winner : String = WINNER_TEMPLATE

var _ducks_tired : TiredRegistry

onready var nothing_script := preload("res://resources/LuaScripts/nothing.tres")

onready var script_scene := preload("res://src/UI/Elements/LuaScriptEditor.tscn")
onready var controller_scene := preload("res://src/World/Characters/DuckController.tscn")
onready var mock_controller_scene := preload("res://src/World/Characters/MockDuckController.tscn")

# References to Nodes
onready var quit_btn := $UI/MarginContainer/Gameplay/HBoxContainer/QuitButton
onready var run_reset_btn := $UI/MarginContainer/Gameplay/HBoxContainer/RunResetButton
onready var simulate_reset_btn := $UI/MarginContainer/Gameplay/HBoxContainer/SimulateResetButton
onready var step_btn := $UI/MarginContainer/Gameplay/HBoxContainer/StepButton
onready var send_pond_script_btn := $UI/MarginContainer/Gameplay/HBoxContainer/SendScriptButton
onready var scripts_tab_container := $UI/Editor/ScriptTabs
onready var lua_script_status := $UI/Editor/ScriptStatus
onready var match_timer := $MatchTimer
onready var timer_label := $TimerLabel

func _init():

	threads = []
	script_editors = []
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

	_ducks_tired = TiredRegistry.new()

func _ready():
	var pond_visualization := CurrentVisualization.get_current()
	pond_visualization.visible = is_visualizing_pond
	pond_visualization.is_visualization_physics_processing = is_visualization_physics_processing
	
	step_btn.visible = is_step_by_step
	send_pond_script_btn.visible = can_send_pond_script
	run_reset_btn.visible = not can_only_simulate_match
	simulate_reset_btn.visible = can_only_simulate_match
	
	threads.resize(PlayerData.MAX_PLAYERS_PER_MATCH)
	script_editors.resize(PlayerData.MAX_PLAYERS_PER_MATCH)
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
	if not is_running:
		return
		
	set_time_left(match_timer.get_time_left())
	
	if not is_step_by_step:
		script_step()
	if are_controllers_finished() :
		self.is_running = false
		join_controllers()
		CurrentVisualization.get_current().stop()
		emit_signal("match_scripts_ended")
		

# If it's is_running, busy waits for every thread to arrive
func script_step():
	if not is_running : 
		return
	# Clears the events to register
	tick += 1
	_ducks_tired.add_frame()
	while not ThreadSincronizer.everyone_arrived() :
		continue
	if is_emitting_state:
		emit_signal("pond_state_updated", self.pond_state)
	
	clear_events()
	ThreadSincronizer.give_permission() 


# Prepare the threads, ThreadSincronizer, and PondVisualization for a new match
# No matter how many times its called, the reset occurs once in the next idle frame
func reset_pond_match() -> void:
	$ResetManager.reset_requested()
	
func _reset() -> void:
	match_timer.stop()
	set_time_left(-1)
	
	winner = WINNER_TEMPLATE
	_ducks_tired.reset()
	tick = 0
	clear_events()

	force_join_controllers()

	var player_count : int = PlayerData.count()	

	var curr_vis := CurrentVisualization.get_current()
	curr_vis.reset()
	yield(curr_vis, "reset_finished")


	for i in player_count:
		var bar : EnergyBar = find_node("EnergyBar%d"%i)
		bar.reset()
		
		if not PlayerData.is_present(i):
			continue
		
		#Connects a Duck's energy_changed signal to it's corresponding energy bar
		# [TODO] Make the duck's signals and connections not a problem for PondMatch (maybe delegate to a "set_energy_visualization" method) 
		#warning-ignore: return_value_discarded
		var duck : Duck = PlayerData.get_duck_node(i)
		if not duck.is_connected("energy_changed", bar, "set_energy"):
			duck.connect("energy_changed", bar, "set_energy")
		#warning-ignore: return_value_discarded
		if not duck.is_connected("tired", self, "_on_Duck_tired"):
			duck.connect("tired", self, "_on_Duck_tired")
			

	# The script execution threads use the instance_id of the LuaController node
	ThreadSincronizer.prepare_participants(controller_ids)

	# Initializes pond_state
	pond_state = State.new(self.tick, self.pond_events, self.duck_pond_states, self.projectile_pond_states)

	self.is_running = false

	enable_simulate(true)

	emit_signal("reset_finished")


# If a victor is found, stores it's username in member winner
func check_victory():
	if PlayerData.present_count() == 1:
		return false
	
	var non_tired := 0
	var non_tired_idx := -1
	
	for idx in PlayerData.count():
		if not PlayerData.is_present(idx):
			continue
		
		if non_tired > 1:
			break
		
		var duck = PlayerData.get_duck_node(idx)
		if duck and not duck.is_tired():
			non_tired += 1
			non_tired_idx = idx
	
	match non_tired:
		0:
			var last_tired_ducks = _ducks_tired.last_tired()
			var winners = []
			var msg = "%s" + " e %s".repeat(last_tired_ducks.size()-1) + " VENCERAM!"
			for duck in last_tired_ducks:
				var idx = PlayerData.duck_node_to_index(duck)
				winners.push_back(PlayerData.get_player(idx).username)
			winner = msg%winners
			return true
		1:
			winner = "%s VENCEU!"%PlayerData.get_player(non_tired_idx).username
			return true
		_:
			winner = WINNER_TEMPLATE
			return false

# Forces a victor to be chosen
# Returns false if there is only one duck in the match

# If a victor is found, stores it's username in member winner
func force_victory():
	if PlayerData.present_count() == 1:
		return false
	
	var less_tired = []
	var highest_energy := -1
	
	for idx in PlayerData.count():
		if not PlayerData.is_present(idx):
			continue
		
		var duck = PlayerData.get_duck_node(idx)
		if not duck or duck.is_tired():
			continue
			
		if duck.energy < highest_energy:
			continue
		elif duck.energy == highest_energy:
			less_tired.push_back(idx)
		else: # duck.energy > highest_energy
			less_tired = [idx]
			highest_energy = duck.energy
			
	
	match less_tired.size():
		0:
			var last_tired_ducks = _ducks_tired.last_tired()
			var winners = []
			var msg = "%s" + " e %s".repeat(last_tired_ducks.size()-1) + " VENCERAM!"
			for duck in last_tired_ducks:
				var idx = PlayerData.duck_node_to_index(duck)
				winners.push_back(PlayerData.get_player(idx).username)
			winner = msg%winners
		1:
			winner = "%s VENCEU!"%PlayerData.get_player(less_tired[0]).username
		_:
			
			var winners = []
			var msg = "%s" + " e %s".repeat(less_tired.size()-1) + " VENCERAM!"
			for idx in less_tired:
				winners.push_back(PlayerData.get_player(idx).username)
			winner = msg%winners
		
	return true


# Parses compilation error message then formats it to readable portuguese
func format_error(p_message : String) -> String:
	var message : String
	var known_index : int = p_message.find(": syntax error near ")
	
	if known_index == -1:
		known_index = p_message.find(" expected near ")
		var start_index : int = p_message.rfind(":", known_index)
		start_index = p_message.rfind(":", start_index-1)
		message = "na linha " + p_message.substr(start_index+1).replace(" expected near ", " esperado perto de ")
	else: 
		var start_index : int = p_message.rfind(":", known_index-1)
		message = "na linha " + p_message.substr(start_index+1).replace(": syntax error near ", ": perto de ")

	return message

# If can_only_simulate_match, returns `nothing_script`, unless p_index is the User's index
func get_duck_script(p_index : int) -> String:
	if not can_only_simulate_match or p_index == PlayerData.get_user_index():
		return PlayerData.get_pond_script(p_index)
	return nothing_script.lua_script

# Compiles the script for the player represented by the given index
# Returns true if successfully compiled; false if not
func compile_script(p_index : int, show_result : bool = false) -> bool:
	controllers[p_index].set_lua_code(get_duck_script(p_index))
	var error_message = ""
	if controllers[p_index].compile() == OK:
		if show_result:
			lua_script_status.set_ok()
		return true 
		
	error_message = controllers[p_index].get_error_message()

	if not show_result:
		return false

	var message : String 
	if error_message.empty() :
		message = "Compilação falhou sem descrição do erro"
	else:
		message = format_error(error_message)
	lua_script_status.set_compilation_error(message)

	return false

func compile_scripts() -> bool:
	var successfully_compiled : bool = true
	var user_index : int = PlayerData.get_user_index()
	var player_count : int = PlayerData.count()
	for i in player_count:
		# Skips absent Players
		if not PlayerData.is_present(i):
			continue
		successfully_compiled = compile_script(i, user_index == i) and successfully_compiled
		
	return successfully_compiled
	

func controller_run_wrapper(p_arguments : Dictionary) -> int :
	var index : int = p_arguments.index
	var show_result : bool = p_arguments.show_result
	
	var return_code = controllers[index].run()
	ThreadSincronizer.remove_participant(controllers[index].get_instance_id())
	
	if return_code != OK and show_result:
		lua_script_status.set_runtime_error(format_error(controllers[index].get_error_message()))

	return return_code

# Returns true if thread launched
func launch_thread(p_index : int, p_show_result : bool = false) -> bool:

	var arguments : Dictionary = {index=p_index, show_result=p_show_result}

	if threads[p_index].start(self, "controller_run_wrapper", arguments) == OK:
		return true

	push_error("thread for controller %d can't be created" % p_index)
	return false

# Returns true if every thread lauched
func launch_threads() -> bool :
	var successfully_launched : bool = true
	var user_index : int = PlayerData.get_user_index()
	var player_count : int = PlayerData.count()
	
	for i in player_count:
		# Skips absent Players
		if not PlayerData.is_present(i):
			continue
		successfully_launched = launch_thread(i, user_index == i) and successfully_launched
	
	return successfully_launched

func run():
	if not compile_scripts():
		reset_pond_match()
		self.is_running = false
		return
		
	if not launch_threads():
		reset_pond_match()
		self.is_running = false
	else:
		self.is_running = true
		match_timer.start(match_duration)

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
	self.is_running = false

func are_controllers_finished() -> bool :
	for thread in threads : 
		if thread and thread.is_alive():
			return false
	return true

# ==============================================
# == Mock controller functionality =============
func compile_mock_script(p_index : int) -> bool:
	if mock_controller:
		remove_child(mock_controller)
		mock_controller.queue_free()
	mock_controller = mock_controller_scene.instance()
	mock_controller.set_name("MockController")
	add_child(mock_controller)
	
	mock_controller.set_lua_code(PlayerData.get_pond_script(p_index))
	var error_message = ""
	if mock_controller.compile() == OK:
		lua_script_status.set_ok()
		return true 
		
	error_message = mock_controller.get_error_message()

	var message : String 
	if error_message.empty() :
		message = "Compilação falhou sem descrição do erro"
	else:
		message = format_error(error_message)

	lua_script_status.set_compilation_error(message)

	return false
		
func mock_controller_run_wrapper() -> int :
	
	var return_code = mock_controller.run()
	
	if return_code != OK and return_code != ERR_TIMEOUT:
		lua_script_status.set_runtime_error(format_error(mock_controller.get_error_message()))

	return return_code

# Returns true if thread launched
func launch_mock_thread() -> bool:
	force_join_mock_controller()

	mock_thread = Thread.new()
	if mock_thread.start(self, "mock_controller_run_wrapper") == OK:
		return true

	push_error("thread for mock_controller %d can't be created")
	return false

func force_join_mock_controller():
	if mock_controller:
		mock_controller.set_force_stop(true)
		
	if mock_thread :
		# warning-ignore:return_value_discarded
		mock_thread.wait_to_finish()

# == END Mock controller functionality =============
# ==================================================

func enable_player(p_index : int):
	var is_user := p_index == PlayerData.get_user_index()
	var can_edit := can_edit_scripts or is_user
	add_pond_script_editor(p_index)
	var can_see := can_see_scripts or is_user
	set_pond_script_editor_visible(p_index, can_see, can_edit)

	threads[p_index] = Thread.new()

	if controllers[p_index]:
		push_error("In PondMatch.enable_player:\n\tOverwriting a controller without removing it first. controller_ids will hold invalid ids and there will be more controllers than expected in the tree. Somehow a enable was called after a enable. If this is expected, I need to protect controllers and controller_ids.")

	var new_controller = controller_scene.instance()
	controllers[p_index] = new_controller 
	new_controller.name = "DuckController%d"%p_index
	new_controller.duck_idx = p_index
	add_child(new_controller)
	
	controller_ids.push_back(new_controller.get_instance_id())

	reset_pond_match()

# Remover controllers e script_editors dos players que não participarão
func disable_player(p_index : int):
	disable_pond_script_editor(p_index)
	
	threads[p_index] = null

	if not controllers[p_index]:
		return

	var node = get_node(controllers[p_index].name)
	controllers[p_index] = null
	remove_child(node)

	controller_ids.erase(node.get_instance_id())

	node.queue_free()
	
	reset_pond_match()

# Assures the order of tabs in scripts_tab_container corresponds to player order
func reorder_pond_script_editors() -> void:
	var curr := 0
	for edit in script_editors:
		if edit == null:
			continue
		scripts_tab_container.move_child(edit, curr)
		curr += 1

# Updates name and text of the corresponding TextEdit
func update_pond_script_editor(p_index : int, p_can_edit : bool) -> void:
	var edit : TextEdit = script_editors[p_index]
	edit.set_readonly(true)
	var uname = PlayerData.players[p_index].username
	var split = uname.find("@")
	edit.name = uname.left(split) if split >= 0 else uname
	edit.text = PlayerData.get_pond_script(p_index)
	edit.set_readonly(not p_can_edit)

# Creates (if necessary), shows and updates a script editor tab
func add_pond_script_editor(p_index : int) -> void:
	if script_editors[p_index]:
		return
	var new_editor := script_scene.instance()
	script_editors[p_index] = new_editor
	scripts_tab_container.add_child(new_editor)
	
	new_editor.connect("lua_script_changed", self, "_on_LuaScriptEditor_lua_script_changed")
	
	reorder_pond_script_editors()
		
func set_pond_script_editor_visible(p_index : int, p_can_see : bool, p_can_edit : bool) -> void:
	scripts_tab_container.set_tab_hidden(p_index, !p_can_see)
	update_pond_script_editor(p_index, p_can_edit)
	
# Enables/disables Send script button, with custom text
func enable_send_script(p_enabled : bool) -> void:
	if p_enabled:
		send_pond_script_btn.set_disabled( false )
		send_pond_script_btn.set_text( "Enviar código" )
	else:
		send_pond_script_btn.set_disabled( true )
		send_pond_script_btn.set_text( "Corrija código" )

# Enables/disables run/reset button
func enable_run_match(p_enabled : bool) -> void:
	run_reset_btn.set_disabled( not p_enabled )
	simulate_reset_btn.set_disabled( not p_enabled )
	

# Hides a script editor tab
func disable_pond_script_editor(p_index : int) -> void:
	scripts_tab_container.set_tab_hidden(p_index, true)

func save_pond_script(p_index : int) -> void:
	var edit = script_editors[p_index]
	if edit is TextEdit and "text" in edit:
		PlayerData.set_pond_script(p_index, edit.text, true)
# Saves pond scripts from `script_editors` in `PlayerData`
func save_pond_scripts() -> void:
	for i in script_editors.size():
		save_pond_script(i)
		
func show_quit_popup() -> void:
	$QuitMatchPopup.popup_centered_minsize()

func set_back_disabled(p_disable : bool) -> void:
	back_disabled = p_disable
	quit_btn.disabled = p_disable
	
func set_is_running(p_value : bool) -> void:
	if is_running == p_value:
		return
		
	is_running = p_value
	
	if is_running:
		emit_signal("match_run_started")
	else:
		emit_signal("match_run_stopped")

# Handles sensitivity of simulate_reset_btn
func enable_simulate(p_enabled : bool) -> void:
	if can_only_simulate_match:
		simulate_reset_btn.set_disabled(not p_enabled)

func _exit_tree():
	force_join_controllers()
	if PlayerData.is_connected("player_joined", self, "_on_PlayerData_player_joined"):
		PlayerData.disconnect("player_joined", self, "_on_PlayerData_player_joined")
	if PlayerData.is_connected("player_left", self, "_on_PlayerData_player_left"):
		PlayerData.disconnect("player_left", self, "_on_PlayerData_player_left")
	if PlayerData.is_connected("pond_script_changed", self, "_on_PlayerData_pond_script_changed"):
		PlayerData.disconnect("pond_script_changed", self, "_on_PlayerData_pond_script_changed")

func set_pond_events(p_events_state : Dictionary):
	var mutex = CurrentVisualization.get_current().mutex
	mutex.lock()
	
	var current := CurrentVisualization.get_current()
	# Pushes sfx
	current.play_sfx(p_events_state["sfx"])
	
	# Pushes vfx
	current.play_vfx(p_events_state["vfx"])
	
	mutex.unlock()

func get_pond_events() -> Dictionary :
	var mutex = CurrentVisualization.get_current().mutex
	mutex.lock()
	var ret = pond_events
	ret.vfx.vision_cone = CurrentVisualization.get_current().vision_cones_pond_states
	mutex.unlock()
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
		var has_ith_player : bool = i < p_states.size() and PlayerData.is_present(i)
		if has_ith_player:
			ducks[i].pond_state = p_states[i]
		ducks[i].set_participating(has_ith_player)

func get_projectile_pond_states() -> Array:
	return CurrentVisualization.get_current().projectile_pond_states
func set_projectile_pond_states(p_states : Array) :
	CurrentVisualization.get_current().projectile_pond_states = p_states

func get_time_left() -> float:
	return time_left
func set_time_left(p_time_left : float) :
	time_left = p_time_left
	
	if time_left < 0 :
		timer_label.set_text(TIMER_DEFAULT)
		return

	# warning-ignore:narrowing_conversion
	var minutes : int = time_left / 60
	var seconds : int = time_left as int % 60 
	# warning-ignore:narrowing_conversion
	var hundredths : int  = floor((time_left-floor(time_left))*100)
	timer_label.set_text(TIMER_TEMPLATE%[minutes, seconds, hundredths])
	
func get_pond_state() -> State:
	pond_state.tick = self.tick
	pond_state.pond_events = self.pond_events
	pond_state.duck_pond_states = self.duck_pond_states
	pond_state.projectile_pond_states = self.projectile_pond_states
	pond_state.time_left = self.time_left
	return pond_state

func set_pond_state(p_state : State) -> void:
	self.tick = p_state.tick
	self.pond_events = p_state.pond_events
	self.duck_pond_states = p_state.duck_pond_states
	self.projectile_pond_states = p_state.projectile_pond_states
	self.time_left = p_state.time_left
	pond_state = p_state
	enable_simulate(false)
	
# ====================================
# === LISTENERS ======================

func _on_MatchTimer_timeout():
	if is_running and force_victory():
		emit_signal("match_ended")	

func _on_Duck_tired(p_duck : Duck):
	_ducks_tired.add_duck(p_duck)
	if is_running and check_victory():
		emit_signal("match_ended")	

func _on_PondVisualization_sfx_played(p_effect_name : String):
	var mutex = CurrentVisualization.get_current().mutex
	mutex.lock()
	pond_events["sfx"][p_effect_name] = true
	mutex.unlock()

func _on_PondVisualization_vfx_played(p_effect_name: String, p_pond_state):
	var mutex = CurrentVisualization.get_current().mutex
	mutex.lock()
	pond_events["vfx"][p_effect_name].push_back(p_pond_state)
	mutex.unlock()

func _on_PlayerData_player_joined(p_index : int):
	if not is_running:
		enable_player(p_index)

func _on_PlayerData_player_left(p_index : int):
	if not is_running:
		disable_player(p_index)

func _on_PlayerData_pond_script_changed(p_index : int, p_pond_script : String):
	if script_editors[p_index] is TextEdit :
		script_editors[p_index].text = p_pond_script

func _on_PondMatch_match_run_started():
	run_reset_btn.swap_role("reset")
	simulate_reset_btn.swap_role("reset")
	
	set_back_disabled(true)
	step_btn.visible = is_step_by_step
	lua_script_status.set_disabled(true)


func _on_PondMatch_match_run_stopped():
	run_reset_btn.swap_role("run")
	simulate_reset_btn.swap_role("run")
	
	set_back_disabled(false)
	step_btn.hide()
	lua_script_status.set_disabled(false)

func _on_StepButton_pressed():
	emit_signal("match_step_requested")


func _on_RunResetButton_reset():
	emit_signal("match_reset_requested")

func _on_RunResetButton_run():
	emit_signal("match_run_requested")


func _on_SimulateResetButton_run():
	emit_signal("match_run_requested")

func _on_SimulateResetButton_reset():
	emit_signal("match_reset_requested")


func _on_SendScriptButton_pressed():
	emit_signal("send_pond_script_requested")

func _on_QuitMatchPopup_confirmed(p_affirmative):
	if p_affirmative:
		emit_signal("match_quit_requested")
	
func _on_QuitButton_pressed():
	show_quit_popup()

func _on_LuaScriptStatus_verify_requested():
	var user_index = PlayerData.get_user_index()
	save_pond_script(user_index)
	if compile_mock_script(user_index) and launch_mock_thread():
		enable_send_script(true)
		enable_run_match(true)
	else:
		enable_send_script(false)
		enable_run_match(false)

func _on_LuaScriptEditor_lua_script_changed(p_node : TextEdit) -> void:
	var index := script_editors.find(p_node)
	if index != PlayerData.get_user_index():
		return
	lua_script_status.set_standby()
	enable_send_script(false)
	enable_run_match(false)
	

# === END LISTENERS ==================
# ====================================

#JSONable class for PondMath
class State extends JSONable:
	var tick : int
	var pond_events : Dictionary
	var duck_pond_states : Array
	var projectile_pond_states : Array
	var time_left : float 
	
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
		p_projectile_pond_states := [],
		p_time_left := 0.0):
		tick = p_tick
		pond_events = p_pond_events
		duck_pond_states = p_duck_pond_states
		projectile_pond_states = p_projectile_pond_states
		time_left = p_time_left

	func to(pond_match : PondMatch = null) -> Dictionary:
		if pond_match:
			tick = pond_match.tick
			pond_events = pond_match.pond_events
			duck_pond_states = pond_match.duck_pond_states
			projectile_pond_states = pond_match.projectile_pond_states
			time_left = pond_match.time_left

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
			"projectile_pond_states" : projectile_states,
			"time_left" : time_left
		}
		
	func from(p_from : Dictionary) -> JSONable:
		tick = p_from.tick
		pond_events = {}
		duck_pond_states = []
		projectile_pond_states = []
		time_left = p_from.time_left

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
