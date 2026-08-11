extends RefCounted
## The air slam: jump, press attack, hit the ground. Measured and photographed,
## in that order and never in the same pass.
##
## The two jobs are split for the reason jump_run.gd splits them: `rig.capture()`
## costs real physics frames, so a loop that both samples the body and takes
## pictures under-counts every duration it reports. `_arc` measures, `_shoot`
## photographs, and the beat throws two slams.
##
## What a `SLAM FAIL` means, per check:
##   * the press did nothing            — request_slam refused; look at the state
##                                        and floor gates in it
##   * the hang never happened          — the hero fell at gravity through the
##                                        wind-up, so the pose has nothing to
##                                        read against
##   * he arrived slower than slam_speed— the drive is not being applied; check
##                                        _apply_gravity's SLAM branch
##   * no dust                          — SlamVfx never spawned, and a slam with
##                                        no dust is a hero sitting down
##   * the post never took a hit        — _slam_targets found nothing, which is
##                                        the shape query or the layer mask
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/slam_attack.gd --out=/tmp/slam/x.png
##   ffmpeg -y -i /tmp/slam/hit_%d.png -filter_complex tile=6x1 /tmp/slam/sheet.png

const ST_GROUND := 0
const ST_SLAM := 6

## 8 frames at 0.06 s covers hang, drive, contact and the first of the recovery —
## the whole verb, at a rate where the contact frame cannot fall between two
## pictures.
const BURST := 8
const GAP := 0.06

var _fails := 0


func run(rig) -> void:
	# THE BOOT KIT IS GONE (game_state.gd STARTER_KIT is empty now, docs/SCOPE.md
	# M1): the bow, the hookshot and the thirty arrows used to be handed over in
	# `Game._ready()`, and this director was written on top of that. It exercises
	# the gear rather than the earning of it, so it hands itself the same three
	# things the boot used to -- the alternative is a director that fails for a
	# reason that has nothing to do with what it claims.
	Game.grant(&"bow")
	Game.grant(&"hookshot")
	if Game.arrows < 30:
		Game.add_arrows(30 - Game.arrows)

	var out: String = rig.arg("out", "/tmp/slam/x.png").get_base_dir()
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		_fail("no node in group `player`")
		_report()
		return
	var hero: Node3D = players[0]
	hero.set(&"facing_yaw", 0.0)

	var cam := hero.get_viewport().get_camera_3d()
	if cam != null:
		cam.set_physics_process(false)
	await rig.wait_seconds(0.8)

	await _beat_measured(rig, hero)
	await _beat_photographed(rig, hero, cam, out)
	await _beat_on_a_target(rig, hero, cam, out)
	await _beat_grounded_press_is_a_swing(rig, hero)

	_report()


