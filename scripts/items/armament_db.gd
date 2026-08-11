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
	# The first of the three workings (`docs/GDD.md` §6.5). It is a ROW here and
	# nothing else -- no school, no mana, no casting layer. What makes a working
	# a working rather than a spell is that it arrives as a stop on the same ring
	# the sword is on, and this table is where that is decided.
	&"burst": "The Burst-Verse",
	# The other two (`docs/GDD.md` §6.5). They arrive by a different door -- Burst
	# comes off the Slag Ogre and these two are READ at the alchemist's counter,
	# which `Game.armament_owned()` asks `RelicDb.knows_working()` about -- and
	# once they are here they are the same kind of thing as Burst and get the
	# same four rows. That sameness is the acceptance criterion: if either of
	# these had needed a table of its own, the working would have stopped being a
	# usable item and started being a casting layer.
	&"sustain": "The Sustain-Verse",
	&"ballast": "The Ballast-Verse",
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
	# No icon, and not because one is missing: `tools/scenes/_iconbake.gd` bakes
	# these off the real MODELS, and a working has no model -- he casts it with
	# an empty hand. Two letters is the honest cell rather than a placeholder
	# glyph that would have to be un-drawn the day somebody asks what it is.
	&"burst": "BU",
	# Same reason, and the two letters are the first two of each name rather than
	# an initial and a flourish -- three cells reading BU / SU / BA on one ring
	# is a set a player can learn in one look, and a player who has all three has
	# them side by side.
	&"sustain": "SU",
	&"ballast": "BA",
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
	&"burst": "Read it and the air comes apart. Doors, mostly.",
	# Both blurbs name the COST, because that is what these two are for -- neither
	# raises a number (GDD §6.3), and a line that only said what you get would be
	# describing a buff.
	&"sustain": "The chain keeps one break. The fee keeps the difference.",
	&"ballast": "Burn the cheapest thing you came for. Wear it instead.",
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
		&"burst": return &"charges"
		# One pool for all three workings -- see the note over `K.BALLAST_TIME`.
		&"sustain": return &"charges"
		&"ballast": return &"charges"
	return &""


## The counter an armament **is**, rather than the one it spends -- `&""` for
## anything that is not itself a count.
##
## The difference is one cell on the HUD. Arrows are a count you put in the LEFT
## hand and charges are a count you put in the right one (`docs/GDD.md` §6.5 --
## "charges are arrows with a different noun"), and both of those cells want the
## number drawn in them. The BOW spends arrows and is not one, so it gets no
## numeral: a bow cell carrying the quiver's count would print the same number
## twice on one row, once under the stave and once under the arrows themselves.
##
## Here rather than in `hud.gd` because the equipment screen asks the same
## question, and the header above this file is about exactly the drift that
## starts when the HUD keeps its own copy of a table.
static func hand_count(id: StringName) -> StringName:
	match id:
		&"arrow": return &"arrows"
		&"burst": return &"charges"
		&"sustain": return &"charges"
		&"ballast": return &"charges"
	return &""


## The INPUT ACTION that fires the thing, or `&""` for anything that is not fired
## from a hand. HUD_PLAN decision 11.
##
## Keyed by ITEM and not by which hand or which corner, because that is the
## honest question: two-handing the sword moves the sword to the other hand and
## the button that swings it does not change.
##
## Note what this returns and what it does not. It is the *action*, never the cap
## text — `Glyph.cap()` reads the LIVE InputMap for that, because
## `user://settings.cfg` is replayed over the InputMap at boot and wins
## (CONTRACT §"The two ways this table has lied" #2), so the shipped binding and
## the player's binding are different questions and only one of them is on the
## player's keyboard. A table of cap strings here would be the second copy, and
## the second copy is the one that goes stale.
##
## Here rather than in `hud.gd` for the reason in this file's header: the HUD
## kept its own `KIT_ACTION` and the equipment screen wants the same fact, which
## is the shape every drift in this project has started in.
static func action_of(id: StringName) -> StringName:
	match id:
		&"sword": return &"attack"
		&"shield": return &"shield"
		# Both shoulder buttons fire a drawn item (`Hud._tick_item_trigger`); the
		# cap names the one a player already associates with "use what is in my
		# hand", rather than making the cell ask which trigger they meant.
		&"bow": return &"attack"
		&"hookshot": return &"attack"
		# A working is cast with the same two shoulders (`docs/GDD.md` §6.5 --
		# "nothing about the input layer changes"), so it takes the same cap.
		# All three of them, which is what that sentence is worth: the ring grew
		# by two stops and the input layer did not grow at all.
		&"burst": return &"attack"
		&"sustain": return &"attack"
		&"ballast": return &"attack"
	return &""
