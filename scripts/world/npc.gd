class_name Npc
extends Interactable
## The five people in the garrison, and the gate they stand around.
##
## They were boxes with a lantern, on purpose, for as long as the loop was the
## thing being built: a stand-in character model that is nearly good is worse
## than an obvious placeholder, because it invites you to fix the model instead
## of the game. The loop works, so they are people now -- standing behind a
## `ShopBooth` full of their own trade, and built two different ways:
##
##   * **All five are authored bodies** (`NpcBody`) -- a dwarf smith, a warrior at
##     the pawnbroker's stall, the hooded Lanternkeeper who is also the village
##     elder, the jewelcrafter and the spectacled alchemist, each modelled as a
##     whole dressed figure. They do not go near the suit system.
##   * **None are built** (`RaceBody`) any more -- the elder was the last, and he
##     is now the Lanternkeeper. `_build_person` keeps that branch on purpose: it
##     is the machine that can put somebody new in the yard without commissioning
##     a model, and it is what the whole monster roster still runs on.
##
## **What they DO did not change, either time, and that is the point.** Turn to
## face you, light up when addressed, open the right screen: all of it still lives
## here, none of it ever depended on the mesh, and both mesh swaps touched
## `_build_person` and nothing else.

## KEEPER and JEWELLER are appended rather than slotted in beside the other
## counters: the values are what an `@export var role` serialises, and
## re-ordering this enum would silently turn every placed alchemist into a gate.
##
## ELDER was appended after those and has now been REMOVED, which is safe for the
## same reason and only because it was last: it took the highest value, so every
## other role kept its number. Nothing in `scenes/` exports a role -- `Garrison`
## builds all six by hand -- but the rule stands for the next person.
enum Role { VENDOR, SMITH, GATE, ALCHEMIST, KEEPER, JEWELLER }

