class_name StoryDb
extends RefCounted
## What the people in the garrison know, and when they are allowed to know it.
##
## `DialogueDb` owns the SUBTITLE — the words under a recording, keyed by the take
## that is playing. It cannot grow a second thing to say, because its key is the
## audio file and there is only ever one of those per cue. So every keeper in the
## build says the same sentence for ever, and the yard is five people with one
## line each standing in it from the first frame of a new save.
##
## This file is the other half: **the same person, saying a different thing
## because you have done something.** Two shapes, and they are deliberately not
## the same shape:
##
##   * **BEATS** — an ordered list per person. The first one whose `needs` are met
##     and which has not been heard yet is what they say when you press TALK. It
##     plays ONCE, then it is behind you for the rest of the save. This is story:
##     the briefing, a keeper arriving, an old man finally telling you about the
##     cadet before you.
##   * **TOPICS** — a repeatable question, offered as a row in the dialogue box's
##     option list once its `needs` are met. This is the tree part: the player
##     asks, gets an answer, and is put back in front of the same list. Nothing is
##     consumed, because a question you can only ask once is a question the player
##     is punished for asking early.
##
## And **UNLOCKS** — who has arrived at all. `Garrison._build_compound_people`
## reads it through `present()`, and simply does not construct the ones who are
## not standing in the yard on this visit.
##
## ## The three metrics, and why there are exactly three
##
##   * `bosses` — how many of `BossDb.BOSSES` are dead on this save. It is the
##     coarse one: four of them exist in the whole Descent, so it is worth roughly
##     a chapter each, and it is what admits the last two traders (alchemist at 1,
##     jewelcrafter at 2).
##   * `item` — a `Game.has()` id. The one metric that is an OBJECT rather than a
##     count, and it exists for the smith: the floor 1 miniboss drops a Vyr
##     maker's mark, and that mark in your pack is what brings Brannoc up the road
##     (card #91). See `SMITH_TOKEN`.
##   * `gold` — `Game.gold_earned`, the LIFETIME total, not the purse. It is the
##     fine one: it moves every single run, it cannot go backwards, and spending
##     does not undo it. That last part is the whole reason it is a separate field
##     from `Game.gold` — gating a line on what is in your pocket would make an
##     old man's story disappear the moment you bought a sharpening.
##
## A fourth was considered and refused: "runs survived". `Game.deaths` exists and
## is deliberately unread by anything that shows the player a number (see its note
## in `game_state.gd`); a keeper who says a different sentence to a player who has
## died a lot is that scoreboard, wearing a face.
##
## ## The words are WRITTEN, not recorded
##
## Nothing in here goes near `Voice`. Every take that exists is already spoken for
## by `DialogueDb.SAID`, and inventing cue names for lines no one has been in a
## booth for would make `tools/directors/dialogue.gd` A0 fail on purpose. A beat
## is text; the greeting under it is still voiced. When somebody records the
## briefing, it becomes a `Voice.LINES` row and a `SAID` row and this table loses
## a `pages` key — no call site changes.

## Speaker -> what has to be true before they are standing in the yard.
##
## Aldric and Kessa are unconditional and that is the opening's shape: you arrive,
## one person tells you what this place is, and one person will buy what you find.
## Everything else is a reward for going down.
##
## **The order is fixed and it is the trade ladder** (owner's call, 2026-08-10):
## quartermaster -> smith -> alchemist -> jewelcrafter. It is also the order the four
## counters get useful in — you cannot forge without components, cannot brew
## without a bottle, cannot set a stone you have not found — so a player who meets
## them in this order never stands in front of a shop that has nothing for them.
##
## **The gates moved down one whole floor on 2026-08-11** (owner's call, card
## #91). They were 1, 2 and 3 BOSSES, which put the smith behind the end of floor
## 1 and the jewelcrafter behind the end of floor 3 — so a player could finish
## three quarters of the game having met one trader. Now the smith comes up on the
## floor 1 MINIBOSS, which is an optional room most of the way down the first
## floor, and each boss after that brings one more.
##
## The smith's gate is also the only one in the table that is an OBJECT. Killing
## something is not a reason for a tradesman to move house; a Vyr maker's mark,
## struck in a metal nobody in Valenfeld can name, is — Aldric sends it up the
## road and the Guild sends the man who can read it. `BossDb.MINIBOSSES` drops it
## off the Sluice-Keeper through the same `Boss._drop_loot` path the Warden's bow
## takes.
static var UNLOCKS := {
	&"elder": {},
	&"quartermaster": {},
	&"smith": {"item": SMITH_TOKEN},
	&"alchemist": {"bosses": 1},
	&"jewelcrafter": {"bosses": 2},
}

