extends Node


onready var pond_match := $PondMatch

func _ready():
	call_deferred("reset")

func reset():
	pond_match.reset_pond_match()
	# For now, immediatelly skips to "elapse
	call_deferred("elapse")
	
func prepare() -> void:
	# [TODO] Add scripts in PondMatch for the AI
	pass
	
func elapse() -> void:
	pond_match.show()

func start() -> void:
	pond_match.run()

func result() -> void:
	pond_match.reset_pond_match()

func _on_PondMatch_match_reset_requested():
	call_deferred("result")

func _on_PondMatch_match_run_requested():
	call_deferred("start")

func _on_PondMatch_match_step_requested():
	pond_match.script_step()
