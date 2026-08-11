class_name Lantern
extends PuzzleAtom
## Atom 9 (`docs/PUZZLES.md` §2): the lantern. T0 -- any blow trips it.
##
## A brass cage on a post with a Vyr flame in it. Struck, it **toggles**: lit goes
## dark, dark goes lit. That is the whole prop.
##
## ## The second atom in the kit that goes backwards, and the first that is asked to
##
## `PressurePlate` is non-latching because physics made it so -- you step off and
## it rises, and nobody chose that. The lantern is non-latching **because the
## puzzle is about turning things off again**. It writes no world flag for the
## same reason a plate does not: a one-way flag on a two-way prop is a lantern
## that comes back lit with nothing having lit it.
##
## ## It does not decide its own state
##
## `press()` emits `pressed` and **does not toggle**. `LanternGrid` listens, and
## the grid is what flips this lantern *and its orthogonal neighbours*
## (`docs/PUZZLES.md` §3, combinator 6 -- **couple**). A lantern that toggled
## itself and then told the grid would be the coupling implemented twice, and the
## bug would be a centre cell that flipped once for its own press and once for
## the grid's -- a puzzle that visibly does not obey its own rule.
##
## A lantern with **no listener** on `pressed` toggles itself instead -- otherwise
## it would be an atom the prefab generator can draw from the T0 pool and no blow
## could ever solve. See `press()`: the two paths are exclusive, so the coupling is
## still written once.
##
## ## Why any blow and not the sword specifically
##
## `apply_hit` takes an arrow just as happily. Floor 1's critical path is T0
## (§1), so it has to answer the sword -- but a lantern that ONLY answered the
## sword would be a lantern the bow cannot reach on floor 2, and the interesting
## version of a lights-out grid is the one across a gap. Refusing the arrow would
## be inventing a restriction the verb ladder does not ask for. `EyeSwitch` is the
## atom that discriminates, and it does so because the bow is its whole point.

## Seconds after a press before this lantern will take another. **One swing is
## one press.** A sword arc reports `apply_hit` on more than one frame while it
## sweeps, and on a latching atom that is harmless -- `solve()` is idempotent. On
## a toggle it is a lantern that flips twice and looks like it ignored you.
const REARM := 0.30

## Radians/sec of the hint's swell (`set_hint`). A hair over three is a
## two-second breath -- the slowest movement in the room, which is what makes it
## read as deliberate. Faster and it is a lantern with a fault in it.
const HINT_RATE := 3.1
## How far the brass swells at the top of that breath, over whichever pose is
## underneath -- **and the two poses need different numbers.** A dark post's cage
## sits at 0.06, so nine tenths is the difference between unlit iron and glowing
## brass and any more of it starts reading as a lit lantern, which is the one
## fact the puzzle is actually made of. A LIT post's cage already sits at 0.55
## and lives next to eight others at 0.55: the same nine tenths there is a shade,
## visible in a crop and invisible across the room. Measured on
## `l_05_hint_on.png` -- the first pass shipped one constant and the lit case was
## the one that needed the bigger one.
const HINT_SWELL := 0.9
const HINT_SWELL_LIT := 2.4

const POST_H := 1.55
const POST_R := 0.09
const CAGE_R := 0.30
const CAGE_H := 0.52
const FLAME_R := 0.16

var _flame: MeshInstance3D
var _lamp: OmniLight3D
var _glow: StandardMaterial3D
var _cage: StandardMaterial3D
var _cool: float = 0.0
var _age: float = 0.0
var _hinted: bool = false
## Seconds since the hint came on. Its OWN clock, not `_age`: the swell has to
## start at the bottom so the first thing the eye catches is a rise, and sharing
## the flame's clock would start it at whatever phase the room happened to be at.
var _hint_t: float = 0.0

## Lit when the room is built. **Set by `LanternGrid` before this enters the
## tree**, so the scramble is already on the posts the first time anybody looks --
## see `_ready`.
@export var starts_lit: bool = false

## One press. The GRID decides what that means; see the class note.
signal pressed(lantern: Lantern)


