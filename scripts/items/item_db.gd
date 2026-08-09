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
static func components() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in all():
		if (all()[id] as ItemDef).is_component():
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