## The artifact that brings the smith. Named here rather than spelled twice,
## because `BossDb.MINIBOSSES` has to drop exactly this id and a typo in either
## place is a trader who never arrives and nothing that says why.
const SMITH_TOKEN := &"makers_mark"

## Speaker -> beats, IN ORDER. The first unmet-and-unheard one is what they say.
##
## `needs` is read by `met()`; `{}` means "always". `told` names an earlier beat id
## and is how a beat says *I only make sense after that one* — it is the one gate
## that is about the conversation rather than about the run.
##
## Each string in `pages` is one typed page of the box. They are short on purpose:
## a page is a breath, and `DialogueBox` types at 46 characters a second.
static var BEATS := {
	&"elder": [
		# THE BRIEFING. The only place in the build that says what the game is:
		# who you are, who he is, what this hole is for, and what killed the last
		# person to be told this. It is nine pages, which is long for this box and
		# right for this beat -- it is the one conversation the player is guaranteed
		# to have and it is standing in for a manual nobody is going to write.
		{"id": &"briefing", "needs": {}, "pages": [
			"Aldric Vane. I hold this outpost, and as of this morning I hold you.",
			"Do not let the walls fool you, cadet. We are not garrisoning anything. This is a mining expedition. Highbridge holds the walls; the Explorer's Guild of Valenfeld pays for what comes out from under them.",
			"The Guild pays for what comes up. Highbridge pays for the walls. You are what goes down.",
			"Below us is the Sunken Cut — the works the Vyr left when they went up. There are things living in it that have never seen the sun, and there are doors in it that were built to be argued with rather than opened.",
			"The cadet before you argued badly. We are still looking for his body.",
			"I tell you that myself because you will hear it from Kessa within the hour, and she tells it worse.",
			"Bring me anything that looks made rather than grown. Broken is expected — the Guild is sending a smith up the road who can put such things back the way they were meant to be.",
			"Kessa keeps the stall behind you. Sell her what you do not need; she is fair, which is not the same as generous. And there is a chest at the foot of your bed — your pack is emptied before every descent, so whatever you mean to keep, keep it in the chest.",
			"That is everything. I have high expectations of you. Try to be worth them.",
		]},
		# The first time the loop has actually paid out. Gold and not a boss,
		# because the thing being acknowledged is that you came back UP, and coming
		# back up is the half of the game that has no monster attached to it.
		{"id": &"first_haul", "needs": {"gold": 300, "told": &"briefing"}, "pages": [
			"You have coin on you. Good — that means you came back up, which is the half of this work nobody can be trained for.",
			"Spend it. A cadet with a full purse and a dull blade is a cadet with a well-attended funeral.",
		]},
		# **The three `*_arrived` beats are gone and they are `INTRODUCTIONS` now.**
		# They were the elder describing a person standing twenty metres behind him,
		# which is the one thing a beat cannot do well: the player heard that Brannoc
		# was short and loud and had to go and find out where. An introduction is
		# two people in one box with the camera panning between them, so the sentence
		# and the man arrive together (card #91).
		#
		# The one he does not volunteer early. Gated on gold rather than on a boss
		# because it is about the walk home, and gold IS the walk home.
		{"id": &"the_last_cadet", "needs": {"gold": 1200, "told": &"briefing"}, "pages": [
			"Deryn. That was his name, and you have earned it.",
			"Nineteen. Better with a bow than you are, and worse at going home.",
			"We found his pack on the third landing with everything still in it. That is the part I cannot get past — he had won. He had it all. And he went back down for one more thing.",
			"When the walk back looks long, cadet, it is long. Take the walk.",
		]},
	],
	&"quartermaster": [
		{"id": &"arrival", "needs": {}, "pages": [
			"You'll be the new one. Kessa. I buy.",
			"Anything that came up out of that hole and isn't nailed to you, I'll put a number on it. The number's fair. You'll hate it anyway — they all do.",
			"Advice, free: your pack gets turned out before every descent. Whatever's still in it goes. There's a chest by your bed. That's where a thing lives if you want to keep it.",
		]},
		{"id": &"the_boy_before", "needs": {"gold": 600}, "pages": [
			"You've been down enough times now that I'll say the thing I don't say to the ones who won't last.",
			"The boy before you sold me a cracked lantern-piece the day before he went missing. I gave him nine gold for it. It was worth ninety.",
			"I've not touched the money. It's in the box under this counter. One day somebody will come asking after him, and they'll get it.",
		]},
		{"id": &"flush", "needs": {"gold": 3000}, "pages": [
			"You've made me rich, cadet, and I've made you richer. That's the only kind of friendship that survives a place like this.",
		]},
	],
	&"smith": [
		{"id": &"arrival", "needs": {}, "pages": [
			"So you're the one killing things. Brannoc. The Guild pulled me off a perfectly good bridge contract for this.",
			"Here's my trade, and it's the only one I have. You bring up something the Vyr made — bent, split, half a thing — and I put it back the way it was meant to be.",
			"Everything down there was made by somebody who knew exactly what they were doing. I just have to agree with them.",
			"Aldric will have told you to bring me anything that looks made rather than grown. He's right. He's insufferable about it, but he's right.",
		]},
		{"id": &"older_metal", "needs": {"bosses": 2}, "pages": [
			"The metal changes the deeper you go. What you brought me last is older than this outpost and it hasn't rusted.",
			"That should not be possible, and I would like you to keep doing it.",
		]},
	],
	&"alchemist": [
		{"id": &"arrival", "needs": {}, "pages": [
			"Ysolt. Don't touch the green one.",
			"I am not here for your expedition. I am here because there is a moss on the second floor that grows without light, and if I can persuade it to grow up here I will never have to be polite to a soldier again.",
			"You are useful, however. Bring me a bottle and what you scrape off the walls, and I will send you back down considerably harder to kill. That is a trade, and I would like it understood as a trade.",
		]},
		{"id": &"estimate_revised", "needs": {"bosses": 3}, "pages": [
			"You came back. Three times now, from rooms that were built not to let you.",
			"I have adjusted my estimate of you. Do not make a thing of it.",
		]},
	],
	&"jewelcrafter": [
		{"id": &"arrival", "needs": {}, "pages": [
			"Marisel. I set stones.",
			"I followed the shipments down from Valenfeld — four crates of cut gems out of a camp that officially produces ore, and nobody at the Guild able to tell me who cut them.",
			"Somebody down there was making jewellery a very long time ago, and doing it better than I do. So bring me what you find in the walls. You'll be prettier and considerably harder to kill, and I get to hold the stones for an afternoon.",
		]},
	],
}

