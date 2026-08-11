extends RefCounted
## Does Z-targeting buy you an attack you cannot otherwise make?
##
## The lunge has its own button now: `heavy`, the one that fires the bow when
## an item is drawn. With the sword out and something locked it is the leap, and
## with nothing locked it is silent — which is OOT's A exactly. What this
## measures is METRES CLOSED, because "he leapt" is a claim about distance and
## the pose cannot settle it.
##
## Four claims:
##   1. Locked, `heavy` closes the gap and lands the blow. Distance before
##      minus distance after is the leap.
##   2. It hurts more than a light swing. It is a commitment; it should pay.
##   3. UNLOCKED, the same inputs do NOT leap. If they do, Z-targeting bought
##      nothing and the lunge is simply the light attack with extra reach.
##   4. It stops SHORT. A leap that ends past the target puts the hero behind
##      the enemy he jumped at, which reads as the hitbox being broken.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/p4_lunge.gd --out=/tmp/p4l/x.png

## Where the hero is put before each attempt, in metres from the post. Inside
## [lunge_min_range, lunge_max_range] and well outside the sword's own reach, so
## a blow that lands here CANNOT have landed without travelling.
const START_RANGE := 4.2
## Frames the stick is held before the attack button goes down. Enough that the
## hero has a wish direction to read, few enough that he has barely walked.
const STICK_LEAD := 4
## Frames given to the GameCamera to settle behind the hero after he is moved or
## the lock changes. The stick is read camera-relative, so this is not padding —
## it is what makes "forward" mean "at the target".
const SETTLE := 60

var _hits: Array[int] = []


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

	var out: String = rig.arg("out", "/tmp/p4l/x.png").get_base_dir()
	var scene: Node = rig.scene()
	var hero: Node3D = scene.get_node_or_null(^"Hero") as Node3D
	var fails := 0

	if hero == null:
		print("LUNGE FAIL no Hero in the scene")
		return
	var combat: Node = hero.get(&"combat")
	if combat == null:
		print("LUNGE FAIL no HeroCombat on the Hero")
		return
	var post: Node = scene.get_node_or_null(^"PostA")
	if post == null:
		print("LUNGE FAIL no PostA to lock onto")
		return
	post.connect(&"struck", _on_struck)
	var post_pos: Vector3 = (post as Node3D).global_position

	# One lockable thing in the room. Targeting scores candidates by screen angle
	# (targeting.gd), so from the middle of the floor the nearest post to the
	# centre of the picture wins — which was PostC, and the whole run then
	# measured a leap at a target this director was not watching.
	for other in ["PostB", "PostC"]:
		var n: Node = scene.get_node_or_null(NodePath(other))
		if n != null:
			n.remove_from_group(&"targetable")

	await rig.wait_frames(30)

	# --- a plain light swing, for the damage the lunge has to beat -----------
	# First, and point-blank, so it definitely connects: what is being compared
	# is the blow's SIZE, not its reach. Taken before anything else because a
	# baseline measured after the leap was measured on a hero the leap had
	# shoved somewhere else, and it silently came back as zero — which made the
	# "the lunge out-damages a light swing" check pass against nothing.
	_place_at(hero, post_pos, 1.1)
	await rig.wait_frames(SETTLE)
	var light := await _press_and_land(rig, "attack")
	print("LUNGE light dmg=%d" % light)
	if light <= 0:
		print("LUNGE FAIL the light baseline swing landed nothing"); fails += 1

	# --- locked, stick forward: the leap ------------------------------------
	_place(hero, post_pos)
	# The camera has to CATCH UP before the stick means anything. `move_up` is
	# screen-forward and the hero reads it camera-relative, so a stick pressed
	# while the camera is still swinging round from the last shot points
	# somewhere else entirely — at 20 frames it read 92 degrees off the target
	# and the lunge was correctly refused for a reason that had nothing to do
	# with the lunge.
	await rig.wait_frames(SETTLE)
	# Lock on. The post is in the `targetable` group (training_post.gd), so it is
	# a legal target before a single enemy exists.
	var presses := await _lock_on(rig, hero)
	var locked: bool = hero.call(&"lock_target") != null
	print("LUNGE locked=%s after %d press(es)" % [locked, presses])
	if not locked:
		print("LUNGE FAIL z_target did not acquire the post"); fails += 1
	await rig.capture(out.path_join("l_00_locked.png"))

	var before := _gap(hero, post_pos)
	if before < START_RANGE - 0.4:
		print("LUNGE FAIL could not place the hero: %.2fm out, wanted %.2fm — he is stuck on something"
			% [before, START_RANGE]); fails += 1
	var dmg := await _lunge(rig, hero)
	await rig.wait_frames(40)
	var after := _gap(hero, post_pos)
	var closed := before - after
	print("LUNGE locked: %.2fm -> %.2fm (closed %.2fm) dmg=%d"
		% [before, after, closed, dmg])
	await rig.capture(out.path_join("l_01_after_lunge.png"))

	# --- unlocked, same inputs: no leap -------------------------------------
	await rig.wait_seconds(1.2)
	# Drop the lock. z_target toggles (targeting.gd), so a second press releases.
	await _lock_off(rig, hero)
	if hero.call(&"lock_target") != null:
		print("LUNGE FAIL still locked after releasing z_target"); fails += 1
	_place(hero, post_pos)
	await rig.wait_frames(SETTLE)
	var free_before := _gap(hero, post_pos)
	var free_dmg := await _lunge(rig, hero)
	await rig.wait_frames(40)
	var free_after := _gap(hero, post_pos)
	var free_closed := free_before - free_after
	print("LUNGE unlocked: %.2fm -> %.2fm (closed %.2fm) dmg=%d"
		% [free_before, free_after, free_closed, free_dmg])
	await rig.capture(out.path_join("l_02_unlocked.png"))

	if dmg <= 0:
		print("LUNGE FAIL the leap landed nothing"); fails += 1
	if dmg <= light:
		print("LUNGE FAIL lunge (%d) does not out-damage a light swing (%d)"
			% [dmg, light]); fails += 1
	# The drive is `lunge_drive_time` long and the hero also walks a little on the
	# stick lead, so this is a floor, not an equality. Half the gap is well past
	# anything walking could account for in a fifth of a second.
	if closed < (START_RANGE - 1.0) * 0.5:
		print("LUNGE FAIL closed only %.2fm of a %.2fm gap — that is a walk, not a leap"
			% [closed, START_RANGE]); fails += 1
	if after < 0.6:
		print("LUNGE FAIL ended %.2fm from the post — the leap overshoots into it"
			% after); fails += 1
	# Unlocked he is allowed to WALK — the stick is held, and holding forward is
	# supposed to move you. What he must not do is TRAVEL: the comparison is
	# against the same inputs with the lock off, for the same number of frames,
	# so anything the walk can explain is subtracted out by construction.
	if closed < free_closed + 1.5:
		print("LUNGE FAIL locked closed %.2fm, unlocked closed %.2fm — the lock buys nothing"
			% [closed, free_closed]); fails += 1

	print("LUNGE %s (fails=%d)" % ["OK" if fails == 0 else "FAIL", fails])


