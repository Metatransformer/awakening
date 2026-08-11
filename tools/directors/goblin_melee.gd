extends RefCounted
## Does a goblin ever SWING? And when a blow throws a body, does it go the way
## the blow was pointing?
##
## Written for a bug report off the controller — *"goblin AI has gotten to the
## point where they're just not doing anything, they go into fighting pose and
## float around the map and I can just go up and attack em"* — and it found it:
## `"behaviour": &"thief"` was an unconditional default on the `goblin` row,
## nothing anywhere ever set `Enemy.behaviour`, and `_tick_chase` reaches for the
## bag BEFORE it checks the swing. So every goblin in the game was a thief, and a
## thief facing a player carrying nothing reached, closed on air, waited out
## `K.THIEF_REGRAB` and reached again. Forever. In the fight, posing, circling,
## unable to attack.
##
## **The control is the first beat and it is not decoration.** A SKELETON, in the
## same room, in front of the same stationary hero, for the same eight seconds.
## It is the plainest melee body in `Enemy.DEFS` and it must reach WINDUP several
## times. If the control ever reads zero, the reading is this file's and not the
## game's, and every number below it is worthless (CLAUDE.md §2 — a director
## reporting a failure is a suspect, not a witness).
##
## Five beats:
##
##   * **control** — a skeleton. WINDUP entries must be > 0.
##   * **plain** — a goblin with the behaviour explicitly off. Must swing.
##   * **thief_empty** — a goblin forced to be a thief, nothing in the hold.
##     **Must swing**: a thief with nothing to steal is a goblin. This is the
##     beat that was red.
##   * **thief_full** — the same body with a packed hold. Must GRAB and must
##     reach FLEE, because fixing the swing must not delete the behaviour.
##   * **share** — sixty unspecified goblins, counted. Neither 0 nor 60 may be
##     thieves. This is the beat that fails the day the row default comes back.
##   * **bearing** — a real sword `Hit` from four sides against a LIVING body,
##     measuring the angle between the launch velocity and *away from the hero*.
##     The answer is known before the run: the hero is placed and the body is
##     placed, so the correct bearing is arithmetic and any error is the game's.
##   * **corpses** — twelve kills, because a corpse flies down a different path
##     and that path was wiping its own arc (card #87).
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/goblin_melee.gd --out=/tmp/gob/x.png

## Seconds each behaviour beat watches for. Long enough to hold several of a
## goblin's 0.32 s wind-ups and several of a skeleton's 0.45 s ones even with
## every cooldown and circle in between.
const WATCH := 8.0

## Where the hero stands and how far in front of him the body starts. Outside a
## skeleton's 1.7 m reach, so the first thing on film is an approach.
const HERO_AT := Vector3(0.0, 0.05, 6.0)
const FOE_OFFSET := 3.0

## The hero's heading yaw for -Z (`docs/CONTRACT.md` §2.5).
const FACE_MINUS_Z := PI

## What goes in the hold when a beat wants a bag worth stealing from.
##
## **Four rows and not one, and the count is the point.** `Run._place` fills the
## three-slot document CASE first and the case is the one region a thief may
## never reach into, so a single stack lands entirely out of reach and the beat
## silently becomes a second copy of the empty one. The first cut of this file
## did exactly that: identical tick counts, to the digit, and nothing said why.
const PACK: Array = [
	[&"bone_shard", 20], [&"rot_moss", 20], [&"cracked_flint", 20],
	[&"iron_scrap", 12],
]

## Goblins rolled in the share beat. Enough that the sampling error on a 0.25
## share is about 5.6 points, which is well inside the margins below.
const ROLLS := 60

## The four bearings the launch beat throws from, as compass offsets from the
## hero in the XZ plane. Four rather than one because a single bearing cannot
## tell "away from the hero" apart from "along +X".
const BEARINGS: Array[Vector3] = [
	Vector3(1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0),
	Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -1.0),
]

## How far off "away from the hero" a launch may point before this fails, in
## degrees. Generous: the body has a capsule, `_separation` is live, and the
## hero's own origin is not the contact point. A real inversion is 180° out and
## nothing legitimate is past 30.
const BEARING_TOLERANCE_DEG := 30.0

## Kills the corpse beat measures. See `_corpses` for why they are twelve seeds
## on one bearing rather than one seed on twelve.
const CORPSES := 12

