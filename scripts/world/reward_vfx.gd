class_name RewardVfx
extends Node3D
## How a reward ARRIVES. One call, two tiers:
##
##     RewardVfx.land(chest, RewardVfx.MINOR)   # you beat the room
##     RewardVfx.land(chest, RewardVfx.MAJOR)   # you beat the thing guarding it
##
## `land` is the whole beat -- the prize becomes visible and interactable, drops
## the last metre, the world flashes, the camera kicks and `Bus.reward_revealed`
## fires so `Sfx` can play the arrival. Callers say one line and own none of it.
##
## **Why two tiers and not a continuum.** A flash that scales smoothly with the
## value of what is inside teaches the player nothing, because they cannot
## compare it to the flash in the last room -- they only ever see one at a time.
## Two is the smallest number that can be *recognised*: this is a chest, and
## THAT is the chest. Anything between them is a third thing to learn.
##
##   MINOR   A room's chest. A ring on the floor, a small star, a brief bloom.
##           Fast -- under a second -- because it happens several times a floor
##           and the player is still holding a sword.
##   MAJOR   Boss-grade: the deep chest beyond the boss arena, the miniboss
##           chamber's chest, the deepest reward on the floor. It adds a SHAFT of
##           light standing in the room and a second, wider ring behind the
##           first, and it runs nearly twice as long. The difference is
##           magnitude and silhouette, not hue: two golds a player has to tell
##           apart is a colour-blindness bug, and a purple flash on a chest of
##           iron scrap would be a lie about the contents.
##
## **Everything here runs on the WALL clock**, `FlourishVfx`'s rule and for the
## same reason plus one. A reward lands on the frame the last monster in the room
## dies, and that frame is a hit-stop (`Feel.hitstop`, `Engine.time_scale = 0`) --
## a Tween or a `_process` delta measured in game seconds would sit at zero for
## the length of the freeze and the flash would start *after* the moment it is
## about. The freeze is the moment this belongs to. The drop tween gets
## `set_ignore_time_scale` for the same reason.
##
## MIX blending and nothing near `#FFFFFF` (STYLEGUIDE §7.2, CLAUDE.md §3): alpha
## does not attenuate ADD over a near-black dungeon floor, so these effects change
## SHAPE -- rings thin, shafts narrow, stars retract -- and never fade a material.

## The tiers. Plain ints rather than an enum because they cross a file boundary
## in both directions (`Dungeon` picks one, `Sfx` indexes on one) and an enum
## member read through `Bus` arrives as an int anyway.
const MINOR := 1
const MAJOR := 2

## How long the node lives, per tier. Longer than the longest animation in it so
## nothing pops out while its motes are still in the air.
const LIFE := {MINOR: 1.1, MAJOR: 2.0}

## The drop. The prize falls this far in this long and settles on a bounce --
## the eye goes to motion, and a chest that eased up from zero alpha in a corner
## is a chest the player walks past.
const DROP_H := {MINOR: 1.1, MAJOR: 2.2}
const DROP_TIME := {MINOR: 0.5, MAJOR: 0.7}

## Camera trauma, and how long it bleeds off. `Feel` SQUARES trauma, so these are
## picked from the top half of the range on purpose -- 0.3 arrives as 9% of the
## maximum shake and 0.62 as 38%, which is the gap that makes the two tiers feel
## different rather than merely measure differently. See `Feel`'s class docstring.
const SHAKE := {MINOR: Vector2(0.30, 0.24), MAJOR: Vector2(0.62, 0.50)}

## The floor ring: metres, and the seconds it takes to get there. MAJOR throws a
## second one, wider and starting a beat later, which is what reads as a bigger
## event from across a room -- one ring twice the size just reads as a bigger room.
const RING := {MINOR: Vector2(2.2, 0.34), MAJOR: Vector2(3.4, 0.42)}
## 3.9 m and not 5.2: the vault's chamber is 11 m across and a ring that reached
## 5.2 m in every direction was still at full brightness when it hit the walls,
## so it read as a band sweeping the room rather than as a wave leaving the chest.
const RING2 := Vector2(3.9, 0.58)
const RING2_DELAY := 0.16

## The star, on `ImpactVfx`/`FlourishVfx` timings so an arrival reads as the same
## class of event as a crit or a parry -- the game's "that went through" language.
const STAR_R := {MINOR: 0.9, MAJOR: 1.7}
const STAR_OPEN := 0.06
const STAR_SHUT := 0.22

## MAJOR only: a shaft of light standing where the prize landed, visible over the
## chest from anywhere in the room. Radius, height, the seconds it takes to snap
## up, and the seconds it takes to narrow to nothing.
## 0.95 m and not the 1.25 it was authored at: a chest is 0.9 m across, so a
## 2.5 m column swallowed its whole silhouette and the prize read as a smudge
## inside the light rather than the thing standing in it.
const SHAFT_R := 0.95
const SHAFT_H := 7.0
const SHAFT_RISE := 0.16
const SHAFT_FADE := 1.1

