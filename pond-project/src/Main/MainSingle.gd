extends Node

var _player_joins : Array
var _main_state := "initial"

onready var pond_match := $PondMatch
onready var victory_popup := $VictoryPopup

func _init():
	# FINAL
	var script1 : LuaScript = preload("res://resources/LuaScripts/default.tres")
	var script2 : LuaScript = preload("res://resources/LuaScripts/rook.tres")
	var script3 : LuaScript = preload("res://resources/LuaScripts/counter.tres")
	var script4 : LuaScript = preload("res://resources/LuaScripts/distant.tres")
	_player_joins = [
		Presence.new("Participante1","Participante1", true , script1.lua_script),
		Presence.new("Participante2","Participante2", false, script2.lua_script),
		Presence.new("Participante3","Participante3", false, script3.lua_script),
		Presence.new("Participante4","Participante4", false, script4.lua_script)
	]
#	# TEST FINAL
#	var script1 : LuaScript = preload("res://resources/LuaScripts/launch_right.tres")
#	var script2 : LuaScript = preload("res://resources/LuaScripts/rook.tres")
#	var script3 : LuaScript = preload("res://resources/LuaScripts/counter.tres")
#	var script4 : LuaScript = preload("res://resources/LuaScripts/distant.tres")
#	_player_joins = [
#		Presence.new("Participante1","Participante1", true , script4.lua_script),
#		Presence.new("Participante2","Participante2", false, script1.lua_script),
##		Presence.new("Participante3","Participante3", false, script3.lua_script),
##		Presence.new("Participante4","Participante4", false, script4.lua_script)
#	]
#	# TEST GENERAL
#	var script1 : LuaScript = preload("res://resources/LuaScripts/launch_cross.tres")
#	var script2 : LuaScript = preload("res://resources/LuaScripts/swim_up_launch_right.tres")
#	_player_joins = [
#		Presence.new("Participante1","Participante1", true),
#		Presence.new("Participante2","Participante2", false, script1.lua_script),
#		Presence.new("Participante3","Participante3", false, script2.lua_script),
#		Presence.new("Participante4","Participante4", false, script2.lua_script)
#	]

	# TEST TIE
	# var script1 : LuaScript = preload("res://resources/LuaScripts/swim_left.tres")
	# var script2 : LuaScript = preload("res://resources/LuaScripts/swim_right.tres")
	# _player_joins = [
	# 	Presence.new("Participante1","Participante1", true , script1.lua_script),
	# 	Presence.new("Participante2","Participante2", false, script2.lua_script)
	# ]

func _ready():
	call_deferred("reset")


func _notification(what):
	match _main_state:
		"elapse", "start", "result":
			if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
				pond_match.show_quit_popup()


func reset():
	_main_state = "reset"
	get_tree().set_auto_accept_quit(true)
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
	get_tree().set_auto_accept_quit(true)
	# [TODO] Add scripts in PondMatch for the AI
	pass
	
func elapse() -> void:
	_main_state = "elapse"
	get_tree().set_auto_accept_quit(false)
	pond_match.show()

func start() -> void:
	_main_state = "start"
	get_tree().set_auto_accept_quit(false)
	pond_match.save_pond_scripts()
	pond_match.run()

func result(winner_declared : bool = false) -> void:
	_main_state = "result"
	get_tree().set_auto_accept_quit(false)
	
	
	pond_match.reset_pond_match()

	if not winner_declared:
		return 
	
	show_victory()
	
	

# Quits to MainMenu
func quit() -> void:
	_main_state = "quit"
	get_tree().set_auto_accept_quit(true)

	pond_match.reset_pond_match()
	yield(pond_match, "reset_finished")
	
	PlayerData.reset()
	# warning-ignore: return_value_discarded
	get_tree().change_scene_to(load("res://src/Main/MainMenu.tscn"))

func show_victory() -> void:
	get_tree().paused = true
	
	pond_match.modulate = Color.gray
	victory_popup.set_winner(pond_match.winner)
	victory_popup.popup_centered()
	yield(victory_popup, "confirmed")
	pond_match.modulate = Color.white
	
	get_tree().paused = false

func _on_PondMatch_match_reset_requested() -> void:
	call_deferred("result", false)

func _on_PondMatch_match_ended() -> void:
	call_deferred("result", true)

func _on_PondMatch_match_run_requested() -> void:
	call_deferred("start")

func _on_PondMatch_match_step_requested() -> void:
	pond_match.pond_script_step()

func _on_PondMatch_match_quit_requested() -> void:
	call_deferred("quit")
