extends Node

var is_pond_match_running := false
var _email := "[no email]"

onready var _scripts := {}
onready var _spinner := $CanvasLayer/Spinner
onready var _spinner_animator := $CanvasLayer/Spinner/AnimationPlayer
onready var _client := $MasterClient
onready var login_and_register := $LoginAndRegister
onready var pond_match := $PondMatch

func _ready():
	_spinner.set_position(get_viewport().size / 2)
	# [TODO] Change use of PondState, should get directly from PondMatch.pond_state
	call_deferred("reset")

func reset():
	login_and_register.reset()
	login_and_register.show()
	pond_match.hide()
	
func prepare(email : String, password : String, do_remember_email : bool, is_register : bool) -> void:
	login_and_register.set_is_enabled(false)
	_spinner.show()
	_spinner_animator.play("spin")
	
	var result : int 
	if is_register:
		result = yield(_client.register_async(email, password, do_remember_email), "completed")
	else:
		result = yield(_client.login_async(email, password, do_remember_email), "completed")
	
	if result != OK:
		login_and_register.set_is_enabled(true)
		login_and_register.set_status("Error code %s: %s"%[result, _client.error_message])
		
		_spinner_animator.stop(true)
		_spinner.hide()
		
		return

	result = yield(_client.connect_async(), "completed")
	if result != OK:
		login_and_register.set_is_enabled(true)
		login_and_register.set_status("Error code %s: %s"%[result, _client.error_message])
		
		_spinner_animator.stop(true)
		_spinner.hide()
		
		return

	# [TODO] Choose a Match to enter
	
	result = yield(_client.join_async(), "completed")
	
	if result != OK:
		login_and_register.set_is_enabled(true)
		login_and_register.set_status("Error code %s: %s"%[result, _client.error_message])
		
		_spinner_animator.stop(true)
		_spinner.hide()
		
		return
	
	_email = email.left(email.find("@"))
	
	login_and_register.hide()
	login_and_register.reset()
		
	_spinner_animator.stop(true)
	_spinner.hide()
	
	# Call to next state "elapse"
	call_deferred("elapse")
	
func elapse() -> void:
	pond_match.show()

func start() -> void:
	pond_match.run()

func result(p_result : String) -> void:
	match p_result :
		"reset_requested":
			pond_match.reset_pond_match()
			_client.end_pond_match()
			call_deferred("elapse")
		"scripts_ended":
			pond_match.reset_pond_match()
			_client.end_pond_match()
			call_deferred("elapse")
		
		
	

func _on_MasterClient_script_received(username, script):
	_scripts[username] = script
	pond_match.add_script(username, script)

func _on_LoginAndRegister_login_pressed(email, password, do_remember_email):
	call_deferred("prepare", email, password, do_remember_email, false)

func _on_LoginAndRegister_register_pressed(email, password, do_remember_email):
	call_deferred("prepare", email, password, do_remember_email, true)

func _on_PondMatch_match_reset_requested():
	call_deferred("result", "reset_requested")
	

func _on_PondMatch_match_scripts_ended():
	call_deferred("result", "scripts_ended")


func _on_PondMatch_match_run_requested():
	call_deferred("start")
	
func _on_MasterClient_connection_closed() -> void:
	call_deferred("reset")
	# [TODO] Possibly handle reconnection attempt


func _on_PondMatch_pond_state_updated():
	_client.update_pond_state(pond_match.pond_state, _scripts)


func _on_PondMatch_match_step_requested():
	pond_match.script_step()
