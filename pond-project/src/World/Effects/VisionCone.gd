extends Polygon2D
class_name VisionCone

var pond_state : State setget set_pond_state, get_pond_state
var animation_position : float setget set_animation_position, get_animation_position
var scanner : int
var is_available : bool = true

onready var _animation_player := $AnimationPlayer

func _init(p_scanner: int = 0):
	scanner = p_scanner

func _ready():
	# warning-ignore:return_value_discarded
	_animation_player.connect("animation_finished", self, "_on_AnimationPlayer_animation_finished")
	reset()
	pond_state = State.new(position, rotation, scanner)

func _exit_tree():
	reset()
	_animation_player.disconnect("animation_finished", self, "_on_AnimationPlayer_animation_finished")
		
func play_animation(p_position : Vector2, p_rotation : float):
	is_available = false
	set_visible(true)
	if _animation_player.is_playing() \
		and _animation_player.current_animation_position != 0.0 :
		_animation_player.seek(0.0, true)
	position = p_position
	rotation = p_rotation
	_animation_player.play("fade")

func reset():
	is_available = true
	position = Vector2.ZERO
	rotation_degrees = 0
	set_visible(false)
	reset_animation()
	update()

func reset_animation() -> void:
	if not has_node("AnimationPlayer"):
		return
	
	if _animation_player.is_playing():
		_animation_player.stop(true)
	
	_animation_player.set_assigned_animation("fade")

func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "fade":
		reset()

func get_animation_position() -> float:
	return _animation_player.get_current_animation_position()
func set_animation_position(p_animation_position : float):
	_animation_player.seek(p_animation_position, true)

func get_pond_state() -> State:
	pond_state.position = self.position
	pond_state.rotation = self.rotation
	pond_state.scanner = self.scanner
	pond_state.animation_position = self.animation_position
	pond_state.visible = self.visible
	return pond_state

func set_pond_state(p_state : State) -> void:
	self.position = p_state.position
	self.rotation = p_state.rotation
	self.scanner = p_state.scanner
	self.animation_position = p_state.animation_position
	self.visible = p_state.visible
	pond_state = p_state

class State extends JSONable:

	var position : Vector2
	var rotation : float	# Radians
	var scanner : int
	var animation_position : float
	var visible : bool

	func _init(
			p_position := Vector2.ZERO,
			p_rotation := 0.0,
			p_scanner := 0,
			p_animation_position := 0.0,
			p_visible := false):
		position = p_position
		rotation = p_rotation
		scanner = p_scanner
		animation_position = p_animation_position
		visible = p_visible
	
	func to(vision_cone : VisionCone = null) -> Dictionary:
		if vision_cone:
			position = vision_cone.position
			rotation = vision_cone.rotation
			scanner = vision_cone.scanner
			animation_position = vision_cone.animation_position
			visible = vision_cone.visible
		
		return {
			"position" : .vector2_to(position),
			"rotation" : rotation,
			"scanner" : scanner,
			"animation_position" : animation_position,
			"visible" : visible
		}
		
	func from(from : Dictionary) -> JSONable:
		position = .vector2_from(from.position)
		rotation = from.rotation
		scanner = from.scanner
		animation_position = from.animation_position
		visible = from.visible
		return self

	func _to_string():
		return "VisionCone.State< position = %s, rotation = %s, scanner = %s, animation_position = %s, visible = %s >"%[position, rotation, scanner, animation_position, visible]
