extends Node2D
class_name Projectile
# Enable to see effect in editor
tool

# Signals that the projectile arrived to it's destination
signal arrived(position)

const PROJECTILE_RADIUS := 5.0
const PROJECTILE_SPEED := 480.0

# export

# To be set as the avatar color
var color := Color.white setget set_color
var shadow_color := Color.white
var start_location := Vector2.ZERO
var end_location := Vector2.ZERO
# Should be in radians
var angle_launched : float = 0.0
# How far the projectile will land 
# In blockly-games' code, `distance` is called `range` 
var distance := 280.0
# Projectile progress in absolute distance
var progress := 0.0
# Projectile progress normalized between 0.0 and 1.0
var normal_progress := 0.0

var pond_state : State setget set_pond_state, get_pond_state

# var _

func _ready():
	if Engine.editor_hint :
		set_physics_process(false)
	pond_state = State.new(color, start_location, end_location, progress, distance)

func _draw():
	var dx = (end_location.x - start_location.x) * normal_progress
	var dy = (end_location.y - start_location.y) * normal_progress # [TODO] May need to invert progress, this line may be overcompensating for the coordinates
	#  Calculate parabolic arc.
	var halfRange = distance / 2
	var height = distance * 0.15  # Change to set height of arc (original was 0.15).
	var xAxis = progress - halfRange
	var parabola = height - pow(xAxis / sqrt(height) * height / halfRange, 2)
	#Calvulate on canvas coordinates
	var projectileX = start_location.x + dx
	var projectileY = start_location.y + dy + parabola
	var shadowY = start_location.y + dy
	draw_circle(Vector2(projectileX, shadowY), max(0.2, 1 - parabola / 100) * PROJECTILE_RADIUS, shadow_color)
	draw_circle(Vector2(projectileX, projectileY), PROJECTILE_RADIUS,	color)
	
#	draw_circle(Vector2.ZERO, PROJECTILE_RADIUS/2, Color.red)

func _process(_delta):
	update()

func _physics_process(delta):
	progress = min(progress+PROJECTILE_SPEED*delta, distance)
	normal_progress = progress / distance
	if progress == distance :
		emit_signal("arrived", end_location)
		queue_free()

func get_class() -> String :
	return "Projectile"

# Sets the color as new_color, but always sets the alpha channel as 1.0
func set_color(new_color : Color) :
	color = new_color
	color.a = 1.0
	shadow_color = color
	shadow_color.a = 0.5
	
func stop():
	set_physics_process(false)

func get_pond_state() -> State:
	pond_state.color = self.color
	pond_state.start_location = self.start_location
	pond_state.end_location = self.end_location
	pond_state.progress = self.progress
	pond_state.distance = self.distance
	return pond_state

func set_pond_state(p_state : State) -> void:
	self.color = p_state.color
	self.start_location = p_state.start_location
	self.end_location = p_state.end_location
	self.progress = p_state.progress
	self.distance = p_state.distance
	pond_state = p_state

class State extends JSONable:
	# var state : Dictionary setget _no_set, _no_get
	var color			: Color
	var start_location	: Vector2
	var end_location	: Vector2
	var progress		: float
	var distance		: float

	func _init(
			p_color := Color.white,
			p_start_location := Vector2.ZERO,
			p_end_location := Vector2.ZERO,
			p_progress := 0.0,
			p_distance := 0.0):
		color = p_color
		start_location = p_start_location
		end_location = p_end_location
		progress = p_progress
		distance = p_distance
	
	func to(projectile : Projectile = null) -> Dictionary:
		if projectile:
			color = projectile.color
			start_location = projectile.start_location
			end_location = projectile.end_location
			progress = projectile.progress
			distance = projectile.distance
		
		return {
			"color" : .color_to(color),
			"start_location" : .vector2_to(start_location),
			"end_location" : .vector2_to(end_location),
			"progress" : progress,
			"distance" : distance
		}
		
	func from(from : Dictionary) -> JSONable:
		color = .color_from(from.color)
		start_location = .vector2_from(from.start_location)
		end_location = .vector2_from(from.end_location)
		progress = from.progress
		distance = from.distance
		return self
