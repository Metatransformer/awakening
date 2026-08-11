extends RefCounted
## Every sound the hero's own MOVES make, driven through the buttons.
##
## `sfx_cues.gd` covers the other half of the audio wiring — `Sfx.CUES`, the
## table hung off `Bus` signals that already say what happened. It cannot cover
## this half, because a jump, a roll, a backflip, a shield block and the
## hookshot's three beats are not signals: they emit `Bus.request_sfx` directly
## from the code that performs them, which is the interface `Sfx` declares and
## `hero_ranged.gd` has always used.
##
## Two failures this is built to catch, and BOTH are silent:
##
##  * **A missing file.** `Sfx._load` push_warnings and returns null, and the
##    move simply makes no noise ever again. Asserting on "did a voice start"
##    covers it (`_ck_file`).
##  * **The wrong id on the right move.** This is the one only a recorder can
##    see. Every new sound here is fired at a moment that also fires something
##    else — the backflip is a dodge, the hookshot's bite is also its pull — so
##    a beat that only asked "did a sound play" would pass with the roll's scuff
##    coming out of a backflip and the smith's anvil coming out of the chain.
##    So `Bus.request_sfx` is tapped and the ids are read back by NAME.
##
## The hookshot's anchor needs something to bite, so this parks a slab on the
## camera's forward ray at runtime — the same trick `hook_freeze` uses to place
## its monster, and for the same reason: a coordinate worked out on paper tests
## my trigonometry and breaks the day the camera's pitch is retuned.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/sfx_moves.gd \
##     --out=/tmp/sfxmoves/x.png --warmup=60

## The hero's grunt. Read off the Hero constant rather than retyped, so the day a
## real recording replaces the charge voice this director follows it there.
##
## A `var` and not a `const`: another class's constant is not a constant
## expression to this one (CLAUDE.md §3), and the parse error takes the whole
## harness down before its first frame.
var VOICE: StringName = Hero.VOICE_EFFORT

var out := ""
var fails := 0

## Every id `Bus.request_sfx` has carried since the last `_listen()`.
var _heard: Array[StringName] = []


func run(rig) -> void:
	out = rig.arg("out", "/tmp/sfxmoves/x.png").get_base_dir()
	Settings.set_volume(&"SFX", 0.9)
	Bus.request_sfx.connect(func(id: StringName, _p: Vector3) -> void:
		_heard.append(id))
	await rig.wait_frames(20)

	# The cheap half first: the four new files and the two existing ones this
	# change reaches for have to be on disk under exactly these names. A typo
	# here is a move that is silent forever and warns once, into a log nobody
	# reads.
	for id in [&"shield_block", &"hookshot_load", &"hookshot_pull", &"dodge_roll",
			&"hit_armor", &"arrow_body_impact", &"ui_move_selection", VOICE]:
		_ck_file(id)

	var hero = rig.get_nodes_in_group(&"player")[0]
	if hero == null:
		_fail("no hero in the scene, so there are no moves to make")
		return

	await _jump(rig, hero)
	await _roll(rig, hero)
	await _backflip(rig, hero)
	await _block(rig, hero)
	await _dpad(rig, hero)
	await _hookshot(rig, hero)

	print("SFXMOVES done, %d failure(s)" % fails)


# --- The body ---------------------------------------------------------------

func _jump(rig, hero) -> void:
	_listen()
	await rig.tap(["jump"])
	await rig.wait_frames(8)
	_ck("the jump grunts", _said(VOICE))
	await rig.capture(out.path_join("s_00_jump.png"))
	await _grounded(rig, hero)


## The roll, out of a committed run — [oot] K.STICK_ACTION_GATE means a walk
## cannot roll at all, so a director that taps `context` from a standstill gets
## no move and no sound and blames the wiring.
func _roll(rig, hero) -> void:
	Input.action_press(&"move_up", 1.0)
	await rig.wait_seconds(0.4)
	_listen()
	await rig.tap(["context"])
	await rig.wait_frames(8)
	Input.action_release(&"move_up")
	_ck("the roll scuffs (%s)" % _log(), _said(&"dodge_roll"))
	_ck("the roll does NOT grunt — that is the backflip's sound",
		not _said(VOICE))
	await rig.capture(out.path_join("s_01_roll.png"))
	await rig.wait_seconds(0.8)


## The backflip. Guarding pins the facing, which gives a NEUTRAL stick an
## unambiguous direction — straight back — and that is the only way to ask for
## Dodge.BACK on purpose (`_try_start_roll`). Free, every dodge is FORWARD.
func _backflip(rig, hero) -> void:
	Input.action_press(&"shield")
	await rig.wait_seconds(0.4)
	if hero.combat == null or not hero.combat.blocking:
		_fail("the guard never came up, so a neutral stick has no back to step to")
		Input.action_release(&"shield")
		return
	_listen()
	await rig.tap(["context"])
	await rig.wait_frames(8)
	Input.action_release(&"shield")
	_ck("the backflip grunts (%s)" % _log(), _said(VOICE))
	_ck("the backflip does NOT scuff — it never touches the ground",
		not _said(&"dodge_roll"))
	await rig.capture(out.path_join("s_02_backflip.png"))
	await rig.wait_seconds(0.9)


