class_name SoundingStone
extends Node3D
## The Echo pedestal. **One prefab, used at all three sites** -- the gate room,
## the treasure chamber and the shortcut door (`docs/PUZZLES.md` §6).
##
## > *Every Echo pickup is a choice of three.*
##
## A drum of Vyr stone with three tones standing over it. Walk into one and it is
## yours; the other two go quiet. It is the Slay the Spire beat and it costs
## nothing beyond the prefab, which is why `docs/PUZZLES.md` §8's manifest can
## say **new UI screens: 0** and mean it.
##
## ## Why the offer is three real `LootMote`s
##
## Because §6's last bullet is *"it arrives as a mote on a pedestal and behaves
## like every other mote when the bag is full: it stays and pulses"*, and
## `LootMote` is already that sentence -- the bob, the magnet, the refusal pulse,
## the `Run.collect` call and the pop. A bespoke pickup here would be a second
## implementation of the one thing in the game the player has done a thousand
## times, and it would be the one that got the full-bag case wrong.
##
## So this file builds a plinth, asks `EchoDb.offer()` for three ids, drops three
## motes on it and listens. Everything else is `LootMote`'s.
##
## ## What it says
##
## Each mote wears the Echo's NAME on a billboard and the stone shows the focused
## one's line. Without that the choice is three identical blue lights, which is a
## coin flip wearing a decision's clothes -- and the names are the whole reason
## §6.1 bothered to be twelve distinct rules rather than a pool of buffs.

## Which pedestal this is, for the world flag. Three sites on one floor need
## three flags or the first one taken silences the others.
@export var stone_id: StringName = &"gate"
## Offered on the frame it is ready. A director (or a placer that wants the stone
## dark until a gate opens) turns this off and calls `offer()` itself.
@export var auto_offer: bool = true

## Radius the three motes stand on, and the plinth's own. Wide enough that a
## walking hero passes through exactly one of them: the motes' pickup spheres are
## 0.75 m, so 1.30 m apart on this ring leaves a clear lane between neighbours
## and the choice is a step rather than a shrug.
##
## It was 1.05, which cleared the *spheres* and not the *names* -- the three
## plates ran into each other and the offer read as one long smear of cyan text.
## The name is the entire reason §6.1 wrote twelve distinct rules instead of a
## pool of buffs, so the ring is sized by the caption, not by the collider.
const RING_R := 1.30
const DRUM_R := 1.72
const DRUM_H := 0.62
const MOTE_Y := 1.16
## How far the plate sits under its mote. Below, not above: the mote is the thing
## you walk into and a caption over it would be the thing you read instead.
const PLATE_DROP := 0.34

var _motes: Array[LootMote] = []
var _plates: Array[Label3D] = []
var _offered: Array[StringName] = []
var _spent: bool = false
var _lamp: OmniLight3D = null
var _age: float = 0.0


func _ready() -> void:
	add_to_group(&"sounding_stone")
	_build()
	# A floor re-entered inside one run does not offer a second tone. The flag is
	# `Game.flags`, which `LockedDoor` and `PuzzleAtom` both write, and it is
	# cleared per RUN rather than per floor for the atom half -- see below.
	if Game.flag(flag_id()):
		_spent = true
		return
	if auto_offer:
		offer()


## The one-way world flag this stone writes.
##
## Prefixed `atom_` **on purpose**, so `PuzzleAtom.clear_run_flags()` wipes it
## with the puzzle it belongs to. An Echo is run-scoped (§6) and the stone that
## offered it has to be too: a permanent flag would mean run two walked past a
## dead pedestal in a gate room it had just re-solved, and §5.2's promise that
## the gate room pays an Echo would be true exactly once per save.
func flag_id() -> StringName:
	return StringName("atom_echo_stone_%d_%s" % [Run.level, stone_id])


func is_spent() -> bool:
	return _spent


## What is standing on it right now. Public so a director can name the three it
## photographed rather than asserting that "a choice" happened.
func offered() -> Array[StringName]:
	return _offered


# --- The offer ----------------------------------------------------------------

