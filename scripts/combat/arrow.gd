class_name Arrow
extends Node3D
## One arrow, in flight. Built and launched by HeroRanged; owns nothing but its
## own trajectory and the one blow it lands.
##
## **It is not an Area3D, and that is the point.** K.ARROW_SPEED is 42 m/s, which
## at 60 Hz is a 0.7 m step per frame — further than a goblin is wide and far
## further than a wall is thick. An Area3D only reports what it OVERLAPS on the
## frame the physics server samples it, so an arrow built that way passes clean
## through a thin enemy roughly as often as it hits one, and the misses look like
## bad aim rather than a bug. So each frame this raycasts the SEGMENT it is about
## to travel and stops at whatever that segment crosses. Nothing can be missed by
## being narrow.
##
## The shaft drops: K.ARROW_GRAVITY is a tenth of the world's, because [oot]
## arrows barely fall across the 8.5 m lock range. Far enough out it is visible,
## which is what makes a long shot a shot rather than a hitscan.
##
## ## It can change in the air — combinator 8, convert
##
## `docs/PUZZLES.md` §3.1: an arrow that crosses a LIT lantern arrives as
## `Hit.ARROW_FIRE`, and a frozen eye switch accepts nothing else. That is one
## `StringName` on the blow (`_kind`), one extra ray a frame (`_probe_convert`)
## and a plume of geometry (`_ignite`) — and it is deliberately the whole of it,
## because §8.1 prices the combinator at exactly that and says a convert needing
## a prop of its own has stopped being a combinator.
##
## The probe is a SECOND query and must stay one. The flight query above stops
## the arrow at whatever it crosses, which is the exact opposite of what a
## convert volume wants; merging them is a flame the arrow sticks in.

## 2 HP, same as the sword — the bow's advantage is
## reach, not damage, and a bow that also out-damages the blade is the only
## weapon anyone brings. [tune]
const DAMAGE := 2
const KNOCKBACK := K.KNOCKBACK_LIGHT
## Seconds a spent arrow stays stuck in whatever it hit before it disappears.
const LINGER := 2.5
## Seconds before an arrow that never hit anything gives up.
const LIFETIME := 4.0

## The model, and how it has to be turned to agree with the flight.
##
## `assets/weapons/arrow.glb` is a real arrow with a real head, real fletching
## and its own materials — 224 triangles, which is cheaper than the five-sided
## cylinder it replaced was going to be once it grew a nock. It imports lying
## along +Y, and this node flies along -Z (see `_face_travel`), so the model gets
## a quarter turn about X and nothing else in the class has to know.
##
## MEASURED, not derived. Which end of a GLB is the point is not a thing to
## reason out from an axis name — see CLAUDE.md §4 and
## `tools/directors/arrow_supply.gd`, which renders it and measures it.
const MODEL_ID := "arrow"
const MODEL_PITCH := -PI * 0.5
## Rendered length, metres. Not used by anything here — the flight is a raycast
## and cares nothing for the mesh — but the bundle and the lookdev both want to
## know how long the thing they are laying out is.
const MODEL_LEN := 0.70

# --- Burning (docs/PUZZLES.md §3.1, combinator 8) ----------------------------
## The plume, in numbers, and **the plume is geometry rather than a brighter
## material on purpose.**
##
## CLAUDE.md §3: emissive over near-black photographs as an opaque slab at every
## opacity, so a "burning" arrow made by turning the shaft's emission up is a
## brighter smear the eye reads as a rendering fault. The rule that survived is
## *change the shape*. So a converted arrow grows four faceted tongues that
## triple its silhouette width for the front half of its length — a plain arrow
## is a line, a burning one is a line with a teardrop wrapped round it — and the
## RUST emission underneath is the second cue, not the first.
##
## This is the entire visual budget of the mechanic. It has to be legible in a
## STILL frame at gameplay distance, because the colour change is the only way
## the player ever learns the rule.
## Licks around the shaft, plus one down the middle. Five splayed and one core:
## an even ring reads as a collar, and a single cone reads as a traffic cone —
## which is what the first pass of this actually shipped, and the broadside frame
## is the only thing that said so.
const FLAME_TONGUES := 5
## Fattest lick at its base, metres. Small on purpose: the width comes from the
## SPLAY below, and five thin licks fanned apart leave gaps that read as fire
## where one fat cone of the same envelope reads as a solid object.
const FLAME_R := 0.075
## How far the outer licks lean off the shaft, radians. 0.30 puts the widest part
## of the plume about 0.20 m off the axis — roughly ten shaft-widths.
const FLAME_SPLAY := 0.30
## Where the plume starts, along the shaft. The node flies along -Z with the head
## at -Z, so this sits just BEHIND the head and everything streams back at +Z.
const FLAME_Z0 := -0.20
## Length of the longest lick. **The single most valuable number here.** Width
## fights the shaft's own scale and loses at ten metres; LENGTH does not — a
## burning arrow is a 1.0 m streak where a plain one is a 0.7 m splinter, and
## that difference survives being twenty pixels tall.
const FLAME_LEN := 0.78
## The lamp the plume carries. A burning arrow that lights the wall it passes is
## the cue that reads even when the arrow itself is only a few pixels tall, and
## it is the one thing a still frame cannot fake.
const FLAME_LIGHT_RANGE := 4.8
const FLAME_LIGHT_ENERGY := 3.6

