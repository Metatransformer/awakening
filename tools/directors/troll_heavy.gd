extends RefCounted
## **The troll's two beats.** Card #130's follow-up: the roster's heaviest body
## now throws an ordinary swing and a telegraphed heavy, and only the heavy is
## allowed to put the player on the ground.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/troll_heavy.gd \
##     --out=/tmp/troll/x.png --warmup=60
##
## Why this exists at all: the troll used to have one swing at `damage 6 /
## windup 0.72`, and `Hit.commitment_of_tell` read that three-quarter-second
## tell -- correctly -- as a fully committed heavy, so an ordinary roster monster
## floored the player 31% of the time. The fix was not a smaller number, it was
## the missing beat. That makes this director's job to prove there are TWO of
## them and that they are different in the ways the player has to read.
##
## Three sections:
##
##   A  **The pricing**, off `Enemy.DEFS` -- both beats through `Hit.tier_odds`,
##      checked against the design rather than against a fit: the ordinary swing
##      may not floor him more often than it staggers him, and the heavy must be
##      able to floor him at all. No engine needed, so it runs first and fails
##      cheap.
##   B  **Both beats thrown, in a real fight.** The troll is let loose on the
##      hero and every wind-up is recorded -- which beat, how long the tell
##      actually ran, and what the blow that ended it was worth. This is the
##      section that would catch the hitbox keeping the jab's numbers under the
##      heavy's telegraph, which is the failure the shared hitbox invites.
##      It also calibrates `roll_tier` against `tier_odds` over 4000 draws --
##      what the player gets against what the model promised. What a KNOCKDOWN
##      then does to the hero's body is `hero_struck.gd` section B's job and is
##      deliberately not repeated here.
##   C  **The two tells, photographed at the same point in their curve**, so the
##      lean and the glow can be compared by eye. Both at 80% through the
##      wind-up: the ease is `t*t`, so a frame count would compare two different
##      places on two different curves and prove nothing.

## Where the fight is staged. Clear of the garrison's props, and far enough from
## the walls that a knockdown has room to travel.
const HERO_AT := Vector3(0.0, 0.05, 5.0)
const TROLL_AT := Vector3(0.0, 0.05, 2.6)

## How many wind-ups to watch in section B. The heavy's share is 0.35, so the
## odds of seeing only one of the two beats in eight rolls is under 3%; the
## director asks for both and says so if it did not get them.
const SWINGS := 8
const FRAMES := 1400

## How far through the eased tell section C photographs. Late, because `t*t` puts
## most of the lean in the last third -- an early frame is a monster standing
## still whichever beat it is throwing.
const TELL_AT := 0.80

var _fails: int = 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/troll/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_pricing(rig)
	await _fight(rig)
	await _tells(rig, out)

	if _fails == 0:
		print("TROLL OK -- two beats, and only one of them floors him")


# --- A. the pricing -----------------------------------------------------------

