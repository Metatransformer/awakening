class_name ExtractNode
extends Interactable
## The way out. Stand on it, hold the button, pay the fee, keep the bag.
##
## It is a HOLD, not a press, for one reason: extracting is the decision the
## whole game is about, and a decision you can make by fumbling a button is not
## a decision. The hold is also long enough to be interrupted, so leaving with
## something chasing you is its own small problem.
##
## The node does not draw its own progress. It drives the HUD's bag corner
## instead (`Hud.set_extract_hold`), so the ring closes around the number the
## player is protecting -- the fee is paid out of that number and the UI says so.

const RUNE_RADIUS := 1.35
const PILLAR_H := 6.0

var _rune: MeshInstance3D
var _rune_mat: StandardMaterial3D
var _pillar: MeshInstance3D
## Scaled instead of the mesh: a MeshInstance3D scales about its OWN origin, so
## scaling the mesh (whose origin is its centre, 3 m up) shrinks the pillar
## toward its middle. The pivot sits on the floor, which is where a beam grows
## from.
var _pillar_pivot: Node3D
var _pillar_mat: StandardMaterial3D
var _light: OmniLight3D
var _age: float = 0.0
var _lit: float = 0.0        ## eased 0..1 focus brightness
var _spent: bool = false


func _ready() -> void:
	prompt = "EXTRACT"
	radius = RUNE_RADIUS + 0.35
	hold_time = 1.5
	super()
	_build()
	# It exists in town too (as the arrival pad), but it is only a way out of
	# somewhere you are.
	visible = true
	set_process(true)


func on_focus(on: bool) -> void:
	if _spent:
		return
	Hud.set_extract_available(on)
	if not on:
		Hud.set_extract_hold(0.0)


func on_hold(t01: float) -> void:
	Hud.set_extract_hold(t01)
	# The pillar fills from the floor up as you hold. The ring in the corner is
	# the number; this is the world telling you the same thing in the same beat.
	_pillar_pivot.scale.y = maxf(0.001, t01)
	_pillar_mat.albedo_color.a = 0.10 + 0.35 * t01


func activate(by: Node3D) -> void:
	if _spent:
		return
	if not Run.extract():
		# Run.extract already told the bus why. Snap the ring back so the failure
		# is visible as a failure and not as a dropped input.
		Hud.set_extract_hold(0.0)
		_pillar_pivot.scale.y = 0.001
		return
	_spent = true
	enabled = false
	Hud.set_extract_available(false)
	Hud.set_extract_hold(0.0)
	_flash()
	activated.emit(by)


func _process(delta: float) -> void:
	_age += delta
	var want := 1.0 if (Prompt.focus == self and not _spent) else 0.0
	_lit = move_toward(_lit, want, delta * 4.0)

	var pulse := 0.5 + 0.5 * sin(_age * (2.2 + 2.6 * _lit))
	_rune.rotation.y = _age * (0.35 + 0.9 * _lit)
	_rune_mat.emission_energy_multiplier = 1.2 + pulse * 0.9 + _lit * 2.4
	_light.light_energy = 1.6 + pulse * 0.5 + _lit * 2.5
	_light.omni_range = 3.4 + _lit * 2.0


# --- Construction -----------------------------------------------------------

func _build() -> void:
	# A flat ring on the floor. TorusMesh laid down, not a decal: the dungeon has
	# no decal pass and a quad on the floor z-fights the slab.
	_rune_mat = StandardMaterial3D.new()
	_rune_mat.albedo_color = Pal.CYAN
	_rune_mat.emission_enabled = true
	_rune_mat.emission = Pal.CYAN
	_rune_mat.emission_energy_multiplier = 1.6
	_rune_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_rune_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_rune = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RUNE_RADIUS - 0.10
	tm.outer_radius = RUNE_RADIUS
	tm.rings = 6           ## hexagonal, so it reads as cut rather than printed
	tm.ring_segments = 4
	_rune.mesh = tm
	_rune.material_override = _rune_mat
	_rune.position.y = 0.045
	add_child(_rune)

	# Three spokes, so the rotation is visible. A plain ring spinning looks static.
	for i in 3:
		var spoke := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(RUNE_RADIUS * 0.9, 0.03, 0.09)
		spoke.mesh = sm
		spoke.material_override = _rune_mat
		spoke.rotation.y = TAU * float(i) / 3.0
		spoke.transform.origin = Basis(Vector3.UP, spoke.rotation.y) \
			* Vector3(RUNE_RADIUS * 0.5, 0.0, 0.0)
		_rune.add_child(spoke)

	_pillar_mat = StandardMaterial3D.new()
	_pillar_mat.albedo_color = Color(Pal.CYAN, 0.10)
	_pillar_mat.emission_enabled = true
	_pillar_mat.emission = Pal.CYAN
	_pillar_mat.emission_energy_multiplier = 1.0
	_pillar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pillar_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_pillar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pillar_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_pillar = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = RUNE_RADIUS * 0.72
	cm.bottom_radius = RUNE_RADIUS * 0.92
	cm.height = PILLAR_H
	cm.radial_segments = 8
	cm.cap_top = false
	cm.cap_bottom = false
	_pillar.mesh = cm
	_pillar.material_override = _pillar_mat
	_pillar.position.y = PILLAR_H * 0.5

	_pillar_pivot = Node3D.new()
	_pillar_pivot.add_child(_pillar)
	_pillar_pivot.scale.y = 0.001
	add_child(_pillar_pivot)

	_light = OmniLight3D.new()
	_light.light_color = Pal.CYAN
	_light.light_energy = 1.8
	_light.omni_range = 3.4
	_light.omni_attenuation = 1.5
	_light.shadow_enabled = false
	_light.position.y = 0.6
	add_child(_light)


## The moment of leaving. One bright frame and a collapse, because the scene is
## about to change anyway and a long animation would be cut off mid-way.
func _flash() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_light, "light_energy", 9.0, 0.12)
	tw.tween_property(_pillar_pivot, "scale:y", 1.0, 0.10)
	tw.tween_property(_pillar_mat, "albedo_color:a", 0.85, 0.10)
