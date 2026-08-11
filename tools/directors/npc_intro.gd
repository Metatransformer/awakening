extends RefCounted
## The arrivals: who unlocks whom, who sells the stores, and the two-hander the
## elder plays when somebody new is standing in the yard.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/npc_intro.gd \
##     --out=/tmp/intro/x.png --warmup=40 --meet
##
## **`--meet` is required and this director refuses to run without it.** The
## harness stamps `met_*` for every keeper by default (`shoot.gd
## ._skip_the_introductions`) precisely so that no OTHER director has a four-page
## conversation open itself over the frame it was taking. Without the flag there
## is nothing here to photograph, and a run that quietly proved nothing is the
## failure mode CLAUDE.md §2 is about.
##
## What it claims, in the order it proves them:
##
##   A  The ladder. The smith is behind an OBJECT (the maker's mark) and not
##      behind a kill count; the alchemist and the jewelcrafter are behind boss
##      one and boss two. A fresh save has neither.
##   B  The sluice keeper drops the mark, drops no relic, and `BossDb.validate`
##      is happy about it -- which is the rule that had to be amended for any of
##      this to exist.
##   C  The stores moved. Arrows, bag slots and hearts are the quartermaster's
##      (`SupplyDb`) and are gone from the forge, at the same ids and the same
##      prices -- because a save that already bought two bag slots must not get
##      them back.
##   D  The scene. The elder opens on himself, the words type, the speaker
##      changes to Kessa, **and the camera is looking at whoever is talking.**
##      Two frames, one per end of the pan.
##   E  It hands the camera back, and it happens once per save.
##   F  The long pan: Brannoc is twelve and a half metres away across the yard,
##      which is the framing a fixed lens could not reach. Two more frames.
##
## **D and F share two measurements and need both.** The ANGLE between where the
## camera is pointing and the line to the speaker's head says it is aimed at the
## right person; `_fills` says you can SEE them, by projecting their crown and
## their feet through the camera that rendered the frame. The angle alone passed
## on a picture of Kessa at 0.0 degrees and a sixth of the frame tall, most of
## that behind the dialogue box -- an aim is not a shot. Both are facts about the
## rendered transform and know nothing about the tween that produced it, so a
## `ConvoCamera` rewritten from scratch would still be judged by them.

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/intro/x.png").get_base_dir()

	# **First thing, before a single await.** `--meet` leaves all four keepers
	# unmet, and `Garrison._do_the_rounds` would then play all four scenes back to
	# back -- sixteen pages, with D and F photographing whichever one happened to
	# be up. This leaves exactly one owed. `run` is called during warmup and the
	# yard's own wait is 1.2 s, so these land first; F re-runs the smith's by hand
	# afterwards, which does not consult the flag.
	for who: StringName in [&"smith", &"alchemist", &"jewelcrafter"]:
		Game.set_flag(StoryDb.intro_flag(who))

	_ladder()
	_boss_table()
	_stores()

	if not _met_is_clear():
		_ck("D0 --meet was passed (nothing below can run without it)", false)
		_verdict()
		return

	await _scene(rig)
	await _long_pan(rig)

	_verdict()


