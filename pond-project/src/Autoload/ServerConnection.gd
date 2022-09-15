extends Node

# Message formats by OpCode:
# SEND_SCRIPT = 1:
# {
# 	“user_id” : String,
# 	“script” : String
# }
# UPDATE_POND_STATE = 2:
# {
# 	“pond_match_tick” : int,
# 	“pond_state” : {}   , Dictionary storing the state of the match
# 	“scripts” : {}		, //Dictionary with every script 
# }

## Signals

# Emited when a message with OpCode.SEND_SCRIPT is received
# parameter are the contents of the specified message format
signal script_received(user_id, script)

# Emited when a message with OpCode.UPDATE_POND_STATE is received
# message is a Dictionary in the specified message format
signal pond_state_updated(pond_match_tick, pond_state, scripts) 


## Enums

# Custom operational codes for state messages.
enum OpCodes {
	SEND_SCRIPT = 1, 		# Emits signal `script_received`
	UPDATE_POND_STATE = 2,	# Emits signal `pond_state_received`
	INITIAL_STATE = 3,
	MANUAL_DEBUG = 99
}


## Constants

# Unique key for the server, defined in it's "docker-compose.yml" file
const KEY := "nakama_pond_server"

# String that contains the error message whenever any of the functions that yield return != OK
var error_message := "" setget _no_set, _get_error_message

# The Nakama used to create sessions in the server
var _client : NakamaClient

# Communication line between client and server
var _socket : NakamaSocket

# The identifier of the match this client participates
var _world_id:= ""

# Delegates
var _exception_handler := ExceptionHandler.new()
var _authenticator : Authenticator

# Starts the Nakama Client and connects it to the server
func start_client() -> void:
# [TODO] When the server is hosted non-locally, change the IP address used
	_client = Nakama.create_client(KEY, "127.0.0.1", 7350, "http")
	_authenticator = Authenticator.new(_client, _exception_handler)

# Asynchronous coroutine. Authenticates a new session via email and password, and
# creates a new account when it did not previously exist, then initializes a session.
# Returns OK or a nakama error code. Stores error messages in `ServerConnection.error_message`
func register_async(email: String, password: String) -> int:
	assert(_client, "_client was not initialized, remember to call ServerConnection.start_client()")
	assert(_authenticator, "_authenticator was not initialized, remember to call ServerConnection.start_client()")

	var result : int = yield(_authenticator.register_async(email, password), "completed")

	return result

# Asynchronous coroutine. Authenticates a new session via email and password, but will
# not try to create a new account when it did not previously exist, then
# initializes a session. If a session previously existed in `AUTH` and `force_exception` is false, 
# will try to recover it without needing the authentication server. 
# Returns OK or a nakama error code. Stores error messages in `ServerConnection.error_message`
func login_async(email : String, password : String, force_new_session: bool = false) -> int :
	assert(_client, "_client was not initialized, remember to call ServerConnection.start_client()")
	assert(_authenticator, "_authenticator was not initialized, remember to call ServerConnection.start_client()")
	
	var result: int = yield(_authenticator.login_async(email, password, force_new_session), "completed")
	
	return result

# Starts the socket connection with the server, if possible
# Returns OK or a nakama error code. Stores error messages in `ServerConnection.error_message`
# @return ERR_UNAUTHORIZED if socket connection failed without error
func connect_to_server_async() -> int :
	assert(_client, "_client was not initialized, remember to call ServerConnection.start_client()")
	assert(_authenticator, "_authenticator was not initialized, remember to call ServerConnection.start_client()")
	assert(_authenticator.session, "_authenticator.session was not initialized, remember to call ServerConnection.login_async()")

	
	# Creates the socket
	_socket = Nakama.create_socket_from(_client)
	# Connects the socket 
	var result: NakamaAsyncResult = yield(
		_socket.connect_async(_authenticator.session), "completed"
	)

	var parsed_result := _exception_handler.parse_exception(result)
	
#	If the token recovered from file was invalid, the first error found was that the default value for 
#	the NakamaException.status_code was returned from connect_async, instead of OK or any Error
	if parsed_result == -1 and not _socket.is_connected_to_host():
		# Forces a login of new session
		_exception_handler.error_message = "Socket connection with current session has failed. Saved token might be invalid. Try login_async with `force_new_session = true`"
		return ERR_UNAUTHORIZED
			
	if parsed_result == OK:
		# Connection was opened, connect to signals in the _socket
		#warning-ignore: return_value_discarded
		_socket.connect("closed", self, "_on_NakamaSocket_closed")
		#warning-ignore: return_value_discarded
		_socket.connect("received_match_state", self, "_on_NakamaSocket_received_match_state")
		
	return parsed_result

