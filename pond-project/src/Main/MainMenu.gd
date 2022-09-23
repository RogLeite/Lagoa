extends MenuList

const _main_single := "res://src/Main/MainSingle.tscn"
const _main_player_client := "res://src/Main/MainPlayer.tscn"
const _main_master_client := "res://src/Main/MainMaster.tscn"

# Popup messages
const _popup_msg_null_scene := "Não foi possível iniciar a cena escolhida: Cena é nula"
const _popup_msg_player_client := "Não foi possível iniciar a cena do Player Client"
const _popup_msg_master_client := "Não foi possível iniciar a cena do Master Client"


onready var modes_list := $ModesList
onready var client_options := $ClientOptions

func _ready():
	self.menu_current = modes_list


func _on_ModesList_singleplayer_requested():
	#warning-ignore: return_value_discarded
	get_tree().change_scene_to(load(_main_single))


func _on_ModesList_multiplayer_requested():
	self.menu_current = client_options


func _on_ClientOptions_main_player_requested():
	#warning-ignore: return_value_discarded
	get_tree().change_scene_to(load(_main_player_client))


func _on_ClientOptions_main_master_requested():
	#warning-ignore: return_value_discarded
	get_tree().change_scene_to(load(_main_master_client))


func _on_ClientOptions_go_back_requested():
	self.menu_current = modes_list
