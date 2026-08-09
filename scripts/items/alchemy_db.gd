class_name AlchemyDb
extends Catalogue
## What the alchemist will make you. Four lines: the bottle, and three things to
## put in it.
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


static func lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = [_bottle_line()]
	for id in PotionDb.IDS:
		out.append(_brew_line(id))
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
		# Parenthesised and spaced rather than separated by a middle dot. PixelFont
		# has no `·` and drew a missing-glyph box between the two halves of the
		# line -- ASCII only in anything this font renders, and the smith's
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
static func remaining(id: StringName) -> int:
	if id != &"bottle":
		return -1
	return maxi(0, K.BOTTLE_MAX - Game.bottle_count())


static func can_buy(line: Dictionary) -> bool:
	var id: StringName = line["id"]
	if remaining(id) == 0:
		return false
	# A brew needs somewhere to go. Checked here rather than at the press, so the
	# row greys out the moment the last bottle is filled and the player can see
	# what is stopping them before they reach for it.
	if id != &"bottle" and Game.empty_bottles() <= 0:
		return false
	if not Game.can_afford_parts(line.get("parts", {})):
		return false
	return Game.gold >= int(line["cost"])


## Why a line is refused, in one phrase, for the footer. Same contract as
## `ShopDb.refusal` and the same reason it exists: "NOT ENOUGH GOLD" on a bench
## that is short of root sends the player back down for the wrong thing.
static func refusal(line: Dictionary) -> String:
	var id: StringName = line["id"]
	if remaining(id) == 0:
		return "YOU HAVE ALL THE GLASS YOU WILL GET"
	if id != &"bottle" and Game.empty_bottles() <= 0:
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
