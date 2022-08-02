extends Node

# Signals

# Enums

# Custom operational codes for state messages.
enum OpCodes {
	SEND_SCRIPT = 1,
	UPDATE_POND_STATE = 2,
	INITIAL_STATE = 3,
	MANUAL_DEBUG = 99
}

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
func start_client():
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
func join_world_async() -> int: 
	# Debug assertions
	assert(_client, "_client was not initialized, remember to call ServerConnection.start_client()")
	assert(_socket, "_socket was not initialized, remember to call ServerConnection.connect_to_server_async()")
	
	# Non-debug assertions
	if not _socket:
		_exception_handler.error_message = "Server not connected"
		return ERR_UNAVAILABLE
	
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
		yield(_socket.join_match_async(_world_id), "completed")
	var parsed_result := _exception_handler.parse_exception(match_join_result)

	if parsed_result == OK:
		# Can enter chat, register presences from match_join_result etc.
		pass
	else:
		return parsed_result

	return parsed_result

# Disconnects from live server
# Returns OK or a nakama error number and puts the error message in `ServerConnection.error_message`
func disconnect_from_server_async() -> int:
	var result: NakamaAsyncResult = \
		yield(_socket.leave_match_async(_world_id), "completed")
	var parsed_result := _exception_handler.parse_exception(result)

	# If left the match successfully, clears data
	if parsed_result == OK:
		_reset_data()
		_authenticator.cleanup()

	return parsed_result

func get_user_id() -> String:
	if _authenticator.session:
		return _authenticator.session.user_id
	return ""

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
		# [TODO] Remove this code corresponding to OpCode.MANUAL_DEBUG
		OpCodes.MANUAL_DEBUG:
			# Receives the current server tick
			var decoded: Dictionary = JSON.parse(raw).result

			var current_tick: int = decoded.current_tick
			print_debug("Current server current_tick: %d"%current_tick)

# Used as a setter function for read-only variables.
func _no_set(_value) -> void:
	pass

# [TODO] Remove this method. It is only used for debugging.
# func _ready():
# 	start_client()
# 	var email := "test1@pond.com"
# 	var password := "password"
	
# 	# Test 1: Fail login then register
# 	# yield( login_async(email, password), "completed" )
# 	# print("Login fail: %s"%_get_error_message())
# 	# print("Registered. Result = %d"% yield( register_async(email, password), "completed" ))
	
# 	# Test 2: Just register
# #	print("Registered. Result = %d"% yield( register_async(email, password), "completed" ))
	
# 	# Test 3: Just login. For a success, needs the a register in previous session
# 	print("LOGIN IN:")
# 	var result: int = yield( login_async(email, password), "completed" )
# 	if result != OK :
# 		print("Error %d when login in: %s"%[result, self.error_message])
# 	print("")



# 	print("CONNECT TO SERVER")
# 	result = yield( connect_to_server_async(), "completed" )
# 	if result != OK :
# 		print("Error %d when connecting: %s. Trying again..."%[result, self.error_message])
# 	if result == ERR_UNAUTHORIZED:
# 		var new_result: int = yield( login_async(email, password, true), "completed" )
# 		if new_result != OK :
# 			print("Error %d when login in: %s"%[result, self.error_message])
# 		new_result = yield( connect_to_server_async(), "completed" )
# 		if new_result != OK :
# 			print("Error %d when connecting: %s."%[result, self.error_message])
		
	
# 	print("")
		
# 	yield(Engine.get_main_loop(), "idle_frame")
# #	print("Connect Error Message : %s"%_get_error_message())
	
# 	print("JOIN MATCH")
# 	result = yield( join_world_async(), "completed" )
# 	if result != OK :
# 		print("Error %d when joining: %s"%[result, self.error_message])
# 	print("")

# func _exit_tree():
# 	var result : int = yield(disconnect_from_server_async(), "completed")
# 	if result == OK:
# 		print("Disconnect from server sucessful")
# 	else:
# 		print("Disconnect from server unsucessful: %s"%self.error_message)
