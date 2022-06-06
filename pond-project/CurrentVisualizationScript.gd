extends Node

# Stores the current active PondVisualization for ease of acess

var current : NodePath

# Returns ERR_CANT_RESOLVE if the node is not inside the tree
func set_current(node : Node):
	if not node.is_inside_tree():
		return ERR_CANT_RESOLVE
	current = node.get_path()

func get_current() -> Node : 
	if current.is_empty() :
		return null
	return get_node(current) 