var _fails: int = 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/gob/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	await _watch(rig, out, &"skeleton", &"", false, "control")
	await _watch(rig, out, &"goblin", &"none", false, "plain")
	await _watch(rig, out, &"goblin", &"thief", false, "thief_empty")
	await _watch(rig, out, &"goblin", &"thief", true, "thief_full")
	await _share(rig)
	await _bearing(rig)
	await _corpses(rig)

	if _fails == 0:
		print("GOBLIN OK -- every check passed")


# --- Beats one to four: does it swing ----------------------------------------

## Stand a body in front of a stationary hero and count what states it visits.
##
## The hero is topped back up every physics tick rather than made invulnerable,
## because i-frames would suppress the very attacks this beat counts — it is the
## ATTACK being measured, not the damage. He is also not driven: a director
## pressing buttons would be a second explanation for anything odd, and the bug
## reported was one you can watch standing still.
func _watch(rig, out: String, kind: StringName, behave: StringName,
		packed: bool, label: String) -> void:
	var scene := rig.current_scene as Node3D
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]

	Run.enter(90210)
	Run.bag.clear()
	Run.cased.clear()
	if packed:
		for row: Array in PACK:
			Run.collect(row[0], int(row[1]), 1.0)
		# Asserted rather than assumed, for PACK's reason.
		if not Run.stealable():
			_fail("%s: the hold has nothing a thief could take, so this beat is"
				% label + " the empty-hold beat wearing a different name")

	hero.global_position = HERO_AT
	hero.set(&"facing_yaw", FACE_MINUS_Z)
	await rig.wait_frames(6)

	# Built by hand rather than through `Enemy.spawn` because the behaviour has
	# to be written BEFORE the body enters the tree -- `_ready` resolves it, and
	# `add_child` runs `_ready` synchronously. Same trap `spawn`'s docstring
	# describes for `level`, one field over.
	var foe := Enemy.new()
	foe.kind = kind
	foe.behaviour = behave
	foe.drop_seed = 4242
	foe.level = Prog.FIRST
	scene.add_child(foe)
	foe.global_position = HERO_AT - Vector3(0.0, 0.0, FOE_OFFSET)
	await rig.wait_physics_frames(4)

	# One counter per state, plus the transitions, because the two answer
	# different questions: a body can sit in CHASE for eight seconds, and a body
	# can enter WINDUP forty times without ever finishing one.
	var seen := {}
	var entries := {}
	var last: int = -1
	var ticks := 0
	var elapsed := 0.0
	var gone := false
	var was_thief := foe.is_thief()
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	while elapsed < WATCH:
		await rig.wait_physics_frames(1)
		# **Re-checked AFTER the await, not before it.** A thief that reaches its
		# door calls `queue_free` on itself, so a body that was valid when the
		# loop condition was evaluated can be freed by the time the resume lands
		# -- which is a `previously freed` SCRIPT ERROR, an aborted beat, and
		# (card #72) a run that still printed OK and exited 0.
		if not is_instance_valid(foe):
			gone = true
			break
		elapsed += step
		ticks += 1
		Game.quarters = Game.max_quarters
		var s: int = foe.state
		seen[s] = int(seen.get(s, 0)) + 1
		if s != last:
			entries[s] = int(entries.get(s, 0)) + 1
			last = s

	print("GOBLIN %-12s %-9s thief=%s ticks=%d gone=%s  %s"
		% [label, kind, was_thief, ticks, gone, _states(seen, entries)])
	if not gone:
		await rig.capture("%s/%s.png" % [out, label])
	# A body that left the scene is a PASS for exactly one beat -- the thief that
	# got through the door with your iron, which is the behaviour working. For
	# every other beat it is a monster that died with nobody hitting it.
	if gone and label != "thief_full":
		_fail("%s: the %s left the scene on its own" % [label, kind])
		return

	var swings := int(entries.get(Enemy.State.WINDUP, 0))
	var strikes := int(entries.get(Enemy.State.STRIKE, 0))
	if label == "thief_full":
		# The other half of the fix: teaching a thief to swing must not have
		# taught it to stop stealing. It has to reach, take, and run.
		if int(entries.get(Enemy.State.GRAB, 0)) == 0:
			_fail("thief_full: a thief with a packed hold in front of it never"
				+ " reached for the bag")
		elif int(entries.get(Enemy.State.FLEE, 0)) == 0:
			_fail("thief_full: it grabbed and never ran -- the behaviour is half"
				+ " a behaviour")
	elif swings == 0 and label == "control":
		# The control failing does NOT mean the game is broken -- it means this
		# file cannot see a wind-up, and every reading below it is worthless.
		_fail("control: the SKELETON never swung either, so the instrument is"
			+ " the suspect and not the goblin")
	elif swings == 0:
		_fail("%s: the %s never entered WINDUP in %.0f s -- it is in the fight"
			% [label, kind, WATCH] + " and it never swings")
	elif strikes == 0:
		_fail("%s: the %s wound up %d times and never struck"
			% [label, kind, swings])
	# Guarded: the thief that got away already freed itself (see `gone`).
	if is_instance_valid(foe):
		foe.queue_free()
	await rig.wait_frames(2)


