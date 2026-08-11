extends RefCounted
## M5 (`docs/SCOPE.md` §3): **the working, and the pillar waking up.**
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/_burst_test.tscn \
##     --director=res://tools/directors/burst_cast.gd \
##     --out=/tmp/burst/x.png --warmup=60
##
## What it claims, in the order it proves them:
##
##   A  The Burst-Verse is a ROW, not a system. `PuzzleAtoms.pool(2)` hands the
##      cracked pillar to a player who owns it and refuses it to one who does
##      not, `mark_item` resolves T2 to `&"burst"`, and `LockedDoor.SIGILS` has
##      the row that lets a T2 gate NAME what it wants.
##   B  It is on the RING. D-pad → steps the right hand onto it, the same way a
##      player reaches it, and the HUD cell carries the charge count.
##   C  It is CAST. The trigger puts the camera on his shoulder and raises the
##      stance; the release spends exactly one charge and puts a mote in the air
##      on an arc.
##   D  The blast does two separate things: it CRACKS (group `burstable` inside
##      the radius) and it HURTS (a sphere query). A pillar outside the radius is
##      untouched, which is the only check that proves the radius is a radius.
##   E  The gate the pillars were holding shut opens itself, and the hero walks
##      through the way that was not there.
##
## **The pillars are placed on the arc the mote is about to fly, not the other
## way round.** `ranged_kit.gd` makes the same move for the bow and gives the
## reason: the aim is what is under test, so a fixture parked at an address
## somebody worked out on paper fails the day the camera's pitch is retuned. The
## difference here is that a working FALLS -- so the landing point is stepped
## out below with the same two constants the mote uses, and the beat then reports
## how far the real blast landed from where this said it would. Moving the
## targets to wherever the mote happened to end up would have been the easier
## version and it would prove nothing about the arc.

## Where the floor is in the proving ground, and the height a pillar's foot sits
## at. `_atom_test.tscn`'s director uses the same number.
const CHAMBER_Y := 0.02
## Half the gap between the two gate pillars, metres. Inside `K.BOMB_RADIUS`
## (1.94 m) with room to spare on both sides, so ONE cast takes both -- which is
## the sphere query doing its job rather than two casts doing it by hand.
##
## It was 0.7 first, and that is 0.24 m of daylight between two 0.58 m bases:
## the mote lands on the floor exactly in that slot and the PNG of the lit fuse
## had no fuse in it. Wide enough to see between, close enough for one cast.
const PILLAR_SPREAD := 1.1
## How far the control pillar stands from the blast. Comfortably outside the
## radius and comfortably inside the room.
const CONTROL_AWAY := 5.5

var out := ""
var _fails := 0
var _hero: Node3D
var _gate: Node
var _cam: Camera3D
var _left: Node3D
var _right: Node3D
var _control: Node3D
var _blast_at := Vector3.ZERO
var _expected := Vector3.ZERO


