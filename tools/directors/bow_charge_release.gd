extends RefCounted
## Photographs a bow shot across BOTH of its clips, so the charge and the loose
## are things somebody looked at rather than two node names in a blend tree.
##
## The shot this exists to catch was not a crash. It was one clip —
## `bow_aim_recoil`, the follow-through — stretched over the whole commitment
## window, which passed every assertion `ranged_kit` makes (an arrow existed, it
## hurt the post, it cost one ammo) while the hero visibly never drew the bow.
## Nothing but a strip of frames says which of those two you are looking at.
##
## It now also owns the TRIGGER, which is the second thing a passing assertion
## could not tell you about. `heavy` is a held trigger: down pulls, up looses,
## and the shot waits at full draw for as long as the player waits. It fired on
## the press for a while — so pulling RT to aim spent the arrow before the stick
## had moved — and every beat below still passed, because an arrow that leaves
## too early is still an arrow. The hold beat is the one that can tell.
##
## The third thing is where he ends up. The stance belongs to the BUTTON, not to
## the bow being in his hand, so the shot has to hand him back to an ordinary
## standing pose holding the bow rather than leaving him at full draw forever.
##
##   godot --path . -s tools/shoot.gd -- \
##     --scene=res://scenes/rooms/training.tscn \
##     --director=res://tools/directors/bow_charge_release.gd --out=/tmp/bow/x.png
##
## Prints `BOWSHOT FAIL …` on any beat that did not happen.

## Fractions of each phase to photograph. The last charge sample and the first
## loose sample sit hard against the seam from either side: the seam is the whole
## claim — full draw on one frame, string away on the next — and a strip that
## steps over it proves two clips played without proving they MEET.
const CHARGE_AT: Array[float] = [0.02, 0.35, 0.68, 0.97]
const LOOSE_AT: Array[float] = [0.05, 0.30, 0.60, 0.95]

## The game runs at a fifth speed for the strip. A 0.44 s draw is 26 frames, and
## grabbing a 1280x720 backbuffer costs more than one of them — sampled at speed,
## the clock jumps past the times asked for and the strip is whatever frames the
## machine happened to be free on. Slowing the whole engine scales the shot
## clock, the TimeScale nodes and the blend together, so these are the real poses
## of the real shot, just handed over slowly enough to photograph.
const SLOW := 0.2

## Turn off dead-on so the drawn arm reads. Straight down the lens hides the pull.
const FACE_OFFSET := 0.7

## Pixels of the 1280x720 frame kept around the hero. Tall rather than square:
## the whole read is a bow held vertically and an arm going back past his ear.
const CROP := Vector2i(420, 600)

## The hold beat's box. Wider and taller than the strip's, because it is asking a
## different question: the strip wants the bowstring, and this wants the whole
## SILHOUETTE — a bow held down at his side reads as an arm and a hip, and a box
## framed on a bowstring that is no longer drawn crops both of them out.
const HOLD_CROP := Vector2i(800, 760)

