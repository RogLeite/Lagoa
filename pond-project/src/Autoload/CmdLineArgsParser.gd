extends Node

# The keys to consider when parsing
const MANUAL_TEST := "manual_test"
const KEYS : Array = [MANUAL_TEST]

# Dictionary with every parsed key=value pair
var arguments := {}
				
func _init():
	for argument in OS.get_cmdline_args():
		if argument.find("=") > -1:
			var key_value = argument.split("=")
			var key : String = key_value[0].lstrip("--") 
			if key in KEYS:
				arguments[key] = key_value[1]
		else:
			# Options without an argument will be present in the dictionary,
			# with the value set to an empty string.
			var key : String = argument.lstrip("--")
			if key in KEYS:
				arguments[key] = ""
