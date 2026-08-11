extends RefCounted
## The locomotion blend photographed side-on, at every speed, with the hero
## DRIVING rather than scrubbed.
##
## `run_lookdev` scrubs clips by hand with the AnimationTree switched off, which
## is the right way to compare two candidates and cannot answer the question that
## follows the swap: what does the BLEND look like between them? A blend space
## with a guarded walk at one point and a free run at the next spends real
## seconds at the speeds in between, and that is where a pose swap shows up as
## mush. So this holds the stick at four deflections and lets the game do it.
##
## It also gets at the foot skate, which is the other thing a scrub cannot show:
## a clip at the wrong playback rate looks fine frozen and slides visibly the
## moment the body is actually travelling.
##
## `p2_walk_run_stop` covers the same ramp and is not this: it shoots from the
## GAMEPLAY camera, behind the hero, in the garrison at night. That is the right
## lens for "does the ramp feel continuous" and the wrong one for "what are his
## arms doing" — from behind, at night, a hero is a silhouette with a shield
## edge.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/run_ramp.gd --out=/tmp/ramp/x.png \
##     --warmup=60

## Stick deflection -> what K.speed_for_stick makes of it. 0.55 is a walk, 1.0 is
## the run cap, and the two in between are the blend itself — the speeds the
## sheet exists to photograph.
##
## The low end starts at 0.55 and not lower because the deflection is deadzoned
## TWICE before it is a speed: the InputMap eats 0.2 of it and `K.STICK_DEADZONE`
## eats more off what survives. A first pass asked for 0.33 and photographed four
## frames of a man standing still, labelled `walk`.
const STEPS: Array[float] = [0.55, 0.72, 0.86, 1.0]
## Frames per step, and the gap between them in seconds. Four samples across
## ~0.5 s catches both feet down and both arms at their extremes at every cadence
## in the blend; a single frame per speed would say nothing about a cycle.
const SHOTS := 4
const SHOT_GAP := 0.11
## Seconds on the stick before the first shot of each step. K.ACCEL needs a beat
## to reach the new speed, and a sheet that shoots into the acceleration is
## photographing the ramp rather than the speed it is labelled with.
const SETTLE := 1.0

## Side-on, and on −X for the reason run_lookdev documents: the training room's
## raised ledge is on +X and a lens parked there sits inside it. Re-parked every
## frame — the hero is travelling, and a fixed camera turns a 4.37 m/s run into
## four frames of him leaving.
const SIDE_OFFSET := Vector3(-3.4, 1.30, 0.0)
## The lane he runs down, and both the x and the z are read off
## proving_ground.tscn rather than guessed, because the lens rides 3.4 m to his
## −X and so BOTH lanes have to stay clear of the furniture:
##
##   x = 0     the room's centreline. Clear of the ledge and its steps (x 2.1
##             and east) on one side and of `BlockTall` (x −5.4) on the other,
##             which leaves the camera lane at x = −3.4 in open floor.
##   z = 4.0   and NOT the 8.0 a first pass used. `BlockLow` sits at z 5.4 and
##             spans x −4.1..−1.7 — the camera lane goes straight through it, so
##             starting north of it and running −Z leaves it behind the lens for
##             the whole sheet. Started at 8.0, six frames were a grey slab.
##
## 13 m of runway from here to the corridor mouth: 3 s at the run cap, 2 at the
## sprint, and every beat below is under 1.5 s.
const START := Vector3(0.0, 0.05, 4.0)
## The lock-on fixtures, dropped through the floor for the duration — hidden AND
## moved, because `PostC` stands at x = 0 z = −2.5, which is both dead on the
## sightline and dead in the lane, and a hidden post still has a collider to run
## into. (A pass that only hid them reported 0.00 m/s for every beat after the
## walk: he was jammed against a training dummy he could not see.)
const HIDE: Array[StringName] = [&"PostA", &"PostB", &"PostC"]
## The lens TRACKS him but never TURNS, and that is the whole trick of this
## director. The stick is read camera-relative, so a camera that re-aims at the
## hero every frame while he runs feeds his own motion back into the direction he
## is being told to run: the first pass parked side-on, and he promptly turned
## and ran away from it, producing twenty frames of the back of his head. Holding
## the basis fixed — always looking down +X — makes "screen-forward" a constant,
## which is what keeps the run a straight line.
const LOOK_DIR := Vector3(1.0, -0.10, 0.0)
## Which action runs him down the runway, and it follows from LOOK_DIR rather
## than from taste. A camera looking +X with +Y up has `basis.z` = −X and
## `basis.x` = +Z, so screen-RIGHT is world +Z and screen-LEFT is world −Z. The
## floor's long axis is −Z (the corridor end), so: left.
const RUN_ACTION := &"move_left"

