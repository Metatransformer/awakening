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
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/town.tscn \
##     --director=res://tools/directors/monster_feel.gd --out=/tmp/feel/x.png

var _fails: int = 0


func run(rig) -> void:
	var out: String = rig.arg("out", "/tmp/feel/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	await _struck(rig, out)
	await _striking(rig, out)

	if _fails == 0:
		print("FEEL OK")


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
	await rig.wait_frames(24)

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
	var before: int = foe.health.quarters
	_strike(foe, 2)
	await rig.wait_frames(2)
	if foe.health.quarters >= before:
		_fail("the blow did not land: health stayed at %d" % before)
	else:
		print("FEEL hit %d -> %d quarters" % [before, foe.health.quarters])

	# Did the world stop, and did the camera move? Both are read one frame after
	# the blow, which is where a player would feel them.
	if Engine.time_scale > 0.0:
		_fail("no hit-stop: Engine.time_scale is %.2f a frame after impact"
			% Engine.time_scale)
	var cam := rig.root.get_viewport().get_camera_3d() as Camera3D
	if cam == null:
		_fail("no 3D camera to shake")
	else:
		var moved := absf(cam.h_offset) + absf(cam.v_offset) + absf(cam.rotation.z)
		if moved <= 0.0001:
			_fail("no shake: the camera did not move on impact")
		else:
			print("FEEL shake offset=%.4f roll=%.4f"
				% [absf(cam.h_offset) + absf(cam.v_offset), cam.rotation.z])

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

	var hp_before: int = Game.quarters
	# Photograph the wind-up on its way through. The orc's is the longest in the
	# roster (0.62 s) precisely so it can be read, so if the tell is invisible it
	# is invisible here first.
	var saw_windup := false
	for i in 260:
		await rig.wait_frames(1)
		if not saw_windup and foe.state == Enemy.State.WINDUP:
			saw_windup = true
			await rig.capture(out.path_join("feel_05_windup.png"))
		if Game.quarters < hp_before:
			break

	if not saw_windup:
		_fail("the orc never wound up -- it closed and never committed")
	if Game.quarters >= hp_before:
		_fail("the orc never landed a blow on the hero in 260 frames")
	else:
		print("FEEL hero %d -> %d quarters" % [hp_before, Game.quarters])
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


func _fail(msg: String) -> void:
	_fails += 1
	print("FEEL FAIL %s" % msg)
