class_name EyeSwitch
extends PuzzleAtom
## Atom 5 of 8 (`docs/PUZZLES.md` §2): the eye switch. **T1 -- the bow.**
##
## The first atom on the ladder that is not "walk there and touch it". It is the
## reason the Cistern Warden's bow is a *key* and not just a second weapon: §1's
## floor diagonal is that each floor's boss hands you the verb the next floor's
## puzzles are built on, and this is the prop that spends it.
##
## ## Only an arrow
##
## `apply_hit` refuses anything that is not an arrow of some kind. That check is
## the whole tier: an eye a sword could open is a T0 atom wearing a T1 label, and
## `PuzzleAtoms.pool()` would then be handing the generator a rung the player has
## not climbed. A sword swing gets a visible refusal rather than silence -- a
## switch that ignores you is a switch you conclude is broken.
##
## ## The frozen variant -- combinator 8, convert
##
## `frozen` is the SAME CHECK WITH A DIFFERENT CONSTANT (`docs/PUZZLES.md` §8.1,
## which prices combinator 8 at exactly that and no more): an iced eye accepts
## `Hit.ARROW_FIRE` and refuses `Hit.ARROW`, so the answer is a shot routed
## through a lit `Lantern` rather than a shot aimed better. It is a VARIANT and
## not a tenth atom -- same script, same row in `PuzzleAtoms.ATOMS`, same tier,
## one exported bool -- because §8.1's ceiling is that a combinator needing a
## prop of its own has stopped being a combinator.
##
## Note what that does to the ladder: the frozen eye asks a question that LOOKS
## like it wants a verb the player has not earned, and is answerable with the bow
## plus a lantern they walked past. That is §0 rule 1 being relaxed honestly,
## which §3.1 says is the whole reason convert was worth having.
##
## **A plain eye accepts a burning arrow.** It reads `is_arrow` and not
## `kind == ARROW`, deliberately: fire is a strictly longer sentence in the same
## word, and an eye that shut its lid on a lit arrow would be teaching the player
## that the lantern is sometimes a mistake.
##
## It sits on `L_WORLD | L_INTERACT` because that is the pair `Arrow`'s query
## masks (`docs/CONTRACT.md` §8), and it answers on `apply_hit` because that is
## the one damage path. There is no second "shootable" interface in this project
## and this atom is not the place to invent one.

const SOCKET_R := 0.46
const PUPIL_R := 0.17
const LAMP_RANGE := 4.2
## Seconds of the closing-lid blink when something that is not an arrow lands.
const REFUSE_TIME := 0.30

## Shards in the rime crust the frozen variant wears. Enough to break the
## socket's clean circle into a jagged outline and not so many that the pupil
## behind them stops showing -- the player still has to read this as an EYE.
const RIME_SHARDS := 7

## Iced over. **Set BEFORE this enters the tree**, exactly as `Lantern.starts_lit`
## is: `_build()` runs from `_ready` and the crust is geometry, so a placer that
## sets this after `add_child` gets a plain eye that refuses plain arrows for no
## visible reason -- the worst possible version of this prop.
@export var frozen: bool = false

var _pupil: MeshInstance3D
var _pupil_mat: StandardMaterial3D
var _lid_top: Node3D
var _lid_bot: Node3D
var _lamp: OmniLight3D
var _rime: Node3D
var _age: float = 0.0


func _ready() -> void:
	if atom_id == &"":
		atom_id = PuzzleAtoms.EYE_SWITCH
	_build()
	super()


func _process(delta: float) -> void:
	if is_solved() or _pupil_mat == null:
		return
	# A slow breath while it is shut. An unlit stone disc on an unlit stone wall is
	# invisible at the range you have to notice it from; a pulse is what makes the
	# player look, and it costs one sine.
	_age += delta
	_pupil_mat.emission_energy_multiplier = 0.9 + sin(_age * 2.1) * 0.35


## The damage contract's entry point (`docs/CONTRACT.md` §8). Arrows only -- see
## the class note.
##
## A `null` hit is a director or a fixture saying "the right thing landed" and is
## accepted by BOTH variants; every real blow in the game carries a `Hit`.
func apply_hit(hit) -> void:
	if is_solved():
		return
	if hit != null and not _accepts(hit.kind):
		_refuse()
		return
	Bus.request_sfx.emit(&"glint_bell", global_position)
	solve()


