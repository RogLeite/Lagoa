extends Popup

signal confirmed(p_affirmative)

export var hide_on_confirmation : bool = true

func _ready():
	call_deferred("popup_centered_minsize")

func _on_Yes_pressed():
	emit_signal("confirmed", true)
	set_visible(not hide_on_confirmation)


func _on_No_pressed():
	emit_signal("confirmed", false)
	set_visible(not hide_on_confirmation)
