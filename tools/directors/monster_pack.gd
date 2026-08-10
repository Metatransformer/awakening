extends RefCounted
## Do four monsters fight like four monsters, or like one?
##
## The three failures this exists to catch are all invisible in a log and all
## obvious in a frame:
##
##   * **The smear.** Every monster steers at the same point with the same rule,
##     so they converge and stack. Three goblins render as one goblin, and you
##     cannot see which of them is winding up.
##   * **The queue.** They share a cooldown clock and re-close immediately, so
##     the fight is a line taking turns at the front — you only ever fight one.
##   * **The conga line.** Nothing lets go, so a hero who walks the floor
##     collects every monster he has ever seen into the last room.
##
## Spacing is measured as the smallest gap between any two of them, which is the
## number that goes to zero when they stack. The pack is spawned deliberately on
## top of each other, because that is the state the separation rule has to be
## able to dig itself out of.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/monster_pack.gd --out=/tmp/pack/x.png

const KINDS: Array[StringName] = [&"goblin", &"goblin", &"skeleton", &"kobold"]

var _fails: int = 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/pack/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var scene: Node = rig.current_scene
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	hero.global_position = Vector3(0.0, 0.05, 7.0)
	await rig.wait_frames(10)

	# All four inside a 40 cm circle: the worst case, on purpose.
	var pack: Array[Enemy] = []
	for i in KINDS.size():
		var e := Enemy.new()
		e.kind = KINDS[i]
		e.drop_seed = 900 + i
		scene.add_child(e)
		e.global_position = Vector3(0.2 * float(i), 0.05, 0.0)
		pack.append(e)
	await rig.wait_frames(4)

	var spawned := _closest_pair(pack)
	Bus.camera_recenter.emit()
	await rig.wait_frames(30)
	await rig.capture(out.path_join("pack_00_spawned.png"))

	# Let them close on the hero. This is where the smear used to happen.
	await rig.wait_frames(120)
	var engaged := _closest_pair(pack)
	await rig.capture(out.path_join("pack_01_engaged.png"))
	print("PACK spacing spawned=%.2f engaged=%.2f m" % [spawned, engaged])
	# Bodies are 0.44-0.7 m across. Under half a metre they are inside each other.
	if engaged < 0.5:
		_fail("the pack stacked: closest pair is %.2f m, they are inside each other"
			% engaged)

	# Are they AROUND him or lined up in front of him? Measured as the spread of
	# bearings from the hero: four monsters queueing all sit on one bearing.
	var spread := _bearing_spread(hero, pack)
	print("PACK bearing spread=%.0f deg" % rad_to_deg(spread))
	if spread < deg_to_rad(45.0):
		_fail("the pack queued: all four are within %.0f deg of one bearing"
			% rad_to_deg(spread))

	# Did anyone actually get a swing in? A pack that spaces beautifully and
	# never commits is a worse fight than the one it replaced.
	var committed := 0
	for e in pack:
		if e.state == Enemy.State.WINDUP or e.state == Enemy.State.STRIKE \
				or e.state == Enemy.State.RECOVER or e.state == Enemy.State.CIRCLE:
			committed += 1
	print("PACK in a fighting state=%d/%d" % [committed, pack.size()])
	if committed == 0:
		_fail("nobody engaged: four monsters spent 120 frames not fighting")

	await rig.wait_frames(90)
	await rig.capture(out.path_join("pack_02_circling.png"))

	# --- the leash ----------------------------------------------------------
	# Walk the hero out of the world and see whether they go home. A monster that
	# stands where the chase ended is how a cleared room refills with other
	# rooms' monsters standing in the doorways.
	#
	# Measured as PROGRESS, not arrival: they walk home at 55% of their speed, so
	# a skeleton covers 1.2 m/s and an arrival test would just be a test of how
	# long this director is willing to wait. Letting go and setting off is the
	# behaviour; the rest is arithmetic.
	var anchors: Array[Vector3] = []
	for e in pack:
		anchors.append(e._anchor)
	hero.global_position = Vector3(0.0, 0.05, 60.0)
	await rig.wait_frames(20)
	var left := _homes(pack, anchors)
	await rig.wait_frames(180)
	var now := _homes(pack, anchors)

	var strays := 0
	for i in pack.size():
		if not is_instance_valid(pack[i]):
			continue
		# Either it is already home, or it is measurably closer than it was.
		if now[i] > 2.0 and now[i] > left[i] - 1.0:
			strays += 1
		if pack[i].state != Enemy.State.IDLE:
			strays += 1
	print("PACK home %.1f -> %.1f / %.1f -> %.1f / %.1f -> %.1f / %.1f -> %.1f m"
		% [left[0], now[0], left[1], now[1], left[2], now[2], left[3], now[3]])
	if strays > 0:
		_fail("%d monsters never let go -- the leash does not hold" % strays)

	# A monster that has stopped fighting must not still be lit. The wind-up glow
	# is written every frame and has no timer of its own, so every way OUT of a
	# wind-up has to take it back down -- and a wind-up that got abandoned rather
	# than completed is the exit that gets forgotten. It shows up as a body
	# glowing hot in a room where nothing is happening.
	#
	# Checked HERE, while the hero is still away, and not after he comes back: a
	# monster that has re-engaged may legitimately be mid-telegraph, and a beat
	# that fails on the feature working is worse than no beat at all.
	for i in pack.size():
		if not is_instance_valid(pack[i]):
			continue
		var lit := _emission(pack[i])
		print("PACK %s state=%d emission=%.2f" % [KINDS[i], pack[i].state, lit])
		if lit > 0.05:
			_fail("a %s is still glowing (%.2f) with nothing to fight"
				% [KINDS[i], lit])

	hero.global_position = Vector3(0.0, 0.05, 7.0)
	Bus.camera_recenter.emit()
	await rig.wait_frames(40)
	await rig.capture(out.path_join("pack_03_gone_home.png"))

	if _fails == 0:
		print("PACK OK")


