class_name SunSocket
extends PuzzleAtom
## Atom 8 of 8 (`docs/PUZZLES.md` §2): the sun socket and its beam. **T0 -- your
## shield.**
##
## > *The shield reflect is in phase 1 on purpose. Floor 1's critical path is
## > T0-only, and without it every Cistern puzzle is a key, a plate or a block --
## > haulage.* (§2)
##
## This is the only T0 atom that asks the player to **aim**, and the only one in
## the whole kit that makes the shield a tool rather than a wall. It needs no item
## that does not already exist: a Vyr light-shaft falls through a grate, the
## player stands in it with the guard up, and the bounce goes where they are
## facing.
##
## ## Three things, one prop
##
## The grate that emits, the catch on the floor, and the socket that receives are
## all built here rather than being three placed nodes. A beam whose two ends can
## be positioned independently is a beam a generator will one day aim at a wall,
## and the failure is invisible until somebody stands in the room. Here the
## geometry is one vector -- `beam_from` -- and the socket is always at this
## node's origin, so it cannot be authored wrong.
##
## ## What counts as a reflection
##
## Standing in the catch, guard up, facing the socket. Not a real optical bounce:
## a mirror-angle solve would demand the player understand the incidence angle of
## a light they cannot see the source of, and the verb §1 asked for was *aim*, not
## *optics*. Facing is measured off `-basis.z` like everything else in this
## project (`CLAUDE.md` §4), never derived.

## Where the shaft comes from, in metres from the socket. Up and back by default
## -- a grate in the ceiling behind the player as they face the socket, which is
## the arrangement that reads without a word of explanation.
@export var beam_from: Vector3 = Vector3(0.0, 5.4, -6.6)
## Where the shaft lands, in metres from the socket. Directly under the grate.
@export var catch_offset: Vector3 = Vector3(0.0, 0.0, -5.0)

## How far off the catch you may stand. A shield is wide; a beam you have to hit
## to the centimetre is a beam nobody finds by accident.
const CATCH_R := 1.35
## cos(55 deg). Generous, for the reason in the class note -- this is aim, not
## optics.
const AIM_DOT := 0.57
## Seconds of holding the bounce before it takes. Long enough that a player
## sweeping past with the guard up does not trip it, short enough to feel like a
## reflection rather than a channel.
const HOLD_TIME := 0.40
const SOCKET_R := 0.40
const BEAM_R := 0.075

var _hero: Node3D
var _held: float = 0.0
var _bounce: Node3D
var _bounce_mesh: MeshInstance3D
var _lens_mat: StandardMaterial3D
var _lamp: OmniLight3D
var _shaft_mat: StandardMaterial3D
var _shine: SpotLight3D


func _ready() -> void:
	if atom_id == &"":
		atom_id = PuzzleAtoms.SUN_SOCKET
	_build()
	super()


# --- The bounce ---------------------------------------------------------------

## Where the shaft lands, in world space. **`to_global`, not
## `global_position + catch_offset`** -- the two are the same only while the
## socket is unrotated, and a placer turning it to face into a room is the normal
## case. The version that ignored the rotation put the pool on one side of the
## socket and looked for the player on the other, which is a puzzle that is
## visibly right and cannot be solved.
##
## Public so a placer can keep the walkable floor clear of it, and so a director
## can stand the hero in it without re-deriving the arithmetic.
func catch_point() -> Vector3:
	return to_global(catch_offset)


func _physics_process(delta: float) -> void:
	if is_solved() or not armed:
		return
	if _hero == null or not is_instance_valid(_hero):
		_hero = _find_hero()
		if _hero == null:
			return
	if not _reflecting():
		_held = 0.0
		_show_bounce(false)
		return
	_show_bounce(true)
	_held += delta
	if _held >= HOLD_TIME:
		solve()


## Guard up, standing in the light, pointed at the socket.
##
## `blocking` is read off the hero as a plain property because that is what
## `Hero.set_blocking` writes and `HeroCombat` owns the decision -- there is no
## second source of truth for "is the shield up" and this must not become one.
func _reflecting() -> bool:
	if not bool(_hero.get(&"blocking")):
		return false
	var catch := catch_point()
	var here := _hero.global_position
	here.y = catch.y
	if here.distance_to(catch) > CATCH_R:
		return false
	# `-basis.z` is forward. Measured, never derived from the yaw the hero happens
	# to be storing -- `CLAUDE.md` §4 is three bugs deep on exactly that.
	var face := -_hero.global_transform.basis.z
	face.y = 0.0
	var to_socket := global_position - _hero.global_position
	to_socket.y = 0.0
	if face.length_squared() < 0.0001 or to_socket.length_squared() < 0.0001:
		return false
	return face.normalized().dot(to_socket.normalized()) >= AIM_DOT