## Speaker -> the questions you can put to them, once you may.
##
## Repeatable, and that is the whole difference from a beat. `DialogueBox` keeps
## the option list up after one of these is answered (the `keep` key), so a topic
## list is somewhere the player can stand and read rather than a thing they spend.
##
## `label` is what the row says. Keep them SHORT — a topic row shares a panel with
## Trade and Leave, and the panel is 42% of the words box.
static var TOPICS := {
	&"elder": [
		{"id": &"the_cut", "label": "The Cut", "needs": {"told": &"briefing"}, "pages": [
			"Four floors that anybody has come back from. The Vyr who cut it went further, and they left their doors behind them.",
			"Water on the first, fire on the second, and after that it stops being weather and starts being intent. Something down there still maintains the place.",
		]},
		{"id": &"the_guild", "label": "The Guild", "needs": {"told": &"briefing"}, "pages": [
			"The Explorer's Guild of Valenfeld. Chartered to open what is closed and to write down what is inside it, in that order, which is how they justify most of what they do.",
			"They pay this expedition and they own what comes out of it. Highbridge only holds the walls. I would rather tell you that myself than have you work it out off a manifest.",
		]},
		# "The shelf" and not "The Far Lantern", which is what it is about: the
		# elder's counter is TITLED The Far Lantern and `Npc._options` prints that
		# title in the Trade row's meta column, so the label he was given first put
		# the same four words twice in one five-row panel.
		{"id": &"the_lantern", "label": "The shelf", "needs": {"told": &"briefing"}, "pages": [
			"My counter. Every relic you bring up out of the Cut gets its place on that shelf and a light beside it, and the yard is a little less dark than it was.",
			"It is a record, cadet. When the Guild finally decides this dig killed too many of us, that shelf is the argument I will make.",
		]},
		{"id": &"deryn", "label": "Deryn", "needs": {"told": &"the_last_cadet"}, "pages": [
			"His mother is in Valenfeld and does not know yet. I have written the letter four times.",
			"I will send it when we find him. Not before.",
		]},
	],
	&"quartermaster": [
		{"id": &"prices", "label": "Your prices", "needs": {"told": &"arrival"}, "pages": [
			"My prices are what somebody in Valenfeld will pay me, less the cart, less the road, less the fact that I am the only cart on it.",
			"You're welcome to walk it to Valenfeld yourself. It's a day each way and the road is not friendly after dark.",
		]},
	],
	&"smith": [
		{"id": &"the_forge", "label": "The forge", "needs": {"told": &"arrival"}, "pages": [
			"Bring me the parts and the coin and I'll put an edge on that blade that'll outlast the arm holding it.",
			"I don't make things here. I mend them. There's a difference and down there it matters.",
		]},
	],
	&"alchemist": [
		{"id": &"the_moss", "label": "The moss", "needs": {"told": &"arrival"}, "pages": [
			"It grows in the dark, on stone, with no water it did not make itself. Every book I own says that is three impossibilities in a row.",
			"So either the books are wrong or the Cut is. I know which one I would bet on and I am here to prove it.",
		]},
	],
	&"jewelcrafter": [
		{"id": &"the_stones", "label": "The stones", "needs": {"told": &"arrival"}, "pages": [
			"A stone does nothing on its own. Set it right and it argues with the world on your behalf — a little more of you gets home.",
			"Set it wrong and it is a pretty rock you paid for. I do not set them wrong.",
		]},
	],
}


