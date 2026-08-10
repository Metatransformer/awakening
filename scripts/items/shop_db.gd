class_name ShopDb
extends Catalogue
## What the smith sells. Up to fifteen lines, and every one of them changes a
## number the player can feel inside one run.
##
## "Up to" because the counter both GROWS and SHRINKS. Three lines are gated on
## ownership (see GATED_BY) -- a fresh save is offered twelve, and the bow's two
## and the hookshot's one appear when those items are found, which is the smith's
## half of docs/GDD.md §5.2. Against that, eight of the twelve are the armour's
## four pieces offered twice, and each piece loses its second row the moment it
## commits (GDD §6.6), so a hero who has answered all four questions is back down
## to a board of eleven.
##
## A `Catalogue`, which is the whole of what `TradeScreen` knows about it -- see
## that file for the contract and for why a third counter is a subclass rather
## than a second screen.
##
## Two shapes of line, on one list on purpose:
##
##  * **Stock** -- arrows, a bag slot, a heart container. Gold only. These are
##    things the smith HAS, and money is the whole transaction.
##  * **Forge** -- the twelve gear ladders (docs/METAGAME.md §6.5). Gold AND
##    components, because the smith cannot make a longer chain out of coin. The
##    rung sits in `Game.upgrades` and the gear reads it back through the
##    accessors on `Game`; nothing here knows what an arc or a draw time is.
##  * **Reforge** -- the undo, one cell per committed armour piece, and the only
##    line on any counter that costs nothing and gives something back (GDD §6.6,
##    added 2026-08-10). It is a held press, not a tap, and `Catalogue.crafts`
##    explains why a free line is the most irreversible one on the board.
##
## One list rather than two screens because the player is answering one question
## -- what is the best thing I can afford right now -- and splitting the answer
## across two menus makes them hold half of it in their head.
##
## Prices are set against the drop tables rather than against each other: a good
## run extracts with roughly 250-450 gold of ingredients, so the cheap lines are
## affordable after one run and the expensive ones after two or three. The
## component costs are the second dial, and they are the slower one: gold you can
## grind, but a Cold Iron Core has to be found.
##
## Everything here is PERMANENT and lives on `Game`, because the only things
## worth buying with money that survives death are things that also survive it.

## Lines that DO NOT EXIST until the player owns the thing they are about.
##
## The bow and the hookshot are boss drops now rather than the [test] starter kit
## they used to be (docs/SCOPE.md M1, `Game.STARTER_KIT`), so their ladders spent
## the whole early game as rows for weapons the player had never seen. Absent,
## not greyed out: a greyed row still tells you a bow exists, still costs a line
## of the counter, and still has to be scrolled past. A ladder for a weapon you
## have not found is a spoiler and a dead row, and the smith has no reason to
## offer to restring something you are not carrying.
##
## `arrows` follows the bow for the reason `Game.armament_owned(&"arrow")` does:
## ammunition you cannot fire is a slot that lies.
##
## A table rather than a branch, because the acceptance test for the next gated
## line has to be "one row in a dictionary". StringName values only, so this is
## a genuine constant expression — a `class_name` or another class's enum in here
## would not be (CLAUDE.md §3).
const GATED_BY := {
	&"arrows": &"bow",
	&"string": &"bow",
	&"chain": &"hookshot",
}

## Purchases you can only make so many times, and how many. Every forge track is
## capped at K.FORGE_MAX because that is how many rungs its ladder has -- the
## limit is not a balance choice here, it is the length of the table.
##
## The eight plate tracks are spelled out rather than generated from
## `Game.PLATE_TRACKS`, because a `const` initialiser cannot run a loop and a
## `static var` one would touch the `Game` autoload at class-load time, which is
## before autoloads exist. The cost of spelling them is a typo that reads as "the
## smith will sell that one forever"; `forge_loop.gd` beat P0 asserts every id in
## `Game.PLATE_TRACKS` appears here, which is where that typo gets caught.
const LIMITS := {
	&"bag_slot": 4,
	&"heart": 3,
	&"edge": K.FORGE_MAX,
	&"guard": K.FORGE_MAX,
	&"string": K.FORGE_MAX,
	&"chain": K.FORGE_MAX,
	&"plate_chest_heavy": K.FORGE_MAX,
	&"plate_chest_light": K.FORGE_MAX,
	&"plate_legs_heavy": K.FORGE_MAX,
	&"plate_legs_light": K.FORGE_MAX,
	&"plate_arms_heavy": K.FORGE_MAX,
	&"plate_arms_light": K.FORGE_MAX,
	&"plate_boots_heavy": K.FORGE_MAX,
	&"plate_boots_light": K.FORGE_MAX,
}

