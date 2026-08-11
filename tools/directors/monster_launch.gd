extends RefCounted
## Does a body GO FLYING, and does it go flying by the right amount?
##
## Three halves, because "bigger hit, bigger everything" is three claims:
##
##   * **The odds** -- a committed blow launches a goblin often and a troll
##     rarely, and a jab never launches anything. Measured over 400 rolls per
##     kind rather than photographed, because a probability is not a picture and
##     one lucky frame would "prove" any number at all.
##   * **The arc** -- the same blow on a goblin, an orc and a troll, filmed. Three
##     apex heights and three flight times off one shared impulse, which is the
##     only way to see that mass is doing something rather than being multiplied
##     by one.
##   * **The impact** -- the star at the contact point on a crit, the scuff on a
##     jab, and the screen shake that used to fire at 0.52 for every hit in the
##     game including the cheapest.
##
## The numeric beats print `LAUNCH FAIL ...` because most of this has no pixels:
## an apex is a number, a probability is a number, and a shake that is too big is
## the failure that looks fine in every single frame.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/monster_launch.gd --out=/tmp/launch/x.png

## Rolls per kind in the odds beat. Enough that the sampling error on a ~0.6
## probability is about 2.5 points, which is well inside the margins asserted
## below and cheap because a roll costs no frames.
const ROLLS := 400

## The three bodies the arc beat films, smallest first. Chosen to span the
## roster: 1.25 m, 1.95 m and 2.60 m, i.e. the extremes and the middle.
const ARC_KINDS: Array[StringName] = [&"goblin", &"orc", &"troll"]

## The hero's heading yaw for -Z. `facing_yaw` IS the heading and the heading is
## `(sin y, 0, cos y)`, so -Z is PI (`docs/CONTRACT.md` §2.5).
const FACE_MINUS_Z := PI

## Where the hero stands and where the body starts, for every filmed beat.
##
## **The geometry is the shot, and this director got it wrong twice.**
##
## The camera rides the HERO, not the thing that was hit. The first cut launched
## the goblin across the room and photographed a clean, empty courtyard with a
## 5.86 m flight happening somewhere off the side of it. The second cut threw the
## body straight down the camera's axis so it could not leave the frame — and
## that hid the one thing the beat exists to show, because a parabola viewed
## end-on is a dot that gets smaller.
##
## So the body is thrown **across** the view, left to right. The hero faces -Z
## with the body in front of him, every blow is struck from the body's left, and
## the launch carries it sideways at roughly constant depth: the arc is drawn
## across the frame, which is the only angle a parabola reads from. The body
## starts left of centre because it has up to 5.9 m of travel to spend.
const HERO_AT := Vector3(0.0, 0.05, 7.4)
const FOE_AT := Vector3(-2.6, 0.05, 2.2)

var _fails: int = 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/launch/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	await _odds(rig)
	await _arc(rig, out)
	await _impact(rig, out)

	if _fails == 0:
		print("LAUNCH OK")


# --- Half one: the odds -------------------------------------------------------

