extends Resource
class_name FishSpeciesData

enum Diet { HERBIVORE, OMNIVORE, CARNIVORE, DETRITIVORE }
enum Temperament { PEACEFUL, SEMI_AGGRESSIVE, AGGRESSIVE }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

## Visual archetype used for procedural fallback shape/sizing (FishShapeBuilder2D).
## One of: "schooler", "livebearer", "labyrinth", "bottom_dweller", "invertebrate".
@export var archetype_id: String = "livebearer"
@export var palette_color: Color = Color.WHITE
@export var pattern_id: String = "solid"
@export var fin_variant_id: String = "default"

@export_group("Water requirements")
@export var temp_min_c: float = 22.0
@export var temp_max_c: float = 28.0
@export var ph_min: float = 6.5
@export var ph_max: float = 7.5
@export var gh_min: float = 5.0
@export var gh_max: float = 20.0
@export var min_tank_liters: float = 20.0
## Marine species need a saltwater tank (TankController.TankType.SALTWATER) and are checked
## against specific gravity (sg_min/sg_max) and ph_min/ph_max instead of gh.
@export var is_marine: bool = false
@export var sg_min: float = 1.020
@export var sg_max: float = 1.026

@export_group("Behavior")
@export var diet_type: Diet = Diet.OMNIVORE
@export var bioload_factor: float = 1.0
@export var temperament: Temperament = Temperament.PEACEFUL
@export var compatibility_tags: Array[String] = []
@export var schooling_min_group: int = 1
## 0 = very disease-prone (e.g. neon tetra disease susceptibility), 1 = very hardy.
@export_range(0.0, 1.0) var disease_resistance: float = 0.5

@export_group("Growth and life cycle")
@export var max_size_cm: float = 5.0
@export var growth_rate_cm_per_sim_day: float = 0.05
@export var maturity_age_sim_days: float = 60.0
@export var lifespan_sim_days: float = 730.0

@export_group("Breeding")
## Livebearers (guppy, platy, molly, shrimp...) give birth to free-swimming fry directly.
## Egg-layers (is_livebearer = false) instead lay a batch that sits in the tank for
## egg_incubation_sim_days before hatching into fry (see TankController.schedule_egg_batch).
@export var is_livebearer: bool = true
@export var pair_required: bool = true
@export var breeding_cooldown_sim_days: float = 20.0
@export var fry_per_batch_min: int = 5
@export var fry_per_batch_max: int = 20
@export var egg_incubation_sim_days: float = 0.0

@export_group("Economy")
@export var base_price: int = 10
@export var sell_price_adult: int = 6
@export var sell_price_fry: int = 1
@export var rarity_tier: int = 0
@export var unlock_tier: int = 0

@export_group("Dev notes")
## Internal-only citation of where real care data came from. Never shown to the player.
@export_multiline var source_note: String = ""


func is_within_tolerance(temp_c: float, ph: float, gh: float, specific_gravity: float = 1.0) -> bool:
	if temp_c < temp_min_c or temp_c > temp_max_c:
		return false
	if is_marine:
		return specific_gravity >= sg_min and specific_gravity <= sg_max \
			and ph >= ph_min and ph <= ph_max
	return ph >= ph_min and ph <= ph_max and gh >= gh_min and gh <= gh_max
