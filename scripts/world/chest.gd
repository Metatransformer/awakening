class_name Chest
extends Interactable
## A chest. Opens once, spits its contents onto the floor as motes, stays open.
##
## Contents are rolled at OPEN time, not at spawn time, and from `Run.rng` -- so
## a seeded run gives the same chest the same contents, but a chest you never
## opened never consumed a roll. That means adding a chest to a room does not
## reshuffle every other chest on the floor.
##
## Chests are the reason to leave the critical path, so they roll on
## ItemDb.CHEST_DROPS, whose floor is above an ordinary enemy's ceiling.

## How many things come out. Two is enough to make a chest feel like an event
## without making it the only thing worth doing. [tune]
@export var picks: int = 2
## Marks the chest as already-looted for the rest of the run.
@export var opened: bool = false

var _lid: Node3D
var _glow: OmniLight3D
var _rim: MeshInstance3D


func _ready() -> void:
	prompt = "OPEN"
	radius = 1.7
	super()
	_build()
	if opened:
		_slam_open()


func activate(by: Node3D) -> void:
	if opened:
		return
	opened = true
	enabled = false
	_rim.visible = false

	var tw := create_tween()
	tw.tween_property(_lid, "rotation:x", deg_to_rad(-104.0), 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_glow, "light_energy", 0.0, 0.5)

	for i in maxi(picks, 1):
		var id := ItemDb.roll(ItemDb.CHEST_DROPS, Run.rng)
		if id == &"":
			continue
		# Fan them out so two drops never land on top of each other and read as
		# one. The angle is off the chest's own facing, not the world's.
		var a := TAU * (float(i) + 0.5) / float(maxi(picks, 1)) - PI * 0.5
		var out := (global_transform.basis * Vector3(sin(a), 0.0, cos(a))).normalized()
		LootMote.drop(get_tree().current_scene, id,
			global_position + Vector3.UP * 0.7, out * 1.15)

	Bus.chest_opened.emit(name, &"chest")
	activated.emit(by)


# --- Construction -----------------------------------------------------------
# Built in code, like the rest of the kit: the .tscn stores parameters, never a
# few hundred generated triangles.

func _build() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.24, 0.16, 0.10)
	wood.roughness = 0.95
	wood.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.30, 0.28, 0.26)
	iron.metallic = 0.7
	iron.roughness = 0.6

	var body := StaticBody3D.new()
	body.collision_layer = K.L_WORLD
	body.collision_mask = 0
	add_child(body)

	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.1, 0.62, 0.78)
	base.mesh = bm
	base.material_override = wood
	base.position.y = 0.31
	body.add_child(base)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 0.9, 0.78)
	col.shape = box
	col.position.y = 0.45
	body.add_child(col)

	for sx in [-1.0, 1.0]:
		var band := MeshInstance3D.new()
		var bandm := BoxMesh.new()
		bandm.size = Vector3(0.10, 0.66, 0.84)
		band.mesh = bandm
		band.material_override = iron
		band.position = Vector3(0.36 * sx, 0.31, 0.0)
		body.add_child(band)

	# The lid pivots on its BACK edge, so the hinge is where a hinge would be.
	_lid = Node3D.new()
	_lid.position = Vector3(0.0, 0.62, -0.39)
	add_child(_lid)

	var lid_mesh := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(1.14, 0.22, 0.82)
	lid_mesh.mesh = lm
	lid_mesh.material_override = wood
	lid_mesh.position = Vector3(0.0, 0.11, 0.39)
	_lid.add_child(lid_mesh)

	var clasp := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.22, 0.26, 0.10)
	clasp.mesh = cm
	clasp.material_override = iron
	clasp.position = Vector3(0.0, 0.06, 0.80)
	_lid.add_child(clasp)

	# A thin seam of gold light at the lid line. This is the whole "there is
	# something in here" read -- no floating icon, no beam, no exclamation mark.
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Pal.GOLD
	rim_mat.emission_enabled = true
	rim_mat.emission = Pal.GOLD
	rim_mat.emission_energy_multiplier = 2.4
	_rim = MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(1.02, 0.03, 0.70)
	_rim.mesh = rm
	_rim.material_override = rim_mat
	_rim.position.y = 0.63
	add_child(_rim)

	_glow = OmniLight3D.new()
	_glow.light_color = Pal.GOLD
	_glow.light_energy = 1.5
	_glow.omni_range = 2.6
	_glow.omni_attenuation = 1.7
	_glow.shadow_enabled = false
	_glow.position.y = 0.75
	add_child(_glow)


func _slam_open() -> void:
	_lid.rotation.x = deg_to_rad(-104.0)
	_glow.light_energy = 0.0
	_rim.visible = false
	enabled = false