var _i := 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/ramp/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var players: Array = rig.get_nodes_in_group(&"player")
	if players.is_empty():
		print("RAMP FAIL no node in group `player`")
		return
	var hero: Node3D = players[0]
	# Everything below runs down −Z, which is the one axis here with a straight
	# 13 m of unobstructed floor on it.
	hero.global_position = START
	for id in HIDE:
		var prop := rig.scene().get_node_or_null(NodePath(id)) as Node3D
		if prop != null:
			prop.visible = false
			prop.global_position -= Vector3(0.0, 50.0, 0.0)
	await rig.wait_frames(10)

	var cam := hero.get_viewport().get_camera_3d()
	if cam == null:
		print("RAMP FAIL no camera")
		return
	cam.set_physics_process(false)

	# The room is authored dark and this sheet is read off limb silhouettes.
	var lamp := OmniLight3D.new()
	lamp.light_energy = 2.4
	lamp.omni_range = 40.0
	lamp.shadow_enabled = false
	rig.scene().add_child(lamp)

	await rig.wait_frames(10)

	for step in STEPS:
		_park(cam, hero, lamp)
		await rig.wait_frames(2)
		Input.action_press(RUN_ACTION, step)
		await rig.wait_seconds(SETTLE)
		for s in SHOTS:
			_park(cam, hero, lamp)
			await rig.capture(out.path_join("f_%02d_s%02d.png" % [_i, int(step * 100)]))
			_i += 1
			await rig.wait_seconds(SHOT_GAP)
		var speed: float = (hero.velocity as Vector3).length()
		print("RAMP stick=%.2f speed=%.2f m/s" % [step, speed])
		# Re-park at the top of the room for each step rather than letting four
		# passes run 25 m down a 20 m floor.
		Input.action_release(RUN_ACTION)
		await rig.wait_seconds(0.4)
		hero.global_position = START
		await rig.wait_frames(6)

	# The sprint, which is the point the swap was partly made for: `ex_fast_run`
	# sits at the top of this same axis, and run -> sprint is now a change of
	# cadence inside one family rather than a change of costume.
	Input.action_press(RUN_ACTION, 1.0)
	Input.action_press(&"context", 1.0)
	Input.action_press(&"interact", 1.0)
	await rig.wait_seconds(1.1)
	for s in SHOTS:
		_park(cam, hero, lamp)
		await rig.capture(out.path_join("f_%02d_sprint.png" % _i))
		_i += 1
		await rig.wait_seconds(SHOT_GAP)
	print("RAMP sprinting=%s speed=%.2f m/s" % [
		hero.get(&"sprinting"), (hero.velocity as Vector3).length()])
	Input.action_release(RUN_ACTION)
	Input.action_release(&"context")
	Input.action_release(&"interact")
	print("RAMP done")


func _park(cam: Camera3D, hero: Node3D, lamp: OmniLight3D) -> void:
	cam.global_position = hero.global_position + SIDE_OFFSET
	cam.look_at(cam.global_position + LOOK_DIR, Vector3.UP)
	lamp.global_position = hero.global_position + Vector3(-2.0, 3.0, 1.0)