## track id -> the recipe for each rung, in order. Index 0 is what rung ONE
## costs, so `PARTS[track][owned]` is always "what the next one costs".
##
## Read the columns, not the rows: grit is the cheap, common tax on the two
## melee ladders; plate is armour's spine and the shield's second ingredient;
## coil belongs to the two things under tension, the bow and the chain. **The top
## rung of every ladder that has a top wants a Cold Iron Core**, which is the
## pacing gate -- the top of any ladder is an event, and which ladder gets the
## core is the only genuinely hard spending decision the smith ever poses.
##
## The split raised the core bill for the Chord Ending (GDD §8, every ladder at
## rung 3) from five to eight, because four heavy pieces each finish on one. That
## is deliberate: it is the completionist ending, and it is also the reason light
## finishes on coil instead -- an all-light hero never queues for a core at all.
##
## **The armour is eight tracks reading two recipes.** A piece's PATH is the
## price, never which piece it is: a heavy boot and a heavy chest cost the same,
## because the difference the player is buying is soak-versus-speed and pricing
## the chest higher would quietly make one of the four pieces the "real" one.
## Light is cheaper in components and asks for no Cold Iron Core at all (GDD
## §6.6) -- the core is the pacing gate, and light's whole offer is that it does
## not make you wait for one.
const PLATE_HEAVY_PARTS := [
	{&"riveted_plate": 2},
	{&"riveted_plate": 4, &"whetstone_grit": 2},
	{&"riveted_plate": 6, &"cold_iron_core": 1},
]
const PLATE_LIGHT_PARTS := [
	{&"riveted_plate": 1},
	{&"riveted_plate": 2, &"tension_coil": 1},
	{&"riveted_plate": 4, &"tension_coil": 2},
]

const PARTS := {
	&"edge": [
		{&"whetstone_grit": 3},
		{&"whetstone_grit": 6, &"riveted_plate": 2},
		{&"whetstone_grit": 10, &"cold_iron_core": 1},
	],
	&"plate_chest_heavy": PLATE_HEAVY_PARTS,
	&"plate_chest_light": PLATE_LIGHT_PARTS,
	&"plate_legs_heavy": PLATE_HEAVY_PARTS,
	&"plate_legs_light": PLATE_LIGHT_PARTS,
	&"plate_arms_heavy": PLATE_HEAVY_PARTS,
	&"plate_arms_light": PLATE_LIGHT_PARTS,
	&"plate_boots_heavy": PLATE_HEAVY_PARTS,
	&"plate_boots_light": PLATE_LIGHT_PARTS,
	&"guard": [
		{&"riveted_plate": 2, &"whetstone_grit": 2},
		{&"riveted_plate": 5, &"whetstone_grit": 4},
		{&"riveted_plate": 8, &"cold_iron_core": 1},
	],
	&"string": [
		{&"tension_coil": 3},
		{&"tension_coil": 6, &"whetstone_grit": 2},
		{&"tension_coil": 10, &"cold_iron_core": 1},
	],
	&"chain": [
		{&"tension_coil": 4},
		{&"tension_coil": 8, &"riveted_plate": 3},
		{&"tension_coil": 12, &"cold_iron_core": 1},
	],
}


## The prefix a REFORGE line's id carries, so `buy()` can tell one from a rung
## without a table of four more ids. `reforge_chest` is not a track and never
## appears in `Game.upgrades` -- it is a verb wearing an id, because `TradeScreen`
## addresses everything on a counter by one.
const REFORGE := "reforge_"