## Everything that differs between the people in this garrison, on one row each.
##
## It started as a name table beside a `match` in `_ready` and a second `match`
## in `activate`, which is three places to edit to add a fourth shopkeeper and
## two of them easy to miss. **A new counter is a row here plus a `Catalogue`
## subclass -- never a new screen and never a new branch.** The trade screen, the
## recipe column, the affordability colouring and the hold-to-craft gauge are
## written once and pointed; that is the entire reason `TradeScreen` takes its
## catalogue as an argument.
##
##   * `sign`   -- the name over their head. "" for the gate, which is masonry.
##   * `prompt` -- the verb. TALK, not SELL/FORGE: the verb on a person should be
##     the thing you do to a person, and the sign already says which one this is.
##   * `hold`   -- seconds on the button, 0 to fire on press. See `Prompt`.
##   * `counter`-- present only for those who stand behind one. `db` null means
##     SELL (the screen reads the bag, not a catalogue).
##   * `voice`  -- their key in `Voice.LINES`, or absent for the ones nobody has
##     recorded. `activate` says their `hello` and the screen says the other two;
##     a speaker with no take for a cue is silent and that is not an error, so
##     the Lanternkeeper simply has no row here and no branch anywhere.
##
## The GATE has no counter, so `activate` has exactly one branch: open a counter,
## or do the role's own thing.
##
## `static var`, not `const`: a catalogue is a script reference and an enum from
## another class, and neither is a constant expression to the parser. Static, so
## the table is still built once for the whole game rather than per shopkeeper.
static var COUNTERS := {
	Role.VENDOR: {
		"sign": "PAWNBROKER", "prompt": "TALK", "hold": 0.0, "voice": &"pawnbroker",
		"counter": {"title": "PAWNBROKER", "mode": TradeScreen.Mode.SELL, "db": null},
	},
	Role.SMITH: {
		"sign": "SMITH", "prompt": "TALK", "hold": 0.0, "voice": &"smith",
		"counter": {"title": "THE FORGE", "mode": TradeScreen.Mode.BUY, "db": ShopDb},
	},
	Role.ALCHEMIST: {
		"sign": "ALCHEMIST", "prompt": "TALK", "hold": 0.0, "voice": &"alchemist",
		"counter": {"title": "THE ALCHEMIST", "mode": TradeScreen.Mode.BUY, "db": AlchemyDb},
	},
	# The fourth counter. She cost exactly this row and a `Catalogue` subclass --
	# no screen, no branch in `activate`, no new mode -- which is the acceptance
	# criterion for the whole relic system and not a nice outcome.
	#
	# She was "the last one there will be" until 2026-08-09, when GDD §6.6 added
	# the jewelcrafter below and docs/SCOPE.md §1 moved garrison NPCs from 4 to
	# 5 as an owner's amendment. The claim was not wrong about the COST -- the
	# fifth counter cost the same row and the same subclass -- which is exactly
	# why the ceiling now lives in SCOPE §1 rather than in a comment here.
	#
	# `hold` is 0 like the other three: the HOLD that matters here is on the
	# LINE, not on the greeting. `RelicDb.crafts()` answers true for every row,
	# so `TradeScreen` puts its gauge on the donation itself and the footer reads
	# HOLD ENT TO RECORD.
	#
	# **He is also the village elder** (2026-08-10, owner's call). Those were two
	# people for a day: an elder standing in the open grass with three recorded
	# lines and no counter, and a silent Lanternkeeper behind the relic hall. They
	# were always the same character description -- the old man who is expecting
	# you, who keeps the Society's records, who is the reason the garrison has
	# somebody to report to -- so they are one person now, and the yard is five
	# people instead of six. That collapse is why this row has BOTH a `voice` and
	# a `counter`, which no row had before: `activate` says the greeting and then
	# opens the screen, in that order, and neither half knew about the other.
	#
	# What it cost: the elder used to be the proof that a row with a voice and NO
	# counter works. Nothing tests that now, and no row needs it -- see the note
	# in `activate`, which still handles it and says so.
	Role.KEEPER: {
		"sign": "LANTERNKEEPER", "prompt": "TALK", "hold": 0.0, "voice": &"elder",
		"counter": {
			"title": "THE FAR LANTERN", "mode": TradeScreen.Mode.BUY, "db": RelicDb,
		},
	},
	# The fifth counter, and the last one there will be (docs/SCOPE.md §1:
	# garrison NPCs **5**, "There is no sixth"). Same bill as the
	# Lanternkeeper's, paid again: one row, one `Catalogue`.
	#
	# `hold` is 0 like the other four. `JewelDb.crafts()` answers true for every
	# rung and false for the four blanks, so the gauge lands on the commits that
	# eat stones and the blanks stay a tap -- which is the rule `Catalogue.crafts`
	# exists to state once.
	Role.JEWELLER: {
		"sign": "JEWELCRAFTER", "prompt": "TALK", "hold": 0.0, "voice": &"jewelcrafter",
		"counter": {
			"title": "THE SETTING BENCH", "mode": TradeScreen.Mode.BUY, "db": JewelDb,
		},
	},
	# 0.9 s, and the only hold in the world. It is the door OUT of the hub and
	# the one press in the game that ends the safe part of the session, so it is
	# the one press that should be impossible to make by accident on the way past.
	#
	# `# NEEDS:` the Warp-Stone Fragment's unlock,
	# `RelicDb.garrison_shortcuts()`, bites HERE -- "start a run at any shortcut
	# you have opened" (GDD §6.2 #9). It cannot be adopted yet and faking it
	# would be worse than leaving it: the gate would have to open a run at floor
	# N, and `Run.enter()` hard-sets `level = 1` with a comment explaining why,
	# so the change is one argument in `scripts/autoload/run_state.gd`. There is
	# also nothing to offer until the shortcut doors exist on a real floor
	# (SCOPE M4/M6). When both land, this row reads
	# `RelicDb.garrison_shortcuts()` and `activate` picks the deepest floor
	# whose `LockedDoor.flag_id()` is set -- still no new screen.
	Role.GATE: {"sign": "", "prompt": "DESCEND", "hold": 0.9},
}