## Roll the launch `ROLLS` times per kind and count. Calls `_try_launch` directly
## rather than swinging at a body, and that is on purpose: this beat is about the
## PROBABILITY, and going through the damage pipeline would need the body's health
## topped up 400 times and would measure the sword as well as the dice.
##
## `_airborne` and the state are put back between rolls because a launch sets
## both, and a second roll on a body already in the air is not a roll.
func _odds(rig) -> void:
	var scene: Node = rig.current_scene
	var rates := {}

	for kind in [&"goblin", &"skeleton", &"orc", &"troll"]:
		var foe := Enemy.new()
		foe.kind = kind
		foe.drop_seed = 909
		scene.add_child(foe)
		foe.global_position = Vector3(0.0, 0.05, -40.0)
		await rig.wait_frames(2)
		# Physics off: this beat wants the dice, not four monsters walking into
		# the courtyard while it counts.
		foe.set_physics_process(false)

		var away := Vector3(0.0, 0.0, 1.0)
		var hits := 0
		for _i in ROLLS:
			foe.state = Enemy.State.CHASE
			foe._airborne = false
			if foe._try_launch(away, 1.0):
				hits += 1
		var rate := float(hits) / float(ROLLS)
		rates[kind] = rate

		# And the jab, which must NEVER launch. `blow_weight` is 0 at
		# K.KNOCKBACK_LIGHT, so this is the gate that keeps the light chain's
		# first two steps from throwing bodies around the room.
		var jabs := 0
		for _i in ROLLS:
			foe.state = Enemy.State.CHASE
			foe._airborne = false
			if foe._try_launch(away, Enemy.blow_weight(K.KNOCKBACK_LIGHT)):
				jabs += 1
		if jabs > 0:
			_fail("a %s was launched by a JAB %d times in %d --"
				% [kind, jabs, ROLLS] + " weight 0 must never throw a body")

		print("LAUNCH odds %-11s height=%.2f m  committed=%.0f%%  jab=%.0f%%"
			% [kind, foe._height(), rate * 100.0, float(jabs) / ROLLS * 100.0])
		foe.queue_free()
		await rig.wait_frames(1)

	# The ordering is the claim, not the individual numbers: smaller bodies fly
	# more often. Asserted as an ORDER rather than against fixed percentages so
	# that retuning K.LAUNCH_CHANCE does not break a director that is supposed to
	# be checking the shape of the curve.
	var goblin: float = rates[&"goblin"]
	var skeleton: float = rates[&"skeleton"]
	var orc: float = rates[&"orc"]
	var troll: float = rates[&"troll"]
	if not (goblin > skeleton and skeleton > orc and orc > troll):
		_fail("the odds are not ordered by mass: goblin=%.2f skeleton=%.2f orc=%.2f troll=%.2f"
			% [goblin, skeleton, orc, troll])
	# And the spread has to be big enough to FEEL, not merely to measure. A
	# goblin that flies 40% of the time against a troll's 35% is a difference
	# nobody will ever notice at the controller.
	if goblin - troll < 0.25:
		_fail("goblin and troll are too close to tell apart: %.2f vs %.2f"
			% [goblin, troll])


# --- Half two: the arc --------------------------------------------------------

## Launch one of each kind with the SAME impulse and measure what came back.
##
## Goes through `_on_damaged` -- a real DamageArea carrying K.KNOCKBACK_HEAVY --
## rather than calling `_launch`, so this exercises the path the game uses. The
## roll is retried until it lands, with health topped up between attempts, which
## is why the body has to be immortal for the duration.
func _arc(rig, out: String) -> void:
	var scene: Node = rig.current_scene
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	hero.global_position = HERO_AT
	hero.set(&"facing_yaw", FACE_MINUS_Z)
	await rig.wait_frames(8)

	for i in ARC_KINDS.size():
		var kind: StringName = ARC_KINDS[i]
		var foe := Enemy.new()
		foe.kind = kind
		foe.drop_seed = 1300 + i
		scene.add_child(foe)
		foe.global_position = FOE_AT
		hero.global_position = HERO_AT
		hero.set(&"facing_yaw", FACE_MINUS_Z)
		await rig.wait_frames(20)
		# Immortal for the retries. The launch roll is a coin and this beat needs
		# a launch, not a corpse -- and a body killed on attempt three would be
		# measured on the DEATH launch, which is a different impulse.
		foe.health.max_quarters = 100000
		foe.health.quarters = 100000
		Bus.camera_recenter.emit()

		var launched := false
		for _try in 40:
			foe.health.quarters = 100000
			# Struck from the body's LEFT, so it is thrown across the frame to
			# the right and the arc is side-on to the camera. See FOE_AT.
			_strike(foe, foe.global_position + Vector3(-1.2, 0.9, 0.0),
				K.KNOCKBACK_HEAVY)
			await rig.wait_physics_frames(3)
			if foe.state == Enemy.State.LAUNCHED:
				launched = true
				break
			# i-frames: K.ENEMY_IFRAME_TIME is 0.20 s, so a retry inside that
			# window is a swing that never landed and never rolled.
			await rig.wait_seconds(0.25)

		if not launched:
			_fail("a %s never launched in 40 committed blows" % kind)
			foe.queue_free()
			continue

		var start := foe.global_position
		var apex := 0.0
		var flight := 0.0
		var frames := 0
		# **A contact sheet, not one frame.** An arc cannot be judged from a
		# single picture -- a body 1.6 m off the ground in one still is
		# indistinguishable from a body standing on a box. Three frames spread
		# across the flight is the cheapest thing that shows a parabola, and it is
		# the same reason `CLAUDE.md` §2 asks for a burst rather than a shot.
		var shots := 0
		while foe.state == Enemy.State.LAUNCHED and frames < 200:
			await rig.wait_physics_frames(1)
			frames += 1
			apex = maxf(apex, foe.global_position.y - start.y)
			if not foe._airborne:
				break
			flight += 1.0 / 60.0
			# Every 7 physics frames while it is in the air. `capture` itself
			# costs real time, so these land unevenly -- which does not matter,
			# because every one of them is a true frame of a real flight.
			if frames % 7 == 1 and shots < 3:
				await rig.capture(out.path_join(
					"launch_0%d_%s_air%d.png" % [i, kind, shots]))
				shots += 1

		var travelled := K.plane(foe.global_position - start).length()
		print("LAUNCH arc %-7s apex=%.2f m  airborne=%.2f s  travelled=%.2f m"
			% [kind, apex, flight, travelled])
		if apex <= 0.05:
			_fail("a %s never left the ground: apex %.3f m" % [kind, apex])
		if travelled < 0.5:
			_fail("a %s was launched %.2f m -- that is a shove, not a throw"
				% [kind, travelled])

		# It has to come back down and get up, or the launch is a body deleted
		# from the fight rather than knocked out of it.
		var up: bool = await rig.until(
			func() -> bool: return foe.state == Enemy.State.CHASE, 4.0)
		if not up:
			_fail("a launched %s never got back up (state %d)" % [kind, foe.state])
		await rig.capture(out.path_join("launch_1%d_%s_up.png" % [i, kind]))

		# The one thing a tumble must not leave behind: a monster walking around
		# lying on its side. `_land` tweens the model back to rest for this.
		if foe._model != null and absf(foe._model.rotation.x - foe._model_rest.x) > 0.2:
			_fail("a landed %s is still pitched %.2f rad off its rest pose"
				% [kind, foe._model.rotation.x - foe._model_rest.x])
		foe.queue_free()
		await rig.wait_frames(4)


