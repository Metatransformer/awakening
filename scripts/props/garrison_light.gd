class_name GarrisonLight
extends Node3D
## One of the twelve dark things in the courtyard, and the whole of "the
## garrison changes".
##
## `docs/GDD.md` §6.2 budgets this at **a prop and a light**, and the budget is
## the design: the reward remains instantly readable through flare and light
## contrast, while the prop now belongs to the garrison's crafted lantern
## language. Its entire state is one bool read out of `RelicDb`.
##
## ## Why the moment is deferred, and why that is not a hack
##
## A donation happens with a `TradeScreen` up, and that screen draws the world
## behind a 0.86-alpha wash of `Pal.VOID`. A lamp that came on the instant
## `RelicDb.buy()` set the flag would therefore light up **underneath a curtain**
## -- the player would close the counter and find a garrison that was quietly
## already different, which is precisely the Moonlighter failure §3 is built to
## avoid ("did the garrison changing register, or did you have to be told?").
##
## So the flag going up ARMS the lamp and the screen closing FIRES it. The
## discrimination is `Prompt.blocked`, which is true exactly while a full-screen
## UI holds input -- not a timer, because a timer would either fire under the
## curtain on a slow reader or leave the lamp dark on a fast one.
##
## `_ready` is the other path and it is deliberately instant: a garrison rebuilt
## after a run must come up with its lamps already on, with no twelve-way flare
## on every arrival.

## Which of `RelicDb.props()` this is. Set by `Garrison`; a light with no prop
## id reads `prop_lit(&"")`, which is false forever, so a mis-wired one is dark
## rather than lit-by-accident.
@export var prop: StringName = &""

const LANTERN_WALL: PackedScene = preload("res://assets/props/booth/Lantern_Wall.gltf")

# --- The two states ----------------------------------------------------------
# Both are the garrison's existing warm-gold vocabulary (every lamp in `Npc` is
# `Pal.GOLD`), so a lit relic prop reads as the same garrison with more of it
# awake rather than as a new kind of object. Nothing here is a colour choice; it
# is the difference between "off" and "on" being large enough to see from across
# the yard, which is the only requirement (GDD §6.2).

const DARK_ALBEDO := Color(0.13, 0.12, 0.15)
## The compact unshaded core makes the state readable inside an authored fixture;
## the flare and omni carry the reward across the yard without a giant signal cube.
## Shape and scale, never a shader. [tune]
const POST_H := 1.48
const HEAD := 0.22
const LIT_EMISSION := 3.4
const LIT_ENERGY := 6.5
const LIT_RANGE := 5.2
## Seconds the lamp takes to come up, and how far past its resting brightness it
## overshoots on the way. The overshoot is the part that makes it an EVENT and
## not a state change you notice later. [tune]
const FLARE_TIME := 1.25
const FLARE_PEAK := 1.9

var _head: MeshInstance3D
var _mat: StandardMaterial3D
var _light: OmniLight3D
var _lit: bool = false
## Set when the donation lands while a screen is up; spent when it closes.
var _armed: bool = false
## Seconds into the flare, or -1 when there is no flare running.
var _flare: float = -1.0


func _ready() -> void:
	_build()
	_lit = RelicDb.prop_lit(prop)
	_apply(1.0 if _lit else 0.0)
	# Twelve of these in a yard that is mostly static: only the one that is
	# actually coming on pays for a `_process`.
	set_process(false)
	Bus.item_acquired.connect(_on_acquired)
	Bus.screen_closed.connect(_on_screen_closed)


## A donation is the only thing that can change the answer, and `item_acquired`
## is the cue `RelicDb.buy` emits. The id is ignored on purpose -- what was
## acquired is the unlock, and this prop asks `RelicDb` about ITSELF rather than
## trusting a signal payload to name it.
func _on_acquired(_id: StringName) -> void:
	if _lit or not RelicDb.prop_lit(prop):
		return
	if Prompt.blocked:
		_armed = true
		return
	_ignite()


func _on_screen_closed(_what: StringName) -> void:
	if not _armed:
		return
	_armed = false
	_ignite()


## Light it while somebody is looking.
func _ignite() -> void:
	_lit = true
	_flare = 0.0
	set_process(true)


func _process(delta: float) -> void:
	_flare += delta
	var t: float = clampf(_flare / FLARE_TIME, 0.0, 1.0)
	# Rises past full and settles back. `sin(t * PI)` is zero at both ends, so
	# the curve is "on, too bright, on" without a second tween or a `Tween` whose
	# lifetime would have to be managed against a scene change.
	_apply(t + sin(t * PI) * FLARE_PEAK)
	if t >= 1.0:
		_flare = -1.0
		set_process(false)


## `k` is 0 for dark, 1 for resting-lit, and above 1 during the flare.
func _apply(k: float) -> void:
	var on: bool = k > 0.0
	_mat.emission_enabled = on
	_mat.albedo_color = Pal.GOLD if on else DARK_ALBEDO
	_mat.emission_energy_multiplier = LIT_EMISSION * k
	_light.visible = on
	_light.light_energy = LIT_ENERGY * k


## Force the lamp to agree with `RelicDb` right now, with no flare.
##
## For the one caller that changes the flag without going through the counter --
## a director proving the dark frame and the lit frame from the same camera, or
## a save loaded under a garrison that is already built.
func sync() -> void:
	_armed = false
	_flare = -1.0
	set_process(false)
	_lit = RelicDb.prop_lit(prop)
	_apply(1.0 if _lit else 0.0)


func lit() -> bool:
	return _lit


# --- Construction ------------------------------------------------------------

func _build() -> void:
	# The short iron post and imported fixture share the garrison's crafted lantern
	# language; flare and light contrast keep the reward instantly readable.
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.16, 0.15, 0.17)
	iron.roughness = 0.9
	iron.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.055
	pm.bottom_radius = 0.08
	pm.height = POST_H
	pm.radial_segments = 6
	post.mesh = pm
	post.material_override = iron
	post.position.y = POST_H * 0.5
	add_child(post)

	var fixture := LANTERN_WALL.instantiate() as Node3D
	fixture.name = &"LanternFixture"
	fixture.scale = Vector3.ONE * 0.30
	fixture.position = Vector3(0.0, 1.38, 0.02)
	add_child(fixture)

	_mat = StandardMaterial3D.new()
	_mat.emission = Pal.GOLD
	_mat.roughness = 0.7
	_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# UNSHADED keeps the small core's off/on contrast legible inside the fixture.
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_head = MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = HEAD * 0.5
	hm.height = HEAD
	_head.mesh = hm
	_head.material_override = _mat
	_head.position = Vector3(0.0, 1.47, 0.08)
	add_child(_head)

	_light = OmniLight3D.new()
	_light.light_color = Pal.GOLD
	_light.omni_range = LIT_RANGE
	_light.omni_attenuation = 1.0
	# Twelve shadow-casting omnis in one small yard is the whole shadow budget
	# spent on dressing. The prop's job is to be SEEN, not to cast.
	_light.shadow_enabled = false
	_light.position = _head.position
	add_child(_light)
