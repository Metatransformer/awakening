class_name BarredPassage
extends Interactable
## The chord edge's one-way gate. **`docs/PUZZLES.md` §4: "connect them, and
## block the connection from the near side only."**
##
## > *The far side is a cracked pillar, a bolted bar, a ledge you can hookshot
## > back across.*
##
## This is the bolted bar, and it is the version the game can build on floor 1 --
## the cracked pillar needs burst (M5) and the ledge needs the hookshot (M7). It
## costs no verb at all, which is the point: the chord is the GATE ROOM's reward,
## and a loop that also demanded a second item would be a reward you cannot
## collect with what the puzzle just gave you.
##
## ## Why one-way is a dot product and not a second prop
##
## The bars are a single object standing in the near room's doorway. Which side
## the player is on is `dot(player - self, out)`, measured every time they press
## the button, where `out` is this node's own -Z -- the direction the corridor
## runs. Facing is measured, never derived (`CLAUDE.md` §4), and this is that rule
## applied to a threshold rather than to a body.
##
## The alternative -- two props, or a trigger volume on each side -- would be two
## things that can disagree about where the player is standing, and the failure is
## invisible: a chord you can open from the wrong side is a floor with a free
## shortcut in it, and nothing about the frame looks wrong.
##
## ## What it says from the wrong side
##
## "BARRED FROM THE OTHER SIDE", not "LOCKED". `LockedDoor`'s own note is that a
## refusal has to tell the player what the door is FOR; this one tells them the
## thing they need to know and cannot see -- that there is a far side, that it is
## reachable, and that the bars are not a wall.

## Fired when the bars go up. `where` is `tag`, verbatim -- the same opaque
## contract `LockedDoor.opened` has, for the same reason.
signal lifted(where: StringName)

## The flag this writes, and the thing the placer names it by. Prefixed `atom_`
## by `flag_id()` below so `PuzzleAtom.clear_run_flags()` wipes it on
## `Run.enter()`: the cycle is the gate room's reward THIS RUN (§5.2), and a
## permanent flag would mean run two walks into a floor with its loop already
## open and its gate room reduced to a corridor.
@export var tag: StringName = &"chord"
## The opening the bars fill. Matches `KitDoorway`'s, which is what a generated
## floor punches -- bars narrower than the hole are a hole.
@export var opening_w: float = K.DOOR_W
@export var opening_h: float = K.DOOR_H

## How many uprights. Odd, so one sits on the centre line and the pattern reads as
## authored ironwork rather than as a fence.
const BARS := 7
const BAR_R := 0.055
const RAIL_T := 0.13
## How far the whole grille rises into the lintel. Past the opening, so the last
## frame is a clear hole and not a row of stubs hanging in it.
const LIFT := 3.05
const LIFT_TIME := 1.05
## Metres of slack on the side test. Zero would make the exact plane of the
## doorway a coin flip; 0.35 puts the boundary inside the masonry, where the
## player cannot stand.
const SIDE_EPS := 0.35

var _open: bool = false
var _grille: Node3D
var _blocker: StaticBody3D
var _lamp: OmniLight3D
var _tween: Tween


func _ready() -> void:
	# The same 2.9 `LockedDoor` measured: the bars are solid, so the nearest the
	# hero can physically stand is about 0.6 m, and a radius that only just
	# reaches there finds nothing when he walks up at an angle.
	radius = 2.9
	prompt = "LIFT THE BARS"
	super()
	_build()
	if Game.flag(flag_id()):
		_pose_open()


## Per RUN. See `tag`.
func flag_id() -> StringName:
	return StringName("atom_bars_%s" % tag)


func is_open() -> bool:
	return _open


# --- Which side ---------------------------------------------------------------

## The way OUT of the near room: this node's own forward, which the placer aimed
## down the corridor. `-basis.z is forward` (docs/CONTRACT.md §2.5).
func out_dir() -> Vector3:
	return -global_transform.basis.z


## Is `who` standing on the far side? Public because a director has to be able to
## assert the refusal from the near side and the lift from the far side as two
## separate facts -- a one-way gate that is really two-way passes every test that
## only ever walks up to it from behind.
func on_far_side(who: Node3D) -> bool:
	if who == null:
		return false
	var to := who.global_position - global_position
	to.y = 0.0
	return to.dot(out_dir()) > SIDE_EPS


# --- The lift -----------------------------------------------------------------

func activate(by: Node3D) -> void:
	if _open:
		return
	if not on_far_side(by):
		_refuse()
		return
	activated.emit(by)
	lift()


func on_focus(on: bool) -> void:
	# `Prompt` formats a focused prop as "<KEY> TO <prompt>", which is right for a
	# verb and nonsense for a statement -- "E TO BARRED FROM THE OTHER SIDE". So
	# the line is re-emitted here, deferred past `Prompt`'s own emit in the same
	# tick. `LockedDoor.on_focus` carries the full reasoning.
	if on and not _open:
		_say_side.call_deferred()


func _say_side() -> void:
	if Prompt.focus != self or _open:
		return
	var hero := get_tree().get_first_node_in_group(&"player") as Node3D
	if on_far_side(hero):
		return
	Bus.prompt_changed.emit("BARRED FROM THE OTHER SIDE")


