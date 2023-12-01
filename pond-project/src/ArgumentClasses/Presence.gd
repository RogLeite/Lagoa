# Stripped-down version of Nakama's concept of Presence, for use internally in the game
extends Reference
class_name Presence

var user_id : String
var username : String
var is_user : bool
var pond_script : String

func _init(p_user_id : String = "", p_username : String = "", p_is_user : bool = false, p_pond_script = null):
	user_id = p_user_id
	username = p_username
	pond_script = p_pond_script if p_pond_script else preload("res://resources/LuaScripts/default.tres").lua_script
	is_user = p_is_user

func _to_string() -> String:
	return "Presence<username=%s, user_id=%s, is_user=%s, pond_script=%s>"%[username, user_id, is_user, pond_script]

func get_class() -> String:
	return "Presence"
