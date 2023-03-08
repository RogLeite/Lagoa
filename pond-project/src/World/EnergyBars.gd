extends GridContainer

var _bars : Array

func _ready():
	_bars = [$EnergyBar0, $EnergyBar1, $EnergyBar2, $EnergyBar3]
	#warning-ignore: return_value_discarded
	PlayerData.connect("player_joined", self, "_on_PlayerData_player_joined")
	#warning-ignore: return_value_discarded
	PlayerData.connect("player_left", self, "_on_PlayerData_player_left")
	setup()

func _exit_tree():
	PlayerData.disconnect("player_joined", self, "_on_PlayerData_player_joined")
	PlayerData.disconnect("player_left", self, "_on_PlayerData_player_left")

func setup() -> void:	
	for i in _bars.size():
		_bars[i].set_visible(PlayerData.is_present(i))
	
	var present := PlayerData.present_count()
	match present:
		1,2,3:
			self.columns = present
		4:
			self.columns = 2

func _on_PlayerData_player_joined(_p_index : int):
	setup()
	
func _on_PlayerData_player_left(_p_index : int):
	setup()
