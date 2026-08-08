class_name HookshotTether
extends Node3D
## The visible chain the hookshot flies on: interlocking links plus a barbed head.
##
## Ported from ~/valenfeld (`scripts/player/HookshotTether.gd`). Two deliberate
## changes from the original:
##
##  * It no longer depends on that project's `MeshKit` — a 1600-line material
##    hub with its own preload chain. The one call it actually made was for a
##    tinted metal surface, which is `_metal()` here.
##  * The extend speed is now driven by `K.HOOK_SPEED` rather than a caller-
##    supplied duration. OOT's hookshot flies at a FIXED SPEED in a PERFECTLY
##    STRAIGHT LINE (docs/CONTRACT.md §2.5) — a fixed *duration* would mean a
##    near shot crawls and a far shot streaks, which is the giveaway tell of a
##    clone. `begin()` still accepts an override for tools that need one.
##
## This owns presentation only. Whoever fires the hookshot owns the raycast,
## the target choice, and moving the hero; it calls begin(), then advance()
## every frame until advance() returns true, then update_pull() while travelling.

enum Phase { IDLE, EXTENDING, PULLING }

@export_group("Chain")
@export_range(0.05, 1.0, 0.01) var segment_length: float = 0.32
@export_range(0.0, 0.5, 0.01) var segment_gap: float = 0.10
@export_range(0.01, 0.25, 0.005) var segment_thickness: float = 0.055
@export_range(8, 160, 1) var max_segments: int = 112
@export var chain_color: Color = Color(0.46, 0.38, 0.22)

@export_group("Head")
@export_range(0.1, 1.2, 0.01) var head_length: float = 0.46
@export_range(0.02, 0.4, 0.005) var head_radius: float = 0.105
@export var head_color: Color = Color(0.38, 0.36, 0.31)

var phase: Phase = Phase.IDLE
var impact_position: Vector3 = Vector3.ZERO
var pull_target: Vector3 = Vector3.ZERO
var travelled: float = 0.0
var distance: float = 0.001
var progress: float = 0.0
var tip_position: Vector3 = Vector3.ZERO

var _chain: MultiMeshInstance3D
var _head: Node3D
var _speed: float = 0.0


func _ready() -> void:
	# The firer parents this to the hero for ownership and lifetime only. Its
	# transforms are world-space presentation and must not inherit the hero's
	# yaw or scale — a chain that rotates with the shooter is not a straight line.
	top_level = true
	_ensure_visual()
	visible = false


## Start a shot from `from` to `impact`, landing the hero at `resolved_pull_target`.
## `speed_override` is for tools that need a deterministic frame count; leave it
## at 0 for the real, fixed-speed flight.
func begin(from: Vector3, impact: Vector3, resolved_pull_target: Vector3,
		speed_override: float = 0.0) -> void:
	_ensure_visual()
	phase = Phase.EXTENDING
	impact_position = impact
	pull_target = resolved_pull_target
	travelled = 0.0
	distance = maxf(from.distance_to(impact), 0.001)
	progress = 0.0
	tip_position = from
	_speed = speed_override if speed_override > 0.0 else K.HOOK_SPEED
	visible = true
	_render_chain(from, from)


## Advance the outbound chain. Returns true only on the tick the chain arrives.
## The hero stays put for every EXTENDING tick, including the arrival tick.
func advance(delta: float, from: Vector3) -> bool:
	if phase != Phase.EXTENDING:
		return false
	travelled = minf(travelled + _speed * maxf(delta, 0.0), distance)
	progress = clampf(travelled / distance, 0.0, 1.0)
	tip_position = from.lerp(impact_position, progress)
	_render_chain(from, tip_position)
	if progress < 1.0:
		return false
	phase = Phase.PULLING
	return true


## Keep the tether drawn while the hero travels. `from` follows the hero, so
## the chain retracts into the anchor with no second animation clock.
func update_pull(from: Vector3) -> void:
	if phase != Phase.PULLING:
		return
	progress = 1.0
	tip_position = impact_position
	_render_chain(from, impact_position)


func clear() -> void:
	phase = Phase.IDLE
	travelled = 0.0
	progress = 0.0
	visible = false
	if _chain != null and _chain.multimesh != null:
		_chain.multimesh.visible_instance_count = 0


func is_extending() -> bool:
	return phase == Phase.EXTENDING


func is_pulling() -> bool:
	return phase == Phase.PULLING


## Draw one instant of an outbound shot without running gameplay, so a director
## can photograph the chain at a chosen extension.
func preview(from: Vector3, impact: Vector3, normalized_progress: float) -> void:
	_ensure_visual()
	phase = Phase.EXTENDING if normalized_progress < 1.0 else Phase.PULLING
	impact_position = impact
	progress = clampf(normalized_progress, 0.0, 1.0)
	tip_position = from.lerp(impact, progress)
	visible = true
	_render_chain(from, tip_position)