## Both beats through `Hit.tier_odds`, built the way `Enemy` builds them.
##
## Spelled out rather than asked of a live troll on purpose (CLAUDE.md §2): a
## director that reads `_hitbox.commitment` back off the body prints whatever the
## body believes, and cannot catch the body believing the wrong thing. Section B
## is where the live numbers are checked -- against these.
func _pricing(rig) -> void:
	var d: Dictionary = Enemy.DEFS[&"troll"]
	var h: Dictionary = d.get("heavy", {})
	if h.is_empty():
		rig.fail("the troll has no heavy row -- there is nothing to prove")
		_fails += 1
		return

	var light := _odds(d, float(d["windup"]), int(d["damage"]),
		K.KNOCKBACK_LIGHT)
	var heavy := _odds(d, float(h["windup"]), int(h["damage"]),
		float(h["knockback"]))

	print("A light  tell %.2f s  %d q  shove %.1f  ->  %.0f/%.0f/%.0f" % [
		float(d["windup"]), int(d["damage"]), K.KNOCKBACK_LIGHT,
		light.x, light.y, light.z])
	print("A heavy  tell %.2f s  %d q  shove %.1f  ->  %.0f/%.0f/%.0f" % [
		float(h["windup"]), int(h["damage"]), float(h["knockback"]),
		heavy.x, heavy.y, heavy.z])

	# The design, in the owner's words: "troll light attack = medium knockback,
	# heavy attack = medium to knockdown."
	if light.z > light.y:
		rig.fail("A the ordinary swing floors him (%.0f%%) more often than it staggers him (%.0f%%) -- that is a heavy wearing a jab's tell"
			% [light.z, light.y])
		_fails += 1
	if heavy.z < 20.0:
		rig.fail("A the heavy only floors him %.0f%% of the time -- a second beat nobody has to answer differently is not a second beat"
			% heavy.z)
		_fails += 1
	if heavy.z <= light.z * 2.0:
		rig.fail("A the heavy (%.0f%%) is not meaningfully worse than the ordinary swing (%.0f%%)"
			% [heavy.z, light.z])
		_fails += 1

	# **The odds are what `tier_odds` says; the ROLL is what the player gets, and
	# nothing checked that the second matches the first.** A known answer in the
	# strict sense (CLAUDE.md §2): the model's own number is the answer, so a
	# `roll_tier` that read the wrong field, or rolled `<=` where it meant `<`,
	# shows up here as a distribution that misses it. 4000 draws puts the
	# standard error at 0.8 pt, so 3 pt of tolerance is ~4 sigma.
	var hit := Hit.make(int(h["damage"]), Vector3.ZERO, &"contact",
		float(h["knockback"]), 0.0, &"troll",
		float(d["height"]) / K.LAUNCH_MASS_REF,
		Hit.commitment_of_tell(float(h["windup"])))
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var rolled := Vector3.ZERO
	for i in 4000:
		match hit.roll_tier(rng):
			Hit.Tier.KNOCKDOWN:
				rolled.z += 1.0
			Hit.Tier.HEAVY:
				rolled.y += 1.0
			_:
				rolled.x += 1.0
	rolled = rolled / 40.0
	print("A heavy  rolled 4000x       ->  %.0f/%.0f/%.0f  (model %.0f/%.0f/%.0f)"
		% [rolled.x, rolled.y, rolled.z, heavy.x, heavy.y, heavy.z])
	if absf(rolled.z - heavy.z) > 3.0 or absf(rolled.x - heavy.x) > 3.0:
		rig.fail("A roll_tier draws %.0f/%.0f/%.0f where tier_odds promises %.0f/%.0f/%.0f -- the reaction the player gets is not the one the model priced"
			% [rolled.x, rolled.y, rolled.z, heavy.x, heavy.y, heavy.z])
		_fails += 1


## light / heavy / knockdown percentages for one authored beat.
func _odds(d: Dictionary, windup: float, dmg: int, knock: float) -> Vector3:
	var hit := Hit.make(dmg, Vector3.ZERO, &"contact", knock, 0.0, &"troll",
		float(d["height"]) / K.LAUNCH_MASS_REF, Hit.commitment_of_tell(windup))
	var o := hit.tier_odds()
	return Vector3((1.0 - o.y) * 100.0, (o.y - o.x) * 100.0, o.x * 100.0)


# --- B. both beats, thrown ----------------------------------------------------

## Let a troll fight the hero and record every wind-up it starts.
##
## The hero is topped up and pinned every frame. Not to cheat the fight -- this
## director is not measuring whether a troll can kill you -- but because a
## knocked-down hero slides two metres and stops being in reach, and eight
## wind-ups need him standing in front of it eight times.
func _fight(rig) -> void:
	var scene: Node = rig.current_scene
	var found: Array = rig.get_nodes_in_group(&"player")
	if found.is_empty():
		rig.fail("no hero in the scene")
		_fails += 1
		return
	var hero: Node3D = found[0]
	hero.global_position = HERO_AT
	await rig.wait_frames(10)

	var foe := Enemy.new()
	foe.kind = &"troll"
	foe.drop_seed = 4021
	scene.add_child(foe)
	foe.global_position = TROLL_AT
	Bus.camera_recenter.emit()
	await rig.wait_frames(20)

	# beat -> [count, tell seconds, damage landed, knockback, commitment]
	var seen := {}
	var winding := false
	var heavy_now := false
	var tell := 0.0
	var hp := Game.quarters

	for i in FRAMES:
		await rig.wait_frames(1)
		Game.quarters = Game.max_quarters
		hp = Game.quarters
		hero.global_position = HERO_AT

		if foe.state == Enemy.State.WINDUP:
			if not winding:
				winding = true
				heavy_now = foe._heavy
				tell = 0.0
			tell += rig.root.get_process_delta_time()
			continue
		if not winding:
			continue
		# The wind-up just ended. STRIKE is 0.18 s long and the hitbox is live
		# for all of it, so the numbers it committed with are still readable.
		winding = false
		var key := "heavy" if heavy_now else "light"
		var row: Array = seen.get(key, [0, 0.0, 0, 0.0, 0.0])
		row[0] = int(row[0]) + 1
		row[1] = maxf(float(row[1]), tell)
		row[2] = maxi(int(row[2]), foe._hitbox.amount)
		row[3] = maxf(float(row[3]), foe._hitbox.knockback)
		row[4] = maxf(float(row[4]), foe._hitbox.commitment)
		seen[key] = row
		if int(seen.get("light", [0])[0]) >= 1 and int(seen.get("heavy", [0])[0]) >= 1 \
				and int(row[0]) + 1 >= SWINGS:
			break

	for key in ["light", "heavy"]:
		if not seen.has(key):
			rig.fail("B the troll never threw its %s beat in %d frames" % [key, FRAMES])
			_fails += 1
			continue
		var row: Array = seen[key]
		print("B %-5s x%d  tell %.2f s  landed %d q  shove %.1f  commit %.2f" % [
			key, row[0], row[1], row[2], row[3], row[4]])

	if not (seen.has("light") and seen.has("heavy")):
		return

	var lr: Array = seen["light"]
	var hr: Array = seen["heavy"]
	# The failure the shared hitbox invites, and the reason this section is a
	# fight rather than arithmetic: a heavy that telegraphs for a second and then
	# lands the jab's damage, shove and commitment. Every one of the three is
	# checked, because stamping two of them and forgetting the third is the shape
	# the bug actually takes.
	if int(hr[2]) <= int(lr[2]):
		rig.fail("B the heavy landed %d q against the ordinary swing's %d -- the telegraph did not pay"
			% [hr[2], lr[2]])
		_fails += 1
	if float(hr[3]) <= float(lr[3]):
		rig.fail("B the heavy shoved %.1f against the ordinary swing's %.1f"
			% [hr[3], lr[3]])
		_fails += 1
	if float(hr[4]) <= float(lr[4]):
		rig.fail("B the heavy committed %.2f against the ordinary swing's %.2f -- Hit.tier_odds cannot tell them apart"
			% [hr[4], lr[4]])
		_fails += 1
	# And the tell itself, which is the half the player reads. Measured, not
	# authored: `Prog.windup_scale` is in the path and a compressed tell is still
	# a tell, but the two must not converge.
	if float(hr[1]) < float(lr[1]) * 1.5:
		rig.fail("B the heavy telegraphs %.2f s against the ordinary swing's %.2f -- too close to read apart"
			% [hr[1], lr[1]])
		_fails += 1

	foe.queue_free()
	await rig.wait_frames(5)


