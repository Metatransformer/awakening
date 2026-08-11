extends RefCounted
## The two reactions: does the parry pay, does it PUNISH, and does a well-timed
## dodge buy time?
##
## Six beats, and five of them are numbers rather than pictures — which is the
## point. Almost everything that can be wrong here is invisible in a still:
##
##   * **the parry lands** — a blow caught inside `K.PARRY_WINDOW` costs no
##     health, throws the thing that swung, and opens the riposte.
##   * **the parry whiffs** — and the guard is DOWN for `K.PARRY_RECOVER`, so
##     the next blow lands in full. This is the beat that proves the move has a
##     price, and a parry with no price is not a parry.
##   * **the perfect dodge** — a roll through a live blow inside `K.DODGE_GRACE`
##     dips `Engine.time_scale` and opens the flurry window.
##   * **the stale dodge** — the SAME roll, the same blow, thrown late. No dip.
##     Without this beat "perfect" would be a word for "mid-roll".
##   * **the flurry** — the window turns the attack button into the leap, and
##     the leap leaves the ground and lands a heavy blow.
##   * **the look** — the two bursts, held, so the gold and the cold ring can be
##     told apart at a glance.
##
## The blows are real `DamageArea`s fired at the hero rather than monsters left
## to swing on their own schedule. That is not a shortcut around the AI — it is
## the only way to hold the ONE variable this whole file is about, which is the
## number of milliseconds between the press and the impact. A director that
## waited for a goblin to decide to attack would be measuring the goblin.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/parry_dodge.gd --out=/tmp/parry/x.png

## The hero's heading yaw for -Z. `facing_yaw` IS the heading and the heading is
## `(sin y, 0, cos y)`, so -Z is PI (`docs/CONTRACT.md` §2.5).
const FACE_MINUS_Z := PI

## Hero and attacker, in the garrison courtyard. The attacker stands 1.9 m
## straight ahead of the hero, which is inside `parry_cone` (45 deg) by a wide
## margin — the cone is not what this director is testing and a shot that
## grazed its edge would fail for a reason nobody was asking about.
const HERO_AT := Vector3(0.0, 0.05, 7.4)
const FOE_AT := Vector3(0.0, 0.05, 5.5)

var _fails: int = 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/parry/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	await _parry_lands(rig, out)
	await _parry_whiffs(rig)
	await _perfect_dodge(rig, out)
	await _stale_dodge(rig)
	await _flurry(rig, out)
	await _look(rig, out)

	if _fails == 0:
		print("PARRY OK")


# --- Beat one: the parry pays -------------------------------------------------

func _parry_lands(rig, out: String) -> void:
	var hero: Node3D = _hero(rig)
	if hero == null:
		return
	var combat = hero.get(&"combat")
	var foe := _foe(rig, 7001)
	await rig.wait_frames(20)
	Bus.camera_recenter.emit()
	# Immortal, because this beat wants to see it thrown and a corpse launches on
	# a different impulse (`Enemy._on_died`).
	foe.health.max_quarters = 100000
	foe.health.quarters = 100000
	foe.set_physics_process(false)

	var hp_before: int = Game.quarters
	# The press. Called rather than driven through Input for the reason the class
	# docstring gives: this beat is about the gap between the press and the blow,
	# and `Input.action_press` is delivered on a frame boundary the director does
	# not own.
	combat.call(&"_parry")
	if combat.get(&"_parry_t") < 0.0:
		_fail("the parry refused to start from a standing hero")
		foe.queue_free()
		return
	await rig.capture(out.path_join("parry_00_shield_out.png"))

	# Inside the window, by construction: one physics frame is 1/60 s and
	# K.PARRY_WINDOW is 0.20.
	await _swing_at(rig, foe, hero)
	await rig.wait_physics_frames(2)
	await rig.capture(out.path_join("parry_01_caught.png"))

	if Game.quarters != hp_before:
		_fail("a parried blow still cost %d quarters"
			% (hp_before - Game.quarters))
	if combat.get(&"_riposte_t") <= 0.0:
		_fail("the parry landed and opened no riposte window")
	# THE OPENING. A staggered body is one that is not swinging, so the assertion
	# is on the state and not on a flinch that might merely be playing.
	var thrown := foe.state == Enemy.State.HURT or foe.state == Enemy.State.LAUNCHED
	print("PARRY landed  foe_state=%d riposte=%.2f hp=%d/%d"
		% [foe.state, combat.get(&"_riposte_t"), Game.quarters, Game.max_quarters])
	if not thrown:
		_fail("a parried goblin is in state %d -- it was not staggered" % foe.state)
	# And the hero is free, not serving out a punish he did not earn.
	if hero.get(&"state") == 4:  # Hero.MoveState.ATTACK
		_fail("the hero is still committed after a parry that landed")

	# The riposte: an attack press in the window comes out as the DASH.
	await rig.wait_frames(4)
	combat.call(&"_tick_light_button")
	Input.action_press(&"attack")
	await rig.wait_physics_frames(2)
	Input.action_release(&"attack")
	await rig.wait_physics_frames(2)
	await rig.capture(out.path_join("parry_02_riposte.png"))
	foe.queue_free()
	await rig.wait_frames(4)


