extends RefCounted
## Card #38 — **every frame on the demo path holds a real dark AND a real
## bright**, measured rather than admired.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/dungeon.tscn \
##     --director=res://tools/directors/room_range.gd \
##     --out=/tmp/range/x.png --warmup=60 --gate-prefab=eye_row
##
## `--gate-prefab=eye_row` forces beat F's control room to be the one the card
## measured. Without it the seed draws whichever of `Dungeon.GATE_PREFABS` it
## likes and the control is a different room run to run, which is not a control.
##
## `docs/STYLEGUIDE.md` §1 rule 1: *"Contrast is range, not darkness. Every frame
## must hold a real dark (a doorway, a corner, a turned-away face) and a real
## bright (a torch pool)."* Floor 1's shortcut-door room came out **76% below
## luminance 8** with a mean of 8.6/255 — one value, no range, the hero a black
## cut-out — while the gate room three rooms away measured 0.6% and 45.2 off the
## same generator and the same `env_dungeon.tres`.
##
## ## Why a whole director rather than a number in a commit message
##
## The card asked for a sweep, and a sweep is the only way to tell "one room is
## broken" from "the floor is". A single before/after pair proves a tuning pass
## moved a histogram; it cannot say whether the pass moved every other room off
## the styleguide at the same time. So this file stands the hero in **six** poses
## across floors 1 and 2 — the four room shapes the demo path walks through, plus
## the corridor between them and the landing behind the shortcut door — and puts
## the same five-band histogram under each.
##
## ## What it measures, and on what
##
## Rec.601 luma of the **top 70% of the frame**. The bottom band is the HUD:
## scoring it is scoring the UI, and the HUD's own black panel fill would drag
## every room's sub-8 share up by a constant. The measurement is taken on the PNG
## a human then looks at, which is `shoot.gd`'s supersampled downscale — card #35
## notes those are not to be judged for edge quality, but a luminance histogram
## survives a Lanczos resample intact.
##
## Three bounds, and the last two are the ones the card was afraid of:
##
##   `DARK_MAX`   no more than half the frame may sit under 8. Below 8 is what a
##                projector in a lit room renders as one flat black, so this is
##                "at least half the picture has to carry information".
##   `BRIGHT_MIN` at least this share must sit **above 64** — a torch pool, a lit
##                face, a hot wall. This is the half that stops "fix the dark"
##                from being answered with lifted ambient: one beige sheet passes
##                `DARK_MAX` trivially, and §1 rule 1 calls that a *lower*-contrast
##                image than the black one.
##   `MEAN_MIN`   and the mean, which is the number the card led with (9.1 against
##                the good room's 44.2). It is what catches the frame that squeaks
##                under a loose `DARK_MAX` by being uniformly almost-black.
##
## One set of numbers for every pose, deliberately. A per-pose exemption is how a
## bound stops meaning anything, and the corridor — the darkest frame on the path,
## and dark *by design* — is the pose that would have got one. It passes on the
## same three numbers as the rooms.
##
## Room-lighting facts are printed beside every pose (sides walled, sides open,
## sconces built) because that is where the answer was: `_build_room_torches`
## skipped any side carrying an anchor, so the one wall the shortcut-door room is
## photographed facing was the one wall in the floor with no fire on it.

## Floor 1's layout, shared with `echo_plates.gd`, `shortcut_puzzle.gd` and
## `cistern_floor.gd` so the four directors describe one floor and not four.
const SEED := 20260809

## Where the hero stands to read a door — `echo_plates.gd`'s `READ_AT`, and for
## its reason: inside `LockedDoor`'s 2.9 m interact radius, far enough back that
## the leaves and what is behind them share the frame. Beat A is deliberately the
## same pose as `e_02_door_shut.png`, which is the frame the card measured.
const READ_AT := 2.5

## The share of the world area allowed under luminance 8, the share required above
## 64, and the floor under the mean.
##
## `DARK_MAX` is loose on purpose, and 50% is a sentence rather than a fitted
## number: *no frame may be more than half nothing*. A frame pointed down an
## unlit corridor SHOULD be largely black — that is rule 1's "real dark" — and a
## bound tight enough to forbid it would be a bound demanding the uniform lift
## rule 1 exists to prevent. What must not happen is 76%.
##
## `BRIGHT_MIN` and `MEAN_MIN` are what stop that looseness from being a hole.
## Against the frames measured the night the card was opened, the three together
## fail every defective pose and pass every sound one: the shortcut room
## (76.3 / 1.5 / 8.6) fails all three, the same room turned round (55.0 / 1.3 /
## 9.7) fails all three, the corridor (51.4 / 2.0 / 15.5) fails all three, and the
## generated room that was never wrong (3.5 / 7.6 / 35.4) passes all three
## untouched.
const DARK_MAX := 50.0
const BRIGHT_MIN := 3.0
const MEAN_MIN := 18.0