## Who each shopkeeper IS -- their body, their clothes, and how they stand.
##
## Separate from `COUNTERS` because the two tables answer different questions and
## get edited for different reasons: `COUNTERS` is what a counter DOES, this is
## what a person looks like. A palette pass should not have to read past the
## trade modes to find the colours.
##
## **There are two kinds of row here, and a row is one or the other.**
##
##  * **`model`** -- an AUTHORED person (`NpcBody.PEOPLE`). They were modelled as a
##    whole figure, dressed, with their buckles and their beard painted into one
##    atlas: the smith's apron, the Lanternkeeper's jewelled mail, the
##    jewelcrafter's gown. There is no bare body under them and no normalised UV
##    layout, so **`suit` and `tint` are meaningless on these rows and must not be
##    added.** Putting the clothing system anywhere near them seats a garment onto
##    a rig it was never fitted to and produces a person wearing another person.
##  * **`race`** -- a base from the Valenfeld pack, dressed by the suit system
##    (`RaceBody.wear`). **No row uses it today**, and it is not dead: it is what
##    you reach for when a person has to be BUILT out of a race, a suit and a
##    colour, which is how the Vale's three peoples are cast and how every monster
##    in the dungeon is made. It is also the only one of the two that can put
##    somebody new in the yard without commissioning a model, so the next person
##    to arrive here probably arrives on it.
##
## The casting is not at random on either side. Each body keeps the counter it
## would keep, which is why the garrison reads as a place with history in it
## rather than five vendors in different hats: a dwarf at the forge, a scarred
## road-warrior fencing goods at the stall, a woman wearing her own trade at the
## setting bench, a hooded man at the apothecary who wears his stock -- spectacles
## and a belt of stoppered flasks -- and, at the Far Lantern, the white-bearded
## elder in relic-jewelled mail who is both the person you report to and the man
## who keeps the records.
##
## Heights are load-bearing and come off `NpcBody.PEOPLE`. The hero is 1.65 m,
## and the row steps -- smith 1.44, jewelcrafter 1.63, pawnbroker 1.72, keeper
## 1.74, alchemist 1.82 -- so the smith reads a clear head short of you and the
## alchemist a clear head tall, before either says a word.
##
##   * `model`  -- an authored body, dressed as it ships. Excludes `race`.
##   * `race`   -- a base to build and dress. Excludes `model`.
##   * `suit`   -- `race` rows only: which authored suit to dress them in
##     (`SuitSeater.SETS`). Not a fabric name: a suit is a whole dressed person,
##     so this picks the entire outfit including boots, gloves and hood.
##   * `tint`   -- `race` rows only, and it MULTIPLIES the weave, so it runs much
##     lighter than a flat robe colour would. The first pass fed in the box
##     placeholders' robe colours directly and produced silhouettes in black.
##   * `idle`   -- their resting loop, so the garrison is not six people breathing
##     in time. All from the standing family; see `RaceBody.CLIPS`, which is the
##     same four clips either kind of body plays.
##   * `booth`  -- the shop they stand in. **Absent means none.** Every row here
##     has one now; the elder was the one that left it out, and he is the
##     Lanternkeeper.
static var LOOKS := {
	# The dwarf: leather apron, one pauldron, a hammer on the belt and a bare
	# forearm, at 1.44 m and half again as wide as anyone else in the yard. He is
	# roughly the height of the Stoneborn he replaced, deliberately -- the forge
	# wants the SHORT silhouette, and the fire two metres behind him is what the
	# tinting of the old placeholder was fighting to survive.
	Role.SMITH: {
		"model": "smith", "idle": &"idle3", "booth": ShopBooth.Kind.FORGE,
	},
	Role.VENDOR: {
		"model": "pawnbroker", "idle": &"idle", "booth": ShopBooth.Kind.STALL,
	},
	# Hooded and spectacled, with a belt of stoppered flasks and a vial at his hip:
	# the apothecary's stock worn on the body, the same trick the jewelcrafter's
	# emerald plays. At 1.82 m he is the tallest person in the yard, which is the
	# height the Vyr row he replaced was carrying and the reason it survives the
	# swap -- he looks DOWN at you over the alembics whether or not he is Vyr any
	# more (he is not; docs/GDD.md §1).
	#
	# `idle3` and NOT `idle4`, which is the clip this row had while he was built
	# from a suit. Four clips, six people, so somebody repeats and the rule is
	# *repeat the one nobody who looks like you is using* -- and `idle4` is already
	# the jewelcrafter's. `idle3` belongs to the smith: a 1.44 m dwarf behind a
	# forge at the far north-east, who cannot be mistaken at any distance for a
	# tall hooded man on the west side.
	Role.ALCHEMIST: {
		"model": "alchemist", "idle": &"idle3", "booth": ShopBooth.Kind.ALCHEMY,
	},
	# Hooded, white-bearded, and wearing a mail coat set with a dozen coloured
	# stones -- the whole of the Far Lantern's pitch worn on a body. He is the
	# second tallest person in the yard and the oldest, so the strange counter
	# reads as the strange one before the sign is legible.
	#
	# **This is the village elder.** He was two people for a day and the art is
	# what collapsed them: the body that arrived for this counter is a bearded old
	# man in robes, which is the elder's description written down, and a garrison
	# of five does not have room for two of him twelve metres apart. So the elder's
	# grass, his lamp and his `Role` are gone, and his three recorded lines came
	# here (`COUNTERS`). He is still the person you report to; he now also keeps
	# the records, which was always what the Society's man did.
	#
	# **NO BOOTH, and he is the only person in the yard without one.** He had a
	# stall for a day and it was the wrong furniture for what he is: the other
	# four sell you something across a counter, and a counter is exactly the right
	# object for that. He is the man who greets you and takes the record, and a
	# stall between him and the hero turned the one person who speaks first in the
	# game into a fifth shopkeeper you happened to be parked in front of.
	#
	# The twelve lamps outside are what says this counter is different, and they
	# say it better with nothing in front of him. `Garrison._build_people` is the
	# other half: with no counter to step back behind, he is placed where he
	# STANDS -- on the centre line, facing the arrival.
	Role.KEEPER: {
		"model": "lanternkeeper", "idle": &"idle9",
	},
	# Black and gold, an emerald the size of a thumb at her throat, gold at both
	# wrists. She is the one person in the garrison wearing her own stock, which
	# says what the setting bench sells without a word of it -- and it is why she
	# needs no tint: the violet the old Stoneborn row used was standing in for
	# exactly this and cost a `cut_gemstone` cross-reference to explain.
	#
	# `idle4` is hers alone now. There are four clips and five people, so exactly
	# one pair repeats, and the rule this row set is *repeat the one nobody who
	# LOOKS like you is using* -- the smith and the alchemist are the pair, a
	# 1.44 m dwarf at the forge and a 1.82 m hooded man at the far side of the
	# yard. (This clip was shared with the elder until he and the Lanternkeeper
	# became one person.)
	Role.JEWELLER: {
		"model": "jewelcrafter", "idle": &"idle4", "booth": ShopBooth.Kind.STALL,
	},
}

