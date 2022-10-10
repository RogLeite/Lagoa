extends Node

var _email := ""

onready var _spinner := $CanvasLayer/Spinner
onready var _spinner_animator := $CanvasLayer/Spinner/AnimationPlayer
onready var _client := $PlayerClient
onready var login_and_register := $LoginAndRegister
onready var pond_match := $PondMatch

func _ready():
	_spinner.set_position(get_viewport().size / 2)

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
	
func start(pond_state : PondMatch.State, scripts : Dictionary) -> void:
	if pond_state.tick > pond_match.tick:
		pond_match.pond_state = pond_state
		
	
func result() -> void:
	# [TODO] Have some flag in "start" indicatig if the match has started and 
	# reset that flag here, so a delayed "pond_state_updated" message does not
	# update de state even though reset_pond_match has just been called (or 
	# pond_state has a "pond_match_id" indicating which match is running and 
	# MainPlayer knows which is it because it was communicated in the
	# "end_pond_match" message
	pond_match.reset_pond_match()
	# [TODO] Possibly handle reconnection attempt

func _on_LoginAndRegister_login_pressed(email, password, do_remember_email):
	call_deferred("prepare",email, password, do_remember_email, false)

func _on_LoginAndRegister_register_pressed(email, password, do_remember_email):
	call_deferred("prepare",email, password, do_remember_email, true)

func _on_PlayerClient_pond_state_updated(pond_state, scripts):
	call_deferred("start", pond_state, scripts)

func _on_PlayerClient_connection_closed() -> void:
	call_deferred("reset")

func _on_PlayerClient_pond_match_ended():
	call_deferred("result")
