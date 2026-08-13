extends RefCounted
## M2, "One boss" (docs/SCOPE.md §3): the Cistern Warden, end to end.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_boss_test.tscn \
##     --director=res://tools/directors/boss_cistern.gd \
##     --out=/tmp/boss/x.png --warmup=60
##
## Add `--item-get-only=1` to stop after H when iterating the reward framing.
##
## Issue #203 moved combat-state ownership to `boss_dynamism.gd`, which proves
## all eight armour/aperture/stagger mappings, exact cycle counts, moving
## attacks and both pressure phases. This legacy director retains the Cistern
## room, reward, persistence, summon-scaling and four arena-turn coverage that
## is unique to it; its old unconditional-punish and direct-chip assertions are
## intentionally no longer invoked.
##
## What it claims, in the order it proves them:
##
##   A  The table is sound. `BossDb.validate()` returns nothing, and `troll` and
##      `knight_iron` -- named by floor 4's roster and until now missing from
##      `Enemy.DEFS` -- have rows, so nothing spawns a troll-shaped 6 HP
##      skeleton any more.
##   B  Before the fight: the arena is open, the boss is asleep and fitted to the
##      height the table authored, and the door refuses BY NAME. Photographed.
##   C  Walking in SEALS the room. The ring comes up, the boss wakes, and
##      `Bus.boss_engaged` fires exactly once. Photographed.
##   D  Each of the three tells, at its readable frame, from the GAME camera at
##      the distance a player fights from. Three photographs, and the pose is
##      asserted as well as shot -- "the three beats look different" is a claim
##      about pixels, and a `pose` StringName is only an input to it.
##   E  Each commit LANDS, for the HP the table authored. Measured on
##      the hero's health, not on the animation.
##   F  The donut. Standing INSIDE `safe_inner` takes nothing from the slam that
##      hurts at 4.4 m. This is the Warden's whole teaching value and it is one
##      comparison.
##   G  Every beat's punish window, MEASURED IN SECONDS off the fight's own clock
##      rather than counted in frames -- the harness renders at about 22 fps and
##      a frame count here would be a measurement of the machine. And a real
##      sword swing inside one of those windows takes health off the boss.
##   H  The kill takes exactly the number of swings the row's comment says it
##      does, and on death: the Bow is NOT granted, its deterministic oversized
##      great chest arrives, and the relic `FloorDb` names is separately PLACED
##      as a mote. Opening the chest through the real prompt grants the Bow and
##      raises the shared item-get camera, model, text and input block. Both
##      reward states are photographed before the seal/door result is checked.
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
##   M  **The Warden's floor AFTER the shrink** (board card 47). Section F above
##      proves the donut at the 11.0 m arena and only there. This runs the same
##      measurement on the other side of the turn, and measures how much floor is
##      left outside the ring with a raycast rather than reading it off the row.
##      See the section's own header.
##   N  **The Riven Knight's hookshot press, photographed** (board card 47).
##      Section L counts the hookables either side of the turn; `docs/BOSSES.md`
##      §6.4 asks for the FAILED press as a picture, because floor 4's fight
##      shape is "the item is both the way across and the way back" and a count
##      is not the player's experience of it. See the section's own header.
##   O  **The summoned adds are curved for the boss's floor** (board card 22),
##      and **the Burst against the choir it is supposed to clear** (board card
##      73): one real blast into the pair the Bellwake calls, clocked from the
##      blast to the frame each is back on the hero, plus the same blast against
##      a bank of twelve seeded choristers because the launch is a roll. See the
##      section's own headers.
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

## `--sabotage=<name>`: break ONE thing on purpose and see whether the check whose
## job it is says so. **`CLAUDE.md` §2 -- a director you have never pointed at a
## known answer has never been tested**, however many times it has passed.
##
## The null case is the ordinary run: no flag, `BOSS ok` on every line.
##
##   `floor-1-adds`  Write `Prog.FIRST` over each summoned add's `level` the frame
##                   after it lands, which is precisely the state card #22 found
##                   the game in -- a floor-3 skeleton carrying floor-1 health.
##                   **O1f/O1g and O2f/O2g must go red.** Everything else stays
##                   green: the bodies are there, the beat was thrown, and only
##                   the numbers on them are wrong, which is the whole reason that
##                   bug survived as long as it did.
##
##   `burst-no-relief`  Hand every blasted chorister straight back to CHASE on
##                   the tick after the blast, with its stagger, its cooldown and
##                   its knockback all cancelled -- "the blast bought nothing",
##                   reproduced from the outside. **O3g and O4d must go red**, and
##                   O3a, O3e, O3f and O4b must not: the blast still landed, it
##                   still took its two HP off both bodies, and only the
##                   relief it bought is gone. Card #73.
##
##   `burst-endless`  The same two checks from the other side: hold every blasted
##                   chorister in HURT for the whole watch, which is a Burst that
##                   DOES buy the strip window. **O3h and O4c must go red.**
##                   Nothing in the game can produce this state -- that is the
##                   point of having it. §6.3 now says the Burst is a shove and
##                   not a strip, and a ceiling nobody has ever pushed against is
##                   a ceiling that is not there (CLAUDE.md §2's null case, run
##                   in the direction a false PASS would come from). Card #73.
const SABOTAGE: Array[String] = ["floor-1-adds", "burst-no-relief", "burst-endless"]

