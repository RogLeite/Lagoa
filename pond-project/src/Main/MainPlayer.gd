extends Node

var _email := ""
var _main_state := "initial"

onready var _spinner := $CanvasLayer/Spinner
onready var _spinner_animator := $CanvasLayer/Spinner/AnimationPlayer
onready var _client := $PlayerClient
onready var login_and_register := $LoginAndRegister
onready var pond_match := $PondMatch

func _ready():
	_spinner.set_position(get_viewport().size / 2)

func reset(p_status : String = ""):
	_main_state = "reset"
	login_and_register.set_is_enabled(true)
	login_and_register.reset()
	login_and_register.show()
	if not p_status.empty():
		login_and_register.set_status(p_status)
		
	_spinner_animator.stop(true)
	_spinner.hide()

	_client.reset()

	pond_match.hide()
	pond_match.reset_pond_match()

func prepare(email : String, password : String, do_remember_email : bool, is_register : bool) -> void:
	_main_state = "prepare"
	login_and_register.set_is_enabled(false)
	_spinner.show()
	_spinner_animator.play("spin")
	
	var result : int 
	if is_register:
		result = yield(_client.register_async(email, password, do_remember_email), "completed")
	else:
		result = yield(_client.login_async(email, password, do_remember_email), "completed")
	
	if result != OK:
		call_deferred("reset","Error code %s: %s"%[result, _client.error_message])
		return

	result = yield(_client.connect_async(), "completed")
	if result != OK:
		call_deferred("reset","Error code %s: %s"%[result, _client.error_message])
		return

	# [TODO] Choose a Match to enter
	
	result = yield(_client.join_async(), "completed")
	if result != OK:
		call_deferred("reset","Error code %s: %s"%[result, _client.error_message])
		return
	
	_email = email.left(email.find("@"))
	
	login_and_register.hide()
	login_and_register.reset()
		
	_spinner_animator.stop(true)
	_spinner.hide()
	
	
	# Call to next state "elapse"
	call_deferred("elapse")

func elapse() -> void:
	_main_state = "elapse"
	pond_match.show()
	
func start(pond_state : PondMatch.State, scripts : Dictionary) -> void:
	_main_state = "start"
	if pond_state.tick > pond_match.tick:
		pond_match.pond_state = pond_state
		
	
func result() -> void:
	_main_state = "result"
	pond_match.reset_pond_match()
	# [TODO] Possibly handle reconnection attempt

func _on_LoginAndRegister_login_pressed(email, password, do_remember_email):
	call_deferred("prepare",email, password, do_remember_email, false)

func _on_LoginAndRegister_register_pressed(email, password, do_remember_email):
	call_deferred("prepare",email, password, do_remember_email, true)

func _on_PlayerClient_pond_state_updated(pond_state, pond_scripts):
	if _main_state == "elapse" or _main_state == "start":
		call_deferred("start", pond_state, pond_scripts)

func _on_PlayerClient_connection_closed() -> void:
	call_deferred("reset")

func _on_PlayerClient_pond_match_ended():
	call_deferred("result")

func _on_PlayerClient_joins_received(p_joins):
	if _main_state == "prepare" or _main_state == "elapse":
		# print("_on_PlayerClient_joins_received:%s"%String(p_joins))
		for join in p_joins:
			if PlayerData.is_registered_player(join.user_id):
				PlayerData.join_player(join)
			else:
				PlayerData.add_player(join)

func _on_PlayerClient_leaves_received(p_leaves):
	if _main_state == "prepare" or _main_state == "elapse":
		# print("_on_PlayerClient_leaves_received: %s"%String(p_leaves))
		for leave in p_leaves:
			if PlayerData.is_registered_player(leave.user_id):
				PlayerData.leave_player(leave)