## Jump, slam, and read every number off the body on the way down.
func _beat_measured(rig, hero: Node3D) -> void:
	_release_all()
	await rig.wait_seconds(0.4)

	var y0: float = hero.global_position.y
	Input.action_press(&"jump")
	await rig.physics_frame
	Input.action_release(&"jump")
	# Late enough to be near the apex, which is where a player would press it.
	await rig.wait_seconds(0.22)

	var apex: float = hero.global_position.y - y0
	Input.action_press(&"attack")
	await rig.physics_frame
	Input.action_release(&"attack")

	# ONE sampling loop that records the whole move frame by frame; every number
	# below is derived from the samples afterwards.
	#
	# The first version of this beat measured in PHASES — poll for the state,
	# then time the hang, then watch the drive — with an `await` between each.
	# The awaits ARE the elapsed time: by the time the hang phase began sampling,
	# the slam had already landed, and the beat reported a metre of sag and no
	# drive on a slam that was working perfectly. A move this short (0.16 s of
	# hang, under 0.1 s of drive) cannot be measured by a loop that stops to
	# think between the parts it is measuring.
	var hang: float = float(hero.get(&"slam_hang"))
	var recover: float = float(hero.get(&"slam_recover"))
	var states: Array[int] = []
	var heights: Array[float] = []
	var falls: Array[float] = []
	var floors: Array[bool] = []
	var frozen: Array[bool] = []
	for i in 120:
		states.append(int(hero.get(&"state")))
		heights.append(hero.global_position.y)
		falls.append(-float(hero.velocity.y))
		floors.append(hero.is_on_floor())
		# Physics frames keep arriving during a hit-stop; only their delta is zero.
		# See the root check below for why this has to be recorded.
		frozen.append(Engine.time_scale <= 0.0)
		await rig.physics_frame

	var enter_f := states.find(ST_SLAM)
	if enter_f < 0:
		_fail("the press did nothing — the hero never entered SLAM")
		return
	var land_f := -1
	var free_f := -1
	for i in range(enter_f, states.size()):
		if land_f < 0 and floors[i]:
			land_f = i
		if land_f >= 0 and states[i] != ST_SLAM:
			free_f = i
			break

	# The hang is the wind-up and the whole read of the move: across the first
	# `slam_hang` seconds of the state, the hero must not have dropped.
	var sagged := 0.0
	for i in range(enter_f, mini(enter_f + int(hang * 60.0), heights.size())):
		sagged = maxf(sagged, heights[enter_f] - heights[i])
	var fastest := 0.0
	for i in range(enter_f, land_f if land_f > 0 else heights.size()):
		fastest = maxf(fastest, falls[i])

	# The root is counted in FRAMES, and the frames spent inside the impact's own
	# hit-stop are not recovery: Feel.hitstop sets Engine.time_scale = 0, which
	# scales the physics DELTA to zero without stopping the ticks, so those frames
	# arrive, cost the hero nothing, and never move `_state_timer`.
	#
	# Do not "correct" for that by adding K.HITSTOP_HEAVY / 60 to the expectation.
	# The stop ends on the wall clock (`_stop_until` in feel.gd) while this loop
	# counts ticks, and if the main loop hitches — the first SlamVfx of a session
	# compiles particle shaders, which is exactly such a hitch — Godot catches up
	# by running several physics steps in one iteration. A nominal nine frozen
	# frames measured nine on one run and fourteen on the next. Counting the
	# frozen frames and subtracting them measures the recovery itself, which is
	# the thing the check is actually about.
	var stopped := 0
	for i in range(land_f, free_f if free_f > 0 else frozen.size()):
		if frozen[i]:
			stopped += 1
	var want: float = float(hero.get(&"slam_speed"))
	var air := (land_f - enter_f) / 60.0 if land_f > 0 else -1.0
	var root := (free_f - land_f - stopped) / 60.0 if free_f > 0 else -1.0
	print("SLAM measured: apex=%.2f m hang_sag=%.3f m drive=%.1f m/s (want %.1f)" % [
		apex, sagged, fastest, want])
	print("SLAM timing: %.2f s commit->floor, %.2f s rooted (want %.2f, +%d frozen frames)" % [
		air, root, recover, stopped])
	if sagged > 0.05:
		_fail("the hero sagged %.3f m during the hang — is _apply_gravity's SLAM branch live?" % sagged)
	if fastest < want * 0.9:
		_fail("he arrived at %.1f m/s against a slam_speed of %.1f — the drive is not being applied" % [
			fastest, want])
	if land_f < 0:
		_fail("the slam never reached the floor")
	# The root has to be REAL, or the move costs nothing; and it has to END,
	# because a root that never lifts is a softlock rather than a price.
	if free_f < 0:
		_fail("the hero never left SLAM — the recovery does not end")
	elif absf(root - recover) > 0.06:
		_fail("the root ran %.2f s of live time against a slam_recover of %.2f" % [root, recover])
	if stopped <= 0:
		_fail("the impact froze nothing — Bus.request_hitstop went unheard")


## The same slam, photographed, and checked for its dust. A slam that measures
## perfectly and throws no particles is a hero sitting down hard.
func _beat_photographed(rig, hero: Node3D, cam: Camera3D, out: String) -> void:
	_release_all()
	await rig.wait_seconds(0.9)
	if Hud != null:
		Hud.visible = false

	Input.action_press(&"jump")
	await rig.physics_frame
	Input.action_release(&"jump")
	await rig.wait_seconds(0.22)
	Input.action_press(&"attack")
	await rig.physics_frame
	Input.action_release(&"attack")

	var saw_dust := false
	for i in BURST:
		_park(cam, hero, Vector3(2.8, 1.3, 3.2))
		await rig.capture(out.path_join("slam_%d.png" % i))
		saw_dust = saw_dust or _dust(hero) != null
		await rig.wait_seconds(GAP)
	print("SLAM shot: %d frames, dust=%s" % [BURST, saw_dust])
	if not saw_dust:
		_fail("no SlamVfx in the scene across the whole impact — the landing threw no dust")


