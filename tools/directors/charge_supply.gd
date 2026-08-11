extends RefCounted
## Card #29 / `docs/ITEMS.md` §8 D13 — **the floor supplies the Burst.**
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/charge_supply.gd \
##     --out=/tmp/charge_supply/x.png --warmup=60
##
## `docs/PUZZLES.md` §0 rule 2: *every puzzle room is solvable from a cold start
## with an empty pouch, because the urns beside it hold exactly what it needs.*
## Floor 2's shortcut is a cracked pillar, the only answer to a cracked pillar is
## a Burst, and until this card charges had **one** source in the whole game — a
## counter upstairs, before you left (the alchemist's then; the quartermaster's
## stores since card #98). A player who descended with none met a door with no
## legal way through and no way to earn one.
##
## So the claim is not "a burst opens the pillar" — `shortcut_puzzle.gd` beat G
## proves that, and it proves it while handing itself three charges out of thin
## air (`Game.add_charges(3)`, line ~421). **The claim is that the pouch starts at
## zero and the floor fills it**, and a director that granted itself a charge
## anywhere would pass identically against the version this fixes.
##
## What it claims, in the order it proves them:
##
##   A  Floor 2's brace prefab places a `ShortcutCache` — an `Urn` whose `holds`
##      is `&"charges"` — and it stands OUTSIDE `K.BOMB_RADIUS` of the pillar, so
##      the cast that needs its contents cannot destroy them.
##   B  Cold start. The pouch is at zero, the working is in the right hand, and
##      the door refuses by naming the pillar.
##   C  **The sword breaks the urn**, from a real swing at real reach, and a
##      `ChargeCache` falls out. The pouch is still at zero: it is a pickup, not
##      a grant.
##   D  Walking over it fills the pouch through `Game.add_charges` — the one seam
##      the counter that sells them uses too (`SupplyDb.buy`) — and the HUD's cell
##      counts it.
##   E  One real cast, and the brace falls. Exactly one charge is spent, so the
##      cache's two were one more than the door asked for, which is the point:
##      one charge and one missed arc is the dead end again.
##   F  Die and come back and the urn is whole. Atom flags are per-run
##      (`PuzzleAtom.clear_run_flags`), so run two is not locked out by run one
##      having smashed the pot.
##
## ## Why the frames are worth looking at even when every check passes
##
## The cache is a new prop and `CLAUDE.md` §3 has two rows waiting for it: an
## emissive over a near-black floor is an opaque slab at every opacity, and a
## light hung at an object's own height eats the object. `arrow_bundle.gd` paid
## for both of those in two passes. Beat C's PNG is the only thing that can say
## whether three 9 cm glyphs in an iron dish read as *supply* at the distance a
## player actually sees them from, or as a smear of orange on the floor. They did
## not, at first: at 7.5 cm and a 1.5-radius spread the three merged into two
## blobs, and `GLYPH_R` / `GLYPH_SPREAD` are what that frame changed.

## Forced, and it is `shortcut_puzzle.gd`'s seed on purpose: two directors
## disagreeing about which layout floor 2 has is two floors to reason about.
const SEED := 20260809

## Where the hero is put to read a door — `shortcut_puzzle.gd`'s constant, same
## reason. Out along the door's own +basis.z, inside `LockedDoor`'s 2.9 m
## interact radius.
const READ_AT := 2.5

## Where the cast is thrown from, out along the same axis. See `_e_the_brace_falls`
## — the aim comes off the camera, and from inside the door's interact radius the
## pillar is closer to the lens than the crosshair is.
const CAST_FROM := 6.0

## How close the hero stands to swing at the urn. The blade is an `Area3D` and
## `HeroCombat._maybe_hit` gates on a 130-degree arc, so this is "within a
## sword's length, facing it" and nothing cleverer.
const SWING_AT := 1.15

