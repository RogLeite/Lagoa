extends Node2D
class_name Projectile
tool

# Signals that the projectile arrived to it's destination
signal arrived(position)

const PROJECTILE_RADIUS := 5.0
const PROJECTILE_SPEED := 480.0

# export
# To be set as the avatar color
var color := Color.white setget set_color
var shadow_color := Color.white
var startLoc := Vector2.ZERO
var endLoc := Vector2.ZERO
# Should be in radians
var angle_launched : float = 0.0
# How far the projectile will land 
# In blockly-games' code, `distance` is called `range` 
var distance := 280.0
# Projectile progress in absolute distance
var progress := 0.0
# Projectile progress normalized between 0.0 and 1.0
var normal_progress := 0.0

# var _

func _ready():
	if Engine.editor_hint :
		set_physics_process(false)

func _draw():
	var dx = (endLoc.x - startLoc.x) * normal_progress
	var dy = (endLoc.y - startLoc.y) * normal_progress # [TODO] May need to invert progress, this line may be overcompensating for the coordinates
	#  Calculate parabolic arc.
	var halfRange = distance / 2
	var height = distance * 0.15  # Change to set height of arc (original was 0.15).
	var xAxis = progress - halfRange
	var parabola = height - pow(xAxis / sqrt(height) * height / halfRange, 2)
	#Calvulate on canvas coordinates
	var projectileX = startLoc.x + dx
	var projectileY = startLoc.y + dy + parabola
	var shadowY = startLoc.y + dy
	draw_circle(Vector2(projectileX, shadowY), max(0.2, 1 - parabola / 100) * PROJECTILE_RADIUS, shadow_color)
	draw_circle(Vector2(projectileX, projectileY), PROJECTILE_RADIUS,	color)
	
#	draw_circle(Vector2.ZERO, PROJECTILE_RADIUS/2, Color.red)

func _process(_delta):
	update()

func _physics_process(delta):
	progress = min(progress+PROJECTILE_SPEED*delta, distance)
	normal_progress = progress / distance
	if progress == distance :
		emit_signal("arrived", endLoc)
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
