class_name HookTarget
extends Node3D
## An authored anchor the hookshot's aim-assist prefers — OOT's ceiling ring.
##
## Ported from ~/valenfeld (`scripts/world/HookTarget.gd`), retargeted onto this
## project's groups and collision layers (docs/CONTRACT.md §5, §6).
##
## The hookshot will still catch any valid surface inside K.HOOK_RANGE via a
## plain raycast — that stays the fallback. A HookTarget layers the OOT feel on
## top: it is a marker the aim-assist scan prefers when you are roughly pointed
## at it, so a dungeon gate points you at the one ring that matters instead of
## demanding pixel-perfect aim across a chasm.
##
## Group membership is the only contract with the firer, registered in _ready so
## a ring baked into a room .tscn and one built at runtime behave identically.
##
## Local convention: origin = the anchor, local +Y = up, local +Z = out from the
## face it is mounted on. `pull_point()` nudges up and out so the hero lands ON
## the ledge rather than embedded in the wall.

## Aim-assist tolerance, metres. Kept as data so dungeon gates can widen a
## deliberately generous ring without touching the firer.
@export var snap_radius: float = 1.5
## Up-nudge off the anchor, to clear a lip.
@export var pull_up: float = 0.4
## Out-nudge off the mounting face, so you do not arrive inside the wall.
@export var pull_out: float = 0.6
## Draw the ring. Off when the anchor is an invisible assist on existing geometry.
@export var show_ring: bool = true
@export var ring_radius: float = 0.28
@export var ring_color: Color = Color(0.42, 0.40, 0.36)


func _ready() -> void:
	add_to_group(&"hookable")
	if show_ring:
		_build_ring()


## The global point the hook zips the hero to: the anchor, nudged along local +Y
## and +Z. Falls back to a plain up-nudge on a degenerate transform (a
## mis-authored placement) and says so, rather than failing silently.
func pull_point() -> Vector3:
	var up := global_transform.basis.y
	var out := global_transform.basis.z
	if up.length() < 0.0001 or out.length() < 0.0001:
		push_warning("HookTarget %s has a degenerate transform — falling back to a plain up-nudge." % [get_path()])
		return global_position + Vector3.UP * pull_up
	return global_position + up.normalized() * pull_up + out.normalized() * pull_out


## Where the hook head actually bites. The reticle and the raycast both want the
## ring itself, not the landing spot.
func anchor_point() -> Vector3:
	return global_position


func _build_ring() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ring_color
	mat.metallic = 0.7
	mat.roughness = 0.45

	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var tm := TorusMesh.new()
	tm.inner_radius = ring_radius * 0.78
	tm.outer_radius = ring_radius
	tm.rings = 12
	tm.ring_segments = 6  # faceted on purpose: N64 silhouette
	tm.material = mat
	ring.mesh = tm
	# The torus lies in XZ by default; stand it up so it faces out along +Z.
	ring.rotation.x = PI * 0.5
	add_child(ring)

	var plate := MeshInstance3D.new()
	plate.name = "Plate"
	var cm := CylinderMesh.new()
	cm.top_radius = ring_radius * 0.34
	cm.bottom_radius = ring_radius * 0.34
	cm.height = 0.08
	cm.radial_segments = 8
	cm.material = mat
	plate.mesh = cm
	plate.rotation.x = PI * 0.5
	plate.position.z = -0.04
	add_child(plate)
