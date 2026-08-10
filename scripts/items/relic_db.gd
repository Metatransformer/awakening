class_name RelicDb
extends Catalogue
## The twelve relics, and the counter they are handed across.
##
## This file is deliberately TWO things, because the design is two things
## (docs/GDD.md §3, §6):
##
##  1. **The definition table.** Twelve named objects in twelve named places.
##     There is no thirteenth, there is no generic relic, and there is no relic
##     drop table -- the moment a relic can *roll* it stops being a thing you
##     remember finding (`docs/SCOPE.md` §2). `RELICS` below is the whole list
##     and the placement manifest and the quest log, all at once.
##  2. **A `Catalogue` subclass**, so the Lanternkeeper is a row in
##     `Npc.COUNTERS` and a subclass here and NOT a fourth screen
##     (`docs/SCOPE.md` §1 says zero new UI screens; `docs/METAGAME.md` §6.6
##     says a third counter is a subclass and a row, nothing else). A donation
##     is a transaction whose price is one relic and zero gold.
##
## **Every unlock below is one line of change to something that already works.**
## That is not a coincidence, it is the acceptance criterion (GDD §6.1) and it
## is the named risk in `docs/SCOPE.md` §6: twelve one-line changes are
## unsatisfying to write and each one wants to become a feature. If a relic
## needs more than a line, it is the wrong relic.
##
## ## What the rest of the game reads
##
## Never `Game.flags` directly and never a hardcoded flag string. The accessors
## at the bottom -- `forge_rungs_known()`, `extract_rate()`, `chest_hums()` and
## the rest -- each return the **unmodified** value when the relic is not
## donated, so a caller adopts one unconditionally and never grows an `if`:
##
## ```gdscript
## var rate := RelicDb.extract_rate(EXTRACT_RATE)   # 0.25 until the Rope-Drum
## ```
##
## A caller that writes `if RelicDb.donated(&"rope_drum")` has re-implemented
## the unlock at the call site, and the next tuning pass will move only one of
## the two copies.
##
## ## The three things the relics deliberately do not do (GDD §6.3)
##
##  * **No relic sells.** There is no `value` on a row here and the vendor never
##    sees one. A relic with a gold price is a relic the player converts into
##    the grind, and §3's whole point is that gold, components and relics do not
##    touch.
##  * **No relic is a stat.** Read the `bites` column: catalogues, recipes,
##    prices, one wayfinding hum. The closest thing to power is `extract_rate()`,
##    and that is a discount on leaving, not a bigger sword.
##  * **No relic gates the ending.** `all_donated()` exists for the *Chord*
##    ending (GDD §8), which is the completionist one. The Lantern ending is
##    reachable having donated none of them.
##
## Static, not instanced, like every other catalogue: this is a pure function of
## `Game.flags`, and an instance would be a second copy of state that is already
## in the save file.


# --- The twelve -------------------------------------------------------------

