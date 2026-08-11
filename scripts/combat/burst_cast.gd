class_name BurstCast
extends Node3D
## One cast of the Burst-Verse, in flight and then not. Built and thrown by
## `HeroRanged`; owns its own arc, its own fuse and the one blast at the end of
## them.
##
## **It is cast, not thrown as a satchel** (`docs/GDD.md` §5.2). What that
## changes is the noun and the particle colour: the mote is a read word rather
## than a bag of powder, so it is a bronze glyph burning down instead of a fuse
## in string, and the arc, the fuse, the sphere query and the cracked wall are
## the same four things they were. There is no mana, no school and no casting
## layer — `HeroRanged` fires this the way it fires an arrow, because a working
## is a usable item (`docs/SCOPE.md` §1).
##
## ## The arc raycasts its own step, exactly as `Arrow` does
##
## A third of an arrow's speed is still 0.2 m a frame, which is thinner than a
## goblin but not thinner than the lip of a stair. The reason to raycast the
## SEGMENT rather than hang an Area3D on it is the same reason `arrow.gd` gives
## and it survives the slower speed: an overlap test only reports what it is
## inside of on the frame the server samples it, and a mote that clipped the
## corner of a step would sail through the floor and fuse under the room. That
## failure is invisible — the blast happens, nothing is in radius, and it reads
## as the working not working.
##
## ## The fuse runs from the CAST, not from the landing
##
## `K.BOMB_FUSE` is 3.5 s from the moment it leaves his hand, whether it lands in
## half a second or bounces for two. That is the [oot] measurement and it is also
## the only version that is a decision: a fuse that started on contact would make
## a long throw free, and the whole cost of the item is that you have to be
## somewhere else by the time it goes.
##
## ## Two things happen in the blast and they are not the same thing
##
## The **damage** is a sphere query against bodies — enemies, and the hero, who
## is NOT exempt (`K.BOMB_HURTS_OWNER`, `docs/CONTRACT.md` §7). The **puzzle** is
## a walk of group `&"burstable"` calling `burst()` on everything inside the
## radius, which is the one line `cracked_pillar.gd` has been waiting for since
## M1 and the reason its entry point is named for the verb. They are separate
## because an atom is not a body: a cracked pillar has a `StaticBody3D` on
## `L_WORLD` and no health, and a query that found it would have to work out what
## it was before deciding what to do to it.

## Seconds the mote lives after the blast, so the light and the grit are not cut
## off with the node that spawned them. Longer than the flash and longer than any
## particle's lifetime.
const AFTERGLOW := 0.9

## How much speed a bounce keeps, and how much sideways drag a landing applies.
## A mote that rolled would be a mote whose resting place the player cannot
## predict, and the whole verb is "put it THERE"; a mote that stopped dead on
## contact would refuse to drop off a ledge it was thrown at. 0.28 is a stone
## skipping once and then sitting down. [tune]
const BOUNCE := 0.28
## Below this, in m/s, it stops pretending and sits still.
const SETTLE_SPEED := 1.2

## Metres. The glyph in flight — small, because the thing the player is reading
## is the ARC and a big bright ball hides its own trajectory behind itself.
const MOTE_R := 0.11

## The flash SNAPS OPEN AND SHUT rather than fading, and that is not a style
## choice — `CLAUDE.md` §3 and `impact_vfx.gd` both record it: alpha does not
## attenuate an additive material, so a bright shell faded out over a near-black
## dungeon floor is an opaque pale slab at every opacity. Change the shape.
const FLASH_OPEN := 0.06
const FLASH_SHUT := 0.20

var _velocity: Vector3 = Vector3.ZERO
var _fuse: float = 0.0
var _spent: bool = false
var _settled: bool = false
var _caster: Node3D = null

var _mote: Node3D = null
var _lamp: OmniLight3D = null
var _flash: MeshInstance3D = null
var _flash_t: float = -1.0

var _query := PhysicsRayQueryParameters3D.new()
var _sphere := PhysicsShapeQueryParameters3D.new()


