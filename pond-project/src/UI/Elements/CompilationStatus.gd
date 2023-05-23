extends HBoxContainer

signal verify_requested

const TEXT_STANDBY : String = "Aperte \"VERIFICAR\" para conferir se há erros de sintaxe."
const TEXT_OK : String = "Compilação bem sucedida."

onready var label := $PanelContainer/ScrollContainer/Label
onready var verify_button := $VerifyButton

func _ready():
	set_standby()

func set_standby() -> void:
	label.text = TEXT_STANDBY

func set_error(p_message : String) -> void:
	label.text = p_message
	
func set_ok() -> void:
	label.text = TEXT_OK
	
func set_disabled(p_value : bool) -> void:
	verify_button.set_disabled(p_value)

func _on_VerifyButton_pressed():
	emit_signal("verify_requested")