## One catalogue line. `cost` grows with `Game.upgrades[id]` for the repeatables,
## so the third sharpening is not the same price as the first, and `parts` is the
## component half of the same bill -- empty for anything the smith just has.
##
## `detail` is the sentence that says what the rung DOES, in the unit the player
## feels it in, with the number they have now and the number they would have.
## A line that only says "SHARPEN BLADE" is asking them to take it on faith.
static func craft_verb() -> String:
	return "FORGE"


## The counter, filtered by what the player owns. One list, built whole and then
## sieved through `stocked()` — a table the caller filters, rather than five
## `if`s scattered through the literal below, so the board is still readable as
## the board.
static func lines() -> Array[Dictionary]:
	var board: Array[Dictionary] = _board()
	var shown: Array[Dictionary] = []
	for line in board:
		if stocked(line["id"]):
			shown.append(line)
	# After the sieve, because a reforge line is not stock and is not gated on
	# ownership -- it exists exactly when there is something in the fire to put
	# back, which `committed_path` is the whole test for.
	for piece: StringName in Game.PLATE_PIECES:
		var line := _reforge(piece)
		if not line.is_empty():
			shown.append(line)
	return shown


## The board as rows: one per thing the smith can make longer, with its rungs
## along it. See `Catalogue.groups` for the shape.
##
## The armour is the reason this override exists. `chest` is ONE row with two
## branches, because the question the player is answering is "what do I do about
## my chest" and heavy and light are its two answers — the flat board put them
## next to each other (see `_board`) and hoped that was enough, but next to each
## other is not the same as on the same row, and eight lines that happened to be
## in pairs read as eight lines. Once a piece commits, the losing branch is not
## in `lines()` at all and the row is simply the one ladder.
##
## The stock lines are ladders too and were never drawn as such: BAG SLOT is four
## purchases at rising prices, and a player who had bought two of them had no way
## to see they were two from the end.
static func groups() -> Array[Dictionary]:
	var rows: Array[Dictionary] = lines()
	var at := {}
	for i in rows.size():
		at[rows[i]["id"]] = i

	var out: Array[Dictionary] = []
	_stock_row(out, at, rows, &"arrows", "ARROWS", 1)
	_stock_row(out, at, rows, &"bag_slot", "THE BAG", int(LIMITS[&"bag_slot"]))
	_stock_row(out, at, rows, &"heart", "HEARTS", int(LIMITS[&"heart"]))
	_forge_row(out, at, &"edge", "THE BLADE")
	_forge_row(out, at, &"guard", "THE SHIELD")
	for piece: StringName in Game.PLATE_PIECES:
		_armour_row(out, at, piece)
	_forge_row(out, at, &"string", "THE BOW")
	_forge_row(out, at, &"chain", "THE CHAIN")
	_reforge_row(out, at)
	return out


## One row, one ladder. Absent from the board entirely when the smith is not
## offering it -- a bow ladder for a bow you have not found is a spoiler and a
## dead row (see `stocked`), and that has to stay true of the row as well as of
## the line.
static func _forge_row(out: Array[Dictionary], at: Dictionary,
		id: StringName, title: String) -> void:
	if not stocked(id):
		return
	out.append({"title": title, "tracks": [_track(at, id, "", K.FORGE_MAX)]})


static func _stock_row(out: Array[Dictionary], at: Dictionary,
		rows: Array[Dictionary], id: StringName, title: String,
		rungs: int) -> void:
	if not stocked(id):
		return
	# Arrows are the one line here with no ceiling, so they get the plain named
	# cell a repeatable gets rather than a one-rung ladder with a numeral on it.
	if rungs <= 1:
		var i: int = at.get(id, -1)
		if i < 0:
			return
		out.append({"title": title, "tracks": [{
			"name": String(rows[i]["label"]), "line": i, "owned": 0, "rungs": 1}]})
		return
	out.append({"title": title, "tracks": [_track(at, id, "", rungs)]})


