extends RefCounted
## Does the hookshot freeze a monster, and does the freeze READ?
##
## The change under test is three facts that have to hold together, and only one
## of them is visible in a boolean:
##
##   * The chain BITES a body. It did not, for as long as the hookshot was purely
##     a traversal item — `L_ENEMY` was missing from its raycast mask, so the head
##     flew through a skeleton's ribcage and stuck in the wall behind it. That is
##     the beat `hook_00`..`hook_02` photograph: chain out, chain on the monster.
##   * It does NO damage and it does not pull. Both are asserted on numbers,
##     because both are silent when they break — a hookshot that chips a quarter
##     heart looks exactly like one that does not, and a hero reeled into the
##     thing he just froze looks like a hookshot working.
##   * The body turns BLUE and thaws. This is the half that has no boolean worth
##     having. `_ice()` measures the albedo of the monster's own surface override
##     so the log can say how blue, and how blue an eighth of a second later —
##     but the frames are what settle it, because "the albedo moved 0.42 toward
##     #48a8c8" is not a thing anyone can look at and call ice.
##
## A BYSTANDER stands next to the target for the same reason monster_feel keeps
## one: a GLB is loaded once and every instance shares its materials, so the
## obvious way to tint a body tints every skeleton in the room. `HitFlash.bind`
## is what stops that, and `ice()` is a new caller into it — if the isolation was
## going to break anywhere it was going to break here, on the first write that
## touches ALBEDO rather than emission.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/town.tscn \
##     --director=res://tools/directors/hook_freeze.gd --out=/tmp/freeze/x.png

var out := ""
var fails := 0