var _fails := 0


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

	var out: String = rig.arg("out", "/tmp/bow/x.png").get_base_dir()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await rig.wait_frames(20)

	# Annotated, not inferred: `rig` is untyped, so every call on it yields
	# Variant and `:=` on one is the "cannot infer the type of X" parse error
	# (CLAUDE.md §3).
	var heroes: Array = rig.get_nodes_in_group(&"player")
	if heroes.is_empty():
		_fail("no hero in the scene")
		return
	var hero: Hero = heroes[0]
	var tree: AnimationTree = hero._tree
	if tree == null or hero.ranged == null:
		_fail("no AnimationTree / no HeroRanged")
		return

	# D-pad → steps the ring to the bow. Pressed, not set behind the game's back
	# (docs/CONTRACT.md §4.1).
	await rig.draw_weapon(&"bow")
	await rig.wait_frames(24)
	if Game.armament(Game.HAND_RIGHT) != &"bow":
		_fail("the weapon ring did not put the bow in his hand")
		return
	_ok("the bow is in his hand")

	# Three-quarters to the lens by the contract's heading formula (§2.5). The
	# aim owns his facing the instant the shot starts, so this only frames the
	# stance he is standing in beforehand.
	var cam: Camera3D = hero.get_viewport().get_camera_3d()
	if cam == null:
		_fail("no camera")
		return
	var to_cam: Vector3 = K.flat(cam.global_position - hero.global_position)
	hero.facing_yaw = atan2(to_cam.x, to_cam.z) + FACE_OFFSET
	await rig.wait_frames(20)

	var draw_time: float = Game.bow_draw_time()
	var loose_time: float = HeroRanged.BOW_LOOSE
	print("BOWSHOT draw=%.2fs loose=%.2fs total=%.2fs"
		% [draw_time, loose_time, draw_time + loose_time])

	await _hold_beat(rig, hero, cam, out, draw_time, loose_time)

	# The sample times, in shot seconds, and what each one is supposed to show.
	var marks: Array = []
	for f in CHARGE_AT:
		marks.append({"t": draw_time * f, "phase": "charge"})
	for f in LOOSE_AT:
		marks.append({"t": draw_time + loose_time * f, "phase": "loose"})

	Engine.time_scale = SLOW
	await rig.tap(["heavy"])

	var shots: Array[Image] = []
	var seen_charge_active := false
	var seen_loose_active := false
	var arrow_at := -1.0
	var free_during_pull := false
	var committed_in_loose := false
	var next := 0
	# Bounded by REAL frames, not by the shot clock: a shot that never starts
	# would otherwise spin here forever.
	for _i in 4000:
		await rig.wait_frames(1)
		var t: float = hero.ranged._bow_t
		if t < 0.0 and next == 0:
			continue  # the press has not landed yet
		# `active` is the OneShot's own answer to "am I playing", which is the
		# only witness that does not just restate the code that fired it.
		if bool(tree.get("parameters/BowDraw/active")):
			seen_charge_active = true
		if bool(tree.get("parameters/Ranged/active")):
			seen_loose_active = true
		if arrow_at < 0.0 and _arrows_in_flight(rig) > 0:
			arrow_at = t
		# Sampled INSIDE the shot, not after it. The follow-through is half the
		# point of splitting the clips: an archer who is walking again the frame
		# the arrow leaves has paid for the loose and not been charged for it.
		# The pull is the opposite claim and wants the opposite witness.
		if t >= 0.0 and t < draw_time * 0.9:
			free_during_pull = free_during_pull or hero.state == Hero.MoveState.GROUND
		if t >= draw_time and t < draw_time + loose_time * 0.8:
			committed_in_loose = committed_in_loose \
				or hero.state == Hero.MoveState.ATTACK
		if next >= marks.size():
			break
		if t < 0.0:
			break  # the shot ended before the last mark; the loop below reports it
		if t >= float(marks[next]["t"]):
			var frame: Image = await _grab(rig, cam, hero)
			shots.append(frame)
			print("BOWSHOT   %-6s t=%.3f  charge=%s loose=%s" % [
				marks[next]["phase"], t,
				tree.get("parameters/BowDraw/active"),
				tree.get("parameters/Ranged/active")])
			next += 1

	Engine.time_scale = 1.0

	_check("the charge clip played", seen_charge_active)
	_check("the loose clip played", seen_loose_active)
	_check("every sample was photographed (%d/%d)" % [shots.size(), marks.size()],
		shots.size() == marks.size())
	# The seam, from the side that can lie. An arrow that leaves during the pull
	# is the one-clip bug wearing two clips.
	_check("the arrow left at the seam, not during the pull (t=%.3f, draw=%.2f)"
		% [arrow_at, draw_time], arrow_at >= draw_time * 0.9)
	# The commitment is the LOOSE and only the loose now. The pull is a stance he
	# can walk in, because it lasts as long as the player holds the trigger and
	# there is no such thing as rooting someone for an unbounded window.
	_check("the hero was committed for the follow-through", committed_in_loose)
	_check("the pull left him free to move", free_during_pull)
	# And he is handed back afterwards. A commitment window that never closes is
	# the same bug as one that never opens, and it looks identical up to here.
	await rig.wait_seconds(0.5)
	_check("the shot handed the hero back", hero.state == Hero.MoveState.GROUND
		and hero.ranged._bow_t < 0.0)

	if not shots.is_empty():
		var sheet := Image.create_empty(
			shots[0].get_width() * shots.size(), shots[0].get_height(),
			false, shots[0].get_format())
		for i in shots.size():
			sheet.blit_rect(shots[i], Rect2i(Vector2i.ZERO, shots[i].get_size()),
				Vector2i(shots[i].get_width() * i, 0))
		var path := out.path_join("bow_charge_release.png")
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		sheet.save_png(path)
		print("BOWSHOT strip -> %s" % path)

	print("BOWSHOT done, %d failure(s)" % _fails)


