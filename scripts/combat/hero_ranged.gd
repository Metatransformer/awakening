class_name HeroRanged
extends Node3D
## The hero's two ranged items: the bow and the hookshot. Everything either of
## them needs that is not presentation — the aim, the raycast, the ammo, and the
## hookshot's ownership of the hero while he is being dragged through the air.
##
## A sibling of `HeroCombat` rather than more of it. HeroCombat is about the
## sword arm: the swing, the block cone, the sockets every model hangs off. What
## an arrow does after it leaves has nothing to do with any of that, and the one
## thing the two genuinely share — which item is in the right hand — already
## lives on `Game`, where it survives the scene change. HeroCombat still owns the
## attack BUTTON (one reader, docs/CONTRACT.md §4) and hands the use button's two
## edges — `use_press` and `use_release` — down here when the hand holding it is
## not holding the sword.
##
## ## The trigger is HELD, and the shot is the release
##
## Both items are pull-to-ready, release-to-fire. `use_press` raises the item —
## the bow starts pulling, the hookshot comes up into its brace — and `use_release`
## is what actually looses. They fired on the PRESS for a while, which made
## holding the trigger indistinguishable from tapping it: you pulled RT to aim,
## and the shot was already gone before you had moved the stick. A button that
## fires on the press cannot be aimed with, and both of these items are aimed.
##
## The release is also what puts him back down. `aim_item()` — the stance — is
## true only between the press and the end of the shot, so when the arrow has
## gone he lowers the bow and stands in ordinary locomotion holding it, until the
## next pull. That resting beat did not exist while the stance was equipment-
## driven: drawing the bow from the D-pad put him at full draw and left him
## there, permanently, which is what a held C-button used to mean and is no
## longer what the item button means.
##
## ## A bow shot is two halves, and this owns the clock between them
##
## Pull then loose: `_bow_draw` seconds of pull, the arrow, then `BOW_LOOSE`
## seconds of follow-through. Two clips (see `Hero.clip_bow_draw`), fired from
## two one-shots, and the seam between them is the only moment the shot has —
## `_tick_bow` spawns the arrow and fires the second clip on the same frame off
## the same counter. What the hero is NOT is the thing timing them, because a
## body counting its own frames next to a `HeroRanged` counting its own is how
## the arrow and the string come apart.
##
## Held past full draw the clock STALLS at `_bow_draw` rather than running on —
## he sits at full draw for as long as the trigger is down. Released early it
## does not stall and does not cut the pull short either: the arrow leaves at the
## seam it was always going to leave at. A tap is therefore exactly the shot the
## button used to fire, which is what keeps `Game.bow_draw_time()` — the forge
## ladder — meaning the thing it says it means, and what stops a mashed trigger
## from being faster than an aimed one.
##
## Only the LOOSE commits the hero. The pull is a stance he can walk in
## (`Hero.request_bow_draw`), because a hold has no length anybody knows in
## advance and rooting a player for an unbounded one is a freeze with a button
## attached.
##
## ## The hookshot bites monsters, and does them no harm at all
##
## A shot that lands on a body is a THIRD outcome, alongside "found an anchor" and
## "played out to nothing". It deals zero damage — deliberately, not as an
## oversight; `HealthComponent.apply_hit` would refuse a zero-quarter blow even if
## one were sent — and it does not pull the hero either, because reeling him into
## the monster he has just stopped would spend the shot's own reward on closing
## the distance he wanted. What it buys is a second of `K.HOOK_FREEZE`: the thing
## goes blue, holds still, and thaws (`Enemy.freeze`). That is the swing, or the
## walk past, or the time to nock an arrow.
##
## ## Aim comes from the camera, not from the body
##
## The hero's facing is a yaw. A hookshot that can only be aimed in yaw cannot
## reach a ceiling ring, which is most of what a hookshot is for. The camera is
## the only thing in this game that carries a player-controlled PITCH (`_pitch`,
## clamped to ±55° in game_camera.gd), so the camera's forward is the aim — the
## same source movement already reads (docs/CONTRACT.md §4, camera-relative).
## Locked on, both items override that and shoot the target, because that is the
## whole promise of the lock.
##
## ## Aim mode is the TRIGGER, not the D-pad
##
## Because the aim IS the camera, pulling one of these has to change the camera,
## or the player is aiming a weapon with a rig framed for running around. So the
## trigger raises `Bus.aim_changed(true)`: the boom drops to the hero's shoulder,
## the FOV narrows, the HUD puts a crosshair on the middle of the screen, and the
## hero turns to face wherever the lens is pointed. Letting go drops all of it
## again. This node is the only emitter — it is the one place that knows what is
## in his hands and whether it is up.
##
## Selecting the item does NOT do that, and used to. Choosing the bow on the
## D-pad zoomed the game into a sight and left it there: you crossed a room in
## over-the-shoulder framing at 42° of lens with a crosshair on the wall, having
## asked for none of it. Carrying a bow is not aiming a bow.

