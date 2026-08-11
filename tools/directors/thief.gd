extends RefCounted
## **The Thief** — `docs/BESTIARY.md` §3, behaviour 4. Films the four beats the
## behaviour is made of and measures the two that have no pixels.
##
##   1. **The reach.** Does the grab telegraph, and does it telegraph the RIGHT
##      way — forward, not back, so it cannot be confused with the swing it
##      replaces? And does it still telegraph at the bottom of the depth curve
##      (GDD §7's 60% floor)?
##   2. **The theft.** Does a bag slot actually leave `Run`, and is it visibly
##      in the goblin's hands afterwards?
##   3. **The flight.** Does it run for a DOOR — the nearest one, not merely away
##      from the hero — and can the player see which door from the frame?
##   4. **The two answers.** Kill it and the slot comes back off the floor; let
##      it go and it does not.
##
## The half of this that a log cannot check is beat 3's second question, which is
## why the frames matter: `thief_04_flight.png` has to show the goblin, the
## thing it is holding, and the mark on the door it is running for, all at once.
## If a player cannot read that picture the behaviour is a bag slot that vanished
## for no reason they can name — which is a bug however correct the arithmetic
## is.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/thief.gd --out=/tmp/thief/x.png \
##     --warmup=60

const DOORWAY := preload("res://scenes/kit/doorway.tscn")

## Where the fight happens, and it is a CAMERA decision before it is a staging
## one. The rig sits over the hero's shoulder looking down -Z, so a monster
## placed straight in front of him is a monster photographed through his coat —
## the first cut of this director put the thief on the hero's axis and every
## frame of the theft is the back of a cloak with a purple glow leaking round it.
## Offset laterally, the same trick `monster_feel._struck` uses and for the same
## reason.
const HERO_AT := Vector3(-3.0, 0.05, 7.5)
const THIEF_AT := Vector3(0.5, 0.05, 2.5)
## The near door is deliberately NOT behind the thief. If the only exit were
## straight away from the hero, "it ran for the door" and "it ran away" would be
## the same picture and the frame would prove nothing. It is also kept inside the
## lens: an escape the camera never sees is an escape this director cannot claim
## is readable.
## Measured from where the THEFT happens, which is beside the hero, and not from
## where the thief spawned. The first placement got that backwards and the
## goblin correctly picked the door this file had labelled "far" — the behaviour
## was right and the constant was a lie about the geometry.
const DOOR_NEAR := Vector3(6.0, 0.0, -3.0)
const DOOR_FAR := Vector3(-20.0, 0.0, 10.0)

## What goes in the bag before anything is stolen, in order. The first three fill
## the document case (`Run.CASE_SLOTS`), which is exactly what this beat needs:
## the thief must never be able to reach them.
const PACK: Array = [
	[&"bone_shard", 20], [&"rot_moss", 20], [&"cracked_flint", 20],
	[&"grave_wax", 15], [&"iron_scrap", 12], [&"void_pearl", 4],
	[&"ghost_silk", 12],
]

var _fails: int = 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/thief/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_manifest()
	await _telegraph(rig, out)
	await _theft_and_kill(rig, out)
	await _escape(rig, out)

	if _fails == 0:
		print("THIEF OK")


# --- Beat 0: the manifest ----------------------------------------------------
## `docs/SCOPE.md` §1 in one assertion. A behaviour is a KEY on a row; the day it
## becomes a tenth kind or a tenth model this beat is what says so.
func _manifest() -> void:
	print("THIEF kinds=%d" % Enemy.DEFS.size())
	if Enemy.DEFS.size() != 7:
		_fail("the roster grew to %d rows -- a behaviour is a key, not a kind"
			% Enemy.DEFS.size())
	var goblin: Dictionary = Enemy.DEFS[&"goblin"]
	if StringName(goblin.get("behaviour", &"")) != &"thief":
		_fail("the goblin row does not carry the thief behaviour")