## Ground distance to the post. Flattened, because the lunge hops and a 3D
## distance would count the hero's height off the floor as ground he failed to
## cover — and flattened BY HAND, because K.flat normalises. This director once
## reported every gap as exactly 1.00 m for that reason.
func _gap(hero: Node3D, post_pos: Vector3) -> float:
	var d := hero.global_position - post_pos
	return Vector2(d.x, d.z).length()


## Stand the hero START_RANGE metres out from the post, facing it.
##
## Placed along the line from the post toward the middle of the ROOM, not along
## +Z. Straight +Z from PostA is the far wall: the first version of this put the
## hero inside it, physics shoved him back out, and he then could neither walk
## nor leap because he was pressed against geometry — which read exactly like a
## broken lunge.
##
## facing_yaw is the HEADING yaw (docs/CONTRACT.md §2.5): heading is
## (sin y, 0, cos y), so the yaw that points at the post is atan2(dx, dz) of the
## vector FROM the hero TO it.
func _place(hero: Node3D, post_pos: Vector3) -> void:
	_place_at(hero, post_pos, START_RANGE)


func _place_at(hero: Node3D, post_pos: Vector3, range_m: float) -> void:
	var inward := Vector3(-post_pos.x, 0.0, -post_pos.z)
	if inward.length() < 0.01:
		inward = Vector3(0.0, 0.0, 1.0)
	inward = inward.normalized()
	hero.global_position = post_pos + inward * range_m + Vector3(0.0, 0.05, 0.0)
	hero.set(&"facing_yaw", atan2(-inward.x, -inward.z))


## Hold the stick toward the target, press `heavy`, and report what landed.
##
## The stick is no longer a GATE — the lunge stopped sharing the attack button,
## and a hidden stick rule on a dedicated button is just a button that
## intermittently does nothing. It is still held here because the unlocked run
## is a CONTROL: both runs get identical inputs, so any ground the unlocked hero
## covers by simply walking is subtracted out by construction.
func _lunge(rig, _hero: Node3D) -> int:
	var before := _hits.size()
	Input.action_press(&"move_up")
	await rig.wait_frames(STICK_LEAD)
	# Held for a good handful of frames, not the two rig.tap uses. `just_pressed`
	# is answered against the PHYSICS frame counter: a press and release that
	# both land between two physics ticks never happened as far as the game is
	# concerned, and this director lost a whole unlocked attack that way.
	Input.action_press(&"heavy")
	# The stick comes off almost immediately: held any longer it lets the
	# unlocked control run at the post under its own steam, which is ground
	# closed that has nothing to do with a leap.
	await rig.wait_frames(2)
	Input.action_release(&"move_up")
	await rig.wait_frames(8)
	Input.action_release(&"heavy")
	for _i in 240:
		if _hits.size() > before:
			return _hits[before]
		await rig.wait_frames(1)
	return 0


## Press z_target until the hero is actually locked, and report how many presses
## it took. More than one is worth knowing about — Targeting drops the queued
## press outright while `Prompt.blocked` (a fade, a shop), so an early press in a
## freshly loaded scene can simply evaporate. Retrying is honest here because
## the button is a TOGGLE and the state, not the press, is what this needs.
func _lock_on(rig, hero: Node3D) -> int:
	for i in 4:
		if hero.call(&"lock_target") != null:
			return i
		await rig.tap(["z_target"])
		await rig.wait_frames(SETTLE)
	return 4


func _lock_off(rig, hero: Node3D) -> void:
	for _i in 4:
		if hero.call(&"lock_target") == null:
			return
		await rig.tap(["z_target"])
		await rig.wait_frames(20)



func _on_struck(amount: int, _from: Vector3) -> void:
	_hits.append(amount)


func _press_and_land(rig, action: String) -> int:
	var before := _hits.size()
	await rig.hold([action], 10)
	for _i in 240:
		if _hits.size() > before:
			return _hits[before]
		await rig.wait_frames(1)
	return 0
