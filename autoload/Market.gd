extends Node
## Everything that happens between the player and the outside world, once a sim-day:
##  - customer orders and wholesale orders (specific fish for a premium price, with a deadline)
##  - fish shows (enter your best fish for a prize)
##  - online auctions (list a fish; the sale comes back in a day or two at a variable price)
##  - the shop's rare-fish stock (some species can only be bought while "in stock")
## Fish are looked up across every owned tank, so an order can be filled from any of them.

signal orders_changed
signal order_expired(order: Dictionary)
signal order_completed(order: Dictionary, reward: int)
signal rare_arrived(species_ids: Array)
signal rare_left(species_id: String)
signal auction_resolved(fish_name: String, species_id: String, amount: int)
signal contest_started
signal contest_finished(result: Dictionary)

const CUSTOMER_COUNT := 10
const RARE_TIER := 3
const MAX_ORDERS_BY_STAGE := [0, 2, 3, 4]
const CONTEST_FEE_BY_STAGE := [0, 12, 25, 50]

var orders: Array = []        ## [{id, kind, species_id, count, sex, adult_only, min_health, reward, days_left, customer}]
var next_order_id: int = 1
var contest: Dictionary = {}  ## {theme, days_left, fee, entered, result}
var next_contest_in: float = 8.0
var rare_stock: Dictionary = {}  ## species_id -> sim-days left in stock
var rare_timer: float = 2.0
var auctions: Array = []      ## [{fish_name, species_id, health, days_left}]


func _ready() -> void:
	TimeManager.sim_day_elapsed.connect(_on_day)


func reset() -> void:
	orders.clear()
	next_order_id = 1
	contest = {}
	next_contest_in = 8.0
	rare_stock.clear()
	rare_timer = 2.0
	auctions.clear()
	orders_changed.emit()


# ----------------------------------------------------------------------------------------
# Daily tick
# ----------------------------------------------------------------------------------------

func _on_day(_day: int) -> void:
	_age_orders()
	_maybe_spawn_order()
	_tick_rare_stock()
	_tick_auctions()
	_tick_contest()
	orders_changed.emit()


func _age_orders() -> void:
	for order in orders.duplicate():
		order["days_left"] = float(order["days_left"]) - 1.0
		if order["days_left"] <= 0.0:
			orders.erase(order)
			order_expired.emit(order)


func max_open_orders() -> int:
	return MAX_ORDERS_BY_STAGE[clampi(Progress.effective_stage(), 0, 3)]


func _maybe_spawn_order() -> void:
	if orders.size() >= max_open_orders():
		return
	if TimeManager.current_day() < 2 or randf() > 0.55:
		return
	var order := _make_order()
	if not order.is_empty():
		orders.append(order)


func _water_types_owned() -> Dictionary:
	var types := {}
	for tank in TankRegistry.tanks:
		if is_instance_valid(tank):
			types[tank.tank_type] = true
	return types


func _make_order() -> Dictionary:
	var types := _water_types_owned()
	var owned_now: Dictionary = {}
	for fish in all_fish():
		owned_now[fish.species.id] = true
	var weights: Array = []
	var candidates: Array = []
	for species in ShopManager.species_catalog.values():
		var tank_type: int = TankController.TankType.SALTWATER if species.is_marine else TankController.TankType.FRESHWATER
		if not types.has(tank_type) or species.unlock_tier > EconomyManager.unlock_tier:
			continue
		if species.fry_per_batch_max <= 0 and not owned_now.has(species.id):
			continue
		candidates.append(species)
		weights.append(4.0 if owned_now.has(species.id) else 1.0)
	if candidates.is_empty():
		return {}
	var species: FishSpeciesData = candidates[_weighted_index(weights)]

	var wholesale: bool = Progress.effective_stage() >= 2 and species.fry_per_batch_max > 0 and randf() < 0.3
	var order := {"id": next_order_id, "species_id": species.id, "customer": randi() % CUSTOMER_COUNT, "min_health": 60}
	next_order_id += 1
	var mult := GameState.reward_multiplier()
	if wholesale:
		var count := randi_range(6, 12)
		var each := maxf(float(species.sell_price_adult) * 0.5, float(species.sell_price_fry) * 2.0)
		order["kind"] = "wholesale"
		order["count"] = count
		order["sex"] = -1
		order["adult_only"] = false
		order["min_health"] = 40
		order["reward"] = maxi(count * 2, int(round(count * each * mult)))
		order["days_left"] = float(randi_range(8, 14))
	else:
		var count := randi_range(1, 3)
		var sex := -1
		if species.dimorphic and species.fry_per_batch_max > 0 and randf() < 0.45:
			sex = randi() % 2
		order["kind"] = "customer"
		order["count"] = count
		order["sex"] = sex
		order["adult_only"] = true
		order["reward"] = maxi(count * 3, int(round(count * species.sell_price_adult * randf_range(1.5, 2.2) * mult)))
		order["days_left"] = float(randi_range(5, 9))
	return order


