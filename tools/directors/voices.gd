extends RefCounted
## The fifteen recorded lines, the man they introduced, and the opening.
##
## Point it at GARRISON, and pass `--intro` -- this is the ONE director that
## wants the opening (`tools/shoot.gd._skip_the_opening` turns it off for every
## other one, because fifteen seconds of black is not what a harness is for):
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/voices.gd \
##     --out=/tmp/voices/x.png --warmup=20 --intro
##
## What it claims, in the order it proves them:
##
##   A  Every take named in `Voice.LINES` is a file that exists.
##   B  The room's half of the opening: the elder speaks a beat after the yard
##      is visible, once per save -- the flag is set and coming home does not
##      re-introduce the place. **The NARRATION is not here**; it moved to
##      `Flow.new_game` and the road painting on 2026-08-10, and
##      `tools/directors/title.gd` is what proves it.
##   C  The elder is in the arrival frame, behind the relic counter, and TALK on
##      him both says something -- a DIFFERENT something the second time -- and
##      opens the Far Lantern off the same press.
##   D  A counter greets you when you address it, says its piece on the press
##      that WORKED and not on the one that was refused, and says goodbye on the
##      way out.
##   E  One mouth: a line starting cuts the line before it.
##   F  A speaker with no take for a cue is silent, and that is not an error --
##      the alchemist does not comment on a sale.
##
## A is the beat that matters and it is the cheapest one: a typo in that table is
## a line that never plays, in a build where nothing warns and nothing crashes.

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/voices/x.png").get_base_dir()

	_table()
	await _opening(rig)
	await _elder(rig)
	await _counter(rig)
	_one_mouth()
	_silence()

	if _fails == 0:
		print("VOICES OK")
	else:
		print("VOICES FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("VOICES FAIL %s" % label)


# --- A. The table ------------------------------------------------------------

func _table() -> void:
	var count := 0
	var missing: Array[String] = []
	for speaker: StringName in Voice.LINES:
		var cues: Dictionary = Voice.LINES[speaker]
		for cue: StringName in cues:
			for take: String in cues[cue]:
				count += 1
				var path: String = Voice.DIR % [speaker, take]
				if not ResourceLoader.exists(path):
					missing.append(path)
	print("VOICES %d lines on disk, %d missing" % [count, missing.size()])
	_ck("A0 every take in the table is a file (%s)" % [missing], missing.is_empty())
	# docs/SCOPE.md §1 says 15 and the table is the manifest. A sixteenth line is
	# an amendment, not a commit.
	_ck("A1 fifteen lines, which is the count SCOPE froze", count == 15)


# --- B. The opening ----------------------------------------------------------

func _opening(rig) -> void:
	if rig.arg("intro", "") == "":
		print("VOICES (no --intro: the opening was skipped, beats B0..B4 not run)")
		return

	# **The narration is not here any more, and that is not a gap.** Until
	# 2026-08-10 this beat asserted a black veil, `Flow.busy`, and the narrator
	# talking over a stopped world -- all of which moved to `Flow.new_game` and
	# the road painting when the title screen landed. `tools/directors/title.gd`
	# beats C and D are where the narration is proven now, over the picture it is
	# actually delivered on. What is left here is the half that always belonged to
	# the ROOM: this scene is entered directly, so there is no fade in front of it
	# and the only thing owed is the elder.
	_ck("B0 no fade: the room is entered, not transitioned into",
		not Flow.busy and not rig.paused)

	# He speaks after a beat of visible yard, not on the first frame: the player
	# needs a moment to see where they are standing. The unit of the wait is the
	# thing waited for.
	var spoke: bool = await rig.until(
		func() -> bool: return Voice.line() == "ive_been_expecting_you", 8.0)
	_ck("B1 the elder is expecting you", spoke)
	# And you can SEE who is saying it. The line goes out through a `DialogueBox`
	# since 2026-08-10 (`Garrison._open_the_game`) -- same take, same timing, with
	# his face and the words under it. A box with no options: he is not asking
	# anything, so one press puts it away.
	var box: Node = rig.dialogue()
	_ck("B1b it is in a box with his face in it", box != null)
	if box != null:
		_ck("B1c and the words are the ones being said (%s)" % box.text(),
			box.text() == "Ah, yes! I've been expecting you.")
		_ck("B1d he is named on it (%s)" % box.speaker_name(),
			box.speaker_name() == DialogueDb.name_of(&"elder"))
	await rig.capture(out.path_join("v_01_arrival.png"))
	# Put it away before anything else: it blocks the world while it is up, which
	# is what it is for, and every beat below this one presses buttons.
	#
	# Tapped until it is gone and NOT a fixed two presses. The first press lands
	# while the line is still typing and only fills it, so the count depends on how
	# far through the sentence the capture above left us -- and one press too many
	# would go straight into the Lanternkeeper, who is 1.9 m away and inside his
	# own 2.3 m trigger.
	for _i in 4:
		if rig.dialogue() == null:
			break
		await rig.tap(["interact"])
		await rig.wait_frames(2)
	_ck("B1e and it can be pressed away", rig.dialogue() == null)

	# Through `Garrison.INTRO_FLAG`, not a literal: `tools/shoot.gd` spells the
	# same flag out by hand (it cannot name a `class_name` without compiling it
	# before the autoloads exist), and this is the joint where a drift shows up.
	_ck("B2 the save has reported for duty", Game.flag(Garrison.INTRO_FLAG))

	# The other half of "once per save", and the half that would go wrong: the
	# flag is what `Flow` brings you back through this scene against, four or five
	# times an hour. Silence it first, or a second greeting cannot be told from
	# the first one still playing.
	Voice.stop()
	var garrison: Garrison = rig.scene()
	garrison._open_the_game()
	await rig.wait_seconds(2.0)
	_ck("B3 coming home does not re-introduce the place", Voice.line() == "")
	_ck("B4 and does not take the screen", not Flow.busy)


# --- C. The elder, who keeps the Far Lantern -----------------------------------

## He was two people until 2026-08-10: an elder alone in the middle of the yard
## with three lines and no counter, and a silent Lanternkeeper behind the relic
## hall. The owner merged them, so this section changed shape -- every claim about
## the OPEN MIDDLE is gone, because he is behind a counter now, and the one claim
## that survived the move is the one that was always load-bearing: **he is in the
## arrival frame.** The opening's whole third beat is a voice from somebody you
## can see (`Garrison._open_the_game`), and moving him fifteen metres east is
## exactly the change that could have broken it in silence.
func _elder(rig) -> void:
	var garrison: Garrison = rig.scene()
	if garrison == null or garrison.keeper == null:
		_ck("C0 there is an elder in the yard", false)
		return

	var at := garrison.keeper.global_position
	print("VOICES the elder stands at %.2v" % at)

	# The arrival camera, spelled out rather than read off a node: the hero lands
	# at (0, 0, +4) and the boom sits behind him at (0, 1.7, +8) looking up -Z.
	# "In the frame" is then just the horizontal angle off that axis against half
	# the camera's fov, which is the cheapest true version of the claim.
	var eye := Vector3(0.0, 1.7, 8.0)
	var to := at - eye
	var off := rad_to_deg(absf(atan2(to.x, -to.z)))
	print("VOICES he is %.1f deg off the arrival camera's axis, %.1f m away"
		% [off, to.length()])
	_ck("C1 he is in the arrival frame (%.1f deg off axis)" % off, off < 24.0)

	# And NO counter, which is the half of him that is new. This checked for
	# exactly one while he stood on the plaza's middle behind a stall; he is the
	# person who greets you now, standing on the hero's own axis with nothing in
	# front of him (`Garrison.KEEPER_AT`), and a stall is the one object that can
	# put itself between a greeting and the person being greeted. Kept as a check
	# rather than deleted: the absence is the decision, so it is the thing worth
	# failing over if somebody gives him furniture again.
	var booths := 0
	for c in garrison.keeper.get_children():
		if c is ShopBooth:
			booths += 1
	_ck("C2 he has no counter between him and you", booths == 0)

	# **The frame the placement is FOR**, taken before anything moves the hero:
	# the arrival camera, untouched, on the spot every player lands on. Captured
	# with or without `--intro`, because the opening is fifteen seconds and this
	# is the picture somebody actually has to look at. C1 is a number about this
	# shot and it cannot see it.
	await rig.capture(out.path_join("v_02_from_the_spawn.png"))

	_stand_at(rig, at + garrison.keeper.global_transform.basis * Vector3(0.0, 0.0, 1.7))
	await rig.wait_physics_frames(6)
	var focused: bool = await rig.until(
		func() -> bool: return Prompt.focus == garrison.keeper, 5.0)
	_ck("C4 TALK is on him", focused)

	Voice.stop()
	await rig.tap(["interact"])
	# Waited for, not counted to. The greeting starts on the same press that opens
	# the screen, and the screen's own first frame is the expensive one -- eight
	# frames was enough while he had no counter and is not now.
	await rig.until(func() -> bool: return Voice.line() != "", 3.0)
	var first := Voice.line()
	print("VOICES elder says '%s'" % first)
	_ck("C5 talking to him says something", first != "")
	# The words on the screen are the words in the ear, because `DialogueDb` looks
	# them up by the TAKE that is playing rather than by the cue. That is the whole
	# design and this is the check that can see it: two takes on this cue, and the
	# box has to be showing the one being heard.
	var said: Node = rig.dialogue()
	_ck("C5b in a box, with his name on it", said != null)
	if said != null:
		_ck("C5c showing the take that is playing (%s / %s)" % [first, said.text()],
			said.text() == DialogueDb.SAID[&"elder"][first])
	await rig.capture(out.path_join("v_03_elder.png"))

	# **Both at once**, which no row did before the merge: the greeting plays AND
	# the counter is offered, off one press. Since 2026-08-10 the counter is behind
	# the Trade option rather than the press itself (`Npc.activate`) -- the greeting
	# is unchanged, and this is still the check that the one press reaches both.
	_ck("C6 and the Far Lantern is on the other side of it", await rig.talk("Trade"))
	_ck("C6b which is the same trade screen", _screen(rig) != null)

	var screen := _screen(rig)
	if screen != null:
		screen.close()
		await rig.wait_frames(6)

	# Two takes, alternating rather than rolled: "hail" is 0.8 s and would
	# otherwise be the most-repeated sound in the game.
	Voice.stop()
	await rig.tap(["interact"])
	await rig.until(func() -> bool: return Voice.line() != "", 3.0)
	var second := Voice.line()
	print("VOICES elder then says '%s'" % second)
	_ck("C7 and a different something the second time", second != first
		and second != "")
	var twice: Node = rig.dialogue()
	_ck("C7b and the box moved with him (%s)" % (twice.text() if twice != null else ""),
		twice != null and twice.text() == DialogueDb.SAID[&"elder"][second])
	# Out through the door he offers rather than by walking off, which is the beat
	# the Leave option exists for. His farewell has no recording yet, so this is
	# also the check that a written line with no take behind it still reaches the
	# screen -- `Voice.say` answers 0.0 and `DialogueDb` falls through to `WRITTEN`.
	Voice.stop()
	_ck("C8 he can be left", await rig.talk("Leave"))
	var parting: Node = rig.dialogue()
	_ck("C8b and says goodbye on the way out (%s)"
		% (parting.text() if parting != null else ""),
		parting != null and parting.text() == "You're doing wonderfully.")
	for _i in 4:
		if rig.dialogue() == null:
			break
		await rig.tap(["interact"])
		await rig.wait_frames(2)
	var again := _screen(rig)
	if again != null:
		again.close()
		await rig.wait_frames(6)


# --- D. A counter, start to finish -------------------------------------------

func _counter(rig) -> void:
	var garrison: Garrison = rig.scene()
	if garrison == null or garrison.jeweller == null:
		_ck("D0 there is a jewelcrafter in the yard", false)
		return

	Game.gold = 40000
	Voice.stop()
	_stand_at(rig, garrison.jeweller.global_position
		+ garrison.jeweller.global_transform.basis * Vector3(0.0, 0.0, 1.6))
	await rig.wait_physics_frames(6)
	var focused: bool = await rig.until(
		func() -> bool: return Prompt.focus == garrison.jeweller, 5.0)
	_ck("D0 TALK is on her", focused)

	await rig.tap(["interact"])
	# The greeting is on the PRESS and the counter is on the option after it. D2
	# below is read before the walk through the conversation for exactly that
	# reason: it is the press that has to have made her speak.
	_ck("D2 she greets you as you address her (%s)" % Voice.line(),
		Voice.line() == "i_have_just_the_right_amulet_for_you")
	_ck("D0b and offers the bench", await rig.talk("Trade"))
	await rig.wait_frames(12)
	var screen := _screen(rig)
	if screen == null:
		_ck("D1 her counter opened", false)
		return
	_ck("D1 her counter opened", true)
	_ck("D3 and the screen knows whose voice it is", screen.speaker == &"jewelcrafter")
	await rig.capture(out.path_join("v_04_counter.png"))

	# The press that WORKED.
	var blank := _row(screen, JewelDb.blank_id(&"amulet"))
	_ck("D4 there is a blank to buy", not blank.is_empty())
	screen._cursor = screen._rows.find(blank)
	Voice.stop()
	screen._commit()
	await rig.wait_frames(6)
	_ck("D5 a sale that landed is remarked on (%s)" % Voice.line(),
		Voice.line() == "there_you_go")

	# And the press that did not. A keeper thanking you for a purchase you could
	# not afford is worse than one who says nothing.
	Game.gold = 0
	screen._refresh()
	var ring := _row(screen, JewelDb.blank_id(&"ring1"))
	screen._cursor = screen._rows.find(ring)
	Voice.stop()
	screen._commit()
	await rig.wait_frames(6)
	_ck("D6 a refusal is not (silent: %s)" % (Voice.line() == ""),
		Voice.line() == "")

	Voice.stop()
	screen.close()
	await rig.wait_frames(8)
	_ck("D7 she says goodbye on the way out (%s)" % Voice.line(),
		Voice.line() == "youre_looking_quite_fashionable")
	await rig.wait_frames(10)


# --- E. One mouth ------------------------------------------------------------

func _one_mouth() -> void:
	Voice.say(&"smith", &"hello")
	var first := Voice.line()
	Voice.say(&"pawnbroker", &"hello")
	print("VOICES '%s' interrupted by '%s'" % [first, Voice.line()])
	_ck("E0 the second line is the one playing",
		Voice.line() == "ive_just_the_deal_for_you")
	_ck("E1 and the first is not", first != Voice.line())
	Voice.stop()


# --- F. Nothing to say is a valid answer -------------------------------------

func _silence() -> void:
	# The alchemist was recorded with two lines and has no `deal`; the
	# Lanternkeeper was not recorded at all. Both go through the same call as
	# everybody else and both are silent, which is what keeps `Npc.activate` and
	# `TradeScreen` free of a branch per counter.
	Voice.stop()
	_ck("F0 the alchemist does not comment on a sale",
		is_zero_approx(Voice.say(&"alchemist", &"deal")) and not Voice.speaking())
	_ck("F1 the Lanternkeeper has nothing to say at all",
		is_zero_approx(Voice.say(&"keeper", &"hello")) and not Voice.speaking())
	_ck("F2 but the alchemist does have the two she was given",
		Voice.say(&"alchemist", &"farewell") > 0.0)
	Voice.stop()


# --- helpers -----------------------------------------------------------------

func _row(screen, id: StringName) -> Dictionary:
	for r in screen._rows:
		if r.get("kind") == &"buy" and r["line"]["id"] == id:
			return r
	return {}


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


func _stand_at(rig, where: Vector3) -> void:
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		return
	var hero: Node3D = players[0]
	hero.global_position = where
