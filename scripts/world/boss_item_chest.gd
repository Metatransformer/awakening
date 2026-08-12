class_name BossItemChest
extends Chest
## The deterministic great chest earned from a floor boss.
##
## Its item waits here until the lid opens. It never rolls `ItemDb`, touches
## `Run.rng`, adds arrows, or shares the corpse-floor relic's bag risk.

@export var item_id: StringName = &""

const ROOT_SCALE := 1.55
const REVEAL_TIME := 0.34

## THE LIT INTERIOR (card #127). The mouth's size and where it sits, in this
## node's OWN space -- so `ROOT_SCALE` carries them out to the world along with
## everything else hung on the chest, and the numbers below stay comparable with
## `Chest.SEAM_Y` and the trim bands next to them rather than being 1.55x copies
## of nothing.
##
## `SEAM_Y` is the lid LINE at 0.505; the pool sits a little under it, because a
## pool exactly on the seam is a bright edge along the rim and what this has to
## read as is the inside of a box.
const MOUTH_SIZE := Vector2(0.98, 0.55)
const MOUTH_Y := 0.46
## How far the spill stands out of the mouth, and it is the one number here that
## was chosen against the CAMERA rather than against the chest.
##
## **Almost none of a chest's mouth is visible from the ceremony camera, and that
## is geometry rather than tuning.** The camera stands 4.2 m off at 1.85 m and
## aims at 1.28, so the sightline that clears the chest's front rim is still
## above the mouth plane when it reaches the back wall -- you are looking at the
## box very nearly edge-on. Swinging the camera 25 and 40 degrees off the
## gameplay bearing was photographed and rejected
## (`item_get_frame --sweep=1`, rows c-f): it exposes a sliver of the interior
## and costs the whole composition, putting the hero off-centre and the item in a
## corner of the frame.
##
## So the thing that carries this shot is not the pool and not the column: it is
## the OPEN LID, which has swung past vertical, stands above the box and is the
## one interior-facing surface either camera can see. `RewardVfx.box_light`'s lamp
## is aimed at it. The column is the supporting half, and 0.62 is as tall as it
## may be -- 0.85 was tried and its hard silhouette cleared the chest's rim as a
## translucent block, which is CLAUDE.md §3 arriving through the geometry instead
## of through the material. It never leaves the chest's own footprint:
## `RewardVfx.MAJOR`'s seven-metre shaft is the across-the-room announcement, and
## this is the opposite sentence.
const SPILL_H := 0.62

var _inside: RewardVfx.BoxLight = null


func _ready() -> void:
	scale = Vector3.ONE * ROOT_SCALE
	super()
	prompt = "OPEN GREAT CHEST"
	_build_great_trim()


func activate(by: Node3D) -> void:
	if not _begin_open():
		return
	_light_the_inside()

	var awarded_item := item_id
	var hero := by as Hero
	var tree := get_tree()
	if tree == null:
		push_warning("BossItemChest: opened outside a SceneTree")
		_pay_item(awarded_item, hero, null)
		_finish_open(by, &"great_chest", false)
		return

	var host := tree.current_scene
	await tree.create_timer(REVEAL_TIME).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return

	_pay_item(awarded_item, hero, host if host == tree.current_scene else null)
	_finish_open(by, &"great_chest", false)


func _pay_item(awarded_item: StringName, hero: Hero, host: Node) -> void:
	if awarded_item == &"":
		push_warning("BossItemChest: opened without an item_id")
		return
	Game.grant(awarded_item)
	if hero == null or not is_instance_valid(hero):
		push_warning("BossItemChest: non-Hero opener received %s without presentation"
			% awarded_item)
		return
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		push_warning("BossItemChest: scene changed before %s could be presented"
			% awarded_item)
		return
	ItemGet.present(host, awarded_item, hero)


## Put a light INSIDE the box on the frame the lid starts to move, and take it
## out again when the ceremony that lifted the item out of it ends.
##
## **`Chest._begin_open` is doing the opposite thing three lines up**, and that is
## the whole of #127 part 2: it tweens the seam glow to zero over half a second,
## because for an ordinary chest the light was the *there is something in here*
## promise and opening it is the promise being kept. A great chest is not done at
## that point -- the item is about to be held over the hero's head for two and a
## half seconds, and #127's note is that the frame has to read as light coming out
## of a box rather than an object parked in the air. So the seam still goes out
## and the INSIDE comes up behind it.
##
## The close is hung on `Bus.item_get_finished` rather than on a timer, because
## the ceremony's length is the ceremony's business (`ItemGet.MIN_DISMISS_TIME`
## is a floor and the player dismisses it) and a chest that went dark early would
## be doing it behind the presentation camera.
func _light_the_inside() -> void:
	if _inside != null and is_instance_valid(_inside):
		return
	_inside = RewardVfx.box_light(self, MOUTH_SIZE,
		Vector3(0.0, MOUTH_Y, 0.0), SPILL_H)
	if _inside == null:
		return
	Bus.item_get_finished.connect(_on_item_get_finished)


func _on_item_get_finished(_id: StringName) -> void:
	if _inside != null and is_instance_valid(_inside):
		_inside.close(0.6)
	if Bus.item_get_finished.is_connected(_on_item_get_finished):
		Bus.item_get_finished.disconnect(_on_item_get_finished)


func _build_great_trim() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Pal.GOLD
	gold.metallic = 0.82
	gold.roughness = 0.28
	gold.emission_enabled = true
	gold.emission = Pal.GOLD * 0.42
	gold.emission_energy_multiplier = 1.35

	_add_trim_box("UpperBand", Vector3(1.18, 0.055, 0.045),
		Vector3(0.0, 0.50, 0.335), gold)
	_add_trim_box("LowerBand", Vector3(1.18, 0.055, 0.045),
		Vector3(0.0, 0.18, 0.335), gold)

	var crest_mesh := CylinderMesh.new()
	crest_mesh.top_radius = 0.15
	crest_mesh.bottom_radius = 0.15
	crest_mesh.height = 0.05
	var crest := MeshInstance3D.new()
	crest.name = "GreatChestCrest"
	crest.mesh = crest_mesh
	crest.material_override = gold
	crest.position = Vector3(0.0, 0.34, 0.365)
	crest.rotation.x = PI * 0.5
	add_child(crest)

	var light := OmniLight3D.new()
	light.name = "GreatChestLight"
	light.light_color = Pal.GOLD
	light.light_energy = 0.8
	light.omni_range = 3.4
	light.omni_attenuation = 1.8
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.95, 0.15)
	add_child(light)


func _add_trim_box(node_name: String, size: Vector3, at: Vector3,
		material: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	add_child(mesh)
