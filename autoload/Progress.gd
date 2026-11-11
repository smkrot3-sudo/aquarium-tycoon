extends Node
## The player's career record: counters (fish bought, orders done...), the species collection
## (owned / bred / colour morphs), mission completion and the career stage, plus the daily
## ticket income of the public aquarium (stage 3). Missions and collection milestones pay out
## automatically the moment they are reached.

signal mission_completed(mission_id: String, reward: int)
signal stage_changed(stage: int)
## kind: "bred" / "morph" / "milestone"; species_id is "" for milestones.
signal collection_reward(kind: String, species_id: String, amount: int)
signal visitors_paid(visitors: int, income: int)

var counters: Dictionary = {}
var owned_species: Dictionary = {}   ## species_id -> true, ever had one in a tank
var bred_species: Dictionary = {}    ## species_id -> true, ever bred one in the player's tank
var morphs: Dictionary = {}          ## species_id -> Array[int] colour buckets seen on bred fry
var completed: Dictionary = {}       ## mission_id -> true
var milestones_claimed: Dictionary = {}
var stage: int = 1
var last_visitors: int = 0
var last_visitor_income: int = 0

## True while a save is being loaded: collection facts are recorded but nothing is paid out.
var loading: bool = false


func _ready() -> void:
	TimeManager.sim_day_elapsed.connect(_on_day)


func reset() -> void:
	counters.clear()
	owned_species.clear()
	bred_species.clear()
	morphs.clear()
	completed.clear()
	milestones_claimed.clear()
	stage = 1
	last_visitors = 0
	last_visitor_income = 0


func bump(counter: String, amount: int = 1) -> void:
	counters[counter] = int(counters.get(counter, 0)) + amount


## Stage 3 features (and everything else) are simply on outside Career mode.
func effective_stage() -> int:
	if GameState.is_career():
		return mini(stage, Goals.STAGE_COUNT)
	return Goals.STAGE_COUNT


func metric(name: String) -> int:
	match name:
		"species_owned":
			return owned_species.size()
		"species_bred":
			return bred_species.size()
		"tanks_owned":
			return TankRegistry.tanks.size()
		"lifetime_earnings":
			return EconomyManager.lifetime_earnings
		_:
			return int(counters.get(name, 0))


func morph_count() -> int:
	var total := 0
	for list in morphs.values():
		total += list.size()
	return total


## Called by TankController.add_fish for every fish that enters a tank.
func note_fish_added(species: FishSpeciesData, is_fry: bool, hue_shift: float) -> void:
	owned_species[species.id] = true
	if is_fry:
		bump("fry_born")
		if not bred_species.has(species.id):
			bred_species[species.id] = true
			_pay_collection("bred", species.id, maxi(5, species.base_price))
		if species.color_variable:
			var bucket := morph_bucket(hue_shift)
			if not morphs.has(species.id):
				morphs[species.id] = []
			if bucket not in morphs[species.id]:
				morphs[species.id].append(bucket)
				_pay_collection("morph", species.id, Goals.MORPH_REWARD)
	_check_collection_milestones()


static func morph_bucket(hue_shift: float) -> int:
	var span: float = FishController.HUE_VARIETY * 2.0
	return clampi(int((hue_shift + FishController.HUE_VARIETY) / span * Goals.MORPH_BUCKETS), 0, Goals.MORPH_BUCKETS - 1)


func _pay_collection(kind: String, species_id: String, base_amount: int) -> void:
	if loading:
		return
	var amount := maxi(1, int(round(base_amount * GameState.reward_multiplier())))
	EconomyManager.earn(amount, "Collection %s" % kind)
	EconomyManager.add_xp(amount * 2)
	collection_reward.emit(kind, species_id, amount)


