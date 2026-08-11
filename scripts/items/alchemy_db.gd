class_name AlchemyDb
extends Catalogue
## What the alchemist will make you. Four lines: the bottle, and three things to
## put in it. **Everything here is BREWED**, and that is the whole of what he is
## for.
##
## **The Burst's charges were a fifth line here until 2026-08-11 and they are the
## quartermaster's now** (card #98, `SupplyDb`). Nothing about them changed --
## same batch of three, same 90 gold, same gate on owning the working -- and the
## argument for moving them was written on this file before anyone acted on it:
## `_charge_line`'s own comment said a charge "is not brewed out of anything the
## floor drops... which is the smith's arrow line and not her bench". The arrow
## line is Kessa's now, so the charges went where they had always belonged. It
## also unhid them by a whole boss: he does not stand in the yard until one is
## dead (`StoryDb.UNLOCKS`) and she is unconditional, so a hero who took Burst off
## the Slag Ogre no longer has to wait for a counter to spend gold at.
##
## **The same shape as `ShopDb`, deliberately and exactly** -- which is now a
## thing the parser knows rather than a promise in a comment: both extend
## `Catalogue`, and the five statics below are its contract. The trade screen
## holds whichever catalogue it was opened with and never asks which.
##
## The transaction is Moonlighter's: **gold AND materials**, over a counter, for
## a thing you carry back down. The smith sells permanence and the alchemist
## sells a consumable, so the two dials are set differently -- the forge's
## prices RAMP because a rung is forever, and a draught costs the same every
## time because a draught is gone by the next room. What limits the brewing is
## not price, it is the four slots and what the floor gave you.

## What each bottle after the first costs in glass, in order. Index 0 is the
## SECOND bottle, so `BOTTLE_PARTS[bought]` is always "what the next one costs".
##
## Read down the column: cullet climbs steeply because glass is common and the
## slot is not, and the LAST one wants Mourning Dew, which never falls off a
## body. That is the same pacing gate the forge's Cold Iron Core is (METAGAME
## §6.5), for the same reason -- the fourth bottle should be a thing you found,
## not a thing you saved up for.
const BOTTLE_PARTS := [
	{&"fired_cullet": 4},
	{&"fired_cullet": 8, &"ash_resin": 2},
	{&"fired_cullet": 14, &"mourning_dew": 1},
]

## Draught id -> what one brew costs. Root is the cheap common tax on the heal;
## resin is what the two lasting draughts are made of, which is why a run that
## found resin is a run that gets to choose between offence and defence rather
## than being handed both.
const BREW_PARTS := {
	&"heart_draught": {&"bitter_root": 3},
	&"ironhide_draught": {&"ash_resin": 2, &"bitter_root": 2},
	&"emberblood_draught": {&"ash_resin": 3},
}

## Gold, per brew. Flat, and cheap against the smith's lines on purpose: the
## draught's real price is the slot it sits in and the materials it ate. A ramp
## here would make the tenth Heart Draught cost more than the first, which is
## nonsense for a thing you drink.
const BREW_GOLD := {
	&"heart_draught": 55,
	&"ironhide_draught": 85,
	&"emberblood_draught": 95,
}

## Base gold for a bottle, and how steeply it climbs. Steeper than anything at
## the smith (×2.4 against ×2.1) because the bottle is the only line here that
## is permanent, and because the fourth one should hurt.
const BOTTLE_GOLD := 110
const BOTTLE_GROWTH := 2.4



## The board, top to bottom. The bottle first: it is the line that makes the
## other three usable, and a player standing here with no empty bottle has to be
## looking at the answer.
static func craft_verb() -> String:
	return "BREW"


static func emblem() -> StringName:
	return &"bottle"  ## Her blown glass.


