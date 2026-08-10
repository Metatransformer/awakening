extends RefCounted
## M2, "One boss" (docs/SCOPE.md §3): the Cistern Warden, end to end.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_boss_test.tscn \
##     --director=res://tools/directors/boss_cistern.gd \
##     --out=/tmp/boss/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  The table is sound. `BossDb.validate()` returns nothing, and `troll` and
##      `knight_iron` -- named by floor 4's roster and until now missing from
##      `Enemy.DEFS` -- have rows, so nothing spawns a troll-shaped six-quarter
##      skeleton any more.
##   B  Before the fight: the arena is open, the boss is asleep and fitted to the
##      height the table authored, and the door refuses BY NAME. Photographed.
##   C  Walking in SEALS the room. The ring comes up, the boss wakes, and
##      `Bus.boss_engaged` fires exactly once. Photographed.
##   D  Each of the three tells, at its readable frame, from the GAME camera at
##      the distance a player fights from. Three photographs, and the pose is
##      asserted as well as shot -- "the three beats look different" is a claim
##      about pixels, and a `pose` StringName is only an input to it.
##   E  Each commit LANDS, for the quarter-hearts the table authored. Measured on
##      the hero's health, not on the animation.
##   F  The donut. Standing INSIDE `safe_inner` takes nothing from the slam that
##      hurts at 4.4 m. This is the Warden's whole teaching value and it is one
##      comparison.
##   G  Every beat's punish window, MEASURED IN SECONDS off the fight's own clock
##      rather than counted in frames -- the harness renders at about 22 fps and
##      a frame count here would be a measurement of the machine. And a real
##      sword swing inside one of those windows takes health off the boss.
##   H  The kill takes exactly the number of swings the row's comment says it
##      does, and on death: the Bow is GRANTED, the relic `FloorDb` names for
##      floor 1's boss is PLACED (a mote, into the bag -- not a grant), the seal
##      drops and the door opens. Photographed.
##   I  Re-entry with the flag set: an open door and an EMPTY arena. GDD §5.1 --
##      the game never asks you to re-fight something you have already beaten.
##
## Every beat is thrown through `force_beat`. `BossDb.pick_beat` is weighted
## random by design, so no amount of positioning can guarantee a particular one,
## and a director that waited for the roll to come up would be a coin flip with
## a screenshot attached.
##
## `Boss`, `BossDoor` and `BossArena` are never NAMED here. They are `class_name`s
## added in the same change as this file, so they are not in the global class
## cache until the project is re-imported, and naming one is a parse error that
## takes the whole run down before its first frame -- the lesson at the bottom of
## `tools/directors/gate_locks.gd`. Everything below goes through node handles,
## public accessors and `load(path).new()`.

var out := ""
var _fails := 0
var _engaged: Array = []
var _defeated := 0
## beat id -> the punish window the fight actually held open, in seconds.
var _punish: Dictionary = {}

## How far through a tell the shutter opens. Not 1.0: the pose is at its extreme
## just before the commit, and a frame taken ON the commit is a photograph of the
## blow rather than of the warning.
const TELL_SHOT_AT := 0.70

