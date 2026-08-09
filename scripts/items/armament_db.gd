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


static func name_of(id: StringName) -> String:
	return NAMES.get(id, String(id).capitalize())


static func letter(id: StringName) -> String:
	return LETTERS.get(id, "?")


static func blurb(id: StringName) -> String:
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