# --- Half three: the impact ---------------------------------------------------

## The mark at the contact point, and the shake that got reeled in.
func _impact(rig, out: String) -> void:
	var scene: Node = rig.current_scene
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	hero.global_position = HERO_AT
	hero.set(&"facing_yaw", FACE_MINUS_Z)
	await rig.wait_frames(8)

	var foe := Enemy.new()
	foe.kind = &"skeleton"
	foe.drop_seed = 5150
	scene.add_child(foe)
	foe.global_position = FOE_AT
	await rig.wait_frames(24)
	foe.health.max_quarters = 100000
	foe.health.quarters = 100000
	# Held still so the camera can hold on the impact site. The burst is parented
	# to the SCENE, so it stays where the blow landed either way -- but a skeleton
	# walking into the lens photographs its own approach instead of its bruise.
	foe.set_physics_process(false)
	Bus.camera_recenter.emit()
	await rig.wait_frames(30)

	# A jab: scuff, no star, and a twitch of a shake.
	var tap := await _shake_of(rig, foe, K.KNOCKBACK_LIGHT)
	await rig.capture(out.path_join("launch_20_jab_scuff.png"))
	await rig.wait_seconds(0.5)

	# A committed blow: the star, and the top of the shake range.
	var hit := await _shake_of(rig, foe, K.KNOCKBACK_HEAVY)
	await rig.wait_seconds(0.5)

	# And the star itself, HELD so it can be looked at.
	#
	# It cannot be photographed in flight and that is a property of the fix it
	# carries, not a shortcut: the star runs on the wall clock so that
	# `Feel.hitstop` cannot freeze it (`ImpactVfx._star_node`), and `rig.capture`
	# spends real milliseconds writing a PNG -- so by the time a frame is on disk
	# the burst has moved on. Holding it is the same move `monster_feel._shake_scale`
	# makes to photograph a shake: stop the thing, take the picture, let it go.
	# What is photographed is the real effect at its real peak.
	await _star_frames(rig, foe, out)

	print("LAUNCH shake jab=%.3f committed=%.3f (was a flat 0.52 for both)"
		% [tap, hit])
	# The whole point of the change: a jab must be visibly cheaper than a
	# committed blow. It was not -- both asked for 0.52.
	if tap >= hit:
		_fail("a jab shakes the screen as hard as a committed blow: %.3f vs %.3f"
			% [tap, hit])
	# Bounded on BOTH sides, and the low end is not pedantry. `Feel` squares
	# trauma, so the first cut's 0.16 came out as 0.4 px of movement -- which
	# `monster_feel` correctly called an invisible shake. A jab has to be cheap
	# and still be there. See K.SHAKE_TAP for the pixel arithmetic.
	if tap > 0.32:
		_fail("a jab still asks for %.3f trauma -- three of those saturate Feel"
			% tap)
	if tap < 0.2:
		_fail("a jab asks for %.3f trauma -- squared, that is no shake at all"
			% tap)

	# The star is geometry that RETRACTS rather than fades (ImpactVfx, and
	# CLAUDE.md §3's ADD-over-black trap). If it is still on screen a second
	# later it is not a flash, it is a decal.
	await rig.wait_seconds(1.0)
	var left := 0
	for n in scene.get_children():
		if n.name.begins_with("ImpactVfx"):
			left += 1
	if left > 0:
		_fail("%d impact bursts are still in the scene a second after the blow"
			% left)
	foe.queue_free()