## The bloom. Peak energy, range, and how long it takes to go out.
##
## MAJOR was authored at 14 and 9.5 m, and 14 is not "brighter" -- shot at the
## instant of arrival it took the ENTIRE FRAME to white: walls, floor, corpses,
## the chest it exists to show, all gone. It had only ever been looked at a third
## of a second late, by which point the cubed decay had brought it down to 4 and
## it looked fine.
##
## 7.0 over 8 m still did it, and the RANGE is why: a dungeon room is 11 m across,
## so a light that reaches 8 m lights the wall the camera is standing against as
## hard as it lights the chest, and the frame goes to white from the edges in.
## 5.5 over 6 m is a step you can see against MINOR without the room going with
## it -- and the bloom was never what makes MAJOR feel bigger anyway. The shaft,
## the second ring, the star at twice the size, the hold and the shake are.
const LIGHT := {MINOR: Vector3(5.0, 5.0, 0.45), MAJOR: Vector3(5.5, 6.0, 1.0)}

## Motes. Enough to read as a burst at MINOR, enough to read as an event at MAJOR.
const MOTES := {MINOR: 14, MAJOR: 34}

## Segments around a ring. 40 is smooth at 5.2 m and still one draw call.
const RING_SEGMENTS := 40
## Sides on the shaft. 20 is round at 1.25 m and cheap; it is unshaded, so there
## is no normal to give a low count away.
const SHAFT_SIDES := 20

## One 64x64 radial falloff, shared by every mote of every reward. `ImpactVfx`'s
## reasoning: a texture per chest would allocate inside the one frame of the game
## that is already doing the most work.
static var _soft: GradientTexture2D = null

var _tier: int = MINOR
var _born_ms: int = 0
## Seconds from the flash starting to the prize hitting the floor. Zero for a
## bare `burst` -- there is nothing falling, so the impact IS the arrival.
##
## **The ring and the star wait for this, and that ordering is the effect.** They
## used to fire at t=0, so a chest was announced by a shockwave and then drifted
## down into a dark room over the next half second: the loudest part of the
## ceremony happened while the prize was still two metres up, and the moment it
## actually landed was the quietest frame in the whole thing.
var _impact: float = 0.0
var _ring: MeshInstance3D = null
var _ring2: MeshInstance3D = null
var _star: MeshInstance3D = null
var _shaft: MeshInstance3D = null
var _glow: OmniLight3D = null


# --- The two verbs ------------------------------------------------------------

## A prize that has been standing hidden in the room ARRIVES.
##
## `prize` is expected to be invisible and, if it is an `Interactable`, disabled
## -- that is how a reward waits without being lootable and without taking focus
## through a wall. This makes it real, drops it into place, and announces it.
##
## Idempotent on `visible`: a puzzle whose `opened` signal fires twice, or a
## floor re-entered inside one run with the flag already set, must not re-drop a
## chest the player is standing next to. `Dungeon._land_prize` carried this guard
## before this class existed and it is kept here so every caller inherits it.
static func land(prize: Node3D, tier: int) -> void:
	if prize == null or not is_instance_valid(prize) or prize.visible:
		return
	var t := MAJOR if tier == MAJOR else MINOR
	prize.visible = true
	# `set` rather than a cast: the callers hand over chests today, and a relic
	# pedestal or a bundle tomorrow. Everything that has an `enabled` wants it
	# turned on and nothing that lacks one cares.
	if prize.get(&"enabled") != null:
		prize.set(&"enabled", true)

	var vfx := burst(prize, Vector3.ZERO, t)
	if vfx != null:
		# The ring and the star are the LANDING, not the announcement. See `_impact`.
		vfx._impact = float(DROP_TIME[t])

	# Falls the last stretch and settles. `position`, not `global_position`: every
	# caller placed the prize as a child of a room root and the drop is straight
	# down in that room's space.
	var to := prize.position
	prize.position = to + Vector3(0.0, float(DROP_H[t]), 0.0)
	var tw := prize.create_tween()
	# The kill frame is a hit-stop. See the class docstring -- without this the
	# chest hangs in the air for the length of the freeze.
	tw.set_ignore_time_scale(true)
	tw.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(prize, ^"position", to, float(DROP_TIME[t]))


## The flash on its own, at `at` in `parent`'s space, with no prize to reveal --
## for a reward that was never hidden because something else spawned it (a boss's
## relic hitting the floor, say). `land` is this plus the drop.
static func burst(parent: Node, at: Vector3, tier: int) -> RewardVfx:
	if parent == null or not parent.is_inside_tree():
		push_warning("RewardVfx: no live parent; the reward arrived unseen")
		return null
	var t := MAJOR if tier == MAJOR else MINOR

	var root := RewardVfx.new()
	root.name = &"RewardVfx"
	root._tier = t
	# The freeze is the moment this belongs to (class docstring). Processed with
	# everything else, the flash would appear only once the hit-stop it is the
	# reason for had ended.
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(root)
	root.position = at
	root._build()

	Bus.request_shake.emit(float(SHAKE[t].x), float(SHAKE[t].y))
	# `Sfx` owns which sound this is, per its own first rule -- one sound per
	# event, chosen there. Emitting an id from here would be this file having an
	# opinion about the mix.
	Bus.reward_revealed.emit(t, root.global_position)
	return root


## Make a held reward real with no ceremony -- the generator's fail-safe. A
## reward that was hidden and never claimed by anything (a room that ended up
## with nothing to defeat, an anchor that landed in a cell `_populate` skips) has
## to end up lootable, and it must NOT flash: four chests going off behind the
## loading card is the beat firing where nobody is standing.
static func show_now(prize: Node3D) -> void:
	if prize == null or not is_instance_valid(prize) or prize.visible:
		return
	prize.visible = true
	if prize.get(&"enabled") != null:
		prize.set(&"enabled", true)


