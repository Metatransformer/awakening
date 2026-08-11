extends RefCounted
## Card #37 — **the last three world labels stop at the first wall.**
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
## What it claims, in the order it proves them:
##
##   A  A keeper stands in the yard with their sign up, and a training post
##      stands in the yard having just been hit, so a readout and a damage
##      number are on it.
##   B  From a camera OUTSIDE the curtain wall, on the keeper's own radial, with
##      masonry proved to be in the way by a ray cast down the camera's line:
##      with `no_depth_test` put back the name paints the wall, and as the game
##      now builds it **not one of its pixels reaches the picture.** Both frames
##      are kept — the first one is what the defect looked like.
##   C  Stepped back inside the yard, on the same line, the name is readable.
##   D  The same pair for the post's readout and its damage number, measured one
##      label at a time.
##   E  And from a lookdev lens with nothing in shot but the post, both labels
##      are whole — the damage number in particular is NOT swallowed by the straw
##      bundle it stands on. That is the half a bare `no_depth_test = false`
##      would have got wrong, and it is why `POPUP_CLEAR` exists: every damage
##      number this post has ever drawn was built INSIDE the bundle, at 1.62 m
##      inside a cylinder spanning 1.20 m to 1.75 m, and the flag was hiding it.
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

	# The hero is parked in the north-west quarter and left there. He is not the
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
	# nothing. So the pose is photographed twice from one spot: once with
	# `no_depth_test` forced back ON — the setting this card is about — and once
	# as the game now builds it. The first frame is kept. It is what the defect
	# looked like, and it is the reason the second frame's zero means something.
	labels = await _arm(rig, subject, hit_from)
	for l: Node3D in labels:
		l.no_depth_test = true
	await rig.wait_frames(4)
	var leak := await _read(rig, lens, labels, box,
		out.path_join("l_%s1_behind_wall_no_depth_test.png" % tag), true)
	for l: Node3D in labels:
		l.no_depth_test = false
	await rig.wait_frames(4)
	print("LABELS %s behind %s, no_depth_test ON -> %d px, %s per label"
		% [what, blocker, leak["ink"], leak["per"]])
	_ck("%s1 with `no_depth_test` %s paints the wall (%d px, >= %d)"
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

	# --- The counterfactual --------------------------------------------------
	# **`POPUP_CLEAR` measured rather than asserted.** The damage number used to
	# be built at `post_height * 0.9` with a jitter that never took it outside the
	# straw bundle, and `no_depth_test` was the only reason anybody ever saw a
	# whole one. Put it back where it used to be, from the same lens, and count:
	# if the number does not drop, the constant is dead weight and should come
	# out. The jitter's MIDDLE is used, because the jitter only ever moved the
	# label around inside the same cylinder.
	#
	# **What "swallowed" turns out to mean here, and it is not what the arithmetic
	# predicted.** The bundle does not hide the digit; it CUTS IT IN HALF. The
	# label's centre is 1.62 m and the bundle caps at 1.75 m, so the glyph stands
	# in the straw with its top emerging over the rim — measured at 253 px against
	# 357 at `POPUP_CLEAR`, which is the bottom of a "3" gone and reads on the
	# frame as a digit sawn through at the waist. So this is a 0.85 bound and not
	# the "a third or less" one it was written as: the honest claim is a
	# measurable bite out of every damage number, not an invisible one. The
	# `l_p4_...` frame beside `l_p3_...` is the pair to look at.
	if hit_from != Vector3.ZERO and labels.size() > 1:
		var number: Node3D = labels[1]
		var kept := number.position
		number.position = Vector3(0.0, subject.get(&"post_height") * 0.9, 0.0)
		await rig.wait_frames(4)
		var old := await _read(rig, lens, [number], box,
			out.path_join("l_%s4_number_where_it_used_to_be.png" % tag))
		number.position = kept
		await rig.wait_frames(4)
		print("LABELS the damage number at its OLD offset -> %d px, against "
			% old["ink"] + "%d at POPUP_CLEAR" % open["per"][1])
		_ck("%s6 and where it used to be built the bundle takes a bite out of "
			% tag + "it: %d px against %d" % [old["ink"], open["per"][1]],
			float(old["ink"]) < float(open["per"][1]) * 0.85)

	lens.queue_free()
	await rig.wait_frames(4)


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
	var prev := Engine.time_scale
	Engine.time_scale = 0.0
	await rig.wait_frames(2)
	await rig.capture(path)
	var lit := Image.load_from_file(path)
	if lit == null:
		Engine.time_scale = prev
		print("LABELS could not re-read %s" % path)
		return {"ink": -1, "framed": 0, "count": labels.size(), "per": []}

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

	var total := await _moved(rig, lit, labels, path, labels, boxes)
	var per: Array[int] = []
	if want_per:
		for i in labels.size():
			per.append(await _moved(rig, lit, [labels[i]], path, labels,
				[boxes[i]]))
	Engine.time_scale = prev
	await rig.wait_frames(2)
	return {"ink": total, "framed": framed, "count": labels.size(), "per": per}


## Hide `hide_these`, re-photograph the frozen pose, and count the pixels inside
## `boxes` that changed against `lit`. `all` is restored visible afterwards.
## The reference frames are written beside `path` and deleted: they exist only to
## be subtracted, and a directory of near-identical PNGs is one nobody looks at.
func _moved(rig, lit: Image, hide_these: Array, path: String,
		all: Array, boxes: Array) -> int:
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
		return -1
	var n := 0
	for b: Rect2i in boxes:
		if b.size == Vector2i.ZERO:
			continue
		for y in range(b.position.y, b.end.y):
			for x in range(b.position.x, b.end.x):
				var p := lit.get_pixel(x, y)
				var q := bare.get_pixel(x, y)
				if absf(p.r - q.r) > INK_DELTA or absf(p.g - q.g) > INK_DELTA \
						or absf(p.b - q.b) > INK_DELTA:
					n += 1
	return n


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


func _labels_under(root: Node) -> Array:
	var found: Array = []
	for n in _all(root):
		if n is Label3D:
			found.append(n)
	return found


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found
