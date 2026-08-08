class_name Town
extends Node3D
## The town: a walled courtyard with a vendor's stall, a smith's forge, and the
## gate down into the dungeon.
##
## Built in code from the P6 kit rather than authored as a .tscn so it stays in
## step with the kit's materials and with K's dimensions — the courtyard is
## sized in TILEs and the gate opening is the same K.DOOR_W as every dungeon
## door, so walking through one teaches you the other.

signal vendor_opened
signal smith_opened
signal gate_entered

const SIZE := 30.0
const HALF := SIZE * 0.5
const WALL_H := 5.0

const SC_FLOOR := "res://scenes/kit/floor_slab.tscn"
const SC_WALL := "res://scenes/kit/wall_segment.tscn"
const SC_TORCH := "res://scenes/kit/torch.tscn"

## Where the hero stands on arriving in town.
const SPAWN := Vector3(0.0, 0.05, 6.0)

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260808
	_build_environment()
	_build_ground()
	_build_walls()
	_build_vendor()
	_build_forge()
	_build_gate()


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	we.environment = load("res://assets/materials/env_town.tres") as Environment
	add_child(we)

	# A low, cold moon. It exists to keep the middle of the courtyard — and the
	# hero standing in it — off pure black between the two firelit stalls. The
	# stalls still win: they are 5–8 energy of warm light against this 0.7 of
	# cold, so "where the light is" still reads as "where the people are".
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.62, 0.70, 0.95)
	moon.light_energy = 0.7
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-52.0, 38.0, 0.0)
	add_child(moon)


func _build_ground() -> void:
	var floor_node := _instance(SC_FLOOR)
	if floor_node != null:
		floor_node.set(&"size", Vector2(SIZE, SIZE))
		add_child(floor_node)


func _build_walls() -> void:
	# North wall is split either side of the gate opening; the rest are solid.
	var gate_gap := K.DOOR_W + 1.6
	var side := (SIZE - gate_gap) * 0.5
	for x_sign in [-1.0, 1.0]:
		var w := _instance(SC_WALL)
		if w == null:
			continue
		w.set(&"length", side)
		w.set(&"height", WALL_H)
		w.position = Vector3(x_sign * (gate_gap + side) * 0.5, 0, -HALF)
		add_child(w)

	var sides := {
		Vector3(HALF, 0, 0): -PI * 0.5,
		Vector3(0, 0, HALF): PI,
		Vector3(-HALF, 0, 0): PI * 0.5,
	}
	for pos: Vector3 in sides:
		var w := _instance(SC_WALL)
		if w == null:
			continue
		w.set(&"length", SIZE)
		w.set(&"height", WALL_H)
		w.position = pos
		w.rotation.y = sides[pos]
		add_child(w)

	for spot in [Vector3(-10, 0, HALF - 0.4), Vector3(10, 0, HALF - 0.4),
			Vector3(-HALF + 0.4, 0, -6), Vector3(HALF - 0.4, 0, -6)]:
		_torch(spot + Vector3.UP * KitStyle.SCONCE_Y, 0.0)


# --- The vendor -------------------------------------------------------------

func _build_vendor() -> void:
	var root := Station.new()
	root.name = "Vendor"
	root.kind = Station.Kind.VENDOR
	root.prompt = "Sell your haul  [E]"
	root.position = Vector3(-8.5, 0, 0)
	root.rotation.y = deg_to_rad(24.0)
	add_child(root)
	root.activated.connect(func(_k: StringName) -> void: vendor_opened.emit())

	var wood := load("res://assets/materials/mat_wood.tres") as Material
	var iron := load("res://assets/materials/mat_iron.tres") as Material

	_box(root, Vector3(3.4, 0.18, 1.1), Vector3(0, 1.02, 0), wood)          # counter top
	_box(root, Vector3(3.0, 0.95, 0.8), Vector3(0, 0.47, 0.05), wood)       # counter body
	for x in [-1.55, 1.55]:
		_box(root, Vector3(0.12, 2.6, 0.12), Vector3(x, 1.3, -0.5), wood)   # canopy poles
	_box(root, Vector3(3.8, 0.10, 1.9), Vector3(0, 2.62, -0.1), wood)       # canopy

	# Crates behind the counter, so the stall reads as a place that holds stock.
	_box(root, Vector3(0.7, 0.7, 0.7), Vector3(-1.1, 0.35, -1.2), wood)
	_box(root, Vector3(0.6, 0.6, 0.6), Vector3(-0.4, 0.3, -1.4), wood)
	_box(root, Vector3(0.5, 1.0, 0.5), Vector3(1.2, 0.5, -1.3), iron)

	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.83, 0.55)
	lamp.light_energy = 5.5
	lamp.omni_range = 9.0
	lamp.omni_attenuation = 1.3
	lamp.position = Vector3(0, 2.35, 0.2)
	root.add_child(lamp)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.4, 1.1, 1.1)
	col.shape = shape
	col.position = Vector3(0, 0.55, 0)
	root.add_child(col)


