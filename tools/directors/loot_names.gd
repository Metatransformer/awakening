extends RefCounted
## Card #123 — **a dropped mote says what it is, at the game camera, and stops
## at the first wall.**
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/loot_names.gd \
##     --out=/tmp/loot/x.png --warmup=60
##
## Add `--internal=1` to run the same beats through STYLEGUIDE §4.5's 480x270
## buffer, which is where card #61's defect lived. See `run`.
##
## The owner's playtest: *"we should show the name of items when they fall on the
## ground."* `LootMote` now hangs a `WorldCaption` off itself inside
## `LootMote.NAME_RANGE`, three at a time, nearest first. Three cards have
## already been paid for on this exact surface and this file is what says none of
## them has come back:
##
##   #26 / #37  a world label painted through the wall it was behind
##   #61        a `Label3D` through §4.5's 480x270 buffer, ~5 px of type
##   #68        three captions in one place drawn through each other
##
## ## Every frame here is the GAME camera, and that is the point
##
## `world_labels.gd` builds its own `Camera3D` and stands it at a chosen
## distance, which is the right instrument for *is this caption legible at
## reading range*. It is the wrong one for this card. A mote is read while you
## are running at it with the OoT boom behind your shoulder — 2.48–4.13 m back
## and 5° up (`K.CAM_DIST_MIN`/`MAX`, `K.CAM_PITCH`) — so the caption is 6-8 m
## from the lens and near the middle of the frame with a hero in front of it.
## That is the picture the claim is about, so no lens is built: the hero is
## walked to the drop and `recenter()` is what aims the shot.
##
## ## What it measures, and why it is bands and not a pixel count
##
## Ink is a count of PRESENCE, which card #61 established cannot see legibility
## — and card #68's defect is invisible to it twice over, because three captions
## drawn through each other put *more* ink on the frame than three drawn apart.
##
## So the caption pixels are found the way `echo_plates.gd` and
## `world_labels.gd` find them (freeze the world, photograph, take the captions
## away, photograph again, diff) and then **projected onto y and cut into
## bands** — runs of scanlines that carry ink, separated by scanlines that carry
## none. Three captions laid out on three rows are three bands about 26 px tall
## (14 px of type plus §5.7's 6 px plate pad top and bottom). Three captions
## drawn through each other are ONE band about 26 px tall, or two, and the beat
## fails naming what it got. The band's height, less the plate, is the cap
## height card #61's floor is written in.
##
## ## The two controls, because a director that has never been pointed at a
## ## known answer has never been tested
##
##  * **A null case** (beat 0). Two captures of the same frozen frame with
##    nothing touched at all must differ by zero pixels. Without it every
##    non-zero reading below could be the fog crawl or a torch (CLAUDE.md §3,
##    card #62) rather than a caption, and this file would be measuring the
##    harness. `rig.still_the_frame()` is what makes it zero.
##  * **The defect itself** (beat C1). The occluded frame's zero is worthless on
##    its own — a caption the range gate had already switched off would read
##    exactly the same. So the same pose is shot twice from one spot, once with
##    `WorldCaption.occlude = false`, and the first frame is kept. It is what
##    the bug looked like and it is the reason the second frame's zero means
##    something.

## Where the run starts, so a floor is generated and drops are real.
const SEED := 4242

## How far a channel has to move for a pixel to count as caption ink. Same
## number `world_labels.gd` and `echo_plates.gd` use, and beat 0 is what says it
## is not absorbing a real signal.
const INK_DELTA := 0.02

## §3.1b's floor, in reference px at 720p. A `WorldCaption` is drawn on the HUD
## canvas after §4.5's present pass, so a frame pixel IS a rasterised pixel and
## there is no buffer divisor here the way there is in `world_labels._raster_h`.
## That is the whole of what card #61 bought.
const CAP_MIN_PX := 10.0

## §5.7's World plate pad, top and bottom, taken off a band before it is read as
## a cap height.
const PLATE_PAD_PX := 6.0

## A band this much taller than one row is two rows that merged — card #68's
## defect, arriving as a measurement rather than as an eyeball. One row is
## `ref_px` 14 + 2 x 6 px of plate = 26 px at 720p; two merged rows are 53.
const ROW_MAX_PX := 40.0

## Scanlines carrying fewer ink pixels than this are treated as blank when the
## bands are cut. Not zero: the plate is VOID at 72% over a dark dungeon floor,
## so its own top and bottom edges can move a single pixel by less than
## `INK_DELTA` and leave a stray behind.
const BAND_FLOOR := 2

## What counts as "the name reached the picture at all", in pixels. A 14 px
## caption with a plate is thousands; this is a floor and deliberately a loose
## one, and the number actually measured is printed either way.
const READABLE := 200

## Half-extents of the window every count is taken inside, in frame px at 720p.
## Generous downward, because the de-collide pushes captions DOWN and a pile-up
## reaches three rows below its own anchor.
const BOX_HALF := Vector2i(230, 110)

## Metres. Where the hero stands to read a drop, and where he stands to prove it
## has gone. `LootMote.NAME_RANGE` is 4.5 with a 1.2 m fade, so 2.6 m is well
## inside and 7.0 m is well past the far edge of the fade.
const READ_AT := 2.6
const AWAY_AT := 7.0

