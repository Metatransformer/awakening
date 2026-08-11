extends RefCounted
## Card #37 — **the last three world labels stop at the first wall.**
## Card #61 — **and you can read them.**
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/world_labels.gd \
##     --out=/tmp/labels/x.png --warmup=60
##
## Card #26 took `no_depth_test` off the Echo name plates and left three labels
## of the same kind behind, deliberately, as out of scope: `TrainingPost`'s
## running readout, `TrainingPost`'s floating damage numbers, and `Npc`'s
## shopkeeper sign. `no_depth_test = true` on a world-space `Label3D` does not
## mean "draw over the thing it hangs off" — it means DRAW OVER THE WORLD, so a
## keeper's name was readable through the garrison's six-metre curtain wall from
## out on the plain, and a damage number would have been readable through it too.
##
## ## What card #61 changed here, and it starts with what this file got wrong
##
## **This director passed, unchanged, through the whole of the defect it now
## catches.** `docs/STYLEGUIDE.md` §4.5 put the world in a fixed 480 x 270
## buffer; every one of these captions was a `Label3D`, so every one went into
## that buffer with the masonry and came out an unreadable smear — and beats n4
## and p4 below went on reporting a thousand pixels of ink, because the pixels
## really were all there. A count of ink is a count of PRESENCE. It cannot see
## legibility, and this file was the instrument the project trusted for it.
##
## So the three captions are `WorldCaption`s now, drawn on the HUD canvas at
## native resolution (`scripts/ui/world_caption.gd`, `Hud._draw_world_captions`),
## and **beat 6 is what this file has that it did not have**: a measurement that
## fails on a caption that is present and unreadable.
##
## ## Beat 6, and why it is a size and not a contrast
##
## The number is the caption's **cap height in the pixels it was rasterised in**,
## against `docs/STYLEGUIDE.md` §3.1b's 10 px floor. Two halves, and only the
## second is arithmetic:
##
##  1. The cap height on the picture is measured off the frame — the bounding box
##     of the ink the caption put there, inset by the surround it wears.
##  2. That is then divided down by whatever buffer the glyph was RASTERISED in.
##     A `WorldCaption` is drawn on the canvas, so a frame pixel is a rasterised
##     pixel and the divisor is one. A `Label3D` is world geometry: it goes
##     through §4.5's 480 x 270 buffer and is upscaled 2.67x on the way out, so
##     fourteen pixels of frame are five pixels of glyph.
##
##   | caption at 3.8 m              | on frame | rasterised at |
##   |-------------------------------|----------|---------------|
##   | `JEWELCRAFTER` as a `Label3D` |   ~14 px |     ~5 px  ✗  |
##   | `JEWELCRAFTER` as a caption   |    14 px |      14 px ✓  |
##
## **Point this file at the commit before card #61 and beat 6 fails.** That is
## the whole test of an instrument and it is why `_labels_under` still finds
## `Label3D`s: a caption that goes back into the buffer is measured, named and
## failed rather than quietly not found.
##
## Two things were TRIED for this and are written down so nobody spends the
## afternoon again. Both were contrast measurements — "what fraction of the ink
## is neither ink nor ground", and "how much of the luminance range does the
## steepest edge cross in one pixel" — and both separated the two builds on the
## long captions (0.37 and 0.41 against 0.11 and 0.14) and then called the
## training post's damage number, which is a perfectly crisp RUST `3` on a plate
## over sunlit straw, worse than the smear they were built to catch. A
## low-contrast caption is not a low-resolution one, and a metric that cannot
## tell them apart will eventually be silenced rather than believed. Size is the
## thing that actually changed and size is what is asked.
##
## What was RETIRED for all this, because the move made it untrue: beat p6, which
## measured the bundle taking a bite out of a damage number placed back where it
## used to be built. A `WorldCaption`'s line-of-sight ray excludes the prop the
## caption hangs off — an enemy does not block its own health bar either — so
## the bundle cannot bite it any more and the beat measured nothing. See
## `TrainingPost.POPUP_CLEAR`, which keeps its placement job and loses its
## clearance one.
##
## What it claims, in the order it proves them:
##
##   A  A keeper stands in the yard with their sign up, and a training post
##      stands in the yard having just been hit, so a readout and a damage
##      number are on it.
##   B  From a camera OUTSIDE the curtain wall, on the keeper's own radial, with
##      masonry proved to be in the way by a ray cast down the camera's line:
##      with occlusion turned off the name paints the wall, and as the game now
##      builds it **not one of its pixels reaches the picture.** Both frames are
##      kept — the first one is what the defect looked like.
##   C  Stepped back inside the yard, on the same line, the name is readable —
##      and **legible**, which is a different claim and a different measurement.
##   D  The same pair for the post's readout and its damage number, measured one
##      label at a time, legibility included.
##
## ## Why this diffs frames instead of reading `visible`
##
## Straight out of `tools/directors/echo_plates.gd`, which is card #26's director
## and the shape this one copies rather than reinvents. Every property involved
## is true in both the broken and the fixed build — the label is `visible`, in
## the tree, correctly placed, correctly worded — so the only thing that changes
## is what reaches the frame, and that is what is counted.
##
## It is counted by **taking the label away**: freeze the clock, photograph the
## pose, hide the label, photograph it again, count the pixels that moved inside
## a box round where the label projects. #26 learned the expensive half of this
## the hard way — its first cut matched on `Pal.CYAN` and scored a frame with the
## names plainly painted on a door at zero, because a caption ten metres off
## comes out of the Lanczos downscale as a dim smear and not as a palette entry.
## Do not "simplify" this back into a colour match.
##
## `Engine.time_scale = 0` is what makes a pair comparable: the lamps swell, the
## grass moves and the damage number is mid-tween, so two captures of a running
## garrison differ everywhere. Frozen — and with `rig.still_the_frame()` holding
## the two things the freeze does not, card #62 — the world differs only where
## the label was.
##
## The count is taken inside a box all the same, and the reason is the box and
## not the overlay: a caption's ink has to be counted where the caption is, or a
## label that moved four pixels reads as a label that appeared. **The HUD itself
## is frozen** — card #62 measured 0 of the overlay's 60,194 painted pixels
## moving between two captures of a stopped world, which is the opposite of what
## this comment used to assert.
##
## ## Why the occluder is found rather than hard-coded
##
## "Put the camera at (16.8, 2.4, 6.9) and trust that the east wall is between"
## is exactly the assertion this repo has been burned by. So the camera walks
## outward along the subject's radial and stops at the first distance where a ray
## from the lens to the label hits `K.L_WORLD` geometry, and the collider it hit
## is printed next to the frame. A frame where the label merely happens not to
## overlap anything proves nothing; this one names the wall.

