extends RefCounted
## The charged release is a SPIN. Does it actually cut a circle, and does it
## look like one?
##
## p4_charge.gd already proves the hold: that a tap still swings immediately,
## that a short hold is just a tap, and that a long hold arms and pays out a
## bigger blow. None of that says anything about the direction the blow goes in,
## and "the charged attack is a 360" is precisely a claim about direction. A
## spin that hits only what a light swing would have hit passes every one of
## p4_charge's checks.
##
## So this director builds the one situation that can tell them apart: THREE
## posts, one in front, one on the flank, one directly behind, all at the same
## distance. Then:
##
##   1. A tap hits the post in FRONT and nothing else. If the light swing has
##      quietly inherited the spin's 360 box — which is exactly what a shared
##      `arc_degrees` would do — this is the beat that catches it.
##   2. A charged release hits ALL THREE. That is the feature, and the post
##      BEHIND him is the whole point of it.
##   3. The blade takes on light across the hold, and gives it back after.
##      Photographed, because a glow that only exists in a tween is a glow
##      nobody has looked at.
##
## The posts are MOVED rather than a new scene being authored. training.tscn
## puts three of them at arbitrary bearings for a lock-on range test, and what
## this needs is a ring — placing them here keeps one fixture instead of two.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/spin_attack.gd --out=/tmp/spin/x.png
##
## NEVER pass --headless. There is no rendering device and every frame comes out
## empty, silently (CLAUDE.md §2).

## Where each post is put, as a bearing in degrees off the hero's facing, and how
## far out. 1.5 m sits inside the spin's 2.1 m reach and outside the light
## swing's forward box, so the only thing that decides whether a post is struck
## is the DIRECTION the blow is credited with.
const RING := 1.5
const BEARINGS := {"PostA": 0.0, "PostB": 95.0, "PostC": 180.0}

## Past chain_window and past the tail of the longest swing, so every measured
## press starts the chain at step one. Same reasoning as p4_charge's LAPSE.
const LAPSE := 1.6