## Point `node`'s -Z at `target`, picking an up vector that is not parallel to
## the aim.
##
## `look_at(to, Vector3.UP)` throws on a straight-down aim, and a straight-down
## aim is the DEFAULT arrangement here -- light falls from a grate. The whole
## shaft then fails to orient and the puzzle is invisible, with one error line in
## a log nobody is reading during a screenshot run.
func _aim(node: Node3D, target: Vector3) -> void:
	var dir := target - node.global_position
	if dir.length_squared() < 0.000001:
		return
	var up := Vector3.UP
	if absf(dir.normalized().dot(up)) > 0.98:
		up = Vector3.FORWARD
	node.look_at(target, up)


func _find_hero() -> Node3D:
	var players := get_tree().get_nodes_in_group(&"player")
	return players[0] as Node3D if not players.is_empty() else null


## Draw (or hide) the reflected shaft, hero to socket. `top_level` so the two
## ends are world points -- a beam parented into this node's frame would inherit
## a placer's rotation and point somewhere else entirely.
func _show_bounce(on: bool) -> void:
	_bounce.visible = on
	if not on:
		return
	var from := _hero.global_position + Vector3.UP * 1.0
	var to := global_position + Vector3.UP * 0.9
	var span := to - from
	var len := span.length()
	if len < 0.05:
		return
	_bounce.global_position = from.lerp(to, 0.5)
	_aim(_bounce, to)
	# The mesh is a unit cylinder standing on +Y, tipped a quarter-turn so its
	# length runs down the holder's -Z. Scaling the MESH is safe -- it is the
	# collision shapes this project must never scale, and a beam has none.
	_bounce_mesh.scale.y = len


# --- Lit ----------------------------------------------------------------------

func on_solved() -> void:
	Bus.request_sfx.emit(&"glint_bell", global_position)
	_show_bounce(false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_lens_mat, "emission", Pal.GOLD, 0.3)
	tw.tween_property(_lens_mat, "emission_energy_multiplier", 1.8, 0.3)
	tw.tween_property(_lamp, "light_color", Pal.GOLD, 0.3)
	tw.tween_property(_lamp, "light_energy", 1.5, 0.3)
	# The shaft fades out. It was the puzzle, and a solved puzzle that keeps
	# advertising itself is a room the player cannot tell they have finished.
	tw.tween_property(_shaft_mat, "albedo_color:a", 0.08, 0.5)
	if _shine != null:
		tw.tween_property(_shine, "light_energy", 0.5, 0.5)


func restore_solved() -> void:
	_show_bounce(false)
	_lens_mat.emission = Pal.GOLD
	_lens_mat.emission_energy_multiplier = 1.8
	_lamp.light_color = Pal.GOLD
	_lamp.light_energy = 1.5
	_shaft_mat.albedo_color.a = 0.08
	if _shine != null:
		_shine.light_energy = 0.5


# --- Construction -------------------------------------------------------------

func _build() -> void:
	_build_socket()
	_build_shaft()
	_build_bounce_node()


func _build_socket() -> void:
	var iron := _mat(Color(0.30, 0.29, 0.28), 0.55, 0.7)
	# A post, so the lens sits at chest height and is not something the player has
	# to look down at. The whole read of this puzzle is a line between two points
	# and both of them want to be in frame at the camera's 5-degree pitch.
	_cyl(self, iron, 0.16, 0.9, Vector3(0.0, 0.45, 0.0), 8)
	_cyl(self, iron, 0.34, 0.10, Vector3(0.0, 0.05, 0.0), 10)
	# The dish: eight petals around the lens, angled in. It is what makes the
	# socket read as a thing that RECEIVES rather than a lamp that is switched off.
	for i in 8:
		var a := TAU * float(i) / 8.0
		_box(self, iron, Vector3(0.30, 0.10, 0.16),
			Vector3(cos(a) * SOCKET_R, 0.9, sin(a) * SOCKET_R), Vector3(0.0, -a, 0.25))

	# ARCANE while it is dark, GOLD when it is lit -- and this is the one place in
	# the kit that does not use the COBALT/MOSS pair. GOLD is currency and only
	# currency in the UI (`docs/STYLEGUIDE.md` §2); in the WORLD it is sunlight,
	# which is the entire subject of this prop, and a sun socket that lit up green
	# would be the one prop whose colour argued with its name.
	_lens_mat = _glow_mat(Pal.ARCANE, 0.7)
	_cyl(self, _lens_mat, 0.26, 0.09, Vector3(0.0, 0.92, 0.0), 10)

	_lamp = OmniLight3D.new()
	_lamp.name = "Lamp"
	_lamp.light_color = Pal.ARCANE
	_lamp.light_energy = 0.7
	_lamp.omni_range = 4.6
	_lamp.omni_attenuation = 1.7
	_lamp.shadow_enabled = false
	_lamp.position.y = 1.0
	add_child(_lamp)


