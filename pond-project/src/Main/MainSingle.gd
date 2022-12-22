extends Node

var _player_joins : Array
var _main_state := "initial"

onready var pond_match := $PondMatch

func _init():
	
	var script1 : Resource = preload("res://resources/LuaScripts/launch_cross.tres")
	var script2 : Resource = preload("res://resources/LuaScripts/swim_up_launch_right.tres")
	_player_joins = [
		Presence.new("Player1","Player1", script1.lua_script),
		Presence.new("Player2","Player2", script1.lua_script),
		Presence.new("Player3","Player3", script2.lua_script),
		Presence.new("Player4","Player4", script2.lua_script)
	]

func _ready():
	call_deferred("reset")

func reset():
	_main_state = "reset"
	pond_match.reset_pond_match()
	
	for join in _player_joins:
		if PlayerData.is_registered_player(join.user_id):
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