## Speaker -> the scene in which the elder puts a new person in front of you.
##
## **The one table in this file whose rows have more than one mouth in them.** A
## beat and a topic are one person talking; this is a conversation, and the two
## shapes are kept apart rather than folded together because everything about them
## differs — when they fire (on ARRIVAL in the yard, not on a press), what they
## cost (the camera, for the length of them), and how many times (once per save,
## `intro_flag`).
##
## Each row is an ordered list of `{"who": StringName, "text": String}`. `who` is
## a `DialogueDb.PEOPLE` key, and it is what `DialogueBox` reads to swap the plate
## and the portrait — and what `Introduction` reads to swing the camera onto the
## person now speaking. **Write them so the speaker changes at least once**; a
## scene with one speaker throughout is a beat, and belongs in `BEATS`.
##
## Short on purpose — four pages, five at the outside. The player has just walked
## through the gate with a bag to sell, and every page here is a page they did not
## ask for. What the scene is FOR is that the new trader is a person who spoke to
## you before they were a menu; their own pitch is still waiting at their counter
## (their `arrival` beat), and saying it twice would make the second one furniture.
static var INTRODUCTIONS := {
	# The opening's last beat. It runs straight off the back of the briefing on a
	# new save, so Aldric hands the player to the one counter that is open on the
	# first frame instead of naming her and letting them go and find her.
	&"quartermaster": [
		{"who": &"elder", "text": "Kessa. Leave the ledger a moment and come and look at what the Guild has sent me."},
		{"who": &"quartermaster", "text": "That's a cadet, Aldric. They sent you a cadet."},
		{"who": &"quartermaster", "text": "Anything you drag up out of that hole, I'll put a number on it. The number's fair. You'll hate it anyway."},
		{"who": &"elder", "text": "Kessa is the reason a sack of Vyr scrap is worth carrying up four flights. Sell to her before you spend anything on yourself."},
	],
	# The payoff for the floor 1 miniboss. The mark itself is the hinge: the player
	# picked an object up off a body, and here is what the object DID.
	&"smith": [
		{"who": &"elder", "text": "That mark you brought up went to Valenfeld on the evening cart. Brannoc came back on the morning one."},
		{"who": &"smith", "text": "They pulled me off a perfectly good bridge contract for this, and I'd have walked here barefoot."},
		{"who": &"smith", "text": "Somebody struck that mark in a metal I have never held. I've been awake since three about it. Bring me anything you find bent and I'll put it back the way it was meant to be."},
		{"who": &"elder", "text": "The forge is yours, cadet. He is short, loud and entirely worth it."},
	],
	&"alchemist": [
		{"who": &"elder", "text": "Ysolt has taken the west shelf. Guild, like the rest of us, and not here for you — he is here for what grows down there."},
		{"who": &"alchemist", "text": "Don't touch the green one."},
		{"who": &"alchemist", "text": "Bring me a bottle and whatever you scrape off the second floor, and I will send you back down considerably harder to kill. I would like that understood as a trade."},
		{"who": &"elder", "text": "He brews the only thing that will keep you standing on the fourth floor. Be civil."},
	],
	&"jewelcrafter": [
		{"who": &"elder", "text": "And this is Marisel, who followed the stones up the way her sort always does."},
		{"who": &"jewelcrafter", "text": "Four crates of cut gems out of a camp that officially produces ore. Somebody was setting stones down there a very long time ago, and doing it better than I do."},
		{"who": &"jewelcrafter", "text": "So bring me what you find in the walls. You'll be prettier, and considerably harder to kill."},
		{"who": &"elder", "text": "Four traders and one soldier. That is the wrong proportion for a garrison and exactly the right one for a dig. I have stopped pretending otherwise."},
	],
}

