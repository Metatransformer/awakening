extends RefCounted
## Everything the LEFT TRIGGER is supposed to buy, pressed the way a player
## presses it: hold LT, then reach for a face button.
##
## guard_moveset.gd already proves the four dodges TRAVEL correctly. This asks
## the two questions it does not:
##
##   1. **LT + A is the jump attack.** With the guard up, something locked and
##      the stick AT REST, `context` — A on the pad — is supposed to leap. The
##      failure this catches is a press that is silently refused: by the range
##      gate, by a missing lock, by a prompt eating the button, or by the dodge
##      taking the press that was meant for the leap. All four look from the
##      couch exactly like a button that does nothing.
##
##      [oot] A is TWO moves and the stick picks. So each leap beat also asserts
##      the hero did not roll — the split failing the other way (both halves
##      answering, or the dodge answering first) is not visible in "did the
##      lunge clip play", and it is the failure a shared button actually has.
##   2. **The sidewards dodge is a ROLL.** Not the standing shuffle the longbow
##      set ships: the hero has to go to ground. Checked by which one-shot is
##      live in the tree, because "it travelled 2.4 m sideways" was true of the
##      shuffle too and told us nothing about what it looked like.
##
## Both are measured at several RANGES, which is the point of the sweep: the
## leap has a min and a max, and the one distance a player actually presses A
## from is sword range — inside the min. A gate that only refuses where nobody
## stands is a gate; one that refuses where everybody stands is the bug.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/lt_moveset.gd --out=/tmp/lt/x.png \
##     --warmup=60

## Hero.MoveState / Hero.Dodge, which are not reachable by name from a
## RefCounted director.
const ST_GROUND := 0
const ST_ROLL := 2
const ST_ATTACK := 4
const DODGE_LEFT := 2
const DODGE_RIGHT := 3
## Hero._DODGE_NODES, in Dodge order. Copied rather than read off the hero
## because a const on a script is not reachable through `get()`.
const _DODGE_NODES: Array[String] = ["Roll", "RollBack", "RollLeft", "RollRight"]

## Where the leap is tried from, in metres. 1.4 is sword range — the distance a
## player is actually standing at when they press A — and it is first in the list
## because it is where the leap used to be refused: HeroCombat had a near edge of
## 1.9 m, so the button was dead at exactly the distance a fight happens at. 6.5
## is the other end, past the old 6.0 far edge and inside the lock's reach.
const LEAP_RANGES: Array[float] = [1.4, 2.6, 4.2, 6.5]

## The mark, and it is guard_moveset's, measured the same way and for the same
## reasons: from z ≈ 2.5 facing -Z the lens sits 4 m behind him with the south
## wall still 3.5 m further back, the sidehops stay in the clear central band,
## and nothing he can do from here ends against geometry. Everything below
## approaches PostC (0, 0, -2.5) from +Z so that one mark serves every beat.
const TARGET := ^"PostC"

## Frames given to the camera after the hero is moved. The stick is read
## camera-relative and the guard pins the facing to the lens, so this is not
## padding — it is what makes "right" mean right. p4_lunge pays the same 60.
const SETTLE := 60

var _fails := 0


