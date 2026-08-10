extends RefCounted
## **What the sword can actually touch.** Two claims, both about the path a real
## swing takes and neither about the thing being swung at.
##
##   A  A `Lantern` standing in front of the hero toggles when he SWINGS at it.
##   B  Three light presses land three blows on a real `Enemy`.
##   C  A blow visibly STAGGERS the body -- the reel is long enough to see and
##      the reel clip is actually the one playing.
##   D  The charged spin COSTS, the bar runs out, and an empty bar refuses to arm
##      the charge while the trigger still swings.
##
## ## Why this exists when `lights_out.gd`, `maze.gd` and `p4_combo.gd` all pass
##
## Every puzzle director in this repo presses a lantern by calling
## `lamp.apply_hit(null)`. That is the right call for proving the *arithmetic* of
## a lights-out board -- and it means not one of them touches the physics
## question, which is whether the blade's Area3D can see the prop at all. The
## lantern shipped on `K.L_WORLD` alone while `HeroCombat`'s hitbox masks
## `L_ENEMY | L_INTERACT`, so every lantern in the game was scenery: the
## lights-out grid could not be pressed and the maze room's chest was walled off
## for ever behind gates nothing could open. The proofs were green the whole
## time.
##
## `p4_combo.gd` has the mirror of it. It swings at a `TrainingPost`, which
## duck-types `apply_hit` and has no `HealthComponent` -- so it has no i-frames,
## and it is the one target in the game that cannot show the chain's second step
## being eaten by them. A real enemy inherited `K.IFRAME_TIME` (1.0 s, the
## HERO's number) and swallowed every blow after the first for the length of a
## whole three-step chain.
##
## Both bugs are one shape: a proof aimed one layer above where the game lives.
## So this file swings the actual button at the actual prop, every time.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/sword_contact.gd --out=/tmp/sc/x.png

## Seconds after contact before the next press. Past `chain_buffer_from` (0.35
## of the swing) so the press is buffered into the next step rather than eaten,
## and short enough to stay inside `chain_window`. Same number p4_combo uses.
const AFTER_CONTACT := 0.12

## The yaw that faces the hero at -Z, which is where both targets below stand.
##
## `facing_yaw` IS the heading (docs/CONTRACT.md §2.5: `h = (sin y, 0, cos y)`),
## so PI is -Z and 0.0 is +Z. Written down because the first cut of this file
## used 0.0, stood both targets at -Z, and reported every swing missing -- a
## director failing the game for its own arithmetic, which is the exact mistake
## §2.5 exists to stop.
const FACE_MINUS_Z := PI

var _fails: int = 0
## Amounts of every blow the enemy took, in order. Off `Bus.hit_landed` rather
## than off a health diff -- a diff across a pause measures whatever else moved
## the number, and the signal cannot drift.
var _blows: Array[int] = []


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/sc/x.png").get_base_dir()
	var scene: Node = rig.scene()
	var hero: Node3D = scene.get_node_or_null(^"Hero") as Node3D
	if hero == null:
		print("CONTACT FAIL no Hero in the scene")
		return

	await rig.wait_frames(24)
	await _a_lantern(rig, scene, hero, out)
	await _b_chain(rig, scene, hero, out)
	await _d_magic(rig, hero, out)

	if _fails == 0:
		print("CONTACT OK")


func _fail(msg: String) -> void:
	print("CONTACT FAIL " + msg)
	_fails += 1


# --- A. The sword can strike a lantern ----------------------------------------

