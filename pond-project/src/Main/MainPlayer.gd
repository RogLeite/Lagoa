extends Node

const _main_menu := "res://src/Main/MainMenu.tscn"

var _email := ""
var _main_state := "initial"

onready var back_button := $BackButton
onready var _spinner := $CanvasLayer/Spinner
onready var _spinner_animator := $CanvasLayer/Spinner/AnimationPlayer
onready var _client := $PlayerClient
onready var login_and_register := $LoginAndRegister
onready var pond_match := $PondMatch
onready var victory_popup := $VictoryPopup

func _ready():
	_spinner.set_position(get_viewport().size / 2)
	PlayerCache.responsible = self
	call_deferred("reset")


func _notification(what):
	match _main_state:
		"elapse", "start", "result":
			if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
				pond_match.show_quit_popup()

func reset(p_status : String = ""):
	_main_state = "reset"
	get_tree().set_auto_accept_quit(true)
	pond_match.modulate = Color.white

	login_and_register.set_is_enabled(true)
	login_and_register.reset()

	if ProjectSettings.get_setting("editor/manual_testing"):
		# Default values to help debugging
		login_and_register.login_form.email_field.text = "P1@test.com"
		login_and_register.login_form.password_field.text = "asdfçlkj"
		login_and_register.login_form.remember_email.pressed = false

	login_and_register.show()
	if not p_status.empty():
		login_and_register.set_status(p_status)
		
	_spinner_animator.stop(true)
	_spinner.hide()

	_client.reset()

	back_button.show()

	$Water.show()
	pond_match.hide()
	pond_match.reset_pond_match()

func prepare(email : String, password : String, do_remember_email : bool, is_register : bool) -> void:
	_main_state = "prepare"
	get_tree().set_auto_accept_quit(true)
	pond_match.set_back_disabled(false)
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
	
	back_button.hide()
	
	# Call to next state "elapse"
	call_deferred("elapse")

func elapse() -> void:
	_main_state = "elapse"
	get_tree().set_auto_accept_quit(false)
	pond_match.modulate = Color.white
	
	$Water.hide()
	pond_match.show()
	
	# print("PlayerCache.print: %s"%PlayerCache)
	PlayerCache.release()
	
func start(pond_state : PondMatch.State) -> void:
	_main_state = "start"
	get_tree().set_auto_accept_quit(false)
	pond_match.modulate = Color.white

	pond_match.set_back_disabled(true)
	if pond_state.tick > pond_match.tick:
		pond_match.pond_state = pond_state
		
	
func result(p_message : String = "") -> void:
	_main_state = "result"
	get_tree().set_auto_accept_quit(false)
	pond_match.set_back_disabled(false)
	pond_match.reset_pond_match()
	pond_match.modulate = Color.white
	# [TODO] Possibly handle reconnection attempt

	if p_message.empty():
		return 
	
	show_victory(p_message)

	call_deferred("elapse")


# Quits to MainMenu
func quit() -> void:
	_main_state = "quit"
	get_tree().set_auto_accept_quit(true)
	pond_match.set_back_disabled(false)

	yield(_client.drop_reservation_async(), "completed")

	pond_match.reset_pond_match()
	yield(pond_match, "reset_finished")
	
	PlayerData.reset()
	# warning-ignore: return_value_discarded
	get_tree().change_scene_to(load("res://src/Main/MainMenu.tscn"))

func show_victory(p_message : String) -> void:
	get_tree().paused = true
	
	pond_match.modulate = Color.gray
	victory_popup.set_winner(p_message)
	victory_popup.popup_centered()
	
	get_tree().paused = false

func join(p_join : Presence) -> void:
	if PlayerData.is_registered_player(p_join.user_id):
		PlayerData.join_player(p_join)
	else:
		PlayerData.add_player(p_join)

func leave(p_leave : Presence) -> void:
	if PlayerData.is_registered_player(p_leave.user_id):
		PlayerData.leave_player(p_leave)

func drop_reservation(user_id : String):
	if PlayerData.is_registered_player(user_id):
		PlayerData.drop_reservation(user_id)

func _on_LoginAndRegister_login_pressed(email, password, do_remember_email) -> void:
	call_deferred("prepare",email, password, do_remember_email, false)

func _on_LoginAndRegister_register_pressed(email, password, do_remember_email) -> void:
	call_deferred("prepare",email, password, do_remember_email, true)

func _on_PlayerClient_pond_state_updated(pond_state) -> void:
	if _main_state == "elapse" or _main_state == "start":
		call_deferred("start", pond_state)

func _on_PlayerClient_connection_closed() -> void:
	call_deferred("reset", "Connection with server closed")
	
func _on_PlayerClient_master_left() -> void:
	call_deferred("reset", "MasterClient ended connection")

func _on_PlayerClient_pond_match_ended() -> void:
	call_deferred("result", false)


func _on_PlayerClient_reservation_dropped(user_id):
	if _main_state == "elapse":
		drop_reservation(user_id)
	else:
		PlayerCache.add_drop_reservation(user_id)



func _on_PlayerClient_joins_received(p_joins) -> void:
	# print("_on_PlayerClient_joins_received:%s"%String(p_joins))
	for player in p_joins:
		if _main_state == "elapse":
			join(player)
		else:
			PlayerCache.add_join(player)


func _on_PlayerClient_leaves_received(p_leaves) -> void:
	# print("_on_PlayerClient_leaves_received: %s"%String(p_leaves))
	for player in p_leaves:
		if _main_state == "elapse":
			leave(player)
		else:
			PlayerCache.add_leave(player)

func _on_PondMatch_send_pond_script_requested() -> void:
	pond_match.save_pond_scripts()
	_client.send_pond_script(PlayerData.get_user_pond_script())

func _on_BackButton_pressed() -> void:
	if _main_state == "reset":
		#warning-ignore: return_value_discarded
		get_tree().change_scene_to(load(_main_menu))


func _on_PondMatch_match_quit_requested() -> void:
	call_deferred("quit")


func _on_PlayerClient_victory_shown(p_message):
	call_deferred("result", p_message)


func _on_VictoryPopup_confirmed(_p_affirmative):
	pond_match.modulate = Color.white
