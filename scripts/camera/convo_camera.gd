class_name ConvoCamera
extends Camera3D
## The camera for a conversation with more than one person in it: it stands where
## the hero's eyes are and turns to whoever is talking.
##
##          Aldric ●                    ● Brannoc
##                  ╲                  ╱
##                   ╲    ◜ pan ◝     ╱
##                    ╲  ╱        ╲  ╱
##                     ▣ ─────────▶▣          ← this camera, pivoting on the
##                      hero's head                hero's own head
##
## **A second `Camera3D` that takes the frame for the length of the scene, and
## NOT a branch inside `GameCamera`.** That file is a thousand lines of boom, wall
## arc, lock-on framing, aim stance and first person, and every one of those rules
## is written against "the thing being looked at is the hero". A conversation is
## the one shot in this game where it is not. Godot makes the swap a one-liner in
## either direction (`make_current`), the transition skill's own recipe, and the
## alternative -- a `_cutscene` flag that six existing functions have to check --
## is the shape that eventually breaks the ordinary camera for everybody.
##
## ## It pivots on the hero and it does not travel
##
## The owner's ask was "pan the camera over to that person from your POV", and
## the two halves of that are load-bearing:
##
##   * **From the hero's head.** The eye sits a pace behind and a little over his
##     crown -- close enough that this is his point of view, far enough back that
##     his own skull is not in the near plane. It never dollies toward the person
##     talking: a camera that flies across the yard is a cutscene, and this is
##     meant to read as the player turning to look.
##   * **So the pan is a ROTATION**, eased in yaw about that one point. Both
##     framings therefore share an origin, which is what makes the movement
##     legible as "you looked over there" rather than as a cut.
##
## ## The FOV is what reaches the far side of the yard
##
## The keeper stands 2.4 m in front of the hero and the smith's forge is eleven
## metres away on the ring, so one focal length cannot frame both: at a fixed 50°
## Brannoc is nine percent of the frame height and unreadable behind a dialogue
## box. So the lens narrows for distance -- `_want_fov` solves for the angle that
## puts the speaker's own height at `FILL` of the frame, clamped -- and eases
## there with the turn. It reads as attention rather than as a zoom, because it
## only ever moves while the camera is already moving.
##
## Nothing here is saved, nothing here is a setting, and it exists only while a
## scene is on screen. `Introduction` owns both ends of that lifetime.

## Where the eye sits relative to the hero's head: back along the line to whoever
## is talking, up, and off to one side.
##
## `BACK` is measured against the hero's own model rather than chosen: at less
## than about 0.8 m the near plane is inside his head and the frame fills with the
## inside of a skull. At much more than a metre it stops being his point of view
## and becomes a shot of the back of his head, which is the third-person camera
## the game already has.
const BACK := 0.95
const RISE := 0.34
## Off the shoulder, and always the SAME shoulder. It is what stops the two
## framings of a two-hander being mirror images of each other -- with the offset
## flipping side by side, a pan from Aldric to Brannoc would swing the hero's head
## through the middle of the frame on the way past.
const SHOULDER := 0.30

## Seconds for the turn, and for the lens with it. Long enough to read as a head
## turning and not a cut; short enough that the next line is not waiting on it.
## The words keep typing throughout — the pan is not a gate.
const PAN_TIME := 0.55
## What fraction of the frame's height the speaker's body should fill. Under a
## dialogue box that owns the bottom third, a figure at 0.42 has their face
## comfortably in the free upper half.
const FILL := 0.42
## The lens may not open wider than a room needs or narrow past a portrait.
##
## **20 and not 28, and the difference is the whole point of the system.** The
## garrison is bigger than it looks from the gate: the hero spawns at the mouth of
## the gatehouse and the ring of counters is eleven to thirteen metres from there,
## so at 28 degrees Brannoc -- a 1.44 m dwarf -- came out **23% of the frame
## height with a dialogue box across the bottom third of it**, which is a
## correctly aimed photograph of somebody you cannot see. `npc_intro.gd` F4b is
## that measurement, taken by projecting his crown and his feet through the camera
## that rendered the frame. At 20 he is a third of the frame and Kessa is
## two-fifths.
##
## It IS a long lens and the yard behind a far speaker flattens under it. That is
## the trade this shot wants: the alternative is flying the camera across the
## courtyard, which stops being the player's point of view (see the header).
const FOV_MIN := 20.0
const FOV_MAX := 52.0

## Whoever is talking, and how tall they are. The height is passed in rather than
## measured off the node: an `Npc` knows its own crown (`Npc.head_y`) and a
## bounding box read off a rigged body includes whatever the idle clip has its
## arms doing.
var _subject: Node3D = null
var _subject_head: float = 1.7
var _hero: Node3D = null
## The camera that had the frame when this one took it, put back by `release`.
var _prev: Camera3D = null

## The orbit angle, which places the EYE, and the world point it is aimed at.
##
## **Two eased quantities and not one, because the eye and the aim are not the
## same problem.** The eye rides a circle around the hero's head, so the honest
## thing to interpolate there is an ANGLE -- lerping its position would cut the
## corner and slide the camera through the hero. The aim is a point on somebody's
## face, and the honest thing to interpolate there is the POINT.
##
## Deriving the aim from the orbit angle instead -- which is what this did first
## -- looks equivalent and is not: it aims the camera along the line from the
## HERO to the speaker, while the camera is standing `SHOULDER` metres to one side
## of the hero. The two lines are parallel, so the speaker sits off the middle of
## the frame by `atan(SHOULDER / distance)` -- **6.6 degrees for somebody standing
## two and a half metres away**, which is a third of the way to the edge of a
## 52-degree frame. `npc_intro.gd` D4 measures exactly this and is the reason it
## is written down.
var _yaw: float = 0.0
var _aim: Vector3 = Vector3.ZERO
var _placed: bool = false


