extends RefCounted
## The whole arrow supply chain, rendered and asserted: the treasure chest as a
## model that opens, the arrow as a model that flies, the bundle on the floor,
## and the fletching bench that turns the bottom of the bag into shots.
##
## Six things can be wrong here and five of them are invisible to a log:
##
##  1. The chest model imports and its lid is a node this code can find. A
##     `push_error` on the lid still leaves a perfectly good closed chest in the
##     frame — you only find it by opening one.
##  2. The lid hinges on the BACK edge. A lid rotated about the wrong pivot
##     swings down through the floor, and the chest still "opens".
##  3. The arrow model points its HEAD along travel. CLAUDE.md §4: which end of
##     a GLB is the point is measured, never derived. A backwards arrow flies
##     fletching-first and nothing prints.
##  4. The arrow is arrow-sized. The GLB is 1.5 m native; unscaled it is longer
##     than the bow.
##  5. The bundle reads as arrows from gameplay distance and not as three sticks.
##  6. Fletching actually moves both numbers — the bag down, the quiver up.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/town.tscn \
##     --director=res://tools/directors/arrow_supply.gd --out=/tmp/arrows/x.png
##
## Prints `ARROW FAIL …` on any beat that did not happen.

## Where the props are staged. Off to one side of whatever scene loaded, so the
## town's own geometry is not in the shot and nothing has to be moved.
const STAGE := Vector3(0.0, 0.0, 40.0)

var _fails: int = 0


func _fail(msg: String) -> void:
	_fails += 1
	push_error("ARROW FAIL %s" % msg)
	print("ARROW FAIL %s" % msg)


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

	var out: String = rig.arg("out", "/tmp/arrows/x.png").get_base_dir()
	var scene: Node = rig.scene()
	await rig.wait_frames(20)

	var stage := Node3D.new()
	stage.name = "ArrowStage"
	scene.add_child(stage)
	stage.global_position = STAGE

	# A floor to stand things on and a key light, because the town's own lighting
	# is 40 m away and an unlit chest is a silhouette test, not a lookdev.
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(14.0, 14.0)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.20, 0.19, 0.18)
	gm.roughness = 1.0
	ground.material_override = gm
	stage.add_child(ground)

	var key := DirectionalLight3D.new()
	key.light_energy = 2.2
	stage.add_child(key)
	key.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(38.0), 0.0)
	var fill := OmniLight3D.new()
	fill.light_energy = 2.6
	fill.omni_range = 12.0
	stage.add_child(fill)
	fill.position = Vector3(-2.5, 3.0, -3.0)

	var cam := Camera3D.new()
	cam.fov = 40.0
	scene.add_child(cam)
	cam.make_current()

	await _shoot_chest(rig, stage, cam, out)
	await _shoot_arrow(rig, stage, cam, out)
	await _shoot_bundle(rig, stage, cam, out)
	_check_fletching()

	cam.queue_free()
	stage.queue_free()
	print("ARROWCHECK fails=%d" % _fails)


# --- The chest --------------------------------------------------------------