# --- Beat 1: the reach -------------------------------------------------------
## The tell, photographed late in the commit and measured at both ends of the
## depth curve.
##
## Captured LATE on purpose: the lean is eased so most of it lands in the last
## third, and a frame from the start of the grab is a photograph of a goblin
## standing still (the same mistake `monster_feel`'s first pass made).
func _telegraph(rig, out: String) -> void:
	var scene: Node = rig.current_scene
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	hero.global_position = HERO_AT
	await rig.wait_frames(10)

	# **GDD §7's floor, checked rather than trusted.** A telegraph that compresses
	# to nothing at depth is the one failure that turns this behaviour from a
	# decision into a mugging, and it is invisible on floor 1.
	var shallow := K.THIEF_GRAB * Prog.windup_scale(Prog.FIRST)
	var deep := K.THIEF_GRAB * Prog.windup_scale(40)
	print("THIEF grab floor1=%.3f s deep=%.3f s (%.0f%% of base)"
		% [shallow, deep, 100.0 * deep / K.THIEF_GRAB])
	if deep < K.THIEF_GRAB * 0.6 - 0.0001:
		_fail("the grab compressed to %.0f%% at depth -- past GDD §7's 60%% floor"
			% (100.0 * deep / K.THIEF_GRAB))

	var foe := _spawn(scene, 1201)
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)
	await rig.capture(out.path_join("thief_00_closing.png"))

	# **The hold is packed to START the reach and emptied to END it**, which is
	# how this beat still gets a clean look at the TELL with no theft on top of
	# it. It used to just leave the bag empty, and that stopped working the day a
	# thief learned to check: a body only reaches when `Run.stealable()` says
	# there is something to reach for (`Enemy._tick_chase`), because reaching at
	# a player carrying nothing is what cost the goblin its swing. So the hold is
	# full at the moment of the commit and empty at the moment it closes -- which
	# is `_close_grab`'s "closed on an empty hold" branch exactly, and the same
	# two frames as before.
	_fill_bag()
	var watch := _watch()
	var reached: bool = await rig.until(func() -> bool:
		return foe.state == Enemy.State.GRAB, 8.0)
	if not reached:
		_fail("the goblin never reached for the bag in 8 s of game time"
			+ _why(watch, foe, hero))
		foe.queue_free()
		await rig.wait_frames(4)
		return
	Run.bag.clear()

	# Two thirds of the way through the commit, on the GAME clock rather than in
	# rendered frames: the lean is eased (`e = t*t`), so where in the telegraph a
	# frame lands decides what it shows, and a frame count means different amounts
	# of telegraph on a 60 Hz panel and a 120 Hz one.
	await rig.wait_seconds(K.THIEF_GRAB * 0.62)
	var lean: float = foe._model.rotation.x - foe._model_rest.x
	var lit := _emission(foe)
	print("THIEF telegraph lean=%+.1f deg glow=%.3f sack=%s"
		% [rad_to_deg(lean), lit, foe._sack != null])
	# **Forward, and that is the whole tell.** `_tick_windup` leans the other way
	# by `Enemy.WINDUP_LEAN_DEG`; if this ever goes negative the grab and the
	# swing are the same picture and the player is guessing.
	if lean <= 0.0:
		_fail("the grab leans %+.1f deg -- it is rearing BACK like a swing"
			% rad_to_deg(lean))
	if lit <= 0.01:
		_fail("no glow on the grab: the body's emission is %.3f" % lit)
	if foe._sack == null:
		_fail("no sack: the reach has nothing to put your loot in")
	await rig.capture(out.path_join("thief_01_reach.png"))

	# It closed on an empty hold. Nothing may be carried and nothing may be lit.
	var settled: bool = await rig.until(func() -> bool:
		return foe.state != Enemy.State.GRAB, 4.0)
	await rig.wait_frames(20)
	print("THIEF whiff state=%d carrying=%s sack=%s"
		% [foe.state, foe.carrying(), foe._sack != null])
	if not settled:
		_fail("the grab never closed")
	if not foe.carrying().is_empty():
		_fail("it stole from an empty bag: %s" % foe.carrying())
	if foe._sack != null:
		_fail("the empty sack outlived the grab -- a goblin carrying nothing")
	await rig.capture(out.path_join("thief_02_whiffed.png"))

	foe.queue_free()
	await rig.wait_frames(6)


