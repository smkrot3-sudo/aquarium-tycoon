extends Resource
class_name FishSpeciesData

enum Diet { HERBIVORE, OMNIVORE, CARNIVORE, DETRITIVORE }
enum Temperament { PEACEFUL, SEMI_AGGRESSIVE, AGGRESSIVE }

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Latin name, shown in the encyclopedia.
@export var scientific_name: String = ""
## How the fish moves on screen (FishController): "cruiser" (steady laps), "darter" (quick
## schooling bursts), "hoverer" (slow, hangs in place), "bottom" (scoots along the sand),
## "eel" (bottom, very wriggly), "crawler" (walks on the sand), "snail" (creeps), "waddler"
## (clownfish wobble), "seahorse" (drifts upright). Empty = derived from archetype_id.
@export var swim_style: String = ""

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
## Every fish has a sex (FishController.Sex) and breeding always needs one of each — this only
## gates whether a *second* same-species adult is required on top of that (a shoal spawner can
## in principle have its one male and one female be the only two fish of their kind; it still
## needs both). True for every species that actually breeds in this game.
@export var pair_required: bool = true
@export var breeding_cooldown_sim_days: float = 20.0
@export var fry_per_batch_min: int = 5
@export var fry_per_batch_max: int = 20
@export var egg_incubation_sim_days: float = 0.0

@export_group("Individuality")
## Males and females are drawn with a visibly different size/vividness (FishController) — real
## for livebearers (platy/molly/guppy/swordtail: males smaller and flashier, females larger and
## plainer) and for betta (the showy fins/color are specifically a male trait).
@export var dimorphic: bool = false
## Each individual gets its own small random hue shift — real individual-to-individual variety
## in these species is part of what makes keeping them fun (guppy strains, betta colors).
@export var color_variable: bool = false

@export_group("Economy")
@export var base_price: int = 10
@export var sell_price_adult: int = 6
@export var sell_price_fry: int = 1
@export var rarity_tier: int = 0
@export var unlock_tier: int = 0

@export_group("Dev notes")
## Internal-only citation of where real care data came from. Never shown to the player.
@export_multiline var source_note: String = ""


## Gameplay tolerance check. Deliberately judges only what the player can influence:
## temperature (heater, seasons), salinity (water changes) and a pH that has drifted well out of
## range (the neglect-driven "old tank" crash). General hardness is NOT checked — there is no
## in-game way to adjust it, and tap-water GH 10 sat outside several species' ideal range
## (mollies, cherry shrimp), which silently left them permanently stressed. The exact ideal
## ranges are still shown in the guide as care information.
const PH_MARGIN := 0.4
const TEMP_MARGIN := 0.3


func is_within_tolerance(temp_c: float, ph: float, _gh: float, specific_gravity: float = 1.0) -> bool:
	if temp_c < temp_min_c - TEMP_MARGIN or temp_c > temp_max_c + TEMP_MARGIN:
		return false
	if ph < ph_min - PH_MARGIN or ph > ph_max + PH_MARGIN:
		return false
	if is_marine:
		return specific_gravity >= sg_min - 0.0005 and specific_gravity <= sg_max + 0.0005
	return true