## How far each of the pack is from where it woke up.
func _homes(pack: Array[Enemy], anchors: Array[Vector3]) -> Array[float]:
	var out: Array[float] = []
	for i in pack.size():
		if not is_instance_valid(pack[i]):
			out.append(0.0)
			continue
		out.append(K.plane(pack[i].global_position - anchors[i]).length())
	return out


## The smallest gap between any two of the pack. This is the number that goes to
## zero when they stack, which an average over all pairs would hide.
func _closest_pair(pack: Array[Enemy]) -> float:
	var best := INF
	for i in pack.size():
		for j in range(i + 1, pack.size()):
			if not is_instance_valid(pack[i]) or not is_instance_valid(pack[j]):
				continue
			var d := K.plane(pack[i].global_position - pack[j].global_position)
			best = minf(best, d.length())
	return best if best < INF else 0.0


## How wide an arc, seen from the hero, the pack occupies. Four monsters queueing
## up in front of him all sit on the same bearing and this collapses toward zero;
## four monsters surrounding him spread it out toward a full turn.
func _bearing_spread(hero: Node3D, pack: Array[Enemy]) -> float:
	var angles: Array[float] = []
	for e in pack:
		if not is_instance_valid(e):
			continue
		var d := K.plane(e.global_position - hero.global_position)
		if d != Vector3.ZERO:
			angles.append(atan2(d.x, d.z))
	if angles.size() < 2:
		return 0.0
	angles.sort()
	# The widest EMPTY wedge is the one that is not covered; what the pack
	# occupies is the rest of the circle. Doing it this way rather than
	# max-minus-min is what keeps a pack straddling the -PI/+PI seam from
	# reporting a near-full spread when it is really all bunched on one side.
	# Annotated because Array.back()/front() return Variant and the subtraction
	# inherits that -- an inferred `:=` here is a parse error, not a warning.
	var widest_gap: float = TAU - (float(angles.back()) - float(angles.front()))
	for i in range(1, angles.size()):
		widest_gap = maxf(widest_gap, angles[i] - angles[i - 1])
	return TAU - widest_gap


## The hottest emission on any surface of the body. Reads the per-surface
## OVERRIDES, because that is the only level `HitFlash` writes at.
func _emission(body: Node) -> float:
	var peak := 0.0
	for node in body.find_children("*", "MeshInstance3D", true, false):
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
	print("PACK FAIL %s" % msg)
