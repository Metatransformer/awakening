class_name DialogueDb
extends RefCounted
## Who the people in the garrison ARE, and the words they say.
##
## `Voice` (scripts/autoload/voice.gd) owns the recordings and states the rule
## this file is built on: **the file name is the words**. So the transcript table
## below is keyed by TAKE — the thing `Voice.line()` hands back the instant a line
## starts — and not by cue, not by speaker-and-a-counter, and not by anything the
## caller has to remember. The words on the screen are the words in the ear
## because they are looked up by the take that is actually playing.
##
## That is the whole reason `DialogueBox` never picks a line. The order is always:
##
##     Voice.say(who, cue)            # the mouth picks the take (it alternates)
##     DialogueDb.pages(who, cue, Voice.line())
##
## and a speaker with two takes for a cue — the elder's "Hail!" and "How go your
## explorations?" — types whichever one you are hearing, with no second alternator
## to fall out of step with the first.
##
## **A cue with no recording is normal and must stay cheap.** `Voice.say` answers
## 0.0 and plays nothing, `Voice.line()` is then "", and this file falls through to
## `WRITTEN` — which is how the elder can say goodbye today, in text, before
## anybody has been into a booth to record him. Adding the take later is one row in
## `SAID` and deleting one row here; no call site changes.
##
## The NAMES are placeholders (2026-08-10, owner's call: "just give them all
## placeholder names"). The sign over a keeper's head says their TRADE — SMITH,
## ALCHEMIST — and it is `Npc.COUNTERS` that owns those. This file owns the name
## of the person wearing the apron, which is a different fact and shows up in a
## different place: the plate on the dialogue box.

## Everyone who can appear in a dialogue box, keyed the way `Voice.LINES` keys
## them — which is also the id `Npc.COUNTERS` already carries as `voice`. One id
## for the mouth, the words and the face, so a counter names its speaker once.
##
##   * `name`     -- the person. PLACEHOLDER, see the header. The hero's is not:
##     `Kael` came with the portraits, in the owner's own file name.
##   * `portrait`  -- the drawing shown in the box, cut out of its backdrop by
##     `tools/cut_portrait.py`. A person with no portrait simply has no figure on
##     their side of the box (`DialogueBox._portrait`).
##   * `model`    -- their body in the world, an `NpcBody.PEOPLE` or
##     `RaceBody.RACES` key. Nothing renders from this any more -- the box is
##     painted, not posed -- but it is the link that says the person talking to
##     you is the person standing in front of you, and
##     `tools/directors/dialogue.gd` beat A2 asserts it. Absent for the hero,
##     whose rig is not an NPC body at all.
##
## Note `elder` -> the `lanternkeeper` model. They were two people until
## 2026-08-10 and the voice id is the one that survived the merge (`Npc.COUNTERS`
## Role.KEEPER); the art is the Lanternkeeper's. This row is where those two
## names are reconciled, and it is the only place that has to know.
const PORTRAITS := "res://assets/ui/portraits/"

static var PEOPLE := {
	# The listener. He has no lines yet -- every conversation in the game is
	# somebody talking AT him -- but he has a face on the left of every box and a
	# name for the day he answers.
	&"hero": {"name": "Kael", "portrait": PORTRAITS + "kael.png"},
	&"elder": {"name": "Aldric", "model": "lanternkeeper",
		"portrait": PORTRAITS + "elder.png"},
	&"smith": {"name": "Brannoc", "model": "smith",
		"portrait": PORTRAITS + "smith.png"},
	&"quartermaster": {"name": "Kessa", "model": "quartermaster",
		"portrait": PORTRAITS + "quartermaster.png"},
	&"alchemist": {"name": "Ysolt", "model": "alchemist",
		"portrait": PORTRAITS + "alchemist.png"},
	# `jeweler.png`, one L and no "crafter": the drawing is named the way the owner
	# named the file and the id is named the way `Voice.LINES` keys her. Renaming
	# either to match the other would break the thing it was named for.
	&"jewelcrafter": {"name": "Marisel", "model": "jewelcrafter",
		"portrait": PORTRAITS + "jeweler.png"},
	&"builder": {"name": "Tamsin", "model": "builder",
		"portrait": PORTRAITS + "builder.png"},
}

