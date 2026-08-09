extends RefCounted
## The whole shield moveset, shot and checked: four dodges out of a raised guard,
## and the dash attack that comes off it.
##
## Two claims are being tested, and neither can be taken on trust:
##
##   1. **Each dodge plays its OWN clip and travels its own way.** Until now
##      every direction fired `ex_roll_to_run`, a forward shoulder dive, so a
##      backstep was a hero rolling forwards while sliding backwards. The check
##      is `Hero._dodge` against what was asked for, plus the direction of the
##      actual displacement measured against the facing he holds through it.
##   2. **Shield + attack is the dash, not a light swing.** `SwingDash` has to be
##      the one-shot in flight, and the hero has to END UP CLOSER to what he was
##      pointing at — a stab that does not close is just a slow slash.
##
## Prints `GUARD FAIL …` on any beat that did not happen, in the house style
## mvp_loop set. The frames are the other half: a passing displacement check
## still cannot tell you the hero looks like he is dodging.
##
## **Every move is performed twice, once measured and once photographed**, and
## that is not redundancy. `rig.capture()` costs real game time — enough that a
## burst interleaved with position samples runs off the end of a 0.44 s hop and
## measures the strafe afterwards instead. An early cut of this did exactly that
## and reported a forward roll travelling sideways, which sent the blame to a
## classifier that was in fact correct. Measure with nothing else happening;
## photograph without pretending the numbers came from those frames.
##
## The camera is left ALIVE here, unlike swing_lookdev. Guarding pins the facing
## to the lens (`Hero._tick_camera_facing`), so a frozen camera would be testing
## a facing the player can never have — and the over-the-shoulder framing it
## gives is exactly the one the dodges have to read in.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/guard_moveset.gd --out=/tmp/guard/x.png \
##     --warmup=60

## Which stick, which Dodge it must become, and what it is called on the strip.
## A neutral stick with the guard raised is the BACKSTEP, the most used defensive
## move in the source material — see `Hero._try_start_roll`.
##
## The sideways pair are ROLLS now, not sidehops — same clip as the forward dive
## with the model turned (`Hero._dodge_model_offset`), so they travel a roll's
## 4 m rather than a hop's 2.7 and clip this room's props on the way. What is
## checked here is unchanged and still true: which Dodge fired, and which way it
## went. The pose and the speed are `tools/directors/lt_moveset.gd`'s beat.
const DODGES := [
	{"action": &"", "dodge": 1, "tag": "backstep"},
	{"action": &"move_left", "dodge": 2, "tag": "roll_l"},
	{"action": &"move_right", "dodge": 3, "tag": "roll_r"},
	{"action": &"move_up", "dodge": 0, "tag": "roll_fwd"},
]

## Hero.MoveState, which is not reachable by name from a RefCounted director.
const ST_ROLL := 2
const ST_ATTACK := 4

var _i := 0
var _fails := 0


func run(rig) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		print("GUARD FAIL no node in group `player`")
		return
	var hero: Node3D = players[0]
	await rig.wait_seconds(0.5)

	for spec in DODGES:
		await _measure_dodge(rig, hero, spec)
		await _shoot_move(rig, hero, spec["action"], &"context", spec["tag"], 5, 0.09)
	await _measure_dash(rig, hero)
	await _shoot_move(rig, hero, &"", &"attack", "dash", 6, 0.07)

	Input.action_release(&"shield")
	print("GUARD done: %d failures" % _fails)


# --- The measured pass ------------------------------------------------------

