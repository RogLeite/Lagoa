extends KinematicBody2D
# class_name Duck

export var max_speed : int = 100

# Only speed, because velocity encodes the direction.
# 	get_speed will be used as a method registered to Lua
var speed : float = 0 setget set_speed, get_speed
# Used to check if the duck is swimming
var speed_target : float = 0 setget set_speed_target
# [TODO] Experiment with the acceleration that feels right
var acceleration : float = 20

func get_speed ():
	return speed;
func set_speed (value):
	speed = clamp(value, 0, 100);

func get_speed_target ():
	return speed_target;
func set_speed_target (value):
	speed_target = clamp(value, 0, 100);


# Target is optional. If omitted, defaults to 50 (half the maximum speed)
func swim (angle, target) -> void :

	self.speed_target = 50.0 if target == null else target
	rotation_degrees = angle

	if speed == 0 and speed_target > 0 :
	# If starting, bump the speed immediately so that avatars can see a change.
		speed = 0.1


func stop () -> void :
	speed_target = 0

func accelerate(delta) :
	# [TODO] Implement acceleration
	if speed != speed_target:
		self.speed = speed_target + delta * 0

func _physics_process(delta):
	accelerate(delta)

	var velocity : Vector2 = Vector2(speed, 0).rotated(rotation)
	velocity = move_and_slide(velocity)