## The shield. Driven through `HeroCombat.on_blocked`, which is the function a
## blocked blow calls — not through `Bus.shield_blocked`, because the thing that
## broke last was the sound living inside `on_blocked` as a per-shot
## AudioStreamPlayer3D (CONTRACT §8), and only the real caller proves it moved.
func _block(rig, hero) -> void:
	if hero.combat == null:
		_fail("the hero has no HeroCombat, so there is no shield to block with")
		return
	_silence()
	hero.combat.on_blocked(hero.global_position + Vector3.UP, Vector3.FORWARD)
	await rig.wait_frames(4)
	# Read off the POOL, not off the recorder. This one does not travel through
	# `Bus.request_sfx` at all — it is a `Sfx.CUES` entry hung on
	# `Bus.shield_blocked`, so the tap at the top of this file never sees it, and
	# the only honest question left is which stream a voice is playing.
	_ck("a blocked blow clangs with shield_block, not with something else",
		_playing(&"shield_block"))
	await rig.capture(out.path_join("s_03_block.png"))


## D-pad ↓ and ↑. NOT ← / → : those already ring `HeroCombat.sfx_swap` whenever
## the right hand's model changes, and this beat asserts the blip stays off them
## so the two never double up on one press.
func _dpad(rig, hero) -> void:
	# Two bottles, so ↓ has a ring to move on. On a ring of one `cycle_item` is a
	# no-op and the blip is deliberately refused.
	var bottles: Array[StringName] = [&"", &""]
	Game.bottle_contents = bottles
	await rig.wait_frames(4)

	_listen()
	await rig.tap(["item_next"])
	await rig.wait_frames(6)
	_ck("D-pad down blips (%s)" % _log(), _said(&"ui_move_selection"))

	_listen()
	await rig.tap(["loadout_swap"])
	await rig.wait_frames(6)
	_ck("D-pad up blips (%s)" % _log(), _said(&"ui_move_selection"))

	# The refusal. One bottle is a ring that cannot move, and a click that says
	# "moved" when nothing moved sends the player to a HUD cell that did not
	# change.
	var one: Array[StringName] = [&""]
	Game.bottle_contents = one
	await rig.wait_frames(4)
	_listen()
	await rig.tap(["item_next"])
	await rig.wait_frames(6)
	_ck("D-pad down on a ring of one stays quiet", not _said(&"ui_move_selection"))


# --- The hookshot -----------------------------------------------------------

func _hookshot(rig, hero) -> void:
	if not await rig.draw_weapon(&"hookshot"):
		_fail("the weapon ring never landed on the hookshot")
		return
	await rig.wait_frames(10)

	var cam = hero.get_viewport().get_camera_3d()
	if cam == null:
		_fail("no camera, so there is no aim to hang an anchor on")
		return
	var aim: Vector3 = K.flat(-cam.global_transform.basis.z)
	# Where he was standing before the chain moved him. The anchor beat REELS
	# HIM IN by design, so the monster beat that follows would otherwise start
	# with the hero pressed against a slab five metres from where this director
	# placed everything — and the first run of it did exactly that, firing into
	# a garrison wall and reporting three failures for a hookshot that was
	# working.
	var stood: Vector3 = hero.global_position

	# Something for the head to bite, on L_WORLD, well inside K.HOOK_RANGE.
	var slab := StaticBody3D.new()
	slab.collision_layer = K.L_WORLD
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 6.0, 0.5)
	col.shape = box
	slab.add_child(col)
	rig.scene().add_child(slab)
	slab.global_position = hero.global_position + aim * 5.0 + Vector3.UP * 1.0
	slab.look_at(hero.global_position + Vector3.UP * 1.0, Vector3.UP)
	await rig.wait_frames(10)

	# HELD, not tapped. `use_press` raises the brace and the shot is aimed at the
	# RELEASE, off wherever the lens is pointed then — a two-frame tap fires into
	# a camera still swinging down out of the follow rig (hook_freeze.gd learned
	# this the expensive way).
	_listen()
	Input.action_press(&"heavy")
	await rig.wait_frames(6)
	_ck("the brace loads (%s)" % _log(), _said(&"hookshot_load"))
	await rig.capture(out.path_join("s_04_hook_load.png"))

	_listen()
	await rig.wait_frames(30)
	Input.action_release(&"heavy")
	# Polled rather than sampled at a fixed frame: the flight is K.HOOK_SPEED
	# over five metres, and a check written at frame N passes on how busy the
	# machine is.
	for i in 90:
		await rig.wait_frames(1)
		if _said(&"hookshot_pull"):
			break
	_ck("the head rings off the anchor (%s)" % _log(), _said(&"hit_armor"))
	_ck("and the chain reels him in", _said(&"hookshot_pull"))
	_ck("the smith's anvil is no longer standing in for either",
		not _said(&"craft_clang"))
	await rig.capture(out.path_join("s_05_hook_pull.png"))
	slab.queue_free()

	await _hook_bites_a_monster(rig, hero, stood)