## Over something that can be hit. The training posts answer `apply_hit` directly
## (they predate HealthComponent), which is exactly the duck-typed case
## `_damageable` exists for, so this also proves the slam did not quietly grow
## its own narrower idea of what a target is.
func _beat_on_a_target(rig, hero: Node3D, cam: Camera3D, out: String) -> void:
	_release_all()
	await rig.wait_seconds(0.6)

	var post := _nearest_post(rig, hero)
	if post == null:
		print("SLAM target: no post in the scene, skipping the damage check")
		return
	# Stand next to it rather than on top of it: a slam landing INSIDE the post's
	# collider would prove the query works at zero range and nothing else.
	hero.global_position = post.global_position + Vector3(1.2, 0.1, 0.0)
	await rig.wait_seconds(0.35)

	var before := _post_damage(post)
	Input.action_press(&"jump")
	await rig.physics_frame
	Input.action_release(&"jump")
	await rig.wait_seconds(0.22)
	Input.action_press(&"attack")
	await rig.physics_frame
	Input.action_release(&"attack")

	for i in 8:
		_park(cam, hero, Vector3(2.4, 1.2, 2.8))
		await rig.capture(out.path_join("hit_%d.png" % i))
		await rig.wait_seconds(GAP)

	var after := _post_damage(post)
	print("SLAM target: post total_damage %d -> %d" % [before, after])
	if after <= before:
		_fail("a post 1.2 m from the impact took no damage — check _slam_targets' mask")


## The half that had to keep working: on the floor, the attack button is still
## the light swing it has always been.
func _beat_grounded_press_is_a_swing(rig, hero: Node3D) -> void:
	_release_all()
	await rig.wait_seconds(1.0)

	Input.action_press(&"attack")
	await rig.physics_frame
	Input.action_release(&"attack")

	var swung := false
	var slammed := false
	for i in 20:
		await rig.physics_frame
		var st := int(hero.get(&"state"))
		swung = swung or st == 4  # MoveState.ATTACK
		slammed = slammed or st == ST_SLAM
	print("SLAM grounded: swung=%s slammed=%s" % [swung, slammed])
	if slammed:
		_fail("a press made ON THE FLOOR came out as a slam")
	if not swung:
		_fail("a press made on the floor no longer swings at all")


# --- helpers ----------------------------------------------------------------

func _dust(hero: Node3D) -> Node:
	for child in hero.get_parent().get_children():
		if child.name.begins_with("SlamVfx"):
			return child
	return null


## The training posts are in `hurtbox` and carry a running `total_damage`, which
## is the only readout in the scene that survives the post's own decay timer.
func _nearest_post(rig, hero: Node3D) -> Node3D:
	var best: Node3D = null
	var best_d := 1e9
	for n in rig.get_nodes_in_group(&"hurtbox"):
		var p := n as Node3D
		if p == null or not ("total_damage" in p):
			continue
		var d: float = p.global_position.distance_to(hero.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _post_damage(post: Node3D) -> int:
	return int(post.get(&"total_damage"))


func _park(cam: Camera3D, hero: Node3D, offset: Vector3) -> void:
	if cam == null:
		return
	cam.global_position = hero.global_position + offset
	cam.look_at(hero.global_position + Vector3(0.0, 0.8, 0.0), Vector3.UP)


func _release_all() -> void:
	for a in [&"jump", &"attack", &"context", &"move_up", &"move_down",
			&"move_left", &"move_right", &"shield", &"interact"]:
		Input.action_release(a)


func _fail(msg: String) -> void:
	_fails += 1
	print("SLAM FAIL %s" % msg)


func _report() -> void:
	print("SLAM done: %d failure(s)" % _fails)
