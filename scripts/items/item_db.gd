class_name ItemDb
extends RefCounted
## The catalogue. Every ingredient, and the tables that decide what drops.
##
## Values are spread across roughly one order of magnitude (4 to 90) on purpose.
## The extraction decision is only interesting when the bag's worth is uncertain,
## and it is only uncertain when a single rare drop can outweigh a full run of
## common ones. A flat table turns "do I leave now?" into arithmetic.

## id -> ItemDef. Built once, on first access.
static var _items: Dictionary = {}


static func all() -> Dictionary:
	if _items.is_empty():
		_build()
	return _items


static func get_def(id: StringName) -> ItemDef:
	return all().get(id, null) as ItemDef


## Is `id` something the forge eats? Asked by `Run.extract()` when it sorts the
## bag and by every screen that has to mark a row. One reader of `kind`, so a
## caller can never disagree with the catalogue about what a thing is for.
static func is_component(id: StringName) -> bool:
	var d := get_def(id)
	return d != null and d.is_component()


## Every component id, in catalogue order. The forge screen and the pouch both
## want a stable list, and neither should hardcode one.
##
## `bench` narrows it to one counter's materials (`ItemDef.BENCH_FORGE` /
## `BENCH_ALCHEMY` / `BENCH_JEWEL`); the default is everything, because the pouch draws one
## workbench and the bag never cared which counter a thing was for.
static func components(bench: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in all():
		var d := all()[id] as ItemDef
		if d.is_component() and (bench == &"" or d.bench == bench):
			out.append(id)
	return out


static func _add(d: ItemDef) -> void:
	_items[d.id] = d


static func _build() -> void:
	const C := ItemDef.Rarity.COMMON
	const U := ItemDef.Rarity.UNCOMMON
	const R := ItemDef.Rarity.RARE

	_add(ItemDef.make(&"bone_shard", "Bone Shard", 4, C, 20,
		Color(0.86, 0.84, 0.74), "Splinters of something that used to walk."))
	_add(ItemDef.make(&"rot_moss", "Rot Moss", 6, C, 20,
		Color(0.42, 0.55, 0.30), "Grows only where the air does not move."))
	_add(ItemDef.make(&"cracked_flint", "Cracked Flint", 8, C, 20,
		Color(0.48, 0.50, 0.56), "Still sparks. Barely."))
	_add(ItemDef.make(&"grave_wax", "Grave Wax", 11, C, 15,
		Color(0.85, 0.79, 0.55), "Burns with a smell you will remember."))

	_add(ItemDef.make(&"iron_scrap", "Iron Scrap", 18, U, 12,
		Color(0.62, 0.60, 0.58), "Someone's armour, once. Smiths pay for it."))
	_add(ItemDef.make(&"ghost_silk", "Ghost Silk", 24, U, 12,
		Color(0.72, 0.78, 0.86), "Weightless. Cold to hold."))
	_add(ItemDef.make(&"ember_gland", "Ember Gland", 32, U, 10,
		Color(0.86, 0.42, 0.20), "Warm hours after the thing that grew it died."))

	_add(ItemDef.make(&"deep_amber", "Deep Amber", 55, R, 6,
		Color(0.93, 0.66, 0.16), "There is a shape inside. Do not look long."))
	_add(ItemDef.make(&"void_pearl", "Void Pearl", 78, R, 4,
		Color(0.55, 0.38, 0.78), "Light falls in and does not come back."))
	_add(ItemDef.make(&"kings_signet", "King's Signet", 90, R, 2,
		Color(0.95, 0.86, 0.42), "The Lower Worlds had a king. This is all that is left."))

	# --- Pot gems: merchandise, not jewelcrafting material -------------------
	# Ambient urn placers are their only source. `make` is load-bearing: these
	# occupy the Run bag and sell for gold instead of banking at the jewel bench.
	_add(ItemDef.make(&"moss_agate", "Moss Agate", 8, C, 12,
		Color(0.36, 0.70, 0.45), "Clouded green stone. Common, but easy to trade."))
	_add(ItemDef.make(&"tide_sapphire", "Tide Sapphire", 24, U, 8,
		Color(0.30, 0.56, 0.86), "Blue as deep water under a torch."))
	_add(ItemDef.make(&"blood_ruby", "Blood Ruby", 46, R, 4,
		Color(0.84, 0.24, 0.34), "A small red cut with no tool marks on it."))

	# --- Components: what the forge eats -------------------------------------
	# Four, not five, and deliberately NOT one per upgrade track. A component
	# only one track wanted would make every drop either a jackpot or litter;
	# each of these feeds at least two ladders, so a pull is always worth
	# carrying and the question is which one you feed with it.
	#
	# Priced ABOVE the ingredient of the same rarity, and the extraction fee
	# taxes them like everything else -- carrying the forge home is not free,
	# which is what keeps the bag a decision rather than a checklist.
	_add(ItemDef.part(&"whetstone_grit", "Whetstone Grit", 14, C, 8,
		Color(0.62, 0.66, 0.72), "Swarf off a stone that has sharpened better men."))
	_add(ItemDef.part(&"riveted_plate", "Riveted Plate", 22, U, 6,
		Color(0.56, 0.54, 0.50), "Cut from a breastplate. The rivets held; he did not."))
	_add(ItemDef.part(&"tension_coil", "Tension Coil", 26, U, 6,
		Color(0.78, 0.62, 0.30), "Still wants to spring. Do not hold it loosely."))
	_add(ItemDef.part(&"cold_iron_core", "Cold Iron Core", 100, R, 2,
		Color(0.74, 0.82, 0.92), "Ice to the hand hours after the forge. Nothing else finishes a piece."))

	# --- Materials: what the alchemist eats ----------------------------------
	# The same kind as the four above and the same rules -- banked on the way
	# home, lost with the bag, never sold -- because they pose the same DECISION:
	# a slot spent on cullet is a slot not spent on a pearl. What differs is the
	# counter they walk to, which is a word on the pouch and nothing else.
	#
	# Glass is deliberately the commonest thing here, because a bottle you cannot
	# make is a bottle you never fill and the whole point of the alchemist is the
	# four slots. The scarcity that matters lives one line down, in the dew.
	_add(ItemDef.brew(&"fired_cullet", "Fired Cullet", 12, C, 8,
		Color(0.56, 0.74, 0.70), "Glass that has already been something once."))
	_add(ItemDef.brew(&"bitter_root", "Bitter Root", 16, C, 8,
		Color(0.48, 0.44, 0.26), "Pulls up hard and tastes worse. Keeps a man upright."))
	_add(ItemDef.brew(&"ash_resin", "Ash Resin", 25, U, 6,
		Color(0.74, 0.50, 0.32), "Weeps out of burnt wood for years afterwards."))
	# Chests only, exactly like the Cold Iron Core and for the same reason: the
	# FOURTH bottle is an event. If dew fell off bodies the last slot would be a
	# grind rather than a find, and grinding is what the depth curve exists to
	# beat (docs/METAGAME.md §7.1).
	_add(ItemDef.brew(&"mourning_dew", "Mourning Dew", 85, R, 2,
		Color(0.66, 0.80, 0.94), "Collected off stone that never sees a morning."))

	# --- Stones: what the jewelcrafter eats ----------------------------------
	# TWO, against the forge's four and the alchemist's four, because her ladders
	# are the shallowest thing in the game to want a component at all: eight
	# tracks that only ever climb from a blank you already bought. A third stone
	# would be a third thing to find for a counter whose whole offer is "spend the
	# speed you lost".
	#
	# No id is shared with the other two benches, and that is a rule rather than a
	# coincidence -- see `ItemDef.bench`. The competition she creates is for the
	# BAG SLOT, which is the only competition this economy actually needs.
	_add(ItemDef.gem(&"silver_wire", "Silver Wire", 15, C, 8,
		Color(0.80, 0.84, 0.90), "Drawn thin enough to hold a stone and nothing else."))
	# Chests only, like the Cold Iron Core and the Mourning Dew, and for the third
	# time the same reason: the top of a ladder is an EVENT. Rarer than the core
	# because two of them finish a jewel and one finishes a ladder.
	_add(ItemDef.gem(&"cut_gemstone", "Cut Gemstone", 95, R, 3,
		Color(0.72, 0.46, 0.86), "Faceted before the Sundering. Nobody has cut one since."))

	# --- The twelve relics ---------------------------------------------------
	# Built from `RelicDb.RELICS`, never typed out again. `Run.collect` refuses an
	# id this catalogue has never heard of, so WITHOUT a row here a relic cannot
	# be picked up at all -- but everything else about one (where it is, what it
	# unlocks, who it is handed to) belongs to `RelicDb`, and a second hand-written
	# list here is a thirteenth relic waiting to happen.
	for row in RelicDb.RELICS:
		_add(_relic(row))

	# --- The twelve Echoes ---------------------------------------------------
	# Built from `EchoDb.ECHOES`, never typed out again, for exactly the reason
	# the relics are: `Run.collect` refuses an id this catalogue has never heard
	# of, so WITHOUT a row here an Echo cannot be picked up at all -- and a second
	# hand-written list here is a thirteenth Echo waiting to happen.
	for id in EchoDb.all():
		_add(_echo(id))


## What the ROPE charges to haul one relic up, and it is NOT a sale price.
##
## GDD §3 says a relic "is charged the extraction fee", and the fee is a share of
## what the bag is worth -- so a relic worth nothing would ride home free and that
## sentence would be a lie. This is that weight. The vendor never pays it:
## `Run.line_value` answers 0 for a relic and `Run.sell` / `Run.sell_all` refuse
## one outright (GDD §6.3, "no relic sells").
##
## 200 against a good run's 250-450 gold of ingredients, so carrying the relic out
## adds about 50 gold to the toll -- a real line on the bill and nowhere near the
## price of abandoning the run. **Uniform across all twelve on purpose.** A
## per-relic toll would be a hidden ranking of which unique is worth the trip, and
## there is no such ranking: the list is twelve things, not a ladder. [tune]
const RELIC_TOLL := 200


## One relic as a thing the bag can hold. Every column is the same for all
## twelve, which is the point: a relic is not a better or worse relic.
##
## `stack` is 1 -- a relic always costs a whole slot, and that slot is the
## sharpest form of the one question (docs/GDD.md §3).
##
## The tier is index 3 of `Pal.RARITY`, ARCANE, which the styleguide reserves for
## legendary and rations at "twice a run at most". Twelve objects in the entire
## game is exactly what that ration was written for, and it is the one colour on
## the board no ingredient can ever wear -- so a violet mote on the floor means
## one thing and nothing else. `ItemDef.Rarity` names three tiers and this is the
## fourth; the cast is deliberate, `Pal.rarity_color` clamps to it, and
## `ItemDef.rarity_name()` has no arm for it yet (it reports "Common" in the
## pouch's caption -- one line, in a file this change does not own).
## **It arrives BROKEN** (GDD §6.4). The name in the bag is `Broken Tally-Ledger`
## and the description is *Take it to the smith* -- both built by `RelicDb` from
## the row's `home` and its place in `WORKING_RELICS`, because the naming rule is
## the table's business and this file only holds the bag's copy of it.
##
## Static, and it can be: a relic is in the bag only while it is broken. Donating
## it is what takes it out (`Run` drops the held flag, `RelicDb.buy` sets the
## donated one), so there is no state in which a working relic wants a different
## row here.
static func _relic(row: Dictionary) -> ItemDef:
	const LEGENDARY := 3
	var id: StringName = row["id"]
	var d := ItemDef.make(id, RelicDb.arrival_name(id), RELIC_TOLL,
		ItemDef.Rarity.RARE, 1, Pal.ARCANE,
		"%s It does nothing until then, and the rope charges for it anyway. %s"
			% [RelicDb.arrival_hint(id), row["detail"]])
	d.rarity = LEGENDARY as ItemDef.Rarity
	return d


## One Echo as a thing the bag can hold. Every column is the same for all twelve,
## and every one of them is `docs/PUZZLES.md` §6 said as a number:
##
##   `value: 0`  — *it is worth 0 gold. It cannot be sold, so it does not raise
##                 the extraction fee.* `base_value()` adds nothing for it, so
##                 `extract_cost()` is untouched with no fee code knowing Echoes
##                 exist. `Run.line_value` therefore draws 0 and `sell()` pays 0.
##   `stack: 1`  — *an Echo costs a bag slot, and that is the only thing it
##                 costs.* One slot, always, exactly like a relic.
##
## CYAN, and it is the one deliberate exception to `docs/STYLEGUIDE.md` §2's
## reservation of that hue for the way out -- because an Echo IS the way out
## working better. Every one of the twelve bends how fast you go or how far you
## get back, and a pale blue mote on a pedestal is not going to be mistaken for
## an extraction node standing three rooms away. If it ever is, the fix is the
## pedestal's own light, not a second saturated colour on the board.
static func _echo(id: StringName) -> ItemDef:
	var d := ItemDef.make(id, EchoDb.name_of(id), 0,
		ItemDef.Rarity.RARE, 1, Pal.CYAN,
		"%s No coin buys it and it does not last the night."
			% EchoDb.line_of(id))
	return d


# --- Drop tables ------------------------------------------------------------

## Weighted table for an ordinary enemy. Weights are relative, not percentages,
## so adding an entry never requires rebalancing the others.
## Components are ~15% of what a body leaves, and the rarest one is not on this
## table at all. A Cold Iron Core has to be found, not farmed: if grinding the
## first room could finish a ladder, the forge would price patience instead of
## depth, and depth is the thing the whole game is about.
const ENEMY_DROPS := {
	&"bone_shard": 34,
	&"rot_moss": 26,
	&"cracked_flint": 18,
	&"grave_wax": 12,
	&"iron_scrap": 7,
	&"ghost_silk": 3,
	&"whetstone_grit": 10,
	&"riveted_plate": 4,
	&"tension_coil": 3,
	# The alchemist's share of a body. Cullet outweighs root because glass is the
	# gate on the SLOT and root is the gate on one draught -- being short of
	# bottles is the state that makes the whole counter pointless.
	&"fired_cullet": 9,
	&"bitter_root": 6,
	&"ash_resin": 3,
	# The jewelcrafter's share. Wire only -- a cut stone never falls off a body.
	&"silver_wire": 5,
}

## Chests are the reason to explore off the critical path, so their floor is
## higher and their ceiling is where the run-defining drops live.
const CHEST_DROPS := {
	&"grave_wax": 20,
	&"iron_scrap": 24,
	&"ghost_silk": 20,
	&"ember_gland": 16,
	&"deep_amber": 12,
	&"void_pearl": 6,
	&"kings_signet": 2,
	&"whetstone_grit": 8,
	&"riveted_plate": 10,
	&"tension_coil": 9,
	# ~2% a chest. Two or three floors of opening everything for the piece that
	# finishes ANY ladder -- which is why a chest is worth the detour even when
	# the bag is nearly full.
	&"cold_iron_core": 3,
	&"fired_cullet": 7,
	&"bitter_root": 6,
	&"ash_resin": 8,
	# The fourth bottle, and nothing else on the board wants it. Rarer than the
	# core: the core finishes a ladder you were already climbing, the dew opens a
	# slot you have never had.
	&"mourning_dew": 2,
	&"silver_wire": 11,
	# Rarer than the core (3) and on a par with the dew: two of these finish one
	# jewel path, and one core finishes a whole ladder.
	&"cut_gemstone": 2,
}


## Pick one id from a weight table. `rng` is passed in so a seeded run is
## reproducible -- a roguelike that cannot replay a seed cannot be debugged.
static func roll(table: Dictionary, rng: RandomNumberGenerator) -> StringName:
	var total := 0
	for w: int in table.values():
		total += w
	if total <= 0:
		return &""
	var pick := rng.randi_range(1, total)
	for id: StringName in table:
		pick -= int(table[id])
		if pick <= 0:
			return id
	return table.keys().back()


## The enemy table as it stands on floor `level`, and the chest table likewise.
##
## The tables above are floor 1. Deeper floors do not get a different table, they
## get the SAME table flattened toward uniform -- see `_lift`. Two tables per
## depth band would be two things to keep in sync and a cliff at every boundary;
## one table with a dial is a curve.
static func enemy_drops(level: int) -> Dictionary:
	return _lift(ENEMY_DROPS, level)


static func chest_drops(level: int) -> Dictionary:
	return _lift(CHEST_DROPS, level)


## Reweight a drop table toward its rare end, by how deep you are.
##
## `w * pow(top / w, k)` leaves the commonest entry untouched and lifts every
## other one in proportion to how rare it already was, so the shape of the table
## is preserved and only its steepness changes. At k = 0 it is the authored
## table; as k grows it flattens toward uniform. It never REORDERS anything --
## a Cold Iron Core is still the rarest thing on the chest table on floor 40 --
## because "deeper is richer" must not turn into "deeper hands you the ladder".
##
## k is capped, which is what keeps an endless game from converging on a table
## where everything is equally likely and the rare drops stop being rare.
static func _lift(table: Dictionary, level: int) -> Dictionary:
	var k := minf(Prog.rarity_lift(level) * 0.12, 0.6)
	if k <= 0.0:
		return table

	var top := 1.0
	for w: int in table.values():
		top = maxf(top, float(w))

	var out: Dictionary = {}
	for id: StringName in table:
		var w := maxf(float(table[id]), 1.0)
		# Rounded up, so the rarest entries cannot be lifted by less than one
		# whole weight unit and quietly stay exactly where they were.
		out[id] = int(ceilf(w * pow(top / w, k)))
	return out
