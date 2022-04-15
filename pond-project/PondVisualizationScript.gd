extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var ducks = [$Duck1.get_path(), $Duck2.get_path()]
	PlayerData.ducks.append_array(ducks)

