extends RefCounted
## Proves the little health bars over the monsters, and proves the three
## conditions that keep them from being icon vomit (docs/STYLEGUIDE.md §5.5).
##
## ## How this director counts a bar, and why it stopped counting red pixels
##
## The bars are drawn by `Hud._draw_enemy_bars` straight into the overlay, so there
## is no node to inspect. This file used to answer that by scanning the WHOLE FRAME
## for flat horizontal runs of red and calling each one a bar -- and cards #51 and
## #64 are both that scan, failing on the courtyard rather than on the HUD:
##
##   * the smith's crate stack is a 12-14 px flat orange band at (866, 350), and it
##     was counted as a monster's bar in three of the four counting cases. Every
##     failure was "one more bar than the case spawned", every time the same band;
##   * it moved run to run, because a threshold sitting on the edge of a lit prop
##     is decided by whatever the torches did that frame;
##   * and case D "passed" only because the wall this director builds for the
##     occlusion case happens to stand in front of the crates.
##
## Two of those are a green beat that means nothing and one is a red beat about
## nothing, which is worse than no check at all. The scan's own discriminator had
## also quietly died: `_flat` separated the overlay from the world by "the HUD
## writes ONE colour, the world is a gradient" -- and since §4.5 the world renders
## into a 480x270 buffer quantized to RGB555, so a lit crate arrives as flat blocks
## of exactly one colour, several pixels wide. The ruler had become softer than the
## thing it was measuring.
##
## So the HUD publishes what it drew -- `Hud.enemy_bar_rects()`, populated inside
## `_draw_enemy_bars` by the same code that issues the draw calls, exactly as
## `_note`/`layout_rects()` does for the fixed furniture and for the same reason
## (HUD_PLAN decision 20). This director asserts on WHICH monsters got a bar, by
## identity, so no prop the garrison ever grows can add one.
##
## **It is still a photograph, and that is the point.** A rect list on its own is a
## claim that `draw_rect` was called, which is not a claim that anything is on
## screen -- so every published bar is then read back OUT OF THE CAPTURE: the fill
## must be `Pal.RUST` inside that rect, as many pixels wide as the monster's health
## says, and the frame must be the right colour. The rect says where to look; the
## ink says the bar exists. Deleting either half leaves a beat that cannot fail for
## the right reason.
##
## Run in GARRISON on purpose. It is lit, so a bar that fails to draw is a visible
## hole rather than a black rectangle on a black wall, and the occlusion case needs
## a wall this director can put wherever it likes.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/garrison.tscn \
##     --director=res://tools/directors/enemy_bars.gd --out=/tmp/ebar/x.png

## How far a pixel may sit from an authored palette colour and still count as that
## colour, per channel. Nearly exact on purpose, in `_bracket_hues` and in the bar
## ink alike: the HUD is composited at native resolution AFTER the world's buffer
## is upscaled, and it carries no alpha over the fill, so its pixels ARE the palette
## bytes. Measured on this tree: the goblin's fill reads (184, 56, 24) at x=457 and
## again at x=705, against a `Pal.RUST` of (184, 56, 24).
##
## The old whole-frame matcher believed otherwise -- it tested "red-dominant"
## because an exact compare had once found the bar in one frame and missed it in
## four. That was the 6880x2756 window being Lanczos-downscaled to 720p (#35, and
## CLAUDE.md §3's proof-frame row); `shoot.gd` renders 1:1 now. If a grade is ever
## put back over the overlay this tolerance is what will say so, loudly, instead of
## the beat quietly going soft.
const HUE_TOL := 0.012