## The tier check, and the frozen variant is the same line with a different
## constant -- `docs/PUZZLES.md` §8.1, verbatim.
func _accepts(kind: StringName) -> bool:
	if frozen:
		return kind == Hit.ARROW_FIRE
	# Both, and a burning arrow is not an accident here -- see the class note.
	return kind == Hit.ARROW or kind == Hit.ARROW_FIRE


## What a gate says while this one is unsolved.
##
## **Overridden rather than added to `PuzzleAtoms.ATOMS`, and that is the point.**
## A row for the frozen eye would be a TENTH atom against a kit `PuzzleAtoms
## .validate()` freezes at nine, and §8.1 spends its last paragraph saying a
## combinator must not buy one. §8.1's own bill says "one `refusal` string **on
## the atom**", so it is on the atom.
##
## It names the verb, which is GDD pillar 3's whole demand of a refusal: not
## "THE EYE IS SHUT" -- the player can see that, and they have already put an
## arrow in it -- but the thing the arrow was missing.
func refusal(left: int = 1, total: int = 1) -> String:
	if not frozen:
		return super(left, total)
	if total <= 1 or left <= 1:
		return "THE ICE WANTS A LIT ARROW"
	return "%d OF %d EYES STILL ICED" % [left, total]


## Shut, hard, for a third of a second. The player who swung at it learns the
## eye is real and the sword is wrong, which is the only two facts they need.
func _refuse() -> void:
	Bus.request_sfx.emit(&"craft_fail", global_position)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_lid_top, "position:y", 0.0, REFUSE_TIME * 0.4)
	tw.tween_property(_lid_bot, "position:y", 0.0, REFUSE_TIME * 0.4)
	tw.chain().tween_property(_lid_top, "position:y", SOCKET_R * 0.62, REFUSE_TIME * 0.6)
	tw.parallel().tween_property(_lid_bot, "position:y", -SOCKET_R * 0.62, REFUSE_TIME * 0.6)


# --- Open ---------------------------------------------------------------------

func on_solved() -> void:
	# The ice goes first, and it GOES -- freed, not hidden. A crust left in the
	# tree at zero scale is an invisible thing in front of an open eye, and the
	# next hand to touch this file will make it visible again by accident.
	if _rime != null:
		var melt := create_tween().set_parallel(true)
		melt.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		melt.tween_property(_rime, "scale", Vector3.ONE * 0.01, 0.22)
		melt.chain().tween_callback(_rime.queue_free)
		_rime = null
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lid_top, "position:y", SOCKET_R * 0.95, 0.26)
	tw.tween_property(_lid_bot, "position:y", -SOCKET_R * 0.95, 0.26)
	tw.tween_property(_pupil_mat, "emission", Pal.MOSS, 0.26)
	tw.tween_property(_pupil_mat, "emission_energy_multiplier", 3.2, 0.26)
	tw.tween_property(_lamp, "light_color", Pal.MOSS, 0.26)
	tw.tween_property(_lamp, "light_energy", 2.4, 0.26)


func restore_solved() -> void:
	if _rime != null:
		_rime.queue_free()
		_rime = null
	_lid_top.position.y = SOCKET_R * 0.95
	_lid_bot.position.y = -SOCKET_R * 0.95
	_pupil_mat.emission = Pal.MOSS
	_pupil_mat.emission_energy_multiplier = 3.2
	_lamp.light_color = Pal.MOSS
	_lamp.light_energy = 2.4


# --- Construction -------------------------------------------------------------
# Built facing -Z, which is this project's forward (`CLAUDE.md` §4). A placer
# points the whole node at the room with `rotation.y = heading + PI` and the eye
# looks back down the arrow's line -- there is no art-space offset here to undo,
# because none of this is imported art.

