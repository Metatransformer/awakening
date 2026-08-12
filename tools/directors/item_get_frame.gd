extends RefCounted
## The item-get ceremony, framed and lit — card #127 only.
##
## Card #108 built the ceremony and `boss_cistern.gd` beat H proves it *happens*.
## This director is about what it LOOKS like, which is the half no assertion can
## reach: how high the item is held, where it lands in frame, whether the chest it
## came out of is still in the shot, and whether the reward and its source are lit.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/item_get_frame.gd \
##     --out=/tmp/ig/x.png --warmup=60
##
## Optional:
##   --sweep=1                photograph the framing candidates side by side
##                            (`FRAMINGS`), which is how #127's numbers were
##                            picked — see the note on that table
##   --item=hookshot          which acquisition beat A opens the chest on
##
## **A dungeon and not the training room, on purpose.** The glow is the point of
## #127 part 2 and CLAUDE.md §3's opaque-slab trap only bites over a near-black
## floor; judged against the proving ground's daylight every one of these effects
## looks fine. The floor is generated and the chest is placed by hand rather than
## earned off a boss — this beat is a camera test, and `cistern_floor.gd` G10-G15
## already owns the earning.

## Fixed so the room around the chest is the same room every run. A framing
## judged against a different wall each time is not a comparison.
const SEED := 4242

## The candidate shots, for `--sweep=1`. Left to right: the item's height above
## the hero's origin, the camera's height, the height it aims at, and the FOV.
##
## Row 0 is what shipped from #108 and it is in this table so the sweep IS the
## before/after — a candidate photographed next to a memory of the old one is not
## a comparison either.
const FRAMINGS := [
	{"tag": "a_shipped_2.28", "h": 2.28, "cam": 1.95, "aim": 1.38, "fov": 38.0,
		"yaw": 0.0, "dist": 4.2},
	{"tag": "b_landed_2.05", "h": 2.05, "cam": 1.85, "aim": 1.28, "fov": 40.0,
		"yaw": 0.0, "dist": 4.2},
	{"tag": "c_yaw25", "h": 2.05, "cam": 1.85, "aim": 1.28, "fov": 40.0,
		"yaw": 25.0, "dist": 4.2},
	{"tag": "d_yaw40", "h": 2.05, "cam": 1.85, "aim": 1.28, "fov": 40.0,
		"yaw": 40.0, "dist": 4.2},
	{"tag": "e_yaw25_high", "h": 2.05, "cam": 2.20, "aim": 1.30, "fov": 40.0,
		"yaw": 25.0, "dist": 4.2},
	{"tag": "f_back52", "h": 2.05, "cam": 1.95, "aim": 1.24, "fov": 40.0,
		"yaw": 22.0, "dist": 5.2},
]

var out := ""
var _fails := 0
var _hero: Node3D = null
var _ceremony_distance := ItemGet.CAMERA_DISTANCE


