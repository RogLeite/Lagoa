extends Node

const main_single := "res://src/Main/MainSingle.tscn"
const main_player_client := "res://src/Main/MainPlayerClient.tscn"

onready var warning_popup := $ModeSelection/WarningPopup
onready var buttons_container := $ModeSelection/Buttons

func _on_SingleplayerButton_pressed():
	#warning-ignore: return_value_discarded
	get_tree().change_scene_to(load(main_single))

func _on_MultiplayerButton_pressed():
	var scene := load(main_player_client)
	if scene == null: 
		warning_popup.popup()
		return
	
	var result := get_tree().change_scene_to(scene)
	if result == ERR_CANT_CREATE:
		warning_popup.popup()


func _on_WarningPopup_about_to_show():
	buttons_container.visible = false


func _on_WarningPopup_popup_hide():
	buttons_container.visible = true
