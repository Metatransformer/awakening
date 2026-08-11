extends Node3D
## Every imported sword, shield, and the hookshot, lined up beside a 1.65 m
## hero-height reference so scale and texturing can be judged by eye rather than
## by filename. Also fires a live HookshotTether at a HookTarget, because a
## chain is the one thing here that cannot be checked from a static model.
##
##   tools/quiet.sh --path . -s tools/shoot.gd -- \
##     --scene=res://tools/scenes/_weapon_lookdev.tscn \
##     --director=res://tools/directors/weapon_lookdev.gd --out=/tmp/w/w.png

const SWORDS := ["sword_knightly", "sword_noble", "sword_elegant", "sword_common", "sword_crude"]
const SHIELDS := ["shield_knightly", "shield_noble", "shield_elegant", "shield_common", "shield_crude", "kite_shield"]

const SPACING := 0.85
const HERO_HEIGHT := 1.65

var tether: HookshotTether
var hook_from: Vector3
var hook_to: Vector3


func _ready() -> void:
	_light()
	_ground()

	# Swords stood on end at z = 0, shields facing camera at z = +1.6.
	for i in SWORDS.size():
		var x := (float(i) - float(SWORDS.size() - 1) * 0.5) * SPACING
		_place(SWORDS[i], Vector3(x, 0.0, 0.0), 0.0)
	for i in SHIELDS.size():
		var x := (float(i) - float(SHIELDS.size() - 1) * 0.5) * SPACING
		_place(SHIELDS[i], Vector3(x, 0.0, 1.6), 0.0)

	# The hookshot, held at roughly the height a hand carries it.
	_place("hookshot_pistol", Vector3(0.0, 1.05, 3.1), 0.0)

	_height_reference()
	_hookshot_demo()


# --- Layout -----------------------------------------------------------------

## Drop a model at `pos`, print what we got, and label it in-world so a contact
## sheet is self-describing instead of needing a legend.
func _place(id: String, pos: Vector3, yaw: float) -> void:
	var m := WeaponModels.make(id)
	if m == null:
		push_error("lookdev: %s missing" % id)
		return
	var holder := Node3D.new()
	holder.name = id
	holder.position = pos
	holder.rotation.y = yaw
	holder.add_child(m)
	add_child(holder)

	var ext := WeaponModels.extent(m)
	print("%-20s extent %.2f m at %v" % [id, ext, pos])

	# Shields have their origin at the centre of the disc, so placing one at
	# y = 0 sinks half of it into the floor. Lift by half its own height rather
	# than by a guessed constant, which also keeps the swords (origin at the
	# pommel, already sitting on the ground) exactly where they belong.
	if id.contains("shield"):
		holder.position.y = ext * 0.5

	var label := Label3D.new()
	label.text = "%s\n%.2f m" % [id.replace("_", " "), ext]
	label.font_size = 42
	# Fixed on-screen size: a world-scaled label puts the nearest item's caption
	# across the whole frame and hides the models the sheet exists to show.
	label.fixed_size = true
	label.pixel_size = 0.00035
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 14
	label.modulate = Color(0.95, 0.92, 0.78)
	label.position = holder.position + Vector3(0, ext * 0.5 + 0.22, 0)
	add_child(label)


## A 1.65 m post beside the rack. Every judgement here is "next to the hero",
## so the hero's height has to be visible in the same frame.
func _height_reference() -> void:
	var x := -float(SHIELDS.size()) * SPACING * 0.5 - 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.25, 0.22)
	var post := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.03
	cm.bottom_radius = 0.03
	cm.height = HERO_HEIGHT
	cm.radial_segments = 8
	cm.material = mat
	post.mesh = cm
	post.position = Vector3(x, HERO_HEIGHT * 0.5, 0.8)
	add_child(post)

	var label := Label3D.new()
	label.text = "hero\n1.65 m"
	label.font_size = 48
	label.fixed_size = true
	label.pixel_size = 0.0004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 16
	label.modulate = Color(1.0, 0.6, 0.55)
	label.position = Vector3(x, HERO_HEIGHT + 0.2, 0.8)
	add_child(label)


# --- Hookshot ---------------------------------------------------------------

## A ring at hookshot range with a live tether aimed at it. The director steps
## the extension so the chain can be photographed part-way out.
func _hookshot_demo() -> void:
	var ring := HookTarget.new()
	ring.name = "Ring"
	ring.position = Vector3(3.6, 2.1, -3.0)
	# Face the shooter, so the pull nudge points back toward the rack.
	ring.rotation.y = PI * 0.75
	add_child(ring)

	hook_from = Vector3(-1.4, 1.2, 1.2)
	hook_to = ring.anchor_point()

	var muzzle := WeaponModels.make("hookshot_pistol")
	if muzzle != null:
		var holder := Node3D.new()
		holder.name = "FiringHookshot"
		holder.position = hook_from
		holder.look_at_from_position(hook_from, hook_to, Vector3.UP)
		# The pistol's barrel runs along +Z; look_at points -Z at the target.
		holder.rotate_object_local(Vector3.UP, PI)
		holder.add_child(muzzle)
		add_child(holder)

	tether = HookshotTether.new()
	tether.name = "Tether"
	add_child(tether)


# --- Stage ------------------------------------------------------------------

func _light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -38, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.07, 0.08, 0.11)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.42, 0.46, 0.58)
	e.ambient_light_energy = 0.8
	env.environment = e
	add_child(env)


func _ground() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.19, 0.18)
	mat.roughness = 1.0
	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(24, 24)
	pm.material = mat
	floor_mesh.mesh = pm
	add_child(floor_mesh)