# --- Frame --------------------------------------------------------------------

func _ready() -> void:
	_born_ms = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	var t := float(Time.get_ticks_msec() - _born_ms) / 1000.0
	if t >= float(LIFE[_tier]):
		queue_free()
		return

	# The shaft stands from the start -- it is the column the prize comes DOWN --
	# and everything that reads as an impact is measured from the landing.
	var i := t - _impact
	_step_ring(_ring, i, RING[_tier].x, RING[_tier].y)
	if _ring2 != null:
		_step_ring(_ring2, i - RING2_DELAY, RING2.x, RING2.y)
	_step_star(i)
	_step_shaft(t)
	_step_light(t)


## A ring GROWS and THINS. It never fades: alpha does not attenuate over a
## near-black floor (CLAUDE.md §3), so the thinning is done by squashing the
## mesh's own thickness, which is a shape change and survives the MIX blend.
func _step_ring(ring: MeshInstance3D, t: float, radius: float,
		seconds: float) -> void:
	if ring == null:
		return
	if t < 0.0:
		# The second ring has not started yet. Held at zero rather than hidden so
		# it has no pop-in frame of its own.
		ring.scale = Vector3.ZERO
		return
	var u := clampf(t / seconds, 0.0, 1.0)
	if u >= 1.0:
		if ring.visible:
			ring.visible = false
		return
	# Ease-out, hard. A shockwave is fastest on the frame it leaves.
	var e := 1.0 - pow(1.0 - u, 3.0)
	ring.scale = Vector3(radius * e, radius * e, maxf(1.0 - u * u, 0.02))


func _step_star(t: float) -> void:
	if _star == null:
		return
	if t < 0.0:
		# Still falling. Held at zero, like the second ring, so it has no pop-in.
		_star.scale = Vector3.ZERO
		return
	# Snap past full, settle, retract -- `ImpactVfx`'s curve, deliberately.
	var hold := STAR_OPEN * 0.7
	var k := 0.0
	if t < STAR_OPEN:
		k = (1.0 - pow(1.0 - t / STAR_OPEN, 3.0)) * 1.16
	elif t < STAR_OPEN + hold:
		k = lerpf(1.16, 1.0, (t - STAR_OPEN) / hold)
	elif t < STAR_OPEN + hold + STAR_SHUT:
		k = 1.0 - pow((t - STAR_OPEN - hold) / STAR_SHUT, 2.0)
	else:
		if _star.visible:
			_star.visible = false
		return
	_star.scale = Vector3.ONE * float(STAR_R[_tier]) * maxf(k, 0.0)
	_star.rotation.y = -t * 1.6


## The shaft snaps to full height, then NARROWS to nothing while staying full
## height. Narrowing rather than fading, and narrowing rather than sinking: a
## column that shrank downward would read as the light being sucked back into the
## chest, which is the opposite of what just happened.
func _step_shaft(t: float) -> void:
	if _shaft == null:
		return
	if t < SHAFT_RISE:
		var e := 1.0 - pow(1.0 - t / SHAFT_RISE, 3.0)
		_shaft.scale = Vector3(1.0, e, 1.0)
		return
	var u := clampf((t - SHAFT_RISE) / SHAFT_FADE, 0.0, 1.0)
	if u >= 1.0:
		if _shaft.visible:
			_shaft.visible = false
		return
	var w := maxf(1.0 - u * u, 0.01)
	_shaft.scale = Vector3(w, 1.0, w)


func _step_light(t: float) -> void:
	if _glow == null:
		return
	var spec: Vector3 = LIGHT[_tier]
	# **Two pulses, and the second is the bigger one.** A single pulse at t=0 went
	# out during the fall and the prize touched down in the dark -- see `_impact`.
	#
	#   ARRIVAL  half strength, squared, stretched over the whole drop. This is
	#            the light the chest falls THROUGH; it has to still be burning
	#            when the chest gets to the bottom, so it decays over
	#            `_impact + fall` and not over `fall`.
	#   LANDING  full strength, cubed. A flash with a tail rather than a lamp
	#            being dimmed, and it starts on the frame of the bounce.
	var over := _impact + spec.z
	var k := 0.0
	if t < over:
		k = 0.5 * pow(1.0 - t / over, 2.0)
	var i := t - _impact
	if i >= 0.0 and i < spec.z:
		k = maxf(k, pow(1.0 - i / spec.z, 3.0))
	if k <= 0.0:
		if _glow.visible:
			_glow.visible = false
		return
	_glow.light_energy = spec.x * k


# --- Construction ---------------------------------------------------------------

