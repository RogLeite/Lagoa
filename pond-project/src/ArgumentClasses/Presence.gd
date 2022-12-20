# Stripped-down version of Nakama's concept of Presence, for use internally in the game
extends Reference
class_name Presence

var user_id : String
var username : String
var pond_script : String

func _init(p_user_id : String = "", p_username : String = "", p_pond_script : String = ""):
	user_id = p_user_id
	username = p_username
	pond_script = p_pond_script

func _to_string() -> String:
	return "Presence<username=%s, user_id=%s, pond_script=%s>"%[username, user_id, pond_script]

func get_class() -> String:
	return "Presence"
