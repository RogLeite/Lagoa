extends Node

var _main_state := "initial"

onready var pond_match := $PondMatch

func _ready():
	call_deferred("reset")

func reset():
	_main_state = "reset"
	pond_match.reset_pond_match()
	# For now, immediatelly skips to "elapse
	call_deferred("elapse")
	
func prepare() -> void:
	_main_state = "prepare"
	# [TODO] Add scripts in PondMatch for the AI
	pass
	
func elapse() -> void:
	_main_state = "elapse"
	pond_match.show()

func start() -> void:
	_main_state = "start"
	pond_match.run()

func result() -> void:
	_main_state = "result"
	pond_match.reset_pond_match()

func _on_PondMatch_match_reset_requested():
	call_deferred("result")

func _on_PondMatch_match_run_requested():
	call_deferred("start")

func _on_PondMatch_match_step_requested():
	pond_match.pond_script_step()
