extends Node
class_name MultiplayerClient

# Connection closed unexpectedly. Authentication may still be valid.
signal connection_closed()

signal script_received(user_id, script)
signal pond_state_updated(pond_match_tick, pond_state, scripts)

export var is_master : bool = false

var _email : String = "no email"
var _is_connected := false


func _ready():
	ServerConnection.start_client()
	# warning-ignore:return_value_discarded
	ServerConnection.connect("connection_closed", self, "_on_ServerConnection_connection_closed")

func register_connect_join_async(email : String, password : String) -> int:
	var result : int = yield(ServerConnection.register_async(email, password), "completed")
	if result != OK:
		_error_treatment("Register error '%d': \"%s\""%[result, ServerConnection.error_message])
		return result
	
	_email = email
	
	result = yield(ServerConnection.connect_to_server_async(), "completed")
	if result != OK:
		_error_treatment("Connect to server error '%d': \"%s\""%[result, ServerConnection.error_message])
		return result
	_is_connected = true

	result = yield(ServerConnection.join_world_async(is_master), "completed")
	if result != OK:
		_error_treatment("Join world error '%d': \"%s\""%[result, ServerConnection.error_message])
		return result
		
	if is_master:
		# warning-ignore:return_value_discarded
		ServerConnection.connect("script_received", self, "_on_ServerConnection_script_received")
	else:
		# warning-ignore:return_value_discarded
		ServerConnection.connect("pond_state_updated", self, "_on_ServerConnection_pond_state_updated")
		
	return OK

func _exit_tree():
	
	# `disconnect` is called because ServerConnection won't be destroyed
	ServerConnection.disconnect("connection_closed", self, "_on_ServerConnection_connection_closed")

	if is_master:
		if ServerConnection.is_connected("script_received", self, "_on_ServerConnection_script_received"):
			ServerConnection.disconnect("script_received", self, "_on_ServerConnection_script_received")
	else:
		if ServerConnection.is_connected("pond_state_updated", self, "_on_ServerConnection_pond_state_updated"):
			ServerConnection.disconnect("pond_state_updated", self, "_on_ServerConnection_pond_state_updated")
	
	if _is_connected:
		var result : int = yield(ServerConnection.disconnect_from_server_async(), "completed")
		if result != OK:
			_error_treatment("Disconnect error '%d': \"%s\""%[result, ServerConnection.error_message])
			return
		_is_connected = false
	
	ServerConnection.end_client()


func send_script(p_script : String) -> void:
	ServerConnection.send_script(p_script)

func update_pond_state(pond_match_tick : int, pond_state : Dictionary, scripts : Dictionary) -> void:
	ServerConnection.update_pond_state(pond_match_tick, pond_state, scripts)

func _on_ServerConnection_connection_closed() -> void:
	_is_connected = false
	# [TODO] Possibly handle reconnection attempt
	emit_signal("connection_closed")


func _on_ServerConnection_script_received(user_id : String, script : String) -> void :
	emit_signal("script_received", user_id, script)
	
func _on_ServerConnection_pond_state_updated(p_pond_match_tick : int, p_pond_state : Dictionary, p_scripts : Dictionary) -> void:
	emit_signal("pond_state_updated", p_pond_match_tick, p_pond_state, p_scripts)

	
	
func _to_string() -> String:
	return "[%s, email:%s]"%[name, _email]

func _error_treatment(msg : String) -> void:
	push_warning("%s : %s"%[self.to_string(), msg])
