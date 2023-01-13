extends Node

var is_pond_match_running := false
var _email := "[no email]"
var _main_state := "initial"

onready var _spinner := $CanvasLayer/Spinner
onready var _spinner_animator := $CanvasLayer/Spinner/AnimationPlayer
onready var _client := $MasterClient
onready var login_and_register := $LoginAndRegister
onready var pond_match := $PondMatch

func _ready():
	_spinner.set_position(get_viewport().size / 2)
	PlayerCache.responsible = self
	call_deferred("reset")

func reset(p_status : String = ""):
	_main_state = "reset"
	login_and_register.set_is_enabled(true)
	login_and_register.reset()

	if ProjectSettings.get_setting("editor/manual_testing"):
		# Default values to help debugging
		login_and_register.login_form.email_field.text = "M1@test.com"
		login_and_register.login_form.password_field.text = "asdfçlkj"
		login_and_register.login_form.remember_email.pressed = false
	
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
	PlayerCache.release()

func start() -> void:
	if PlayerData.present_count() == 0:
		return
	_main_state = "start"
	pond_match.save_pond_scripts()
	pond_match.run()

func result(p_result : String) -> void:
	_main_state = "result"
	match p_result :
		"reset_requested":
			pond_match.reset_pond_match()
			_client.end_pond_match()
			call_deferred("elapse")
		"scripts_ended":
			pond_match.reset_pond_match()
			_client.end_pond_match()
			call_deferred("elapse")
	

func join(p_join : Presence):
	if PlayerData.is_registered_player(p_join.user_id):
		PlayerData.join_player(p_join)
	else:
		PlayerData.add_player(p_join)

func leave(p_leave : Presence):
	if PlayerData.is_registered_player(p_leave.user_id):
		PlayerData.leave_player(p_leave)

func _on_MasterClient_pond_script_received(p_user_id, p_pond_script):
	var index := PlayerData.get_index_by_user_id(p_user_id)
	PlayerData.set_pond_script(index, p_pond_script)

func _on_MasterClient_joins_received(p_joins):
	# print("_on_MasterClient_joins_received:%s"%String(p_joins))
	for player in p_joins:
		if _main_state == "elapse":
			join(player)
		else:
			PlayerCache.add_join(player)


func _on_MasterClient_leaves_received(p_leaves):
	# print("_on_MasterClient_leaves_received: %s"%String(p_leaves))
	for player in p_leaves:
		if _main_state == "elapse":
			leave(player)
		else:
			PlayerCache.add_leave(player)

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


func _on_PondMatch_pond_state_updated(p_pond_state):
	_client.update_pond_state(p_pond_state)


func _on_PondMatch_match_step_requested():
	pond_match.pond_script_step()