## How far a published bar may sit from the monster's own unprojected head, in
## pixels. `_draw_enemy_bars` quantizes the anchor to the world's 480x270 grid --
## 2.67 px at 720p -- so a bar is never exactly over the head and must not be far
## from it either. This is the check that the rect list is about the monster the
## director means and not merely about a monster.
const NEAR_HEAD := Vector2(5.0, 8.0)

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
## -- it placed the hero and recentred, and inherited whatever facing the
## garrison spawn happened to give him. That worked until a merge moved the
## default, and then the sleeper was simply off screen: case B still "passed" (no
## bar, because no monster) and case C failed. A director that reads its own
## frames must own the framing.
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

	# **This director reads pixels, so it has to render at 1:1.**
	#
	# It used to resize the OS window itself. `shoot.gd` opened a 6880x2756 window
	# for a 1280x720 canvas and Lanczos-downscaled the shot — a 5.4x supersample,
	# and a supersample is a BLUR: measured on `eb_06_lock_hostile.png`, an
	# eight-stroke RUST bracket that should be ~128 pixels of exactly `c85038` came
	# back as **5**. Every other pixel of it was an intermediate blend of RUST and
	# the courtyard.
	#
	# `shoot.gd._size_the_window` does it for every director now (#35), so at
	# native resolution a 2 px stroke is 2 pixels of the exact authored colour and
	# `HUE_TOL` means what it says it means. This only reports what it got, because
	# a resize that stops taking must not be silent here.
	print("BARS render size=%s" % [DisplayServer.window_get_size()])

	# And it has to render the SAME frame twice — card #62, CLAUDE.md §3. Less
	# load-bearing than it was, now that the counting is done off the rect list
	# rather than off a threshold that a guttering torch could tip, but the ink
	# checks below are still colour compares inside a lit room and the brackets in
	# case G always were.
	rig.still_the_frame()

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
	print("BARS engaged %s state=%d" % [_seen(a), goblin.state])
	_only(a, [[goblin, "goblin"]], "engaged")
	_ink_ok(a, hero, goblin, "goblin", false)

	# --- B. Asleep and unhurt earns nothing ---------------------------------
	var sleeper := _spawn(scene, &"skeleton", AT_SLEEPER, false)
	await rig.wait_frames(24)
	await _settle(rig, [[goblin, AT_GOBLIN], [sleeper, AT_SLEEPER]])
	var b := await _shot(rig, "eb_01_asleep.png")
	print("BARS asleep %s sleeper_state=%d engaged=%s" % [
		_seen(b), sleeper.state, sleeper.is_engaged()])
	_want(not sleeper.is_engaged(),
		"the distant skeleton woke up on its own; case B proves nothing")
	# The two ways this case lies, both of which it has already told: the monster
	# is awake (so "no bar" is untested), or it is not in frame at all (so "no bar"
	# is a tautology). Assert the head is somewhere the bar COULD have been drawn.
	_want(_framed(hero, sleeper),
		"the sleeping skeleton was not on camera; case B proves nothing")
	_only(b, [[goblin, "goblin"]], "asleep")

	# --- C. Bleeding earns a bar even asleep --------------------------------
	# **And it has to still be asleep when the shutter opens**, which it was not.
	# `_on_damaged` puts the body in HURT and `_tick_hurt` hands it to `_wake()`
	# when the stagger ends, so a struck monster is CHASE a few frames later and
	# `is_engaged()` is true -- which is the OTHER clause of the HUD's condition.
	# Photographed like that, this case was case A a second time and the "or
	# already bleeding" half of §5.5 had no proof at all. Putting it back to IDLE
	# holds: the sleeper stands 12.7 m out, past its own 11 m detect, so
	# `_tick_idle` leaves it alone. The assertion below is what says so.
	_hurt(sleeper, 2)
	await _settle(rig, [[goblin, AT_GOBLIN], [sleeper, AT_SLEEPER]])
	sleeper.state = Enemy.State.IDLE
	await _settle(rig, [[goblin, AT_GOBLIN], [sleeper, AT_SLEEPER]])
	var c := await _shot(rig, "eb_02_asleep_hurt.png")
	print("BARS asleep_hurt %s sleeper_state=%d engaged=%s" % [
		_seen(c), sleeper.state, sleeper.is_engaged()])
	_want(not sleeper.is_engaged(),
		"the hurt skeleton is engaged, so case C is testing the same clause as "
		+ "case A and 'bleeding earns a bar' is unproven")
	_only(c, [[goblin, "goblin"], [sleeper, "sleeper"]], "asleep_hurt")
	_ink_ok(c, hero, sleeper, "sleeper", false)

	# --- D. A wall takes it away -------------------------------------------
	# The whole reason the occlusion ray exists: without it this feature is an
	# x-ray that reads monsters through walls.
	var cam := hero.get_viewport().get_camera_3d()
	var wall := _wall(scene, cam.global_position, sleeper.global_position)
	await _settle(rig, [[goblin, AT_GOBLIN], [sleeper, AT_SLEEPER]])
	var d := await _shot(rig, "eb_03_occluded.png")
	print("BARS occluded %s" % [_seen(d)])
	_only(d, [[goblin, "goblin"]], "occluded")
	wall.queue_free()
	await rig.wait_frames(4)

	# --- E. The locked target's bar is wider --------------------------------
	var plain: float = _rect(c, goblin).size.x
	Bus.target_acquired.emit(goblin)
	await _settle(rig, [[goblin, AT_GOBLIN], [sleeper, AT_SLEEPER]])
	var e := await _shot(rig, "eb_04_locked.png")
	var locked: float = _rect(e, goblin).size.x
	# Both halves reported: the rect the HUD says it drew, and the RUST actually in
	# the picture. A widening that exists only in the layout would be a lie the ink
	# catches, and vice versa.
	print("BARS locked plain=%.0f locked=%.0f ratio=%.2f ink=%d" % [
		plain, locked, locked / maxf(plain, 1.0), _run(e, _rect(e, goblin), Pal.RUST)])
	_want(locked > plain,
		"the locked target's bar (%.0f px) is not wider than an ordinary one (%.0f px)"
			% [locked, plain])
	_ink_ok(e, hero, goblin, "locked goblin", false)
	Bus.target_lost.emit()
	await rig.wait_frames(6)

	# --- F. An elite is framed in BONE, and is bigger ----------------------
	var elite := _spawn(scene, &"orc", AT_ELITE, true)
	await rig.wait_frames(24)
	_hurt(elite, 4)
	await _settle(rig, [[goblin, AT_GOBLIN], [sleeper, AT_SLEEPER], [elite, AT_ELITE]])
	var f := await _shot(rig, "eb_05_elite.png")
	print("BARS elite %s height=%.2f elite=%s bone=%d/%d" % [
		_seen(f), elite.head_point().y - elite.global_position.y, elite.elite,
		_ink(f, _rect(f, elite), Pal.BONE), _ink(f, _rect(f, goblin), Pal.BONE)])
	_only(f, [[goblin, "goblin"], [sleeper, "sleeper"], [elite, "elite"]], "elite")
	_ink_ok(f, hero, elite, "elite", true)

	# --- G. The lock bracket says WHAT KIND, three ways ---------------------
	# Decisions 16, 22 and 31. The bracket used to be RUST for everything; it now
	# carries hue, shape and arm length together, so that "can I hook that" is not
	# a red-against-cyan judgement made mid-fight — which is the commonest form of
	# colour blindness there is, on the one element the player is looking directly
	# at.
	#
	# The targets are bare `Node3D`s in the groups `Targeting` walks, and the lock
	# is driven straight through `Bus.target_acquired` exactly as case E does.
	# Building a real hookshot anchor would be testing the anchor.
	Bus.target_lost.emit()
	# Beside the GOBLIN and not beside the sleeper: the sleeper stands in front of
	# the garrison's cyan-lit gate, and a bracket measured against that background
	# answers a question about the courtyard. The hostile case measured clean here
	# (rust=124, cyan=0) which is what makes this the honest spot.
	var hookable := _dummy(scene, AT_GOBLIN + Vector3(2.2, 0.0, 0.0),
		[&"targetable", &"hookable"])
	var neutral := _dummy(scene, AT_GOBLIN + Vector3(-2.2, 0.0, 0.0),
		[&"targetable"])
	await rig.wait_frames(6)

	# Three locks, three photographs, and the count of each bracket colour inside
	# the box the bracket occupies. What makes this measurable at all is `run`'s
	# native-resolution window: two earlier attempts at this beat both failed on
	# the courtyard rather than on the HUD, because a supersampled 2 px stroke is
	# not the colour it was drawn in.
	for case: Array in [[goblin, Pal.RUST, "hostile"],
			[hookable, Pal.CYAN, "hookable"], [neutral, Pal.MOTH, "neutral"]]:
		var node: Node3D = case[0]
		var want: Color = case[1]
		var label: String = case[2]

		Bus.target_acquired.emit(node)
		await _settle(rig, [[goblin, AT_GOBLIN], [sleeper, AT_SLEEPER]])
		var on_path := _out.path_join("eb_06_lock_%s.png" % label)
		await rig.capture(on_path)

		var on := Image.load_from_file(on_path)
		if on == null:
			_want(false, "could not read back %s" % on_path)
			continue
		var counts := _bracket_hues(on, hero, node)
		print("BARS lock_%s rust=%d cyan=%d moth=%d" % [
			label, counts[0], counts[1], counts[2]])
		var got: int = counts[[Pal.RUST, Pal.CYAN, Pal.MOTH].find(want)]
		var most: int = maxi(counts[0], maxi(counts[1], counts[2]))
		_want(got > 0 and got == most,
			"the %s bracket is not mostly its own colour (rust=%d cyan=%d moth=%d)"
				% [label, counts[0], counts[1], counts[2]])
	Bus.target_lost.emit()

	if _fails == 0:
		print("BARS OK all cases passed")