var _velocity: Vector3 = Vector3.ZERO
var _origin: Vector3 = Vector3.ZERO
var _age: float = 0.0
var _stuck: bool = false
## Nodes the shot must not hit: the hero and everything under him. An arrow
## leaving a muzzle that sits inside the hero's own capsule would otherwise
## report a hit on frame one, every time.
var _ignore: Array[RID] = []

## What this arrow will be when it lands. `Hit.ARROW` until it crosses something
## that rewrites it — see `_probe_convert`. One field, which is the whole cost
## `docs/PUZZLES.md` §8.1 quotes for combinator 8.
var _kind: StringName = Hit.ARROW
var _plume: Node3D

var _query := PhysicsRayQueryParameters3D.new()
## The convert probe, kept apart from the flight query above and never merged
## with it. The flight query STOPS the arrow at what it finds; this one must not,
## so it masks one layer nothing else uses (`K.L_CONVERT`), looks only at areas,
## and reports a crossing rather than a collision.
var _convert_query := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_build()


## Fire from `from` along `dir`. `shooter` is excluded from the raycast.
func launch(from: Vector3, dir: Vector3, shooter: CollisionObject3D = null) -> void:
	global_position = from
	_origin = from
	_velocity = dir.normalized() * K.ARROW_SPEED
	if shooter != null:
		_ignore = [shooter.get_rid()]
	_query.collision_mask = K.L_WORLD | K.L_ENEMY | K.L_INTERACT
	# Bodies AND areas: enemies are bodies, but the props that predate
	# HealthComponent hang their damage surface off an Area3D, and the sword
	# scans both for exactly this reason (hero_combat.gd `_scan`).
	_query.collide_with_bodies = true
	_query.collide_with_areas = true
	_query.exclude = _ignore

	# Areas only, and only the convert bit. `hit_from_inside` because an arrow
	# loosed from inside a flame volume (a lantern at point-blank range) has no
	# entry surface for the ray to cross and would otherwise fly out unchanged.
	_convert_query.collision_mask = K.L_CONVERT
	_convert_query.collide_with_bodies = false
	_convert_query.collide_with_areas = true
	_convert_query.hit_from_inside = true
	_convert_query.exclude = _ignore
	_face_travel()


## What this shot will land as. `Hit.ARROW`, or `Hit.ARROW_FIRE` once it has
## crossed a lit flame. Read by directors and by nothing in the game — the atoms
## are told by the `Hit` they are handed, which is the one damage path.
func kind() -> StringName:
	return _kind


func _physics_process(delta: float) -> void:
	if _stuck:
		_age += delta
		if _age >= LINGER:
			queue_free()
		return

	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return

	_velocity.y -= K.ARROW_GRAVITY * delta
	var from := global_position
	var to := from + _velocity * delta

	# **Before the strike, on the same segment.** A shot that crosses a lit
	# lantern and lands on the eye behind it in one 0.7 m step has to arrive
	# already converted, and it will: the flame is nearer than the eye, so the
	# crossing belongs to this frame either way.
	_probe_convert(from, to)

	_query.from = from
	_query.to = to
	var hit := get_world_3d().direct_space_state.intersect_ray(_query)
	if hit.is_empty():
		global_position = to
		_face_travel()
		return

	# Land ON the surface, not a hair inside it, so a stuck arrow reads as an
	# arrow in a wall rather than a fletching sticking out of nothing.
	global_position = hit["position"] as Vector3 - _velocity.normalized() * 0.04
	_face_travel()
	_strike(hit["collider"] as Node)


