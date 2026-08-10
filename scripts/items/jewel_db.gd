class_name JewelDb
extends Catalogue
## What the jewelcrafter sells. Four slots, eight paths, and the place the speed
## heavy armour took gets bought back (docs/GDD.md §6.6).
##
## The fifth counter and the last one there will be (docs/SCOPE.md §1: garrison NPCs
## **5**). She cost this file and one row in `Npc.COUNTERS` -- no screen, no new
## mode, no branch in `activate` -- which is the same bill the Lanternkeeper paid
## and the acceptance criterion for `Catalogue` existing at all.
##
## **A slot is bought twice.** First a blank -- an amulet, a ring, a bracelet,
## gold only, because she HAS those -- and then a path, four rungs of it, gold
## and stones. The blank is not ceremony: it is the row that says the slot
## exists before the player has decided what it is for, and it is the cheapest
## thing on the counter so the decision can be deferred without being blocked.
##
## Five states, not four, and one deeper than a forge ladder (SCOPE §1: "×2
## paths, ×5 rungs (base + 4 bought)"). A jewel has no rung 0 you already own,
## so the ladder has to be able to climb from nothing.
##
##   | Slot | Path A | Path B |
##   |---|---|---|
##   | Amulet | Vigor -- max health | Focus -- max stamina |
##   | Ring x2 | Edge -- damage | Swift -- speed |
##   | Bracelet | Ward -- soak | Wind -- stamina regen |
##
## Both rings draw on the same pair on purpose: two Edge rings and one of each
## are different builds, and that is where the variety comes from without a ninth
## path existing.
##
## **The ceiling belongs to the number, not to the faucet.** Ward and the heavy
## plate ladder both move soak; Swift and the same ladder both move speed; Edge
## and the sword's ladder both move damage. Each of those is ONE number with two
## taps on it, and the cap lives on the number -- `K.SOAK_MAX`, `K.EDGE_MAX`,
## the 1.0 in `Game.speed_mult()`. A cap per faucet would let two full faucets
## add up to twice the ceiling, which is the exact arithmetic that made four
## plate pieces at `[0,1,2,3]` a twelve (GDD §6.6).
##
## **Jewel rungs are NOT rationed by `RelicDb.forge_rungs_known()`.** That relic
## pair teaches the SMITH -- the Tally-Ledger and the Imperium Anvil-Plate are
## his ladders' gate, and reusing it here would put her whole counter behind two
## objects she has nothing to do with. Her gate is the stones.

## Slot id -> the blank's display name and what it costs in gold.
##
## The rings are the same price as each other and cheaper than the amulet,
## because the second ring is the purchase that turns "which path" into "which
## MIX" and it should not be the one the player puts off for two runs.
const BLANKS := {
	&"amulet": {"name": "AMULET", "gold": 220},
	&"ring1": {"name": "FIRST RING", "gold": 150},
	&"ring2": {"name": "SECOND RING", "gold": 150},
	&"bracelet": {"name": "BRACELET", "gold": 190},
}

## Slot id -> its two paths, in board order. The second entry of each pair is
## the one that does NOT move a number the smith already moves -- Focus, Swift
## and Wind -- so a player reading down the right-hand column is reading the
## things only she sells.
const PATHS := {
	&"amulet": [&"vigor", &"focus"],
	&"ring1": [&"edge", &"swift"],
	&"ring2": [&"edge", &"swift"],
	&"bracelet": [&"ward", &"wind"],
}

## What each path is called on the counter, and the sentence under it.
##
## Every one names the unit the player FEELS it in -- a heart, a quarter, a
## second of running -- because GDD §6.6's rule for the whole gear loop is that
## a stat needing a tooltip is a stat that does not matter.
const PATH_INFO := {
	&"vigor": {
		"label": "VIGOR", "blurb": "Two rungs is a whole heart more to lose.",
	},
	&"focus": {
		"label": "FOCUS", "blurb": "A longer breath. One more roll before the well is dry.",
	},
	&"edge": {
		"label": "EDGE", "blurb": "The stone bites for you. Four rungs is a quarter-heart a swing.",
	},
	&"swift": {
		"label": "SWIFT", "blurb": "Back on your feet. This is where heavy plate is paid for.",
	},
	&"ward": {
		"label": "WARD", "blurb": "Turns the edge aside before it reaches the plate.",
	},
	&"wind": {
		"label": "WIND", "blurb": "The breath comes back quicker. Nothing else does.",
	},
}

