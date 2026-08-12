class_name SupplyDb
extends Catalogue
## What the quartermaster offers across her two services: repeatable stock in
## Trade, and permanent bag/heart progression under Upgrades.
##
## **Six rows now, and four of them are Trade stock** (card #98, 2026-08-11).
## Arrows, Burst charges, food and drink are the expendables -- the things you buy
## in the yard, take down, and come back without. Two of the four arrived from
## other counters and two are new, and the sentence that admits all four is the
## one Kessa says about herself: a quartermaster ISSUES. She does not make
## anything and nothing on this board is crafted (`crafts()` is false for every
## row), which is the whole difference between this counter and the forge or the
## bench next door.
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
## A `Catalogue`, so both services share the same rows and purchase authority.
## `STOCK_IDS` and `UPGRADE_IDS` below are the single partition: the TradeScreen
## decides how to arrange them, but never decides which offering belongs where.
##
## Every transaction is gold-only and lives on `Game`: stock fills a carried
## vessel, while the two upgrade rows permanently raise a limit. Nothing eats
## components, so `Catalogue.crafts` is false and every purchase is a tap.

## Purchases you can only make so many times, and how many. The bag's ceiling is
## read by `MenuPouchPanel` (it sizes the grid to the biggest bag that can exist),
## so this constant is load-bearing outside this file.
const LIMITS := {
	&"bag_slot": 4,
	&"heart": 3,
}

## The repeatable expendables shown on the quartermaster's two-sided Trade board.
const STOCK_IDS: Array[StringName] = [
	&"arrows", &"charges", &"hardtack", &"small_beer",
]

## The permanent linear ladders shown by her separate Upgrades service.
const UPGRADE_IDS: Array[StringName] = [&"bag_slot", &"heart"]

## Lines that DO NOT EXIST until the player owns the thing they are about.
##
## The same rule `ShopDb.GATED_BY` keeps for the bow's ladders: ammunition you
## cannot fire is a slot that lies. Absent rather than greyed -- a row for a
## weapon you have never seen is a spoiler, which for the charges is the sharper
## half of it: a player who has not reached the Foundry should not be sold ammo
## for a verb they have never seen.
const GATED_BY := {
	&"arrows": &"bow",
	&"charges": &"burst",
}

## How many charges come in a bundle, and what the bundle costs. **Both moved
## here from `AlchemyDb` unchanged on 2026-08-11** -- same batch, same price, so
## nobody's mental price list moved with the counter (card #98).
const CHARGE_BATCH := 3
const CHARGE_GOLD := 90

## What a purchase of food or drink costs, per `K.RATION_BATCH`.
##
## Priced against the arrow line's 40 for ten, which is the only other expendable
## on this counter: a biscuit is cheaper than an arrow because it is worth less
## and because the thing it actually costs is the twelve seconds. Drink is dearer
## than food for the reason the bars differ -- a heart comes back by walking home
## and the blue bar does not come back at all, so the drink is the only thing in
## the game that sells you a spin. [tune]
const RATION_GOLD := {
	&"hardtack": 25,
	&"small_beer": 45,
}


static func emblem() -> StringName:
	return &"bag"  ## The pack she issues you.


## Nothing here is made, so nothing here is held. The verb exists because
## `Catalogue` promises it; `crafts()` is false for every row, so `TradeScreen`
## never says it -- and `charge_buy.gd` beat C6 asserts that of the whole board
## rather than of one line, so the day a row grows a `parts` entry it fails.
static func craft_verb() -> String:
	return "BUY"


static func lines() -> Array[Dictionary]:
	var shown: Array[Dictionary] = []
	for line in _board():
		if stocked(line["id"]):
			shown.append(line)
	return shown


## The Upgrades service is two linear ladders. Trade consumes the same catalogue
## lines through `STOCK_IDS` and draws them as ordinary stock cells instead.
static func groups() -> Array[Dictionary]:
	var rows: Array[Dictionary] = lines()
	var at := {}
	for i in rows.size():
		at[rows[i]["id"]] = i

	var out: Array[Dictionary] = []
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
		# **The Burst's ammunition, and it was the alchemist's until 2026-08-11**
		# (card #98). It moved for the reason its own comment on his counter gave
		# while it sat there: "a charge is not brewed out of anything the floor
		# drops -- GDD §6.5 calls it a stock you paid for before you left, which
		# is the smith's arrow line and not her bench". That arrow line is now
		# Kessa's, three rows up, and a charge is the same kind of thing as it --
		# an expendable issued from a store, not a thing anybody makes.
		#
		# The move also unhides it by a whole boss. The alchemist does not stand in
		# the yard until one is dead (`StoryDb.UNLOCKS`), so a hero holding Burst
		# and no charges had nowhere to spend gold on the answer; Kessa is
		# unconditional. Nothing else changed in the move: same batch, same price,
		# same gate on owning the working.
		{
			"id": &"charges",
			"label": "CHARGES X%d" % CHARGE_BATCH,
			"cost": CHARGE_GOLD,
			"parts": {},
			"blurb": "Stoppered, and heavier than it looks. It does not come back once it is spent.",
			# The number the decision is actually about. They do NOT refill
			# underground (GDD §6.5), so what is in the pouch when you take the
			# rope down is the whole of what you get.
			"detail": "%d / %d charges" % [Game.charges, Game.max_charges],
		},
		_ration_line(&"hardtack"),
		_ration_line(&"small_beer"),
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