@export var role: Role = Role.VENDOR
@export var lamp_color: Color = Pal.GOLD

var _body: Node3D
## Whoever is standing here -- a `RaceBody` or an `NpcBody`, see `LOOKS`. Held as
## a `Node3D` because nothing outside `_build_person` asks it anything.
var _person: Node3D
var _lamp: OmniLight3D
var _lamp_mat: StandardMaterial3D
var _sign: Label3D
var _lit: float = 0.0
var _age: float = 0.0
## Crown height of whoever is standing here, so the name floats over the head it
## belongs to. The three races differ by 40 cm; a fixed 2.25 put the Stoneborn's
## sign most of a metre above him.
var _head: float = 1.75


## The row for this NPC. Never null -- a role added to the enum and forgotten
## here gets a nameless prop you can walk up to, not a crash mid-garrison.
func _row() -> Dictionary:
	var row: Dictionary = COUNTERS.get(role, {})
	return row


func _ready() -> void:
	var row := _row()
	prompt = str(row.get("prompt", "EXAMINE"))
	hold_time = float(row.get("hold", 0.0))
	radius = 2.3
	super()
	_build()


## **You TALK to them. The counter is something the conversation offers you.**
##
## Until 2026-08-10 this function said hello and opened the shop on the same
## press, which is the shape a shop keeper has when the shop is the only thing
## about them. It is not the shape a PERSON has: the greeting was a sound with
## nothing on screen, the counter's own name was the only thing that said who you
## were standing in front of, and there was no moment in the game where somebody
## addressed you and waited.
##
## So the press opens a `DialogueBox` -- their face, their name, their line typed
## out -- and Trade is one of the options at the end of it. The counter itself did
## not change and neither did anything below `TradeScreen.open`: what used to be
## the whole of this function is now `_choose_trade`, reached by a choice instead
## of by the press.
##
## The gate is masonry and answers first. It has no voice, no name and nothing to
## say; a hole in the ground does not greet you.
func activate(_by: Node3D) -> void:
	if role == Role.GATE:
		Flow.enter_dungeon()
		return

	var row := _row()
	var who := StringName(row.get("voice", &""))

	# **The story first, and only then the greeting.** `StoryDb` holds an ordered
	# list per person -- the briefing, a trader's arrival, the thing an old man
	# will only tell you once you have earned it -- and `pending` hands back the
	# first one that is due. It is WRITTEN, so nothing is played: these are lines
	# nobody has been in a booth for, and `Voice`'s "a speaker with no take is
	# silent" rule is what lets that be normal rather than a gap.
	#
	# `on_read` and not a `mark_told` here: the flag belongs on the last page
	# actually being turned. Escaping out of Aldric's nine-page briefing has to
	# leave it owed, or the one conversation that explains the game is one stray
	# press from being gone for the save.
	var beat := StoryDb.pending(who)
	var pages: PackedStringArray
	var on_read := Callable()
	if beat.is_empty():
		# The mouth picks the take and `DialogueDb` reads the words off the take
		# that is playing, so the elder's two greetings alternate in the ear and on
		# the screen together. See `DialogueDb.speak`.
		pages = DialogueDb.speak(who, &"hello")
	else:
		pages = StoryDb.pages_of(beat)
		var beat_id := StringName(beat.get("id", &""))
		on_read = func() -> void: StoryDb.mark_told(who, beat_id)

	if pages.is_empty():
		# Nobody has written them a line. Straight to the counter, exactly as this
		# function behaved before there was a dialogue box -- a keeper with no words
		# is still a keeper, and a box that opened to say nothing would be worse
		# than no box.
		_choose_trade(who, row)
		return
	DialogueBox.open(self, who, pages, _options(who, row), on_read)


