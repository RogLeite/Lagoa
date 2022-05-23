extends Node2D

# [TODO] Either programatically instanciate ducks, allowing variable quantities;
# or manually Build extensions of PondVisualization for each player count.
# export var duck_amount := 1

func _ready() -> void:
	var ducks := [$Duck0.get_path(), $Duck1.get_path()]
	PlayerData.ducks = ducks