## amount per post name, appended as they are struck.
var _hits: Dictionary = {}


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/spin/x.png").get_base_dir()
	var scene: Node = rig.scene()
	var fails := 0

	var hero: Node3D = scene.get_node_or_null(^"Hero") as Node3D
	if hero == null:
		print("SPIN FAIL no Hero in the scene")
		return
	# The hero owns its combat node and publishes it; do not go fishing in the
	# scene tree for it (docs/CONTRACT.md §8).
	var combat: Node = hero.get(&"combat")
	if combat == null:
		print("SPIN FAIL no HeroCombat on the Hero")
		return

	await rig.wait_frames(24)

	# PLACE the hero rather than walking him here. A director measuring the swing
	# must not also be measuring the pathing.
	#
	# facing_yaw is the HEADING yaw (docs/CONTRACT.md §2.5): heading is
	# (sin y, 0, cos y), so PI is heading (0,0,-1) and the hero faces -Z.
	var centre := Vector3(0.0, 0.05, 0.0)
	hero.global_position = centre
	hero.set(&"facing_yaw", PI)
	await rig.wait_frames(10)

	var posts := {}
	for name in BEARINGS:
		var post: Node3D = scene.get_node_or_null(NodePath(name)) as Node3D
		if post == null:
			print("SPIN FAIL no %s to hit" % name)
			fails += 1
			continue
		# Bearing 0 is the hero's facing, which is -Z. Rotating that vector about
		# UP by the bearing puts each post on the ring at a known angle off his
		# nose — so "behind" is a measured 180, not a guess at a coordinate.
		var dir := Vector3(0.0, 0.0, -1.0).rotated(Vector3.UP, deg_to_rad(BEARINGS[name]))
		post.global_position = centre + dir * RING
		post.connect(&"struck", _on_struck.bind(name))
		posts[name] = post
		_hits[name] = []
	if posts.size() < 3:
		print("SPIN FAIL only %d posts placed" % posts.size())
		return

	await rig.wait_frames(20)
	for name in posts:
		var p: Node3D = posts[name]
		print("SPIN placed %s at %.0f deg, %.2f m" % [
			name, BEARINGS[name], hero.global_position.distance_to(p.global_position)])
	await rig.capture(out.path_join("s_00_ring.png"))

	var charge_time: float = float(combat.get(&"charge_time"))

	# --- 1. the tap. Front only. ---------------------------------------------
	_clear()
	await rig.tap(["attack"])
	await rig.wait_seconds(LAPSE)
	var tap_front := _struck("PostA")
	var tap_side := _struck("PostB")
	var tap_back := _struck("PostC")
	await rig.capture(out.path_join("s_01_after_tap.png"))
	await rig.wait_seconds(LAPSE)

	# --- 2. the charge, photographed ------------------------------------------
	# The sheet cannot also be the thing that times the swing: capture() stalls
	# the frame clock. The measured release is a separate hold, below.
	_clear()
	# `heavy`, not `attack`. The wind-up moved to the trigger when the sword grew
	# a second button, and this director was left holding RB — which charges
	# nothing now, so the sheet was four frames of an unlit sword and the release
	# was a light swing. Beat 1 above stays on `attack` deliberately: the thing it
	# is checking is that the LIGHT chain has not inherited the spin's 360 box.
	Input.action_press(&"heavy")
	# Wait on the ARMED FLAG, never on a frame count. capture() stalls the frame
	# clock, so 20 frames of waiting is not 20/60 of a second of holding — the
	# first version of this beat photographed four frames of an unlit sword and
	# then released, and the whole contact sheet was of a charge that never
	# happened. The loop keeps shooting until the flag comes up.
	var lit := false
	for i in 10:
		await rig.wait_frames(6)
		await rig.capture(out.path_join("s_02_charge_%d.png" % i))
		lit = bool(combat.get(&"charged"))
		if lit:
			break
	Input.action_release(&"heavy")
	for i in 6:
		await rig.wait_frames(4)
		await rig.capture(out.path_join("s_03_spin_%d.png" % i))
	await rig.wait_seconds(LAPSE)
	await rig.capture(out.path_join("s_04_after.png"))
	await rig.wait_seconds(LAPSE)

	# --- 3. the release, measured ---------------------------------------------
	_clear()
	await rig.hold_seconds(["heavy"], charge_time + 0.35)
	# Long enough for a 0.90 s spin to open its window, sweep, and close it.
	await rig.wait_seconds(1.8)
	var spin_front := _struck("PostA")
	var spin_side := _struck("PostB")
	var spin_back := _struck("PostC")
	var spin_dmg := _damage("PostC")

	print("SPIN tap    front=%s side=%s back=%s" % [tap_front, tap_side, tap_back])
	print("SPIN charged release front=%s side=%s back=%s (back took %d quarter-hearts)"
		% [spin_front, spin_side, spin_back, spin_dmg])

	# The tap. Front and nothing else -- this is the beat that catches the spin's
	# 360 leaking into the light chain.
	if not tap_front:
		print("SPIN FAIL the tap never reached the post in front of him"); fails += 1
	if tap_side or tap_back:
		print("SPIN FAIL a LIGHT swing hit side=%s back=%s — the light chain has the spin's arc"
			% [tap_side, tap_back]); fails += 1

	if not lit:
		print("SPIN FAIL the photographed hold never armed — the sheet shows nothing"); fails += 1

	# The spin. All three, and the one BEHIND him is the whole feature.
	if not spin_front:
		print("SPIN FAIL the spin missed the post in front"); fails += 1
	if not spin_side:
		print("SPIN FAIL the spin missed the post on the flank"); fails += 1
	if not spin_back:
		print("SPIN FAIL the spin missed the post BEHIND him — it is not a 360"); fails += 1
	if spin_dmg > 0 and spin_dmg <= 2 * K.QUARTER:
		print("SPIN FAIL the post behind took %d, no more than a light swing's %d"
			% [spin_dmg, 2 * K.QUARTER]); fails += 1

	# --- 4. the arc, from where you can actually see it ------------------------
	# The game camera rides just over his shoulder, which is the right place to
	# play from and a useless place to judge a circle from: at two metres the arc
	# leaves frame on both sides and every shot above shows two fragments of blue.
	# So the last beat pulls up and back. This is a LOOKDEV pass and nothing is
	# asserted about it — the frames are the output.
	await rig.wait_seconds(LAPSE)
	var cam := hero.get_viewport().get_camera_3d()
	if cam != null:
		# GameCamera IS the Camera3D and re-derives its transform every physics
		# frame, so placing it and waiting places it nowhere.
		cam.set_physics_process(false)
		cam.global_position = centre + Vector3(0.0, 4.2, 4.6)
		cam.look_at(centre + Vector3(0.0, 0.6, 0.0), Vector3.UP)
	_clear()
	await rig.hold_seconds(["heavy"], charge_time + 0.35)
	for i in 8:
		await rig.wait_frames(3)
		await rig.capture(out.path_join("s_05_arc_%d.png" % i))

	print("SPIN %s (fails=%d)" % ["OK" if fails == 0 else "FAIL", fails])


func _on_struck(amount: int, _from: Vector3, name: String) -> void:
	(_hits[name] as Array).append(amount)


func _clear() -> void:
	for name in _hits:
		(_hits[name] as Array).clear()


func _struck(name: String) -> bool:
	return not (_hits.get(name, []) as Array).is_empty()


## What `name` took, summed. Read off the `struck` signal rather than the post's
## own `total_damage`: the post clears its running total after 4 s of quiet, and
## this director both holds buttons for a second at a time and writes a contact
## sheet to disk. p4_combo found that the hard way and reported a swing dealing
## -2.
func _damage(name: String) -> int:
	var total := 0
	for a in (_hits.get(name, []) as Array):
		total += int(a)
	return total
