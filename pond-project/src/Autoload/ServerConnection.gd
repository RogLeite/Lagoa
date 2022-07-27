extends Node

# Signals

# Enums

# Custom operational codes for state messages.
enum OpCodes {
	SEND_SCRIPT = 1,
	UPDATE_POND_STATE,
	INITIAL_STATE,
	MANUAL_DEBUG = 99
}

# Unique key for the server, defined in it's "docker-compose.yml" file
const KEY := "nakama_pond_server"

# String that contains the error message whenever any of the functions that yield return != OK
var error_message := "" setget _no_set, _get_error_message

# Stores the authentication token for the user's session in the server
var _session: NakamaSession

# The Nakama used to create sessions in the server
var _client : NakamaClient

# Communication line between client and server
var _socket : NakamaSocket

# The identifier of the match this client participates
var _world_id:= ""

var _exception_handler := ExceptionHandler.new()

# Starts the Nakama Client and connects it to the server
func start_client():
# [TODO] When the server is hosted non-locally, change the IP address used
	 _client = Nakama.create_client(KEY, "127.0.0.1", 7350, "http")

# Authenticates a new session from the given email and password. If it's a new user, registers the credentials
# Returns OK or a nakama error code. Stores error messages in `ServerConnection.error_message`
# [TODO] Split Registering from Authenticating
func authenticate_async(email : String, password : String) -> int :
	assert(_client, "_client was not initialized, remember to call ServerConnection.start_client()")		 
	
	var should_create := true

	var new_session: NakamaSession = \
		yield(_client.authenticate_email_async(email, password, email, should_create), "completed")	
	
	var result := _exception_handler.parse_exception(new_session)

	if result == OK:
		_session = new_session
		
	return result

# Starts the socket connection with the server, if possible
# Returns OK or a nakama error code. Stores error messages in `ServerConnection.error_message`
func connect_to_server_async() -> int :
	assert(_client, "_client was not initialized, remember to call ServerConnection.start_client()")
	assert(_session, "_session was not initialized, remember to call ServerConnection.authenticate_async()")
	
	# Creates the socket
	_socket = Nakama.create_socket_from(_client)
	# Connects the socket 
	var result: NakamaAsyncResult = \
		yield(_socket.connect_async(_session), "completed")

	var parsed_result := _exception_handler.parse_exception(result)

	if parsed_result == OK:
		# Connection was opened, connect to signals in the _socket
		_socket.connect("closed", self, "_on_NakamaSocket_closed")
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
		var rpc_result : NakamaAPI.ApiRpc = yield(_client.rpc_async(_session,"get_world_id", ""), "completed")

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

	return parsed_result

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
		# [TODO] Remove the code corresponding to OpCode.MANUAL_DEBUG
		OpCodes.MANUAL_DEBUG:
			# Receives the current server tick
			var decoded: Dictionary = JSON.parse(raw).result

			var current_tick: int = decoded.current_tick
			print("Current server current_tick: %d"%current_tick)

# Used as a setter function for read-only variables.
func _no_set(_value) -> void:
	pass

# [TODO] Remove this method. It is only used for debugging.
# func _ready():
# 	start_client()
# 	var email := "test1@pond.com"
# 	var password := "password"
# 	print("Authenticate: %d"%yield( authenticate_async(email, password), "completed" ))
# 	print("Connect to Server: %d"%yield( connect_to_server_async(), "completed" ))
# 	yield( join_world_async(), "completed" )

# func _exit_tree():
# 	var result : int = yield(disconnect_from_server_async(), "completed")
# 	if result == OK:
# 		print("Disconnect from server sucessful")
# 	else:
# 		print("Disconnect from server sucessful: %s"%self.error_message)