func _build() -> void:
	var t := _tier

	_ring = _ring_mesh(Pal.GOLD, Pal.BONE, 0.14)
	# Authored in XY; a quarter turn about X lays it on the floor. Lifted a
	# fingernail so it does not z-fight the slab it is drawn on.
	_ring.rotation.x = -PI * 0.5
	_ring.position.y = 0.05
	_ring.scale = Vector3.ZERO
	add_child(_ring)

	if t == MAJOR:
		_ring2 = _ring_mesh(Pal.GOLD, Pal.MOTH, 0.07)
		# Renamed off `_ring_mesh`'s `Ring`, because a duplicate sibling name at
		# RUNTIME does not become `Ring2` the way it does in the editor -- Godot
		# hands out `@Ring@2`, and anything reading the tree by name then sees one
		# ring on a two-ring flash. `room_reward`'s beat D4 failed exactly that way.
		_ring2.name = &"RingOuter"
		_ring2.rotation.x = -PI * 0.5
		_ring2.position.y = 0.04
		_ring2.scale = Vector3.ZERO
		add_child(_ring2)

		_shaft = _shaft_mesh()
		_shaft.scale = Vector3(1.0, 0.0, 1.0)
		add_child(_shaft)

	_star = _star_mesh(global_position)
	# Chest-height on a 1.65 m hero (docs/CONTRACT.md §1), so the burst is on the
	# lid rather than at the player's ankles.
	_star.position.y = 0.8
	_star.scale = Vector3.ZERO
	add_child(_star)

	_glow = OmniLight3D.new()
	_glow.name = &"Bloom"
	_glow.light_color = Pal.GOLD
	_glow.light_energy = float((LIGHT[t] as Vector3).x)
	_glow.omni_range = float((LIGHT[t] as Vector3).y)
	_glow.omni_attenuation = 1.6
	# No shadow. This light exists for a third of a second and a shadow map for it
	# is a stall on the frame the player is meant to be enjoying.
	_glow.shadow_enabled = false
	_glow.position.y = 0.9
	add_child(_glow)

	add_child(_motes(t))


## A flat annulus in the XY plane, hot on the inner edge and transparent at the
## outer one, with its thickness carried in Z so `_step_ring` can squash it.
##
## The Z trick is why this is an ArrayMesh and not a TorusMesh: a torus is a solid
## of revolution and there is no way to thin one without rebuilding it, which is
## an allocation per chest. A local copy of `FlourishVfx`'s, which is this
## project's pattern for VFX helpers and not an oversight -- every one of them is
## a few lines tuned to the effect around it.
static func _ring_mesh(inner_c: Color, outer_c: Color,
		width: float) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for i in RING_SEGMENTS:
		var a0 := TAU * float(i) / float(RING_SEGMENTS)
		var a1 := TAU * float(i + 1) / float(RING_SEGMENTS)
		var i0 := Vector3(sin(a0) * (1.0 - width), cos(a0) * (1.0 - width), 0.0)
		var i1 := Vector3(sin(a1) * (1.0 - width), cos(a1) * (1.0 - width), 0.0)
		# **The outer edge is LIFTED, and that lift is the whole reason
		# `_step_ring` can thin the ring.** This was authored flat -- every vertex
		# at `z = 0` -- under a docstring saying the thickness was carried in Z, so
		# the Z-squash was multiplying zero by a shrinking number and the ring
		# simply vanished on one frame at full size. It read as a fat gold band
		# blinking out, which is what the first tier-2 frame showed.
		#
		# The node is turned `-PI/2` about X, so local +Z is world UP: this makes
		# the annulus a shallow crest that collapses INTO the floor as it spreads,
		# which is a shockwave, and it does it by changing shape rather than by
		# fading (CLAUDE.md §3).
		var o0 := Vector3(sin(a0), cos(a0), width)
		var o1 := Vector3(sin(a1), cos(a1), width)
		verts.append_array([i0, o0, o1, i0, o1, i1])
		var hot := Color(inner_c.r, inner_c.g, inner_c.b, 0.9)
		var cold := Color(outer_c.r, outer_c.g, outer_c.b, 0.0)
		colors.append_array([hot, cold, cold, hot, cold, hot])
	return _mesh_of(verts, colors, &"Ring", false)


## The MAJOR shaft: an open cylinder, unit radius and unit height, brightest at
## the bottom and transparent at the top. Open because a capped one shows the
## player a hard disc seven metres up, which reads as a solid object.
static func _shaft_mesh() -> MeshInstance3D:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	# **0.30 and not the 0.62 this was authored at, and the reason is the cull
	# mode below.** A cylinder is two walls deep from every angle, so a MIX
	# transparency of `a` composites to `1 - (1 - a)^2` -- 0.62 became 0.86, which
	# over a near-black floor is a solid cream cylinder with the chest somewhere
	# inside it. The first frames of the tier-2 flash showed no prize at all.
	var hot := Color(Pal.GOLD.r, Pal.GOLD.g, Pal.GOLD.b, 0.30)
	var cold := Color(Pal.BONE.r, Pal.BONE.g, Pal.BONE.b, 0.0)
	for i in SHAFT_SIDES:
		var a0 := TAU * float(i) / float(SHAFT_SIDES)
		var a1 := TAU * float(i + 1) / float(SHAFT_SIDES)
		var b0 := Vector3(sin(a0) * SHAFT_R, 0.0, cos(a0) * SHAFT_R)
		var b1 := Vector3(sin(a1) * SHAFT_R, 0.0, cos(a1) * SHAFT_R)
		var t0 := Vector3(b0.x, SHAFT_H, b0.z)
		var t1 := Vector3(b1.x, SHAFT_H, b1.z)
		verts.append_array([b0, t0, t1, b0, t1, b1])
		colors.append_array([hot, cold, cold, hot, cold, hot])
	var mi := _mesh_of(verts, colors, &"Shaft", false)
	# **The only thing in this file that culls, and it is the point of the
	# effect.** Everything else here is a flat sheet that has to be visible from
	# both sides. A cylinder is not: with `CULL_DISABLED` you draw its near wall
	# IN FRONT OF the chest and its far wall behind, and the near one is a veil
	# over the thing the flash exists to show you. `CULL_FRONT` keeps only the far
	# wall, so the column becomes a lit backdrop the prize is silhouetted against
	# -- which is what a shaft of light on a treasure actually looks like.
	#
	# The obvious alternative was tried and is worse: both walls at 0.17 gives a
	# convincingly round column, and it is a GLASS TUBE. Two silhouette edges plus
	# two top edges close into a hard rim ellipse seven metres up -- the exact
	# "solid object" this mesh is open-ended to avoid -- and the chest goes back
	# behind a pane. One wall has no rim and no pane.
	(mi.material_override as StandardMaterial3D).cull_mode = \
		BaseMaterial3D.CULL_FRONT
	return mi


