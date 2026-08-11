extends RefCounted
## Is `ex_parry` a shield bash? Photographs it, and photographs what else the
## library could have been holding.
##
## The move is the most committed thing in the hero's kit — 0.62 s of no
## steering and no guard (`K.PARRY_WINDOW` + `K.PARRY_RECOVER`) — and the
## complaint that opened this card was that it does not look like it costs
## anything. `tools/_clip_shield.gd` puts a number on that half: the left
## forearm, which is where the shield is mounted, peaks at 0.520 m/s of clip
## time against a standing IDLE's 0.279, and the game plays the clip at 0.677x
## (`_clip_scale`: 0.42 s of clip over a 0.62 s move), so on screen the shield
## goes out at 0.352 m/s — 1.26x a man breathing. Every other candidate in the
## set is two to seven times that.
##
## A number is not a verdict about a pose, which is why this exists. Two beats:
##
##   * **as played** — the real press, in the real scene, with the real shield on
##     the arm. This is the only beat that can catch the move failing to fire at
##     all, so it POLLS `parameters/SwingParry/active` and fails the run if the
##     one-shot never goes live. A lookdev that only ever scrubs clips would
##     photograph a beautiful animation the game never plays.
##   * **the sheet** — every candidate scrubbed at the same camera, over the
##     window the game would actually play it (`Hero._SWING_START_OFFSET` to the
##     end), so the frames are comparable and none of them is flattering a clip
##     by showing seconds the hero would never see.
##
## Scrubbed and not played, for swing_lookdev's reason: `rig.capture()` costs
## real game time, and a burst interleaved with a 0.62 s move runs off the end of
## it. The AnimationTree has to be switched off first or it overwrites the scrub
## with the locomotion blend on the next tick.
##
## Shot in the training room and not the garrison: the garrison is lit for night
## and the hero reads as a silhouette in it, which is the one thing a shield
## lookdev cannot afford to lose.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/parry_lookdev.gd --out=/tmp/parry_look/x.png \
##     --warmup=60
##
## Then tile each clip's frames into a strip (no ImageMagick on this machine):
##   for c in /tmp/parry_look/*_0.png; do b=${c%_0.png}; \
##     ffmpeg -y -i "${b}_%d.png" -filter_complex tile=7x1 "${b}_sheet.png"; done

## The clip in use, first, so it is the reference the rest are judged against —
## and its two nearest relatives from the same sword-and-shield set, which are
## the only clips in the library authored around a shield the hero is holding.
##
## The rest are here because they are the fastest LEFT ARMS in the library
## (`_clip_shield.gd --quiet` over all of it). None was authored as a bash; the
## question the sheet answers is whether any of them reads as one anyway once the
## kite shield is on the forearm, which is not a thing the source clip's own name
## can tell you — `ax_melee_attack_360_high` was rejected as a spin for exactly
## the opposite reason, that it reads as a bash while being named a spin
## (build_anim_lib.gd §ONLY).
const CLIPS: Array[StringName] = [
	&"ex_parry",            # in use
	&"ss_crouch_block_01",  # 1.60 m/s — a braced shield driven forward off a crouch
	&"ss_block_01",         # 1.04 m/s
	&"ss_block_02",
	&"ss_kick_01",          # 1.31 m/s — a shove, but with the wrong limb
	&"ss_attack_02",        # 2.35 m/s — the off arm swings hard through a sword cut
	&"bow_punch",           # 3.67 m/s — the fastest left arm in the library
	&"ss_impact_02",        # taking a blow, for the sake of a pose that is NOT a bash
]

## Frames per clip. Seven is what it takes to tell a throw from a settle across a
## half-second move: five put the whole strike inside one gap.
const FRAMES := 7

## Where `Hero._SWING_START_OFFSET[Swing.PARRY]` starts the clip. Spelled out
## rather than read off the hero, because the sheet shows every candidate over
## the same window and the others have no offset of their own to read.
const PARRY_SKIP := 0.08