## A piece of armour: one row, and its two paths are two branches on it until one
## of them commits.
static func _armour_row(out: Array[Dictionary], at: Dictionary,
		piece: StringName) -> void:
	var tracks: Array = []
	for path: StringName in [Game.PLATE_HEAVY, Game.PLATE_LIGHT]:
		var id := Game.plate_track(piece, path)
		if not stocked(id) and Game.forge_level(id) == 0:
			continue
		tracks.append(_track(at, id, String(path).to_upper(), K.FORGE_MAX))
	if tracks.is_empty():
		return
	out.append({"title": String(piece).to_upper(), "tracks": tracks})


## **The undo, one row, one cell per piece that has something to undo.**
##
## Last on the board and gathered into a single row rather than hung off each
## piece's own row, which is the one layout decision here worth arguing about.
## Under the piece it would sit next to the rung it cancels and read as a third
## branch of the same ladder -- a choice between heavy, light and *unheavy*. It is
## not a branch; it is the counter offering to undo work you paid for, and the
## player should have to leave the ladder to find it (GDD §6.6: it stops being a
## menu when it costs something, and it should not LOOK like a menu either).
##
## Absent entirely when nothing has committed, so a fresh save is never shown a
## row about a decision it has not made.
static func _reforge_row(out: Array[Dictionary], at: Dictionary) -> void:
	var tracks: Array = []
	for piece: StringName in Game.PLATE_PIECES:
		var i: int = at.get(StringName(REFORGE + String(piece)), -1)
		if i < 0:
			continue
		tracks.append({"name": String(piece).to_upper(), "line": i,
			"owned": 0, "rungs": 1})
	if tracks.is_empty():
		return
	out.append({"title": "REFORGE", "tracks": tracks})


## Which path `piece` has committed to, and how far up it. `[&"", 0]` when it has
## not committed at all -- rung 0 on both paths is a piece still deciding, and
## there is nothing to put back in the fire.
##
## Returns the pair rather than the track alone because every caller wants both
## and re-deriving the level from the track is another `forge_level` lookup that
## can disagree with the branch that chose it.
static func committed_path(piece: StringName) -> Array:
	for path: StringName in [Game.PLATE_HEAVY, Game.PLATE_LIGHT]:
		var id := Game.plate_track(piece, path)
		var lvl := Game.forge_level(id)
		if lvl > 0:
			return [id, lvl]
	return [&"", 0]


## The reforge line for one piece, or `{}` when there is nothing to undo.
##
## **Zero gold, and that is the design and not an oversight** (GDD §6.6, §10).
## The components come back and the gold does not: what a reforge costs is every
## coin already sunk in the ladder you are dismantling, which you must now earn
## again for the other path. Charging a fee on top would price the same decision
## twice. The bill is invisible at the counter and enormous in the purse, which is
## exactly the shape §3 asks for -- it costs time in the grind, never progress
## through the gate.
static func _reforge(piece: StringName) -> Dictionary:
	var pair := committed_path(piece)
	var track: StringName = pair[0]
	var lvl: int = pair[1]
	if track == &"" or lvl <= 0:
		return {}
	var back := refund_of(track, lvl)
	var words: Array[String] = []
	for pid: StringName in back:
		var def := ItemDb.get_def(pid)
		words.append("%d %s" % [int(back[pid]),
			def.display_name if def != null else String(pid)])
	var was := String(track).get_slice("_", 2).to_upper()
	return {
		"id": StringName(REFORGE + String(piece)),
		"label": "REFORGE - %s" % String(piece).to_upper(),
		"cost": 0,
		"parts": {},
		# The `holds` key, not an empty recipe. See `Catalogue.crafts`.
		"holds": true,
		"verb": "REFORGE",
		"blurb": "Back in the fire. The metal comes back. The gold does not.",
		"detail": "%s %d -> nothing,  returns %s" % [was, lvl,
			", ".join(words) if not words.is_empty() else "nothing"],
	}


## Every component sunk into the first `rungs` rungs of `track`, summed. This is
## what a reforge hands back, and it is read off `PARTS` rather than recorded at
## purchase time on purpose: a receipt stored in the save would be a second copy
## of the recipe table that a tuning change could not reach.
static func refund_of(track: StringName, rungs: int) -> Dictionary:
	var back := {}
	if not PARTS.has(track):
		return back
	var recipes: Array = PARTS[track]
	for i in mini(rungs, recipes.size()):
		var recipe: Dictionary = recipes[i]
		for pid: StringName in recipe:
			back[pid] = int(back.get(pid, 0)) + int(recipe[pid])
	return back