## Sieved through `RelicDb.knows_draught()`, exactly as the smith's ladders are
## sieved through `RelicDb.forge_rungs_known()`.
##
## **A recipe she has not learned is a line that has not APPEARED yet**, not a
## line she refuses -- same rule as `ShopDb.stocked()`, and for the same reason:
## a greyed-out row with "NOT RECOVERED, CISTERN VAULT" under it turns her board
## into a second copy of the Lanternkeeper's checklist, and the relic list is the
## quest log (`docs/SCOPE.md` §1). The Cracked Still-Head and the Cinder-Retort
## are what put Ironhide and Emberblood here (GDD §6.2, relics 3 and 4).
##
## Adopted with no `if`: `knows_draught()` answers true for anything not in
## `RelicDb.DRAUGHT_RELICS`, so the Heart Draught -- and any recipe added later
## that forgets to ask -- is hers from the start.
static func lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = [_bottle_line()]
	for id in PotionDb.IDS:
		if not RelicDb.knows_draught(id):
			continue
		out.append(_brew_line(id))
	return out


## Two rows, because she sells two different kinds of thing and the flat board
## made them look like one.
##
## Glass is a LADDER: four bottles at rising prices, and how many you have is the
## only cap on everything under it. Draughts are repeatables -- a Heart Draught
## is a Heart Draught however many you have brewed -- so they share one wrapping
## row of plain named cells, which is what they already looked like.
static func groups() -> Array[Dictionary]:
	var rows: Array[Dictionary] = lines()
	if rows.is_empty():
		return []

	var out: Array[Dictionary] = []
	# `_bottle_line` is always `lines()[0]`; asserting that here rather than
	# searching for the id, because if it ever stops being true the glass row is
	# the wrong length and that is worth failing loudly over.
	out.append({"title": "GLASS", "tracks": [{
		"name": "",
		"line": 0 if Game.bottle_count() < K.BOTTLE_MAX else -1,
		"owned": Game.bottle_count() - K.BOTTLE_START,
		"rungs": K.BOTTLE_MAX - K.BOTTLE_START,
	}]})
	# Everything after the glass is a draught, and `flat_group` is still not what
	# builds it. A third row (CHARGES) lived here until the charges moved to the
	# quartermaster, and the loop is kept in that shape on purpose: `flat_group`
	# takes everything from an index to the END, so the day he sells a fourth kind
	# of thing it would swallow it into the draughts silently. Sorting by id is
	# what makes a new line land in the row it belongs in. `line` still indexes
	# `lines()`, which is the only coupling this row has.
	var draughts: Array = []
	for i in range(1, rows.size()):
		draughts.append({"name": String(rows[i].get("label", "")), "line": i,
			"owned": 0, "rungs": 1})
	if not draughts.is_empty():
		out.append({"title": "DRAUGHTS", "tracks": draughts})
	return out


static func _bottle_line() -> Dictionary:
	var owned := Game.bottle_count()
	return {
		"id": &"bottle",
		"label": "BLOW A BOTTLE",
		"cost": int(round(BOTTLE_GOLD * pow(BOTTLE_GROWTH, float(maxi(owned - K.BOTTLE_START, 0))))),
		"parts": next_bottle_parts(),
		"blurb": "Glass, breath and patience. It comes out of the fire clear.",
		"detail": ("%d bottles -> %d" % [owned, owned + 1]) if owned < K.BOTTLE_MAX
			else "%d bottles  (all of them)" % owned,
	}


## `detail` says what the draught DOES, generated from K through PotionDb, and
## then how many empties are waiting -- which is the number that decides whether
## the player can press the button at all.
static func _brew_line(id: StringName) -> Dictionary:
	return {
		"id": id,
		"label": PotionDb.name_of(id).to_upper(),
		"cost": int(BREW_GOLD.get(id, 0)),
		"parts": BREW_PARTS.get(id, {}),
		"blurb": PotionDb.blurb_of(id),
		# Parenthesised and spaced rather than separated by a middle dot. Cinzel
		# has no `·`, so it arrives from the system fallback in a foreign face
		# -- ASCII only in anything CanvasText renders, and the smith's
		# "8.7 -> 11.9 m reach  (finished)" is the house shape for a trailing aside.
		"detail": "%s   (%d empty of %d)" % [
			PotionDb.effect_of(id), Game.empty_bottles(), Game.bottle_count()],
	}




## What the NEXT bottle costs in materials, or `{}` when you own all four.
static func next_bottle_parts() -> Dictionary:
	var bought := Game.bottle_count() - K.BOTTLE_START
	if bought < 0 or bought >= BOTTLE_PARTS.size():
		return {}
	return BOTTLE_PARTS[bought]


