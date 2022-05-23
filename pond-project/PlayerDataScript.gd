extends Node

# Stores player data as autoloaded singleton for ease of access by the whole game

# [TODO] Better data structure to represent player
#    - Probably a Resource called PlayerDatum (https://docs.godotengine.org/en/3.4/tutorials/scripting/resources.html#creating-your-own-resources)
#    - Has storage for the current edited, player script and a storage for the last successfully compiled
var ducks : Array