## Where the plaza is and how far out the keepers ring it. `Garrison.PLAZA_AT`
## and its neighbours, spelled out rather than read off the class: this file is
## loaded with `-s`, and a `preload` of a script that names an autoload takes the
## whole harness down before the autoloads exist (`CLAUDE.md` §3, and the same
## note is on `echo_plates.gd`).
const PLAZA_AT := Vector3(0.0, 0.0, -2.0)

## Where the training post is stood, as a bearing off the plaza and a radius.
##
## South-east, and off every occupied bearing in `Garrison._build_people` (the
## ring is 55 / -55 / 118 / -118) so the post is not inside somebody's forge. 8.5
## m from the plaza's middle puts it two and a half metres clear of the south
## curtain, which is the wall this half of the run photographs it through.
const POST_BEARING := 145.0
const POST_R := 8.5

## How far out along a subject's radial the occluded camera is allowed to walk
## looking for masonry, and in what steps. It starts past the curtain (13 m in x,
## 11 m in z off `Garrison.yard`) and the ray test is what actually decides.
const FAR_FROM := 15.0
const FAR_TO := 30.0
const FAR_STEP := 1.5

## And how much further it stands back once it has found some.
##
## The first occluded distance is often two metres from the masonry, which fills
## the whole picture with one blurred course of stone -- and on the east curtain,
## which is in shadow at this sun angle, with a near-black field. The label being
## there or not there is still legible in that frame, but "look at the frames" is
## the bar (`CLAUDE.md` §2) and a frame that has to be explained is a poor one.
## Six metres further back puts the parapet, the sky and the ground in shot, so
## the picture says *the label is behind that wall* on its own. Occlusion is
## re-tested at the new spot rather than assumed, and the search keeps the nearer
## one if stepping back opens a line.
const FAR_MARGIN := 6.0

## How far in front of a subject the clear-line-of-sight lens sits. Near enough
## that the label is a few hundred pixels of ink, far enough that the whole
## subject is in the picture.
##
## **It is also the distance card #61 is judged at, and that is on purpose.**
## 3.8 m is inside talking range of a keeper and inside sword range of the post:
## it is where a player stands when they read these things, not a distance
## chosen to flatter the caption. If a name is not legible here it is not
## legible anywhere.
const NEAR_AT := 3.8

## How far a channel has to move for a pixel to count as "the label was here".
## The two captures are the same frozen frame with one node hidden, so anything
## the label touches moves far more than this and everything else moves not at
## all; the window only absorbs the last of the Lanczos downscale.
const INK_DELTA := 0.02

## What counts as "the label reached the picture at all", far and near. A sign
## seen from fifteen metres is a couple of hundred pixels of glyph and outline;
## the same sign at four metres is well over a thousand. These are floors, and
## deliberately loose ones — the numbers this run actually measures are printed.
const READABLE := 30
const READABLE_NEAR := 200