# --- Setup helpers ----------------------------------------------------------

## A bare targetable. It has no health, no model and no `target_point()`, which
## is the point: `Hud._lock_kind` reads GROUPS, and a dummy proves it reads them
## rather than sniffing for an `Enemy`.
func _dummy(scene: Node, at: Vector3, groups: Array) -> Node3D:
	var n := Node3D.new()
	scene.add_child(n)
	n.global_position = at
	for g: StringName in groups:
		n.add_to_group(g)
	return n


## How many pixels of each of the three bracket colours are inside the box the
## bracket is drawn in. Returns [rust, cyan, moth].
##
## The box is the bracket's own half-extents (26 x 34 reference px) plus the
## longest arm, unprojected about the same point `Hud._draw_lock_on` uses. It has
## to be tight: this scene has a cyan-lit gate in it and every monster on screen
## wears a RUST health bar, so a whole-frame count answers a different question
## every time the camera moves.
##
## `HUE_TOL` does the other half. The brackets are drawn with no alpha, straight
## from `Pal`, so at the native resolution `run` forces they land as the EXACT
## authored bytes -- and nothing in a courtyard of photographed sandstone is
## exactly `807868`. A loose tolerance is what made the hostile case read moth=95
## against rust=99 off the flagstones.
func _bracket_hues(img: Image, hero: Node3D, target: Node3D) -> Array:
	var cam := hero.get_viewport().get_camera_3d()
	if cam == null:
		return [0, 0, 0]
	var c := cam.unproject_position(target.global_position + Vector3(0.0, 0.8, 0.0))
	var s := Vector2(img.get_size())
	var half := Vector2(Pal.px(26.0, s.y), Pal.px(34.0, s.y)) + Vector2.ONE * Pal.px(14.0, s.y)
	var box := Rect2(c - half, half * 2.0).intersection(Rect2(Vector2.ZERO, s))
	var out := [0, 0, 0]
	var wants := [Pal.RUST, Pal.CYAN, Pal.MOTH]
	for y in range(int(box.position.y), int(box.end.y)):
		for x in range(int(box.position.x), int(box.end.x)):
			var px := img.get_pixel(x, y)
			for i in 3:
				var w: Color = wants[i]
				if _same(px, w):
					out[i] = int(out[i]) + 1
	return out



