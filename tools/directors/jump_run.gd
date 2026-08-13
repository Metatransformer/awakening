extends RefCounted
## The jump and the sprint, measured and photographed.
##
## Both of these are new verbs on the hero, and both are the kind of thing that
## can look completely finished in a log and be wrong on screen — a jump whose
## impulse is clamped away still plays the whole jump clip, standing on the
## floor, and prints nothing. So this director does two separate jobs and will
## not let either one stand in for the other:
##
##   1. MEASURES. Apex height, airtime, top speed, stamina drain — read off the
##      body every physics frame and checked against the constants they were
##      designed from. A number that disagrees with K prints `JUMP FAIL`.
##   2. PHOTOGRAPHS. A burst through each arc, because the numbers cannot tell
##      you the hero is playing an anticipation crouch while already rising,
##      which is the exact failure `jump_start_offset` exists to prevent.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/jump_run.gd --out=/tmp/jump/x.png
##
## Tile each burst into a strip (no ImageMagick on this machine):
##   for b in /tmp/jump/stand /tmp/jump/run /tmp/jump/sprint; do \
##     ffmpeg -y -i "${b}_%d.png" -filter_complex tile=6x1 "${b}_sheet.png"; done

const ST_GROUND := 0
const ST_ROLL := 2

## Frames per burst, and the gap between them. 6 frames across ~0.6 s of air is
## a frame every 0.1 s: enough to see launch, tuck, apex, fall and land as five
## distinct poses rather than one blur.
const BURST := 6

## MEASURING AND PHOTOGRAPHING ARE SEPARATE PASSES, and this is not neatness.
## `rig.capture()` awaits — it costs real physics frames — so a loop that both
## samples the body and takes pictures counts only the frames it did not spend
## on a picture. The first version of this director did exactly that and
## reported a 0.60 s jump as 0.50 s: six captures, one frame each, 0.10 s
## missing. It then sent somebody looking for the missing time in
## `floor_snap_length`, which had nothing to do with it.
##
## So: `_arc()` measures and never captures, `_shoot()` captures and never
## measures, and each beat jumps twice.

var _fails := 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/jump/x.png").get_base_dir()

	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		_fail("no node in group `player`")
		_report()
		return
	var hero: Node3D = players[0]

	# The camera re-derives its transform every physics frame, so parking it and
	# waiting is parking it nowhere (the note in swing_lookdev.gd cost somebody
	# a wide shot of the garrison with a 40 px hero in it). Take its hands off
	# first.
	var cam := hero.get_viewport().get_camera_3d()
	if cam != null:
		cam.set_physics_process(false)

	await rig.wait_seconds(0.8)

	await _beat_standing_jump(rig, hero, cam, out)
	await _beat_running_jump(rig, hero, cam, out)
	await _beat_sprint(rig, hero, cam, out)
	await _beat_tap_still_rolls(rig, hero)
	await _beat_release_after_hold_is_silent(rig, hero)

	_report()


## A jump from a dead stop. The one that proves the impulse survives
## `_apply_gravity` at all: if it does not, the rise is zero and every other
## number here is still perfectly plausible.
func _beat_standing_jump(rig, hero: Node3D, cam: Camera3D, out: String) -> void:
	_release_all()
	hero.set(&"facing_yaw", 0.0)
	await rig.wait_seconds(0.5)

	var arc := await _arc(rig, hero)
	var apex: float = arc[0]
	var airtime: float = arc[1]

	print("JUMP stand: apex=%.2f m airtime=%.2f s (want %.2f / %.2f)" % [
		apex, airtime, _want_apex(hero), _want_airtime(hero)])
	# 15% either way. These are derived from K.JUMP_SPEED and K.GRAVITY, so a
	# real miss means the impulse was clamped or the gravity is not what K says,
	# not that a tuning value drifted.
	if absf(apex - _want_apex(hero)) > _want_apex(hero) * 0.15:
		_fail("apex is %.2f m, expected %.2f — is the impulse being clamped?" % [
			apex, _want_apex(hero)])
	if absf(airtime - _want_airtime(hero)) > _want_airtime(hero) * 0.15:
		_fail("airtime is %.2f s, expected %.2f" % [airtime, _want_airtime(hero)])

	# A second jump, purely for the camera. See the note on BURST.
	await rig.wait_seconds(0.5)
	await _shoot(rig, hero, cam, out, "stand", Vector3(2.6, 1.4, 3.0), 0.1)


