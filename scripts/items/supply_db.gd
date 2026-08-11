class_name SupplyDb
extends Catalogue
## What the quartermaster STOCKS: the three things you carry more of.
##
## **These three lines were the smith's until 2026-08-11 and they were in the
## wrong shop, which only became visible when the smith stopped being in the yard
## on the first frame.** `StoryDb.UNLOCKS` now holds Brannoc back until the floor
## 1 miniboss is down (card #91), and every rung of that first hour -- a bag slot,
## a heart container, a fresh ten of arrows -- was locked behind a counter the
## player could not reach. A hero could buy a sharpening he had no components for
## and could not buy the bag slot he had the gold for.
##
## They also never belonged at a forge on their own terms. A smith MENDS things
## (`StoryDb.BEATS.smith.the_forge`: "I don't make things here. I mend them");
## Kessa is a quartermaster, and a quartermaster is exactly the person who issues
## you a bigger pack, a ration of arrows and -- as far as this outpost's paperwork
## is concerned -- another heart. Nothing about the three lines changed in the
## move: the same ids, the same prices, the same `LIMITS`, the same growth
## factors, so a save written before the move loads with its `Game.upgrades`
## intact and finds the ladders exactly where it left them, behind a different
## face.
##
## A `Catalogue`, so this cost one file and one row in `Npc.COUNTERS` -- see
## `Catalogue` for why a counter is never a second screen. It is the FIFTH
## catalogue and the first that shares a keeper with another counter: Kessa has
## two, a SELL screen for the bag and this, and `Npc._options` offers both.
##
## Everything here is PERMANENT and lives on `Game`. Nothing here eats components,
## so `Catalogue.crafts` is false for every row and the whole board is a tap --
## which is right, and is the difference between this counter and the forge: a
## bag slot is bought with money you can go and earn again.

## Purchases you can only make so many times, and how many. The bag's ceiling is
## read by `MenuPouchPanel` (it sizes the grid to the biggest bag that can exist),
## so this constant is load-bearing outside this file.
const LIMITS := {
	&"bag_slot": 4,
	&"heart": 3,
}

## Lines that DO NOT EXIST until the player owns the thing they are about.
##
## One row, and it is the same rule `ShopDb.GATED_BY` keeps for the bow's ladders:
## ammunition you cannot fire is a slot that lies. Absent rather than greyed --
## a row for a weapon you have never seen is a spoiler.
const GATED_BY := {
	&"arrows": &"bow",
}


static func emblem() -> StringName:
	return &"bag"  ## The pack she issues you.


## Nothing here is made, so nothing here is held. The verb exists because
## `Catalogue` promises it; `crafts()` is false for all three rows, so
## `TradeScreen` never says it.
static func craft_verb() -> String:
	return "BUY"


static func lines() -> Array[Dictionary]:
	var shown: Array[Dictionary] = []
	for line in _board():
		if stocked(line["id"]):
			shown.append(line)
	return shown


## Three rows, and two of them are ladders. BAG SLOT is four purchases at rising
## prices and HEART CONTAINER is three; drawn flat, a player two from the end of
## either had no way to see it. Arrows have no ceiling, so they get the plain
## named cell a repeatable gets.
static func groups() -> Array[Dictionary]:
	var rows: Array[Dictionary] = lines()
	var at := {}
	for i in rows.size():
		at[rows[i]["id"]] = i

	var out: Array[Dictionary] = []
	if stocked(&"arrows"):
		var i: int = at.get(&"arrows", -1)
		if i >= 0:
			out.append({"title": "ARROWS", "tracks": [{
				"name": String(rows[i]["label"]), "line": i, "owned": 0,
				"rungs": 1}]})
	out.append({"title": "THE BAG", "tracks": [
		_track(at, &"bag_slot", "", int(LIMITS[&"bag_slot"]))]})
	out.append({"title": "HEARTS", "tracks": [
		_track(at, &"heart", "", int(LIMITS[&"heart"]))]})
	return out


static func _track(at: Dictionary, id: StringName, branch: String,
		rungs: int) -> Dictionary:
	return {
		"name": branch,
		"line": int(at.get(id, -1)),
		"owned": int(Game.upgrades.get(id, 0)),
		"rungs": rungs,
	}


## Is `id` on the counter at all? The same distinction `ShopDb.stocked` draws: a
## finished ladder is still a row (with a refusal on it), an ungated one is no row.
static func stocked(id: StringName) -> bool:
	if not GATED_BY.has(id):
		return true
	var needs: StringName = GATED_BY[id]
	return Game.has(needs)


static func _board() -> Array[Dictionary]:
	return [
		{
			"id": &"arrows",
			"label": "ARROWS X10",
			"cost": _scaled(40, &"", 1.0),
			"parts": {},
			"blurb": "Fletched from something that used to fly.",
			"detail": "%d / %d arrows" % [Game.arrows, Game.max_arrows],
		},
		{
			"id": &"bag_slot",
			"label": "BAG SLOT",
			"cost": _scaled(140, &"bag_slot", 1.6),
			"parts": {},
			"blurb": "One more thing you can carry, and lose.",
			"detail": "%d slots -> %d" % [Game.bag_slots, Game.bag_slots + 1],
		},
		{
			"id": &"heart",
			"label": "HEART CONTAINER",
			"cost": _scaled(320, &"heart", 1.5),
			"parts": {},
			"blurb": "One more heart. It does not grow back on its own.",
			"detail": "%d hearts -> %d" % [
				Game.max_quarters / K.HEART, Game.max_quarters / K.HEART + 1],
		},
	]


static func _scaled(base: int, id: StringName, factor: float) -> int:
	if id == &"":
		return base
	var owned: int = Game.upgrades.get(id, 0)
	return int(round(base * pow(factor, float(owned))))


static func remaining(id: StringName) -> int:
	if not LIMITS.has(id):
		return -1
	return maxi(0, int(LIMITS[id]) - int(Game.upgrades.get(id, 0)))


static func can_buy(line: Dictionary) -> bool:
	var id: StringName = line["id"]
	if remaining(id) == 0:
		return false
	if id == &"arrows" and Game.arrows >= Game.max_arrows:
		return false
	return Game.gold >= int(line["cost"])


static func refusal(line: Dictionary) -> String:
	var id: StringName = line["id"]
	if remaining(id) == 0:
		return "NOTHING LEFT TO DO THERE"
	if id == &"arrows" and Game.arrows >= Game.max_arrows:
		return "THE QUIVER IS FULL"
	if Game.gold < int(line["cost"]):
		return "NOT ENOUGH GOLD"
	return ""


## Gold only -- there is nothing here to spend a component on. Checked then
## charged, so a refusal can never leave the player half-paid.
static func buy(line: Dictionary) -> bool:
	if not can_buy(line):
		return false
	var id: StringName = line["id"]
	if not Game.spend_gold(int(line["cost"])):
		return false

	Game.upgrades[id] = int(Game.upgrades.get(id, 0)) + 1
	match id:
		&"arrows":
			Game.add_arrows(10)
		&"bag_slot":
			Game.bag_slots += 1
		&"heart":
			# Derived from `upgrades`, which the line above has already bumped, so
			# there is no second copy of "how many hearts have been bought".
			Game.resync_maxima(true)
	Bus.item_acquired.emit(id)
	return true
