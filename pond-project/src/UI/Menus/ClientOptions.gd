extends Menu

signal main_player_requested ()
signal main_master_requested ()
signal go_back_requested ()


func _on_PlayerClientButton_pressed():
	emit_signal("main_player_requested")


func _on_MasterClientButton_pressed():
	emit_signal("main_master_requested")


func _on_BackButton_pressed():
	emit_signal("go_back_requested")