func run(rig) -> void:
	# THE BOOT KIT IS GONE (game_state.gd STARTER_KIT is empty now, docs/SCOPE.md
	# M1): the bow, the hookshot and the thirty arrows used to be handed over in
	# `Game._ready()`, and this director was written on top of that. It exercises
	# the gear rather than the earning of it, so it hands itself the same three
	# things the boot used to -- the alternative is a director that fails for a
	# reason that has nothing to do with what it claims.
	Game.grant(&"bow")
	Game.grant(&"hookshot")
	if Game.arrows < 30:
		Game.add_arrows(30 - Game.arrows)

	var out: String = rig.arg("out", "/tmp/lt/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var scene: Node = rig.scene()
	var hero: Node3D = scene.get_node_or_null(^"Hero") as Node3D
	if hero == null:
		print("LT FAIL no Hero in the scene")
		return
	var post := scene.get_node_or_null(TARGET) as Node3D
	if post == null:
		print("LT FAIL no %s to lock onto" % TARGET)
		return
	# One lockable thing in the room, for the reason p4_lunge documents: the
	# scorer picks by screen angle and the wrong post kept winning.
	for other in ["PostA", "PostB"]:
		var n: Node = scene.get_node_or_null(NodePath(other))
		if n != null:
			n.remove_from_group(&"targetable")
	await rig.wait_frames(20)

	for r in LEAP_RANGES:
		await _leap_at(rig, hero, post, r)
	await _shoot_leap(rig, hero, post, out)
	await _dodge(rig, hero, post, &"move_right", DODGE_RIGHT, "roll_r", out)
	await _dodge(rig, hero, post, &"move_left", DODGE_LEFT, "roll_l", out)

	Input.action_release(&"shield")
	print("LT done: %d failures" % _fails)


# --- LT + A -----------------------------------------------------------------

func _leap_at(rig, hero: Node3D, post: Node3D, range_m: float) -> void:
	await _stance(rig, hero, post, range_m, &"")
	var locked: bool = hero.call(&"lock_target") != null
	if not locked:
		_fail("%.1fm: the trigger acquired nothing to leap at" % range_m)
		await _drop(rig, &"")
		return

	var before := _gap(hero, post)
	# Every reason the press can be swallowed, printed BEFORE it is made. A
	# refused jump attack looks identical from the couch whichever of these did
	# it, and guessing between them is how this went unfixed.
	var focus: Object = Prompt.focus if Prompt != null else null
	print("LT   @%.1fm gap=%.2f focus=%s stamina=%.0f"
		% [range_m, before, focus, float(Game.get(&"stamina"))])
	# `context`, the same action the dodge reads, because the whole point is that
	# ONE press goes one of two ways. `_stance` left the stick alone, so this is
	# the neutral half.
	Input.action_press(&"context")
	# Polled rather than sampled: the one-shot is only REQUESTED on the frame
	# the state flips, so a single read on that frame sees no swing at all.
	# guard_moveset paid for this lesson on the dash.
	var tree: AnimationTree = hero.find_child("AnimTree", false, false)
	var saw_lunge := false
	var saw_attack := false
	var saw_roll := false
	for _i in 14:
		var st := int(hero.get(&"state"))
		if st == ST_ATTACK:
			saw_attack = true
		if st == ST_ROLL:
			saw_roll = true
		if tree != null and bool(tree.get("parameters/SwingLunge/active")):
			saw_lunge = true
		await rig.wait_frames(1)
	Input.action_release(&"context")
	await rig.wait_seconds(1.0)
	var closed := before - _gap(hero, post)
	print("LT leap @%.1fm: attack=%s lunge_clip=%s rolled=%s closed=%+.2fm"
		% [range_m, saw_attack, saw_lunge, saw_roll, closed])
	if not saw_lunge:
		_fail("%.1fm: LT+A did not throw the jump attack" % range_m)
	if saw_roll:
		_fail("%.1fm: LT+A dodged as well — the stick split leaks" % range_m)
	await _drop(rig, &"")


## The leap, photographed. Separate from the measured sweep for the reason
## `_shoot` gives below — `rig.capture()` costs game time and a burst
## interleaved with the poll loop would miss the frame the swing starts on.
##
## 4.2 m is the range chosen to LOOK at: point blank the leap correctly has no
## travel (see `lunge_min_range` in hero_combat.gd), which is the right answer
## and a useless photograph of it.
func _shoot_leap(rig, hero: Node3D, post: Node3D, out: String) -> void:
	await _stance(rig, hero, post, 4.2, &"")
	Input.action_press(&"context")
	await rig.wait_frames(2)
	Input.action_release(&"context")
	for i in 7:
		await rig.capture(out.path_join("lt_leap_%d.png" % i))
		await rig.wait_seconds(0.10)
	await _drop(rig, &"")


# --- LT + stick + roll ------------------------------------------------------

func _dodge(rig, hero: Node3D, post: Node3D, action: StringName, want: int,
		tag: String, out: String) -> void:
	await _stance(rig, hero, post, 5.0, action)

	var tree: AnimationTree = hero.find_child("AnimTree", false, false)
	Input.action_press(&"context")
	var started := await _await_state(rig, hero, ST_ROLL)
	Input.action_release(&"context")
	if not started:
		_fail("%s never started" % tag)
		await _drop(rig, action)
		return

	var facing: float = hero.get(&"facing_yaw")
	var got: int = hero.get(&"_dodge")
	if got != want:
		_fail("%s fired Dodge %d, wanted %d" % [tag, got, want])

	# VELOCITY, not displacement, and this is not a preference. The training room
	# is 22 m square with a 7x10 ledge across its whole east half and two blocks
	# to the west, so a 4 m roll from any mark that can see a post ends against
	# geometry — guard_moveset's 0.44 s hop already clipped the same props at
	# 1.66 m. Displacement there measures the wall, not the move. It is still
	# printed, because a number that is sometimes the wall is worth seeing; it
	# is just not what passes or fails.
	var vel: Vector3 = hero.velocity
	var fwd := Vector3(sin(facing), 0.0, cos(facing))
	# Hero-RIGHT: forward turned -90 about Y is (-f.z, 0, f.x). Written out rather
	# than imported, so this director does not share a sign bug with the code it
	# is checking. Same note as guard_moveset.
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var side := vel.dot(right)
	var speed := Vector2(vel.x, vel.z).length()

	# WHICH CLIP, which is the whole question the user asked. Two halves, because
	# either one alone can be satisfied by the bug: the one-shot for THIS dodge
	# has to be the live one in the tree, and the clip hanging off it has to be
	# the forward roll's. A sidehop node playing a roll and a roll node playing a
	# sidehop look identical to a check that only asks one of those.
	# Annotated, because indexing an untyped array returns Variant and "Cannot
	# infer the type of X" is a parse error, not a warning. CLAUDE.md §3.
	var node: String = _DODGE_NODES[got]
	var clip: StringName = hero.call(&"_dodge_clip", got)
	var want_clip: StringName = hero.get(&"clip_roll")
	var saw_node := false
	var before := hero.global_position
	var frames := 0
	while int(hero.get(&"state")) == ST_ROLL:
		if tree != null and bool(tree.get("parameters/%s/active" % node)):
			saw_node = true
		frames += 1
		await rig.wait_frames(1)
	if not saw_node:
		_fail("%s did not fire the %s one-shot" % [tag, node])
	if clip != want_clip:
		_fail("%s plays `%s`, not the roll (`%s`)" % [tag, clip, want_clip])

	var moved := hero.global_position - before
	print("LT %-7s dodge=%d node=%s clip=%s side_vel=%+.2f speed=%.2f moved=%.2fm over %d frames"
		% [tag, got, node, clip, side, speed, Vector2(moved.x, moved.z).length(), frames])
	if want == DODGE_RIGHT and side < 4.0:
		_fail("%s did not launch right (%.2f m/s)" % [tag, side])
	if want == DODGE_LEFT and side > -4.0:
		_fail("%s did not launch left (%.2f m/s)" % [tag, side])
	# A roll's speed, because it is a roll. Under this and it is still the hop.
	if speed < float(hero.get(&"roll_speed")) - 0.2:
		_fail("%s left at %.2f m/s, not a roll's %.2f"
			% [tag, speed, float(hero.get(&"roll_speed"))])
	# The facing is the other half of "strafe dodge": the body must still be
	# watching the thing it is locked to when the roll is over.
	var off := absf(rad_to_deg(wrapf(_yaw_to(hero, post) - float(hero.get(&"facing_yaw")),
		-PI, PI)))
	if off > 25.0:
		_fail("%s came out of the roll %.0f deg off the target" % [tag, off])

	# In and OUT of the trigger: the shield is still held, so the guard has to
	# come back up on its own once the recovery is done.
	await rig.wait_seconds(0.6)
	var combat: Node = hero.get(&"combat")
	if combat != null and not bool(combat.get(&"blocking")):
		_fail("%s: the guard did not come back up with the trigger still held" % tag)

	await _shoot(rig, hero, post, action, tag, out)
	await _drop(rig, action)


## The photographed pass. Separate from the measured one for the reason
## guard_moveset documents at length: rig.capture() costs game time, and a burst
## interleaved with position samples runs off the end of the move.
##
## Its own mark, and it is chosen for the LENS, not the hero. A 4 m roll drags
## the camera 4 m sideways with it, and the training room's west props are 2 m
## tall: shot from the measured mark the left-hand roll put the lens inside
## `BlockTall` (x −6.6…−4.2, z 2.4…4.8) and returned six black frames of a roll
## nobody can see. So the hero starts 3 m to the far side and rolls back across
## the middle — the lens then travels the clear central band instead of into the
## furniture. z ≈ 3.5 is the one row that works: it is past the ledge (which ends
## at z = 3) and short of `BlockLow` (z 4.2…6.6), with the south wall still 6 m
## behind the camera.
func _shoot(rig, hero: Node3D, post: Node3D, action: StringName, tag: String,
		out: String) -> void:
	await _stance(rig, hero, post, 6.0, action,
		3.0 if action == &"move_left" else -3.0)
	Input.action_press(&"context")
	await rig.wait_frames(2)
	Input.action_release(&"context")
	for i in 6:
		await rig.capture(out.path_join("lt_%s_%d.png" % [tag, i]))
		await rig.wait_seconds(0.09)


# --- Plumbing ---------------------------------------------------------------

## Put the hero on his mark at `range_m` from the post, pull the trigger, and
## wait for the guard to settle onto the lens before touching the stick — every
## clause of which guard_moveset._stance explains and paid for.
func _stance(rig, hero: Node3D, post: Node3D, range_m: float,
		action: StringName, x_bias: float = 0.0) -> void:
	Game.set(&"stamina", K.MAX_STAMINA)
	# Straight out along +Z from the post, so the mark is the one described at
	# the top of the file and the lens always trails into open floor. `x_bias`
	# only ever moves the photographed pass — see `_shoot`.
	hero.global_position = post.global_position + Vector3(x_bias, 0.15, range_m)
	hero.set(&"facing_yaw", PI)
	hero.velocity = Vector3.ZERO
	Input.action_release(&"shield")
	var cam := hero.get_viewport().get_camera_3d()
	if cam != null and cam.has_method(&"recenter"):
		cam.call(&"recenter")
	await rig.wait_frames(SETTLE)
	Input.action_press(&"shield")
	await rig.wait_seconds(0.35)
	# The guard pins the facing to the lens, and a body still swinging round from
	# the last beat classifies every dodge against a facing the player never saw.
	for _i in 90:
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
	await rig.wait_seconds(0.4)


func _await_state(rig, hero: Node3D, want: int) -> bool:
	for _i in 20:
		if int(hero.get(&"state")) == want:
			return true
		await rig.wait_frames(1)
	return false


func _yaw_to(hero: Node3D, post: Node3D) -> float:
	var d := post.global_position - hero.global_position
	return atan2(d.x, d.z)


func _gap(hero: Node3D, post: Node3D) -> float:
	var d := post.global_position - hero.global_position
	return Vector2(d.x, d.z).length()


func _fail(msg: String) -> void:
	_fails += 1
	print("LT FAIL %s" % msg)
