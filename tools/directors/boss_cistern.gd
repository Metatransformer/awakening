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
##   K  **Floor 2's receptacle** (`docs/BOSSES.md` §6.2, board card 34), which is
##      in the Warden's director because the Warden is the fight that drops the
##      Bow and this is what the Bow is for. A Slag Ogre is stood up in the same
##      chamber and thrown `bellows_charge` three times: an arrow into the
##      TRAVEL, which stops it; the same arrow into the WIND-UP, which must not;
##      and the beat unanswered, for the contrast. See the section's own header.
##   L  **The turn** (`docs/BOSSES.md` §5, board card 41): all four bosses'
##      one-phase escalation, photographed either side of the
##      `Bus.boss_phase_changed` emit, with the Warden's annulus guard as its own
##      beat -- the hero standing at 10 m when a fence rises at 8.5. See the
##      section's own header.
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
	await _receptacle(rig)
	await _turns(rig)

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

	# 2.76 m out and off to one side: inside `LockedDoor`'s 2.9 m interact radius,
	# and 11.3 m from the arena's centre, which is outside the 9.02 m seal
	# trigger. The before-shot has to be takeable without starting the fight.
	#
	# OFF TO ONE SIDE and not square-on, which is a camera fix rather than a
	# composition one. The chase camera sits behind the hero along his facing, so
	# a hero standing square in front of the door put the lens at z = -6.4 -- one
	# and a half metres from the sleeping Warden's centre, INSIDE its mesh, and
	# b_01 came back as a screenful of green with the door nowhere in it. Two
	# metres to the right walks the lens past the boss's shoulder instead, and
	# photographs the surround's stepped mouldings at a rake, which is the angle
	# they were built to be read at.
	await _stand_at(rig, door.global_position + Vector3(2.0, 0.05, 1.9),
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
		# The HANDLE, not a lookup by name: `_clear_marker` queue_frees the last
		# one and a freed-but-not-yet-removed sibling makes Godot rename the
		# replacement, so `get_node("Mark")` finds the corpse or nothing.
		var mark: Node3D = boss._marker
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
		if b["shape"] == BossDb.SHAPE_ARC and mark != null:
			# Board card 21. This used to be a rectangle `reach * 2 * sin(half)`
			# across -- 6.9 m of drawn width for a 4.6 m cone -- and no check in
			# this file noticed, because the only probe stood dead in front where
			# the box and the cone happen to agree.
			var fan := _fan_extent(mark)
			print("BOSS %s fan drawn %.1f deg to %.2f m, damage %.1f deg to %.2f m"
				% [id, fan.x, fan.y, float(b["arc_deg"]), float(b["reach"])])
			_ck("D%df and the cone is drawn where the damage is" % i,
				absf(fan.x - float(b["arc_deg"])) < 3.0
				and absf(fan.y - float(b["reach"])) < 0.15)
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


# --- K. Floor 2's receptacle --------------------------------------------------

## **The one row on `docs/BOSSES.md` §7's diagonal that holds in its strong
## form** — and until this section it held only in prose. The branch §6.2
## specifies did not exist, and §9's own warning box says why nobody noticed:
## `SHAPE_CHARGE` had **zero runtime coverage**. `bellows_charge` is the first
## charge any director in this project has ever thrown.
##
## The rule is scoped by ORDERING and not by weapon, so proving it takes two
## shots and never one:
##
##   K1–K5  An arrow into `bellows_charge` **while it is travelling** stops the
##          charge where the arrow found it, brings the beat's authored 1.70 s
##          punish forward, and leaves the hero standing untouched with the plate
##          stopped short of him.
##   K6–K9  **The negative, and it is the half that can fail silently.** The same
##          bow, the same arrow, the same boss, the same beat — loosed into the
##          WIND-UP. It damages, and it changes nothing: the tell lands, the beat
##          commits, and the charge runs its full length through where the hero
##          was standing. A branch that fired on every arrow passes K1–K5 and
##          fails here, and a positive-only director would have shipped it.
##   K10    The same beat with no arrow in it at all, for the contrast frame.
##
## (Section L, the turn, is at the bottom of the file with its own header.)
##
## ## Why the Ogre fights in the Cistern's chamber
##
## Same reason `tools/directors/minibosses.gd` gives: `_boss_test.tscn` carries
## one `Arena` wired to `cistern_warden`, and a fresh `BossArena` built from the
## bare script into the same 26 x 26 room is both the cheapest fixture and a test
## of the construction path `Dungeon._place_chamber` uses. The Ogre's row asks for
## a 12 m arena and three slag posts, and it gets both — the posts are built at
## `radius * 0.55` on 0/120/240 degrees, which puts the nearest one 3.3 m off the
## Z axis this section charges along. That clearance is deliberate: a charge
## stopped by a post is `is_on_wall()` ending the commit early (which is the
## fight's own second answer, `boss_db.gd`'s row says so) and it would read
## exactly like the arrow working.
##
## ## What throwing the first charge in the project's history actually found
##
## `docs/BOSSES.md` §9 says to expect a bug in the charge path, and there was one
## — **in the director, not in `Boss`.** `_park_boss` set `rotation.y` and
## nothing else, and `Enemy._physics_process` writes `rotation.y = _facing` every
## frame, so the parked body's yaw was gone by the next tick. It never showed on
## the Warden, whose beats resolve on the frame of the commit; the Ogre
## committed `bellows_charge` 119 degrees off the hero and ran nine metres into a
## masonry wall — and every check still passed, because the plate had travelled.
## `CLAUDE.md` §4 with a different actor in it: facing is measured, not derived.
## Both parkers set `_facing` now. With that fixed the shape is sound: an
## unanswered charge runs 10.83 m of its authored 11.0 and takes the hero's four
## quarters off him on the way through.
const OGRE_BOSS_Z := -3.5
const OGRE_HERO_Z := 4.0
## Where the punish frame is taken from, every time, and it is BROADSIDE to the
## lane rather than down it. Standing behind the far end put the boss 12 m up the
## room in one case and inside the lens in the other — the same camera cannot do
## both, because the two outcomes are nine metres apart along the axis it would
## be looking down. Side-on at 8 m, with the eye on the middle of the lane, holds
## a plate stopped at z = -1.8 and a plate that finished at z = +7.3 in one frame
## and puts the difference across the picture where it can be seen.
const WATCH_MARK := Vector3(8.0, 0.05, 3.0)
const WATCH_EYE := Vector3(0.0, 0.0, 3.0)

## Recorded off `Bus.hit_landed`, which `Boss._on_damaged` emits BEFORE the
## receptacle branch runs — so this is the boss's state at the instant the arrow
## connected, which is the thing the rule is scoped by. Reading it off
## `health.damaged` instead would be too late: `Enemy._ready` connects
## `_on_damaged` first, so by the time a second handler ran the state would
## already be whatever the branch changed it to.
var _landed: Array[Dictionary] = []
## `beat_committed` → where and when the plate started moving.
var _commit_at: Vector3 = Vector3.ZERO
var _commit_ms: int = 0
var _opened: Array[Dictionary] = []
## `when` -> metres the plate actually travelled. The negative cases are graded
## against the positive one rather than against the authored 11 m; see K8.
var _went: Dictionary = {}
## The `Bus.hit_landed` handler above, held so it can be taken off the bus again.
var _k_landed: Callable = Callable()


func _receptacle(rig) -> void:
	var root: Node = rig.scene()
	# The Cistern's leftovers go first. `arena3` is spent and harmless, but it
	# still holds a seal fence and J's replacement mote in the middle of the
	# chamber the Ogre is about to charge across.
	for n in root.get_children():
		if n.name.begins_with("Arena") or n.name.begins_with("BossDoor"):
			n.queue_free()
	await rig.wait_frames(8)

	var arena := (load("res://scripts/world/boss_arena.gd") as GDScript).new() as Area3D
	arena.name = "Foundry"
	arena.set(&"boss_id", &"slag_ogre")
	arena.set(&"boss_offset", Vector3(0.0, 0.0, OGRE_BOSS_Z))
	root.add_child(arena)
	(arena as Node3D).global_position = Vector3.ZERO
	await rig.wait_frames(20)

	var boss: Node = arena.boss()
	_ck("K0 the Foundry arena built the Slag Ogre", boss != null)
	if boss == null:
		return
	print("BOSS built \"%s\" model=%s hp=%d arena_r=%.1f"
		% [boss.title(), boss.kind, boss.health.max_quarters, boss.arena_radius()])

	# Kept as a handle so it can be DISCONNECTED at the bottom of this section.
	# It captures `boss`, and section L frees that Ogre to stand the next fight
	# up -- a lambda whose capture has been freed refuses to run and prints
	# `Lambda capture at index 0 was freed` on every blow for the rest of the run,
	# which is a page of engine errors in a log whose whole job is to be read.
	_k_landed = func(who: Node3D, amount: int, _at: Vector3) -> void:
		if who != boss:
			return
		_landed.append({
			"amount": amount, "state": boss.state, "charging": boss._charging,
			"beat": boss.current_beat(),
		})
	Bus.hit_landed.connect(_k_landed)
	# Filtered to the charge. The Ogre throws its own beats between the director's,
	# and an arc committing after the plate had stopped would overwrite the mark
	# the travel is measured from.
	boss.beat_committed.connect(func(id: StringName) -> void:
		if id != &"bellows_charge":
			return
		_commit_at = boss.global_position
		_commit_ms = Time.get_ticks_msec())
	boss.punish_opened.connect(func(id: StringName, seconds: float) -> void:
		if id == &"bellows_charge":
			_opened.append({"id": id, "seconds": seconds}))

	# The bow the Warden dropped, and something to put in it. H4 already granted
	# the bow off the kill; the quiver is the harness's own, because what is under
	# test is the branch and not the economy.
	_ck("K0b the hero is carrying the Bow the Warden dropped", Game.has(&"bow"))
	if Game.arrows < 20:
		Game.add_arrows(20 - Game.arrows)
	Game.heal(999)

	# Walked in, so the fight starts the way a fight starts.
	await _stand_at(rig, Vector3(0.0, 0.05, OGRE_HERO_Z), Vector3(0.0, 0.0, OGRE_BOSS_Z))
	await _until(rig, func() -> bool: return arena.is_sealed(), 240)
	_ck("K0c the Foundry sealed and the Ogre woke",
		arena.is_sealed() and boss.is_awake())

	if not await rig.draw_weapon(&"bow"):
		_ck("K0d the weapon ring put the bow in his hand", false)
		return
	_ck("K0d the weapon ring put the bow in his hand", true)

	await _charge_shot(rig, arena, boss, "travel")
	await _charge_shot(rig, arena, boss, "windup")
	await _charge_shot(rig, arena, boss, "none")

	if Bus.hit_landed.is_connected(_k_landed):
		Bus.hit_landed.disconnect(_k_landed)


## One `bellows_charge`, with the arrow loosed into `when` — `travel`, `windup`,
## or `none` at all.
##
## The three cases are ONE function on purpose. The only difference between the
## proof and the disproof has to be the instant the string leaves his fingers; a
## negative case written as its own routine is a negative case that can differ
## from the positive one in some other way and nobody would see it.
func _charge_shot(rig, arena: Node, boss: Node, when: String) -> void:
	# ANNOTATED, not inferred: indexing an untyped `const`/literal Dictionary
	# yields Variant and `:=` on one is the "Cannot infer the type of X" parse
	# error CLAUDE.md §3 lists.
	var tag: String = {"travel": "K1", "windup": "K6", "none": "K10"}[when]
	var b := BossDb.beat(&"slag_ogre", &"bellows_charge")
	var reach := float(b["reach"])
	var travel := reach / float(b["speed"])

	await _mark_ogre(rig, arena, boss)
	# **At full draw BEFORE the beat is queued**, which is where the first version
	# of this had it wrong. `Game.bow_draw_time()` is around half of the 0.90 s
	# tell, so a pull started inside the wind-up spent most of the window it was
	# aiming at and the "windup" arrow left too late to land in it -- once. The
	# other time it landed in the tell and the check passed, which is the worst
	# possible way for a director to be wrong. `HeroRanged._tick_bow` parks the
	# clock at full draw for as long as the trigger is down, so a bow drawn here
	# waits at his ear for as long as the beat takes to arrive and costs nothing.
	if when != "none":
		# Topped up first: a hero who is being knocked about by a beat he is
		# standing in cannot start a pull at all, and the quiver is not what is
		# under test.
		Game.heal(999)
		if Game.arrows < 3:
			Game.add_arrows(10)
		if not await _nock(rig):
			_ck("%s he got to full draw" % tag, false)
			return

	if not await _queue_charge(rig, boss, 600):
		_ck("%s the Ogre threw bellows_charge" % tag, false)
		return
	_park_ogre(arena, boss)
	# **Re-acquired here, after the roam, and this is what run 8 was missing.**
	# `_mark_ogre` locks on before the beat is queued, but `_queue_charge` then
	# lets the Ogre wander the 12 m arena for as long as it takes to roll the
	# charge, and `K.LOCK_BREAK_RANGE` is 10.40 m -- so the lock can be gone by the
	# time the string is let go, and nothing puts it back. It matters because
	# `HeroRanged._aim_at_target_or_camera` falls through to a CROSSHAIR raycast
	# when there is no lock: the shot then goes wherever the boom happens to be
	# pointing, which on a teleported hero is not down the lane. That is exactly
	# what a lost travel arrow looked like -- `landed=[]`, boss untouched, charge
	# unstopped -- and it read as the branch not firing.
	var locked := await _lock_on(rig, boss)
	Game.heal(999)
	# Cleared HERE and not before the queue: the Ogre may have been finishing a
	# beat of its own while the mark was being set, and that beat's own
	# `punish_opened` would otherwise be sitting in `_opened` pretending to be
	# this one's.
	_landed.clear()
	_opened.clear()
	var hp_before: int = boss.health.quarters
	var hero_q := Game.quarters
	# The pull can be lost while the beat is being waited for -- a stray beat that
	# stuns him drops it (`HeroRanged._can_hold`) -- and a lost pull is an arrow
	# that never leaves, which would read downstream as the branch not firing.
	# Said out loud rather than silently re-drawn into the tell.
	if when != "none":
		_ck("%sd he is still at full draw when the tell starts" % tag,
			_at_full_draw(rig))
		_ck("%sl he is locked onto the Ogre, so the shot is aimed at a body" % tag,
			locked)

	# Loosed into the tell FIRST and photographed after, so the frame carries the
	# arrow in the air over the lane rather than a wind-up that has not been
	# answered yet. 0.90 s of tell against about 0.20 s of flight.
	if when == "windup":
		_ck("%sa the arrow left the bow" % tag, await _loose(rig))
	await rig.capture(out.path_join("b_11_%s_tell.png" % when))

	# `current_beat` in the test as well as the state: without it a charge that
	# had already been and gone would be answered by whatever the Ogre rolled
	# NEXT, and the distance measured would be an arc's zero.
	if not await _until(rig, func() -> bool:
			return boss.state == Enemy.State.STRIKE \
				and boss.current_beat() == &"bellows_charge", 400):
		_ck("%s the beat committed while the director was watching" % tag, false)
		return
	# The instant the plate is moving and not one beat before it. This line is
	# the whole scoping claim.
	if when == "travel":
		_ck("%sa the arrow left the bow" % tag, await _loose(rig))
	await rig.capture(out.path_join("b_12_%s_travel.png" % when))

	# Out the far side of the commit, however it ended -- sampling the gap between
	# the two bodies on the way, because "the hero never wore it" wants to say
	# whether the plate got near him and not only whether his health moved.
	var hero: Node3D = _hero(rig)
	var near := INF
	for _i in 600:
		if boss.state != Enemy.State.STRIKE:
			break
		if hero != null:
			near = minf(near, K.plane(hero.global_position - boss.global_position).length())
		await rig.wait_frames(1)
	var went := K.plane(boss.global_position - _commit_at).length()
	_went[when] = went
	print("BOSS %s lane: commit at %.2v, ended %.2v, hero %.2v, lane dir %.2v"
		% [tag, _commit_at, boss.global_position,
			Vector3.ZERO if hero == null else hero.global_position,
			K.flat(boss.global_position - _commit_at)])
	# WALL clock, and printed rather than asserted for that reason: the harness
	# renders at about 22 fps and `Feel.hitstop` stops the engine outright at
	# every commit, so this is not the fight's own clock. `went` is.
	var wall := (Time.get_ticks_msec() - _commit_ms) / 1000.0
	print(("BOSS %s (%s): the plate went %.2f m of %.1f (%.2f s of travel authored)"
		+ " in %.2f s wall, closest approach %.2f m; boss %d -> %d q,"
		+ " hero %d -> %d q; landed=%s")
		% [tag, when, went, reach, travel, wall, near, hp_before,
			boss.health.quarters, hero_q, Game.quarters, _landed])

	var stopped := float(_went.get("travel", 0.0))
	match when:
		"travel":
			_ck("K2 the arrow landed while the charge was travelling",
				_landed.size() == 1 and bool(_landed[0]["charging"])
				and int(_landed[0]["state"]) == int(Enemy.State.STRIKE))
			_ck("K3 and the charge stopped dead -- %.2f m of %.1f" % [went, reach],
				went < reach * 0.5)
			_ck("K4 the hero never wore it -- %.2f m short, %d -> %d q"
				% [reach - went, hero_q, Game.quarters],
				Game.quarters == hero_q and near > 2.0)
		"windup":
			_ck("K6 the arrow landed during the TELL",
				_landed.size() == 1
				and int(_landed[0]["state"]) == int(Enemy.State.WINDUP))
			_ck("K7 and it took health off it (%d -> %d q)"
				% [hp_before, boss.health.quarters],
				boss.health.quarters < hp_before)
			# **The claim is comparative and it has to be**: an unanswered charge
			# does not always reach its authored 11 m, because the hero is standing
			# in the lane and the Ogre's own capsule shoulders past him -- see the
			# note under K10. What the negative case proves is that the arrow at the
			# wrong instant bought NOTHING, and the honest measure of that is the
			# distance against the one that did.
			_ck("K8 and changed nothing -- %.2f m against the stopped charge's %.2f"
				% [went, stopped], went > maxf(stopped * 3.0, reach * 0.6))
		"none":
			_ck("K10 an unanswered charge crosses the floor -- %.2f m of %.1f"
				% [went, reach], went > maxf(stopped * 3.0, reach * 0.6))

	# The punish is the beat's own, both ways round -- a receptacle hit brings the
	# window forward and never invents one (§6.2).
	await _until(rig, func() -> bool: return not _opened.is_empty(), 600)
	var got := -1.0 if _opened.is_empty() else float(_opened[0]["seconds"])
	_ck("%sw the beat still opened its authored %.2f s window (got %.2f)"
		% [tag, float(b["punish"]), got], absf(got - float(b["punish"])) < 0.01)
	await _until(rig, func() -> bool: return boss.is_punishable(), 300)
	# **Photographed from one fixed mark in all three cases, and that IS the
	# contrast.** The camera rides behind the hero, so a punish shot taken from
	# wherever he is standing frames the boss at the same size every time and
	# says nothing; from a mark the plate never reaches, how far up the room the
	# Ogre is IS the measurement — near the far wall when the arrow stopped it,
	# on top of the viewer when it did not. The unanswered case previously put
	# the lens INSIDE the ogre's mesh and photographed a screenful of red.
	await _stand_at(rig, WATCH_MARK, WATCH_EYE)
	# Recentred TWICE, with frames in between. The hero is Z-locked onto the boss
	# and the lock owns the boom, so the first `camera_recenter` is spent fighting
	# it -- the shot came back with the Ogre hard against the edge of the frame.
	# The second one lands after the teleport has settled the lock.
	Bus.camera_recenter.emit()
	await rig.wait_frames(22)
	await rig.capture(out.path_join("b_13_%s_punish.png" % when))
	await _until(rig, func() -> bool: return boss.state == Enemy.State.CHASE, 600)


## Wait for a `bellows_charge` WIND-UP, re-queueing it every frame the Ogre is
## between beats.
##
## **A single `force_beat` is not enough here, and the first run of this section
## proved it by hanging for forty seconds.** `_forced` is a one-shot flag that
## `_choose` consumes on the next pick, so a queue placed while the boss is
## finishing a beat of its own is spent on a wind-up the director was still
## walking the hero into position for — and then it never comes back, because
## `pick_beat`'s range gate excludes `bellows_charge` from every later roll: the
## Ogre closes to `ROAM_RING` (3.8 m) between beats and the beat's own
## `min_range` is 4.5. The Warden's `_tells` above can queue once and walk away
## because none of its three beats has a `min_range` at all.
func _queue_charge(rig, boss: Node, frames: int) -> bool:
	for _i in frames:
		if boss.current_beat() == &"bellows_charge" \
				and boss.state == Enemy.State.WINDUP:
			return true
		if boss.state == Enemy.State.CHASE:
			boss.force_beat(&"bellows_charge")
		await rig.wait_frames(1)
	return false


## Pull the trigger and hold it at full draw.
##
## `Input.action_press` and not `rig.hold`, because the release has to be timed
## against the FIGHT rather than counted in frames -- which is the entire
## difference between the two cases this section proves. The button is polled
## (`HeroCombat._tick_item_trigger`), so a pressed action is seen; CLAUDE.md §3's
## trap is about `_unhandled_input`, which nothing on this path uses.
##
## The arrow does not leave here. `HeroRanged._tick_bow` parks the clock at full
## draw for as long as the trigger is down and looses at the SEAM, so this is a
## bow held at his ear waiting for the beat.
func _nock(rig) -> bool:
	var hero := _hero(rig) as Hero
	if hero == null or hero.ranged == null:
		return false
	# **Re-pressed, and that is the whole of this loop.** The trigger is read as
	# an EDGE (`HeroCombat._tick_item_trigger` polls `is_action_just_pressed`) and
	# `HeroRanged.use_press` REFUSES one outright when the hero is not standing on
	# the floor -- reeling from a beat, mid-roll, a frame after a teleport. So a
	# press declined on frame one is declined for good, and a director that
	# pressed once and then waited would sit out its whole timeout waiting for a
	# draw that was never going to start. It did, intermittently, and only in the
	# runs where the freshly-woken Ogre got a beat off first.
	for _attempt in 12:
		Input.action_release(&"heavy")
		await rig.wait_frames(2)
		Input.action_press(&"heavy")
		if await _until(rig, func() -> bool: return _at_full_draw(rig), 30):
			return true
	Input.action_release(&"heavy")
	return false


## String at his ear, waiting. `_bow_t` is parked ON `_bow_draw` while the
## trigger is down, and set to -1 the moment the pull is abandoned.
func _at_full_draw(rig) -> bool:
	var hero := _hero(rig) as Hero
	if hero == null or hero.ranged == null:
		return false
	return hero.ranged._bow_t >= hero.ranged._bow_draw


## Let go, and say whether an arrow actually left.
##
## The seam is the next tick of `_tick_bow`, so the arrow exists within a frame or
## two of this returning — but it may not exist at all, and that is the failure
## this return value exists to name. `_tick_bow` drops the pull silently the
## moment `_can_hold` goes false (knocked off `MoveState.GROUND`, the bow out of
## his right hand), and a director that assumed the shot left would then measure
## an unanswered charge and report it as the branch not firing. **The quiver is
## the witness**: `_release_arrow` spends the ammo AT the seam and nowhere else,
## so one arrow gone is one arrow in the air.
func _loose(rig) -> bool:
	var before := Game.arrows
	Input.action_release(&"heavy")
	# Up to four render frames: the harness draws at about 22 fps against 60 Hz of
	# physics, so one frame is already three chances at the seam, but a hitstop at
	# the commit can stall the game clock across it.
	for _i in 4:
		await rig.wait_frames(1)
		if Game.arrows < before:
			return true
	return false


## Hold a Z-lock on the boss, taking one if there is not one already.
##
## `z_target` is ONE button that both locks and releases, so a director cannot
## just press it — it has to know what it is holding first. A lock pointing at
## something else (or at a freed Warden) is released and re-taken rather than
## left, because the bow aims at `lock_target()` before it aims at anything else.
func _lock_on(rig, boss: Node) -> bool:
	var hero := _hero(rig) as Hero
	if hero == null:
		return false
	if hero.lock_target() == boss:
		return true
	if hero.lock_target() != null:
		await rig.tap(["z_target"])
		await rig.wait_frames(4)
	await rig.tap(["z_target"])
	# WAITED for rather than counted: `lock_target()` reads `is_locked` off the
	# targeting component, and a tap is an edge that has to survive a frame of
	# input polling and an acquire before that flag is up. A fixed handful of
	# frames read the lock as still absent and then it appeared during the tell --
	# which is why the aim was fine and the check said it was not.
	# Bounded at 24 because this can be called INSIDE the 0.90 s wind-up, and a
	# wait that outlasts the tell would push the "windup" arrow into the commit
	# and quietly turn the negative case into a second positive one.
	return await _until(rig, func() -> bool: return hero.lock_target() == boss, 24)


## The Ogre's mark: eleven metres of lane, aimed down +Z, with the hero standing
## in it at 7.5 m -- inside `K.LOCK_RANGE` (8.49 m) so the bow's aim resolves on
## the locked body rather than on wherever the crosshair happened to be, and far
## enough that a charge stopped in the first third of its travel is visibly short
## of him.
func _mark_ogre(rig, arena: Node, boss: Node) -> void:
	_park_ogre(arena, boss)
	await _stand_at(rig, Vector3(0.0, 0.05, OGRE_HERO_Z), (boss as Node3D).global_position)
	await _lock_on(rig, boss)


## `_facing` and not just `rotation.y` -- see `_park_boss` for what that cost.
func _park_ogre(arena: Node, boss: Node) -> void:
	var at: Vector3 = (arena as Node3D).global_position + Vector3(0.0, 0.0, OGRE_BOSS_Z)
	at.y = boss.global_position.y
	boss.global_position = at
	boss.rotation.y = PI
	boss._facing = PI


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
##
## **`_facing` as well as `rotation.y`, and that is not a belt-and-braces line.**
## `Enemy._physics_process` writes `rotation.y = _facing` every frame, so a
## director that sets only the node has set nothing that survives the next tick
## -- exactly the trap `_stand_at` documents on the hero's side. It was invisible
## on the Warden, whose three beats all resolve on the frame of the commit and
## whose tell has 1.0-1.4 s to turn the body back. It is NOT invisible on a
## charge: parked at the mark with a stale `_facing`, the Slag Ogre committed
## `bellows_charge` 119 degrees off the hero and ran nine metres into a wall, and
## the frame of it looks exactly like a fight working.
func _park_boss(arena: Node, boss: Node) -> void:
	var at: Vector3 = (arena as Node3D).global_position \
		+ Vector3(0.0, 0.0, -WATCH_DIST * 0.5)
	at.y = boss.global_position.y
	boss.global_position = at
	boss.rotation.y = PI
	boss._facing = PI


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


## The half-angle in DEGREES and the radius in metres an arc's floor mark
## actually covers, read off the sector's own vertices. `Boss._fan_marker` builds
## one `ArrayMesh` triangle fan with its apex on the boss, so the widest vertex
## bearing off `-Z` is the drawn half-angle and the longest is the drawn reach.
func _fan_extent(mark: Node3D) -> Vector2:
	var wide := 0.0
	var far := 0.0
	for c in mark.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var arrays: Array = mi.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts:
			var r := Vector2(v.x, v.z).length()
			if r < 0.001:
				continue
			far = maxf(far, r)
			# `atan2(-x, -z)`, so the fan's own `(-sin a, 0, -cos a)` reads back
			# as `a` -- the bearing off the forward the damage measures from.
			wide = maxf(wide, absf(atan2(-v.x, -v.z)))
	return Vector2(rad_to_deg(wide), far)


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


# --- L. The turn ---------------------------------------------------------------

## **`docs/BOSSES.md` §5, and board card 41: the one-phase escalation, built for
## all four bosses and photographed either side of its own signal.**
##
## Here rather than in four new directors for the reason §K gives for the Ogre:
## `_boss_test.tscn` is a 26 m chamber with a hero and a camera in it, and a
## `BossArena` built from the bare script into the middle of it is both the
## cheapest fixture and a test of the construction path `Dungeon._place_boss`
## uses. Four fights, one room, one file.
##
##   L1  **The Warden's `shrink`, standing at 10 m** -- outside the 8.5 m fence
##       the turn is about to raise, which is §9's own beat and the one most
##       likely to fail. He must end up inside the new ring, on the floor, able
##       to walk. `pulled() == 1` is the assertion that says the guard had
##       something to DO: a frame where the hero happened to be standing in the
##       middle proves nothing at all.
##   L2  **The Ogre's `topple`**: three slag posts before, one after.
##   L3  **The Bellwake's `douse`**: the Choir's sconces go out. See `_lit()` --
##       the count is taken off the torches themselves and not off a claim.
##   L4  **The Riven Knight's `keystone`**: nothing hookable in the room before
##       the turn (§6.4 -- the failed press is half the fight), a mass with a
##       `HookTarget` on it after.
##
## And on all four: the turn fires ONCE. Two more blows land after it and
## `Bus.boss_phase_changed` stays at one emit.
##
## ## Why this section brings its own camera
##
## Every other section in this file frames with `_stand_at`, which recentres the
## chase boom behind the hero's facing. That is exactly wrong here. **The
## Warden's turn MOVES THE HERO** -- that is what the annulus guard is -- so a
## boom would move with him, and the before/after pair would differ by the lens
## as much as by the room. A fixed eye is what makes "different pictures" mean
## the room changed. It is parked at `r * 0.86` and 6.2 m up: inside the fence
## whatever the fence is, under the 7.0 m ceiling (`K.CEIL_ROOM`), and high
## enough that the near arc of a 3.4 m seal is crossed well above its top rather
## than photographed from behind it.

## Which way the Warden's kiting player has run. Off the Z axis on purpose: dead
## ahead of the eye puts a 3.4 m boss between the lens and the hero, and the
## annulus frame would be a photograph of the Warden's back.
const KITE_DIR := Vector3(0.55, 0.0, -0.835)

## Every `Bus.boss_phase_changed` this director has seen, in order.
var _phases: Array[int] = []


func _turns(rig) -> void:
	Bus.boss_phase_changed.connect(func(phase: int) -> void: _phases.append(phase))
	# A clean slate, and it is `Game.reset()` rather than a flag poke because
	# section H killed the Warden and wrote `boss_dead_cistern_warden`. A fresh
	# Cistern arena built with that flag up comes back SPENT with no boss in it,
	# which would read as "the turn never fired".
	Game.reset()
	Run.level = 1
	await rig.wait_frames(8)

	# 20 and up: section K already owns b_11 through b_13.
	#
	# **The Bellwake goes LAST, and that ordering is load-bearing.** `douse` is
	# the only turn that changes the room rather than the arena, and nothing puts
	# a sconce back -- the first run of this section had the Riven Knight's
	# keystone photographed in a chamber the Bellwake had already darkened, and
	# the frame is a black rectangle with two health bars in it. A relight here
	# would be the director undoing the thing it just proved.
	await _turn_of(rig, &"cistern_warden", "L1", 20, 10.0)
	await _turn_of(rig, &"slag_ogre", "L2", 30, 0.0)
	await _turn_of(rig, &"riven_knight", "L3", 40, 0.0)
	await _turn_of(rig, &"bellwake", "L4", 50, 0.0)


## One fight's turn, end to end. `kite_r` is how far out from the middle the hero
## is standing when it fires -- 0.0 means "leave him on the mark", and the
## Warden's 10.0 is the annulus.
func _turn_of(rig, id: StringName, tag: String, shot: int, kite_r: float) -> void:
	var root: Node = rig.scene()
	for n in root.get_children():
		if n.name.begins_with("Arena") or n.name.begins_with("BossDoor") \
				or n.name.begins_with("Foundry") or n.name.begins_with("Turn"):
			n.queue_free()
	# And whatever the last fight left standing OUTSIDE its arena. `_shape_summon`
	# parents the Bellwake's choristers to the scene, not to the arena, so freeing
	# the arena leaves two hooded skeletons in the middle of the next fight's
	# frame -- which is exactly what the first run of this section photographed.
	for n in rig.get_nodes_in_group(&"enemy"):
		(n as Node).queue_free()
	await rig.wait_frames(8)

	var arena := (load("res://scripts/world/boss_arena.gd") as GDScript).new() as Area3D
	arena.name = "Turn_%s" % id
	arena.set(&"boss_id", id)
	# `&""`, like a miniboss chamber: this section is about the room and not the
	# economy, and a `boss` slot here would have every fight it stands up trying
	# to place floor 1's relic on the floor.
	arena.set(&"relic_slot", &"")
	arena.set(&"boss_offset", Vector3(0.0, 0.0, -5.0))
	root.add_child(arena)
	(arena as Node3D).global_position = Vector3.ZERO
	await rig.wait_frames(24)

	var boss: Node = arena.boss()
	_ck("%s0 the arena stood up %s" % [tag, id], boss != null)
	if boss == null:
		return
	var hp: HealthComponent = boss.get(&"health")
	var r0: float = arena.radius()
	var t := BossDb.turn(id)
	print("BOSS %s \"%s\" hp=%d r=%.1f turn=%s at=%.2f"
		% [tag, boss.title(), hp.max_quarters, r0, t.get("kind", "-"),
			float(t.get("at", -1.0))])

	# Walked in, so the room shuts the way a room shuts -- and then, for the
	# Warden, walked back OUT to the far edge. That is the player this turn is
	# aimed at: `docs/BOSSES.md` §6.1's whole argument for `shrink` is that it
	# takes the far half of the arena away from someone who has been kiting in it.
	await _stand_at(rig, Vector3(3.0, 0.05, 4.5), Vector3(0.0, 0.0, -5.0))
	await _until(rig, func() -> bool: return arena.is_sealed(), 240)
	_ck("%s1 the room sealed and %s woke" % [tag, id],
		arena.is_sealed() and boss.is_awake())
	Game.heal(999)

	var hero := _hero(rig)
	if kite_r > 0.0:
		hero.global_position = KITE_DIR * kite_r + Vector3(0.0, 0.05, 0.0)
		await rig.wait_frames(10)

	_eye(rig, arena, kite_r > 0.0)
	await rig.wait_frames(4)

	# Down to one quarter ABOVE the threshold in a single blow, so the "before"
	# frame is a fight that is one hit away from turning rather than a fight at
	# full health. One blow and not several: `HealthComponent` holds 0.20 s of
	# i-frames after every hit and a burst would be one landed hit and a swallow.
	var half := hp.max_quarters / 2
	_bleed(boss, hp.max_quarters - (half + 1))
	await rig.wait_frames(4)

	var before := _turn_state(arena, boss, hero)
	print("BOSS %s before: %s" % [tag, before])
	_ck("%s2 nothing has turned yet at %.0f%% health"
		% [tag, hp.fraction() * 100.0],
		not arena.has_turned() and _phases.is_empty())
	await rig.capture(out.path_join("b_%02d_%s_before.png" % [shot, id]))

	# THE BLOW. One quarter, and everything after this line is on the other side
	# of the `Bus.boss_phase_changed` emit.
	await _until(rig, func() -> bool: return not hp.is_invulnerable(), 60)
	_bleed(boss, 1)
	_ck("%s3 the turn fired at %.2f (row says %.2f)"
		% [tag, hp.fraction(), float(t.get("at", -1.0))],
		arena.has_turned() and _phases.size() == 1 and _phases[0] == 1)
	# Long enough for every tween the four turns start: the pull is 0.30 s, the
	# inner ring 0.55 s behind it, `douse` 0.80 s, `topple` 0.55 s.
	await rig.wait_frames(70)

	var after := _turn_state(arena, boss, hero)
	print("BOSS %s after:  %s" % [tag, after])
	await rig.capture(out.path_join("b_%02d_%s_after.png" % [shot + 1, id]))

	await _turn_claims(rig, arena, boss, hero, tag, before, after, r0)

	# Fires ONCE. Two more blows, spaced past the i-frames, and the emit count
	# does not move -- a handler that latched on the wrong side of the compare
	# would turn the room again on every hit for the rest of the fight.
	for _i in 2:
		await _until(rig, func() -> bool: return not hp.is_invulnerable(), 60)
		_bleed(boss, 1)
		await rig.wait_frames(6)
	_ck("%s9 it turned once and stayed turned (%d emit(s))" % [tag, _phases.size()],
		_phases.size() == 1)
	_phases.clear()


## The per-boss half of the claim. Everything above this is the same four lines
## for every fight; this is what each kind actually did to the room.
func _turn_claims(rig, arena: Node, boss: Node, hero: Node3D, tag: String,
		before: Dictionary, after: Dictionary, r0: float) -> void:
	match arena.turn_kind():
		&"shrink":
			var to_r: float = float(BossDb.turn(&"cistern_warden").get("to", 8.5))
			_ck("%s4 the fence walked in (%.1f -> %.1f m)" % [tag, r0, after["r"]],
				is_equal_approx(float(after["r"]), to_r))
			# §5 note 1. The boss's own radius is what `_shape_zone` scatters
			# against, and it is a SEPARATE number from the arena's.
			_ck("%s5 and the boss's arena followed it (%.1f m)"
				% [tag, boss.arena_radius()],
				is_equal_approx(boss.arena_radius(), to_r))
			# THE ANNULUS GUARD, and this line is the one that says the frame is
			# worth anything: the hero was in the ring the wall came up through.
			_ck("%s6 the guard had a body to pull (%d, from %.2f m)"
				% [tag, arena.pulled(), float(before["hero_r"])],
				arena.pulled() == 1 and float(before["hero_r"]) > to_r)
			var hr := float(after["hero_r"])
			_ck("%s7 and he is inside the new ring, not sealed into the annulus "
				% tag + "and not shoved through the outer fence (%.2f m)" % hr,
				hr < to_r - 0.5 and hr > 0.3)
			_ck("%s7b standing on the floor, not on top of a wall (y=%.2f)"
				% [tag, hero.global_position.y], absf(hero.global_position.y) < 0.6)
			# "Able to move" is a claim about the physics and not about a
			# coordinate: a body pushed a hair inside a `StaticBody3D` reports a
			# perfectly good position and cannot walk out of it. Two directions,
			# because which way is free depends on where the pull put him.
			var walked := await _can_walk(rig, hero)
			_ck("%s8 and the fight goes on -- he walks %.2f m" % [tag, walked],
				walked > 0.30)
		&"topple":
			_ck("%s4 three posts became one (%d -> %d)"
				% [tag, int(before["posts"]), int(after["posts"])],
				int(before["posts"]) == 3 and int(after["posts"]) == 1)
		&"douse":
			print("BOSS %s lights in reach: %s" % [tag, _light_census(arena)])
			_ck("%s4 the sconces in the room went out (%d lit -> %d, %d doused)"
				% [tag, int(before["lit"]), int(after["lit"]), arena.doused()],
				arena.doused() > 0 and int(after["lit"]) == 0
				and int(before["lit"]) > 0)
			# And the walk stayed in the room. The corridor's sconces are the
			# control: a `douse` that reached them would be a turn putting out the
			# lights of a whole floor, and `DOUSE_REACH` is the only thing
			# standing between this and that.
			_ck("%s5 and the corridor past it is still lit (%d)"
				% [tag, int(after["lit_out"])],
				int(after["lit_out"]) == int(before["lit_out"])
				and int(after["lit_out"]) > 0)
		&"keystone":
			# §6.4: the arena has nothing hookable in it before the turn, and
			# that absence is half the fight.
			_ck("%s4 there was nothing to hook before it (%d)"
				% [tag, int(before["hooks"])], int(before["hooks"]) == 0)
			_ck("%s5 and the keystone came down with an anchor on it (%d)"
				% [tag, int(after["hooks"])], int(after["hooks"]) == 1)
			var mass := arena.get_node_or_null(^"Keystone") as StaticBody3D
			_ck("%s6 it is solid, in the middle, on the floor" % tag,
				mass != null and mass.collision_layer == K.L_WORLD
				and K.plane(mass.global_position - (arena as Node3D).global_position) \
					.length() < 0.5
				and absf(mass.position.y) < 0.05)


## Everything the four turns can change about a room, read off the room.
func _turn_state(arena: Node, boss: Node, hero: Node3D) -> Dictionary:
	return {
		"r": arena.radius(),
		"boss_r": boss.arena_radius(),
		# `K.plane` and never `K.flat` -- `flat()` normalises (`consts.gd`:901), and
		# reading a radius through it answers 1.00 m for a hero standing anywhere
		# at all. That is how the first run of this section reported the Warden's
		# kiting player one metre from the middle.
		"hero_r": K.plane(hero.global_position
			- (arena as Node3D).global_position).length(),
		"posts": _posts(arena),
		"lit": _lit(arena, true),
		"lit_out": _lit(arena, false),
		"hooks": _hooks(arena),
	}


## Cover posts still standing. Counted by NAME, because that is the handle the
## turn uses: `_build_cover` names them `Cover%d` and `topple` sinks and frees
## the ones past `to`. A post that had been hidden rather than freed would still
## be counted here, which is the point.
func _posts(arena: Node) -> int:
	var n := 0
	for c in (arena as Node).get_children():
		if c.name.begins_with("Cover"):
			n += 1
	return n


## Sconces still burning WITHIN THE TURN'S REACH.
##
## Off the TORCHES and not off the lights: a `KitTorch` rewrites its OmniLight's
## energy every frame from its own export, so a light read at a random frame is a
## sample of a flicker and `is_lit` is the fact.
##
## Bounded by the same `radius + DOUSE_REACH` the turn uses, and that bound is
## the assertion rather than a convenience. `_boss_test.tscn` hangs ten torches
## off the scene root and two of them are down the CORRIDOR -- so an unbounded
## count came back "one still lit" after a douse that had worked perfectly, and
## the corridor sconce staying lit is the bound doing its job. What must be zero
## afterwards is the torches in the room, and what must stay lit is everything
## past it.
func _lit(arena: Node, within: bool) -> int:
	var room: Node = (arena as Node).get_parent()
	if room == null:
		return 0
	var here: Vector3 = (arena as Node3D).global_position
	var reach: float = arena.radius() + 8.0
	var n := 0
	for c in _all(room):
		var torch := c as KitTorch
		if torch == null or not torch.is_lit:
			continue
		var d := K.plane(torch.global_position - here).length()
		if (d <= reach) == within:
			n += 1
	return n


## Every `Light3D` the douse walk can see, by path. Printed rather than asserted:
## the question it answers is "did the turn reach for something that is not the
## room's light" -- the hero's own lamp, a boss's glow -- and that is a thing to
## read once with your eyes, not a number to pin.
func _light_census(arena: Node) -> String:
	var room: Node = (arena as Node).get_parent()
	if room == null:
		return "-"
	var here: Vector3 = (arena as Node3D).global_position
	var reach: float = arena.radius() + 8.0
	var names: Array[String] = []
	for c in _all(room):
		var light := c as Light3D
		if light == null:
			continue
		if K.plane(light.global_position - here).length() <= reach:
			names.append("%s/%s" % [light.get_parent().name, light.name])
	return ", ".join(names)


func _hooks(arena: Node) -> int:
	var n := 0
	for c in _all(arena):
		if c is HookTarget:
			n += 1
	return n


## One blow straight into the health, for the threshold's sake.
##
## `apply_hit` and not a swing: what is under test is the arena's handler and the
## row's fraction, and driving a sword through eleven punish windows to get a
## boss to half health would be section G's proof done twice and a fight's worth
## of frames to reach one signal.
func _bleed(boss: Node, quarters: int) -> void:
	if quarters <= 0:
		return
	var hp: HealthComponent = boss.get(&"health")
	hp.apply_hit(Hit.make(quarters, (boss as Node3D).global_position
		+ Vector3(0.0, 0.0, 3.0), &"sword"))


## How far the hero can actually walk, in metres, trying both lateral directions.
##
## Two directions because which one is free depends on where the pull put him,
## and the claim is "he is not welded into the wall" rather than "he can go
## left". Held through `rig.hold`, which presses the real actions -- the hero
## POLLS his movement (`Input.action_press` dispatches no `InputEvent`, CLAUDE.md
## §3), so this is the same input a player gives.
func _can_walk(rig, hero: Node3D) -> float:
	var best := 0.0
	for action in ["move_left", "move_right"]:
		var from := hero.global_position
		await rig.hold([action], 26)
		await rig.wait_frames(4)
		best = maxf(best, K.plane(hero.global_position - from).length())
	return best


## The fixed eye section L frames every turn through. See the section header for
## why it is not the chase boom.
##
## Two marks, and the second one is a lesson rather than a preference. The
## default is an overview from just inside the fence, which is the right picture
## for three of the four turns -- but the FIRST run put the `shrink` there too,
## and the near arc of the new 8.5 m ring came up a metre in front of the lens
## and filled the bottom of the frame with a wall. The hero, standing 1.2 m
## inside that ring, was behind it. So the annulus mark is a HIGH one near the
## middle, looking outward down the hero's own radius: the wall then rises
## BEYOND him and the pair reads as "the fence came in past me", which is the
## whole claim.
func _eye(rig, arena: Node, annulus: bool) -> Camera3D:
	var cam := rig.scene().get_node_or_null(^"TurnEye") as Camera3D
	if cam == null:
		cam = Camera3D.new()
		cam.name = "TurnEye"
		cam.fov = 62.0
		rig.scene().add_child(cam)
	var at := Vector3(0.0, 6.2, minf(arena.radius() * 0.86, 11.4))
	var look := Vector3(0.0, 1.0, -2.0)
	if annulus:
		at = Vector3(0.0, 6.4, 2.5)
		look = KITE_DIR * 7.5 + Vector3(0.0, 0.8, 0.0)
	cam.global_position = at
	cam.look_at(look, Vector3.UP)
	cam.current = true
	return cam


## Every mote hanging under one arena. Scoped to the arena rather than to the
## scene because the J beat's question is "did THIS prop put one back", and the
## scene still has the corpse's own drop lying about from H.
func _motes(arena: Node) -> Array[LootMote]:
	var out: Array[LootMote] = []
	for n in _all(arena):
		if n is LootMote:
			out.append(n as LootMote)
	return out
