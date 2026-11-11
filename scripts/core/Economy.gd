extends RefCounted
class_name Economy

const STARTING_CASH := 60

## Species data keeps real-world-ish life-cycle numbers (a guppy matures in ~60 days, breeds
## every ~3 weeks); these scale them down to something a phone play session can actually see.
const BREEDING_PACE := 0.16  ## guppy: 21 -> ~3.4 sim days between batches (~7 real minutes)
const MATURITY_PACE := 0.09  ## guppy: 60 -> ~5.4 sim days from fry to sellable adult (~11 minutes)
## Fish stop breeding once the tank is this full (fraction of max_safe_bioload) — the player
## has to sell to make room, which is the whole economic loop, and it stops runaway floods.
const BREEDING_STOCKING_LIMIT := 0.9


static func breeding_cooldown_days(species: FishSpeciesData) -> float:
	return species.breeding_cooldown_sim_days * BREEDING_PACE


static func maturity_days(species: FishSpeciesData) -> float:
	return maxf(1.0, species.maturity_age_sim_days * MATURITY_PACE)


## Lifetime earnings still needed to reach the next unlock tier (0 when already at the top).
static func earnings_to_next_tier(lifetime_earnings: int) -> int:
	var tier := unlock_tier_for_earnings(lifetime_earnings)
	if tier + 1 >= TIER_THRESHOLDS.size():
		return 0
	return TIER_THRESHOLDS[tier + 1] - lifetime_earnings

## Unlock tiers are gated by cumulative lifetime earnings (simplest possible rule for MVP;
## see plan Section 4 for the Phase-2+ reputation layer).
const TIER_THRESHOLDS := [0, 60, 150, 350, 800, 1800]

## Rough real-world "inches of fish per gallon" style rule of thumb, converted to this game's
## bioload_factor units per liter. Caps PURCHASES (not breeding) — an overstocked tank from
## breeding is still a real, player-fixable emergent problem (sell fry before it gets there),
## not something silently blocked by the game.
const BIOLOAD_PER_LITER := 0.125

static func max_safe_bioload(tank_liters: float) -> float:
	return tank_liters * BIOLOAD_PER_LITER


static func unlock_tier_for_earnings(lifetime_earnings: int) -> int:
	var tier := 0
	for i in range(TIER_THRESHOLDS.size()):
		if lifetime_earnings >= TIER_THRESHOLDS[i]:
			tier = i
	return tier


static func fry_sale_value(species: FishSpeciesData, is_fry: bool) -> int:
	return species.sell_price_fry if is_fry else species.sell_price_adult


## Soft-gate check: can this tank+equipment combination legally host this species at all,
## independent of money? Returns "" when compatible, or a short reason CODE otherwise —
## deliberately not a formatted message, so callers (GameController) can localize it. See
## compatibility_reason_english() below for a quick non-localized version (dev tools/logs only).
static func compatibility_reason_code(species: FishSpeciesData, tank_liters: float, tank_is_saltwater: bool, has_heater: bool, current_bioload: float = 0.0) -> String:
	if species.is_marine and not tank_is_saltwater:
		return "marine_needs_saltwater"
	if not species.is_marine and tank_is_saltwater:
		return "freshwater_in_saltwater"
	if tank_liters < species.min_tank_liters:
		return "tank_too_small"
	if not has_heater and species.temp_min_c > 24.0:
		return "needs_heater"
	if current_bioload + species.bioload_factor > max_safe_bioload(tank_liters):
		return "tank_at_capacity"
	return ""


## English-only convenience wrapper over compatibility_reason_code(), for dev tools/logs
## (e.g. HeadlessSmokeTest) that don't go through GameController's localized alert path.
static func compatibility_reason_english(species: FishSpeciesData, tank_liters: float, tank_temp: float, has_heater: bool, tank_is_saltwater: bool = false, current_bioload: float = 0.0) -> String:
	match compatibility_reason_code(species, tank_liters, tank_is_saltwater, has_heater, current_bioload):
		"marine_needs_saltwater":
			return "%s is a marine species — needs a saltwater/reef tank" % species.display_name
		"freshwater_in_saltwater":
			return "%s is a freshwater species — won't survive in a saltwater tank" % species.display_name
		"tank_too_small":
			return "Tank too small (%d L needed, %d L available)" % [int(species.min_tank_liters), int(tank_liters)]
		"needs_heater":
			return "Needs a heater to reach %.0f-%.0f°C" % [species.temp_min_c, species.temp_max_c]
		"tank_at_capacity":
			return "Tank is at capacity — sell or upgrade before adding more fish."
		_:
			return ""