## A jump taken at speed. Checks the OTHER clip is chosen, and that the hero
## keeps his horizontal travel through the air — a jump that drops the run's
## velocity on launch reads as hitting a wall in mid-air.
func _beat_running_jump(rig, hero: Node3D, cam: Camera3D, out: String) -> void:
	_release_all()
	await rig.wait_seconds(0.6)

	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(0.9)  # long enough to reach the run cap

	var p0: Vector3 = hero.global_position
	var arc := await _arc(rig, hero)
	var apex: float = arc[0]
	var fired_run: bool = arc[2]
	var travelled := Vector2(hero.global_position.x - p0.x,
		hero.global_position.z - p0.z).length()

	print("JUMP run: apex=%.2f m airtime=%.2f s travelled=%.2f m" % [
		apex, arc[1], travelled])
	if travelled < 1.5:
		_fail("a running jump covered %.2f m — the leap is losing its speed" % travelled)
	if not fired_run:
		_fail("the RUNNING jump clip never fired; the standing one played instead")

	await _shoot(rig, hero, cam, out, "run", Vector3(3.4, 1.4, 2.2), 0.1)
	Input.action_release(&"move_up")


## Hold the dodge button and keep holding it. Proves four separate things: that
## the hold becomes a run at all, that it does NOT roll on the way in, that the
## run is faster than the run cap, and that the bar is what ends it.
##
## The second of those is the newest and the one worth stating: the hold used to
## fire the dodge on the press and start the run underneath it, so every sprint
## began with an involuntary roll that spent a third of the bar the run needed.
## `Hero.sprint_hold_time` is a WINDOW now — released inside it the press is a
## dodge, still down when it expires it is a run and nothing else — and a roll
## seen anywhere in this beat means the two halves have started overlapping
## again.
func _beat_sprint(rig, hero: Node3D, cam: Camera3D, out: String) -> void:
	_release_all()
	await rig.wait_seconds(1.4)  # let stamina come back from the rolls above
	Game.stamina = Game.max_stamina

	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(0.7)
	var run_speed := _planar(hero)

	Input.action_press(&"context")
	# Polled from the press frame rather than sampled after the wait: the roll
	# being hunted here is 0.4 s long and lands right at the start, so a single
	# read taken once the sprint is up would miss it every time.
	var rolled_in := false
	for i in 60:  # 1.0 s, well past sprint_hold_time (0.36)
		await rig.physics_frame
		if int(hero.get(&"state")) == ST_ROLL:
			rolled_in = true

	var top := 0.0
	var stam_before: float = Game.stamina
	for i in 72:  # 1.2 s, measured clean
		await rig.physics_frame
		top = maxf(top, _planar(hero))

	var sprinting: bool = hero.get(&"sprinting")
	var drained: float = stam_before - Game.stamina
	print("JUMP sprint: run=%.2f sprint=%.2f m/s (cap %.2f) drained=%.1f sprinting=%s rolled_in=%s" % [
		run_speed, top, K.RUN_SPEED, drained, sprinting, rolled_in])

	if not sprinting:
		_fail("holding the dodge button never became a run")
	if rolled_in:
		_fail("the held button rolled on its way into the run — the window is not exclusive")
	if top < K.RUN_SPEED * 1.15:
		_fail("the sprint topped out at %.2f m/s, barely over the %.2f run cap" % [
			top, K.RUN_SPEED])
	if top > K.ROLL_SPEED:
		_fail("the sprint (%.2f) is faster than a roll (%.2f) — see K.SPRINT_SPEED" % [
			top, K.ROLL_SPEED])
	if drained <= 0.0:
		_fail("a sprint ran for 1.2 s and spent no stamina")

	# Photographed while still running, before the bar is run dry below.
	var shot := 0
	while shot < BURST:
		_park(cam, hero, Vector3(3.0, 1.5, 2.4))
		await rig.capture(out.path_join("sprint_%d.png" % shot))
		await rig.wait_seconds(0.12)
		shot += 1

	# Now run it dry. The bar should end the run, and the hero should drop back
	# to the ordinary run cap rather than stopping dead.
	var guard := 0
	while bool(hero.get(&"sprinting")) and guard < 600:
		await rig.physics_frame
		guard += 1
	await rig.wait_seconds(0.4)
	print("JUMP sprint: bar ran out after %.1f s, speed now %.2f m/s" % [
		guard / 60.0, _planar(hero)])
	if guard >= 600:
		_fail("the sprint never ended — is it spending stamina at all?")
	if _planar(hero) < K.WALK_SPEED:
		_fail("running out of stamina stopped the hero dead instead of dropping him to a run")

	Input.action_release(&"context")
	Input.action_release(&"move_up")


## The half that had to keep working. A tap is still a dodge — on the RELEASE
## now, since that is the frame the press is known to have been a tap. Hold it
## for 0.30 s to prove the newly forgiving 0.36 s window accepts a slower
## reaction that the old 0.18 s window would have classified as a run. That is
## the entire promise of putting the run on a hold, and it is the half the
## window could break by classifying every press as a run.
func _beat_tap_still_rolls(rig, hero: Node3D) -> void:
	_release_all()
	await rig.wait_seconds(1.6)
	Game.stamina = Game.max_stamina

	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(0.6)
	Input.action_press(&"context")
	await rig.wait_seconds(0.30)
	Input.action_release(&"context")

	var rolled := false
	for i in 20:
		await rig.physics_frame
		if int(hero.get(&"state")) == ST_ROLL:
			rolled = true
			break
	Input.action_release(&"move_up")
	print("JUMP tap: rolled=%s" % rolled)
	if not rolled:
		_fail("a TAP no longer rolls — the hold has eaten the dodge")