func _shoot_chest(rig, stage: Node3D, cam: Camera3D, out: String) -> void:
	# A seed the run controls, so "the chest gave arrows" is a fact about this
	# director and not about the day it ran.
	Run.enter(20190920)
	Game.arrows = 0

	var chest := Chest.new()
	chest.name = "LookdevChest"
	chest.picks = 2
	# Forced, not rolled: the point of the shot is that a bundle comes OUT, and a
	# 40% roll would photograph an empty-handed chest three runs in five.
	chest.arrow_chance = 1.0
	stage.add_child(chest)
	chest.position = Vector3.ZERO
	await rig.wait_frames(6)

	var model := chest.get_node_or_null(^"StaticBody3D/Model") as Node3D
	if model == null:
		# The StaticBody3D is unnamed, so find it the honest way.
		for c in chest.get_children():
			if c is StaticBody3D:
				model = (c as StaticBody3D).get_node_or_null("Model") as Node3D
	if model == null:
		_fail("chest model did not instance")
	else:
		var lid := model.get_node_or_null(Chest.LID_NODE)
		if lid == null:
			_fail("chest has no '%s' node — the lid cannot open" % Chest.LID_NODE)
		var span := WeaponModels.extent(model)
		print("SIZE chest extent=%.2fm" % span)
		# The chest is 1.15 m across at MODEL_SCALE. Anything outside this band is
		# a scale that got away, which is invisible next to a hero who is not in
		# the frame.
		if span < 0.9 or span > 1.5:
			_fail("chest is %.2f m across — that is not a chest" % span)

	await _frame(rig, cam, chest.global_position + Vector3(2.2, 1.5, 2.6),
		chest.global_position + Vector3.UP * 0.4, out, "chest_closed")

	var before := Run.bag.duplicate()
	chest.activate(null)
	# The lid tween is 0.34 s and the fling is 0.42 s. Wait both out, or the shot
	# is of a chest mid-swing with its contents still in the air.
	await rig.wait_frames(40)

	await _frame(rig, cam, chest.global_position + Vector3(2.2, 1.5, 2.6),
		chest.global_position + Vector3.UP * 0.4, out, "chest_open")

	var lid_open := false
	if model != null:
		var lid := model.get_node_or_null(Chest.LID_NODE) as Node3D
		lid_open = lid != null and absf(lid.rotation.x - Chest.LID_OPEN) < 0.02
	if not lid_open:
		_fail("the lid did not reach the open angle")
	# Motes on the FLOOR, not entries in the bag. A chest spills its contents and
	# walking over them is a separate act — asserting on `Run.bag` here would be
	# asserting that opening a chest picks its own loot up, which it must not.
	var motes := _motes_in(stage)
	if motes < maxi(chest.picks, 1):
		_fail("chest with picks=%d dropped %d motes" % [chest.picks, motes])
	else:
		print("CHEST spilled %d motes (bag still %d, as it should be)"
			% [motes, before.size()])

	var bundles := _bundles_in(stage)
	if bundles.is_empty():
		_fail("arrow_chance=1.0 and the chest produced no bundle")
	else:
		print("CHEST bundle count=%d" % (bundles[0] as ArrowBundle).count)

	# Walk the pickup: the bundle has to answer a body in the player group, and
	# the number it grants has to land on Game.
	if not bundles.is_empty():
		var got := await _walk_onto(rig, stage, bundles[0] as ArrowBundle)
		if got <= 0:
			_fail("walked onto a chest bundle and the quiver did not move")
		else:
			print("CHEST pickup +%d arrows (quiver %d)" % [got, Game.arrows])

	chest.queue_free()
	# Sweep the spilled motes out of BOTH places. A chest drops into
	# `current_scene`, not into the stage, and a forgotten one is a metre-tall
	# yellow prism parked in front of the next shot.
	for r in [stage, stage.get_tree().current_scene]:
		if r == null:
			continue
		for m in (r as Node).get_children():
			if m is LootMote:
				m.queue_free()
	await rig.wait_frames(4)


# --- The arrow --------------------------------------------------------------

