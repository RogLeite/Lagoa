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
	if players.size() > 0:
		for i in players.size():
			ret.append(get_duck_node(i))
	return ret

# Checks if the player at p_index is present
func is_present(p_index : int) -> bool:
	return players[p_index] and players[p_index].is_present

# Checks if the player at p_index has it's duck_path defined
func has_duck(p_index : int) -> bool:
	return not players[p_index].duck_path.is_empty()

# Does not check if `players` has the same size as p_paths
func set_duck_paths(p_paths : Array) -> void:
	for i in p_paths.size():
		set_duck_path(i, p_paths[i])

func set_duck_path(p_index : int, p_path : NodePath) -> void:
	players[p_index].duck_path = p_path

func set_pond_script(p_index : int, p_script : String) -> void:
	if players[p_index].pond_script != p_script:
		players[p_index].pond_script = p_script
		emit_signal("pond_script_changed", p_index, p_script)

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
		if players[i].user_id == p_join.user_id:
			if not players[i].is_present :
				_present_count += 1
			players[i].is_present = true
			emit_signal("player_joined", i)
			return
	
# Marks a player as absent
func leave_player(p_leave : Presence) -> void:
	for i in players.size():
		if players[i].user_id == p_leave.user_id:
			if players[i].is_present :
				_present_count -= 1
			players[i].is_present = false
			emit_signal("player_left", i)
			return

# Adds a new player and joins it
# DOES NOT CHECK IF PLAYER IS ALREADY PRESENT
func add_player(p_join : Presence) -> void:
	var datum = PlayerDatum.new()
	datum.user_id = p_join.user_id
	datum.username = p_join.username
	players.push_back(datum)
	join_player(p_join)

# [TODO] Force the removal of the player.
func remove_player():
	pass	

func _no_set(_val):
	pass

class PlayerDatum extends Reference:
	var duck_path : NodePath = ""
	var user_id : String  = ""
	var username : String  = ""
	var pond_script : String  = ""
	var last_compileable_script : String  = ""
	var is_present : bool = false