var _fails: int = 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/parry_look/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		print("PARRYLOOK FAIL no node in group `player`")
		return
	var hero: Node3D = players[0]

	await _as_played(rig, hero, out)
	await _the_sheet(rig, hero, out)

	if _fails == 0:
		print("PARRYLOOK OK")
	else:
		print("PARRYLOOK %d FAILED" % _fails)


func _fail(msg: String) -> void:
	_fails += 1
	print("PARRYLOOK FAIL ", msg)


## The move as the game plays it. Guard up, parry, and watch what the body does.
##
## CALLED, NOT PRESSED — `combat._parry()` rather than a button, which is
## `parry_dodge.gd`'s choice and is made here for a sharper version of its
## reason. This beat is about the POSE, and an input that misses its frame
## reports the pose as absent: an early cut drove it with `rig.tap` and then
## `rig.hold`, got the parry three times out of five, and on the two misses
## printed "SwingParry never went live" — a claim about the harness dressed up
## as a claim about the game (CLAUDE.md §3, the `Input.action_press` row, one
## layer along). The binding is not this file's to prove and is not in doubt:
## `guard_buttons.gd` drives A behind a raised shield through real input and
## exists for exactly that, and `parry_dodge.gd` proves the window pays.
##
## The guard is still raised through `rig.press`, because `_parry` reads
## `blocking` and a hero who is not guarding is a different move.
##
## MEASURED ONCE AND PHOTOGRAPHED ONCE, which is guard_moveset's arrangement and
## is here for the reason that file gives: `rig.capture()` costs real game time —
## enough that a burst interleaved with a 0.62 s move eats the frames the shove
## needs and samples the settle instead. An early cut of this measured the shove
## at 0.133 m of its authored 0.26 and called the settle broken, and both numbers
## were the captures stealing the tween's frames. Measure with nothing else
## happening; photograph without pretending the numbers came from those frames.
func _as_played(rig, hero: Node3D, out: String) -> void:
	var tree: AnimationTree = hero.find_child("AnimTree", false, false)
	if tree == null:
		_fail("hero has no AnimTree")
		return
	var model: Node3D = hero.get_node_or_null(^"Model") as Node3D
	if model == null:
		_fail("hero has no Model node to read the shove off")
		return
	# `hero.combat`, which is the handle parry_dodge uses — the node's NAME is not
	# a contract and the property is.
	var combat = hero.get(&"combat")
	if combat == null:
		_fail("hero has no HeroCombat")
		return

	await rig.press(&"shield")
	# Long enough for the guard blend to be up (`Hero.block_fade`) before the
	# parry, so this measures the move and not the stance getting there.
	await rig.wait_seconds(0.5)

	# ALONG THE HERO'S HEADING, IN WORLD SPACE, and the reason is the bug this
	# beat printed a passing number through. It used to read `model.position.z -
	# rest`: the magnitude of a displacement on a LOCAL axis, which is identical
	# whichever way the body actually went. `Hero._bash_pose` was shoving him
	# backwards — hero-local +Z is the heading REVERSED (`rotation.y = facing_yaw
	# + PI`, docs/CONTRACT.md §2.5) — and this printed "0.260 m of an authored
	# 0.260" over it, twice, on two different days.
	#
	# A signed dot with `_forward()` cannot do that: a backwards shove is a
	# negative reach and fails the check below on its sign alone. CLAUDE.md §4 —
	# and note which half of §4 caught it, because it was not the arithmetic. The
	# frames were tiled and looked at, and the hero got BIGGER against a camera
	# parked behind him.
	var fwd := Vector3(sin(float(hero.get(&"facing_yaw"))), 0.0,
			cos(float(hero.get(&"facing_yaw"))))
	var rest := model.global_position - hero.global_position

	combat.call(&"_parry")
	if float(combat.get(&"_parry_t")) < 0.0:
		_fail("the parry refused to start from behind a raised guard")
		return

	var reach := 0.0
	var pitch := 0.0
	var live := false
	# 60 frames covers the whole 0.62 s move with room to spare, and there is
	# nothing else in this loop, so the frames are the game's own.
	for i in 60:
		if bool(tree.get("parameters/SwingParry/active")):
			live = true
		reach = maxf(reach,
				(model.global_position - hero.global_position - rest).dot(fwd))
		# Signed too, and toward the target: the model's 180 about Y means a
		# POSITIVE `rotation.x` tips the top forward, so a negative peak here is a
		# hero leaning away from the thing he is shoulder-charging.
		pitch = maxf(pitch, model.rotation.x)
		await rig.wait_frames(1)

	# The settle, read after the move has had its whole recovery and then some.
	await rig.wait_seconds(0.4)
	var settled := (model.global_position - hero.global_position - rest).length()

	if not live:
		_fail("the parry ran and SwingParry never went live")
	# A quarter of the authored reach, which no jitter reaches and no rounding
	# produces. The check is "did the body go with the shield at all", not a
	# tolerance on the tuning — `parry_bash_reach` is an export and is meant to
	# be turned without this failing.
	if reach < float(hero.get(&"parry_bash_reach")) * 0.25:
		_fail("the bash never moved the model: reach %.3f m" % reach)
	else:
		print("PARRYLOOK shove: %.3f m of an authored %.3f, %.1f deg of pitch" % [
			reach, hero.get(&"parry_bash_reach"), rad_to_deg(pitch)])
	# And it must come BACK. A settle that does not finish leaves the rig parked
	# in front of its own collision capsule for the rest of the run, which is the
	# failure `_kill_bash` exists to prevent and the one a still frame cannot see.
	if settled > 0.01:
		_fail("the bash never settled: model still %.3f m forward" % settled)

	# NOW the photographs, off a second parry, with the measurement finished.
	combat.call(&"_parry")
	for shot in 4:
		await rig.capture(out.path_join("played_%d.png" % shot))
	rig.release(&"shield")
	await rig.wait_seconds(0.6)