## The arrow, close up and in flight. The close-up is the only way to see which
## end the head is on; the flight is the only way to see that the model agrees
## with the direction the raycast is using.
func _shoot_arrow(rig, stage: Node3D, cam: Camera3D, out: String) -> void:
	# The MODEL, mounted exactly as `Arrow._build` mounts it, on a node that is
	# not an Arrow. An un-launched Arrow is not a still arrow: `_physics_process`
	# starts applying gravity on frame one and `_face_travel` turns it to point
	# down its own fall, so photographing one tells you which way DOWN is and
	# nothing about which way forward is.
	var holder := Node3D.new()
	holder.name = "StillArrow"
	stage.add_child(holder)
	holder.position = Vector3(0.0, 1.0, 0.0)
	var model := WeaponModels.make(Arrow.MODEL_ID)
	if model == null:
		_fail("arrow model did not instance")
	else:
		model.rotation.x = Arrow.MODEL_PITCH
		holder.add_child(model)
		await rig.wait_frames(2)
		var span := WeaponModels.extent(model)
		print("SIZE arrow extent=%.2fm (want ~%.2f)" % [span, Arrow.MODEL_LEN])
		if absf(span - Arrow.MODEL_LEN) > 0.12:
			_fail("arrow is %.2f m — %.2f m was the promise" % [span, Arrow.MODEL_LEN])

	# Broadside. The node's forward is -Z, so the camera sits out on +X: the head
	# must come out on the LEFT of the frame and the fletching on the right.
	await _frame(rig, cam, holder.global_position + Vector3(1.7, 0.0, 0.0),
		holder.global_position, out, "arrow_side")
	holder.queue_free()

	# And in flight, which is the only frame that proves the model agrees with the
	# direction the raycast is stepping. Framed off the arrow's LIVE position — at
	# K.ARROW_SPEED it crosses a room in a quarter of a second, so a camera parked
	# where it was launched photographs an empty stage.
	var flyer := Arrow.new()
	flyer.name = "FlyingArrow"
	stage.add_child(flyer)
	flyer.launch(stage.global_position + Vector3(-4.0, 1.4, 0.0), Vector3.RIGHT)
	await rig.wait_frames(2)
	if not is_instance_valid(flyer):
		_fail("the arrow died before it had flown")
		return
	var at := flyer.global_position
	cam.global_position = at + Vector3(0.0, 0.0, -2.2)
	cam.look_at(at, Vector3.UP)
	# One frame only: any more and the camera is pointed where it USED to be.
	await rig.wait_frames(1)
	await rig.capture(out.path_join("ar_arrow_flight.png"))
	if is_instance_valid(flyer):
		flyer.queue_free()
	await rig.wait_frames(2)


# --- The bundle -------------------------------------------------------------

func _shoot_bundle(rig, stage: Node3D, cam: Camera3D, out: String) -> void:
	Game.arrows = 0
	var b := ArrowBundle.drop(stage, stage.global_position + Vector3(0.0, 0.0, 0.0),
		ArrowBundle.FLOOR_COUNT)
	await rig.wait_frames(30)

	# Close, then from the hero's own eye height at conversational distance —
	# the second is the shot that decides whether a player walking past would
	# read it as arrows or as scenery.
	await _frame(rig, cam, b.global_position + Vector3(0.9, 0.7, 1.0),
		b.global_position + Vector3.UP * 0.1, out, "bundle_close")
	await _frame(rig, cam, b.global_position + Vector3(0.0, K.HERO_EYE_Y, 3.4),
		b.global_position + Vector3.UP * 0.1, out, "bundle_eye")

	var got := await _walk_onto(rig, stage, b)
	if got != ArrowBundle.FLOOR_COUNT:
		_fail("floor bundle granted %d arrows, not %d" % [got, ArrowBundle.FLOOR_COUNT])
	else:
		print("FLOOR pickup +%d arrows" % got)

	# And the full-quiver refusal: it must NOT vanish, because a bundle you could
	# not take is a bundle to come back for.
	Game.arrows = Game.max_arrows
	var b2 := ArrowBundle.drop(stage, stage.global_position, ArrowBundle.FLOOR_COUNT)
	await rig.wait_frames(30)
	var walker := await _walk_onto(rig, stage, b2)
	if walker != 0:
		_fail("a full quiver accepted a bundle anyway")
	elif not is_instance_valid(b2):
		_fail("a refused bundle deleted itself instead of staying put")
	else:
		print("FULL quiver refused the bundle and it stayed on the floor")
	if is_instance_valid(b2):
		b2.queue_free()