## Columns, and why each one is here:
##
##  * `id`      -- greppable, short, and the key of both world flags.
##  * `name`    -- the proper name from GDD §6.2. Title case here; the counter
##                 upper-cases it, because the table is the record and the
##                 screen is a rendering of it.
##  * `level`   -- which floor it is on. 1-4 are the Descent; **10 is the Long
##                 Descent's tenth floor**, which cannot collide with a main-line
##                 floor because the main line stops at four (GDD §5).
##  * `source`  -- SOURCE_* below. The four anchors a floor manifest places
##                 (GDD §5.1) plus the endless mode's one chest.
##  * `effect`  -- the flag id of the unlock, so a reader can grep the
##                 consequence and land on the accessor that serves it. It is
##                 NOT the donation flag -- see `flag_donated`.
##  * `bites`   -- where the one line of change lands, named in full. This is
##                 the column that keeps §6.1 honest: if you cannot write this
##                 as one accessor and one call site, the relic is wrong.
##  * `detail`  -- the consequence in the player's words, for the counter. Same
##                 contract as the forge's before/after text.
##  * `prop`    -- which dark thing in the courtyard lights when it is donated.
##                 Twelve dark props, twelve come on (GDD §6.2). The garrison reads
##                 `props_lit()`; the contrast between the first frame and the
##                 last IS the reward, and it must not cost more than a prop.
##  * `lore`    -- the writing. See the note above the strings.
##
## `const`, so it is read-only at runtime and nothing can quietly append a
## thirteenth. Nothing in here is a `class_name` or another class's enum, which
## is the one thing that would have forced `static var` (CLAUDE.md §3).
##
## ## On the lore
##
## This is the one place the game's writing lives, and it is a **Vyr salvage
## catalogue kept by the Far Lantern Society**, whose creed is three clauses:
## *go far, come home, tell true*. Five nouns are in scope and no more -- the
## Society, the Listening College, the Vyr, Valenfeld, the Sundering
## (`docs/SCOPE.md` §6, "Lore gravity"). Every entry implies a person, a use and
## a failure, because a museum label implies none of those and nobody reads one
## twice.
##
## **ASCII only, and a narrower ASCII than you think.** `PixelFont` has no
## semicolon and no em dash -- anything missing draws as a filled 5x7 block, and
## that survived several screenshots the last time (see its GLYPH table). Full
## stops and commas only.
##
## Length is bounded by the panel, not by taste: `TradeScreen` wraps
## `blurb + detail` upward from the bottom of the panel at ~63 characters a line,
## and the twelve rows above it reach down to within five lines of it.
##
## **TODAY ONLY TWO OF THOSE LINES DRAW, and the entries below are longer than
## that.** `PixelFont.wrap()` takes a `max_lines` that DEFAULTS TO 2 and
## `trade_screen.gd` does not pass one, so every entry here is clipped mid-word
## on the counter -- `relic_donate.gd`'s `r_21_hold.png` is the frame that caught
## it. This comment used to claim four lines fit; it was never true.
##
## `# NEEDS:` one argument at the `PixelFont.wrap` call in
## `scripts/ui/shop/trade_screen.gd` (`, 4`). The panel has the room -- the list
## ends around 90 px above where the blurb starts -- and the fix belongs there
## rather than here, because the smith's and the alchemist's blurbs are clipped
## by the same default. The lore was deliberately NOT cut down to ~80 characters
## to work around it: shortening twelve entries to fit a bug is a change that is
## hard to undo and easy to forget, and a clipped sentence is a worse counter
## than a short one only until that argument lands.
const RELICS: Array[Dictionary] = [
	{
		"id": &"tally_ledger",
		"name": "Tally-Ledger of Fair Weights",
		"level": 1, "source": &"deep_chest",
		"effect": &"forge_rung_2",
		"bites": "RelicDb.forge_rungs_known() -> ShopDb's twelve ladders",
		"detail": "The smith learns rung 2 of every ladder.",
		"prop": &"lamp_weighhouse",
		"lore": "Vyr accounting, and every column of it still true after an age underwater. The Society priced it at nothing and gave it to the smith, who has stopped guessing what a good rung weighs.",
	},
	{
		"id": &"anvil_plate",
		"name": "Imperium Anvil-Plate",
		"level": 1, "source": &"boss",
		"effect": &"forge_rung_3",
		"bites": "RelicDb.forge_rungs_known() -> ShopDb's twelve ladders",
		"detail": "The smith learns rung 3 of every ladder.",
		"prop": &"forge_fire",
		"lore": "Not Vyr work. The face is Imperium bronze, poured over something older that would not take a mark, and whoever hammered on it learned the last third of every ladder before he left it in the water.",
	},
	{
		"id": &"still_head",
		"name": "Cracked Still-Head",
		"level": 1, "source": &"vault",
		"effect": &"draught_ironhide",
		"bites": "RelicDb.knows_draught() -> AlchemyDb.lines()",
		"detail": "The alchemist learns the Ironhide Draught.",
		"prop": &"well_lamp",
		"lore": "Do not seal the crack. A recovery team did, boiled the head and lost a woman's hands. The fracture is where the vapour is meant to go, and open it makes a thing that turns a blow aside.",
	},
	{
		"id": &"cinder_retort",
		"name": "Cinder-Retort",
		"level": 2, "source": &"deep_chest",
		"effect": &"draught_emberblood",
		"bites": "RelicDb.knows_draught() -> AlchemyDb.lines()",
		"detail": "The alchemist learns the Emberblood Draught.",
		"prop": &"alchemist_window",
		"lore": "Eleven degrees off vertical, in any hand, on any table. The Listening College has no explanation for that. The alchemist stopped asking the day it gave her something that burns in the blood.",
	},
	{
		"id": &"kiln_core",
		"name": "Glass-Kiln Core",
		"level": 2, "source": &"boss",
		"effect": &"bottles_3_4",
		"bites": "RelicDb.bottle_cap() -> AlchemyDb's bottle line",
		"detail": "Bottles 3 and 4 can be blown.",
		"prop": &"glasshouse_kiln",
		"lore": "How does a fire nobody has fed since the Sundering still hold its heat? The Society cannot say. It knows only that glass blown off this core comes out clear, and that four bottles is all one core will carry.",
	},
	{
		"id": &"fletchers_jig",
		"name": "Fletcher's Jig",
		"level": 2, "source": &"vault",
		"effect": &"fletch_seven",
		"bites": "RelicDb.fletch_yield() -> Fletching.BATCH",
		"detail": "Fletching cuts 7 arrows instead of 5.",
		"prop": &"fletchers_lamp",
		"lore": "Two clamps, a nock groove, and a spine of Vyr bronze that has never gone out of true. Hess kept it thirty years, taught nobody, and took it down the shaft with him. It cuts seven shafts where a steady hand cuts five.",
	},
	{
		"id": &"pillar_shard",
		"name": "Pillar-Shard",
		"level": 3, "source": &"deep_chest",
		"effect": &"market_lit",
		"bites": "RelicDb.vendor_price_mult() -> Run.line_value()",
		"detail": "The square lights. The vendor pays +10%.",
		"prop": &"market_lamps",
		"lore": "Set it in stone and the stone gives light back for as long as it stays there. Lift it out and there is nothing to see. Valenfeld's square has been dark six generations, and a lit market is one people bring money to.",
	},
	{
		"id": &"sounding_rod",
		"name": "Sounding-Rod",
		"level": 3, "source": &"boss",
		"effect": &"chest_hum",
		"bites": "RelicDb.chest_hums() -> the floor's deep chest",
		"detail": "The deep chest hums the moment you arrive.",
		"prop": &"college_window",
		"lore": "It hums near anything the Vyr sealed and meant to come back for. The Society lost two members proving that and recorded it anyway, because the creed says tell true and a rod that only hummed over treasure would have been a lie.",
	},
	{
		"id": &"warp_stone",
		"name": "Warp-Stone Fragment",
		"level": 3, "source": &"vault",
		"effect": &"garrison_shortcuts",
		"bites": "RelicDb.garrison_shortcuts() -> the gate's descend",
		"detail": "Start a run at any shortcut you have opened.",
		"prop": &"gate_arch",
		"lore": "A chip off something much larger, and nobody has found the rest of it. Stand it at a door you have already opened and the walk to that door stops existing. The Listening College calls this impossible and uses it weekly.",
	},
	{
		"id": &"rope_drum",
		"name": "Rope-Drum",
		"level": 4, "source": &"deep_chest",
		"effect": &"rope_toll",
		"bites": "RelicDb.extract_rate() -> Run.extract_cost()",
		"detail": "Extraction fee 25% -> 20%.",
		"prop": &"winch_lamp",
		"lore": "Vyr winch-gear, cut so fine a rope over it hauls for a fifth less than anything Valenfeld can forge. There were two. The first slipped its sling coming up and is still down there, so the saving comes off the second.",
	},
	{
		"id": &"waterwheel_gear",
		"name": "Waterwheel Gear",
		"level": 4, "source": &"boss",
		"effect": &"mill_turns",
		"bites": "RelicDb.smith_stock_mult() -> ShopDb's three stock lines",
		"detail": "The mill turns. The smith's stock costs 15% less.",
		"prop": &"mill_wheel",
		"lore": "One tooth. The mill has stood still since the Sundering for want of one tooth, and the smith has bought his stock in from two valleys over ever since. Grain turns again, and everything on his shelf comes down.",
	},
	{
		"id": &"riven_chord",
		"name": "The Riven Chord",
		"level": 10, "source": &"long_descent",
		"effect": &"chord",
		"bites": "RelicDb.all_donated() -> the Chord ending",
		"detail": "The last one. The College can fire the pillar.",
		"prop": &"resonance_pillar",
		"lore": "The last entry in the catalogue, written by a woman who never saw the thing she was describing. Go far, come home, tell true. The Listening College knows what to do with the third clause, and this is what it needs to do it.",
	},
]