func _ready() -> void:
	if atom_id == &"":
		atom_id = PuzzleAtoms.LANTERN
	_build()
	# **Before `super()`, and deliberately not through `solve()`.** `PuzzleAtom`
	# defers `_offer`, the gate adopts on the next frame and reads `is_solved()`
	# then -- so the scrambled state has to be true by the time that read happens
	# or the gate counts a grid that has not been dealt yet. Going through
	# `solve()` instead would emit `solved` per lit lantern during construction,
	# and a grid dealt all-lit for one frame is a gate that opens on the frame it
	# was built. `_solved` is inherited, not private to the base.
	_solved = starts_lit
	super()
	_pose(starts_lit)


# --- The blow -----------------------------------------------------------------

func apply_hit(_hit) -> void:
	press()


## Trip it. Public and named for the VERB rather than for the outcome, because
## the outcome is not this node's to decide -- a coupled lantern that was lit may
## well still be lit afterwards, if a neighbour's flip landed on it in the same
## press.
func press() -> void:
	if not armed or _cool > 0.0:
		return
	_cool = REARM
	Bus.request_sfx.emit(&"craft_clang", global_position)
	# **Nobody listening means nobody else's job.** A lone lantern -- one the prefab
	# generator drew out of the T0 pool with no grid over it -- has to answer its own
	# verb, or it is an atom the kit can place and no blow can ever solve. With a
	# grid connected this branch is dead and the grid does all the flipping,
	# including this cell's, so the coupling is still implemented exactly once.
	if pressed.get_connections().is_empty():
		set_lit(not is_solved())
	pressed.emit(self)


## Lit, or not. `LanternGrid`'s only writer -- it is `solve`/`unsolve` underneath,
## so `PuzzleGate` counts these exactly as it counts a pressure plate and needs no
## idea that a grid exists.
func set_lit(on: bool) -> void:
	if on == is_solved():
		return
	if on:
		solve()
	else:
		unsolve()


## Breathe, because the grid is pointing at this one -- `LanternGrid.HINT_AFTER`.
##
## **The cage breathes, not the flame's colour.** A dark lantern nudged toward
## gold is a lantern that reads as half-lit, and the one fact this puzzle is made
## of is which posts are lit. So the hue never moves: only the brass swells, on a
## cycle slow enough to be a signal rather than a fault.
func set_hint(on: bool) -> void:
	if on == _hinted:
		return
	_hinted = on
	_hint_t = 0.0
	if not on:
		_pose(is_solved())


func on_solved() -> void:
	_pose(true)
	Bus.request_sfx.emit(&"glint_bell", global_position)


func on_unsolved() -> void:
	_pose(false)


## The same two poses with no sound, for construction and for a floor rebuilt
## mid-run. `PuzzleAtom.restore_solved` is the latching version of this split.
func _pose(lit: bool) -> void:
	if _flame == null:
		return
	var hue := Pal.GOLD if lit else Pal.MIDNIGHT
	_flame.visible = true
	_glow.emission = hue
	# Not zero when dark. A cage with nothing in it reads as scenery and the
	# player stops counting it; a cold blue coal reads as a lantern that is OFF,
	# which is the fact the puzzle is made of. The same argument `PressurePlate`
	# makes for COBALT-cold rather than unlit.
	_glow.emission_energy_multiplier = 2.6 if lit else 0.30
	_glow.albedo_color = hue.darkened(0.82)
	if _cage != null:
		_cage.emission_energy_multiplier = 0.55 if lit else 0.06
	if _lamp != null:
		_lamp.light_color = hue
		_lamp.light_energy = 2.9 if lit else 0.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flame.scale = Vector3.ONE * (1.0 if lit else 0.55)
	tw.tween_property(_flame, ^"scale",
		Vector3.ONE * (1.0 if lit else 0.55), 0.18).from(Vector3.ONE * 1.35)


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	if _lamp == null:
		return
	_age += delta
	if _hinted and _cage != null:
		_hint_t += delta
		# 0..1, starting at 0 -- a cosine, not a sine, so the breath begins at the
		# bottom and the first thing that happens is a rise. Rides on top of
		# whichever pose is underneath, so a hinted post that is already lit swells
		# its brass without touching its flame.
		var swell := 0.5 - cos(_hint_t * HINT_RATE) * 0.5
		var lit := is_solved()
		_cage.emission_energy_multiplier = (
			(0.55 if lit else 0.06) + swell * (HINT_SWELL_LIT if lit else HINT_SWELL))
	if not is_solved():
		return
	# A guttering flame, unlike `SoundingStone`'s slow swell -- this one IS a
	# torch, and it is the one prop in the kit that is allowed to flicker.
	_lamp.light_energy = 2.9 + sin(_age * 6.3) * 0.28 + sin(_age * 2.1) * 0.16


