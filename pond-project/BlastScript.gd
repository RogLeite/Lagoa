extends Node2D
tool

const MAX_RADIUS := 10.0
const MIN_RADIUS := 2.5
export var radius : float

func _ready():
	radius = MAX_RADIUS

func _draw():
	draw_circle(Vector2.ZERO, radius, Color.white)

func _process(_delta):
	update()

func play():
	$AnimationPlayer.play("blast")

func stop():
	$AnimationPlayer.stop(true)
