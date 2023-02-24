extends Node

enum {JOIN, LEAVE, DROP_RESERVATION}

var responsible : Node

var _cache : Array = [] setget _no_set, _no_get

func add_join(p_join) -> void:
	_cache.push_back({"type":JOIN, "player":p_join})

func add_leave(p_leave) -> void:
	_cache.push_back({"type":LEAVE, "player":p_leave})
	
func add_drop_reservation(p_user_id : String) -> void:
	_cache.push_back({"type":DROP_RESERVATION, "player":p_user_id})

func release() -> void:
	for v in _cache:
		match v.type:
			JOIN:
				responsible.join(v.player)
			LEAVE:
				responsible.leave(v.player)
			DROP_RESERVATION:
				responsible.drop_reservation(v.player)
	_cache.clear()

func _to_string() -> String:
	var ret : Array = []
	for v in _cache:
		ret.push_back("%s:%s"%["join" if v.type==JOIN else "leave", v.player.username])
	return String(ret)


func _no_set(_v) -> void:
	pass
func _no_get():
	pass