func _verdict() -> void:
	if _fails == 0:
		print("INTRO OK -- every check passed")
	else:
		print("INTRO FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("INTRO FAIL %s" % label)


## `--meet` reaches this director as an arg, but the thing that actually matters
## is whether the flags are down -- somebody could stamp them by hand.
func _met_is_clear() -> bool:
	return not Game.flag(StoryDb.intro_flag(&"quartermaster"))


# --- A. The ladder -------------------------------------------------------------

func _ladder() -> void:
	# `met()` and not `unlocked()`: `unlocked` LATCHES, and the harness has already
	# stamped all five arrival flags so every keeper is standing in the yard to be
	# photographed. The gate itself is what this beat is about, and it is still
	# readable underneath the latch.
	var smith: Dictionary = StoryDb.UNLOCKS.get(&"smith", {})
	_ck("A0 the smith is gated on an item and not a kill count",
		smith.has("item") and not smith.has("bosses"))
	_ck("A1 that item is the maker's mark",
		StringName(smith.get("item", &"")) == StoryDb.SMITH_TOKEN)

	var had := Game.has(StoryDb.SMITH_TOKEN)
	Game.items.erase(StoryDb.SMITH_TOKEN)
	_ck("A2 without the mark, the forge is shut", not StoryDb.met(smith))
	Game.grant(StoryDb.SMITH_TOKEN)
	_ck("A3 with it, Brannoc has arrived", StoryDb.met(smith))
	if not had:
		Game.items.erase(StoryDb.SMITH_TOKEN)

	_ck("A4 the alchemist is behind boss one",
		int((StoryDb.UNLOCKS.get(&"alchemist", {}) as Dictionary).get("bosses", 0)) == 1)
	_ck("A5 the jewelcrafter is behind boss two",
		int((StoryDb.UNLOCKS.get(&"jewelcrafter", {}) as Dictionary).get("bosses", 0)) == 2)
	# The two who are there on the first frame, and the reason C matters.
	_ck("A6 the elder and the quartermaster are ungated",
		(StoryDb.UNLOCKS.get(&"elder", {}) as Dictionary).is_empty()
		and (StoryDb.UNLOCKS.get(&"quartermaster", {}) as Dictionary).is_empty())

	# The ladder order the yard plays them in, which is a `const` and not a
	# Dictionary's key order -- see `StoryDb.INTRO_ORDER`.
	_ck("A7 every rung has a scene written for it",
		StoryDb.INTRO_ORDER.all(func(w: StringName) -> bool:
			return not StoryDb.introduction(w).is_empty()))
	# **Two speakers minimum.** A one-voice row is a beat wearing a scene's
	# clothes, and the camera would sit still through the whole of it.
	for who: StringName in StoryDb.INTRO_ORDER:
		var voices := {}
		for line: Dictionary in StoryDb.introduction(who):
			voices[StringName(line.get("who", &""))] = true
		_ck("A8 %s's scene has more than one mouth in it (%d)"
			% [who, voices.size()], voices.size() >= 2)


# --- B. The drop ---------------------------------------------------------------

func _boss_table() -> void:
	# `MINIBOSSES` and not `BOSSES`: two tables, and the sluice keeper is in the
	# second one. Reading the wrong one returned `{}` and failed this check with a
	# perfectly correct table underneath it.
	var row: Dictionary = BossDb.MINIBOSSES.get(&"sluice_keeper", {})
	var drop: Dictionary = row.get("drop", {})
	_ck("B0 the sluice keeper drops the maker's mark",
		StringName(drop.get("item", &"")) == StoryDb.SMITH_TOKEN)
	# The half of the miniboss rule that did NOT move: a miniboss still hands out
	# no verb and no relic, so floor 1 stays completable by somebody who walked
	# past it. See `BossDb`'s rule 2.
	_ck("B1 and no relic with it", StringName(drop.get("relic", &"")) == &"")
	_ck("B2 the mark is on the progress allow-list",
		BossDb.PROGRESS_TOKENS.has(StoryDb.SMITH_TOKEN))
	var problems := BossDb.validate()
	_ck("B3 the table validates (%s)" % [problems], problems.is_empty())


# --- C. The stores -------------------------------------------------------------

## The three lines that had to move when the smith went behind the miniboss.
const STOCK: Array[StringName] = [&"arrows", &"bag_slot", &"heart"]

func _stores() -> void:
	# With a bow in the pack, because `lines()` is the SHOP and arrows are gated on
	# owning something to fire them (`SupplyDb.GATED_BY`) exactly as they were at
	# the forge. Asking an empty save for the arrow row and failing when it is
	# absent is the instrument being wrong, not the shop -- and it read as "the
	# quartermaster does not stock arrows" for one run before this line existed.
	var had_bow := Game.has(&"bow")
	Game.grant(&"bow")
	var supply := {}
	for line: Dictionary in SupplyDb.lines():
		supply[StringName(line.get("id", &""))] = line
	if not had_bow:
		Game.items.erase(&"bow")
	for id: StringName in STOCK:
		_ck("C0 the quartermaster stocks %s" % id, supply.has(id))

	var forge := {}
	for line: Dictionary in ShopDb.lines():
		forge[StringName(line.get("id", &""))] = line
	for id: StringName in STOCK:
		_ck("C1 the forge no longer sells %s" % id, not forge.has(id))

	# **Same ids, same prices, same limits.** This is the check that stands
	# between the move and a save-file migration: `Game.upgrades` is keyed by these
	# ids, so a player who has bought two bag slots keeps them and buys the third
	# at the third price.
	_ck("C2 the bag still stops at four slots",
		int(SupplyDb.LIMITS.get(&"bag_slot", 0)) == 4)
	_ck("C3 and the heart track at three",
		int(SupplyDb.LIMITS.get(&"heart", 0)) == 3)
	_ck("C4 arrows are still gated on owning a bow",
		StringName(SupplyDb.GATED_BY.get(&"arrows", &"")) == &"bow")

	# And the counter itself: two on one person, which is the whole reason there
	# is no second `Npc` standing inside Kessa.
	var row: Dictionary = Npc.COUNTERS.get(Npc.Role.VENDOR, {})
	var counters: Array = row.get("counters", [])
	_ck("C5 the quartermaster has two counters (%d)" % counters.size(),
		counters.size() == 2)
	if counters.size() == 2:
		_ck("C6 she buys on the first and sells the stores on the second",
			int((counters[0] as Dictionary).get("mode", -1)) == TradeScreen.Mode.SELL
			and (counters[1] as Dictionary).get("db") == SupplyDb)


# --- D. The scene --------------------------------------------------------------

func _scene(rig) -> void:
	var garrison: Garrison = rig.scene()
	if garrison == null:
		_ck("D0 there is a garrison", false)
		return

	# `_do_the_rounds` waits 1.2 s behind the fade before it says anything.
	var opened: bool = await rig.until(func() -> bool: return rig.dialogue() != null, 8.0)
	_ck("D1 somebody is being introduced", opened)
	var box: Node = rig.dialogue()
	if box == null:
		return
	_ck("D2 the elder opens it (%s)" % box.speaker_name(),
		box.speaker_name() == DialogueDb.name_of(&"elder"))

	var cam := _convo(rig)
	_ck("D3 the conversation has taken the camera", cam != null)
	if cam == null:
		return
	await rig.until(func() -> bool: return cam.settled(), 3.0)
	var on_elder := _off_axis(cam, garrison.keeper)
	_ck("D4 and it is pointed at him (%.1f deg off)" % on_elder, on_elder < 6.0)
	var fill_elder := _fills(cam, garrison.keeper)
	_ck("D4b and he is big enough to look at (%.0f%% of the frame)"
		% (fill_elder * 100.0), fill_elder > 0.30)
	print("INTRO elder: %.1f deg off, %.0f%% tall, fov %.1f"
		% [on_elder, fill_elder * 100.0, cam.fov])
	await rig.capture(out.path_join("i_01_elder.png"))

	# Forward until Kessa answers. Tapped rather than waited out: the first press
	# only fills the line that is still typing, which is the same reason `voices`
	# B1e counts presses instead of assuming two.
	var turned := false
	for _i in 8:
		if rig.dialogue() == null:
			break
		if box.speaker == &"quartermaster":
			turned = true
			break
		await rig.tap(["interact"])
		await rig.wait_frames(2)
	_ck("D5 the quartermaster answers him", turned)
	if not turned:
		return
	_ck("D6 and the plate says so (%s)" % box.speaker_name(),
		box.speaker_name() == DialogueDb.name_of(&"quartermaster"))

	# **The claim this whole system exists to make.** Not "a tween ran" -- the
	# rendered frame is looking at the person now talking.
	await rig.until(func() -> bool: return cam.settled(), 3.0)
	var on_kessa := _off_axis(cam, garrison.vendor)
	_ck("D7 the camera panned onto her (%.1f deg off)" % on_kessa, on_kessa < 6.0)
	# **The null case for D7** (CLAUDE.md §2): the same measurement, pointed at the
	# man who is no longer talking. If Aldric is also in the middle of the frame,
	# `_off_axis` is not measuring anything and D7 passed for free.
	#
	# Bounded against the LENS and not against a fixed angle, because these two
	# happen to be nearly in line: from the spawn Aldric stands 2.9 m ahead and
	# Kessa 12.5 m beyond his left shoulder, so the whole turn between them is 13
	# degrees. What makes it a different shot is the FOV -- 52 down to 28 -- and
	# a quarter of the frame's height is the honest way to say "he is no longer
	# what this is a picture of". F5 is the same control over a real pan.
	var off_elder := _off_axis(cam, garrison.keeper)
	_ck("D8 and off him (%.1f deg off, was %.1f, on a %.1f deg lens)"
		% [off_elder, on_elder, cam.fov], off_elder > cam.fov * 0.25)
	var fill_kessa := _fills(cam, garrison.vendor)
	_ck("D7b and she is big enough to look at (%.0f%% of the frame)"
		% (fill_kessa * 100.0), fill_kessa > 0.30)
	print("INTRO kessa: %.1f deg off, %.0f%% tall, fov %.1f"
		% [on_kessa, fill_kessa * 100.0, cam.fov])
	print("INTRO eye %.2v | elder %.2v | kessa %.2v"
		% [cam.global_position, garrison.keeper.global_position,
			garrison.vendor.global_position])
	await rig.capture(out.path_join("i_02_quartermaster.png"))

	# --- E. Handing back -------------------------------------------------------
	for _i in 10:
		if rig.dialogue() == null:
			break
		await rig.tap(["interact"])
		await rig.wait_frames(2)
	await rig.wait_frames(4)
	_ck("E0 the scene ends", rig.dialogue() == null)
	_ck("E1 the camera goes back to the game's", _convo(rig) == null)
	_ck("E2 and the save has met her",
		Game.flag(StoryDb.intro_flag(&"quartermaster")))
	# Once per save: the yard is entered four or five times an hour.
	_ck("E3 so nobody is owed one now", StoryDb.pending_introduction() == &"")
	await rig.capture(out.path_join("i_03_handed_back.png"))


# --- F. The long pan -----------------------------------------------------------

## Brannoc, on purpose. Kessa stands 55 degrees off the arrival axis at about 7 m;
## the forge is on the far side of the ring, and the hearth reaches 11 m from the
## middle of the plaza. That distance is what broke a fixed lens -- at 50 degrees
## he is a ninth of the frame height with a dialogue box under him -- and it is
## the case `ConvoCamera._want_fov` was written for.
func _long_pan(rig) -> void:
	var garrison: Garrison = rig.scene()
	if garrison == null or garrison.smith == null:
		_ck("F0 the smith is in the yard", false)
		return

	Introduction.play(garrison, &"smith")
	var opened: bool = await rig.until(func() -> bool: return rig.dialogue() != null, 4.0)
	_ck("F1 Brannoc is introduced", opened)
	var box: Node = rig.dialogue()
	var cam := _convo(rig)
	if box == null or cam == null:
		_ck("F2 with a camera on it", false)
		return

	for _i in 8:
		if rig.dialogue() == null:
			break
		if box.speaker == &"smith":
			break
		await rig.tap(["interact"])
		await rig.wait_frames(2)
	_ck("F2 the smith answers", box.speaker == &"smith")
	await rig.until(func() -> bool: return cam.settled(), 3.0)

	var off := _off_axis(cam, garrison.smith)
	var dist := cam.global_position.distance_to(garrison.smith.global_position)
	print("INTRO eye %.2v -> smith %.2v (crown %.2f), settled=%s"
		% [cam.global_position, garrison.smith.global_position,
			garrison.smith.head_y(), cam.settled()])
	_ck("F3 the camera reaches him (%.1f deg off, %.1f m away)" % [off, dist],
		off < 6.0)
	# The lens is what makes that distance readable, and the clamp is what stops it
	# becoming a telescope. If this ever reads exactly `FOV_MIN` for the near
	# speaker too, the solve has stopped doing anything.
	_ck("F4 and narrowed for the distance (fov %.1f)" % cam.fov,
		cam.fov < 45.0 and cam.fov >= ConvoCamera.FOV_MIN)
	var fill_smith := _fills(cam, garrison.smith)
	_ck("F4b and he is big enough to look at (%.0f%% of the frame)"
		% (fill_smith * 100.0), fill_smith > 0.30)
	print("INTRO smith: %.1f deg off, %.1f m away, %.0f%% tall, fov %.1f"
		% [off, dist, fill_smith * 100.0, cam.fov])
	await rig.capture(out.path_join("i_04_smith.png"))

	# **The null case** (CLAUDE.md §2). Every number above is an angle this
	# director computes itself, so it can be wrong in the flattering direction as
	# easily as the honest one. Point the same measurement at somebody the camera
	# is NOT looking at: if that also comes out under six degrees, the instrument
	# is measuring nothing.
	var control := _off_axis(cam, garrison.keeper)
	_ck("F5 control: the elder is NOT in the middle of it (%.1f deg off)" % control,
		control > 20.0)

	for _i in 10:
		if rig.dialogue() == null:
			break
		await rig.tap(["interact"])
		await rig.wait_frames(2)


# --- The instruments -----------------------------------------------------------

## The live `ConvoCamera`, or null. Found off the viewport rather than by name:
## the claim is about which camera is RENDERING, and a staged-but-not-current
## camera would pass a search of the tree.
func _convo(rig) -> ConvoCamera:
	var scene: Node = rig.scene()
	if scene == null:
		return null
	var vp := scene.get_viewport()
	if vp == null:
		return null
	return vp.get_camera_3d() as ConvoCamera


## Degrees between where the camera is pointing and the line from it to `who`'s
## head. The whole verdict of D and F, and it is deliberately a fact about the
## rendered transform: it reads `global_transform` after the frame that produced
## the capture, and knows nothing about tweens, targets or intent.
## How much of the frame's HEIGHT the speaker's body takes up, 0..1.
##
## The check the angle cannot make. `_off_axis` says the camera is pointed at
## somebody; it says nothing at all about whether you can see them, and the first
## frame this director shot had Kessa dead centre at 0.0 degrees and about a
## sixth of the frame tall -- a correctly aimed picture of a distant smudge. The
## owner's ask was "so you can see", and this is the number that says it.
##
## Projected through the camera that rendered it (`unproject_position`), so it is
## a fact about the pixels and not about `_want_fov`'s arithmetic.
func _fills(cam: Camera3D, who: Npc) -> float:
	if cam == null or who == null:
		return 0.0
	var feet := cam.unproject_position(who.global_position)
	var crown := cam.unproject_position(
		who.global_position + Vector3.UP * who.head_y())
	var h := float(cam.get_viewport().get_visible_rect().size.y)
	if h <= 0.0:
		return 0.0
	return absf(feet.y - crown.y) / h


func _off_axis(cam: Camera3D, who: Npc) -> float:
	if cam == null or who == null:
		return 999.0
	var head := who.global_position + Vector3.UP * who.head_y()
	var to := head - cam.global_position
	if to.length() < 0.01:
		return 999.0
	return rad_to_deg((-cam.global_transform.basis.z).angle_to(to))