## What rung N costs in stones, index 0 being the FIRST one bought -- the same
## shape as `ShopDb.PARTS` so `Catalogue.crafts()` and the recipe column need no
## special case.
##
## One table for all eight paths. A per-path recipe would be eight tables that
## have to stay in step for no design reason: what the player is choosing here is
## which NUMBER goes up, and pricing Swift above Ward would be a thumb on that
## scale that nothing in the GDD asks for.
##
## The stone arrives at rung 3, not rung 1, so the first half of any path is
## buyable off wire the floor drops and the second half is a thing you go and
## find. Two stones for the top rung against the forge's one core: her ladder is
## a rung longer, and the last rung of a jewel is the single largest permanent
## step in the game.
const PARTS_LADDER := [
	{&"silver_wire": 2},
	{&"silver_wire": 4},
	{&"silver_wire": 6, &"cut_gemstone": 1},
	{&"silver_wire": 8, &"cut_gemstone": 2},
]

## Gold for rung N, index 0 first. Steeper than the forge's geometric ramp on
## purpose: four rungs of Edge is +1 quarter-heart of damage forever, which is a
## third of what the sword's whole ladder buys, and it must not be the cheaper
## way to get there.
const GOLD_LADDER := [90, 180, 340, 620]


static func craft_verb() -> String:
	return "SET"


static func emblem() -> StringName:
	return &"jewel"  ## The stone itself.


## The counter. Four rows on a fresh save -- one blank per slot -- growing to
## eight as blanks are bought and settling back to four as each slot commits.
##
## Never more than eight, which is why this one does not need the smith's
## fifteen-row window (see `TradeScreen._top`). It gets it anyway, because the
## window lives in the screen and the screen is one screen.
static func lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot: StringName in Game.JEWEL_SLOTS:
		if not owns_blank(slot):
			out.append(_blank(slot))
			continue
		var pair: Array = PATHS[slot]
		for path: StringName in pair:
			var track := Game.jewel_track(slot, path)
			# The losing path of a committed slot. Gone rather than greyed, for
			# the reason `ShopDb.stocked` gives: it is a row for a thing that can
			# never happen again.
			if Game.path_closed(track):
				continue
			out.append(_rung(slot, path))
	return out


## Her board as rows: one per slot. Exactly the smith's armour shape and for the
## same reason -- the question is "what goes in the amulet", and Vigor and Focus
## are its two answers, so they belong on one row rather than merely next to each
## other. A slot with no blank in it yet is a one-cell row: there is nothing to
## choose between until the blank exists, and drawing two empty ladders under it
## would be the counter offering a decision it is not offering.
static func groups() -> Array[Dictionary]:
	var rows: Array[Dictionary] = lines()
	var at := {}
	for i in rows.size():
		at[rows[i]["id"]] = i

	var out: Array[Dictionary] = []
	for slot: StringName in Game.JEWEL_SLOTS:
		var title := String(BLANKS[slot]["name"]).to_upper()
		if not owns_blank(slot):
			var i: int = at.get(blank_id(slot), -1)
			if i < 0:
				continue
			out.append({"title": title, "tracks": [{
				"name": "BLANK", "line": i, "owned": 0, "rungs": 1}]})
			continue
		var tracks: Array = []
		for path: StringName in PATHS[slot]:
			var track := Game.jewel_track(slot, path)
			if Game.path_closed(track):
				continue
			tracks.append({
				"name": String(PATH_INFO[path]["label"]),
				"line": int(at.get(track, -1)),
				"owned": Game.jewel_level(track),
				"rungs": K.JEWEL_MAX,
			})
		if not tracks.is_empty():
			out.append({"title": title, "tracks": tracks})
	return out


## Has the player bought the blank for `slot`? Stored as a rung count on the
## slot's own id, which is the same `Game.upgrades` shape everything else uses --
## a `Dictionary[StringName, bool]` of owned blanks would be a second store that
## the save file, the reset and the director all have to learn about.
static func owns_blank(slot: StringName) -> bool:
	return int(Game.upgrades.get(blank_id(slot), 0)) > 0


static func blank_id(slot: StringName) -> StringName:
	return StringName("jewel_%s" % slot)


