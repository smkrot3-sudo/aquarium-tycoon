extends Node
## Player cash, lifetime earnings and the level they drive, and the transaction log. In Sandbox
## mode money is unlimited: nothing is ever deducted and every level's unlocks are open.
##
## `unlock_tier` is the player's LEVEL (1..50, see Levels); the name is kept from when it was a
## handful of money tiers. Experience = lifetime earnings + bonus experience.

signal cash_changed(new_balance: int)
signal unlock_tier_changed(new_tier: int)
signal transaction(amount: int, reason: String)

var cash: int = Economy.STARTING_CASH
var lifetime_earnings: int = 0
var bonus_xp: int = 0
var unlock_tier: int = 1


func can_afford(amount: int) -> bool:
	return GameState.is_sandbox() or cash >= amount


func spend(amount: int, reason: String) -> bool:
	if not can_afford(amount):
		return false
	if GameState.is_sandbox():
		transaction.emit(-amount, reason)
		return true
	cash -= amount
	transaction.emit(-amount, reason)
	cash_changed.emit(cash)
	return true


func earn(amount: int, reason: String) -> void:
	cash += amount
	lifetime_earnings += amount
	transaction.emit(amount, reason)
	cash_changed.emit(cash)
	_recompute_unlock_tier()


func xp() -> int:
	return lifetime_earnings + bonus_xp


## Experience that doesn't come from money (missions, a new species in the collection...).
func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	bonus_xp += amount
	_recompute_unlock_tier()


## Call after the game mode changes (new game) or a save is loaded.
func apply_mode() -> void:
	if GameState.is_sandbox():
		cash = GameState.SANDBOX_CASH
		cash_changed.emit(cash)
	_recompute_unlock_tier()


func _recompute_unlock_tier() -> void:
	var new_level := Levels.level_for_xp(xp())
	if GameState.is_sandbox():
		new_level = Levels.MAX_LEVEL
	if new_level != unlock_tier:
		unlock_tier = new_level
		unlock_tier_changed.emit(unlock_tier)


func to_save_dict() -> Dictionary:
	return {"cash": cash, "lifetime_earnings": lifetime_earnings, "bonus_xp": bonus_xp, "unlock_tier": unlock_tier}


func from_save_dict(d: Dictionary) -> void:
	cash = d.get("cash", Economy.STARTING_CASH)
	lifetime_earnings = d.get("lifetime_earnings", 0)
	if d.has("bonus_xp"):
		bonus_xp = int(d["bonus_xp"])
	else:
		## A save from before levels existed: give it the level its old tier now corresponds to.
		var floor_level := Levels.level_for_legacy_tier(int(d.get("unlock_tier", 0)))
		bonus_xp = maxi(0, Levels.xp_for_level(floor_level) - lifetime_earnings)
	unlock_tier = Levels.level_for_xp(xp())
