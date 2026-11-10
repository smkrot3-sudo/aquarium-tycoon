extends Resource
class_name MedicationData
## A course of treatment dosed into the whole tank (real meds are tank-wide, not per-fish).
## While active, sick fish recover much faster; see TankController.administer_medication and
## FishController's disease recovery roll.

@export var id: String = ""
@export var display_name: String = ""
@export var price: int = 10
@export var unlock_tier: int = 0
@export var treatment_duration_sim_days: float = 5.0
@export var recovery_chance_per_day: float = 0.35