## The pile-up. Five, which is what card #123 asks for, inside a radius a single
## kill's fling actually scatters over.
const PILE := 5
const PILE_R := 0.55

var out := ""
var _fails := 0
var _muted: Array[Node3D] = []
var _refs: Array[String] = []
## Is the subtract-and-diff worth believing in this run? See `_measured`.
var _pixels := true


func run(rig) -> void:
	out = rig.arg("out", "/tmp/loot/x.png").get_base_dir()

	var scene: Node3D = rig.scene() as Node3D
	if scene == null or scene.name != &"DungeonRun":
		print("LOOTNAME FAIL wrong host scene (%s) -- pass "
			% (scene.name if scene else "<none>")
			+ "--scene=res://scenes/rooms/dungeon.tscn")
		return
	await rig.wait_frames(30)
	if not Run.in_dungeon:
		# Booting the scene directly never calls Run.enter(), which leaves the
		# bag stale and `Run.collect` refusing — and a mote that cannot be picked
		# up is not the object this card is about.
		Run.enter(SEED)
		await rig.wait_frames(10)

	var hero: Node3D = _hero(rig)
	if hero == null:
		print("LOOTNAME FAIL no hero in the scene")
		return

	# **`--internal` turns §4.5's 480x270 pipeline on, and this file is one of
	# the places that has to be run both ways.** `Settings.internal_render`
	# defaults to FALSE — card #58 shipped it on for a day and the owner turned
	# it off on 2026-08-11 — so a plain run judges these captions at the
	# window's own resolution. That is the shipped pipeline and it is the right
	# default here, but it is also the LAXER of the two, and card #61 is the
	# card about a caption that was fine at native and mush in the buffer. A
	# `WorldCaption` is drawn on the HUD canvas after the present pass and so
	# should not care either way; "should not" is not a measurement, and this
	# flag is how the claim gets one. `frame_repro`, `fog_crawl`, `internal_res`
	# and `msaa_clamp` each turn it on the same way.
	if rig.arg("internal", "") != "":
		Settings.set_internal_render(true)
		await rig.wait_frames(10)
	_pixels = not Settings.internal_render
	print("LOOTNAME internal_render is %s (STYLEGUIDE §4.5; pass --internal=1 "
		% ("ON" if Settings.internal_render else "OFF")
		+ "to judge these captions through the 480x270 buffer)")
	if not _pixels:
		# **Measured, on the run that produced this line: hiding one caption
		# under §4.5 changed 43,100 pixels of the frame, edge to edge, on a
		# world that was frozen and un-reprojected.** That is not the caption --
		# it is CLAUDE.md §3's quantizer row arriving. The internal buffer is
		# RGB555, one step is 8/255, and `INK_DELTA` is 5/255, so ANY sub-LSB
		# wobble anywhere in the picture crosses a step and reads as ink. The
		# same beat measures 26 px bands at native.
		#
		# So under this flag the pixel beats are REPORTED and not asserted. The
		# alternative is a threshold wide enough to swallow a whole frame of
		# dither, which is a threshold that would swallow a caption too, and a
		# green run that means nothing is worse than an amber one that says
		# what it could not check. What this flag is FOR is the picture: a
		# `WorldCaption` is drawn on the HUD canvas after the present pass, so
		# it should be the one thing in the frame the buffer never touched --
		# open `n_01_in_the_open.png` from a `--internal=1` run next to one
		# from a plain run and the type is identical while the masonry is not.
		# The state beats (who is named, how many, which three) are asserted in
		# both runs, because they are not made of pixels.
		print("LOOTNAME §4.5 is on, so the subtractive diff is REPORTED and "
			+ "NOT asserted this run -- see the note in `run`. Look at the "
			+ "frames; the state checks still fail on their own.")

	# The pair below is a pixel diff, so the frame has to be reproducible.
	# `Engine.time_scale = 0` alone is not enough: the torches swing and the
	# volumetric fog is temporally reprojected with a jitter that never
	# converges (CLAUDE.md §3, card #62). Beat 0 is what proves this took.
	rig.still_the_frame()
	await rig.wait_frames(6)

	await _null_case(rig, hero)
	await _kill_a_pack(rig, hero)
	var floor_spot: Vector3 = await _read_them(rig, hero)
	# The pile BEFORE the wall, and the order is load-bearing. `_behind_a_wall`
	# leaves the hero a stride from masonry facing it, and a pile dropped three
	# metres in front of him from there lands inside the wall -- correctly
	# occluded, and photographing nothing. It is also why that beat sweeps the
	# floor first: a leftover caption inside its measurement box is ink the
	# zero it is looking for cannot survive.
	await _pile_up(rig, hero, floor_spot)
	await _behind_a_wall(rig, hero)

	# The reference frames exist only to be subtracted, and a directory of
	# near-identical PNGs is one nobody looks at -- so a clean run throws them
	# away. A run that FAILED keeps them, because the first hypothesis about an
	# alarming number here is this file (CLAUDE.md §2) and the pair is the only
	# thing that can settle it.
	if _fails == 0:
		for r: String in _refs:
			DirAccess.remove_absolute(r)
		print("LOOTNAME ok -- every check passed")
	else:
		print("LOOTNAME kept %d reference frame(s) beside the pictures -- the "
			% _refs.size() + "diff is what any number below is made of")
		print("LOOTNAME FAIL -- %d check(s) failed" % _fails)
		rig.fail("loot_names: %d check(s) failed" % _fails)