# Remote calls `get_world_id()` then joins the match
# Returns OK or a nakama error code. Stores error messages in `ServerConnection.error_message`
func join_world_async( is_master : bool) -> int: 
	# Debug assertions
	assert(_client, "_client was not initialized, remember to call ServerConnection.start_client()")
	assert(_socket, "_socket was not initialized, remember to call ServerConnection.connect_to_server_async()")
	
	# Non-debug assertions
	if not _socket:
		_exception_handler.error_message = "Server not connected"
		return ERR_UNAVAILABLE
	
	# [TODO] Pass "is_master" to the get_world rpc, so it can choose a world that still has no MasterClient
	# Gets the world id from the server with RPC to `get_world_id()`
	if not _world_id:
		var rpc_result : NakamaAPI.ApiRpc = yield(_client.rpc_async(_authenticator.session,"get_world_id", ""), "completed")

		var parsed_result := _exception_handler.parse_exception(rpc_result)

		if parsed_result != OK:
			return parsed_result

		_world_id = rpc_result.payload
		

	# Joins the match represented by _world_id
	# [TODO] Maybe the metadata sent can identify if this client wants to be a MasterClient
	var match_join_result: NakamaRTAPI.Match = \
		yield(_socket.join_match_async(_world_id, {"is_master" : String(is_master)}), "completed")
	var parsed_result := _exception_handler.parse_exception(match_join_result)

	if parsed_result == OK:
		# Can enter chat, register presences from match_join_result etc.
		pass
	else:
		return parsed_result

	return parsed_result

# Disconnects from live server
# Assumes the caller has verified the connection is live
# Returns OK or a nakama error number and puts the error message in `ServerConnection.error_message`
func disconnect_from_server_async() -> int:
	var parsed_result := OK
		
	var result: NakamaAsyncResult = yield(_socket.leave_match_async(_world_id), "completed")
	parsed_result = _exception_handler.parse_exception(result)

	# If left the match successfully, clears data
	if parsed_result == OK:
		_reset_data()
		_authenticator.cleanup()

	return parsed_result

func get_user_id() -> String:
	if _authenticator.session:
		return _authenticator.session.user_id
	return ""

func get_username() -> String:
	if _authenticator.session:
		return _authenticator.session.username
	return ""

 # Sends a message to the server stating a change in the script for the player.
func send_script(p_script: String) -> void:
	if _socket:
		var payload := {username = get_username(), script = p_script}
		_socket.send_match_state_async(_world_id, OpCodes.SEND_SCRIPT, JSON.print(payload))


 # Sends a message to the server stating a change in the script for the player.
func update_pond_state(p_pond_match_tick : int, p_pond_state : Dictionary, p_scripts : Dictionary) -> void:
	if _socket:
		var payload := {
			pond_match_tick = p_pond_match_tick,
			pond_state = Adapter.convert(p_pond_state),
			scripts = p_scripts
		}
		_socket.send_match_state_async(_world_id, OpCodes.UPDATE_POND_STATE, JSON.print(payload))



func _get_error_message() -> String:
	return _exception_handler.error_message

# Clears the socket, world i
func _reset_data() -> void:
	_socket = null
	_world_id = ""
	# Cleanup of other data, such as asny presences stored

# De-references the _socket object
func _on_NakamaSocket_closed() -> void:
	_socket = null

# Called when the server sends a match update
func _on_NakamaSocket_received_match_state(match_state : NakamaRTAPI.MatchData) -> void:
	var code := match_state.op_code
	var raw := match_state.data
	match code:
		OpCodes.SEND_SCRIPT:
			var decoded: Dictionary = JSON.parse(raw).result
			var username: String = decoded.username
			var script: String = decoded.script
			emit_signal("script_received", username, script)
		OpCodes.UPDATE_POND_STATE:
			var decoded: Dictionary = JSON.parse(raw).result
			var pond_match_tick: int = decoded.pond_match_tick
			var pond_state: Dictionary = Adapter.deconvert(decoded.pond_state)
			var scripts: Dictionary = decoded.scripts
			
			emit_signal("pond_state_updated", pond_match_tick, pond_state, scripts)
		OpCodes.MANUAL_DEBUG:
			pass

# Used as a setter function for read-only variables.
func _no_set(_value) -> void:
	pass

# Adapts the pond_state Dictionary to and from a acceptable configuration for transmition
class Adapter:
	const TYPE_NAMES=["TYPE_NIL","TYPE_BOOL","TYPE_INT","TYPE_REAL","TYPE_STRING","TYPE_VECTOR2","TYPE_RECT2","TYPE_VECTOR3","TYPE_TRANSFORM2D","TYPE_PLANE","TYPE_QUAT","TYPE_AABB","TYPE_BASIS","TYPE_TRANSFORM","TYPE_COLOR","TYPE_NODE_PATH","TYPE_RID","TYPE_OBJECT","TYPE_DICTIONARY","TYPE_ARRAY","TYPE_RAW_ARRAY","TYPE_INT_ARRAY","TYPE_REAL_ARRAY","TYPE_STRING_ARRAY","TYPE_VECTOR2_ARRAY","TYPE_VECTOR3_ARRAY","TYPE_COLOR_ARRAY","TYPE_MAX"]

	static func convert_Vector2(vector : Vector2) -> Dictionary:
		return {x = vector.x, y = vector.y}
	static func deconvert_Vector2(vector : Dictionary) -> Vector2:
		return Vector2(vector.x, vector.y)

	static func convert(state : Dictionary) -> Dictionary:
		return {ball_position = convert_Vector2(state.ball_position)}
	static func deconvert(state : Dictionary) -> Dictionary:
		return {ball_position = deconvert_Vector2(state.ball_position)}
