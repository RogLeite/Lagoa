extends Node2D

signal sfx_played (effect_name)
signal vfx_played (effect_name, p_pond_state)

# Indicates if the pond is simulating or just showing it's state visually
# Enables physics_process for Projectiles.
var is_simulating_match := true

# How many time bigger is the scale of this map versus the 100x100 map from blocly-games' pond
const MAP_SCALE_FROM_BLOCKLY : float = 4.0
const SOUNDS_EFFECTS_GROUP : String = "sound_effects"
const VISUAL_EFFECTS_GROUP : String = "visual_effects"
const PROJECTILES_GROUP : String = "projectiles_effects"

var projectiles : Array setget _no_set, _no_get
var projectile_pond_states : Array setget _set_projectile_pond_states, _get_projectile_pond_states
var vision_cones_pond_states : Array setget , _get_vision_cones_pond_states

# [TODO] Make a tool to edit starting positions and rotations
var starting_positions := [Vector2(92,100), Vector2(308,100), Vector2(92,300), Vector2(308,300)]
var starting_rotations := [0.0, PI, 0.0, PI]

var _every_duck := []
# Every duck that is participating in the match. MAY NOT BE IN THE REAL DUCK ORDER!
var _participating_ducks := []
var _pool_vision_cones := []

var scan_mutex := Mutex.new()
var projectile_mutex := Mutex.new()

onready var projectile_scene := preload("res://src/World/Characters/Projectile.tscn")
onready var vision_cone_scene := preload("res://src/World/Effects/VisionCone.tscn")
onready var boom_player_scene := preload("res://src/World/Effects/BoomPlayer.tscn")
onready var blast_scene := preload("res://src/World/Effects/Blast.tscn")
onready var splash_player_scene := preload("res://src/World/Effects/SplashPlayer.tscn")

func _enter_tree():
	# Sets itself as the current visualization
	CurrentVisualization.set_current(self)

func _ready() -> void:
	
	# Prepares every VisionCone ever needed
	for i in PlayerData.MAX_PLAYERS_PER_MATCH:
		# Sets every duck as not participating
		var duck : Duck = get_node("Duck%d"%i)
		duck.set_participating(false)
		_every_duck.append(duck)

		# Prepares every VisionCone ever needed: 7 per player
		for j in 2:
			var new_cone = vision_cone_scene.instance(i)
			_pool_vision_cones.push_back(new_cone)
			new_cone.name = "VisionCone%d"%j
			add_child(new_cone)	



		# Prepares every Projectile ever needed: 3 per player
		for j in 3:
			var proj := projectile_scene.instance()
			projectiles.push_back(proj)
			hide_projectile(proj)
			# warning-ignore:return_value_discarded
			proj.connect("arrived", self, "_on_Projectile_arrived")
			proj.add_to_group(PROJECTILES_GROUP)
			add_child(proj)

	# If there are already players, adds a duck to PlayerData
	for i in PlayerData.count():
		if PlayerData.is_present(i):
			enable_duck(i)
	
	
	# Sets collision metadata for the walls
	$PondEdges.set_meta("collider_type", "wall")
	
	reset()

	# Connects signals
	# warning-ignore:return_value_discarded
	PlayerData.connect("player_joined", self, "_on_PlayerData_player_joined")
	# warning-ignore:return_value_discarded
	PlayerData.connect("player_left", self, "_on_PlayerData_player_left")


func _physics_process(_delta):
	$Debugger/Label.text = "Duck0 speed = %f\nDuck1 speed = %f\nDuck0 pos = %s\nDuck1 pos = %s\n"% \
						[$Duck0.speed,$Duck1.speed,String($Duck0.position),String($Duck1.position)]

func _exit_tree():
	if PlayerData.is_connected("player_joined", self, "_on_PlayerData_player_joined"):
		PlayerData.disconnect("player_joined", self, "_on_PlayerData_player_joined")
	if PlayerData.is_connected("player_left", self, "_on_PlayerData_player_left"):
		PlayerData.disconnect("player_left", self, "_on_PlayerData_player_left")

# If the center of a duck is visible, returns distance to it. Else returns INF
func scan_field(scanner : int, degree, angular_resolution) -> float:
	scan_mutex.lock()

	# [TODO] Consider if thread protection with mutexes is needed
	var scanner_duck : Duck = _every_duck[scanner]
	var start : Vector2 = scanner_duck.position
	var radians := deg2rad(degree)
	var scanning_to := Vector2(1,0).rotated(radians).normalized()
	var best_distance := INF
	
	for i in _participating_ducks.size():
		var verifying_duck : Duck = _participating_ducks[i]
		if verifying_duck == scanner_duck or verifying_duck.is_tired():
			continue
		# Position to other duck
		var target_pos : Vector2 = verifying_duck.position
		var direction_to = start.direction_to(target_pos)
		var angular_dist := abs(scanning_to.angle_to(direction_to))
		
		# Checks if the angle to the other duck is within tolerance
		if angular_dist > deg2rad(angular_resolution/2) :
			continue

		var dist := start.distance_to(target_pos)
		# Updates best distance
		best_distance = min(dist, best_distance)

	add_vision_cone(start, radians)
	
	scan_mutex.unlock()
	
	return best_distance

# Receives a Dictionary where every Key that has corresponding Value true is a sfx to play
# Example:
# {
# 	"boom" : true,
# 	"splash" : true
# }
func play_sfx(p_effects : Dictionary):
	if p_effects.has("boom") and p_effects.boom :
		var player : AudioStreamPlayer = boom_player_scene.instance()
		player.add_to_group(SOUNDS_EFFECTS_GROUP)
		add_child(player)
		player.play()
	
	if p_effects.has("splash") and p_effects.splash :
		var player : AudioStreamPlayer = splash_player_scene.instance()
		player.add_to_group(SOUNDS_EFFECTS_GROUP)
		add_child(player)
		player.play()

