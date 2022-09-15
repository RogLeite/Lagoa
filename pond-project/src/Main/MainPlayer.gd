extends Node

var _last_tick = -1

onready var _client := $PlayerClient
onready var _ball := $Ball
onready var _text_box := $CenterContainer/VBoxContainer/TextEdit
onready var _total_scripts:= $CenterContainer/VBoxContainer/TotalScripts

func _on_SendTextButton_pressed():
	_client.send_script(_text_box.text)


func _on_PlayerClient_pond_state_updated(pond_match_tick, pond_state, scripts):
	if pond_match_tick > _last_tick:
		_ball.position = Vector2(pond_state.ball_position.x, pond_state.ball_position.y)
		_total_scripts.text = "Total Scripts: %d"%scripts.size()
		