## Raise the guard, hold the stick, dodge, and watch where he actually goes.
## No captures anywhere in here — see the note at the top about why.
func _measure_dodge(rig, hero: Node3D, spec: Dictionary) -> void:
	var tag: String = spec["tag"]
	var action: StringName = spec["action"]
	await _stance(rig, hero, action)

	Input.action_press(&"context")
	var started := await _await_state(rig, hero, ST_ROLL)
	Input.action_release(&"context")
	if not started:
		_fail("%s did not start a dodge at all" % tag)
		await _drop(rig, action)
		return

	# Both sampled on the frame the dodge COMMITS. Guarding chases the lens at
	# 1620 deg/sec and the lens is still swinging round a hero who has been
	# strafing for half a second, so a facing read even three frames early can be
	# 70 degrees stale. From here the facing is frozen (`_tick_roll` does not
	# steer) and the velocity is constant, so this is the honest moment.
	var before := hero.global_position
	var facing: float = hero.get(&"facing_yaw")
	var got: int = hero.get(&"_dodge")
	var want: int = spec["dodge"]
	if got != want:
		_fail("%s fired Dodge %d, wanted %d" % [tag, got, want])

	var moved := await _travel_during(rig, hero, before, ST_ROLL)
	var fwd := Vector3(sin(facing), 0.0, cos(facing))
	var ahead := moved.dot(fwd)
	# Hero-RIGHT: forward turned -90 about Y is (-f.z, 0, f.x). Getting this sign
	# wrong is what made the sidehops swap clips the first time round, and it is
	# worth writing out rather than importing, because a director that shares the
	# bug with the code it is checking checks nothing.
	var side := moved.dot(Vector3(-fwd.z, 0.0, fwd.x))
	print("GUARD %-10s travel ahead=%+.2f side=%+.2f (%.2f m)" % [
		tag, ahead, side, Vector2(moved.x, moved.z).length()])
	# Dominance, not just sign: a backstep that drifts a metre sideways is a
	# backstep the player did not ask for, and a bare sign test passes it.
	match want:
		0: _want(tag, ahead > 0.6 and ahead > absf(side), "should travel forward")
		1: _want(tag, ahead < -0.6 and -ahead > absf(side), "should travel backward")
		2: _want(tag, side < -0.6 and -side > absf(ahead), "should travel left")
		3: _want(tag, side > 0.6 and side > absf(ahead), "should travel right")

	await _drop(rig, action)


## Shield up, attack pressed: the stab.
func _measure_dash(rig, hero: Node3D) -> void:
	await _stance(rig, hero, &"")

	Input.action_press(&"attack")
	var started := await _await_state(rig, hero, ST_ATTACK)
	Input.action_release(&"attack")
	if not started:
		_fail("dash did not start a swing")
		await _drop(rig, &"")
		return

	var before := hero.global_position
	var facing: float = hero.get(&"facing_yaw")
	# The DASH one-shot has to be the live one. Read off the TREE rather than off
	# HeroCombat on purpose: the failure this guards against is a swing whose
	# numbers are the dash's and whose pose is the light slash, and no amount of
	# asking HeroCombat what it committed would ever catch that.
	#
	# POLLED, not sampled once. `MoveState.ATTACK` is set by the same call that
	# merely *requests* the one-shot; the tree does not process that request until
	# it next ticks, so on the frame the state flips no swing node is active at
	# all — not the dash's and not a light's. Sampling there is a coin toss on
	# frame phase, and it came up heads long enough to look like a passing check.
	# The claim being made is "SwingDash goes live during this swing", so poll it.
	var tree: AnimationTree = hero.find_child("AnimTree", false, false)
	var combat = hero.get(&"combat")
	var saw_dash := false
	var saw_guard_drop := false
	for _i in 12:
		if tree != null and bool(tree.get("parameters/SwingDash/active")):
			saw_dash = true
		if combat != null and not bool(combat.get(&"blocking")):
			saw_guard_drop = true
		if saw_dash and saw_guard_drop:
			break
		await rig.wait_frames(1)
	if tree != null and not saw_dash:
		_fail("dash swung something that was not SwingDash")
	if combat != null and not saw_guard_drop:
		_fail("the shield stayed up through the dash")

	var moved := await _travel_during(rig, hero, before, ST_ATTACK)
	var ahead := moved.dot(Vector3(sin(facing), 0.0, cos(facing)))
	print("GUARD %-10s travel ahead=%+.2f (%.2f m)" % [
		"dash", ahead, Vector2(moved.x, moved.z).length()])
	_want("dash", ahead > 0.8, "should close distance forward")

	await _drop(rig, &"")


