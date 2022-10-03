extends Node2D

# [TODO] Either programatically instanciate ducks, allowing variable quantities;
# or manually Build extensions of PondVisualization for each player count.
export var duck_amount := 2

# Indicates if the pond is simulating or just showing it's state visually
# Enables physics_process for Projectiles.
export var is_simulating := true

# How many time bigger is the scale of this map versus the 100x100 map from blocly-games' pond
const MAP_SCALE_FROM_BLOCKLY : float = 4.0
const SOUNDS_EFFECTS_GROUP : String = "sound_effects"
const VISUAL_EFFECTS_GROUP : String = "visual_effects"
const PROJECTILES_GROUP : String = "projectiles_effects"
const MAX_DUCKS : int = 4

var projectiles : Array setget _no_set, _no_get
var projectile_pond_states : Array setget _set_projectile_pond_states, _get_projectile_pond_states

# [TODO] Make a tool to edit starting positions and rotations
onready var STARTING_POSITIONS := [Vector2(94,101), Vector2(279,101)]
onready var STARTING_ROTATIONS := [0.0, PI]

onready var _ducks := []
onready var _vision_cones := []
onready var projectile_scene := preload("res://src/World/Characters/Projectile.tscn")
onready var vision_cone_scene := preload("res://src/World/Effects/VisionCone.tscn")
onready var boom_player_scene := preload("res://src/World/Effects/BoomPlayer.tscn")
onready var blast_scene := preload("res://src/World/Effects/Blast.tscn")
onready var splash_player_scene := preload("res://src/World/Effects/SplashPlayer.tscn")
onready var scan_mutex := Mutex.new()

func _enter_tree():
	# Sets itself as the current visualization
	CurrentVisualization.set_current(self)

func _ready() -> void:
	var duck_paths := []
	for i in duck_amount :
		# [TODO] Change this so it instances new ducks
		#     will need to change the color somehow
		_ducks.append(get_node("Duck%d"%i))
		duck_paths.append(_ducks[i].get_path())
		
		# Instances a vision cone for each duck
		var new_cone = vision_cone_scene.instance()
		_vision_cones.append(new_cone)
		new_cone.name = "VisionCone%d"%i
		new_cone.set_visible(false)
		add_child(new_cone)
	
	# Prepares every Projectile ever needed
	for i in duck_amount*3:
		var proj := projectile_scene.instance()
		projectiles.push_back(proj)
		hide_projectile(proj)
		# warning-ignore:return_value_discarded
		proj.connect("arrived", self, "_on_Projectile_arrived")
		proj.add_to_group(PROJECTILES_GROUP)
		add_child(proj)
	
	PlayerData.ducks = duck_paths
	
	# Sets collision metadata for the walls
	$PondEdges.set_meta("collider_type", "wall")


func _physics_process(_delta):
	$Debugger/Label.text = "Duck0 speed = %f\nDuck1 speed = %f\nDuck0 pos = %s\nDuck1 pos = %s\n"% \
						[$Duck0.speed,$Duck1.speed,String($Duck0.position),String($Duck1.position)]

# If the center of a duck is visible, returns distance to it. Else returns INF
func scan_field(scanner : int, degree, angular_resolution) -> float:
	scan_mutex.lock()

	# [TODO] Consider if thread protection with mutexes is needed
	var start : Vector2 = _ducks[scanner].position
	var radians := deg2rad(degree)
	var scanning_to := Vector2(1,0).rotated(radians).normalized()
	var best_distance := INF
	
	for i in _ducks.size():
		if i == scanner :
			continue
		# Position to other duck
		var target_pos : Vector2 = _ducks[i].position
		var direction_to = start.direction_to(target_pos)
		var angular_dist := abs(scanning_to.angle_to(direction_to))
		
		# Checks if the angle to the other duck is within tolerance
		if angular_dist <= deg2rad(angular_resolution/2) :
			var dist := start.distance_to(target_pos)
			if dist < best_distance:
				# Updates best distance
				best_distance = dist

	_vision_cones[scanner].play_animation(start, radians)
	
	scan_mutex.unlock()
	
	return best_distance

func _on_Projectile_arrived(landing_position : Vector2, projectile : Projectile) :
	var has_hit := false
	var max_exhaustion := 0.0
	for duck in _ducks:
		if duck.is_tired() :
		  continue
		var distance = landing_position.distance_to(duck.position) / MAP_SCALE_FROM_BLOCKLY
		var exhaustion = (1 - distance / 4) * 10
		if exhaustion > 0 :
			max_exhaustion = max(exhaustion, max_exhaustion)
			duck.tire(exhaustion)
			has_hit = true
	projectile_splash(landing_position, has_hit, max_exhaustion)
	hide_projectile(projectile)
			
func projectile_splash(landing_position : Vector2, has_hit : bool, exhaustion : float):
	var player : AudioStreamPlayer = null
	if has_hit:
		player = boom_player_scene.instance()
		player.volume_db = -40 + 40 * (exhaustion / 10)
	elif Geometry.is_point_in_polygon(landing_position, $Water.polygon):
		player = splash_player_scene.instance()
	if player != null:
		player.add_to_group(SOUNDS_EFFECTS_GROUP)
		add_child(player)
		player.play()
		
		var blast = blast_scene.instance()
		blast.position = landing_position
		blast.add_to_group(VISUAL_EFFECTS_GROUP)
		add_child(blast)
		blast.play()
		
	
func add_projectile(p_color : Color, p_start_location : Vector2, p_end_location : Vector2, p_distance : float):
	for proj in projectiles:
		if not proj.is_processing():
			proj.distance = p_distance
			proj.color = p_color
			proj.start_location = p_start_location
			proj.end_location = p_end_location
			proj.progress = 0.0
			show_projectile(proj)

func show_projectile(projectile : Projectile):
	projectile.show()
	projectile.set_process(true)
	projectile.set_physics_process(is_simulating)
func hide_projectile(projectile : Projectile):
	projectile.hide()
	projectile.set_physics_process(false)
	projectile.set_process(false)

func _set_projectile_pond_states(p_states : Array):
	var proj : Projectile
	for i in projectiles.size():
		proj = projectiles[i]
		if i < p_states.size() :
			proj.pond_state = p_states[i]
			show_projectile(proj)
		else:
			hide_projectile(proj)
		

func _get_projectile_pond_states() -> Array:
	var states := []
	for proj in projectiles:
		if proj.is_processing():
			states.push_back(proj.pond_state)
	return states

func _free_groups(effects : Array):
	for effect in effects :
		effect.stop()
		effect.queue_free()
		remove_child(effect)

func reset():
	var tree = get_tree()
	_free_groups(tree.get_nodes_in_group(SOUNDS_EFFECTS_GROUP))
	_free_groups(tree.get_nodes_in_group(VISUAL_EFFECTS_GROUP))
#	_free_groups(tree.get_nodes_in_group(PROJECTILES_GROUP))
	for proj in projectiles:
		hide_projectile(proj)
	for i in _ducks.size():
		_ducks[i].reset(STARTING_POSITIONS[i], STARTING_ROTATIONS[i])
	for cone in _vision_cones:
		cone.reset()
		cone.set_visible(false)

func _no_set(_p):
	return

func _no_get():
	return
