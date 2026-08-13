extends RefCounted
## Does a blow READ? Spawns a monster in the lit courtyard, hits it with the same
## DamageArea the hero swings, and both photographs and measures what comes back.
##
## Two halves, because impact is two different problems:
##
##   * **Struck** -- the monster is frozen so the camera can hold still on it and
##     the flash and the recoil can be looked at. Physics off, feedback on.
##   * **Striking** -- the monster is let loose to chase the hero down and hit
##     him, which is the only way to see the wind-up tell and the damage
##     vignette.
##
## The numeric beats print `FEEL FAIL ...` because half of impact has no pixels:
## whether the damage landed, whether time actually stopped, whether the camera
## actually moved, whether the stop ever lifted. That last one matters most --
## a hit-stop that fails to lift is not a missing effect, it is the game hung.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/monster_feel.gd --out=/tmp/feel/x.png

## How much image a unit of `Camera3D.h_offset` is worth, at 1280x720 and this
## project's FOV. Measured by rendering the same shot at several offsets and
## cross-correlating them -- see `_shake_scale`, which still emits those frames.
const PX_PER_OFFSET := 37.5

var _fails: int = 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/feel/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	await _struck(rig, out)
	await _striking(rig, out)
	await _shake_scale(rig, out)

	if _fails == 0:
		print("FEEL OK")


## What the shake actually looks like, as a picture rather than as arithmetic.
##
## Every number in the shake is a fraction of a fraction -- trauma is squared,
## multiplied by a noise sample that is rarely near 1, and decaying the whole
## time -- so "peak offset 0.017 of a possible 0.16" is not a thing anyone can
## judge from the log. These three frames are the same shot at rest, at a landed
## blow's trauma, and at the ceiling, so the threshold below them is set by
## looking rather than by guessing.
func _shake_scale(rig, out: String) -> void:
	var cam := rig.root.get_viewport().get_camera_3d() as Camera3D
	if cam == null:
		return
	await rig.wait_frames(30)

	# Feel and the scene BOTH have to be held still for this to be an A/B.
	#
	# The tree is paused so the three frames differ by the offset and nothing
	# else -- otherwise the orc walks between shots and the comparison is of two
	# different pictures. And `Feel` is disabled outright, because it is
	# PROCESS_MODE_ALWAYS and its shake tick zeroes h_offset/v_offset on every
	# idle frame where there is no trauma. Writing the camera directly with Feel
	# still running produced three identical frames: the write happened after the
	# draw, and Feel wiped it before the next one.
	var was := Feel.process_mode
	Feel.process_mode = Node.PROCESS_MODE_DISABLED
	rig.paused = true

	for shot in [{"n": "feel_10_rest", "o": 0.0},
			{"n": "feel_11_hit", "o": 0.15},
			{"n": "feel_12_full", "o": Feel.MAX_OFFSET}]:
		cam.h_offset = float(shot["o"])
		cam.v_offset = float(shot["o"]) * 0.6
		await rig.capture(out.path_join(String(shot["n"]) + ".png"))

	cam.h_offset = 0.0
	cam.v_offset = 0.0
	rig.paused = false
	Feel.process_mode = was


# --- Half one: the monster takes a blow --------------------------------------