## The crit star at full extension, and a jab's scuff beside it for scale.
##
## Spawns `ImpactVfx` directly rather than swinging, because this beat is a
## lookdev of the burst and a real blow would launch the body out from under it
## before the shutter closed. Both bursts go off at the same spot on the same
## body, so the pair is an A/B of "bigger hit, bigger impact" and not two
## photographs of two different situations.
func _star_frames(rig, foe: Node3D, out: String) -> void:
	for shot in [{"n": "launch_21_jab_mark", "w": 0.0, "crit": false},
			{"n": "launch_22_crit_star", "w": 1.0, "crit": true}]:
		var at: Vector3 = foe.call(&"_impact_point",
			foe.global_position + Vector3(0.0, 0.9, 2.0))
		var vfx: ImpactVfx = ImpactVfx.spawn(rig.current_scene, at,
			float(shot["w"]), bool(shot["crit"]))
		if vfx == null:
			_fail("ImpactVfx refused to spawn")
			return
		# Hold it at the peak. The star opens in ImpactVfx.STAR_OPEN seconds of
		# wall clock, so poll for the frame where it stops growing rather than
		# guessing a frame count -- a guess is a number that goes stale the moment
		# the open is retuned.
		var peak := 0.0
		for _i in 30:
			await rig.wait_frames(1)
			if vfx._star_node == null:
				break
			var s: float = vfx._star_node.scale.x
			if s < peak:
				break
			peak = s
		vfx.process_mode = Node.PROCESS_MODE_DISABLED
		await rig.capture(out.path_join(String(shot["n"]) + ".png"))
		if bool(shot["crit"]) and peak <= 0.01:
			_fail("the crit star never opened: peak scale %.3f" % peak)
		vfx.queue_free()
		await rig.wait_seconds(0.4)


## Land one blow of `knock` on `foe` and return the PEAK trauma it asked Feel for.
##
## Peak over a window rather than a single sample, for the reason
## `monster_feel.gd` gives about the shake: any one frame can land on a zero
## crossing. Read off `Feel._trauma`, which is the number the request became.
func _shake_of(rig, foe: Node3D, knock: float) -> float:
	# Feel accumulates, so a leftover from the previous blow would be counted
	# again and the second reading would always be the bigger one.
	Feel._trauma = 0.0
	await rig.wait_frames(2)
	_strike(foe, foe.global_position + Vector3(-1.2, 0.9, 0.0), knock)
	var peak := 0.0
	for _i in 10:
		await rig.wait_physics_frames(1)
		peak = maxf(peak, Feel._trauma)
	return peak


## Swing at `foe` from `at` the way the hero does: a DamageArea, activated for a
## window. Reaching past it into HealthComponent.apply_hit would prove the health
## maths and skip the exact link the launch hangs off -- `Hit.knockback` is what
## `blow_weight` reads.
func _strike(foe: Node3D, at: Vector3, knock: float) -> void:
	var box := DamageArea.new()
	box.collision_layer = K.L_PLAYER_HITBOX
	box.collision_mask = K.L_ENEMY
	box.amount = 2
	box.kind = &"sword"
	box.knockback = knock
	box.stun = K.STUN_LIGHT
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	col.shape = sphere
	box.add_child(col)
	foe.get_parent().add_child(box)
	box.global_position = at
	box.activate()


func _fail(msg: String) -> void:
	_fails += 1
	print("LAUNCH FAIL %s" % msg)