## The other end of the window, and the beat that would have caught the obvious
## wrong implementation of it: fire the dodge whenever the button comes up.
##
## Held 0.5 s — past `Hero.sprint_hold_time` (0.36) but nowhere near long enough
## to be mistaken for the sprint beat above — and then released with a FULL bar,
## so a roll refusing here would have to be refused for the right reason and not
## for want of stamina. Nothing may happen on the release: the press was spent on
## the run and a player who lets go of a sprint is asking to stop, not to dive.
func _beat_release_after_hold_is_silent(rig, hero: Node3D) -> void:
	_release_all()
	await rig.wait_seconds(1.6)
	Game.stamina = Game.max_stamina

	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(0.6)
	Input.action_press(&"context")
	await rig.wait_seconds(0.5)
	var ran: bool = hero.get(&"sprinting")
	var stam: float = Game.stamina
	Input.action_release(&"context")

	var rolled := false
	for i in 30:
		await rig.physics_frame
		if int(hero.get(&"state")) == ST_ROLL:
			rolled = true
	Input.action_release(&"move_up")
	print("JUMP hold_release: ran=%s stamina_at_release=%.0f rolled_after=%s" % [
		ran, stam, rolled])
	if not ran:
		_fail("a 0.5 s hold never reached the run — this beat proves nothing")
	if stam < 20.0:
		_fail("the bar was down to %.0f at the release, so a refused roll proves"
			% stam + " nothing about the window")
	if rolled:
		_fail("letting go after a run still rolled — the window is being ignored"
			+ " and every sprint ends in a dive")


# --- helpers ----------------------------------------------------------------

## One jump, measured and NOT photographed. Returns [apex, airtime, was_running].
##
## Airtime is counted off the hero's own `_airborne_time` rather than off
## is_on_floor sampled from out here: the director resumes at an arbitrary point
## in the frame, so a flag read from this side is a frame stale at each end of
## the arc and reports 0.03 s short for no reason anybody can see.
func _arc(rig, hero: Node3D) -> Array:
	var y0: float = hero.global_position.y
	Input.action_press(&"jump")
	await rig.physics_frame
	Input.action_release(&"jump")

	var apex := 0.0
	var airtime := 0.0
	var running := false
	# 1.2 s is twice the designed airtime. If he is still up there at the end,
	# that IS the answer, and the loop must not hide it by stopping early.
	for i in 72:
		await rig.physics_frame
		apex = maxf(apex, hero.global_position.y - y0)
		airtime = maxf(airtime, float(hero.get(&"_airborne_time")))
		running = running or _shot_fired(hero, "JumpRun")
	return [apex, airtime, running]


## One jump, photographed and NOT measured. Every capture costs physics frames,
## which is exactly why it may not share a loop with the arithmetic.
func _shoot(rig, hero: Node3D, cam: Camera3D, out: String, tag: String,
		offset: Vector3, gap: float) -> void:
	Input.action_press(&"jump")
	await rig.physics_frame
	Input.action_release(&"jump")
	for i in BURST:
		_park(cam, hero, offset)
		await rig.capture(out.path_join("%s_%d.png" % [tag, i]))
		await rig.wait_seconds(gap)

## Apex the hero's own exports predict, in metres: v^2 / 2g.
func _want_apex(hero: Node3D) -> float:
	var v: float = hero.get(&"jump_speed")
	var g: float = hero.get(&"gravity")
	return (v * v) / (2.0 * g)


func _want_airtime(hero: Node3D) -> float:
	var v: float = hero.get(&"jump_speed")
	var g: float = hero.get(&"gravity")
	return 2.0 * v / g


func _planar(hero: Node3D) -> float:
	var v: Vector3 = hero.velocity
	return Vector2(v.x, v.z).length()


## Whether a OneShot in the hero's tree is running. `active` is the read-only
## half of the same parameter `request` writes, so this asks the tree what it is
## really playing rather than trusting the code that asked it to.
func _shot_fired(hero: Node3D, id: String) -> bool:
	var tree: AnimationTree = hero.find_child("AnimTree", false, false)
	if tree == null:
		return false
	return bool(tree.get("parameters/%s/active" % id))


func _park(cam: Camera3D, hero: Node3D, offset: Vector3) -> void:
	if cam == null:
		return
	cam.global_position = hero.global_position + offset
	cam.look_at(hero.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)


func _release_all() -> void:
	for a in [&"jump", &"context", &"move_up", &"move_down", &"move_left",
			&"move_right", &"shield", &"attack"]:
		Input.action_release(a)


func _fail(msg: String) -> void:
	_fails += 1
	print("JUMP FAIL %s" % msg)


func _report() -> void:
	print("JUMP done: %d failure(s)" % _fails)
