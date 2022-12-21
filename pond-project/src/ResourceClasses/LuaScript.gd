extends Resource
class_name LuaScript

export(String, MULTILINE) var lua_script : String = "swim(0)" setget set_lua_script

func _init(p_lua_script : String):
	lua_script = p_lua_script

func set_lua_script(p_lua_script : String) -> void:
	lua_script = p_lua_script

func get_class() -> String:
	return "LuaScript"