# --- Beat two: the parry punishes ---------------------------------------------

## Whiff it, then hit him. The blow must land in full.
##
## This is the beat that proves the price exists, and it is the one a future
## session is most likely to break by "fixing" the guard so it comes back up
## between the window and the end of the move.
func _parry_whiffs(rig) -> void:
	var hero: Node3D = _hero(rig)
	if hero == null:
		return
	var combat = hero.get(&"combat")
	var foe := _foe(rig, 7002)
	await rig.wait_frames(16)
	foe.set_physics_process(false)
	# The guard is UP going in, so what the beat measures is the parry dropping
	# it and not merely a hero who was never blocking.
	combat.set(&"blocking", true)
	hero.call(&"set_blocking", true)
	# i-frames from the previous beat would swallow the blow and the failure
	# would read as "the recovery is safe".
	hero.set(&"_invuln", 0.0)

	combat.call(&"_parry")
	if combat.get(&"blocking"):
		_fail("the shield is still up on the frame the parry started")
	# Past the window, inside the recovery.
	await rig.wait_seconds(K.PARRY_WINDOW + 0.08)
	if combat.call(&"parries", foe.global_position):
		_fail("the parry is still live %.2f s in -- the window does not close"
			% (K.PARRY_WINDOW + 0.08))
	if combat.call(&"blocks", foe.global_position):
		_fail("the guard is back up during the parry's recovery -- there is no punish")

	var hp_before: int = Game.quarters
	await _swing_at(rig, foe, hero)
	await rig.wait_physics_frames(3)
	var lost := hp_before - Game.quarters
	print("PARRY whiffed  lost=%d quarters (hp %d -> %d)"
		% [lost, hp_before, Game.quarters])
	if lost <= 0:
		_fail("a blow during the parry's recovery cost nothing -- a missed parry"
			+ " has to be a hole")
	foe.queue_free()
	await rig.wait_frames(4)


# --- Beat three: the dodge buys time ------------------------------------------

func _perfect_dodge(rig, out: String) -> void:
	var hero: Node3D = _hero(rig)
	if hero == null:
		return
	var combat = hero.get(&"combat")
	var foe := _foe(rig, 7003)
	await rig.wait_frames(16)
	foe.set_physics_process(false)
	hero.set(&"_invuln", 0.0)
	Feel._slow_until = 0
	Feel._slow_scale = 1.0
	Engine.time_scale = 1.0

	if not _roll(rig, hero):
		foe.queue_free()
		return
	await rig.wait_physics_frames(2)

	var hp_before: int = Game.quarters
	await _swing_at(rig, foe, hero)
	await rig.wait_physics_frames(2)
	var scale := Engine.time_scale
	await rig.capture(out.path_join("parry_10_dodge.png"))

	print("PARRY dodge  time_scale=%.2f flurry=%.2f hp=%d"
		% [scale, combat.get(&"_flurry_t"), Game.quarters])
	if Game.quarters != hp_before:
		_fail("a dodged blow still cost %d quarters" % (hp_before - Game.quarters))
	if scale >= 0.99:
		_fail("a perfect dodge did not slow time down (scale %.2f)" % scale)
	if combat.get(&"_flurry_t") <= 0.0:
		_fail("a perfect dodge opened no flurry window")

	# And it has to END. A dip that never lifts is the whole game stuck at a
	# third speed, which is the exact failure `Feel._tick_time` exists to make
	# impossible -- so it is worth asserting rather than assuming.
	var back: bool = await rig.until(
		func() -> bool: return Engine.time_scale >= 0.99, 2.5)
	if not back:
		_fail("time never came back up: scale is %.2f" % Engine.time_scale)
	foe.queue_free()
	await rig.wait_frames(4)