## The order they are offered in, which is `UNLOCKS`' trade ladder. Spelled out
## rather than read off `INTRODUCTIONS.keys()`: a Dictionary's key order is its
## insertion order and would work today, and the day somebody re-sorts that
## literal alphabetically the jewelcrafter would introduce herself first.
const INTRO_ORDER: Array[StringName] = [
	&"quartermaster", &"smith", &"alchemist", &"jewelcrafter",
]


## The flag stamped once an introduction has been played to the end.
static func intro_flag(who: StringName) -> StringName:
	return StringName("met_%s" % who)


## Whoever the elder still owes the player an introduction to, or `&""`.
##
## Only somebody who has actually ARRIVED (`unlocked`) and whose scene has never
## run, and the FIRST such in ladder order — `Garrison._do_the_rounds` calls this
## again after each one, so a walk-in that owes two plays both, back to back.
##
## Two at once is a real case and not a corner: the floor 1 miniboss and the floor
## 1 boss are the same run, so a good first descent brings the smith and the
## alchemist home together. Eight pages is a lot to hand somebody who just wanted
## to sell a bag — and the alternative is a stranger standing at a new counter
## with nobody having said who he is, which is the exact thing this system was
## built to stop.
static func pending_introduction() -> StringName:
	for who in INTRO_ORDER:
		if Game.flag(intro_flag(who)):
			continue
		if not INTRODUCTIONS.has(who):
			continue
		if unlocked(who):
			return who
	return &""


## The scene, as `Introduction` wants it. Empty for anybody with none.
static func introduction(who: StringName) -> Array:
	return INTRODUCTIONS.get(who, []) as Array


static func mark_introduced(who: StringName) -> void:
	Game.set_flag(intro_flag(who))


# --- Who is in the yard --------------------------------------------------------

## The flag stamped the moment somebody's gate is first met.
static func arrival_flag(who: StringName) -> StringName:
	return StringName("garrison_%s_arrived" % who)


## The flag stamped when a beat has been read to the end.
static func told_flag(who: StringName, beat: StringName) -> StringName:
	return StringName("told_%s_%s" % [who, beat])


## Is this person standing in the garrison?
##
## **It latches.** The flag is set the first frame the metric is met and every
## answer after that comes off the flag, for two reasons. A person who ARRIVED
## must never un-arrive — the metrics here cannot go backwards today, but a
## keeper whose presence is recomputed from live state is one balance change away
## from vanishing between two runs, and a shop that disappears reads as a bug in
## every game that has ever shipped one. And it gives the harness a door:
## `tools/shoot.gd` sets these flags directly so a director does not have to kill
## three bosses to photograph the jewelcrafter.
##
## Yes, a predicate with a write in it. The write is one-way, idempotent, and the
## alternative is a second call every caller has to remember to make.
static func unlocked(who: StringName) -> bool:
	var flag := arrival_flag(who)
	if Game.flag(flag):
		return true
	if not met(UNLOCKS.get(who, {})):
		return false
	Game.set_flag(flag)
	return true