## Damage whatever the head found, if it is the kind of thing that takes damage.
## World geometry is not, and an arrow in a wall is a legitimate outcome — it is
## how you learn the range.
func _strike(collider: Node) -> void:
	_stuck = true
	_age = 0.0
	_velocity = Vector3.ZERO

	var victim := _damageable(collider)
	if victim == null:
		Bus.request_sfx.emit(&"weapon_impact_stab_1", global_position)
		return

	var hit := Hit.make(DAMAGE, _origin, _kind, KNOCKBACK)
	var landed = victim.apply_hit(hit)
	# apply_hit returns bool on a HealthComponent and null on the duck-typed
	# props that predate it, so absence of a false is a landed blow. Same rule
	# the sword uses; they must not diverge.
	if landed == false:
		return
	Bus.request_sfx.emit(&"arrow_body_impact", global_position)
	Bus.request_hitstop.emit(K.HITSTOP_LIGHT)
	# An arrow that stayed lodged in a walking enemy would have to be parented to
	# it and dragged around; it is not worth the ownership question, so it goes
	# the moment it connects.
	queue_free()


# --- Convert (docs/PUZZLES.md §3.1, combinator 8) ----------------------------

## Did this frame's segment cross something that rewrites the shot?
##
## **The volume decides, not this.** The probe finds an `Area3D` on `L_CONVERT`,
## walks to whatever owns it, and asks — a lantern that is DARK answers `&""` and
## the arrow flies on unchanged, which is the entire "only while lit" rule and
## the reason it lives on the lantern rather than here. An arrow that tested
## `lantern.is_solved()` itself would be the projectile knowing what a lantern is.
##
## Converts once. A second flame on the same line has nothing left to say, and
## `_kind` staying put is what stops a corridor of lanterns from being a corridor
## of re-ignitions each costing a ray.
func _probe_convert(from: Vector3, to: Vector3) -> void:
	if _kind != Hit.ARROW:
		return
	_convert_query.from = from
	_convert_query.to = to
	var found := get_world_3d().direct_space_state.intersect_ray(_convert_query)
	if found.is_empty():
		return
	var volume := found["collider"] as Node
	if volume == null:
		return
	# The Area3D is a child of the prop; the prop is what knows its own state.
	var owner_node := volume.get_parent()
	if owner_node == null or not owner_node.has_method(&"convert_kind"):
		return
	var into: StringName = owner_node.call(&"convert_kind")
	if into == &"" or into == _kind:
		return
	_kind = into
	_ignite(found["position"] as Vector3)


