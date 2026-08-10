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
##   B  The opening: black BEFORE the yard, the narration over it, the world
##      stopped, then the veil lifts on the courtyard and the elder speaks. Once
##      per save -- the flag is set and a second garrison does not re-narrate.
##   C  There is a man in the middle of the yard, in the arrival frame, with no
##      counter, and TALK on him says something and says a DIFFERENT something
##      the second time.
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
		print("VOICES (no --intro: the opening was skipped, beats B0..B6 not run)")
		return

	# The director is called after the warmup, and the whole opening is still in
	# front of it: the narration is ~15 s long.
	_ck("B0 the veil is down before a frame of the yard is drawn",
		Flow.busy and rig.paused)
	_ck("B1 the narrator is talking (%s)" % Voice.line(),
		Voice.line() == "opening")
	await rig.capture(out.path_join("v_00_black.png"))

	# The unit of this wait is the thing waited for, not a frame count: the veil
	# comes up when the line ends, and the line is however long it is.
	var lifted: bool = await rig.until(func() -> bool: return not Flow.busy, 45.0)
	_ck("B2 the opening ends by itself", lifted)
	_ck("B3 and gives the world back", not rig.paused)

	# He speaks AFTER the fade, not under it. Half a second of yard, then a voice.
	var spoke: bool = await rig.until(
		func() -> bool: return Voice.line() == "ive_been_expecting_you", 6.0)
	_ck("B4 the elder is expecting you", spoke)
	await rig.capture(out.path_join("v_01_arrival.png"))

	# Through `Garrison.INTRO_FLAG`, not a literal: `tools/shoot.gd` spells the
	# same flag out by hand (it cannot name a `class_name` without compiling it
	# before the autoloads exist), and this is the joint where a drift shows up.
	_ck("B5 the save has reported for duty", Game.flag(Garrison.INTRO_FLAG))
	# The other half of "once per save", and the half that would go wrong: the
	# flag is what `Flow` brings you back through this scene against, four or five
	# times an hour.
	var garrison: Garrison = rig.scene()
	garrison._open_the_game()
	await rig.wait_frames(4)
	_ck("B6 coming home does not re-narrate", not Flow.busy)


# --- C. The man in the middle ------------------------------------------------

func _elder(rig) -> void:
	var garrison: Garrison = rig.scene()
	if garrison == null or garrison.elder == null:
		_ck("C0 there is an elder in the yard", false)
		return

	var at := garrison.elder.global_position
	print("VOICES the elder stands at %.2v" % at)
	# The open middle, near the arrival: the hero lands at (0, 0, +4) looking
	# north, so this is the ground that is in front of him on the first frame.
	_ck("C0 he is in the open middle of the yard",
		absf(at.x) < 4.0 and absf(at.z) < 4.0)
	_ck("C1 forward of the arrival spot, so he is in the arrival frame",
		at.z < 3.4)
	# **And NOT on the centre line**, which is the failure the capture caught and
	# the code cannot: x = 0 is the arrival camera, the hero, the walk to the gate
	# and the gate's own 2.5 m cyan mouth, all on one axis. Standing him there put
	# him behind the hero and inside the doorway at the same time.
	_ck("C1b and off the gate's axis, where the hero is not standing on him",
		absf(at.x) > 1.6)
	# Not a counter. The row in `Npc.COUNTERS` has no `counter` key and the row in
	# `Npc.LOOKS` has no `booth`, and this is what those two absences look like
	# from outside.
	var booths := 0
	for c in garrison.elder.get_children():
		if c is ShopBooth:
			booths += 1
	_ck("C2 he is not standing behind a shop", booths == 0)
	var nearest := 999.0
	for l in garrison.lights:
		nearest = minf(nearest, at.distance_to(l.global_position))
	_ck("C3 he is clear of the relic ring (%.2f m)" % nearest, nearest > 2.0)

	# **The frame the placement is FOR**, taken before anything moves the hero:
	# the arrival camera, untouched, on the spot every player lands on. Captured
	# with or without `--intro`, because the opening is fifteen seconds and this
	# is the picture somebody actually has to look at. Every claim above is about
	# this shot and none of them can see it.
	await rig.capture(out.path_join("v_02_from_the_spawn.png"))

	_stand_at(rig, at + garrison.elder.global_transform.basis * Vector3(0.0, 0.0, 1.7))
	await rig.wait_physics_frames(6)
	var focused: bool = await rig.until(
		func() -> bool: return Prompt.focus == garrison.elder, 5.0)
	_ck("C4 TALK is on him", focused)

	Voice.stop()
	await rig.tap(["interact"])
	await rig.wait_frames(8)
	var first := Voice.line()
	print("VOICES elder says '%s'" % first)
	_ck("C5 talking to him says something", first != "")
	await rig.capture(out.path_join("v_03_elder.png"))

	# Two takes, alternating rather than rolled: "hail" is 0.8 s and would
	# otherwise be the most-repeated sound in the game.
	await rig.tap(["interact"])
	await rig.wait_frames(8)
	var second := Voice.line()
	print("VOICES elder then says '%s'" % second)
	_ck("C6 and a different something the second time", second != first
		and second != "")

	# And no screen came up. The elder is the proof that a row with a voice and no
	# counter is a whole person.
	_ck("C7 talking to him opens nothing", _screen(rig) == null)


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
	await rig.wait_frames(12)
	var screen := _screen(rig)
	if screen == null:
		_ck("D1 her counter opened", false)
		return
	_ck("D1 her counter opened", true)
	_ck("D2 she greets you as it opens (%s)" % Voice.line(),
		Voice.line() == "i_have_just_the_right_amulet_for_you")
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
