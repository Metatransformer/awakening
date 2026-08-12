extends RefCounted
## Airborne dodge and grounded-only guard, exercised through the live inputs.
##
## The first beat jumps, waits for the body to leave the floor, then presses the
## existing dodge while a full movement direction is held. The second starts
## with a real grounded guard and holds that same input through takeoff and
## landing. Every wait is on the state being proved, with a bounded game-time
## deadline; no refresh-rate-dependent frame count stands in for behavior.
##
##   timeout 400 tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/airborne_dodge_guard.gd \
##     --out=/tmp/air-dodge/x.png

## Hero.MoveState, which is not reachable by name from a RefCounted director.
const ST_GROUND := 0
const ST_ROLL := 2


func run(rig) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_release_inputs()

	var hero := rig.get_first_node_in_group(&"player") as Hero
	if not rig.check(hero != null, "AIR DODGE/GUARD no hero in group `player`"):
		return
	var combat := hero.combat as HeroCombat
	if not rig.check(combat != null, "AIR DODGE/GUARD hero has no combat component"):
		return

	var grounded: bool = await rig.until(func() -> bool:
		return hero.is_on_floor() and int(hero.state) == ST_GROUND, 2.0)
	if not rig.check(grounded, "AIR DODGE/GUARD hero never settled on the training floor"):
		return

	var out: String = rig.arg("out", "/tmp/air-dodge/x.png").get_base_dir()
	await _prove_airborne_roll(rig, hero, out)
	await _prove_airborne_guard_drop(rig, hero, combat, out)
	_release_inputs()

	if rig.fails == 0:
		print("AIR DODGE/GUARD OK")


func _prove_airborne_roll(rig, hero: Hero, out: String) -> void:
	Game.stamina = Game.max_stamina
	Input.action_press(&"jump")
	var airborne: bool = await rig.until(func() -> bool:
		return not hero.is_on_floor(), 1.0)
	Input.action_release(&"jump")
	if not rig.check(airborne, "AIR DODGE jump never left the floor"):
		return

	# Full deflection is load-bearing: the ordinary free dodge still requires a
	# committed direction, in the air exactly as it does on the ground.
	Input.action_press(&"move_up", 1.0)
	Input.action_press(&"context")
	var rolled_in_air: bool = await rig.until(func() -> bool:
		return int(hero.state) == ST_ROLL and not hero.is_on_floor(), 0.6)
	Input.action_release(&"context")
	if not rig.check(rolled_in_air,
			"AIR DODGE committed airborne press never entered MoveState.ROLL"):
		Input.action_release(&"move_up")
		return

	# Let the roll animation become legible without surrendering the behavioral
	# proof: the next assertion still requires both the roll state and open air.
	await rig.wait_seconds(0.08)
	if not rig.check(int(hero.state) == ST_ROLL and not hero.is_on_floor(),
			"AIR DODGE left the roll or landed before the mid-air capture"):
		Input.action_release(&"move_up")
		return
	_frame_camera(hero)
	await rig.capture(out.path_join("airborne_dodge_midair_roll.png"))
	rig.check(int(hero.state) == ST_ROLL and not hero.is_on_floor(),
		"AIR DODGE left the roll or landed before the mid-air capture")
	Input.action_release(&"move_up")

	var recovered_on_floor: bool = await rig.until(func() -> bool:
		return hero.is_on_floor() and int(hero.state) == ST_GROUND, 3.0)
	rig.check(recovered_on_floor,
		"AIR DODGE did not preserve the existing landing/recovery path")


func _prove_airborne_guard_drop(rig, hero: Hero, combat: HeroCombat,
		out: String) -> void:
	if not rig.check(hero.is_on_floor() and int(hero.state) == ST_GROUND,
			"AIR GUARD beat started before the airborne dodge recovered"):
		return

	Input.action_press(&"shield")
	var raised: bool = await rig.until(func() -> bool:
		return hero.is_on_floor() and combat.blocking, 0.6)
	if not rig.check(raised, "AIR GUARD held shield never raised guard on the floor"):
		Input.action_release(&"shield")
		return

	Input.action_press(&"jump")
	var airborne: bool = await rig.until(func() -> bool:
		return not hero.is_on_floor(), 1.0)
	Input.action_release(&"jump")
	if not rig.check(airborne, "AIR GUARD guarded jump never left the floor"):
		Input.action_release(&"shield")
		return

	var dropped: bool = await rig.until(func() -> bool:
		return not hero.is_on_floor() and not combat.blocking, 0.25)
	if not rig.check(dropped, "AIR GUARD blocking did not drop on takeoff"):
		Input.action_release(&"shield")
		return

	_frame_camera(hero)
	await rig.capture(out.path_join("airborne_guard_shield_down.png"))
	rig.check(not hero.is_on_floor() and not combat.blocking,
		"AIR GUARD was not airborne with the shield down at capture time")

	var guard_rose_in_air := false
	var landed: bool = await rig.until(func() -> bool:
		if not hero.is_on_floor():
			guard_rose_in_air = guard_rose_in_air or combat.blocking
			return false
		return true, 2.0)
	rig.check(not guard_rose_in_air,
		"AIR GUARD held shield raised blocking again before landing")
	if not rig.check(landed, "AIR GUARD hero never landed while shield remained held"):
		Input.action_release(&"shield")
		return

	var resumed: bool = await rig.until(func() -> bool:
		return hero.is_on_floor() and combat.blocking, 0.6)
	rig.check(resumed, "AIR GUARD held guard did not return after landing")
	Input.action_release(&"shield")


## Park a readable three-quarter view only after the measured state is live, so
## changing the camera cannot influence the direction used to start the dodge.
func _frame_camera(hero: Hero) -> void:
	var camera := hero.get_viewport().get_camera_3d()
	if camera == null:
		return
	camera.set_physics_process(false)
	var facing: float = hero.facing_yaw
	var forward := Vector3(sin(facing), 0.0, cos(facing))
	var right := Vector3(-forward.z, 0.0, forward.x)
	camera.global_position = hero.global_position - forward * 3.4 + right * 1.6 \
		+ Vector3.UP * 1.7
	camera.look_at(hero.global_position + Vector3.UP * 0.9, Vector3.UP)


func _release_inputs() -> void:
	for action in [&"jump", &"context", &"move_up", &"shield"]:
		Input.action_release(action)