## Seconds of loose and follow-through after the arrow leaves — the second half
## of a bow shot, and the second of its two clips (`Hero.clip_bow_shot`).
##
## FIXED, where the draw in front of it is the forge ladder `Game.bow_draw_time()`
## (K.BOW_DRAW). That split is the whole shape of the upgrade: a better string
## lets you pull faster, it does not make the arrow leave your hand faster once
## you have let go. Buying the string therefore buys back a shrinking share of
## the shot, which is what a ladder that tops out is supposed to feel like.
##
## 0.30 s against a 0.70 s clip is a 2.3x compression — the snap reads and the
## settle does not outstay it. He is committed for all of it: a bow you can walk
## out of the instant the arrow leaves is a bow with half its cost. [tune]
const BOW_LOOSE := 0.30
## How long the hookshot's firing POSE is scaled to run for. It is not a
## commitment window — `hook_begin()` takes the hero over on the same frame, and
## the chain's flight is the real commitment. This only decides how fast the
## clip plays. [tune]
const HOOK_FIRE_TIME := 0.34

## Half-angle of the hookshot's aim-assist cone, degrees. Generous on purpose: a
## HookTarget is an AUTHORED promise that this is the anchor that matters, and
## demanding pixel aim across a chasm is how a traversal item becomes a chore.
const HOOK_ASSIST_CONE := 22.0

## The two items that put the camera on the shoulder. A set rather than a pair of
## comparisons so adding a third — a slingshot, a wand — is one entry.
const AIMED: Array[StringName] = [&"bow", &"hookshot"]

var _hero: Hero
var _tether: HookshotTether

## True while a ranged item is RAISED — the trigger is down, or the shot it fired
## is still playing out. Mirrored onto the Bus; kept here so a late listener (a
## HUD rebuilt on a scene change) can ask.
var aiming: bool = false

## The use button, as of the last frame HeroCombat polled it. Not read from
## `Input` here: the buttons have one reader (docs/CONTRACT.md §4), and this node
## must not start disagreeing with the one that owns the shop and channel gates.
var _using: bool = false

## Counts up through the shot — `_bow_draw` of pull and then `BOW_LOOSE` of
## loose — or -1.0 when idle. It STALLS at `_bow_draw` while the trigger is
## still down, which is the hero sitting at full draw.
var _bow_t: float = -1.0
## The draw length THIS shot was started at. Latched rather than re-read every
## frame: buying the string mid-draw would otherwise move the release point of a
## shot already being pulled, and the clip's time scale (set from the same number
## in `request_bow_draw`) would no longer agree with it.
var _bow_draw: float = 0.44
var _bow_fired: bool = false

## The hookshot is up in its brace, waiting for the trigger to come off. It has
## no pull clock — a grapple pistol is either pointed at something or it is not —
## so this flag is the whole of its held state.
var _hook_ready: bool = false

## The chain is out. `_hook_bit` distinguishes a shot that found an anchor from
## one that played out to maximum range and found nothing — both draw the chain,
## only one moves the hero.
var _hook_active: bool = false
var _hook_bit: bool = false
var _hook_pull: Vector3 = Vector3.ZERO
## The monster the head is going to bite, if it is going to bite one. A THIRD
## outcome, not a flavour of the other two: the chain found something (`_hook_bit`
## is true, the clang plays) but nothing gets pulled anywhere — see `_tick_hook`.
var _hook_foe: Enemy = null