# --- Beat 0: the instrument answers a question it already knows ---------------

## Photograph a frozen frame twice, touching nothing between. Anything but zero
## means the world is still moving and every number below this line is noise.
func _null_case(rig, hero: Node3D) -> void:
	var at := hero.global_position + Vector3(0.0, 1.0, 0.0)
	var prev := Engine.time_scale
	Engine.time_scale = 0.0
	await rig.wait_frames(2)
	var lit := await _shoot(rig, out.path_join("n_00_null_a.png"))
	var again := await _shoot(rig, out.path_join("n_00_null_b.png"))
	Engine.time_scale = prev
	if lit == null or again == null:
		_ck("0 the null pair could be re-read off disk", false)
		return
	var cam := _cam(rig)
	var box := _box(cam, lit, at)
	var moved := _diff(lit, again, [box])
	print("LOOTNAME null case: %d px of %d moved between two captures of a "
		% [moved["n"], box.size.x * box.size.y] + "stopped world")
	_ck("0 a stopped world photographed twice is bit-identical (%d px)"
		% moved["n"], moved["n"] == 0)


# --- Beat A: real drops, from a real kill ------------------------------------

## Kill whatever the floor spawned near the hero, through `HealthComponent` so
## the drop goes down the path the game uses. `queue_free` on an enemy would
## produce no loot at all and this beat would then be photographing motes this
## file had placed itself, which proves nothing about the game.
func _kill_a_pack(rig, hero: Node3D) -> void:
	# The floor puts its packs where it likes and the hero starts in the entry
	# room, so the hero is taken to a pack rather than the pack being wished
	# nearer. Everything else in this beat then happens where he is standing,
	# which is the situation the card describes.
	var live: Array[Node3D] = []
	for n in rig.get_nodes_in_group(&"enemy"):
		var e := n as Node3D
		var hp = e.get(&"health") if e != null else null
		if hp != null and not hp.dead:
			live.append(e)
	print("LOOTNAME %d living enemies on the floor" % live.size())
	if live.is_empty():
		_ck("A0 the floor spawned something to kill", false)
		return
	var pack: Node3D = _by_distance(live, hero)[0]
	hero.velocity = Vector3.ZERO
	hero.global_position = pack.global_position \
		+ K.flat(hero.global_position - pack.global_position).normalized() * 3.0 \
		+ Vector3(0.0, 0.15, 0.0)
	await rig.wait_physics_frames(6)

	var killed := 0
	for e: Node3D in _by_distance(live, hero):
		if e.global_position.distance_to(hero.global_position) > 12.0:
			break
		var hp = e.get(&"health")
		hp.apply_hit(Hit.make(hp.health_points + 4, e.global_position, &"director", 0.0))
		killed += 1
		if killed >= 4:
			break
	await rig.wait_seconds(1.2)

	# **Cold from here on, or there is no fixture.** Four kills leaves the chain
	# lit, and `Heat.magnet_range()` at that tier is 2.5-4.5 m -- further than
	# the hero stands to READ a mote. Every drop below would be dragged in and
	# swept before the first capture, and the beats would photograph an empty
	# floor while reporting a layout failure. This is the fixture asking for a
	# cold floor and not a claim about heat; `heat_flow.gd` owns the magnet.
	Heat.reset()
	await rig.wait_frames(4)
	await _clear_the_corpses(rig)

	var motes := _motes(rig)
	print("LOOTNAME killed %d, %d mote(s) on the floor" % [killed, motes.size()])
	for m: Node3D in motes:
		print("LOOTNAME   \"%s\" at %.1f m" % [_text_of(m),
			m.global_position.distance_to(hero.global_position)])
	_ck("A0 killing a pack put motes on the floor (%d)" % motes.size(),
		not motes.is_empty())
	_ck("A1 and every one of them knows its own name (%d unnamed)"
		% _unnamed(motes), _unnamed(motes) == 0)


## Take the bodies off the floor before anything is measured.
##
## **A ragdoll keeps moving in a frozen frame, and it took a kept reference pair
## to see it.** `Engine.time_scale = 0` plus `rig.still_the_frame()` holds the
## world, the flames and the fog -- beat 0 measures exactly zero moving pixels
## with all three -- but a corpse is a `PhysicalBoneSimulator3D`
## (`enemy_ragdoll.gd`), and its bones went on integrating between two captures
## taken a frame apart. Measured: 728 px of a stepped-back frame moved, in a
## bounding box that turned out to be three tumbling rats, and beat B5 reported
## it as a name reaching a screen with no names on it.
##
## That is the same shape as CLAUDE.md §3's torch-and-fog row and it belongs
## next to it: the freeze stops the game clock, and a ragdoll is another thing
## here that does not run on it. The fix is not a looser threshold -- a
## threshold that absorbs a rat absorbs a caption -- it is to take the moving
## thing out of the picture before the pair is shot.
func _clear_the_corpses(rig) -> void:
	var gone := 0
	for n in rig.get_nodes_in_group(&"enemy"):
		var e := n as Node3D
		var hp = e.get(&"health") if e != null else null
		if hp != null and hp.dead:
			e.queue_free()
			gone += 1
	if gone > 0:
		print("LOOTNAME swept %d settling corpse(s) out of the frame -- see "
			% gone + "_clear_the_corpses")
	await rig.wait_frames(8)