# --- Beat four: and a late one does not ---------------------------------------

## The same roll and the same blow, thrown after `K.DODGE_GRACE`. Nothing should
## happen except the blow missing, which it does anyway because the hero is
## mid-roll.
##
## Without this beat, "perfect dodge" would mean "any dodge", and the reward for
## reading a telegraph would be handed to a player who rolled at random.
func _stale_dodge(rig) -> void:
	var hero: Node3D = _hero(rig)
	if hero == null:
		return
	var combat = hero.get(&"combat")
	var foe := _foe(rig, 7004)
	await rig.wait_frames(16)
	foe.set_physics_process(false)
	hero.set(&"_invuln", 0.0)
	combat.set(&"_flurry_t", 0.0)
	Feel._slow_until = 0
	Feel._slow_scale = 1.0
	Engine.time_scale = 1.0

	if not _roll(rig, hero):
		foe.queue_free()
		return
	# Past the grace and still rolling. `roll_time` is 0.44 and the grace is
	# 0.30, so this window genuinely exists -- if either number moves so that it
	# does not, this beat starts failing, which is the correct outcome.
	await rig.wait_seconds(K.DODGE_GRACE + 0.06)
	var still_rolling: bool = hero.get(&"state") == 2  # Hero.MoveState.ROLL
	await _swing_at(rig, foe, hero)
	await rig.wait_physics_frames(2)
	print("PARRY stale   rolling=%s time_scale=%.2f flurry=%.2f"
		% [still_rolling, Engine.time_scale, combat.get(&"_flurry_t")])
	if not still_rolling:
		_fail("the roll was over %.2f s in, so this beat proved nothing"
			% (K.DODGE_GRACE + 0.06))
	elif Engine.time_scale < 0.99:
		_fail("a LATE dodge slowed time down -- the grace window does nothing")
	elif combat.get(&"_flurry_t") > 0.0:
		_fail("a late dodge opened the flurry window")
	foe.queue_free()
	await rig.wait_frames(4)


# --- Beat five: the leap ------------------------------------------------------

func _flurry(rig, out: String) -> void:
	var hero: Node3D = _hero(rig)
	if hero == null:
		return
	var combat = hero.get(&"combat")
	var foe := _foe(rig, 7005)
	await rig.wait_frames(20)
	Bus.camera_recenter.emit()
	foe.health.max_quarters = 100000
	foe.health.quarters = 100000
	# Held still. This beat is about the hero leaving the floor and arriving, and
	# a goblin free to walk out of the landing zone turns a movement assertion
	# into a coin toss on where its AI happened to be.
	foe.set_physics_process(false)
	foe.state = Enemy.State.IDLE
	hero.global_position = HERO_AT
	hero.set(&"facing_yaw", FACE_MINUS_Z)
	hero.set(&"state", 0)  # GROUND
	Game.stamina = K.MAX_STAMINA
	await rig.wait_frames(6)

	# Hand the window over directly. Earning it again here would make this beat
	# depend on beat three passing, and a director whose beats fail in cascades
	# tells you about one bug five times.
	combat.set(&"_flurry_t", K.FLURRY_WINDOW)
	# `rig.tap` and not a bare `Input.action_press`: the press has to be stamped
	# at the TOP of a frame or `is_action_just_pressed` compares it against a
	# frame that has already gone by and every polled button ignores it
	# (`shoot.gd:hold`). This is the trap in CLAUDE.md §3, one layer along.
	await rig.tap([&"attack"])
	var swung: float = combat.get(&"_swing_t")

	var airborne := false
	var top := hero.global_position.y
	var shots := 0
	for i in 90:
		await rig.wait_physics_frames(1)
		top = maxf(top, hero.global_position.y)
		if not hero.is_on_floor():
			airborne = true
		if i % 9 == 2 and shots < 3:
			await rig.capture(out.path_join("parry_2%d_leap.png" % shots))
			shots += 1
		if foe.state == Enemy.State.LAUNCHED or foe.state == Enemy.State.HURT:
			break

	var rise := top - HERO_AT.y
	print("PARRY flurry  swing_t=%.2f airborne=%s rise=%.2f m foe_state=%d hp=%d"
		% [swung, airborne, rise, foe.state, foe.health.quarters])
	if swung < 0.0:
		_fail("the attack button in the flurry window started no swing at all")
	if not airborne:
		_fail("the flurry attack never left the ground")
	if foe.state != Enemy.State.LAUNCHED and foe.state != Enemy.State.HURT:
		_fail("the flurry attack landed on nothing (foe state %d)" % foe.state)
	if combat.get(&"_flurry_t") > 0.0:
		_fail("the flurry window survived the leap it paid for")
	foe.queue_free()
	await rig.wait_frames(6)


