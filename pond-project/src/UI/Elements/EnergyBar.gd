extends Control
class_name EnergyBar

signal pressed

# Facilitates changes to the tint of the bar and it's tooltip
onready var bottom_child := $Button
export var text : String = "Label" setget set_text, get_text

func _ready():
	self.text = text
	set_energy(100)

func _entered():
	#print("Entered")
	bottom_child.modulate = Color(0.9, 0.9, 0.9, 0.4)
func _exited():
	#print("Exited")
	bottom_child.modulate = Color(0.9, 0.9, 0.9, 0)

func _pressed():
	set_energy($Bar.value - 1) # [TODO] Remove this line after testing
	emit_signal("pressed")

func set_energy(value : int):
	bottom_child.hint_tooltip = self.text + ": %d"%value
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
