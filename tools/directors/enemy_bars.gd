extends RefCounted
## Proves the little health bars over the monsters, and proves the three
## conditions that keep them from being icon vomit (docs/STYLEGUIDE.md §5.5).
##
## The bars are drawn by `Hud._draw_enemy_bars` straight into the overlay, so
## there is no node to inspect and no property to assert on -- the only honest
## check is the picture. So this director READS ITS OWN CAPTURES back: it scans
## the frame for horizontal runs of `Pal.RUST` in the top three quarters of the
## screen (the HUD's own bars live in the bottom corner and are excluded), and a
## run of that colour at that length is a health bar. Counting them is what turns
## "the bars look right" into a beat that can fail.
##
## Run in TOWN on purpose. It is lit, so a bar that fails to draw is a visible
## hole rather than a black rectangle on a black wall, and the occlusion case
## needs a wall this director can put wherever it likes.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/town.tscn \
##     --director=res://tools/directors/enemy_bars.gd --out=/tmp/ebar/x.png

## Shortest horizontal run of RUST that counts as a bar. A full ordinary bar is
## `Pal.px(20)` = 20 px at 720p and a full locked one 44; every monster here is
## deliberately damaged, so the runs to catch are the FILLS -- 12 to 26 px. Ten
## catches all of them and rejects a torch flame, which is 1-2 px wide.
const MIN_RUN := 10
## Longer than any bar can be, so a red wall or a lit banner cannot pass as one.
const MAX_RUN := 70
## How much a run's channels may vary and still count as one flat colour. 20/255,
## against ~10 measured across a real bar and 31 at best for a torch flame. See
## `_flat`.
const FLAT_EPS := 20.0 / 255.0
## Tallest band of red that can still be a bar. The fill is 2 px; 4 leaves room for
## a blended edge row without admitting a torch flame, which is 9 or more.
const MAX_THICK := 4
## Everything below this fraction of the screen is the player's own instrument
## cluster -- the health bar's RUST ghost lives there and is not a monster.
const SCAN_BOTTOM := 0.75

## Where each case stands. Off the hero's own axis on purpose -- a monster parked
## dead ahead is behind the hero's shoulders from a boom camera, and a shot of a
## bar floating over the player's head proves nothing about whose bar it is.
## The hero stands at the courtyard's near end rather than at the origin, purely so
## there is 16 m of lit, walled, ON-SCREEN depth in front of him. The sleeper has to
## be all four of those at once and the origin only bought 10 m -- see AT_SLEEPER.
const AT_HERO := Vector3(0.0, 0.05, 7.0)
const AT_GOBLIN := Vector3(-2.2, 0.05, 2.4)
## 12.7 m from the hero: beyond the skeleton's own 11 m detect, so it never wakes,
## and inside the bars' 22 m range, so range is not what is hiding it. Both halves
## matter -- placed outside the courtyard this case passed by being off camera,
## which is a pass that proves nothing.
const AT_SLEEPER := Vector3(2.5, 0.05, -5.5)
const AT_ELITE := Vector3(2.8, 0.05, 1.6)
## Every position above is written in world space and only frames anything if the
## camera is looking north, so this director has to SAY so. It did not, at first
## -- it placed the hero and recentred, and inherited whatever facing the town
## spawn happened to give him. That worked until a merge moved the default, and
## then the sleeper was simply off screen: case B still "passed" (no bar, because
## no monster) and case C failed. A director that reads its own frames must own
## the framing.
##
## `facing_yaw` is the HEADING yaw (docs/CONTRACT.md §2.5): heading is
## (sin y, 0, cos y), so PI is heading (0,0,-1) and the camera's behind_yaw puts
## the lens at the hero's back looking up the courtyard.
const LOOK_NORTH := PI

var _out := ""
var _fails := 0


