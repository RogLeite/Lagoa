extends Node

const _main_single := "res://src/Main/MainSingle.tscn"
const _main_player_client := "res://src/Main/MainPlayer.tscn"
const _main_master_client := "res://src/Main/MainMaster.tscn"

# Popup messages
const _popup_msg_null_scene := "Não foi possível iniciar a cena escolhida: Cena é nula"
const _popup_msg_player_client := "Não foi possível iniciar a cena do Player Client"
const _popup_msg_master_client := "Não foi possível iniciar a cena do Master Client"


onready var _warning_popup := $ModeSelection/WarningPopup
onready var _mode_buttons_container := $ModeSelection/ModeButtons
onready var _client_buttons_container := $ModeSelection/ClientButtons

func _on_SingleplayerButton_pressed():
	#warning-ignore: return_value_discarded
	get_tree().change_scene_to(load(_main_single))

func _on_MultiplayerButton_pressed():
	_mode_buttons_container.hide()
	_client_buttons_container.show()


func _on_PlayerClientButton_pressed():
	var scene := load(_main_player_client)
	_try_change_scene(scene, _popup_msg_player_client)


func _on_MasterClientButton_pressed():
	var scene := load(_main_master_client)
	_try_change_scene(scene, _popup_msg_master_client)


func _on_WarningPopup_about_to_show():
	_mode_buttons_container.hide()
	_client_buttons_container.hide()


func _on_WarningPopup_popup_hide():
	_mode_buttons_container.show()
	_client_buttons_container.hide()


func _try_change_scene(scene, msg) -> void :
	if scene == null:
		_warning_popup.set_text(_popup_msg_null_scene) 
		_warning_popup.popup()
		return
	
	var result := get_tree().change_scene_to(scene)
	if result == ERR_CANT_CREATE:
		_warning_popup.set_text(msg) 
		_warning_popup.popup()

	
