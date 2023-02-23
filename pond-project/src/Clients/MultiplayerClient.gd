extends Node
class_name MultiplayerClient

# Connection closed unexpectedly. Authentication may still be valid.
signal connection_closed()

signal pond_match_ended()
signal pond_script_received(user_id, pond_script)
signal pond_state_updated(pond_state)
signal joins_received(p_joins)
signal leaves_received(p_leaves)
signal master_left

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
	
	connect_signals()
		
	# [TODO] Trocar onde chamar isso
	result = yield(ServerConnection.get_presences_async(), "completed")
	if result != OK:
		return result

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

	disconnect_signals()

	if _is_connected:
		var result : int = yield(ServerConnection.disconnect_from_server_async(), "completed")
		if result != OK:
			push_error("%s : Disconnect error '%d': \"%s\""%[self.to_string(), result, ServerConnection.error_message])
			return
		_is_connected = false
	else:
		yield(Engine.get_main_loop(), "idle_frame")
	
	ServerConnection.end_client()

func connect_signal(signal_name):
	# warning-ignore:return_value_discarded
	ServerConnection.connect(signal_name, self, "_on_ServerConnection_"+signal_name)

func disconnect_signal(signal_name):
	if ServerConnection.is_connected(signal_name, self, "_on_ServerConnection_"+signal_name):
		ServerConnection.disconnect(signal_name, self, "_on_ServerConnection_"+signal_name)
	
func connect_signals() -> void:

	connect_signal("joins_received")
	connect_signal("leaves_received")
	
	if is_master:
		connect_signal("pond_script_received")
	else:
		connect_signal("pond_match_ended")
		connect_signal("pond_state_updated")
		connect_signal("master_left")

func disconnect_signals() -> void:
	# `disconnect` is called because ServerConnection won't be destroyed
	ServerConnection.disconnect("connection_closed", self, "_on_ServerConnection_connection_closed")

	disconnect_signal("joins_received")
	disconnect_signal("leaves_received")

	if is_master:
		disconnect_signal("pond_script_received")
	else:
		disconnect_signal("pond_match_ended")
		disconnect_signal("pond_state_updated")
		disconnect_signal("master_left")

func _exit_tree():
	yield(end(), "completed")

func end_pond_match() -> void:
	ServerConnection.end_pond_match()
	
func send_pond_script(p_pond_script : String) -> void:
	ServerConnection.send_pond_script(p_pond_script)

func update_pond_state(pond_state : PondMatch.State) -> void:
	ServerConnection.update_pond_state(pond_state)

func _on_ServerConnection_connection_closed() -> void:
	_is_connected = false
	# [TODO] Possibly handle reconnection attempt
	emit_signal("connection_closed")


func _on_ServerConnection_pond_match_ended() -> void :
	emit_signal("pond_match_ended")

func _on_ServerConnection_pond_script_received(p_user_id : String, p_pond_script : String) -> void :
	emit_signal("pond_script_received", p_user_id, p_pond_script)
	
func _on_ServerConnection_pond_state_updated(p_pond_state : PondMatch.State) -> void:
	emit_signal("pond_state_updated", p_pond_state)

func _on_ServerConnection_master_left() -> void:
	emit_signal("master_left")

func _on_ServerConnection_joins_received(p_joins : Array) -> void :
	# print("_on_ServerConnection_joins_received:%s"%String(p_joins))
	emit_signal("joins_received", p_joins)
	
func _on_ServerConnection_leaves_received(p_leaves : Array) -> void :
	# print("_on_ServerConnection_leaves_received: %s"%String(p_leaves))
	emit_signal("leaves_received", p_leaves)


func _no_set(_value) -> void:
	pass

func _get_error_message() -> String:
	return ServerConnection.error_message	

func _to_string() -> String:
	return "[%s]"%name
