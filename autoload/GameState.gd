extends Node
## Cross-cutting state that doesn't belong to one system: the debug flag, and the game mode and
## difficulty chosen when a game is started (they decide the starting cash, how rough the random
## events are, how generous mission/order rewards are, and whether money is limited at all).

enum Mode { CAREER, FREE, SANDBOX }
enum Difficulty { EASY, NORMAL, HARD }

const SANDBOX_CASH := 99999
const START_CASH := [100, 60, 40]
const EVENT_MULTIPLIER := [0.6, 1.0, 1.5]
const REWARD_MULTIPLIER := [1.25, 1.0, 0.85]

var debug_mode: bool = OS.is_debug_build()
var first_run: bool = true
var mode: int = Mode.CAREER
var difficulty: int = Difficulty.NORMAL


func is_sandbox() -> bool:
	return mode == Mode.SANDBOX


func is_career() -> bool:
	return mode == Mode.CAREER


func start_cash() -> int:
	return SANDBOX_CASH if is_sandbox() else START_CASH[difficulty]


func event_multiplier() -> float:
	return EVENT_MULTIPLIER[difficulty]


func reward_multiplier() -> float:
	return REWARD_MULTIPLIER[difficulty]


func to_save_dict() -> Dictionary:
	return {"mode": mode, "difficulty": difficulty}


## A save written before modes existed is an open-ended game: it carries on as Free play.
func from_save_dict(d: Dictionary) -> void:
	mode = clampi(int(d.get("mode", Mode.FREE)), 0, Mode.SANDBOX)
	difficulty = clampi(int(d.get("difficulty", Difficulty.NORMAL)), 0, Difficulty.HARD)
