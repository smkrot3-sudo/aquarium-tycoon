extends RefCounted
class_name WaterChemistry

## Pure simulation math, deliberately kept free of any Node/scene dependency so it can be
## unit-tested (e.g. with GUT) without running the 3D scene. All "per hour" functions are
## meant to be called once per sim_tick (one in-game hour) by TankController.

const AMMONIA_DANGER := 0.5     ## ppm
const NITRITE_DANGER := 0.25    ## ppm
const NITRATE_DANGER := 40.0    ## ppm
const OXYGEN_DANGER := 4.0      ## ppm, below this fish get low-oxygen stress


## Filter maturity (0..100) models the real nitrogen cycle: starts at 0 on a new tank,
## climbs slowly once there is a bioload source to feed the bacteria colony, and determines
## how effectively ammonia/nitrite get processed.
static func step_filter_maturity(current_maturity: float, bioload_total: float, filter_bio_capacity: float, hours: float) -> float:
	if bioload_total <= 0.0 or filter_bio_capacity <= 0.0:
		return current_maturity
	var growth_per_hour: float = 1.2 * filter_bio_capacity * clampf(bioload_total, 0.5, 3.0)
	return clampf(current_maturity + growth_per_hour * hours, 0.0, 100.0)


## Ammonia rises from uneaten/digested food (waste_input) and bioload, falls as the filter's
## bacteria colony (scaled by filter_maturity) processes it. Returns both the new ammonia level
## AND the actual amount processed this step (accounting for the floor-at-0 clamp below), since
## step_nitrite needs that exact figure as its own "produced" input — returning it directly here
## avoids the caller having to reconstruct it by duplicating this function's `produced` formula.
static func step_ammonia(current_ammonia: float, waste_input: float, bioload_total: float, filter_flow: float, filter_maturity: float, hours: float) -> Dictionary:
	var produced: float = (waste_input + bioload_total * 0.02) * hours
	var maturity_factor: float = filter_maturity / 100.0
	## clampf(...,0,1): never process more than what's there in one step (matters for the big
	## batched `hours` of an offline catch-up).
	var processed: float = current_ammonia * clampf((filter_flow / 500.0) * maturity_factor * 2.5 * hours, 0.0, 1.0)
	var next_ammonia: float = maxf(0.0, current_ammonia + produced - processed)
	var actual_processed: float = current_ammonia + produced - next_ammonia
	return {"ammonia": next_ammonia, "processed": actual_processed}


## Nitrite is produced from ammonia being processed (first stage of the nitrogen cycle) and
## itself broken down into nitrate by a *matured* colony (nitrite-oxidizing bacteria lag behind
## ammonia-oxidizing bacteria in a real new tank, which is why nitrite often spikes *after* ammonia).
static func step_nitrite(current_nitrite: float, ammonia_processed: float, filter_maturity: float, hours: float) -> float:
	var produced: float = ammonia_processed * 0.8
	var maturity_factor: float = clampf((filter_maturity - 10.0) / 60.0, 0.0, 1.0)
	var processed: float = current_nitrite * clampf(maturity_factor * 0.8 * hours, 0.0, 1.0)
	return maxf(0.0, current_nitrite + produced - processed)


static func step_nitrate(current_nitrate: float, nitrite_processed: float, water_change_reset_fraction: float) -> float:
	var next_value: float = current_nitrate + nitrite_processed * 0.9
	return next_value * (1.0 - water_change_reset_fraction)


## Temperature drifts toward ambient (season-shifted room temp) unless a working heater pulls
## it toward its target. heater_active=false models a failed/missing heater.
## Fraction-of-the-way-there approach (clamped to 1.0) rather than a raw rate*hours delta,
## so a single large batched `hours` (e.g. an offline-progress catch-up) converges toward the
## target instead of overshooting past it.
static func step_temperature(current_temp: float, ambient_temp: float, heater_target: float, heater_power: float, heater_active: bool, hours: float) -> float:
	var ambient_fraction: float = clampf(0.02 * hours, 0.0, 1.0)
	var next_temp: float = current_temp + (ambient_temp - current_temp) * ambient_fraction
	if heater_active:
		var heater_fraction: float = clampf(0.1 * heater_power * hours, 0.0, 1.0)
		next_temp += (heater_target - next_temp) * heater_fraction
	return next_temp


