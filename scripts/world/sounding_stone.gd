class_name SoundingStone
extends Node3D
## The Votive Court shrine used at all three dungeon reward sites. The authored
## scene owns its `Interactable` and seven effigies; this root owns only the
## offer, menu hand-off, run flag, and the stonework they stand on.

const BLESSING_MENU_SCENE := "res://scenes/ui/blessing_menu.tscn"
const PatronDbScript := preload("res://scripts/items/patron_db.gd")
const DAIS_SIZE := Vector3(5.4, 0.22, 2.75)
const STEP_SIZE := Vector3(4.2, 0.12, 0.58)
const MAKER_PLINTH_R := 0.72
const MAKER_PLINTH_H := 0.34

## Which shrine this is, for the run-scoped world flag. Three sites on one floor
## need three flags or the first blessing silences the other two.
@export var stone_id: StringName = &"gate"
## Offered on the frame it is ready. Generated sites turn this off and call
## `offer()` only when their gate, shortcut, or miniboss reward resolves.
@export var auto_offer: bool = true

var _offers: Dictionary = {}
var _rolled: bool = false
var _spent: bool = false
var _interactable: Interactable = null
var _menu: Node = null


func _ready() -> void:
	add_to_group(&"sounding_stone")
	add_to_group(&"votive_shrine")
	_build_dais()
	_interactable = get_node_or_null(^"Interactable") as Interactable
	if _interactable != null:
		_interactable.activated.connect(_on_activated)
	_set_interaction(false)
	_set_answering({})

	# A floor re-entered inside one run does not offer a second blessing. The
	# `atom_` prefix is what lets `PuzzleAtom.clear_run_flags()` reset this with
	# the run rather than preserving it across descents.
	if Game.flag(flag_id()):
		_spent = true
		return
	if auto_offer:
		offer()


## The one-way, run-scoped world flag this shrine writes.
func flag_id() -> StringName:
	return StringName("atom_echo_stone_%d_%s" % [Run.level, stone_id])


func is_spent() -> bool:
	return _spent


## The blessing ids currently offered. Patron ownership stays internal to the
## shrine except through `responding_patrons()`.
func offered() -> Array[StringName]:
	var ids: Array[StringName] = []
	for value: Variant in _offers.values():
		ids.append(StringName(value))
	return ids


func responding_patrons() -> Array[StringName]:
	var patrons: Array[StringName] = []
	for key: Variant in _offers.keys():
		patrons.append(StringName(key))
	return patrons


func menu_open() -> bool:
	return is_instance_valid(_menu) and not _menu.is_queued_for_deletion()


# --- Offer and choice ---------------------------------------------------------

## Roll once from the run RNG. An empty result is still a completed roll: a
## shrine with no legal blessing stays dark instead of advancing RNG until it
## eventually finds a different answer.
func offer() -> void:
	if _spent or _rolled:
		return
	_rolled = true
	_offers = PatronDbScript.offer(Run.rng, Run.level, Run.echoes_held())
	_set_answering(_offers)
	_set_interaction(not _offers.is_empty())
	if not _offers.is_empty():
		Bus.request_sfx.emit(&"glint_bell", global_position)


func _on_activated(_by: Node3D) -> void:
	if _spent or _offers.is_empty() or menu_open():
		return
	var packed := load(BLESSING_MENU_SCENE) as PackedScene
	if packed == null:
		push_error("sounding_stone: %s failed to load" % BLESSING_MENU_SCENE)
		return
	var menu := packed.instantiate()
	if menu == null:
		push_error("sounding_stone: %s failed to instantiate" % BLESSING_MENU_SCENE)
		return
	var host := get_tree().current_scene
	if host == null:
		menu.queue_free()
		return

	# `setup` happens outside the tree by contract, so the first UI frame already
	# knows which three presences answer. The world is neither hidden nor paused.
	menu.call(&"setup", _offers.duplicate())
	menu.connect(&"blessing_chosen", _on_blessing_chosen)
	menu.connect(&"dismissed", _on_menu_dismissed)
	menu.tree_exited.connect(_on_menu_tree_exited)
	_menu = menu
	host.add_child(menu)


