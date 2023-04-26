extends Popup

signal confirmed(p_affirmative)

const base_text : String = "%s\nVENCEU!!!"

export var hide_on_confirmation : bool = true

var winner : String = "<Jogador>" setget set_winner

func set_winner( p_winner : String ):
	winner = p_winner
	$Panel/Winner.text = base_text%winner

func _on_Continue_pressed():
	emit_signal("confirmed", true)
	set_visible(not hide_on_confirmation)
