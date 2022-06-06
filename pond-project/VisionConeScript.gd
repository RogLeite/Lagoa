extends Polygon2D


func _exit_tree():
	if has_node("AnimationPlayer") and $AnimationPlayer.is_playing():
		$AnimationPlayer.stop()
	
func set_angular_width(angle):
	polygon[1] = Vector2(1000,0).rotated(angle/2)
	polygon[2] = Vector2(1000,0).rotated(-angle/2)

func play_animation():
	$AnimationPlayer.play("fade")

func stop():
	$AnimationPlayer.stop()