# --- Beat B: read them, from the game camera ---------------------------------

## Walk the hero onto a drop and photograph what he sees. This is the frame the
## card asks for: the game camera, demo distance, name readable.
func _read_them(rig, hero: Node3D) -> Vector3:
	var motes := _motes(rig)
	if motes.is_empty():
		_ck("B0 there are motes to read", false)
		return Vector3.ZERO
	var subject: Node3D = _by_distance(motes, hero)[0]
	var at := subject.global_position
	# One mote for this beat, deliberately. The band cut below projects ink onto
	# y, which reads a VERTICAL stack correctly and would merge two names side
	# by side at the same depth into one band — a false failure about a frame
	# that is fine. The stack is beat D's job and it gets a real pile there;
	# here the claim is only "you can read the name", so there is one name.
	for m in motes:
		if m != subject:
			(m as Node).queue_free()
	await rig.wait_frames(6)
	if not await _stand_off(rig, hero, at, READ_AT):
		_ck("B1 there is somewhere to stand and read this drop from", false)
		return Vector3.ZERO

	var up := _named(rig)
	print("LOOTNAME standing %.1f m off, %d of %d mote(s) wearing a name"
		% [hero.global_position.distance_to(at), up.size(), motes.size()])
	_ck("B1 inside NAME_RANGE at least one mote is named (%d)" % up.size(),
		not up.is_empty())
	if up.is_empty():
		return at

	var read := await _bands(rig, at, out.path_join("n_01_in_the_open.png"))
	print("LOOTNAME in the open -> %d px of ink in %d band(s): %s"
		% [read["n"], read["bands"].size(), _heights(read["bands"])])
	_measured("B2 the name reaches the frame (%d px, >= %d)"
		% [read["n"], READABLE], read["n"] >= READABLE)
	_check_bands("B3", read, up.size())

	# --- And it leaves when you do ------------------------------------------
	# The other half of the WHEN. A name that never went away would be the
	# floating-text vomit §7.10 refuses, and it is the reason this is an
	# attention radius rather than a permanent label.
	if not await _stand_off(rig, hero, at, AWAY_AT):
		_ck("B4 there is somewhere %.1f m off to step back to" % AWAY_AT, false)
		return at
	var far_up := _named(rig)
	var gone := await _bands(rig, at, out.path_join("n_02_stepped_back.png"))
	print("LOOTNAME %.1f m off -> %d named, %d px of ink"
		% [AWAY_AT, far_up.size(), gone["n"]])
	_ck("B4 stepped past NAME_RANGE + the fade, nothing is named (%d)"
		% far_up.size(), far_up.is_empty())
	_measured("B5 and not one pixel of a name reaches the frame (%d)"
		% gone["n"], gone["n"] == 0)
	# Handed to the pile beat. It is a patch of floor a mote has just been read
	# on from two distances, so it is provably open, provably reachable and
	# provably in shot -- which is worth more than any point this file could
	# pick out of the air.
	return at


# --- Beat C: cards #26 and #37, on a mote -------------------------------------

## Put a mote on the far side of solid geometry, stand the hero close enough to
## it that the range gate is NOT what is hiding the name, and photograph the
## pair: occlusion off, then the game as it builds.
##
## The wall is FOUND rather than chosen. "Put it at (12, 0, -4) and trust that
## the east wall is between" is the assertion this repo has been burned by, so
## the search walks bearings round the hero and stops at the first one where a
## ray from the LENS to where the caption would hang hits `K.L_WORLD` — and the
## collider it hit is printed next to the frame.
func _behind_a_wall(rig, hero: Node3D) -> void:
	var cam := _cam(rig)
	if cam == null:
		_ck("C0 there is a game camera to shoot through", false)
		return
	# See the note on the beat order in `run`. Every count below is "how much
	# ink did a loot caption put here", and another mote's name drifting into
	# the box is indistinguishable from this one's.
	for m in _motes(rig):
		(m as Node).queue_free()
	await rig.wait_frames(6)

	var found := await _across_a_wall(rig, hero)
	_ck("C0 there is solid geometry between the game camera and a point inside "
		+ "NAME_RANGE (%s)" % str(found.get("what", "NOTHING FOUND")),
		not found.is_empty())
	if found.is_empty():
		return
	cam = _cam(rig)
	var at: Vector3 = found["at"]
	print("LOOTNAME wall lens->mote: %s, mote %.1f m from the hero, %.1f m "
		% [found["what"], hero.global_position.distance_to(at),
			cam.global_position.distance_to(at)] + "from the lens")

	var mote := LootMote.drop(rig.scene(), &"deep_amber", at)
	await rig.wait_seconds(0.5)
	var caps := _caps([mote])
	_ck("C1 the walled-off mote is named at all (%d)" % caps.size(),
		caps.size() == 1)
	if caps.is_empty():
		mote.queue_free()
		return

	# The control, and it is the bug. Without it a zero below reads the same
	# whether the wall hid the caption or the caption was never drawn.
	_set_occluded(caps, false)
	await rig.wait_frames(6)
	var leak := await _bands(rig, at, out.path_join("n_03_wall_occlude_off.png"))
	_set_occluded(caps, true)
	await rig.wait_frames(6)
	var held := await _bands(rig, at, out.path_join("n_04_wall.png"))

	print("LOOTNAME behind %s: occlusion OFF -> %d px, as it builds -> %d px"
		% [found["what"], leak["n"], held["n"]])
	_measured("C2 with occlusion off the name paints the wall (%d px, >= %d)"
		% [leak["n"], READABLE], leak["n"] >= READABLE)
	_measured("C3 as the game builds it, NOT ONE pixel of the name reaches the "
		+ "frame (%d)" % held["n"], held["n"] == 0)

	mote.queue_free()
	await rig.wait_frames(4)