func _struck(rig, out: String) -> void:
	var scene: Node = rig.current_scene
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]

	# Off to one side and turned in, so the camera sits over the hero's shoulder
	# with the monster beside him rather than directly behind his back. A shot of
	# the hero's coat is not a shot of a hit-flash.
	hero.global_position = Vector3(-2.6, 0.05, 4.2)
	await rig.wait_frames(8)

	var foe := Enemy.new()
	foe.kind = &"skeleton"
	foe.drop_seed = 4242
	scene.add_child(foe)
	foe.global_position = Vector3(1.4, 0.05, 0.0)

	# A SECOND skeleton, and it is the whole point of HitFlash existing. A GLB is
	# loaded once and every instance shares the loaded mesh's materials, so the
	# obvious way to write a hit-flash lights up every skeleton in the room at
	# once -- and the dungeon spawns three of a kind per room, so the tell built
	# to make one enemy readable would make the room unreadable. This one stands
	# there and gets hit by nothing; if it glows, the isolation is broken.
	var bystander := Enemy.new()
	bystander.kind = &"skeleton"
	bystander.drop_seed = 4243
	scene.add_child(bystander)
	bystander.global_position = Vector3(4.6, 0.05, -1.0)
	await rig.wait_frames(24)
	bystander.set_physics_process(false)

	# Frozen: this half is about what a struck body LOOKS like, and a skeleton
	# walking into the lens mid-flash photographs its own approach instead. The
	# flash and the recoil are tweens, so they still play with physics off.
	foe.set_physics_process(false)
	Bus.camera_recenter.emit()
	await rig.wait_frames(34)
	await rig.capture(out.path_join("feel_00_before.png"))

	# The damage path itself. Not "did a signal fire" -- did the health number
	# move. Everything else here is feedback ABOUT a blow, and feedback about a
	# blow that never landed is the failure that hides every other failure.
	var before: int = foe.health.health_points
	_strike(foe, 2)
	await rig.wait_frames(2)
	if foe.health.health_points >= before:
		_fail("the blow did not land: health stayed at %d" % before)
	else:
		print("FEEL hit %d -> %d HP" % [before, foe.health.health_points])

	# Did the world stop, and did the camera move? Both are read one frame after
	# the blow, which is where a player would feel them.
	if Engine.time_scale > 0.0:
		_fail("no hit-stop: Engine.time_scale is %.2f a frame after impact"
			% Engine.time_scale)
	# Sampled at frame_post_draw, which is the only moment the camera holds the
	# values the player actually saw. `GameCamera` works in _physics_process and
	# ends on `look_at`, which rebuilds the whole basis -- so anywhere else in the
	# frame the ROLL reads as exactly zero while the offsets, which look_at does
	# not touch, still hold. Reading it at an arbitrary idle point reported a dead
	# roll on a shake that was rendering fine.
	# Every impact number is a PEAK over one window, sampled together.
	#
	# Peaks, because a shake is a noise field: any single frame can land on a zero
	# crossing and read as no shake at all. "Is there a shake" and "can you feel
	# it" are different questions and only the second one matters.
	#
	# Together, because these effects overlap and each one's window is short. A
	# 20-frame loop added to measure the shake spent the flash's entire 0.17 s
	# before the flash was read, and reported a hit-flash of 0.000 on a flash that
	# was working -- a director that breaks the thing it is measuring.
	var cam := rig.root.get_viewport().get_camera_3d() as Camera3D
	if cam == null:
		_fail("no 3D camera to shake")
	var peak_off := 0.0
	var peak_roll := 0.0
	var want_roll := 0.0
	var lit := 0.0
	var other := 0.0
	for i in 20:
		await RenderingServer.frame_post_draw
		if cam != null:
			peak_off = maxf(peak_off, absf(cam.h_offset) + absf(cam.v_offset))
			peak_roll = maxf(peak_roll, absf(cam.rotation.z))
			want_roll = maxf(want_roll, absf(Feel._roll))
		lit = maxf(lit, _emission(foe))
		other = maxf(other, _emission(bystander))

	if cam != null:
		# Reported in PIXELS, because that is the only unit anyone can judge.
		# `h_offset` is a frustum shift whose magnitude means nothing on its own --
		# the first version of this beat passed a shake of 0.6 px because 0.017 of
		# a possible 0.16 sounds like a tenth of something.
		var px := peak_off * PX_PER_OFFSET
		print("FEEL shake peak offset=%.4f (%.1f px) roll=%.4f (wanted %.4f)"
			% [peak_off, px, peak_roll, want_roll])
		if peak_off <= 0.0001:
			_fail("no shake: the camera did not move on impact")
		# **This threshold used to be 3.0 px and it was measuring a design that
		# no longer exists.** `_strike` below lands a JAB (`K.KNOCKBACK_LIGHT`),
		# and when this was written every blow in the game asked Feel for a flat
		# 0.52 trauma regardless of weight -- so a jab moved the image as far as
		# the spin did, and 3 px was a fair bar for "a landed blow".
		#
		# The shake is scaled by the blow now (`K.SHAKE_TAP`), because trauma
		# ACCUMULATES and three jabs inside 1.2 s were pinning the camera at
		# maximum on the cheapest attack available. A jab is deliberately a
		# twitch: 0.26 trauma, ~1.2 px, a quarter of what it was.
		#
		# So what this beat still owns is that the twitch EXISTS -- a shake that
		# has been reeled all the way to nothing is the regression this catches,
		# and the first cut of the change did exactly that at 0.4 px. The LADDER
		# (jab < committed < crit) is asserted in `monster_launch.gd`, which
		# lands one of each and compares them.
		#
		# The bar is LOW and it has to be, because this number is noisy across
		# runs in a way the old 3 px one was too big to notice: `_tick_shake`
		# walks a free-running noise field every frame, so the peak a 20-frame
		# window happens to catch off the same 0.26 trauma measures anywhere from
		# 0.4 px to 1.2 px depending on where in the field the blow landed. A
		# threshold set near the value would fail on a coin flip. What is being
		# caught here is the camera not moving AT ALL.
		elif px < 0.2:
			_fail("the shake is gone: a jab moves the image %.2f px" % px)
		if peak_roll <= 0.00001:
			_fail("no roll: the camera shook but never tilted --"
				+ " look_at is winning the frame")

	# Did the body actually go white, and did it go white ALONE?
	if lit <= 0.01:
		_fail("no hit-flash: the struck body's emission is %.3f" % lit)
	else:
		print("FEEL flash struck=%.2f bystander=%.2f" % [lit, other])
	if other > 0.01:
		_fail("the flash leaked: an unhit skeleton lit up at %.3f too --"
			% other + " the GLB's materials are shared, not per-instance")

	await rig.capture(out.path_join("feel_01_impact.png"))
	await rig.wait_frames(5)
	await rig.capture(out.path_join("feel_02_flash.png"))
	await rig.wait_frames(12)
	await rig.capture(out.path_join("feel_03_recoil.png"))

	# And did it lift? A stop that never ends is a hung game, so this is measured
	# on the wall clock rather than in frames -- frames are what stopped.
	var waited := 0
	while Engine.time_scale <= 0.0 and waited < 120:
		await rig.wait_frames(1)
		waited += 1
	if Engine.time_scale <= 0.0:
		_fail("the hit-stop never lifted -- time_scale is still 0 after 120 frames")

	await rig.wait_frames(40)
	await rig.capture(out.path_join("feel_04_settled.png"))
	var cam2 := rig.root.get_viewport().get_camera_3d() as Camera3D
	if cam2 != null and absf(cam2.h_offset) + absf(cam2.v_offset) > 0.002:
		_fail("the shake never settled: offset is still %.4f"
			% (absf(cam2.h_offset) + absf(cam2.v_offset)))

	foe.queue_free()
	bystander.queue_free()
	await rig.wait_frames(4)


