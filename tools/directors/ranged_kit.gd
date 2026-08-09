extends RefCounted
## Do the bow and the hookshot actually work when you press the button?
##
## The button is `use_item` (A / F). `attack` is the SWORD now and pressing it
## with an item drawn stows the item and swings — see tools/directors/buttons.gd
## for that half. Firing here goes through the use button, which is the one a
## player with a bow in his hands actually presses.
##
## Prints `RANGED FAIL ...` on any beat that did not happen, and photographs the
## ones that have pixels — the drawn bow, the arrow in the air, the chain out,
## the hero at the end of it. A boolean that flipped is not proof that a chain
## was drawn; every real bug in this project was found by looking at the frame.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/ranged_kit.gd --out=/tmp/ranged/x.png

var out := ""
var fails := 0
## Where he starts: open floor with room in every direction. The hookshot beats
## end by slamming him into a wall, and a beat that fires from wherever the last
## pull dumped him is testing the room, not the item.
var home := Vector3.ZERO


func run(rig) -> void:
	out = rig.arg("out", "/tmp/ranged/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await rig.wait_frames(20)

	var hero = rig.get_nodes_in_group(&"player")[0]
	home = hero.global_position

	await _starter_kit(rig)
	await _bow(rig, hero)
	await _empty_quiver(rig, hero)
	await _hookshot_ring(rig, hero)
	await _hookshot_wall(rig, hero)

	print("RANGED done, %d failure(s)" % fails)


# --- The starter kit --------------------------------------------------------

func _starter_kit(rig) -> void:
	_check("the bow is owned at boot", Game.has(&"bow"))
	_check("the hookshot is owned at boot", Game.has(&"hookshot"))
	_check("there are arrows to fire (%d)" % Game.arrows, Game.arrows > 0)
	_check("the bow took dpad left (%s)" % Game.quick(Game.QUICK_LEFT),
		Game.quick(Game.QUICK_LEFT) == &"bow")
	_check("the hookshot took dpad up (%s)" % Game.quick(Game.QUICK_UP),
		Game.quick(Game.QUICK_UP) == &"hookshot")
	await rig.wait_frames(20)
	await rig.capture(out.path_join("r_00_kit.png"))


# --- The bow ----------------------------------------------------------------

func _bow(rig, hero) -> void:
	# dpad left draws it. Nothing cycles in play (docs/CONTRACT.md §4.1), so the
	# button is pressed rather than the loadout being set behind the game's back.
	await rig.tap(["item_left"])
	await rig.wait_frames(8)
	_check("dpad left drew the bow (right hand is %s)" % Game.armament(Game.HAND_RIGHT),
		Game.armament(Game.HAND_RIGHT) == &"bow")
	_check("the bow model is in his hands", _visible(hero.combat.bow))
	# A kite shield growing out of a bowstring: both used to be on the left arm.
	_check("the shield came off the bow arm", not _visible(hero.combat.shield))
	var cam = hero.get_viewport().get_camera_3d()
	if cam == null:
		_fail("no camera, so there is no aim and nothing to photograph")
		return
	# Selecting it must not zoom. Carrying a bow is not aiming a bow, and the
	# framing this photo used to be taken in — shoulder rig, 42° lens — is now
	# something the trigger buys and the D-pad does not.
	_check("selecting the bow did not zoom", not cam.aiming())
	await rig.wait_frames(24)
	await rig.capture(out.path_join("r_01_bow_carried.png"))

	# --- Shot one: aimed by the camera ---------------------------------------
	# The post is moved ONTO the camera's forward ray rather than the shot being
	# aimed at the post. Aim is what is under test, and a fixture parked at a
	# coordinate I worked out on paper would be testing my arithmetic.
	var post = _nearest_post(rig, hero)
	if post == null:
		_fail("no training post to shoot at")
		return

	# HELD, not tapped, and the fixture is not placed until the rig has arrived.
	# The stance belongs to the trigger now, so the eye is still out on the free
	# boom on the frame the button goes down and slides 0.6 m to his right over
	# the next sixth of a second. A post placed on the ray read before that slide
	# is a post the settled crosshair is half a metre off — the arrow flies true
	# and misses, and the beat reports the aim as broken. Holding also costs
	# nothing: the pull parks at full draw for as long as the button is down.
	Input.action_press(&"use_item")
	await rig.wait_frames(30)
	_check("the trigger put the camera over the shoulder", cam.aiming())
	_check("holding the trigger raised the bow (stance=%s)" % hero.aim_item(),
		hero.aim_item() == &"bow")
	await rig.capture(out.path_join("r_01b_bow_drawn.png"))
	var aim: Vector3 = -cam.global_transform.basis.z
	# From the CAMERA, not from the hero. Over the shoulder the eye sits ~0.6 m to
	# his right, so the crosshair ray and the hero's centre line are parallel and
	# half a metre apart — a post on the hero's line is not the thing under the
	# crosshair, and the arrow correctly sails past it. This is the whole reason
	# `_aim_from` converges on the crosshair POINT instead of firing parallel.
	#
	# Six metres out, not nine. The aim is a raycast to whatever the crosshair is
	# over, so a post parked BEHIND the room's barrels is not what is being aimed
	# at. The fixture has to be the first thing on the line, same as for a player.
	post.global_position = cam.global_position + K.flat(aim) * 6.0
	post.global_position.y = 0.0
	await rig.wait_frames(10)

	var before_arrows := Game.arrows
	var before_damage: int = post.total_damage
	# The release is the shot. He is already at full draw, so the arrow leaves at
	# the seam a fraction of a second later, aimed down the ray measured above.
	Input.action_release(&"use_item")
	# Watched frame by frame rather than sampled once. The arrow leaves at the
	# seam between the charge clip and the loose — the far end of a 0.44 s draw —
	# and the first version of this beat looked on a fixed frame, found the arrow
	# already spent, and reported that no arrow had ever existed. Photographing
	# the frame it is FOUND on is also the only way to be sure the picture has an
	# arrow in it.
	var arrows_out := 0
	for i in 60:
		await rig.wait_frames(1)
		arrows_out = _arrows_in_flight(rig)
		if arrows_out > 0:
			break
	await rig.capture(out.path_join("r_02_arrow_in_flight.png"))

	await rig.wait_frames(40)
	_check("firing spent exactly one arrow (%d -> %d)" % [before_arrows, Game.arrows],
		Game.arrows == before_arrows - 1)
	_check("an arrow existed in the world after the shot", arrows_out > 0)
	_check("the camera-aimed arrow hurt the post (%d -> %d)"
		% [before_damage, post.total_damage], post.total_damage > before_damage)
	await rig.capture(out.path_join("r_03_arrow_landed.png"))

	# --- Shot two: aimed by the lock, at a post the camera is NOT pointed at --
	# Locked on, the bow shoots the target and not the crosshair. Proving that
	# needs a target off the camera ray, or the two aims agree and the assertion
	# passes without testing anything.
	#
	# The lock is set here rather than by pressing z_target: Targeting reads the
	# press in `_unhandled_input`, and `Input.action_press` sets action state but
	# dispatches NO InputEvent (CLAUDE.md §3), so a synthetic press never reaches
	# it. This is the director standing in for a thumb, not a shortcut around a
	# gate — the gate under test is the aim, not the toggle.
	var side = _other_post(rig, post)
	if side == null:
		_fail("no second post to put off-axis")
		return
	# Off to one side, but on a side he can actually SEE. The proving ground has a
	# raised ledge to the hero's right, and the first version of this beat parked
	# the post inside it: every locked arrow struck the ledge and the director
	# blamed the lock for what was a fixture in a wall. Line of sight is checked
	# rather than assumed.
	var right: Vector3 = K.flat(cam.global_transform.basis.x)
	# `await`ed: _park_off_axis waits out the lock's grace period, so calling it
	# bare would hand back a coroutine and test that a Signal is truthy.
	var parked: bool = await _park_off_axis(rig, hero, side, K.flat(aim), right)
	if not parked:
		_fail("nowhere off-axis where the lock survives — the room has no clear side")
		return
	_check("the lock is holding a post off the camera ray", hero.lock_target() == side)

	var side_before: int = side.total_damage
	await rig.tap(["use_item"])
	# Named, because the failure it catches is silent otherwise: the arrow is
	# aimed at RELEASE, a quarter of a second after the press, and `Targeting`
	# drops a lock whose line of sight lapses. A lock that quietly expires in
	# that gap sends the shot back to the camera aim, which looks exactly like
	# the lock override never having been written.
	_check("the lock survived the draw", hero.lock_target() == side)
	await rig.wait_frames(50)
	_check("the locked shot hurt the post the camera was NOT aimed at (%d -> %d)"
		% [side_before, side.total_damage], side.total_damage > side_before)
	await rig.capture(out.path_join("r_03b_locked_shot.png"))

	hero.targeting.is_locked = false
	hero.targeting.current_target = null
	await rig.wait_frames(6)


## A bow with an empty quiver must refuse, and must refuse WITHOUT costing
## anything or leaving the hero mid-shot. This is the check that catches a
## `spend_ammo` called on the press instead of on the release.
func _empty_quiver(rig, hero) -> void:
	var post = _nearest_post(rig, hero)
	# `total_damage` is a READOUT, not a ledger: training_post.gd clears it after
	# `readout_reset` seconds of quiet. Comparing it before and after a window is
	# therefore only meaningful from a baseline of zero — the first version of
	# this beat captured a live tally, the tally expired mid-window, and the
	# director reported a shot that never happened.
	if post != null:
		await _wait_for_quiet_post(rig, post)

	var kept := Game.arrows
	Game.arrows = 0
	await rig.tap(["use_item"])
	# Sampled every frame rather than once at the end, so an arrow that landed
	# and whose readout then expired cannot slip through the gap.
	var struck := false
	for i in 50:
		await rig.wait_frames(1)
		if post != null and post.total_damage > 0:
			struck = true
	_check("an empty quiver fires nothing", Game.arrows == 0)
	if post != null:
		_check("an empty quiver damaged nothing", not struck)
	Game.add_arrows(kept)
	await rig.wait_frames(4)

	# Put the bow away, so the hookshot beats start clean.
	await rig.tap(["item_left"])
	await rig.wait_frames(6)
	_check("dpad left again put the bow away (right hand is %s)"
		% Game.armament(Game.HAND_RIGHT), Game.armament(Game.HAND_RIGHT) == &"sword")


# --- The hookshot, onto an authored ring ------------------------------------

func _hookshot_ring(rig, hero) -> void:
	await rig.tap(["item_up"])
	await rig.wait_frames(8)
	_check("dpad up drew the hookshot (right hand is %s)" % Game.armament(Game.HAND_RIGHT),
		Game.armament(Game.HAND_RIGHT) == &"hookshot")
	_check("the hookshot model is in his hand", _visible(hero.combat.hookshot))
	await rig.capture(out.path_join("r_04_hookshot_drawn.png"))

	# The ring is placed ON the camera's forward ray at runtime rather than at
	# an address I worked out on paper. The aim-assist cone is what is under
	# test; a ring parked at a hand-computed coordinate tests my trigonometry
	# instead, and fails the day the camera's pitch is retuned.
	var cam = hero.get_viewport().get_camera_3d()
	if cam == null:
		_fail("no camera, so there is no aim to place a ring on")
		return
	var muzzle: Vector3 = hero.global_position + Vector3.UP * 1.2
	var aim: Vector3 = -cam.global_transform.basis.z
	var ring := HookTarget.new()
	ring.name = "TestRing"
	rig.scene().add_child(ring)
	ring.global_position = muzzle + aim * 7.0
	# Local +Z is "out from the face it is mounted on" (hook_target.gd), so it
	# faces the hero — otherwise pull_point() nudges him THROUGH the wall.
	ring.look_at(hero.global_position, Vector3.UP)
	ring.rotate_object_local(Vector3.UP, PI)
	await rig.wait_frames(6)

	var start: Vector3 = hero.global_position
	var pull: Vector3 = ring.pull_point()
	await rig.tap(["use_item"])
	await rig.wait_frames(6)
	_check("the chain went out", hero.hooking())
	await rig.capture(out.path_join("r_05_chain_out.png"))

	# Watch the whole pull rather than sampling the end: the closest he ever gets
	# is the honest measure of where the hook took him, and a frame-perfect
	# check on arrival would pass or fail on how busy the machine is.
	var closest := 1e9
	for i in 90:
		await rig.wait_frames(1)
		closest = minf(closest, hero.global_position.distance_to(pull))
		if not hero.hooking():
			break
	var travelled := start.distance_to(hero.global_position)
	print("RANGED hook travelled %.2f m, closest approach %.2f m" % [travelled, closest])
	_check("the hook moved him a real distance (%.2f m)" % travelled, travelled > 3.0)
	_check("he arrived at the ring's pull point (%.2f m off)" % closest, closest < 1.2)
	_check("the pull released him", not hero.hooking())
	await rig.capture(out.path_join("r_06_hook_arrived.png"))

	ring.queue_free()
	await rig.wait_frames(6)


# --- The hookshot, onto plain geometry --------------------------------------
## No ring anywhere: the raycast fallback is what has to catch the wall. This is
## the case that makes the hookshot usable in a room nobody authored an anchor
## into, and it is the one that would silently rot if only the ring were tested.

func _hookshot_wall(rig, hero) -> void:
	# The ring shot leaves him in mid-air off a wall, and `request_hookshot`
	# refuses while he is not on the floor — same gate the sword uses. Waiting
	# for the landing is not padding: a beat that fires while he is still falling
	# tests the refusal, then blames the hookshot for it.
	await _wait_for_floor(rig, hero)

	# Back to open floor. The ring pull ends with him a metre from the surface it
	# anchored to, and firing from there hooks a wall he is already standing at:
	# the chain arrives on the first frame, the pull distance is nothing, and the
	# beat reports that no chain went out. It did — there was just nowhere to go.
	hero.global_position = home
	hero.velocity = Vector3.ZERO
	await _wait_for_floor(rig, hero)
	await rig.wait_frames(20)

	var start: Vector3 = hero.global_position
	var rings: Array = rig.get_nodes_in_group(&"hookable")
	_check("no authored ring is left standing for the fallback beat", rings.is_empty())
	print("RANGED wall is %.2f m away along the aim" % _wall_distance(hero))

	await rig.tap(["use_item"])
	# Polled rather than sampled at a fixed frame: how long the chain is out
	# depends on how far the wall is, and a beat that reads `hooking()` on frame
	# eight and nowhere else fails whenever the answer is "it already arrived".
	var fired := false
	for i in 20:
		await rig.wait_frames(1)
		if hero.hooking():
			fired = true
			break
	await rig.capture(out.path_join("r_07_wall_chain.png"))

	for i in 120:
		await rig.wait_frames(1)
		if not hero.hooking():
			break
	var travelled := start.distance_to(hero.global_position)
	print("RANGED wall shot fired=%s travelled %.2f m" % [fired, travelled])
	_check("a shot with no ring still put the chain out", fired)
	_check("the raycast fallback moved him (%.2f m)" % travelled, travelled > 1.0)
	_check("the hero is not stuck on the hook", not hero.hooking())
	await rig.capture(out.path_join("r_08_wall_arrived.png"))


# --- Helpers ----------------------------------------------------------------

## Wait for a post's damage readout to clear itself, so a later "nothing hit it"
## can be read off a baseline of zero instead of off a number that expires.
func _wait_for_quiet_post(rig, post) -> void:
	for i in 400:
		if post.total_damage == 0:
			return
		await rig.wait_frames(1)
	_fail("the post's damage readout never cleared")


## Block until the hero has feet on the ground again, or give up loudly. Every
## ranged action is gated on `is_on_floor()`.
func _wait_for_floor(rig, hero) -> void:
	for i in 180:
		if hero.is_on_floor():
			await rig.wait_frames(6)
			return
		await rig.wait_frames(1)
	_fail("the hero never landed after the hook pull")


## Move `post` somewhere off to one side that the hero can genuinely lock, and
## return whether that worked.
##
## It tries candidates and, for each, sets the lock and waits — the acceptance
## test is `Targeting` still holding the lock a moment later, not my own idea of
## what "visible" means. That distinction is the whole point: the proving ground
## is not symmetrical, the first version of this beat parked the post inside a
## raised ledge, `Targeting` dropped the lock on line of sight the frame after
## the director checked it, and the shot fell back to the camera aim. Which
## reads, on the log, exactly like the lock override never having been written.
##
## Waiting past `los_grace` is the part that matters. A lock is allowed to lapse
## briefly, so a spot that looks locked for six frames can still be gone by the
## time the arrow leaves.
func _park_off_axis(rig, hero, post, forward: Vector3, right: Vector3) -> bool:
	for lateral in [-3.0, 3.0, -2.2, 2.2]:
		for ahead in [4.5, 3.0, 6.0]:
			var spot: Vector3 = hero.global_position + forward * ahead + right * lateral
			spot.y = 0.0
			post.global_position = spot
			hero.targeting.current_target = post
			hero.targeting.is_locked = true
			await rig.wait_frames(24)
			if hero.lock_target() == post:
				print("RANGED off-axis post parked %.1f m ahead, %.1f m to the side"
					% [ahead, lateral])
				return true
	return false


## How far the wall is along the way he is looking. Printed, not asserted: it is
## the number that explains a short pull, and it belongs in the log next to it.
func _wall_distance(hero) -> float:
	var cam = hero.get_viewport().get_camera_3d()
	if cam == null:
		return -1.0
	var eye: Vector3 = hero.global_position + Vector3.UP * K.HERO_EYE_Y
	var aim: Vector3 = -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(eye, eye + aim * K.HOOK_RANGE)
	q.collision_mask = K.L_WORLD
	q.exclude = [hero.get_rid()]
	var hit: Dictionary = hero.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return -1.0
	return eye.distance_to(hit["position"] as Vector3)


func _other_post(rig, exclude):
	for node in rig.get_nodes_in_group(&"targetable"):
		if node is TrainingPost and node != exclude:
			return node
	return null


func _nearest_post(rig, hero):
	var best = null
	var best_d := 1e9
	for node in rig.get_nodes_in_group(&"targetable"):
		if not (node is TrainingPost):
			continue
		var d: float = (node as Node3D).global_position.distance_to(hero.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best


func _arrows_in_flight(rig) -> int:
	var n := 0
	for node in rig.scene().get_children():
		if node is Arrow:
			n += 1
	return n


func _visible(node) -> bool:
	return node != null and (node as Node3D).is_visible_in_tree()


func _check(what: String, ok: bool) -> void:
	if ok:
		print("RANGED ok   %s" % what)
	else:
		_fail(what)


func _fail(what: String) -> void:
	fails += 1
	print("RANGED FAIL %s" % what)