# --- Construction -----------------------------------------------------------

func _ensure_visual() -> void:
	if _chain != null:
		return
	_chain = MultiMeshInstance3D.new()
	_chain.name = "SegmentedChain"
	# A real link, not a stick: an oval torus whose ring plane holds the chain
	# axis, so successive links (rolled 90 deg apart in _render_chain) read as
	# interlocked iron instead of a dashed cable. 10x5 keeps the whole tether to
	# one draw call at N64-era triangle budgets.
	var link := TorusMesh.new()
	link.inner_radius = 0.24
	link.outer_radius = 0.5
	link.rings = 10
	link.ring_segments = 5
	link.material = _metal(chain_color)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = max_segments
	mm.visible_instance_count = 0
	mm.mesh = link
	_chain.multimesh = mm
	add_child(_chain)
	_head = _build_head()
	add_child(_head)


## The barbed head the chain flies on: a short collar tapering to a solid point,
## built +Y-forward so _render_chain only maps local +Y onto the travel axis.
func _build_head() -> Node3D:
	var head := Node3D.new()
	head.name = "HookHead"
	var mat := _metal(head_color)

	var collar_mesh := CylinderMesh.new()
	collar_mesh.top_radius = head_radius * 0.86
	collar_mesh.bottom_radius = head_radius * 0.62
	collar_mesh.height = head_length * 0.42
	collar_mesh.radial_segments = 8
	collar_mesh.rings = 1
	collar_mesh.material = mat
	var collar := MeshInstance3D.new()
	collar.name = "Collar"
	collar.mesh = collar_mesh
	collar.position.y = collar_mesh.height * 0.5
	head.add_child(collar)

	var spike_mesh := CylinderMesh.new()
	spike_mesh.top_radius = 0.0  # a cone: the point that bites the surface
	spike_mesh.bottom_radius = head_radius
	spike_mesh.height = head_length * 0.62
	spike_mesh.radial_segments = 8
	spike_mesh.rings = 1
	spike_mesh.material = mat
	var spike := MeshInstance3D.new()
	spike.name = "Spike"
	spike.mesh = spike_mesh
	spike.position.y = head_length * 0.42 + spike_mesh.height * 0.5
	head.add_child(spike)
	return head


## Tinted metal. Stands in for the source project's MeshKit "metal" surface —
## dark, low-roughness, faintly specular, so links catch the dungeon torches.
func _metal(tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.metallic = 0.75
	m.metallic_specular = 0.6
	m.roughness = 0.38
	return m


# --- Rendering --------------------------------------------------------------

func _render_chain(from: Vector3, to: Vector3) -> void:
	_ensure_visual()
	# `top_level` preserves the transform this node had when detached from its
	# parent. Reset the whole world frame, not just position: otherwise the
	# hero's yaw is retained and rotates these already-world-space vectors twice.
	global_transform = Transform3D(Basis.IDENTITY, from)

	var span := to - from
	var length := span.length()
	# Before the chain has length the tip still needs a facing, so fall back to
	# the shot's own aim rather than whatever the last shot left behind.
	var aim := span if length > 0.001 else (impact_position - from)
	var direction := aim.normalized() if aim.length() > 0.001 else Vector3.FORWARD
	# Godot cannot build a look basis when direction and up are parallel, and a
	# straight-up hookshot is a legitimate traversal shot.
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.98 else Vector3.UP
	var look := Basis.looking_at(direction, up)

	# +Y-forward head geometry onto the travel axis (look maps local -Z to direction).
	_head.transform = Transform3D(
		look * Basis(Vector3.RIGHT, -PI * 0.5),
		direction * maxf(length - head_length, 0.0)
	)

	# The chain stops where the collar begins so links never poke through the spike.
	var chain_length := length - head_length * 0.8
	if chain_length <= 0.001:
		_chain.multimesh.visible_instance_count = 0
		return

	var spacing := maxf(segment_length + segment_gap, 0.001)
	# Links overrun their own spacing so each closes through its neighbour; that
	# overlap is what reads as an interlocked chain, not a row of floating hoops.
	var link_length := spacing * 1.7
	var link_width := maxf(segment_thickness * 2.8, 0.001)
	var count := mini(max_segments, int(ceil(chain_length / spacing)))
	var rendered := 0
	for i in count:
		var start := float(i) * spacing
		if start >= chain_length:
			break
		var drawn := clampf(chain_length - start, spacing * 0.6, link_length)
		var centre := direction * (start + drawn * 0.5)
		# Every other link is rolled a quarter turn about the chain axis.
		var roll := Basis(Vector3.BACK, PI * 0.5) if i % 2 == 1 else Basis.IDENTITY
		var basis := look * roll * Basis.from_scale(
			Vector3(link_width, link_width * 0.85, drawn))
		_chain.multimesh.set_instance_transform(rendered, Transform3D(basis, centre))
		rendered += 1
	_chain.multimesh.visible_instance_count = rendered