## Put the fire on it. Geometry, not a brighter material — see FLAME_TONGUES.
func _ignite(at: Vector3) -> void:
	if _plume != null:
		return
	_plume = Node3D.new()
	_plume.name = "Plume"
	add_child(_plume)

	# RUST, the palette's danger hue (`docs/STYLEGUIDE.md` §2), and not GOLD.
	# Gold is currency and only currency by that table's own rule — the lantern
	# already spends it on a flame and a second borrower would make it the colour
	# of "hot" instead of the colour of "money".
	var mat := _flame_mat(Pal.RUST, 2.4)
	# The core runs hotter, and it is a DITHER of two palette entries rather than
	# a thirteenth colour: styleguide anti-slop #5's own prescription is *dither
	# toward BONE* instead of reaching for bloom. It also does the work contrast
	# needs in a torchlit room, where a mid-orange plume against mid-orange stone
	# is a shape you have to already know is there.
	# Pulled well toward BONE and made the WIDEST lick rather than a thin wick,
	# because it is the part that survives distance. Measured on
	# `06_lit_z-2.6_far.png`: at ten metres a RUST plume in a torchlit hall is an
	# orange smudge among orange torches, and the pale core is the one thing in
	# the silhouette the room does not already contain.
	var core_mat := _flame_mat(Pal.RUST.lerp(Pal.BONE, 0.6), 3.8)

	# Five licks fanned around the shaft plus one straight down it. Each cone's
	# APEX POINTS BACKWARD: the fire streams off the head and tapers away behind,
	# which is the read. Built nose-forward the first time, and the frame came
	# back with a solid orange dart on the front of the arrow.
	for i in FLAME_TONGUES + 1:
		var core := i == FLAME_TONGUES
		# Never TAU/N: an even ring photographs as a machined collar. A
		# golden-ratio walk lands them unevenly and never repeats.
		var a := TAU * float(i) * 0.618034
		var splay := 0.0 if core else FLAME_SPLAY * (0.55 + fmod(float(i) * 0.41, 0.62))
		var len := FLAME_LEN * (1.0 if core else 0.52 + fmod(float(i) * 0.33, 0.46))

		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = FLAME_R * (1.35 if core else 1.0)
		cone.height = len
		# Faceted at five sides like every other hand-built prop here — a
		# smooth-shaded flame reads as an asset from a different project
		# (`loot_mote.gd` says the same), and five is odd so no lick presents a
		# flat face square to the lens.
		cone.radial_segments = 5

		# Rolled about the travel axis, so the lean below lands somewhere
		# different for each lick.
		var lick := Node3D.new()
		lick.rotation.z = a
		_plume.add_child(lick)

		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = core_mat if core else mat
		# The mesh grows along +Y. A quarter turn about X lays it along +Z — the
		# TRAILING direction, and the opposite of `MODEL_PITCH`, which is what
		# turns the arrow itself nose-first. `splay` short of that quarter turn is
		# the outward lean.
		mi.rotation.x = PI * 0.5 - splay
		# Centre it on its own axis, starting from just behind the head.
		mi.position = Vector3(0.0, sin(splay) * len * 0.5,
			FLAME_Z0 + cos(splay) * len * 0.5)
		lick.add_child(mi)

	var lamp := OmniLight3D.new()
	lamp.name = "Lamp"
	lamp.light_color = Pal.RUST
	lamp.light_energy = FLAME_LIGHT_ENERGY
	lamp.omni_range = FLAME_LIGHT_RANGE
	lamp.omni_attenuation = 1.5
	lamp.shadow_enabled = false
	_plume.add_child(lamp)

	Bus.request_sfx.emit(&"spell_cast_fire", at)


## One flame surface. Emission-only, with the albedo dragged dark, for the reason
## `PuzzleAtom._glow_mat` gives: a coloured albedo under a nearby lamp clips to
## white and the coloured thing photographs as a white smear.
func _flame_mat(hue: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = hue.darkened(0.7)
	m.roughness = 0.9
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.emission_enabled = true
	m.emission = hue
	m.emission_energy_multiplier = energy
	return m


func _damageable(node: Node) -> Node:
	if node == null:
		return null
	if node.has_method(&"apply_hit"):
		return node
	for child in node.get_children():
		if child is HealthComponent:
			return child
	# The hurtbox is often a child Area3D and the health lives on the body.
	var parent := node.get_parent()
	if parent != null and parent.has_method(&"apply_hit"):
		return parent
	return null


## Point the shaft along travel. The arc is shallow but it is not flat, and an
## arrow that keeps its launch pitch all the way down reads as a dart on rails.
func _face_travel() -> void:
	if _velocity.length_squared() < 0.0001:
		return
	var dir := _velocity.normalized()
	# looking_at cannot build a basis when the direction and up are parallel, and
	# a shot fired straight up off a hookshot pull is reachable.
	var up := Vector3.FORWARD if absf(dir.dot(Vector3.UP)) > 0.98 else Vector3.UP
	global_basis = Basis.looking_at(dir, up)


# --- Construction -----------------------------------------------------------
## The node flies along local -Z, so `looking_at` aims it with no extra
## correction. The MODEL is turned to match, once, here — that is the whole of
## the art-space fix and it lives on the model node, never on this node's basis,
## because `-basis.z is forward` is the contract the flight and the raycast both
## read (CLAUDE.md §4).

func _build() -> void:
	var model := WeaponModels.make(MODEL_ID)
	if model == null:
		return
	model.name = "Model"
	model.rotation.x = MODEL_PITCH
	add_child(model)
