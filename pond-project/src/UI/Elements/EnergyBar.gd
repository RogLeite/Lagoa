extends Control
class_name EnergyBar

# Facilitates changes to the tint of the bar and it's tooltip
export var text : String = "Label" setget set_text, get_text

func _ready():
	self.text = text
	set_energy(100)

func set_energy(value : int):
	$Bar.value = value

func set_text(string : String) : 
	text = string
	if has_node("Label"):
		$Label.text = string
func get_text() -> String : 
	if has_node("Label"):
		return $Label.text
	else:
		return text