## Throw one. `caster` is excluded from the FLIGHT raycast only — he is very
## much included in the blast, which is the item's own risk and the reason the
## arc is worth aiming.
static func cast_from(parent: Node, from: Vector3, dir: Vector3,
		caster: Node3D = null) -> BurstCast:
	if parent == null or not parent.is_inside_tree():
		push_warning("BurstCast: no live parent; the working went nowhere")
		return null
	var b := BurstCast.new()
	b.name = "BurstCast"
	# Parented to the SCENE and never to the hero, for `arrow.gd`'s reason: a
	# mote under him inherits his yaw and his 1.65 scale, which bends the arc and
	# renders a metre-wide glyph.
	parent.add_child(b)
	b.global_position = from
	b._velocity = dir.normalized() * K.BURST_THROW_SPEED
	b._caster = caster
	if caster != null:
		b._query.exclude = [caster.get_rid()]
	return b


func _ready() -> void:
	_fuse = K.BOMB_FUSE
	_query.collision_mask = K.L_WORLD | K.L_ENEMY | K.L_INTERACT
	_query.collide_with_bodies = true
	_query.collide_with_areas = false
	_build()
	Bus.request_sfx.emit(&"hookshot_load", global_position)


func _physics_process(delta: float) -> void:
	if _spent:
		_afterglow(delta)
		return

	_fuse -= delta
	# The pulse quickens as the fuse runs down. It is the only warning the player
	# gets and it has to be readable from outside the blast radius, so it is
	# carried by the LIGHT rather than by a colour change — a hue shift on a
	# 0.11 m ball is invisible at 4 m, and 4 m is exactly where you want to be.
	if _lamp != null:
		var urgency := 1.0 - clampf(_fuse / maxf(K.BOMB_FUSE, 0.01), 0.0, 1.0)
		var beat := sin(Time.get_ticks_msec() * 0.001 * TAU * lerpf(1.6, 9.0, urgency))
		_lamp.light_energy = lerpf(1.1, 3.4, urgency) * (0.7 + 0.3 * beat)

	if _fuse <= 0.0:
		_blast()
		return
	if not _settled:
		_fly(delta)


# --- The arc ------------------------------------------------------------------

func _fly(delta: float) -> void:
	_velocity.y -= K.GRAVITY * K.BURST_GRAVITY_SCALE * delta
	var from := global_position
	var to := from + _velocity * delta

	_query.from = from
	_query.to = to
	var hit := get_world_3d().direct_space_state.intersect_ray(_query)
	if hit.is_empty():
		global_position = to
		return

	var normal := hit["normal"] as Vector3
	# Stand it off the surface by its own radius, so a landed mote reads as a
	# glyph lying on the floor rather than as one half-buried in it.
	global_position = (hit["position"] as Vector3) + normal * MOTE_R

	# Reflect, lose most of it, and give up once there is nothing left. Note the
	# fuse does not care about any of this — see the class note.
	_velocity = _velocity.bounce(normal) * BOUNCE
	if _velocity.length() < SETTLE_SPEED:
		_velocity = Vector3.ZERO
		_settled = true
	Bus.request_sfx.emit(&"weapon_impact_stab_1", global_position)


# --- The blast ----------------------------------------------------------------

func _blast() -> void:
	_spent = true
	_velocity = Vector3.ZERO
	var at := global_position

	_wake_the_burstable(at)
	_hurt_what_is_in_reach(at)

	if _mote != null:
		_mote.visible = false
	_flash = _build_flash()
	_flash_t = 0.0
	add_child(_build_grit())
	if _lamp != null:
		_lamp.light_energy = 9.0
		_lamp.omni_range = K.BOMB_RADIUS * 2.4
	Bus.request_sfx.emit(&"jump_slam", at)
	# Above `SHAKE_CRIT`, and it is the only thing in the game that is. A crit is
	# a blow landing on a body and this is a room changing shape — the whole
	# reason the working is the destructive answer (GDD §5.2) is that it moves
	# architecture, and a blast that shook the camera less than a sword would
	# tell the player it did not.
	Bus.request_shake.emit(K.SHAKE_CRIT * 1.25, 0.34)
	Bus.request_hitstop.emit(K.HITSTOP_HEAVY)