func run(rig) -> void:
	_out = rig.arg("out", "/tmp/ebar/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var scene: Node = rig.current_scene
	var hero: Node3D = rig.get_nodes_in_group(&"player")[0]
	hero.global_position = AT_HERO
	# `rotation.y` as well as `facing_yaw`: the hero turns toward his own heading
	# every frame, so setting only the node is undone before the first capture.
	hero.set(&"facing_yaw", LOOK_NORTH)
	hero.rotation.y = LOOK_NORTH + PI
	Bus.camera_recenter.emit()
	await rig.wait_frames(20)

	# --- A. Engaged and bleeding earns a bar --------------------------------
	var goblin := _spawn(scene, &"goblin", AT_GOBLIN, false)
	await rig.wait_frames(20)
	_hurt(goblin, 2)
	await _settle(rig, [[goblin, AT_GOBLIN]])
	var a := await _shot(rig, "eb_00_engaged.png")
	print("BARS engaged bars=%d lengths=%s state=%d" % [
		a.size(), _lengths(a), goblin.state])
	_want(a.size() == 1, "an engaged, bleeding goblin 5 m away drew %d bars, wanted 1"
		% a.size())

	# --- B. Asleep and unhurt earns nothing ---------------------------------
	var sleeper := _spawn(scene, &"skeleton", AT_SLEEPER, false)
	await rig.wait_frames(24)
	await _settle(rig, [[goblin, AT_GOBLIN], [sleeper, AT_SLEEPER]])
	var b := await _shot(rig, "eb_01_asleep.png")
	print("BARS asleep bars=%d lengths=%s sleeper_state=%d engaged=%s" % [
		b.size(), _lengths(b), sleeper.state, sleeper.is_engaged()])
	_want(not sleeper.is_engaged(),
		"the distant skeleton woke up on its own; case B proves nothing")
	# The two ways this case lies, both of which it has already told: the monster
	# is awake (so "no bar" is untested), or it is not in frame at all (so "no bar"
	# is a tautology). Assert the head is somewhere the bar COULD have been drawn.
	_want(_framed(hero, sleeper),
		"the sleeping skeleton was not on camera; case B proves nothing")
	_want(b.size() == 1,
		"a sleeping, unhurt skeleton drew a bar (%d on screen, wanted 1)" % b.size())

	# --- C. Bleeding earns a bar even asleep --------------------------------
	_hurt(sleeper, 2)
	await _settle(rig, [[goblin, AT_GOBLIN], [sleeper, AT_SLEEPER]])
	var c := await _shot(rig, "eb_02_asleep_hurt.png")
	print("BARS asleep_hurt bars=%d lengths=%s" % [c.size(), _lengths(c)])
	_want(c.size() == 2,
		"a hurt monster did not get a bar while idle (%d on screen, wanted 2)" % c.size())

	# --- D. A wall takes it away -------------------------------------------
	# The whole reason the occlusion ray exists: without it this feature is an
	# x-ray that reads monsters through walls.
	var cam := hero.get_viewport().get_camera_3d()
	var wall := _wall(scene, cam.global_position, sleeper.global_position)
	await _settle(rig, [[goblin, AT_GOBLIN], [sleeper, AT_SLEEPER]])
	var d := await _shot(rig, "eb_03_occluded.png")
	print("BARS occluded bars=%d lengths=%s" % [d.size(), _lengths(d)])
	_want(d.size() == 1,
		"a wall between the camera and a hurt monster did not hide its bar"
		+ " (%d on screen, wanted 1)" % d.size())
	wall.queue_free()
	await rig.wait_frames(4)

	# --- E. The locked target's bar is wider --------------------------------
	var plain := _longest(c)
	Bus.target_acquired.emit(goblin)
	await _settle(rig, [[goblin, AT_GOBLIN], [sleeper, AT_SLEEPER]])
	var e := await _shot(rig, "eb_04_locked.png")
	var locked := _longest(e)
	print("BARS locked plain=%d locked=%d ratio=%.2f" % [
		plain, locked, float(locked) / maxf(float(plain), 1.0)])
	_want(locked > plain,
		"the locked target's bar (%d px) is not wider than an ordinary one (%d px)"
			% [locked, plain])
	Bus.target_lost.emit()
	await rig.wait_frames(6)

	# --- F. An elite is framed in BONE, and is bigger ----------------------
	var elite := _spawn(scene, &"orc", AT_ELITE, true)
	await rig.wait_frames(24)
	_hurt(elite, 4)
	await _settle(rig, [[goblin, AT_GOBLIN], [sleeper, AT_SLEEPER], [elite, AT_ELITE]])
	await _shot(rig, "eb_05_elite.png")
	print("BARS elite height=%.2f elite=%s" % [
		elite.head_point().y - elite.global_position.y, elite.elite])

	if _fails == 0:
		print("BARS OK all cases passed")


# --- Setup helpers ----------------------------------------------------------

func _spawn(scene: Node, kind: StringName, at: Vector3, elite: bool) -> Enemy:
	var e := Enemy.new()
	e.kind = kind
	e.drop_seed = 4400 + int(absf(at.x) * 7.0)
	e.elite = elite
	scene.add_child(e)
	e.global_position = at
	return e


## Is this monster's head somewhere the HUD could put a bar? Deliberately the same
## two questions `Hud._draw_enemy_bars` asks -- behind the lens, or off the rect --
## and deliberately NOT the occlusion ray, because case D wants a framed monster
## the wall is hiding.
func _framed(hero: Node3D, e: Enemy) -> bool:
	var cam := hero.get_viewport().get_camera_3d()
	if cam == null:
		return false
	var head: Vector3 = e.head_point()
	if cam.is_position_behind(head):
		return false
	var r := Rect2(Vector2.ZERO, Vector2(cam.get_viewport().get_visible_rect().size))
	return r.has_point(cam.unproject_position(head))


func _hurt(e: Enemy, quarters: int) -> void:
	# Straight at the component. `DamageArea` looks for `take_hit` first and falls
	# back to this, and `Enemy` has no `take_hit` -- docs/CONTRACT.md §8.
	e.health.apply_hit(Hit.make(quarters, e.global_position + Vector3.FORWARD,
		&"test", 0.0, 0.0))


## Put the monsters back where the case wanted them, then let a few frames pass.
##
## They CHASE, and the first version of this only zeroed velocity -- so the goblin
## spent its twenty aggro frames walking into the hero and stood inside him for
## every shot after. The bar was correct and the picture was useless. The occlusion
## case needs the monster behind the wall when the shutter opens, so position is
## the thing that has to be held, not just speed.
##
## Held for one frame at a time rather than by freezing the AI: the state machine
## is what puts them in CHASE, and CHASE is the state under test.
func _settle(rig, foes: Array) -> void:
	for i in 8:
		for f: Array in foes:
			var e := f[0] as Enemy
			if e != null and is_instance_valid(e):
				e.global_position = f[1]
				e.velocity = Vector3.ZERO
		await rig.wait_frames(1)


## A slab on the world layer, halfway between two points and facing neither.
func _wall(scene: Node, from: Vector3, to: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = K.L_WORLD
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 5.0, 0.4)
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box.size
	mesh.mesh = bm
	body.add_child(mesh)
	scene.add_child(body)
	# A third of the way from the monster, so it is unambiguously between the two
	# and cannot be mistaken for clipping the camera.
	body.global_position = to.lerp(from, 0.33) + Vector3.UP * 1.2
	body.look_at(from, Vector3.UP)
	return body


# --- Reading the picture back -----------------------------------------------

func _shot(rig, name: String) -> Array:
	var path := _out.path_join(name)
	await rig.capture(path)
	var img := Image.load_from_file(path)
	if img == null:
		_want(false, "could not read back the capture at %s" % path)
		return []
	return _bars(img)


## Horizontal runs of Pal.RUST long enough to be a bar, one entry per run, as
## [x, y, length]. Adjacent rows of the same bar collapse into the longest row.
func _bars(img: Image) -> Array:
	var found: Array = []
	var limit := int(float(img.get_height()) * SCAN_BOTTOM)
	for y in range(0, limit):
		var run := 0
		for x in img.get_width():
			if _is_rust(img.get_pixel(x, y)):
				run += 1
				continue
			_keep(img, found, x - run, y, run)
			run = 0
		_keep(img, found, img.get_width() - run, y, run)
	return _collapse(found)


func _keep(img: Image, found: Array, x0: int, y: int, run: int) -> void:
	if run < MIN_RUN or run > MAX_RUN:
		return
	if not _flat(img, x0, y, run):
		return
	if not _thin(img, x0 + run / 2, y):
		return
	found.append([x0, y, run])


## Is this run of red a FLAT one?
##
## The second half of telling a health bar from a torch. Red-dominance alone is not
## enough in a lit courtyard: a flame 12 px across is red, wide enough, and in the
## top of the frame, and three of them were being counted as monsters. But a flame
## is a GRADIENT -- its red channel swings 30 to 107 values across the run -- and
## the HUD writes one flat colour, which comes back out of the grade swinging about
## 10. So flatness is the thing that separates the overlay from the world, and it
## does not care what the grade did to the absolute value.
## The END PIXELS ARE EXCLUDED, and that is not a fudge -- it is the difference
## between this working and this rejecting every bar on screen. A bar's first and
## last pixel sit against its 1 px frame and come back blended: measured across a
## real 13 px bar the interior held 203-218 and the two ends read 222 and 135, so
## the full-run spread was 87 against an interior spread of 15. The first version
## measured the ends and threw the feature out as a gradient.
func _flat(img: Image, x0: int, y: int, run: int) -> bool:
	var lo := Color(1.0, 1.0, 1.0)
	var hi := Color(0.0, 0.0, 0.0)
	for x in range(x0 + 1, x0 + run - 1):
		var c := img.get_pixel(x, y)
		lo = Color(minf(lo.r, c.r), minf(lo.g, c.g), minf(lo.b, c.b))
		hi = Color(maxf(hi.r, c.r), maxf(hi.g, c.g), maxf(hi.b, c.b))
	return hi.r - lo.r <= FLAT_EPS and hi.g - lo.g <= FLAT_EPS \
		and hi.b - lo.b <= FLAT_EPS


## Is this red only a couple of pixels TALL?
##
## The other half of telling the overlay from the world, and the one that catches
## what flatness misses. A bar is `Pal.px(2)` = 2 px tall, 3 with the blended edge.
## A torch flame is nine or more rows of red, and a flame's individual rows can be
## flat enough to pass `_flat` on their own. Nothing in this HUD draws a red band
## thicker than a bar, so thickness is decisive and needs no colour constant.
func _thin(img: Image, x: int, y: int) -> bool:
	var thick := 0
	var top := maxi(y - MAX_THICK - 1, 0)
	var bottom := mini(y + MAX_THICK + 2, img.get_height())
	for row in range(top, bottom):
		if _is_rust(img.get_pixel(x, row)):
			thick += 1
	return thick <= MAX_THICK


## One bar is 2 px tall, so it reports two runs at the same x. Keep the longest
## row per cluster rather than counting the same bar twice.
func _collapse(runs: Array) -> Array:
	var out: Array = []
	for r: Array in runs:
		var merged := false
		for i in out.size():
			var o: Array = out[i]
			if absf(float(r[0]) - float(o[0])) <= 4.0 \
					and absf(float(r[1]) - float(o[1])) <= 6.0:
				if int(r[2]) > int(o[2]):
					out[i] = r
				merged = true
				break
		if not merged:
			out.append(r)
	return out


## Red-dominant rather than equal to `Pal.RUST`, and this is the whole reason this
## helper has a comment.
##
## The HUD writes RUST flat and unshaded, so matching the constant looks like the
## obvious test -- and it FAILS, silently and selectively. The capture is graded
## after the overlay is composited, and the grade is position-dependent: the same
## bar reads (206, 65, 28) near the middle of the screen and (142, 37, 15) out
## towards the edge, against a constant of (184, 56, 24). An exact compare
## therefore found the bar in one frame, missed it in four, and the director
## reported the FEATURE as broken when the only broken thing was the ruler.
##
## So the test is the property that survives a grade: strongly red, with red well
## clear of the other two channels. Nothing else in the top three quarters of a
## town frame is that -- torch flames are warm but only 1-2 px wide, and the run
## length filter is what rejects them.
func _is_rust(c: Color) -> bool:
	return c.r > 0.43 and c.r > c.g * 1.8 and c.r > c.b * 2.0


func _lengths(bars: Array) -> String:
	var out: Array = []
	for b: Array in bars:
		out.append(int(b[2]))
	return str(out)


func _longest(bars: Array) -> int:
	var best := 0
	for b: Array in bars:
		best = maxi(best, int(b[2]))
	return best


func _want(ok: bool, why: String) -> void:
	if ok:
		return
	_fails += 1
	print("BARS FAIL " + why)