## The trigger, held. The bug: pulling RT drew AND loosed, so a player bringing
## the bow up to aim had already spent the arrow before the stick moved.
##
## Held for three times the draw. That is the whole test — anything that fires on
## its own clock rather than on the release will have gone by then, and the
## `_bow_t` reading says which: parked exactly at `_bow_draw` is a hero standing
## at full draw waiting, and anything past it is a shot that went without him.
##
## Then the release, and then the REST — he lowers the bow rather than staying at
## full draw, which is what `aim_item()` going quiet means. Both states are
## photographed side by side, because "he goes back to a resting position" is a
## claim about a pose and no counter can make it for you.
func _hold_beat(rig, hero: Hero, cam: Camera3D, out: String,
		draw_time: float, loose_time: float) -> void:
	var before: int = Game.arrows
	var ranged: HeroRanged = hero.ranged

	await rig.wait_frames(1)
	Input.action_press(&"heavy")

	var held_frames := int(draw_time * 3.0 * Engine.physics_ticks_per_second)
	var fired_while_held := false
	for _i in held_frames:
		await rig.wait_frames(1)
		if Game.arrows < before or _arrows_in_flight(rig) > 0:
			fired_while_held = true
			break

	var t_held: float = ranged._bow_t
	var stance_held: StringName = hero.aim_item()
	var full_draw: Image = await _grab(rig, cam, hero, HOLD_CROP)

	_check("holding the trigger did not loose the arrow", not fired_while_held)
	_check("he waited AT full draw (t=%.3f, draw=%.2f)" % [t_held, draw_time],
		absf(t_held - draw_time) < 0.05)
	_check("the full-draw stance was up while held (%s)" % stance_held,
		stance_held == &"bow")

	# And he can WALK there, which is the other half of taking the commitment off
	# the pull. A hold is open-ended; rooting a player for one is a freeze with a
	# button attached, and `AimLoco`'s aim-walk existed for years without ever
	# being reachable because the stance only ever lasted as long as a shot.
	var from_pos: Vector3 = hero.global_position
	Input.action_press(&"move_left")
	await rig.wait_frames(36)
	var walked: float = K.flat(hero.global_position - from_pos).length()
	var walking: Image = await _grab(rig, cam, hero, HOLD_CROP)
	Input.action_release(&"move_left")
	_check("he could walk at full draw (%.2f m)" % walked, walked > 0.5)
	_check("...and was still at full draw after it (t=%.3f)" % ranged._bow_t,
		absf(ranged._bow_t - draw_time) < 0.05)
	DirAccess.make_dir_recursive_absolute(out)
	walking.save_png(out.path_join("bow_hold_walk.png"))

	Input.action_release(&"heavy")

	# Generous: the loose has to start, spawn the arrow and run its clip out.
	var fired_after := false
	for _i in int((loose_time + 0.5) * Engine.physics_ticks_per_second):
		await rig.wait_frames(1)
		if Game.arrows < before:
			fired_after = true
			break
	_check("releasing the trigger loosed the arrow", fired_after)

	await rig.wait_seconds(loose_time + 0.6)
	var rest: Image = await _grab(rig, cam, hero, HOLD_CROP)
	_check("he lowered the bow afterwards (stance=%s)" % hero.aim_item(),
		hero.aim_item() == &"")
	_check("the shot ended and gave the body back",
		ranged._bow_t < 0.0 and hero.state == Hero.MoveState.GROUND)
	# The bow is still IN HIS HAND. Lowering it must not put it away — that is the
	# D-pad's job, and a trigger that stowed the item would make every second shot
	# cost two presses.
	_check("the bow is still drawn (right hand = %s)"
		% Game.armament(Game.HAND_RIGHT), Game.armament(Game.HAND_RIGHT) == &"bow")

	_save_pair(full_draw, rest, out.path_join("bow_hold_release.png"))
	print("BOWSHOT hold strip -> %s" % out.path_join("bow_hold_release.png"))

	# THIS arrow has to be gone before the strip beat starts counting them, or the
	# strip reads it as an arrow that left during its own pull — which is exactly
	# the failure the strip exists to catch, reported against the wrong shot.
	for _i in 600:
		if _arrows_in_flight(rig) == 0:
			break
		await rig.wait_frames(1)