## Band edges for the printed histogram. The five the card used, so its table and
## this one can be read side by side.
const BANDS: Array[int] = [8, 32, 64, 128, 256]

## The fraction of the frame that is world rather than HUD.
const WORLD_FRAC := 0.70

var out := ""
var _fails := 0
var _rows: Array[String] = []


func run(rig) -> void:
	out = rig.arg("out", "/tmp/range/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if rig.scene().name != &"DungeonRun":
		print("RANGE FAIL wrong host scene (%s) -- pass "
			% rig.scene().name
			+ "--scene=res://scenes/rooms/dungeon.tscn")
		return

	Game.reset()
	Run.enter(SEED)
	# The bow opens the shortcut door's eye, and beat D is shot through it.
	Game.grant(&"bow")

	var d := await _rebuild(rig, 1)
	if d == null:
		print("RANGE FAIL the dungeon did not build")
		return
	var hero: Node3D = _hero(rig)
	var cam := _game_camera(rig)
	if hero == null or cam == null:
		print("RANGE FAIL no hero or no GameCamera in the scene")
		return
	cam.make_current()
	_clear_the_floor(d)
	await rig.wait_frames(20)

	_print_floor(d, 1)

	# --- A. The room the card is about ---------------------------------------
	var door: Node3D = d.anchor_node(&"shortcut_door")
	_ck("A0 floor 1 has a shortcut door", door != null)
	if door == null:
		return
	await _stand_at(rig, hero, door, READ_AT)
	await _shot(rig, "r_01_shortcut_door", "floor 1 entrance, at the shut door")

	# --- B. The same room, turned round --------------------------------------
	# The other half of "is this room dark, or is this WALL dark". Same spot, same
	# lights, the hero facing the room instead of the anchor.
	var centre: Vector3 = _room_centre(d, door)
	await _face_point(rig, hero, centre)
	await _shot(rig, "r_02_entrance_inward", "floor 1 entrance, facing the room")

	# --- C. A plain generated room -------------------------------------------
	var plain: Node3D = _plain_room(d)
	if plain != null:
		hero.velocity = Vector3.ZERO
		hero.global_position = plain.global_position + Vector3(0.0, 0.15, 4.0)
		await _face_point(rig, hero, plain.global_position + Vector3(0, 0, -6))
		await _shot(rig, "r_03_plain_room", "floor 1, a room with no anchor in it")

	# --- D. Through the shortcut door, and the landing behind it --------------
	var eye: Node = _named(d, "ShortcutEye")
	if eye != null:
		eye.call(&"apply_hit", null)
		await rig.until(func() -> bool: return bool(door.call(&"is_open")), 5.0)
		await rig.wait_frames(40)
		await _stand_at(rig, hero, door, READ_AT)
		await _shot(rig, "r_04_door_open", "floor 1 entrance, the door swung")

		# On the landing itself: one sconce on the back wall, and it is the only
		# warm light past the door. `ShortcutLanding` is turned so its own +Z runs
		# away from the room, down the stub and into the chamber -- so the hero
		# stands a stub's length in and looks the way he walked.
		var landing: Node3D = _named(d, "ShortcutLanding") as Node3D
		if landing != null:
			var into := landing.global_transform.basis.z
			hero.velocity = Vector3.ZERO
			hero.global_position = landing.global_position + into * 2.0 \
				+ Vector3(0.0, 0.15, 0.0)
			await _face_point(rig, hero, landing.global_position + into * 12.0)
			await _shot(rig, "r_05_landing", "floor 1, the landing behind it")

	# --- E. A corridor -------------------------------------------------------
	var corr: Node3D = _first(d, func(n: Node) -> bool:
		return n is Node3D and (n as Node).name.begins_with("Corr_")) as Node3D
	if corr != null:
		hero.velocity = Vector3.ZERO
		hero.global_position = corr.global_position + Vector3(0.0, 0.15, 3.0)
		await _face_point(rig, hero, corr.global_position + Vector3(0, 0, -8))
		await _shot(rig, "r_06_corridor", "floor 1, a corridor")

	# --- F. The room that already passes -------------------------------------
	# Floor 2's gate room, which the card used as its control. Rebuilt rather than
	# taken on trust: a fix that quietly moved THIS room is a fix that traded one
	# outlier for another, and only a measurement taken in the same run can say.
	var d2 := await _rebuild(rig, 2)
	if d2 != null:
		_clear_the_floor(d2)
		await rig.wait_frames(20)
		_print_floor(d2, 2)
		var gate: Node3D = _gate_room(d2)
		if gate != null:
			# Aimed at the eye wall when the seed drew `eye_row` (pass
			# `--gate-prefab=eye_row` and it always has), so this is the same room
			# from the same side as the card's control frame.
			var eye0: Node = _first(gate, func(n: Node) -> bool:
				return n.name.begins_with("GateEye"))
			var look: Vector3 = (eye0 as Node3D).global_position if eye0 != null \
				else gate.global_position + Vector3(0.0, 2.05, -6.0)
			hero.velocity = Vector3.ZERO
			hero.global_position = K.flat(look) \
				+ (gate.global_position - K.flat(look)).normalized() * 6.0 \
				+ Vector3(0.0, 0.15, 0.0)
			await _face_point(rig, hero, look)
			await _shot(rig, "r_07_gate_room", "floor 2, the gate room (control)")

	# --- The table -----------------------------------------------------------
	print("")
	print("RANGE %-26s %7s %7s %7s %7s %7s %7s"
		% ["frame", "<8", "8-31", "32-63", "64-127", "128+", "mean"])
	for r: String in _rows:
		print(r)
	print("")

	if _fails == 0:
		print("RANGE ok -- every pose holds a real dark and a real bright")
	else:
		print("RANGE FAIL -- %d check(s) failed" % _fails)


# --- The measurement ----------------------------------------------------------

## Photograph the pose, then read the PNG back and score its world area.
func _shot(rig, stem: String, what: String) -> void:
	await rig.wait_frames(12)
	var path := out.path_join("%s.png" % stem)
	await rig.capture(path)
	var img := Image.load_from_file(path)
	if img == null:
		_ck("%s could not be re-read" % stem, false)
		return
	var h := _histogram(img)
	var share: Array = h["share"]
	_rows.append("RANGE %-26s %6.1f%% %6.1f%% %6.1f%% %6.1f%% %6.1f%% %7.1f"
		% [stem, share[0], share[1], share[2], share[3], share[4], h["mean"]])
	var bright: float = share[3] + share[4]
	# What the pose costs, beside what it looks like. Draw calls rather than a
	# frame time: this harness renders a maximised retina window and shares the
	# machine with three other directors, so a millisecond here is a number about
	# the Mac. Draw calls are the same on a quiet machine and a busy one, and a
	# sconce is geometry as well as a light.
	print("RANGE %s -- %s: <8 %.1f%%, >64 %.1f%%, mean %.1f, %d draw call(s)"
		% [stem, what, share[0], bright, h["mean"],
			RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	_ck("%s is not mostly nothing (<8 is %.1f%%, cap %.0f%%)"
		% [stem, share[0], DARK_MAX], share[0] <= DARK_MAX)
	_ck("%s holds a real bright (>64 is %.1f%%, floor %.0f%%)"
		% [stem, bright, BRIGHT_MIN], bright >= BRIGHT_MIN)
	_ck("%s carries an image (mean %.1f, floor %.0f)"
		% [stem, h["mean"], MEAN_MIN], h["mean"] >= MEAN_MIN)


## Five-band Rec.601 histogram of the top `WORLD_FRAC` of an image.
##
## Through `get_data()` rather than `get_pixel()`: this is 645k pixels a frame and
## seven frames a run, and the per-pixel `Variant` round trip through `Color` puts
## that at a minute and a half of a director whose whole job is to be run often.
func _histogram(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := int(img.get_height() * WORLD_FRAC)
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	var raw := img.get_data()
	var counts: Array[int] = [0, 0, 0, 0, 0]
	var total := w * h
	var acc := 0
	var i := 0
	var n := total * 3
	while i < n:
		# Integer luma, so the number in the table is the number a viewer's eye
		# gets off the sRGB bytes rather than a linearised one nobody sees.
		var lum := (raw[i] * 299 + raw[i + 1] * 587 + raw[i + 2] * 114) / 1000
		acc += lum
		for b in BANDS.size():
			if lum < BANDS[b]:
				counts[b] += 1
				break
		i += 3
	var share: Array[float] = []
	for c: int in counts:
		share.append(100.0 * float(c) / float(total))
	return {"share": share, "mean": float(acc) / float(total)}


func _ck(label: String, ok: bool) -> void:
	if ok:
		print("RANGE ok %s" % label)
	else:
		_fails += 1
		print("RANGE FAIL %s" % label)


# --- What the floor is made of ------------------------------------------------

## Sides walled / sides open / sconces built, per room. This is the diagnostic the
## card asked for: the shortcut room's number is the answer.
func _print_floor(d: Node, level: int) -> void:
	var rooms: Dictionary = d.get(&"rooms")
	var floor_lights := 0
	for n in _all(d):
		if n is OmniLight3D:
			floor_lights += 1
	print("RANGE F%d %d omni light(s) on the floor" % [level, floor_lights])
	for cell: Vector2i in rooms:
		var r: Dictionary = rooms[cell]
		var node: Node = r["node"]
		if node == null:
			continue
		var doors: Array = r["doors"]
		var anchors: Dictionary = r["anchors"]
		var lit := 0
		for n in _all(node):
			if n is OmniLight3D:
				lit += 1
		print("RANGE F%d room %s dist=%d size=%.0f doors=%s anchors=%s -> %d light(s)"
			% [level, cell, r["dist"], r["size"], doors, anchors.keys(), lit])


func _room_centre(d: Node, near: Node3D) -> Vector3:
	var rooms: Dictionary = d.get(&"rooms")
	var best := near.global_position
	var far := -1.0
	for cell: Vector2i in rooms:
		var node: Node3D = rooms[cell]["node"]
		if node == null:
			continue
		var dist := node.global_position.distance_to(near.global_position)
		if far < 0.0 or dist < far:
			far = dist
			best = node.global_position
	return best


## A room carrying no anchor and holding more than one wall — the generated
## default, and the thing every fix here has to leave alone.
func _plain_room(d: Node) -> Node3D:
	var rooms: Dictionary = d.get(&"rooms")
	for cell: Vector2i in rooms:
		var r: Dictionary = rooms[cell]
		if not (r["anchors"] as Dictionary).is_empty():
			continue
		if cell == d.get(&"entrance") or cell == d.get(&"deepest"):
			continue
		return r["node"]
	return null


## `rooms[cell]["anchors"]` is keyed by SIDE, not by anchor id -- a first cut of
## this file looked for `&"gate_room"` in it and silently found nothing on every
## floor. `placements` is the dictionary keyed the other way.
func _gate_room(d: Node) -> Node3D:
	var placements: Dictionary = d.get(&"placements")
	var rooms: Dictionary = d.get(&"rooms")
	if placements.has(&"gate_room"):
		var cell: Vector2i = placements[&"gate_room"]["cell"]
		if rooms.has(cell):
			return rooms[cell]["node"]
	return null


# --- Fixture ------------------------------------------------------------------

func _rebuild(rig, level: int) -> Node:
	Run.level = level
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
	await rig.wait_frames(12)
	return d


func _clear_the_floor(d: Node) -> void:
	for e in _every(d, func(n: Node) -> bool: return n is Enemy):
		e.queue_free()
	_still_the_flames(d)


## Stop the torches guttering, for the duration of the measurement only.
##
## `KitTorch._process` swings `light_energy` by ±16% off `Time.get_ticks_msec()`
## — the **wall** clock, not the game clock, so `Engine.time_scale = 0` does not
## touch it and two runs of this director photograph two different frames of two
## different fires. That is invisible in a room lit by six sconces and it is not
## invisible in a corridor lit by one: the same corridor scored 36.0% and 40.1%
## under luminance 8 on consecutive runs, which is larger than most of the changes
## this file exists to detect. So the flame is held at its nominal energy while
## the histogram is taken. Nothing else about the lighting is touched, and the
## number under a frame is then the room's design rather than its phase.
##
## Re-assigning `light_energy` to itself is deliberate: the setter runs
## `_apply_light`, which is the only thing that puts the nominal value back into
## the `OmniLight3D` after `_process` has been multiplying it.
func _still_the_flames(d: Node) -> void:
	var n := 0
	for t in _every(d, func(x: Node) -> bool: return x is KitTorch):
		t.flicker = 0.0
		t.light_energy = t.light_energy
		n += 1
	print("RANGE held %d flame(s) at nominal energy for the measurement" % n)


func _stand_at(rig, hero: Node3D, door: Node3D, back: float) -> void:
	hero.velocity = Vector3.ZERO
	hero.global_position = door.global_position \
		+ door.global_transform.basis.z * back + Vector3(0.0, 0.15, 0.0)
	await _face_point(rig, hero, door.global_position)


func _face_point(rig, hero: Node3D, at: Vector3) -> void:
	var to := K.flat(at - hero.global_position)
	if to != Vector3.ZERO:
		hero.facing_yaw = atan2(to.x, to.z)
		hero.rotation.y = hero.facing_yaw + PI
	Bus.camera_recenter.emit()
	await rig.wait_physics_frames(6)
	await rig.wait_frames(24)


func _named(d: Node, what: String) -> Node:
	return _first(d, func(x: Node) -> bool: return x.name == what)


func _hero(rig) -> Node3D:
	var players: Array = rig.get_nodes_in_group(&"player")
	return players[0] if not players.is_empty() else null


func _game_camera(rig) -> Camera3D:
	for n in _all(rig.scene()):
		if n is GameCamera:
			return n
	return null


func _all(root: Node) -> Array:
	var found := [root]
	for c in root.get_children():
		found.append_array(_all(c))
	return found


func _first(root: Node, pred: Callable) -> Node:
	for n in _all(root):
		if pred.call(n):
			return n
	return null


func _every(root: Node, pred: Callable) -> Array:
	var found: Array = []
	for n in _all(root):
		if pred.call(n):
			found.append(n)
	return found