static func _blank(slot: StringName) -> Dictionary:
	var row: Dictionary = BLANKS[slot]
	return {
		"id": blank_id(slot),
		"label": "%s (BLANK)" % row["name"],
		"cost": int(row["gold"]),
		"parts": {},
		"blurb": "Nothing set in it yet. That is the next decision, not this one.",
		"detail": "opens %s" % _pair_words(slot),
	}


static func _rung(slot: StringName, path: StringName) -> Dictionary:
	var track := Game.jewel_track(slot, path)
	var lvl: int = Game.jewel_level(track)
	var info: Dictionary = PATH_INFO[path]
	var detail := _detail(path, lvl)
	if lvl >= K.JEWEL_MAX:
		detail = "%s  (finished)" % detail
	return {
		"id": track,
		"label": "%s - %s" % [String(BLANKS[slot]["name"]), String(info["label"])],
		"cost": GOLD_LADDER[mini(lvl, GOLD_LADDER.size() - 1)],
		"parts": next_parts(track),
		"blurb": String(info["blurb"]),
		"detail": detail,
	}


## What the number is now and what it would be, in the unit the player feels.
##
## Every arm reads the SAME accessor the game reads -- `Game.armour_soak_exact`,
## `Game.sword_bonus`, `Game.speed_mult` -- and adds one rung's worth to it. A
## table of "+0.5 soak" strings here would be a second copy of `K`'s numbers, and
## the second copy is the one that goes stale (see `ShopDb._forge`).
static func _detail(path: StringName, lvl: int) -> String:
	var last := lvl >= K.JEWEL_MAX
	# One rung's worth, or none when there is no next rung to describe. Keeping
	# the arms below arithmetic rather than branching twice each is what lets
	# `_arrow` be the ONE place that decides how a finished path reads.
	var n := 0.0 if last else 1.0
	match path:
		&"vigor":
			# The half-containers Vigor has bought so far, which `heart_containers()`
			# cannot see: `add_heart_container` only fires on the EVEN rung, so an
			# odd rung is half a heart that has been paid for and is not on the HUD
			# yet. A row that rounded that away would show a purchase doing nothing.
			var h := float(Game.heart_containers()) + 0.5 * float(lvl % 2)
			return _arrow("%.1f", "hearts", h,
				minf(h + K.JEWEL_VIGOR_HEARTS * n, float(K.HEART_MAX)), last)
		&"focus":
			var s := Game.max_stamina
			return _arrow("%.0f", "stamina", s,
				minf(s + K.JEWEL_FOCUS_STAMINA * n, K.STAMINA_MAX), last)
		&"edge":
			# The FLOORED figure, like `sword_bonus()` itself, so the row is the
			# number the swing will actually use. Four rungs is one quarter, and
			# the three that are not paying yet say so by not moving.
			var e := float(Game.sword_bonus())
			var e2 := minf(floorf(_edge_exact() + K.JEWEL_EDGE_DAMAGE * n),
				float(K.EDGE_MAX))
			return _arrow("+%.0f", "quarters a swing", e, e2, last)
		&"swift":
			var m := Game.speed_mult_raw()
			return _arrow("%.1f%%", "speed", clampf(m, 0.5, 1.0) * 100.0,
				clampf(m * pow(K.JEWEL_SWIFT_SPEED, n), 0.5, 1.0) * 100.0, last)
		&"ward":
			var k := Game.armour_soak_exact()
			return _arrow("%.1f", "quarters soaked", k,
				minf(k + K.JEWEL_WARD_SOAK * n, K.SOAK_MAX), last)
		&"wind":
			var r := Game.stamina_regen()
			return _arrow("%.1f", "stamina a second", r,
				r + K.STAMINA_REGEN * K.JEWEL_WIND_REGEN * n, last)
	return ""


## "1.4 -> 1.9 quarters soaked", or just "1.9 quarters soaked" on a finished
## path. Same shape as `ShopDb._forge`'s and the same reason: the unit is named
## ONCE, at the end, because the unit on both sides pushed the shop's blurb past
## the width of the panel.
static func _arrow(fmt: String, noun: String, now: float, then: float,
		last: bool) -> String:
	if last:
		return "%s %s" % [fmt % now, noun]
	return "%s -> %s %s" % [fmt % now, fmt % then, noun]


