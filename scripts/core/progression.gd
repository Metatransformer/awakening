class_name Prog
extends RefCounted
## The difficulty curve, endless, in one file.
##
## Every number that gets harder or richer as you go deeper is a pure function of
## `Run.level` and lives here. Nothing else is allowed a curve of its own: the
## dungeon asks how many rooms and what to put in them, the enemy asks how much
## health and how hard it hits, the drop table asks how generous to be. Scatter
## those and the game has four difficulty curves that disagree, which is how a
## floor ends up with tougher monsters and worse loot at the same time.
##
## **Bands, not level-scaling.** These functions take the FLOOR, never the
## player. Monsters do not get stronger because you got stronger -- they get
## stronger because you walked further down. That is what makes floor 1 genuinely
## easy on your fiftieth run, and it is what keeps the forge worth buying
## (docs/GDD.md §5). A curve keyed off player power would silently delete both.
##
## **Endless means no ceiling, not no shape.** Health and damage climb linearly
## for ever, because the forge tops out (`K.EDGE_DAMAGE` ends at +3) and the run
## has to end somewhere -- the wall is the point of a roguelite, and where you
## hit it is your score. What does NOT climb for ever is anything that would stop
## the game being readable or fair: the wind-up never compresses past 60%, the
## roster runs out of worse monsters, and the pack size is capped so a room is
## still a fight and not a wall of bodies.

## Floor 1 is the numbers as authored in `Enemy.DEFS`; everything here is
## measured from there.
const FIRST := 1

## Health multiplier per floor after the first. +25% a floor: a skeleton is 6
## quarters on floor 1 and 16 on floor 8, which at a fully forged blade (2 base
## +3 edge) is a 4-hit kill instead of a 2-hit one. [tune]
const HEALTH_PER_FLOOR := 0.25
## One extra quarter-heart of damage every this many floors. Slower than health
## on purpose: monsters that kill you faster stop being readable long before
## monsters that take longer to kill do. [tune]
const FLOORS_PER_DAMAGE := 3
## Wind-ups compress 3% a floor, and never past this. The telegraph is the thing
## that makes a fight fair, so it is the one number with a hard floor -- a wind-up
## you cannot react to is not difficulty, it is a coin flip (see
## `Enemy._tick_windup`). [tune]
const WINDUP_PER_FLOOR := 0.03
const WINDUP_FLOOR := 0.6

## Elites start here, and their share of a room grows until it stops.
const ELITE_FROM := 3
const ELITE_PER_FLOOR := 0.05
const ELITE_MAX := 0.35
## What an elite is. Deliberately a big single-body threat rather than a stat
## nudge: a room of six ordinary monsters and a room of five plus one you can see
## is coming are different rooms, and only the second one is a decision.
const ELITE_HEALTH := 1.8
const ELITE_DAMAGE := 1
const ELITE_SCALE := 1.22


static func health_mult(level: int) -> float:
	return 1.0 + HEALTH_PER_FLOOR * float(maxi(level, FIRST) - FIRST)


static func damage_bonus(level: int) -> int:
	return int(maxi(level, FIRST) - FIRST) / FLOORS_PER_DAMAGE


static func windup_scale(level: int) -> float:
	return maxf(WINDUP_FLOOR,
		1.0 - WINDUP_PER_FLOOR * float(maxi(level, FIRST) - FIRST))


## Monsters per room, as (min, max). Grows slowly and stops at 7: past that a
## room stops being a fight you can read and the separation rule (which is what
## keeps a pack legible at all) runs out of floor to spread them over.
static func pack(level: int) -> Vector2i:
	var l := maxi(level, FIRST) - FIRST
	return Vector2i(mini(2 + l / 2, 5), mini(4 + l, 7))


## Rooms on the floor. More rooms is more run before the stair, which is the
## main way a deep floor costs more than a shallow one.
static func rooms(level: int) -> int:
	return mini(6 + (maxi(level, FIRST) - FIRST) / 2, 12)


## How dangerous this room is allowed to be: the floor, plus how far into the
## floor you have walked. One number, so the roster and the elite roll agree
## about what "deep" means, and the deepest room of floor 1 overlaps with the
## first room of floor 2 rather than jumping.
static func band(level: int, room_dist: int) -> int:
	return maxi(level, FIRST) + maxi(room_dist, 0) / 2


static func elite_chance(level: int) -> float:
	if level < ELITE_FROM:
		return 0.0
	return minf(ELITE_PER_FLOOR * float(level - ELITE_FROM + 1), ELITE_MAX)


## Extra drop rolls off a body, beyond the first. Deeper bodies are worth more to
## sweep, which is what stops a deep floor from being all cost and no reward --
## the extraction fee scales with what you are carrying, so if the carrying did
## not scale too, going deeper would be strictly worse.
static func drop_rolls(level: int) -> int:
	return 1 + (maxi(level, FIRST) - FIRST) / 3


## Chest picks. The deepest room's chest is always worth the walk.
static func chest_picks(level: int, deepest: bool) -> int:
	var base := (3 if deepest else 2) + (maxi(level, FIRST) - FIRST) / 3
	return mini(base, 7)


## How much the rare end of a drop table is weighted, 0 on floor 1 and climbing.
## Applied by `ItemDb.enemy_drops` rather than here, because the tables are the
## catalogue's business and the curve is this file's.
static func rarity_lift(level: int) -> float:
	return float(maxi(level, FIRST) - FIRST) * 0.35


## The place you are going down into. One dungeon today (docs/GDD.md §8), so one
## name, and it lives here beside the curve because the curve is the only other
## thing in the project that knows what a "floor" is.
##
## It is a NAME and not a number for the reason the run report is a receipt and
## not a score: "FLOOR 7" is a depth reading, and "THE SUNKEN CUT, LEVEL 7" is
## somewhere you went. Uppercase because PixelFont has no lowercase (see its
## header) -- do not write it in title case anywhere the HUD will draw it.
const NAME := "THE SUNKEN CUT"


## The short line, for the places that already sit inside dungeon context and
## would only be repeating the name: the run report's header, a debug print.
static func label(level: int) -> String:
	return "LEVEL %d" % maxi(level, FIRST)


## The whole thing, for the two places that ANNOUNCE a floor rather than report
## one -- the loading card and the HUD's top-left card. Two spaces between the
## name and the number: PixelFont is monospaced with a 1 px track, so a single
## space reads as a slightly wide letter gap rather than a break between two
## thoughts.
static func full_label(level: int) -> String:
	return "%s  %s" % [NAME, label(level)]