# --- Beat D: card #68, on a pile ----------------------------------------------

## Five motes inside half a metre. `LootMote.NAME_MAX` says three of them are
## named — the three NEAREST, which is the choice the HUD's own de-collide
## cannot make (it drops by projected y, so the FARTHEST names would survive) —
## and those three arrive on three separate rows.
func _pile_up(rig, hero: Node3D, at: Vector3) -> void:
	for m in _motes(rig):
		(m as Node).queue_free()
	Heat.reset()  # See `_kill_a_pack` -- a lit chain eats the fixture.
	await rig.wait_frames(6)

	if at == Vector3.ZERO:
		_ck("D0 beat B found a patch of floor to pile onto", false)
		return
	var ids: Array[StringName] = [&"bone_shard", &"rot_moss", &"cracked_flint",
		&"deep_amber", &"ember_gland"]
	for i in PILE:
		var a := float(i) / float(PILE) * TAU
		LootMote.drop(rig.scene(), ids[i % ids.size()],
			at + Vector3(sin(a), 0.0, cos(a)) * PILE_R)
	await rig.wait_seconds(0.6)
	if not await _stand_off(rig, hero, at, READ_AT):
		_ck("D0 there is somewhere to read the pile from", false)
		return

	var motes := _motes(rig)
	var up := _named(rig)
	print("LOOTNAME pile of %d -> %d named: %s"
		% [motes.size(), up.size(), _texts(up)])
	_ck("D0 five motes landed (%d)" % motes.size(), motes.size() == PILE)
	_ck("D1 exactly NAME_MAX of them wear a name (%d, want %d)"
		% [up.size(), LootMote.NAME_MAX], up.size() == LootMote.NAME_MAX)

	# The three named ones must be the three NEAREST. This is the half of card
	# #68 that a pixel cannot answer: a layout that shows three of five names is
	# only right if it is showing the three the player is walking onto.
	var mine := _by_distance(motes, hero)
	var want: Array[String] = []
	for i in mini(LootMote.NAME_MAX, mine.size()):
		want.append(_text_of(mine[i]))
	want.sort()
	var got := _texts(up)
	got.sort()
	_ck("D2 and they are the three NEAREST (%s, want %s)" % [got, want],
		got == want)

	var read := await _bands(rig, at, out.path_join("n_05_pile_of_five.png"))
	print("LOOTNAME pile -> %d px of ink in %d band(s): %s"
		% [read["n"], read["bands"].size(), _heights(read["bands"])])
	_measured("D3 the pile puts names on the frame (%d px, >= %d)"
		% [read["n"], READABLE], read["n"] >= READABLE)
	_check_bands("D4", read, up.size())


## Every band is one row tall and there is one per visible caption. Both halves
## matter: three bands of 53 px is three captions drawn as three merged pairs,
## and one band of 26 px is card #68 exactly.
func _check_bands(tag: String, read: Dictionary, want: int) -> void:
	var bands: Array = read["bands"]
	var floor_px := CAP_MIN_PX * float(read["frame_h"]) / 720.0
	var pad := PLATE_PAD_PX * float(read["frame_h"]) / 720.0
	var row_max := ROW_MAX_PX * float(read["frame_h"]) / 720.0
	_measured("%s one band of ink per name on screen (%d band(s), %d name(s))"
		% [tag, bands.size(), want], bands.size() == want)
	for b: Dictionary in bands:
		var h := float(b["h"])
		var cap := h - pad * 2.0
		print("LOOTNAME   band y %d..%d, %.0f px tall -> %.1f px of cap height "
			% [int(b["y0"]), int(b["y1"]), h, cap] + "(floor %.1f)" % floor_px)
		_measured("%s a band is ONE row and not two run together "
			% tag + "(%.0f px, < %.0f)" % [h, row_max], h < row_max)
		_measured("%s and it is LEGIBLE and not merely present: %.1f px of cap "
			% [tag, cap] + "height where §3.1b's floor is %.1f" % floor_px,
			cap >= floor_px)


# --- The measurement ----------------------------------------------------------

