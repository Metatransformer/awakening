class_name Stairs
extends Interactable
## The way down. Stands in the deepest room of every floor, next to the chest.
##
## This is the decision the whole loop is built around, and it is deliberately a
## thing you have to walk to and press a button on rather than a hole you fall
## through. Standing in front of it, you are holding a bag you have not banked,
## you know roughly what the next floor costs, and you can still turn around and
## go home with what you have. A stair that triggered on touch would make that
## decision for you (docs/GDD.md §5, docs/METAGAME.md §3).
##
## It does NOT bank anything, heal anything, or end the run. Going down keeps the
## bag, keeps the damage, and keeps the extraction fee climbing -- the descent is
## a commitment, not a checkpoint. The only way to bank is to go home.
##
## Built in code like the rest of the kit: the scene stores parameters, never a
## few hundred generated triangles.

## A rimmed pit with a short flight in the back of it. Everything is ABOVE the
## floor, and the rim is deliberately low.
##
## Two earlier builds are worth the space, because both looked right in the
## source and photographed as furniture:
##
##   1. **Steps sinking below y=0.** A room's floor is one slab
##      (scenes/kit/floor_slab.tscn, sized by dungeon.gd), so there is no hole to
##      see a sunken flight through. Every tread was behind that slab from every
##      angle the camera can reach; the prop rendered as a black doormat.
##   2. **A waist-high housing with the flight descending away inside it.** The
##      geometry was all above the floor this time, but the camera sits about 30
##      degrees up, and a flight that descends AWAY presents the back of its top
##      step to you: one tall slab across the opening, no treads, a stone bench.
##
## What a descent actually needs is for the eye to get INTO the hole. That means
## the near rim has to be low enough not to occlude the interior at 30 degrees
## (a `RIM_H` rim hides `RIM_H / tan(30 deg)` ~ 1.7x its own height of floor
## behind it), and the treads have to sit past that band. Hence: low rim, an
## unshaded black plate for the bottom, and the flight set back in the far half
## where nothing is standing in front of it.
const PIT_W := 2.7
const PIT_D := 3.2
## Low on purpose -- see above. Waist height here is what killed build 2.
const RIM_H := 0.44
const RIM_T := 0.36
const STEPS := 4
const RUN := 0.36


func _ready() -> void:
	prompt = "DESCEND"
	# Measured off the build below, not picked: the pit is 3.2 deep and its kerb is
	# solid, so the closest the hero can physically stand to the node's origin is
	# about 2.1 m head-on and more than that at a corner. A 2.2 radius left him
	# able to touch the stair from directly in front and nowhere else.
	radius = 3.2
	super()
	_build()


func activate(_by: Node3D) -> void:
	if Flow.busy:
		return
	# `Flow` owns the transition, and it is the only thing in the project that
	# calls change_scene_to_file. A stair that loaded the next floor itself would
	# be the second one, and the fade would stop being a guarantee.
	Flow.descend()


# --- Construction -----------------------------------------------------------

func _build() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.20, 0.19, 0.22)
	stone.roughness = 0.98
	stone.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var body := StaticBody3D.new()
	body.collision_layer = K.L_WORLD
	body.collision_mask = 0
	add_child(body)

	var half_w := PIT_W * 0.5 + RIM_T * 0.5
	var half_d := PIT_D * 0.5

	# The rim. Four low kerbs around the opening, so the pit reads as a pit from
	# every side rather than only from the one the flight faces -- the camera
	# orbits, and a prop that only works from its good side does not work.
	for sx in [-1.0, 1.0]:
		_slab(body, stone, Vector3(RIM_T, RIM_H, PIT_D + RIM_T * 2.0),
			Vector3(half_w * sx, RIM_H * 0.5, 0.0), true)
	for sz in [-1.0, 1.0]:
		_slab(body, stone, Vector3(PIT_W, RIM_H, RIM_T),
			Vector3(0.0, RIM_H * 0.5, (half_d + RIM_T * 0.5) * sz), true)

	# The bottom, and the only thing here doing the "down" -- an UNSHADED black
	# plate. Unshaded because the lamp two lines below is right on top of it: lit
	# like ordinary stone it comes back as a dark grey tray, and a tray with a
	# visible bottom is not a hole.
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Pal.VOID
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var pit := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(PIT_W, 0.06, PIT_D)
	pit.mesh = pm
	pit.material_override = dark
	# Just clear of the room's floor slab: coplanar boxes z-fight into a flicker.
	pit.position = Vector3(0.0, 0.03, 0.0)
	body.add_child(pit)

	# The flight, in the BACK half of the pit and descending toward the viewer.
	# Both halves of that matter: set back, the near kerb cannot hide it, and
	# descending toward you it shows its risers instead of the blank back of its
	# top step.
	for i in STEPS:
		var top := RIM_H * (float(STEPS - i) / float(STEPS))
		_slab(body, stone, Vector3(PIT_W, top, RUN),
			Vector3(0.0, top * 0.5, half_d - RUN * (float(i) + 0.5)), false)

	# Two posts on the near corners, lit cold. Every other light in the dungeon is
	# torch-orange, so the one cold light on the floor is the way down -- readable
	# from the doorway without a marker or an arrow, and tall enough to clear the
	# monsters that will be standing in front of it.
	for sx in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var postm := BoxMesh.new()
		postm.size = Vector3(0.3, 1.5, 0.3)
		post.mesh = postm
		post.material_override = stone
		post.position = Vector3(half_w * sx, 0.75, -half_d)
		body.add_child(post)

		var cap := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.38, 0.18, 0.38)
		cap.mesh = cm
		var glow := StandardMaterial3D.new()
		# Half the emission this started on. At 2.2 over a near-black room the cap
		# clipped to a white slab with a bloom halo and stopped being a lamp on a
		# post -- see the note about ADD over near-black in CLAUDE.md §3. The
		# colour has to survive the exposure or the one cold light in the dungeon
		# is just a bright rectangle.
		glow.albedo_color = Pal.CYAN
		glow.emission_enabled = true
		glow.emission = Pal.CYAN
		glow.emission_energy_multiplier = 1.1
		cap.material_override = glow
		cap.position = Vector3(half_w * sx, 1.59, -half_d)
		add_child(cap)

	# The lamp sits low and just inside the near kerb, raking ACROSS the treads
	# rather than shining down on them. Hung at cap height it lit the pit evenly
	# and the flight vanished -- steps are read off the shadow each one casts on
	# the next, so a light that kills the shadows kills the steps.
	var lamp := OmniLight3D.new()
	lamp.light_color = Pal.CYAN
	lamp.light_energy = 3.4
	lamp.omni_range = 5.0
	lamp.omni_attenuation = 1.4
	lamp.position = Vector3(0.0, 0.5, -half_d * 0.6)
	add_child(lamp)


## One box, optionally solid. `blocking` shapes are the housing itself -- the
## treads are left non-colliding so the hero can stand at the head of the flight
## instead of being held two metres off it by a staircase he cannot climb.
func _slab(body: StaticBody3D, mat: Material, size: Vector3, at: Vector3,
		blocking: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	body.add_child(mi)
	if not blocking:
		return
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position = at
	body.add_child(col)
