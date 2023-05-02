extends Node
# Stores player data as autoloaded singleton for ease of access by the whole game

# Emmited when a player joins
signal player_joined(p_index)
# Emmited when a player leaves
signal player_left(p_index)
# Emmited when a player's script has changed
signal pond_script_changed(p_index, p_script)

const MAX_PLAYERS_PER_MATCH : int = 4

var _present_count : int = 0

# Players in the match. If one leaves, the default behaviour is not to remove it from this array, because they can return
var players : Array setget _no_set

func present_count() -> int:
	return _present_count

func count() -> int:
	return players.size()

func get_duck_node(p_index : int) -> Node: 
	var path = players[p_index].duck_path
	if is_inside_tree() and has_node(path):
		return get_node(path)
	return null

# Gets an array with the nodes for every player's Duck
# If a player does not have a duck_path defined, it's index in the array has `null`
func get_duck_nodes() -> Array:
	var ret := []
	
	for i in players.size():
		ret.append(get_duck_node(i))

	return ret

func duck_node_to_index(p_duck : Node) -> int:
	var ducks = get_duck_nodes()
	for i in ducks.size():
		if ducks[i] == p_duck:
			return i
	
	return -1


# Checks if the player at p_index is present
func is_present(p_index : int) -> bool:
	return players.size() > p_index and players[p_index] and players[p_index].is_present

# Checks if the player at p_index has it's duck_path defined
func has_duck(p_index : int) -> bool:
	return not players[p_index].duck_path.is_empty()

# Does not check if `players` has the same size as p_paths
func set_duck_paths(p_paths : Array) -> void:
	for i in p_paths.size():
		set_duck_path(i, p_paths[i])

func set_duck_path(p_index : int, p_path : NodePath) -> void:
	players[p_index].duck_path = p_path

# Sets the player's script as p_script, if is different
# then, is p_supress_signal is not true, emits "pond_script_changed"
func set_pond_script(p_index : int, p_script : String, p_supress_signal : bool = false) -> void:
	if players[p_index].pond_script == p_script:
		return
		
	players[p_index].pond_script = p_script
	if not p_supress_signal:
		emit_signal("pond_script_changed", p_index, p_script)

# Returns -1 if no player is the user. This should not happen, but is needed for syntatic correctness
func get_user_index() -> int:
	for i in players.size():
		if players[i].is_user:
			return i
	return -1

func get_player(p_index : int):
	return players[p_index]

# Checks if index corresponds to the user
func is_user(p_index : int) -> bool:
	return players[p_index] and players[p_index].is_user

# Returns first index available for reservation. Returns the size of the array if there are no spaces available
func get_unreserved_index() -> int:
	for i in players.size():
		if not players[i] or not players[i].keep_reservation:
			return i
	return players.size()

# Returns -1 if not found. This should not happen, but is needed for syntatic correctness
func get_index_by_user_id(p_user_id : String) -> int:
	for i in players.size():
		if players[i].user_id == p_user_id:
			return i
	return -1

func get_user_pond_script() -> String:
	return get_pond_script(get_user_index())

func get_pond_script(p_index : int) -> String:
	return players[p_index].pond_script

func get_pond_scripts() -> Array:
	var ret = []
	for i in players.size():
		ret.push_back(get_pond_script(i))
	return ret


# Checks if a Player with p_user_id is already present in `players`
func is_registered_player(p_user_id : String) -> bool:
	for player in players:
		if player.user_id == p_user_id:
			return true
	return false

# If the specified player is already in `players`, sets `is_present` to `true`
# and emits `player_joined`
func join_player(p_join : Presence) -> void:
	for i in players.size():

		if players[i].user_id != p_join.user_id:
			continue

		if not players[i].is_present :
			_present_count += 1
		players[i].is_present = true
		set_pond_script(i, p_join.pond_script)
		emit_signal("player_joined", i)
		return
	
# Marks a player as absent
func leave_player(p_leave : Presence) -> void:
	for i in players.size():
		var datum : PlayerDatum = players[i]
		if datum.user_id != p_leave.user_id:
			continue

		if datum.is_present :
			_present_count -= 1
		datum.is_present = false
		emit_signal("player_left", i)
		return

# Adds a new player and joins it
# DOES NOT CHECK IF PLAYER IS ALREADY PRESENT
func add_player(p_join : Presence) -> void:
	var datum = PlayerDatum.new()
	datum.user_id = p_join.user_id
	datum.username = p_join.username
	datum.is_user = p_join.is_user
	
	var index : int = get_unreserved_index()
	if index < players.size():
		leave_player(players[index])
		players[index] = datum
	else:
		players.push_back(datum)
		
	
	set_pond_script(index, p_join.pond_script)
	join_player(p_join)

# Drops a Player's reservation, so when they leave they are forgotten
func drop_reservation(p_user_id) -> void:
	var index: int = get_index_by_user_id(p_user_id)
	if index == -1:
		return
	players[index].keep_reservation = false

# Resets PlayerData's state without emitting any signal
func reset() -> void:
	_present_count = 0
	players = []	


func _no_set(_val):
	pass

class PlayerDatum extends Presence:
	# var user_id : String  = ""
	# var username : String  = ""
	# var pond_script : String  = ""
	# var is_user : bool = false
	var duck_path : NodePath = ""
	var last_compileable_script : String  = ""
	var is_present : bool = false
	var keep_reservation : bool = true