## Capture the frame a human looks at, then find which of its pixels the loot
## captions put there and cut them into bands.
##
## The captions are taken away ALL AT ONCE rather than one at a time, and that
## is not a shortcut: `Hud._draw_world_captions` lays a cluster out against
## itself, so hiding one caption MOVES the others, and a per-caption diff would
## score its neighbours' new rows as its own ink. Every non-loot caption in the
## room is muted for the whole measurement for the same reason
## (`world_labels._read` learned this the expensive way).
func _bands(rig, anchor: Vector3, path: String) -> Dictionary:
	var cam := _cam(rig)
	_mute_strangers(rig)
	await rig.wait_frames(2)

	var prev := Engine.time_scale
	Engine.time_scale = 0.0
	await rig.wait_frames(2)
	var lit := await _shoot(rig, path)
	if lit == null:
		Engine.time_scale = prev
		_unmute()
		print("LOOTNAME could not re-read %s" % path)
		return {"n": -1, "bands": [], "frame_h": 720}

	# Remembered, not re-derived. `LootMote._show_name` owns which captions are
	# up and the clock is stopped, so nothing would put them back by itself --
	# and asking `visible` after hiding them answers "no" for all of them.
	var caps := _caps(_motes(rig))
	var was: Array[bool] = []
	for c: Node3D in caps:
		was.append(c.visible)
		c.visible = false
	await rig.wait_frames(2)
	var ref := path.get_basename() + ".ref.png"
	var bare := await _shoot(rig, ref)
	_refs.append(ref)
	for i in caps.size():
		(caps[i] as Node3D).visible = was[i]
	Engine.time_scale = prev
	_unmute()
	await rig.wait_frames(2)

	if bare == null or bare.get_size() != lit.get_size():
		return {"n": -1, "bands": [], "frame_h": lit.get_size().y}
	var box := _box(cam, lit, anchor)
	var d := _diff(lit, bare, [box])
	d["frame_h"] = lit.get_size().y
	return d


## Pixels of `a` that differ from `b` inside `boxes`, and the horizontal bands
## they fall into. A band is a run of scanlines each carrying at least
## `BAND_FLOOR` changed pixels; `CAPTION_STACK_GAP` leaves one clear scanline
## between two stacked plates, which is what makes two rows two bands.
func _diff(a: Image, b: Image, boxes: Array) -> Dictionary:
	var rows: Dictionary = {}
	var n := 0
	for box: Rect2i in boxes:
		if box.size == Vector2i.ZERO:
			continue
		for y in range(box.position.y, box.end.y):
			var hits := 0
			for x in range(box.position.x, box.end.x):
				var p := a.get_pixel(x, y)
				var q := b.get_pixel(x, y)
				if absf(p.r - q.r) > INK_DELTA or absf(p.g - q.g) > INK_DELTA \
						or absf(p.b - q.b) > INK_DELTA:
					hits += 1
			if hits > 0:
				n += hits
			if hits >= BAND_FLOOR:
				rows[y] = hits

	var ys: Array = rows.keys()
	ys.sort()
	var bands: Array[Dictionary] = []
	var y0 := -1
	var prev := -99
	for y: int in ys:
		if y != prev + 1:
			if y0 >= 0:
				bands.append({"y0": y0, "y1": prev, "h": float(prev - y0 + 1)})
			y0 = y
		prev = y
	if y0 >= 0:
		bands.append({"y0": y0, "y1": prev, "h": float(prev - y0 + 1)})
	return {"n": n, "bands": bands}


## The window every count is taken inside. Whole-frame diffs are not an option:
## `Engine.time_scale` freezes the world and NOT the HUD, which runs off the
## wall clock, so a vitals bar ticking between the pair scores as caption ink.
func _box(cam: Camera3D, img: Image, anchor: Vector3) -> Rect2i:
	if cam == null or cam.is_position_behind(anchor):
		return Rect2i()
	var view: Vector2 = cam.get_viewport().get_visible_rect().size
	var scale := Vector2(img.get_size()) / view
	var half := Vector2(BOX_HALF) * float(img.get_size().y) / 720.0
	var c := cam.unproject_position(anchor) * scale
	var b := Rect2i(Vector2i(c - half), Vector2i(half * 2.0))
	# Clipped rather than refused: a mote near the edge of the picture is a
	# normal thing to photograph, and the alternative is a beat that silently
	# measures nothing.
	return b.intersection(Rect2i(Vector2i.ZERO, img.get_size()))


func _shoot(rig, path: String) -> Image:
	await rig.capture(path)
	return Image.load_from_file(path)


# --- Fixture ------------------------------------------------------------------