## Where the tells are photographed from. Outside every one of the Warden's
## damaging shapes (the arc reaches 4.6 m, the slam 6.2) so the frame is of the
## TELL and not of the aftermath, and close enough that a 3.4 m body and a 1.65 m
## hero are in one shot at the game camera's own focal length.
const WATCH_DIST := 7.0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/boss/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	Game.reset()
	Run.level = 1

	var arena: Node = rig.scene().get_node_or_null(^"Arena")
	var door: Node = rig.scene().get_node_or_null(^"BossDoor")
	if arena == null or door == null:
		print("BOSS FAIL the fixture is missing the arena or the door")
		return

	Bus.boss_engaged.connect(func(b: Node3D) -> void: _engaged.append(b))
	Bus.boss_defeated.connect(func() -> void: _defeated += 1)

	await rig.wait_frames(20)

	_table()
	await _before(rig, arena, door)

	var boss: Node = arena.boss()
	if boss == null:
		print("BOSS FAIL the arena built no boss")
		return
	boss.punish_closed.connect(func(id: StringName, measured: float) -> void:
		_punish[id] = measured)

	await _seal(rig, arena, boss)
	await _tells(rig, arena, boss)
	await _commits(rig, arena, boss)
	await _windows(rig, arena, boss)
	await _kill(rig, arena, boss, door)
	await _reentry(rig, arena, door)

	if _fails == 0:
		print("BOSS OK -- every check passed")
	else:
		print("BOSS FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("BOSS ok %s" % label)
	else:
		_fails += 1
		print("BOSS FAIL %s" % label)


# --- A. The table -------------------------------------------------------------

func _table() -> void:
	var problems := BossDb.validate()
	for p in problems:
		_ck("A0 table says: %s" % p, false)
	_ck("A0 BossDb.validate() is clean", problems.is_empty())

	# The silent-fallback trap floor 4 was sitting on: `Enemy._resolve_def` swaps
	# an unknown kind for skeleton's STATS while keeping the requested MODEL, so a
	# missing row is a troll-shaped six-quarter skeleton and nothing logs it.
	for kind: StringName in [&"troll", &"knight_iron"]:
		_ck("A1 %s has a row in Enemy.DEFS" % kind, Enemy.DEFS.has(kind))
	if not (Enemy.DEFS.has(&"troll") and Enemy.DEFS.has(&"knight_iron")):
		return
	var troll: Dictionary = Enemy.DEFS[&"troll"]
	var knight: Dictionary = Enemy.DEFS[&"knight_iron"]
	var orc: Dictionary = Enemy.DEFS[&"orc"]
	# The arithmetic the rows' own comment shows, checked rather than asserted in
	# prose. `Prog.health_mult(4)` is 1.75; a light swing is 2 quarters at blade
	# rung 0 and 2 + K.EDGE_DAMAGE[3] = 5 at rung 3.
	var t4 := int(roundf(float(troll["health"]) * Prog.health_mult(4)))
	var k4 := int(roundf(float(knight["health"]) * Prog.health_mult(4)))
	print("BOSS floor-4 health: troll %d q = %d swings at rung 0, %d at rung 3"
		% [t4, ceili(t4 / 2.0), ceili(t4 / 5.0)])
	print("BOSS floor-4 health: knight_iron %d q = %d swings at rung 0, %d at rung 3"
		% [k4, ceili(k4 / 2.0), ceili(k4 / 5.0)])
	_ck("A2 they are heavier than the orc (%d/%d vs %d)"
		% [int(troll["health"]), int(knight["health"]), int(orc["health"])],
		int(troll["health"]) > int(orc["health"])
		and int(knight["health"]) >= int(orc["health"]))
	_ck("A3 and taller (%.2f/%.2f vs %.2f)"
		% [float(troll["height"]), float(knight["height"]), float(orc["height"])],
		float(troll["height"]) > float(orc["height"])
		and float(knight["height"]) > float(orc["height"]))
	# Rung 3 has to stay a real answer to floor 4's heaviest body, or the blade
	# curve stops meaning anything at the bottom of the Descent.
	_ck("A4 rung 3 still kills a floor-4 troll in under ten swings",
		ceili(t4 / 5.0) < 10)


# --- B. Before the fight ------------------------------------------------------

func _before(rig, arena: Node, door: Node) -> void:
	var boss: Node = arena.boss()
	_ck("B0 the arena built a boss", boss != null)
	if boss != null:
		_ck("B1 it is asleep until the room seals", not boss.is_awake())
		print("BOSS built \"%s\" model=%s hp=%d arena_r=%.1f"
			% [boss.title(), boss.kind, boss.health.max_quarters,
				boss.arena_radius()])
		# Contract §1b: the fit is MEASURED, never a magic factor. Proving the
		# NUMBER and not the code path -- the rendered mesh has to actually be
		# 3.40 m tall or the division did nothing.
		var native := Enemy._model_height(boss._model)
		var fitted: float = native * boss._model.scale.y
		print("BOSS golem native=%.3f m, fitted=%.3f m (table says %.2f)"
			% [native, fitted, boss._height()])
		_ck("B2 the golem is fitted to the table's height by measurement (%.2f m)"
			% fitted, absf(fitted - boss._height()) < 0.05)
		# CLAUDE.md §4, which this project has been bitten by three times: the
		# art-space 180 goes on the MODEL node, never into the steering.
		_ck("B3 the art-space 180 is on the model node",
			absf(wrapf(boss._model.rotation.y - PI, -PI, PI)) < 0.01)
	_ck("B4 the room is open", not arena.is_sealed())
	_ck("B5 the door is shut", not door.is_open())
	_ck("B6 and unlocked() says no", not door.unlocked())

	# 2.2 m out: inside `LockedDoor`'s 2.9 m interact radius, and 10.85 m from the
	# arena's centre, which is outside the 9.02 m seal trigger. The before-shot
	# has to be takeable without starting the fight.
	await _stand_at(rig, door.global_position + Vector3(0.0, 0.05, 2.2),
		door.global_position)
	var said: String = Hud._prompt
	print("BOSS the door says: \"%s\"" % said)
	_ck("B7 the refusal names what is holding it", said.contains("CISTERN WARDEN"))
	_ck("B8 and does not just say LOCKED", not said.contains("LOCKED"))
	await rig.capture(out.path_join("b_01_sealed_door.png"))


# --- C. The seal --------------------------------------------------------------

func _seal(rig, arena: Node, boss: Node) -> void:
	# Walked in, not called. `seal()` is public, but the claim is that ENTERING
	# the arena shuts it and the trigger volume is the half of that which can be
	# wrong without anything saying so.
	await _stand_at(rig, arena.global_position + Vector3(0.0, 0.05, 7.0),
		arena.global_position)
	await _until(rig, func() -> bool: return arena.is_sealed(), 180)
	_ck("C0 walking in sealed the room", arena.is_sealed())
	_ck("C1 the boss woke up", boss.is_awake())
	_ck("C2 Bus.boss_engaged fired exactly once (%d)" % _engaged.size(),
		_engaged.size() == 1 and _engaged[0] == boss)
	# `Music` picks itself off that signal (docs/CONTRACT.md §8) and nothing in
	# the fight touches it, so this is the only thing that can be checked from
	# out here -- and it is the one that would break if the boss started its own
	# track.
	_ck("C3 the music moved to BOSS on its own (%s)" % Music.mood_name(),
		Music.mood_name() == "BOSS")
	# `is_sealed()` flips the instant `seal()` is called; the ring itself is a
	# 0.55 s tween behind it, so asserting the pose on the same frame as the flag
	# photographed the fence half-risen and failed a fence that works. Wait for
	# the pose, then assert it -- the timeout is what makes this still a check
	# rather than a sleep: a ring that never comes up runs out the loop and fails.
	var seal: Node3D = arena.get_node_or_null(^"Seal")
	await _until(rig, func() -> bool: return seal.position.y > -0.05, 180)
	_ck("C4 the ring is up (y=%.2f)" % seal.position.y, seal.position.y > -0.05)
	await rig.capture(out.path_join("b_02_sealed.png"))


# --- D. The three tells -------------------------------------------------------

## One photograph per beat at the frame the tell is readable, from the game
## camera, with the hero in shot at the distance a player fights from.
func _tells(rig, arena: Node, boss: Node) -> void:
	var shots := {
		&"sluice_sweep": "b_03_tell_sweep.png",
		&"cistern_drop": "b_04_tell_drop.png",
		&"drown_pool": "b_05_tell_pool.png",
	}
	var seen: Dictionary = {}
	var i := 0
	for id: StringName in shots:
		i += 1
		var tell: Dictionary = BossDb.beat(&"cistern_warden", id)["tell"]
		var total := float(tell["time"])
		Game.heal(999)
		# Queued FIRST, while the boss may still be finishing whatever it rolled
		# for itself. Every Warden beat has `cooldown == punish` or within 0.25 s
		# of it -- pure openings, contract §4 -- so the gap between one beat's
		# window closing and the next tell starting is about one frame, and a
		# director that positioned first would be positioning into a wind-up.
		boss.force_beat(id)
		# Both bodies to the mark, and the camera given time to arrive on it.
		await _mark_up(rig, arena, boss)
		await _until(rig, func() -> bool: return boss.current_beat() == id \
			and boss.state == Enemy.State.WINDUP, 600)
		if boss.current_beat() != id or boss.state != Enemy.State.WINDUP:
			_ck("D%d the boss threw %s" % [i, id], false)
			continue
		# On the first frame of the tell, back on its mark: if it spent the wait
		# above finishing a beat of its own it will have closed some of the gap,
		# and the whole tell should play out from the same place every time. No
		# settle, because the hero has not moved and the camera is already on him.
		_park_boss(arena, boss)
		# MEASURED off the fight's own countdown, not counted in frames.
		await _until(rig, func() -> bool:
			return boss.state != Enemy.State.WINDUP \
				or boss._timer <= total * (1.0 - TELL_SHOT_AT), 200)
		var through := 1.0 - clampf(boss._timer / total, 0.0, 1.0)
		var shape := Vector3(boss._model.rotation.x, boss._model.scale.y,
			boss._model.rotation.z)
		var mark: Node = boss.get_node_or_null(^"Mark")
		if mark == null:
			mark = boss.get_node_or_null(^"Lane")
		print("BOSS tell %s: pose=%s %.0f%% through, model rx=%.2f sy=%.2f rz=%.2f, floor mark=%s"
			% [id, tell["pose"], through * 100.0, shape.x, shape.y, shape.z,
				"yes" if mark != null else "none (a zone draws at commit)"])
		_ck("D%d the %s tell is on screen and still winding up" % [i, id],
			boss.state == Enemy.State.WINDUP and through > 0.45)
		# A pose that moved nothing is a tell nobody can read.
		_ck("D%dp %s holds a pose the rest pose does not" % [i, id],
			absf(shape.x - boss._model_rest.x) > 0.05
			or absf(shape.z - boss._model_rest.z) > 0.05
			or absf(shape.y - boss._fit_scale.y) > 0.02)
		var key := "%.2f|%.2f|%.2f" % [shape.x, shape.y, shape.z]
		_ck("D%ds and one no other beat holds" % i, not seen.has(key))
		seen[key] = id
		# The mark has to be a picture of the damage, not a decoration near it.
		# Measured off the mesh the player is looking at and compared with the
		# numbers `_shape_slam` will test against -- the first version of
		# `_ring_marker` drew a 3.5-4.8 m hoop for a blow that reaches 2.1-6.2 m,
		# and every check in this file still passed because the two probe
		# distances happened to fall on the right side of both.
		var b := BossDb.beat(&"cistern_warden", id)
		if b["shape"] == BossDb.SHAPE_SLAM and mark != null:
			var span := _ring_extent(mark as Node3D)
			print("BOSS %s ring drawn %.2f..%.2f m, damage %.2f..%.2f m"
				% [id, span.x, span.y, float(b["safe_inner"]), float(b["radius"])])
			_ck("D%dr and the ring is drawn where the damage is" % i,
				absf(span.x - float(b["safe_inner"])) < 0.3
				and absf(span.y - float(b["radius"])) < 0.3)
		await rig.capture(out.path_join(shots[id]))
		await _until(rig, func() -> bool: return boss.state == Enemy.State.CHASE, 500)


# --- E and F. The commits -----------------------------------------------------

## Every beat lands for the quarter-hearts the table authored, measured on the
## hero's health. `Game.quarters` and not the animation: the whole reason
## `DamageArea._deliver` exists is that a swing can play perfectly and never move
## the number -- every GLB monster in the game was harmless for weeks under a
## correct-looking attack.
func _commits(rig, arena: Node, boss: Node) -> void:
	# The arc, from directly in front and inside its 4.6 m reach.
	await _commit_beat(rig, arena, boss, &"sluice_sweep", 3.0, true, "E0", 3)
	# The slam, out in the ring where it hurts...
	await _commit_beat(rig, arena, boss, &"cistern_drop", 4.4, false, "E1", 4)
	# ...and under its chin, inside `safe_inner`, where the table says it does
	# not. THE thing this boss teaches: the answer to the biggest attack in the
	# fight is to walk toward it, and a donut whose hole does not work is a fight
	# that punishes the player for reading it correctly.
	await _commit_beat(rig, arena, boss, &"cistern_drop", 1.4, false, "F0", 0)
	# The zone: two discs, the first drawn where the hero IS, bursting after the
	# fuse rather than at the commit. Standing still in one is how you take it.
	await _commit_beat(rig, arena, boss, &"drown_pool", 5.0, false, "E2", 3)


func _commit_beat(rig, arena: Node, boss: Node, id: StringName, dist: float,
		in_front: bool, tag: String, expect: int) -> void:
	var b := BossDb.beat(&"cistern_warden", id)
	boss.force_beat(id)
	await _mark_up(rig, arena, boss)
	await _until(rig, func() -> bool: return boss.current_beat() == id \
		and boss.state == Enemy.State.WINDUP, 600)
	if boss.current_beat() != id or boss.state != Enemy.State.WINDUP:
		_ck("%s the boss threw %s" % [tag, id], false)
		return
	_park_boss(arena, boss)
	# Placed DURING the tell, the one window where the boss is rooted -- so the
	# distance under test is the distance at the commit and not wherever a walking
	# boss happened to end up.
	var at: Vector3 = boss.global_position
	if in_front:
		at += K.flat(-boss.global_transform.basis.z) * dist
	else:
		at += Vector3(0.0, 0.0, 1.0) * dist
	at.y = 0.05
	await _stand_at(rig, at, boss.global_position, false)
	# Healed here and not earlier: a stray beat thrown while we were waiting for
	# this one would otherwise be counted as this one's damage.
	Game.heal(999)
	var before := Game.quarters
	await _until(rig, func() -> bool: return boss.state == Enemy.State.STRIKE, 300)
	await rig.capture(out.path_join("b_06_commit_%s_%s.png" % [tag.to_lower(), id]))
	# Past the fuse, so a zone's discs have had their say. The pool's fuse is
	# 1.10 s against a 0.55 s recovery, so waiting for RECOVER alone would read
	# the health before the water arrived.
	await rig.wait_seconds(float(b.get("fuse", 0.0)) + 0.7)
	var took := before - Game.quarters
	print("BOSS %s %s at %.1f m: %d -> %d quarters (took %d, the row says %d)"
		% [tag, id, dist, before, Game.quarters, took, int(b["damage"])])
	_ck("%s %s at %.1f m takes %d quarters (took %d)"
		% [tag, id, dist, expect, took], took == expect)
	await _until(rig, func() -> bool: return boss.state == Enemy.State.CHASE, 500)


# --- G. The window ------------------------------------------------------------

## The promise the fight makes: every beat, without exception, buys the player a
## window (contract §4). Measured in SECONDS off the fight's own clock -- the boss
## reports what it actually held open, not what the row says it would.
func _windows(rig, arena: Node, boss: Node) -> void:
	var i := 0
	for id: StringName in [&"sluice_sweep", &"cistern_drop", &"drown_pool"]:
		i += 1
		var want := float(BossDb.beat(&"cistern_warden", id)["punish"])
		if not _punish.has(id):
			# D and E should already have banked one for every beat; throw it
			# again if something ate it.
			boss.force_beat(id)
			await _until(rig, func() -> bool: return _punish.has(id), 900)
		var got := float(_punish.get(id, -1.0))
		print("BOSS window %s: authored %.2f s, measured %.2f s" % [id, want, got])
		_ck("G%d %s holds its %.2f s window open (measured %.2f s)"
			% [i, id, want, got], absf(got - want) < 0.12)

	# And the window is worth something: a real swing, from the button, inside
	# one. A punish nobody can hit into is a pause.
	Game.heal(999)
	boss.force_beat(&"sluice_sweep")
	await _mark_up(rig, arena, boss)
	await _until(rig, func() -> bool: return boss.is_punishable(), 900)
	_ck("G4 the window opened", boss.is_punishable())
	# 1.7 m: the sword's hitbox is a 0.84 m sphere thrown 0.74 m forward, and the
	# Warden's capsule is 0.68 m across, so this is inside the blade and outside
	# the body.
	var at: Vector3 = boss.global_position + K.flat(-boss.global_transform.basis.z) * 1.7
	at.y = 0.05
	await _stand_at(rig, at, boss.global_position, false)
	var hp_before: int = boss.health.quarters
	await rig.tap(["attack"])
	await rig.wait_seconds(0.9)
	print("BOSS punish swing: %d -> %d quarters" % [hp_before, boss.health.quarters])
	_ck("G5 a sword swing inside the window takes health off it",
		boss.health.quarters < hp_before)
	await rig.capture(out.path_join("b_07_punish.png"))
	await _until(rig, func() -> bool: return boss.state == Enemy.State.CHASE, 500)


# --- H. The kill and the drop -------------------------------------------------

func _kill(rig, arena: Node, boss: Node, door: Node) -> void:
	var relic: StringName = FloorDb.relic_in(1, &"boss")
	var item: StringName = FloorDb.boss_item(1)
	print("BOSS floor 1 expects item=%s relic=%s" % [item, relic])
	_ck("H0 the hero does not own the %s yet" % item, not Game.has(item))

	# Fought from the middle of the room, so the corpse -- and the mote it drops
	# -- land where the arena can be photographed around them.
	await _mark_up(rig, arena, boss)
	# Back to full, because G5 already took two quarters off it and the claim
	# below is about the row's number rather than about whatever is left.
	boss.health.quarters = boss.health.max_quarters
	var start_q: int = boss.health.quarters
	# Rung-3 swings, 5 quarters each, straight down the real damage path. 48 / 5
	# rounds up to ten, and the row's comment says ten. Paced past
	# `HealthComponent.iframe_time`, because a boss that could be hit twice in a
	# frame makes any count meaningless -- and only LANDED blows are counted, so a
	# swing eaten by i-frames cannot flatter the total.
	await rig.wait_seconds(K.IFRAME_TIME + 0.1)
	var swings := 0
	var tries := 0
	var hero: Node3D = _hero(rig)
	while boss.health.quarters > 0 and tries < 40:
		tries += 1
		if boss.health.apply_hit(Hit.make(5, hero.global_position, &"sword",
				0.0, 0.0, &"director")):
			swings += 1
		if boss.health.quarters == 0:
			break
		# The hero is standing in a live boss fight for the ten seconds this
		# takes. Killing him would end the run in the middle of a measurement.
		Game.heal(999)
		await rig.wait_seconds(K.IFRAME_TIME + 0.06)
	print("BOSS killed with %d landed swings of 5 quarters (%d max)"
		% [swings, start_q])
	_ck("H1 %d quarters is %d rung-3 swings (took %d)"
		% [start_q, ceili(start_q / 5.0), swings], swings == ceili(start_q / 5.0))
	_ck("H2 the boss is dead", boss.health.dead)
	_ck("H3 Bus.boss_defeated fired once (%d)" % _defeated, _defeated == 1)
	_ck("H4 the %s is granted" % item, Game.has(item))

	# Looked for on the SAME frame as the kill, with no wait in between. The drop
	# is synchronous inside `_on_died`, and the mote magnetises toward the hero
	# and is absorbed within a second or two -- the first run of this director
	# looked after a 1.6 s pause, found nothing, and reported a boss that dropped
	# no relic while the relic was already in the bag.
	#
	# It is a MOTE and emphatically not a grant: GDD §3 puts a relic in the BAG,
	# where it costs a slot, is charged the extraction fee and dies with the bag.
	# Granting it would have deleted the decision it exists to create.
	var mote := _find_mote(rig, relic)
	_ck("H5 the relic %s is a mote on the floor, not an owned item" % relic,
		mote != null and not Game.has(relic))
	if mote != null:
		# Walked over, the way a player takes it.
		await _stand_at(rig, mote.global_position + Vector3(0.0, 0.05, 0.0),
			mote.global_position, false)
		await rig.wait_seconds(1.6)
		_ck("H6 and it goes into the BAG (%s)" % [Run.bag],
			int(Run.bag.get(relic, 0)) >= 1)
		_ck("H6b and never into the item list", not Game.has(relic))
	await rig.wait_seconds(1.0)

	await _until(rig, func() -> bool: return door.is_open(), 400)
	_ck("H7 the door opened", door.is_open())
	_ck("H8 the arena is spent", arena.is_spent() and not arena.is_sealed())
	var seal: Node3D = arena.get_node_or_null(^"Seal")
	_ck("H9 and the ring went back down (y=%.2f)" % seal.position.y,
		seal.position.y < -1.0)
	_ck("H10 the kill wrote its one-way flag (%s)" % door.flag_id(),
		Game.flag(door.flag_id()))
	await _stand_at(rig, door.global_position + Vector3(0.0, 0.05, 3.4),
		door.global_position)
	await rig.capture(out.path_join("b_08_open.png"))


# --- I. Coming back -----------------------------------------------------------

## A floor you have cleared. GDD §5.1: the door hangs open and the arena is empty
## forever after -- the game never asks you to re-fight something you have beaten.
##
## Built as FRESH props rather than by reloading the scene, because the claim is
## about CONSTRUCTION: a new arena and a new door, reading the same world flag and
## told nothing else, must come up empty and open. That is exactly what `Dungeon`
## will do at M4 when it rebuilds floor 1.
func _reentry(rig, arena: Node, door: Node) -> void:
	var root: Node = rig.scene()
	var arena_at: Transform3D = (arena as Node3D).global_transform
	var door_at: Transform3D = (door as Node3D).global_transform
	arena.queue_free()
	door.queue_free()
	await rig.wait_frames(8)

	var door2 := (load("res://scripts/world/boss_door.gd") as GDScript).new() as Area3D
	door2.name = "BossDoor2"
	door2.set(&"boss_id", &"cistern_warden")
	door2.set(&"label", "The Long Descent")
	door2.set(&"opening_w", 5.0)
	door2.set(&"opening_h", 5.0)
	var arena2 := (load("res://scripts/world/boss_arena.gd") as GDScript).new() as Area3D
	arena2.name = "Arena2"
	arena2.set(&"boss_id", &"cistern_warden")
	arena2.set(&"door_path", NodePath("../BossDoor2"))
	arena2.set(&"boss_offset", Vector3(0.0, 0.0, -5.0))
	# The door first, and that is an ordering requirement rather than a habit: the
	# arena asks the door whether the fight is already over, on its own `_ready`,
	# and a door that is not in the tree yet answers nothing.
	root.add_child(door2)
	door2.global_transform = door_at
	root.add_child(arena2)
	arena2.global_transform = arena_at
	await rig.wait_frames(30)

	_ck("I0 a re-entered floor builds no boss", arena2.boss() == null)
	_ck("I1 the arena is spent before anybody walks in", arena2.is_spent())
	_ck("I2 the door comes up already open", door2.is_open())
	_ck("I3 and stops offering itself", not door2.enabled)
	await _stand_at(rig, door2.global_position + Vector3(0.0, 0.05, 3.4),
		door2.global_position)
	_ck("I4 the room does not seal itself again", not arena2.is_sealed())
	_ck("I5 there is nothing standing in it",
		arena2.get_node_or_null(^"Boss") == null)
	await rig.capture(out.path_join("b_09_reentry.png"))

	# --- J. The relic you died carrying ---------------------------------------
	#
	# The one relic in the game that could be lost FOREVER, and neither half of
	# the build could see it: `RelicDb.outstanding()` promises that a relic you
	# died holding "answers true again the moment the floor is rebuilt", and the
	# deep chest and the vault keep that promise because they are rebuilt every
	# run. The boss is not. Kill the Warden, take the Anvil-Plate, die on the walk
	# out, and the arena comes back spent with no boss in it and therefore no
	# drop -- forge rungs 3 and 4 gone for the rest of the save.
	#
	# The bag, emptied. `Run.die()` itself refuses outside a run (`in_dungeon` is
	# false in this fixture -- there is no descent here, just a chamber), and what
	# death does to a relic is exactly and only this: it drops the bag and writes
	# NOTHING. `run_state.die()`'s own comment is the specification -- "the held
	# flag was never raised, so `held()` and `donated()` both still answer false,
	# which is precisely the state that means still down there". So the state
	# below IS post-death state, and J1 is the assertion that says so.
	Run.bag.clear()
	await rig.wait_frames(8)
	_ck("J0 losing the bag banked nothing (%s)" % [Run.bag],
		not Run.bag.has(&"anvil_plate") and not RelicDb.donated(&"anvil_plate")
		and not RelicDb.held(&"anvil_plate"))
	_ck("J1 so the Cistern says it is still down there",
		RelicDb.outstanding(&"anvil_plate"))

	var arena3 := (load("res://scripts/world/boss_arena.gd") as GDScript).new() as Area3D
	arena3.name = "Arena3"
	arena3.set(&"boss_id", &"cistern_warden")
	arena3.set(&"door_path", NodePath("../BossDoor2"))
	root.add_child(arena3)
	arena3.global_transform = arena_at
	await rig.wait_frames(30)

	var back := _motes(arena3)
	_ck("J2 the cleared arena put it back on the floor (%d mote(s))" % back.size(),
		back.size() == 1)
	_ck("J3 and it is the Anvil-Plate, not a nameless mote",
		back.size() == 1 and StringName(back[0].get(&"item_id")) == &"anvil_plate")
	# The chest's and the vault's relics are forced cold (`RelicPickup` sets
	# `heat_mult = 1.0`) because a relic was never merchandise the run earned.
	# The boss's went out through `LootMote.drop` and carried the run's heat
	# multiplier instead -- three relics on one floor, one of them paying
	# differently, off a code path nobody would think to compare.
	_ck("J4 and it is cold, like the chest's and the vault's (x%.2f)"
		% (back[0].heat_mult if back.size() == 1 else -1.0),
		back.size() == 1 and is_equal_approx(back[0].heat_mult, 1.0))
	_ck("J5 the arena is still spent -- it did not resurrect the Warden",
		arena3.is_spent() and arena3.boss() == null)
	await _stand_at(rig, arena3.global_position + Vector3(0.0, 0.05, 6.0),
		arena3.global_position)
	await rig.capture(out.path_join("b_10_relic_back.png"))


# --- Helpers ------------------------------------------------------------------

func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return null if players.is_empty() else players[0] as Node3D


## Stand the hero somewhere, facing something, with the boom asked to recentre.
##
## Teleported rather than walked: pathing synthetic input across a 26 m chamber is
## its own project, and what is under test is the fight rather than the
## locomotion.
##
## `facing_yaw` as well as `rotation.y`, because the hero turns toward his own
## heading every frame and setting only the node is undone before the shutter
## opens (docs/CONTRACT.md §2.5 -- facing is measured, not derived). The `+ PI` is
## the same contract from the other side: a Node3D's forward is `-basis.z`, so a
## body whose heading is `h` has `rotation.y = h + PI`.
func _stand_at(rig, at: Vector3, look_at: Vector3, settle: bool = true) -> void:
	var hero := _hero(rig)
	if hero == null:
		return
	hero.global_position = at
	var to := K.flat(look_at - at)
	if to != Vector3.ZERO:
		hero.facing_yaw = atan2(to.x, to.z)
		hero.rotation.y = hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_frames(14 if settle else 3)


## Put the boss back on its half of the mark. Instant, and nothing waits on it.
##
## `-basis.z` is forward (docs/CONTRACT.md §2.5), so a body looking down `+Z` --
## at the hero's half of the mark -- has `rotation.y = PI`. The art-space 180 is
## not this rotation and must not be folded into it: that one lives on the MODEL
## node, where `Boss._ready` put it (CLAUDE.md §4).
func _park_boss(arena: Node, boss: Node) -> void:
	var at: Vector3 = (arena as Node3D).global_position \
		+ Vector3(0.0, 0.0, -WATCH_DIST * 0.5)
	at.y = boss.global_position.y
	boss.global_position = at
	boss.rotation.y = PI


## Both bodies on the mark in the middle of the arena, facing each other, with
## the camera given time to arrive.
##
## Staged rather than followed, and that is what the first run of this director
## got wrong. It placed only the HERO, seven metres behind wherever the boss had
## walked to -- and because the boss closes to `ROAM_RING` between beats, every
## shot pushed the pair further down the room. By the third tell they were in the
## south doorway and the photograph was taken through it. Where in the chamber a
## tell happens is not what these frames are of.
func _mark_up(rig, arena: Node, boss: Node) -> void:
	_park_boss(arena, boss)
	var at: Vector3 = (arena as Node3D).global_position \
		+ Vector3(0.0, 0.05, WATCH_DIST * 0.5)
	await _stand_at(rig, at, (boss as Node3D).global_position)


## Poll a condition, up to `frames` rendered frames. True if it came true.
func _until(rig, pred: Callable, frames: int) -> bool:
	for _i in frames:
		if pred.call():
			return true
		await rig.wait_frames(1)
	return false


## The inner and outer radius an annulus marker actually covers, in metres,
## measured off the corners of the boxes it is built from. Unaffected by the
## grow tween, which scales the marker ROOT and leaves the children where they
## were authored.
func _ring_extent(mark: Node3D) -> Vector2:
	var lo := INF
	var hi := 0.0
	for c in mark.get_children():
		var mi := c as MeshInstance3D
		if mi == null:
			continue
		var box := mi.mesh as BoxMesh
		if box == null:
			continue
		var half: Vector3 = box.size * 0.5
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var p: Vector3 = mi.position \
					+ mi.transform.basis * Vector3(half.x * sx, 0.0, half.z * sz)
				var d := Vector2(p.x, p.z).length()
				lo = minf(lo, d)
				hi = maxf(hi, d)
	return Vector2(lo, hi)


func _find_mote(rig, id: StringName) -> Node3D:
	for n in _all(rig.scene()):
		if n is LootMote and (n as LootMote).item_id == id:
			return n as Node3D
	return null


func _all(root: Node) -> Array:
	var found: Array = [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found


## Every mote hanging under one arena. Scoped to the arena rather than to the
## scene because the J beat's question is "did THIS prop put one back", and the
## scene still has the corpse's own drop lying about from H.
func _motes(arena: Node) -> Array[LootMote]:
	var out: Array[LootMote] = []
	for n in _all(arena):
		if n is LootMote:
			out.append(n as LootMote)
	return out
