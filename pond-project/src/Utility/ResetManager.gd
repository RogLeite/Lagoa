extends Node
class_name ResetManager


var _managed : Node
var _reset_requested : bool = false

func _ready():
	#warning-ignore: return_value_discarded
	get_parent().connect("ready", self, "_on_Parent_ready", [], CONNECT_ONESHOT)

func _on_Parent_ready() -> void:
	_managed = get_parent()

func reset_requested() -> void:
	if not _managed or _reset_requested:
		return
	_managed.call_deferred("_reset")
	_reset_requested = true
	set_deferred("_reset_requested", false)

func _exit_tree():
	_managed = null