var _query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_hero = get_parent() as Hero
	if _hero == null:
		push_error("HeroRanged must be a child of the Hero")
		return
	_tether = HookshotTether.new()
	_tether.name = "Tether"
	_hero.add_child(_tether)

	Bus.loadout_changed.connect(_on_loadout_changed)
	# Deferred: the hero is still being built, and the camera and the HUD that
	# listen for this have not necessarily reached their own _ready yet. A stance
	# announced into an empty room leaves the camera framed for running while the
	# bow is already in his hand, which is exactly the bug this signal exists for.
	_refresh_aiming.call_deferred()


func _on_loadout_changed(_set_index: int, _right: StringName, _left: StringName) -> void:
	_refresh_aiming()


## The RAISED item, or &"" for none — what the hero's stance is built from.
##
## True only from the moment the trigger goes down to the end of the shot it
## fired. Merely HOLDING a bow is not this: he stands in ordinary locomotion
## carrying it, which is the rest pose, and letting go of the button puts the bow
## down without putting it away.
##
## `aiming` is this same fact with the item thrown away, mirrored onto the Bus
## for the camera and the HUD (`_refresh_aiming`). The pose, the framing and the
## crosshair therefore all begin and end on the trigger, together.
func aim_item() -> StringName:
	var held := Game.armament(Game.HAND_RIGHT)
	if not AIMED.has(held):
		return &""
	if held == &"bow":
		return &"bow" if _bow_t >= 0.0 else &""
	return &"hookshot" if _hook_ready or _hook_active else &""


## Recompute the stance from what is actually RAISED, and announce a change.
##
## The trigger decides this, not the D-pad. It was equipment-driven — selecting
## the bow dropped the camera onto his shoulder, narrowed the lens to 42° and put
## a crosshair up, and left all three there until you put the item away. You were
## not aiming; you were carrying a bow, and the game had committed the entire
## frame to a shot you had not asked for. Walking anywhere with the bow selected
## meant walking in a sight.
##
## So the zoom is now exactly as long as the pull: trigger down raises it, the
## end of the shot puts it back down, and between shots he stands in ordinary
## third-person framing holding a bow. That also makes this the same fact as
## `aim_item()` — one is which item, the other is whether there is one — and they
## are deliberately the same fact, because a camera and a body disagreeing about
## whether he is aiming is the bug this whole node exists to prevent.
func _refresh_aiming() -> void:
	var want := aim_item() != &""
	if want == aiming:
		return
	aiming = want
	Bus.aim_changed.emit(aiming)


## The use button went down. Raise whatever is in the right hand: the bow starts
## pulling, the hookshot comes up. Returns false when the press should be ignored
## — no ammo, not a ranged item, a shot already running, or a body that cannot
## take a stance right now — so the caller does not play a noise for a shot that
## never happened.
##
## Nothing LEAVES here. That is `use_release`.
func use_press(id: StringName) -> bool:
	_using = true
	if _bow_t >= 0.0 or _hook_active or not AIMED.has(id):
		return false
	# Rolling, swinging, in the air. Refused for the reasons a swing is refused,
	# and refused HERE rather than by the hero, because the hookshot's brace fires
	# no clip for the hero to decline.
	if _hero.state != Hero.MoveState.GROUND or not _hero.is_on_floor():
		return false
	match id:
		&"bow": return _draw_bow()
		&"hookshot": return _ready_hookshot()
	return false


## The use button came up: loose it. Safe to call on a frame where nothing was
## raised, which is why HeroCombat can call it blindly every frame the button is
## not down.
##
## The BOW is deliberately not handled here. Released before full draw, the pull
## still has to finish — the arrow leaves at the seam and nowhere else — so the
## release is a fact `_tick_bow` reads rather than an event it is handed, and
## `_using` going false above is the whole of it.
func use_release() -> void:
	_using = false
	if _hook_ready:
		_hook_ready = false
		_fire_hookshot()