## Two frames side by side: held at full draw, and lowered afterwards.
func _save_pair(a: Image, b: Image, path: String) -> void:
	var sheet := Image.create_empty(a.get_width() + b.get_width(),
		maxi(a.get_height(), b.get_height()), false, a.get_format())
	sheet.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
	sheet.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(a.get_width(), 0))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	sheet.save_png(path)


## One rendered frame, CROPPED to the hero rather than scaled down.
##
## Eight full frames side by side is a 10 k image nobody can read, and halving
## them is worse than useless here: over the shoulder the hero is a sixth of the
## picture, and the thing under test is a bowstring. The crop box is unprojected
## off his chest every frame, so it follows him and the strip is comparable frame
## to frame. Clamped into the viewport so a hero near the edge yields a smaller
## box rather than a black margin — `blit_rect` on an out-of-bounds source is
## silent, and a silently empty photograph is the one failure this whole director
## exists to prevent.
func _grab(rig, cam: Camera3D, hero: Hero, crop: Vector2i = CROP) -> Image:
	await RenderingServer.frame_post_draw
	var img: Image = rig.root.get_texture().get_image()
	var chest: Vector2 = cam.unproject_position(
		hero.global_position + Vector3.UP * (K.HERO_H * 0.6))

	# `unproject_position` answers in the LOGICAL viewport (1280x720 here); on this
	# Mac the backbuffer comes back hiDPI at 3456x1944. Cropping at the raw
	# unprojected point put the box 2.7x too far up and left — dead centre on a
	# barrel across the room — and it did it silently, in a photograph, which is
	# the exact failure mode CLAUDE.md §2 is about. `shoot.gd:capture` normalises
	# the same mismatch by resizing; this scales into image space instead, because
	# the whole reason to crop is to keep the pixels.
	var logical: Vector2 = cam.get_viewport().get_visible_rect().size
	var zoom := Vector2(
		img.get_size().x / maxf(logical.x, 1.0),
		img.get_size().y / maxf(logical.y, 1.0))

	# The size is FIXED and the corner is what moves. Clamping the rect instead
	# would hand back a different box on any frame he drifts near an edge, and the
	# sheet below sizes itself off the first shot — mismatched frames blit
	# silently and the strip quietly loses its right-hand side.
	var size := Vector2i(Vector2(crop) * zoom).min(img.get_size())
	var corner := Vector2i(chest * zoom) - size / 2
	corner = corner.clamp(Vector2i.ZERO, img.get_size() - size)
	return img.get_region(Rect2i(corner, size))


func _arrows_in_flight(rig) -> int:
	var n := 0
	for node in rig.scene().get_children():
		if node is Arrow:
			n += 1
	return n


func _check(what: String, pass_: bool) -> void:
	if pass_:
		_ok(what)
	else:
		_fail(what)


func _ok(what: String) -> void:
	print("BOWSHOT ok   %s" % what)


func _fail(what: String) -> void:
	_fails += 1
	print("BOWSHOT FAIL %s" % what)