## Where a relic sits, for the floor manifests that place them (GDD §5.1) and
## for the counter's "not recovered yet" line. Four anchors and the endless
## mode's one chest -- there is no fifth, because a relic that could appear
## anywhere is a relic that rolls.
const SOURCE_DEEP_CHEST := &"deep_chest"
const SOURCE_VAULT := &"vault"
const SOURCE_BOSS := &"boss"
const SOURCE_LONG_DESCENT := &"long_descent"

## Floor names and boss names, for `where_text` only. Duplicated from GDD §5's
## table rather than read out of a floor manifest because the manifest does not
## exist yet and this is one string each. **When `data/dungeon/floors` lands,
## delete these two tables and read the manifest** -- a floor named in two
## places is a floor that gets renamed in one.
const FLOOR_NAMES := {
	1: "THE CISTERN", 2: "THE FOUNDRY", 3: "THE HUSHING CHOIR",
	4: "THE CHORD GATE", 10: "THE LONG DESCENT",
}
const BOSS_NAMES := {
	1: "THE CISTERN WARDEN", 2: "THE SLAG OGRE",
	3: "THE BELLWAKE", 4: "THE RIVEN KNIGHT",
}


# --- Tuning the unlocks create ----------------------------------------------
# Each of these is a number that does not exist until a relic exists, which is
# why it lives here and not in `K`: the un-donated value belongs to the system
# that owns it (Run's EXTRACT_RATE, Fletching's BATCH) and is passed IN, so
# there is exactly one place each number is authored.

