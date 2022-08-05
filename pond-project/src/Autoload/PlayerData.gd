extends Node

# Stores player data as autoloaded singleton for ease of access by the whole game

# [TODO] Better data structure to represent player
#    - Probably a Resource called PlayerDatum (https://docs.godotengine.org/en/3.4/tutorials/scripting/resources.html#creating-your-own-resources)
#    - Has storage for the current edited, player script and a storage for the last successfully compiled
var ducks : Array

func get_duck(duck_idx : int) : 
	var path = ducks[duck_idx]
	if is_inside_tree() and has_node(path):
		return get_node(path)
	else:
		return null
func get_ducks_as_nodes() -> Array:
	var ret := []
	for i in ducks.size():
		ret.append(get_duck(i))
	return ret