## take -> the words, verbatim.
##
## Transcribed from the recordings by the owner on 2026-08-10, punctuation and
## all. **Do not tidy these into better sentences.** They are a subtitle: an actor
## said this, and a line that reads better than it sounds is a line the player can
## hear is wrong.
##
## A `\n` splits a take into two typed PAGES. Nothing needs it yet -- every take
## is one sentence -- and it costs nothing to allow, so a long line recorded later
## does not need a second mechanism.
static var SAID := {
	&"elder": {
		"ive_been_expecting_you": "Ah, yes! I've been expecting you.",
		"hail": "Hail!",
		"how_go_your_explorations": "How go your explorations?",
	},
	&"smith": {
		"finest_wares_in_the_vale": "I've the finest wares in the Vale.",
		"thats_a_good_deal": "That's a good deal.",
		"take_care": "Take care.",
	},
	&"quartermaster": {
		"ive_just_the_deal_for_you": "I have just the deal for you.",
		"good_price": "Good price.",
		"come_back_with_more_treasures": "Come back soon with more treasures.",
	},
	&"alchemist": {
		"need_any_potions": "Need any potions?",
		"do_try_to_stay_alive_down_there": "Do try to stay alive down there.",
	},
	&"jewelcrafter": {
		"i_have_just_the_right_amulet_for_you": "I have just the right amulet for you.",
		"there_you_go": "There you go.",
		"youre_looking_quite_fashionable":
			"If I may say, you are looking quite fashionable.",
	},
}

## speaker -> cue -> the words, for a cue nobody has recorded.
##
## The fallback, and deliberately a THIN one: this is the text that has no voice
## behind it, so every row here is a small debt. The elder's farewell is the only
## one today ("i dont have audio for this yet", 2026-08-10) -- and it is exactly
## the case `Voice`'s "a speaker with no take for a cue is silent, and that is not
## an error" rule was written for. He says goodbye; you just do not hear it.
static var WRITTEN := {
	&"elder": {
		&"farewell": "You're doing wonderfully.",
	},
	&"builder": {
		&"hello": "The west wall will not mend itself.",
		&"farewell": "Bring me what the works board asks for.",
	},
}


## Their name, or "" for somebody this table has never met.
##
## "" rather than the speaker id, which is what an accidental fallback would
## produce: a box captioned `jewelcrafter` reads as a debug build, and a box with
## no plate at all reads as a voice from off-stage, which is the honest picture of
## a speaker nobody has named.
static func name_of(who: StringName) -> String:
	var row: Dictionary = PEOPLE.get(who, {})
	return String(row.get("name", ""))


## The `NpcBody.PEOPLE` key for their body in the world, or "" for the hero and
## for anybody with no body modelled.
static func model_of(who: StringName) -> String:
	var row: Dictionary = PEOPLE.get(who, {})
	return String(row.get("model", ""))


## The drawing of them, or "" for anybody nobody has drawn.
static func portrait_of(who: StringName) -> String:
	var row: Dictionary = PEOPLE.get(who, {})
	return String(row.get("portrait", ""))


## The pages to type for a line that is playing (or that would have played).
##
## `take` is `Voice.line()` read straight after `Voice.say` — the file, without
## its extension, that the mouth chose. Pass "" when nothing was said, which is
## both the silent-speaker case and the "this cue has no recording" case; they
## take the same path here on purpose, because from the player's side they are the
## same thing.
##
## Empty when there is nothing written either. A caller getting an empty array
## should NOT open a box: an empty box is a UI that appeared to say nothing.
static func pages(who: StringName, cue: StringName, take: String) -> PackedStringArray:
	var said: Dictionary = SAID.get(who, {})
	var words := String(said.get(take, ""))
	if words.is_empty():
		var written: Dictionary = WRITTEN.get(who, {})
		words = String(written.get(cue, ""))
	if words.is_empty():
		return PackedStringArray()
	return _split(words)


## Say a cue and get its words back — the two halves of a line, which always
## happen together and always in this order.
##
## Every caller had this pair written out, and every one of them had to know that
## `Voice.line()` must be read AFTER `say` and BEFORE anything else can interrupt
## it. One place, so the alternating-take contract cannot be got wrong by the
## fourth caller.
static func speak(who: StringName, cue: StringName) -> PackedStringArray:
	Voice.say(who, cue)
	return pages(who, cue, Voice.line())


static func _split(words: String) -> PackedStringArray:
	var out := PackedStringArray()
	for page in words.split("\n", false):
		var trimmed := page.strip_edges()
		if not trimmed.is_empty():
			out.append(trimmed)
	return out
