extends MenuList

const _main_single := "res://src/Main/MainSingle.tscn"
const _main_player_client := "res://src/Main/MainPlayer.tscn"
const _main_master_client := "res://src/Main/MainMaster.tscn"

# Popup messages
const _popup_msg_null_scene := "Não foi possível iniciar a cena escolhida: Cena é nula"
const _popup_msg_player_client := "Não foi possível iniciar a cena do Player Client"
const _popup_msg_master_client := "Não foi possível iniciar a cena do Master Client"


onready var modes_list := find_node("ModesList")
onready var ip_edit := $MarginContainer/ModesList/IP

func _ready():
	if ProjectSettings.get_setting("editor/manual_testing"):
		if RunArgs.has_arg(RunArgs.MASTER):
			call_deferred("change_to_master")
			return
		elif RunArgs.has_arg(RunArgs.PLAYER):
			call_deferred("change_to_player")
			return

	self.menu_current = modes_list
	ip_edit.text = ServerConnection.server_ip
	

func change_to_single() -> void:
	#warning-ignore: return_value_discarded
	get_tree().change_scene_to(load(_main_single))
	
func change_to_master() -> void:
	#warning-ignore: return_value_discarded
	get_tree().change_scene_to(load(_main_master_client))
	
func change_to_player() -> void:
	#warning-ignore: return_value_discarded
	get_tree().change_scene_to(load(_main_player_client))

func _unhandled_input(event : InputEvent):
	if event.is_action_pressed("ui_master_shortcut"):
		change_to_master()


func _on_ModesList_singleplayer_requested():
	change_to_single()

func _on_ModesList_multiplayer_requested():	
	change_to_player()

func _on_IP_text_changed(new_text):
	ServerConnection.server_ip = new_text