## `State` counts, named, busiest first. Raw enum ordinals in a log are how
## `Music`'s `[1, 2, 3, 4]` happened (`Enemy.State`'s own comment).
func _states(seen: Dictionary, entries: Dictionary) -> String:
	var names := PackedStringArray()
	var keys: Array = seen.keys()
	keys.sort_custom(func(a, b): return int(seen[a]) > int(seen[b]))
	for k in keys:
		names.append("%s=%d(x%d)" % [Enemy.State.find_key(k), int(seen[k]),
			int(entries.get(k, 0))])
	return " ".join(names)


# --- Beat five: how many of them are thieves ---------------------------------

## Roll `ROLLS` unspecified goblins and count the thieves.
##
## **This is the beat that fails the day the row default comes back.** The bug
## was not that the thief existed, it was that it was ALL of them, and no amount
## of watching one body can see that — the first four beats each name the
## behaviour they want, so every one of them would still pass against a 1.0
## share. The claim here is only that the share is a share: neither nobody nor
## everybody. Asserted as bounds rather than against `K.THIEF_SHARE` exactly, so
## retuning that number does not break a director that is checking its shape.
func _share(rig) -> void:
	var scene := rig.current_scene as Node3D
	var thieves := 0
	for i in ROLLS:
		var foe := Enemy.new()
		foe.kind = &"goblin"
		foe.drop_seed = 5000 + i
		scene.add_child(foe)
		# Parked far outside the room and stopped dead: this beat wants the roll
		# in `_ready`, not sixty goblins walking into the courtyard to find out.
		foe.global_position = Vector3(0.0, 0.05, -60.0)
		foe.set_physics_process(false)
		if foe.is_thief():
			thieves += 1
		foe.queue_free()
	await rig.wait_frames(2)

	var share := float(thieves) / float(ROLLS)
	print("GOBLIN share thieves=%d/%d (%.0f%%) K.THIEF_SHARE=%.0f%%"
		% [thieves, ROLLS, share * 100.0, K.THIEF_SHARE * 100.0])
	if thieves == 0:
		_fail("share: not one goblin in %d is a thief -- the behaviour is gone"
			% ROLLS)
	elif thieves == ROLLS:
		_fail("share: ALL %d goblins are thieves, which is the bug this file was"
			% ROLLS + " written for -- a thief never swings")
	elif absf(share - K.THIEF_SHARE) > 0.20:
		_fail("share: %.0f%% of goblins are thieves against a stated %.0f%%"
			% [share * 100.0, K.THIEF_SHARE * 100.0])


# --- Beat six: which way does a thrown body go -------------------------------