## The rung arithmetic, in one place. `line` is -1 when the ladder is finished or
## the smith is not offering it, which is what tells `UpgradeLadder` there is
## nothing on this chain to point the cursor at.
static func _track(at: Dictionary, id: StringName, branch: String,
		rungs: int) -> Dictionary:
	return {
		"name": branch,
		"line": int(at.get(id, -1)),
		"owned": int(Game.upgrades.get(id, 0)),
		"rungs": rungs,
	}


## Is `id` on the counter at all? Public because a caller that wants to know
## whether a line is HIDDEN cannot tell from `lines()` — the row simply is not
## there — and the director that proves the gate has to be able to ask.
##
## Note this is not `remaining()`'s job and must not become it. `remaining` is
## "you have bought all of these", which is a finished ladder the smith still
## displays with a refusal; this is "the smith does not offer that", which is no
## row at all. A finished ladder and an unearned one look nothing alike, and
## collapsing them would put "NOTHING LEFT TO DO THERE" on a bow you never found.
static func stocked(id: StringName) -> bool:
	# A committed piece's losing path. Hidden rather than greyed, which is the
	# OPPOSITE of the call made for the bow above, and on purpose: a greyed bow
	# ladder is a spoiler for something you might still find, while a greyed
	# `plate_chest_light` is a row for a thing that can never happen again (GDD
	# §6.6, no re-spec). Leaving it would cost a line of a counter that already
	# runs to fifteen, forever, to say "no" over and over.
	if Game.path_closed(id):
		return false
	if not GATED_BY.has(id):
		return true
	# Indexing an untyped const Dictionary hands back a Variant (CLAUDE.md §3).
	var needs: StringName = GATED_BY[id]
	return Game.has(needs)


## Everything the smith could ever offer, before the ownership sieve. Split out
## of `lines()` rather than inlined so the filter has one thing to filter and the
## literal stays a literal.
static func _board() -> Array[Dictionary]:
	return [
		{
			"id": &"arrows",
			"label": "ARROWS X10",
			"cost": _stock(40),
			"parts": {},
			"blurb": "Fletched from something that used to fly.",
			"detail": _arrow_detail(),
		},
		{
			"id": &"bag_slot",
			"label": "BAG SLOT",
			"cost": _stock(140, &"bag_slot", 1.6),
			"parts": {},
			"blurb": "One more thing you can carry, and lose.",
			"detail": "%d slots -> %d" % [Game.bag_slots, Game.bag_slots + 1],
		},
		{
			"id": &"heart",
			"label": "HEART CONTAINER",
			"cost": _stock(320, &"heart", 1.5),
			"parts": {},
			"blurb": "One more heart. It does not grow back on its own.",
			"detail": "%d hearts -> %d" % [
				Game.max_quarters / K.HEART, Game.max_quarters / K.HEART + 1],
		},
		_forge(&"edge", "SHARPEN THE BLADE", 120, 2.1,
			"Takes a quarter-heart more off whatever it meets.",
			K.EDGE_DAMAGE, "+%d", "quarters"),
		# The armour, eight rows deep on a fresh save and four once every piece
		# has committed. Grouped piece by piece rather than all-heavy-then-all-
		# light, because the choice the player is making is "what do I do about my
		# chest", and the two answers to it have to be adjacent to be a choice.
		_plate(&"chest", Game.PLATE_HEAVY), _plate(&"chest", Game.PLATE_LIGHT),
		_plate(&"legs", Game.PLATE_HEAVY), _plate(&"legs", Game.PLATE_LIGHT),
		_plate(&"arms", Game.PLATE_HEAVY), _plate(&"arms", Game.PLATE_LIGHT),
		_plate(&"boots", Game.PLATE_HEAVY), _plate(&"boots", Game.PLATE_LIGHT),
		_forge(&"guard", "BIND THE SHIELD", 110, 2.2,
			"A wider face. It catches what comes in off the shoulder.",
			K.GUARD_ARC, "%.0f", "degree guard"),
		_forge(&"string", "STRING THE BOW", 130, 2.1,
			"Draws faster. The shot owns you for less of the fight.",
			K.BOW_DRAW, "%.2f", "s draw"),
		_forge(&"chain", "LENGTHEN THE CHAIN", 150, 2.1,
			"More chain on the drum. The far side gets closer.",
			K.CHAIN_REACH, "%.1f", "m reach"),
	]


