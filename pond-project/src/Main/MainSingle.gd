extends Node

var _main_state := "initial"
var _player_joins := [
	{"username" : "Player1", "user_id" : "Player1"},
	{"username" : "Player2", "user_id" : "Player2"},
	{"username" : "Player3", "user_id" : "Player3"},
	{"username" : "Player4", "user_id" : "Player4"}
]


onready var pond_match := $PondMatch

func _ready():
	call_deferred("reset")

func reset():
	_main_state = "reset"
	pond_match.reset_pond_match()
	
	for join in _player_joins:
		if PlayerData.is_returning_player(join.user_id):
			PlayerData.join_player(join)
		else:
			PlayerData.add_player(join)

	# For now, immediatelly skips to "elapse
	call_deferred("elapse")
	
func prepare() -> void:
	_main_state = "prepare"
	# [TODO] Add scripts in PondMatch for the AI
	pass
	
func elapse() -> void:
	_main_state = "elapse"
	pond_match.show()

func start() -> void:
	_main_state = "start"
	pond_match.run()

func result() -> void:
	_main_state = "result"
	pond_match.reset_pond_match()

func _on_PondMatch_match_reset_requested():
	call_deferred("result")

func _on_PondMatch_match_run_requested():
	call_deferred("start")

func _on_PondMatch_match_step_requested():
	pond_match.pond_script_step()
