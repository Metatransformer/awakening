extends RefCounted
## **Combinator 8 — convert** (`docs/PUZZLES.md` §3.1, priced in §8.1), rendered
## and asserted. The arrow that catches fire.
##
## The room is one sentence: a frozen eye switch on the north wall, a lantern
## standing on the sight line to it, and a hero seven metres back with a bow. The
## direct shot bounces off the ice. Light the lantern, shoot *through* it, and the
## same arrow arrives as something else and the eye opens.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_atom_test.tscn \
##     --director=res://tools/directors/convert_arrow.gd \
##     --out=/tmp/convert/x.png --warmup=60
##
## Prints `CONVERT FAIL …` on any beat that did not happen.
##
## ## What is being claimed, and why each beat is here
##
##   A  The room builds: a frozen eye, a plain eye beside it as the control, and
##      a lantern on the line. Photographed cold — a frozen eye that looks
##      exactly like a plain one is a puzzle with no question in it, so the two
##      stand in the same frame on purpose.
##   B  **A DARK lantern converts nothing.** The arrow crosses the flame volume
##      and comes out the far side still `Hit.ARROW`; the frozen eye refuses it.
##      This is the beat that makes the puzzle a puzzle — without it the lantern
##      is scenery on the way to an eye that opens anyway.
##   C  The control: a plain arrow opens a PLAIN eye. If this fails, nothing
##      below means anything, because the bow itself is broken.
##   D  A blow lights the lantern. Its own verb (`docs/PUZZLES.md` §2, *any
##      blow*), through `apply_hit`, which is the one damage path.
##   E  The same shot again, and now it converts mid-flight and the eye OPENS.
##      Photographed on both sides of the flame from one fixed camera at
##      gameplay distance — that pair of frames is the real deliverable, because
##      the colour change is the only way a player ever learns this rule.
##   F  The refusal names the verb, and it reaches the DOOR. A gate wearing a
##      frozen eye that says "THE EYE IS SHUT" is telling the player to do the
##      thing they just did.
##   G  A burning arrow still opens a plain eye. Fire is a longer sentence in the
##      same word, not a different word.
##
## ## Why the arrow is launched rather than loosed from the bow
##
## `Arrow.launch()` is the real projectile on the real raycast — it is the exact
## call `HeroRanged._release_arrow` makes, one line down from the ammo spend, and
## every part of this mechanic (the convert probe, the rewrite, the plume, the
## blow that lands) is downstream of it. What launching skips is the bow's two
## clips and the camera aim, and those are already the whole subject of
## `bow_charge_release.gd` and `ranged_kit.gd`. Driving them again here would put
## the beat that can fail — *did the arrow change in the air* — behind a
## crosshair the director has to steer onto a 0.34 m pupil at seven metres.
##
## ## Why the clock is slowed
##
## `K.ARROW_SPEED` is 42 m/s: the whole 7.4 m flight is ten frames, and grabbing
## a 1280x720 backbuffer costs more than one of them. At `SLOW` the same shot,
## unchanged in every other way, is slow enough to photograph at a chosen point
## on the line — which is the only way the two A/B frames can be taken from the
## same camera at the same place on the same trajectory.

## Engine time scale during a shot. Same trick, same reason, as
## `bow_charge_release.gd`: this slows the flight, not the arrow's physics.
const SLOW := 0.12

## Where everything stands. The proving ground's clear rectangle is roughly
## x in [-8.5, 1], z in [-4.5, 4] (see `puzzle_atoms.gd`'s own plan note); all of
## this lives inside it.
const EYE_FROZEN := Vector3(-4.0, 2.05, -4.2)
const EYE_PLAIN := Vector3(-6.8, 2.05, -4.2)
const LANTERN_AT := Vector3(-4.0, 0.02, -1.0)
const HERO_AT := Vector3(-4.0, 0.02, 3.2)

## Height the shot leaves from. A bow is held about here on a 1.65 m hero
## (`HeroRanged._muzzle` falls back to `K.HERO_EYE_Y` + a little), and it matters
## that this is a plausible muzzle rather than a convenient one: the whole aiming
## question of the puzzle is whether the line from a real firing height to a real
## wall eye passes through the flame.
const MUZZLE_Y := 1.35

## Marks on the line the two A/B frames are taken at, in z. One clearly BEFORE
## the lantern and one clearly after it, and both used for both shots, so the
## plain and the burning arrow are photographed at the same two places from the
## same lens. Anything else is comparing two pictures of different things.
const MARK_BEFORE := 1.2
const MARK_AFTER := -2.6

