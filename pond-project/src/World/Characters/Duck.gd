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

# [TODO] Initialize and use "player"
var player : int = -1
# [TODO] Define and use "color" for the duck
var color : Color = Color.white
var pond_state : State setget set_pond_state, get_pond_state

onready var projectile_max_distance : float = PROJECTILE_MAX_DISTANCE_FROM_BLOCKLY * CurrentVisualization.get_current().MAP_SCALE_FROM_BLOCKLY
onready var tire_mutex := Mutex.new()
onready var _base_modulate := modulate
onready var collision := $Collision

func _ready():
	collision.shape.radius = COLLISION_CIRCLE_RADIUS
	# Sets metadata for collision
	set_meta("collider_type", "duck")
	pond_state = State.new(position, color, rotation, speed, player, energy)

func _physics_process(delta):
	if is_tired():
		return
	accelerate(delta)
	# Needs delta in calculations because move_and_collide doesn't use it
	# automatically like move_and_slide does
	var velocity : Vector2 = Vector2(speed, 0).rotated(rotation) * delta
	var collision_result :=  move_and_collide(velocity, true, true, false)
	
	# [TODO] better check to see if should check the collision_result (even if stopped, the ducks keep colliding)
	#   maybe a move on both parties so they get out of collision_result range?
	if collision_result and collision_result.collider:
		match collision_result.collider.get_meta("collider_type"):
			"duck":
				if (speed!=0 and collision_result.collider.speed != 0):
					call_deferred("tire", COLLISION_DAMAGE_DUCK)
					call_deferred("emergency_stop")
					# print("Collided with duck")
			"wall":
				if speed!=0:
					call_deferred("tire", COLLISION_DAMAGE_WALL)
					call_deferred("emergency_stop")
					# print("Collided with wall")

func get_speed ():
	return speed
func set_speed (value):
	speed = clamp(value, 0, 100)
	
func set_speed_target (value):
	speed_target = clamp(value, 0, 100)
	
func set_energy(value : int) :
	energy = int(clamp(value, 0, 100))
	emit_signal("energy_changed", energy)
	check_energy()
	
func set_can_launch(value : bool):
	can_launch = value

func set_participating(p_participating : bool) -> void:
	self.visible = p_participating
	collision.disabled = not p_participating
	
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

# Passes Projectile parameters to CurrentVisualization.get_current().add_projectile()
# Starts a cooldown timer for the launcher.
# @ param angle is in degrees
func launcher(angle, distance):
	if can_launch:
		can_launch = false
		var p_dist := clamp(distance, 0, projectile_max_distance)
		var p_color := Color.darkslategray
		var p_start_location := position
		var p_end_location := position+Vector2(p_dist,0).rotated(deg2rad(angle))
		
		CurrentVisualization.get_current().add_projectile(p_color, p_start_location, p_end_location, p_dist)
		# Starts a cooldown timer for can_launch
		# warning-ignore: return_value_discarded
		get_tree().create_timer(LAUNCHER_COOLDOWN).connect("timeout", self, "set_can_launch", [true])
		
func get_class() -> String :
	return "Duck"

func reset(pos : Vector2, angle : float):
	speed = 0
	speed_target = 0
	self.energy = MAX_ENERGY
	modulate = _base_modulate
	can_launch = true
	position = pos
	rotation = angle

func get_pond_state() -> State:
	pond_state.position = self.position
	pond_state.color = self.color
	pond_state.rotation = self.rotation
	pond_state.speed = self.speed
	pond_state.player = self.player
	pond_state.energy = self.energy
	return pond_state

func set_pond_state(p_state : State) -> void:
	self.position = p_state.position
	self.color = p_state.color
	self.rotation = p_state.rotation
	self.speed = p_state.speed
	self.player = p_state.player
	self.energy = p_state.energy
	pond_state = p_state

class State extends JSONable:
	# var state : Dictionary setget _no_set, _no_get
	var position : Vector2
	var color 	 : Color
	var rotation : float	# Radians
	var speed 	 : float 	# Velocity is calculated with rotation
	var player 	 : int
	var energy 	 : int

	func _init(
			p_position := Vector2.ZERO,
			p_color := Color.white,
			p_rotation := 0.0,
			p_speed := 0.0,
			p_player := -1,
			p_energy := 100):
		position = p_position
		color = p_color
		rotation = p_rotation
		speed = p_speed
		player = p_player
		energy = p_energy
	
	func to(duck : Duck = null) -> Dictionary:
		if duck:
			position = duck.position
			color = duck.color
			rotation = duck.rotation
			speed = duck.speed
			player = duck.player
			energy = duck.energy
		
		return {
			"position" : .vector2_to(position),
			"color" : .color_to(color),
			"rotation" : rotation,
			"speed" : speed,
			"player" : player,
			"energy" : energy
		}
		
	func from(from : Dictionary) -> JSONable:
		position = .vector2_from(from.position)
		color = .color_from(from.color)
		rotation = from.rotation
		speed = from.speed
		player = from.player
		energy = from.energy
		return self
