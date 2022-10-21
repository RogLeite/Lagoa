extends Node2D
class_name Blast
# Enabled as tool to see effect in editor
tool

const MAX_RADIUS := 10.0
const MIN_RADIUS := 2.5
export var radius : float

var pond_state : State setget set_pond_state, get_pond_state

func _ready():
	radius = MAX_RADIUS
	pond_state = State.new(position)

func _draw():
	draw_circle(Vector2.ZERO, radius, Color.white)

func _process(_delta):
	update()

func play():
	$AnimationPlayer.play("blast")

func stop():
	$AnimationPlayer.stop(true)

func get_pond_state() -> State:
	pond_state.position = self.position
	return pond_state

func set_pond_state(p_state : State) -> void:
	self.position = p_state.position
	pond_state = p_state

class State extends JSONable:
	# var state : Dictionary setget _no_set, _no_get
	var position : Vector2

	func _init(p_position := Vector2.ZERO):
		position = p_position
	
	func to(blast : Blast = null) -> Dictionary:
		if blast:
			position = blast.position
		
		return {
			"position" : .vector2_to(position)
		}
		
	func from(from : Dictionary) -> JSONable:
		position = .vector2_from(from.position)
		return self

	func _to_string():
		return "Blast.State:{%s}"%position
