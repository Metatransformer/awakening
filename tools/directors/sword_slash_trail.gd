extends RefCounted
## The ordinary sword trail follows the real LIGHT1/2/3, tap-heavy, and parry
## counter blades. The held charged spin remains the null control.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/sword_slash_trail.gd \
##     --out=/tmp/sword_slash_trail/x.png --warmup=60
##
## Each light step is selected directly through HeroCombat's existing test seam
## and waited out before the next. capture() can outlive the real chain window,
## so attempting to photograph a live three-press chain would make the camera
## break the combo it claims to prove. The null case uses the real held trigger:
## the hold must arm and release a spin without advancing the light serial or
## producing even one neutral ribbon section. Heavy and counter use their real
## input paths so a direct helper call cannot hide a missing gameplay wire.

const MIN_LIVE_SECTIONS := 8


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/sword_slash_trail/x.png").get_base_dir()
	var scene: Node = rig.scene()
	var hero := scene.get_node_or_null(^"Hero") as Hero
	if hero == null:
		rig.fail("SLASH TRAIL no real Hero in training.tscn")
		return
	var combat: HeroCombat = hero.combat
	if combat == null or combat.slash_trail == null:
		rig.fail("SLASH TRAIL HeroCombat did not publish a bound slash_trail")
		return
	var trail: SwordSlashTrail = combat.slash_trail

	# Use the training room's open centre and the real gameplay lens, but park the
	# camera at a stable front-right angle. The normal follow camera can otherwise
	# settle behind the low wall and photograph masonry instead of the blade arc.
	hero.global_position = Vector3(0.0, 0.05, 0.0)
	hero.facing_yaw = 0.0
	await rig.wait_frames(10)
	var camera := hero.get_viewport().get_camera_3d()
	if camera == null:
		rig.fail("SLASH TRAIL no gameplay camera")
		return
	camera.set_physics_process(false)
	camera.global_position = hero.global_position + Vector3(2.4, 1.65, 3.6)
	camera.look_at(hero.global_position + Vector3(0.0, 0.9, 0.0), Vector3.UP)
	await rig.wait_frames(2)

	var first_serial := trail.stroke_serial
	for step in 3:
		await _prove_light(rig, hero, combat, trail, step, out)
	if trail.stroke_serial != first_serial + 3:
		rig.fail("SLASH TRAIL three accepted lights advanced serial %d times, not 3"
			% (trail.stroke_serial - first_serial))
	await _prove_heavy(rig, hero, combat, trail, out)
	await _prove_counter(rig, hero, combat, trail, out)
	if trail.stroke_serial != first_serial + 5:
		rig.fail("SLASH TRAIL lights + heavy + counter advanced serial %d times, not 5"
			% (trail.stroke_serial - first_serial))

	await _prove_spin_control(rig, hero, combat, trail)
	print("SLASH TRAIL done -- serial=%d, %d failed checks"
		% [trail.stroke_serial, rig.fails])


func _prove_light(rig, hero: Hero, combat: HeroCombat, trail: SwordSlashTrail,
		step: int, out: String) -> void:
	Game.stamina = Game.max_stamina
	Bus.stamina_changed.emit(Game.stamina, Game.max_stamina)
	var before := trail.stroke_serial
	# This is the real move path: request_attack, clip, stamina, hitbox and trail.
	# Supplying the step only prevents a PNG write from deciding the combo state.
	combat._light_swing(step)
	if trail.stroke_serial != before + 1:
		rig.fail("SLASH TRAIL LIGHT%d was refused or did not start a stroke" % (step + 1))
		return

	var built: bool = await rig.until(func() -> bool:
		return trail.section_count >= MIN_LIVE_SECTIONS, 1.0)
	if not built:
		rig.fail("SLASH TRAIL LIGHT%d never built %d live sections (got %d)"
			% [step + 1, MIN_LIVE_SECTIONS, trail.section_count])
	else:
		if trail.render_section_count < trail.section_count * 4:
			rig.fail("SLASH TRAIL LIGHT%d rendered only %d sections from %d samples"
				% [step + 1, trail.render_section_count, trail.section_count])
		# One more pose gives the tapered tail time to read while remaining well
		# inside even LIGHT2's active slice.
		await rig.wait_physics_frames(1)
		await rig.capture(out.path_join("light_%d_arc.png" % (step + 1)))

	var finished: bool = await rig.until(func() -> bool:
		return hero.state != Hero.MoveState.ATTACK, 2.0)
	if not finished:
		rig.fail("SLASH TRAIL LIGHT%d never left the real attack state" % (step + 1))
	var cleared: bool = await rig.until(func() -> bool:
		return trail.section_count == 0, 0.5)
	if not cleared:
		rig.fail("SLASH TRAIL LIGHT%d left %d sections past follow-through"
			% [step + 1, trail.section_count])


