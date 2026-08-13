class_name Statue
extends Interactable
## The First Lanternbearer, on a plinth in the middle of the plaza.
##
## **It is the `lanternkeeper` body in stone, and that is the point rather than a
## saving.** The Lanternkeeper stands at the foot of it, hooded, at 1.74 m; the
## statue is the same hooded silhouette at half again the size, weathered pale,
## holding up the lamp she sells you. Two figures with one outline, one of them
## carved, is a sentence about the Far Lantern Society that costs no dialogue and
## no screen -- the order she belongs to has been doing this long enough to have a
## founder worth carving, and the shop in front of it is what is left of them.
##
## Reusing an authored NPC body as sculpture works because of what these rigs
## are: whole people baked into one atlas (see `NpcBody`), so a flat stone tint
## across every surface takes the cloth, the leather and the face together and
## none of them fights the others. A statue modelled out of boxes would have been
## the honest kit-era choice and would have read as a box.
##
## The plinth carries the height. The figure is 2.6 m and the stone under it
## another 1.5, which puts the hood at 4.1 m -- clear of every roofline in the
## yard except the gatehouse, which is the one thing that is allowed to win.

## Metres, crown to heel, of the carved figure alone.
const FIGURE_H := 2.6
## Top of the plinth, and therefore the figure's floor.
const PLINTH_H := 1.5

## Pale, cold and completely flat. The garrison is a warm scene and the statue is
## the one thing in it made of nothing but weather -- a stone that took any of the
## sunset would sit in the same value band as the booths behind it and vanish.
const STONE := Color(0.47, 0.48, 0.46)

## Which body is carved. `NpcBody.PEOPLE` names them.
@export var who: String = "lanternkeeper"
## Only the real plaza monument offers the Glint service. Other copies preserve
## the same sculpture and collision but never enter Prompt arbitration.
@export var glint_service: bool = false


func _ready() -> void:
	prompt = "COMMUNE"
	enabled = glint_service
	radius = 2.5
	super()
	_build_plinth()
	_build_figure()
	_build_collision()


func activate(by: Node3D) -> void:
	if not glint_service or not enabled:
		return
	activated.emit(by)
	TradeScreen.open(self, TradeScreen.Mode.PROGRESSION,
		"THE GLINT STATUE", GlintDb, &"", "Glimmer")


## Three courses, each smaller than the one under it.
##
## A single block would be a pedestal; the step is what makes it a monument, and
## it is also the only thing keeping the figure's feet off the same plane as the
## paving -- a statue standing flat on the floor reads as a person standing still.
func _build_plinth() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = STONE * Color(0.86, 0.86, 0.88)
	mat.roughness = 1.0
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var courses := [
		{"size": Vector3(2.30, 0.30, 2.30), "y": 0.15},
		{"size": Vector3(1.90, 0.34, 1.90), "y": 0.47},
		{"size": Vector3(1.45, 0.86, 1.45), "y": 1.07},
	]
	for c in courses:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = c["size"]
		m.mesh = bm
		m.material_override = mat
		m.position.y = float(c["y"])
		add_child(m)

	# The inscription, on the face the plaza's south opening looks at. Small, and
	# deliberately unreadable from more than a few metres: it is a texture of
	# words at a distance and a name up close, which is how a monument works.
	#
	# **A `Label3D`, and it STAYS one — card #61.** That card moved three
	# billboarded captions onto the HUD canvas because `docs/STYLEGUIDE.md` §4.5
	# renders the world at 480 x 270 and a `Label3D` goes into that buffer with
	# the masonry. This is the case the card kept: an inscription is not a
	# caption ABOUT the monument, it is cut into it, and the sentence above is
	# already asking for exactly what §4.5 now delivers for free. It is not
	# billboarded, which is the tell — see `scripts/ui/world_caption.gd`. Making
	# it crisp at forty metres would be the regression, not the fix.
	var plate := Label3D.new()
	plate.text = "THE FIRST LANTERN"
	plate.font_size = 32
	plate.pixel_size = 0.0016
	plate.modulate = Pal.MOTH
	plate.outline_size = 10
	plate.position = Vector3(0.0, 1.05, 0.74)
	add_child(plate)


func _build_figure() -> void:
	var body := NpcBody.make(who)
	if body == null:
		return
	# Scaled by the ratio of the heights, because `NpcBody` has already fitted the
	# rig to its own metre height and re-fitting it here would fight that.
	body.scale = Vector3.ONE * (FIGURE_H / body.height)
	body.position.y = PLINTH_H
	# The pose is off `idle9` -- the Lanternkeeper's own clip, held at the top of
	# its lift, where the hands are up and the weight is on one foot. A statue
	# needs a moment, not an average (see `NpcBody.hold`).
	add_child(body)
	body.hold(&"idle9", 1.35)
	_petrify(body)


## Every surface of the body, turned to stone.
##
## The albedo goes flat pale grey and the EMISSION and the metallic go to zero,
## which is the part that matters: these atlases carry baked highlights in the
## eyes and the metalwork, and a statue with two live eyes in it is a person
## painted grey.
func _petrify(n: Node) -> void:
	for mi in _meshes(n):
		for s in mi.mesh.get_surface_count():
			var mat := StandardMaterial3D.new()
			mat.albedo_color = STONE
			mat.roughness = 1.0
			mat.metallic = 0.0
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			mi.set_surface_override_material(s, mat)


## The plinth only. The figure above it is out of reach and boxing it would just
## give the player an invisible column to walk into on the way past.
func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = K.L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.30, PLINTH_H, 2.30)
	cs.shape = box
	cs.position.y = PLINTH_H * 0.5
	body.add_child(cs)
	add_child(body)


static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var mi := n as MeshInstance3D
	if mi != null and mi.mesh != null:
		out.append(mi)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out