## Put down whatever is raised without firing it. The shop, the escape rope's
## channel and a stowed item all land here: a pull abandoned costs nothing,
## because the arrow is only ever spent at the seam.
func cancel_use() -> void:
	_using = false
	_hook_ready = false
	if _bow_t >= 0.0 and not _bow_fired:
		_bow_t = -1.0


func busy() -> bool:
	return _bow_t >= 0.0 or _hook_active


# --- The bow ----------------------------------------------------------------

## Start the pull. The quiver is checked HERE, on the press, and not at the seam:
## a bow that comes up, draws for half a second and then declines to shoot has
## told you about the empty quiver at the worst possible moment.
func _draw_bow() -> bool:
	if Game.arrows <= 0:
		# Deliberately audible, unlike an unbound button: you asked for a shot
		# with a bow you are holding, and silence there reads as a dropped input
		# rather than as an empty quiver.
		Bus.request_sfx.emit(&"craft_fail", _hero.global_position)
		return false
	_bow_draw = Game.bow_draw_time()
	if not _hero.request_bow_draw(_bow_draw):
		return false
	_bow_t = 0.0
	_bow_fired = false
	# On the press, over the charge clip, which is now a real pull rather than a
	# recoil played slowly — so this cue finally has the motion it was named for
	# underneath it. `bow_shoot` fires at the seam, with the loose.
	Bus.request_sfx.emit(&"bow_draw", _hero.global_position)
	return true


## The arrow leaves, at the seam between the two clips. Ammo is spent HERE and
## not on the press, so a pull interrupted before release costs nothing — the
## arrow that was never loosed is still in the quiver, which is the only reading
## that is not a lie.
func _release_arrow() -> void:
	_bow_fired = true
	# Aimed at RELEASE rather than at the press: that is the entire point of a
	# trigger you hold. The lock can move, and the player has spent the whole pull
	# putting the crosshair somewhere — reusing the press's vector would throw the
	# shot down a line they had already left.
	var dir := _aim_at_target_or_camera()
	# The body looses whether or not the quiver agrees. The string is at his ear;
	# the one thing that cannot happen here is that he holds that pose and the
	# shot silently evaporates.
	_hero.bow_loose(BOW_LOOSE, dir)
	if not Game.spend_ammo(&"arrows"):
		return
	var arrow := Arrow.new()
	arrow.name = "Arrow"
	# Parented to the scene, not to the hero. An arrow under the hero inherits
	# his yaw and his 1.65 scale, which would both bend the flight and render a
	# 1 m arrow.
	_scene_root().add_child(arrow)
	arrow.launch(_muzzle(&"bow"), dir, _hero)
	Bus.request_sfx.emit(&"bow_shoot", _hero.global_position)


# --- The hookshot -----------------------------------------------------------

## Bring it up. No clip and no clock — `clip_hook_shot` doubles as the held brace
## (`HookAimAnim`, looped) and the firing pose, so raising it is one blend
## amount, driven off this flag by `aim_item()`.
##
## Always true: unlike the bow there is nothing to spend and nothing to check.
## Whether the chain finds an anchor is a question for the release.
func _ready_hookshot() -> bool:
	_hook_ready = true
	# The brace is a HOLD with no clock and no cost, so before this it was the
	# only item in the game you could take out in total silence -- the pistol
	# came up in the corner of the eye and nothing said the trigger was live.
	# The load is the sound of it being made ready, and it is the tell that the
	# next release fires.
	Bus.request_sfx.emit(&"hookshot_load", _hero.global_position)
	return true