## **The legibility bar, and the whole of card #61's instrument.**
##
## Cap height, in the pixels the glyph was rasterised in, against
## `docs/STYLEGUIDE.md` §3.1b's floor. Its wording is exact and it is why this is
## a floor and not a preference: "there is no longer any margin under the floor,
## and no viewport AA setting can add one ... font rasterisation is the only
## antialiasing 2D type will ever get, so the answer to an illegible label is
## fewer entries or a bigger size, never a knob."
##
## Scaled by the frame's height, so a run at `--size=1920x1080` asks the same
## question of the same design rather than a laxer one.
const CAP_MIN_PX := 10.0

## How much of the caption's own surround to take off the ink's bounding box
## before it is read as a cap height.
##
## §5.7's World plate pad is 6 px, which is what a `WorldCaption` wears, and one
## number is used for both builds rather than two tuned ones.
##
## **It over-subtracts on a `Label3D` and the verdict does not depend on that.**
## A `Label3D`'s outline comes out thinner than 6 px on the frame at this
## distance, so taking 6 off each edge eats into the glyph as well: measured on
## the old build, `JEWELCRAFTER` reported a 14 px ink box and a 2 px cap. Take
## the inset to zero and the same caption is 14 px of frame, which through the
## 480 x 270 buffer is **5.25 px of type against a floor of 10** — still failing
## by half. The inset changes how badly the old build fails and not whether it
## does, which is the only property it needs to have.
const CAP_INSET_PX := 6.0

## The internal buffer §4.5 renders the world into. Spelled out rather than read
## off `ScreenPresent.INTERNAL`, for the reason at the top of `PLAZA_AT`: this
## file is loaded with `-s` and does not get to touch a script that names an
## autoload. `Settings.internal_render` decides whether it applies at all, and it
## is asked at runtime rather than assumed — a run with the pipeline switched off
## has captions rasterised at the frame's own height, and saying otherwise would
## make this file lie in the one configuration where the defect does not exist.
const INTERNAL_H := 270.0

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/labels/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var g: Node3D = rig.scene() as Node3D
	if g == null or g.name != &"Garrison":
		print("LABELS FAIL wrong host scene (%s) -- pass "
			% (g.name if g else "<none>")
			+ "--scene=res://scenes/rooms/garrison.tscn")
		return
	await rig.wait_frames(30)

	# The pair below is a pixel diff, so the frame has to be reproducible, and
	# `Engine.time_scale = 0` alone does not make it one -- card #62, CLAUDE.md
	# §3. The garrison's braziers and the volumetric fog both keep moving in a
	# stopped world; under §4.5's RGB555 quantizer the fog's jitter alone is
	# thousands of pixels past `INK_DELTA`, which is the number this file counts.
	rig.still_the_frame()

	# The hero is parked out of the way while the fixture is built, and then
	# **moved to the subject by `_prove`** -- see `_park_beside`, and card #61
	# for why he can no longer be left in the north-west quarter. He is not the
	# subject of any of these frames and he is a 1.65 m body that would confound
	# a "the wall hid it" reading if he wandered onto one of the camera lines --
	# which is `echo_plates.gd`'s own lesson (correct occlusion means the hero
	# can hide a label, and that is right, so photograph off his axis).
	var hero: Node3D = _hero(rig)
	if hero == null:
		print("LABELS FAIL no hero in the scene")
		return
	hero.velocity = Vector3.ZERO
	hero.global_position = Vector3(-8.0, 0.15, -6.0)
	await rig.wait_physics_frames(6)
	await rig.wait_frames(12)

	# --- A. The fixture ------------------------------------------------------
	var npc: Node3D = _a_keeper(g)
	_ck("A0 a keeper with a sign stands in the yard", npc != null)
	if npc == null:
		return
	var signs: Array = await _arm(rig, npc, Vector3.ZERO)
	_ck("A1 and their sign is up",
		signs.size() == 1 and (signs[0] as Node3D).visible)
	if signs.is_empty():
		return
	print("LABELS keeper %s, sign \"%s\" at y=%.2f"
		% [npc.name, signs[0].text, (signs[0] as Node3D).global_position.y])

	var post: Node3D = _stand_a_post(g)
	_ck("A2 a training post stands in the yard", post != null)
	if post == null:
		return
	await rig.wait_frames(10)

	# Struck from the far camera's side, so the damage number ends up on the face
	# of the post that BOTH lenses see. Placed the other way the straw bundle
	# itself would hide it from the far lens and the zero would prove nothing
	# about the wall.
	var strike_from := post.global_position + _radial(post) * 2.0 \
		+ Vector3(0.0, 1.2, 0.0)
	var post_labels: Array = await _arm(rig, post, strike_from)
	_ck("A3 and being struck put two labels on it -- a running readout and a "
		+ "damage number (%d)" % post_labels.size(), post_labels.size() == 2)
	if post_labels.size() != 2:
		return
	for l: Node3D in post_labels:
		# `K.plane`, not `K.flat`. `flat` normalises and would answer this
		# distance question with 1.00 every time -- which it did, on the first
		# run of this file, and `consts.gd` has the note saying it would.
		print("LABELS post label \"%s\" at y=%.2f, %.2f m off the post's axis"
			% [l.text, l.global_position.y,
				K.plane(l.global_position - post.global_position).length()])

	# --- B / C. The keeper's sign -------------------------------------------
	await _prove(rig, "n", "the keeper's sign", npc, Vector3.ZERO,
		Vector2i(130, 44))

	# --- D / E. The post's readout and its damage number ---------------------
	await _prove(rig, "p", "the post's readout and damage number", post,
		strike_from, Vector2i(240, 52))

	if _fails == 0:
		print("LABELS ok -- every check passed")
	else:
		print("LABELS FAIL -- %d check(s) failed" % _fails)


