extends Node

# Stores player data as autoloaded singleton for ease of access by the whole game
# [TODO] Implement storage for more than one player/duck

var duck : NodePath setget set_duck

func set_duck(path : NodePath):
	duck = path