static func _weighted_index(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += float(w)
	var roll := randf() * total
	for i in range(weights.size()):
		roll -= float(weights[i])
		if roll <= 0.0:
			return i
	return weights.size() - 1


# ----------------------------------------------------------------------------------------
# Orders
# ----------------------------------------------------------------------------------------

func all_fish() -> Array:
	var out: Array = []
	for tank in TankRegistry.tanks:
		if is_instance_valid(tank):
			out.append_array(tank.get_fish())
	return out


## Fish that could be handed over for this order, least healthy first (the player keeps the best).
func matching_fish(order: Dictionary) -> Array:
	var out: Array = []
	for fish in all_fish():
		if fish.species.id != order["species_id"] or fish.is_sick:
			continue
		if order["adult_only"] and fish.is_fry:
			continue
		if int(order["sex"]) >= 0 and int(fish.sex) != int(order["sex"]):
			continue
		if fish.health < float(order["min_health"]):
			continue
		out.append(fish)
	out.sort_custom(func(a, b): return a.health < b.health)
	return out


func can_fulfill(order: Dictionary) -> bool:
	return matching_fish(order).size() >= int(order["count"])


func fulfill_order(order_id: int) -> int:
	for order in orders:
		if int(order["id"]) != order_id:
			continue
		var fish_list := matching_fish(order)
		if fish_list.size() < int(order["count"]):
			return -1
		for i in range(int(order["count"])):
			fish_list[i].queue_free()
		var reward := int(order["reward"])
		orders.erase(order)
		EconomyManager.earn(reward, "Order")
		Progress.bump("orders_done")
		order_completed.emit(order, reward)
		orders_changed.emit()
		return reward
	return -1


func orders_ready_count() -> int:
	var n := 0
	for order in orders:
		if can_fulfill(order):
			n += 1
	return n


# ----------------------------------------------------------------------------------------
# Rare stock
# ----------------------------------------------------------------------------------------

func is_rare(species: FishSpeciesData) -> bool:
	return species.rarity_tier >= RARE_TIER


func in_stock(species: FishSpeciesData) -> bool:
	if not is_rare(species) or GameState.is_sandbox():
		return true
	return float(rare_stock.get(species.id, 0.0)) > 0.0


func stock_days_left(species: FishSpeciesData) -> int:
	return int(ceil(float(rare_stock.get(species.id, 0.0))))


func _tick_rare_stock() -> void:
	for id in rare_stock.keys():
		rare_stock[id] = float(rare_stock[id]) - 1.0
		if rare_stock[id] <= 0.0:
			rare_stock.erase(id)
			rare_left.emit(id)
	rare_timer -= 1.0
	if rare_timer <= 0.0:
		rare_timer = randf_range(2.5, 4.5)
		restock_rare()


func restock_rare() -> void:
	var candidates: Array = []
	for species in ShopManager.species_catalog.values():
		if is_rare(species) and species.unlock_tier <= EconomyManager.unlock_tier and not rare_stock.has(species.id):
			candidates.append(species)
	if candidates.is_empty():
		return
	candidates.shuffle()
	var arrived: Array = []
	for i in range(mini(randi_range(1, 2), candidates.size())):
		rare_stock[candidates[i].id] = float(randi_range(6, 10))
		arrived.append(candidates[i].id)
	rare_arrived.emit(arrived)


# ----------------------------------------------------------------------------------------
# Auctions
# ----------------------------------------------------------------------------------------

func can_auction(fish: FishController) -> bool:
	return not fish.is_fry and not fish.is_sick and fish.health >= 50.0


func expected_auction_value(fish: FishController) -> int:
	return int(round(fish.species.sell_price_adult * _auction_factor(fish.health, fish.species.rarity_tier) * 1.15))


static func _auction_factor(health: float, rarity: int) -> float:
	return 0.85 + 0.35 * health / 100.0 + 0.06 * rarity


func list_for_auction(fish: FishController) -> bool:
	if not can_auction(fish):
		return false
	auctions.append({
		"fish_name": fish.fish_name, "species_id": fish.species.id, "health": fish.health,
		"days_left": randi_range(1, 2),
	})
	fish.queue_free()
	orders_changed.emit()
	return true


func _tick_auctions() -> void:
	for auction in auctions.duplicate():
		auction["days_left"] = int(auction["days_left"]) - 1
		if auction["days_left"] > 0:
			continue
		auctions.erase(auction)
		var species := ShopManager.get_species(auction["species_id"])
		if species == null:
			continue
		var amount := maxi(1, int(round(species.sell_price_adult * _auction_factor(auction["health"], species.rarity_tier) * randf_range(0.6, 1.7))))
		EconomyManager.earn(amount, "Auction")
		Progress.bump("fish_sold")
		auction_resolved.emit(auction["fish_name"], species.id, amount)


# ----------------------------------------------------------------------------------------
# Fish shows
# ----------------------------------------------------------------------------------------

func contest_fee() -> int:
	return CONTEST_FEE_BY_STAGE[clampi(Progress.effective_stage(), 0, 3)]


func contest_open() -> bool:
	return not contest.is_empty() and not bool(contest.get("entered", false))


func _tick_contest() -> void:
	if Progress.effective_stage() < 2:
		return
	if contest.is_empty():
		next_contest_in -= 1.0
		if next_contest_in <= 0.0:
			contest = {"theme": randi() % 3, "days_left": 5.0, "fee": contest_fee(), "entered": false, "result": {}}
			contest_started.emit()
		return
	contest["days_left"] = float(contest["days_left"]) - 1.0
	if contest["days_left"] <= 0.0:
		contest = {}
		next_contest_in = randf_range(9.0, 14.0)


## What the judges think of this fish: health first, then how grown it is and how special the
## species is. A little luck on the day.
func contest_score(fish: FishController, with_luck: bool = false) -> float:
	var size_fraction: float = clampf(fish.size_cm / maxf(fish.species.max_size_cm, 0.01), 0.0, 1.0)
	var rarity: float = clampf(float(fish.species.base_price) * 2.0, 0.0, 100.0)
	var score: float = fish.health * 0.5 + size_fraction * 100.0 * 0.2 + rarity * 0.15 + (100.0 - fish.stress) * 0.15
	if with_luck:
		score += randf_range(-4.0, 4.0)
	return score


func eligible_for_contest() -> Array:
	var out: Array = []
	for fish in all_fish():
		if not fish.is_fry and not fish.is_sick:
			out.append(fish)
	out.sort_custom(func(a, b): return contest_score(a) > contest_score(b))
	return out


## Returns the result dictionary, or {} when the entry was not possible.
func enter_contest(fish: FishController) -> Dictionary:
	if not contest_open() or fish.is_fry or fish.is_sick:
		return {}
	var fee := int(contest["fee"])
	if not EconomyManager.spend(fee, "Show entry"):
		return {}
	var stage := Progress.effective_stage()
	var difficulty_bonus: float = [-4.0, 0.0, 5.0][GameState.difficulty]
	var mine := contest_score(fish, true)
	var rivals: Array = []
	for i in range(4):
		rivals.append(snappedf(randf_range(48.0, 62.0) + stage * 5.0 + difficulty_bonus, 0.1))
	var place := 1
	for r in rivals:
		if r > mine:
			place += 1
	var multipliers := [6.0, 3.0, 1.5]
	var prize := 0
	if place <= 3:
		prize = int(round(fee * multipliers[place - 1] * GameState.reward_multiplier()))
		EconomyManager.earn(prize, "Show prize")
	if place == 1:
		Progress.bump("contests_won")
	Progress.bump("contests_entered")
	var result := {"place": place, "score": snappedf(mine, 0.1), "rivals": rivals, "prize": prize, "fish_name": fish.fish_name, "species_id": fish.species.id}
	contest["entered"] = true
	contest["result"] = result
	contest_finished.emit(result)
	return result


func to_save_dict() -> Dictionary:
	return {
		"orders": orders, "next_order_id": next_order_id, "contest": contest, "next_contest_in": next_contest_in,
		"rare_stock": rare_stock, "rare_timer": rare_timer, "auctions": auctions,
	}


func from_save_dict(d: Dictionary) -> void:
	reset()
	orders = d.get("orders", [])
	next_order_id = int(d.get("next_order_id", 1))
	contest = d.get("contest", {})
	next_contest_in = float(d.get("next_contest_in", 8.0))
	rare_stock = d.get("rare_stock", {})
	rare_timer = float(d.get("rare_timer", 2.0))
	auctions = d.get("auctions", [])
	## JSON turns every number into a float; the integer fields above are read back with int()
	## wherever they are used, so nothing else to fix up here.