## What the Rope-Drum takes the extraction fee down to. GDD §6.2 says 25% -> 20%
## and `Run.EXTRACT_RATE` is the 25. [tune]
const RATE_WITH_DRUM := 0.20
## A lit market pays more for the same bag. [tune]
const VENDOR_MULT_LIT := 1.10
## The mill turning takes 15% off the smith's STOCK lines -- arrows, a bag slot,
## a heart container. Not the forge ladders: a rung is not something the smith
## buys in, and discounting it would make the Waterwheel Gear the strongest
## relic on the list by a distance. [tune]
const SMITH_MULT_MILL := 0.85
## Arrows per fletching batch once the jig is on the bench. `Fletching.BATCH` is
## the 5. [tune]
const FLETCH_WITH_JIG := 7
## How many bottles the alchemist can blow before the Glass-Kiln Core. The
## ceiling is `K.BOTTLE_MAX` (4) and this is the gate in front of it, so the
## relic is worth two whole slots rather than a discount. [tune]
const BOTTLES_WITHOUT_CORE := 2

## The forge ladders' rungs, in the order the smith learns them. Rung 1 is
## always known, so this array is rungs 2 upward and its length plus one is the
## ceiling. An array rather than two `if`s, so a third teaching relic would be
## an entry rather than a branch.
const RUNG_RELICS: Array[StringName] = [&"tally_ledger", &"anvil_plate"]

## Draught id -> the relic that teaches it. A draught NOT in this table is known
## from the start (the Heart Draught is, and so is anything added later that
## forgets to ask) -- the table lists what is LOCKED, because the default for a
## recipe should be "the alchemist can make it".
const DRAUGHT_RELICS := {
	&"ironhide_draught": &"still_head",
	&"emberblood_draught": &"cinder_retort",
}


# --- Lookups ----------------------------------------------------------------

