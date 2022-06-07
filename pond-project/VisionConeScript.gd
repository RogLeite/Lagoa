extends Polygon2D

onready var _animation_player := $AnimationPlayer
	
func _exit_tree():
	if has_node("AnimationPlayer") and _animation_player.is_playing():
		_animation_player.stop()
		
func play_animation(from : Vector2, angle : float):
	if _animation_player.is_playing() \
		and _animation_player.current_animation_position != 0.0 :
		_animation_player.seek(0.0, true)
	rotation = angle
	position = from
	_animation_player.play("fade")


func reset():
	_animation_player.stop(true)
	position = Vector2.ZERO
	rotation_degrees = 0