## Stand the hero `metres` from `at`, facing it, and let the game camera settle
## behind his shoulder.
##
## `recenter()` and then a WAIT ON THE ANGLE, not on a frame count: the recentre
## is an ease over `recenter_time` on the physics clock, and a director that
## guessed twenty rendered frames would pass or fail on the refresh rate of the
## panel it ran on (`rig.until`, and the note on it in `shoot.gd`).
func _stand_off(rig, hero: Node3D, at: Vector3, metres: float) -> bool:
	var space := hero.get_world_3d().direct_space_state
	var eye := Vector3.UP * K.HERO_EYE_Y
	var subject := at + Vector3.UP * LootMote.NAME_Y
	var toward := K.flat(hero.global_position - at)
	toward = toward.normalized() if toward != Vector3.ZERO else Vector3.BACK

	# **The bearing is SEARCHED and not taken from where the hero happens to be,
	# and one frame is why.** Backing straight off a drop put the hero 40 cm from
	# a wall; the camera's own wall check then pulled the boom to
	# `GameCamera.hard_min_distance` (1.35 m), and the capture was a full-frame
	# photograph of the back of his cloak with the mote somewhere behind his
	# shoulder. The beat failed reporting zero ink, which was true and told
	# nobody anything. So a stand point has to satisfy both halves of "a player
	# could have produced this frame": the mote is visible from it, and the boom
	# has somewhere to go behind it.
	var room := K.CAM_DIST_MAX + 0.6
	var best := Vector3.ZERO
	var best_score := -1.0
	for step in 36:
		var a := float(step) / 36.0 * TAU
		var dir := Vector3(sin(a), 0.0, cos(a))
		var stand := Vector3(at.x, hero.global_position.y, at.z) + dir * metres
		if not _ray(space, stand + eye, subject).is_empty():
			continue
		var behind := _ray(space, stand + eye, stand + eye + dir * room)
		var clear := room
		if not behind.is_empty():
			clear = (behind["position"] as Vector3).distance_to(stand + eye)
		# Ties go to the bearing nearest the one the hero was already on, so the
		# shot is the walk he was on and not the tidiest one in the room.
		var score := minf(clear, room) + dir.dot(toward) * 0.5
		if score > best_score:
			best_score = score
			best = stand
	if best_score < 0.0:
		print("LOOTNAME no stand-off point at %.1f m can see the subject" % metres)
		return false

	var back := K.flat(best - at).normalized()
	hero.velocity = Vector3.ZERO
	hero.global_position = best + Vector3(0.0, 0.15, 0.0)
	# Heading yaw: heading == (sin y, 0, cos y), and the body carries
	# `rotation.y = facing_yaw + PI` (docs/CONTRACT.md §2.5, CLAUDE.md §4). Set
	# the heading and let `_physics_process` derive the body from it.
	var look := -back
	hero.set(&"facing_yaw", atan2(look.x, look.z))
	await rig.wait_physics_frames(6)

	var cam := _cam(rig)
	if cam != null:
		cam.call(&"recenter")
		var want := K.flat(at - hero.global_position).normalized()
		await rig.until(func() -> bool:
			return K.flat(-cam.global_transform.basis.z).normalized().dot(want) \
				> 0.97, 4.0)
	await rig.wait_frames(12)
	cam = _cam(rig)
	if cam != null:
		# Printed, not asserted. The boom is allowed to be short — a corridor is
		# a real place to read a drop — but a frame shot off a collapsed boom is
		# a frame whose verdict has to be read differently, and the number has to
		# be in the log for that to be possible.
		print("LOOTNAME stood %.1f m off, boom %.2f m (%.2f-%.2f nominal)"
			% [metres, cam.global_position.distance_to(
				hero.global_position + Vector3.UP * K.HERO_EYE_Y),
				K.CAM_DIST_MIN, K.CAM_DIST_MAX])
	return true


## Put the hero a stride in front of the nearest wall, aim the game camera at
## it, and hand back a point on the FAR side of it — close enough to the hero
## that `LootMote.NAME_RANGE` cannot be what hides the name.
##
## The wall is found rather than chosen. "Put it at (12, 0, -4) and trust that
## the east wall is between" is exactly the assertion this repo has been burned
## by, so a fan of rays picks the nearest masonry the hero is actually standing
## near, and the collider's name is printed beside the frame.
##
## Both rays are then re-cast and checked, because a hit found from the hero's
## eye is not the claim: the claim is that the LENS cannot see it, and the lens
## has moved since — it sits on a boom behind the shoulder and eases into place.
func _across_a_wall(rig, hero: Node3D) -> Dictionary:
	var space := hero.get_world_3d().direct_space_state
	var eye := hero.global_position + Vector3.UP * K.HERO_EYE_Y
	var best := {}
	var best_d := 1e9
	for step in 48:
		var a := float(step) / 48.0 * TAU
		var dir := Vector3(sin(a), 0.0, cos(a))
		var hit := _ray(space, eye, eye + dir * 9.0)
		if hit.is_empty():
			continue
		var d: float = (hit["position"] as Vector3).distance_to(eye)
		# Nearer than 1.5 m and standing off it would put the hero inside the
		# wall; further than 9 m and the picture is of a room, not of a wall.
		if d < 1.5 or d >= best_d:
			continue
		best_d = d
		best = {"pos": hit["position"], "normal": hit["normal"],
			"what": str((hit["collider"] as Node).name), "dir": dir}
	if best.is_empty():
		return {}

	var face: Vector3 = K.flat(best["dir"]).normalized()
	var wall: Vector3 = best["pos"]
	# 1.2 m off the face, and the mote 1.5 m through it. 2.7 m apart, which is
	# well inside NAME_RANGE — so a zero on the far frame is the WALL and not
	# the range gate, which is the whole reason those two numbers are what they
	# are.
	hero.velocity = Vector3.ZERO
	hero.global_position = Vector3(wall.x, hero.global_position.y, wall.z) \
		- face * 1.2 + Vector3(0.0, 0.15, 0.0)
	hero.set(&"facing_yaw", atan2(face.x, face.z))
	await rig.wait_physics_frames(6)
	var at := Vector3(wall.x, hero.global_position.y - 0.15, wall.z) + face * 1.5

	var cam := _cam(rig)
	if cam != null:
		cam.call(&"recenter")
		await rig.until(func() -> bool:
			return K.flat(-cam.global_transform.basis.z).normalized().dot(face) \
				> 0.97, 4.0)
	await rig.wait_frames(12)
	cam = _cam(rig)
	if cam == null:
		return {}

	var anchor := at + Vector3.UP * LootMote.NAME_Y
	if cam.is_position_behind(anchor):
		return {}
	var lens := _ray(space, cam.global_position, anchor)
	# **And the wall has to be between the HERO and the mote too.** The card's
	# words are "walk behind a wall", not "stand where the lens happens to clip
	# a pillar": a mote the player can see but the camera cannot is a different
	# and much rarer frame, and photographing it would let this beat pass on
	# geometry that answers the wrong question.
	var mine := _ray(space, hero.global_position + Vector3.UP * K.HERO_EYE_Y,
		anchor)
	if lens.is_empty() or mine.is_empty():
		print("LOOTNAME wall search: nearest masonry %s at %.1f m, but the "
			% [best["what"], best_d] + "line is %s from the lens / %s from the "
			% ["clear" if lens.is_empty() else "blocked",
				"clear" if mine.is_empty() else "blocked"] + "hero")
		return {}
	return {"at": at, "what": str((lens["collider"] as Node).name)}


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3,
		to: Vector3) -> Dictionary:
	return space.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to, K.L_WORLD))