## The burst. Eight long spikes and eight short, plus a small solid core.
##
## `at` seeds the jitter so two chests on one floor do not throw an identical
## star, without a `randf()` making a director's frames non-reproducible -- the
## same trade `ImpactVfx` and `FlourishVfx` make, and the same reason.
static func _star_mesh(at: Vector3) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(at * 16.0))
	var spikes := 16

	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var core := Pal.BONE
	var tip := Pal.GOLD
	for i in spikes:
		var a := TAU * float(i) / float(spikes)
		var long := (i % 2) == 0
		var r := (1.0 if long else 0.42) * rng.randf_range(0.82, 1.0)
		var half := (0.07 if long else 0.16) * TAU / float(spikes) * 6.0
		var inner := 0.14
		verts.append_array([
			Vector3(sin(a - half) * inner, cos(a - half) * inner, 0.0),
			Vector3(sin(a) * r, cos(a) * r, 0.0),
			Vector3(sin(a + half) * inner, cos(a + half) * inner, 0.0),
		])
		colors.append_array([
			Color(core.r, core.g, core.b, 0.95),
			Color(tip.r, tip.g, tip.b, 0.0),
			Color(core.r, core.g, core.b, 0.95),
		])

	var disc := 12
	for i in disc:
		var a0 := TAU * float(i) / float(disc)
		var a1 := TAU * float(i + 1) / float(disc)
		verts.append_array([
			Vector3.ZERO,
			Vector3(sin(a0) * 0.2, cos(a0) * 0.2, 0.0),
			Vector3(sin(a1) * 0.2, cos(a1) * 0.2, 0.0),
		])
		colors.append_array([
			Color(core.r, core.g, core.b, 1.0),
			Color(core.r, core.g, core.b, 0.3),
			Color(core.r, core.g, core.b, 0.3),
		])
	return _mesh_of(verts, colors, &"Star", true)


static func _mesh_of(verts: PackedVector3Array, colors: PackedColorArray,
		node_name: StringName, billboarded: bool) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.material_override = _flat_mat(billboarded)
	return mi