## **The line `cracked_pillar.gd` was written for.** Walked as a GROUP rather
## than found by a query, because an atom is a marker and not a body: the pillar
## keeps a `StaticBody3D` on `L_WORLD` for the slab it is holding up, so a shape
## query would hand this the same collider it hands back for a wall and it would
## have to guess which was which. The group is the atom saying "I answer to this
## verb", which is the whole of `docs/PUZZLES.md` §2's contract.
func _wake_the_burstable(at: Vector3) -> void:
	var r2 := K.BOMB_RADIUS * K.BOMB_RADIUS
	for node in get_tree().get_nodes_in_group(&"burstable"):
		var atom := node as Node3D
		if atom == null or not is_instance_valid(atom):
			continue
		if not atom.has_method(&"burst"):
			continue
		# Measured to the atom's ORIGIN, which for a pillar is its foot. That is
		# the right point: what the blast has to reach is the base it stands on,
		# and a pillar whose head happened to be inside the radius while its foot
		# was not is one you would have had to throw upwards at.
		if atom.global_position.distance_squared_to(at) > r2:
			continue
		atom.call(&"burst")


## Everything alive inside the radius, the hero included.
##
## `K.BOMB_HURTS_OWNER` is true and there is no owner check anywhere below —
## `docs/CONTRACT.md` §7 spells that out as an [oot] fact, and it is also the
## only thing that makes the fuse a decision rather than a delay.
func _hurt_what_is_in_reach(at: Vector3) -> void:
	var shape := SphereShape3D.new()
	shape.radius = K.BOMB_RADIUS
	_sphere.shape = shape
	_sphere.transform = Transform3D(Basis.IDENTITY, at)
	_sphere.collision_mask = K.L_ENEMY | K.L_PLAYER | K.L_INTERACT
	_sphere.collide_with_bodies = true
	# Areas too: the props that predate `HealthComponent` hang their damage
	# surface off an Area3D, and the sword's scan and the arrow both look at both
	# for exactly this reason.
	_sphere.collide_with_areas = true

	var space := get_world_3d().direct_space_state
	var seen: Dictionary = {}
	for row in space.intersect_shape(_sphere, 32):
		var victim := _damageable(row.get("collider") as Node)
		if victim == null or seen.has(victim.get_instance_id()):
			continue
		seen[victim.get_instance_id()] = true
		# Sourced at the blast so the knockback throws OUTWARD from it. `Hit`
		# derives its direction from the origin, so a hit sourced at the caster
		# would shove everything down the throw line instead of away from where
		# the thing actually went off.
		victim.call(&"apply_hit", Hit.make(K.BOMB_DAMAGE, at, &"bomb",
			K.BURST_KNOCKBACK))


## The same ladder `arrow.gd` climbs, and deliberately the same order: the node,
## then a `HealthComponent` child, then the parent a hurtbox hangs off. Two
## copies of this rule that could disagree would be two answers to "did that
## hit", which is the one question the whole damage path exists to have one
## answer to (`docs/CONTRACT.md` §8).
func _damageable(node: Node) -> Node:
	if node == null:
		return null
	if node.has_method(&"apply_hit"):
		return node
	for child in node.get_children():
		if child is HealthComponent:
			return child
	var parent := node.get_parent()
	if parent != null and parent.has_method(&"apply_hit"):
		return parent
	return null


# --- The flash ----------------------------------------------------------------

## Open, shut, and then the node goes. On the SCALED clock and not the wall
## clock, unlike `ImpactVfx`'s star: this asks for hit-stop in the same breath as
## the flash, so a shell measured on real seconds would spend the whole freeze
## expanding behind a stopped frame and be gone by the time the world moved.
func _afterglow(delta: float) -> void:
	if _flash_t >= 0.0 and _flash != null:
		_flash_t += delta
		var span := FLASH_OPEN + FLASH_SHUT
		var k := _flash_t / FLASH_OPEN if _flash_t < FLASH_OPEN \
			else 1.0 - (_flash_t - FLASH_OPEN) / FLASH_SHUT
		_flash.scale = Vector3.ONE * maxf(k, 0.0) * K.BOMB_RADIUS
		if _flash_t >= span:
			_flash.queue_free()
			_flash = null
			_flash_t = -1.0
	if _lamp != null:
		_lamp.light_energy = maxf(_lamp.light_energy - delta * 26.0, 0.0)
	_fuse -= delta
	if _fuse <= -AFTERGLOW:
		queue_free()