## Hit a goblin with the sword's own `Hit` from four sides and measure where it
## went.
##
## **The answer is known before the run.** The hero is put at `HERO_AT` and the
## body one bearing away from him, so "away from the hero" is that bearing and
## nothing else — which is what makes a reading here mean something (CLAUDE.md
## §2's known-answer calibration, pointed at a direction rather than a stall).
##
## The blow is built the way `HeroCombat._maybe_hit` builds it, `from` being the
## HERO'S OWN POSITION, so this measures the game's path rather than a
## re-derivation of it.
func _bearing(rig) -> void:
	var scene := rig.current_scene as Node3D
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	hero.global_position = HERO_AT
	hero.set(&"facing_yaw", FACE_MINUS_Z)
	await rig.wait_frames(6)

	for i in BEARINGS.size():
		var away: Vector3 = BEARINGS[i]
		var at: Vector3 = HERO_AT + away * 1.1
		var foe := Enemy.spawn(scene, &"goblin", at, 700 + i, Prog.FIRST)
		await rig.wait_physics_frames(4)
		# Held still, so the chase this beat does not want cannot walk the body
		# off its bearing between the spawn and the blow.
		foe.set_physics_process(false)
		foe.global_position = at

		var flew := false
		var got := Vector3.ZERO
		for _attempt in 60:
			# Topped up FIRST and hit for 2 quarters against a goblin's 5, so it
			# cannot die inside the loop -- a corpse answers `_can_launch`
			# differently and the beat would be measuring another question.
			# `_invuln` is zeroed by hand because `set_physics_process(false)`
			# above has stopped the clock that would otherwise bleed it off.
			foe.health.quarters = foe.health.max_quarters
			foe.health._invuln = 0.0
			foe.state = Enemy.State.CHASE
			foe._airborne = false
			foe.health.apply_hit(Hit.make(2, hero.global_position, &"sword",
				K.KNOCKBACK_HEAVY, 0.3))
			if foe._airborne:
				flew = true
				got = K.flat(foe.velocity)
				break
		if not flew:
			_fail("bearing %.0f,%.0f: sixty heavy blows and the body never left"
				% [away.x, away.z] + " the ground")
			foe.queue_free()
			await rig.wait_frames(1)
			continue

		var err := rad_to_deg(got.angle_to(away))
		print("GOBLIN bearing away=(%+.0f,%+.0f) alive=(%+.2f,%+.2f) err=%.1f deg"
			% [away.x, away.z, got.x, got.z, err])
		if err > BEARING_TOLERANCE_DEG:
			_fail("bearing %.0f,%.0f: the LIVING body was thrown %.0f deg off"
				% [away.x, away.z, err] + " away-from-hero")
		foe.queue_free()
		await rig.wait_frames(1)


## **And the corpse, which is a different code path and the one the player
## actually watches.** A living body flies on a ROLL out of `_on_damaged`; a dead
## one flies unconditionally out of `_on_died`, off the `_last_hit_dir` the blow
## before it stamped. Every kill throws the body, a goblin has five quarters, and
## most swings kill one — so a beat that only measured the living launch left the
## common case unmeasured, and the common case was broken.
##
## **`CORPSES` seeds on ONE bearing, not one seed on four.** Whether a given kill
## also crit the LIVING body first is a coin flip on that body's own RNG, and the
## two outcomes are different branches of `_on_died`: the crit branch was the
## broken one, and it was broken in a way that has nothing to do with which way
## the hero is standing. Four bearings with one seed each is four coin flips —
## the first cut of this beat drew two heads and two tails and only found the bug
## by luck. Twelve flips on one bearing is the same total spawns and cannot miss
## a branch that fires half the time.
func _corpses(rig) -> void:
	var scene := rig.current_scene as Node3D
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	var away := Vector3(1.0, 0.0, 0.0)
	var at: Vector3 = HERO_AT + away * 1.1
	var slumped := 0
	var worst := 0.0

	for i in CORPSES:
		var corpse := Enemy.spawn(scene, &"goblin", at, 800 + i, Prog.FIRST)
		await rig.wait_physics_frames(4)
		corpse.set_physics_process(false)
		corpse.global_position = at
		corpse.health.apply_hit(Hit.make(corpse.health.max_quarters,
			hero.global_position, &"sword", K.KNOCKBACK_HEAVY, 0.3))
		if corpse.state != Enemy.State.DEAD:
			_fail("corpse %d: a blow for its whole health did not kill it" % i)
			corpse.queue_free()
			continue
		var flat := K.plane(corpse.velocity)
		# **The speed and the direction are two claims and the failure was the
		# first one.** A corpse whose horizontal velocity was wiped has no
		# bearing at all -- `angle_to` on a zero vector is not a large error, it
		# is no answer -- so "did it go anywhere" has to be asked before "did it
		# go the right way".
		if flat.length() < 0.5:
			slumped += 1
			print("GOBLIN corpse %2d launched=(%+.2f,%+.2f) UP=%+.2f -- no lateral"
				% [i, flat.x, flat.z, corpse.velocity.y])
		else:
			var err := rad_to_deg(K.flat(flat).angle_to(away))
			worst = maxf(worst, err)
			if err > BEARING_TOLERANCE_DEG:
				_fail("corpse %d: thrown %.0f deg off away-from-hero" % [i, err])
		corpse.queue_free()
		await rig.wait_frames(1)

	print("GOBLIN corpses n=%d slumped=%d worst_bearing=%.1f deg"
		% [CORPSES, slumped, worst])
	if slumped > 0:
		_fail("corpses: %d of %d were thrown straight UP with no lateral"
			% [slumped, CORPSES] + " velocity -- a kill that also crit the living"
			+ " body had its arc wiped by `_on_died`")


func _fail(msg: String) -> void:
	_fails += 1
	print("GOBLIN FAIL -- %s" % msg)