# --- Half two: the monster lands one ------------------------------------------

func _striking(rig, out: String) -> void:
	var scene: Node = rig.current_scene
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	hero.global_position = Vector3(0.0, 0.05, 5.0)
	await rig.wait_frames(10)

	var foe := Enemy.new()
	foe.kind = &"orc"
	foe.drop_seed = 77
	scene.add_child(foe)
	foe.global_position = Vector3(0.0, 0.05, -1.5)
	Bus.camera_recenter.emit()
	await rig.wait_frames(30)

	var hp_before: int = Game.health_points
	# Photograph the wind-up on its way through. The orc's is the longest in the
	# roster (0.62 s) precisely so it can be read, so if the tell is invisible it
	# is invisible here first.
	var saw_windup := false
	for i in 260:
		await rig.wait_frames(1)
		if not saw_windup and foe.state == Enemy.State.WINDUP:
			saw_windup = true
			# Late in the commit, not on the frame it starts. The lean is eased
			# so most of it is in the last third -- capturing frame one of the
			# wind-up photographs a monster standing perfectly still and proves
			# nothing, which is exactly what the first pass of this director did.
			await rig.wait_frames(22)
			await rig.capture(out.path_join("feel_05_windup.png"))
		if Game.health_points < hp_before:
			break

	if not saw_windup:
		_fail("the orc never wound up -- it closed and never committed")
	if Game.health_points >= hp_before:
		_fail("the orc never landed a blow on the hero in 260 frames")
	else:
		print("FEEL hero %d -> %d HP" % [hp_before, Game.health_points])
		await rig.capture(out.path_join("feel_06_hero_hurt.png"))

	await rig.wait_frames(30)
	await rig.capture(out.path_join("feel_07_after.png"))


## Swing at `foe` the way the hero does: a DamageArea, activated for a window.
## Reaching past DamageArea into HealthComponent.apply_hit would prove the health
## maths and skip the exact link that was broken.
func _strike(foe: Node3D, amount: int) -> void:
	var box := DamageArea.new()
	box.collision_layer = K.L_PLAYER_HITBOX
	box.collision_mask = K.L_ENEMY
	box.amount = amount
	box.kind = &"sword"
	box.knockback = K.KNOCKBACK_LIGHT
	box.stun = 0.2
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.4
	col.shape = sphere
	box.add_child(col)
	foe.get_parent().add_child(box)
	box.global_position = foe.global_position + Vector3.UP * 0.9
	box.activate()


## The brightest emission on any surface of `body`. Reads the surface OVERRIDE
## rather than the active material, because the override is exactly the thing
## HitFlash installs to keep one body's reaction to itself -- checking the shared
## material would report the same number for every skeleton and quietly agree
## with itself.
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
	print("FEEL FAIL %s" % msg)