# --- The claim ----------------------------------------------------------------

## Both directions for one subject: hidden by masonry, then readable in the open.
##
## `hit_from` is where a training post is to be struck from, or `Vector3.ZERO`
## for anything that is not one — see `_arm`, which re-arms whatever is transient
## (a sign `Prompt` may drop, a damage number that has a lifetime) immediately
## before every capture, while the clock is still running.
func _prove(rig, tag: String, what: String, subject: Node3D, hit_from: Vector3,
		box: Vector2i) -> void:
	var dir := _radial(subject)
	await _park_beside(rig, subject, dir)
	var labels: Array = await _arm(rig, subject, hit_from)
	if labels.is_empty():
		_ck("%s0 %s has labels to measure" % [tag, what], false)
		return
	var aim_y: float = (labels[0] as Node3D).global_position.y
	var aim_at := Vector3(subject.global_position.x, aim_y,
		subject.global_position.z)

	var lens := Camera3D.new()
	lens.name = "LabelLookdev"
	rig.scene().add_child(lens)

	# --- Behind the wall -----------------------------------------------------
	var far_at := Vector3.ZERO
	var blocker := ""
	var r := FAR_FROM
	while r <= FAR_TO:
		var candidate := PLAZA_AT + dir * r + Vector3(0.0, aim_y, 0.0)
		var hit := _ray(lens, candidate, aim_at)
		if not hit.is_empty():
			far_at = candidate
			blocker = str((hit["collider"] as Node).name)
			# Stand back for a picture, but only as far as the wall still reaches.
			var back := PLAZA_AT + dir * (r + FAR_MARGIN) + Vector3(0.0, aim_y, 0.0)
			if not _ray(lens, back, aim_at).is_empty():
				far_at = back
				r += FAR_MARGIN
			break
		r += FAR_STEP
	_ck("%s0 there is solid geometry between the far lens and %s (%s at %.1f m)"
		% [tag, what, blocker if blocker != "" else "NOTHING FOUND", r],
		far_at != Vector3.ZERO)
	if far_at == Vector3.ZERO:
		lens.queue_free()
		return
	print("LABELS far lens %.1f m out from the plaza, %s in the way"
		% [r, blocker])

	lens.global_position = far_at
	lens.look_at(aim_at)
	lens.make_current()
	await rig.wait_frames(10)

	# **The control, and it is the bug itself.** A zero that came from a label
	# too small to survive the downscale reads exactly like a label the wall
	# correctly hid, which is a way for this whole file to pass while proving
	# nothing. So the pose is photographed twice from one spot: once with the
	# occlusion rule switched off — the setting these cards are about — and once
	# as the game now builds it. The first frame is kept. It is what the defect
	# looked like, and it is the reason the second frame's zero means something.
	#
	# The flag moved with the text. It was `Label3D.no_depth_test = true`, the
	# renderer's own; card #61 put these captions on the HUD canvas, where the
	# depth buffer is not available and the rule is bought back with a ray, so
	# the control is `WorldCaption.occlude = false`. Same claim, same frame, and
	# the file name is kept so the pair still sorts next to its neighbour.
	labels = await _arm(rig, subject, hit_from)
	for l: Node3D in labels:
		_set_occluded(l, false)
	await rig.wait_frames(4)
	var leak := await _read(rig, lens, labels, box,
		out.path_join("l_%s1_behind_wall_no_depth_test.png" % tag), true)
	for l: Node3D in labels:
		_set_occluded(l, true)
	await rig.wait_frames(4)
	print("LABELS %s behind %s, occlusion OFF -> %d px, %s per label"
		% [what, blocker, leak["ink"], leak["per"]])
	_ck("%s1 with occlusion off %s paints the wall (%d px, >= %d)"
		% [tag, what, leak["ink"], READABLE], leak["ink"] >= READABLE)
	_ck("%s2 and every label was framed and in front of the far lens (%d/%d)"
		% [tag, leak["framed"], leak["count"]],
		leak["framed"] == leak["count"])

	labels = await _arm(rig, subject, hit_from)
	var hidden := await _read(rig, lens, labels, box,
		out.path_join("l_%s2_behind_wall.png" % tag), true)
	print("LABELS %s behind %s, as it now builds -> %d px, %s per label"
		% [what, blocker, hidden["ink"], hidden["per"]])
	_ck("%s3 as the game now builds it, NOT ONE pixel of %s reaches the frame "
		% [tag, what] + "(%d)" % hidden["ink"], hidden["ink"] == 0)

	# --- In the open ---------------------------------------------------------
	# Same line, stepped inside the wall. Only the masonry has been taken out of
	# the picture, so this pair is an A/B on the wall and on nothing else.
	lens.global_position = aim_at + dir * NEAR_AT
	lens.look_at(aim_at)
	await rig.wait_frames(10)
	labels = await _arm(rig, subject, hit_from)
	var open := await _read(rig, lens, labels, box,
		out.path_join("l_%s3_line_of_sight.png" % tag), true)
	print("LABELS %s in the open -> %d px, %s per label"
		% [what, open["ink"], open["per"]])
	_ck("%s4 and stepped inside the wall it is readable again (%d px, >= %d)"
		% [tag, open["ink"], READABLE_NEAR], open["ink"] >= READABLE_NEAR)
	# Per-label, not just the total. One label carrying the count while the other
	# sits inside the prop it hangs off is exactly the failure a bare flag flip
	# produces, and it is the reason `POPUP_CLEAR` is in `training_post.gd`.
	var eaten := 0
	for n: int in open["per"]:
		if n < READABLE_NEAR / 2:
			eaten += 1
	_ck("%s5 and no label is swallowed by the prop it hangs off (%s)"
		% [tag, open["per"]], eaten == 0)

	# --- Legibility, which is card #61 and which ink cannot answer -----------
	# Everything above this line was true of the build that shipped the defect:
	# thousands of pixels of ink, all present, none of them readable.
	# `l_%s3_line_of_sight.png` is the frame; look at it, and then read the
	# numbers under it. See `CAP_MIN_PX` for where the floor comes from.
	var frame_h := float(open["frame_h"])
	var floor_px := CAP_MIN_PX * frame_h / 720.0
	for i in labels.size():
		var m: Dictionary = open["metrics"][i]
		if int(m.get("n", 0)) <= 0:
			continue
		var l: Node3D = labels[i]
		var what_i: String = str(l.get(&"text"))
		var raster := _raster_h(l, frame_h)
		var cap: float = float(m["cap"]) * raster / frame_h
		print("LABELS \"%s\" is %.0f px tall on the frame, rasterised in a "
			% [what_i, m["cap"]]
			+ "%.0f px buffer -> %.1f px of cap height (floor %.1f)"
			% [raster, cap, floor_px])
		_ck("%s6 \"%s\" is LEGIBLE and not merely present: %.1f px of cap "
			% [tag, what_i, cap]
			+ "height where §3.1b's floor is %.1f" % floor_px, cap >= floor_px)

	lens.queue_free()
	await rig.wait_frames(4)