func _on_blessing_chosen(patron_id: StringName, blessing_id: StringName) -> void:
	if _spent or not _offers.has(patron_id):
		return
	if StringName(_offers[patron_id]) != blessing_id:
		return
	if Run.collect(blessing_id, 1) == 0:
		if menu_open():
			_menu.call(&"show_refusal", "BAG FULL — MAKE ROOM FOR A BLESSING")
		return

	_spent = true
	Game.set_flag(flag_id())
	_set_interaction(false)
	_set_chosen_effigy(patron_id)
	Bus.request_sfx.emit(&"level_chime", global_position)
	Bus.prompt_changed.emit(EchoDb.line_of(blessing_id).to_upper())
	_close_menu()


func _on_menu_dismissed() -> void:
	_menu = null


func _on_menu_tree_exited() -> void:
	_menu = null


func _close_menu() -> void:
	if not menu_open():
		_menu = null
		return
	var menu := _menu
	_menu = null
	menu.call(&"close")


func _set_interaction(active: bool) -> void:
	if _interactable != null:
		_interactable.enabled = active


func _set_answering(offers: Dictionary) -> void:
	for effigy: Node in _effigies():
		var patron_id := StringName(effigy.get(&"patron_id"))
		effigy.call(&"set_answering", offers.has(patron_id))


func _set_chosen_effigy(chosen: StringName) -> void:
	for effigy: Node in _effigies():
		var patron_id := StringName(effigy.get(&"patron_id"))
		effigy.call(&"set_answering", patron_id == chosen)


func _effigies() -> Array[Node]:
	var found: Array[Node] = []
	var root := get_node_or_null(^"Effigies")
	if root == null:
		return found
	for node: Node in root.get_children():
		if node.has_method(&"set_answering"):
			found.append(node)
	return found


# --- Shrine stonework ---------------------------------------------------------

func _build_dais() -> void:
	var stone := _mat(Pal.ASH.lerp(Pal.MIDNIGHT, 0.18))
	var edge := _mat(Pal.ASH.darkened(0.28))
	var body := StaticBody3D.new()
	body.name = "ShrineDais"
	body.collision_layer = K.L_WORLD
	body.collision_mask = 0
	add_child(body)

	# The top sits at y=0 so authored effigies can remain grounded. The front
	# tread projects toward local -Z, which is the side every placer aims home.
	_box(body, stone, DAIS_SIZE, Vector3(0.0, -DAIS_SIZE.y * 0.5, 0.15))
	_box(body, edge, STEP_SIZE, Vector3(0.0, -STEP_SIZE.y * 0.5, -1.47))
	_collision_box(body, DAIS_SIZE, Vector3(0.0, -DAIS_SIZE.y * 0.5, 0.15))

	# Vallen's broken figure is authored by `PatronEffigy`; this is only the
	# central maker-stone beneath it, kept dark like the monument itself.
	_cyl(body, edge, MAKER_PLINTH_R, MAKER_PLINTH_H,
		Vector3(0.0, MAKER_PLINTH_H * 0.5, 0.72))
	_collision_cyl(body, MAKER_PLINTH_R, MAKER_PLINTH_H,
		Vector3(0.0, MAKER_PLINTH_H * 0.5, 0.72))


func _mat(albedo: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.roughness = 0.96
	material.metallic = 0.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return material


func _box(parent: Node, material: Material, size: Vector3,
		at: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = at
	parent.add_child(mesh_instance)
	return mesh_instance


func _cyl(parent: Node, material: Material, radius: float, height: float,
		at: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.86
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = at
	parent.add_child(mesh_instance)
	return mesh_instance


func _collision_box(parent: Node, size: Vector3, at: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = at
	parent.add_child(collision)


func _collision_cyl(parent: Node, radius: float, height: float,
		at: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	collision.position = at
	parent.add_child(collision)