func _build() -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	# Both layers, and both matter: `L_WORLD` is what stops the arrow and
	# `L_INTERACT` is what the arrow's query is looking for. On `L_WORLD` alone the
	# arrow buries itself in the wall an inch from the pupil and nothing happens.
	body.collision_layer = K.L_WORLD | K.L_INTERACT
	body.collision_mask = 0
	add_child(body)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(SOCKET_R * 2.0, SOCKET_R * 2.0, 0.28)
	cs.shape = bx
	cs.position.z = -0.06
	body.add_child(cs)

	var stone := _mat(Color(0.31, 0.30, 0.33), 0.96, 0.0)
	var lidmat := _mat(Color(0.24, 0.23, 0.26), 0.94, 0.0)

	# The socket: a ring of eight wedges around the lids, so the eye reads as set
	# INTO the wall rather than stuck onto it.
	for i in 8:
		var a := TAU * float(i) / 8.0
		_box(self, stone, Vector3(0.30, 0.16, 0.22),
			Vector3(cos(a) * SOCKET_R, sin(a) * SOCKET_R, -0.02),
			Vector3(0.0, 0.0, a + PI * 0.5))

	# The pupil. Emission only -- `PuzzleAtom._glow_mat`'s note: a coloured albedo
	# under the socket's own lamp clips to white and photographs as a smear.
	_pupil_mat = _glow_mat(Pal.FROST if frozen else Pal.COBALT, 0.9)
	_pupil = _box(self, _pupil_mat, Vector3(PUPIL_R * 2.0, PUPIL_R * 2.0, 0.06),
		Vector3(0.0, 0.0, -0.14))
	# A darker iris ring, so the lit part is a pupil and not a glowing tile.
	_box(self, _mat(Color(0.16, 0.15, 0.19), 0.9, 0.0),
		Vector3(PUPIL_R * 2.9, PUPIL_R * 2.9, 0.05), Vector3(0.0, 0.0, -0.115))

	# Two lids, meeting at the centre when shut. Separate nodes because the OPEN
	# pose is the two of them apart, and one lid sliding sideways reads as a
	# shutter rather than as an eye.
	_lid_top = Node3D.new()
	_lid_top.name = "LidTop"
	add_child(_lid_top)
	_box(_lid_top, lidmat, Vector3(SOCKET_R * 1.7, SOCKET_R * 0.98, 0.10),
		Vector3(0.0, SOCKET_R * 0.49, -0.18))
	_lid_bot = Node3D.new()
	_lid_bot.name = "LidBot"
	add_child(_lid_bot)
	_box(_lid_bot, lidmat, Vector3(SOCKET_R * 1.7, SOCKET_R * 0.98, 0.10),
		Vector3(0.0, -SOCKET_R * 0.49, -0.18))
	# Shut, but not sealed: a hairline of pupil shows, which is what makes a player
	# 8 m away read "closed eye" instead of "blank stone".
	_lid_top.position.y = SOCKET_R * 0.62
	_lid_bot.position.y = -SOCKET_R * 0.62

	_lamp = OmniLight3D.new()
	_lamp.name = "Lamp"
	_lamp.light_color = Pal.FROST if frozen else Pal.COBALT
	_lamp.light_energy = 0.7
	_lamp.omni_range = LAMP_RANGE
	_lamp.omni_attenuation = 1.6
	_lamp.shadow_enabled = false
	_lamp.position.z = -0.5
	add_child(_lamp)

	if frozen:
		_build_rime()


## The crust, and it is a SILHOUETTE change and not a tint.
##
## A frozen eye that differed from a plain one only in hue would be unreadable at
## the range this puzzle is shot from -- and CLAUDE.md §3 records the specific
## way that fails here, which is that emissive over near-black photographs as an
## opaque slab whatever the colour. So the ice is seven shards standing PROUD of
## the socket at broken angles: the plain eye is a clean disc, the frozen one has
## a jagged outline you can pick out of a still frame across the room.
##
## FROST (`Pal.FROST`) rather than COBALT, and it is the palette's existing ice:
## `docs/STYLEGUIDE.md` §2 already spends it on a body the hookshot has frozen,
## which is the same fact about the same world.
func _build_rime() -> void:
	_rime = Node3D.new()
	_rime.name = "Rime"
	add_child(_rime)
	# Glassy rather than matte -- the one thing in the atom kit allowed a
	# highlight besides iron, because a specular that MOVES is most of what makes
	# a surface read as ice instead of as blue stone.
	var ice := _mat(Pal.FROST.darkened(0.45), 0.22, 0.0)
	ice.emission_enabled = true
	ice.emission = Pal.FROST
	# Low. The crust has to sit in FRONT of a breathing pupil without drowning
	# it, and the shard shapes are doing the work the brightness would otherwise
	# have to.
	ice.emission_energy_multiplier = 0.55
	for i in RIME_SHARDS:
		# Deliberately not TAU/RIME_SHARDS: an even ring reads as a manufactured
		# collar. Seven shards on a golden-ratio walk around the socket land
		# unevenly and never repeat.
		var a := TAU * float(i) * 0.618034
		var r := SOCKET_R * (0.34 + fmod(float(i) * 0.37, 0.52))
		var long := 0.20 + fmod(float(i) * 0.29, 0.26)
		_box(_rime, ice, Vector3(0.10, long, 0.13),
			Vector3(cos(a) * r, sin(a) * r, -0.24),
			Vector3(0.0, 0.0, a + fmod(float(i) * 0.9, 1.1)))