# --- Beats 2 and 4: the theft, the chase and the recovery --------------------
func _theft_and_kill(rig, out: String) -> void:
	var scene: Node = rig.current_scene
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	_doors(scene)
	_fill_bag()
	hero.global_position = HERO_AT
	await rig.wait_frames(12)

	var packed: int = Run.case_slots_used()
	var cased: Dictionary = Run.case_contents()
	var before := Run.bag_value()
	print("THIEF bag %d gold, %d slots (%d cased): %s"
		% [before, Run.slots_used(), packed, Run.bag])

	var foe := _spawn(scene, 1301)
	Bus.camera_recenter.emit()
	await rig.wait_frames(20)
	await rig.capture(out.path_join("thief_03_before.png"))

	var watch := _watch()
	var robbed: bool = await rig.until(func() -> bool:
		return not foe.carrying().is_empty(), 12.0)
	if not robbed:
		_fail("it never took anything in 12 s of game time"
			+ _why(watch, foe, hero))
		return

	var loot: Dictionary = foe.carrying()
	var after := Run.bag_value()
	print("THIEF stole %s x%d -- bag %d -> %d gold, %d -> %d slots"
		% [String(loot["id"]), int(loot["count"]), before, after,
			packed + 6, Run.slots_used()])
	if after >= before:
		_fail("the bag is no poorer: %d -> %d gold" % [before, after])
	# **The richest slot it could reach, and never the case.** Both halves are
	# design (`Run.steal_slot`): the first is what makes chasing worth doing, the
	# second is the promise GDD §3.1 makes about what comes home.
	if StringName(loot["id"]) != &"void_pearl":
		_fail("it took %s -- the richest reachable slot was void_pearl"
			% String(loot["id"]))
	if Run.case_contents() != cased:
		_fail("the case was robbed: %s -> %s" % [cased, Run.case_contents()])

	# Is it holding it, and is the thing it is holding the right COLOUR? That is
	# the whole of "visible what it took" -- the sack is the same faceted prism
	# and the same tint the player has been picking off floors all run.
	var want: Color = ItemDb.get_def(StringName(loot["id"])).tint
	var got: Color = foe._sack_mat.albedo_color if foe._sack_mat != null else Color.BLACK
	print("THIEF sack tint=%s want=%s light=%s"
		% [got, want, foe._sack_light != null])
	if not got.is_equal_approx(want):
		_fail("the sack is %s, not the item's own %s" % [got, want])
	if foe._sack_light == null:
		_fail("the loot in its hands is unlit -- invisible in a dark room")

	# Where did it go? The NEAR door, which is neither the far one nor straight
	# away from the hero.
	var to_near := K.plane(foe._exit - DOOR_NEAR).length()
	var to_far := K.plane(foe._exit - DOOR_FAR).length()
	print("THIEF exit=%v near=%.2f far=%.2f ribbon=%s"
		% [foe._exit, to_near, to_far, foe._ribbon != null])
	if to_near > 1.0:
		_fail("it did not pick the nearest door: exit is %v, near door is %v"
			% [foe._exit, DOOR_NEAR])
	if foe._ribbon == null or not is_instance_valid(foe._ribbon):
		_fail("no mark on the door -- the player cannot see where it went")
	await rig.capture(out.path_join("thief_04_flight.png"))

	# Running, and facing the way it runs. `-basis.z` is forward by contract
	# (docs/CONTRACT.md §2.5) and a thief that flees backwards would be the
	# facing bug this project has now paid for three times (CLAUDE.md §4).
	#
	# **The window for this measurement has two walls and both of them cost a
	# run.** Ask too early and the answer is -1.00: the grab left it facing the
	# hero and `_face_heading` turns at 300 deg/s, so the first ~0.6 s of the
	# flight is a body pivoting, which is correct and photographs as a thief
	# running backwards. Ask too late and it is through the door and the state is
	# DEAD. 0.9 s is after the turn and well inside the ~2.4 s run.
	await rig.wait_seconds(0.9)
	var heading := K.flat(foe._exit - foe.global_position)
	var facing := -foe.global_transform.basis.z
	var dot := K.flat(facing).dot(heading)
	var gap := K.plane(foe.global_position - HERO_AT).length()
	print("THIEF fleeing state=%d facing.dot(exit)=%.2f gap to hero=%.1f m"
		% [foe.state, dot, gap])
	if foe.state != Enemy.State.FLEE:
		_fail("it is in state %d, not FLEE, while holding your loot" % foe.state)
	if dot < 0.6:
		_fail("it is running at the door facing %.2f away from it -- see"
			% dot + " CLAUDE.md §4, facing is measured and this one is wrong")
	await rig.capture(out.path_join("thief_05_running.png"))

	# **The fast answer** (`docs/BESTIARY.md` §3): kill it and it drops what it
	# took. Struck through a real DamageArea rather than by reaching into
	# HealthComponent, so the beat exercises the link a sword actually uses.
	# A Dictionary and not a bare `bool`, because a lambda captures a local by
	# VALUE: `died = true` inside the handler would rebind the closure's own copy
	# and this loop would spin until the thief was out of the door. Mutating a
	# shared container is the way a signal talks back to a director.
	var kill := {"done": false}
	foe.died_at.connect(func(_p: Vector3) -> void: kill["done"] = true)
	for i in 6:
		if bool(kill["done"]) or not is_instance_valid(foe):
			break
		# **The hero has to run it down**, which is the point of the behaviour and
		# also the only way this beat is possible: a thief flees at 4.5 m/s and a
		# director standing still gets six swings at empty air while its target
		# leaves through the door.
		hero.global_position = foe.global_position \
			+ K.flat(HERO_AT - foe.global_position) * 1.4
		hero.global_position.y = HERO_AT.y
		Bus.camera_recenter.emit()
		await _strike(rig, foe, 4)
	if not bool(kill["done"]):
		_fail("six blows did not kill a 5-quarter goblin")
		return
	await rig.wait_frames(10)
	await rig.capture(out.path_join("thief_06_killed.png"))

	var mote := _find_mote(rig, StringName(loot["id"]))
	if mote == null:
		_fail("it died holding %s and nothing hit the floor" % String(loot["id"]))
		return
	print("THIEF dropped %s x%d at %v"
		% [String(mote.item_id), mote.count, mote.global_position])
	if mote.count != int(loot["count"]):
		_fail("it dropped %d of %d -- the slot did not come back whole"
			% [mote.count, int(loot["count"])])

	# And the recovery: walk over it and the bag is whole again.
	hero.global_position = Vector3(mote.global_position.x, HERO_AT.y,
		mote.global_position.z)
	Bus.camera_recenter.emit()
	var back: bool = await rig.until(func() -> bool:
		return Run.bag_value() >= before, 4.0)
	# `>=` and not `==`: the corpse also rolled its ordinary drop
	# (`Enemy._drop_loot`), and the hero standing on the recovery is standing on
	# that too. The stolen slot coming back is the assertion; the goblin's own
	# loot arriving with it is the game working.
	print("THIEF recovered: bag %d -> %d gold (was %d before the theft)"
		% [after, Run.bag_value(), before])
	if not back:
		_fail("the drop did not go back in the bag: %d, was %d before the theft"
			% [Run.bag_value(), before])
	await rig.wait_frames(20)
	await rig.capture(out.path_join("thief_07_recovered.png"))