## Real nitrification is acid-producing (it releases H+ ions), so a tank running high ammonia/
## nitrite — i.e. a neglected tank, NOT just an ordinary still-cycling one — drifts toward a
## LOWER effective pH than its nominal baseline; general hardness buffers against that swing
## (soft water "crashes" much more easily than hard water, a well-known real aquarium hazard
## sometimes called "old tank syndrome"). The smoothstep dead zone below means a normal cycling
## tank's everyday ammonia/nitrite blip does nothing — this only engages once levels are
## genuinely elevated, so it reads as a neglect consequence, not a punishing floor every new
## tank starts tripping over. Freshwater only: marine mixes use carbonate-buffered synthetic
## salt and don't realistically crash the same way, so TankController skips this for saltwater.
static func freshwater_ph_baseline(base_ph: float, gh: float, ammonia: float, nitrite: float) -> float:
	var ammonia_pressure: float = smoothstep(0.3, 1.5, ammonia / AMMONIA_DANGER)
	var nitrite_pressure: float = smoothstep(0.3, 1.5, nitrite / NITRITE_DANGER)
	var acid_pressure: float = clampf(ammonia_pressure + nitrite_pressure, 0.0, 2.0)
	var buffer_resistance: float = clampf(gh / 10.0, 0.3, 2.0)
	var ph_drop: float = clampf(acid_pressure / buffer_resistance * 0.9, 0.0, 1.8)
	return base_ph - ph_drop


static func step_drift_toward(current: float, baseline: float, rate: float, hours: float) -> float:
	var fraction: float = clampf(rate * hours, 0.0, 1.0)
	return current + (baseline - current) * fraction


## Warmer water holds less dissolved oxygen (real physical effect); bioload consumes it;
## an air stone / surface agitation replenishes it. Modeled as drift toward a target rather
## than an instant value so a sudden bioload spike doesn't cause an unrealistic O2 cliff.
static func step_oxygen(current_oxygen: float, temperature: float, bioload_total: float, oxygen_boost: float, hours: float) -> float:
	var baseline: float = clampf(9.5 - (temperature - 22.0) * 0.15, 4.0, 9.5)
	var consumption: float = bioload_total * 0.3
	var target: float = clampf(baseline - consumption + oxygen_boost, 1.0, 12.0)
	var fraction: float = clampf(0.15 * hours, 0.0, 1.0)
	return current_oxygen + (target - current_oxygen) * fraction


## Specific gravity (salinity) drifts toward the tank type's target, but evaporation slowly
## concentrates salts the longer it's been since a water change (real reef-keeping requires
## regular top-off/water changes to hold salinity steady) — modeled as a slowly rising
## effective target rather than a hard mechanic, consistent with the other fraction-based steps.
static func step_specific_gravity(current_sg: float, target_sg: float, days_since_water_change: float, hours: float) -> float:
	var evaporation_drift: float = clampf(days_since_water_change * 0.00012, 0.0, 0.01)
	var effective_target: float = target_sg + evaporation_drift
	var fraction: float = clampf(0.02 * hours, 0.0, 1.0)
	return current_sg + (effective_target - current_sg) * fraction


## 0..1 score describing how neglected a tank currently is. Used to scale random-event
## probability (EventManager) without making it the *only* factor (there's always a floor
## "bad luck" chance in the event roll itself).
static func compute_neglect_score(ammonia: float, nitrite: float, days_since_water_change: float, days_since_feeding: float) -> float:
	var water_quality_score: float = clampf(ammonia / AMMONIA_DANGER, 0.0, 1.0) * 0.5 + clampf(nitrite / NITRITE_DANGER, 0.0, 1.0) * 0.5
	var maintenance_score: float = clampf(days_since_water_change / 14.0, 0.0, 1.0)
	var feeding_score: float = clampf(days_since_feeding / 3.0, 0.0, 1.0) * 0.3  ## underfeeding is milder than dirty water
	return clampf(water_quality_score * 0.5 + maintenance_score * 0.4 + feeding_score * 0.1, 0.0, 1.0)