# --- C. the two tells, side by side -------------------------------------------

## Photograph each beat at the same point in its own eased curve.
##
## Forced rather than waited for, because an unforced pair is two frames from two
## different rolls and cannot be compared -- the same argument `hero_struck.gd`
## makes for forcing the reaction tier. `_heavy` is the switch the game itself
## uses, so setting it is the same door, not a back one.
func _tells(rig, out: String) -> void:
	var scene: Node = rig.current_scene
	var found: Array = rig.get_nodes_in_group(&"player")
	if found.is_empty():
		return
	var hero: Node3D = found[0]
	hero.global_position = HERO_AT

	for beat in ["light", "heavy"]:
		var foe := Enemy.new()
		foe.kind = &"troll"
		foe.drop_seed = 11
		scene.add_child(foe)
		foe.global_position = TROLL_AT
		await rig.wait_frames(20)
		# **Pinned and pre-turned, and the first pass of this director was not.**
		# `_tick_windup` keeps tracking the hero at 130 deg/s while it leans, so
		# the 0.50 s tell got 0.40 s of turning and the 1.05 s tell got 0.84 s --
		# and the pair of frames differed mostly by WHICH WAY THE TROLL WAS
		# FACING. Two photographs of a monster at two angles cannot be compared,
		# whatever the lean is doing. Squared up first, held still after.
		foe.global_position = TROLL_AT
		foe._facing = atan2(HERO_AT.x - TROLL_AT.x, HERO_AT.z - TROLL_AT.z) + PI
		foe.rotation.y = foe._facing

		# Put it straight into the wind-up for the beat we want, rather than
		# waiting for the roll to hand it over.
		foe._heavy = beat == "heavy"
		foe.state = Enemy.State.WINDUP
		var authored: float = foe._beat("windup") * Prog.windup_scale(foe.level)
		foe._timer = authored
		foe._struck = false

		var elapsed := 0.0
		for i in 240:
			await rig.wait_frames(1)
			hero.global_position = HERO_AT
			foe.global_position = TROLL_AT
			elapsed += rig.root.get_process_delta_time()
			if foe.state != Enemy.State.WINDUP or elapsed >= authored * TELL_AT:
				break
		print("C %-5s photographed %.0f%% through a %.2f s tell (lean %.1f deg)"
			% [beat, elapsed / maxf(authored, 0.001) * 100.0, authored,
			rad_to_deg(absf(foe._model_rest.x - foe._model.rotation.x))
				if foe._model != null else 0.0])
		await rig.capture(out.path_join("troll_tell_%s.png" % beat))
		foe.queue_free()
		await rig.wait_frames(5)