## What the conversation offers when the line is finished.
##
## Three kinds of row and they are in the order a player wants them:
##
##   1. **Trade**, for somebody with a counter -- the thing you walked over here
##      for. Absent for anybody without one (there is nobody today; the elder was
##      the last, `COUNTERS`), which still leaves a box you can say goodbye to
##      rather than only walk away from.
##   2. **Topics** (`StoryDb.topics`) -- the questions this person will answer
##      today. They are `keep` rows, so asking one puts the list straight back up;
##      see `DialogueBox.open`. What is in the list grows as the save does, which
##      is the whole tree: the same man has more to say about Deryn after he has
##      told you Deryn's name.
##   3. **Leave**, always last.
##
## They are all one typeface -- `DialogueBox._ask` turns the kit's primary
## promotion off, and says why.
func _options(who: StringName, row: Dictionary) -> Array:
	var out: Array = []
	var counter: Dictionary = row.get("counter", {})
	if not counter.is_empty():
		out.append({
			"label": "Trade",
			# The counter's own name in the meta column, so picking Trade at the
			# Lanternkeeper is visibly not the same act as picking it at the smith.
			"meta": _titled(str(counter.get("title", ""))),
			"act": _choose_trade.bind(who, row),
		})
	for topic: Dictionary in StoryDb.topics(who):
		out.append({
			"label": String(topic.get("label", "")),
			"keep": true,
			"act": func() -> PackedStringArray: return StoryDb.pages_of(topic),
		})
	out.append({"label": "Leave", "act": _choose_leave.bind(who)})
	return out


## One screen, pointed. See `Catalogue` for why there is not a second one.
##
## Returns nothing to say, which `DialogueBox` reads as "the conversation is
## over": the shop is the rest of this interaction, and it says the farewell
## itself when it comes down (`TradeScreen.close`).
func _choose_trade(who: StringName, row: Dictionary) -> PackedStringArray:
	var counter: Dictionary = row.get("counter", {})
	if counter.is_empty():
		return PackedStringArray()
	TradeScreen.open(self, int(counter["mode"]), str(counter["title"]),
		counter["db"] as GDScript, who)
	return PackedStringArray()