## Stand a lantern in front of him and swing at it. Nothing here calls `press()`
## or `apply_hit`: the whole point is the trip from the button to the prop.
func _a_lantern(rig, scene: Node, hero: Node3D, out: String) -> void:
	var lamp := PuzzleAtoms.make(PuzzleAtoms.LANTERN, &"") as Lantern
	if lamp == null:
		_fail("PuzzleAtoms could not make a lantern")
		return
	lamp.name = "ContactLantern"
	# Lit, so the swing has somewhere to go: a dark lantern that fails to be hit
	# and a dark lantern that was hit twice look identical.
	lamp.starts_lit = true
	scene.add_child(lamp)

	# Placed, not walked, and the hero turned in by hand -- the same arrangement
	# p4_combo uses, for the same reason: a director measuring reach must not
	# also be measuring the pathing.
	lamp.global_position = hero.global_position + Vector3(0.0, 0.0, -1.1)
	hero.set(&"facing_yaw", FACE_MINUS_Z)
	await rig.wait_frames(20)
	await rig.capture(out.path_join("sc_00_lantern_lit.png"))

	var before: bool = lamp.is_solved()
	await rig.tap([&"attack"])
	# Past the whole swing, so a late damage window still counts.
	await rig.wait_seconds(0.9)
	var after: bool = lamp.is_solved()
	print("CONTACT lantern lit %s -> %s" % [before, after])
	if after == before:
		_fail("a sword swing at a lantern 1.1 m in front did nothing --"
			+ " the blade's hitbox masks L_ENEMY|L_INTERACT and the post is on"
			+ " L_WORLD, so the two never meet")
	await rig.capture(out.path_join("sc_01_lantern_struck.png"))
	lamp.queue_free()
	await rig.wait_frames(4)


# --- B. Three presses, three blows, on something with i-frames ----------------

func _b_chain(rig, scene: Node, hero: Node3D, out: String) -> void:
	var foe := Enemy.new()
	foe.kind = &"skeleton"
	foe.drop_seed = 909
	scene.add_child(foe)
	foe.global_position = hero.global_position + Vector3(0.0, 0.05, -1.2)
	await rig.wait_frames(24)
	# A skeleton has six quarters and the chain deals ten, so a fixed roster body
	# dies on the finisher and the beat measures a corpse. Topped up AFTER
	# `_build_combat` has run -- this is the one place a director is allowed to
	# overwrite a roster stat, because what is under test is the chain, not the
	# tuning.
	foe.health.max_quarters = 40
	foe.health.quarters = 40
	# Held still so the chain is measured and not the chase. Physics off leaves
	# the HealthComponent ticking (it is `_process`), which is exactly what has
	# to keep running -- i-frames are the thing under test.
	foe.set_physics_process(false)
	hero.set(&"facing_yaw", FACE_MINUS_Z)
	await rig.wait_frames(10)
	print("CONTACT enemy iframe_time=%.2fs" % foe.health.iframe_time)

	Bus.hit_landed.connect(_on_hit_landed)
	_blows = []
	for i in 3:
		await rig.tap([&"attack"])
		# Wait out the swing, then press again inside the chain window.
		await rig.wait_seconds(0.62 if i < 2 else 1.1)
		if i < 2:
			await rig.wait_seconds(AFTER_CONTACT)
	Bus.hit_landed.disconnect(_on_hit_landed)

	print("CONTACT chain blows %s (health %d/%d)"
		% [_blows, foe.health.quarters, foe.health.max_quarters])
	if _blows.size() < 3:
		_fail("three presses landed %d blows on a real enemy --"
			% _blows.size()
			+ " the chain is inside the victim's i-frames (%.2fs)"
			% foe.health.iframe_time)
	await rig.capture(out.path_join("sc_02_chain.png"))
	await _c_flinch(rig, hero, foe, out)
	foe.queue_free()
	await rig.wait_frames(4)


# --- C. The blow is visibly taken ---------------------------------------------