## Put three tones up. Idempotent, and refuses once one has been taken.
##
## Rolled off `Run.rng` rather than a generator of its own, so a replayed seed
## offers the same three stones -- and filtered against what the player is
## already carrying, so a second copy of an on/off rule is never one of them.
func offer() -> void:
	if _spent or not _motes.is_empty():
		return
	_offered = EchoDb.offer(Run.rng, Run.level, Run.echoes_held())
	if _offered.is_empty():
		# Every Echo in the pool is already in the bag. Nothing to offer and
		# nothing has gone wrong -- the stone simply stays dark, which is the
		# honest picture of a player who has taken all twelve.
		return
	for i in _offered.size():
		_raise(_offered[i], i, _offered.size())
	Bus.request_sfx.emit(&"glint_bell", global_position)


func _raise(id: StringName, i: int, total: int) -> void:
	# Spread across the FRONT half only (-60 to +60 of local -Z), not the whole
	# circle: a mote behind the drum is a mote the player has to walk round the
	# prop to read, and the placer already aimed this thing at the way in.
	var span := deg_to_rad(120.0)
	var a := -span * 0.5 + span * (float(i) / float(maxi(total - 1, 1)))
	var at := Vector3(sin(a) * RING_R, MOTE_Y, -cos(a) * RING_R)

	# Parented to the stone rather than to `current_scene`, unlike a dropped
	# mote: this one has a plinth under it and has to travel with it if a
	# placer ever moves one. `LootMote.drop` writes `global_position`, so the
	# node has to be in the tree before the position takes.
	var m := LootMote.new()
	m.item_id = id
	add_child(m)
	m.position = at
	m.taken.connect(_on_taken)
	_motes.append(m)

	var plate := Label3D.new()
	plate.text = EchoDb.name_of(id)
	plate.font_size = 44
	# 0.0022 made "The Returning Shaft" about 1.15 m wide on a ring whose
	# neighbours were 1.05 m apart -- a caption that overlapped its own siblings.
	# 0.0019 on the wider ring is about 0.8 m against 1.30 m of spacing, which is
	# a clear gap AND still readable from where the follow camera actually sits.
	plate.pixel_size = 0.0019
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# **Depth-tested, and that is not what this shipped with.** It carried
	# `no_depth_test = true`, which does not mean "draw over the plinth" -- it
	# means DRAW OVER THE WORLD. The three names on the landing behind a shut
	# shortcut door came out painted on the door in cyan, readable from a room
	# the player had not opened yet, which leaks `docs/PUZZLES.md` §5.1's reward
	# through the wall that is the entire point of a shortcut (card #26).
	#
	# What `no_depth_test` was reaching for is real -- a caption swallowed by its
	# own drum is no caption -- but the fix for that is the GEOMETRY, which is
	# `CLAUDE.md` §3's standing advice for this whole class of bug: change the
	# shape, not the material. `PLATE_DROP` hangs the plate at 0.82 m and the
	# drum's cap tops out at 0.75 m, so the caption already stands clear of the
	# stone it belongs to and depth testing costs it nothing.
	# `tools/directors/echo_plates.gd` measures both halves by subtracting the
	# labels back out of the frame.
	plate.no_depth_test = false
	plate.modulate = Pal.CYAN
	plate.outline_size = 16
	plate.outline_modulate = Pal.VOID
	plate.position = at - Vector3(0.0, PLATE_DROP, 0.0)
	add_child(plate)
	_plates.append(plate)


## One was taken. The other two go quiet -- **not** "are also collectable and the
## player is trusted not to". §6's whole arithmetic is one Echo per site,
## minimum one and maximum two per floor, against a bag of twelve; a stone you
## could sweep would make that four and delete the decision.
func _on_taken(id: StringName) -> void:
	if _spent:
		return
	_spent = true
	Game.set_flag(flag_id())
	Bus.request_sfx.emit(&"level_chime", global_position)
	# The NAME is already on screen -- `Bus.loot_gained` fired inside
	# `Run.collect` and the HUD toasts every pickup by its display name. What is
	# missing is what the tone DOES, so that is what this says. Same channel
	# `LockedDoor` uses for a refusal, and for the same reason: the HUD's one line
	# is where the world talks, and a second toast lane would be a second thing
	# to arbitrate.
	Bus.prompt_changed.emit(EchoDb.line_of(id).to_upper())
	for m in _motes:
		if is_instance_valid(m) and m.item_id != id:
			_quiet(m)
	_motes.clear()
	for p in _plates:
		if is_instance_valid(p):
			var tw := create_tween()
			tw.tween_property(p, ^"modulate:a", 0.0, 0.35)
			tw.tween_callback(p.queue_free)
	_plates.clear()
	if _lamp != null:
		var tw2 := create_tween()
		tw2.tween_property(_lamp, ^"light_energy", 0.55, 0.6)