## Give the captions their tweened opacity back. See the pin in `_read`.
func _unpin(labels: Array, held: Array) -> void:
	for i in labels.size():
		if held[i] >= 0.0:
			(labels[i] as Node3D).set(&"alpha", held[i])


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("LABELS ok %s" % label)
	else:
		_fails += 1
		print("LABELS FAIL %s" % label)


# --- The measurement ----------------------------------------------------------

## Capture to `path` — the frame a human looks at — and return how many of its
## pixels `labels` actually put there. Lifted from `echo_plates.gd::_read`.
func _read(rig, cam: Camera3D, labels: Array, box: Vector2i,
		path: String, want_per: bool = false) -> Dictionary:
	# Frozen, or the lamps and the damage number's own tween would differ between
	# the pair. Restored in every exit -- a director that leaves `time_scale` at
	# zero hangs every beat after it, on the game clock, for ever.
	# **Every OTHER caption in the room goes down first, and card #61 is what
	# found out why.** The whole method here is "hide the subject and diff", and
	# it silently assumes nothing else is drawn on top of the subject. That
	# assumption was false the entire time and no frame could show it: the
	# director arms a keeper by calling `on_focus(true)` straight, while `Prompt`
	# independently focuses whoever the parked hero is nearest, so TWO signs were
	# up — and as `Label3D`s they overlapped into one smear that read as a single
	# blurred caption. Drawn sharp on the canvas they are plainly two words in
	# the same place, and the diff was measuring one of them against the other.
	# The frames are cleaner for it too: a shot of the keeper's sign should have
	# the keeper's sign in it.
	var muted: Array[Node] = []
	for n in rig.get_nodes_in_group(&"world_caption"):
		var other := n as Node3D
		if other == null or labels.has(other) or not other.visible:
			continue
		other.visible = false
		muted.append(other)
	if not muted.is_empty():
		await rig.wait_frames(2)

	var prev := Engine.time_scale
	Engine.time_scale = 0.0

	# **Full opacity for the measurement, and the tween is what makes this
	# necessary.** A damage number lives 0.85 s and fades out over all of it, so
	# a frozen frame catches it at whatever alpha the clock happened to stop at
	# — measured across three runs of this file: mush 0.062, 0.077 and 0.448 for
	# the same digit, because a caption at 30% opacity has a luminance range too
	# narrow for anything to sit at either end of it, and correctly reads as
	# mush. That is a true statement about a caption on its way out and a
	# useless one about the caption's legibility, which is a property of the
	# glyph and is asked at the strength a player reads it at.
	#
	# Set AFTER the freeze and restored BEFORE it is lifted: at `time_scale = 0`
	# the tween does not advance, so the pinned value survives the capture and
	# the tween picks up its own value again when the clock starts.
	var held: Array[float] = []
	for l: Node3D in labels:
		# A `Label3D` has no `alpha` and does not fade, so it is left alone and
		# recorded as -1. This file runs against both builds (`_labels_under`).
		var a = l.get(&"alpha")
		held.append(float(a) if a != null else -1.0)
		if a != null:
			l.set(&"alpha", 1.0)

	await rig.wait_frames(2)
	await rig.capture(path)
	var lit := Image.load_from_file(path)
	if lit == null:
		_unpin(labels, held)
		Engine.time_scale = prev
		for o: Node3D in muted:
			o.visible = true
		print("LABELS could not re-read %s" % path)
		return {"ink": -1, "framed": 0, "count": labels.size(), "per": [],
			"metrics": [], "frame_h": 720}

	# Where each label lands on the picture. The count is taken INSIDE these
	# boxes and nowhere else: `Engine.time_scale` freezes the world but not the
	# HUD, which runs off the wall clock, and a whole-frame diff scores a vitals
	# bar ticking between the pair as hundreds of pixels of caption.
	var view: Vector2 = cam.get_viewport().get_visible_rect().size
	var scale := Vector2(lit.get_size()) / view
	var boxes: Array[Rect2i] = []
	var framed := 0
	for l: Node3D in labels:
		if cam.is_position_behind(l.global_position):
			boxes.append(Rect2i())
			continue
		var at := Vector2i(cam.unproject_position(l.global_position) * scale)
		var b := Rect2i(at - box, box * 2)
		# Half a label off the edge of the picture is not evidence either way,
		# and silently counting the half that is left would let a beat pass on a
		# badly framed shot. Framing is asked of the CAMERA, not of the picture.
		if not Rect2i(Vector2i.ZERO, lit.get_size()).encloses(b):
			boxes.append(Rect2i())
			continue
		boxes.append(b)
		framed += 1

	var total: Dictionary = await _moved(rig, lit, labels, path, labels, boxes)
	var per: Array[int] = []
	var metrics: Array[Dictionary] = []
	if want_per:
		for i in labels.size():
			var m: Dictionary = await _moved(rig, lit, [labels[i]], path, labels,
				[boxes[i]])
			per.append(int(m["n"]))
			metrics.append(m)
	_unpin(labels, held)
	Engine.time_scale = prev
	for o: Node3D in muted:
		o.visible = true
	await rig.wait_frames(2)
	return {"ink": int(total["n"]), "framed": framed, "count": labels.size(),
		"per": per, "metrics": metrics, "frame_h": lit.get_size().y}


## Hide `hide_these`, re-photograph the frozen pose, and report the pixels inside
## `boxes` that changed against `lit`. `all` is restored visible afterwards.
## The reference frames are written beside `path` and deleted: they exist only to
## be subtracted, and a directory of near-identical PNGs is one nobody looks at.
##
## Returns `n` — the ink count every beat above card #61 reads — plus the two
## numbers card #61 added:
##
##  * `cap` — the height of the ink's bounding box, in pixels, after the
##    surround is taken off. For a caption that is the cap height of its
##    capitals, which is the unit `docs/STYLEGUIDE.md` §3.1b's ladder is written
##    in, so it can be compared against the 10 px floor directly.
##  * `mush` — of the pixels the caption put inside that rectangle, the fraction
##    landing between a quarter and three quarters of the way up its own
##    luminance range. See `MUSH_MAX`.
##
## The range is taken as the 5th and 95th percentiles rather than min and max: a
## single specular pixel off a lamp inside the box would otherwise set the top of
## the scale and drag every glyph pixel into the middle band, and one such pixel
## is enough to make this whole measurement meaningless.
func _moved(rig, lit: Image, hide_these: Array, path: String,
		all: Array, boxes: Array) -> Dictionary:
	for l: Node3D in hide_these:
		l.visible = false
	await rig.wait_frames(2)
	var ref := path.get_basename() + ".ref.png"
	await rig.capture(ref)
	var bare := Image.load_from_file(ref)
	DirAccess.remove_absolute(ref)
	for l: Node3D in all:
		l.visible = true
	await rig.wait_frames(2)
	if bare == null or bare.get_size() != lit.get_size():
		return {"n": -1, "cap": 0.0}

	# Pass one: which pixels moved, and how far the ink reaches.
	var moved: Array[Vector2i] = []
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-1, -1)
	for b: Rect2i in boxes:
		if b.size == Vector2i.ZERO:
			continue
		for y in range(b.position.y, b.end.y):
			for x in range(b.position.x, b.end.x):
				var p := lit.get_pixel(x, y)
				var q := bare.get_pixel(x, y)
				if absf(p.r - q.r) > INK_DELTA or absf(p.g - q.g) > INK_DELTA \
						or absf(p.b - q.b) > INK_DELTA:
					moved.append(Vector2i(x, y))
					lo = lo.min(Vector2i(x, y))
					hi = hi.max(Vector2i(x, y))
	if moved.is_empty():
		return {"n": 0, "cap": 0.0}

	# The letters only. The bounding box of the ink includes whatever the caption
	# wears round its edge — §5.7's plate on a `WorldCaption`, an outline on the
	# `Label3D`s that came before — and a plate's pad is not type. See
	# `CAP_INSET_PX`, including why under-insetting is the safe direction.
	var inset := int(round(CAP_INSET_PX * float(lit.get_size().y) / 720.0))
	var cap := float(hi.y - lo.y + 1 - inset * 2)
	return {"n": moved.size(), "cap": maxf(cap, 0.0)}