## **What the flinch actually is, sampled rather than argued.** One swing, then
## poll the body every frame: how long it stays in HURT, and which clip it spent
## that time in.
##
## The clip name is checked because the duration alone passes on a monster that
## reels for a third of a second in its WALK cycle -- which is precisely what
## shipped. `Hit.stun` was never set by the sword, `Enemy._on_damaged` fell to
## its 0.22 s floor, and the 0.15 s cross-fade into a 0.60 s `hurt` meant the
## body barely left the pose it was already in. The state machine was correct the
## whole time; nothing on screen moved.
func _c_flinch(rig, hero: Node3D, foe, out: String) -> void:
	# **Physics back on**, which beat B turned off to hold the body still. The
	# reel is a countdown inside `_tick_hurt`, so measuring it with physics
	# disabled measures a monster that is in HURT for ever -- the first cut of
	# this beat reported a 1.50 s stagger, which was the poll loop running out.
	foe.set_physics_process(true)
	await rig.wait_seconds(1.2)
	foe.global_position = hero.global_position + Vector3(0.0, 0.05, -1.2)
	hero.set(&"facing_yaw", FACE_MINUS_Z)
	await rig.wait_frames(6)
	var anim := foe.find_child("AnimationPlayer", true, false) as AnimationPlayer
	await rig.tap([&"attack"])

	var reel := 0.0
	var clips := {}
	# NOT A FRAME IS CAPTURED IN HERE -- `capture()` awaits frame_post_draw and
	# writes a PNG, which is far longer than the thing being timed. The picture is
	# taken off a second swing below.
	for _i in 120:
		await rig.wait_physics_frames(1)
		if int(foe.state) != int(Enemy.State.HURT):
			if reel > 0.0:
				break
			continue
		reel += 1.0 / 60.0
		if anim != null:
			clips[anim.current_animation] = true

	print("CONTACT flinch reel=%.2fs clips=%s (K.STUN_LIGHT=%.2f)"
		% [reel, clips.keys(), K.STUN_LIGHT])
	await _flinch_frame(rig, hero, foe, out)
	if reel <= 0.0:
		_fail("the body never entered HURT -- the blow did not land at all")
		return
	# Under the fade into the reel clip is the failure state, not under some
	# absolute idea of "enough": a stagger shorter than its own blend is a
	# stagger nobody can see.
	if reel < 0.25:
		_fail("the reel lasted %.2fs -- the sword is passing no stun and"
			% reel + " Enemy._on_damaged has fallen back to its 0.22 s floor")
	if not (clips.has("hurt") or clips.has("hurt_heavy")):
		_fail("the body spent its whole reel in %s, never in a hurt clip"
			% str(clips.keys()))


## A picture of the stagger, off a swing of its own. The stagger is the half of
## this the numbers cannot judge -- "0.30 s in a clip called hurt" is true of a
## reel nobody can see -- so a frame lands on disk and somebody looks at it.
##
## Three frames across the reel rather than one: a flinch is a movement, and one
## still of a movement is indistinguishable from a pose.
func _flinch_frame(rig, hero: Node3D, foe, out: String) -> void:
	await rig.wait_seconds(1.0)
	foe.global_position = hero.global_position + Vector3(0.9, 0.05, -1.0)
	hero.set(&"facing_yaw", FACE_MINUS_Z)
	await rig.wait_frames(8)
	await rig.capture(out.path_join("sc_03_before.png"))
	await rig.tap([&"attack"])
	# Contact is at 0.22 of a 0.60 s swing, so the reel opens around here. The
	# tree is paused between shots so the three frames are the same swing sampled
	# three times rather than three different swings.
	await rig.wait_seconds(0.16)
	for i in 3:
		await rig.wait_physics_frames(4)
		await rig.capture(out.path_join("sc_04_reel_%d.png" % i))


# --- D. The spin has a price ---------------------------------------------------

