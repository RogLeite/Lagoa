extends KinematicBody2D
class_name Duck

signal energy_changed(new_value)
signal tired(duck)

export var MAX_SPEED : int = 100
# Scan resolution in degrees
export var scan_resolution := 5.0

export var show_outline : bool setget set_show_outline, get_show_outline

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

var following_node : Node setget set_following_node

# [TODO] Define and use "color" for the duck
var color : Color = Color.white
var pond_state : State setget set_pond_state, get_pond_state

onready var projectile_max_distance : float = PROJECTILE_MAX_DISTANCE_FROM_BLOCKLY * CurrentVisualization.get_current().MAP_SCALE_FROM_BLOCKLY
onready var tire_mutex := Mutex.new()
onready var _base_modulate := modulate
onready var collision := $Collision
onready var follower := $Follower

func _ready():
	collision.shape.radius = COLLISION_CIRCLE_RADIUS
	# Sets metadata for collision
	set_meta("collider_type", "duck")
	pond_state = State.new(position, color, rotation, speed, energy)

func _physics_process(delta):
	if is_tired():
		return
	accelerate(delta)
	# Needs delta in calculations because move_and_collide doesn't use it automatically like move_and_slide does
	var velocity : Vector2 = Vector2(speed, 0).rotated(rotation) * delta
	var collision_result :=  move_and_collide(velocity, true, true, false)
	
	if not collision_result or not collision_result.collider:
		return
		
	match collision_result.collider.get_meta("collider_type"):
		"duck":
			if (speed!=0 or collision_result.collider.speed != 0):
				call_deferred("tire", COLLISION_DAMAGE_DUCK)
				# print("Collided with duck")
		"wall":
			if speed!=0:
				call_deferred("tire", COLLISION_DAMAGE_WALL)
				# print("Collided with wall")

func getX () -> float:
	return position.x / CurrentVisualization.get_current().MAP_SCALE_FROM_BLOCKLY

func getY () -> float:
	return position.y / CurrentVisualization.get_current().MAP_SCALE_FROM_BLOCKLY

func get_speed ():
	return speed
func set_speed (value):
	speed = clamp(value, 0, MAX_SPEED)
	
func set_speed_target (value):
	speed_target = clamp(value, 0, MAX_SPEED)
	
func set_energy(value : int) :
	energy = int(clamp(value, 0, MAX_ENERGY))
	emit_signal("energy_changed", energy)
	check_energy()
	
func set_can_launch(value : bool):
	can_launch = value

func set_show_outline(p_show_outline : bool) -> void:
	material.set_shader_param("enable", p_show_outline)
	
func get_show_outline() -> bool:
	return material.get_shader_param("enable")

func set_following_node( p_node : Node ) -> void:
	following_node = p_node
	
	if p_node == null:
		follower.remote_path = NodePath("")
		return
		
	var path = follower.get_path_to(p_node)
	follower.remote_path = path
	
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
	if speed < speed_target :
		self.speed = min(speed + ACCELERATION * delta, speed_target)
	elif speed > speed_target :
		self.speed = max(speed - ACCELERATION * delta, speed_target)

func check_energy():
	if energy == 0 :
		emergency_stop()
		collision.disabled = true
		modulate = Color(0.75,0.75,0.75,0.75)
		emit_signal("tired", self)
		call_deferred("set_physics_process", false)

func is_tired() -> bool :
	return energy == 0

func scan(duck_idx, angle):
	if is_tired():
		return INF
	var vis := CurrentVisualization.get_current()
	return vis.scan_field(duck_idx, angle, scan_resolution) / vis.MAP_SCALE_FROM_BLOCKLY

# Passes Projectile parameters to CurrentVisualization.get_current().add_projectile()
# Starts a cooldown timer for the launcher.
# @ param angle is in degrees
# returns true if launched a projectile
func launcher(angle, p_distance) -> bool:
	if is_tired() or not can_launch:
		return false

	can_launch = false
	var distance : float
	if p_distance is String:
		match p_distance.to_lower():
			"infinity":
				distance = INF
			_:
				distance = float(distance)
	else:
		distance = p_distance
	var vis = CurrentVisualization.get_current()
	var p_dist : float = clamp(distance, 0, PROJECTILE_MAX_DISTANCE_FROM_BLOCKLY) * vis.MAP_SCALE_FROM_BLOCKLY
	var p_color := Color.darkslategray
	var p_start_location := position
	var p_end_location := position+Vector2(p_dist,0).rotated(deg2rad(angle))
	
	vis.add_projectile(p_color, p_start_location, p_end_location, p_dist)
	# Starts a cooldown timer for can_launch
	# warning-ignore: return_value_discarded
	get_tree().create_timer(LAUNCHER_COOLDOWN).connect("timeout", self, "set_can_launch", [true])
	return true
		
func get_class() -> String :
	return "Duck"

func reset(pos : Vector2, angle : float):
	speed = 0
	speed_target = 0
	energy = MAX_ENERGY
	modulate = _base_modulate
	can_launch = true
	position = pos
	rotation = angle
	collision.disabled = false
	call_deferred("set_physics_process", true)

func get_pond_state() -> State:
	pond_state.position = self.position
	pond_state.color = self.color
	pond_state.rotation = self.rotation
	pond_state.speed = self.speed
	pond_state.energy = self.energy
	return pond_state

func set_pond_state(p_state : State) -> void:
	self.position = p_state.position
	self.color = p_state.color
	self.rotation = p_state.rotation
	self.speed = p_state.speed
	self.energy = p_state.energy
	pond_state = p_state

class State extends JSONable:
	# var state : Dictionary setget _no_set, _no_get
	var position : Vector2
	var color 	 : Color
	var rotation : float	# Radians
	var speed 	 : float 	# Velocity is calculated with rotation
	var energy 	 : int

	func _init(
			p_position := Vector2.ZERO,
			p_color := Color.white,
			p_rotation := 0.0,
			p_speed := 0.0,
			p_energy := 100):
		position = p_position
		color = p_color
		rotation = p_rotation
		speed = p_speed
		energy = p_energy
	
	func to(duck : Duck = null) -> Dictionary:
		if duck:
			position = duck.position
			color = duck.color
			rotation = duck.rotation
			speed = duck.speed
			energy = duck.energy
		
		return {
			"position" : .vector2_to(position),
			"color" : .color_to(color),
			"rotation" : rotation,
			"speed" : speed,
			"energy" : energy
		}
		
	func from(from : Dictionary) -> JSONable:
		position = .vector2_from(from.position)
		color = .color_from(from.color)
		rotation = from.rotation
		speed = from.speed
		energy = from.energy
		return self