func _spawn(scene: Node, kind: StringName, at: Vector3, elite: bool) -> Enemy:
	var e := Enemy.new()
	e.kind = kind
	e.drop_seed = 4400 + int(absf(at.x) * 7.0)
	e.elite = elite
	# Named, because `_only`'s failure line prints the node behind every bar the
	# HUD drew, and `@CharacterBody3D@894` names nothing.
	e.name = String(kind) + ("_elite" if elite else "")
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


func _hurt(e: Enemy, health_points: int) -> void:
	# Straight at the component. `DamageArea` looks for `take_hit` first and falls
	# back to this, and `Enemy` has no `take_hit` -- docs/CONTRACT.md §8.
	e.health.apply_hit(Hit.make(health_points, e.global_position + Vector3.FORWARD,
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

## One beat: the capture, and the bars the HUD says it drew on it.
##
## The rect list is read straight after the shutter and never earlier. `Hud`
## repaints every frame while there are monsters in the tree (`_wake`), so the
## dictionary belongs to the frame in the PNG -- and every case holds its monsters
## still with `_settle` first, so a frame either side of the shutter would say the
## same thing anyway.
func _shot(rig, name: String) -> Dictionary:
	var path := _out.path_join(name)
	await rig.capture(path)
	var rects: Dictionary = Hud.enemy_bar_rects().duplicate()
	var img := Image.load_from_file(path)
	if img == null:
		_want(false, "could not read back the capture at %s" % path)
	return {&"img": img, &"rects": rects, &"name": name}


## The published bars must be EXACTLY the monsters this case expects -- no fewer,
## and just as importantly no more.
##
## "No more" is the whole of cards #51 and #64. The old whole-frame scan could only
## say "three red runs", so an orange crate and a monster were the same observation;
## this says WHICH bodies drew, by instance, and prints the node behind any id it
## did not expect. A garrison prop cannot be one of those ids, and if a keeper ever
## did join the `enemy` group with a health component, this is the beat that would
## name him instead of silently counting him.
func _only(shot: Dictionary, want: Array, tag: String) -> void:
	var rects: Dictionary = shot[&"rects"]
	var missing: Array = []
	var ids: Array = []
	for w: Array in want:
		var n: Node3D = w[0]
		ids.append(n.get_instance_id())
		if not rects.has(n.get_instance_id()):
			missing.append(w[1])
	var extra: Array = []
	for id: int in rects:
		if ids.has(id):
			continue
		var n := instance_from_id(id) as Node
		extra.append("%s(%s)" % [n.name if n != null else "<freed>",
			n.get_class() if n != null else id])
	_want(missing.is_empty(),
		"%s: no bar was drawn for %s (drew %d: %s)"
			% [tag, str(missing), rects.size(), _seen(shot)])
	_want(extra.is_empty(),
		"%s: the HUD drew a bar for %s, which this case does not expect to have one"
			% [tag, str(extra)])


## The bar the HUD says it drew for this monster is actually in the picture, is
## over that monster's head, and is as full as its health.
##
## Three separate claims and all three are the point of the beat:
##
##   * `Pal.RUST` inside the rect, at all -- a bar that was "drawn" into a
##     zero-sized rect, or over itself in `Pal.VOID`, publishes exactly the same
##     dictionary entry as a working one;
##   * the widest run of it matching `round(inner_width * fraction)` to a pixel --
##     which ties the ink to the monster's own health rather than to a constant, so
##     a fill that stops tracking damage is a red beat;
##   * the rect sitting over the head the HUD unprojected, within the 480x270
##     quantization step -- so this is a bar over THIS monster and not merely a bar.
func _ink_ok(shot: Dictionary, hero: Node3D, e: Enemy, label: String,
		elite: bool) -> void:
	var img: Image = shot[&"img"]
	var rects: Dictionary = shot[&"rects"]
	if img == null or not rects.has(e.get_instance_id()):
		return  # `_only` has already reported this one.
	var r: Rect2 = rects[e.get_instance_id()]
	var b := Pal.px(Hud.EBAR_BORDER, float(img.get_height()))
	var inner := r.size.x - b * 2.0
	var want_fill := roundf(inner * e.health.fraction())
	var got := _run(shot, r, Pal.RUST)
	_want(absf(float(got) - want_fill) <= 1.0,
		"%s's bar is %d px of RUST in the frame, and its health says %.0f of %.0f"
			% [label, got, want_fill, inner])

	# The frame around it. BONE for an elite is the only per-kind mark on the HUD
	# (`Hud._draw_enemy_bars`), so it is worth a pixel and not just a print.
	var bone := _ink(shot, r, Pal.BONE)
	_want(bone > 0 if elite else bone == 0,
		"%s's bar frame is %s BONE (%d px) — an elite's frame is BONE and an "
			% [label, "not" if elite else "wrongly", bone]
			+ "ordinary one is VOID")

	# `_draw_enemy_bars` hangs the bar's top-left off the unprojected head, so the
	# rect's centre sits half a bar below it -- 1 px at 720p, inside the tolerance
	# the quantization already forces. Comparing centres keeps this a statement
	# about WHERE, not a re-derivation of the HUD's own arithmetic.
	var cam := hero.get_viewport().get_camera_3d()
	var head := cam.unproject_position(e.head_point())
	var off := (r.get_center() - head).abs()
	_want(off.x <= NEAR_HEAD.x and off.y <= NEAR_HEAD.y,
		"%s's bar %s is %s px from its own head at %s" % [label, r, off, head])


## Pixels of `col` inside `r`.
func _ink(shot: Dictionary, r: Rect2, col: Color) -> int:
	var img: Image = shot[&"img"]
	if img == null:
		return 0
	var box := r.intersection(Rect2(Vector2.ZERO, Vector2(img.get_size())))
	var n := 0
	for y in range(int(box.position.y), int(box.end.y)):
		for x in range(int(box.position.x), int(box.end.x)):
			if _same(img.get_pixel(x, y), col):
				n += 1
	return n


## Longest horizontal run of `col` inside `r`. The fill's width, in other words --
## the number the health has to explain.
func _run(shot: Dictionary, r: Rect2, col: Color) -> int:
	var img: Image = shot[&"img"]
	if img == null:
		return 0
	var box := r.intersection(Rect2(Vector2.ZERO, Vector2(img.get_size())))
	var best := 0
	for y in range(int(box.position.y), int(box.end.y)):
		var run := 0
		for x in range(int(box.position.x), int(box.end.x)):
			if _same(img.get_pixel(x, y), col):
				run += 1
				best = maxi(best, run)
			else:
				run = 0
	return best


## Is this pixel that palette colour? See `HUE_TOL`.
func _same(px: Color, col: Color) -> bool:
	return absf(px.r - col.r) < HUE_TOL and absf(px.g - col.g) < HUE_TOL \
		and absf(px.b - col.b) < HUE_TOL


func _rect(shot: Dictionary, e: Node3D) -> Rect2:
	var rects: Dictionary = shot[&"rects"]
	return rects.get(e.get_instance_id(), Rect2())


## What the HUD says it drew, as `name@x,y w x h`, for the log line of each case.
func _seen(shot: Dictionary) -> String:
	var rects: Dictionary = shot[&"rects"]
	var out: Array = []
	for id: int in rects:
		var n := instance_from_id(id) as Node
		var r: Rect2 = rects[id]
		out.append("%s@%.0f,%.0f %.0fx%.0f" % [
			n.name if n != null else "<freed>", r.position.x, r.position.y,
			r.size.x, r.size.y])
	out.sort()
	return "bars=%d %s" % [rects.size(), str(out)]


func _want(ok: bool, why: String) -> void:
	if ok:
		return
	_fails += 1
	print("BARS FAIL " + why)