## Where the beats that only ask a question of the KIND CHECK stand their props:
## far enough out of the chamber to be out of every frame, and still in the tree,
## because an atom that never reached `_ready` has never built its lids and
## `on_solved()`'s tween would be created on a node outside the scene.
const OFFSTAGE := Vector3(0.0, 0.0, 60.0)

var out := ""
var _fails := 0
var _hero: Node3D
var _gate: Node
var _eye_frozen: Node3D
var _eye_plain: Node3D
var _lantern: Node3D
var _cam: Camera3D
var _cam_side: Camera3D
## The arrow's kind as last seen IN FLIGHT. Read off the projectile every frame
## of `_shoot` rather than after it lands, because an arrow that lands on
## something damageable frees itself on the same frame -- asserting on the
## wreckage would be asserting on `null` and passing for the wrong reason.
var _last_kind: StringName = &""
## Mark (z) -> the kind the arrow was carrying as it crossed it. The two-sided
## reading beat E is made of.
var _kind_at: Dictionary = {}


func run(rig) -> void:
	out = rig.arg("out", "/tmp/convert/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# A run, so the atom flags start clean. A director inheriting a previous
	# session's flags would find the eye already open and prove nothing.
	Run.enter(90210)

	_hero = rig.scene().get_node_or_null(^"Hero") as Node3D
	_gate = rig.scene().get_node_or_null(^"Gate")
	if _hero == null or _gate == null:
		print("CONVERT FAIL the fixture is missing the hero or the gate")
		return

	_a_build(rig)
	# `PuzzleAtom._offer` is DEFERRED, so adoption has not happened yet on the
	# frame the props were added -- checking it inside `_a_build` would fail for
	# a reason that has nothing to do with tags.
	await rig.wait_physics_frames(10)
	# The frozen eye carries the fixture gate's `puzzle_id`, so the door in the
	# north doorway is standing on this puzzle. Beat B asks it what it says.
	var watched: Array = _gate.call(&"atoms")
	_ck("the gate adopted the frozen eye by tag (%d)" % watched.size(),
		watched.size() == 1)
	await _frame(rig, "01_room_cold.png")

	await _b_dark_lantern(rig)
	await _c_control(rig)
	await _d_light(rig)
	await _e_convert(rig)
	await _f_refusal(rig)
	await _g_fire_opens_plain(rig)

	if _fails == 0:
		print("CONVERT OK the lit lantern rewrites the shot and the ice lets it in")
	else:
		print("CONVERT FAIL %d checks failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("CONVERT FAIL %s" % label)


# --- A. The room --------------------------------------------------------------

func _a_build(rig) -> void:
	# Through `PuzzleAtoms.make()`, which is the call a generator makes. A
	# director that instanced the scripts by hand would be testing the props and
	# nothing about the kit being able to place them.
	# Tagged with the fixture gate's own `puzzle_id`, so the door in the north
	# doorway adopts it and beat F can ask what the DOOR says rather than what the
	# prop holds in a field. That is not decoration: `PuzzleGate.refusal_line`
	# used to compose its line off the static table, which meant a variant's
	# overridden `refusal()` could never be heard (CLAUDE.md §3, static dispatch).
	_eye_frozen = PuzzleAtoms.make(PuzzleAtoms.EYE_SWITCH, &"demo")
	_eye_frozen.name = "FrozenEye"
	# **Before the tree.** `_build()` runs from `_ready` and the crust is
	# geometry; set after `add_child` this is a plain-looking eye that refuses
	# plain arrows, which is the worst version of this prop (EyeSwitch's note).
	_eye_frozen.set(&"frozen", true)
	_eye_frozen.position = EYE_FROZEN
	# Built looking down -Z, so a half-turn faces it back at the hero, who is at
	# +Z. `EyeSwitch`'s construction note; CLAUDE.md §4.
	_eye_frozen.rotation.y = PI
	rig.scene().add_child(_eye_frozen)

	_eye_plain = PuzzleAtoms.make(PuzzleAtoms.EYE_SWITCH, &"")
	_eye_plain.name = "PlainEye"
	_eye_plain.position = EYE_PLAIN
	_eye_plain.rotation.y = PI
	rig.scene().add_child(_eye_plain)

	_lantern = PuzzleAtoms.make(PuzzleAtoms.LANTERN, &"")
	_lantern.name = "LineLantern"
	_lantern.position = LANTERN_AT
	rig.scene().add_child(_lantern)

	_ck("the room built (frozen eye, plain eye, lantern)",
		_eye_frozen != null and _eye_plain != null and _lantern != null)
	_ck("the frozen eye wears the ice", _eye_frozen.get(&"frozen") == true
		and _eye_frozen.get_node_or_null(^"Rime") != null)
	_ck("the plain eye does not", _eye_plain.get_node_or_null(^"Rime") == null)
	_ck("the lantern starts dark", not bool(_lantern.call(&"is_solved")))
	# The lantern is a lantern and not a new prop -- §8.1's ceiling, asserted
	# rather than believed. Nine rows, and none of them is "frozen eye".
	_ck("the kit is still nine atoms (PUZZLES.md §8's ceiling)",
		PuzzleAtoms.all().size() == 9 and PuzzleAtoms.validate().is_empty())

	_hero.global_position = HERO_AT
	_hero.set(&"velocity", Vector3.ZERO)
	_hero.set(&"facing_yaw", PI)

	# One fixed camera for every frame this director takes. Fixed because the two
	# A/B stills are only a comparison if the lens has not moved between them, and
	# ~10 m out because that is the range the player actually reads this puzzle
	# from -- the lantern is 4.2 m ahead of the hero and the eye 7.4 m.
	#
	# **Held well off the firing line, and that is not framing taste.** The first
	# pass put it over the hero's shoulder, which is the natural place for it and
	# is exactly wrong here: the camera, the lantern and the arrow are COLLINEAR by
	# construction — the whole puzzle is that they are — so the lantern stands
	# directly in front of every arrow that has just passed through it, and the
	# money frame came back with the subject hidden behind the prop that converted
	# it. 3.2 m of lateral offset opens the parallax that lets the shot be seen.
	_cam = Camera3D.new()
	_cam.name = "ConvertCam"
	_cam.fov = 60.0
	_cam.position = Vector3(-0.8, 1.95, 6.6)
	rig.scene().add_child(_cam)
	_cam.look_at(Vector3(-4.0, 1.95, MARK_AFTER), Vector3.UP)
	_cam.make_current()

	# And a second lens, broadside to the flight, for the same instants. The
	# gameplay camera answers "would a player notice"; this one answers "what is
	# it", and a director that only shipped the first cannot tell a plume that is
	# too small from a plume that is behind something.
	_cam_side = Camera3D.new()
	_cam_side.name = "ConvertSideCam"
	_cam_side.fov = 50.0
	rig.scene().add_child(_cam_side)


# --- The shot -----------------------------------------------------------------

## Loose one arrow at `target` and photograph it crossing `marks`.
##
## Returns the arrow, still in the tree if it has not landed yet. The caller owns
## what it asserts about it -- this only flies it and takes the pictures.
func _shoot(rig, target: Vector3, marks: Array, tag: String) -> void:
	var from := _hero.global_position + Vector3.UP * MUZZLE_Y
	var arrow := Arrow.new()
	arrow.name = "DirectorArrow"
	# Parented to the scene, exactly as `HeroRanged._release_arrow` does it: an
	# arrow under the hero inherits his yaw and his 1.65 scale.
	rig.scene().add_child(arrow)
	arrow.launch(from, _aim(from, target), _hero as CollisionObject3D)
	_last_kind = arrow.kind()
	_kind_at.clear()

	var prev := Engine.time_scale
	Engine.time_scale = SLOW
	var pending := marks.duplicate()
	# A wall-clock watchdog, not a measurement: an arrow that never reaches a
	# mark (because it stuck in something on the way) must not hang the harness.
	var deadline := Time.get_ticks_msec() + 20000
	while not pending.is_empty() and is_instance_valid(arrow) \
			and Time.get_ticks_msec() < deadline:
		await rig.wait_frames(1)
		if not is_instance_valid(arrow):
			break
		_last_kind = arrow.kind()
		var z: float = arrow.global_position.z
		var mark: float = pending[0]
		if z <= mark:
			pending.remove_at(0)
			_kind_at[mark] = _last_kind
			await _both_lenses(rig, arrow, "%s_z%+0.1f" % [tag, mark])
	Engine.time_scale = prev
	if not pending.is_empty():
		_ck("%s reached every mark (%d missed)" % [tag, pending.size()], false)


## The same instant from both lenses. The arrow moves 8 cm between them at
## `SLOW`, which is a tenth of its own length -- close enough that the pair is
## one moment rather than two.
func _both_lenses(rig, arrow: Arrow, stem: String) -> void:
	_cam.make_current()
	await rig.capture("%s_far.png" % stem)
	if not is_instance_valid(arrow):
		return
	# Broadside, 2.8 m off, level with the shaft. Placed per shot rather than
	# fixed because the whole point of it is to be square on to wherever the arrow
	# has got to.
	var at := arrow.global_position
	_cam_side.global_position = at + Vector3(2.8, 0.15, 0.0)
	_cam_side.look_at(at, Vector3.UP)
	_cam_side.make_current()
	await rig.wait_frames(1)
	await rig.capture("%s_near.png" % stem)
	_cam.make_current()


## Aim so the shot ARRIVES at `target`, gravity included.
##
## `K.ARROW_GRAVITY` is 6.0, which over a 7.4 m flight is nearly nine centimetres
## of drop -- more than the pupil is wide. Aimed straight at the eye the arrow
## lands under it, and that miss would look exactly like the convert having
## failed. Two passes of the standard first-order lead is well inside a pixel at
## this range.
func _aim(from: Vector3, target: Vector3) -> Vector3:
	var lift := 0.0
	for i in 2:
		var to := (target + Vector3.UP * lift) - from
		var t := to.length() / K.ARROW_SPEED
		lift = 0.5 * K.ARROW_GRAVITY * t * t
	return ((target + Vector3.UP * lift) - from).normalized()


# --- B. A dark lantern converts nothing ---------------------------------------

## **The beat that makes it a puzzle.** The arrow flies the whole line, crosses
## the dark lantern's volume, and is still a plain arrow on the far side.
##
## Asserted on the far-side mark and not merely on the outcome: an arrow that
## missed the volume entirely would also fail to convert and would also be
## refused, and those two are indistinguishable from the eye's end. The frame
## taken at MARK_AFTER is what shows the shot went where it was supposed to.
func _b_dark_lantern(rig) -> void:
	await _shoot(rig, EYE_FROZEN, [MARK_BEFORE, MARK_AFTER], "02_dark")
	_ck("a shot past a DARK lantern is still a plain arrow (%s)" % _last_kind,
		_last_kind == Hit.ARROW)
	await rig.wait_seconds(0.6)
	_ck("and the ice refuses it -- the frozen eye stays shut",
		not bool(_eye_frozen.call(&"is_solved")))
	# **What the DOOR says, at the moment it is the question.**
	#
	# `PuzzleGate.refusal_line` used to compose its line off the static table, so
	# a variant's overridden `refusal()` was written, correct, and unreachable --
	# CLAUDE.md §3's static-dispatch row. The door onto a frozen eye said "THE EYE
	# IS SHUT" to a player who had just put an arrow in it, which is the exact
	# failure GDD pillar 3 forbids, and no assertion made on the PROP can see it.
	var said: String = _gate.call(&"refusal_line")
	_ck("and the door names the verb rather than the state: \"%s\"" % said,
		said == "THE ICE WANTS A LIT ARROW")
	_ck("the gate is shut", not bool(_gate.call(&"is_open")))
	await _frame(rig, "03_ice_refused.png")


# --- C. The control -----------------------------------------------------------

## A plain arrow opens a PLAIN eye. Without this beat every failure below is
## ambiguous between "convert is broken" and "the bow is broken".
func _c_control(rig) -> void:
	await _shoot(rig, EYE_PLAIN, [MARK_AFTER], "04_control")
	_ck("and it was never converted -- no lantern on that line (%s)" % _last_kind,
		_last_kind == Hit.ARROW)
	await rig.wait_seconds(0.6)
	_ck("the control: a plain arrow opens a plain eye",
		bool(_eye_plain.call(&"is_solved")))


# --- D. Light it --------------------------------------------------------------

## Its own verb: any blow, through `apply_hit`, which is the one damage path
## (`docs/CONTRACT.md` §8). Not `solve()` -- a lantern that reports lit when told
## to proves nothing about the prop the player swings at.
func _d_light(rig) -> void:
	_lantern.call(&"apply_hit", Hit.make(K.HEALTH_POINT,
		_lantern.global_position + Vector3.BACK, Hit.ARROW, 0.0, 0.0, &"DIRECTOR"))
	await rig.wait_seconds(0.5)
	_ck("a blow lights the lantern", bool(_lantern.call(&"is_solved")))
	_ck("and a LIT lantern offers the fire",
		StringName(_lantern.call(&"convert_kind")) == Hit.ARROW_FIRE)
	await _frame(rig, "05_lantern_lit.png")


# --- E. Shoot through it ------------------------------------------------------

## The whole card, in one shot. Same hero, same mark, same eye, same lens as beat
## B -- the ONLY thing different is that the lantern is lit.
func _e_convert(rig) -> void:
	# Read on BOTH sides of the flame, off one arrow. "It was on fire" is only the
	# mechanic if it was not on fire when it left the bow, and the pair of frames
	# taken at these two marks is the same claim made to the eye.
	await _shoot(rig, EYE_FROZEN, [MARK_BEFORE, MARK_AFTER], "06_lit")
	_ck("short of the lantern it was still a plain arrow (%s)"
		% _kind_at.get(MARK_BEFORE, &"?"),
		_kind_at.get(MARK_BEFORE, &"") == Hit.ARROW)
	_ck("past the flame it is a BURNING arrow (%s)" % _kind_at.get(MARK_AFTER, &"?"),
		_kind_at.get(MARK_AFTER, &"") == Hit.ARROW_FIRE)
	await rig.wait_seconds(0.8)
	_ck("and the ice takes it -- the frozen eye OPENS",
		bool(_eye_frozen.call(&"is_solved")))
	# The crust has to go with it. An eye that opens behind its own ice is an eye
	# the player cannot tell they solved.
	_ck("the rime is gone, not merely hidden",
		_eye_frozen.get_node_or_null(^"Rime") == null)
	# The atom is a body that emits `solved` and a door that listens
	# (`docs/PUZZLES.md` §2). Convert changes what answers the eye and nothing
	# about that contract, and this is the line that says so.
	await rig.wait_seconds(1.0)
	_ck("and the door it stands on opens", bool(_gate.call(&"is_open")))
	await _frame(rig, "07_eye_open.png")


# --- F. The refusal names the verb --------------------------------------------

## The strings themselves. Beat B already proved the DOOR reaches them; this is
## the pair of lines side by side, which is what stops the frozen variant from
## quietly acquiring the plain one's wording.
func _f_refusal(rig) -> void:
	var iced := await _offstage(rig, true)
	var plain := await _offstage(rig, false)
	var line: String = iced.call(&"refusal", 1, 1)
	# GDD pillar 3: a refusal names what is WANTED, not what is wrong.
	_ck("the frozen eye's refusal names the verb: \"%s\"" % line,
		line.contains("LIT") and line != "THE EYE IS SHUT")
	_ck("and a plain eye still says its own line: \"%s\""
		% plain.call(&"refusal", 1, 1),
		String(plain.call(&"refusal", 1, 1)) == "THE EYE IS SHUT")
	# The count, which a gate with more than one iced eye needs. It must not fall
	# back through to "EYES STILL SHUT" -- a door counting iced eyes in the plain
	# eye's words is the same lie in the plural.
	var many: String = iced.call(&"refusal", 2, 3)
	_ck("and it counts in its own words: \"%s\"" % many, many == "2 OF 3 EYES STILL ICED")


# --- G. Fire is a longer sentence in the same word ----------------------------

func _g_fire_opens_plain(rig) -> void:
	var eye := await _offstage(rig, false)
	eye.call(&"apply_hit", Hit.make(K.HEALTH_POINT, Vector3.ZERO, Hit.ARROW_FIRE))
	_ck("a burning arrow opens a PLAIN eye too", bool(eye.call(&"is_solved")))

	var iced := await _offstage(rig, true)
	iced.call(&"apply_hit", Hit.make(K.HEALTH_POINT, Vector3.ZERO, Hit.ARROW))
	_ck("a plain arrow never opens an iced one", not bool(iced.call(&"is_solved")))
	iced.call(&"apply_hit", Hit.make(K.HEALTH_POINT, Vector3.ZERO, &"sword"))
	_ck("and neither does a sword", not bool(iced.call(&"is_solved")))


## One eye, in the tree and out of shot. **In the tree** because `_ready` is what
## builds the lids, and `on_solved()`'s tween would otherwise be created on a
## node outside the scene -- an error, and one that would read as the kind check
## having failed.
func _offstage(rig, iced: bool) -> Node3D:
	var eye := PuzzleAtoms.make(PuzzleAtoms.EYE_SWITCH, &"") as Node3D
	if iced:
		eye.set(&"frozen", true)
	# Distinct names, so two of these never collide and Godot never renames one
	# out from under a `get_node`.
	eye.name = "Offstage%s%d" % ["Iced" if iced else "Plain",
		rig.scene().get_child_count()]
	eye.position = OFFSTAGE
	rig.scene().add_child(eye)
	await rig.wait_frames(3)
	return eye


# --- Photography --------------------------------------------------------------

func _frame(rig, path: String) -> void:
	if _cam != null:
		_cam.make_current()
	await rig.wait_frames(12)
	await rig.capture(path)