## A tone that was not chosen. It sinks into the drum rather than popping, which
## is `LootMote._pop`'s opposite on purpose: a pop reads as "you got that", and
## the one thing the player must not think is that they took all three.
func _quiet(m: LootMote) -> void:
	m.monitoring = false
	# And STOP it. `LootMote._process` calls `get_overlapping_bodies()` every
	# frame, which Godot refuses on an Area3D with `monitoring` off -- one error
	# line per mote per frame for the whole 0.45 s sink, which is thirty pages of
	# log for a tone the player declined. Turning the pickup off is two facts, not
	# one: it must not be takeable and it must not be looking.
	m.set_process(false)
	var tw := m.create_tween().set_parallel(true)
	tw.tween_property(m, ^"position:y", m.position.y - 0.7, 0.45) \
		.set_ease(Tween.EASE_IN)
	tw.tween_property(m, ^"scale", Vector3.ONE * 0.05, 0.45)
	tw.chain().tween_callback(m.queue_free)


# --- The drum -----------------------------------------------------------------

func _process(delta: float) -> void:
	_age += delta
	if _lamp == null or _spent:
		return
	# A slow swell rather than a flicker. The stone is holding a note; a torch
	# gutters and this must not read as one.
	_lamp.light_energy = 2.4 + sin(_age * 1.15) * 0.55


func _build() -> void:
	var stone := _mat(Pal.ASH.lerp(Pal.MIDNIGHT, 0.25), 0.95)
	var vein := _glow_mat(Pal.CYAN, 0.9)

	# The drum, as a squat faceted cylinder. Eight sides, like everything else in
	# the kit -- a smooth-shaded plinth reads as an asset from a different game
	# (`LootMote` and `PuzzleAtom._cyl` both say so).
	var body := StaticBody3D.new()
	body.name = "Drum"
	body.collision_layer = K.L_WORLD
	body.collision_mask = 0
	add_child(body)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = DRUM_R
	cyl.height = DRUM_H
	col.shape = cyl
	col.position.y = DRUM_H * 0.5
	body.add_child(col)

	_cyl(body, stone, DRUM_R, DRUM_H, Vector3(0.0, DRUM_H * 0.5, 0.0))
	_cyl(body, stone, DRUM_R * 0.78, 0.14, Vector3(0.0, DRUM_H + 0.06, 0.0))

	# Three veins in the top face, one under each tone, so the arrangement reads
	# as authored even before the motes are up -- and so a SPENT stone still
	# looks like the thing that gave you something.
	for i in 3:
		var a := deg_to_rad(-60.0 + 60.0 * float(i))
		var at := Vector3(sin(a) * RING_R * 0.72, DRUM_H + 0.135,
			-cos(a) * RING_R * 0.72)
		_box(body, vein, Vector3(0.20, 0.02, 0.62), at, Vector3(0.0, -a, 0.0))

	_lamp = OmniLight3D.new()
	_lamp.light_color = Pal.CYAN
	_lamp.light_energy = 2.4
	_lamp.omni_range = 5.2
	_lamp.omni_attenuation = 1.6
	_lamp.shadow_enabled = false
	_lamp.position.y = MOTE_Y
	add_child(_lamp)


# --- Small builders -----------------------------------------------------------
# The same three `PuzzleAtom` grew, and copied here rather than inherited: this
# is a `Node3D` in `scripts/world/`, not an atom, and making it one to borrow
# three helpers would put a pedestal in the kit's `puzzle_atom` group and hand it
# to every gate that went looking.

func _mat(albedo: Color, rough: float = 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


func _glow_mat(hue: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(hue.darkened(0.80), 0.85)
	m.emission_enabled = true
	m.emission = hue
	m.emission_energy_multiplier = energy
	return m


func _box(parent: Node, mat: Material, size: Vector3, at: Vector3,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _cyl(parent: Node, mat: Material, radius: float, height: float,
		at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi
