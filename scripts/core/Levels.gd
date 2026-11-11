extends RefCounted
class_name Levels
## The player's level, 1..50. Experience is lifetime earnings plus bonus experience (missions,
## new species...). Everything in the shop unlocks at a level: species, equipment and tanks carry
## it in their `unlock_tier` field (the field keeps its old name; it now means "level").

const MAX_LEVEL := 50
const CURVE_FACTOR := 25.0
const CURVE_POWER := 1.75


## Total experience at which `level` is reached (level 1 = 0).
static func xp_for_level(level: int) -> int:
	if level <= 1:
		return 0
	return int(round(CURVE_FACTOR * pow(float(level - 1), CURVE_POWER)))


static func level_for_xp(xp: int) -> int:
	var level := 1
	while level < MAX_LEVEL and xp >= xp_for_level(level + 1):
		level += 1
	return level


## Experience still needed for the next level (0 at the top).
static func xp_to_next(xp: int) -> int:
	var level := level_for_xp(xp)
	if level >= MAX_LEVEL:
		return 0
	return xp_for_level(level + 1) - xp


## 0..1 progress through the current level.
static func level_fraction(xp: int) -> float:
	var level := level_for_xp(xp)
	if level >= MAX_LEVEL:
		return 1.0
	var start := xp_for_level(level)
	var end := xp_for_level(level + 1)
	return clampf(float(xp - start) / float(maxi(1, end - start)), 0.0, 1.0)


## Old saves had five unlock tiers (0-5); they start at about the level those tiers now mean.
static func level_for_legacy_tier(tier: int) -> int:
	return [1, 5, 10, 18, 26, 33][clampi(tier, 0, 5)]