## Build a forge line. `ladder` is the K array the track reads and `unit` is a
## format string for ONE of its entries, so the detail text is generated from the
## same table the gear obeys -- a screen that hardcoded "+3 quarters" would be
## the next thing to drift when the tuning moves.
## `fmt` formats one rung's number and `noun` names the unit ONCE, at the end:
## "8.7 -> 11.9 m reach", not "8.7 m reach -> 11.9 m reach". The unit on both
## sides pushed the shop's blurb line past the width of the panel, and a line
## the player has to read twice to find the one number that changed is worse
## than the shorter one anyway.
static func _forge(id: StringName, label: String, base: int, growth: float,
		blurb: String, ladder: Array, fmt: String, noun: String) -> Dictionary:
	var lvl: int = Game.forge_level(id)
	var recipes: Array = PARTS[id]
	var detail := fmt % ladder[lvl]
	if lvl < recipes.size():
		detail = "%s -> %s %s" % [detail, fmt % ladder[lvl + 1], noun]
	else:
		detail = "%s %s  (finished)" % [detail, noun]
	return {
		"id": id,
		"label": label,
		"cost": _scaled(base, id, growth),
		"parts": next_parts(id),
		"blurb": blurb,
		"detail": detail,
	}


## One armour row. Its own builder rather than another `_forge` call, because a
## plate rung is the only purchase in the shop that moves TWO numbers and the
## second one is a cost -- `_forge`'s one-ladder-one-format shape cannot say
## "this buys you soak and takes some of your step".
##
## The before/after is the WHOLE hero, not this piece: `Game.armour_soak_exact()`
## is what the blow will actually be reduced by, and a row that said "0.0 -> 0.4"
## about one boot while the player had three other pieces on would be arithmetic
## the player has to do in their head. It is printed to one decimal on purpose --
## `armour_soak()` floors, so a rung that moves 0.7 to 1.0 is the one that
## actually pays, and a row rounded to whole quarters would show three purchases
## in a row doing nothing and then a fourth doing everything (see the note over
## `K.PLATE_HEAVY_SOAK`).
static func _plate(piece: StringName, path: StringName) -> Dictionary:
	var heavy := path == Game.PLATE_HEAVY
	var id := Game.plate_track(piece, path)
	var lvl: int = Game.forge_level(id)
	var ladder: Array = K.PLATE_HEAVY_SOAK if heavy else K.PLATE_LIGHT_SOAK
	var soak := Game.armour_soak_exact()

	var detail := ""
	if lvl < K.FORGE_MAX:
		var after := minf(soak + (float(ladder[lvl + 1]) - float(ladder[lvl])),
			K.SOAK_MAX)
		detail = "%.1f -> %.1f quarters soaked" % [soak, after]
		if heavy:
			# Clamped from the RAW product, not from `speed_mult()`. Two Swift
			# rings can be holding the hero at the 1.0 ceiling with headroom to
			# spare, and in that case this rung genuinely costs nothing -- the row
			# has to be able to say 100.0% -> 100.0%.
			var raw := Game.speed_mult_raw()
			var step := float(K.PLATE_HEAVY_SPEED[lvl + 1]) \
				/ float(K.PLATE_HEAVY_SPEED[lvl])
			detail += ",  speed %.1f%% -> %.1f%%" % [
				clampf(raw, 0.5, 1.0) * 100.0, clampf(raw * step, 0.5, 1.0) * 100.0]
	else:
		detail = "%.1f quarters soaked  (finished)" % soak

	return {
		"id": id,
		"label": "%s - %s" % [String(piece).to_upper(),
			"HEAVY" if heavy else "LIGHT"],
		# Heavy is dearer in gold as well as in components, and light's rungs stay
		# inside one good run's takings so the early game has an armour answer it
		# can actually afford.
		"cost": _scaled(65 if heavy else 35, id, 1.9 if heavy else 1.8),
		"parts": next_parts(id),
		"blurb": "Thicker plate. It takes the blow, and a little of your step." \
			if heavy else "Thinner plate. Less of the blow, all of your step.",
		"detail": detail,
	}