func run(rig) -> void:
	out = rig.arg("out", "/tmp/ig/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if rig.scene().name != &"DungeonRun":
		print("ITEMGET FAIL wrong host scene (%s) -- pass "
			% rig.scene().name + "--scene=res://scenes/rooms/dungeon.tscn")
		rig.fail("wrong host scene")
		return

	Game.reset()
	Run.enter(SEED)
	Run.level = 1

	var d: Node = await _build_floor(rig)
	if d == null:
		_ck("the dungeon built", false)
		_report(rig)
		return
	_hero = _find_hero(rig)
	if _hero == null:
		_ck("there is a hero in the scene", false)
		_report(rig)
		return
	var cam := _game_camera(rig)
	if cam != null:
		cam.make_current()
	Bus.camera_recenter.emit()
	await rig.wait_frames(24)

	await _a_the_ceremony(rig, StringName(rig.arg("item", "bow")))
	if rig.arg("sweep", "") != "":
		await _b_the_framings(rig)

	_report(rig)


# --- A: the real thing ---------------------------------------------------------

## Open a real `BossItemChest` standing in a real room and photograph the beat it
## starts. Three frames because a ceremony is not a still: the item RISES, it
## HOLDS, and the chest is what is left when it goes.
func _a_the_ceremony(rig, item: StringName) -> void:
	var chest := _plant_a_chest(rig, item)
	if chest == null:
		_ck("A0 a great chest could be planted in front of the hero", false)
		return

	# Straight at it, so the gameplay camera is squarely behind the hero when the
	# ceremony reads its side off it. A hero opening a chest over his shoulder
	# gives the ceremony a camera nobody would ever see it from.
	var to_chest: Vector3 = K.flat(chest.global_position - _hero.global_position)
	_hero.facing_yaw = atan2(to_chest.x, to_chest.z)
	_hero.rotation.y = _hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_frames(30)
	await rig.capture(out.path_join("i_00_before.png"))

	chest.activate(_hero)
	# The chest holds the item back for `BossItemChest.REVEAL_TIME` so the lid is
	# open before the ceremony takes the camera. Past that, this is the RISE --
	# `_reveal_display`'s scale tween is 0.68 s long and this lands inside it.
	await rig.wait_seconds(0.62)
	var ceremony: Node = rig.scene().get_tree() \
		.get_first_node_in_group(&"item_get")
	_ck("A1 opening the chest starts the ceremony", ceremony != null)
	if ceremony == null:
		return
	await rig.capture(out.path_join("i_01_rise.png"))
	var rise_pose := _pose_yaws()

	await rig.wait_seconds(0.9)
	await rig.capture(out.path_join("i_02_hold.png"))
	_measure(rig, ceremony, chest)
	_where_the_clip_puts_him(rise_pose, _pose_yaws())

	# 1.4 s and not 1.0. `ItemGet._age` starts when the CEREMONY is built, which
	# is `BossItemChest.REVEAL_TIME` after the lid begins to move -- so the three
	# waits above had spent 2.18 s of the ceremony's own clock against a
	# `MIN_DISMISS_TIME` of 2.2, `dismiss()` refused by 20 ms, and the run
	# photographed a ceremony that would not close and reported it as a bug in
	# the game.
	await rig.wait_seconds(1.4)
	ceremony.call(&"dismiss")
	await rig.wait_frames(8)
	_ck("A9 dismissal hands gameplay back", not Prompt.blocked)
	await rig.capture(out.path_join("i_03_close.png"))


## The numbers behind the frames. Everything here is measured off live nodes --
## CLAUDE.md §4: facing in particular is measured and never derived.
func _measure(rig, ceremony: Node, chest: Node3D) -> void:
	var display := ceremony.call(&"display_node") as Node3D
	var cam := ceremony.call(&"camera_node") as Camera3D
	_ck("A2 the ceremony camera is current", cam != null and cam.is_current())
	if display == null or cam == null:
		return
	_ceremony_distance = K.flat(
		cam.global_position - _hero.global_position).length()

	# The gameplay camera has already shortened its boom around walls. ItemGet
	# must preserve that collision solution when it takes over: card #127's first
	# dedicated capture originally put the fixed 4.2 m ceremony boom through the
	# entrance-room wall and produced a black world under a perfectly live UI.
	# Node checks alone called that frame green, so ask the actual physics space
	# whether masonry sits between the ceremony lens and its subject.
	var sight := PhysicsRayQueryParameters3D.create(
		cam.global_position, _hero.global_position + Vector3.UP * 1.25, K.L_WORLD)
	var blocked := _hero.get_world_3d().direct_space_state.intersect_ray(sight)
	_ck("A2b the ceremony lens has a clear line to the hero",
		blocked.is_empty())

	# HOW FAR ABOVE HIS HEAD, in metres, which is the whole of #127 part 1. The
	# hero is 1.65 m (CLAUDE.md §6) and #108 held the item at 2.28 -- 63 cm of
	# empty air over the top of his skull.
	var lift := display.global_position.y - _hero.global_position.y
	var over_head := lift - K.HERO_H
	print("ITEMGET lift=%.2f m over_head=%.2f m" % [lift, over_head])
	_ck("A3 the item is held above his head (%.2f m over) and not a metre over it"
		% over_head, over_head > 0.0 and over_head < 0.5)

	# WHERE IT LANDS IN FRAME. `unproject_position` answers in the viewport the
	# camera lives in, which is the root window at native (STYLEGUIDE §4.5's note
	# about never reparenting the world), so this is honest screen pixels.
	var vp: Vector2 = rig.root.get_visible_rect().size
	var at := cam.unproject_position(display.global_position)
	var frac := at.y / maxf(vp.y, 1.0)
	print("ITEMGET item at %.0f,%.0f of %.0fx%.0f (y=%.3f of height)"
		% [at.x, at.y, vp.x, vp.y, frac])
	_ck("A4 it lands in the upper third of the frame (y=%.3f)" % frac,
		frac > 0.16 and frac < 0.36)

	# The chest, and this is the other half of #127 part 2: a glow inside a box
	# that the shot does not contain is a glow nobody sees. The bottom letterbox
	# bar starts at 0.68 of the height, so anything below that is behind it.
	var chest_at := cam.unproject_position(
		chest.global_position + Vector3.UP * 0.45)
	var chest_frac := chest_at.y / maxf(vp.y, 1.0)
	print("ITEMGET chest at y=%.3f of height" % chest_frac)
	_ck("A5 the chest it came out of is still in shot, above the lower bar (y=%.3f)"
		% chest_frac, chest_frac > 0.0 and chest_frac < 0.68)

	# FACING, MEASURED (CLAUDE.md §4 / docs/CONTRACT.md §2.5). A Node3D's forward
	# is -basis.z. Nothing here is read off the rest pose or off `facing_yaw`;
	# both of those are the thing under test.
	var forward := -_hero.global_basis.z
	var to_cam := K.flat(cam.global_position - _hero.global_position).normalized()
	var face := forward.dot(to_cam)
	print("ITEMGET hero forward.to_camera = %.3f" % face)
	_ck("A6 the hero is turned to the lens (dot %.3f)" % face, face > 0.9)

	# The glow, asked of the tree rather than of a pixel diff -- CLAUDE.md §3:
	# the fog jitters an RGB555 step in a stopped room and a diff would read that
	# as the effect. What a frame CAN be asked is whether the lights exist and are
	# alight; whether they look like light is what the PNGs above are for.
	var chest_lit := _lit_energy(chest)
	print("ITEMGET chest interior light energy=%.2f" % chest_lit)
	_ck("A7 the opened chest is still lit from the inside (%.2f)" % chest_lit,
		chest_lit > 0.05)
	var item_lit := _lit_energy(ceremony)
	_ck("A8 and the item carries its own light (%.2f)" % item_lit, item_lit > 0.05)


## A6 IS NOT THE WHOLE OF THE FACING, AND THE FRAMES ARE WHY THIS EXISTS.
##
## A6 asks the hero's own Node3D, which is the only part of the turn the code
## owns, and it reads a clean 1.000 -- correctly, because `ItemGet._build_camera`
## does the CONTRACT §2.5 turn properly. The frame at that same instant shows him
## in PROFILE, a shoulder to the lens and his face pointing off to the left.
##
## Both are true. The body is square to the camera and the CLIP twists what sits
## on top of it: `clip_item_get` is `ss_power_up_01`, a stand-in, and its upper
## body turns away while the hips stay put. Measured below, and the two numbers
## are the whole story -- the hips barely move and the head swings. A director
## that stopped at A6 would print a green next to a photograph of the hero's ear,
## which is CLAUDE.md §4's RENDER IT AND LOOK arriving in one frame.
##
## Deltas between two live samples of the same bone, so this needs no opinion
## about which way the art faces in its own space and reads nothing off the rest
## pose. Reported and not failed: the fix is an ANIMATION ASSET (#127 part 3, the
## hands-above-head pose), and a permanently red beat here would stall every
## later run of a director whose other checks are about framing and light.
func _where_the_clip_puts_him(rise: Dictionary, hold: Dictionary) -> void:
	if rise.is_empty() or hold.is_empty():
		print("ITEMGET NOTE no skeleton found; the clip's own turn is unmeasured")
		return
	for bone in ["hips", "head"]:
		var a: float = rise.get(bone, NAN)
		var b: float = hold.get(bone, NAN)
		if is_nan(a) or is_nan(b):
			continue
		print("ITEMGET NOTE %s turns %.1f deg between rise and hold"
			% [bone, absf(rad_to_deg(wrapf(b - a, -PI, PI)))])
	print("ITEMGET NOTE   -> A6's dot is the BODY's. ss_power_up_01 twists what")
	print("ITEMGET NOTE      is on top of it, so at the hold his face is in")
	print("ITEMGET NOTE      profile. #127 part 3: the clip is a stand-in.")


## World yaw of the named bones, sampled live. Not the rest pose -- CLAUDE.md §4
## forbids reasoning from rest-pose bone tracks, and this is the opposite of
## that: it is what the bones are doing on the frame that was just captured.
func _pose_yaws() -> Dictionary:
	var hero := _hero as Hero
	if hero == null:
		return {}
	var skel: Skeleton3D = hero.skeleton()
	if skel == null or skel.get_bone_count() == 0:
		return {}
	var out_yaws := {}
	for i in skel.get_bone_count():
		var lower := skel.get_bone_name(i).to_lower()
		for want in ["hips", "head"]:
			if out_yaws.has(want) or not lower.ends_with(want):
				continue
			var b: Basis = (skel.global_transform
				* skel.get_bone_global_pose(i)).basis
			out_yaws[want] = atan2(-b.z.x, -b.z.z)
	return out_yaws


# --- B: the framing sweep ------------------------------------------------------

## Photograph every row of `FRAMINGS` on one pose, so the choice is made by
## looking rather than by arithmetic. #127 says so in as many words.
##
## It reaches into the ceremony's own fields to do it. That is deliberate and it
## is what a director is allowed to do here (CLAUDE.md §3's `screen._cursor` row
## is the same move); the alternative is five constants promoted to variables
## that only a sweep would ever write.
func _b_the_framings(rig) -> void:
	for row in FRAMINGS:
		var ceremony: Node = ItemGet.present(rig.scene(), &"bow", _hero as Hero)
		if ceremony == null:
			_ck("B0 %s presented" % row["tag"], false)
			continue
		await rig.wait_frames(2)
		_reframe(ceremony, row)
		await rig.wait_seconds(1.0)
		await rig.capture(out.path_join("i_10_sweep_%s.png" % row["tag"]))
		# Freed rather than dismissed. `dismiss` refuses inside
		# `MIN_DISMISS_TIME` and `present` hands back the ceremony that is
		# already in the group, so a candidate that failed to clear would
		# photograph its predecessor five times. `_exit_tree` does the whole of
		# `_finish` on the way out, so nothing is skipped by leaving early.
		ceremony.free()
		await rig.wait_frames(6)


func _reframe(ceremony: Node, row: Dictionary) -> void:
	var cam := ceremony.call(&"camera_node") as Camera3D
	if cam == null:
		return
	var side := K.flat(cam.global_position - _hero.global_position).normalized()
	# Each candidate starts from a fresh ceremony, so this is the collision-safe
	# boom ItemGet inherited from the live gameplay camera. A sweep must not put
	# its comparison camera back through the wall merely because the table's
	# authored distance is longer.
	# `yaw` swings the camera around the hero, off the bearing the gameplay
	# camera handed over. The hero is NOT re-turned to follow it, deliberately:
	# `ItemGet._build_camera` turns him to the lens and a candidate that also
	# moved him would be measuring two changes at once.
	side = side.rotated(Vector3.UP, deg_to_rad(float(row.get("yaw", 0.0))))
	ceremony.set(&"_display_base",
		_hero.global_position + Vector3.UP * float(row["h"]))
	cam.fov = float(row["fov"])
	cam.global_position = _hero.global_position \
		+ side * minf(float(row.get("dist", ItemGet.CAMERA_DISTANCE)),
			_ceremony_distance) \
		+ Vector3.UP * float(row["cam"])
	cam.look_at(
		_hero.global_position + Vector3.UP * float(row["aim"]), Vector3.UP)



# --- plumbing ------------------------------------------------------------------

func _build_floor(rig) -> Node:
	var scene: Node = rig.scene()
	var old := scene.get_node_or_null(^"Dungeon")
	if old != null:
		old.name = "DungeonOld"
		old.queue_free()
		await rig.wait_frames(2)
	var script := load("res://scripts/world/dungeon.gd") as GDScript
	var d: Node = script.new()
	d.name = "Dungeon"
	d.seed_override = SEED
	scene.add_child(d)
	await rig.wait_frames(14)
	return d


## Stand a great chest a stride in front of the hero, in whichever direction he
## has room for it. The entrance room is small and a chest dropped blindly on
## `+X` ends up inside a wall, where the lid opens into stone and the whole point
## of the glow is behind it.
func _plant_a_chest(rig, item: StringName) -> Node3D:
	var script := load("res://scripts/world/boss_item_chest.gd") as GDScript
	var chest: Node3D = script.new()
	chest.name = "DirectorGreatChest"
	chest.set(&"item_id", item)
	rig.scene().add_child(chest)
	_place_chest(chest)
	return chest


## Where the chest goes. Swept around the hero and kept at the first bearing with
## a clear metre and a half, measured with a real shape query rather than by
## trusting the room's nominal size.
func _place_chest(chest: Node3D) -> void:
	var space := _hero.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = K.L_WORLD
	var best := _hero.global_position + Vector3.FORWARD * 1.6
	for i in 12:
		var a := TAU * float(i) / 12.0
		var at := _hero.global_position \
			+ Vector3(sin(a), 0.0, cos(a)) * 1.6 + Vector3.UP * 0.7
		query.transform = Transform3D(Basis.IDENTITY, at)
		if space.intersect_shape(query, 1).is_empty():
			best = at - Vector3.UP * 0.7
			break
	chest.global_position = best
	# Facing the hero, so the lid opens toward him and toward the camera behind
	# him. `-basis.z` is forward (docs/CONTRACT.md §2.5), so this is a look_at
	# spelled out rather than a guess about which way a chest's art points.
	var back: Vector3 = K.flat(_hero.global_position - best)
	if back != Vector3.ZERO:
		chest.rotation.y = atan2(back.x, back.z) + PI


## The brightest live light anywhere under `n`. Deliberately not "is there an
## OmniLight3D": #108's chest already had one and `_begin_open` tweened it to
## zero on the way open, so a check that only counted nodes would have passed on
## a chest that goes DARK the moment it matters.
func _lit_energy(n: Node) -> float:
	var best := 0.0
	for node in _all(n):
		var l := node as Light3D
		if l != null and l.visible:
			best = maxf(best, l.light_energy)
	return best


func _find_hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _game_camera(rig) -> Camera3D:
	for n in _all(rig.scene()):
		if n is GameCamera:
			return n
	return null


func _all(root: Node) -> Array:
	var found := [root]
	var i := 0
	while i < found.size():
		for c in (found[i] as Node).get_children():
			found.append(c)
		i += 1
	return found


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("ITEMGET OK   %s" % label)
	else:
		_fails += 1
		print("ITEMGET FAIL %s" % label)


## Card #72: a director's own failures never reached the exit code, so they are
## handed to `rig.fail` as well as printed. Read the output either way.
func _report(rig) -> void:
	if _fails == 0:
		print("ITEMGET OK -- every check passed")
		return
	print("ITEMGET FAIL -- %d check(s) failed" % _fails)
	rig.fail("%d item-get check(s) failed" % _fails)
