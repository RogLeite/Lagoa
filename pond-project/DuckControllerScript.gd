extends LuaController

onready var result = 0
export var duck_idx := 0

func _ready():
	
	set_methods_to_register({
		"swim":"swim",
		"stop":"stop"
		})

func swim(angle, target):
	var duck = get_node(PlayerData.ducks[duck_idx])
	duck.call_deferred("swim", angle, target)
	# [TODO] yield waiting for a "next" step signal
	
func stop():
	var duck = get_node(PlayerData.ducks[duck_idx])
	duck.call_deferred("stop")
	# [TODO] yield waiting for a "next" step signal
	