func run(rig) -> void:
	out = rig.arg("out", "/tmp/freeze/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await rig.wait_frames(20)

	var hero = rig.get_nodes_in_group(&"player")[0]
	var cam = hero.get_viewport().get_camera_3d()
	if cam == null:
		_fail("no camera, so there is no aim to put a monster on")
		return

	# Placed ON the camera's forward ray at runtime, exactly as ranged_kit places
	# its test ring: the aim path is what is under test, and a monster parked at
	# a coordinate I worked out on paper would test my trigonometry instead and
	# fail the day the camera's pitch is retuned.
	var aim: Vector3 = K.flat(-cam.global_transform.basis.z)
	var foe := Enemy.new()
	foe.kind = &"skeleton"
	foe.drop_seed = 8801
	rig.scene().add_child(foe)
	foe.global_position = hero.global_position + aim * 6.0

	var bystander := Enemy.new()
	bystander.kind = &"skeleton"
	bystander.drop_seed = 8802
	rig.scene().add_child(bystander)
	bystander.global_position = foe.global_position + aim.cross(Vector3.UP) * 2.8
	await rig.wait_frames(20)

	# Both held still. This beat is about what the CHAIN does and what the frozen
	# body LOOKS like; a skeleton that closes to claw range mid-shot photographs
	# its own approach and hits the hero during the thaw.
	foe.set_physics_process(false)
	bystander.set_physics_process(false)
	await rig.wait_frames(10)
	await rig.capture(out.path_join("hook_00_before.png"))

	# Taken here, before a shot is fired and after the models have settled, so
	# every "how blue" below is measured against what these two actually looked
	# like rather than against an idea of what a skeleton is.
	var foe_base := _baseline(foe)
	var bystander_base := _baseline(bystander)

	# Draw it. dpad up is the hookshot's quick slot (ranged_kit asserts that
	# binding; this beat only needs it to be true).
	await rig.tap(["item_up"])
	await rig.wait_frames(10)
	if Game.armament(Game.HAND_RIGHT) != &"hookshot":
		_fail("dpad up did not draw the hookshot (right hand holds %s)"
			% Game.armament(Game.HAND_RIGHT))
		return

	var hp_before: int = foe.health.quarters
	var stood: Vector3 = hero.global_position

	# The monster has to be let go for the freeze itself: a body with physics off
	# never runs `_tick_frozen`, so it would never thaw and the tint would be a
	# still life of a state machine that is not running.
	foe.set_physics_process(true)
	# HELD, not tapped, and the difference is the whole shot. `use_press` is what
	# raises the item and puts the camera on his shoulder; the aim is read at the
	# RELEASE, off wherever the lens is pointed then. A two-frame tap releases
	# into a camera that is still swinging down out of the follow rig, and the
	# first run of this director photographed the result: the chain went into the
	# cobbles two metres in front of his boots, and the beat below blamed
	# `L_ENEMY` for it.
	await rig.hold(["use_item"], 40)
	await rig.wait_frames(3)
	await rig.capture(out.path_join("hook_01_chain_out.png"))

	# Polled, not sampled at a fixed frame. The flight is `K.HOOK_SPEED` over six
	# metres — about a sixth of a second — and a check written at frame N passes
	# or fails on how busy the machine is.
	var froze := false
	for i in 90:
		await rig.wait_frames(1)
		if foe.is_frozen():
			froze = true
			break
	_check("the chain bit the monster and froze it", froze)
	if not froze:
		print("FREEZE done, %d failure(s)" % fails)
		return

	# The two numbers that are silent when they break.
	_check("the hookshot did no damage (%d -> %d quarters)"
		% [hp_before, foe.health.quarters], foe.health.quarters == hp_before)
	var moved := stood.distance_to(hero.global_position)
	print("FREEZE the hero moved %.2f m during the shot" % moved)
	_check("the hero was not reeled into the monster (%.2f m)" % moved, moved < 1.0)

	var solid := _ice(foe, foe_base)
	var leaked := _ice(bystander, bystander_base)
	print("FREEZE ice: target %.3f, bystander %.3f" % [solid, leaked])
	_check("the frozen body actually turned blue (%.3f)" % solid, solid > 0.25)
	_check("the tint stayed on the body it belongs to — the bystander read %.3f"
		% leaked, leaked < 0.05)
	await rig.capture(out.path_join("hook_02_frozen.png"))

	# Mid-thaw, then past the end of it. `K.HOOK_THAW` of the freeze is the tail
	# the tint bleeds out over, so a frame taken inside that window and one taken
	# after it are the whole of "slowly thaws" as a picture.
	await rig.wait_seconds(K.HOOK_FREEZE * (1.0 - K.HOOK_THAW * 0.4))
	var thawing := _ice(foe, foe_base)
	print("FREEZE ice mid-thaw: %.3f" % thawing)
	_check("the ice is bleeding out rather than holding flat (%.3f -> %.3f)"
		% [solid, thawing], thawing < solid)
	_check("it is still frozen while it is still blue", foe.is_frozen())
	await rig.capture(out.path_join("hook_03_thawing.png"))

	# Held still again for the last frame, so "thawed" is a photograph of the
	# monster's own colours and not of a skeleton mid-stride.
	await rig.wait_seconds(K.HOOK_FREEZE)
	_check("the freeze let go", not foe.is_frozen())
	var after := _ice(foe, foe_base)
	print("FREEZE ice after the thaw: %.3f" % after)
	_check("the body went back to its own colour (%.3f)" % after, after < 0.05)
	foe.set_physics_process(false)
	await rig.wait_frames(6)
	await rig.capture(out.path_join("hook_04_thawed.png"))

	await _killed_while_frozen(rig, bystander, bystander_base)

	print("FREEZE done, %d failure(s)" % fails)


## Kill a monster while it is still iced.
##
## The one exit from FROZEN that no amount of playing reaches on purpose, and the
## one with a trap under it: `_physics_process` returns at the top when the state
## is DEAD, so it never reaches the guard that lifts the freeze. A corpse would
## keep `speed_scale = 0.0` — its death clip frozen on frame one — and keep the
## albedo the freeze wrote, sinking into the floor blue. `Enemy._thaw_body`
## exists for exactly this, and this beat is the reason to believe it.
func _killed_while_frozen(rig, foe, base: Dictionary) -> void:
	foe.set_physics_process(true)
	foe.freeze(K.HOOK_FREEZE)
	await rig.wait_frames(2)
	_check("the bystander froze when it was hooked in turn", foe.is_frozen())

	var anim := foe.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		_fail("no AnimationPlayer on the monster, so the stopped clock cannot be read")
		return
	_check("the freeze stopped the animation clock (%.2f)" % anim.speed_scale,
		is_zero_approx(anim.speed_scale))

	# Struck through a DamageArea rather than by reaching into HealthComponent,
	# for the reason monster_feel does the same: the link between a blow and a
	# body is exactly the part that would break silently.
	_strike(foe, 40)
	for i in 40:
		await rig.wait_frames(1)
		if foe.state == Enemy.State.DEAD:
			break
	_check("a blow through the ice still killed it", foe.state == Enemy.State.DEAD)
	_check("the death let the animation clock go again (%.2f)" % anim.speed_scale,
		is_equal_approx(anim.speed_scale, 1.0))
	var corpse := _ice(foe, base)
	print("FREEZE ice on the corpse: %.3f" % corpse)
	_check("the corpse is not still blue (%.3f)" % corpse, corpse < 0.05)
	await rig.wait_frames(12)
	await rig.capture(out.path_join("hook_05_killed_frozen.png"))


## A blow of `amount` quarters, delivered the way the hero delivers one.
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


## Every material `HitFlash` owns on `body`, as it stands right now.
##
## Reads the surface OVERRIDE rather than the active material, for the reason
## monster_feel's `_emission` does: the override is exactly the per-instance
## shell `HitFlash.bind` installs, and asking the shared material would report
## the same number for every skeleton in the scene and quietly agree with itself.
func _surfaces(body: Node) -> Array[BaseMaterial3D]:
	var out_mats: Array[BaseMaterial3D] = []
	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		if mi.material_override is BaseMaterial3D:
			out_mats.append(mi.material_override as BaseMaterial3D)
			continue
		for surface in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(surface) as BaseMaterial3D
			if m != null:
				out_mats.append(m)
	return out_mats


## What `body` looked like before anything touched it: material -> {albedo, energy}.
## Captured rather than assumed, because the nine monster GLBs start from nine
## different base colours — and a wraith is emissive before you hit it at all.
func _baseline(body: Node) -> Dictionary:
	var base := {}
	for m in _surfaces(body):
		base[m.get_instance_id()] = {
			"albedo": m.albedo_color,
			"energy": m.emission_energy_multiplier if m.emission_enabled else 0.0,
		}
	return base


## How frozen `body` looks, 0 to 1, against the baseline it started from.
##
## A FRACTION OF THE TRIP, not a distance from FROST. "How close is this colour
## to #48a8c8" sounds like the same question and is not: a bone-white skeleton
## scores 0.66 on it standing in an empty room, so a thawed body would read as
## two thirds frozen and the beat that says "it went back to its own colour"
## would pass on a monster that never changed at all.
##
## Emission is folded in with the same normalisation, because the glow is the
## other half of `ice()` and a leak that showed up only there would otherwise
## sail past the bystander check — but only when it is FROST-coloured. A body
## that is lit is not a body that is frozen: this beat originally counted any
## emission at all, and the merge onto main caught it out immediately. The
## skeleton thawed correctly, walked into the hero, and started a wind-up, and
## the render showed a monster glowing RUST orange under a line claiming it was
## still 34% iced. The hue is what tells the two tells apart.
func _ice(body: Node, base: Dictionary) -> float:
	var peak := 0.0
	for m in _surfaces(body):
		var was: Dictionary = base.get(m.get_instance_id(), {})
		if was.is_empty():
			continue
		var start: Color = was["albedo"]
		var trip := _rgb(start).distance_to(_rgb(Pal.FROST))
		if trip > 0.001:
			peak = maxf(peak, _rgb(start).distance_to(_rgb(m.albedo_color)) / trip)
		var lit := 0.0
		if m.emission_enabled and _rgb(m.emission).distance_to(_rgb(Pal.FROST)) < 0.2:
			lit = absf(m.emission_energy_multiplier - float(was["energy"]))
		peak = maxf(peak, lit / HitFlash.ICE_ENERGY)
	return clampf(peak, 0.0, 1.0)


func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


func _check(what: String, ok: bool) -> void:
	if ok:
		print("FREEZE ok: %s" % what)
	else:
		_fail(what)


func _fail(what: String) -> void:
	fails += 1
	print("FREEZE FAIL %s" % what)
