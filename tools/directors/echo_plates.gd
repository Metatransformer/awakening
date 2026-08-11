extends RefCounted
## Card #26 — **an Echo's name stops at the first wall.**
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/echo_plates.gd \
##     --out=/tmp/plates/x.png --warmup=60
##
## `SoundingStone._raise` hangs a `Label3D` under each of its three tones. Those
## labels shipped with `no_depth_test = true`, which is not "draw on top of the
## stone" — it is *draw on top of the entire world*. The three names on the
## landing behind a shut shortcut door were legible through the door, painted on
## it in cyan, from a room the player had not opened yet.
##
## What it claims, in the order it proves them:
##
##   A  Floor 1's shortcut door is shut, and a sounding stone stands on the
##      landing behind it, offering three named Echoes.
##   B  Standing in front of the SHUT door, with all three plates squarely
##      inside the frame and in front of the camera: with `no_depth_test` put
##      back the names paint the door in cyan — and as the game now builds them,
##      **not one of their pixels reaches the picture.** Both frames are kept.
##   C  The eye is shot and the door swings. Photographed from the same spot,
##      for the record.
##   D  Through that open door, at the stone, all three names are on the
##      picture.
##   E  And from a lookdev lens with nothing in shot but the plinth, every
##      caption is whole — NOT swallowed by the drum it stands on. That is the
##      half a bare `no_depth_test = false` could get wrong, and it is why this
##      file measures pixels rather than asserting a flag.
##
## ## Why this diffs frames instead of reading `visible`
##
## Every property involved here is true in both the broken and the fixed build:
## the plate is `visible`, it is in the tree, its text is right, and its
## `global_position` never moves. The only thing that changes is *what reaches
## the frame*, so that is what is measured.
##
## It is measured by **taking the plates away**: freeze the clock, photograph the
## pose, hide the three labels, photograph it again, and count the pixels that
## moved. That number is exactly the plates' contribution to the picture — zero
## when the door swallows them, hundreds when it does not — and unlike a colour
## match it cannot be fooled by the door's own green sigil sitting a few pixels
## above the captions, nor defeated by a caption thirteen metres away whose ink
## comes out of the downscale as a dim smear rather than as `Pal.CYAN`. The first
## cut of this file matched on the colour and scored a frame with the names
## plainly painted on the door at **zero**.
##
## `Engine.time_scale = 0` is what makes the pair comparable: the torches gutter,
## the stone's lamp swells and the motes bob, so two consecutive captures of a
## running scene differ everywhere. Frozen, the world differs only where the
## labels were — **but the HUD is not frozen**, because it runs off the wall
## clock, so the diff is counted inside a box round each plate rather than over
## the whole picture. Without that box a caption scored nineteen thousand pixels
## on the strength of a vitals bar ticking between the pair.

## Floor 1's layout, shared with `shortcut_puzzle.gd` and `cistern_floor.gd` so
## the three directors are describing one floor and not three.
const SEED := 20260809

## Where the hero stands to read a door — `shortcut_puzzle.gd`'s own constant,
## and for its reason: inside `LockedDoor`'s 2.9 m interact radius, far enough
## back that the leaves and what is behind them share the frame.
const READ_AT := 2.5

## How far a channel has to move for a pixel to count as "the plate was here".
## The two captures are the same frozen frame with one node hidden, so anything
## the labels touch moves far more than this and everything else moves not at
## all; the window only absorbs the last bit of the Lanczos downscale.
const INK_DELTA := 0.02

## Half-extents, in 1280x720 pixels, of the box drawn round each plate's
## projected centre. The diff is counted inside these and nowhere else — a plate
## outside its own box is not the thing under test, and the HUD (which runs off
## the wall clock and so is NOT frozen with the rest of the world) is never
## inside one. A name is about 0.8 m of world at `pixel_size` 0.0019, which is
## roughly 150 px across from where the hero reads the stone and a tenth of that
## through the doorway, so the box is generous sideways and tight vertically.
const BOX := Vector2i(110, 34)

## What counts as "the name is on screen at all". A caption thirteen metres away,
## seen through a doorway, is about thirty pixels of glyph and its outline; the
## same caption at the stone is several hundred. This is the floor for the far
## one, and `READABLE_NEAR` is the floor for the near one.
const READABLE := 30
const READABLE_NEAR := 400