## Every candidate at one camera, scrubbed over the window the game would play.
func _the_sheet(rig, hero: Node3D, out: String) -> void:
	hero.global_position = Vector3(0.0, 0.05, 0.0)
	# `facing_yaw` is the HEADING yaw (docs/CONTRACT.md §2.5): 0 is heading
	# (0,0,+1), so he faces the camera parked out on +Z. His LEFT — and so the
	# shield — is toward +X, which is why the camera sits on the +X side.
	hero.set(&"facing_yaw", 0.0)
	await rig.wait_frames(10)

	# The tree drives the rig every frame and would overwrite the scrub with the
	# locomotion blend on the next tick.
	var tree: AnimationTree = hero.find_child("AnimTree", false, false)
	if tree != null:
		tree.active = false

	var skel: Skeleton3D = hero.skeleton()
	if skel == null:
		_fail("no skeleton")
		return
	var player: AnimationPlayer = skel.get_parent().find_child(
		"AnimationPlayer", true, false)
	if player == null:
		_fail("no AnimationPlayer")
		return

	var cam := hero.get_viewport().get_camera_3d()
	if cam == null:
		_fail("no camera")
		return
	# GameCamera IS the Camera3D and re-derives its transform in
	# _physics_process, so placing it and waiting places it nowhere.
	cam.set_physics_process(false)

	for clip in CLIPS:
		if not player.has_animation(clip):
			print("PARRYLOOK %-20s MISSING" % clip)
			continue
		var length := player.get_animation(clip).length
		var from := PARRY_SKIP if clip == &"ex_parry" else 0.0
		print("PARRYLOOK %-20s %.2f-%.2fs -> %d frames" % [clip, from, length, FRAMES])
		for i in FRAMES:
			player.play(clip)
			# Sampled inside the window rather than at its ends: frame 0 of a
			# Mixamo clip is the neutral pose every one of them shares.
			player.seek(from + (length - from) * (float(i) + 0.5) / float(FRAMES), true)
			cam.global_position = hero.global_position + Vector3(1.6, 1.4, 2.4)
			cam.look_at(hero.global_position + Vector3(0.0, 1.05, 0.0), Vector3.UP)
			await rig.wait_frames(2)
			await rig.capture(out.path_join("%s_%d.png" % [clip, i]))

	if tree != null:
		tree.active = true
