tool
extends Control
class_name EnergyBar

export var text : String = "<no text>" setget set_text, get_text
# Facilitates changes to the tint of the bar and it's tooltip
export var theme_override : StyleBoxFlat setget set_theme_override, get_theme_override

func _ready():
	self.text = text
	set_energy(100)
	apply_theme_override()

func set_energy(value : int):
	$Bar.value = value

func reset() -> void:
	set_energy(100)

func set_text(string : String) : 
	text = string
	if has_node("Label"):
		$Label.text = text
func get_text() -> String : 
	if has_node("Label"):
		return $Label.text
	else:
		return text
		
func set_theme_override(p_style: StyleBoxFlat) -> void:
	theme_override = p_style

func get_theme_override() -> StyleBoxFlat:
	return theme_override

func apply_theme_override() -> void:
	$Bar.add_stylebox_override("fg", theme_override)