## How many more of `id` the player may buy. -1 means unlimited, which every
## draught is: what limits brewing is the empty bottle, enforced in `can_buy`,
## not a count of how many you have already made.
##
## The ceiling goes through `RelicDb.bottle_cap()`, which hands back
## `K.BOTTLE_MAX` untouched once the Glass-Kiln Core is in the ledger and clamps
## to two before it (GDD §6.2, relic 5). Two whole slots, so the relic is worth
## finding rather than being a discount -- and no branch here, because the
## accessor already contains the only `if` there is.
static func remaining(id: StringName) -> int:
	if id != &"bottle":
		return -1
	return maxi(0, RelicDb.bottle_cap(K.BOTTLE_MAX) - Game.bottle_count())


## Is this line a draught, as opposed to the glass it goes in? Asked rather than
## inferred from `id != &"bottle"`, which is what the two lines below used to do
## and which quietly made the charge line -- when there was one here -- require an
## empty bottle. Every non-glass row is a brew again today; the question is kept
## asked properly because that is exactly the state it was in last time.
static func _is_brew(id: StringName) -> bool:
	return PotionDb.IDS.has(id)


static func can_buy(line: Dictionary) -> bool:
	var id: StringName = line["id"]
	if remaining(id) == 0:
		return false
	# A brew needs somewhere to go. Checked here rather than at the press, so the
	# row greys out the moment the last bottle is filled and the player can see
	# what is stopping them before they reach for it.
	if _is_brew(id) and Game.empty_bottles() <= 0:
		return false
	if not Game.can_afford_parts(line.get("parts", {})):
		return false
	return Game.gold >= int(line["cost"])


## Why a line is refused, in one phrase, for the footer. Same contract as
## `ShopDb.refusal` and the same reason it exists: "NOT ENOUGH GOLD" on a bench
## that is short of root sends the player back down for the wrong thing.
static func refusal(line: Dictionary) -> String:
	var id: StringName = line["id"]
	# True at two bottles and true at four, which is what lets it stay one
	# sentence. It USED to read "YOU HAVE ALL THE GLASS YOU WILL GET", which
	# became a lie the moment `remaining()` started clamping to the Glass-Kiln
	# Core: a player stopped at two would have been told the ceiling was
	# permanent. The Lanternkeeper's board is where "and here is how to raise it"
	# is written -- the relic list is the quest log (docs/SCOPE.md §1) -- so this
	# footer states the fact and does not branch on why.
	if remaining(id) == 0:
		return "THAT IS ALL THE GLASS SHE CAN BLOW"
	if _is_brew(id) and Game.empty_bottles() <= 0:
		return "NO EMPTY BOTTLE"
	var parts: Dictionary = line.get("parts", {})
	for pid: StringName in parts:
		if Game.component_count(pid) < int(parts[pid]):
			var def := ItemDb.get_def(pid)
			var what: String = def.display_name if def != null else String(pid)
			return "NOT ENOUGH %s" % what.to_upper()
	if Game.gold < int(line["cost"]):
		return "NOT ENOUGH GOLD"
	return ""


## Take the money AND the materials, then make the thing. Checked-then-charged,
## exactly as the forge is: `can_buy` has already said the whole bill is payable,
## so nothing below can leave a player short of a bottle they paid for.
static func buy(line: Dictionary) -> bool:
	if not can_buy(line):
		return false
	var id: StringName = line["id"]
	var parts: Dictionary = line.get("parts", {})
	if not Game.spend_gold(int(line["cost"])):
		return false
	for pid: StringName in parts:
		Game.spend_component(pid, int(parts[pid]))

	if id == &"bottle":
		Game.add_bottle()
	elif Game.fill_bottle(id) < 0:
		# Unreachable while `can_buy` gates on an empty bottle, and checked
		# anyway: this is the one branch where the player has already been
		# charged, and a silent failure here is a theft.
		push_error("AlchemyDb: brewed %s with no empty bottle to put it in" % id)
		return false
	Bus.item_acquired.emit(id)
	return true
