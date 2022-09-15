extends Node
class_name MultiplayerClient

signal script_received(user_id, script)
signal pond_state_updated(pond_match_tick, pond_state, scripts)

var _is_connected := false

# [TODO] Remove placeholder credentials and error treatment
export var username := "MultiplayerClient@test.com"
export var password := "password"
export var is_master : bool = false


func _ready():
	
	ServerConnection.start_client()
	
	var result : int = yield(ServerConnection.register_async(username, password), "completed")
	if result != OK:
		_print_error("Register error '%d': \"%s\""%[result, ServerConnection.error_message])
		return

	result = yield(ServerConnection.connect_to_server_async(), "completed")
	if result != OK:
		_print_error("Connect to server error '%d': \"%s\""%[result, ServerConnection.error_message])
		return
	_is_connected = true

	result = yield(ServerConnection.join_world_async(is_master), "completed")
	if result != OK:
		_print_error("Join world error '%d': \"%s\""%[result, ServerConnection.error_message])
		return
		
	if is_master:
		# warning-ignore:return_value_discarded
		ServerConnection.connect("script_received", self, "_on_ServerConnection_script_received")
	else:
		# warning-ignore:return_value_discarded
		ServerConnection.connect("pond_state_updated", self, "_on_ServerConnection_pond_state_updated")

func _exit_tree():
	
	if is_master:
		ServerConnection.disconnect("script_received", self, "_on_ServerConnection_script_received")
	else:
		ServerConnection.disconnect("pond_state_updated", self, "_on_ServerConnection_pond_state_updated")
	
	if _is_connected:
		var result : int = yield(ServerConnection.disconnect_from_server_async(), "completed")
		if result != OK:
			_print_error("Disconnect error '%d': \"%s\""%[result, ServerConnection.error_message])
			return
		_is_connected = false


func send_script(p_script : String) -> void:
	ServerConnection.send_script(p_script)

func update_pond_state(pond_match_tick : int, pond_state : Dictionary, scripts : Dictionary) -> void:
	ServerConnection.update_pond_state(pond_match_tick, pond_state, scripts)


func _on_ServerConnection_script_received(user_id : String, script : String) -> void :
	emit_signal("script_received", user_id, script)
	
func _on_ServerConnection_pond_state_updated(p_pond_match_tick : int, p_pond_state : Dictionary, p_scripts : Dictionary) -> void:
	emit_signal("pond_state_updated", p_pond_match_tick, p_pond_state, p_scripts)

	
	
func _to_string() -> String:
	return "[%s, username:%s]"%[name, username]

func _print_error(msg : String) -> void:
	push_error("%s : %s"%[self.to_string(), msg])
