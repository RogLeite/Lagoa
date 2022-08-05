extends KinematicBody2D
class_name Duck

signal energy_changed(new_value)

export var max_speed : int = 100
# Scan resolution in degrees
export var scan_resolution := 5.0

const ACCELERATION : float = 300.0
const MAX_ENERGY : int = 100
const COLLISION_CIRCLE_RADIUS : float = 10.0
const COLLISION_DAMAGE_DUCK : int = 3
const COLLISION_DAMAGE_WALL : int = 1
const PROJECTILE_MAX_DISTANCE_FROM_BLOCKLY : float = 70.0
const LAUNCHER_COOLDOWN : float = 0.5

# Only speed, because velocity encodes the direction.
# 	get_speed will be used as a method registered to Lua
var speed : float = 0 setget set_speed, get_speed
# Used to check if the duck is swimming
var speed_target : float = 0 setget set_speed_target

var energy : int = MAX_ENERGY setget set_energy

var can_launch : bool = true setget set_can_launch

onready var projectile_max_distance : float = PROJECTILE_MAX_DISTANCE_FROM_BLOCKLY * CurrentVisualization.get_current().MAP_SCALE_FROM_BLOCKLY
onready var projectile_scene := preload("res://Projectile.tscn")
onready var tire_mutex := Mutex.new()

func _ready():
	$Collision.shape.radius = COLLISION_CIRCLE_RADIUS
	# Sets metadata for collision
	set_meta("collider_type", "duck")

func _physics_process(delta):
	if is_tired():
		return
	accelerate(delta)
	# Needs delta in calculations because move_and_collide doesn't use it
	# automatically like move_and_slide does
	var velocity : Vector2 = Vector2(speed, 0).rotated(rotation) * delta
	var collision :=  move_and_collide(velocity, true, true, false)
	
	# [TODO] better check to see if should check the collision (even if stopped, the ducks keep colliding)
	#   maybe a move on both parties so they get out of collision range?
	if collision and collision.collider:
		match collision.collider.get_meta("collider_type"):
			"duck":
				if (speed!=0 and collision.collider.speed != 0):
					call_deferred("tire", COLLISION_DAMAGE_DUCK)
					call_deferred("emergency_stop")
					# print("Collided with duck")
			"wall":
				if speed!=0:
					call_deferred("tire", COLLISION_DAMAGE_WALL)
					call_deferred("emergency_stop")
					# print("Collided with wall")

func get_speed ():
	return speed;
func set_speed (value):
	speed = clamp(value, 0, 100);
	
func set_speed_target (value):
	speed_target = clamp(value, 0, 100)
	
func set_energy(value : int) :
	energy = int(clamp(value, 0, 100))
	emit_signal("energy_changed", energy)
	check_energy()
	
func set_can_launch(value : bool):
	can_launch = value
	
func tire(value : int) :
	tire_mutex.lock()
	self.energy = energy - value
	tire_mutex.unlock()


# Target is optional. If omitted, defaults to 50 (half the maximum speed)
func swim (angle, target) -> void :

	self.speed_target = 50.0 if target == null else target
	rotation_degrees = angle

	if speed == 0 and speed_target > 0 :
	# If starting, bump the speed immediately so that avatars can see a change.
		speed = 0.1

func stop () -> void :
	speed_target = 0
	
func emergency_stop() -> void :
	stop()
	self.speed = 0

func accelerate(delta) :
	if speed != speed_target:
		if speed < speed_target :
			self.speed = min(speed + ACCELERATION * delta, speed_target)
		elif speed > speed_target :
			self.speed = max(speed - ACCELERATION * delta, speed_target)

func check_energy():
	if energy == 0 :
		emergency_stop()
		$Collision.disabled = true
		modulate = Color(0.75,0.75,0.75,0.75)
		set_physics_process(false)

func is_tired() -> bool :
	return energy == 0

func scan(duck_idx, angle):
	return CurrentVisualization.get_current().scan_field(duck_idx, angle, scan_resolution)

# Create a new insatnce of Projectile, configure it, then call CurrentVisualization.get_current().add_projectile()
# angle is in degrees
func launcher(angle, distance):
	if can_launch:
		can_launch = false
		var dist = clamp(distance, 0, projectile_max_distance)
		var projectile := projectile_scene.instance()
		# [TODO] Consider if any calculation should be delegated to Projectile
		projectile.angle_launched = deg2rad(angle)
		projectile.color = Color.darkslategray
		projectile.startLoc = position
		projectile.endLoc = position+Vector2(dist,0).rotated(deg2rad(angle))
		
		CurrentVisualization.get_current().add_projectile(projectile)
		# Starts a cooldown timer for can_launch
		var _err = get_tree().create_timer(LAUNCHER_COOLDOWN).connect("timeout", self, "set_can_launch", [true])
		
func get_class() -> String :
	return "Duck"

func reset(pos : Vector2, angle : float):
	speed = 0
	speed_target = 0
	self.energy = MAX_ENERGY
	can_launch = true
	position = pos
	rotation = angle
