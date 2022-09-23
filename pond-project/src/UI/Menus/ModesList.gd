extends Menu

signal singleplayer_requested()
signal multiplayer_requested()


func _on_SingleplayerButton_pressed():
	emit_signal("singleplayer_requested")


func _on_MultiplayerButton_pressed():
	emit_signal("multiplayer_requested")
