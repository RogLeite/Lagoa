extends Node

var _last_tick := -1
var _email := ""

onready var _spinner := $CanvasLayer/Spinner
onready var _spinner_animator := $CanvasLayer/Spinner/AnimationPlayer
onready var _client := $PlayerClient
onready var _ball := $Ball
onready var _text_box := $CenterContainer/VBoxContainer/TextEdit
onready var _total_scripts:= $CenterContainer/VBoxContainer/TotalScripts
onready var _login_and_register := $LoginAndRegister


func _ready():
	_spinner.set_position(get_viewport().size / 2)


func prepare(email : String, password : String, do_remember_email : bool, is_register : bool) -> void:
	_login_and_register.set_is_enabled(false)
	_spinner.show()
	_spinner_animator.play("spin")
	
	var result : int 
	if is_register:
		result = yield(_client.register_async(email, password, do_remember_email), "completed")
	else:
		result = yield(_client.login_async(email, password, do_remember_email), "completed")
	
	if result != OK:
		_login_and_register.set_is_enabled(true)
		_login_and_register.set_status("Error code %s: %s"%[result, _client.error_message])
		
		_spinner_animator.stop(true)
		_spinner.hide()
		
		return

	result = yield(_client.connect_async(), "completed")
	if result != OK:
		_login_and_register.set_is_enabled(true)
		_login_and_register.set_status("Error code %s: %s"%[result, _client.error_message])
		
		_spinner_animator.stop(true)
		_spinner.hide()
		
		return

	# [TODO] Choose a Match to enter
	
	result = yield(_client.join_async(), "completed")
	if result != OK:
		_login_and_register.set_is_enabled(true)
		_login_and_register.set_status("Error code %s: %s"%[result, _client.error_message])
		
		_spinner_animator.stop(true)
		_spinner.hide()
		
		return
	
	_email = email.left(email.find("@"))
	
	_login_and_register.hide()
	_login_and_register.reset()
		
	_spinner_animator.stop(true)
	_spinner.hide()
	
	
	# Call to next state "elapse"
	call_deferred("elapse")

func elapse() -> void:
	$CenterContainer.show()
	$CenterContainer/VBoxContainer/Label.text = _email
	_ball.show()
	
func start(pond_match_tick : int, pond_state : PondMatch.State, scripts : Dictionary) -> void:
	if pond_match_tick > _last_tick:
		_ball.position = pond_state.ball_position
		_total_scripts.text = "Total Scripts: %d"%scripts.size()
	
func result() -> void:
	_last_tick = -1
	_total_scripts.text = "Connection closed"
	# [TODO] Possibly handle reconnection attempt

func _on_SendTextButton_pressed():
	_client.send_script(_text_box.text)

func _on_LoginAndRegister_login_pressed(email, password, do_remember_email):
	call_deferred("prepare",email, password, do_remember_email, false)

func _on_LoginAndRegister_register_pressed(email, password, do_remember_email):
	call_deferred("prepare",email, password, do_remember_email, true)

func _on_PlayerClient_pond_state_updated(pond_match_tick, pond_state, scripts):
	call_deferred("start", pond_match_tick, pond_state, scripts)

func _on_PlayerClient_connection_closed() -> void:
	call_deferred("result")