# --- Construction -------------------------------------------------------------

func _build() -> void:
	# One body, on the world layer AND the interact layer, so the sword's sweep
	# finds it the way it finds an urn. It is also a real obstacle: a grid of
	# lanterns you can walk through is a grid with no shape, and the walk between
	# two posts is part of reading it.
	#
	# **`L_INTERACT` is not optional and its absence shipped.** `HeroCombat`'s
	# blade masks `L_ENEMY | L_INTERACT` and nothing else, so a post on `L_WORLD`
	# alone is a post the sword cannot see -- and this file carried the comment
	# above, claiming parity with the urn, while `Urn` had both bits and this had
	# one. Every lantern in the game was scenery: the lights-out grid could not be
	# pressed and the maze room's chest stood walled off behind gates nothing
	# could open.
	#
	# It was invisible to every proof because every proof calls `apply_hit`
	# directly (`lights_out.gd`, `maze.gd`, `puzzle_atoms.gd`) -- the right call
	# for checking a board's arithmetic and the wrong one for checking that a
	# blade can reach it. `tools/directors/sword_contact.gd` swings the button.
	var body := StaticBody3D.new()
	body.name = "Post"
	body.collision_layer = K.L_WORLD | K.L_INTERACT
	body.collision_mask = 0
	add_child(body)

	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = CAGE_R
	cyl.height = POST_H + CAGE_H
	cs.shape = cyl
	cs.position.y = (POST_H + CAGE_H) * 0.5
	body.add_child(cs)

	var iron := _mat(Color(0.22, 0.20, 0.19), 0.55, 0.85)
	_cyl(body, iron, POST_R, POST_H, Vector3(0.0, POST_H * 0.5, 0.0), 6)
	# A foot, so the post does not read as a pipe pushed into the floor.
	_cyl(body, iron, POST_R * 2.4, 0.09, Vector3(0.0, 0.045, 0.0), 6)

	# The cage: four uprights and two hoops. Brass that catches its own flame --
	# emissive rather than metallic-reflective, because `LockedDoor` learned twice
	# that a tinted albedo under a nearby lamp clips to white.
	_cage = _glow_mat(Pal.RUST, 0.55)
	var y0 := POST_H
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		_box(body, _cage, Vector3(0.045, CAGE_H, 0.045),
			Vector3(cos(a) * CAGE_R, y0 + CAGE_H * 0.5, sin(a) * CAGE_R))
	for y: float in [y0 + 0.02, y0 + CAGE_H - 0.02]:
		for i in 8:
			var a := TAU * float(i) / 8.0
			_box(body, _cage, Vector3(0.24, 0.04, 0.05),
				Vector3(cos(a) * CAGE_R, y, sin(a) * CAGE_R), Vector3(0.0, -a, 0.0))
	# A cap, so the cage is a lantern and not a bird feeder.
	_cyl(body, iron, CAGE_R * 1.15, 0.06, Vector3(0.0, y0 + CAGE_H + 0.03, 0.0), 8)

	_glow = _glow_mat(Pal.GOLD, 2.6)
	var flame := SphereMesh.new()
	flame.radius = FLAME_R
	flame.height = FLAME_R * 2.4
	flame.radial_segments = 8
	flame.rings = 4
	_flame = MeshInstance3D.new()
	_flame.name = "Flame"
	_flame.mesh = flame
	_flame.material_override = _glow
	_flame.position.y = y0 + CAGE_H * 0.5
	body.add_child(_flame)

	_lamp = OmniLight3D.new()
	_lamp.name = "Lamp"
	_lamp.light_color = Pal.GOLD
	_lamp.light_energy = 0.0
	_lamp.omni_range = 6.4
	_lamp.omni_attenuation = 1.5
	_lamp.shadow_enabled = false
	_lamp.position.y = y0 + CAGE_H * 0.5
	add_child(_lamp)