# Plays VFX according to a Dictionary of Arrays of States
# The Keys of the Dictionary are the effect name, the Values are Arrays of States for that effect
# {
# 	"vision_cone" : [], 
# 	"blast" : []
# }
func play_vfx(p_effects : Dictionary):
	var received_states : Array = p_effects["vision_cone"]
	for i in received_states.size():
		var cone : VisionCone = _pool_vision_cones[i]
		cone.pond_state = received_states[i]

	for blast_state in p_effects["blast"]:
		_play_blast(blast_state.position, false)
		
func _play_blast(p_position : Vector2, p_emit : bool = true) -> void:
	var blast = blast_scene.instance()
	blast.position = p_position
	blast.add_to_group(VISUAL_EFFECTS_GROUP)
	add_child(blast)
	blast.play()
	if p_emit:
		emit_signal("vfx_played", "blast", blast.pond_state)

func projectile_splash(landing_position : Vector2, is_hit : bool, _exhaustion : float) -> void:
	var player : AudioStreamPlayer = null
	
	if is_hit:
		player = boom_player_scene.instance()
		# player.volume_db = -40 + 40 * (exhaustion / 10)
		emit_signal("sfx_played", "boom")
	elif Geometry.is_point_in_polygon(landing_position, $Water.polygon):
		player = splash_player_scene.instance()
		emit_signal("sfx_played", "splash")
	
	if !player :
		return
	
	player.add_to_group(SOUNDS_EFFECTS_GROUP)
	add_child(player)
	if visible:
		player.play()
	
	_play_blast(landing_position)
	
func add_vision_cone(p_position : Vector2, p_rotation : float):
	for cone in _pool_vision_cones:
		if cone.is_available:
			cone.play_animation(p_position, p_rotation)
			break

func add_projectile(p_color : Color, p_start_location : Vector2, p_end_location : Vector2, p_distance : float):
	projectile_mutex.lock()

	for proj in projectiles:
		if proj.is_processing():
			continue
		proj.distance = p_distance
		proj.color = p_color
		proj.start_location = p_start_location
		proj.end_location = p_end_location
		proj.progress = 0.0
		show_projectile(proj)
		break

	projectile_mutex.unlock()

func show_projectile(projectile : Projectile):
	projectile.set_process(true)
	projectile.set_physics_process(is_simulating_match)
	projectile.show()

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

func _get_vision_cones_pond_states() -> Array:
	scan_mutex.lock()
	var states := [] 
	for cone in _pool_vision_cones:
		states.push_back(cone.pond_state)
	scan_mutex.unlock()
	return states

func _free_groups(effects : Array):
	for effect in effects :
		effect.stop()
		effect.queue_free()
		remove_child(effect)

func stop():
	# set_process(false)
	set_physics_process(false)

func reset_effects() -> void:
	var tree = get_tree()
	_free_groups(tree.get_nodes_in_group(SOUNDS_EFFECTS_GROUP))
	_free_groups(tree.get_nodes_in_group(VISUAL_EFFECTS_GROUP))
#	_free_groups(tree.get_nodes_in_group(PROJECTILES_GROUP))

func reset_projectiles() -> void:
	for proj in projectiles:
		hide_projectile(proj)

func reset_ducks() -> void:
	for i in _every_duck.size():
		_every_duck[i].reset(starting_positions[i], starting_rotations[i])
	# If there are already players, adds a duck to PlayerData
	for i in PlayerData.count():
		if not PlayerData.is_present(i):
			disable_duck(i)

func reset_vision_cones() -> void:
	for cone in _pool_vision_cones:
		cone.reset()

func reset():
	reset_effects()
	reset_projectiles()
	reset_ducks()
	reset_vision_cones()
	set_physics_process(true)

func add_duck(p_index):
	var duck = _every_duck[p_index]
	PlayerData.set_duck_path(p_index, duck.get_path())

# Sets a duck as participating and sets it's path in PlayerData. 
func enable_duck(p_index):
	var duck = _every_duck[p_index]
	duck.reset(starting_positions[p_index], starting_rotations[p_index])
	duck.set_participating(true)
	if _participating_ducks.find(duck) == -1:
		_participating_ducks.push_back(duck)

# [TODO] Force the removal of the player
func remove_duck(_p_index):
	pass

func disable_duck(p_index):
	var duck = _every_duck[p_index]
	duck.reset(starting_positions[p_index], starting_rotations[p_index])
	duck.set_participating(false)
	_participating_ducks.erase(duck)

func _no_set(_p):
	return

func _no_get():
	return

func _on_PlayerData_player_joined(p_index : int) -> void:
	if not PlayerData.has_duck(p_index):
		add_duck(p_index)
	enable_duck(p_index)

func _on_PlayerData_player_left(p_index : int) -> void:
	if PlayerData.has_duck(p_index):
		disable_duck(p_index)
	

func _on_Projectile_arrived(landing_position : Vector2, projectile : Projectile) :
	var is_hit := false
	var max_exhaustion := 0.0
	for duck in _participating_ducks:
		if duck.is_tired() :
			continue
		var distance = landing_position.distance_to(duck.position) / MAP_SCALE_FROM_BLOCKLY
		var exhaustion = (1 - distance / 4) * 10
		if exhaustion > 0 :
			max_exhaustion = max(exhaustion, max_exhaustion)
			duck.tire(exhaustion)
			is_hit = true
	projectile_splash(landing_position, is_hit, max_exhaustion)
	hide_projectile(projectile)