## Take the frame. Returns null when there is no hero to stand behind, which is
## every harness scene with no player in it — a caller should treat that as "no
## camera work" and still play the words.
static func stage(host: Node) -> ConvoCamera:
	var tree := host.get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var hero := tree.get_first_node_in_group(&"player") as Node3D
	if hero == null:
		return null
	var cam := ConvoCamera.new()
	cam.name = "ConvoCamera"
	cam._hero = hero
	# ALWAYS, for `DialogueBox`'s reason: a conversation can be opened over a
	# paused tree (the opening runs behind `Flow`'s veil), and a camera that
	# stopped ticking there would hold the first frame of the pan for the whole
	# of it.
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	cam._prev = host.get_viewport().get_camera_3d()
	tree.current_scene.add_child(cam)
	cam.make_current()
	return cam


## Turn to `subject`. Called once per speaker change; calling it again with the
## same node is harmless and does not restart the turn.
func watch(subject: Node3D, head_y: float = 1.7) -> void:
	if subject == null or subject == _subject:
		return
	_subject = subject
	_subject_head = head_y


## Give the frame back. Idempotent — `Introduction` calls it from a signal that
## can, in principle, arrive twice.
func release() -> void:
	if _prev != null and is_instance_valid(_prev):
		_prev.make_current()
	queue_free()


## True once the turn has arrived: within a degree of the orbit angle and ten
## centimetres of the face. What a director asks so it can photograph the end of a
## pan rather than the middle of one.
##
## Both halves, because the two ease independently and either one lagging is a
## frame that is not yet the shot -- an aim still 40 cm short of a face eleven
## metres away is two degrees of miss, which is more than `npc_intro.gd` allows.
func settled() -> bool:
	if _subject == null or _hero == null:
		return true
	return absf(wrapf(_want_yaw() - _yaw, -PI, PI)) < deg_to_rad(1.0) \
		and _aim.distance_to(_face()) < 0.10


func _process(delta: float) -> void:
	if _hero == null or not is_instance_valid(_hero) \
			or _subject == null or not is_instance_valid(_subject):
		return

	var want_yaw := _want_yaw()
	var want_aim := _face()
	if not _placed:
		# The FIRST framing is a cut, not a pan. There is nothing to pan from —
		# this camera did not exist a frame ago — and easing in from whatever yaw
		# a fresh `_yaw` of zero happens to name would swing the yard through the
		# frame before the first word.
		_placed = true
		_yaw = want_yaw
		_aim = want_aim
		fov = _want_fov(want_yaw)
	else:
		var k := 1.0 - exp(-(1.0 / PAN_TIME) * delta)
		_yaw = lerp_angle(_yaw, want_yaw, k)
		_aim = _aim.lerp(want_aim, k)
		fov = lerpf(fov, _want_fov(want_yaw), k)

	var eye := _eye(Vector3(sin(_yaw), 0.0, cos(_yaw)))
	global_position = eye
	# Guard the degenerate case — an aim point on top of the camera — because
	# `look_at` pushes an error and leaves the basis alone.
	if not _aim.is_equal_approx(eye):
		look_at(_aim, Vector3.UP)


## Where the eye stands for a given facing. Off the hero's head, never the
## subject's — see the header.
func _eye(fwd: Vector3) -> Vector3:
	var side := Vector3(fwd.z, 0.0, -fwd.x)
	return _hero.global_position + Vector3.UP * (K.HERO_EYE_Y + RISE) \
		- fwd * BACK + side * SHOULDER


## The world yaw from the hero to whoever is talking. `(sin y, 0, cos y)` is this
## project's heading convention — CLAUDE.md §4.
func _want_yaw() -> float:
	var to := K.flat(_subject.global_position - _hero.global_position)
	if to == Vector3.ZERO:
		return _yaw
	return atan2(to.x, to.z)


## What the camera looks at: the speaker's crown.
##
## The crown and not the eyes, and not the middle of the body. Aimed at the crown,
## the head sits on the frame's centre line with the whole figure hanging below it
## — which is the half of the frame a dialogue box does not own. Aimed at the
## chest, the face rides up into the top eighth and the box covers the boots.
func _face() -> Vector3:
	return _subject.global_position + Vector3.UP * _subject_head


## The angle that puts a body of `_subject_head` metres at `FILL` of the frame
## height, clamped. Straight trigonometry: half the subject over the distance is
## the tangent of half the vertical angle it subtends, and we want that to be
## `FILL` of the tangent of half the FOV.
func _want_fov(yaw: float) -> float:
	var eye := _eye(Vector3(sin(yaw), 0.0, cos(yaw)))
	var dist := eye.distance_to(_subject.global_position
		+ Vector3.UP * _subject_head * 0.5)
	if dist < 0.5:
		return fov
	var half := atan((_subject_head * 0.5) / (dist * FILL))
	return clampf(rad_to_deg(half) * 2.0, FOV_MIN, FOV_MAX)
