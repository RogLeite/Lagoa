extends Node2D

# [TODO] Either programatically instanciate ducks, allowing variable quantities;
# or manually Build extensions of PondVisualization for each player count.
# export var duck_amount := 1

# How many time bigger is the scale of this map versus the 100x100 map from blocly-games' pond
const MAP_SCALE_FROM_BLOCKLY : float = 4.0

onready var vision_cone_scene := preload("res://VisionCone.tscn")
onready var boom_player_scene := preload("res://BoomPlayer.tscn")
onready var blast_scene := preload("res://Blast.tscn")
onready var splash_player_scene := preload("res://SplashPlayer.tscn")

func _enter_tree():
	# Sets itself as the current visualization
	CurrentVisualization.set_current(self)

func _ready() -> void:
	var ducks := [$Duck0.get_path(), $Duck1.get_path()]
	PlayerData.ducks = ducks
	# Sets collision metadata for the walls
	$PondEdges.set_meta("collider_type", "wall")


func _physics_process(_delta):
	$Debugger/Label.text = "Duck0 speed = %f\nDuck1 speed = %f"%[$Duck0.speed,$Duck1.speed]

# If the center of a duck is visible, returns distance to it. Else returns INF
func scan_field(scanner : int, angle, angular_resolution) -> float:
	# [TODO] Consider if thread protection with mutexes is needed
	var ducks := PlayerData.get_ducks_as_nodes()
	var start : Vector2 = ducks[scanner].position
	var scanning_to := Vector2(1,0).rotated(deg2rad(angle)).normalized()
	var best_distance := INF
	
	for i in ducks.size():
		if i == scanner :
			continue
		# Position to other duck
		var target_pos : Vector2 = ducks[i].position
		var direction_to = start.direction_to(target_pos)
		var angular_dist := abs(scanning_to.angle_to(direction_to))
		#print("In scan angular_dist found: %f"%angular_dist)
		# Checks if the angle to the other duck is within tolerance
		#print("In scan conversion of half angular resolution to rad: %f"%deg2rad(angular_resolution/2))
		if angular_dist <= deg2rad(angular_resolution/2) :
			var dist := start.distance_to(target_pos)
			if dist < best_distance:
				# Updates best distance
				best_distance = dist

	draw_scan(start, deg2rad(angle), deg2rad(angular_resolution))
	
	return best_distance

# Receives the angles in rad
func draw_scan(position: Vector2, angle: float, angular_width: float):
	var new_instance = vision_cone_scene.instance()
	add_child(new_instance)
	new_instance.set_angular_width(angular_width)
	new_instance.rotate(angle)
	new_instance.position = position
	new_instance.play_animation()

func _on_Projectile_arrived(landing_position : Vector2) :
	var ducks := PlayerData.get_ducks_as_nodes()
	var has_hit := false
	var max_exhaustion := 0.0
	for duck in ducks:
		if duck.is_tired() :
		  continue
		var distance = landing_position.distance_to(duck.position) / MAP_SCALE_FROM_BLOCKLY
		var exhaustion = (1 - distance / 4) * 10
		if exhaustion > 0 :
			max_exhaustion = max(exhaustion, max_exhaustion)
			duck.tire(exhaustion)
			has_hit = true
	projectile_splash(landing_position, has_hit, max_exhaustion)
			
func projectile_splash(landing_position : Vector2, has_hit : bool, exhaustion : float):
	var player : AudioStreamPlayer = null
	if has_hit:
		player = boom_player_scene.instance()
		player.volume_db = -40 + 40 * (exhaustion / 10)
	elif Geometry.is_point_in_polygon(landing_position, $Water.polygon):
		player = splash_player_scene.instance()
	if player != null:
		player.add_to_group("sound_effects")
		add_child(player)
		player.play()
		
		var blast = blast_scene.instance()
		blast.position = landing_position
		blast.add_to_group("visual_effects")
		add_child(blast)
		blast.play()
		
	
func add_projectile(projectile : Projectile):
	projectile.connect("arrived", self, "_on_Projectile_arrived")
	add_child(projectile)
