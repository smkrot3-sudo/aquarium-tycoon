extends Node
## Owns the simulation clock. Fires coarse per-sim-hour ticks (not per-frame) that drive
## water chemistry / fish state updates elsewhere. See plan "Core simulation model".

enum Season { SPRING, SUMMER, AUTUMN, WINTER }

const SIM_MINUTES_PER_REAL_SECOND := 12.0  ## one in-game day per 2 real minutes — phone-session pacing
const SIM_DAYS_PER_SEASON := 7
const MAX_OFFLINE_SIM_DAYS := 3.0           ## cap how far offline-progress catch-up can jump

signal sim_tick(hours_elapsed: float)       ## emitted roughly once per in-game hour
signal sim_day_elapsed(day: int)
signal season_changed(season: Season)
signal speed_changed

## The player's speed button cycles 1x -> 2x -> 4x -> paused -> 1x.
const SPEEDS := [1.0, 2.0, 4.0]

## A game starts at 8 in the morning (midnight would greet the player with a dark room).
const START_MINUTES := 8.0 * 60.0
var sim_minutes_total: float = START_MINUTES
var _minutes_accum_since_last_tick: float = 0.0
var current_season: Season = Season.SPRING
var paused: bool = false                    ## set by the home screen (the game isn't being played)
var player_paused: bool = false             ## set by the player's pause button
var speed_index: int = 0
var time_scale: float = 1.0                 ## debug fast-forward multiplier


func cycle_speed() -> void:
	if player_paused:
		player_paused = false
		speed_index = 0
	elif speed_index >= SPEEDS.size() - 1:
		player_paused = true
	else:
		speed_index += 1
	speed_changed.emit()


func reset_speed() -> void:
	player_paused = false
	speed_index = 0
	speed_changed.emit()


func _process(delta: float) -> void:
	if paused or player_paused:
		return
	var minutes: float = delta * SIM_MINUTES_PER_REAL_SECOND * time_scale * SPEEDS[speed_index]
	sim_minutes_total += minutes
	_minutes_accum_since_last_tick += minutes

	var prev_day := current_day()

	while _minutes_accum_since_last_tick >= 60.0:
		_minutes_accum_since_last_tick -= 60.0
		sim_tick.emit(1.0)

	var new_day := current_day()
	if new_day != prev_day:
		sim_day_elapsed.emit(new_day)
		_check_season_change(prev_day, new_day)


func current_day() -> int:
	return int(sim_minutes_total / (60.0 * 24.0))


func current_hour_of_day() -> float:
	return fmod(sim_minutes_total / 60.0, 24.0)


func _check_season_change(prev_day: int, new_day: int) -> void:
	var prev_season_idx := (prev_day / SIM_DAYS_PER_SEASON) % 4
	var new_season_idx := (new_day / SIM_DAYS_PER_SEASON) % 4
	if new_season_idx != prev_season_idx:
		current_season = new_season_idx as Season
		season_changed.emit(current_season)


## Called by SaveManager right after loading, with the real-world seconds elapsed since the
## save was written. Applies a capped, batched catch-up rather than replaying every hour,
## per the plan's "Offline progress" design.
func apply_offline_progress(elapsed_real_seconds: float) -> float:
	var elapsed_sim_minutes: float = elapsed_real_seconds * SIM_MINUTES_PER_REAL_SECOND
	var elapsed_sim_days: float = elapsed_sim_minutes / (60.0 * 24.0)
	var capped_days: float = min(elapsed_sim_days, MAX_OFFLINE_SIM_DAYS)
	sim_minutes_total += capped_days * 24.0 * 60.0
	return capped_days


## Debug/cheat helper (see plan "Verification" — fast-forward for testing slow systems).
## Emits a single large sim_tick batch (safe: WaterChemistry's step functions are
## fraction-of-the-way-there formulas, so one big `hours` converges rather than overshoots)
## instead of looping hour-by-hour, then fires one sim_day_elapsed so events get a chance to roll.
func debug_fast_forward_days(days: float) -> void:
	sim_minutes_total += days * 24.0 * 60.0
	sim_tick.emit(days * 24.0)
	sim_day_elapsed.emit(current_day())