# --- Beat six: the look -------------------------------------------------------

## The two bursts, held at their peak so they can be looked at side by side.
##
## Held rather than caught in flight, and that is a property of the fix they
## carry rather than a shortcut: both run on the WALL clock so a hit-stop cannot
## freeze them (`FlourishVfx`), and `rig.capture` spends real milliseconds
## writing a PNG — so by the time a frame is on disk the effect has moved on.
## `monster_launch._star_frames` makes the same move for the same reason.
## How much of the ring's full radius counts as "open enough to photograph".
##
## NOT its peak. The last beat of the growth is the ring at its thinnest and
## fastest, and one frame after that it is gone — so a loop that waits for the
## scale to stop rising exits one frame too late and freezes an empty courtyard.
## That is exactly what the first pass of this director did, twice, and both
## lookdev frames came back with nothing in them.
const RING_OPEN := 0.85

func _look(rig, out: String) -> void:
	var hero: Node3D = _hero(rig)
	if hero == null:
		return
	hero.global_position = HERO_AT
	# TOWARDS the lens, not away. Every other beat faces the hero at the goblin,
	# which points his back at the camera — and the parry burst blooms at the
	# SHIELD, on the far side of that back. The two frames this beat exists to
	# produce were both a torso with some gold leaking round the edges.
	hero.set(&"facing_yaw", 0.0)
	Bus.camera_recenter.emit()
	# Let the flurry finish landing. The lookdev is the one beat with no assertion
	# about the hero, and a hero still in mid-leap is a hero standing in front of
	# the thing being photographed.
	await rig.until(func() -> bool: return hero.is_on_floor(), 2.0)
	await rig.wait_frames(20)

	# Facing +Z, the hero's LEFT is +X (up × forward), and the shield is on the
	# left arm — so this is where `HeroCombat.on_parried` puts the burst, turned
	# to where the camera can see it.
	var shots := [
		{"n": "parry_30_burst", "at": hero.global_position + Vector3(0.45, 1.1, 0.45),
			"parry": true},
		{"n": "parry_31_dodge_ring", "at": hero.global_position, "parry": false},
	]
	for shot in shots:
		var vfx: FlourishVfx
		if bool(shot["parry"]):
			vfx = FlourishVfx.parry(rig.current_scene, shot["at"])
		else:
			vfx = FlourishVfx.dodge(rig.current_scene, shot["at"])
		if vfx == null:
			_fail("FlourishVfx refused to spawn")
			return
		# Polled against the ring's own radius rather than a frame count, so a
		# retuned `*_RING_TIME` cannot silently move where this stops.
		var peak := 0.0
		for _i in 40:
			await rig.wait_frames(1)
			if vfx._ring == null or not vfx._ring.visible:
				break
			peak = vfx._ring.scale.x
			if peak >= vfx._ring_r * RING_OPEN:
				break
		vfx.process_mode = Node.PROCESS_MODE_DISABLED
		await rig.capture(out.path_join(String(shot["n"]) + ".png"))
		if peak < vfx._ring_r * RING_OPEN:
			_fail("%s was photographed at %.2f of its %.2f m ring -- it closed"
				% [shot["n"], peak, vfx._ring_r] + " before the shutter")
		vfx.queue_free()
		await rig.wait_seconds(0.3)

	# Neither may outlive its own animation. They are flashes, and a flash still
	# on screen a second later is a decal.
	await rig.wait_seconds(1.2)
	var left := 0
	for n in rig.current_scene.get_children():
		if n.name.begins_with("FlourishVfx"):
			left += 1
	if left > 0:
		_fail("%d flourishes are still in the scene a second later" % left)