# --- Small change -------------------------------------------------------------

## A check made of PIXELS. Identical to `_ck` at native, and downgraded to a
## printed reading under `--internal` -- see the long note in `run`.
func _measured(label: String, ok: bool) -> void:
	if _pixels:
		_ck(label, ok)
	elif ok:
		print("LOOTNAME ok(reported) %s" % label)
	else:
		print("LOOTNAME UNVERIFIED %s -- §4.5's dither, not a verdict" % label)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("LOOTNAME ok %s" % label)
	else:
		_fails += 1
		print("LOOTNAME FAIL %s" % label)


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _cam(rig) -> Camera3D:
	return (rig.root as Viewport).get_camera_3d()


func _motes(rig) -> Array:
	var found: Array = []
	for n in rig.get_nodes_in_group(LootMote.NAME_GROUP):
		if is_instance_valid(n):
			found.append(n)
	return found


## The motes actually wearing a name right now, asked of the game's own state.
func _named(rig) -> Array:
	var found: Array = []
	for m in _motes(rig):
		if _wants_name(_cap_of(m)):
			found.append(m)
	return found


func _caps(motes: Array) -> Array:
	var found: Array = []
	for m in motes:
		var c := _cap_of(m)
		if c != null:
			found.append(c)
	return found


func _cap_of(m) -> Node3D:
	if m == null or not is_instance_valid(m):
		return null
	for c in (m as Node).get_children():
		if c is WorldCaption:
			return c
	return null


## Is this caption one the game has put up? Read off `visible` rather than off
## `LootMote._named` so the answer is the one the HUD acts on.
func _wants_name(c: Node3D) -> bool:
	return c != null and is_instance_valid(c) and c.visible \
		and not str(c.get(&"text")).is_empty()


func _text_of(m) -> String:
	var c := _cap_of(m)
	return str(c.get(&"text")) if c != null else ""


func _texts(motes: Array) -> Array[String]:
	var found: Array[String] = []
	for m in motes:
		found.append(_text_of(m))
	return found


func _unnamed(motes: Array) -> int:
	var n := 0
	for m in motes:
		if _text_of(m).is_empty():
			n += 1
	return n


func _by_distance(motes: Array, hero: Node3D) -> Array:
	var sorted := motes.duplicate()
	sorted.sort_custom(func(p, q) -> bool:
		return (p as Node3D).global_position.distance_to(hero.global_position) \
			< (q as Node3D).global_position.distance_to(hero.global_position))
	return sorted


func _set_occluded(caps: Array, on: bool) -> void:
	for c: Node3D in caps:
		c.set(&"occlude", on)


func _heights(bands: Array) -> Array[float]:
	var found: Array[float] = []
	for b: Dictionary in bands:
		found.append(float(b["h"]))
	return found


## Take every caption that is NOT a loot mote's off the screen for the duration
## of a measurement. They are not the subject, they are laid out against the
## subject by the de-collide, and one drifting into the box would be counted as
## a name.
func _mute_strangers(rig) -> void:
	_muted.clear()
	var mine := _caps(_motes(rig))
	for n in rig.get_nodes_in_group(WorldCaption.GROUP):
		var c := n as Node3D
		if c == null or mine.has(c) or not c.visible:
			continue
		c.visible = false
		_muted.append(c)


func _unmute() -> void:
	for c: Node3D in _muted:
		if is_instance_valid(c):
			c.visible = true
	_muted.clear()
