class_name ElderUpgradeDb
extends Catalogue
## The Elder's permanent quality-of-life services. These are ordinary gold-only
## catalogue ladders: this file records their rungs, while the bed, footlocker
## and garrison schedule read the public constants and `Game.upgrades` to apply
## the effects where those systems live.

const BED_ID := &"elder_bed"
const LOCKER_ID := &"elder_locker"
const REVEILLE_ID := &"elder_reveille"

const UPGRADE_IDS: Array[StringName] = [BED_ID, LOCKER_ID, REVEILLE_ID]
const LIMITS := {
	BED_ID: 3,
	LOCKER_ID: 2,
	REVEILLE_ID: 1,
}

const BED_OVERHEALTH_PER_RANK := K.QUARTER
const LOCKER_SLOTS_PER_RANK := 6

const _COSTS := {
	BED_ID: [120, 260, 480],
	LOCKER_ID: [180, 420],
	REVEILLE_ID: [350],
}

const RUNG_NAMES := {
	BED_ID: ["Wool Mattress", "Featherbed", "Restorative Bed"],
	LOCKER_ID: ["Pine Shelves", "Iron Shelves"],
	REVEILLE_ID: ["Dawn Bell"],
}


static func emblem() -> StringName:
	return &"locker"


## Nothing here consumes a found component, so every purchase is a tap.
static func craft_verb() -> String:
	return "BUY"


static func crafts(_line: Dictionary) -> bool:
	return false


## Always return all three tracks. A completed service remains on the board as
## a fully ticked ladder instead of vanishing and making its permanent effect
## look temporary.
static func lines() -> Array[Dictionary]:
	return [
		_line(BED_ID),
		_line(LOCKER_ID),
		_line(REVEILLE_ID),
	]


static func summary(id: StringName) -> Dictionary:
	if not UPGRADE_IDS.has(id):
		return {}
	var line: Dictionary = _line(id)
	var owned: int = clampi(int(Game.upgrades.get(id, 0)), 0, int(LIMITS[id]))
	return {
		"label": String(line["label"]),
		"owned": owned,
		"limit": int(LIMITS[id]),
		"effect": _effect_text(id, owned),
	}


static func groups() -> Array[Dictionary]:
	var rows: Array[Dictionary] = lines()
	var at := {}
	for i in rows.size():
		at[rows[i]["id"]] = i
	return [
		{"title": "QUARTERS", "tab": "QUARTERS", "icon": "quarters", "tracks": [
			_track(at, BED_ID, "BED"),
			_track(at, LOCKER_ID, "LOCKER"),
		]},
		{"title": "REVEILLE", "tab": "REVEILLE", "icon": "reveille", "tracks": [
			_track(at, REVEILLE_ID, ""),
		]},
	]


static func _track(at: Dictionary, id: StringName, name: String) -> Dictionary:
	return {
		"name": name,
		"line": int(at.get(id, -1)),
		"owned": int(Game.upgrades.get(id, 0)),
		"rungs": int(LIMITS[id]),
		"rung_names": _rung_names(id, int(LIMITS[id])),
	}


static func _rung_names(id: StringName, rungs: int) -> Array[String]:
	var authored: Array = RUNG_NAMES.get(id, [])
	var names: Array[String] = []
	for i in rungs:
		names.append(String(authored[i]) if i < authored.size()
			else "%s %d" % [String(id).replace("elder_", "").capitalize(), i + 1])
	return names


static func _line(id: StringName) -> Dictionary:
	var owned: int = maxi(0, int(Game.upgrades.get(id, 0)))
	var done := owned >= int(LIMITS[id])
	var cost := 0 if done else int((_COSTS[id] as Array)[owned])
	match id:
		BED_ID:
			return {
				"id": id,
				"label": "A BETTER BED",
				"cost": cost,
				"parts": {},
				"blurb": "Sleep fully heals. Each rank grants 1/4 heart of temporary overhealth.",
				"detail": "Complete: sleep grants 3/4 heart of temporary overhealth." if done \
					else "Temporary overhealth: %d/4 heart -> %d/4 heart." % [owned, owned + 1],
			}
		LOCKER_ID:
			var slots := owned * LOCKER_SLOTS_PER_RANK
			return {
				"id": id,
				"label": "FOOTLOCKER SHELVES",
				"cost": cost,
				"parts": {},
				"blurb": "Each rank adds 6 slots to the footlocker.",
				"detail": "Complete: +12 footlocker slots." if done \
					else "Footlocker capacity bonus: +%d slots -> +%d slots." % [
						slots, slots + LOCKER_SLOTS_PER_RANK],
			}
		REVEILLE_ID:
			return {
				"id": id,
				"label": "EARLY REVEILLE",
				"cost": cost,
				"parts": {},
				"blurb": "Garrison services open one hour earlier.",
				"detail": "Complete: garrison services open at 06:00." if done \
					else "Service opening time: 07:00 -> 06:00.",
			}
	return {}


static func _effect_text(id: StringName, owned: int) -> String:
	match id:
		BED_ID:
			if owned <= 0:
				return "Sleep fully heals; no temporary overhealth."
			return "Sleep fully heals and grants %d/4 heart of temporary overhealth." % owned
		LOCKER_ID:
			if owned <= 0:
				return "No bonus footlocker slots."
			return "+%d footlocker slots." % (owned * LOCKER_SLOTS_PER_RANK)
		REVEILLE_ID:
			return "Garrison services open at %s." % (
				"06:00" if owned > 0 else "07:00")
	return ""


static func remaining(id: StringName) -> int:
	if not LIMITS.has(id):
		return -1
	return maxi(0, int(LIMITS[id]) - int(Game.upgrades.get(id, 0)))


static func can_buy(line: Dictionary) -> bool:
	var id: StringName = line["id"]
	if remaining(id) == 0:
		return false
	return Game.gold >= int(line["cost"])


static func refusal(line: Dictionary) -> String:
	var id: StringName = line["id"]
	if remaining(id) == 0:
		return "NOTHING LEFT TO DO THERE"
	if Game.gold < int(line["cost"]):
		return "NOT ENOUGH GOLD"
	return ""


## Checked then charged, matching the other gold-only catalogues. `spend_gold`
## emits `gold_changed`; `item_acquired` tells catalogue listeners which ladder
## advanced. Applying each effect belongs to its owning system, not this till.
static func buy(line: Dictionary) -> bool:
	if not can_buy(line):
		return false
	var id: StringName = line["id"]
	if not Game.spend_gold(int(line["cost"])):
		return false
	Game.upgrades[id] = int(Game.upgrades.get(id, 0)) + 1
	Bus.item_acquired.emit(id)
	return true