func _check_collection_milestones() -> void:
	var owned := owned_species.size()
	for threshold in Goals.COLLECTION_MILESTONES.keys():
		var key := "own_%d" % threshold
		if owned >= threshold and not milestones_claimed.has(key):
			milestones_claimed[key] = true
			_pay_collection("milestone", "", Goals.COLLECTION_MILESTONES[threshold])
	var total: int = ShopManager.species_catalog.size()
	if total > 0 and owned >= total and not milestones_claimed.has("own_all"):
		milestones_claimed["own_all"] = true
		_pay_collection("milestone", "", Goals.COLLECTION_COMPLETE_BONUS)


## Pays any mission whose target has been reached and moves up a stage when the current one
## is finished. Cheap enough to call on every state change.
func check() -> void:
	if loading:
		return
	var again := true
	while again:
		again = false
		for m in Goals.MISSIONS:
			var id: String = m[0]
			if completed.has(id) or m[1] > stage:
				continue
			if metric(m[2]) >= m[3]:
				completed[id] = true
				var reward := maxi(1, int(round(m[4] * GameState.reward_multiplier())))
				EconomyManager.earn(reward, "Mission %s" % id)
				EconomyManager.add_xp(reward)
				mission_completed.emit(id, reward)
				again = true
		if stage <= Goals.STAGE_COUNT and stage_done(stage):
			stage += 1
			stage_changed.emit(stage)
			again = true


func stage_done(of_stage: int) -> bool:
	for m in Goals.missions_of_stage(of_stage):
		if not completed.has(m[0]):
			return false
	return true


func stage_progress(of_stage: int) -> Vector2i:
	var done := 0
	var missions := Goals.missions_of_stage(of_stage)
	for m in missions:
		if completed.has(m[0]):
			done += 1
	return Vector2i(done, missions.size())


# ----------------------------------------------------------------------------------------
# Public aquarium (stage 3): ticket income, once per sim-day
# ----------------------------------------------------------------------------------------

func _on_day(_day: int) -> void:
	if effective_stage() < Goals.STAGE_COUNT or GameState.is_sandbox():
		return
	var tanks := TankRegistry.tanks.size()
	if tanks < 3:
		return
	var species_alive: Dictionary = {}
	var health_sum := 0.0
	var fish_total := 0
	for tank in TankRegistry.tanks:
		if not is_instance_valid(tank):
			continue
		for fish in tank.get_fish():
			species_alive[fish.species.id] = true
			health_sum += fish.health
			fish_total += 1
	if fish_total == 0:
		return
	var health_factor: float = clampf(health_sum / float(fish_total) / 100.0, 0.2, 1.0)
	var visitors := int((8.0 * sqrt(float(tanks)) + 3.0 * species_alive.size()) * health_factor)
	var income := int(round(visitors * 0.9 * GameState.reward_multiplier()))
	last_visitors = visitors
	last_visitor_income = income
	if income > 0:
		EconomyManager.earn(income, "Tickets")
		visitors_paid.emit(visitors, income)


func to_save_dict() -> Dictionary:
	return {
		"counters": counters, "owned": owned_species.keys(), "bred": bred_species.keys(),
		"morphs": morphs, "completed": completed.keys(), "milestones": milestones_claimed.keys(),
		"stage": stage, "last_visitors": last_visitors, "last_visitor_income": last_visitor_income,
	}


func from_save_dict(d: Dictionary) -> void:
	reset()
	for key in d.get("counters", {}).keys():
		counters[key] = int(d["counters"][key])
	for id in d.get("owned", []):
		owned_species[id] = true
	for id in d.get("bred", []):
		bred_species[id] = true
	var saved_morphs: Dictionary = d.get("morphs", {})
	for id in saved_morphs.keys():
		morphs[id] = []
		for bucket in saved_morphs[id]:
			morphs[id].append(int(bucket))
	for id in d.get("completed", []):
		completed[id] = true
	for id in d.get("milestones", []):
		milestones_claimed[id] = true
	stage = int(d.get("stage", 1))
	last_visitors = int(d.get("last_visitors", 0))
	last_visitor_income = int(d.get("last_visitor_income", 0))