# --- The other answer: let it go ---------------------------------------------
## `docs/BESTIARY.md` §3's expensive answer, and the reason the whole behaviour
## is worth building: **the loss has to be real, or chasing is never a decision.**
func _escape(rig, out: String) -> void:
	var scene: Node = rig.current_scene
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	hero.global_position = HERO_AT
	await rig.wait_frames(10)

	var before := Run.bag_value()
	var foe := _spawn(scene, 1401)
	# See the note on `kill` above: a lambda captures locals by value, so the
	# handler has to MUTATE a shared container rather than rebind one.
	var gone := {"loot": {}}
	foe.escaped_with.connect(func(loot: Dictionary, _p: Vector3) -> void:
		gone["loot"] = loot)
	Bus.camera_recenter.emit()

	var watch := _watch()
	var robbed: bool = await rig.until(func() -> bool:
		return not foe.carrying().is_empty(), 12.0)
	if not robbed:
		_fail("the second thief never took anything" + _why(watch, foe, hero))
		return
	var loot: Dictionary = foe.carrying()
	await rig.wait_frames(30)
	await rig.capture(out.path_join("thief_08_getaway.png"))

	# Let it run. Nobody chases.
	var away: bool = await rig.until(func() -> bool:
		return not (gone["loot"] as Dictionary).is_empty(), 12.0)
	await rig.wait_frames(20)
	var after := Run.bag_value()
	print("THIEF got away with %s x%d -- bag %d -> %d gold, still gone"
		% [String(loot.get("id", &"?")), int(loot.get("count", 0)), before, after])
	if not away:
		_fail("it never made it out: still in the room at %v"
			% (foe.global_position if is_instance_valid(foe) else Vector3.ZERO))
	if after >= before:
		_fail("the bag recovered on its own: %d -> %d gold" % [before, after])
	# A body that got out frees itself; one still standing there had better not be
	# holding a cyan mark up over a door nobody is running to any more.
	if is_instance_valid(foe) and foe._ribbon != null and is_instance_valid(foe._ribbon):
		_fail("the mark on the door outlived the escape")
	await rig.capture(out.path_join("thief_09_gone.png"))