## Is this person standing in the yard on THIS visit?
##
## **Arriving and being there are two different facts, and card #115 is the bill
## for having conflated them.** `unlocked` latches the moment the metric is met,
## and `Garrison` built anybody it answered yes for -- on `_ready`, before a word
## had been said. A run that took the floor 1 miniboss and the floor 1 boss
## therefore came home to TWO new bodies in the yard, and the elder could only
## introduce one of them: the alchemist was a stranger at a new counter, which is
## the exact failure `Introduction` exists to prevent (owner, 2026-08-12).
##
## So presence is gated on the CONVERSATION and not on the unlock:
##
##   * somebody the elder has already introduced (`met_<who>`) is simply here,
##     forever, as they always were;
##   * plus `arriving` -- the ONE keeper whose scene is about to play this visit,
##     who has to be standing in the yard for `ConvoCamera` to turn to them;
##   * and nobody else. A second unlocked-but-unmet keeper is not built at all.
##     They walk up the road next time you come home.
##
## That last clause IS the throttle: a good descent pays out one arrival now and
## holds one in reserve, rather than handing a player who wanted to sell a bag
## eight pages of introductions. `arriving` is `pending_introduction()` read ONCE
## by the caller, before it builds anything, so the body and the scene can never
## disagree about who this visit is for.
##
## The arrival flag is untouched by any of this. It is the earned fact and it
## stays latched -- `roster.gd` D is the proof, and it is still true.
static func present(who: StringName, arriving: StringName) -> bool:
	if not unlocked(who):
		return false
	return Game.flag(intro_flag(who)) or who == arriving


# --- What they say -------------------------------------------------------------

## The beat they owe you, or `{}` when they have nothing new.
##
## Read-only: hearing it is what `mark_told` records, and that happens when the
## last page has actually been turned rather than when the box opens. A player who
## hits Escape half way through Aldric's briefing has not been briefed.
static func pending(who: StringName) -> Dictionary:
	var beats: Array = BEATS.get(who, [])
	for beat: Dictionary in beats:
		var id := StringName(beat.get("id", &""))
		if Game.flag(told_flag(who, id)):
			continue
		if met(beat.get("needs", {}), who):
			return beat
	return {}


## The questions they will answer today.
static func topics(who: StringName) -> Array:
	var out: Array = []
	for topic: Dictionary in (TOPICS.get(who, []) as Array):
		if met(topic.get("needs", {}), who):
			out.append(topic)
	return out


## Their words, ready for `DialogueBox`.
static func pages_of(entry: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for page: String in (entry.get("pages", []) as Array):
		var trimmed := page.strip_edges()
		if not trimmed.is_empty():
			out.append(trimmed)
	return out


static func mark_told(who: StringName, beat: StringName) -> void:
	Game.set_flag(told_flag(who, beat))


# --- The gate ------------------------------------------------------------------

## Are `needs` satisfied? `{}` always is.
##
##   bosses : int         how many of `BossDb.BOSSES` are dead on this save
##   item   : StringName  an id `Game.has()` must answer true for
##   gold   : int         `Game.gold_earned` — LIFETIME, not the purse
##   told   : StringName  a beat id of `who` that must already have been heard
##
## `who` is only needed for `told` and defaults to nothing, so `UNLOCKS` — which
## never uses it — reads without a second argument.
static func met(needs: Dictionary, who: StringName = &"") -> bool:
	if needs.is_empty():
		return true
	if int(needs.get("bosses", 0)) > bosses_felled():
		return false
	# `Game.has` and NOT the bag: this is ownership, the one-way flag a boss drop
	# sets (`Game.grant`), so a maker's mark cannot be sold to Kessa by mistake and
	# it cannot die with the bag on the walk home. A gate that a bad run can undo
	# is a trader who leaves town.
	var item := StringName(needs.get("item", &""))
	if item != &"" and not Game.has(item):
		return false
	if int(needs.get("gold", 0)) > Game.gold_earned:
		return false
	var after := StringName(needs.get("told", &""))
	if after != &"" and not Game.flag(told_flag(who, after)):
		return false
	return true


## How many of the Descent's bosses are dead on this save.
##
## Counted over `BossDb.BOSSES` rather than over every `boss_dead_*` flag in
## `Game.flags`, because the MINIBOSSES set flags of exactly the same shape
## (`BossArena._already_dead`) and there are several of them per floor. A garrison
## that filled up on miniboss kills would hand the player the whole trade ladder
## before the first real door.
static func bosses_felled() -> int:
	var n := 0
	for id: StringName in BossDb.BOSSES:
		if Game.flag(StringName("boss_dead_%s" % id)):
			n += 1
	return n