var out := ""
var _fails := 0
var _engaged: Array = []
var _defeated := 0
var _sabotage := ""
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

	_sabotage = rig.arg("sabotage", "")
	if _sabotage != "":
		if not SABOTAGE.has(_sabotage):
			print("BOSS FAIL unknown --sabotage=%s (have %s)" % [_sabotage, SABOTAGE])
			return
		print("BOSS CALIBRATION --sabotage=%s -- this run is SUPPOSED to fail. " % _sabotage
			+ "A green run under a sabotage flag is a broken check, not a pass.")

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
	# Combat commits and damage windows are issue #203's shared eight-row
	# contract, proved by boss_dynamism.gd. The old calls here assumed every
	# recovery accepted chip damage and therefore described the retired fight.
	await _kill(rig, arena, boss, door)
	if rig.arg("item-get-only", "") == "1":
		if _fails == 0:
			print("BOSS OK -- item-get checks passed")
		else:
			print("BOSS FAIL -- %d item-get check(s) failed" % _fails)
		return
	await _reentry(rig, arena, door)
	# The Ogre's live charge aperture is likewise covered by boss_dynamism.gd;
	# this director keeps only the lifecycle evidence it uniquely owns.
	# BEFORE `_turns`, and for the reason `_turns` puts the Bellwake last: `douse`
	# darkens the room and nothing puts a sconce back, so a summon photographed
	# after it is two skeletons in a black rectangle.
	await _summon_band(rig)
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
	# missing row is a troll-shaped 6 HP skeleton and nothing logs it.
	for kind: StringName in [&"troll", &"knight_iron"]:
		_ck("A1 %s has a row in Enemy.DEFS" % kind, Enemy.DEFS.has(kind))
	if not (Enemy.DEFS.has(&"troll") and Enemy.DEFS.has(&"knight_iron")):
		return
	var troll: Dictionary = Enemy.DEFS[&"troll"]
	var knight: Dictionary = Enemy.DEFS[&"knight_iron"]
	var orc: Dictionary = Enemy.DEFS[&"orc"]
	# The arithmetic the rows' own comment shows, checked rather than asserted in
	# prose. `Prog.health_mult(4)` is 1.75; a light swing is 2 HP at blade
	# rung 0 and 2 + K.EDGE_DAMAGE[3] = 5 at rung 3.
	var t4 := int(roundf(float(troll["health"]) * Prog.health_mult(4)))
	var k4 := int(roundf(float(knight["health"]) * Prog.health_mult(4)))
	print("BOSS floor-4 health: troll %d HP = %d swings at rung 0, %d at rung 3"
		% [t4, ceili(t4 / 2.0), ceili(t4 / 5.0)])
	print("BOSS floor-4 health: knight_iron %d HP = %d swings at rung 0, %d at rung 3"
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
			% [boss.title(), boss.kind, boss.health.max_health_points,
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
	_ck("B7 the refusal names what is holding it", said.contains("BOSS KEY"))
	_ck("B8 and does not just say LOCKED", not said.contains("LOCKED"))
	await rig.capture(out.path_join("b_01_sealed_door.png"))

	# This fight fixture predates the generated Boss Chamber, so it proves the
	# threshold contract in place before walking into the arena: a floor-bound
	# Boss Key opens the door once, writes the door flag, and is consumed.
	Game.add_boss_key()
	_ck("B9 the floor-bound Boss Key unlocks the door", door.unlocked())
	door.activate(_hero(rig))
	await _until(rig, func() -> bool: return door.is_open(), 180)
	_ck("B10 the Boss Key opened the threshold", door.is_open())
	_ck("B11 opening consumed the Boss Key", not Game.has_boss_key)
	_ck("B12 opening wrote the door flag", Game.flag(door.flag_id()))


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

## Every beat lands for the HP the table authored, measured on the
## hero's health. `Game.health_points` and not the animation: the whole reason
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
	var before := Game.health_points
	await _until(rig, func() -> bool: return boss.state == Enemy.State.STRIKE, 300)
	await rig.capture(out.path_join("b_06_commit_%s_%s.png" % [tag.to_lower(), id]))
	# Past the fuse, so a zone's discs have had their say. The pool's fuse is
	# 1.10 s against a 0.55 s recovery, so waiting for RECOVER alone would read
	# the health before the water arrived.
	await rig.wait_seconds(float(b.get("fuse", 0.0)) + 0.7)
	var took := before - Game.health_points
	print("BOSS %s %s at %.1f m: %d -> %d HP (took %d, the row says %d)"
		% [tag, id, dist, before, Game.health_points, took, int(b["damage"])])
	_ck("%s %s at %.1f m takes %d HP (took %d)"
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
	var hp_before: int = boss.health.health_points
	await rig.tap(["attack"])
	await rig.wait_seconds(0.9)
	print("BOSS punish swing: %d -> %d HP" % [hp_before, boss.health.health_points])
	_ck("G5 a sword swing inside the window takes health off it",
		boss.health.health_points < hp_before)
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
	# Back to full, because G5 already took two HP off it and the claim
	# below is about the row's number rather than about whatever is left.
	boss.health.health_points = boss.health.max_health_points
	var start_hp: int = boss.health.health_points
	# Rung-3 swings, 5 HP each, straight down the real damage path. 48 / 5
	# rounds up to ten, and the row's comment says ten. Paced past
	# `HealthComponent.iframe_time`, because a boss that could be hit twice in a
	# frame makes any count meaningless -- and only LANDED blows are counted, so a
	# swing eaten by i-frames cannot flatter the total.
	await rig.wait_seconds(K.IFRAME_TIME + 0.1)
	var swings := 0
	var tries := 0
	var hero: Node3D = _hero(rig)
	while boss.health.health_points > 0 and tries < 40:
		tries += 1
		if boss.health.apply_hit(Hit.make(5, hero.global_position, &"sword",
				0.0, 0.0, &"director")):
			swings += 1
		if boss.health.health_points == 0:
			break
		# The hero is standing in a live boss fight for the ten seconds this
		# takes. Killing him would end the run in the middle of a measurement.
		Game.heal(999)
		await rig.wait_seconds(K.IFRAME_TIME + 0.06)
	print("BOSS killed with %d landed swings of 5 HP (%d max)"
		% [swings, start_hp])
	_ck("H1 %d HP is %d rung-3 swings (took %d)"
		% [start_hp, ceili(start_hp / 5.0), swings], swings == ceili(start_hp / 5.0))
	_ck("H2 the boss is dead", boss.health.dead)
	_ck("H3 Bus.boss_defeated fired once (%d)" % _defeated, _defeated == 1)
	_ck("H4 the %s is not silently granted by the kill" % item, not Game.has(item))
	# Snapshot the synchronous physical drop before the chest ceremony gives its
	# magnet time to pull the mote into the hero. Issue #203's mobile kill can
	# leave the corpse much closer than this legacy fixture once assumed.
	var mote := _find_mote(rig, relic)
	_ck("H16 the relic %s is a separate mote on the floor, not an owned item" % relic,
		mote != null and not Game.has(relic))

	var great_chest: Node3D = arena.boss_item_chest()
	_ck("H5 the kill placed one deterministic great chest", great_chest != null)
	if great_chest != null:
		_ck("H6 it carries %s, not a loot roll" % item,
			StringName(great_chest.get(&"item_id")) == item)
		_ck("H7 it is physically larger than an ordinary chest (x%.2f)"
			% great_chest.scale.x, great_chest.scale.x > 1.4)
		# Rebuild the spent arena while the item is still unclaimed. This is the
		# persistence case the live room cannot prove by itself: the boss flag is
		# already written, but ownership is still false, so a fresh arena must bring
		# back the chest without bringing back the fight.
		var retry := (load("res://scripts/world/boss_arena.gd") as GDScript).new() \
			as Area3D
		retry.name = "UnclaimedRewardReentry"
		retry.set(&"boss_id", &"cistern_warden")
		retry.set(&"relic_slot", &"")
		retry.position = Vector3(50.0, 0.0, 0.0)
		rig.scene().add_child(retry)
		await rig.wait_frames(3)
		_ck("H7b an unclaimed great chest returns on re-entry",
			retry.boss_item_chest() != null)
		_ck("H7c and the defeated boss does not return with it", retry.boss() == null)
		retry.queue_free()
		await rig.wait_frames(3)
		await rig.wait_seconds(0.9)
		await _stand_at(rig,
			great_chest.global_position + great_chest.global_transform.basis.z * 1.2
				+ Vector3.UP * 0.05,
			great_chest.global_position)
		await rig.capture(out.path_join("b_08a_great_chest.png"))
		var focused := await _until(rig,
			func() -> bool: return Prompt.focus == great_chest, 120)
		_ck("H8 the great chest owns the ordinary OPEN prompt", focused)
		if focused:
			await rig.tap(["interact"])
			await rig.wait_seconds(0.65)

		var ceremony: Node = rig.scene().get_tree().get_first_node_in_group(&"item_get")
		_ck("H9 opening, not killing, grants the %s" % item, Game.has(item))
		_ck("H10 one item-get ceremony is active", ceremony != null)
		if ceremony != null:
			var title := ceremony.find_child("Title", true, false) as Label
			var display := ceremony.call(&"display_node") as Node3D
			var ceremony_camera := ceremony.call(&"camera_node") as Camera3D
			_ck("H11 its title names the Knightly Bow",
				title != null and title.text.contains("You got the Knightly Bow"))
			_ck("H12 the Bow is held above the hero",
				display != null and display.global_position.y > hero.global_position.y + 1.5)
			_ck("H13 its dedicated camera is current",
				ceremony_camera != null and ceremony_camera.is_current())
			_ck("H14 gameplay input is blocked during the ceremony", Prompt.blocked)
			await rig.capture(out.path_join("b_08b_item_get.png"))
			await rig.wait_seconds(2.3)
			ceremony.call(&"dismiss")
			await rig.wait_frames(5)
			_ck("H15 dismissal restores gameplay input", not Prompt.blocked)

	# Looked for on the SAME frame as the kill, with no wait in between. The drop
	# is synchronous inside `_on_died`, and the mote magnetises toward the hero
	# and is absorbed within a second or two -- the first run of this director
	# looked after a 1.6 s pause, found nothing, and reported a boss that dropped
	# no relic while the relic was already in the bag.
	#
	# It is a MOTE and emphatically not a grant: GDD §3 puts a relic in the BAG,
	# where it costs a slot, is charged the extraction fee and dies with the bag.
	# Granting it would have deleted the decision it exists to create.
	if is_instance_valid(mote):
		# Walked over, the way a player takes it.
		await _stand_at(rig, mote.global_position + Vector3(0.0, 0.05, 0.0),
			mote.global_position, false)
		await rig.wait_seconds(1.6)
	_ck("H17 and it goes into the BAG (%s)" % [Run.bag],
		int(Run.bag.get(relic, 0)) >= 1)
	_ck("H17b and never into the item list", not Game.has(relic))
	await rig.wait_seconds(1.0)

	_ck("H18 the keyed door stayed open through the fight", door.is_open())
	_ck("H19 the arena is spent", arena.is_spent() and not arena.is_sealed())
	var seal: Node3D = arena.get_node_or_null(^"Seal")
	_ck("H20 and the ring went back down (y=%.2f)" % seal.position.y,
		seal.position.y < -1.0)
	var dead_flag := BossDoor.dead_flag(StringName(door.get(&"boss_id")))
	_ck("H21 the kill wrote its separate one-way flag (%s)" % dead_flag,
		Game.flag(dead_flag))
	await _stand_at(rig, door.global_position + Vector3(0.0, 0.05, 3.4),
		door.global_position)
	await rig.capture(out.path_join("b_08_open.png"))


# --- I. Coming back -----------------------------------------------------------

## A floor you have cleared. GDD §5.1: the door hangs open and the arena is empty
## forever after -- the game never asks you to re-fight something you have beaten.
##
## Built as FRESH props rather than by reloading the scene, because the claim is
## about CONSTRUCTION: a new arena and a new door, reading their separate kill
## and open flags and told nothing else, must come up empty and open. That is
## exactly what `Dungeon` does when it rebuilds floor 1.
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
	door2.set(&"opening_w", BossDoor.BOSS_OPENING_W)
	door2.set(&"opening_h", BossDoor.BOSS_OPENING_H)
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
	_ck("I6 and the claimed boss-item chest does not respawn",
		arena2.boss_item_chest() == null)
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
## HP off him on the way through.
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
		% [boss.title(), boss.kind, boss.health.max_health_points, boss.arena_radius()])

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
	var hp_before: int = boss.health.health_points
	var hero_hp := Game.health_points
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
		+ " in %.2f s wall, closest approach %.2f m; boss %d -> %d HP,"
		+ " hero %d -> %d HP; landed=%s")
		% [tag, when, went, reach, travel, wall, near, hp_before,
			boss.health.health_points, hero_hp, Game.health_points, _landed])

	var stopped := float(_went.get("travel", 0.0))
	match when:
		"travel":
			_ck("K2 the arrow landed while the charge was travelling",
				_landed.size() == 1 and bool(_landed[0]["charging"])
				and int(_landed[0]["state"]) == int(Enemy.State.STRIKE))
			_ck("K3 and the charge stopped dead -- %.2f m of %.1f" % [went, reach],
				went < reach * 0.5)
			_ck("K4 the hero never wore it -- %.2f m short, %d -> %d HP"
				% [reach - went, hero_hp, Game.health_points],
				Game.health_points == hero_hp and near > 2.0)
		"windup":
			_ck("K6 the arrow landed during the TELL",
				_landed.size() == 1
				and int(_landed[0]["state"]) == int(Enemy.State.WINDUP))
			_ck("K7 and it took health off it (%d -> %d HP)"
				% [hp_before, boss.health.health_points],
				boss.health.health_points < hp_before)
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

## **`docs/BOSSES.md` §5, and board card 41: the phase-2 arena turn, built for
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
	# **M and N sit INSIDE L's ordering and not after it**, for the same reason
	# the Bellwake is last: both stand up a fight of their own, and a section that
	# ran after a `douse` would photograph a barb in a black room.
	# Leap landing and the live annulus are now measured in boss_dynamism.gd;
	# the shrink/pull assertions above remain this director's responsibility.
	await _turn_of(rig, &"slag_ogre", "L2", 30, 0.0)
	await _turn_of(rig, &"riven_knight", "L3", 40, 0.0)
	await _keystone_press(rig)
	await _turn_of(rig, &"bellwake", "L4", 50, 0.0)


## A fight standing alone in the middle of the chamber, with whatever the last
## one left behind cleared out from under it.
##
## Shared by L, M and N. Building a `BossArena` from the bare script into
## `_boss_test.tscn` is both the cheapest fixture and a test of the construction
## path `Dungeon._place_boss` uses -- and it is the same fifteen lines three
## times if each section keeps its own copy, which is how the second one drifts.
func _fresh_arena(rig, id: StringName, offset: Vector3) -> Area3D:
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
	# `&""`, like a miniboss chamber: these sections are about the room and not
	# the economy, and a `boss` slot here would have every fight they stand up
	# trying to place floor 1's relic on the floor.
	arena.set(&"relic_slot", &"")
	arena.set(&"boss_offset", offset)
	root.add_child(arena)
	(arena as Node3D).global_position = Vector3.ZERO
	await rig.wait_frames(24)
	return arena


## Give the lens back to the hero's own camera.
##
## `Camera3D.current` is a single global fact and nothing in the game ever takes
## it back, so section L's fixed `TurnEye` owns every frame shot after it until
## something says otherwise. That is right for L -- a before/after pair of one
## room must not differ by the lens -- and wrong for M's commits and N's presses,
## which are photographs of what the PLAYER is looking at.
func _game_eye(rig) -> void:
	var cam := rig.scene().get_node_or_null(^"GameCamera") as Camera3D
	if cam != null:
		cam.make_current()