# --- Helpers ------------------------------------------------------------------

## Both clocks, stamped, so a wait that ends badly can say WHICH one ran out.
func _watch() -> Array:
	return [Time.get_ticks_msec(), Engine.get_physics_frames()]


## Why a wait on the goblin ended without the goblin doing the thing.
##
## **This exists because issue #33 was a FAIL nobody could act on.** "The goblin
## never reached for the bag in 8 s" names the symptom and nothing else, so the
## session that met it could not tell a goblin stuck on a keeper from a goblin
## that was walking normally while the director's stopwatch ran fast -- and those
## live in different files. Two runs went into the difference and neither settled
## it. So the line now carries every term the wait depended on: where the body
## got to, what it was doing, whether its own cooldown was refusing it, and both
## clocks side by side.
##
## The clocks are the pair that mattered. `rig.until` spends its budget in GAME
## seconds now (`shoot.gd`), and the ratio between the two is the thing that moves
## when the machine is busy: a report of `8.0 s game / 8.2 s wall` is a goblin that
## genuinely did not arrive, and `8.0 s game / 31 s wall` is a machine at 0.25x
## that the old wall-clock deadline would have cut off at a quarter of the wait.
func _why(watch: Array, foe: Enemy, hero: Node3D) -> String:
	if not is_instance_valid(foe):
		return " -- and the goblin is gone: it was freed while the beat waited"
	var reach: float = float(Enemy.DEFS[&"goblin"]["reach"])
	var step: float = 1.0 / float(Engine.physics_ticks_per_second)
	var game := float(Engine.get_physics_frames() - int(watch[1])) * step
	var wall := float(Time.get_ticks_msec() - int(watch[0])) / 1000.0
	return (" -- it is in state %d at %v, %.2f m from the hero (it grabs inside"
		+ " %.2f m), cooldown %.2f, carrying %s. The wait spent %.1f s of game"
		+ " time over %.1f s of wall clock (%.2fx); at 1.00x these are the same"
		+ " number and anything lower is the machine, not the goblin.") % [
		foe.state, foe.global_position,
		K.plane(foe.global_position - hero.global_position).length(), reach,
		foe._cooldown, foe.carrying(), game, wall,
		game / wall if wall > 0.0 else 0.0]


