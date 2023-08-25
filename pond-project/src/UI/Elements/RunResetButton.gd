extends Button
class_name RunResetButton

signal run
signal reset

export(String , "run", "reset") var current_role = "run" setget swap_role
export var run_text : String = "run"

func _pressed():
	if current_role == "run" :
		emit_signal("run")
	elif current_role == "reset" :
		emit_signal("reset")

func swap_role(role):
	if role.to_lower() == "run":
		to_run()
	elif role.to_lower() == "reset":
		to_reset()
	
func to_run():
	text = run_text
	current_role = "run"
func to_reset():
	text = "Parar"
	current_role = "reset"
