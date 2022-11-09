extends Node
class_name MultiplayerClient

# Connection closed unexpectedly. Authentication may still be valid.
signal connection_closed()

signal pond_match_ended()
signal pond_script_received(user_id, pond_script)
signal pond_state_updated(pond_state, pond_scripts)
signal joins_received(p_joins)
signal leaves_received(p_leaves)

export var is_master : bool = false
# Sets the log level of NakamaLogger
export(NakamaLogger.LOG_LEVEL) var log_level = NakamaLogger.LOG_LEVEL.WARNING

var error_message : String = "" setget _no_set, _get_error_message

var _is_connected : bool = false
var _force_new_session : bool = false


func _ready():
	start()

func login_async(email : String, password : String, do_remember_email : bool) -> int :
	var result : int = yield(ServerConnection.login_async(email, password, _force_new_session), "completed")


	if do_remember_email:
		ServerConnection.save_email(email)

	_force_new_session = false

	return result
	
func register_async(email : String, password : String, do_remember_email : bool) -> int :
	var result : int = yield(ServerConnection.register_async(email, password), "completed")
	
	if do_remember_email:
		ServerConnection.save_email(email)

	_force_new_session = false
		
	return result


func connect_async() -> int:
	var result: int = yield(ServerConnection.connect_to_server_async(), "completed")
	
	if result == OK:
		_is_connected = true
	
	return result

func join_async() -> int :
	var result: int = yield(ServerConnection.join_world_async(is_master), "completed")
	if result != OK:
		return result
		
	if is_master:
		# warning-ignore:return_value_discarded
		ServerConnection.connect("pond_script_received", self, "_on_ServerConnection_pond_script_received")
		# warning-ignore:return_value_discarded
		ServerConnection.connect("joins_received", self, "_on_ServerConnection_joins_received")
		# warning-ignore:return_value_discarded
		ServerConnection.connect("leaves_received", self, "_on_ServerConnection_leaves_received")
	else:
		# warning-ignore:return_value_discarded
		ServerConnection.connect("pond_match_ended", self, "_on_ServerConnection_pond_match_ended")
		# warning-ignore:return_value_discarded
		ServerConnection.connect("pond_state_updated", self, "_on_ServerConnection_pond_state_updated")
		
	return OK

func start() -> void:
	ServerConnection.start_client(log_level)
	# warning-ignore:return_value_discarded
	ServerConnection.connect("connection_closed", self, "_on_ServerConnection_connection_closed")
	_force_new_session = true

func reset() -> void: 
	yield(end(), "completed")
	start()

func end() -> void:
	# `disconnect` is called because ServerConnection won't be destroyed
	ServerConnection.disconnect("connection_closed", self, "_on_ServerConnection_connection_closed")

	if is_master:
		if ServerConnection.is_connected("pond_script_received", self, "_on_ServerConnection_pond_script_received"):
			ServerConnection.disconnect("pond_script_received", self, "_on_ServerConnection_pond_script_received")
		if ServerConnection.is_connected("joins_received", self, "_on_ServerConnection_joins_received"):
			ServerConnection.disconnect("joins_received", self, "_on_ServerConnection_joins_received")
		if ServerConnection.is_connected("leaves_received", self, "_on_ServerConnection_leaves_received"):
			ServerConnection.disconnect("leaves_received", self, "_on_ServerConnection_leaves_received")
	else:
		if ServerConnection.is_connected("pond_state_updated", self, "_on_ServerConnection_pond_state_updated"):
			ServerConnection.disconnect("pond_state_updated", self, "_on_ServerConnection_pond_state_updated")
	
	if _is_connected:
		var result : int = yield(ServerConnection.disconnect_from_server_async(), "completed")
		if result != OK:
			push_error("%s : Disconnect error '%d': \"%s\""%[self.to_string(), result, ServerConnection.error_message])
			return
		_is_connected = false
	else:
		yield(Engine.get_main_loop(), "idle_frame")
	
	ServerConnection.end_client()

func _exit_tree():
	end()

func end_pond_match() -> void:
	ServerConnection.end_pond_match()
	
func send_script(p_script : String) -> void:
	ServerConnection.send_script(p_script)

func update_pond_state(pond_state : PondMatch.State, scripts : Dictionary) -> void:
	ServerConnection.update_pond_state(pond_state, scripts)

func _on_ServerConnection_connection_closed() -> void:
	_is_connected = false
	# [TODO] Possibly handle reconnection attempt
	emit_signal("connection_closed")


func _on_ServerConnection_pond_match_ended() -> void :
	emit_signal("pond_match_ended")

func _on_ServerConnection_pond_script_received(p_user_id : String, p_pond_script : String) -> void :
	emit_signal("pond_script_received", p_user_id, p_pond_script)
	
func _on_ServerConnection_pond_state_updated(p_pond_state : PondMatch.State, p_pond_scripts : Dictionary) -> void:
	emit_signal("pond_state_updated", p_pond_state, p_pond_scripts)

func _on_ServerConnection_joins_received(p_joins : Array) -> void :
	emit_signal("joins_received", p_joins)

func _on_ServerConnection_leaves_received(p_leaves : Array) -> void :
	emit_signal("leaves_received", p_leaves)


func _no_set(_value) -> void:
	pass

func _get_error_message() -> String:
	return ServerConnection.error_message	

func _to_string() -> String:
	return "[%s]"%name
