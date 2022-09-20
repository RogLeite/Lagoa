extends Node

var is_pond_match_running := false
var _all_scripts := {}
var _tick := 0

onready var _client := $MasterClient
onready var _scripts := $CenterContainer/HBoxContainer/Scripts

onready var _ball := $Ball
onready var _pond_state := {ball_position = _ball.position}

func login(email : String, password : String) -> void:
	$Login.visible = false
	# [TODO] Clean login test code
	var result: int = yield(_client.register_connect_join_async(email, password), "completed")
	if result != OK:
		# [TODO] Change to a proper alert
		var label = Label.new()
		add_child(label)
		label.set_text("register_connect_join failed")
	else:
		$CenterContainer/HBoxContainer/VBoxContainer/Description.text = email
		$CenterContainer.visible = true
		_ball.visible = true

func start_pond_match() -> void:
	is_pond_match_running = true
	start_ball()

# [TODO] Remove this method. Was used for testing
func start_ball():
	$Ball/AnimationPlayer.play("wobble")
	
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
		_scripts.visible = true
	
	yield(get_tree(),"idle_frame")
	
	_scripts.add_child(new_page)
		

func _on_StartMatchButton_pressed():
	start_pond_match()


func _on_MasterClient_script_received(username, script):
	add_script_tab(username, script)

func _on_MasterClient_connection_closed() -> void:
	is_pond_match_running = false
	# [TODO] Possibly handle reconnection attempt

# [TODO] Remove Login test
func _on_Master1_pressed():
	login("MasterClient1@test.com", "password")
func _on_Master2_pressed():
	login("MasterClient2@test.com", "password")