## Is there world geometry between `from` and `to`? `K.L_WORLD` only: the
## question is whether a WALL is in the way, and a keeper's own capsule or the
## post's hurtbox answering yes would be this file fooling itself.
func _ray(node: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var space := node.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, K.L_WORLD)
	return space.intersect_ray(q)


# --- Fixture ------------------------------------------------------------------

## Put the subject's labels back on it, and hand back exactly the ones to measure.
##
## **Both of these labels are transient and that is the whole reason this exists.**
## A keeper's sign is raised by `Prompt` and dropped again the moment focus
## leaves. A damage number lives 0.85 s and then frees itself, and the post's
## running readout blanks after `readout_reset` seconds of no hits — so a beat
## that measured the pose it photographed four beats ago would be measuring an
## empty post and calling the zero a success.
##
## Stale numbers are freed rather than left: two of them overlap, and per-label
## ink counted through another label's outline is not a number about either.
func _arm(rig, subject: Node3D, hit_from: Vector3) -> Array:
	if hit_from == Vector3.ZERO:
		subject.call(&"on_focus", true)
		await rig.wait_frames(4)
		return _labels_under(subject)

	# The readout is built in `_build` and outlives every strike; anything else
	# under the post is a damage number from a previous beat.
	var found := _labels_under(subject)
	for i in range(1, found.size()):
		(found[i] as Node).queue_free()
	await rig.wait_frames(3)
	subject.call(&"strike", 3, hit_from)
	await rig.wait_frames(3)
	return _labels_under(subject)


## Stand the hero next to the subject, square to the camera line.
##
## **This is card #61's, and the file was wrong without it in a way that only
## showed up once the captions were sharp enough to look at.** A `WorldCaption`
## fades out past `max_range` — 18 m, measured from the HERO, the same bargain
## `Hud.EBAR_RANGE` makes for a monster's health bar, and for the same reason: a
## caption that does not shrink with distance has to be taken off the screen
## rather than made smaller, or the yard fills with floating names (§7.10).
##
## This file used to park the hero in the north-west quarter and leave him
## there, which put him 16.8 m from the jewelcrafter — three metres inside the
## fade — so every caption it photographed was drawn at about 40% opacity. The
## PIXELS were all there and every count passed. The plate was a faint wash, the
## ink was grey rather than BONE, and the legibility measurement read it as
## mush, correctly. That is the same class of mistake as the one this card is
## about: a number that goes up when the thing is present, and says nothing
## about whether it is any good.
##
## 2.6 m, perpendicular to the radial both lenses stand on, so he is at reading
## distance and off both camera lines. The far lens looks through the wall at a
## subject the hero is standing beside; that is exactly the frame the claim
## wants, because the wall is being asked to hide a caption from a camera and
## NOT from the player.
func _park_beside(rig, subject: Node3D, dir: Vector3) -> void:
	var hero: Node3D = _hero(rig)
	if hero == null:
		return
	var side := Vector3(-dir.z, 0.0, dir.x)
	hero.velocity = Vector3.ZERO
	hero.global_position = subject.global_position + side * 2.6 \
		+ Vector3(0.0, 0.15, 0.0)
	await rig.wait_physics_frames(6)
	await rig.wait_frames(10)