# --- The bench --------------------------------------------------------------

## Fletching, as arithmetic. There are no pixels in this one — the card that
## draws it is proved by the menu director — but the recipe has to actually take
## from the bag and give to the quiver, and it has to refuse when it cannot.
func _check_fletching() -> void:
	Run.bag.clear()
	Run.premium = 0
	Game.arrows = 0

	if Fletching.can_fletch():
		_fail("an empty bag was allowed to fletch")
	if Fletching.refusal().is_empty():
		_fail("an empty bag gave no reason for refusing")

	for id: StringName in Fletching.RECIPE:
		var need: int = Fletching.RECIPE[id]
		Run.collect(id, need)
	if not Fletching.can_fletch():
		_fail("a bag holding exactly the recipe could not fletch: %s"
			% Fletching.cost_line())

	var made := Fletching.fletch()
	if made != Fletching.BATCH:
		_fail("fletched %d arrows, expected %d" % [made, Fletching.BATCH])
	if Game.arrows != made:
		_fail("quiver is %d after fletching %d" % [Game.arrows, made])
	for id: StringName in Fletching.RECIPE:
		if Run.bag.get(id, 0) != 0:
			_fail("'%s' survived the recipe that was supposed to eat it" % id)
	if Fletching.can_fletch():
		_fail("the bench offered a second batch out of an emptied bag")
	print("BENCH fletched %d arrows for %s" % [made, Fletching.cost_line()])

	# And the quiver ceiling: a full quiver refuses rather than burning the bag.
	Game.arrows = Game.max_arrows
	for id: StringName in Fletching.RECIPE:
		Run.collect(id, int(Fletching.RECIPE[id]))
	if Fletching.fletch() != 0:
		_fail("fletched into a full quiver")
	for id: StringName in Fletching.RECIPE:
		if Run.bag.get(id, 0) <= 0:
			_fail("a refused fletch ate '%s' anyway" % id)
	print("BENCH full quiver refused and the bag was untouched")


# --- Helpers ----------------------------------------------------------------

func _motes_in(root: Node) -> int:
	var n := 0
	for r in [root, root.get_tree().current_scene]:
		if r == null:
			continue
		for c in (r as Node).get_children():
			if c is LootMote:
				n += 1
	return n


func _bundles_in(root: Node) -> Array:
	var out: Array = []
	for c in root.get_children():
		if c is ArrowBundle:
			out.append(c)
	# Chests spill into `get_tree().current_scene`, not into the stage.
	var scene := root.get_tree().current_scene
	if scene != null and scene != root:
		for c in scene.get_children():
			if c is ArrowBundle:
				out.append(c)
	return out


## Put a body in the `player` group on top of `b` and let its overlap fire.
## The real hero is 40 m away in the town and dragging him here would drag the
## camera, the HUD and the lock-on with him; what the bundle actually asks is
## "is there a body in the player group in me", so that is what this supplies.
func _walk_onto(rig, stage: Node3D, b: ArrowBundle) -> int:
	if not is_instance_valid(b):
		return 0
	var before := Game.arrows
	var walker := CharacterBody3D.new()
	walker.name = "Walker"
	walker.collision_layer = K.L_PLAYER
	walker.collision_mask = 0
	walker.add_to_group(&"player")
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.3
	cs.shape = sp
	walker.add_child(cs)
	stage.add_child(walker)
	walker.global_position = b.global_position
	# Long enough for the Area3D to report the overlap AND for the pop tween to
	# finish, so `is_instance_valid` below means what it says.
	await rig.wait_frames(30)
	walker.queue_free()
	return Game.arrows - before


func _frame(rig, cam: Camera3D, eye: Vector3, at: Vector3, out: String,
		label: String) -> void:
	cam.global_position = eye
	cam.look_at(at, Vector3.UP)
	await rig.wait_frames(3)
	await rig.capture(out.path_join("ar_%s.png" % label))
