class_name ArmamentDb
extends RefCounted
## The player-facing face of an armament id: its name, its icon, and the line of
## text that says what it is for.
##
## `Game` owns which id is in which hand and knows nothing about how it looks.
## This is the one place that decides how &"bow" is spelled and drawn, so the
## equipment screen and the HUD cannot drift apart -- they did, once, when the
## HUD carried its own KIT_ICON table and the menu did not exist yet.
##
## Icons are the SAME textures the HUD strip uses: baked from the real models by
## tools/scenes/_iconbake.gd. See hud.gd for the regeneration command and the
## warning about what that baker overwrites.

const NAMES := {
	&"": "Empty Hand",
	&"sword": "Knightly Sword",
	&"shield": "Kite Shield",
	&"bow": "Knightly Bow",
	&"hookshot": "Hookshot",
	&"arrow": "Arrows",
}

const ICONS := {
	&"sword": "res://assets/ui/icons/hud/sword_knightly.png",
	&"shield": "res://assets/ui/icons/hud/kite_shield.png",
	&"hookshot": "res://assets/ui/icons/hud/hookshot_pistol.png",
	&"bow": "res://assets/ui/icons/hud/bow_knightly.png",
}

## Two letters for anything with no icon -- the empty hand, and arrows, which
## are a count rather than a thing you hold up. An empty cell would read as
## "you have no bow", which is a lie the UI must never tell.
const LETTERS := {
	&"": "—",
	&"sword": "SW",
	&"shield": "SH",
	&"bow": "BW",
	&"hookshot": "HK",
	&"arrow": "AR",
}

## One line, present tense, about what carrying it costs or buys. Shown on the
## equipment screen under the name.
const BLURBS := {
	&"": "Both hands free. Nothing to raise, nothing to hide behind.",
	&"sword": "Close work. Everything the game teaches you first.",
	&"shield": "Raise it and you stop moving like someone in a hurry.",
	&"bow": "For the thing that has not noticed you yet.",
	&"hookshot": "Crosses a gap, or brings the gap to you.",
	&"arrow": "Useless without the bow, which is why the bow gates them.",
}


## A BOTTLE is not an armament -- it never goes in a hand -- but it is bindable,
## and the two surfaces that draw a bound thing (the HUD cross and the Items
## screen) route every id through here. Answering for bottles in this one place
## is what keeps them from each growing a bottle branch of their own, which is
## exactly the drift the header above is about.
static func name_of(id: StringName) -> String:
	var b := Game.bottle_index(id)
	if b >= 0:
		var held := Game.bottle(b)
		return "Bottle %d — %s" % [b + 1,
			PotionDb.name_of(held) if held != &"" else "Empty"]
	return NAMES.get(id, String(id).capitalize())


## The same thing, short enough to sit in a slot card.
##
## `name_of` is written for the DETAIL pane, which has a column to itself; the
## cards on the Items screen are about 200 px wide and every armament name
## happens to fit ("Knightly Sword", "Kite Shield"), so nothing enforced it.
## "Bottle 3 — Emberblood Draught" does not fit: it ran off its card and printed
## over the neighbour's, and the capture at a_04b_equip caught it doing that.
## The card is not losing information -- the glyph above it already shows the
## draught's short name, and the detail pane spells the whole thing out.
static func slot_name(id: StringName) -> String:
	var b := Game.bottle_index(id)
	return "Bottle %d" % (b + 1) if b >= 0 else name_of(id)


static func letter(id: StringName) -> String:
	var b := Game.bottle_index(id)
	if b >= 0:
		var short := PotionDb.short_of(Game.bottle(b))
		return short if short != "" else "—"
	return LETTERS.get(id, "?")


static func blurb(id: StringName) -> String:
	var b := Game.bottle_index(id)
	if b >= 0:
		return PotionDb.blurb_of(Game.bottle(b))
	return BLURBS.get(id, "")


## Null when the id has no icon -- callers fall back to `letter()` rather than
## drawing nothing.
static func icon(id: StringName) -> Texture2D:
	var path: String = ICONS.get(id, "")
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## The counter an armament spends, or &"" if it spends nothing. The equipment
## screen shows this next to the icon so "arrows" is never just a word.
static func ammo_of(id: StringName) -> StringName:
	match id:
		&"arrow": return &"arrows"
		&"bow": return &"arrows"
	return &""