## The direction to walk out from the yard's middle past a subject, flattened.
## Every camera in this file is placed along one of these, so the far lens and
## the near lens differ only by the wall between them.
func _radial(subject: Node3D) -> Vector3:
	var d := K.flat(subject.global_position - PLAZA_AT)
	return d.normalized() if d != Vector3.ZERO else Vector3.FORWARD


## Whichever ring keeper this save has. `tools/shoot.gd` stamps the arrival flags
## so a director gets all of them, but the roster is `StoryDb.UNLOCKS`' business
## and not this file's, so it takes the first one that turned up rather than
## naming a shop and failing when the story moves.
func _a_keeper(g: Node3D) -> Node3D:
	for field in ["jeweller", "smith", "vendor", "alchemist", "keeper"]:
		var n: Node3D = g.get(field)
		if n != null and n.has_method(&"on_focus"):
			return n
	return null


## A training post in the yard, hit-ready. Built here rather than found because
## the garrison has never had one -- `scenes/rooms/training.tscn` is where posts
## live, and that room is an open proving ground with no wall in it to be hidden
## behind. `load` and not `preload`: preloading a script that names an autoload
## takes the harness down before the autoloads exist.
func _stand_a_post(g: Node3D) -> Node3D:
	var packed := load("res://scenes/props/training_post.tscn") as PackedScene
	if packed == null:
		return null
	var p := packed.instantiate() as Node3D
	var b := deg_to_rad(POST_BEARING)
	p.name = "LabelPost"
	p.position = PLAZA_AT + Vector3(sin(b), 0.0, -cos(b)) * POST_R
	g.add_child(p)
	return p


## The captions hanging off `root`, in build order.
##
## **Both kinds, on purpose.** Card #61 moved these three onto the HUD canvas as
## `WorldCaption`s, and the obvious edit here was to look for that class alone —
## which would have made this file silently find nothing on the build it was
## written to fail. It finds `Label3D`s too, so that pointing it at the commit
## before #61, or at a caption somebody puts back in the world, produces a named
## failure at beat 6 rather than an empty run. Every other beat is written
## against whichever kind it got: see `_set_occluded` and `_raster_h`.
func _labels_under(root: Node) -> Array:
	var found: Array = []
	for n in _all(root):
		if n is WorldCaption or n is Label3D:
			found.append(n)
	return found


## Turn a caption's occlusion rule on or off, whichever build this is.
##
## `Label3D.no_depth_test` is the renderer's own flag and the one cards #26 and
## #37 are about; `WorldCaption.occlude` is the line-of-sight ray that replaced
## it when card #61 moved the text off the depth buffer and onto the canvas. The
## claim being controlled for is identical, so one call site should not have to
## know which it is holding.
func _set_occluded(l: Node3D, on: bool) -> void:
	if l is WorldCaption:
		(l as WorldCaption).occlude = on
	elif l is Label3D:
		(l as Label3D).no_depth_test = not on


## The height of the buffer this caption's glyphs were RASTERISED in.
##
## The frame's own height for a `WorldCaption`, which is drawn on the HUD canvas
## after §4.5's present pass and is therefore 1:1 with the picture. 270 for a
## `Label3D`, which is world geometry and goes through the internal buffer with
## the masonry — unless the pipeline is off, in which case the world is drawn at
## the frame's height and so was the glyph.
##
## This is the divisor beat 6 turns fourteen pixels of frame into five pixels of
## type with, and it is the only part of that measurement that is not read off
## the picture. It is knowledge the frame cannot carry: a 2.67x upscale of a
## five-pixel glyph and a fourteen-pixel glyph occupy the same rectangle, which
## is exactly why a count of ink could not tell them apart for a whole card.
func _raster_h(l: Node3D, frame_h: float) -> float:
	if l is WorldCaption:
		return frame_h
	if not bool(Settings.internal_render):
		return frame_h
	return INTERNAL_H


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found