## One fight's turn, end to end. `kite_r` is how far out from the middle the hero
## is standing when it fires -- 0.0 means "leave him on the mark", and the
## Warden's 10.0 is the annulus.
func _turn_of(rig, id: StringName, tag: String, shot: int, kite_r: float) -> void:
	var arena := await _fresh_arena(rig, id, Vector3(0.0, 0.0, -5.0))

	var boss: Node = arena.boss()
	_ck("%s0 the arena stood up %s" % [tag, id], boss != null)
	if boss == null:
		return
	var hp: HealthComponent = boss.get(&"health")
	var r0: float = arena.radius()
	var t := BossDb.turn(id)
	print("BOSS %s \"%s\" hp=%d r=%.1f turn=%s at=%.2f"
		% [tag, boss.title(), hp.max_health_points, r0, t.get("kind", "-"),
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

	# Down to 1 HP ABOVE the threshold in a single blow, so the "before"
	# frame is a fight that is one hit away from turning rather than a fight at
	# full health. One blow and not several: `HealthComponent` holds 0.20 s of
	# i-frames after every hit and a burst would be one landed hit and a swallow.
	var half := hp.max_health_points / 2
	_bleed(boss, hp.max_health_points - (half + 1))
	await rig.wait_frames(4)

	var before := _turn_state(arena, boss, hero)
	print("BOSS %s before: %s" % [tag, before])
	_ck("%s2 nothing has turned yet at %.0f%% health"
		% [tag, hp.fraction() * 100.0],
		not arena.has_turned() and _phases.is_empty())
	await rig.capture(out.path_join("b_%02d_%s_before.png" % [shot, id]))

	# THE BLOW. 1 HP, and everything after this line is on the other side
	# of the `Bus.boss_phase_changed` emit.
	await _until(rig, func() -> bool: return not hp.is_invulnerable(), 60)
	_bleed(boss, 1)
	_ck("%s3 the turn fired at %.2f (row says %.2f)"
		% [tag, hp.fraction(), float(t.get("at", -1.0))],
		arena.has_turned() and _phases.size() == 1 and _phases[0] == 2)
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
func _bleed(boss: Node, health_points: int) -> void:
	if health_points <= 0:
		return
	var hp: HealthComponent = boss.get(&"health")
	hp.apply_hit(Hit.make(health_points, (boss as Node3D).global_position
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


# --- M. The Warden's floor, after the fence walked in --------------------------

## **`docs/BOSSES.md` §6.1 and §9's last open line on the shrink. Board card 47.**
##
## Section F above proves the donut at the **11.0 m** arena and only there:
## `cistern_drop` takes its four HP at 4.4 m and takes NOTHING under the
## chin at 1.4 m, which is floor 1's whole fight shape — the answer to the
## biggest, loudest attack in the fight is to walk toward it. Card 41 then moved
## the fence to **8.5 m** at half health and nobody re-ran F on the other side of
## it. If the donut and the shrunken fence leave nowhere to stand, floor 1's
## escalation deletes floor 1's fight shape, silently, at half health, in front of
## an audience.
##
##   M1  **The floor BEFORE**, measured off the fence rather than read off the
##       row — twenty-four rays out of the arena's own pivot. The row says 11.0
##       and the floor stops about a fifth of a metre inside it, because a seal is
##       twenty 0.45 m panels centred ON that radius; it is the floor the player
##       stands on that this section is about and not the number.
##   M2  The turn fires and the fence's inner face moves with it.
##   M3  **The hole still works.** Section F's own measurement — `cistern_drop`,
##       1.4 m, zero HP — after the shrink.
##   M4  **And it is still a donut.** The same beat at 4.4 m still lands its four.
##       A slam whose safe hole had swallowed the ring would pass M3 and be a
##       fight with no attack in it, which is the failure M3 alone cannot see.
##   M5  **There is still floor outside the ring to stand on**, and it is the one
##       claim the shrink could actually break. The boss parked in the middle of
##       its own arena, the hero at 7.0 m — outside the 6.2 m ring, inside the new
##       fence — taking nothing from the slam and able to walk out of where he is
##       standing.
##
## The verdict M reports is an ANNULUS and not a yes/no, because the two answers
## §6.1 gives the player are on opposite sides of the ring and the shrink only
## touches one of them. The hole (0 → 2.1 m) is a fact about the beat and the
## fence cannot reach it. The kiting ground (6.2 m → the fence) is what the turn
## is aimed at, and §6.1 says out loud that taking it away is the point.

## Bearings the fence is measured on. Twenty against twenty panels would sample
## one point per panel and could sit on the joints for ever; twenty-four walks
## across them.
const FENCE_BEARINGS := 24

## Where M5 stands the hero: outside `cistern_drop`'s 6.2 m ring and inside the
## 8.5 m fence, on the same bearing L1's kiting player ran down so the two frames
## read as the same corner of the same room.
const BAND_STAND := 7.0


func _warden_floor(rig) -> void:
	var arena := await _fresh_arena(rig, &"cistern_warden",
		Vector3(0.0, 0.0, -WATCH_DIST * 0.5))
	var boss: Node = arena.boss()
	_ck("M0 the arena stood the Warden up again", boss != null)
	if boss == null:
		return
	_game_eye(rig)
	var hp: HealthComponent = boss.get(&"health")
	var b := BossDb.beat(&"cistern_warden", &"cistern_drop")
	var inner := float(b["safe_inner"])
	var outer := float(b["radius"])

	# Walked in, so the fence that is about to be measured is the fence a fight
	# actually raises.
	await _stand_at(rig, Vector3(3.0, 0.05, 4.5), (boss as Node3D).global_position)
	await _until(rig, func() -> bool: return arena.is_sealed(), 240)
	# `SEAL_RISE` is a tween and the ray does not care what the mesh is doing --
	# but the COLLISION rides the same node, so a ray fired while the ring is
	# still coming up out of the floor passes over the top of it and reports the
	# masonry at 13 m. Waited out rather than assumed.
	await rig.wait_frames(40)
	Game.heal(999)

	var face0 := _fence_face(arena)
	_ck("M1 the room sealed at the authored 11.0 m (inner face %.2f m)" % face0.x,
		arena.is_sealed() and absf(face0.x - 11.0) < 0.6)
	print("BOSS M1 before: fence face %.2f..%.2f m, standable to %.2f m; "
		% [face0.x, face0.y, face0.x - K.HERO_RADIUS]
		+ "donut %.1f..%.1f m -> %.2f m of floor outside the ring"
		% [inner, outer, face0.x - K.HERO_RADIUS - outer])

	# One blow to 1 HP above the threshold, one more to cross it. The same
	# two-step section L uses, and for the same reason: `HealthComponent` holds
	# 0.20 s of i-frames and a burst would be one landed hit and a swallow.
	var half := hp.max_health_points / 2
	_bleed(boss, hp.max_health_points - (half + 1))
	await rig.wait_frames(4)
	await _until(rig, func() -> bool: return not hp.is_invulnerable(), 60)
	_bleed(boss, 1)
	await rig.wait_frames(70)

	var face1 := _fence_face(arena)
	var band0 := face0.x - K.HERO_RADIUS - outer
	var band1 := face1.x - K.HERO_RADIUS - outer
	_ck("M2 the fence walked in (%.2f -> %.2f m of inner face)"
		% [face0.x, face1.x],
		arena.has_turned() and absf(face1.x - 8.5) < 0.6 and face1.x < face0.x)
	print("BOSS M2 after:  fence face %.2f..%.2f m, standable to %.2f m; "
		% [face1.x, face1.y, face1.x - K.HERO_RADIUS]
		+ "donut %.1f..%.1f m -> %.2f m of floor outside the ring"
		% [inner, outer, band1])
	print("BOSS M2 THE ANNULUS: outside the ring %.2f m -> %.2f m of standable "
		% [band0, band1] + "floor; the hole is 0.00 -> %.2f m either way" % inner)

	# **Section F, re-run, on the other side of the turn.** Same function, same
	# two distances, same expected HP -- the only thing that has changed
	# between F and this is the fence, which is the whole question.
	await _commit_beat(rig, arena, boss, &"cistern_drop", 1.4, false, "M3", 0)
	await _commit_beat(rig, arena, boss, &"cistern_drop", 4.4, false, "M4", 4)

	await _band_stand(rig, arena, boss, b)
	# **`_phases` is `_turn_of`'s ledger and this section fires a turn into it.**
	# Left behind, it is a `boss_phase_changed` the NEXT fight's L2 blames on
	# itself: "nothing has turned yet" reads a non-empty array and fails, and the
	# emit count comes out at two. Six checks in L failed exactly this way the
	# first time M and N were run inside its ordering.
	_phases.clear()


## M5. The floor left OUTSIDE the ring, stood on.
##
## Written out rather than handed to `_commit_beat` because that function measures
## from the boss's own mark (`_park_boss`, half a `WATCH_DIST` up the room) and
## this claim is about the arena's middle: "is there floor between the ring and
## the fence" only means anything when the two circles share a centre. So the
## boss is parked ON the pivot and the hero put out on L1's kiting bearing, which
## also puts the pair where `_eye`'s annulus mark can see both.
func _band_stand(rig, arena: Node, boss: Node, b: Dictionary) -> void:
	var here: Vector3 = (arena as Node3D).global_position
	var at := here + KITE_DIR * BAND_STAND + Vector3(0.0, 0.05, 0.0)
	_park_centre(arena, boss, at)
	await _stand_at(rig, at, here)
	boss.force_beat(&"cistern_drop")
	await _until(rig, func() -> bool: return boss.current_beat() == &"cistern_drop" \
		and boss.state == Enemy.State.WINDUP, 600)
	# Re-parked during the tell, the one window where the boss is rooted, so the
	# distance under test is the distance at the commit -- `_commit_beat` makes
	# the same move for the same reason.
	_park_centre(arena, boss, at)
	await _stand_at(rig, at, here, false)
	_eye(rig, arena, true)
	Game.heal(999)
	var hero := _hero(rig)
	var stand := K.plane(hero.global_position - here).length()
	var gap := K.plane(hero.global_position - (boss as Node3D).global_position).length()
	var before := Game.health_points
	await _until(rig, func() -> bool: return boss.state == Enemy.State.STRIKE, 300)
	await rig.capture(out.path_join("b_22_cistern_warden_band.png"))
	await rig.wait_seconds(0.7)
	var took := before - Game.health_points
	print("BOSS M5 standing at %.2f m of the pivot, %.2f m of the boss: %d -> %d HP"
		% [stand, gap, before, Game.health_points])
	_ck("M5 the band outside the ring is inside the fence (%.2f m of %.2f)"
		% [stand, _fence_face(arena).x], stand < _fence_face(arena).x - K.HERO_RADIUS)
	_ck("M5b and the slam does not reach it (took %d, ring ends at %.1f m)"
		% [took, float(b["radius"])], took == 0)
	# "There is floor" is a claim about the physics and not about a coordinate: a
	# body a hair inside a `StaticBody3D` reports a perfectly good position and
	# cannot walk out of it. L1's own check, on the band rather than on the pull.
	var walked := await _can_walk(rig, hero)
	_ck("M5c and he can stand and move in it -- he walks %.2f m" % walked,
		walked > 0.30)
	await _until(rig, func() -> bool: return boss.state == Enemy.State.CHASE, 500)


## The fence's inner face, in metres off the arena's pivot, measured.
##
## Read rather than derived, which is `CLAUDE.md` §4 wearing a different hat. The
## row says 11.0 and 8.5; a seal is twenty 0.45 m panels CENTRED on that radius
## and overlapped 1.2x at the joints, so the floor stops somewhere inside the
## number and the amount is not a thing to work out on paper. Returns the nearest
## and furthest hit, because the spread between them IS the panelling.
##
## `K.L_WORLD` only: the hero is on `L_PLAYER` and the boss on `L_ENEMY`, so
## neither body can stand in for a wall. The chamber's own masonry is at 13 m and
## every fence this measures is inside it.
func _fence_face(arena: Node) -> Vector2:
	var here: Vector3 = (arena as Node3D).global_position + Vector3(0.0, 0.9, 0.0)
	var space := (arena as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = K.L_WORLD
	q.collide_with_bodies = true
	q.collide_with_areas = false
	var lo := INF
	var hi := 0.0
	for i in FENCE_BEARINGS:
		var a := TAU * float(i) / float(FENCE_BEARINGS)
		q.from = here
		q.to = here + Vector3(cos(a), 0.0, sin(a)) * 20.0
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			continue
		# `K.plane` and never `K.flat` -- `flat()` NORMALISES (`consts.gd`:901),
		# and a fence measured through it is 1.00 m away whatever it is doing.
		var d := K.plane((hit["position"] as Vector3) - here).length()
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return Vector2(0.0 if lo == INF else lo, hi)


## Put the boss on the arena's own pivot, facing `look_at`.
##
## `_facing` and not just `rotation.y`, for the reason `_park_boss` spells out at
## length: `Enemy._physics_process` writes `rotation.y = _facing` every frame and
## a parker that sets only the node has set nothing. The `+ PI` is
## `docs/CONTRACT.md` §2.5 from the other side -- a Node3D's forward is `-basis.z`.
func _park_centre(arena: Node, boss: Node, look_at: Vector3) -> void:
	var at: Vector3 = (arena as Node3D).global_position
	at.y = boss.global_position.y
	boss.global_position = at
	var to := K.flat(look_at - at)
	var yaw := (atan2(to.x, to.z) + PI) if to != Vector3.ZERO else PI
	boss.rotation.y = yaw
	boss._facing = yaw


# --- N. The Riven Knight's press ----------------------------------------------

## **`docs/BOSSES.md` §6.4, and the half of §9's Riven Knight line that section L
## does not do. Board card 47.**
##
## L4 counts the hookables either side of the turn -- nought before, one after --
## and a count is not the player's experience of it. §6.4 asks for the FAILED
## press as a picture, because floor 4's fight shape is *"the item is both the way
## across and the way back"* and the first sixty-four HP of the fight are
## the half where the item has nothing in the room to attach to. That claim is a
## photograph or it is a sentence.
##
##   N1  **The press that finds nothing.** The chain goes out its full 8.74 m at
##       the middle of the arena, bites nothing, and drops. The hero does not
##       move a centimetre.
##   N2  **The same press, after the keystone lands.** The barb catches, the chain
##       goes taut, and the hero crosses the room on it -- and ends up ON the
##       mass, which is what makes it a reposition rather than an escape.
##
## ## The Knight stands still for both, and that is deliberate
##
## The same argument section L makes for bleeding with `apply_hit` rather than
## fighting: the claim here is about the item and the room, and a `gate_lunge` --
## twelve metres at 16 m/s down a 1.2 m lane, on a 0.78 s tell -- through the
## middle of the shot is a second variable in a photograph that has one subject.
## Worse than untidy: `HeroRanged._fire_hookshot`'s raycast has `K.L_ENEMY` in its
## mask, so a Knight that had walked into the lane would be BITTEN, which is a
## third outcome (`Boss.freeze` clangs and nothing moves) that photographs almost
## exactly like the failed press it is standing next to. The room is sealed --
## the fence is up, the bar is up, the fight has started -- and then the boss is
## held in the guard it has been standing in for four hundred years.
##
## ## Why the engine is slowed and nothing measured is
##
## `K.HOOK_SPEED` is 34 m/s, so a full-reach chain is out and back in 0.26 s. The
## harness renders at about 22 fps: the whole flight is five or six frames and
## `progress` steps by about half a chain per rendered frame, so "photograph the
## barb in the air" is a coin toss at real time. `Engine.time_scale` buys the
## shutter the frames and changes nothing this section asserts -- every claim
## below is a position, a boolean or a node, and not one of them is a duration.
## Restored on every exit, including the failed ones.

## Where the hero presses from. Inside `Game.hook_reach()` (8.74 m at rung 0) of
## an anchor 2.4 m up over the middle, and far enough out that the crossing is a
## crossing.
const PRESS_STAND := 6.5
## Where the Knight is held. Off the lane by four metres -- clear of the chain's
## line and of the 3 m keystone, and still inside the frame at the aim stance's
## 42 degrees of lens.
const PRESS_BOSS := Vector3(-4.0, 0.0, -2.5)
## How slowly the two flights are photographed. See the section header.
const PRESS_TIME_SCALE := 0.20
## Where both presses are aimed, in metres above the arena's pivot. `docs/
## BOSSES.md` §6.4's number; the built anchor is 2.55 and `_press_of` prints both.
const PRESS_AIM_Y := 2.4


func _keystone_press(rig) -> void:
	var arena := await _fresh_arena(rig, &"riven_knight", PRESS_BOSS)
	var boss: Node = arena.boss()
	_ck("N0 the arena stood the Riven Knight up again", boss != null)
	if boss == null:
		return
	_game_eye(rig)
	var hp: HealthComponent = boss.get(&"health")
	var here: Vector3 = (arena as Node3D).global_position
	# Where the anchor is GOING to be, and it has to be a constant here rather
	# than a read: the two presses must be aimed at the same place, and on the
	# first one there is nothing in the room to read a height off.
	#
	# **It is not a row key either**, which is what this section found. `docs/
	# BOSSES.md` §6.4's pasted row ends `"radius": 1.5, "hook_y": 2.4` and
	# `BossDb`'s Riven Knight carries neither: the mass is
	# `BossArena.KEYSTONE_SIZE`, one `Vector3(3, 2.4, 3)`, and the anchor is built
	# on top of it at `KEYSTONE_SIZE.y + 0.15`. So this aims where §6.4 SAYS the
	# ring is, the check below prints where it actually got built, and the 0.15 m
	# between them is nothing against an assist cone 19 degrees wide.
	var at := here + Vector3(0.0, PRESS_AIM_Y, 0.0)

	# The Hookshot is the Bellwake's drop and this section is not the economy.
	Game.grant(&"hookshot")
	_ck("N0b the hero is carrying the Hookshot", Game.has(&"hookshot"))
	await _stand_at(rig, here + Vector3(0.0, 0.05, PRESS_STAND), here)
	if not arena.is_sealed():
		arena.seal()
	await _until(rig, func() -> bool: return arena.is_sealed(), 120)
	await rig.wait_frames(40)
	_ck("N0c the Chord Gate sealed", arena.is_sealed())
	if not await rig.draw_weapon(&"hookshot"):
		_ck("N0d the weapon ring put the Hookshot in his hand", false)
		return
	_ck("N0d the weapon ring put the Hookshot in his hand", true)

	await _press_of(rig, arena, boss, at, "N1", 44, false)

	# THE TURN, exactly as section L fires it: one blow to 1 HP above the
	# threshold and one more across it.
	var half := hp.max_health_points / 2
	_bleed(boss, hp.max_health_points - (half + 1))
	await rig.wait_frames(4)
	await _until(rig, func() -> bool: return not hp.is_invulnerable(), 60)
	_bleed(boss, 1)
	_ck("N3 the keystone came down", arena.has_turned() and _hooks(arena) == 1)
	await rig.wait_frames(50)

	await _press_of(rig, arena, boss, at, "N4", 45, true)
	# See `_warden_floor`: this section's turn is not the Bellwake's to answer for.
	_phases.clear()


## One press, from the brace to whatever the chain found.
##
## ONE function for both cases, the argument `_charge_shot` makes above: the only
## difference between the proof and the disproof has to be the state of the room,
## and a negative case written as its own routine is a negative case that can
## differ from the positive one in some other way that nobody ever sees.
func _press_of(rig, arena: Node, boss: Node, at: Vector3, tag: String,
		shot: int, want_bite: bool) -> void:
	var here: Vector3 = (arena as Node3D).global_position
	var hero := _hero(rig) as Hero
	if hero == null or hero.ranged == null:
		_ck("%s the hero has a ranged component" % tag, false)
		return
	_hold_still(boss, here + Vector3(0.0, 0.0, PRESS_STAND))
	await _stand_at(rig, here + Vector3(0.0, 0.05, PRESS_STAND), here)

	# The brace. Re-pressed rather than pressed once, for the reason `_nock`
	# gives: `use_press` REFUSES outright unless the hero is standing on the
	# floor, so a press made a frame after a teleport is declined for good and a
	# director that pressed and then waited would sit out its whole timeout.
	var braced := false
	for _attempt in 8:
		Input.action_release(&"heavy")
		await rig.wait_frames(2)
		Input.action_press(&"heavy")
		if await _until(rig, func() -> bool: return hero.ranged._hook_ready, 24):
			braced = true
			break
	_ck("%sa the Hookshot came up into its brace" % tag, braced)
	if not braced:
		Input.action_release(&"heavy")
		return
	# The aim stance takes the boom to the shoulder and the lens to 42 degrees,
	# and the crosshair the shot converges on is only where it belongs once that
	# has arrived.
	await rig.wait_frames(20)
	var off := await _aim_camera_at(rig, at, 40)
	# A DIAGNOSTIC and not the claim -- the claim is what the chain found, below.
	# 9 degrees because the assist cone this feeds is about 19 wide at this range
	# and one held frame of look is already five or six of them.
	_ck("%sb and the crosshair is on the anchor (%.1f deg off)" % [tag, off],
		absf(off) < 9.0)

	var from := hero.global_position
	Engine.time_scale = PRESS_TIME_SCALE
	Input.action_release(&"heavy")
	var fired := await _until(rig,
		func() -> bool: return hero.ranged._hook_active, 40)
	_ck("%sc the chain went out" % tag, fired)
	if not fired:
		Engine.time_scale = 1.0
		return
	var bit: bool = hero.ranged._hook_bit
	var foe: Node = hero.ranged._hook_foe
	var pull: Vector3 = hero.ranged._hook_pull
	var tether: HookshotTether = hero.ranged._tether

	# **The picture, and it is the SAME instant in both cases**: the barb at the
	# far end of its flight, from the hero's own shoulder, with the room in front
	# of it either holding an anchor or not. 0.80 and not 1.0 because the tether
	# is torn down on the frame the chain ARRIVES -- a shot that found nothing
	# calls `_end_hook()` on that tick (`HeroRanged._tick_hook`), so a shutter
	# waiting for full extension photographs an empty room in both cases.
	var caught := ""
	for _i in 300:
		if tether.is_extending() and tether.progress > 0.80:
			caught = "extending at %.2f" % tether.progress
			break
		if not hero.ranged._hook_active:
			break
		await rig.wait_frames(1)
	if caught != "":
		await rig.capture(out.path_join("b_%02d_riven_knight_press_%s.png"
			% [shot, "catches" if want_bite else "drops"]))
	_ck("%sd the shutter found the chain (%s)" % [tag, caught], caught != "")

	await _until(rig, func() -> bool: return not hero.ranged._hook_active, 400)
	await rig.wait_frames(8)
	Engine.time_scale = 1.0
	await rig.wait_frames(10)
	# **Where it put him**, and only for the shot that landed. §6.4's sentence is
	# "the item is both the way across and the way back", and the half of it that
	# is not in the flight is a hero standing on top of the thing he shot at with
	# the room he came from behind him.
	if want_bite:
		Bus.camera_recenter.emit()
		await rig.wait_frames(22)
		await rig.capture(out.path_join("b_%02d_riven_knight_crossed.png"
			% [shot + 1]))

	var went := K.plane(hero.global_position - from).length()
	var ended := K.plane(hero.global_position - here).length()
	print("BOSS %s press: bit=%s foe=%s pull=%.2v; hero %.2v -> %.2v (%.2f m, "
		% [tag, bit, "-" if foe == null else "A BODY", pull, from,
			hero.global_position, went]
		+ "%.2f m of the pivot, y=%.2f)" % [ended, hero.global_position.y])
	# A monster is the third outcome and it photographs like the first one.
	_ck("%se the chain did not bite the Knight" % tag, foe == null)
	if want_bite:
		var hook := _first_hook(arena)
		_ck("%sf the barb caught the keystone" % tag, bit and hook != null)
		_ck("%sg and it landed him on it, not beside it (%.2f m, y=%.2f)"
			% [tag, ended, hero.global_position.y],
			ended < 1.2 and hero.global_position.y > 1.6)
		if hook != null:
			print("BOSS %s aimed at the doc's %.2f m; the anchor is built at %.2f m"
				% [tag, at.y - here.y, hook.anchor_point().y - here.y])
	else:
		_ck("%sf the barb found nothing and dropped" % tag, not bit)
		_ck("%sg and he is standing exactly where he pressed (%.2f m)"
			% [tag, went], went < 0.35)
	# Put the trigger down whatever happened -- a held `heavy` carried into the
	# Bellwake's section would raise a brace in the middle of somebody else's
	# frame.
	Input.action_release(&"heavy")
	await rig.wait_frames(4)


## Hold the boss in the guard it has been standing in for four hundred years.
##
## `State.IDLE` is what `is_awake()` reads as asleep and what `Boss._tick_idle`
## answers with a `_stop()` and a looping idle clip -- so this is a body that is
## in the room, lit, on the health bar, and not moving. Nothing wakes it again:
## `wake()` is `BossArena.seal()`'s call and the room is already sealed.
##
## Re-applied before every press because a `_bleed` in between puts it back into
## a hurt state and out the far side into `CHASE`.
func _hold_still(boss: Node, look_at: Vector3) -> void:
	var at: Vector3 = (boss as Node3D).global_position
	var to := K.flat(look_at - at)
	var yaw := (atan2(to.x, to.z) + PI) if to != Vector3.ZERO else PI
	boss.rotation.y = yaw
	boss._facing = yaw
	boss.state = Enemy.State.IDLE


## Point the hero's own camera at `at` by pushing the look stick, and say how many
## degrees of elevation it ended up off by.
##
## The stick and not a write to `_pitch`, because the pitch is the thing the
## player steers with and `HeroRanged._aim_from` converges the muzzle on whatever
## the CROSSHAIR is over -- so a camera aimed by hand is the only thing that makes
## this the player's press rather than the director's.
##
## MEASURED and not counted (`CLAUDE.md` §4). `stick_speed_deg`, the sensitivity
## slider and `_fov_gain()` all multiply into one degree of look, so a fixed
## number of held frames is a fixed number of frames and not a fixed angle. This
## reads the camera's own forward back every iteration and stops when it is on
## the mark. In the aim stance the LOOK is exactly `_orbit_dir(_yaw, _pitch)`
## (`game_camera.gd`, `_place`) while the EYE is frozen at the rig's resting
## elevation, so the forward is the honest thing to read and `_pitch` is not.
func _aim_camera_at(rig, at: Vector3, tries: int) -> float:
	var cam := rig.scene().get_node_or_null(^"GameCamera") as Camera3D
	if cam == null:
		return 90.0
	var off := 0.0
	var was := 0.0
	for i in tries:
		var to := at - cam.global_position
		if to.length() < 0.5:
			break
		var want := asin(clampf(to.normalized().y, -1.0, 1.0))
		var have := asin(clampf((-cam.global_transform.basis.z).y, -1.0, 1.0))
		off = rad_to_deg(want - have)
		# **The tolerance is the STEP and not a preference.** `stick_speed_deg` is
		# 170 deg/s against a 60 Hz `_apply_look`, so the shortest hold this rig
		# can issue -- one rendered frame, which is about three physics ticks at
		# the harness's 22 fps -- is already five or six degrees of pitch. Asking
		# for two would hunt back and forth for ever. Five is well inside the cone
		# it is feeding: `HeroRanged._best_hookable` allows
		# `atan2(snap_radius, dist) + 6`, about 19 degrees at this range.
		if absf(off) < 5.0:
			break
		# Crossed it. One more push would only take it back the other way, and the
		# side of the mark it lands on does not matter at this tolerance.
		if i > 0 and signf(off) != signf(was):
			break
		was = off
		# `cam_up` LOWERS `_pitch` (`Input.get_vector(cam_left, cam_right, cam_up,
		# cam_down)` puts `cam_down` on +y and `_apply_look` adds it), and a lower
		# pitch is an eye that has come down off its arc and is looking further up.
		await rig.hold(["cam_up" if off > 0.0 else "cam_down"], 1)
	return off


func _first_hook(arena: Node) -> HookTarget:
	for c in _all(arena):
		if c is HookTarget:
			return c as HookTarget
	return null


# --- O. The adds are curved for the floor the boss is standing on ---------------

## **Board card 22, and the first director in this project to throw
## `SHAPE_SUMMON`.** The two summon beats in the game are the Bellwake's
## `hushing_choir` (2x `skeleton`, floor 3) and the Riven Knight's
## `call_the_iron` (2x `wraith`, floor 4), and until this section existed nothing
## anywhere had ever looked at what came out of one.
##
## What it is for. `docs/GDD.md` §7 is "difficulty comes from depth, not from
## you", and `Prog` is the one file allowed a curve. An add that arrives at
## `Prog.FIRST` is the single place in the game where that rule is quietly false
## -- and it is INVISIBLE. The body is the right body, the model is the right
## model, the tell is the right tell; it simply has floor-1 health and floor-1
## damage in it. Nothing on screen says so, which is why the numbers below are
## printed as well as asserted.
##
##   a-e  The arena stands the fight up, the room seals, the beat is thrown and
##        the bodies land. Photographed on the frame they land on.
##   f    **`level` is the BOSS's floor**, and `Run.level` is deliberately left at
##        1 for the whole of this section, so a body reading 3 or 4 here can only
##        have read it off the row.
##   g    **`health.max_health_points` is that band's number**, which is the claim that
##        actually matters: `level` is an input and the HP are what
##        the player fights. `Enemy._build_combat` latches it, so a `level`
##        written a line too late leaves this at the floor-1 value with a
##        perfectly correct `level` sitting beside it -- which is exactly what
##        this section found on its first run: `level=3 6q`, twice. **f passed and
##        g failed**, and that pair is the whole reason card #22 could sit in the
##        game unnoticed. A check that had read `level` would have been green.
##   h    And the two numbers differ, so g is capable of telling them apart. A
##        band whose floor-N health equalled its floor-1 health would make g pass
##        for ever without ever having been a test of anything.
##
## Calibrated both ways: `--sabotage=floor-1-adds` writes `Prog.FIRST` back over
## each add and O_2/O_3 go red while the rest of the section stays green.
const SUMMON_FIGHTS: Array[StringName] = [&"bellwake", &"riven_knight"]


func _summon_band(rig) -> void:
	# A clean slate for the same reason `_turns` takes one: section H killed the
	# Warden and the flags it wrote have nothing to do with these two fights.
	Game.reset()
	# **Left at floor 1 on purpose.** `_shape_summon` must read the boss's row and
	# never `Run`, so the run being on floor 1 while the adds come out at 3 and 4
	# is half of what this section proves.
	Run.level = 1
	await rig.wait_frames(8)
	var i := 0
	for id in SUMMON_FIGHTS:
		i += 1
		await _summon_of(rig, id, "O%d" % i, 60 + i - 1)
	await _choir_and_the_burst(rig)
	await _burst_bank(rig)


## One fight's summon, from the seal to the HP on the bodies.
func _summon_of(rig, id: StringName, tag: String, shot: int) -> void:
	var row := BossDb.get_boss(id)
	var beat_id := _summon_beat(id)
	_ck("%sa %s has a summon beat" % [tag, id], beat_id != &"")
	if beat_id == &"":
		return
	var b := BossDb.beat(id, beat_id)
	var kind: StringName = b["kind"]
	var deep := int(row.get("floor", 1))
	# The expected number, derived from `Enemy.DEFS` and `Prog` rather than typed
	# in: a literal here would be a second copy of the curve, and the first thing
	# a second copy does is stop agreeing with the first (`progression.gd`'s own
	# header makes this argument about the game and it is no less true of a check).
	var base := int((Enemy.DEFS[kind] as Dictionary)["health"])
	var want := maxi(int(roundf(float(base) * Prog.health_mult(deep))), 1)
	var shallow := maxi(int(roundf(float(base) * Prog.health_mult(Prog.FIRST))), 1)

	var arena := await _fresh_arena(rig, id, Vector3(0.0, 0.0, -5.0))
	var boss: Node = arena.boss()
	_ck("%sb the arena stood up %s" % [tag, id], boss != null)
	if boss == null:
		return
	await _stand_at(rig, Vector3(3.0, 0.05, 4.5), Vector3(0.0, 0.0, -5.0))
	await _until(rig, func() -> bool: return arena.is_sealed(), 240)
	_ck("%sc the room sealed and %s woke" % [tag, id],
		arena.is_sealed() and boss.is_awake())
	Game.heal(999)

	boss.force_beat(beat_id)
	await _mark_up(rig, arena, boss)
	var thrown := await _until(rig, func() -> bool:
		return boss.current_beat() == beat_id and boss.state == Enemy.State.WINDUP, 600)
	_ck("%sd it threw %s" % [tag, beat_id], thrown)
	if not thrown:
		return
	# **The MIDDLE of the arena, not `_park_boss`'s mark 3.5 m off it.** Every
	# other section parks the boss on the mark because it is photographing the
	# boss; this one is photographing an 8-9 m ring drawn around it, and off-centre
	# that ring reaches 11.5 m -- past an 11 m fence, so half of each summon landed
	# outside the room. The frames show it: two runs of "where did the other one
	# go". In a real fight the arena builds its boss at the centre and the ring
	# fits, so the off-centre mark was the director inventing a case the game does
	# not have.
	_park_centre(arena, boss, _hero(rig).global_position)
	# The lens goes up DURING the tell, so the shutter can open on the frame the
	# bodies are still standing where the ring put them. Ten frames later they are
	# already 0.6 m into a chase and the picture is of two monsters walking.
	_summon_eye(rig, arena, boss as Node3D)
	# The bodies exist from the frame of the commit, which is the far end of the
	# tell -- 2.00 s on the Bellwake, the longest in the game.
	var want_n := int(b["count"])
	var landed := await _until(rig,
		func() -> bool: return boss._summons.size() >= want_n, 400)
	_ck("%se %d body/bodies walked in" % [tag, boss._summons.size()], landed)
	if not landed:
		return
	# **Not on the frame `_until` returned on.** The bodies are appended during a
	# physics tick and the shutter would hand back the frame rendered before it:
	# the first version of this shot is the boss alone in an empty ring, which
	# looks exactly like a summon that did not happen. Four frames is under a fifth
	# of a second -- half a metre of chase, and they are still on their ring.
	await rig.wait_frames(4)
	await rig.capture(out.path_join("b_%02d_%s_summon.png" % [shot, id]))
	_game_eye(rig)

	if _sabotage == "floor-1-adds":
		# The bug as filed, reproduced from the outside: `Boss._shape_summon` wrote
		# `e.level` AFTER `Enemy.spawn` had already run `_ready`, so the curve never
		# saw it. Writing `Prog.FIRST` here puts the same numbers on the same
		# bodies, one frame later.
		for n in boss._summons:
			(n as Enemy).level = Prog.FIRST
		await rig.wait_frames(2)

	var lines := PackedStringArray()
	var ok_level := true
	var ok_health := true
	var centre: Vector3 = (arena as Node3D).global_position
	for n in boss._summons:
		var e := n as Enemy
		# The distance from the middle is printed because the first two runs of
		# this section photographed an empty ring and the numbers are what said
		# why: bodies placed past the fence. It is a reading about the FIXTURE and
		# not a claim about the game, which is why it prints rather than asserts.
		lines.append("level=%d %dq at %.1f m" % [e.level, e.health.max_health_points,
			K.plane(e.global_position - centre).length()])
		ok_level = ok_level and e.level == deep
		ok_health = ok_health and e.health.max_health_points == want
	print("BOSS %s %s/%s summons %d %s: floor %d wants %d HP, floor 1 would be %d HP -- got %s"
		% [tag, id, beat_id, boss._summons.size(), kind, deep, want, shallow,
			", ".join(lines)])
	_ck("%sf every add is levelled for floor %d, with Run.level still %d"
		% [tag, deep, Run.level], ok_level)
	_ck("%sg and carries the band's health: %d HP, not floor 1's %d"
		% [tag, want, shallow], ok_health)
	# The null guard on the check above. See the header.
	_ck("%sh the two bands are different numbers (%d vs %d)" % [tag, want, shallow],
		want != shallow)


## The lens for one summon: the whole ring the adds are placed on, in one frame.
##
## **It is a WIDE lens and not a distant one, and it took two wrong frames to
## learn why.** `hushing_choir` rings its adds at 8 m and `call_the_iron` at 9,
## so the thing to photograph is 16-18 m across in a chamber whose fence is 11 m
## from the middle -- there is nowhere in the room far enough back to see it at a
## normal focal length, and the arithmetic says so: you would need about two and
## a half ring-radii of stand-off. Both earlier attempts failed in ways worth
## keeping written down:
##
##   * `_eye`'s overview (section L's, from just inside the fence) put ONE add in
##     frame out of two -- the near half of the ring falls below the bottom edge.
##     A picture of half a summon is worse than none: it reads as a beat that
##     half-worked.
##   * Backing off to `radius * 2.2` -- 17.6 m behind an 11 m arena -- put the
##     camera INSIDE the chamber wall. The frame is black except for the HUD, and
##     nothing in the run says so; every check above it still passed. `_ck` cannot
##     see the shutter, which is the whole reason CLAUDE.md §2 asks for eyes.
##
## So: the height and the stand-off `_eye` already proved are inside the room, and
## a 95 degree lens instead of a 62 degree one. The far edges bow a little. That
## is the correct trade for a frame whose only job is to show two bodies where the
## ring put them.
func _summon_eye(rig, arena: Node, boss: Node3D) -> void:
	var cam := rig.scene().get_node_or_null(^"SummonEye") as Camera3D
	if cam == null:
		cam = Camera3D.new()
		cam.name = "SummonEye"
		cam.fov = 95.0
		rig.scene().add_child(cam)
	# Placed off the ARENA and not off the boss, which is what keeps it indoors:
	# the arena knows where its fence is and the boss does not.
	cam.global_position = (arena as Node3D).global_position \
		+ Vector3(0.0, 6.4, minf(arena.radius() * 0.92, 11.4))
	cam.look_at(boss.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
	cam.current = true


## The one summon beat in a fight's list, or `&""`.
##
## Looked up rather than tabled beside `SUMMON_FIGHTS`: a fifth boss, or a second
## summon on one of these two, should widen this section rather than slip past it.
func _summon_beat(id: StringName) -> StringName:
	for b in BossDb.beats(id):
		if b["shape"] == BossDb.SHAPE_SUMMON:
			return b["id"]
	return &""


# --- O3, O4. The Burst against the choir it is supposed to clear -----------------

## **Board card 73**, and the first time anything in this project has pointed a
## Burst at a chorister.
##
## `docs/BOSSES.md` §9 carried one surviving Bellwake line -- *"One blast clears
## both choristers"* -- and §6.3 built the fight on it: a 6.00 s strip window
## *"in which the player has to spend the free hits AND clear two bodies, and
## only one thing in the kit does both"*.
##
## **The KILL reading is settled on paper and O3a re-derives it here** rather
## than repeating the card's arithmetic: `K.BOMB_DAMAGE` is 2 HP against a
## floor-3 skeleton's 9, so "one blast" is five, twice, out of a stock of twelve.
## Nothing had to be run to know that; it is asserted anyway because a sentence
## nobody re-checks is how the old "one blast" survived card #22 rewriting the
## number under it.
##
## **What paper could NOT settle is the DISPLACEMENT reading** -- "clears" as
## "shoves them off you". `Enemy._on_damaged` rolls `_try_launch` on every blow
## and a launched body is out of the fight far longer than HURT's 0.22 s floor,
## so the whole question is whether a Burst launches a skeleton. The blow's
## `weight` is `(K.BURST_KNOCKBACK - K.KNOCKBACK_LIGHT) / (K.KNOCKBACK_HEAVY -
## K.KNOCKBACK_LIGHT)` = exactly **0.5**, mid-scale, which is precisely where
## `docs/BESTIARY.md` §3.5's mass rule decides rather than saturating -- and a
## mass rule read off constants is the class of claim CLAUDE.md §4 has caught
## this project getting wrong three times. So it is measured.
##
##   O3  **The real pair, in the real arena, on the real beat.** They are watched
##       converging on a hero who stands still, one real `BurstCast` is put on
##       the floor between them the moment one blast can reach both, and each is
##       clocked from the blast to the frame it is *walking at him again* and
##       again to the frame it is *back inside its own reach of him*. Those are
##       two different numbers and the second is the one the design cares about:
##       a body thrown 1.8 m has to walk back.
##   O4  **The same blast against a bank of twelve**, because the launch is a
##       ROLL and one body is a coin flip with a screenshot attached -- the same
##       objection this file's header makes to waiting for `pick_beat` to come
##       up. Twelve seeds, one blast each, and the launch RATE is reported
##       against the odds `_try_launch`'s formula says it should be.
##
## Calibrated in BOTH directions, because the verdict is a two-sided one -- the
## Burst is a real shove and it is not the strip window, and a check for either
## half alone passes for the wrong reason on a blast that does nothing.
## `--sabotage=burst-no-relief` cancels the relief (O3g, O4d go red) and
## `--sabotage=burst-endless` holds the bodies for the whole watch (O3h, O4c go
## red). Neither state is one the game can reach; that is what makes them
## calibrations rather than tests.

## O4's bank: twelve bodies on a 4x3 grid, `BANK_SPACING` apart. The spacing is
## comfortably past `2 * K.BOMB_RADIUS` (3.88 m) so no body is ever inside two
## blasts, and 15 x 10 m fits the fixture's 26 m floor with room on every side.
const BANK_COLS := 4
const BANK_ROWS := 3
const BANK_SPACING := 5.0

## Longest a clocked body is watched, in GAME seconds. Deliberately longer than
## the whole 6.00 s strip window: a disable that DID buy the window has to be
## measured rather than clipped at the edge of the watch, or the reading would
## be an artefact of how long this director was willing to look.
const CLOCK_WATCH := 8.0

## **What one blast would have had to buy, in seconds, for §6.3's old sentence to
## be true.** Not a preference and not a round number -- it is the window
## arithmetic §6.3 already worked, run to its end:
##
##   the punish opens 1.52 s after the commit and the 6.00 s strip window runs
##   from there; the choristers walk 6.3 m at 2.2 m/s and are on the hero at
##   2.86 s, which is 1.34 s into it. **6.00 - 1.34 = 4.66 s of window left when
##   the blast goes off**, and "spend the rest of it on the boss instead of on
##   two skeletons" was a claim about all of it.
##
## Held at 4.0 rather than 4.66 so the bar is not an arithmetic tightrope: a
## blast that bought four of the remaining four and two-thirds seconds would have
## been an answer, and this must not turn on a rounding.
##
## **It is now a CEILING and not a floor**, because the measurement came back
## 1.03-1.27 s and §6.3 was rewritten around that (card #73). O3h and O4c assert
## the Burst does NOT buy the window, which is the doc-and-code contract stated
## as a check: the day somebody raises `K.BOMB_DAMAGE` or bolts a `stun_time`
## onto `burst_cast.gd`'s one call site, §6.3 becomes wrong and these say so.
const RELIEF_NEEDED := 4.0

## **And the floor, which is the half that stops the ceiling passing for the
## wrong reason.** A blast that did nothing at all would satisfy "not the window"
## perfectly. The Burst IS a real shove -- one charge for about a second and a
## quarter, §6.3's panic button -- and this is the smallest version of that
## claim: every body it catches is off the hero for at least this long.
##
## 0.20 and not the measured 1.03: `Enemy._on_damaged` floors HURT at 0.22 s and
## everything above that is the launch roll and where the crowd happened to be
## standing, so a floor set near the measurement would be a check that fails on
## variance rather than on a defect.
const RELIEF_FLOOR := 0.20

## The near-left corner of O4's grid. Chosen so the whole 15 x 10 m block sits on
## the fixture's 26 m floor with two metres of masonry to spare on every side,
## and so the nearest blast is 2.9 m from the hero's mark at `(0, 3.5)` --
## outside `K.BOMB_RADIUS`, because `K.BOMB_HURTS_OWNER` is true and a hero
## taking twelve blasts at once would end the run in the middle of a measurement.
const BANK_AT := Vector3(-7.5, 0.05, -8.0)


## O3. The pair the beat actually summons, and one blast into it.
func _choir_and_the_burst(rig) -> void:
	var b := BossDb.beat(&"bellwake", &"hushing_choir")
	var kind: StringName = b["kind"]
	var deep := int(BossDb.get_boss(&"bellwake").get("floor", 1))
	var base := int((Enemy.DEFS[kind] as Dictionary)["health"])
	var chorister_hp := maxi(int(roundf(float(base) * Prog.health_mult(deep))), 1)
	var blasts := int(ceilf(float(chorister_hp) / float(K.BOMB_DAMAGE)))

	# The kill reading, re-derived from the two tables rather than restated. Both
	# halves are printed because a bare pass/fail here would hide the number that
	# moved under §9 in the first place.
	print("BOSS O3 the kill reading: a %s chorister is %d HP on floor %d, "
		% [kind, chorister_hp, deep]
		+ "K.BOMB_DAMAGE is %d, so one body is %d blasts and the pair is %d "
		% [K.BOMB_DAMAGE, blasts, blasts * 2]
		+ "of a stock of %d" % K.BURST_CHARGES_MAX)
	_ck("O3a one blast does NOT kill a chorister (%d HP of %d)"
		% [K.BOMB_DAMAGE, chorister_hp], K.BOMB_DAMAGE < chorister_hp)

	var arena := await _fresh_arena(rig, &"bellwake", Vector3(0.0, 0.0, -5.0))
	var boss: Node = arena.boss()
	_ck("O3b the arena stood the Bellwake up", boss != null)
	if boss == null:
		return
	await _stand_at(rig, Vector3(3.0, 0.05, 4.5), Vector3(0.0, 0.0, -5.0))
	await _until(rig, func() -> bool: return arena.is_sealed(), 240)
	Game.heal(999)

	boss.force_beat(&"hushing_choir")
	await _mark_up(rig, arena, boss)
	var telling := func() -> bool: return boss.current_beat() == &"hushing_choir" \
		and boss.state == Enemy.State.WINDUP
	var thrown := await _until(rig, telling, 600)
	_ck("O3c it threw hushing_choir", thrown)
	if not thrown:
		return
	_park_centre(arena, boss, _hero(rig).global_position)
	var landed := await _until(rig,
		func() -> bool: return boss._summons.size() >= 2, 400)
	_ck("O3d two choristers walked in", landed)
	if not landed:
		return

	# **The boss is stood down for the rest of O3, and that is a fixture decision
	# with a reason.** `first_toll` is a 7.5 m ring for 5 HP on a hero with
	# 12, and this section leaves him standing still for the better part of ten
	# seconds while two skeletons walk at him; a fight that killed him mid-beat
	# would change the scene out from under the run. It costs nothing that is
	# under test -- `Boss._victims()` returns the player group only, so the boss's
	# beats never touch a chorister and the thing being clocked cannot notice.
	_hold_still(boss, _hero(rig).global_position)

	var hero := _hero(rig)
	var pair: Array[Enemy] = []
	for n in boss._summons:
		pair.append(n as Enemy)

	# They arrive on an 8 m ring around the boss, which is 16 m apart -- so the
	# first thing to measure is not the blast, it is whether one blast can ever
	# reach both. `CROWD_RADIUS` is 1.5 m, so the answer is expected to be yes
	# once they are both on the hero, but "expected" is what this section exists
	# to stop being an argument.
	#
	# **Waited on BOTH BEING ON HIM and not on the gap itself, and the difference
	# is 3.86 m against 1.9.** The first cut of this waited for the pair to close
	# to `2 * K.BOMB_RADIUS` and fired the moment the trailing one crossed it,
	# with the leader already on the hero and the other still walking -- so the
	# reading was "one blast reaches both, by 2 cm", which reads as a knife-edge
	# and is really a stopwatch started early. §6.3's sentence is about casting it
	# "into the pair as they CLOSE", which is this moment and not that one.
	var reach := float((Enemy.DEFS[kind] as Dictionary)["reach"])
	var on_him := func() -> bool:
		for e in pair:
			if not is_instance_valid(e):
				return false
			if K.plane(e.global_position - hero.global_position).length() \
					> reach + 0.6:
				return false
		return true
	var closed := await _until(rig, on_him, 900)
	var gap := _pair_gap(pair)
	# The CHECK is the gap and not `closed`: if they never both arrived, the gap
	# is still the honest answer to "can one blast reach both" and the run should
	# say what it measured rather than time out into a different question.
	_ck("O3e one blast can reach both: on the hero they stand %.2f m apart, "
		% gap + "inside the %.2f m a blast spans (both arrived: %s)"
		% [K.BOMB_RADIUS * 2.0, closed], gap <= K.BOMB_RADIUS * 2.0)
	await rig.capture(out.path_join("b_62_bellwake_choir_closed.png"))
	if gap > K.BOMB_RADIUS * 2.0:
		return

	var mid := (pair[0].global_position + pair[1].global_position) * 0.5
	# The hero is not exempt (`K.BOMB_HURTS_OWNER`, and `burst_cast.gd` has no
	# owner check) -- so how far he is from the only point that reaches both is
	# part of the answer and not a footnote.
	var hero_in := K.plane(hero.global_position - mid).length() <= K.BOMB_RADIUS
	print("BOSS O3 the blast that reaches both is %.2f m from the hero, who is "
		% K.plane(hero.global_position - mid).length()
		+ "%s it (K.BOMB_HURTS_OWNER)" % ("INSIDE" if hero_in else "outside"))

	var rows := await _blast_and_clock(rig, [mid], pair, hero, reach)
	# **The pair AFTER the clock has run out, not on the frame of the blast**, and
	# that is the picture the design turns on: a second and a half later both
	# choristers are upright and back on the hero and the only thing on screen
	# that changed is the hero's own health bar, two HP down.
	await rig.capture(out.path_join("b_63_bellwake_choir_one_blast_later.png"))

	var caught := 0
	var relief := INF
	var longest := 0.0
	for r in rows:
		print("BOSS O3 chorister seed=%d: %s, %d HP lost, walking again after "
			% [r["seed"], "LAUNCHED" if r["launched"] else "staggered",
				r["lost"]]
			+ "%.2f s, thrown %.2f m, back inside its reach of the hero after "
			% [r["t_move"], r["out"]]
			+ "%.2f s, free to swing after %.2f s" % [r["t_back"], r["t_swing"]])
		if int(r["lost"]) == K.BOMB_DAMAGE:
			caught += 1
		relief = minf(relief, float(r["t_back"]))
		longest = maxf(longest, float(r["t_back"]))
	_ck("O3f the one blast caught both (%d of 2, %d HP each)"
		% [caught, K.BOMB_DAMAGE], caught == 2)
	# **The two checks card 73 exists to settle, and they run in opposite
	# directions on purpose.** `t_back` and not `t_move`: the question is how
	# long the pair is OFF him, and a body thrown two metres has to walk back --
	# relief the stagger timer alone does not show.
	_ck("O3g the blast is a real shove: both are off him for at least %.2f s "
		% RELIEF_FLOOR + "(the shorter of the two: %.2f s)" % relief,
		relief >= RELIEF_FLOOR)
	_ck("O3h and it is a shove and NOT the strip window (%.2f s of the %.2f s "
		% [longest, RELIEF_NEEDED] + "§6.3 would have needed)",
		longest < RELIEF_NEEDED)


## O4. The launch is a roll, so it is sampled rather than argued about.
func _burst_bank(rig) -> void:
	var b := BossDb.beat(&"bellwake", &"hushing_choir")
	var kind: StringName = b["kind"]
	var deep := int(BossDb.get_boss(&"bellwake").get("floor", 1))
	# The room is cleared first, arena before bodies, in `_fresh_arena`'s order
	# and for its reason: the choristers are parented to the SCENE and outlive
	# the arena that summoned them, so freeing the arena alone leaves O3's pair
	# standing in the middle of O4's grid.
	for n in (rig.scene() as Node).get_children():
		if n.name.begins_with("Arena") or n.name.begins_with("Turn"):
			n.queue_free()
	await rig.wait_frames(4)
	for n in rig.get_nodes_in_group(&"enemy"):
		(n as Node).queue_free()
	await rig.wait_frames(8)

	var bank: Array[Enemy] = []
	var at: Array[Vector3] = []
	var root := rig.scene() as Node3D
	for gr in BANK_ROWS:
		for gc in BANK_COLS:
			var p := BANK_AT + Vector3(float(gc) * BANK_SPACING, 0.0,
				float(gr) * BANK_SPACING)
			# The seed is explicit and consecutive, which is what makes this a
			# measurement somebody else can repeat rather than a number off one
			# run: `Enemy._ready` puts `drop_seed` straight into `_rng`, and the
			# launch roll is `_rng.randf()`. Seed 0 means "randomise", so the
			# bank starts at 1.
			bank.append(Enemy.spawn(root, kind, p, 1 + bank.size(), deep))
			at.append(p)
	await rig.wait_physics_frames(6)
	_ck("O4a a bank of %d floor-%d choristers is standing" % [bank.size(), deep],
		bank.size() == BANK_COLS * BANK_ROWS)

	# **No hero, so no `t_back`.** The bank stands where it was put and nothing
	# walks at anybody: what O4 is sampling is the ROLL and the dwell it buys,
	# and "how long until it is back on you" is a question about the arena
	# geometry O3 measured rather than about the blast.
	var rows := await _blast_and_clock(rig, at, bank, null,
		float((Enemy.DEFS[kind] as Dictionary)["reach"]))

	var launched := 0
	var caught := 0
	var moved := PackedFloat32Array()
	# How far a blast actually MOVES a body, which is the other half of "shoves
	# them off you" and the half a dwell in seconds cannot show: a stagger that
	# leaves the body where it stood is not a shove however long it lasts.
	var shoved := PackedFloat32Array()
	var flew := PackedFloat32Array()
	for r in rows:
		if int(r["lost"]) == K.BOMB_DAMAGE:
			caught += 1
		if bool(r["launched"]):
			launched += 1
			flew.append(float(r["out"]))
		else:
			shoved.append(float(r["out"]))
		moved.append(float(r["t_move"]))
	_ck("O4b every body in the bank took the blast (%d of %d)"
		% [caught, rows.size()], caught == rows.size())

	# What `_try_launch` says it should be, spelled out so the measured rate has
	# something to disagree with. `_mass_ratio` is `K.LAUNCH_MASS_REF / height`,
	# and a skeleton is 1.70 m against a reference of 1.70 -- exactly 1.0, which
	# is why this body and not another is the one the mid-scale weight is
	# interesting on.
	var weight := Enemy.blow_weight(K.BURST_KNOCKBACK)
	var mass := K.LAUNCH_MASS_REF / float((Enemy.DEFS[kind] as Dictionary)["height"])
	var odds := clampf(K.LAUNCH_CHANCE * pow(mass, 2.0) * weight,
		K.LAUNCH_CHANCE_MIN, K.LAUNCH_CHANCE_MAX)
	moved.sort()
	var lo: float = moved[0] if moved.size() > 0 else -1.0
	var hi: float = moved[moved.size() - 1] if moved.size() > 0 else -1.0
	var mid: float = moved[moved.size() / 2] if moved.size() > 0 else -1.0
	print("BOSS O4 %d of %d launched (%.0f%%), against the %.0f%% the formula "
		% [launched, rows.size(), 100.0 * float(launched) / float(maxi(rows.size(), 1)),
			100.0 * odds]
		+ "gives for weight %.2f at mass ratio %.2f. Walking again after "
		% [weight, mass]
		+ "%.2f / %.2f / %.2f s (min / median / max), " % [lo, mid, hi]
		+ "shoved %s m staggered and %s m launched."
		% [_metres(shoved), _metres(flew)])
	# **The launch was the only thing that could have rescued the displacement
	# reading, and this is where that was settled.** If the LUCKIEST roll in a
	# dozen does not hold a body still for the window, no roll of the dice makes
	# the old sentence true -- the question is closed rather than left to
	# variance, which is why a bank and not one body. The floor beside it is what
	# stops "not the window" passing for a blast that did nothing.
	_ck("O4c even the luckiest of %d rolls is a %.2f s dwell, not the %.2f s "
		% [rows.size(), hi, RELIEF_NEEDED] + "§6.3 would have needed",
		hi < RELIEF_NEEDED)
	_ck("O4d and the unluckiest is still a stagger (%.2f s, floor %.2f)"
		% [lo, RELIEF_FLOOR], lo >= RELIEF_FLOOR)

	for e in bank:
		if is_instance_valid(e):
			e.queue_free()
	await rig.wait_frames(4)


## A run of distances as `lo-hi`, or `n/a` for an empty one -- which is the
## honest answer when no body in the bank rolled a launch, and reads better than
## a min and a max of the same nothing.
func _metres(v: PackedFloat32Array) -> String:
	if v.is_empty():
		return "n/a"
	var lo := INF
	var hi := 0.0
	for d in v:
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return "%.2f-%.2f" % [lo, hi]


## Metres between the two choristers, or `INF` if one of them is gone.
func _pair_gap(pair: Array[Enemy]) -> float:
	if pair.size() < 2 or not is_instance_valid(pair[0]) \
			or not is_instance_valid(pair[1]):
		return INF
	return K.plane(pair[0].global_position - pair[1].global_position).length()


## Put one real `BurstCast` at each of `where`, and clock every body in `bodies`
## from the blast until it is chasing again.
##
## **A real `BurstCast` and not a hand-made `Hit`.** What is under test is the
## blow the working actually delivers, and `burst_cast.gd:245` is the only place
## that decides what that is -- a director that assembled its own `Hit.make` would
## be a second copy of the one line card 73 is about, and it would still pass the
## day somebody changed the real one.
##
## **The fuse is cut short and the arc is not flown.** `K.BOMB_FUSE` is 3.5 s
## from the cast, in which a chasing skeleton walks 7.7 m -- so a director that
## let the fuse run would be measuring where the bodies went, not what the blast
## did to them. The arc is already proved, frame by frame, in
## `tools/directors/burst_cast.gd` §C; nothing below touches `_blast` or
## `_hurt_what_is_in_reach`, which are the only two functions this section has an
## opinion about.
func _blast_and_clock(rig, where: Array, bodies: Array[Enemy], hero: Node3D,
		reach: float) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var from: Array[Vector3] = []
	for e in bodies:
		rows.append({
			"seed": e.drop_seed, "q0": e.health.health_points, "lost": 0,
			"launched": false, "t_move": -1.0, "t_back": -1.0, "t_swing": -1.0,
			"out": 0.0,
		})
		from.append(e.global_position)

	var motes: Array = []
	for p in where:
		var at: Vector3 = p
		var mote := BurstCast.cast_from(rig.scene(), at + Vector3(0.0, 0.9, 0.0),
			Vector3.DOWN)
		if mote != null:
			# Set AFTER `cast_from`, because `_ready` runs inside its `add_child`
			# and assigns `K.BOMB_FUSE` over anything written before it.
			mote.set(&"_fuse", 0.12)
			motes.append(mote)
	# Bound to a name rather than written inline: a multi-line lambda cannot be
	# followed by another argument in the same call.
	var all_spent := func() -> bool:
		for m in motes:
			if not is_instance_valid(m) or not bool(m.get(&"_spent")):
				return false
		return true
	var went := await _until(rig, all_spent, 240)
	if not went:
		print("BOSS FAIL the working never went off")
		_fails += 1
		return rows

	# **GAME seconds, not wall clock and not frames.** `Feel.hitstop` sets
	# `Engine.time_scale = 0` for several frames after every blow and the blast
	# asks for `K.HITSTOP_HEAVY` itself, so a wall clock would charge the stagger
	# for the freeze. `get_physics_process_delta_time()` carries the scale, which
	# is the same delta `Enemy._timer` and `_cooldown` count down in -- and a
	# frame count would be a measurement of this harness's ~22 fps rather than of
	# the 60 Hz step the fight runs on (§G makes the same argument).
	var clock := rig.scene() as Node
	var t := 0.0
	while t < CLOCK_WATCH:
		await rig.wait_physics_frames(1)
		t += clock.get_physics_process_delta_time()
		var pending := false
		for i in bodies.size():
			var e := bodies[i]
			var r: Dictionary = rows[i]
			if not is_instance_valid(e):
				continue
			r["lost"] = int(r["q0"]) - e.health.health_points
			if e.state == Enemy.State.LAUNCHED:
				r["launched"] = true
			if _sabotage == "burst-endless":
				# The other direction: a blast that DOES buy the window. Nothing
				# in the game can do this -- that is the point. O3h and O4c are
				# the only two checks that may notice, and a ceiling nobody has
				# ever pushed against is a ceiling that is not there.
				e.state = Enemy.State.HURT
				e._timer = maxf(e._timer, CLOCK_WATCH)
			if _sabotage == "burst-no-relief":
				# The blast buying nothing, reproduced from the outside: the body
				# is handed straight back to CHASE with its stagger cancelled,
				# which is what a knockback with no launch and no stun in it
				# amounts to one tick later.
				e.state = Enemy.State.CHASE
				e._timer = 0.0
				e._cooldown = 0.0
				e._knockback = Vector3.ZERO
			var held := e.state == Enemy.State.HURT \
				or e.state == Enemy.State.LAUNCHED
			if float(r["t_move"]) < 0.0:
				if held:
					pending = true
				else:
					r["t_move"] = t
					r["out"] = K.plane(e.global_position - from[i]).length()
			if float(r["t_swing"]) < 0.0:
				if e._cooldown > 0.0:
					pending = true
				else:
					r["t_swing"] = t
			# **"Back on him" is BOTH conditions, and the first cut of this had
			# only the second.** A launched chorister is in the air 1.7 m from
			# the hero and cannot touch him, and a reach test alone reported that
			# as `0.00 s of relief` -- the worst number in the table, for the body
			# the blast did the most to. It is back on him when it is acting
			# again AND standing within its own reach of him.
			if hero != null and float(r["t_back"]) < 0.0:
				if held or K.plane(e.global_position
						- hero.global_position).length() > reach:
					pending = true
				else:
					r["t_back"] = t
		if not pending:
			break
	# A body that never came back inside reach in the whole watch is reported as
	# the watch length and not as -1, because the number is read as "seconds of
	# relief" and a sentinel would silently be the best result in the table.
	for r in rows:
		for key in ["t_move", "t_back", "t_swing"]:
			if float(r[key]) < 0.0:
				r[key] = t
	return rows
