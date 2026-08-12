class_name PatronDb
extends RefCounted
## The six presences of the Votive Court and the blessings each may answer with.
## Vallen has presentation data for the broken monument, but is never part of
## the selectable court and therefore never answers an offering.

const LADY_LONG_WATER := &"lady_long_water"
const LAST_GUEST := &"last_guest"
const OLD_HARROW := &"old_harrow"
const OLD_MAN_MOUNTAIN := &"old_man_mountain"
const GOOD_NEIGHBOR := &"good_neighbor"
const GREY_WALKER := &"grey_walker"
const VALLEN := &"vallen"

const OFFER_SIZE := 3

## `static var`, not `const`: these rows contain another class's constants,
## which are not constant expressions in GDScript.
static var PATRONS := {
	LADY_LONG_WATER: {
		"name": "Lady of Long Water",
		"epithet": "She remembers every shore.",
		"rite": "A basin filled from running water.",
		"color": Color("68a9bd"),
		"kind": &"basin",
		"blessings": [EchoDb.SLOW_FADE, EchoDb.RETURNING_SHAFT],
	},
	LAST_GUEST: {
		"name": "Last Guest",
		"epithet": "The final light at a barred door.",
		"rite": "An unlit lamp set before a closed door.",
		"color": Color("c48a62"),
		"kind": &"door",
		"blessings": [EchoDb.SECOND_WIND, EchoDb.BLAZING_TITHE],
	},
	OLD_HARROW: {
		"name": "Old Harrow",
		"epithet": "Keeper of the turned furrow.",
		"rite": "A crooked spade bound with new growth.",
		"color": Color("7fa66b"),
		"kind": &"harrow",
		"blessings": [EchoDb.DEEP_POCKET, EchoDb.FULL_CUP],
	},
	OLD_MAN_MOUNTAIN: {
		"name": "Old Man Under the Mountain",
		"epithet": "The sealed heart below.",
		"rite": "A cairn stacked over a shut seam.",
		"color": Color("b29a68"),
		"kind": &"mountain",
		"blessings": [EchoDb.ANSWERING_STRIKE, EchoDb.QUIET_ROOM],
	},
	GOOD_NEIGHBOR: {
		"name": "Good Neighbor",
		"epithet": "The warmth beyond the wall.",
		"rite": "An empty chair drawn close to the hearth.",
		"color": Color("c8796f"),
		"kind": &"neighbor",
		"blessings": [EchoDb.HELD_NOTE, EchoDb.COLD_LEDGER],
	},
	GREY_WALKER: {
		"name": "Grey Walker",
		"epithet": "The road that does not end.",
		"rite": "A staff rested against a roadside cairn.",
		"color": Color("908aae"),
		"kind": &"walker",
		"blessings": [EchoDb.UNBROKEN_ROPE, EchoDb.LONG_CHORD],
	},
}

static var VALLEN_ROW := {
	"name": "Vallen",
	"epithet": "The broken maker.",
	"rite": "A split hammer laid beneath the ruined monument.",
	"color": Color("805d58"),
	"kind": &"vallen",
	"blessings": [],
}


static func all() -> Array[StringName]:
	return [
		LADY_LONG_WATER,
		LAST_GUEST,
		OLD_HARROW,
		OLD_MAN_MOUNTAIN,
		GOOD_NEIGHBOR,
		GREY_WALKER,
	]


static func row(id: StringName) -> Dictionary:
	if id == VALLEN:
		return VALLEN_ROW
	return PATRONS.get(id, {})


static func name_of(id: StringName) -> String:
	return String(row(id).get("name", "Unknown Patron"))


static func color_of(id: StringName) -> Color:
	var value: Variant = row(id).get("color", Color(0.42, 0.43, 0.45))
	return value as Color if value is Color else Color(0.42, 0.43, 0.45)


static func blessings_of(id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var values: Variant = row(id).get("blessings", [])
	if values is Array:
		for value: Variant in values:
			if value is StringName:
				out.append(value as StringName)
	return out


## Returns one floor-legal, unheld blessing from each of up to three distinct
## patrons. Both patron selection and blessing selection consume only `rng`, so
## replaying a run seed reproduces the same answering court.
static func offer(rng: RandomNumberGenerator, level: int,
		held: Dictionary = {}) -> Dictionary:
	var candidates: Array[StringName] = []
	for id in all():
		if not _eligible_blessings(id, level, held).is_empty():
			candidates.append(id)

	# Fisher-Yates deliberately avoids Array.shuffle(), which uses the global RNG.
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp

	var out: Dictionary = {}
	for i in mini(OFFER_SIZE, candidates.size()):
		var patron_id := candidates[i]
		var eligible := _eligible_blessings(patron_id, level, held)
		var blessing_id := eligible[rng.randi_range(0, eligible.size() - 1)]
		out[patron_id] = blessing_id
	return out


static func _eligible_blessings(id: StringName, level: int,
		held: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for blessing_id in blessings_of(id):
		if held.has(blessing_id):
			continue
		if level < EchoDb.floor_of(blessing_id):
			continue
		out.append(blessing_id)
	return out


## Proves the court's fixed partition and all player-facing data needed by the
## shrine and blessing menu. Empty means the table is sound.
static func validate() -> PackedStringArray:
	var out := PackedStringArray()
	var ids := all()
	if PATRONS.size() != 6 or ids.size() != 6:
		out.append("the selectable court must contain exactly six patrons")
	if ids.has(VALLEN) or PATRONS.has(VALLEN):
		out.append("Vallen is a broken monument and must never be selectable")

	var seen_names: Dictionary = {}
	var seen_colors: Dictionary = {}
	var blessing_counts: Dictionary = {}
	var echo_ids := EchoDb.all()
	for id in ids:
		var patron_row := row(id)
		if patron_row.is_empty():
			out.append("%s: missing patron row" % id)
			continue
		for field in ["name", "epithet", "rite"]:
			if String(patron_row.get(field, "")).strip_edges().is_empty():
				out.append("%s: missing presentation field %s" % [id, field])
		var kind: StringName = patron_row.get("kind", &"")
		if kind == &"":
			out.append("%s: missing prototype kind" % id)
		var color_value: Variant = patron_row.get("color")
		if not color_value is Color:
			out.append("%s: missing Color" % id)
		else:
			var color_key := (color_value as Color).to_html()
			if seen_colors.has(color_key):
				out.append("%s: color duplicates %s" % [id, seen_colors[color_key]])
			seen_colors[color_key] = id

		var display_name := String(patron_row.get("name", ""))
		if seen_names.has(display_name):
			out.append("%s: name duplicates %s" % [id, seen_names[display_name]])
		seen_names[display_name] = id

		var blessings := blessings_of(id)
		if blessings.size() != 2:
			out.append("%s: must own exactly two blessings" % id)
		for blessing_id in blessings:
			if not echo_ids.has(blessing_id):
				out.append("%s: %s is not an EchoDb row" % [id, blessing_id])
			blessing_counts[blessing_id] = int(blessing_counts.get(blessing_id, 0)) + 1

	if blessing_counts.size() != echo_ids.size():
		out.append("the patron partition must cover all 12 EchoDb rows")
	for echo_id in echo_ids:
		var count := int(blessing_counts.get(echo_id, 0))
		if count != 1:
			out.append("%s: covered %d times instead of once" % [echo_id, count])

	for field in ["name", "epithet", "rite", "kind", "color"]:
		if not VALLEN_ROW.has(field):
			out.append("Vallen: missing monument presentation field %s" % field)
	return out