## The shaft from the grate to the catch, and the pool it makes on the floor.
func _build_shaft() -> void:
	var span := catch_offset - beam_from
	var len := span.length()
	if len < 0.1:
		return

	# **Not emissive.** The first two renders of this prop were a solid white bar
	# across the frame: an emissive shaft is lit by its own spotlight AND picked up
	# by the environment's glow, and the two stack into pure white long before the
	# multiplier looks high. So the shaft is UNSHADED and half-transparent -- no
	# light touches it, nothing blooms it, and what the player sees is a pale
	# column with the room faintly through it.
	#
	# The narrowness is still doing the work `CLAUDE.md` §3 describes: a fat
	# translucent shaft over near-black stone photographs as a slab whatever the
	# alpha says. Thin is what reads as light.
	_shaft_mat = _shaft_material(0.20)
	var holder := Node3D.new()
	holder.name = "Shaft"
	holder.position = beam_from + span * 0.5
	add_child(holder)
	_aim(holder, to_global(catch_offset))
	var mi := _cyl(holder, _shaft_mat, BEAM_R, len, Vector3.ZERO, 6)
	mi.rotation.x = PI * 0.5

	# The grate. Four bars across the mouth, so the light has somewhere to have
	# come FROM -- a shaft that begins in mid-air reads as an effect.
	var iron := _mat(Color(0.22, 0.22, 0.24), 0.9, 0.3)
	for i in 4:
		_box(self, iron, Vector3(0.9, 0.08, 0.10),
			beam_from + Vector3(0.0, 0.06, -0.3 + float(i) * 0.2))

	# The catch, marked in stone. A RING and not a lit disc: an emissive disc the
	# spotlight was also pointed at came back as a flat white ellipse -- the
	# brightest thing in a frame where it is one of eight props. The light itself
	# is what fills the middle, which is what a shaft of sunlight actually does.
	var inlay := _mat(Color(0.52, 0.50, 0.44), 0.92, 0.0)
	for i in 16:
		var a := TAU * float(i) / 16.0
		_box(self, inlay, Vector3(0.30, 0.03, 0.13),
			catch_offset + Vector3(cos(a) * CATCH_R, 0.016, sin(a) * CATCH_R),
			Vector3(0.0, -a, 0.0))
	var down := SpotLight3D.new()
	_shine = down
	down.name = "Shine"
	down.light_color = Pal.BONE
	down.light_energy = 2.2
	down.spot_range = len + 1.0
	down.spot_angle = 15.0
	down.shadow_enabled = false
	down.position = beam_from
	add_child(down)
	_aim(down, to_global(catch_offset))


## A beam's material: unshaded, alpha-blended, no light and no bloom. Shared by
## the falling shaft and by the reflection, so the two are visibly the SAME light
## and cannot drift apart the day one of them is tuned.
func _shaft_material(alpha: float, hue: Color = Pal.BONE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hue.r, hue.g, hue.b, alpha)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Off, or the shaft sorts against the floor it lands on and flickers as the
	# camera moves. It is a volume, not a surface.
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _build_bounce_node() -> void:
	_bounce = Node3D.new()
	_bounce.name = "Bounce"
	# World-space, for the reason `_show_bounce` records.
	_bounce.top_level = true
	_bounce.visible = false
	add_child(_bounce)
	# Unit height, scaled per frame. `_cyl`'s faceted 6 segments is the same
	# silhouette the shaft has, so the reflection is visibly the SAME light.
	_bounce_mesh = _cyl(_bounce, _shaft_material(0.55, Pal.GOLD), BEAM_R * 0.9, 1.0,
		Vector3.ZERO, 6)
	_bounce_mesh.rotation.x = PI * 0.5
