extends HBoxContainer
class_name Match

onready var player_script := $PlayerScript
onready var lua := $LuaController

func run():
	lua.set_lua_code(player_script.text)
	var error_message = ""
	
	if lua.compile() != OK :
		error_message = lua.get_error_message()
	elif lua.run() != OK:
		error_message = lua.get_error_message()
	
	if error_message != "" :
		print_debug(error_message)
