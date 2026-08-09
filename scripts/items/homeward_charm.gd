class_name HomewardCharm
extends Node3D
## The way out, carried. You open the menu, use the charm, and it pulls you home.
##
## This replaces the rune pad (`ExtractNode`, deleted). The pad made leaving a
## PLACE — you had to find your way back to it, which turned the game's central
## decision into a navigation chore and, worse, meant a rich run could be lost to
## not remembering where the exit was. The decision was never supposed to be
## "can I get back to the door", it was "is what I am carrying worth the fee".
##
## What the pad got right and this keeps, because METAGAME §5 is built on it:
##
##  * **Leaving takes time and can be interrupted.** The pad was a HOLD so that a
##    decision could not be made by fumbling a button and so that something
##    chasing you was a real problem. A menu press has neither property on its
##    own — the menu is paused, so a "hold" in there is just a slow click. So the
##    charm channels in the WORLD, after the menu closes, and a hit breaks it.
##  * **The fee is paid out of the number you are protecting**, and the HUD says
##    so: the ring closes around the bag total, exactly as it did on the pad.
##
## It is deliberately NOT bindable to an item button. One D-pad press that ends
## the run is the fumble the hold existed to prevent.

## Long enough to be interrupted by something already swinging at you, short
## enough that using it in a cleared room is not a punishment. [tune]
const CHANNEL_TIME := 1.2
## A ring of thin rising slats, not a cylinder of light. See _build.
const SLAT_COUNT := 6
const SLAT_H := 3.2
const SLAT_W := 0.09
const SLAT_R := 0.78

## Ticking 0 -> CHANNEL_TIME while leaving, or -1.0 when idle.
var _t: float = -1.0
var _column: Node3D
var _slat_mat: StandardMaterial3D
var _light: OmniLight3D


func _ready() -> void:
	_build()
	set_process(false)
	Bus.homeward_used.connect(_on_used)


func active() -> bool:
	return _t >= 0.0


# --- The channel ------------------------------------------------------------

## Start leaving. Returns false (and says why on the bus) if this is not a
## moment when leaving is possible at all.
func begin() -> bool:
	if _t >= 0.0:
		return false
	if not Run.in_dungeon:
		return false
	# Affordability is checked HERE as well as at the end, so being too poor is
	# refused before the hero is rooted for a second and a bit. Run.extract()
	# checks again on completion because the fee moves with the bag and the bag
	# can change during the channel.
	if not Run.can_extract():
		Bus.extract_refused.emit(Run.extract_cost(), Game.gold)
		return false
	_t = 0.0
	set_process(true)
	_column.scale.y = 0.001
	_show_fx(true)
	return true


## Something went wrong on the way out. `Bus.extract_refused` is not used here:
## that signal means "you cannot afford this", and being hit is a different
## sentence entirely.
func cancel() -> void:
	if _t < 0.0:
		return
	_t = -1.0
	set_process(false)
	_show_fx(false)
	Hud.set_extract_hold(0.0)
	Bus.homeward_broken.emit()


func _process(delta: float) -> void:
	_t += delta
	var t01 := clampf(_t / CHANNEL_TIME, 0.0, 1.0)
	Hud.set_extract_hold(t01)
	# The slats climb the hero rather than standing on the floor. The charm is
	# the thing working, so the effect belongs on the body carrying it.
	_column.scale.y = maxf(0.001, t01)
	_column.rotation.y = t01 * 1.4
	# Deliberately modest. The camera sits a couple of metres behind him, so a
	# light bright enough to look dramatic in a screenshot washes the floor to
	# flat cyan and the player loses the room they are standing in.
	_light.light_energy = 1.0 + 2.4 * t01
	_light.omni_range = 2.4 + 1.4 * t01

	if t01 < 1.0:
		return

	_t = -1.0
	set_process(false)
	Hud.set_extract_hold(0.0)
	if not Run.extract():
		# The bag grew mid-channel and the fee outran the purse. Run.extract
		# already said so on the bus; just stop looking like we left.
		_show_fx(false)
		return
	# The scene is about to change, so there is no point animating the collapse
	# -- one bright frame is all anyone will see of it.
	_light.light_energy = 6.0


func _on_used() -> void:
	begin()


## The charm is invisible until it is working. An always-on CYAN light on the
## hero would read as an equipped item and, worse, would light the room -- CYAN
## is reserved for the way out and nothing else (STYLEGUIDE §1).
func _show_fx(on: bool) -> void:
	_column.visible = on
	_light.visible = on


# --- Construction -----------------------------------------------------------
## SIX THIN SLATS ON A RING, not a column of light.
##
## The first version of this was the rune pad's cylinder: an ADD-blended,
## alpha-faded mesh around the hero. It rendered as a solid CYAN slab that hid
## the hero, the doorway and half the room -- caught by looking at the frame,
## and it is the trap CLAUDE.md §3 already names. **Alpha does not attenuate
## ADD**, so "fade it in" is not a thing this material can do; every opacity is
## the same opacity. The fix is never the material, it is the shape.
##
## So: opaque, unshaded, emissive slats, 9 cm wide, with five-sixths of the ring
## being GAP. You see the hero between them, the effect still wraps him, and it
## grows from the floor because that is the direction the charm pulls.
func _build() -> void:
	_slat_mat = StandardMaterial3D.new()
	_slat_mat.albedo_color = Pal.CYAN
	_slat_mat.emission_enabled = true
	_slat_mat.emission = Pal.CYAN
	_slat_mat.emission_energy_multiplier = 2.2
	_slat_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_slat_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Scaled on a pivot at the FLOOR. A MeshInstance3D scales about its own
	# origin, so scaling a slat whose origin is its centre grows it from the
	# middle in both directions -- it has to be the parent that scales, with the
	# slats offset up into it.
	_column = Node3D.new()
	_column.name = "Column"
	_column.visible = false
	add_child(_column)

	for i in SLAT_COUNT:
		var slat := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(SLAT_W, SLAT_H, SLAT_W)
		slat.mesh = bm
		slat.material_override = _slat_mat
		var a := TAU * float(i) / float(SLAT_COUNT)
		slat.position = Vector3(sin(a) * SLAT_R, SLAT_H * 0.5, cos(a) * SLAT_R)
		_column.add_child(slat)

	_light = OmniLight3D.new()
	_light.light_color = Pal.CYAN
	_light.light_energy = 1.0
	_light.omni_range = 2.4
	_light.omni_attenuation = 1.5
	_light.shadow_enabled = false
	_light.position.y = 0.9
	_light.visible = false
	add_child(_light)
