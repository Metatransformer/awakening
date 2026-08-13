extends RefCounted
## The backflip as the GAME plays it — pose and ground travel on one timeline.
##
## dodge_lookdev.gd photographs `ex_backflip` the clip, with the AnimationTree
## switched off. That answers "is this a backflip" and it cannot answer the only
## question that matters for feel, which is what the hero is doing during the
## first third of the move: the clip is compressed onto the dodge's real duration
## by an AnimationNodeTimeScale, and the hero is travelling at
## `K.BACKFLIP_SPEED` from the frame the button goes down whether or not the
## pose has left the ground yet.
##
## So this fires a REAL dodge — guard up, stick back, `context` — and shoots a
## fixed-cadence burst.
##
## The camera TRACKS, and the first cut of this director had it static so the
## 2.6 m of travel would show. That was the wrong trade twice over: the hero
## backs into an unlit corridor and behind a pillar, and at the distance needed
## to hold the whole run he is forty pixels tall — you cannot see a tuck at that
## size. The travel does not need the lens, because every frame is NAMED with the
## metre and the hip height it was taken at, and those two numbers side by side
## are the entire question:
##
##   b04_t0.13_back0.58_hip0.68   <- 0.58 m gone, hips still at standing height
##
## The camera is repositioned on the frame the dodge COMMITS, not before.
## Guarding pins the facing to the lens (`Hero._tick_camera_facing`), so a side
## camera set up in advance is a side camera the hero immediately turns to face.
## Once `MoveState.ROLL` is entered the facing is frozen and the lens is free.
##
## `Engine.time_scale` IS NOT DECORATION. guard_moveset.gd's note that
## `rig.capture()` costs real game time is an understatement at this cadence: a
## PNG save is ~100 ms of wall clock, the harness renders uncapped, and the first
## cut of this director sampled the entire 0.80 s move in six frames while
## believing it had taken 0.20 s. At 0.1 the physics tick rate drops with it, so
## a save eats a tenth of a tick instead of six, and `t` is read off
## `Engine.get_physics_frames()` rather than counted by the loop — the loop never
## sees the frames a capture consumed.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/_backflip_trace.gd --out=/tmp/bf/x.png
##   ffmpeg -y -i /tmp/bf/b%02d*.png -filter_complex tile=6x3 /tmp/bf/sheet.png

## Hero.MoveState.ROLL and Hero.Dodge.BACK, neither reachable by name from a
## RefCounted. The dodge is CHECKED and not assumed: guarding pins the facing to
## the lens, this director drives the lens by hand, and the second take of an
## early cut classified as a forward roll and photographed a man rolling along
## the floor under a filename that said backflip. A sheet that lies about which
## move it is showing is worse than no sheet.
const ST_ROLL := 2
const DODGE_BACK := 1
## Every Nth physics TICK. Ticks keep coming at 60 Hz of wall clock whatever the
## time scale is — what `time_scale` changes is the delta each one carries — so a
## 0.033 s game-time cadence is 20 ticks at SLOMO 0.1, and game time is
## `ticks * SLOMO / 60`. Getting that factor wrong is not a subtle error: it
## reports a 0.33 s move as a 3.3 s one and every number on the sheet is a lie.
const EVERY := 20
## Game time per real second during the burst. See the note at the top.
const SLOMO := 0.1
## `backflip_time` values to shoot, one sheet each, in one run of the harness.
## EMPTY means "shoot whatever the hero ships with", which is what a verification
## run wants — a sweep that sets the value cannot tell you the exported default
## is right. Put numbers in to compare candidates; take them out again after.
##
## Sweeping the DURATION and not the offset, because only one of the two can be
## swept from a director: `backflip_time` is read when the dodge fires, so it can
## be set between takes, while `backflip_start_offset` is baked into an
## AnimationNodeAnimation when `_build_anim_tree` runs in `_ready` and changing
## it needs a fresh boot.
const TIMES: Array[float] = []


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/bf/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		rig.fail("BF FAIL no node in group `player`")
		return
	var hero: Node3D = players[0]
	var cam := hero.get_viewport().get_camera_3d()
	if cam == null:
		rig.fail("BF FAIL no camera")
		return
	# A key-cap legend across the bottom of twenty-odd pose frames helps nobody.
	if Hud != null:
		Hud.visible = false

	print("BF offset=%.2f shipped_time=%.2f" % [
		float(hero.get(&"backflip_start_offset")), float(hero.get(&"backflip_time"))])
	var home := hero.global_position
	var times := TIMES
	if times.is_empty():
		times = [float(hero.get(&"backflip_time"))]
	for bf_time in times:
		hero.set(&"backflip_time", bf_time)
		# Back to the mark between takes. Three backflips in a row otherwise walk
		# him eight metres into the far wall, and a dodge that runs out of room
		# is a dodge whose travel numbers are the wall's, not the move's.
		hero.global_position = home
		await _take(rig, hero, cam, out, bf_time)
	print("BF done")