## Goodbye, said out loud and written down, and then the box closes on the next
## press. The same `farewell` cue the trade screen says on its way out -- one cue,
## two doors out of the same conversation.
func _choose_leave(who: StringName) -> PackedStringArray:
	return DialogueDb.speak(who, &"farewell")


## "THE FORGE" -> "The Forge". `COUNTERS` writes these in caps, which is right
## over a shop front and shouting in a meta column. Godot's own `capitalize()`
## cannot do it -- it inserts a space before every interior capital, so "THE
## FORGE" comes back as "T H E   F O R G E". Same four lines as
## `TradeScreen._counter_name`, and for the same reason.
func _titled(caps: String) -> String:
	var words: Array[String] = []
	for word in caps.strip_edges().to_lower().split(" ", false):
		words.append(word.substr(0, 1).to_upper() + word.substr(1))
	return " ".join(words)


func on_focus(on: bool) -> void:
	if role == Role.GATE:
		return
	_sign.visible = on


func on_hold(t01: float) -> void:
	# The gate's descent bar is the gate itself filling with light.
	_lamp.light_energy = 1.4 + t01 * 7.0
	_lamp_mat.emission_energy_multiplier = 0.55 + t01 * 5.0


func _process(delta: float) -> void:
	_age += delta
	var want := 1.0 if Prompt.focus == self else 0.0
	_lit = move_toward(_lit, want, delta * 5.0)

	if role != Role.GATE:
		_lamp.light_energy = 1.1 + _lit * 1.8 + sin(_age * 3.1) * 0.12
		_lamp_mat.emission_energy_multiplier = 1.8 + _lit * 2.2
		# Turns to face you. It is two lines and it is the difference between a
		# shopkeeper and a crate with a menu attached.
		var hero := get_tree().get_first_node_in_group(&"player") as Node3D
		if hero != null:
			var to := K.flat(hero.global_position - global_position)
			if to != Vector3.ZERO:
				# GLOBAL, because the Npc node itself is now turned to aim its booth
				# at the yard. `atan2(to.x, to.z)` is a world yaw, and writing a world
				# yaw into a local rotation left every keeper facing off by however
				# far their stall was rotated.
				var want_yaw := atan2(to.x, to.z)
				_body.global_rotation.y = lerp_angle(_body.global_rotation.y, want_yaw, delta * 6.0)
	elif Prompt.focus != self:
		_lamp.light_energy = 3.2 + sin(_age * 1.7) * 0.5
		_lamp_mat.emission_energy_multiplier = 0.55


# --- Construction -----------------------------------------------------------

func _build() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	if role == Role.GATE:
		_build_gate()
	else:
		_build_person()

	_sign = Label3D.new()
	_sign.text = str(_row().get("sign", ""))
	_sign.font_size = 48
	_sign.pixel_size = 0.0022
	_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# **Depth-tested, and it shipped the other way.** `no_depth_test = true` is
	# not "draw over the keeper" — it is draw over the world, so a shopkeeper's
	# name plate was readable through the garrison's six-metre curtain wall from
	# out on the plain. That is card #26's Echo bug with a different label on it;
	# `scripts/world/sounding_stone.gd` carries the long note, and this is #37.
	#
	# Nothing has to move for it. The sign hangs half a metre above `_head`, so
	# it clears the keeper's own crown, and the booth it clears by two metres —
	# the same way `PLATE_DROP` already stood the Echo captions off their drum.
	# `tools/directors/world_labels.gd` measures both halves.
	_sign.no_depth_test = false
	_sign.modulate = Pal.BONE
	_sign.outline_size = 16
	_sign.position.y = _head + 0.5
	_sign.visible = false
	add_child(_sign)