## **The cheese, closed, measured at the button.** The charged spin was free: hold
## the trigger, sweep everything in reach, hold it again. Nothing in the game
## said no, so the answer to every room was one move.
##
## It is priced in magic now (`K.MAGIC_SPIN`), and magic only comes back when you
## leave the dungeon (`RunState.enter/extract/die`). Four spins a trip, and the
## fifth hold is the one this beat is really about: it must NOT go dead. A trigger
## that stops responding reads as a broken button, so the hold still happens, the
## charge simply never arms and the release throws the overhead instead.
##
## Held through `rig.hold_seconds` rather than by poking `Game.magic` and calling
## `_spin_swing`: the spend sits between the arm-up and the release, which is
## exactly the stretch a direct call skips over.
func _d_magic(rig, hero: Node3D, out: String) -> void:
	var combat = hero.get_node_or_null(^"Combat")
	if combat == null:
		_fail("no Combat node on the hero -- cannot price the spin")
		return

	Game.fill_magic()
	var start: int = Game.magic
	print("CONTACT magic %d/%d, spin costs %d"
		% [start, Game.max_magic, K.MAGIC_SPIN])
	if start < K.MAGIC_SPIN:
		_fail("a full bar (%d) cannot pay for one spin (%d)" % [start, K.MAGIC_SPIN])
		return

	# One hold, well past `charge_time` (0.42) and clear of the swing before it.
	#
	# Nothing below reads `charged`. It is cleared by `_release_charge` on the way
	# out whether the wind-up armed or not, so after a hold it says the same thing
	# either way -- and the bar is the better witness anyway: `_spin_swing` is the
	# only thing in the game that spends, so magic moving IS the spin firing.
	await rig.wait_seconds(0.8)
	await rig.capture(out.path_join("sc_05_magic_full.png"))
	await rig.hold_seconds([&"heavy"], 0.7)
	await rig.wait_seconds(1.2)
	var after_one: int = Game.magic
	print("CONTACT one spin: magic %d -> %d" % [start, after_one])
	if after_one != start - K.MAGIC_SPIN:
		_fail("a charged spin moved the bar %d, not %d -- the spin is still free"
			% [start - after_one, K.MAGIC_SPIN])

	# Drain the rest, one hold at a time, and stop the moment the bar cannot pay.
	# Bounded rather than `while Game.magic > 0` so a spin that silently stopped
	# spending cannot spin this director for ever.
	for _i in 8:
		if Game.magic < K.MAGIC_SPIN:
			break
		await rig.hold_seconds([&"heavy"], 0.7)
		await rig.wait_seconds(1.2)
	print("CONTACT bar spent down to %d/%d" % [Game.magic, Game.max_magic])
	if Game.magic >= K.MAGIC_SPIN:
		_fail("eight holds could not empty a %d-point bar" % Game.max_magic)
		return
	if Game.magic < 0:
		_fail("the bar went negative (%d) -- the spend is not gated" % Game.magic)
	await rig.capture(out.path_join("sc_06_magic_spent.png"))

	# The fifth hold. The charge must refuse, and the button must still swing.
	var empty: int = Game.magic
	await rig.hold_seconds([&"heavy"], 0.7)
	# Two frames after the release, not zero. `_tick_heavy_button` reads the
	# release EDGE in `_process`, so the overhead the refusal falls through to has
	# not been asked for yet on the frame `hold_seconds` returns on.
	await rig.wait_frames(2)
	var swung: bool = float(combat.get(&"_swing_t")) >= 0.0
	print("CONTACT empty hold: swung=%s magic %d -> %d"
		% [swung, empty, Game.magic])
	if Game.magic != empty:
		_fail("an unaffordable hold still moved the bar, %d -> %d"
			% [empty, Game.magic])
	if not swung:
		_fail("the trigger went dead on an empty bar -- it must fall through to"
			+ " the overhead, not stop responding")
	await rig.capture(out.path_join("sc_07_empty_swing.png"))

	# Leave the bar as the player would find it. This director shares a GameState
	# with whatever runs after it in the same process.
	Game.fill_magic()


func _on_hit_landed(_victim: Node, amount: int, _at: Vector3) -> void:
	_blows.append(amount)
