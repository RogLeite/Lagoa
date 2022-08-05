extends Node

var semaphores : Dictionary
var total_participants_mutex : Mutex
var amount_waiting_mutex : Mutex
var semaphores_mutex : Mutex #Protection for read/write to the semaphores dictionary
export var total_participants : int
var amount_waiting : int setget set_amount_waiting, get_amount_waiting
# Um dicionário de Threads? Com um contador pra cada?


func _init() -> void:
	semaphores = {}
	total_participants_mutex = Mutex.new()
	amount_waiting_mutex = Mutex.new()
	semaphores_mutex = Mutex.new()
	amount_waiting = 0

# 	Every unique identifier in the array is registered as a participant in the
# sincronization. Called with an array of unique identifiers. We suggest using
# the instance_id of the expected caller of await_permission.
# 	Warning! By calling this method, ScriptSincronizer will lose it's
# reference to previous participants and their respective semaphores
func prepare_participants( identifiers : Array ) : 
	semaphores = {}
	total_participants = identifiers.size()
	for id in identifiers :
		semaphores[id] = Semaphore.new()

func everyone_arrived() -> bool :
	total_participants_mutex.lock()
	var amount = total_participants
	total_participants_mutex.unlock()
	return amount == get_amount_waiting()

# identifier has to be a value in the array passed in the last call to prepare()
func await_permission( unique_id ):
	assert( semaphores.has( unique_id ), "In ScriptSincronizer.await_permission: semaphores has no key \"%s\""%var2str(unique_id) )
	increment_amount_waiting()
	# No problem if main thread posts before this wait, this thread will just proceed as usual.
	semaphores_mutex.lock()
	var semaphore = semaphores[unique_id]
	semaphores_mutex.unlock()
	semaphore.wait()
	

func give_permission():
	# Called by main thread to allow the others to take a step
	set_amount_waiting(0)
	semaphores_mutex.lock()
	for key in semaphores :
		semaphores[key].post()
	semaphores_mutex.unlock()
	
func set_amount_waiting(value : int) :
	assert(value == 0, "Only setting amount_waiting to 0 is allowed")
	amount_waiting_mutex.lock()
	amount_waiting = 0
	amount_waiting_mutex.unlock()

func increment_amount_waiting() :
	amount_waiting_mutex.lock()
	amount_waiting += 1
	amount_waiting_mutex.unlock()

func get_amount_waiting() -> int : 
	var ret : int
	amount_waiting_mutex.lock()
	ret = amount_waiting
	amount_waiting_mutex.unlock()
	return ret

# Remove a participant from the sincronization.
func remove_participant(unique_id) : 
	# Needs to remove the dictionary element and decrement the counter
	assert(semaphores.has(unique_id), "In ScriptSincronizer.remove_participant: semaphores has no key \"%s\""%var2str(unique_id) )
	
	semaphores_mutex.lock()
	var _val = semaphores.erase(unique_id)
	semaphores_mutex.unlock()

	total_participants_mutex.lock()
	var amount : int = total_participants
	var has_participants : bool = amount > 0
	if has_participants:
		total_participants -= 1
	total_participants_mutex.unlock()
	
	assert(has_participants, "In ScriptSincronizer.remove_participant: no participants to remove; the amount of participants is %d"%amount)