## A person, their shop, and the lamp they work by.
##
## Note what hangs off what. `_body` turns to follow you and holds ONLY the
## person; the booth and the lamp are children of the Npc itself and never move.
## That split is the entire trick -- a keeper who tracks you across their own
## stationary counter reads as somebody at work, and the earlier version, where
## everything hung off the turning node, would have swung the forge round the
## yard every time you walked past it.
func _build_person() -> void:
	var look: Dictionary = LOOKS.get(role, {})

	# The shop. Set forward of the keeper along the Npc's own +Z, which is the
	# side `ShopBooth` authors its counter to face -- so aiming an Npc at the
	# yard aims their booth at it too, and nothing has to be placed twice.
	#
	# Absent only for the gate now. `Garrison._stand` was the other half of this
	# -- a keeper is placed by where their COUNTER goes and steps back behind it,
	# so somebody with no counter had to be placed where they stood -- and it went
	# when the elder did.
	if look.has("booth"):
		var booth := ShopBooth.new()
		booth.kind = look["booth"]
		booth.position.z = ShopBooth.KEEPER_BACK
		add_child(booth)

	# The person. Two kinds, and the row says which -- see `LOOKS`. An authored
	# body arrives dressed and is left alone; a race base is built, then dressed by
	# the suit system. Both answer `height` and `play`, so nothing below this cares
	# which one turned up.
	var idle: StringName = look.get("idle", &"idle")
	if look.has("model"):
		var authored := NpcBody.make(str(look["model"]))
		if authored != null:
			_person = authored
			_body.add_child(authored)
			authored.play(idle)
			_head = authored.height
	else:
		var built := RaceBody.make(str(look.get("race", "reshi")))
		if built != null:
			_person = built
			_body.add_child(built)
			built.wear(str(look.get("suit", "cloth")), look.get("tint", Color.WHITE))
			built.play(idle)
			_head = built.height

	# The lamp on its post, at the end of the counter. It used to be a cube in
	# the keeper's fist, which was the right call for a keeper made of cubes; a
	# glowing box clenched by an actual hand would be a worse lie than the boxes
	# were. On a post it is a lamp, and it is still the only light on their face
	# -- which is what makes the focus brightening read on the PERSON and not
	# just as a puddle on the flagstones.
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = lamp_color
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = lamp_color
	_lamp_mat.emission_energy_multiplier = 1.8
	_lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.15, 0.17)
	iron.roughness = 0.85
	iron.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	# CLEAR of the counter's right-hand end, and only just forward of it.
	#
	# 1.18 out and 0.30 forward was the first try, and from any three-quarter
	# angle the post stood squarely in front of the keeper -- the pawnbroker was
	# a lamp with a stall behind it. 1.52 puts it outside both the stall's posts
	# and the workbench's top, so it lights the keeper's face across the counter
	# without ever being between them and you.
	var at := Vector3(1.52, 0.0, ShopBooth.KEEPER_BACK + 0.10)
	# ...unless there is no counter for it to be at the end of. The offsets above
	# are measured off the stall, so on the one person without one they plant a
	# 2 m pole a metre in FRONT of him -- which is the failure the note above
	# describes, except that a keeper with nothing between you and them gets it
	# from every angle instead of only from three-quarters. Beside him and half a
	# step back: still the only light on his face, never in front of it.
	if not look.has("booth"):
		at = Vector3(1.05, 0.0, -0.25)
	const LAMP_Y := 1.96

	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.035
	pm.bottom_radius = 0.055
	pm.height = LAMP_Y
	pm.radial_segments = 6
	post.mesh = pm
	post.material_override = iron
	post.position = at + Vector3(0.0, LAMP_Y * 0.5, 0.0)
	add_child(post)

	var cap := MeshInstance3D.new()
	var cm := PrismMesh.new()
	cm.size = Vector3(0.24, 0.14, 0.24)
	cap.mesh = cm
	cap.material_override = iron
	cap.position = at + Vector3(0.0, LAMP_Y + 0.07, 0.0)
	add_child(cap)

	var lamp_mesh := MeshInstance3D.new()
	var lmm := BoxMesh.new()
	lmm.size = Vector3(0.16, 0.20, 0.16)
	lamp_mesh.mesh = lmm
	lamp_mesh.material_override = _lamp_mat
	lamp_mesh.position = at + Vector3(0.0, LAMP_Y - 0.10, 0.0)
	add_child(lamp_mesh)

	_lamp = OmniLight3D.new()
	_lamp.light_color = lamp_color
	_lamp.light_energy = 1.1
	_lamp.omni_range = 5.5
	_lamp.omni_attenuation = 1.4
	_lamp.shadow_enabled = false
	_lamp.position = at + Vector3(0.0, LAMP_Y - 0.10, 0.0)
	add_child(_lamp)

	# The keeper's own body, so you cannot stand inside them if you come round
	# the side of the stall. The counter's collision belongs to `ShopBooth`.
	var solid := StaticBody3D.new()
	solid.collision_layer = K.L_WORLD
	solid.collision_mask = 0
	var cc := CollisionShape3D.new()
	var cshape := CapsuleShape3D.new()
	cshape.radius = 0.32
	cshape.height = maxf(_head, 0.8)
	cc.shape = cshape
	cc.position.y = _head * 0.5
	solid.add_child(cc)
	add_child(solid)