func _fire_hookshot() -> bool:
	var from := _muzzle(&"hookshot")
	var aim := _camera_forward()
	# Read ONCE per shot and threaded through everything below. The reach decides
	# the assist search, the raycast and the length the chain plays out to, and
	# those three disagreeing is a hookshot that visibly reaches a ring it then
	# refuses to grab.
	var reach := Game.hook_reach()
	var anchor := from + aim * reach
	var pull := Vector3.ZERO
	var bit := false
	var foe: Enemy = null

	# An authored ring first. It is the designer saying "this one", and it wins
	# over whatever wall happens to be behind it.
	var ring := _best_hookable(from, aim, reach)
	if ring != null:
		anchor = ring.anchor_point()
		pull = ring.pull_point()
		bit = true
		# Told, at the instant it wins. A ring has no collision of its own — it is
		# a marker the scan above prefers — so this call is the ONLY way a
		# `HookRing` puzzle atom can ever learn it was the one caught.
		ring.on_bitten(_hero)
	else:
		_query.from = from
		_query.to = from + aim * reach
		# L_ENEMY is in here so the chain can BITE a monster rather than passing
		# through one. It was absent for as long as the hookshot was only a
		# traversal item, and the tell was unmistakable once you looked: the head
		# flew through a skeleton's ribcage and stuck in the wall behind it.
		_query.collision_mask = K.L_WORLD | K.L_HOOK | K.L_ENEMY
		_query.collide_with_bodies = true
		_query.collide_with_areas = false
		_query.exclude = [_hero.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(_query)
		if not hit.is_empty():
			anchor = hit["position"] as Vector3
			foe = hit["collider"] as Enemy
			# A monster is an anchor that does not hold. The chain bites, the
			# clang plays, and the hero stays exactly where he is — a hookshot
			# that reeled you into the thing you just froze would spend its own
			# reward walking you into claw range. `pull` stays ZERO and
			# `_tick_hook` never reads it.
			if foe == null:
				var normal := hit["normal"] as Vector3
				# Land ON the surface the head bit, standing off it along its own
				# normal. Without the stand-off the pull ends inside the wall and
				# move_and_slide spends the next second squeezing him back out.
				pull = anchor + normal * (K.HERO_RADIUS + 0.25)
				# A shot into a ceiling would otherwise leave him hanging in the
				# air under it; drop the landing to where his feet can be.
				if normal.y > 0.6:
					pull.y = anchor.y + 0.05
				elif normal.y < -0.6:
					pull = anchor + Vector3.DOWN * (K.HERO_H + 0.2)
			bit = true

	if not _hero.request_hookshot(HOOK_FIRE_TIME, aim):
		return false

	_hook_active = true
	_hook_bit = bit
	_hook_foe = foe
	_hook_pull = pull
	_hero.hook_begin()
	_tether.begin(from, anchor, pull)
	Bus.request_sfx.emit(&"crossbow_shoot", _hero.global_position)
	return true


## The `hookable` nearest the aim line, or null. Scored on ANGLE off the aim,
## not on distance: the player is pointing at something, and the nearest ring is
## regularly not the one they are looking at.
## `reach` is the caller's, not this function's, so the assist and the shot can
## never disagree about how far the chain goes.
func _best_hookable(from: Vector3, aim: Vector3, reach: float) -> HookTarget:
	var best: HookTarget = null
	var best_angle := HOOK_ASSIST_CONE
	for node in get_tree().get_nodes_in_group(&"hookable"):
		var ring := node as HookTarget
		if ring == null or not is_instance_valid(ring):
			continue
		var to := ring.anchor_point() - from
		var dist := to.length()
		if dist < 0.5 or dist > reach:
			continue
		var angle := rad_to_deg(aim.angle_to(to))
		# The snap radius is the ring's own tolerance in METRES, converted to the
		# angle it subtends from here — a generous ring stays generous close up
		# and does not become a wall-sized target across the room.
		var allowed := minf(HOOK_ASSIST_CONE, rad_to_deg(atan2(ring.snap_radius, dist)) + 6.0)
		if angle > allowed or angle > best_angle:
			continue
		best_angle = angle
		best = ring
	return best


func _end_hook() -> void:
	_hook_active = false
	_hook_bit = false
	_hook_foe = null
	_tether.clear()


# --- Frame ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _hero == null:
		return
	_tick_bow(delta)
	_tick_hook(delta)
	# POLLED, at the end, after both items have had their say. The raised state
	# ends in half a dozen places — the seam, the follow-through running out, a
	# roll or a hit taking the pose away, `cancel_use` from the shop — and a
	# `Bus.aim_changed` hung off each of those is five places for the sixth to be
	# forgotten and one for the camera to be left zoomed into a shot that ended.
	# One comparison a frame against `aim_item()` cannot go stale.
	_refresh_aiming()


## True while the body can still hold `id` raised. Checked every frame of a hold
## rather than only at the press, because a hold is open-ended and the world gets
## a say in it: a roll, a hit reaction or an item stowed by the attack button's
## escape hatch all have to put the thing down.
##
## Deliberately says nothing about the BUTTON — the two items disagree about what
## a release means, and each handles its own. Re-raising afterwards is not
## automatic either: it costs a new press, so a trigger still held down when he
## gets back up does not fire a shot the player has stopped asking for.
func _can_hold(id: StringName) -> bool:
	return Game.armament(Game.HAND_RIGHT) == id \
		and _hero.state == Hero.MoveState.GROUND


func _tick_bow(delta: float) -> void:
	if _bow_t < 0.0:
		return

	if _bow_fired:
		# The loose. He is committed for it and nothing takes it back.
		_bow_t += delta
		if _bow_t >= _bow_draw + BOW_LOOSE:
			_bow_t = -1.0
		return

	# Still pulling. Note the BUTTON is not part of this: a trigger released early
	# does not cancel the pull, it schedules the loose for the seam below.
	if not _can_hold(&"bow"):
		_bow_t = -1.0
		return

	_bow_t += delta
	if _bow_t < _bow_draw:
		return
	if _using:
		# Full draw, trigger still down. Parked rather than left to run on, so
		# the clock reads the same on the frame he lets go whether he held it for
		# a tenth of a second or ten seconds — everything downstream measures the
		# loose from `_bow_draw`.
		_bow_t = _bow_draw
		return
	# The seam. The charge clip ends on full draw and the loose opens on it, so
	# this one instant is the string leaving his fingers, the arrow spawning and
	# the second clip firing — all three off this clock, so they cannot drift.
	_release_arrow()


func _tick_hook(delta: float) -> void:
	if _hook_ready and not _can_hold(&"hookshot"):
		# Knocked out of the brace, or the pistol left his hand mid-hold. Put it
		# down rather than firing it: a chain that goes out because he got hit is
		# a shot the player did not aim.
		_hook_ready = false
	if not _hook_active:
		return
	var from := _muzzle(&"hookshot")

	if _tether.is_extending():
		if not _tether.advance(delta, from):
			return
		# The chain arrived. A shot that found nothing has now shown the player
		# exactly how far the hookshot reaches, which is the whole information
		# content of a miss; there is nothing left to do but let go.
		if not _hook_bit:
			_hero.hook_end()
			_end_hook()
			return
		# It bit a monster. Zero damage — nothing goes near `HealthComponent`,
		# which refuses a zero-quarter blow anyway — and the freeze IS the shot's
		# whole effect. The hero is handed straight back rather than dragged,
		# because there is nothing here to be dragged to; `Enemy.freeze` owns the
		# clang and the hit-stop for this one, since it is the body being hit
		# that knows whether the hit landed on anything.
		if _hook_foe != null:
			if is_instance_valid(_hook_foe):
				_hook_foe.freeze(K.HOOK_FREEZE)
			_hero.hook_end()
			_end_hook()
			return
		# The head bites stone. `craft_clang` was standing in here and it is the
		# SMITH's anvil — the shop's sound, in a dungeon, on a traversal move.
		# `hit_armor` is metal arriving on something hard, which is what this is.
		Bus.request_sfx.emit(&"hit_armor", _tether.impact_position)
		# ...and immediately the reel. Two sounds on one frame on purpose: the
		# bite and the pull are one beat to the player, and the chain running is
		# the only thing that says the anchor HELD (a monster clangs and lets go).
		#
		# Trimmed to 0.9 s at import for exactly this: the pull is
		# distance / K.HOOK_PULL_SPEED, which tops out around 0.62 s at
		# K.HOOK_RANGE, so a chain any longer than this would still be reeling
		# after the hero had landed. Fired and forgotten — `Sfx` has no stop.
		Bus.request_sfx.emit(&"hookshot_pull", _hero.global_position)
		_hero.hook_pull_to(_hook_pull)
		return

	# Travelling. The tether redraws from the moving hero, so the chain retracts
	# into the anchor with no second animation clock (see hookshot_tether.gd).
	_tether.update_pull(from)
	if not _hero.hooking():
		_end_hook()


# --- Aim --------------------------------------------------------------------

## Where the shot comes FROM. The real model if it is mounted and visible, so
## the chain leaves the hookshot's barrel rather than the hero's sternum; his
## eye line otherwise, which is what a director rendering a bare hero gets.
func _muzzle(id: StringName) -> Vector3:
	var model: Node3D = null
	if _hero.combat != null:
		model = _hero.combat.hookshot if id == &"hookshot" else _hero.combat.bow
	if model != null and model.is_inside_tree() and model.is_visible_in_tree():
		return model.global_position
	return _hero.global_position + Vector3.UP * K.HERO_EYE_Y \
		+ (-_hero.global_transform.basis.z) * 0.35


## The locked target's chest, else wherever the camera is pointed.
func _aim_at_target_or_camera(id: StringName = &"bow") -> Vector3:
	var muzzle := _muzzle(id)
	var target := _hero.lock_target()
	if target != null:
		var to := target.global_position + Vector3.UP * 0.9 - muzzle
		if to.length_squared() > 0.01:
			return to.normalized()
	return _aim_from(muzzle)


## The aim vector from `muzzle` toward whatever the camera is looking AT.
##
## Not parallel to the camera's forward — *convergent on its target*, and the
## difference is the difference between a bow that works and one that does not.
## The bow is held in the left hand and the hookshot in the right, so a muzzle
## sits ~0.6 m off the hero's centre line. Firing parallel meant every shot
## travelled its whole flight 0.6 m to one side of the thing the player had
## lined up: it missed a training post it was visibly pointed at, and that reads
## as the bow being broken rather than as an origin being offset.
##
## The fix is the one every third-person shooter uses. Ask the camera what its
## crosshair is actually over — one raycast down its ray — and aim the muzzle at
## that POINT. Exact at every distance, which a fixed convergence distance is
## not: converging at 8 m leaves a half-metre error on a target 2 m away, and
## point blank is exactly where a miss is least forgivable.
func _aim_from(muzzle: Vector3) -> Vector3:
	var fallback := -_hero.global_transform.basis.z
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return fallback
	var look := -cam.global_transform.basis.z
	if look.length_squared() < 0.0001:
		return fallback
	look = look.normalized()

	# Far enough to be past anything either item can reach, so an unobstructed
	# ray still yields a focus point rather than nothing. Off the LONGSHOT rather
	# than the current chain: this is the crosshair's ray, not a weapon's, and it
	# must not get shorter than the bow when the hookshot is un-forged.
	var reach := K.HOOK_LONGSHOT_RANGE * 2.0
	var focus := cam.global_position + look * reach
	_query.from = cam.global_position
	_query.to = focus
	_query.collision_mask = K.L_WORLD | K.L_ENEMY | K.L_INTERACT | K.L_HOOK
	_query.collide_with_bodies = true
	_query.collide_with_areas = true
	# The hero is between the camera and the crosshair. Without this the ray
	# stops on his own back and every shot aims at his shoulder blades.
	_query.exclude = [_hero.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(_query)
	if not hit.is_empty():
		focus = hit["position"] as Vector3

	var to := focus - muzzle
	# Degenerate only when the crosshair is on something inside the muzzle.
	return to.normalized() if to.length_squared() > 0.0001 else fallback


## The aim for a hookshot shot, which leaves the barrel in his right hand.
##
## The lock wins here for the same reason it wins for the bow: holding a target
## and then having the chain sail past it because the crosshair was a few degrees
## off reads as the lock being decorative. The ring assist in `_best_hookable`
## still runs on top of whatever this returns, so an authored anchor beside the
## locked enemy is still the thing that gets grabbed.
func _camera_forward() -> Vector3:
	return _aim_at_target_or_camera(&"hookshot")


func _scene_root() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null else get_tree().root