# --- Plumbing -----------------------------------------------------------------

## The hero, planted and IDLE.
##
## The last line is the one that matters and it was not here at first. Every beat
## ends by throwing a blow, and a blow leaves the hero committed — beat one's
## riposte is a dash that is still running when beat two starts. `request_attack`
## refuses from inside a commitment, so beat two's parry silently never began and
## the failure it printed was "the shield is still up", which is a true statement
## about a move that had not happened.
func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		_fail("no node in group `player`")
		return null
	var hero: Node3D = players[0]
	hero.global_position = HERO_AT
	hero.set(&"facing_yaw", FACE_MINUS_Z)
	if hero.get(&"state") == 4:  # Hero.MoveState.ATTACK
		hero.call(&"end_commitment")
	hero.set(&"state", 0)  # GROUND
	var combat = hero.get(&"combat")
	if combat != null:
		combat.set(&"_swing_t", -1.0)
		combat.set(&"_buffer", -1)
		# The blade's window closes with it. A swing abandoned mid-frame would
		# otherwise leave a live Area3D on the hero that hits the NEXT beat's
		# goblin the moment it is planted.
		var box: Area3D = combat.get(&"_hitbox")
		if box != null:
			box.monitoring = false
	return hero


## One goblin, planted in front of the hero and out of the fight's own hands.
## It is a real `Enemy` because `stagger` is the thing being tested and a stand-in
## with a `stagger` method would only prove the director can write one.
func _foe(rig, seed_val: int) -> Enemy:
	var foe := Enemy.new()
	foe.kind = &"goblin"
	foe.drop_seed = seed_val
	rig.current_scene.add_child(foe)
	foe.global_position = FOE_AT
	return foe


## Start a roll, by hand. `_try_start_roll` reads `context_tapped`, which is set
## by a press measured over several frames (`Hero._tick_context`) — driving that
## from here would make every dodge beat a test of the button's hold detector.
func _roll(rig, hero: Node3D) -> bool:
	Game.stamina = K.MAX_STAMINA
	hero.set(&"state", 0)  # GROUND
	hero.set(&"context_tapped", true)
	var ok: bool = hero.call(&"_try_start_roll", -hero.call(&"_forward"), 1.0)
	hero.set(&"context_tapped", false)
	if not ok:
		_fail("the hero refused to roll")
	return ok


## A blow at the hero from `foe`'s feet, through the real damage path. The
## position matters twice: it is `Hit.from`, which is what the parry cone and the
## knockback are measured against, and it is what `HeroCombat._parried_body` uses
## to find who to throw.
func _swing_at(rig, foe: Node3D, hero: Node3D) -> void:
	var box := DamageArea.new()
	box.collision_layer = K.L_ENEMY_HITBOX
	box.collision_mask = K.L_PLAYER
	box.amount = 2
	box.kind = &"contact"
	box.knockback = K.KNOCKBACK_LIGHT
	box.stun = K.STUN_LIGHT
	box.source = &"GOBLIN"
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.6
	col.shape = sphere
	box.add_child(col)
	hero.get_parent().add_child(box)
	box.global_position = foe.global_position
	# A physics frame between placing it and opening it. `activate` finds bodies
	# already inside by sweeping `get_overlapping_bodies()`, and that list is
	# built by the physics server -- an area opened on the frame it was moved
	# overlaps nothing and the blow silently never happens.
	await rig.wait_physics_frames(1)
	box.activate()
	await rig.wait_physics_frames(2)
	box.deactivate()
	box.queue_free()


func _fail(msg: String) -> void:
	_fails += 1
	print("PARRY FAIL %s" % msg)