## id -> index into `RELICS`. Built once, on first ask, exactly as `ItemDb` does
## it. Twelve rows is small enough to scan, and the point of the index is not
## speed -- it is that `by_id` cannot silently return the wrong row.
static var _index: Dictionary = {}


static func all() -> Array[Dictionary]:
	return RELICS


## The row for `id`, or `{}` for anything that is not one of the twelve. The row
## is READ-ONLY (`RELICS` is a const), which is deliberate: a caller that wants
## to annotate a relic wants its own dictionary, not a scribble on the record.
static func by_id(id: StringName) -> Dictionary:
	if _index.is_empty():
		for i in RELICS.size():
			var row: Dictionary = RELICS[i]
			_index[row["id"]] = i
	if not _index.has(id):
		return {}
	var at: int = _index[id]
	return RELICS[at]


static func is_relic(id: StringName) -> bool:
	return not by_id(id).is_empty()


## Every relic placed on floor `level`, in catalogue order. What a floor
## manifest asks on generation. Floors 1-3 answer with three, floor 4 with two
## (it has no vault -- the boss room is the vault, GDD §5.3), and floor 10 of
## the Long Descent with one.
static func relics_on_floor(level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in RELICS:
		if int(row["level"]) == level:
			out.append(row)
	return out


## The relic behind one specific anchor -- "what is in floor 2's vault" -- or
## `{}` if that anchor carries none. This is the call the placer actually wants:
## a deep chest asks once, gets an id or nothing, and never has to know how many
## relics its floor has.
static func relic_at(level: int, source: StringName) -> Dictionary:
	for row in RELICS:
		if int(row["level"]) == level and row["source"] == source:
			return row
	return {}


## "THE CISTERN, DEEP CHEST" / "THE SLAG OGRE". Where to go and get it, for the
## counter's refusal line and for anything else that has to point at one.
##
## A boss answers with the boss's name alone -- "THE FOUNDRY, THE SLAG OGRE" is
## the floor said twice, and the name of a boss is a better instruction than the
## name of a floor anyway.
static func where_text(id: StringName) -> String:
	var row := by_id(id)
	if row.is_empty():
		return ""
	var level: int = row["level"]
	var floor_name: String = FLOOR_NAMES.get(level, "THE DESCENT")
	match row["source"]:
		SOURCE_BOSS:
			return BOSS_NAMES.get(level, floor_name)
		SOURCE_VAULT:
			return "%s, THE VAULT" % floor_name
		SOURCE_LONG_DESCENT:
			return "%s, FLOOR %d" % [floor_name, level]
	return "%s, THE DEEP CHEST" % floor_name


# --- State: found, and given away -------------------------------------------
# Two one-way flags per relic on `Game.flags`, and NOT an entry in `Game.items`.
# `items` is gear the hero carries; a relic is a fact about the world, which is
# what `flags` has always been for, and it means relics ride the save file with
# no new field (see save_game.gd's VERSION note before adding one).
#
# WHERE THE FLAGS ARE SET is the part that is easy to get wrong. A relic sits in
# the BAG on the way up (GDD §3) -- it costs a slot, it is charged the
# extraction fee, and it dies with the bag. So `recover()` is called by
# `Run.extract()` when the bag comes home, never on pickup. **A relic lost on
# death is not destroyed**: nothing is set, the relic goes back to the room it
# was placed in, and the player can go down and get it again. That is why there
# is no `lose()` here -- the absence of a flag IS the relic still being down
# there, and a permanently missable unique in a game that takes your bag would
# be a corrupt save rather than tension.

static func flag_held(id: StringName) -> StringName:
	return StringName("relic_held_%s" % id)


static func flag_donated(id: StringName) -> StringName:
	return StringName("relic_given_%s" % id)


## The relic reached the garrison. Idempotent, and false for anything that is
## not one of the twelve -- a typo at the call site should not mint a thirteenth
## flag.
static func recover(id: StringName) -> bool:
	if by_id(id).is_empty():
		return false
	Game.set_flag(flag_held(id))
	return true


## In hand, in the garrison, not yet given away.
##
## The donated check is not redundant. `Game.set_flag` is ONE-WAY by design
## (there is no `clear_flag`), so the held flag survives the donation and
## `held()` has to subtract. Reading only `relic_held_*` would leave every
## donated relic sitting in the player's hand forever.
static func held(id: StringName) -> bool:
	return Game.flag(flag_held(id)) and not donated(id)


static func donated(id: StringName) -> bool:
	return Game.flag(flag_donated(id))


## Is this relic still down there, waiting to be found?
##
## The one question a room asks before it places one, and it is the whole of "a
## relic lost on death goes back where it came from" (GDD §3). Death sets no flag
## -- so a relic you were carrying when you died answers true again the moment the
## floor is rebuilt, with nobody having written a line of code to put it back.
## The only two states that take it off the floor are being in your hand
## (`held`) and being in the ledger (`donated`).
##
## False for anything that is not one of the twelve, so a typo in a floor manifest
## places nothing rather than a nameless mote.
static func outstanding(id: StringName) -> bool:
	if by_id(id).is_empty():
		return false
	return not held(id) and not donated(id)


static func donated_count() -> int:
	var n := 0
	for row in RELICS:
		if donated(row["id"]):
			n += 1
	return n


## All twelve recorded. Half of the Chord ending's condition -- the other half is
## every ladder at rung 3 (GDD §8), which is `Game.forge_level` and not this
## file's business. **This is not a gate on the Lantern ending**, which is
## reachable having donated none of them (GDD §6.3).
static func all_donated() -> bool:
	return donated_count() == RELICS.size()


# --- The courtyard ----------------------------------------------------------

## Which prop this relic lights.
static func prop_of(id: StringName) -> StringName:
	var row := by_id(id)
	return row.get("prop", &"") if not row.is_empty() else &""


## Is this prop lit? What each dark prop in the garrison scene asks about
## itself, once, on ready -- and again when `Bus.item_acquired` fires, because a
## donation is the only thing that changes the answer.
static func prop_lit(prop: StringName) -> bool:
	for row in RELICS:
		if row["prop"] == prop and donated(row["id"]):
			return true
	return false


## The twelve dark things, in catalogue order, whether or not they are lit.
##
## What `Garrison` builds the courtyard's props from. It iterates THIS rather
## than `RELICS` so the yard cannot end up with eleven lamps, or a thirteenth
## that nothing will ever light: the prop list and the relic list are the same
## list by construction, and `GarrisonLight` only ever asks `prop_lit()` about
## an id that came out of here.
static func props() -> Array[StringName]:
	var out: Array[StringName] = []
	for row in RELICS:
		out.append(row["prop"])
	return out


## Every prop currently lit, in catalogue order. The garrison can iterate this
## instead of asking twelve times.
static func props_lit() -> Array[StringName]:
	var out: Array[StringName] = []
	for row in RELICS:
		if donated(row["id"]):
			out.append(row["prop"])
	return out


# --- The counter ------------------------------------------------------------

## RECORD, not ENTRUST.
##
## Both are true of the act and only one is the Society's. GDD §6 spells the
## four verbs out in a row -- "the vendor buys, the smith forges, the alchemist
## brews, the Lanternkeeper *records*" -- and the creed's third clause is *tell
## true*, which is a clause about the writing rather than about the object.
## ENTRUST describes handing something over and stops there. RECORD describes
## what actually changes the garrison: the smith learns rung 2 because the
## ledger was *read*, not because it is on a shelf.
##
## Overridden here rather than answered by the base class for the reason spelled
## out on `Catalogue.craft_verb` -- and reached only through the handle
## `TradeScreen` was given. A bare static call inside `Catalogue` binds to
## `Catalogue` at parse time and shipped a smith saying HOLD ENT TO CRAFT.
static func craft_verb() -> String:
	return "RECORD"


static func emblem() -> StringName:
	return &"relic"  ## The lantern's mark.


## All twelve, always, in catalogue order -- including the ones you have never
## seen.
##
## **The list IS the quest log.** `docs/SCOPE.md` §1 budgets zero quests and says
## why: "the relic list is the quest log". A counter that only showed relics you
## were holding would be a counter that is empty for the first three hours and
## tells you nothing about where to go. Instead every row you have not recovered
## reads its location out of the refusal footer, and its catalogue entry stays
## blank until the thing is in front of the Lanternkeeper -- the Society does not
## write up an object it has not seen.
static func lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row in RELICS:
		var id: StringName = row["id"]
		var known := held(id) or donated(id)
		out.append({
			"id": id,
			"label": String(row["name"]).to_upper(),
			# Zero gold, and the column says so. She does not buy and she does
			# not sell (GDD §6): the price of a donation is the object.
			"cost": 0,
			# **No `parts`.** The first cut carried `{id: 1}` here, on the reasoning
			# that the price IS the object and the concrete `Catalogue.crafts()`
			# would then make the row a hold with nothing overridden. It read wrong
			# on the frame: `TradeScreen._recipe` prices a parts token against
			# `Game.component_count`, which is 0 for a relic and always will be, so
			# all twelve rows drew a RUST "1 WEIGHTS" -- "you need one of these and
			# you have none" printed over a relic that was in the player's hand.
			# The quantity column says "1 LEFT" / "0 LEFT" off `remaining()` now,
			# which is what a checklist of twelve wants to say anyway, and the hold
			# comes from the `crafts()` override below.
			"blurb": String(row["lore"]) if known else _unwritten(row),
			"detail": String(row["detail"]),
		})
	return out


## The catalogue entry for a relic nobody has brought in. Not a teaser and not a
## riddle: the Society's ledger has a line for the object and a note of where it
## is believed to be, because that is what an honest catalogue of things you
## have not found looks like.
static func _unwritten(row: Dictionary) -> String:
	return "Not recovered. Believed still at %s." % where_text(row["id"]).to_lower()


## One to record, or none left once it is recorded. Never -1: "unlimited" is
## exactly the wrong answer about an object there is one of.
##
## A relic you have not found still answers 1. There IS one, and the refusal
## says where -- answering 0 would grey the row out as though the thing were
## already spoken for.
static func remaining(id: StringName) -> int:
	return 0 if donated(id) else 1


static func can_buy(line: Dictionary) -> bool:
	return held(line["id"])


## Why not, in the player's words. The same contract the smith's keeps and for a
## sharper version of the same reason: "NOT ENOUGH GOLD" on this counter would
## be a lie every single time, and the only useful thing this footer can say
## about a relic you do not have is **where it is**.
static func refusal(line: Dictionary) -> String:
	var id: StringName = line["id"]
	if donated(id):
		return "ALREADY RECORDED"
	if not held(id):
		return "NOT RECOVERED. %s" % where_text(id)
	return ""


## Hand it over. No gold moves and no component moves -- the whole bill is the
## object, and the object is a flag.
##
## Checked-then-charged like the other two counters, even though there is
## nothing here to leave half-paid: the shape is the contract, and the next
## person to add a line to this function will add it under a guard that already
## holds.
static func buy(line: Dictionary) -> bool:
	if not can_buy(line):
		return false
	var id: StringName = line["id"]
	Game.set_flag(flag_donated(id))
	# The counter's chime, and the cue every existing listener already handles
	# by ignoring the id (`Sfx`, `HeroCombat`). What was acquired is the unlock
	# and the lamp, not the relic -- the player just gave that away -- but the
	# garrison gained something, which is the only thing this signal has ever
	# meant.
	Bus.item_acquired.emit(id)
	return true


## A donation is a HOLD.
##
## This is the one override of `Catalogue.crafts` in the game, and the base
## class's warning against it is about a shop ANSWERING DIFFERENTLY -- committing
## as a hold at one counter and a tap at the next. This answers the same: yes,
## hold. What it cannot do is answer it the same way the other two do, through a
## `parts` recipe, because a relic is not a component and the recipe column
## priced it as one (see `lines()`).
##
## Reached because `TradeScreen` asks through the catalogue it was handed
## (`_db().crafts(line)`) rather than bare inside `Catalogue`, which is exactly
## the distinction the note on `Catalogue.craft_verb` was written about.
##
## **Why hold, when the mistake is nearly harmless.** You can only donate a relic
## you are holding, every relic is eventually donated, and the order barely
## matters -- so the hold is NOT protecting against a misallocation the way the
## forge's is (a Cold Iron Core spent on the wrong ladder is a whole run gone).
## It is here for the other half of `Catalogue.crafts`'s reason: the thing being
## spent is FOUND, it is one of twelve, it never rolls and it never comes back.
## The half second is the game saying *this one only happens once*, which is true
## here in a way it is not true of anything else on any counter in the garrison.
static func crafts(_line: Dictionary) -> bool:
	return true


# --- The unlocks ------------------------------------------------------------
# Every accessor here returns the UNMODIFIED value when its relic is not
# donated, so a caller adopts it unconditionally and never grows a branch. That
# is the whole reason they exist rather than callers reading `donated()`:
# `if RelicDb.donated(...)` at a call site is the unlock implemented twice.

## How many rungs of every forge ladder the smith knows how to make. 1 until the
## Tally-Ledger, 2 until the Imperium Anvil-Plate, K.FORGE_MAX after.
##
## `ShopDb` clamps its ladders to this: a rung above what the smith knows is not
## a line he refuses, it is a line that has not appeared yet.
static func forge_rungs_known() -> int:
	var n := 1
	for id in RUNG_RELICS:
		if not donated(id):
			break
		n += 1
	return mini(n, K.FORGE_MAX)


## Can the alchemist make this draught yet? True for anything not in
## `DRAUGHT_RELICS` -- the Heart Draught is hers from the start, and a recipe
## added later defaults to knowable rather than to silently locked.
static func knows_draught(potion: StringName) -> bool:
	if not DRAUGHT_RELICS.has(potion):
		return true
	var id: StringName = DRAUGHT_RELICS[potion]
	return donated(id)


## How many bottles the alchemist will blow, given the ceiling she would
## otherwise work to (`K.BOTTLE_MAX`). Two until the Glass-Kiln Core.
static func bottle_cap(base: int) -> int:
	return base if donated(&"kiln_core") else mini(base, BOTTLES_WITHOUT_CORE)


## Arrows out of one fletching batch, given the recipe's own yield
## (`Fletching.BATCH`).
static func fletch_yield(base: int) -> int:
	return FLETCH_WITH_JIG if donated(&"fletchers_jig") else base


## Multiplier on what the vendor PAYS for a line of the bag. A lit market is a
## market people bring money to.
##
## Applied to the vendor's side only. It deliberately does not touch the
## extraction fee, which is a fraction of the same bag value -- the Pillar-Shard
## should make selling better, not make leaving cheaper, and the relic that
## makes leaving cheaper is the Rope-Drum.
static func vendor_price_mult() -> float:
	return VENDOR_MULT_LIT if donated(&"pillar_shard") else 1.0


## Multiplier on the smith's STOCK lines -- arrows, bag slots, heart containers.
## Not the forge ladders (see SMITH_MULT_MILL).
static func smith_stock_mult() -> float:
	return SMITH_MULT_MILL if donated(&"waterwheel_gear") else 1.0


## The fraction of the bag's value that leaving costs, given the rate the run
## would otherwise pay (`Run.EXTRACT_RATE`).
##
## This is the closest any relic comes to power and it is still not a stat: it
## is a discount on LEAVING, which makes the one question (GDD §2) slightly
## easier to answer in the player's favour and changes nothing about what they
## can survive on the way down.
static func extract_rate(base: float) -> float:
	return RATE_WITH_DRUM if donated(&"rope_drum") else base


## Does the floor's deep chest announce itself on arrival? The only wayfinding
## in the game -- there is no map screen, and the Sounding-Rod is the answer to
## "where is the good chest" (GDD §10).
static func chest_hums() -> bool:
	return donated(&"sounding_rod")


## Can a run start at a shortcut you have already opened, from the garrison
## gate? Still not fast travel: the only doors it offers are ones you opened by
## killing the boss whose item opens them (GDD §5.3, SCOPE §2).
static func garrison_shortcuts() -> bool:
	return donated(&"warp_stone")
