# Class that stores the order the Ducks got tired 
extends Reference

class_name TiredRegistry

var _order : Array = [_new_set()] setget _no_set, _no_get
var total_tired : int = 0 setget _no_set

func _init():
	reset()

func reset():
	_order = [_new_set()]
	total_tired = 0

func add_frame() -> void:
	if _order.back().size() == 0 :
		return
	_order.push_back(_new_set())

func add_duck(p_duck : Duck) -> void:
	_order.back().push_back(p_duck)
	total_tired += 1

func last_tired():
	return _order.back()

func _new_set() -> Array:
	return []

func _no_set(_v) -> void:
	pass
func _no_get():
	pass