## How far off the pedestal's axis the hero stands to be photographed reading it.
##
## Dead ahead, the hero's own body is between the camera and the MIDDLE tone --
## measured, at 26 pixels against its neighbours' 365 and 270 -- because the
## three names hang at 0.82 m, which is his chest. That is correct occlusion and
## not a bug: a body in the world hides what is behind it, and the version of
## this that did not was the version that also painted the names on a shut door.
## It is a framing fact, so it is fixed in the framing, exactly as
## `puzzle_loop.gd` steps off the treasure chest's axis for the same reason.
##
## Negative, i.e. toward the stone's own -X, and SMALL. The placer stands the
## pedestal 3 m off the centre line of a 9 m landing with the stair in the middle
## of it, so this is a narrow lane: step 2.4 m the other way and the camera boom
## ends up inside the side wall (the frame becomes the back of the hero's head);
## step 2.4 m this way and he is stood on the stair. 1.2 m clears the middle
## caption and keeps his feet on the floor.
const SIDESTEP := -1.2

## How far in front of the plinth the lookdev lens sits, and the two numbers off
## `SoundingStone` it aims at. Spelled out rather than read off the class: this
## file is loaded with `-s`, and a `preload` of a script that names an autoload
## takes the whole harness down before the autoloads exist (`CLAUDE.md` §3).
const LOOKDEV_AT := 3.2
const MOTE_Y := 1.16
const PLATE_DROP := 0.34

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/plates/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if rig.scene().name != &"DungeonRun":
		print("PLATES FAIL wrong host scene (%s) -- pass "
			% rig.scene().name
			+ "--scene=res://scenes/rooms/dungeon.tscn")
		return

	Game.reset()
	Run.enter(SEED)
	# The bow, because the door in front of the landing is opened by an arrow and
	# beat C has to get through it. Granted rather than won: the Warden's
	# hand-over is `shortcut_puzzle.gd`'s claim, not this one.
	Game.grant(&"bow")

	var d := await _rebuild(rig, 1)
	if d == null:
		print("PLATES FAIL the dungeon did not build")
		return
	var hero: Node3D = _hero(rig)
	var cam := _game_camera(rig)
	if hero == null or cam == null:
		print("PLATES FAIL no hero or no GameCamera in the scene")
		return
	cam.make_current()
	_clear_the_floor(d)
	await rig.wait_frames(20)

	var door: Node3D = d.anchor_node(&"shortcut_door")
	_ck("A0 floor 1 has a shortcut door", door != null)
	if door == null:
		return
	_ck("A1 and it is shut", not bool(door.call(&"is_open")))

	var stone: Node3D = _stone_with(d, &"shortcut")
	_ck("A2 a sounding stone stands on the landing behind it", stone != null)
	if stone == null:
		return
	# Offered BY HAND, with the door shut. The placer wires `offer()` to the
	# door's `opened`, which is the honest lifetime -- and it also means the only
	# way to photograph "names behind a shut door" is to ask for them. The bug is
	# not about when the stone lights; it is about what a lit stone paints on.
	stone.call(&"offer")
	await rig.wait_frames(12)
	var plates := _plates_under(stone)
	print("PLATES stone offers %s -- %d plate(s)"
		% [stone.call(&"offered"), plates.size()])
	_ck("A3 and it is offering three named tones (%d)" % plates.size(),
		plates.size() == 3)
	if plates.is_empty():
		return

	# --- B. Shut -------------------------------------------------------------
	await _stand_at(rig, hero, door)

	# **The control, and it is the bug itself.** A "0 pixels" that came from a
	# caption thirteen metres away being too small to survive the downscale would
	# read exactly like a caption the door had hidden, and that is a way for this
	# whole file to pass while proving nothing. So the pose is photographed twice:
	# once with `no_depth_test` forced back ON -- the setting this card is about --
	# and once as the game now builds it. The first frame is kept. It is what the
	# defect looked like, from the spot a player stands in, and it is the reason
	# the second frame's zero means something.
	for p: Node3D in plates:
		p.no_depth_test = true
	await rig.wait_frames(4)
	var leak := await _read(rig, cam, plates,
		out.path_join("e_01_door_shut_no_depth_test.png"))
	for p: Node3D in plates:
		p.no_depth_test = false
	await rig.wait_frames(4)
	_ck("B0 the three plates are on screen and in front of the camera",
		leak["framed"] == plates.size())
	print("PLATES door SHUT, no_depth_test ON -> %d pixel(s) of plate"
		% leak["ink"])
	_ck("B1 and with `no_depth_test` they paint the shut door (%d px)"
		% leak["ink"], leak["ink"] >= READABLE)

	var shut := await _read(rig, cam, plates,
		out.path_join("e_02_door_shut.png"))
	print("PLATES door SHUT -> %d pixel(s) of plate in the frame" % shut["ink"])
	_ck("B2 as the game builds them, NOT ONE of their pixels reaches the "
		+ "frame (%d)" % shut["ink"], shut["ink"] == 0)

	# --- C. Through the door -------------------------------------------------
	var eye: Node = _named(d, "ShortcutEye")
	_ck("C0 the door's eye is in the room", eye != null)
	if eye != null:
		# The atom's own entry point. `shortcut_puzzle.gd` owns the claim that a
		# real arrow reaches it; re-firing one here would give this file a way to
		# fail for a reason that has nothing to do with a label.
		eye.call(&"apply_hit", null)
	var swung: bool = await rig.until(func() -> bool:
		return bool(door.call(&"is_open")), 5.0)
	_ck("C1 shooting it opened the door", swung)
	await rig.wait_frames(40)

	# The same spot as beat B, with the door swung. Kept for the record and NOT
	# measured: the mouth behind the leaves is a four-metre stub with walls of its
	# own, and the stone stands three metres off its centre line, so from out here
	# the aperture shows a torch and a slice of floor and the stone is round the
	# corner of it whatever the labels do. Asserting anything about ink in this
	# frame would be asserting a fact about the landing's shape. Beat D is where
	# the names have to be legible, and it is shot through this open door.
	await _stand_at(rig, hero, door)
	await rig.capture(out.path_join("e_03_door_open.png"))

	# --- D. At the stone -----------------------------------------------------
	# The half a plain revert would get wrong. A caption that stops at the first
	# wall is no use if its own plinth is the first wall.
	await _stand_in_front(rig, hero, stone, 5.0, SIDESTEP)
	var near := await _read(rig, cam, plates,
		out.path_join("e_04_at_the_stone.png"), true)
	print("PLATES at the stone -> %d pixel(s), %s per plate"
		% [near["ink"], near["per"]])
	_ck("D0 all three plates are in frame at the stone",
		near["framed"] == plates.size())
	_ck("D1 and the names are on the picture (%d px, >= %d)"
		% [near["ink"], READABLE_NEAR], near["ink"] >= READABLE_NEAR)
	# The per-plate numbers, PRINTED AND NOT ASSERTED. Beat E is where "none of
	# the three is swallowed by the drum" is claimed, and it is the only place it
	# can be: this pose has the hero between the camera and the row, and what the
	# left-hand plate is behind is **his bow**, not the plinth.
	#
	# There used to be a check here with a floor of `READABLE_NEAR / 4`. It is
	# gone rather than retuned, because retuning it would have been retuning a
	# measurement of an idle animation. Three identical runs of this file, same
	# seed, same pose, same code, gave the left plate **128, 19 and 108** pixels
	# while the total stayed at 1580, 1495 and 1583 — the hero's idle breathes,
	# `Engine.time_scale = 0` freezes it wherever the frame budget happened to
	# leave it, and some of those frames have a bow limb across the caption. The
	# file's own `SIDESTEP` note already records this exact fact about the MIDDLE
	# plate ("that is correct occlusion and not a bug"); it was true of the left
	# one too and the check had simply been lucky.
	#
	# Card #38 is what surfaced it: lighting the entrance room changed the
	# background these counts are diffed against, which moved every near number and
	# put the left plate on the wrong side of a threshold nothing had justified.
	# The claim itself survives intact one beat down, at [2649, 2781, 1912].
	print("PLATES per-plate at the stone: %s (printed, not asserted -- see the "
		% [near["per"]] + "note here; beat E is where the drum is judged)")

	# --- E. The plate at its own prop ----------------------------------------
	# The landing is a nine-metre room with a stair down the middle of it, so the
	# game camera can only ever see this pedestal past the hero and over the
	# stair. That is a fine picture of arriving and a poor one for the question
	# this card actually asks -- *is the caption readable at the stone, or has
	# depth testing handed it to the drum?* -- so it is asked again from a plain
	# lookdev camera set in front of the plinth, the way `monster_lookdev.gd`
	# asks about a body. Nothing but the stone is in this frame, so the per-plate
	# numbers under it are the drum's verdict and no one else's.
	var lens := Camera3D.new()
	lens.name = "PlateLookdev"
	rig.scene().add_child(lens)
	var fwd := -stone.global_transform.basis.z
	lens.global_position = stone.global_position + fwd * LOOKDEV_AT \
		+ Vector3(0.0, 1.15, 0.0)
	lens.look_at(stone.global_position + Vector3(0.0, MOTE_Y - PLATE_DROP, 0.0))
	lens.make_current()
	await rig.wait_frames(12)
	var lookdev := await _read(rig, lens, plates,
		out.path_join("e_05_plate_lookdev.png"), true)
	print("PLATES lookdev -> %d pixel(s), %s per plate"
		% [lookdev["ink"], lookdev["per"]])
	_ck("E0 all three plates are in frame at the plinth",
		lookdev["framed"] == plates.size())
	var eaten := 0
	for n: int in lookdev["per"]:
		if n < READABLE_NEAR:
			eaten += 1
	_ck("E1 and with nothing but the stone in shot, every caption is whole "
		+ "(%s)" % [lookdev["per"]], eaten == 0)
	lens.queue_free()
	cam.make_current()
	await rig.wait_frames(6)

	if _fails == 0:
		print("PLATES ok -- every check passed")
	else:
		print("PLATES FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("PLATES ok %s" % label)
	else:
		_fails += 1
		print("PLATES FAIL %s" % label)


# --- The measurement ----------------------------------------------------------

## Capture to `path` — the frame a human looks at — and return how many of its
## pixels the three name plates actually put there.
##
## `per` is the same number one plate at a time, so "two captions carried the
## count while the third sat inside the drum" cannot pass. The reference frames
## are written next to `path` and deleted: they exist only to be subtracted, and
## a directory of near-identical PNGs is a directory nobody looks at.
func _read(rig, cam: Camera3D, plates: Array, path: String,
		want_per: bool = false) -> Dictionary:
	# Frozen, or the torches alone would differ between the pair. Restored in
	# every exit from this function -- a director that leaves `time_scale` at
	# zero hangs every beat after it, on the game clock, for ever.
	var prev := Engine.time_scale
	Engine.time_scale = 0.0
	await rig.wait_frames(2)
	await rig.capture(path)
	var lit := Image.load_from_file(path)
	if lit == null:
		Engine.time_scale = prev
		print("PLATES could not re-read %s" % path)
		return {"ink": -1, "framed": 0, "per": []}

	# Where each plate lands on the picture. The count is taken INSIDE these boxes
	# and nowhere else. `Engine.time_scale` freezes the world but not the HUD,
	# which runs off the wall clock -- a whole-frame diff scored a caption at
	# nineteen thousand pixels because a vitals bar had ticked between the pair.
	var view: Vector2 = cam.get_viewport().get_visible_rect().size
	var scale := Vector2(lit.get_size()) / view
	var boxes: Array[Rect2i] = []
	var framed := 0
	for p: Node3D in plates:
		if cam.is_position_behind(p.global_position):
			boxes.append(Rect2i())
			continue
		var at := Vector2i(cam.unproject_position(p.global_position) * scale)
		var box := Rect2i(at - BOX, BOX * 2)
		# Half a plate off the edge of the picture is not evidence either way, and
		# silently counting the half that is left would let a beat pass on a badly
		# framed shot. Framing is asked of the CAMERA, not of the picture: a plate
		# that scored zero because it was behind the hero would otherwise read as
		# a plate the door correctly hid.
		if not Rect2i(Vector2i.ZERO, lit.get_size()).encloses(box):
			boxes.append(Rect2i())
			continue
		boxes.append(box)
		framed += 1

	var total := await _moved(rig, lit, plates, path, plates, boxes)
	var per: Array[int] = []
	if want_per:
		for i in plates.size():
			per.append(await _moved(rig, lit, [plates[i]], path, plates,
				[boxes[i]]))
	Engine.time_scale = prev
	await rig.wait_frames(2)
	return {"ink": total, "framed": framed, "per": per}


## Hide `hide_these`, re-photograph the frozen pose, and count the pixels inside
## `boxes` that changed against `lit`. `all` is restored visible afterwards,
## whichever subset was taken away.
func _moved(rig, lit: Image, hide_these: Array, path: String,
		all: Array, boxes: Array) -> int:
	for p: Node3D in hide_these:
		p.visible = false
	await rig.wait_frames(2)
	var ref := path.get_basename() + ".ref.png"
	await rig.capture(ref)
	var bare := Image.load_from_file(ref)
	DirAccess.remove_absolute(ref)
	for p: Node3D in all:
		p.visible = true
	await rig.wait_frames(2)
	if bare == null or bare.get_size() != lit.get_size():
		return -1
	var n := 0
	for box: Rect2i in boxes:
		if box.size == Vector2i.ZERO:
			continue
		for y in range(box.position.y, box.end.y):
			for x in range(box.position.x, box.end.x):
				var a := lit.get_pixel(x, y)
				var b := bare.get_pixel(x, y)
				if absf(a.r - b.r) > INK_DELTA or absf(a.g - b.g) > INK_DELTA \
						or absf(a.b - b.b) > INK_DELTA:
					n += 1
	return n


# --- Fixture ------------------------------------------------------------------

func _rebuild(rig, level: int) -> Node:
	Run.level = level
	var scene: Node = rig.scene()
	var old := scene.get_node_or_null(^"Dungeon")
	if old != null:
		old.name = "DungeonOld"
		old.queue_free()
		await rig.wait_frames(2)
	var script := load("res://scripts/world/dungeon.gd") as GDScript
	var d: Node = script.new()
	d.name = "Dungeon"
	d.seed_override = SEED
	scene.add_child(d)
	await rig.wait_frames(12)
	return d


func _clear_the_floor(d: Node) -> void:
	var freed := 0
	for e in _every(d, func(n: Node) -> bool: return n is Enemy):
		freed += 1
		e.queue_free()
	print("PLATES cleared %d bodies" % freed)
	_still_the_flames(d)


## Hold every flame at its nominal energy, because `Engine.time_scale = 0` does
## not.
##
## The note above `_read` says the freeze is *"what makes the pair comparable"* —
## and it is, for everything that moves on the game clock. `KitTorch._process`
## does not: it swings `light_energy` by ±16% off `Time.get_ticks_msec()`, the
## **wall** clock, which keeps running while the world is stopped. So the two
## captures of a "frozen" pose differ wherever a torch reaches, and the diff picks
## that up as ink.
##
## It was invisible until card #38 and only because of what card #38 was about:
## the boxes here land on the shut shortcut door, and that door stood in a room
## with no sconces in it. On near-black masonry a 16% swing is under `INK_DELTA`.
## The moment the entrance room got the fire it should always have had, the same
## boxes covered lit stone, the same swing cleared the threshold, and **B2 failed
## at 93 px with no name anywhere on the door** — the frame is
## `/tmp/lit_after/plates/e_02_door_shut.png` and there is not a cyan pixel in it.
## A measurement that reports a leak because a fire flickered is a measurement
## that will one day report no leak for an equally bad reason.
func _still_the_flames(d: Node) -> void:
	var n := 0
	for t in _every(d, func(x: Node) -> bool: return x is KitTorch):
		t.flicker = 0.0
		# The setter runs `_apply_light`, which is the only thing that puts the
		# nominal energy back after `_process` has been multiplying it.
		t.light_energy = t.light_energy
		n += 1
	print("PLATES held %d flame(s) still -- time_scale does not stop them" % n)


## Out along the door's own `+basis.z`, which is the side the player stands on
## (`docs/CONTRACT.md` §2.5).
func _stand_at(rig, hero: Node3D, door: Node3D, back: float = READ_AT) -> void:
	hero.velocity = Vector3.ZERO
	hero.global_position = door.global_position \
		+ door.global_transform.basis.z * back + Vector3(0.0, 0.15, 0.0)
	await _look_at(rig, hero, door)


## Out along a PROP's own forward (`-basis.z`), which is the opposite convention
## and the right one for anything that is aimed at the player rather than showing
## it a pair of leaves. Standing a hero on the wrong one of these puts the camera
## inside masonry -- `puzzle_loop.gd` has the same pair of helpers for the same
## reason.
func _stand_in_front(rig, hero: Node3D, at: Node3D, back: float,
		side: float = 0.0) -> void:
	hero.velocity = Vector3.ZERO
	hero.global_position = at.global_position \
		- at.global_transform.basis.z * back \
		+ at.global_transform.basis.x * side + Vector3(0.0, 0.15, 0.0)
	await _look_at(rig, hero, at)


func _look_at(rig, hero: Node3D, at: Node3D) -> void:
	var to := K.flat(at.global_position - hero.global_position)
	if to != Vector3.ZERO:
		hero.facing_yaw = atan2(to.x, to.z)
		hero.rotation.y = hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(6)
	await rig.wait_frames(24)


func _stone_with(d: Node, id: StringName) -> Node3D:
	for n in _every(d, func(x: Node) -> bool:
			return x.is_in_group(&"sounding_stone") and x.get(&"stone_id") == id):
		return n
	return null


func _plates_under(stone: Node) -> Array:
	var found: Array = []
	for n in _every(stone, func(x: Node) -> bool: return x is Label3D):
		found.append(n)
	return found


func _named(d: Node, what: String) -> Node:
	for n in _every(d, func(x: Node) -> bool: return x.name == what):
		return n
	return null


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _game_camera(rig) -> Camera3D:
	for n in _all(rig.scene()):
		if n is GameCamera:
			return n
	return null


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found


func _every(root: Node, pred: Callable) -> Array:
	var found: Array = []
	for n in _all(root):
		if pred.call(n):
			found.append(n)
	return found