func _take(rig, hero: Node3D, cam: Camera3D, out: String, bf_time: float) -> void:
	var tag := "t%03d" % int(round(bf_time * 100.0))
	await rig.wait_seconds(0.6)
	# Guard up and stick back: blocking keeps the facing, so pulling back is a
	# backflip rather than a turn-and-dive. See Hero._try_start_roll.
	Input.action_press(&"shield")
	await rig.wait_seconds(0.5)
	Input.action_press(&"move_down", 1.0)
	await rig.wait_seconds(0.3)

	Engine.time_scale = SLOMO
	Input.action_press(&"context")
	var started := false
	for i in 30:
		await rig.physics_frame
		if int(hero.get(&"state")) == ST_ROLL:
			started = true
			break
	Input.action_release(&"context")
	if not started:
		Engine.time_scale = 1.0
		rig.fail("BF FAIL %s no dodge started" % tag)
		return
	var fired := int(hero.get(&"_dodge"))
	if fired != DODGE_BACK:
		Engine.time_scale = 1.0
		rig.fail("BF FAIL %s fired Dodge %d, wanted BACK — the lens has drifted off "
			% [tag, fired] + "the facing again; see the note on DODGE_BACK")
		return

	var facing: float = hero.get(&"facing_yaw")
	var fwd := Vector3(sin(facing), 0.0, cos(facing))
	var side := Vector3(-fwd.z, 0.0, fwd.x)
	var start := hero.global_position
	cam.set_physics_process(false)

	var skel: Skeleton3D = hero.skeleton()
	var hips := -1
	if skel != null:
		hips = skel.find_bone(&"mixamorig_Hips")

	# The move plus its recovery plus three frames of standing on the end, so the
	# sheet shows the hero arriving back in locomotion rather than stopping
	# mid-absorb. `roll_recover_time` is 0.20 and not readable from here.
	var shots := int(ceil((bf_time + 0.20 + 0.10) / (float(EVERY) * SLOMO / 60.0)))
	var f0 := Engine.get_physics_frames()
	var next := 0
	for shot in shots:
		while int(Engine.get_physics_frames() - f0) < next:
			await rig.physics_frame
		var t := float(Engine.get_physics_frames() - f0) * SLOMO / 60.0
		var back: float = (start - hero.global_position).dot(fwd)
		var hip_y := 0.0
		if hips >= 0:
			hip_y = (skel.global_transform * skel.get_bone_global_pose(hips)).origin.y \
				- hero.global_position.y
		# Side-on and a little ahead of him, aimed at hip height rather than the
		# chest: a backflip's read is the legs coming over the head, and a lens
		# on the chest crops the feet off exactly when they matter.
		cam.global_position = hero.global_position + side * 3.0 + fwd * 1.4 \
			+ Vector3(0.0, 1.3, 0.0)
		cam.look_at(hero.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
		await rig.wait_frames(1)
		print("BF %s b%02d t=%.2f back=%.2f hip=%.2f state=%d" % [
			tag, shot, t, back, hip_y, int(hero.get(&"state"))])
		await rig.capture(out.path_join(
			"%s/b%02d_t%.2f_back%.2f_hip%.2f.png" % [tag, shot, t, back, hip_y]))
		next += EVERY

	Engine.time_scale = 1.0
	Input.action_release(&"move_down")
	Input.action_release(&"shield")
	# Hand the lens back. Not housekeeping: guarding pins the facing to the camera
	# (`Hero._tick_camera_facing`), so a camera left parked where the last shot of
	# the burst put it re-aims the hero for the NEXT take, and `move_down` stops
	# meaning backwards. That is exactly how take two came out a forward roll.
	cam.set_physics_process(true)
	# Let him settle out of the recovery before the next take re-presses.
	await rig.wait_seconds(0.4)