## **Asks for the behaviour rather than inheriting it**, and that is not
## boilerplate. `K.THIEF_SHARE` makes only a quarter of the goblins the dungeon
## scatters into thieves -- the row default used to be all of them, which is what
## took the goblin's swing away -- so a director that relied on the default would
## now be a coin flip and this file would fail three runs in four. Beat 0 still
## asserts the row carries the key; this asserts the BODY does.
func _spawn(scene: Node, seed_val: int) -> Enemy:
	var e := Enemy.new()
	e.kind = &"goblin"
	e.behaviour = &"thief"
	e.drop_seed = seed_val
	scene.add_child(e)
	e.global_position = THIEF_AT
	return e


## Two doorways, so "the nearest exit" is a choice this director can check rather
## than the only option. `KitDoorway` puts itself in the `exit` group.
func _doors(scene: Node) -> void:
	for at in [DOOR_NEAR, DOOR_FAR]:
		var d := DOORWAY.instantiate()
		d.span = 6.0
		d.height = K.CEIL_ROOM
		scene.add_child(d)
		d.global_position = at
		d.rotation.y = PI * 0.5 if at == DOOR_NEAR else 0.0


## Start a run and pack the bag. The first three lines land in the document case
## (`Run._place` fills it first), which is exactly the arrangement the theft has
## to be tested against.
func _fill_bag() -> void:
	Run.enter(90210)
	for row: Array in PACK:
		Run.collect(row[0], int(row[1]), 1.0)


func _find_mote(rig, id: StringName) -> LootMote:
	for node in rig.current_scene.find_children("*", "Area3D", true, false):
		var m := node as LootMote
		if m != null and m.item_id == id:
			return m
	return null


## Swing at `foe` the way the hero does: a DamageArea, activated for a window.
## Lifted from `monster_feel.gd` for the reason given there -- reaching past it
## into `HealthComponent.apply_hit` would prove the maths and skip the link.
##
## Two differences from that version, and both are the THIEF's doing. The box is
## a CHILD of the body rather than a fixed point in the world, because this
## target is running at 4.5 m/s and a box left where it was standing catches
## nothing -- `activate()` sweeps on a DEFERRED call, by which time a fleeing
## goblin has left. And the caller awaits, so consecutive blows are spaced past
## `K.ENEMY_IFRAME_TIME` instead of being eaten by the i-frames of the one before.
func _strike(rig, foe: Node3D, amount: int) -> void:
	var box := DamageArea.new()
	box.collision_layer = K.L_PLAYER_HITBOX
	box.collision_mask = K.L_ENEMY
	box.amount = amount
	box.kind = &"sword"
	box.knockback = K.KNOCKBACK_LIGHT
	box.stun = 0.2
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.6
	col.shape = sphere
	box.add_child(col)
	foe.add_child(box)
	box.position = Vector3(0.0, 0.7, 0.0)
	box.activate()
	# Physics ticks, not rendered frames: the overlap this depends on is resolved
	# by the physics server (`shoot.gd`'s own note on `until`).
	await rig.wait_physics_frames(3)
	box.deactivate()
	box.queue_free()
	await rig.wait_seconds(K.ENEMY_IFRAME_TIME + 0.06)


## The brightest emission on any surface of the BODY's model, ignoring the sack.
## Reads the surface overrides, because that is the only level `HitFlash` writes
## at -- see the same helper in `monster_feel.gd`.
func _emission(foe: Enemy) -> float:
	var peak := 0.0
	for node in foe._model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var whole := mi.material_override as BaseMaterial3D
		if whole != null and whole.emission_enabled:
			peak = maxf(peak, whole.emission_energy_multiplier)
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as BaseMaterial3D
			if m != null and m.emission_enabled:
				peak = maxf(peak, m.emission_energy_multiplier)
	return peak


func _fail(msg: String) -> void:
	_fails += 1
	print("THIEF FAIL %s" % msg)