var out := ""
var _fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/charge_supply/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Said out loud, because getting it wrong does not look like getting it
	# wrong — this director ADDS a `Dungeon` to whatever it was pointed at.
	if rig.scene().name != &"DungeonRun":
		print("SUPPLY FAIL wrong host scene (%s) -- pass "
			% rig.scene().name + "--scene=res://scenes/rooms/dungeon.tscn")
		return

	var hero: Node3D = _hero(rig)
	if hero == null:
		print("SUPPLY FAIL there is no hero in the scene")
		return
	var cam := _game_camera(rig)
	if cam != null:
		cam.make_current()

	# **The cold start, and it is the whole card.** `reset` zeroes `charges`
	# (`game_state.gd:~267`); the only thing granted below is the ITEM, never its
	# ammunition. If a line anywhere in this file calls `add_charges`, the
	# director has stopped proving anything.
	Game.reset()
	Run.enter(SEED)
	Game.grant(&"burst")
	await rig.wait_frames(20)

	var d := await _rebuild(rig, 2)
	if d == null:
		print("SUPPLY FAIL floor 2 did not build")
		return
	_clear_the_floor(d)

	var room: Node3D = d.rooms[d.entrance]["node"]
	var door: Node3D = d.anchor_node(&"shortcut_door")
	var pillar: Node3D = room.get_node_or_null(^"ShortcutPillar")
	var pot: Node3D = room.get_node_or_null(^"ShortcutCache")
	if door == null or pillar == null:
		print("SUPPLY FAIL floor 2 has no braced shortcut to answer")
		return

	_a_the_floor_supplies_it(pillar, pot)
	await _b_the_cold_start(rig, hero, door)
	if pot == null:
		print("SUPPLY FAIL -- there is nothing on the floor to pick up")
		return
	var cache := await _c_the_sword_breaks_it(rig, hero, pot)
	if cache != null:
		await _d_the_pouch_fills(rig, hero, cache)
	await _e_the_brace_falls(rig, hero, door)
	await _f_the_urn_comes_back(rig)

	if _fails == 0:
		print("SUPPLY ok -- every check passed")
	else:
		print("SUPPLY FAIL -- %d check(s) failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("SUPPLY ok %s" % label)
	else:
		_fails += 1
		print("SUPPLY FAIL %s" % label)


# --- A. The floor supplies it --------------------------------------------------

func _a_the_floor_supplies_it(pillar: Node3D, pot: Node3D) -> void:
	_ck("A0 floor 2's brace places a cache beside it", pot != null)
	if pot == null:
		return
	_ck("A1 and the placer decided what is inside (holds=%s)"
		% pot.get(&"holds"), StringName(pot.get(&"holds")) == &"charges")
	# The check that is not obvious and would have been a real bug: the blast is
	# a 1.94 m sphere and an urn inside it is an urn destroyed by the very cast
	# that needed what was in it — a dead end with an extra step.
	var gap := pot.global_position.distance_to(pillar.global_position)
	print("SUPPLY cache stands %.2f m from the pillar (K.BOMB_RADIUS %.2f)"
		% [gap, K.BOMB_RADIUS])
	_ck("A2 and it stands clear of the blast (%.2f m > %.2f m)"
		% [gap, K.BOMB_RADIUS], gap > K.BOMB_RADIUS)


# --- B. The cold start ---------------------------------------------------------

func _b_the_cold_start(rig, hero: Node3D, door: Node3D) -> void:
	_ck("B0 the pouch is EMPTY (%d/%d)" % [Game.charges, Game.max_charges],
		Game.charges == 0)
	var reached: bool = await rig.draw_weapon(&"burst")
	_ck("B1 and the working is still in the right hand -- owning it is not the "
		+ "problem", reached)
	await _stand_at(rig, hero, door)
	await _focus(rig, door)
	var said: String = Hud._prompt
	print("SUPPLY floor 2 refusal = \"%s\"" % said)
	_ck("B2 the door refuses by naming the pillar (\"%s\")" % said,
		said.contains("PILLAR"))
	# The dead end, said by the game rather than by this file. `_read_burst`
	# refuses an empty pouch and plays `craft_fail`, so the trigger comes up
	# holding nothing -- which is exactly the state a player was stuck in before
	# this card, and the state beat E has to get him out of.
	Input.action_press(&"heavy")
	await rig.wait_frames(24)
	var raised := StringName(hero.call(&"aim_item"))
	Input.action_release(&"heavy")
	await rig.wait_frames(10)
	_ck("B3 and the trigger raises nothing on an empty pouch (stance=%s)"
		% raised, raised != &"burst")
	await rig.capture(out.path_join("c_01_cold_start.png"))


# --- C. The sword breaks it ----------------------------------------------------

## Swung, not `apply_hit`ed. `HeroCombat._damageable` records that `Urn` was
## "breakable by arrows only, under a comment claiming the opposite" for a whole
## release, because nothing had ever swung a blade at one — and a hero who has
## just arrived on floor 2 with an empty pouch has a sword and nothing else. If
## the pot cannot be opened with the one tool a cold start guarantees, rule 2 is
## still unmet and this beat is the only thing that would notice.
func _c_the_sword_breaks_it(rig, hero: Node3D, pot: Node3D) -> Node3D:
	# **Step the ring back to the sword first, the way a player would.**
	# `HeroCombat._tick_light_button` opens with *"An item owns both shoulder
	# buttons while it is drawn. There is no sword half to reach"* — so with the
	# working still in his right hand, `attack` is the working's trigger and the
	# swing this beat is about cannot happen at all. That is not a quirk of the
	# harness: it is the sequence the fix actually asks of a player, and it is
	# worth a director noticing that the cold-start answer needs the ring stepped
	# twice rather than a button pressed once.
	var sheathed: bool = await rig.draw_weapon(&"sword")
	_ck("C0 the ring steps back to the sword", sheathed)

	hero.velocity = Vector3.ZERO
	var away := K.flat(hero.global_position - pot.global_position)
	if away == Vector3.ZERO:
		away = Vector3.FORWARD
	hero.global_position = pot.global_position + away * SWING_AT \
		+ Vector3(0.0, 0.15, 0.0)
	_face(hero, pot)
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(6)
	await rig.wait_frames(20)
	print("SUPPLY hero %.2v faces %.2v, urn at %.2v, %.2f m apart"
		% [hero.global_position, -hero.global_transform.basis.z,
			pot.global_position, hero.global_position.distance_to(pot.global_position)])
	await rig.capture(out.path_join("c_02_urn_beside_the_brace.png"))

	await rig.tap([&"attack"])
	var broke: bool = await rig.until(func() -> bool:
		return bool(pot.call(&"is_solved")), 4.0)
	_ck("C1 one sword swing breaks the urn", broke)

	var cache := await _find_cache(rig, 4.0)
	_ck("C2 and a cache of charges falls out of it", cache != null)
	# The distinction the whole prop exists for. A grant would have already
	# happened by now; a pickup is a thing lying on the floor that the player has
	# to walk to, which is what makes the PLACEMENT mean anything.
	_ck("C3 and the pouch is still empty -- it is a pickup, not a grant (%d)"
		% Game.charges, Game.charges == 0)
	await rig.wait_frames(30)
	if cache != null:
		print("SUPPLY cache lies at %.2v (urn foot %.2v)"
			% [cache.global_position, pot.global_position])
		# A step back and a look AT it, because the wide shot of a room is not a
		# look at a 20 cm prop. `CLAUDE.md` §2 is the whole reason this exists:
		# the frame is the proof, and a frame in which the thing under test is
		# eleven pixels across proves that the checks ran.
		var back := K.flat(hero.global_position - cache.global_position)
		var stand := cache.global_position + back * 2.4
		stand.y = pot.global_position.y + 0.15
		hero.velocity = Vector3.ZERO
		hero.global_position = stand
		# **Aimed BESIDE the cache, not at it.** The chase camera sits on the line
		# behind the hero, so a hero looking straight at a 20 cm prop on the floor
		# is a hero standing exactly in front of it — the first pass of this frame
		# photographed the back of his head with the pickup behind it. Turning him
		# a metre and a half wide of it puts the cache off-centre and clear of his
		# silhouette while he is still visibly next to it.
		var side := Vector3(-back.z, 0.0, back.x)
		_face_at(hero, cache.global_position + side * 1.5)
		Bus.camera_recenter.emit()
		await rig.wait_physics_frames(6)
		await rig.wait_frames(40)
	await rig.capture(out.path_join("c_03_cache_on_the_floor.png"))
	return cache


# --- D. The pouch fills --------------------------------------------------------

func _d_the_pouch_fills(rig, hero: Node3D, cache: Node3D) -> void:
	# Walked onto with his own capsule against the real collision, because
	# `ChargeCache` is an `Area3D` polling `get_overlapping_bodies()` for group
	# `player` — teleporting on top of it would prove the overlap and not the
	# pickup, and a cache floating 40 cm inside the wall it spilled against
	# passes the teleport happily.
	var got: bool = await _walk_onto(rig, hero, cache)
	_ck("D0 walking over it fills the pouch (%d/%d)"
		% [Game.charges, Game.max_charges], got)
	_ck("D1 and the floor gave two, not one -- a missed arc is not a second dead "
		+ "end (%d)" % Game.charges, Game.charges == ChargeCache.HOLDS)
	# Through the same two lookups the HUD's cell and the equipment screen use,
	# so a numeral drawn in the wrong cell is a table being wrong rather than a
	# drawing bug (`burst_cast.gd` beat B asks it the same way).
	_ck("D2 and the working's hand cell counts them (%s = %d)"
		% [ArmamentDb.hand_count(&"burst"), Game.ammo_count(&"charges")],
		ArmamentDb.hand_count(&"burst") == &"charges"
		and Game.ammo_count(&"charges") == Game.charges)
	# The ring stepped onto the working BEFORE the frame, because the cell only
	# draws a numeral for the item in the hand: the first version of this capture
	# was taken with the sword still out and photographed a sword, which proved
	# the checks had run and nothing else.
	_ck("D3 and the ring steps onto the working with them in the pouch",
		await rig.draw_weapon(&"burst"))
	await rig.wait_frames(24)
	await rig.capture(out.path_join("c_04_pouch_filled.png"))


# --- E. The brace falls --------------------------------------------------------

func _e_the_brace_falls(rig, hero: Node3D, door: Node3D) -> void:
	if Game.charges <= 0:
		_ck("E0 there is a charge to spend", false)
		return
	# And the ring steps forward again, the other half of beat C's note.
	var drawn: bool = await rig.draw_weapon(&"burst")
	_ck("E0 the ring steps back onto the working", drawn)
	# **Further back than `READ_AT`, and that is a real finding rather than a
	# harness tweak.** `HeroRanged._aim_from` builds the cast direction from the
	# CAMERA's ray, and the aiming camera sits over the hero's shoulder — at the
	# 2.5 m the refusal is read from, the pillar fills the screen a metre from
	# his face and the crosshair is already past its right edge, so the mote sails
	# down the room and fuses out of radius. Stood at CAST_FROM the ray lands on
	# the pillar and the throw is the one a player makes. A shortcut brace is
	# something you back away from before you blow it up.
	await _stand_at(rig, hero, door, CAST_FROM)
	var before := Game.charges

	# **Pressed, not called.** `shortcut_puzzle.gd` beat G3 reaches straight for
	# `BurstCast.cast_from` because what it is proving is the pillar; what THIS
	# beat is proving is the pouch, and a director that bypassed `HeroRanged`
	# would never touch `spend_ammo` -- so "it cost one charge" would be a
	# sentence this file wrote rather than one the game did.
	#
	# The aim is the camera's, which is why he is stood square in front of the
	# door with the pillar between him and it: anything roughly forward lands on
	# the pillar or on the leaves 1.3 m behind it, and `K.BOMB_RADIUS` is 1.94 m.
	# That is slack on purpose. The pillar's exact position is the seed's, and a
	# beat that needed a 20 cm aim would be measuring the camera boom.
	Input.action_press(&"heavy")
	await rig.wait_frames(30)
	var raised := StringName(hero.call(&"aim_item"))
	_ck("E1 with charges in the pouch the trigger raises the working (stance=%s)"
		% raised, raised == &"burst")
	await rig.capture(out.path_join("c_05_about_to_cast.png"))
	Input.action_release(&"heavy")

	var fell: bool = await rig.until(func() -> bool:
		return bool(door.call(&"is_open")), 8.0)
	_ck("E2 the floor's own charge opens the shortcut", fell)
	_ck("E3 and the cast spent exactly one (%d -> %d)"
		% [before, Game.charges], before - Game.charges == 1)
	_ck("E4 leaving one in the pouch for the walk on (%d)" % Game.charges,
		Game.charges >= 1)
	await rig.wait_frames(50)
	await rig.capture(out.path_join("c_06_brace_open.png"))


# --- F. Run two -----------------------------------------------------------------

## The half of the fix that is invisible in a single run. `PuzzleAtom`'s flags are
## per-run and the door's is permanent (`shortcut_puzzle.gd` beat F) — so a player
## who smashed the pot, died, and came back must find a whole pot. If the urn's
## solved flag outlived the run the dead end would come back on run two, wearing a
## fix.
func _f_the_urn_comes_back(rig) -> void:
	Run.enter(SEED)
	var d := await _rebuild(rig, 2)
	if d == null:
		_ck("F0 floor 2 rebuilt", false)
		return
	_clear_the_floor(d)
	var pot: Node3D = d.rooms[d.entrance]["node"].get_node_or_null(^"ShortcutCache")
	_ck("F0 run two places the cache again", pot != null)
	if pot != null:
		_ck("F1 and the urn came back whole -- atom flags are per-run",
			not bool(pot.call(&"is_solved")))
	await rig.wait_frames(10)


# --- Plumbing -------------------------------------------------------------------

func _rebuild(rig, level: int) -> Node:
	Run.level = level
	var scene: Node = rig.scene()
	var old := scene.get_node_or_null(^"Dungeon")
	if old != null:
		old.name = "DungeonOld"
		old.queue_free()
		await rig.wait_frames(2)
	var script := load("res://scripts/world/dungeon.gd") as GDScript
	var d: Node = script.new()
	d.name = "Dungeon"
	d.seed_override = SEED
	scene.add_child(d)
	# Fourteen: `shortcut_puzzle.gd`'s settle, which is twelve for the floor plus
	# the frame `PuzzleGate._adopt` waits for on both sides.
	await rig.wait_frames(14)
	return d


## The spill lands in `get_tree().current_scene`, not under the urn — the urn is
## about to free its own children. So this looks at the whole scene, and it polls,
## because `_spill` runs inside `on_solved` and the drop tween starts a frame
## later.
func _find_cache(rig, seconds: float) -> Node3D:
	var waited := 0.0
	while waited < seconds:
		for n in _all(rig.scene()):
			if n is ChargeCache:
				return n as Node3D
		await rig.wait_frames(2)
		waited += 2.0 / 60.0
	return null


## Step the hero onto `cache` with `test_move` against the real collision, and
## report whether the pouch moved. `shortcut_puzzle.gd::_sweep`'s shape, shortened
## to one target and given an early out — the cache frees itself on pickup, so the
## loop has to stop looking at it the moment it is gone.
func _walk_onto(rig, hero: Node3D, cache: Node3D) -> bool:
	var before := Game.charges
	var target := cache.global_position
	for _i in 240:
		if not is_instance_valid(cache):
			break
		if Game.charges > before:
			break
		# `K.plane`, NOT `K.flat` — `flat` normalises, so an arrival test written
		# against it never fires (`cistern_floor.gd`'s fourth).
		var to := K.plane(target - hero.global_position)
		if to.length() > 0.25:
			var step := to.limit_length(0.25)
			hero.velocity = Vector3.ZERO
			if not hero.test_move(hero.global_transform, step):
				hero.global_position += step
			else:
				var side := Vector3(-step.z, 0.0, step.x).normalized() * 0.25
				if not hero.test_move(hero.global_transform, side):
					hero.global_position += side
				else:
					hero.global_position -= side
		await rig.wait_frames(2)
	return Game.charges > before


## Put the hero where a player reads this door from, and let the physics notice.
## `shortcut_puzzle.gd`'s, verbatim in intent: the settle is on the PHYSICS clock
## because `Interactable.player_inside` is set by an `Area3D`.
func _stand_at(rig, hero: Node3D, door: Node3D, back: float = READ_AT) -> void:
	hero.velocity = Vector3.ZERO
	hero.global_position = door.global_position \
		+ door.global_transform.basis.z * back + Vector3(0.0, 0.15, 0.0)
	_face(hero, door)
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(6)
	await rig.wait_frames(24)


func _face(hero: Node3D, at: Node3D) -> void:
	_face_at(hero, at.global_position)


## `rotation.y = heading + PI`, which is `docs/CONTRACT.md` §2.5 and `CLAUDE.md`
## §4: a Node3D's forward is `-basis.z`, so the body is turned half a circle past
## the heading to point down it.
func _face_at(hero: Node3D, at: Vector3) -> void:
	var to := K.flat(at - hero.global_position)
	if to == Vector3.ZERO:
		return
	hero.facing_yaw = atan2(to.x, to.z)
	hero.rotation.y = hero.facing_yaw + PI


## Wait for `prop` to own the interact button. Polled rather than awaited on a
## signal: `Prompt` hands focus to whatever is nearest and a bare wait breaks
## instantly on the wrong one.
func _focus(rig, prop: Node) -> bool:
	for _i in 90:
		if Prompt.focus == prop:
			return true
		await rig.wait_frames(2)
	return false


## Free every body on the floor. This beat is about a pot, a door and a pillar,
## and a goblin that walks into the shot is a measurement of the pack.
func _clear_the_floor(d: Node) -> void:
	var freed := 0
	for n in _all(d):
		if n is Enemy:
			freed += 1
			n.queue_free()
	if freed > 0:
		print("SUPPLY cleared %d bodies" % freed)


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _game_camera(rig) -> Camera3D:
	for n in _all(rig.scene()):
		if n is GameCamera:
			return n
	return null


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found