## Depth-TESTED. `ImpactVfx`'s hard-won note: a `no_depth_test` flash paints
## straight through the hero, who is nearer the camera than the thing it is
## about -- and the whole point of the shaft is that the chest is BEHIND it.
static func _flat_mat(billboarded: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	if billboarded:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	m.render_priority = 1
	return m


## What comes out of the floor with the chest. Rising and slow, not thrown: this
## is treasure surfacing, and the fast outward spray is `FlourishVfx`'s parry --
## the two must not sound the same in the eye either.
static func _motes(tier: int) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = &"Motes"
	p.amount = int(MOTES[tier])
	p.lifetime = 1.0 if tier == MINOR else 1.7
	p.one_shot = true
	p.explosiveness = 0.86
	p.local_coords = true
	# 30 Hz. These are soft blobs drifting upward; nothing in the motion needs a
	# 60 Hz sample and the floor may have three of them alight at once.
	p.fixed_fps = 30
	var reach := 3.0 if tier == MINOR else 8.0
	p.visibility_aabb = AABB(Vector3(-reach, -1.0, -reach),
		Vector3(reach * 2.0, reach + 2.0, reach * 2.0))

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3.UP
	m.emission_ring_radius = 0.75 if tier == MINOR else 1.3
	m.emission_ring_inner_radius = 0.25
	m.emission_ring_height = 0.1
	m.direction = Vector3.UP
	m.spread = 18.0
	m.initial_velocity_min = 1.6 if tier == MINOR else 2.8
	m.initial_velocity_max = 3.0 if tier == MINOR else 5.6
	# A TENTH of gravity. They hang; that is the whole read. At full gravity they
	# are sparks off an anvil, which is a different event.
	m.gravity = Vector3(0.0, -K.GRAVITY * 0.1, 0.0)
	m.damping_min = 1.0
	m.damping_max = 2.4
	m.angular_velocity_min = -90.0
	m.angular_velocity_max = 90.0
	m.scale_min = 0.6
	m.scale_max = 1.4 if tier == MINOR else 2.0
	m.scale_curve = _curve([Vector2(0.0, 0.2), Vector2(0.18, 1.0),
		Vector2(1.0, 0.1)])
	var tint := Pal.GOLD.lerp(Pal.BONE, 0.25)
	m.color_ramp = _fade(tint, 0.05, 0.55, 0.95)
	p.process_material = m
	p.draw_pass_1 = _billboard(tint, 0.1 if tier == MINOR else 0.15)
	p.emitting = true
	return p


# --- Light that STAYS -----------------------------------------------------------
#
# Everything above this line is an EVENT: it fires on one frame, decays on a
# clock of its own and frees itself. The two below are STATES -- a thing is being
# held up for you to look at; a box is standing open with something alight inside
# it -- and they last exactly as long as whatever owns them says.
#
# Card #127. The playtest note was that the ceremony read as *an object parked in
# the air*, and the two halves of the fix are here rather than in `ItemGet` and
# `BossItemChest` because a second glow vocabulary is the thing this file exists
# to prevent. Same palette, same MIX blending, same rule: **these breathe by
# changing SHAPE and never by changing a material's alpha** (CLAUDE.md §3 --
# alpha does not attenuate over a near-black dungeon floor, and additive over it
# is an opaque slab at every opacity).

## Peak alpha of a standing glow, and it is a THIRD of what looks right in the
## editor viewport. The disc is a radial falloff, so this is the alpha at its
## very centre; at 1.0 -- which is what `_billboard` hands out by default for a
## mote -- the middle of the halo is flat gold over a black room and the item
## being presented is a silhouette cut out of a coin.
const AURA_ALPHA := 0.34
## The mouth of an opened chest, seen nearly edge-on from the ceremony camera. It
## carries more than the halo because it is the thing that has to read as *inside
## the box*: too faint and it is a smudge on the lid line.
const MOUTH_ALPHA := 0.46
## The spill standing above the mouth. `_shaft_mesh`'s hard-won number, and for
## its reason -- a cylinder is two walls deep from most angles, so a MIX alpha of
## `a` composites toward `1 - (1 - a)^2`. This one is CULL_FRONT like the shaft,
## which is what keeps the near wall from being drawn as a veil over the chest.
const SPILL_ALPHA := 0.26


## The light an item being presented carries with it: a soft disc standing behind
## it, a lamp so the model is lit rather than merely outlined, and a slow drift of
## motes so the air around it is doing something.
##
## It BREATHES by scale. A halo whose alpha pulsed would be invisible at the
## bottom of the cycle and a gold plate at the top; a halo whose radius moves
## reads as light at every point in between.
class Aura extends Node3D:
	## How far the disc's radius travels, either side of 1.0, and how fast. Small:
	## this is meant to be felt rather than watched, and a halo that visibly
	## throbs turns the item into a warning light.
	const BREATH := 0.085
	const BREATH_SPEED := 1.9

	var _t := 0.0
	var _rest := 1.0
	var _disc: MeshInstance3D = null

	func _process(delta: float) -> void:
		_t += delta
		if _disc == null or not is_instance_valid(_disc):
			return
		var k := _rest * (1.0 + sin(_t * BREATH_SPEED) * BREATH)
		_disc.scale = Vector3(k, k, k)


## The inside of an opened chest, alight. A pool of light lying in the mouth, a
## short column standing out of it, and a lamp down in the box so the lid's
## underside and the inner walls are actually lit by it.
##
## `close()` NARROWS it out rather than fading it, for `_step_shaft`'s reason
## turned around: the chest is being emptied, and a column that shrank downward
## would read as the light being pulled back into a box the player has just been
## shown is empty.
class BoxLight extends Node3D:
	const BREATH := 0.055
	const BREATH_SPEED := 1.35

	var _t := 0.0
	var _shut := -1.0
	var _shut_time := 0.5
	var _breath: Node3D = null
	var _lamp: OmniLight3D = null
	var _lamp_energy := 1.0

	func _process(delta: float) -> void:
		_t += delta
		var k := 1.0 + sin(_t * BREATH_SPEED) * BREATH
		if _shut >= 0.0:
			_shut += delta
			var u := clampf(_shut / _shut_time, 0.0, 1.0)
			k *= maxf(1.0 - u * u, 0.0)
			if _lamp != null:
				# A LIGHT, not a material, so this one is allowed to fade -- see
				# `_step_light`, which does exactly this. §3's trap is about
				# surfaces composited over black, and a lamp is neither.
				_lamp.light_energy = _lamp_energy * maxf(1.0 - u, 0.0)
			if u >= 1.0:
				queue_free()
				return
		if _breath != null:
			# X and Z only. The column keeps its height while it thins, which is
			# `_step_shaft`'s shape and the reason given there.
			_breath.scale = Vector3(k, 1.0, k)

	## Put it out over `seconds`. Idempotent -- a chest whose ceremony is
	## dismissed twice must not restart the close and live twice as long.
	func close(seconds: float = 0.5) -> void:
		if _shut < 0.0:
			_shut = 0.0
			_shut_time = maxf(seconds, 0.05)


## Hang an `Aura` on `anchor`. `radius` is the halo's radius in metres; pass a
## little more than the item's own extent, so the light is around it rather than
## behind it like a plate.
static func aura(anchor: Node3D, radius: float,
		tint: Color = Pal.GOLD) -> Aura:
	if anchor == null or not is_instance_valid(anchor):
		return null
	var node := Aura.new()
	node.name = &"Aura"
	node._rest = maxf(radius, 0.05)
	anchor.add_child(node)

	var warm := tint.lerp(Pal.BONE, 0.2)
	node._disc = MeshInstance3D.new()
	node._disc.name = &"Halo"
	# Unit-sized, scaled by `_process`. A quad whose SIZE was animated would
	# rebuild the mesh every frame; a quad whose node scale is animated is one
	# transform, and `billboard_keep_scale` is what makes that legal on a
	# billboard at all.
	node._disc.mesh = _billboard(
		Color(warm.r, warm.g, warm.b, AURA_ALPHA), 2.0)
	node._disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# BEHIND the item, always. The halo is depth-tested (this whole file is --
	# see `_flat_mat`), so without this it z-fights the model it is lighting from
	# whichever angle the display's own rotation brings round.
	node._disc.sorting_offset = -0.35
	node._disc.scale = Vector3.ONE * node._rest
	node.add_child(node._disc)

	var lamp := OmniLight3D.new()
	lamp.name = &"AuraLamp"
	lamp.light_color = warm
	lamp.light_energy = 2.2
	lamp.omni_range = 3.0
	lamp.omni_attenuation = 1.6
	lamp.shadow_enabled = false
	# ABOVE the item and not inside it, and this is a SHAPE fix for exactly the
	# failure CLAUDE.md §3 names. An omni at the item's own centre is zero metres
	# from every surface of it, and 1/d^2 does what 1/d^2 does: the bow, which is
	# a thin silhouette with almost no face turned to the lamp, read beautifully,
	# and the Verse plaque -- a flat 0.78 m plate whose face normal points
	# straight at the camera -- went to a WHITE RECTANGLE with its letter gone.
	# Four of the six items that get this ceremony use that plaque.
	#
	# Lowering the energy would not have fixed it (at d ~ 0 nothing does) and
	# raising the plaque's roughness would have been solving it on the wrong
	# object. Moved up by most of a radius instead, the plate is lit at a grazing
	# angle -- N.L near zero, so the face stays the near-black it was authored as
	# -- while the halo and the motes, which are what the eye reads as the glow,
	# are untouched. Verified by looking: `item_get_frame --out=/tmp/ig10`,
	# `i_20_copy_burst.png`.
	lamp.position.y = node._rest * 0.9
	node.add_child(lamp)

	node.add_child(_drift(warm, radius))
	return node


## Light the inside of `chest`. `mouth` is the opening's size, `at` is where that
## opening sits and `height` is how far the spill stands out of it -- all three in
## the CHEST'S OWN space, and all three from the caller. A great chest is scaled
## up at the root and an ordinary one is not, so a glow measured off a bounding
## box here would put the pool through somebody's lid.
static func box_light(chest: Node3D, mouth: Vector2, at: Vector3,
		height: float, tint: Color = Pal.GOLD) -> BoxLight:
	if chest == null or not is_instance_valid(chest):
		return null
	var node := BoxLight.new()
	node.name = &"BoxLight"
	chest.add_child(node)
	node.position = at

	node._breath = Node3D.new()
	node._breath.name = &"Breath"
	node.add_child(node._breath)

	var pool := _pool_mesh(mouth, tint)
	node._breath.add_child(pool)

	# The spill takes the MOUTH'S footprint and not a circle inscribed in it. A
	# chest is half as deep as it is wide, so a round column narrow enough to fit
	# the depth is narrower than the hero standing in front of it -- and the
	# ceremony camera looks at the hero's back with the chest directly behind him,
	# so all of it went behind his shoulders and the frame showed no light leaving
	# the box at all. Matching the ellipse puts it either side of him.
	node._breath.add_child(
		_spill_mesh(mouth * 0.44, maxf(height, 0.02), tint))

	node._lamp = OmniLight3D.new()
	node._lamp.name = &"BoxLamp"
	node._lamp.light_color = tint
	node._lamp_energy = 1.7
	node._lamp.light_energy = node._lamp_energy
	node._lamp.omni_range = 2.3
	node._lamp.omni_attenuation = 1.4
	node._lamp.shadow_enabled = false
	# DOWN in the box, not at the mouth. The read is the inner walls and the
	# underside of the open lid catching it; a lamp level with the opening lights
	# the room and leaves the inside of the chest exactly as dark as it was.
	# A QUARTER of the mouth's depth and not a third: at a third the open lid --
	# which has swung past vertical, stands above the box and is by far the
	# largest interior-facing surface either camera can actually SEE -- sat
	# outside the falloff and stayed dark.
	#
	# **1.7 and 2.3 m, and both were measured off a frame that was wrong.** At
	# 3.0 over 2.8 m the lid clipped to white and read as a pale slab standing
	# behind the chest: STYLEGUIDE §7.2's "nothing near #FFFFFF", arrived at from
	# the light rather than from the material. It is the one surface in this
	# effect that is lit rather than emitted, so it is also the one that can blow.
	node._lamp.position.y = -mouth.y * 0.25
	node.add_child(node._lamp)
	return node


## The pool of light lying in a chest's mouth: a flat radial disc in the XZ
## plane, hot in the middle and transparent at the rim.
##
## Depth-TESTED and therefore occluded by the chest's own walls, which is the
## point -- from the ceremony camera you are looking down into the box at a
## shallow angle and the near wall has to cut the pool off. `_flat_mat`'s note
## about `no_depth_test` is the same lesson from the other end.
static func _pool_mesh(mouth: Vector2, tint: Color) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var hot := Color(tint.r, tint.g, tint.b, MOUTH_ALPHA)
	var cold := Color(Pal.BONE.r, Pal.BONE.g, Pal.BONE.b, 0.0)
	var sides := 24
	# Elliptical rather than round, because a chest's mouth is. Built as a fan
	# from a hot centre so the falloff is in the VERTEX COLOURS and not in a
	# texture -- one more 64x64 gradient per chest is the allocation `_tex`'s note
	# refuses on the frame this lands.
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		verts.append_array([
			Vector3.ZERO,
			Vector3(sin(a0) * mouth.x * 0.5, 0.0, cos(a0) * mouth.y * 0.5),
			Vector3(sin(a1) * mouth.x * 0.5, 0.0, cos(a1) * mouth.y * 0.5),
		])
		colors.append_array([hot, cold, cold])
	var mi := _mesh_of(verts, colors, &"Pool", false)
	# A hair above the seam so it does not z-fight the chest's own floor when the
	# caller's `at` lands exactly on it.
	mi.position.y = 0.01
	return mi


## The short column of light standing out of the mouth. `_shaft_mesh`'s trick at
## a twentieth of the size: an open cylinder, hot at the BOTTOM and transparent
## at the top, with only its far wall drawn.
##
## The MAJOR shaft is a seven-metre announcement visible across a room. This is
## the opposite piece of language -- it exists to say *the light is coming out of
## here*, so it is shorter than the chest is wide and it never leaves the box's
## own silhouette.
static func _spill_mesh(radii: Vector2, height: float,
		tint: Color) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var hot := Color(tint.r, tint.g, tint.b, SPILL_ALPHA)
	var cold := Color(Pal.BONE.r, Pal.BONE.g, Pal.BONE.b, 0.0)
	var sides := 16
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var b0 := Vector3(sin(a0) * radii.x, 0.0, cos(a0) * radii.y)
		var b1 := Vector3(sin(a1) * radii.x, 0.0, cos(a1) * radii.y)
		var t0 := Vector3(b0.x, height, b0.z)
		var t1 := Vector3(b1.x, height, b1.z)
		verts.append_array([b0, t0, t1, b0, t1, b1])
		colors.append_array([hot, cold, cold, hot, cold, hot])
	var mi := _mesh_of(verts, colors, &"Spill", false)
	# CULL_FRONT, for `_shaft_mesh`'s reason spelled out there: with both walls
	# drawn the near one is a veil across the thing the light exists to show.
	(mi.material_override as StandardMaterial3D).cull_mode = \
		BaseMaterial3D.CULL_FRONT
	return mi


## What drifts around a held item. Continuous and slow, not a burst: `_motes` is
## the moment of arrival and this is the minute afterwards, so they must not read
## as the same event.
static func _drift(tint: Color, radius: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = &"Drift"
	p.amount = 10
	p.lifetime = 2.4
	p.local_coords = true
	p.fixed_fps = 30
	p.visibility_aabb = AABB(Vector3(-2.0, -1.0, -2.0), Vector3(4.0, 5.0, 4.0))

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = radius * 0.8
	m.direction = Vector3.UP
	m.spread = 22.0
	m.initial_velocity_min = 0.10
	m.initial_velocity_max = 0.34
	# NO gravity at all, where `_motes` runs a tenth. These are meant to hang in
	# the air beside a thing being held still; anything that falls turns the
	# presentation into an object shedding sparks.
	m.gravity = Vector3.ZERO
	m.damping_min = 0.2
	m.damping_max = 0.7
	m.scale_min = 0.5
	m.scale_max = 1.2
	m.scale_curve = _curve([Vector2(0.0, 0.0), Vector2(0.25, 1.0),
		Vector2(1.0, 0.0)])
	m.color_ramp = _fade(tint, 0.12, 0.6, 0.85)
	p.process_material = m
	p.draw_pass_1 = _billboard(tint, 0.055)
	p.emitting = true
	return p


# --- Shared building blocks -----------------------------------------------------
# Local copies, this folder's pattern: `SlamVfx`, `SpinVfx`, `ImpactVfx` and
# `FlourishVfx` each carry their own, tuned to the effect around them.

static func _curve(points: Array[Vector2]) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


static func _fade(c: Color, rise: float, hold: float,
		peak: float) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, rise, hold, 1.0])
	g.colors = PackedColorArray([
		Color(c.r, c.g, c.b, 0.0),
		Color(c.r, c.g, c.b, peak),
		Color(c.r, c.g, c.b, peak * 0.75),
		Color(c.r, c.g, c.b, 0.0),
	])
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _billboard(c: Color, size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = c
	m.albedo_texture = _tex()
	m.disable_receive_shadows = true
	q.material = m
	return q


static func _tex() -> GradientTexture2D:
	if _soft != null:
		return _soft
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	_soft = GradientTexture2D.new()
	_soft.gradient = g
	_soft.width = 64
	_soft.height = 64
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5, 0.5)
	_soft.fill_to = Vector2(1.0, 0.5)
	return _soft
