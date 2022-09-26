extends Node

var is_pond_match_running := false
var _all_scripts := {}
var _tick := 0
var _email := "[no email]"

onready var _spinner := $CanvasLayer/Spinner
onready var _spinner_animator := $CanvasLayer/Spinner/AnimationPlayer
onready var _client := $MasterClient
onready var _scripts := $CenterContainer/HBoxContainer/Scripts
onready var _login_and_register := $LoginAndRegister

onready var _ball := $Ball
onready var _pond_state : PondMatch.State = PondMatch.State.new(_ball.position)

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
	$CenterContainer/HBoxContainer/VBoxContainer/Description.text = _email
	$CenterContainer.show()
	_ball.show()

func start() -> void:
	is_pond_match_running = true
	$Ball/AnimationPlayer.play("wobble")
	$CenterContainer/HBoxContainer/VBoxContainer/StartMatchButton.hide()
	$CenterContainer/HBoxContainer/VBoxContainer/StopMatchButton.show()

func result() -> void:
	$Ball/AnimationPlayer.stop(true)
	$CenterContainer/HBoxContainer/VBoxContainer/StopMatchButton.hide()
	$CenterContainer/HBoxContainer/VBoxContainer/StartMatchButton.show()
	is_pond_match_running = false
	_all_scripts.clear()
	for child in _scripts.get_children():
		_scripts.remove_child(child)
		child.queue_free()

	
func _physics_process(_delta):
	if is_pond_match_running :
		_tick += 1
		_pond_state.ball_position = _ball.position
		_client.update_pond_state(_tick, _pond_state, _all_scripts)

func add_script_tab(username : String, text : String) -> void :
	var new_page := Label.new()
	new_page.autowrap = true
	new_page.name = username.left(username.find("@"))
	new_page.text = text
	
	_all_scripts[username] = text
	
	if not _scripts.visible :
		_scripts.show()
	
	yield(get_tree(),"idle_frame")
	
	_scripts.add_child(new_page)
	

func _on_MasterClient_script_received(username, script):
	add_script_tab(username, script)

func _on_LoginAndRegister_login_pressed(email, password, do_remember_email):
	call_deferred("prepare", email, password, do_remember_email, false)

func _on_LoginAndRegister_register_pressed(email, password, do_remember_email):
	call_deferred("prepare", email, password, do_remember_email, true)

func _on_StartMatchButton_pressed():
	call_deferred("start")
	
func _on_StopMatchButton_pressed():
	call_deferred("result")
	
func _on_MasterClient_connection_closed() -> void:
	call_deferred("result")
	# [TODO] Possibly handle reconnection attempt
