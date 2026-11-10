extends Resource
class_name RandomEventData

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var notification_text: String = ""

## Seasons this event is eligible in. Empty = any season. Values match TimeManager.Season.
@export var trigger_season_tags: Array[int] = []

@export var base_probability_per_day: float = 0.01
## Multiplies base_probability_per_day based on TankController.get_neglect_score() (0..1).
@export var neglect_multiplier_max: float = 5.0

@export var duration_sim_days: float = 2.0

## Effect keys applied to the Tank's state while active, interpreted by TankController.apply_event_effects().
## Example: {"heater_failed": true} or {"ammonia_spike": 1.5} or {"health_penalty_per_day": 2.0}
@export var effects: Dictionary = {}