# --- The smith --------------------------------------------------------------

func _build_forge() -> void:
	var root := Station.new()
	root.name = "Smith"
	root.kind = Station.Kind.SMITH
	root.prompt = "Forge  [E]"
	root.position = Vector3(8.5, 0, 0)
	root.rotation.y = deg_to_rad(-24.0)
	add_child(root)
	root.activated.connect(func(_k: StringName) -> void: smith_opened.emit())

	var stone := load("res://assets/materials/mat_prop.tres") as Material
	var iron := load("res://assets/materials/mat_iron.tres") as Material

	_box(root, Vector3(2.4, 1.0, 1.4), Vector3(0, 0.5, -0.4), stone)        # forge body
	_box(root, Vector3(0.9, 0.9, 0.9), Vector3(0, 1.45, -0.4), stone)       # chimney
	# Anvil: a stubby block on a stump reads at camera distance; a silhouetted
	# horn would be lost against the forge glow behind it.
	_box(root, Vector3(0.5, 0.45, 0.5), Vector3(1.5, 0.22, 0.5), stone)
	_box(root, Vector3(0.9, 0.34, 0.38), Vector3(1.5, 0.60, 0.5), iron)

	# The coals. This is the town's warmest light and the thing that tells you
	# from across the courtyard which stall is which.
	var coals := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.5, 0.12, 0.8)
	coals.mesh = cm
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.35, 0.10)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.42, 0.12)
	glow.emission_energy_multiplier = 6.0
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	coals.mesh.material = glow
	coals.position = Vector3(0, 1.02, -0.4)
	root.add_child(coals)

	var fire := OmniLight3D.new()
	fire.light_color = KitStyle.FIRE_COLOR
	fire.light_energy = 8.0
	fire.omni_range = 11.0
	fire.omni_attenuation = 1.4
	fire.position = Vector3(0, 1.35, -0.3)
	root.add_child(fire)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 1.2, 1.4)
	col.shape = shape
	col.position = Vector3(0, 0.6, -0.4)
	root.add_child(col)


# --- The way down -----------------------------------------------------------

func _build_gate() -> void:
	var root := Station.new()
	root.name = "Gate"
	root.kind = Station.Kind.GATE
	root.prompt = "Descend  [E]"
	root.reach = 3.4
	root.position = Vector3(0, 0, -HALF + 0.6)
	add_child(root)
	root.activated.connect(func(_k: StringName) -> void: gate_entered.emit())

	var stone := load("res://assets/materials/mat_prop.tres") as Material
	var half_gap := (K.DOOR_W + 1.6) * 0.5
	for x in [-half_gap, half_gap]:
		_box(root, Vector3(0.9, K.DOOR_H + 0.9, 0.9), Vector3(x, (K.DOOR_H + 0.9) * 0.5, 0), stone)
	_box(root, Vector3(half_gap * 2.0 + 0.9, 0.8, 1.0),
		Vector3(0, K.DOOR_H + 1.3, 0), stone)

	# The descent itself: the same cold portal light the dungeon's exit uses, so
	# the two ends of the trip are visibly the same object.
	var veil := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(K.DOOR_W + 1.4, K.DOOR_H + 0.6)
	veil.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.30, 0.62, 0.95, 0.30)
	mat.emission_enabled = true
	mat.emission = Color(0.42, 0.76, 1.0)
	mat.emission_energy_multiplier = 2.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	veil.material_override = mat
	veil.position = Vector3(0, (K.DOOR_H + 0.6) * 0.5, 0.1)
	root.add_child(veil)

	var lamp := OmniLight3D.new()
	lamp.light_color = Color(0.45, 0.78, 1.0)
	lamp.light_energy = 4.0
	lamp.omni_range = 9.0
	lamp.position = Vector3(0, 2.0, 1.0)
	root.add_child(lamp)


# --- Helpers ----------------------------------------------------------------

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _torch(pos: Vector3, yaw: float) -> void:
	var t := _instance(SC_TORCH)
	if t == null:
		return
	t.position = pos
	t.rotation.y = yaw
	t.set(&"rng_seed", _rng.randi_range(1, 9999))
	add_child(t)


func _instance(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		push_error("Town: missing kit scene %s" % path)
		return null
	var packed := load(path) as PackedScene
	return packed.instantiate() as Node3D if packed != null else null