# --- Construction -------------------------------------------------------------

func _build() -> void:
	_mote = Node3D.new()
	_mote.name = "Mote"
	add_child(_mote)

	var glyph := SphereMesh.new()
	glyph.radius = MOTE_R
	glyph.height = MOTE_R * 2.0
	# Faceted, never smooth — the whole kit is hard-edged and a smooth ball reads
	# as an asset from a different game (`puzzle_atom._cyl` says the same).
	glyph.radial_segments = 8
	glyph.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = glyph
	mi.material_override = _burn(1.6)
	_mote.add_child(mi)

	_lamp = OmniLight3D.new()
	_lamp.name = "Fuse"
	_lamp.light_color = Pal.RUST.lerp(Pal.GOLD, 0.35)
	_lamp.omni_range = 3.2
	_lamp.light_energy = 1.1
	# No shadow. One more shadow-casting light bouncing around a room full of
	# them for three and a half seconds buys nothing the glow does not.
	_lamp.shadow_enabled = false
	add_child(_lamp)


## The shell. Unshaded MIX and nowhere near `#FFFFFF` (`docs/STYLEGUIDE.md`
## §7.2) — the core is BONE dragged toward the working's own hue.
func _build_flash() -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var mi := MeshInstance3D.new()
	mi.name = "Flash"
	mi.mesh = sphere
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Pal.BONE.lerp(Pal.RUST, 0.45)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.scale = Vector3.ZERO
	add_child(mi)
	return mi


## Grit, thrown out and falling. Debris rather than sparks — it SHRINKS as it
## dies, because a growing mote reads as smoke and a working that smoked would be
## the satchel again.
func _build_grit() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Grit"
	p.amount = 34
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.fixed_fps = 30
	var reach := K.BOMB_RADIUS * 1.6
	p.visibility_aabb = AABB(Vector3.ONE * -reach, Vector3.ONE * reach * 2.0)

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = K.BOMB_RADIUS * 0.25
	m.direction = Vector3.UP
	m.spread = 180.0
	m.initial_velocity_min = 3.0
	m.initial_velocity_max = 8.5
	m.gravity = Vector3(0.0, -K.GRAVITY * 0.5, 0.0)
	m.damping_min = 3.0
	m.damping_max = 7.0
	m.scale_min = 0.6
	m.scale_max = 1.5
	m.scale_curve = _curve([Vector2(0.0, 1.0), Vector2(0.6, 0.75), Vector2(1.0, 0.1)])
	var tint := Pal.GOLD.lerp(Pal.RUST, 0.5)
	m.color_ramp = _fade(tint, 0.05, 0.55)
	p.process_material = m
	p.draw_pass_1 = _speck(tint, 0.09)
	p.emitting = true
	return p


## The glyph's own material: emissive, with the albedo dragged dark. A tinted
## albedo under a nearby lamp clips to white and the coloured thing photographs
## as a white smear — `puzzle_atom._glow_mat` learned that twice and this is the
## same lesson, which is why the numbers match it.
func _burn(energy: float) -> StandardMaterial3D:
	var hue := Pal.RUST.lerp(Pal.GOLD, 0.35)
	var m := StandardMaterial3D.new()
	m.albedo_color = hue.darkened(0.80)
	m.roughness = 0.85
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.emission_enabled = true
	m.emission = hue
	m.emission_energy_multiplier = energy
	return m


func _speck(tint: Color, size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = tint
	q.material = m
	return q


func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p: Vector2 in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


## Full at birth, gone by the end, with the knee late so the grit is visible for
## most of its life instead of being a flicker.
func _fade(tint: Color, hold: float, knee: float, peak: float = 1.0) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, Color(tint, peak))
	g.set_offset(1, 1.0)
	g.set_color(1, Color(tint, 0.0))
	g.add_point(clampf(hold, 0.0, 1.0), Color(tint, peak))
	g.add_point(clampf(knee, 0.0, 1.0), Color(tint, peak * 0.65))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t
