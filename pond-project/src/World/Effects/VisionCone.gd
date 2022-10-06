extends Polygon2D
class_name VisionCone

var pond_state : State setget set_pond_state, get_pond_state
var scanner : int

onready var _animation_player := $AnimationPlayer

func _init(p_scanner: int = 0):
	scanner = p_scanner

func _ready():
	pond_state = State.new(position, rotation, scanner)

func _exit_tree():
	if has_node("AnimationPlayer") and _animation_player.is_playing():
		_animation_player.stop()
		
func play_animation(p_position : Vector2, p_rotation : float):
	if _animation_player.is_playing() \
		and _animation_player.current_animation_position != 0.0 :
		_animation_player.seek(0.0, true)
	position = p_position
	rotation = p_rotation
	_animation_player.play("fade")

func reset():
	_animation_player.stop(true)
	position = Vector2.ZERO
	rotation_degrees = 0

func get_pond_state() -> State:
	pond_state.position = self.position
	pond_state.rotation = self.rotation
	pond_state.scanner = self.scanner
	return pond_state

func set_pond_state(p_state : State) -> void:
	self.position = p_state.position
	self.rotation = p_state.rotation
	self.scanner = p_state.scanner
	pond_state = p_state

class State extends JSONable:
	# var state : Dictionary setget _no_set, _no_get
	var position : Vector2
	var rotation : float	# Radians
	var scanner : int

	func _init(
			p_position := Vector2.ZERO,
			p_rotation := 0.0,
			p_scanner := 0):
		position = p_position
		rotation = p_rotation
		scanner = p_scanner
	
	func to(vision_cone : VisionCone = null) -> Dictionary:
		if vision_cone:
			position = vision_cone.position
			rotation = vision_cone.rotation
			scanner = vision_cone.scanner
		
		return {
			"position" : .vector2_to(position),
			"rotation" : rotation,
			"scanner" : scanner
		}
		
	func from(from : Dictionary) -> JSONable:
		position = .vector2_from(from.position)
		rotation = from.rotation
		scanner = from.scanner
		return self