## The other half of the shot: a body is an anchor that does not hold. `Enemy.freeze`
## owns that impact, and it was the smith's `craft_clang` until this change.
func _hook_bites_a_monster(rig, hero, stood: Vector3) -> void:
	# Back to the open ground the last beat started from, and let the camera
	# settle before the aim is read again: the ray is taken FRESH here rather
	# than reused, because the follow rig has been swinging through a reel-in and
	# a five-metre walk-back since the first one was measured.
	hero.global_position = stood
	hero.velocity = Vector3.ZERO
	await rig.wait_seconds(1.2)

	var foe := Enemy.new()
	foe.kind = &"skeleton"
	foe.drop_seed = 4411
	rig.scene().add_child(foe)
	foe.global_position = _in_the_way(hero)
	# Held still. A skeleton that closes to claw range mid-shot walks out of the
	# aim it was placed on and takes the beat with it.
	foe.set_physics_process(false)
	await rig.wait_frames(20)
	foe.set_physics_process(true)

	_listen()
	Input.action_press(&"heavy")
	await rig.wait_frames(36)
	Input.action_release(&"heavy")
	for i in 90:
		await rig.wait_frames(1)
		if foe.is_frozen():
			break
	_ck("the chain bit the monster", foe.is_frozen())
	_ck("and it lands in a body rather than on an anvil (%s)" % _log(),
		_said(&"arrow_body_impact"))
	_ck("a monster is not an anchor, so nothing reels",
		not _said(&"hookshot_pull"))
	await rig.capture(out.path_join("s_06_hook_bite.png"))


## Standing room ON the shot the hookshot is actually going to take, short of
## whatever the shot would otherwise hit.
##
## Not `hero.global_position + flat_forward * 5` — that was the first version and
## it fired into the cobbles twice. `_aim_from` does NOT shoot parallel to the
## camera: it asks the camera what its crosshair is over and aims the muzzle at
## that POINT, so on a follow rig pitched even slightly down the ray meets the
## ground a few metres out and a monster parked five metres ahead is behind the
## floor. So this walks the same ray the shot will walk, finds what stops it, and
## puts the body at 55% of the way there — comfortably in front, and low enough
## on a downward ray that the ray is still above the pavement when it arrives.
func _in_the_way(hero) -> Vector3:
	var eye: Vector3 = hero.global_position + Vector3.UP * K.HERO_EYE_Y
	var cam = hero.get_viewport().get_camera_3d()
	var look: Vector3 = -cam.global_transform.basis.z if cam != null \
		else -hero.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(eye, eye + look * K.HOOK_RANGE)
	q.collision_mask = K.L_WORLD
	q.exclude = [hero.get_rid()]
	# ANNOTATED, not inferred. `hero` is untyped here (the rig hands directors a
	# bare Node), so the whole call chain off it is Variant and `:=` cannot infer
	# a type for the result — a PARSE error, which takes the director down before
	# its first frame and reads from the harness as a hang. CLAUDE.md §3.
	var hit: Dictionary = hero.get_world_3d().direct_space_state.intersect_ray(q)
	var stops_at: float = K.HOOK_RANGE
	if not hit.is_empty():
		stops_at = eye.distance_to(hit["position"] as Vector3)
	var at: Vector3 = eye + look * minf(stops_at * 0.55, 5.0)
	# Feet on the hero's own floor. A skeleton spawned at the ray's height would
	# either hang in the air or sink, and neither is a thing to shoot at.
	return Vector3(at.x, hero.global_position.y, at.z)


# --- Plumbing ---------------------------------------------------------------

## Wait until the hero is back on the floor, so the next beat starts from a
## stance it can actually act from.
func _grounded(rig, hero) -> void:
	for i in 120:
		await rig.wait_frames(1)
		if hero.is_on_floor() and hero.state == Hero.MoveState.GROUND:
			return


func _listen() -> void:
	_heard.clear()


func _said(id: StringName) -> bool:
	return _heard.has(id)


func _log() -> String:
	return "heard %s" % [_heard] if not _heard.is_empty() else "heard nothing"


func _silence() -> void:
	for v in Sfx._pool:
		v.stop()


## Is a voice playing THIS sound right now? `Sfx._load` caches, so the stream a
## voice holds is the identical object the id resolves to — which is what makes
## "a voice started" into "the right sound started".
func _playing(id: StringName) -> bool:
	var want: AudioStream = Sfx._load(id)
	if want == null:
		return false
	for v in Sfx._pool:
		if v.playing and v.stream == want:
			return true
	return false


## Is there a real file behind this id? The whole point of `Sfx.VARIANTS` is that
## `doom_stinger` is on disk as `doom_stinger_1`, so this goes through `_load`
## rather than `ResourceLoader.exists` — the bare name is what the callers pass.
func _ck_file(id: StringName) -> void:
	_ck("a file exists for %s" % id, Sfx._load(id) != null)


func _ck(what: String, ok: bool) -> void:
	if ok:
		print("SFXMOVES ok: %s" % what)
	else:
		_fail(what)


func _fail(what: String) -> void:
	fails += 1
	print("SFXMOVES FAIL %s" % what)
