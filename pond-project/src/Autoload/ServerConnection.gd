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

# Stores the authentication token for the user's session in the server
var _session: NakamaSession

# The Nakama used to create sessions in the server
var _client : NakamaClient

# Communication line between client and server
var _socket : NakamaSocket

# The identifier of the match this client participates
var _world_id:= ""

# Starts the Nakama Client and connects it to the server
func start_client():
# [TODO] When the server is hosted non-locally, change the IP address used
	 _client = Nakama.create_client(KEY, "127.0.0.1", 7350, "http")

# Authenticates a new session from the given email and password. If it's a new user, registers the credentials
# Can return: 
# 	OK if successful
# 	ERR_CANT_CONNECT if authenticate_email_async() failed
# [TODO] Split Registering from Authenticating
func authenticate_async(email : String, password : String) -> int :
	assert(_client, "_client was not initialized, remember to call ServerConnection.start_client()")		 
	
	var result := OK
	
	var should_create := true

	var new_session: NakamaSession = \
		yield(_client.authenticate_email_async(email, password, email, should_create), "completed")	
	
	if not new_session.is_exception():
		_session = new_session
	else:
		result = new_session.get_exception().status_code
		
	return result

# Starts the socket connection with the server, if possible
# returns ERR_CANT_CONNECT if socket could not connect to the session
func connect_to_server_async() -> int :
	assert(_client, "_client was not initialized, remember to call ServerConnection.start_client()")
	assert(_session, "_session was not initialized, remember to call ServerConnection.authenticate_async()")
	
	# Creates the socket
	_socket = Nakama.create_socket_from(_client)
	# Connects the socket 
	var result: NakamaAsyncResult = \
		yield(_socket.connect_async(_session), "completed")

	# Connection failed, returns error
	if result.is_exception():
		return ERR_CANT_CONNECT

	# Connection was opened, connect to signals in the _socket
	_socket.connect("closed", self, "_on_NakamaSocket_closed")
	_socket.connect("received_match_state", self, "_on_NakamaSocket_received_match_state")
	return OK

# Remote calls `get_world_id()` then joins the match
func join_world_async(): 
	# Debug assertions
	assert(_client, "_client was not initialized, remember to call ServerConnection.start_client()")
	assert(_socket, "_socket was not initialized, remember to call ServerConnection.connect_to_server_async()")
	
	# Non-debug assertions
	if not _socket:
		printerr("Server not connected.")
		return
	
	# Gets the world id from the server with RPC to `get_world_id()`
	var rpc_result : NakamaAPI.ApiRpc = yield(_client.rpc_async(_session,"get_world_id", ""), "completed")

	if not rpc_result.is_exception():
		_world_id = rpc_result.payload
	else: 
		var exception: NakamaException = rpc_result.get_exception()
		printerr("RPC returned exception: %s - %s." % [exception.status_code, exception.message])
		return

	# Joins the match represented by _world_id
	# [TODO] Maybe the metadata sent can identify if this client wants to be a MasterClient
	var match_join_result: NakamaRTAPI.Match = \
		yield(_socket.join_match_async(_world_id), "completed")
	# If join failed, prints error message
	if match_join_result.is_exception():
		var exception : NakamaException = match_join_result.get_exception()
		printerr("Error joining the match: %s - %s" % [exception.status_code, exception.message])
		return

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

# [TODO] Remove this method. It is only used for debugging.
# func _ready():
# 	start_client()
# 	var email := "test1@pond.com"
# 	var password := "password"
# 	print("Authenticate: %d"%yield( authenticate_async(email, password), "completed" ))
# 	print("Connect to Server: %d"%yield( connect_to_server_async(), "completed" ))
# 	yield( join_world_async(), "completed" )