## One ration's row. Built rather than typed out twice: the two differ by an id, a
## price and which bar they feed, and every word the player reads about them
## already lives in `RationDb`.
##
## The `detail` is the STACK, not the effect -- the effect is the blurb's job and
## `RationDb.effect_of` writes it. What a player standing at this counter is
## deciding is whether they have room for five more, and "17 / 20 carried" is the
## only line that answers it.
static func _ration_line(id: StringName) -> Dictionary:
	return {
		"id": id,
		"label": "%s X%d" % [RationDb.name_of(id).to_upper(), K.RATION_BATCH],
		"cost": int(RATION_GOLD.get(id, 0)),
		"parts": {},
		"blurb": "%s %s" % [RationDb.blurb_of(id), RationDb.effect_of(id)],
		"detail": "%d / %d carried" % [Game.ration_count(id), K.RATION_STACK],
	}


static func _scaled(base: int, id: StringName, factor: float) -> int:
	if id == &"":
		return base
	var owned: int = Game.upgrades.get(id, 0)
	return int(round(base * pow(factor, float(owned))))


static func remaining(id: StringName) -> int:
	if id == &"charges":
		# The pouch's headroom in BUNDLES, rounded up, so a player one charge
		# short of full still sees a line they can press. `add_charges` clamps, so
		# the last bundle is a partial fill rather than a refusal -- exactly what
		# ARROWS X10 does against a quiver of 30. Moved from `AlchemyDb.remaining`
		# with the line itself and unchanged.
		return int(ceil(float(maxi(0, Game.max_charges - Game.charges))
			/ float(CHARGE_BATCH)))
	if RationDb.has(id):
		# Same shape, same reason, against the stack instead of the pouch.
		return int(ceil(float(maxi(0, K.RATION_STACK - Game.ration_count(id)))
			/ float(K.RATION_BATCH)))
	if not LIMITS.has(id):
		return -1
	return maxi(0, int(LIMITS[id]) - int(Game.upgrades.get(id, 0)))


## Is this line an expendable whose vessel is already full? One question asked in
## one place, because `can_buy` and `refusal` have to agree about it and the way
## they stop agreeing is by each growing their own `id ==` chain.
static func _full(id: StringName) -> bool:
	match id:
		&"arrows": return Game.arrows >= Game.max_arrows
		&"charges": return Game.charges >= Game.max_charges
	return RationDb.has(id) and Game.ration_count(id) >= K.RATION_STACK


static func can_buy(line: Dictionary) -> bool:
	var id: StringName = line["id"]
	if remaining(id) == 0 or _full(id):
		return false
	return Game.gold >= int(line["cost"])


static func refusal(line: Dictionary) -> String:
	var id: StringName = line["id"]
	# **`_full` is asked FIRST, and the order is the whole of this function.**
	# `remaining()` answers an expendable in BUNDLES, so a full quiver, pouch or
	# pack is also a `remaining() == 0` -- and with the ladder's phrase on top, a
	# player who could not buy another biscuit was told "NOTHING LEFT TO DO THERE",
	# which is what the board says about a heart container you have bought all
	# three of. It reads as a permanent ceiling on a line that will be pressable
	# again the moment you eat one. `rations.gd` beat B12 caught it; the ladders
	# are unaffected because `_full` is false for both of them.
	if _full(id):
		# Named per vessel rather than one "YOU ARE FULL", because the refusal is
		# also the only place the counter says WHERE the thing goes -- a player
		# who has never eaten does not yet know that food is a stack of twenty.
		match id:
			&"arrows": return "THE QUIVER IS FULL"
			&"charges": return "THE POUCH IS FULL"
		return "THE PACK IS FULL"
	# A finished LADDER, which is the one thing here that really is permanent.
	if remaining(id) == 0:
		return "NOTHING LEFT TO DO THERE"
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
		&"charges":
			# `add_charges` clamps at `max_charges` and emits `Bus.ammo_changed`,
			# which is what puts the new numeral in the HUD's working cell -- so
			# the counter and the cell cannot disagree.
			Game.add_charges(CHARGE_BATCH)
		&"hardtack", &"small_beer":
			Game.add_rations(id, K.RATION_BATCH)
		&"bag_slot":
			Game.bag_slots += 1
		&"heart":
			# Derived from `upgrades`, which the line above has already bumped, so
			# there is no second copy of "how many hearts have been bought".
			Game.resync_maxima(true)
	Bus.item_acquired.emit(id)
	return true