func _refuse() -> void:
	Bus.request_sfx.emit(&"door_refused", global_position)
	_say_side()
	if _tween != null and _tween.is_valid() or _grille == null:
		return
	# A rattle, not a swing: iron set in stone does not give, and a grille that
	# rocked would read as a gate somebody forgot to bolt.
	_tween = create_tween()
	_tween.tween_property(_grille, ^"position:x", 0.035, 0.05)
	_tween.tween_property(_grille, ^"position:x", 0.0, 0.22) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## The bars go up. Public and separate from `activate` so a director can prove
## the LIFT without also having to stand a hero on the correct side of a
## threshold -- the side test is the other half of this prop and deserves to fail
## on its own rather than inside a beat about geometry.
func lift() -> void:
	if _open:
		return
	_open = true
	lifted.emit(tag)
	# Take the refusal back down. `Bus.prompt_changed` is a one-line HUD that holds
	# whatever was last written to it, so without this the grille rises and the
	# screen goes on saying BARRED FROM THE OTHER SIDE over an open passage --
	# which is exactly the frame `puzzle_loop`'s `p_07` caught.
	Bus.prompt_changed.emit("")
	Game.set_flag(flag_id())
	# **One sound, and it is this one.** `Bus.door_opened` used to be emitted on
	# the next line as well, and `Sfx` maps that signal to `door_open` played AT
	# THE HERO -- so lifting a grille played two different noises from two
	# different places on the same frame, one of them a wooden door swinging in a
	# passage that has no door in it. `LockedDoor._swing` carries the note this
	# repeats: pick the sound and the place, and do not also emit the signal that
	# picks another. Nothing but `Sfx` ever listened to `door_opened`, so the
	# grille's own `lifted` signal is the whole progression fact.
	Bus.request_sfx.emit(&"craft_grind", global_position)
	# The blocker is FREED, not disabled. A shape that is only disabled is one bug
	# away from an invisible wall in a passage you can see straight through --
	# `LockedDoor._build_blocker` records the same call.
	if _blocker != null:
		_blocker.queue_free()
		_blocker = null
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_grille, ^"position:y", LIFT, LIFT_TIME)
	if _lamp != null:
		tw.parallel().tween_property(_lamp, ^"light_energy", 0.0, LIFT_TIME)


## The same pose with no motion and no sound, for a passage already opened this
## run. The split `LockedDoor` makes between `_swing()` and `_pose_open()`.
func _pose_open() -> void:
	_open = true
	if _blocker != null:
		_blocker.queue_free()
		_blocker = null
	if _grille != null:
		_grille.position.y = LIFT
	if _lamp != null:
		_lamp.light_energy = 0.0


# --- The ironwork -------------------------------------------------------------

func _build() -> void:
	var hw := opening_w * 0.5
	# Darker than the timber it is not: there is no door here, so the bars ARE the
	# object and they get `LockedDoor`'s iron unchanged -- barely metallic, so the
	# sheen lands on the edges at a rake instead of on the flat.
	var iron := _mat(Color(0.150, 0.145, 0.172), 0.72, 0.16)

	_blocker = StaticBody3D.new()
	_blocker.name = "Blocker"
	_blocker.collision_layer = K.L_WORLD
	_blocker.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(opening_w, opening_h, 0.32)
	cs.shape = box
	cs.position = Vector3(0.0, opening_h * 0.5, 0.0)
	_blocker.add_child(cs)
	add_child(_blocker)

	_grille = Node3D.new()
	_grille.name = "Grille"
	add_child(_grille)

	# Uprights, sunk into the floor and running past the lintel, so the grille has
	# somewhere to go that is not visibly nowhere.
	for i in BARS:
		var t := float(i) / float(BARS - 1)
		var x := lerpf(-hw + BAR_R * 2.0, hw - BAR_R * 2.0, t)
		_cyl(_grille, iron, BAR_R, opening_h + 0.5,
			Vector3(x, (opening_h + 0.5) * 0.5 - 0.25, 0.0))

	# Two rails. The lower one at shin height is what makes the grille read as one
	# object rather than as seven pipes.
	for y: float in [0.62, opening_h - 0.42]:
		_box(_grille, iron, Vector3(opening_w - BAR_R, RAIL_T, RAIL_T * 0.85),
			Vector3(0.0, y, 0.0))

	# A cold lamp on the far side of the bars, aimed back through them. Without it
	# a barred passage is a black rectangle and reads as a wall with a texture on
	# it; with it, the thing the player is being refused is a lit corridor.
	_lamp = OmniLight3D.new()
	_lamp.light_color = Pal.FROST
	_lamp.light_energy = 3.4
	_lamp.omni_range = 6.5
	_lamp.omni_attenuation = 1.7
	_lamp.shadow_enabled = false
	_lamp.position = out_dir_local() * 1.9 + Vector3(0.0, opening_h * 0.55, 0.0)
	add_child(_lamp)


## `out_dir()` before the node has a global transform to read. Local -Z, stated
## once so the lamp and the side test cannot drift apart.
func out_dir_local() -> Vector3:
	return Vector3(0.0, 0.0, -1.0)


# --- Small builders -----------------------------------------------------------
# Private, like `LockedDoor`'s and `SoundingStone`'s. This is a prop in
# `scripts/props/`, not a `PuzzleAtom`, and inheriting the atom's three helpers
# would put a doorway in the kit's `puzzle_atom` group for every gate to adopt.

func _mat(albedo: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	if metal <= 0.001:
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


func _box(parent: Node, mat: Material, size: Vector3, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)


func _cyl(parent: Node, mat: Material, r: float, h: float, at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 8
	mi.mesh = cm
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