## The way down. A gatehouse with a cold mouth at the bottom of it: the garrison
## is warm and gold, so the entrance being the only cold thing in it is the only
## signposting needed.
##
## **The masonry is `Gatehouse` and everything that BEHAVES is here.** That split
## is deliberate and it is the same one `ShopBooth` uses: a booth is dressing with
## no state and a keeper is the thing you can talk to, and mixing them is how you
## end up unable to move a stall without re-tuning a prompt. The gatehouse knows
## where its own arch, its own passage floor and its own sign band are, and hands
## those back as constants; the mouth, the light it throws, the plate and the
## hold-to-descend stay on the Npc, because those are the parts the player
## presses.
func _build_gate() -> void:
	var house := Gatehouse.new()
	_body.add_child(house)

	_lamp_mat = StandardMaterial3D.new()
	# Faint. An additive quad at full strength reads as a lit swimming pool; the
	# gate should read as a hole with something cold behind it.
	_lamp_mat.albedo_color = Color(Pal.CYAN, 0.22)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Pal.CYAN
	_lamp_mat.emission_energy_multiplier = 0.55
	_lamp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lamp_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# **Lying flat over the shaft at the back of the passage**, not standing up in
	# the plane of the arch. That one change is most of the difference between the
	# old gate and this one: a vertical quad with nothing in front of it and
	# nothing behind it photographs as a teal poster, and the same quad laid over
	# a wellhead four metres down a dark passage photographs as light coming UP out
	# of the floor. You do not walk through this gate, you climb down it, and the
	# geometry should say so before the prompt does.
	var mouth := MeshInstance3D.new()
	var mm := QuadMesh.new()
	mm.size = Gatehouse.MOUTH_SIZE
	mouth.mesh = mm
	mouth.material_override = _lamp_mat
	mouth.position = Vector3(0.0, Gatehouse.MOUTH_Y, Gatehouse.MOUTH_Z)
	mouth.rotation.x = Gatehouse.MOUTH_PITCH
	_body.add_child(mouth)

	# The light sits just ABOVE the shaft, so it rakes the coping and the underside
	# of the headframe on its way out rather than only lighting the plate it is
	# stuck to. Range is up from 6.0 because it now has four metres of passage to
	# cross before it reaches anybody standing at the threshold.
	_lamp = OmniLight3D.new()
	_lamp.light_color = Pal.CYAN
	_lamp.light_energy = 3.2
	_lamp.omni_range = 13.0
	_lamp.omni_attenuation = 1.3
	_lamp.shadow_enabled = false
	_lamp.position = Vector3(0.0, 0.55, Gatehouse.MOUTH_Z + 0.6)
	_body.add_child(_lamp)

	var plate := Label3D.new()
	# The name of the place this gate opens onto, not the name of the setting.
	# "The Lower Worlds" is everything under the garrison (docs/GDD.md); THE
	# SUNKEN CUT is the one dungeon there is a way down into, and a sign over a
	# door should say where the door goes. It reads off `Prog.NAME` so the gate,
	# the loading card and the HUD cannot end up calling it three different
	# things.
	plate.text = Prog.NAME
	plate.font_size = 40
	plate.pixel_size = 0.0028
	plate.modulate = Pal.MOTH
	plate.outline_size = 14
	# On the string course over the arch, which is the band `Gatehouse` builds for
	# it. A sign floating in front of a doorway is a label; a sign on a course of
	# stone cut to carry one is a lintel.
	plate.position = Vector3(0.0, Gatehouse.PLATE_Y, Gatehouse.FACE_T + 0.3)
	_body.add_child(plate)
