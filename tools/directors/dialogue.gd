extends RefCounted
## The conversation: two figures, a name, a line typed out, and a question.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/dialogue.gd \
##     --out=/tmp/dialogue/x.png --warmup=40
##
## What it claims, in the order it proves them:
##
##   A  Every recorded take has words written for it, and every person in the
##      garrison has a name and a face. This is the table check, and it is the
##      cheapest one: a typo in `DialogueDb.SAID` is a line that types nothing,
##      in a build where nothing warns and nothing crashes. It now also walks
##      `StoryDb`: every beat has pages, every `told` gate names a beat that
##      exists, and every unlock names somebody with a face.
##   B  TALK opens a BOX, not a shop. The speaker's name is on it, their body is
##      in it, the hero's is opposite, and the line arrives a character at a time.
##   C  The button that opened it is the button that drives it: fill the line,
##      then ask the question.
##   D  Trade opens the same `TradeScreen` it always did.
##   E  Leave says goodbye -- out loud where there is a recording, in text where
##      there is not -- and hands the world back.
##   F  The world is HELD while a box is up: no walking off mid-sentence, and
##      nothing else can take the interact button.
##   G  **One typeface across the option list.** `Trade` used to render in Cinzel
##      at 19 and `Leave` in the sans at 16, which is the kit's primary promotion
##      doing exactly what it is for on a screen it is wrong for.
##   H  **The tree.** A topic is asked, answered, and the same list comes back;
##      a story beat is heard once and is gone; and the gate is progression --
##      Aldric owes the briefing on a fresh save and does not owe it twice.
##
## The frames are the point (CLAUDE.md §2). `d_02` and `d_03` are the same
## sentence half a second apart and are the only proof that the typing is typing.

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/dialogue/x.png").get_base_dir()

	_table()
	await _arrival(rig)
	await _story(rig)
	await _tree(rig)
	await _open(rig)
	await _options(rig)
	await _faces(rig)
	await _trade(rig)
	await _leave(rig)
	await _gallery(rig)

	if _fails == 0:
		print("DIALOGUE OK")
	else:
		print("DIALOGUE FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("DIALOGUE FAIL %s" % label)


# --- A. The table --------------------------------------------------------------

func _table() -> void:
	# Every take that can play has words. The direction of this check matters:
	# walking `Voice.LINES` catches the line that plays and types nothing, which is
	# the failure a player sees. Walking `SAID` instead would only catch a
	# transcript nobody can hear.
	# Every index is read into an ANNOTATED local first: `Voice.LINES` is a const
	# Dictionary and indexing one hands back a Variant, which is a parse error the
	# moment you iterate it (CLAUDE.md §3).
	var missing: Array[String] = []
	for who: StringName in Voice.LINES:
		if who == &"narrator":
			# The opening narration is a cutscene's, and the cutscene writes its own
			# words under the picture (`Cutscene.OPENING`). Nobody speaks it in a box.
			continue
		var said: Dictionary = DialogueDb.SAID.get(who, {})
		var cues: Dictionary = Voice.LINES[who]
		for cue: StringName in cues:
			var takes: Array = cues[cue]
			for take: String in takes:
				if String(said.get(take, "")).is_empty():
					missing.append("%s/%s" % [who, take])
	_ck("A0 every recorded take has words (%s)" % [missing], missing.is_empty())

	# And everybody who can be addressed has a name and a body. `Npc.COUNTERS` is
	# the manifest: a role with a `voice` is a role that can open a box.
	var nameless: Array[String] = []
	var faceless: Array[String] = []
	for role: int in Npc.COUNTERS:
		var row: Dictionary = Npc.COUNTERS[role]
		var who := StringName(row.get("voice", &""))
		if who == &"":
			continue
		if DialogueDb.name_of(who).is_empty():
			nameless.append(String(who))
		var model := DialogueDb.model_of(who)
		if model.is_empty() or not NpcBody.PEOPLE.has(model):
			faceless.append(String(who))
	_ck("A1 every counter's speaker has a name (%s)" % [nameless], nameless.is_empty())
	_ck("A2 and a body to show (%s)" % [faceless], faceless.is_empty())
	# The hero is the other half of every two-shot and is not a counter, so no
	# walk over `COUNTERS` can see him.
	_ck("A3 and so does the listener", not DialogueDb.name_of(&"hero").is_empty())

	# `StoryDb`'s tables, walked the same way and for the same reason: a beat with
	# no pages is a press that opens nothing, a `told` gate naming a beat that was
	# renamed is a line the player can never reach, and both are silent.
	var empty: Array[String] = []
	var dangling: Array[String] = []
	var unknown: Array[String] = []
	for who: StringName in StoryDb.BEATS:
		if DialogueDb.name_of(who).is_empty():
			unknown.append(String(who))
		var ids := {}
		for beat: Dictionary in (StoryDb.BEATS[who] as Array):
			var id := StringName(beat.get("id", &""))
			ids[id] = true
			if StoryDb.pages_of(beat).is_empty():
				empty.append("%s/%s" % [who, id])
		# Read AFTER the whole list is collected, so a beat may gate on one that
		# comes later in the table without this reporting it as missing. Nothing
		# does today; the check is about the id existing, not about the order.
		for entry: Dictionary in ((StoryDb.BEATS[who] as Array)
				+ (StoryDb.TOPICS.get(who, []) as Array)):
			var after := StringName((entry.get("needs", {}) as Dictionary).get("told", &""))
			if after != &"" and not ids.has(after):
				dangling.append("%s/%s -> %s" % [who, entry.get("id", &""), after])
		for topic: Dictionary in (StoryDb.TOPICS.get(who, []) as Array):
			if StoryDb.pages_of(topic).is_empty():
				empty.append("%s/%s" % [who, topic.get("id", &"")])
	_ck("A4 every story beat and topic has words (%s)" % [empty], empty.is_empty())
	_ck("A5 and every `told` gate names a beat that exists (%s)" % [dangling],
		dangling.is_empty())
	_ck("A6 and everybody with a story has a face (%s)" % [unknown], unknown.is_empty())

	var strangers: Array[String] = []
	for who: StringName in StoryDb.UNLOCKS:
		if DialogueDb.name_of(who).is_empty():
			strangers.append(String(who))
	_ck("A7 and everybody who can be unlocked is somebody (%s)" % [strangers],
		strangers.is_empty())


# --- The arrival beat, got out of the way --------------------------------------

## `Garrison._open_the_game` opens the elder's arrival box 1.4 s after the room is
## ready. `shoot.gd` sets `reported_for_duty` before the scene is attached so it
## does not normally fire -- but `--intro` turns that off, and a save whose flag
## has been cleared brings it back. It is worth handling rather than assuming
## away: two boxes up at once is not a state the game can reach on its own, and
## both of them POLL the same button, so a director that does not clear this one
## is driving two conversations with one press and every beat after it is a coin
## toss. Waited for by name rather than slept past -- 1.4 s is a number that can
## change, and the thing being waited for is the box.
func _arrival(rig) -> void:
	var came: bool = await rig.until(func() -> bool: return rig.dialogue() != null, 2.5)
	if not came:
		# It has already been and gone, or this scene did not run the opening.
		return
	var box: Node = rig.dialogue()
	_ck("Z0 the arrival beat is the elder, in a box (%s)" % box.speaker_name(),
		box.speaker_name() == DialogueDb.name_of(&"elder"))
	for _i in 6:
		if rig.dialogue() == null:
			break
		await rig.tap(["interact"])
		await rig.wait_frames(2)
	_ck("Z1 and can be pressed away", rig.dialogue() == null)
	_ck("Z2 giving the yard back",
		await rig.until(func() -> bool: return not Prompt.blocked, 2.0))


# --- H. The story, and the gate on it ------------------------------------------
## The elder is the one who has something long to say, so he is the one this beat
## uses. On a harness save he owes the briefing: nine pages that say what the
## outpost is for, who pays for it and what happened to the cadet before you.

func _story(rig) -> void:
	var garrison: Garrison = rig.scene()
	if garrison == null or garrison.keeper == null:
		_ck("H0 the elder is in the yard", false)
		return

	var owed: Dictionary = StoryDb.pending(&"elder")
	_ck("H0 a fresh save is owed the briefing (%s)" % [owed.get("id", "-")],
		StringName(owed.get("id", &"")) == &"briefing")
	_ck("H1 and has not been told it yet",
		not Game.flag(StoryDb.told_flag(&"elder", &"briefing")))

	await _walk_to(rig, garrison.keeper)
	Voice.stop()
	await rig.tap(["interact"])
	var up: bool = await rig.until(func() -> bool: return rig.dialogue() != null, 3.0)
	var box: Node = rig.dialogue()
	if not up or box == null:
		_ck("H2 he opens a box", false)
		return
	_ck("H2 and it is the briefing, not his greeting (%s)" % box.text(),
		box.text().begins_with("Aldric Vane."))
	await rig.tap(["interact"])
	await rig.wait_frames(3)
	await rig.capture(out.path_join("d_11_briefing.png"))

	# Turn the whole thing. The count is generous rather than exact -- the beat is
	# nine pages today and the point of the check is that it ENDS, not that it is
	# nine.
	var pages := 0
	for _i in 40:
		if rig.dialogue() == null or box.is_choosing():
			break
		pages += 1
		await rig.tap(["interact"])
		await rig.wait_frames(2)
	_ck("H3 it is a long one and it finishes (%d presses)" % pages, pages > 6)
	_ck("H4 and reading it to the end is what marks it told",
		Game.flag(StoryDb.told_flag(&"elder", &"briefing")))
	_ck("H5 so he does not owe it twice",
		StringName(StoryDb.pending(&"elder").get("id", &"")) != &"briefing")


# --- J. The tree ---------------------------------------------------------------
## A topic is a question, not a spend: it is answered, and the same list comes
## back up. Everything in this repo's dialogue before today ended the conversation
## on the first choice, which is the shape a shop menu has and not the shape a
## person has.

func _tree(rig) -> void:
	var garrison: Garrison = rig.scene()
	if garrison == null or garrison.keeper == null:
		return
	# Out of the briefing's box and back to him with a clean press.
	await _dismiss(rig)
	await _walk_to(rig, garrison.keeper)
	Voice.stop()
	await rig.tap(["interact"])
	if not await rig.until(func() -> bool: return rig.dialogue() != null, 3.0):
		_ck("J0 he can be addressed again", false)
		return
	var box: Node = rig.dialogue()
	_ck("J0 and now says his recorded greeting (%s)" % box.text(),
		box.text() in ["Hail!", "How go your explorations?"])

	# Press through to the list. This is a loop and not two taps on purpose: a
	# press that lands while the typewriter is still running COMPLETES the page
	# instead of turning it, so how many presses a one-page greeting costs is a
	# function of how long "Hail!" takes to type versus how long a tap takes to
	# land. Guessing the number made this beat a coin toss -- and losing the toss
	# meant the extra press hit the option list and picked something, which reads
	# as "the box vanished" three checks later.
	for _i in 8:
		if rig.dialogue() == null or box.is_choosing():
			break
		await rig.tap(["interact"])
		await rig.wait_frames(3)
	if rig.dialogue() == null or not box.is_choosing():
		_ck("J1 the options come up", false)
		return
	var labels: PackedStringArray = box.choice_labels()
	print("DIALOGUE elder options %s" % [labels])
	_ck("J1 the briefing unlocked topics to ask about (%s)" % [labels],
		labels.size() > 2 and labels[0] == "Trade"
			and labels[labels.size() - 1] == "Leave")
	await rig.capture(out.path_join("d_12_topics.png"))

	# Walk to the first topic -- index 1, straight under Trade -- and ask it.
	await rig.tap(["ui_down"])
	await rig.wait_frames(2)
	var asked := labels[1] if labels.size() > 1 else ""
	await rig.tap(["interact"])
	await rig.wait_frames(4)
	box = rig.dialogue()
	_ck("J2 asking '%s' is answered rather than ending it" % asked,
		box != null and not box.text().is_empty())
	if box == null:
		return
	await rig.capture(out.path_join("d_13_answer.png"))

	# Press through the answer. The list has to be waiting on the other side.
	for _i in 12:
		if rig.dialogue() == null or box.is_choosing():
			break
		await rig.tap(["interact"])
		await rig.wait_frames(2)
	_ck("J3 and the same questions are waiting afterwards (%s)"
		% [box.choice_labels() if rig.dialogue() != null else []],
		rig.dialogue() != null and box.is_choosing()
			and box.choice_labels() == labels)
	# ...and the same question can be asked again. A topic is not consumed.
	_ck("J4 including the one just asked",
		rig.dialogue() != null and asked in box.choice_labels())
	await _dismiss(rig)


# --- B. The box opens ----------------------------------------------------------

func _open(rig) -> void:
	var garrison: Garrison = rig.scene()
	if garrison == null or garrison.smith == null:
		_ck("B0 there is a smith in the yard", false)
		return

	# He owes an arrival beat of his own -- he walked into this yard after the
	# first boss died. Get it out of the way so the beats below are about the
	# recorded greeting, which is what they have always been about.
	await _exhaust(rig, garrison.smith, &"smith")

	await _walk_to(rig, garrison.smith)
	_ck("B0 TALK is on him", Prompt.focus == garrison.smith)
	await rig.capture(out.path_join("d_01_prompt.png"))

	Voice.stop()
	await rig.tap(["interact"])
	var box: Node = null
	var up: bool = await rig.until(func() -> bool: return rig.dialogue() != null, 3.0)
	box = rig.dialogue()
	_ck("B1 a box opened, not a shop", up and _screen(rig) == null)
	if box == null:
		return

	_ck("B2 it is his name on it, not his trade (%s)" % box.speaker_name(),
		box.speaker_name() == DialogueDb.name_of(&"smith"))
	_ck("B3 and the words are the ones he is saying (%s)" % box.text(),
		box.text() == "I've the finest wares in the Vale.")

	# THE FRAME THIS DIRECTOR EXISTS FOR. Caught deliberately early: a sentence
	# half arrived is the only picture that can tell typing from printing, and it
	# is gone about 0.6 s after the press at `DialogueBox.TYPE_CPS`.
	_ck("B4 the line is still arriving", box.is_typing())
	await rig.capture(out.path_join("d_02_typing.png"))

	# And it is HELD. `hero.gd` reads `Prompt.blocked` for its own lock, so this
	# one check covers both halves: nothing else can take the interact button, and
	# the hero cannot walk out of the conversation while it is happening.
	_ck("B5 the world is held while somebody is talking", Prompt.blocked)


# --- C. One button drives it ---------------------------------------------------

func _options(rig) -> void:
	var box: Node = rig.dialogue()
	if box == null:
		_ck("C0 there is a box to drive", false)
		return

	await rig.tap(["interact"])
	await rig.wait_frames(2)
	_ck("C0 the first press fills the line rather than turning the page",
		not box.is_typing() and not box.is_choosing())
	await rig.capture(out.path_join("d_03_line.png"))

	await rig.tap(["interact"])
	await rig.wait_frames(4)
	_ck("C1 the second press asks the question", box.is_choosing())
	var labels: PackedStringArray = box.choice_labels()
	print("DIALOGUE options %s" % [labels])
	# Trade first and Leave last, with whatever he will answer questions about in
	# between. Asserted by the ENDS rather than by the whole list: the middle grows
	# as `StoryDb.TOPICS` does, and a check that pinned the exact list would fail
	# every time somebody wrote him a new question.
	_ck("C2 Trade first, Leave last (%s)" % [labels],
		labels.size() >= 2 and labels[0] == "Trade"
			and labels[labels.size() - 1] == "Leave")
	await rig.capture(out.path_join("d_04_options.png"))

	# The stick walks the list and wraps, so a player never dead-ends on it. It
	# also has to come back to 0, because `_trade` below takes whatever the cursor
	# is on -- one press per row, whatever the row count is today.
	await rig.tap(["ui_down"])
	await rig.wait_frames(2)
	_ck("C3 the stick moves the cursor", box.choice_index() == 1)
	for _i in labels.size() - 1:
		await rig.tap(["ui_down"])
		await rig.wait_frames(2)
	_ck("C4 and wraps (%d)" % box.choice_index(), box.choice_index() == 0)


# --- G. One typeface -----------------------------------------------------------
## `Trade` rendered in Cinzel at 19 and `Leave` in Alegreya Sans at 16, because
## `VerbRow` promotes the first row of a panel to the display face. That is the
## kit's rule and it is right on a shop menu; on a list of things one person can
## say it reads as two different kinds of object. `DialogueBox._ask` turns it off,
## and this is the check that it stays off -- read off the resolved theme font,
## not off the config, so a theme change cannot bring it back in silence.

func _faces(rig) -> void:
	var box: Node = rig.dialogue()
	if box == null or not box.is_choosing():
		_ck("G0 there are options to measure", false)
		return
	var faces: PackedStringArray = box.choice_faces()
	print("DIALOGUE option faces %s" % [faces])
	var one := true
	for f in faces:
		if f != faces[0]:
			one = false
	_ck("G0 every option is in the same face at the same size (%s)" % [faces],
		faces.size() >= 2 and one)
	_ck("G1 and it is the body face, not the display one (%s)" % [faces],
		faces.size() > 0 and not faces[0].begins_with("Cinzel"))


# --- D. Trade ------------------------------------------------------------------

func _trade(rig) -> void:
	var box: Node = rig.dialogue()
	if box == null or not box.is_choosing():
		_ck("D0 the options are up", false)
		return
	await rig.tap(["interact"])
	var opened: bool = await rig.until(func() -> bool: return _screen(rig) != null, 3.0)
	_ck("D0 Trade opens the counter", opened)
	_ck("D1 and it is the smith's, unchanged",
		_screen(rig) != null and _screen(rig).catalogue == ShopDb)
	# The box goes with the press. Two windows describing the same person, one
	# behind the other, is the failure this checks for.
	_ck("D2 and the conversation gets out of its way", rig.dialogue() == null)
	await rig.wait_frames(12)
	await rig.capture(out.path_join("d_05_trade.png"))

	var screen := _screen(rig)
	if screen != null:
		screen.close()
		await rig.until(func() -> bool: return _screen(rig) == null, 3.0)
	await rig.wait_frames(6)


# --- E. Leave ------------------------------------------------------------------

func _leave(rig) -> void:
	var garrison: Garrison = rig.scene()
	await _walk_to(rig, garrison.smith)
	Voice.stop()
	await rig.tap(["interact"])
	_ck("E0 he can be addressed again", await rig.talk("Leave"))

	var box: Node = rig.dialogue()
	_ck("E1 and says goodbye rather than just closing (%s)"
		% (box.text() if box != null else ""),
		box != null and box.text() == "Take care.")
	_ck("E2 out loud, too (%s)" % Voice.line(), Voice.line() == "take_care")
	await rig.capture(out.path_join("d_06_farewell.png"))

	for _i in 4:
		if rig.dialogue() == null:
			break
		await rig.tap(["interact"])
		await rig.wait_frames(2)
	# **This is the check that found the `Prompt._armed` bug.** The press that
	# closes the last page was still down on the frame the block came off, and the
	# keeper -- back in reach that same frame -- took it and started the whole
	# conversation again. What it looked like was a box that would not go away.
	var left: Node = rig.dialogue()
	if left != null:
		print("DIALOGUE leftover box: %s / '%s' choosing=%s"
			% [left.speaker_name(), left.text(), left.is_choosing()])
	_ck("E3 the box goes away when it is pressed", left == null)
	# `close()` is a `queue_free`, so the block does not come off until the node
	# is actually gone -- one frame later at the earliest. Waited for rather than
	# asserted on the spot: the thing that matters is that it comes off at all.
	var freed: bool = await rig.until(func() -> bool: return not Prompt.blocked, 2.0)
	_ck("E4 and hands the world back", freed)


# --- F. The other faces --------------------------------------------------------

## One frame per speaker, because the bust crop is the part of this that cannot be
## asserted. `DollStage.BUST_OF_H` is a fraction of each body's own height and the
## garrison is deliberately 38 cm of people apart (`NpcBody.PEOPLE`): the smith is
## 1.44 m and the alchemist 1.82 m, and a crop that reads well on one of them is
## the exact way to get a chin or a chest on the other.
func _gallery(rig) -> void:
	var garrison: Garrison = rig.scene()
	var who := {
		"d_07_alchemist.png": garrison.alchemist,
		"d_08_keeper.png": garrison.keeper,
		"d_09_pawnbroker.png": garrison.vendor,
		"d_10_jewelcrafter.png": garrison.jeweller,
	}
	for shot: String in who:
		var person: Npc = who[shot]
		if person == null:
			continue
		await _walk_to(rig, person)
		Voice.stop()
		await rig.tap(["interact"])
		var up: bool = await rig.until(func() -> bool: return rig.dialogue() != null, 3.0)
		if not up:
			_ck("F %s never opened a box" % shot, false)
			continue
		# Let the line finish rather than shooting it mid-word: these frames are
		# about the FACES, and a half-typed sentence is the subject of `d_02`.
		await rig.tap(["interact"])
		await rig.wait_frames(6)
		await rig.capture(out.path_join(shot))
		for _i in 4:
			if rig.dialogue() == null:
				break
			await rig.tap(["ui_cancel"])
			await rig.wait_frames(2)
		# Cancel and NOT the pause menu behind it: `ui_cancel` opens `PauseMenu`
		# too, and a box that lets the press through leaves the yard frozen with a
		# menu over it -- which the next beat would report as "nobody would talk".
		_ck("F %s closes on cancel, and only that" % shot,
			rig.dialogue() == null and not rig.paused)


# --- helpers -------------------------------------------------------------------

## Stand in front of somebody and wait until they actually own the interact
## button. An Area3D notices a teleported body on the PHYSICS clock, so the unit
## of this wait is the thing waited for and never a frame count (`shoot.until`).
func _walk_to(rig, who: Node3D) -> void:
	# Their OWN forward and not world +Z: the keeper and the jewelcrafter are
	# turned into the yard, and a fixed offset puts you behind their booth.
	var front: Vector3 = who.global_transform.basis * Vector3(0.0, 0.0, 1.65)
	_stand_at(rig, who.global_position + front)
	await rig.wait_physics_frames(6)
	var focused: bool = await rig.until(
		func() -> bool: return Prompt.focus == who, 5.0)
	if not focused:
		var players: Array = rig.get_nodes_in_group(&"player")
		var hero: Node3D = players[0] if not players.is_empty() else null
		_ck("could not get the interact button on %s (blocked=%s, focus=%s, %.2f m away, inside=%s, enabled=%s, paused=%s)"
			% [who.name, Prompt.blocked, Prompt.focus,
			   0.0 if hero == null else hero.global_position.distance_to(who.global_position),
			   who.player_inside, who.enabled, rig.paused],
			false)


## Close whatever box is up, with the button a player would use.
func _dismiss(rig) -> void:
	for _i in 6:
		if rig.dialogue() == null:
			break
		await rig.tap(["ui_cancel"])
		await rig.wait_frames(2)
	await rig.until(func() -> bool: return not Prompt.blocked, 2.0)


## Talk to somebody until they have no story left to tell, so the beat that
## follows is about their recorded greeting rather than about their arrival.
func _exhaust(rig, who: Node3D, voice: StringName) -> void:
	for _round in 8:
		if StoryDb.pending(voice).is_empty():
			return
		await _walk_to(rig, who)
		Voice.stop()
		await rig.tap(["interact"])
		if not await rig.until(func() -> bool: return rig.dialogue() != null, 3.0):
			return
		var box: Node = rig.dialogue()
		for _page in 40:
			if rig.dialogue() == null or box.is_choosing():
				break
			await rig.tap(["interact"])
			await rig.wait_frames(2)
		await _dismiss(rig)
	_ck("%s still owes a story after 8 conversations" % voice, false)


func _stand_at(rig, where: Vector3) -> void:
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		return
	var hero: Node3D = players[0]
	hero.global_position = where


func _screen(rig) -> TradeScreen:
	for n in _all(rig.scene()):
		if n is TradeScreen:
			return n
	return null


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found