## What the NEXT rung of `id` costs in components, or `{}` when the ladder is
## finished or `id` is not a forge track.
static func next_parts(id: StringName) -> Dictionary:
	if not PARTS.has(id):
		return {}
	var recipes: Array = PARTS[id]
	var owned: int = Game.forge_level(id)
	if owned >= recipes.size():
		return {}
	return recipes[owned]


static func _arrow_detail() -> String:
	return "%d / %d arrows" % [Game.arrows, Game.max_arrows]


static func _scaled(base: int, id: StringName, factor: float) -> int:
	var owned: int = Game.upgrades.get(id, 0)
	return int(round(base * pow(factor, float(owned))))


## A STOCK line's price: the scaled cost with the mill's discount on it.
##
## The three lines the smith BUYS IN -- arrows, a bag slot, a heart container --
## and not the twelve forge ladders, which is the whole reason this is a second
## helper rather than a multiply inside `_scaled`. A rung is not something the
## smith buys in, and discounting it would make the Waterwheel Gear the strongest
## relic on the list by a distance (`RelicDb.SMITH_MULT_MILL`).
##
## Adopted unconditionally: `smith_stock_mult()` is 1.0 until the mill turns, so
## there is no branch here and there must never be one.
static func _stock(base: int, id: StringName = &"", factor: float = 1.0) -> int:
	return int(round(_scaled(base, id, factor) * RelicDb.smith_stock_mult()))


## How many more of `id` the player may buy. -1 means unlimited.
static func remaining(id: StringName) -> int:
	if not LIMITS.has(id):
		return -1
	return maxi(0, cap_of(id) - int(Game.upgrades.get(id, 0)))


## The ceiling on `id`: how many of it the smith will ever sell.
##
## For the three stock lines that is `LIMITS` and nothing else. For a forge
## ladder it is `LIMITS` clamped by **what the smith has been taught** --
## `RelicDb.forge_rungs_known()` is 1 until the Tally-Ledger of Fair Weights and
## 2 until the Imperium Anvil-Plate. Adopted unconditionally, because that
## accessor already returns the untouched ceiling once both are recorded; an
## `if RelicDb.donated(...)` here would be the unlock written a second time.
##
## Public so `refusal()` can tell the two ceilings apart, and so a director can
## ask without re-deriving it.
static func cap_of(id: StringName) -> int:
	# A committed piece's other path. Zero, not "hidden": `lines()` already drops
	# the row, and this is the answer for everything that does not go through
	# `lines()` -- a director, a save that arrived with both siblings set, a
	# future screen. GDD §6.6's commitment is enforced HERE, where the ceiling
	# lives, rather than in the row-building code that only draws it.
	if Game.path_closed(id):
		return 0
	var limit: int = int(LIMITS.get(id, -1))
	if not PARTS.has(id):
		return limit
	return mini(limit, RelicDb.forge_rungs_known())


static func can_buy(line: Dictionary) -> bool:
	var id: StringName = line["id"]
	if remaining(id) == 0:
		return false
	if id == &"arrows" and Game.arrows >= Game.max_arrows:
		return false
	if not Game.can_afford_parts(line.get("parts", {})):
		return false
	return Game.gold >= int(line["cost"])


