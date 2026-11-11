extends RefCounted
class_name Goals
## Static data for the career: its three stages and the missions of each. A mission is
## [id, stage, metric, target, reward]; Progress.metric() says how far along a metric is, and
## its name and description come from Localization ("ms_<id>").

const STAGE_COUNT := 3

const MISSIONS := [
	["first_fish", 1, "fish_bought", 1, 8],
	["first_fry", 1, "fry_born", 1, 10],
	["three_species", 1, "species_owned", 3, 15],
	["clean_water", 1, "water_changes", 3, 10],
	["earn_250", 1, "lifetime_earnings", 250, 20],
	["second_tank", 1, "tanks_owned", 2, 25],

	["first_orders", 2, "orders_done", 3, 40],
	["eight_species", 2, "species_owned", 8, 40],
	["three_tanks", 2, "tanks_owned", 3, 50],
	["sell_fifteen", 2, "fish_sold", 15, 40],
	["breed_four", 2, "species_bred", 4, 60],
	["scrape_glass", 2, "scraped", 15, 30],
	["vacuum_sand", 2, "vacuumed", 15, 30],
	["earn_1500", 2, "lifetime_earnings", 1500, 80],

	["twelve_orders", 3, "orders_done", 12, 150],
	["eighteen_species", 3, "species_owned", 18, 150],
	["five_tanks", 3, "tanks_owned", 5, 150],
	["contest_win", 3, "contests_won", 1, 200],
	["breed_ten", 3, "species_bred", 10, 200],
	["earn_6000", 3, "lifetime_earnings", 6000, 300],
]

## Number of owned species -> one-time bonus. The last one (every species in the game) is
## handled by Progress using the catalog size.
const COLLECTION_MILESTONES := {10: 50, 20: 120, 30: 250}
const COLLECTION_COMPLETE_BONUS := 500

## Reward for breeding a species for the first time in the player's own tank, and for each new
## colour morph of a colour-variable species.
const MORPH_BUCKETS := 4
const MORPH_REWARD := 3


static func missions_of_stage(stage: int) -> Array:
	var out: Array = []
	for m in MISSIONS:
		if m[1] == stage:
			out.append(m)
	return out