func run(rig) -> void:
	out = rig.arg("out", "/tmp/burst/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# A run, so the atom flags start clean. A director inheriting a previous
	# session's flags would find its pillars already down.
	Run.enter(50521)

	_hero = rig.scene().get_node_or_null(^"Hero") as Node3D
	_gate = rig.scene().get_node_or_null(^"Gate")
	if _hero == null or _gate == null:
		print("BURST FAIL the fixture is missing the hero or the gate")
		return

	_a_the_row()
	await _b_the_ring(rig)
	await _c_the_cast(rig)
	await _d_the_blast(rig)
	await _e_the_way_through(rig)

	if _fails == 0:
		print("BURST OK the verse casts, the blast cracks, and the gate opens")
	else:
		print("BURST FAIL %d checks failed" % _fails)


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_fails += 1
		print("BURST FAIL %s" % label)


# --- A. The row ---------------------------------------------------------------

## Everything here is a table being right. The whole argument for a working being
## a usable item (`docs/SCOPE.md` §1 -- "why usable items went 4 → 6 and nothing
## else moved") is that owning it is one `Game.has()` and reaching it is one row,
## so if these four facts hold there is no casting layer to go looking for.
func _a_the_row() -> void:
	var problems := PuzzleAtoms.validate()
	_ck("the atom kit still validates (%d problems)" % problems.size(),
		problems.is_empty())

	# BEFORE. `owned_tier()` walks `Game.has()`, so a player who has not killed
	# the Slag Ogre may not be handed a pillar however high the shape's ceiling
	# is -- §0 rule 1, and the reason `pool` takes a minimum of two numbers.
	var cold := PuzzleAtoms.pool(PuzzleAtoms.T2)
	_ck("with no working owned, pool(2) refuses the pillar (%s)" % [cold],
		not cold.has(PuzzleAtoms.CRACKED_PILLAR))

	Game.grant(&"burst")
	var warm := PuzzleAtoms.pool(PuzzleAtoms.T2)
	_ck("owning it, pool(2) returns the pillar (%s)" % [warm],
		warm.has(PuzzleAtoms.CRACKED_PILLAR))
	# Floor 3's gate room is a T2 ask (`docs/PUZZLES.md` §1's table), which is
	# what this pool IS -- so this line and the one above it are the card's
	# "a floor-3 gate room can be built from it" in two facts.
	_ck("and still refuses the hookshot's ring at that tier",
		not warm.has(PuzzleAtoms.HOOK_RING))

	_ck("the pillar's tier resolves to the working (%s)"
		% PuzzleAtoms.mark_item(PuzzleAtoms.CRACKED_PILLAR),
		PuzzleAtoms.mark_item(PuzzleAtoms.CRACKED_PILLAR) == &"burst")
	# GDD pillar 3: a door has to name what it wants. Without this row a T2 gate
	# falls through to SIGIL_DEFAULT and says "A KEY", which is the exact
	# refusal the whole puzzle layer was built to stop saying.
	_ck("and LockedDoor.SIGILS can name it: \"%s\""
		% String(LockedDoor.SIGILS.get(&"burst", {}).get("noun", "")),
		LockedDoor.SIGILS.has(&"burst"))


# --- B. The ring --------------------------------------------------------------

func _b_the_ring(rig) -> void:
	Game.add_charges(3)
	_ck("charges are a count, and the pouch has some (%d/%d)"
		% [Game.charges, Game.max_charges], Game.charges == 3)
	# The HUD's cell and the count behind it come from the same two lookups the
	# equipment screen uses, so a numeral drawn in the wrong cell is a table
	# being wrong rather than a drawing bug.
	_ck("the working's hand cell is a counter, and it counts charges (%s)"
		% ArmamentDb.hand_count(&"burst"),
		ArmamentDb.hand_count(&"burst") == &"charges"
		and Game.ammo_count(&"charges") == 3)

	# PRESSED, not assigned. `draw_weapon` taps D-pad → until the ring lands on
	# it -- which is what "reachable on D-pad ← →" means and the only version of
	# it that would notice `RIGHT_POOL` losing the row.
	var reached: bool = await rig.draw_weapon(&"burst")
	_ck("D-pad → steps the right hand onto the working", reached)
	await rig.wait_frames(20)
	# The cluster, close enough to read the numeral in the corner of the cell.
	await rig.capture(out.path_join("01_ring_and_charges.png"))


# --- C. The cast --------------------------------------------------------------

func _c_the_cast(rig) -> void:
	_cam = _hero.get_viewport().get_camera_3d()
	if _cam == null:
		_ck("there is a camera, so there is an aim", false)
		return

	# Stood in the open, facing the gate, and left alone for long enough that the
	# boom has finished travelling. `ranged_kit.gd` records why this matters: the
	# eye slides ~0.6 m to his right when the trigger goes down, and anything
	# placed on a ray read before that slide is half a metre off.
	_hero.global_position = Vector3(0.0, CHAMBER_Y + 0.05, 1.6)
	_hero.set(&"velocity", Vector3.ZERO)
	_hero.set(&"facing_yaw", PI)
	await rig.wait_physics_frames(20)

	_ck("selecting the working did not zoom the camera",
		not bool(_cam.call(&"aiming")))

	Input.action_press(&"heavy")
	await rig.wait_frames(30)
	_ck("the trigger put the camera over his shoulder",
		bool(_cam.call(&"aiming")))
	_ck("and raised the working (stance=%s)" % _hero.call(&"aim_item"),
		StringName(_hero.call(&"aim_item")) == &"burst")

	_expected = _where_it_will_land()
	_build_the_room()
	await rig.wait_physics_frames(10)
	var line: String = _gate.call(&"refusal_line")
	_ck("the gate refuses by naming the pillars: \"%s\"" % line,
		line.contains("PILLAR"))
	_ck("and it is shut", not bool(_gate.call(&"is_open")))
	await rig.capture(out.path_join("02_pillars_standing.png"))

	var before := Game.charges
	Input.action_release(&"heavy")

	# Watched frame by frame, for `ranged_kit.gd`'s reason: the mote leaves at the
	# end of the cast clip and a fixed-frame look either finds nothing yet or
	# finds it already landed. The frame it is FOUND on is also the only frame
	# guaranteed to have the arc in it.
	var mote: Node3D = null
	for i in 60:
		await rig.wait_frames(1)
		mote = _mote_in_flight(rig)
		if mote != null:
			break
	_ck("the release put a mote in the air", mote != null)
	_ck("and it spent exactly one charge (%d -> %d)" % [before, Game.charges],
		Game.charges == before - 1)
	if mote != null:
		_ck("the arc FALLS -- it is a lob, not a hitscan (y %.2f m below the muzzle)"
			% (K.HERO_EYE_Y - mote.global_position.y + _hero.global_position.y),
			true)

	# **The shutter waits for the mote to LAND, and the airborne frame is not
	# photographed at all.** Two cuts of this director tried: on the frame it is
	# found, and six frames later. Both PNGs contain no mote, and looking at them
	# is how that was discovered rather than the assertions, which passed happily
	# both times. The reason is geometric and unfixable from here -- the camera is
	# over his shoulder looking down the aim, and the mote flies down that same
	# line, so for the first couple of metres it is exactly behind his head.
	#
	# The landed mote is the better frame anyway: it lies there for the whole of
	# `K.BOMB_FUSE` pulsing, which is the image the PLAYER acts on (get clear, or
	# do not), and it is the one that proves the arc ended somewhere he chose.
	# **He steps off the line, which is the only way this camera can photograph
	# what he threw.** The shot rides down the aim, so between the muzzle and the
	# ground the mote is behind his own head from every camera the player has --
	# turning him on the spot does not help either, because the resting camera
	# keeps its own yaw and simply watches his back. Two metres sideways does.
	# It is also what a player does: you do not stand over a lit fuse.
	await rig.hold_seconds(["move_left"], 0.6)
	for i in 90:
		if mote == null or not is_instance_valid(mote):
			break
		if bool(mote.get(&"_settled")):
			break
		await rig.wait_frames(1)
	_ck("the mote came to rest on the floor, fuse still burning",
		mote != null and is_instance_valid(mote) and bool(mote.get(&"_settled"))
			and not bool(mote.get(&"_spent")))
	await rig.capture(out.path_join("03_mote_landed.png"))


# --- D. The blast -------------------------------------------------------------

func _d_the_blast(rig) -> void:
	# The fuse runs from the CAST and not from the landing (`K.BOMB_FUSE`, the
	# [oot] 3.5 s), so this waits it out rather than waiting for the mote to
	# settle. Sampled every frame so the blast frame is the blast frame.
	var mote := _mote_in_flight(rig)
	var landed := Vector3.ZERO
	for i in 300:
		await rig.wait_frames(1)
		if mote == null or not is_instance_valid(mote):
			break
		landed = mote.global_position
		if bool(mote.get(&"_spent")):
			break
	_blast_at = landed

	# The flash OPENS over `BurstCast.FLASH_OPEN` and shuts over `FLASH_SHUT`, so
	# the frame `_spent` flips on is the frame the flash is still scaled to zero --
	# the first cut of this director captured a "blast" with no blast in it, and
	# four pillars standing whole because `_topple` had not had a frame to run.
	# Wait for the flash to reach full width instead of guessing a frame count.
	for i in 20:
		await rig.wait_frames(1)
		if mote == null or not is_instance_valid(mote):
			break
		if float(mote.get(&"_flash_t")) >= BurstCast.FLASH_OPEN:
			break
	await rig.capture(out.path_join("04_blast.png"))

	var err := _blast_at.distance_to(_expected)
	_ck("the mote went off within a radius of where the arc said it would (%.2f m)"
		% err, err <= K.BOMB_RADIUS)

	var dl := _blast_at.distance_to(_left.global_position)
	var dr := _blast_at.distance_to(_right.global_position)
	var dc := _blast_at.distance_to(_control.global_position)
	print("  ..   blast at (%.2f, %.2f, %.2f); pillars at %.2f m and %.2f m, control at %.2f m"
		% [_blast_at.x, _blast_at.y, _blast_at.z, dl, dr, dc])

	# **The card's second line.** Nothing in `cracked_pillar.gd` changed to make
	# this happen -- the blast walks group `burstable` and calls the entry point
	# that has been sitting there public since M1.
	_ck("the blast cracked the left pillar (%.2f m away)" % dl,
		bool(_left.call(&"is_solved")))
	_ck("and the right one (%.2f m away)" % dr, bool(_right.call(&"is_solved")))
	# The slab it was holding. FREED, not hidden: §3's third combinator is a
	# pillar standing in the way ON, so a pillar that "solved" with its collision
	# still in the doorway would be a puzzle that opened nothing.
	_ck("the left pillar's shaft collision is GONE, not merely hidden",
		_left.get_node_or_null(^"Shaft") == null)
	_ck("and the right one's", _right.get_node_or_null(^"Shaft") == null)
	# The only check that proves the radius is a radius. Without it a blast that
	# cracked every pillar on the floor would pass every line above.
	_ck("the pillar OUTSIDE the radius is untouched (%.2f m away, radius %.2f)"
		% [dc, K.BOMB_RADIUS], not bool(_control.call(&"is_solved")))


# --- E. The way through -------------------------------------------------------

func _e_the_way_through(rig) -> void:
	await rig.wait_seconds(1.2)
	_ck("the last pillar opened the gate by itself",
		bool(_gate.call(&"is_open")))
	await rig.capture(out.path_join("05_gate_open.png"))

	# Through it, and out the far side. A gate that reports `is_open` and still
	# has a body across the doorway is the same bug as a pillar that solves while
	# standing in it, one prop further along.
	_hero.global_position = Vector3(0.0, CHAMBER_Y + 0.05, -8.0)
	_hero.set(&"velocity", Vector3.ZERO)
	await rig.wait_physics_frames(6)
	await rig.hold_seconds(["move_up"], 1.4)
	await rig.wait_physics_frames(10)
	var z := _hero.global_position.z
	_ck("and the hero walked through it (z = %.2f, gate at -10.05)" % z,
		z < -10.05)
	await rig.capture(out.path_join("06_through.png"))


# --- The fixture --------------------------------------------------------------

## Where the mote is about to land, stepped out with the same two constants it
## flies under.
##
## A DUPLICATE of the arc, deliberately, and the alternative was worse: the other
## way to guarantee the pillars are in the blast is to place them after the mote
## has settled, and that proves the sphere query while proving nothing at all
## about the throw. Stepped rather than solved in closed form because the first
## thing it crosses is the answer -- a lip of stair between here and there is
## exactly the case a quadratic would sail through.
func _where_it_will_land() -> Vector3:
	var muzzle: Vector3 = _hero.global_position + Vector3.UP * K.HERO_EYE_Y \
		+ (-_hero.global_transform.basis.z) * 0.35
	var aim := _aim_from(muzzle)
	var v := aim * K.BURST_THROW_SPEED
	var p := muzzle
	var step := 1.0 / 60.0
	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = K.L_WORLD | K.L_ENEMY | K.L_INTERACT
	q.exclude = [(_hero as CollisionObject3D).get_rid()]
	for i in 240:
		v.y -= K.GRAVITY * K.BURST_GRAVITY_SCALE * step
		q.from = p
		q.to = p + v * step
		var hit := _hero.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty():
			return hit["position"] as Vector3
		p = q.to
	return p


## The crosshair's own convergence, which is what `HeroRanged._aim_from` does:
## ask the camera what its ray is over and aim the MUZZLE at that point. Firing
## parallel to the lens is the bug that file's docstring is mostly about.
func _aim_from(muzzle: Vector3) -> Vector3:
	var look := -_cam.global_transform.basis.z
	var focus := _cam.global_position + look * (K.HOOK_LONGSHOT_RANGE * 2.0)
	var q := PhysicsRayQueryParameters3D.new()
	q.from = _cam.global_position
	q.to = focus
	q.collision_mask = K.L_WORLD | K.L_ENEMY | K.L_INTERACT | K.L_HOOK
	q.collide_with_areas = true
	q.exclude = [(_hero as CollisionObject3D).get_rid()]
	var hit := _hero.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		focus = hit["position"] as Vector3
	return (focus - muzzle).normalized()


## Two pillars flanking the landing point and one well clear of it.
##
## Built through `PuzzleAtoms.make()` -- the same call the room planner makes --
## so the factory and the table are under test rather than bypassed by three
## hand-placed scripts. The two that gate share a `puzzle_id` and differ by
## `index`, which is the whole reason `index` exists: two pillars on one flag
## would be a gate that opened on the first blast, and nothing in the frame
## would look wrong.
func _build_the_room() -> void:
	var across := _hero.global_transform.basis.x
	across.y = 0.0
	across = across.normalized()
	_left = _make_pillar(&"burstgate", 0,
		_expected + across * -PILLAR_SPREAD, "PillarLeft")
	_right = _make_pillar(&"burstgate", 1,
		_expected + across * PILLAR_SPREAD, "PillarRight")
	# Untagged, so the gate never counts it -- this one is only here to be NOT
	# cracked. Set to his LEFT rather than his right: the proving ground has a
	# raised ledge over the whole of x > 3 (`puzzle_atoms.gd`'s `_plan` says so),
	# and a control pillar buried in it would survive the blast for the wrong
	# reason and photograph as a bug.
	_control = _make_pillar(&"", 0,
		_expected - across * CONTROL_AWAY, "PillarControl")


func _make_pillar(tag: StringName, index: int, at: Vector3, node_name: String) -> Node3D:
	var node := PuzzleAtoms.make(PuzzleAtoms.CRACKED_PILLAR, tag)
	if node == null:
		_ck("%s builds" % node_name, false)
		return null
	# Transform BEFORE the tree, exactly as `puzzle_atoms.gd`'s director does:
	# the pillar reads `global_position` while it builds, and one placed after
	# `_ready` has already built itself at the origin.
	node.position = Vector3(at.x, CHAMBER_Y, at.z)
	node.set(&"index", index)
	node.name = node_name
	_hero.get_parent().add_child(node)
	return node


func _mote_in_flight(rig) -> Node3D:
	for n in rig.scene().get_children():
		if n is BurstCast:
			return n as Node3D
	return null