## Permanent sword damage BEFORE the floor, so `_detail` can add a rung to it and
## floor once. Flooring first and then adding 0.25 would round the same quarter
## away four times over and show a path that never pays.
static func _edge_exact() -> float:
	var e := float(K.EDGE_DAMAGE[Game.forge_level(Game.FORGE_EDGE)])
	for slot: StringName in [&"ring1", &"ring2"]:
		e += K.JEWEL_EDGE_DAMAGE * float(
			Game.jewel_level(Game.jewel_track(slot, &"edge")))
	return e


## "VIGOR or FOCUS", for the blank's line. The blank is the only row on the
## counter that does not name a number, so it has to at least name the question.
static func _pair_words(slot: StringName) -> String:
	var pair: Array = PATHS[slot]
	return "%s or %s" % [
		String(PATH_INFO[pair[0]]["label"]), String(PATH_INFO[pair[1]]["label"])]


## What the NEXT rung of `track` costs in stones, or `{}` for a finished path or
## a blank (which is gold only -- she has the settings, she is selling you one).
static func next_parts(track: StringName) -> Dictionary:
	if _is_blank_id(track):
		return {}
	var owned: int = Game.jewel_level(track)
	if owned >= PARTS_LADDER.size():
		return {}
	return PARTS_LADDER[owned]


static func _is_blank_id(id: StringName) -> bool:
	for slot: StringName in Game.JEWEL_SLOTS:
		if id == blank_id(slot):
			return true
	return false


## How many more of `id` may be bought. A blank is once; a path is
## `K.JEWEL_MAX`, or nothing at all once its sibling has taken a rung.
static func remaining(id: StringName) -> int:
	return maxi(0, cap_of(id) - int(Game.upgrades.get(id, 0)))


static func cap_of(id: StringName) -> int:
	if _is_blank_id(id):
		return 1
	if Game.path_closed(id):
		return 0
	return K.JEWEL_MAX


static func can_buy(line: Dictionary) -> bool:
	var id: StringName = line["id"]
	if remaining(id) == 0:
		return false
	if not Game.can_afford_parts(line.get("parts", {})):
		return false
	return Game.gold >= int(line["cost"])


static func refusal(line: Dictionary) -> String:
	var id: StringName = line["id"]
	if remaining(id) == 0:
		if Game.path_closed(id):
			return "THAT SETTING IS ALREADY CUT"
		return "NOTHING LEFT TO DO THERE"
	var parts: Dictionary = line.get("parts", {})
	for pid: StringName in parts:
		if Game.component_count(pid) < int(parts[pid]):
			var def := ItemDb.get_def(pid)
			var what: String = def.display_name if def != null else String(pid)
			return "NOT ENOUGH %s" % what.to_upper()
	if Game.gold < int(line["cost"]):
		return "NOT ENOUGH GOLD"
	return ""


## Checked-then-charged, exactly as `ShopDb.buy` is: `can_buy` has already said
## the whole bill is payable, so nothing below can leave the player half-charged
## for a rung they did not get.
##
## Vigor and Focus are the only two paths that APPLY anything here. Every other
## rung is read straight off `Game.upgrades` by an accessor the next time
## something asks -- but max health and max stamina are stored numbers rather
## than derived ones (the HUD's hearts, and a bar that has to refill), so their
## rung has to push. That asymmetry is the whole reason this is a match and not
## a comment saying there is nothing to do.
static func buy(line: Dictionary) -> bool:
	if not can_buy(line):
		return false
	var id: StringName = line["id"]
	var parts: Dictionary = line.get("parts", {})
	if not Game.spend_gold(int(line["cost"])):
		return false
	for pid: StringName in parts:
		Game.spend_component(pid, int(parts[pid]))

	Game.upgrades[id] = int(Game.upgrades.get(id, 0)) + 1
	var path := String(id).get_slice("_", 2)
	match path:
		"vigor":
			# Half a container a rung, so four rungs is two hearts and the odd
			# rungs are the ones that feel like nothing. Deliberate: the pair is
			# the purchase, and `add_heart_container` will not add half of one.
			if Game.jewel_level(id) % 2 == 0:
				Game.add_heart_container()
		"focus":
			Game.add_max_stamina(K.JEWEL_FOCUS_STAMINA)
	Bus.gear_forged.emit(id, int(Game.upgrades[id]))
	Bus.item_acquired.emit(id)
	return true
