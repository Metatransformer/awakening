class_name HookRing
extends PuzzleAtom
## Atom 7 of 8 (`docs/PUZZLES.md` §2): the hook ring. **T3 -- the hookshot.**
##
## The top of §1's ladder, and the only atom that is solved by a *traversal* verb
## rather than by a blow or by weight. That is the point of it: the hookshot's
## puzzle is aiming at the right anchor across a gap, and the ring is the anchor
## saying "this one".
##
## ## Why it has a `HookTarget` instead of being one
##
## `HookTarget` is the firer's contract (group `&"hookable"`, `anchor_point()`,
## `pull_point()`) and `PuzzleAtom` is the gate's. GDScript has one base class, so
## the ring OWNS a `HookTarget` child and listens to its `bitten` signal.
##
## That is also the honest shape: this atom is a `HookTarget` that happens to
## count, and every other ring in the game is one that does not. Nothing in
## `HeroRanged` knows the difference, which is exactly the amount it should know.
##
## ## Bitten, not reached
##
## It solves the instant the hook CATCHES, not when the hero arrives. A ring that
## waited for the landing would be a ring you can fail to solve by being
## interrupted mid-zip -- and the verb the player performed was the aim.

const RING_R := 0.34
const BRACKET_L := 0.55
const LAMP_RANGE := 4.6

var _target: HookTarget
var _ring_mat: StandardMaterial3D
var _lamp: OmniLight3D
var _age: float = 0.0


func _ready() -> void:
	if atom_id == &"":
		atom_id = PuzzleAtoms.HOOK_RING
	_build()
	super()


func _process(delta: float) -> void:
	if is_solved() or _ring_mat == null:
		return
	# The same slow breath the eye has. Rings in this game are usually decoration
	# on a ledge; a PUZZLE ring has to be the one the player picks out of a wall of
	# them, and a pulse is the cheapest way to say so.
	_age += delta
	_ring_mat.emission_energy_multiplier = 0.8 + sin(_age * 2.1) * 0.30


func _on_bitten(_by: Node3D) -> void:
	if is_solved():
		return
	Bus.request_sfx.emit(&"glint_hi", global_position)
	solve()


## The anchor the firer aims at. Public so a director can prove the seating
## without owning a hookshot -- and so a placer can hang a second ring off the
## same point.
func target() -> HookTarget:
	return _target


# --- Caught -------------------------------------------------------------------

func on_solved() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_ring_mat, "emission", Pal.MOSS, 0.24)
	tw.tween_property(_ring_mat, "emission_energy_multiplier", 3.0, 0.24)
	tw.tween_property(_lamp, "light_color", Pal.MOSS, 0.24)
	tw.tween_property(_lamp, "light_energy", 2.2, 0.24)


func restore_solved() -> void:
	_ring_mat.emission = Pal.MOSS
	_ring_mat.emission_energy_multiplier = 3.0
	_lamp.light_color = Pal.MOSS
	_lamp.light_energy = 2.2


# --- Construction -------------------------------------------------------------
# Built facing local +Z, which is `HookTarget`'s own convention (its class note):
# origin is the anchor, +Y is up, +Z is out from the face it is mounted on. That
# is NOT this project's forward -- `-basis.z` is (`CLAUDE.md` §4) -- and the
# difference is deliberate and belongs to the firer, not to us. A placer points
# the ring's +Z into the room.

func _build() -> void:
	# CYAN is the hookshot's line and the way out, and nothing else
	# (`docs/STYLEGUIDE.md` §2). A hookshot anchor is one of exactly two things in
	# the game entitled to it, and using anything else here would make the one
	# colour the player has been taught to read stop meaning what it means.
	_ring_mat = _glow_mat(Pal.CYAN, 0.8)

	var iron := _mat(Color(0.38, 0.37, 0.35), 0.45, 0.8)
	# The bracket: a stub off the wall, so the ring stands proud of the face and
	# the chain has somewhere to land that is not stone.
	_box(self, iron, Vector3(0.16, 0.16, BRACKET_L), Vector3(0.0, 0.0, BRACKET_L * 0.5))
	_box(self, iron, Vector3(0.34, 0.34, 0.07), Vector3(0.0, 0.0, 0.03))

	# The ring itself: twelve segments around the bracket's end. A `TorusMesh`
	# would do it in one node, and does in `HookTarget._build_ring` -- but that one
	# cannot be tinted per-instance without a second material, and this ring's
	# whole job is to CHANGE colour when it is caught.
	var z := BRACKET_L
	for i in 12:
		var a := TAU * float(i) / 12.0
		_box(self, _ring_mat, Vector3(0.20, 0.085, 0.085),
			Vector3(cos(a) * RING_R, sin(a) * RING_R, z), Vector3(0.0, 0.0, a + PI * 0.5))

	_lamp = OmniLight3D.new()
	_lamp.name = "Lamp"
	_lamp.light_color = Pal.CYAN
	_lamp.light_energy = 0.9
	_lamp.omni_range = LAMP_RANGE
	_lamp.omni_attenuation = 1.6
	_lamp.shadow_enabled = false
	_lamp.position.z = z + 0.3
	add_child(_lamp)

	_target = HookTarget.new()
	_target.name = "Anchor"
	# Its own art off: the ring above IS the art, and a second torus at the same
	# point would z-fight with it.
	_target.show_ring = false
	# Wider than the default 1.5 m. A ring the player must SOLVE is one they are
	# usually aiming at across a gap, and demanding the same precision as a ring
	# they are merely travelling by makes the puzzle about the stick.
	_target.snap_radius = 2.2
	_target.position.z = z
	add_child(_target)
	_target.bitten.connect(_on_bitten)
