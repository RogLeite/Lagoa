extends Node

var _last_tick = -1

onready var _client := $PlayerClient
onready var _ball := $Ball
onready var _text_box := $CenterContainer/VBoxContainer/TextEdit
onready var _total_scripts:= $CenterContainer/VBoxContainer/TotalScripts

func login(email : String, password : String) -> void:
	# [TODO] Clean login test code
	$Login.visible = false
	var result: int = yield(_client.register_connect_join_async(email, password), "completed")
	if result != OK:
		# [TODO] Change to a proper alert
		var label = Label.new()
		add_child(label)
		label.set_text("register_connect_join failed")
	else:
		$CenterContainer.visible = true
		$CenterContainer/VBoxContainer/Label.text = email
		_ball.visible = true

func _on_SendTextButton_pressed():
	_client.send_script(_text_box.text)


func _on_PlayerClient_connection_closed() -> void:
	_total_scripts.text = "Connection closed"
	# [TODO] Possibly handle reconnection attempt

func _on_PlayerClient_pond_state_updated(pond_match_tick, pond_state, scripts):
	if pond_match_tick > _last_tick:
		_ball.position = pond_state.ball_position
		_total_scripts.text = "Total Scripts: %d"%scripts.size()
		

# [TODO] Remove Login test
func _on_Client1_pressed():
	login("PlayerClient1@test.com", "password")
func _on_Client2_pressed():
	login("PlayerClient2@test.com", "password")