## Why a line is refused, in one phrase, for the footer. The screen used to say
## "NOT ENOUGH GOLD" for every refusal, which was a lie two thirds of the time
## the moment components existed -- and a shop that misreports the reason sends
## the player back down for the wrong thing.
static func refusal(line: Dictionary) -> String:
	var id: StringName = line["id"]
	if remaining(id) == 0:
		# THREE different ceilings now, and telling the player the wrong one sends
		# them to the wrong place. A path whose sibling has a rung in it is closed
		# for good and the answer is nothing; a ladder at the top of its own table
		# is FINISHED; a ladder stopped short of it is a rung the smith has not
		# been taught, and the answer to that is a relic, not another run's grit.
		if Game.path_closed(id):
			return "THAT PIECE IS ALREADY COMMITTED"
		if int(LIMITS.get(id, 0)) > cap_of(id):
			return "HE HAS NOT BEEN TAUGHT THAT RUNG"
		return "NOTHING LEFT TO DO THERE"
	if id == &"arrows" and Game.arrows >= Game.max_arrows:
		return "THE QUIVER IS FULL"
	var parts: Dictionary = line.get("parts", {})
	for pid: StringName in parts:
		if Game.component_count(pid) < int(parts[pid]):
			var def := ItemDb.get_def(pid)
			var what: String = def.display_name if def != null else String(pid)
			return "NOT ENOUGH %s" % what.to_upper()
	if Game.gold < int(line["cost"]):
		return "NOT ENOUGH GOLD"
	return ""


## Take the money AND the components, then apply the effect. Returns false if it
## could not happen, so the caller can play a refusal instead of a chime.
##
## The order matters and it is checked-then-charged: `can_buy` has already said
## the whole bill is payable, so nothing below can leave a player half-charged
## for a rung they did not get.
static func buy(line: Dictionary) -> bool:
	if not can_buy(line):
		return false
	var id: StringName = line["id"]
	# Before a coin moves, because a reforge is not a purchase: nothing is spent
	# and the rung goes DOWN. Reaching the increment below with a `reforge_chest`
	# id would put a made-up track in `Game.upgrades` and leave it in the save.
	if String(id).begins_with(REFORGE):
		return _do_reforge(StringName(String(id).substr(REFORGE.length())))
	var parts: Dictionary = line.get("parts", {})
	if not Game.spend_gold(int(line["cost"])):
		return false
	for pid: StringName in parts:
		Game.spend_component(pid, int(parts[pid]))

	Game.upgrades[id] = int(Game.upgrades.get(id, 0)) + 1
	match id:
		&"arrows":
			Game.add_arrows(10)
		&"bag_slot":
			Game.bag_slots += 1
		&"heart":
			# Derived from `upgrades`, which the line above has already bumped, so
			# there is no second copy of "how many hearts do the ladders add up to"
			# for Recut to have to agree with (GDD §6.6).
			Game.resync_maxima(true)
		_:
			# Every forge track. There is nothing to apply: the rung IS the
			# effect, and the gear reads it off Game the next time it spawns.
			# Adding a per-track branch here would be a second place that has to
			# agree with K's ladders, and it would eventually not.
			Bus.gear_forged.emit(id, Game.upgrades[id])
	Bus.item_acquired.emit(id)
	return true


## Put a piece back in the fire (GDD §6.6).
##
## The rung is ERASED rather than set to zero. `path_closed` asks whether the
## sibling has a rung, `Game.upgrades.get(other, 0)` reads a stored 0 the same as
## a missing key, and both readings work today -- but a key that says "this piece
## once committed to heavy" left lying in the save is a fact nothing needs and the
## next reader of `upgrades` might believe. Gone means gone.
##
## Nothing is charged and the components come back, so there is no half-paid
## state to guard against; the only ordering that matters is that the refund is
## computed from the level BEFORE it is thrown away.
static func _do_reforge(piece: StringName) -> bool:
	var pair := committed_path(piece)
	var track: StringName = pair[0]
	var lvl: int = pair[1]
	if track == &"" or lvl <= 0:
		return false
	var back := refund_of(track, lvl)
	for pid: StringName in back:
		Game.add_component(pid, int(back[pid]))
	Game.upgrades.erase(track)
	# The gear reads its rung off `Game` the next time it spawns, exactly as it
	# does after a purchase, so the same signal is the whole of the effect. The
	# rung it carries is 0, which is what the hero is now wearing.
	Bus.gear_forged.emit(track, 0)
	return true