func _prove_heavy(rig, hero: Hero, combat: HeroCombat, trail: SwordSlashTrail,
		out: String) -> void:
	Game.stamina = Game.max_stamina
	Bus.stamina_changed.emit(Game.stamina, Game.max_stamina)
	var before := trail.stroke_serial
	# A short real trigger pull releases the tap-heavy without arming the spin.
	await rig.tap([&"heavy"])
	# The heavy commits on the RELEASE edge, which the gameplay poller sees on
	# the frame after the rig sends it. Wait for the accepted move, not the send.
	var started: bool = await rig.until(func() -> bool:
		return trail.stroke_serial == before + 1, 0.5)
	if not started:
		rig.fail("SLASH TRAIL accepted tap-heavy did not start a stroke")
		return
	await _capture_special(rig, hero, trail, "heavy", out.path_join("heavy_arc.png"))


func _prove_counter(rig, hero: Hero, combat: HeroCombat, trail: SwordSlashTrail,
		out: String) -> void:
	Game.stamina = Game.max_stamina
	Bus.stamina_changed.emit(Game.stamina, Game.max_stamina)
	var before := trail.stroke_serial
	# Hand over the earned window, then use the real attack mapping. This is the
	# stable director seam parry_dodge uses to isolate the riposte from parry AI.
	combat.set(&"_riposte_t", K.RIPOSTE_WINDOW)
	await rig.tap([&"attack"])
	var started: bool = await rig.until(func() -> bool:
		return trail.stroke_serial == before + 1, 0.5)
	if not started:
		rig.fail("SLASH TRAIL accepted parry counter did not start a stroke")
		return
	if float(combat.get(&"_riposte_t")) > 0.0:
		rig.fail("SLASH TRAIL parry counter did not spend its riposte window")
	await _capture_special(rig, hero, trail, "counter", out.path_join("counter_arc.png"))


func _capture_special(rig, hero: Hero, trail: SwordSlashTrail,
		label: String, path: String) -> void:
	var built: bool = await rig.until(func() -> bool:
		return trail.section_count >= MIN_LIVE_SECTIONS, 1.2)
	if not built:
		rig.fail("SLASH TRAIL %s never built %d live sections (got %d)"
			% [label, MIN_LIVE_SECTIONS, trail.section_count])
	else:
		await rig.wait_physics_frames(1)
		await rig.capture(path)
	var finished: bool = await rig.until(func() -> bool:
		return hero.state != Hero.MoveState.ATTACK, 2.0)
	if not finished:
		rig.fail("SLASH TRAIL %s never left the real attack state" % label)
	var cleared: bool = await rig.until(func() -> bool:
		return trail.section_count == 0, 0.5)
	if not cleared:
		rig.fail("SLASH TRAIL %s left %d sections past follow-through"
			% [label, trail.section_count])


func _prove_spin_control(rig, hero: Hero, combat: HeroCombat,
		trail: SwordSlashTrail) -> void:
	Game.stamina = Game.max_stamina
	Game.fill_magic()
	var before := trail.stroke_serial
	var sections_seen := 0
	await rig.press(&"heavy")
	await rig.wait_seconds(combat.charge_time + 0.20)
	if not combat.charged:
		rig.fail("SLASH TRAIL charged control never armed")
	sections_seen = maxi(sections_seen, trail.section_count)
	if trail.stroke_serial != before:
		rig.fail("SLASH TRAIL held wind-up advanced the light stroke serial")
	rig.release(&"heavy")

	var spin_started: bool = await rig.until(func() -> bool:
		return hero.state == Hero.MoveState.ATTACK, 0.5)
	if not spin_started:
		rig.fail("SLASH TRAIL charged control never released into the real spin")
	# `until` samples every rendered frame through the complete move. A before /
	# after check could miss a forbidden short ribbon born halfway through it.
	var watch: Dictionary = {"max_sections": sections_seen}
	var spin_finished: bool = await rig.until(func() -> bool:
		watch["max_sections"] = maxi(int(watch["max_sections"]), trail.section_count)
		return hero.state != Hero.MoveState.ATTACK, 1.5)
	if not spin_finished:
		rig.fail("SLASH TRAIL charged control never finished the real spin")
	sections_seen = int(watch["max_sections"])
	if trail.stroke_serial != before:
		rig.fail("SLASH TRAIL charged spin advanced the light stroke serial")
	if sections_seen != 0:
		rig.fail("SLASH TRAIL charged hold/spin produced %d ordinary ribbon sections"
			% sections_seen)