## Put the hero back on his mark, raise the guard, wait for the body to actually
## arrive on the lens, and only then touch the stick.
##
## Every clause here was paid for. **The mark**: eight dodges in a row walk the
## hero across the training room and into a wall, and a dodge that ends against
## geometry travels wherever `move_and_slide` deflects it — which is not the
## direction anything asked for. **The settle poll**: the guard pins the facing
## to the lens, but a lens that swung during the unguarded gap between beats
## leaves the body up to 50 degrees behind it, and a dodge fired then is
## classified against a facing the player never saw. Measured, guarding tracks
## the lens to within 8 degrees once settled, so 12 is a threshold the stance can
## actually reach. **The stamina**: a dodge costs K.STAMINA_ROLL and this
## director throws eight, more than a full bar — without it the later beats would
## fail for a reason with nothing to do with animation.
func _stance(rig, hero: Node3D, action: StringName) -> void:
	Game.set(&"stamina", K.MAX_STAMINA)
	# The mark, chosen by walking the room's collision out on paper rather than by
	# eye, because a dodge that ends against geometry travels wherever
	# `move_and_slide` deflects it and reports a clean failure for a move that
	# worked. The origin is ringed by training.tscn's three posts — the first
	# mark put him there and the right sidehop moved 16 cm into PostB. z = 5 then
	# ran the left sidehop into proving_ground's BlockLow (x -4.1…-1.7,
	# z 4.2…6.6). z = 8 cleared all of that for the *hero* and still shot four
	# unusable beats, because the thing that needs room is the **lens**: the
	# camera trails ~4 m behind him, z = 8 put it at z = 12 inside the south
	# wall, and its collision push-in parked it inside his hair. Budget for the
	# camera, not the body. Facing -Z from z = 2.5, the lens sits at z ≈ 6.5 with
	# 3.5 m of wall clearance even at the end of a backstep, and a forward roll
	# ends 1.8 m short of PostC. The sideways pair DO clip the furniture now that
	# they are 4 m rolls rather than 2.7 m hops (blocks west of x = -1.7, the
	# ledge east of x = 3), which is why the checks below are direction and
	# dominance and never a distance.
	hero.global_position = Vector3(0.0, 0.15, 2.5)
	hero.velocity = Vector3.ZERO
	# Face the posts, and put the lens back behind him, so every beat starts from
	# the same pose rather than from wherever the last one left the pair.
	hero.set(&"facing_yaw", PI)
	Input.action_release(&"shield")
	var cam := hero.get_viewport().get_camera_3d()
	if cam != null and cam.has_method(&"recenter"):
		cam.call(&"recenter")
	await rig.wait_seconds(0.6)
	Input.action_press(&"shield")
	await rig.wait_seconds(0.35)
	for i in 90:
		if absf(_facing_error(hero)) < 12.0:
			break
		await rig.wait_frames(1)
	if action != &"":
		Input.action_press(action, 1.0)
		# Long enough to be moving, short enough not to reach a wall.
		await rig.wait_seconds(0.22)


## Degrees between the lens and the body. Positive means the lens leads.
func _facing_error(hero: Node3D) -> float:
	var cam := hero.get_viewport().get_camera_3d()
	if cam == null:
		return 0.0
	var ch := K.flat(-cam.global_transform.basis.z)
	if ch == Vector3.ZERO:
		return 0.0
	return rad_to_deg(wrapf(atan2(ch.x, ch.z) - float(hero.get(&"facing_yaw")), -PI, PI))


func _drop(rig, action: StringName) -> void:
	if action != &"":
		Input.action_release(action)
	Input.action_release(&"shield")
	await rig.wait_seconds(0.7)   # let the recovery finish and the guard drop


## Displacement from `before` over exactly the frames the hero spends in `state`.
## Polls per rendered frame and takes the last reading still inside the move, so
## the strafe that follows a dodge never lands in the dodge's own number.
func _travel_during(rig, hero: Node3D, before: Vector3, state: int) -> Vector3:
	var moved := Vector3.ZERO
	for i in 240:
		if hero.get(&"state") != state:
			break
		moved = hero.global_position - before
		await rig.wait_frames(1)
	return moved


# --- The photographed pass --------------------------------------------------

## Do the move again, this time for the camera.
func _shoot_move(rig, hero: Node3D, action: StringName, button: StringName,
		tag: String, frames: int, every: float) -> void:
	await _stance(rig, hero, action)
	await _shot(rig, tag + "_guard")
	Input.action_press(button)
	await rig.wait_frames(2)
	Input.action_release(button)
	for i in frames:
		await rig.wait_seconds(every)
		await _shot(rig, tag)
	await _drop(rig, action)
	await _shot(rig, tag + "_after")


# --- Plumbing ---------------------------------------------------------------

## Spin a frame at a time until the hero is in `want`, and return on the FIRST
## frame he is. Polling rather than a fixed wait because how long the press takes
## to be seen is not fixed: `_shot` resumes the director on `frame_post_draw`,
## which is a different point in the frame from where `Input` stamps a synthetic
## press (see `shoot.hold`). A fixed sleep either misses the press or samples the
## position several frames into the move it was supposed to be measuring.
func _await_state(rig, hero: Node3D, want: int, max_frames: int = 30) -> bool:
	for i in max_frames:
		if hero.get(&"state") == want:
			return true
		await rig.wait_frames(1)
	return hero.get(&"state") == want


func _want(tag: String, ok: bool, what: String) -> void:
	if not ok:
		_fail("%s %s" % [tag, what])


func _fail(msg: String) -> void:
	_fails += 1
	print("GUARD FAIL %s" % msg)


func _shot(rig, tag: String) -> void:
	await rig.capture("f_%02d_%s.png" % [_i, tag])
	_i += 1
