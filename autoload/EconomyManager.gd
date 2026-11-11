extends Node
## Player cash, lifetime earnings (drives unlock tiers), and transaction log. In Sandbox mode
## money is unlimited: nothing is ever deducted and every unlock tier is open.

signal cash_changed(new_balance: int)
signal unlock_tier_changed(new_tier: int)
signal transaction(amount: int, reason: String)

var cash: int = Economy.STARTING_CASH
var lifetime_earnings: int = 0
var unlock_tier: int = 0


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


## Call after the game mode changes (new game) or a save is loaded.
func apply_mode() -> void:
	if GameState.is_sandbox():
		cash = GameState.SANDBOX_CASH
		cash_changed.emit(cash)
	_recompute_unlock_tier()


func _recompute_unlock_tier() -> void:
	var new_tier := Economy.unlock_tier_for_earnings(lifetime_earnings)
	if GameState.is_sandbox():
		new_tier = Economy.TIER_THRESHOLDS.size() - 1
	if new_tier != unlock_tier:
		unlock_tier = new_tier
		unlock_tier_changed.emit(unlock_tier)


func to_save_dict() -> Dictionary:
	return {"cash": cash, "lifetime_earnings": lifetime_earnings, "unlock_tier": unlock_tier}


func from_save_dict(d: Dictionary) -> void:
	cash = d.get("cash", Economy.STARTING_CASH)
	lifetime_earnings = d.get("lifetime_earnings", 0)
	unlock_tier = d.get("unlock_tier", 0)
